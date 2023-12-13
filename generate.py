#!/usr/bin/python3

import sys
import os
import json

project = sys.argv[1]
package_type = sys.argv[2]

configuration_filename = f"{project}-{package_type}-configuration.json"

with open(configuration_filename, 'r') as f:
  configuration = json.load(f)

distributions = configuration["distributions"]
packages = configuration["packages"]

generated_directory = "generated"
if os.path.exists(generated_directory):
    os.system("rm -rf " + generated_directory)

os.mkdir(generated_directory)

reusable_workflow_template_file = open(os.path.join("templates", project, package_type, "reusable-workflow.yml"), "r")
reusable_workflow_template = reusable_workflow_template_file.read()
reusable_workflow_template_file.close()


ubuntu_distributions = filter(lambda distribution: distribution["name"] == "ubuntu", distributions)
ubuntu_versions = " ".join(map(lambda distribution: distribution["version"], ubuntu_distributions))

reusable_workflow = reusable_workflow_template.replace("§ubuntu_versions§", ubuntu_versions)

reusable_worflow_filename = f"gen-{package_type}-{project}-reusable-workflow.yml"
reusable_workflow_file = open(os.path.join(generated_directory, reusable_worflow_filename), "w") 
reusable_workflow_file.write(reusable_workflow)
reusable_workflow_file.close() 

workflow_template_file = open(os.path.join("templates", project, package_type, "workflow.yml"), "r")
workflow_template = workflow_template_file.read()
workflow_template_file.close()

for package in packages:
    major_version = package["major"]
    major_label = major_version.replace(".", "_")
    supported_distributions = package["distributions"]
    ppa_repository = package.get("ppa_repository", "")
    for distribution in distributions:
        distribution_name = distribution["name"]
        distribution_codename = distribution["codename"]
        distribution_version = distribution["version"]
        distribution_label = distribution_name.capitalize() + " " + distribution_version.capitalize()
        workflow = workflow_template
        if distribution_codename in supported_distributions:
            workflow = workflow\
                .replace("§project§", project)\
                .replace("§major§", major_version)\
                .replace("§major_label§", major_label)\
                .replace("§distribution_label§", distribution_label)\
                .replace("§distribution_name§", distribution_name)\
                .replace("§distribution_codename§", distribution_codename)\
                .replace("§distribution_version§", distribution_version)\
                .replace("§ppa_repository§", ppa_repository)
            workflow_filename = f"gen-{package_type}-{project}-{major_version}-{distribution_name}-{distribution_version}.yml"
            workflow_file = open(os.path.join(generated_directory, workflow_filename), "w") 
            workflow_file.write(workflow)
            workflow_file.close() 
         
workflow_directory = ".github/workflows"
os.system(f"rm -f {workflow_directory}/gen-{package_type}-{project}-*.yml")
os.system("cp " + generated_directory + "/* " + workflow_directory)
os.system("rm -rf " + generated_directory)


