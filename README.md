## Freesurfer recon-all BIDS App

### Description
This app implements surface reconstruction using Freesurfer. It reconstructs the surface for each subject individually and then
creates a study specific template. In case there are multiple sessions the Freesurfer longitudinal pipeline is used (creating subject specific templates) unless instructed to combine data across sessions. This app is available for both Freesurfer 6 and 7. 

The current Freesurfer version for Freesurfer 6 is based on: freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.1.tar.gz  
The current Freesurfer version for Freesurfer 7 is based on: freesurfer-linux-centos7_x86_64-7.4.1.tar.gz

We only plan to support ove version of Freesurfer 6 and Freesurfer 7 at a time.

The output of the pipeline consist of the SUBJECTS_DIR created during the analysis.

### How to get it

Freesurfer 6 will remain the default image till 2024, at which point Freesurfer 7 will become the default.

You can get the default version with `docker pull bids/freesurfer`.  

Freesurfer 7 is available at `docker pull bids/freesurfer:7`.  

Freesurfer 6 is available at `docker pull bids/freesurfer:6`.  

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
                      [--session_label SESSION_LABEL [SESSION_LABEL ...]]
                      [--n_cpus N_CPUS]
                      [--stages {autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon-pial,autorecon3,autorecon-all,all}
                                [{autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon-pial,autorecon3,autorecon-all,all} ...]]
                      [--steps {cross-sectional,template,longitudinal}
                               [{cross-sectional,template,longitudinal} ...]]
                      [--template_name TEMPLATE_NAME] --license_file LICENSE_FILE
                      [--acquisition_label ACQUISITION_LABEL]
                      [--refine_pial_acquisition_label REFINE_PIAL_ACQUISITION_LABEL]
                      [--multiple_sessions {longitudinal,multiday}]
                      [--refine_pial {T2,FLAIR,None,T1only}]
                      [--hires_mode {auto,enable,disable}]
                      [--parcellations {aparc,aparc.a2009s} [{aparc,aparc.a2009s} ...]]
                      [--measurements {area,volume,thickness,thicknessstd,meancurv,gauscurv,foldind,curvind}
                                      [{area,volume,thickness,thicknessstd,meancurv,gauscurv,foldind,curvind} ...]]
                      [-v] [--bids_validator_config BIDS_VALIDATOR_CONFIG]
                      [--skip_bids_validator] [--3T {true,false}]
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
                                (in parallel) using the same output_dir. "group1"
                                creates study specific group template. "group2"
                                exports group stats tables for cortical parcellation,
                                subcortical segmentation a table with euler numbers.

        optional arguments:
          -h, --help            show this help message and exit
          --participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
                                The label of the participant that should be analyzed.
                                The label corresponds to sub-<participant_label> from
                                the BIDS spec (so it does not include "sub-"). If this
                                parameter is not provided all subjects should be
                                analyzed. Multiple participants can be specified with
                                a space separated list.
          --session_label SESSION_LABEL [SESSION_LABEL ...]
                                The label of the session that should be analyzed. The
                                label corresponds to ses-<session_label> from the BIDS
                                spec (so it does not include "ses-"). If this
                                parameter is not provided all sessions should be
                                analyzed. Multiple sessions can be specified with a
                                space separated list.
          --n_cpus N_CPUS       Number of CPUs/cores available to use.
          --stages {autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon-pial,autorecon3,autorecon-all,all}
                                [{autorecon1,autorecon2,autorecon2-cp,autorecon2-wm,autorecon-pial,autorecon3,autorecon-all,all} ...]
                                Autorecon stages to run.
          --steps {cross-sectional,template,longitudinal} [{cross-sectional,template,longitudinal} ...]
                                Longitudinal pipeline steps to run.
          --template_name TEMPLATE_NAME
                                Name for the custom group level template generated for
                                this dataset
          --license_file LICENSE_FILE
                                Path to FreeSurfer license key file. To obtain it you
                                need to register (for free) at
                                https://surfer.nmr.mgh.harvard.edu/registration.html
          --acquisition_label ACQUISITION_LABEL
                                If the dataset contains multiple T1 weighted images
                                from different acquisitions which one should be used?
                                Corresponds to "acq-<acquisition_label>"
          --refine_pial_acquisition_label REFINE_PIAL_ACQUISITION_LABEL
                                If the dataset contains multiple T2 or FLAIR weighted
                                images from different acquisitions which one should be
                                used? Corresponds to "acq-<acquisition_label>"
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
                                Group2 option: cortical measurements to extract stats
                                for.
          -v, --version         show program's version number and exit
          --bids_validator_config BIDS_VALIDATOR_CONFIG
                                JSON file specifying configuration of bids-validator:
                                See https://github.com/INCF/bids-validator for more
                                info
          --skip_bids_validator
                                skips bids validation
	  --3T {true,false}     enables the two 3T specific options that recon-all
	  			supports: nu intensity correction params, and the
				special schwartz atlas

#### Participant level
To run it in participant level mode (for one participant):

		docker run -ti --rm \
		-v /Users/filo/data/ds005:/bids_dataset:ro \
		-v /Users/filo/outputs:/outputs \
		-v /Users/filo/freesurfer_license.txt:/license.txt \
		bids/freesurfer \
		/bids_dataset /outputs participant --participant_label 01 \
		--license_file "/license.txt"


#### Group level
After doing this for all subjects (potentially in parallel) the
group level analyses can be run.

##### Template creation
To create a study specific template run:

		docker run -ti --rm \
		-v /Users/filo/data/ds005:/bids_dataset:ro \
		-v /Users/filo/outputs:/outputs \
		-v /Users/filo/freesurfer_license.txt:/license.txt \
		bids/freesurfer \
		/bids_dataset /outputs group1 \
		--license_file "/license.txt"

##### Stats and quality tables export
To export tables with aggregated measurements within regions of
cortical parcellation and subcortical segementation, and a table with
 euler numbers (a quality metric, see
 [Rosen et. al, 2017](https://www.biorxiv.org/content/early/2017/10/01/125161))
 run:

		docker run -ti --rm \
		-v /Users/filo/data/ds005:/bids_dataset:ro \
		-v /Users/filo/outputs:/outputs \
		-v /Users/filo/freesurfer_license.txt:/license.txt \
		bids/freesurfer \
		/bids_dataset /outputs group2 \
		--license_file "/license.txt"
Also see the *--parcellations* and *--measurements* arguments.

This step writes ouput into `<output_dir>/00_group2_stats_tables/`. E.g.:

* `lh.aparc.thickness.tsv` contains cortical thickness values for the
left hemisphere extracted via the aparac parcellation.
* `aseg.tsv` contains subcortical information from the aseg segmentation.
* `euler.tsv` contains the euler numbers
