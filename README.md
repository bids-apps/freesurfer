
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
