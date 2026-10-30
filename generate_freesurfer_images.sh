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

image="repronim/neurodocker:2.1.1"
for TARGET in docker singularity
do
  if [ $TARGET = docker ]
  then
    OUTFILEBASE=Dockerfile
  else
    OUTFILEBASE=Singularity
  fi
  for VERSION in "7.4.1" "8.2.0"
  do
    if [ $VERSION = "7.4.1" ]
    then
      OUTFILE=${OUTFILEBASE}_fs7
      FS_ROOT=/opt/freesurfer
      install_pkgs="perl-modules libsm-dev libx11-dev libxt-dev libxext-dev libglu1-mesa"
      extra_args=''
    else
      OUTFILE=${OUTFILEBASE}_fs8
      FS_ROOT=/usr/local/freesurfer/8.2.0
      # apt resolves the .deb's own Depends: (xorg/tcsh/bc/etc.), so no need
      # to hand-list them here like the tarball-based 7.4.1 above does.
      install_pkgs="ca-certificates"
      extra_args="--miniconda version=latest mamba=true conda_install=pandas pip_install=nibabel"
    fi

    # 8.2.0 ships only as a .deb (no generic tarball), so neurodocker's
    # --freesurfer template (which only knows versions <=7.4.1) can't be used
    # for it -- install it by hand with --run-bash.
    if [ $VERSION = "8.2.0" ]
    then
      fs_install=(--run-bash "wget -q -O /tmp/freesurfer_8.2.0.deb https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/8.2.0/freesurfer_ubuntu22-8.2.0_amd64.deb && apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -q /tmp/freesurfer_8.2.0.deb && rm -f /tmp/freesurfer_8.2.0.deb && rm -rf /var/lib/apt/lists/*")
    else
      fs_install=(--freesurfer version=${VERSION} install_path=$FS_ROOT)
    fi

    # Generate a dockerfile for building BIDS-Apps Freesurfer container
    docker run --rm ${image} generate ${TARGET} \
      --base-image ubuntu:jammy \
      --pkg-manager apt \
      --install tcsh bc tar libgomp1 wget curl $install_pkgs \
      "${fs_install[@]}" \
      $extra_args \
      --bids_validator version=1.12.0\
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
            PATH=/opt/miniconda-latest/bin:$FS_ROOT/python/bin:$FS_ROOT/bin:$FS_ROOT/fsfast/bin:$FS_ROOT/tktools:$FS_ROOT/mni/bin:/usr/lib/fsl/5.0:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
            PYTHONPATH="" \
      --run 'mkdir root/matlab && touch root/matlab/startup.m' \
      --run 'mkdir /scratch' \
      --run 'mkdir /local-scratch' \
      --copy run.py '/run.py' \
      --run  'chmod +x /run.py' \
      --copy version '/version' \
      --entrypoint 'python3 /run.py' \
    > $OUTFILE
  done
done
