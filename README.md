
		$ docker run -ti bids/freesurfer --help
		usage: run.py [-h]
		              [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]]
		              [--first_level_results FIRST_LEVEL_RESULTS]
		              [--template_name TEMPLATE_NAME]
		              bids_dir output_dir

		FreeSurfer recon-all + custom template generation.

		positional arguments:
		  bids_dir              The directory with the input dataset formatted
		                        according to the BIDS standard.
		  output_dir            The directory where the output files should be stored.

		optional arguments:
		  -h, --help            show this help message and exit
		  --participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
		                        label of the participant that should be analyzed. The
		                        label corresponds to sub-<participant_label> from the
		                        BIDS spec (so it does not include "sub-"). If this
		                        parameter is not provided all subjects should be
		                        analyzed. Multiple participants can be specified with
		                        a space separated list.
		  --first_level_results FIRST_LEVEL_RESULTS
		                        (group level only) directory with outputs from a set
		                        of participants which will be used as input to the
		                        group level (this is where first level pipelines store
		                        outputs via output_dir).
		  --template_name TEMPLATE_NAME
		                        Name for the custom group level tempalate generated
		                        for this dataset
