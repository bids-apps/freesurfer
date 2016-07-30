#!/usr/bin/env python3
import argparse
import os
import nibabel
import numpy
from glob import glob
from subprocess import Popen, PIPE
from shutil import rmtree
import subprocess

def run(command, env={}):
	process = Popen(command, stdout=PIPE, stderr=subprocess.STDOUT, shell=True, env=env)
	while True:
		line = process.stdout.readline()
		line = str(line, 'utf-8')[:-1]
		print(line)
		if line == '' and process.poll() != None:
			break

parser = argparse.ArgumentParser(description='FreeSurfer recon-all + custom template generation.')
parser.add_argument('bids_dir', help='The directory with the input dataset '
					'formatted according to the BIDS standard.')
parser.add_argument('output_dir', help='The directory where the output files '
					'should be stored.')
parser.add_argument('--participant_label', help='The label of the participant that should be analyzed. The label '
				   'corresponds to sub-<participant_label> from the BIDS spec '
				   '(so it does not include "sub-"). If this parameter is not '
				   'provided all subjects should be analyzed. Multiple '
				   'participants can be specified with a space separated list.',
				   nargs="+")
parser.add_argument('--first_level_results', help='(group level only) directory with the outputs '
					'from a set of participants which will be used as input to '
					'the group level (this is where first level pipelines store '
					'outputs via output_dir).')
parser.add_argument('--template_name', help='Name for the custom group level tempalate generated for this dataset',
					default="newtemplate")

args = parser.parse_args()

subjects_to_analyze = []
# only for a subset of subjects
if args.participant_label:
	subjects_to_analyze = args.participant_label
# for all subjects
else:
	subject_dirs = glob(os.path.join(args.bids_dir, "sub-*"))
	subjects_to_analyze = [subject_dir.split("-")[-1] for subject_dir in subject_dirs]

# running first level
if not args.first_level_results:
	# find all T1s and skullstrip them
	for subject_label in subjects_to_analyze:
		# grab all T1s from all sessions
		input_args = " ".join(["-i %s"%f for f in glob(os.path.join(args.bids_dir,"sub-%s"%subject_label,"anat", "*_T1w.nii*")) + glob(os.path.join(args.bids_dir,"sub-%s"%subject_label,"ses-*","anat", "*_T1w.nii*"))])
		cmd = "recon-all -subjid %s -sd %s %s -all"%(subject_label,
												 args.output_dir,
												 input_args)
		print(cmd)
		if os.path.exists(os.path.join(args.output_dir, subject_label)):
			rmtree(os.path.join(args.output_dir, subject_label))
		run(cmd)
else:
	# running group level
	# FreeSurfer is used to do things in place so we need to copy the relevant files to their final destination
	# we do this before generating the template in caset first_level_results folder is read only
	for subject_label in subjects_to_analyze:
		copytree(os.path.join(args.first_level_results, subject_label), args.output_dir)

	# generate study specific template
	cmd = "make_average_subject --out " + args.template_name + " --subjects " + " ".join(subjects_to_analyze)
	print(cmd)
	run(cmd, env={"SUBJECTS_DIR": args.output_dir})
	tif_file = os.path.join(args.output_dir, args.template_name, hemi+".reg.template.tif")
	for subject_label in subjects_to_analyze:
		for hemi in ["lh", "rh"]:
			sphere_file = os.path.join(args.output_dir, subject_label, "surf", hemi+".sphere")
			reg_file = os.path.join(args.output_dir, subject_label, "surf", hemi+".sphere.reg." + args.template_name)
			cmd = "mris_register -curv %s %s %s"%(sphere_file, tif_file, reg_file)
			run(cmd, env={"SUBJECTS_DIR": args.output_dir})
