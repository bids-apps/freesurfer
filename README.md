## Freesurfer recon-all BIDS App
### Description
This app implements surface reconstruction using Freesurfer. It reconstruct the surface for each subject individually and then
creates a study specific template. In case there are multiple sessions the Freesurfer longitudinal pipeline is used (creating subject specific templates).

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
This App has the following comman line arguments:

		$ docker run -ti bids/freesurfer --help
		usage: run.py [-h]
		              [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]]
		              [--template_name TEMPLATE_NAME]
		              bids_dir output_dir {participant,group}

		FreeSurfer recon-all + custom template generation.

		positional arguments:
		  bids_dir              The directory with the input dataset formatted
		                        according to the BIDS standard.
		  output_dir            The directory where the output files should be stored.
		                        If you are running group level analysis this folder
		                        should be prepopulated with the results of
		                        theparticipant level analysis.
		  {participant,group}   Level of the analysis that will be performed. Multiple
		                        participant level analyses can be run independently
		                        (in parallel) using the same output_dir.

		optional arguments:
		  -h, --help            show this help message and exit
		  --participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
		                        The label of the participant that should be analyzed.
		                        The label corresponds to sub-<participant_label> from
		                        the BIDS spec (so it does not include "sub-"). If this
		                        parameter is not provided all subjects should be
		                        analyzed. Multiple participants can be specified with
		                        a space separated list.
		  --template_name TEMPLATE_NAME
		                        Name for the custom group level template generated
		                        for this dataset

To run it in participant level mode (for one participant):

    docker run -i --rm \
		-v /Users/filo/data/ds005:/bids_dataset \
		-v /Users/filo/outputs:/outputs \
		bids/freesurfer \
		/bids_dataset /outputs participant --participant_label 01

After doing this for all subjects (potentially in parallel) the group level analysis
can be run:

    docker run -i --rm \
		-v /Users/filo/data/ds005:/bids_dataset \
		-v /Users/filo/outputs:/outputs \
		bids/freesurfer \
		/bids_dataset /outputs group
