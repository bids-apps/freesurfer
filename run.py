#!/usr/bin/env python3
import argparse
import os
import shutil
import nibabel
from glob import glob
from subprocess import Popen, PIPE
from shutil import rmtree
import subprocess

def run(command, env={}, ignore_errors=False):
    merged_env = os.environ
    merged_env.update(env)
    # DEBUG env triggers freesurfer to produce gigabytes of files
    merged_env.pop('DEBUG', None)
    process = Popen(command, stdout=PIPE, stderr=subprocess.STDOUT, shell=True, env=merged_env)
    while True:
        line = process.stdout.readline()
        line = str(line, 'utf-8')[:-1]
        print(line)
        if line == '' and process.poll() != None:
            break
    if process.returncode != 0 and not ignore_errors:
        raise Exception("Non zero return code: %d"%process.returncode)

__version__ = open('/version').read()

parser = argparse.ArgumentParser(description='FreeSurfer recon-all + custom template generation.')
parser.add_argument('bids_dir', help='The directory with the input dataset '
                    'formatted according to the BIDS standard.')
parser.add_argument('output_dir', help='The directory where the output files '
                    'should be stored. If you are running group level analysis '
                    'this folder should be prepopulated with the results of the'
                    'participant level analysis.')
parser.add_argument('analysis_level', help='Level of the analysis that will be performed. '
                    'Multiple participant level analyses can be run independently '
                    '(in parallel) using the same output_dir.',
                    choices=['participant', 'group'])
parser.add_argument('--participant_label', help='The label of the participant that should be analyzed. The label '
                   'corresponds to sub-<participant_label> from the BIDS spec '
                   '(so it does not include "sub-"). If this parameter is not '
                   'provided all subjects should be analyzed. Multiple '
                   'participants can be specified with a space separated list.',
                   nargs="+")
parser.add_argument('--n_cpus', help='Number of CPUs/cores available to use.',
                   default=1, type=int)
parser.add_argument('--stages', help='Autorecon stages to run.',
                    choices=["autorecon1", "autorecon2", "autorecon2-cp", "autorecon2-wm", "autorecon2-pial", "autorecon3", "autorecon-all", "all"],
                    default=["autorecon-all"],
                    nargs="+")
parser.add_argument('--template_name', help='Name for the custom group level template generated for this dataset',
                    default="average")
parser.add_argument('--license_key', help='FreeSurfer license key - letters and numbers after "*" in the email you received after registration. To register (for free) visit https://surfer.nmr.mgh.harvard.edu/registration.html',
                    required=True)
parser.add_argument('--acquisition_label', help='If the dataset contains multiple T1 weighted images from different acquisitions which one should be used? Corresponds to "acq-<acquisition_label>"')
parser.add_argument('--multiple_sessions', help='For datasets with multiday sessions where you do not want to '
                    'use the longitudinal pipeline, i.e., sessions were back-to-back, '
                    'set this to multiday, otherwise sessions with T1w data will be '
                    'considered independent sessions for longitudinal analysis.',
                    choices=["longitudinal", "multiday"],
                    default="longitudinal")
parser.add_argument('--refine_pial', help='If the dataset contains 3D T2 or T2 FLAIR weighted images (~1x1x1), '
                    'these can be used to refine the pial surface. If you want to ignore these, specify None or '
                    ' T1only to base surfaces on the T1 alone.',
                    choices=['T2', 'FLAIR', 'None', 'T1only'],
                    default=['T2'])
parser.add_argument('--hires_mode', help='',
                    choices=['auto', 'enable', 'disable'],
                    default='auto')
parser.add_argument('-v', '--version', action='version',
                    version='BIDS-App example version {}'.format(__version__))

args = parser.parse_args()

run("bids-validator " + args.bids_dir)

subject_dirs = glob(os.path.join(args.bids_dir, "sub-*"))
if args.acquisition_label:
    acq_tpl = "*acq-%s*" % args.acquisition_label
else:
    acq_tpl = "*"

subjects_to_analyze = []
# only for a subset of subjects
if args.participant_label:
    subjects_to_analyze = args.participant_label
# for all subjects
else:
    subject_dirs = glob(os.path.join(args.bids_dir, "sub-*"))
    subjects_to_analyze = [subject_dir.split("-")[-1] for subject_dir in subject_dirs]

