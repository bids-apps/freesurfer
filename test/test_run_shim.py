"""Fast tests for run.py (the shim): fake FreeSurfer commands on PATH, no container, no FreeSurfer.

run.py sends every FreeSurfer call through a shell, so a stub `recon-all` that logs its arguments is enough to
check *what the shim asks FreeSurfer to do*: subject names, flags, step order, and what it leaves in the output.
What this cannot catch is anything about the real environment (kernel, PID namespaces, FreeSurfer itself);
that stays with the container tests in .circleci.
"""
import re
import subprocess
import sys
from pathlib import Path

import nibabel
import numpy as np
import pytest

RUN = Path(__file__).resolve().parent.parent / "run.py"
LINKED = ("fsaverage", "lh.EC_average", "rh.EC_average")  # run.py puts these in the output (#103)


def nifti(path, zoom=1.0):
    path.parent.mkdir(parents=True, exist_ok=True)
    nibabel.save(nibabel.Nifti1Image(np.zeros((2, 2, 2), np.float32), np.diag([zoom, zoom, zoom, 1])), path)


def make_bids(root, subjects):
    """subjects: {"01": [session labels] or None for a dataset without sessions}; one 1mm T1w per session."""
    for sub, sessions in subjects.items():
        for ses in sessions or [None]:
            d = root / f"sub-{sub}" / (f"ses-{ses}" if ses else "") / "anat"
            nifti(d / f"sub-{sub}{f'_ses-{ses}' if ses else ''}_T1w.nii.gz")
    return root


def shim(tmp_path, subjects, *args, zoom=1.0):
    """Run `run.py participant` with a fake recon-all; return (recon-all calls in order, output dir)."""
    bin_dir, log = tmp_path / "bin", tmp_path / "calls.log"
    bin_dir.mkdir()
    stub = bin_dir / "recon-all"
    stub.write_text('#!/bin/sh\necho "recon-all $*" >> "$FAKE_LOG"\n')
    stub.chmod(0o755)
    subjects_dir = tmp_path / "freesurfer_subjects"  # stands in for the container's $SUBJECTS_DIR
    for name in LINKED:
        (subjects_dir / name).mkdir(parents=True)
        (subjects_dir / name / "marker").write_text("x")
    bids = make_bids(tmp_path / "bids", subjects)
    if zoom != 1.0:
        for t1 in bids.rglob("*_T1w.nii.gz"):
            nifti(t1, zoom)
    license_file = tmp_path / "license.txt"
    license_file.write_text("fake")
    out = tmp_path / "out"
    out.mkdir()
    env = {"PATH": f"{bin_dir}:/usr/bin:/bin", "SUBJECTS_DIR": str(subjects_dir), "FAKE_LOG": str(log)}
    subprocess.run([sys.executable, str(RUN), str(bids), str(out), "participant", "--license_file", str(license_file),
                    "--skip_bids_validator", *args], env=env, check=True, capture_output=True)
    return (log.read_text().splitlines() if log.exists() else []), out


def subjids(calls):
    return [m.group(1) for c in calls if (m := re.search(r"-subjid (\S+)", c))]


# ---- #105: the FreeSurfer subject is named after the arguments, not after what else is on disk ----
@pytest.mark.parametrize("on_disk, args, expected", [
    pytest.param(None, [], ["sub-01"], id="no sessions"),
    pytest.param(["1", "2"], ["--session_label", "1", "--steps", "cross-sectional"], ["sub-01_ses-1"],
                 id="two on disk, one asked for"),
    pytest.param(["1"], ["--session_label", "1", "--steps", "cross-sectional"], ["sub-01_ses-1"],
                 id="one on disk, same ask",
                 marks=pytest.mark.xfail(strict=True, reason="#105: the name drops the session; remove with the fix")),
    pytest.param(["1", "2"], ["--multiple_sessions", "multiday"], ["sub-01"], id="multiday combines sessions"),
])
def test_subject_naming(tmp_path, on_disk, args, expected):
    calls, _ = shim(tmp_path, {"01": on_disk}, *args)
    assert subjids(calls) == expected


# ---- the whole longitudinal chain, in order ----
def test_longitudinal_order(tmp_path):
    calls, _ = shim(tmp_path, {"01": ["1", "2"]})
    kinds = ["cross" if "-subjid" in c else "template" if "-base" in c else "long" if "-long" in c else "?"
             for c in calls]
    assert kinds == ["cross", "cross", "template", "long", "long"]
    assert "-tp sub-01_ses-1" in calls[2] and "-tp sub-01_ses-2" in calls[2]


# ---- flags ----
@pytest.mark.parametrize("zoom, mode, hires", [
    (0.8, "auto", True), (1.0, "auto", False), (0.8, "disable", False), (1.0, "enable", True),
])
def test_hires(tmp_path, zoom, mode, hires):
    calls, _ = shim(tmp_path, {"01": None}, "--hires_mode", mode, zoom=zoom)
    assert (" -hires" in calls[0]) is hires


def test_only_requested_participant(tmp_path):
    calls, _ = shim(tmp_path, {"01": None, "02": None}, "--participant_label", "02")
    assert subjids(calls) == ["sub-02"]


# ---- #103: nothing in the output should point into the container's FreeSurfer ----
@pytest.mark.xfail(strict=True, reason="#103: run.py still links them; remove when #104 (copy instead) merges")
def test_output_has_no_links_into_the_container(tmp_path):
    _, out = shim(tmp_path, {"01": None})
    assert [n for n in LINKED if (out / n).is_symlink()] == []
    assert all((out / n / "marker").exists() for n in LINKED)  # real copies, not missing
