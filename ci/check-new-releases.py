#!/bin/python

import sys
import json
import requests
import os

project = sys.argv[1]
org_repository = sys.argv[2]

configuration_filename = project + "-configuration.json"
releases_filename = project + "-releases.json"

with open(configuration_filename, 'r') as f:
  packages = json.load(f)["packages"]

majors = list(map(lambda p: p["major"], packages))

print("Getting latest releases...")
releases = requests.get(
        "https://api.github.com/repos/" + org_repository + "/releases",
        headers = {'X-GitHub-Api-Version' : '2022-11-28', 'Accept' : 'application/vnd.github+json'}
        ).json()

with open(releases_filename, 'r') as f:
  old_latests = json.load(f)

print("Current state:")
print(old_latests)

new_latests = dict()

headers = {
        "Accept": "application/vnd.github.v3+json",
        "Authorization": "token " + os.environ['CI_GITHUB_TOKEN']
        }

has_changed = False

for release in releases:
    tag = release["tag_name"]
    curated_tag = tag.replace("OTP-", "").replace("v", "")
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
                        "event_type" : "new_" + project + "_" + major,
                        "client_payload": { "tag" : new_latest } 
                        }
                print("Sending notification with body:")
                print(body)
                response = requests.post(
                        "https://api.github.com/repos/rabbitmq/erlang-packages/dispatches",
                        json = body,
                        headers = headers)
                if not response.ok:
                    print("Notification failed with status status: " + response.status_code)

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