# workaround for https://mail.nmr.mgh.harvard.edu/pipermail//freesurfer/2016-July/046538.html
output_dir = os.path.abspath(args.output_dir)

# running participant level
if args.analysis_level == "participant":
    if not os.path.exists(os.path.join(output_dir, "fsaverage")):
        run("cp -rf " + os.path.join(os.environ["SUBJECTS_DIR"], "fsaverage") + " " + os.path.join(output_dir, "fsaverage"),
            ignore_errors=True)
    if not os.path.exists(os.path.join(output_dir, "lh.EC_average")):
        run("cp -rf " + os.path.join(os.environ["SUBJECTS_DIR"], "lh.EC_average") + " " + os.path.join(output_dir, "lh.EC_average"),
            ignore_errors=True)
    if not os.path.exists(os.path.join(output_dir, "rh.EC_average")):
        run("cp -rf " + os.path.join(os.environ["SUBJECTS_DIR"], "rh.EC_average") + " " + os.path.join(output_dir, "rh.EC_average"),
            ignore_errors=True)

    for subject_label in subjects_to_analyze:

        # Check for multiple sessions to combine as a multiday session or as a longitudinal stream
        session_dirs = glob(os.path.join(args.bids_dir,"sub-%s"%subject_label,"ses-*"))
        sessions = [os.path.split(dr)[-1].split("-")[-1] for dr in session_dirs]
        longitudinal_study = False
        n_valid_sessions = 0
        for session_label in sessions:
            if glob(os.path.join(args.bids_dir, "sub-%s"%subject_label,
                                                "ses-%s"%session_label,
                                                "anat",
                                                "%s_T1w.nii*"%acq_tpl)):
                n_valid_sessions += 1
        if n_valid_sessions > 1 and args.multiple_sessions == "longitudinal":
            longitudinal_study = True

        timepoints = []

        if len(sessions) > 0 and longitudinal_study == True:
            # Running each session separately, prior to doing longitudinal pipeline
            for session_label in sessions:
                T1s = glob(os.path.join(args.bids_dir,
                                  "sub-%s"%subject_label,
                                  "ses-%s"%session_label,
                                  "anat",
                                  "%s_T1w.nii*"%acq_tpl))
                input_args = ""
                for T1 in T1s:
                    if (round(max(nibabel.load(T1).header.get_zooms()),1) < 1.0 and args.hires_mode == "auto") or args.hires_mode == "enable":
                        input_args += " -hires"
                    input_args += " -i %s"%T1

                T2s = glob(os.path.join(args.bids_dir, "sub-%s"%subject_label,
                                        "ses-%s"%session_label, "anat",
                                        "*_T2w.nii*"))
                FLAIRs = glob(os.path.join(args.bids_dir, "sub-%s"%subject_label,
                                        "ses-%s"%session_label, "anat",
                                        "*_FLAIR.nii*"))
                if args.refine_pial == "T2":
                    for T2 in T2s:
                        if max(nibabel.load(T2).header.get_zooms()) < 1.2:
                            input_args += " " + " ".join(["-T2 %s"%T2])
                            input_args += " -T2pial"
                elif args.refine_pial == "FLAIR":
                    for FLAIR in FLAIRs:
                        if max(nibabel.load(FLAIR).header.get_zooms()) < 1.2:
                            input_args += " " + " ".join(["-FLAIR %s"%FLAIR])
                            input_args += " -FLAIRpial"

                fsid = "sub-%s_ses-%s"%(subject_label, session_label)
                timepoints.append(fsid)
                cmd = "recon-all -subjid %s -sd %s %s -all -parallel -openmp %d"%(fsid,
                                                                        output_dir,
                                                                        input_args,
                                                                        args.n_cpus)
                resume_cmd = "recon-all -subjid %s -sd %s -all -parallel -openmp %d"%(fsid,
                                                                            output_dir,
                                                                            args.n_cpus)

                if os.path.isfile(os.path.join(output_dir, fsid,"scripts/IsRunning.lh+rh")):
                    rmtree(os.path.join(output_dir, fsid))
                    print("DELETING OUTPUT SUBJECT DIR AND RE-RUNNING COMMAND:")
                    print(cmd)
                    run(cmd)
                elif os.path.exists(os.path.join(output_dir, fsid)):
                    print("SUBJECT DIR ALREADY EXISTS (without IsRunning.lh+rh), RUNNING COMMAND:")
                    print(resume_cmd)
                    run(resume_cmd)
                else:
                    print(cmd)
                    run(cmd)

            # creating a subject specific template
            input_args = " ".join(["-tp %s"%tp for tp in timepoints])
            fsid = "sub-%s"%subject_label
            stages = " ".join(["-" + stage for stage in args.stages])
            cmd = "recon-all -base %s -sd %s %s %s -parallel -openmp %d"%(fsid,
                                                                output_dir,
                                                                input_args,
                                                                stages,
                                                                args.n_cpus)
            resume_cmd = "recon-all -base %s -sd %s %s -parallel -openmp %d"%(fsid,
                                                                    output_dir,
                                                                    stages,
                                                                    args.n_cpus)

            if os.path.isfile(os.path.join(output_dir, fsid,"scripts/IsRunning.lh+rh")):
                rmtree(os.path.join(output_dir, fsid))
                print("DELETING OUTPUT SUBJECT DIR AND RE-RUNNING COMMAND:")
                print(cmd)
                run(cmd)
            elif os.path.exists(os.path.join(output_dir, fsid)):
                print("SUBJECT DIR ALREADY EXISTS (without IsRunning.lh+rh), RUNNING COMMAND:")
                print(resume_cmd)
                run(resume_cmd)
            else:
                print(cmd)
                run(cmd)

            for tp in timepoints:
                # longitudinally process all timepoints
                fsid = "sub-%s"%subject_label
                stages = " ".join(["-" + stage for stage in args.stages])
                cmd = "recon-all -long %s %s -sd %s %s -parallel -openmp %d"%(tp,
                                                                    fsid,
                                                                    output_dir,
                                                                    stages,
                                                                    args.n_cpus)

                if os.path.isfile(os.path.join(output_dir, tp + ".long." + fsid,"scripts/IsRunning.lh+rh")):
                    rmtree(os.path.join(output_dir, tp + ".long." + fsid))
                    print("DELETING OUTPUT SUBJECT DIR AND RE-RUNNING COMMAND:")
                print(cmd)
                run(cmd)

        elif len(sessions) > 0 and longitudinal_study == False:
            # grab all T1s/T2s from multiple sessions and combine
            T1s = glob(os.path.join(args.bids_dir,
                                    "sub-%s"%subject_label,
                                    "ses-*",
                                    "anat",
                                    "%s_T1w.nii*"%acq_tpl))
            input_args = ""
            for T1 in T1s:
                if (round(max(nibabel.load(T1).header.get_zooms()),1) < 1.0 and args.hires_mode == "auto") or args.hires_mode == "enable":
                    input_args += " -hires"
                input_args += " -i %s"%T1

            T2s = glob(os.path.join(args.bids_dir,
                                    "sub-%s"%subject_label,
                                    "ses-*",
                                    "anat",
                                    "*_T2w.nii*"))
            FLAIRs = glob(os.path.join(args.bids_dir,
                                    "sub-%s"%subject_label,
                                    "ses-*",
                                    "anat",
                                    "*_FLAIR.nii*"))
            if args.refine_pial == "T2":
                for T2 in T2s:
                    if max(nibabel.load(T2).header.get_zooms()) < 1.2:
                        input_args += " " + " ".join(["-T2 %s"%T2])
                        input_args += " -T2pial"
            elif args.refine_pial == "FLAIR":
                for FLAIR in FLAIRs:
                    if max(nibabel.load(FLAIR).header.get_zooms()) < 1.2:
                        input_args += " " + " ".join(["-FLAIR %s"%FLAIR])
                        input_args += " -FLAIRpial"

            fsid = "sub-%s"%subject_label
            stages = " ".join(["-" + stage for stage in args.stages])
            cmd = "recon-all -subjid %s -sd %s %s %s -parallel -openmp %d"%(fsid,
                                                                  output_dir,
                                                                  input_args,
                                                                  stages,
                                                                  args.n_cpus)
            resume_cmd = "recon-all -subjid %s -sd %s %s -parallel -openmp %d"%(fsid,
                                                                      output_dir,
                                                                      stages,
                                                                      args.n_cpus)

            if os.path.isfile(os.path.join(output_dir, fsid,"scripts/IsRunning.lh+rh")):
                rmtree(os.path.join(output_dir, fsid))
                print("DELETING OUTPUT SUBJECT DIR AND RE-RUNNING COMMAND:")
                print(cmd)
                run(cmd)
            elif os.path.exists(os.path.join(output_dir, fsid)):
                print("SUBJECT DIR ALREADY EXISTS (without IsRunning.lh+rh), RUNNING COMMAND:")
                print(resume_cmd)
                run(resume_cmd)
            else:
                print(cmd)
                run(cmd)

        else:
            # grab all T1s/T2s from single session (no ses-* directories)
            T1s = glob(os.path.join(args.bids_dir,
                       "sub-%s"%subject_label,
                       "anat",
                       "%s_T1w.nii*"%acq_tpl))
            input_args = ""
            for T1 in T1s:
                if (round(max(nibabel.load(T1).header.get_zooms()),1) < 1.0 and args.hires_mode == "auto") or args.hires_mode == "enable":
                    input_args += " -hires"
                input_args += " -i %s"%T1
            T2s = glob(os.path.join(args.bids_dir, "sub-%s"%subject_label, "anat",
                                    "*_T2w.nii*"))
            FLAIRs = glob(os.path.join(args.bids_dir, "sub-%s"%subject_label, "anat",
                                    "*_FLAIR.nii*"))
            if args.refine_pial == "T2":
                for T2 in T2s:
                    if max(nibabel.load(T2).header.get_zooms()) < 1.2:
                        input_args += " " + " ".join(["-T2 %s"%T2])
                        input_args += " -T2pial"
            elif args.refine_pial == "FLAIR":
                for FLAIR in FLAIRs:
                    if max(nibabel.load(FLAIR).header.get_zooms()) < 1.2:
                        input_args += " " + " ".join(["-FLAIR %s"%FLAIR])
                        input_args += " -FLAIRpial"

            fsid = "sub-%s"%subject_label
            stages = " ".join(["-" + stage for stage in args.stages])
            cmd = "recon-all -subjid %s -sd %s %s %s -parallel -openmp %d"%(fsid,
                                                                  output_dir,
                                                                  input_args,
                                                                  stages,
                                                                  args.n_cpus)
            resume_cmd = "recon-all -subjid %s -sd %s %s -parallel -openmp %d"%(fsid,
                                                                      output_dir,
                                                                      stages,
                                                                      args.n_cpus)

            if os.path.isfile(os.path.join(output_dir, fsid,"scripts/IsRunning.lh+rh")):
                rmtree(os.path.join(output_dir, fsid))
                print("DELETING OUTPUT SUBJECT DIR AND RE-RUNNING COMMAND:")
                print(cmd)
                run(cmd)
            elif os.path.exists(os.path.join(output_dir, fsid)):
                print("SUBJECT DIR ALREADY EXISTS (without IsRunning.lh+rh), RUNNING COMMAND:")
                print(resume_cmd)
                run(resume_cmd)
            else:
                print(cmd)
                run(cmd)

elif args.analysis_level == "group":    	# running group level
    if len(subjects_to_analyze) > 1:
        # generate study specific template
        fsids = ["sub-%s"%s for s in subjects_to_analyze]
        cmd = "make_average_subject --no-symlink --out " + args.template_name + " --subjects " + " ".join(fsids)
        print(cmd)
        if os.path.exists(os.path.join(output_dir, args.template_name)):
            rmtree(os.path.join(output_dir, args.template_name))
        run(cmd, env={"SUBJECTS_DIR": output_dir})
        for subject_label in subjects_to_analyze:
            for hemi in ["lh", "rh"]:
                tif_file = os.path.join(output_dir, args.template_name, hemi+".reg.template.tif")
                fsid = "sub-%s"%subject_label
                sphere_file = os.path.join(output_dir, fsid, "surf", hemi+".sphere")
                reg_file = os.path.join(output_dir, fsid, "surf", hemi+".sphere.reg." + args.template_name)
                cmd = "mris_register -curv %s %s %s"%(sphere_file, tif_file, reg_file)
                run(cmd, env={"SUBJECTS_DIR": output_dir})
    else:
        print("Only one subject included in the analysis. Skipping group level")
