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
  for VERSION in "6.0.1" "7.4.1"
  do
    if [ $VERSION = "6.0.1" ]
    then
      OUTFILE=${OUTFILEBASE}_fs6
    else
      OUTFILE=${OUTFILEBASE}_fs7
    fi

    # Generate a dockerfile for building BIDS-Apps Freesurfer container
    docker run --rm ${image} generate ${TARGET} \
      --base-image ubuntu:jammy \
      --pkg-manager apt \
      --install tcsh bc tar libgomp1 perl-modules wget curl \
        libsm-dev libx11-dev libxt-dev libxext-dev libglu1-mesa libpython2.7-stdlib\
      --freesurfer version=${VERSION} install_path=/opt/freesurfer \
      --miniconda version=latest mamba=true conda_install="pandas" pip_install="nibabel" \
      --run-bash 'curl -sL https://deb.nodesource.com/setup_16.x | bash -' \
      --install nodejs \
      --run-bash 'npm install -g bids-validator@1.12.0' \
      --env FSLDIR=/usr/share/fsl/5.0 FSLOUTPUTTYPE=NIFTI_GZ \
            FSLMULTIFILEQUIT=TRUE POSSUMDIR=/usr/share/fsl/5.0 LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
            FSLTCLSH=/usr/bin/tclsh FSLWISH=/usr/bin/wish FSLOUTPUTTYPE=NIFTI_GZ \
      --env OS=Linux FS_OVERRIDE=0 FIX_VERTEX_AREA= SUBJECTS_DIR=/opt/freesurfer/subjects \
            FSF_OUTPUT_FORMAT=nii.gz MNI_DIR=/opt/freesurfer/mni LOCAL_DIR=/opt/freesurfer/local \
            FREESURFER_HOME=/opt/freesurfer FSFAST_HOME=/opt/freesurfer/fsfast MINC_BIN_DIR=/opt/freesurfer/mni/bin \
            MINC_LIB_DIR=/opt/freesurfer/mni/lib MNI_DATAPATH=/opt/freesurfer/mni/data \
            FMRI_ANALYSIS_DIR=/opt/freesurfer/fsfast PERL5LIB=/opt/freesurfer/mni/share/perl5 \
            MNI_PERL5LIB=/opt/freesurfer/mni/share/perl5/ \
            PATH=/opt/miniconda-latest/bin:/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/freesurfer/mni/bin:/usr/lib/fsl/5.0:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
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
