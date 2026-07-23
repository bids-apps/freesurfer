#!/bin/bash

###############################################################################
# Generate a Dockerfile and Singularity recipe for building the BIDS-Apps Freesurfer container.
#
# Steps to build, upload, and deploy the BIDS-Apps Freesurfer docker and/or singularity image:
#
# 1. Create or update the Dockerfile and Singuarity recipe:
# bash generate_freesurfer_images.sh
#
# 2. Build the docker image:
# docker build -t freesurfer -f Dockerfile .
#
#    and/or singularity image:
# singularity build freesurfer.simg Singularity
#
# 3. Push to Docker hub:
# (https://docs.docker.com/docker-cloud/builds/push-images/)
# export DOCKER_ID_USER="bids"
# docker login
# docker tag mindboggle bids/mindboggle  # See: https://docs.docker.com/engine/reference/commandline/tag/
# docker push nipy/mindboggle
#
# 4. Pull from Docker hub (or use the original):
# docker pull bids/freesurfer
#
# In the following, the Docker container can be the original (bids)
# or the pulled version (bids/freesurfer), and is given access to /Users/filo
# on the host machine.
#
# 5. Enter the bash shell of the Docker container, and add port mappings:
# docker run -ti --rm \
#                -v /Users/filo/data/ds005:/bids_dataset:ro \
#                -v /Users/filo/outputs:/outputs \
#                -v /Users/filo/freesurfer_license.txt:/license.txt \
#                bids/freesurfer \
#                /bids_dataset /outputs participant --participant_label 01 \
#                --license_file "/license.txt"
#
###############################################################################

