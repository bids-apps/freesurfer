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

image="kaczmarj/neurodocker:master@sha256:936401fe8f677e0d294f688f352cbb643c9693f8de371475de1d593650e42a66"

# Generate a dockerfile for building BIDS-Apps Freesurfer container
docker run --rm ${image} generate docker \
  --base ubuntu:xenial \
  --pkg-manager apt \
  --install tcsh bc tar libgomp1 perl-modules wget curl \
    python3 python3-pip python3-pandas python2.7 python-pip \
    libsm-dev libx11-dev libxt-dev libxext-dev libglu1-mesa \
  --freesurfer version=6.0.0-min install_path=/opt/freesurfer \
  --run-bash 'pip3 install nibabel pandas==0.21.0' \
  --run-bash 'curl -sL https://deb.nodesource.com/setup_6.x | bash -' \
  --install nodejs \
  --run-bash 'npm install -g bids-validator@0.19.8' \
  --env FSLDIR=/usr/share/fsl/5.0 FSLOUTPUTTYPE=NIFTI_GZ \
        FSLMULTIFILEQUIT=TRUE POSSUMDIR=/usr/share/fsl/5.0 LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
        FSLTCLSH=/usr/bin/tclsh FSLWISH=/usr/bin/wish FSLOUTPUTTYPE=NIFTI_GZ \
  --env OS=Linux FS_OVERRIDE=0 FIX_VERTEX_AREA="" SUBJECTS_DIR=/opt/freesurfer/subjects \
        FSF_OUTPUT_FORMAT=nii.gz MNI_DIR=/opt/freesurfer/mni LOCAL_DIR=/opt/freesurfer/local \
        FREESURFER_HOME=/opt/freesurfer FSFAST_HOME=/opt/freesurfer/fsfast MINC_BIN_DIR=/opt/freesurfer/mni/bin \
        MINC_LIB_DIR=/opt/freesurfer/mni/lib MNI_DATAPATH=/opt/freesurfer/mni/data \
        FMRI_ANALYSIS_DIR=/opt/freesurfer/fsfast PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5 \
        MNI_PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5 \
        PATH=/usr/lib/fsl/5.0:/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/freesurfer/mni/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        PYTHONPATH="" \
  --run 'mkdir /scratch' \
  --run 'mkdir /local-scratch' \
  --copy run.py '/run.py' \
  --run  'chmod +x /run.py' \
  --copy version '/version' \
  --entrypoint '/neurodocker/startup.sh /run.py' \
> Dockerfile


# Generate a singularity recipe for building BIDS-Apps Freesurfer container
docker run --rm ${image} generate singularity \
  --base ubuntu:xenial \
  --pkg-manager apt \
  --install tcsh bc tar libgomp1 perl-modules wget curl \
    python3 python3-pip python3-pandas python2.7 python-pip \
    libsm-dev libx11-dev libxt-dev libxext-dev libglu1-mesa \
  --freesurfer version=6.0.0-min install_path=/opt/freesurfer \
  --run-bash 'pip3 install nibabel pandas==0.21.0' \
  --run-bash 'curl -sL https://deb.nodesource.com/setup_6.x | bash -' \
  --install nodejs \
  --run-bash 'npm install -g bids-validator@0.19.8' \
  --env FSLDIR=/usr/share/fsl/5.0 FSLOUTPUTTYPE=NIFTI_GZ PATH=/usr/lib/fsl/5.0:$PATH \
        FSLMULTIFILEQUIT=TRUE POSSUMDIR=/usr/share/fsl/5.0 LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
        FSLTCLSH=/usr/bin/tclsh FSLWISH=/usr/bin/wish FSLOUTPUTTYPE=NIFTI_GZ \
  --env OS=Linux FS_OVERRIDE=0 FIX_VERTEX_AREA="" SUBJECTS_DIR=/opt/freesurfer/subjects \
        FSF_OUTPUT_FORMAT=nii.gz MNI_DIR=/opt/freesurfer/mni LOCAL_DIR=/opt/freesurfer/local \
        FREESURFER_HOME=/opt/freesurfer FSFAST_HOME=/opt/freesurfer/fsfast MINC_BIN_DIR=/opt/freesurfer/mni/bin \
        MINC_LIB_DIR=/opt/freesurfer/mni/lib MNI_DATAPATH=/opt/freesurfer/mni/data \
        FMRI_ANALYSIS_DIR=/opt/freesurfer/fsfast PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5 \
        MNI_PERL5LIB=/opt/freesurfer/mni/lib/perl5/5.8.5 \
        PATH=/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/freesurfer/mni/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        PYTHONPATH="" \
  --run 'mkdir /scratch' \
  --run 'mkdir /local-scratch' \
  --copy run.py '/run.py' \
  --run  'chmod +x /run.py' \
  --copy version '/version' \
  --entrypoint '/neurodocker/startup.sh /run.py' \
> Singularity
