#!/bin/python

import json
import requests
import os

with open('configuration.json', 'r') as f:
  packages = json.load(f)["packages"]

erlang_majors = list(map(lambda p: p["major"], packages))

print("Getting latest Erlang releases...")
releases = requests.get(
        'https://api.github.com/repos/erlang/otp/releases',
        headers = {'X-GitHub-Api-Version' : '2022-11-28', 'Accept' : 'application/vnd.github+json'}
        ).json()

latests_filename = 'latests.json'
with open(latests_filename, 'r') as f:
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
    major = tag.replace("OTP-", "").split(".")[0]
    if major in erlang_majors:
        erlang_majors.remove(major)
        old_latest = "-1" if major not in old_latests else old_latests[major]
        new_latest = tag
        new_latests[major] = new_latest
        if old_latest != new_latest:
            has_changed = True
            print("New tag detected for Erlang " + major + ": " + new_latest)
            body = {
                    "event_type" : "new_erlang_" + major,
                    "client_payload": { "tag" : new_latest } 
                    }
            print("Sending notification with body:")
            print(body)
            # response = requests.post(
            #         "https://api.github.com/repos/rabbitmq/erlang-packages/dispatches",
            #         json = body,
            #         headers = headers)
            # if not response.ok:
            #     print("Notification failed with status status: " + response.status_code)

if has_changed:
    print("New state:")
    print(str(new_latests))
else:
    print("No changes detected.")

latests_file = open(latests_filename, 'w')
json.dump(new_latests, latests_file)
latests_file.close()

if 'GITHUB_ENV' in os.environ:
    has_changed = "true" if has_changed else "false"
    with open(os.environ['GITHUB_ENV'], 'a') as fh:
        print(f'has_changed={has_changed}', file=fh)