image="repronim/neurodocker@sha256:e552690641a7175ece97e0ef05dd2679d7f916a5bb6864aa92515bd350c24758"
for TARGET in docker singularity
do
  if [ $TARGET = docker ]
  then
    OUTFILEBASE=Dockerfile
  else
    OUTFILEBASE=Singularity
  fi
  for VERSION in "6.0.1" "7.4.1" "8.2.0"
  do
    if [ $VERSION = "6.0.1" ]
    then
      OUTFILE=${OUTFILEBASE}_fs6
      INSTALL_DIR=/opt/freesurfer
      FS_ROOT=$INSTALL_DIR
    elif [ $VERSION = "7.4.1" ]
    then
      OUTFILE=${OUTFILEBASE}_fs7
      # INSTALL_DIR here is the --freesurfer install_path=, i.e. the tar
      # extraction target below (-C $INSTALL_DIR --strip-components 1) --
      # it is NOT the same as the true FreeSurfer root (FS_ROOT). The
      # 7.4.1 tarball's entries are "./freesurfer/...", so
      # --strip-components 1 only strips the leading "./"; extracting
      # into /opt/freesurfer directly (like fs6) would double-nest to
      # /opt/freesurfer/freesurfer. Extracting into /opt/ instead lands
      # the files at /opt/freesurfer, one level below INSTALL_DIR.
      # Confirmed by actually building both variants and inspecting the
      # image (`docker run --entrypoint bash ... find /opt`), not just
      # reading the extraction command -- a "fix" here that made FS_ROOT
      # equal INSTALL_DIR broke recon-all's PATH entirely (caught by CI:
      # bids-apps/freesurfer#96, test_7_1/test_7_2, "recon-all: not found").
      INSTALL_DIR=/opt/
      FS_ROOT=/opt/freesurfer
    else
      OUTFILE=${OUTFILEBASE}_fs8
      INSTALL_DIR=/usr/local/freesurfer/8.2.0
      FS_ROOT=$INSTALL_DIR
    fi

    # 8.2.0 ships only as a .deb (no generic tarball), so neurodocker's
    # --freesurfer template (which only knows versions <=7.4.1) can't be used
    # for it -- install it by hand the same way the miniconda/nodejs steps
    # below already do with --run-bash. apt resolves the .deb's own Depends:
    # (xorg/tcsh/bc/etc.), so no need to hand-list them here like the
    # tarball-based versions below do.
    ARGS=(generate ${TARGET} --base-image ubuntu:jammy --pkg-manager apt)
    if [ $VERSION = "8.2.0" ]
    then
      ARGS+=(--install tcsh bc tar libgomp1 wget curl ca-certificates)
      ARGS+=(--run-bash "wget -q -O /tmp/freesurfer_8.2.0.deb https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/8.2.0/freesurfer_ubuntu22-8.2.0_amd64.deb && apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -q /tmp/freesurfer_8.2.0.deb && rm -f /tmp/freesurfer_8.2.0.deb && rm -rf /var/lib/apt/lists/*")
    else
      ARGS+=(--install tcsh bc tar libgomp1 perl-modules wget curl libsm-dev libx11-dev libxt-dev libxext-dev libglu1-mesa libpython2.7-stdlib python2)
      ARGS+=(--freesurfer version=${VERSION} install_path=$INSTALL_DIR)
    fi
    # run.py no longer calls df.append() (removed in pandas 2.0), so nothing
    # needs the old pandas==1.5.3 pin anymore -- and pinning it now actively
    # breaks the build: Miniconda's "latest" installer currently ships
    # Python 3.14, which pandas 1.5.3 (needs <3.11) can't be solved against.
    PANDAS_SPEC="pandas"

    # Hand-written equivalent of neurodocker's own --miniconda template: that
    # template (baked into the pinned neurodocker image) predates Anaconda's
    # Terms-of-Service gate on the defaults channels, so a fresh build fails
    # with CondaToSNonInteractiveError on `conda update -yq -nbase conda`
    # regardless of FreeSurfer version -- not an fs8-specific issue, would hit
    # a fresh fs6/fs7 build the same way. Same steps as the template's own
    # generated RUN block, just with the two `conda tos accept` calls it's
    # missing, inserted where the error says to run them (right after the
    # installer, before anything else touches those channels).
    CONDA_CMD='apt-get update -qq && apt-get install -y -q --no-install-recommends bzip2 ca-certificates curl && rm -rf /var/lib/apt/lists/* && export PATH="/opt/miniconda-latest/bin:$PATH" && echo "Downloading Miniconda installer ..." && conda_installer="/tmp/miniconda.sh" && curl -fsSL -o "$conda_installer" https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash "$conda_installer" -b -p /opt/miniconda-latest && rm -f "$conda_installer" && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && conda update -yq -nbase conda && conda install -yq -nbase conda-libmamba-solver && conda config --set solver libmamba && conda config --system --prepend channels conda-forge && conda config --set channel_priority strict && conda config --system --set auto_update_conda false && conda config --system --set show_channel_urls true && conda init bash && conda install -y --name base '"$PANDAS_SPEC"' && bash -c "source activate base && python -m pip install --no-cache-dir nibabel" && sync && conda clean --all --yes && sync && rm -rf ~/.cache/pip/*'

    # Generate a dockerfile for building BIDS-Apps Freesurfer container
    docker run --rm ${image} "${ARGS[@]}" \
      --run-bash "$CONDA_CMD" \
      --run-bash 'curl -sL https://deb.nodesource.com/setup_18.x | bash -' \
      --install nodejs \
      --run-bash 'npm install -g bids-validator@1.12.0' \
      --env FSLDIR=/usr/share/fsl/5.0 FSLOUTPUTTYPE=NIFTI_GZ \
            FSLMULTIFILEQUIT=TRUE POSSUMDIR=/usr/share/fsl/5.0 LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
            FSLTCLSH=/usr/bin/tclsh FSLWISH=/usr/bin/wish FSLOUTPUTTYPE=NIFTI_GZ \
      --env FS_VERSION=${VERSION} \
      --env OS=Linux FS_OVERRIDE=0 FIX_VERTEX_AREA= SUBJECTS_DIR=$FS_ROOT/subjects \
            FSF_OUTPUT_FORMAT=nii.gz MNI_DIR=$FS_ROOT/mni LOCAL_DIR=$FS_ROOT/local \
            FREESURFER_HOME=$FS_ROOT FREESURFER=$FS_ROOT FSFAST_HOME=$FS_ROOT/fsfast MINC_BIN_DIR=$FS_ROOT/mni/bin \
            MINC_LIB_DIR=$FS_ROOT/mni/lib MNI_DATAPATH=$FS_ROOT/mni/data \
            FMRI_ANALYSIS_DIR=$FS_ROOT/fsfast FUNCTIONALS_DIR=$FS_ROOT/sessions PERL5LIB=$FS_ROOT/mni/share/perl5 \
            MNI_PERL5LIB=$FS_ROOT/mni/share/perl5/ \
            PATH=/opt/miniconda-latest/bin:$FS_ROOT/bin:$FS_ROOT/fsfast/bin:$FS_ROOT/tktools:$FS_ROOT/mni/bin:/usr/lib/fsl/5.0:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            PYTHONPATH="" \
      --run 'mkdir root/matlab && touch root/matlab/startup.m' \
      --run 'mkdir /scratch' \
      --run 'mkdir /local-scratch' \
      --copy run.py '/run.py' \
      --run  'chmod +x /run.py' \
      --copy version '/version' \
      --entrypoint 'python /run.py' \
    > $OUTFILE
  done
done
