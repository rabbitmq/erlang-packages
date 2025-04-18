#!/usr/bin/env python3

import sys
import json
import requests
import os
import re
import os.path

project = sys.argv[1]
org_repository = sys.argv[2]

configuration_filename = project + "-rpm-configuration.json"
releases_filename = project + "-releases.json"


if os.path.isfile(configuration_filename) is False:
  configuration_filename = project + "-deb-configuration.json"

with open(configuration_filename, 'r') as f:
  packages = json.load(f)["packages"]

majors = list(map(lambda p: p["major"], packages))

print("Getting latest releases...")
tags0 = requests.get(
        "https://api.github.com/repos/" + org_repository + "/tags",
        params = {'per_page': 100},
        headers = {'X-GitHub-Api-Version' : '2022-11-28', 'Accept' : 'application/vnd.github+json'}
        ).json()

with open(releases_filename, 'r') as f:
  old_latests = json.load(f)

print("Current state (from {}):".format(releases_filename))
print(old_latests)

new_latests = dict()

headers = {
        "Accept": "application/vnd.github.v3+json",
        "Authorization": "token " + os.environ['MK_RELEASE_AUTOMATION_TOKEN']
        }

has_changed = False

def curate_tag(tag):
    return tag.replace("OTP-", "").replace("v", "")

def filter_final_releases(rel):
    if rel.get("name") is None:
        return False
    tag = rel.get("name")
    curated_tag = curate_tag(tag)
    if curated_tag[:1].isdigit() is False:
        return False
    if curated_tag[-1].isdigit() is False:
        return False
    return True

tags = filter(filter_final_releases, tags0)

for tag_data in tags:
    print("Release: {}".format(tag_data))
    tag = tag_data.get("name", None)
    if tag is None:
        pass
    curated_tag = curate_tag(tag)
    for major in majors:
        if (curated_tag.startswith(major)):
            majors.remove(major)
            old_latest = "-1" if major not in old_latests else old_latests[major]
            new_latest = tag
            new_latests[major] = new_latest
            if old_latest != new_latest:
                has_changed = True
                print("New tag detected for major " + major + ": " + new_latest)
                body = {
                        "event_type" : "new_" + project + "_" + major.replace(".", "_") + "_release",
                        "client_payload": { "tag" : new_latest } 
                        }
                print("Sending notification with body:")
                print(body)
                response = requests.post(
                        "https://api.github.com/repos/rabbitmq/erlang-packages/dispatches",
                        json = body,
                        headers = headers)
                if not response.ok:
                    print("Notification failed with status status: {}".format(response.status_code))

if has_changed:
    print("New state:")
    print(str(new_latests))
else:
    print("No changes detected.")

releases_file = open(releases_filename, 'w')
json.dump(new_latests, releases_file)
releases_file.close()

if 'GITHUB_ENV' in os.environ:
    has_changed = "true" if has_changed else "false"
    with open(os.environ['GITHUB_ENV'], 'a') as fh:
        print(f'has_changed={has_changed}', file=fh)
