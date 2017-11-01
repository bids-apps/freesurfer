## Freesurfer recon-all BIDS App
### Description
This app implements surface reconstruction using Freesurfer. It reconstructs the surface for each subject individually and then
creates a study specific template. In case there are multiple sessions the Freesurfer longitudinal pipeline is used (creating subject specific templates) unless instructed to combine data across sessions.

The current Freesurfer version is based on: freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz

The output of the pipeline consist of the SUBJECTS_DIR created during the analysis.

### Documentation
 - [Surface reconstruction](https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all)
 - [Study specific template creation](https://surfer.nmr.mgh.harvard.edu/fswiki/SurfaceRegAndTemplates#CreatingaregistrationtemplateinitializedwithFreeSurfertemplate.28DG.29)
 - [Longitudinal pipeline](https://surfer.nmr.mgh.harvard.edu/fswiki/LongitudinalProcessing)

### How to report errors
https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferSupport

### Acknowledgements
https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferMethodsCitation

### Usage
This App has the following command line arguments:


        $ docker run -ti --rm bids/freesurfer --help
        usage: run.py [-h]
                      [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]]
                      [--n_cpus N_CPUS]
                      [--stages {autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon2-pial,autorecon3,autorecon-all,all}
                                [{autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon2-pial,autorecon3,autorecon-all,all} ...]]
                      [--template_name TEMPLATE_NAME] --license_key LICENSE_KEY
                      [--acquisition_label ACQUISITION_LABEL]
                      [--multiple_sessions {longitudinal,multiday}]
                      [--refine_pial {T2,FLAIR,None,T1only}]
                      [--hires_mode {auto,enable,disable}]
                      [--parcellations {aparc,aparc.a2009s} [{aparc,aparc.a2009s} ...]]
                      [--measurements {area,volume,thickness,thicknessstd,meancurv,gauscurv,foldind,curvind}
                                      [{area,volume,thickness,thicknessstd,meancurv,gauscurv,foldind,curvind} ...]]
                      [-v] [--bids_validator_config BIDS_VALIDATOR_CONFIG]
                      [--skip_bids_validator]
                      bids_dir output_dir {participant,group1,group2}
        FreeSurfer recon-all + custom template generation.

        positional arguments:
          bids_dir              The directory with the input dataset formatted
                                according to the BIDS standard.
          output_dir            The directory where the output files should be stored.
                                If you are running group level analysis this folder
                                should be prepopulated with the results of
                                theparticipant level analysis.
          {participant,group1,group2}
                                Level of the analysis that will be performed. Multiple
                                participant level analyses can be run independently
                                (in parallel) using the same output_dir. "goup1"
                                creates study specific group template. "group2 exports
                                group stats tables for cortical parcellation and
                                subcortical segmentation.

        optional arguments:
          -h, --help            show this help message and exit
          --participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
                                The label of the participant that should be analyzed.
                                The label corresponds to sub-<participant_label> from
                                the BIDS spec (so it does not include "sub-"). If this
                                parameter is not provided all subjects should be
                                analyzed. Multiple participants can be specified with
                                a space separated list.
          --n_cpus N_CPUS       Number of CPUs/cores available to use.
          --stages {autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon2-pial,autorecon3,autorecon-all,all}
                                [{autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon2-pial,autorecon3,autorecon-all,all} ...]
                                Autorecon stages to run.
          --template_name TEMPLATE_NAME
                                Name for the custom group level template generated for
                                this dataset
          --license_file LICENSE_FILE
                                Path to FreeSurfer license key file. To obtain it you
								need to register (for free) visit
                                https://surfer.nmr.mgh.harvard.edu/registration.html
          --acquisition_label ACQUISITION_LABEL
                                If the dataset contains multiple T1 weighted images
                                from different acquisitions which one should be used?
                                Corresponds to "acq-<acquisition_label>"
          --multiple_sessions {longitudinal,multiday}
                                For datasets with multiday sessions where you do not
                                want to use the longitudinal pipeline, i.e., sessions
                                were back-to-back, set this to multiday, otherwise
                                sessions with T1w data will be considered independent
                                sessions for longitudinal analysis.
          --refine_pial {T2,FLAIR,None,T1only}
                                If the dataset contains 3D T2 or T2 FLAIR weighted
                                images (~1x1x1), these can be used to refine the pial
                                surface. If you want to ignore these, specify None or
                                T1only to base surfaces on the T1 alone.
          --hires_mode {auto,enable,disable}
                                Submilimiter (high resolution) processing. 'auto' -
                                use only if <1.0mm data detected, 'enable' - force on,
                                'disable' - force off
          --parcellations {aparc,aparc.a2009s} [{aparc,aparc.a2009s} ...]
                                Group2 option: cortical parcellation(s) to extract
                                stats from.
          --measurements {area,volume,thickness,thicknessstd,meancurv,gauscurv,foldind,curvind}
                                [{area,volume,thickness,thicknessstd,meancurv,gauscurv,foldind,curvind} ...]
                                Group2 option: cortical measurements to extract stats for.
          -v, --version         show program's version number and exit
          --bids_validator_config BIDS_VALIDATOR_CONFIG
                                JSON file specifying configuration of bids-validator:
                                See https://github.com/INCF/bids-validator for more
                                info
          --skip_bids_validator
                               skips bids validation


#### Participant level
To run it in participant level mode (for one participant):

		docker run -ti --rm \
		-v /Users/filo/data/ds005:/bids_dataset:ro \
		-v /Users/filo/outputs:/outputs \
		bids/freesurfer \
		/bids_dataset /outputs participant --participant_label 01 \
		--license_file "license.txt"


#### Group level
After doing this for all subjects (potentially in parallel) the
group level analyses can be run.

To create a study specific template run:

		docker run -ti --rm \
		-v /Users/filo/data/ds005:/bids_dataset:ro \
		-v /Users/filo/outputs:/outputs \
		bids/freesurfer \
		/bids_dataset /outputs group1 \
		--license_file "license.txt"

To export tables with aggregated measurements within regions of
cortical parcellation and subcortical segementation run:

		docker run -ti --rm \
		-v /Users/filo/data/ds005:/bids_dataset:ro \
		-v /Users/filo/outputs:/outputs \
		bids/freesurfer \
		/bids_dataset /outputs group2 \
		--license_file "license.txt"
Also see *--parcellations* and *--measurements* arguments.
