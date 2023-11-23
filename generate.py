#!/usr/bin/python3

distributions = [
        ["debian", "buster", "buster"],
        ["debian", "bullseye", "bullseye"],
        ["debian", "bookworm", "bookworm"],
        ["debian", "trixie", "trixie"],
        ["ubuntu", "bionic", "18.04"],
        ["ubuntu", "focal", "20.04"],
        ["ubuntu", "jammy", "22.04"],
        ]

packages = [
        ["24", ["buster", "bullseye", "bionic", "focal", "jammy"]],
        ["25", ["buster", "bullseye", "bookworm", "trixie", "bionic", "focal", "jammy"]],
        ["26", ["buster", "bullseye", "bookworm", "trixie", "focal", "jammy"]]
        ]

import glob
import os

generated_directory = "generated"
if os.path.exists(generated_directory):
    os.system("rm -rf " + generated_directory)

os.mkdir(generated_directory)

reusable_workflow_template_file = open("erlang-debian-package.template.yml", "r")
reusable_workflow_template = reusable_workflow_template_file.read()
reusable_workflow_template_file.close()

ubuntu_distributions = filter(lambda distribution: distribution[0] == "ubuntu", distributions)
ubuntu_versions = " ".join(map(lambda distribution: distribution[2], ubuntu_distributions))

reusable_workflow = reusable_workflow_template.replace("§ubuntu_versions§", ubuntu_versions)

reusable_workflow_file = open(os.path.join(generated_directory, "gen-erlang-debian-package.yml"), "w") 
reusable_workflow_file.write(reusable_workflow)
reusable_workflow_file.close() 

workflow_template_file = open("erlang-distribution-debian.template.yml", "r")
workflow_template = workflow_template_file.read()
workflow_template_file.close()

for package in packages:
    major_version = package[0]
    supported_distributions = package[1]
    for distribution in distributions:
        distribution_name = distribution[0]
        distribution_codename = distribution[1]
        distribution_version = distribution[2]
        distribution_label = distribution_name.capitalize() + " " + distribution_version.capitalize()
        workflow = workflow_template
        if distribution_codename in supported_distributions:
            workflow = workflow\
                .replace("§erlang_major§", major_version)\
                .replace("§distribution_label§", distribution_label)\
                .replace("§distribution_name§", distribution_name)\
                .replace("§distribution_codename§", distribution_codename)\
                .replace("§distribution_version§", distribution_version)
            workflow_file = open(os.path.join(generated_directory, "gen-erlang-" + major_version + "-" + distribution_name + "-" + distribution_version + ".yml"), "w") 
            workflow_file.write(workflow)
            workflow_file.close() 
         
workflow_directory = ".github/workflows"
os.system("rm -f " + workflow_directory + "/gen-*.yml")
os.system("cp " + generated_directory + "/* " + workflow_directory)
os.system("rm -rf " + generated_directory)


