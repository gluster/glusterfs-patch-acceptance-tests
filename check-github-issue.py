#!/usr/bin/env python

import argparse
import requests
import os
import json
import subprocess
import re
from github3 import login


def main(dry_run):
    project = os.environ.get('GERRIT_PROJECT')
    branch = os.environ.get('GERRIT_BRANCH')
    change_id = os.environ.get('GERRIT_CHANGE_ID')
    revision_number = os.environ.get('GERRIT_PATCHSET_NUMBER')
    link = os.environ.get('GERRIT_CHANGE_URL')

    # get commit message
    commit = get_commit_message()

    # check if updates/fixes: xxx appears in the commit
    issues = parse_commit_message(commit)

    if issues:
        # remove duplicates from previous commit message (if any)
        newissues = remove_duplicates(project, branch, change_id, revision_number,
                                      issues)
        for issue in newissues:
            # comment on issue: xxx about the review
            check_issue(issue, commit, dry_run)


parser = argparse.ArgumentParser(description='Comment on Github issue')
parser.add_argument(
        '--dry-run', '-d',
        action='store_true',
        help="Do not comment on Github. Print to stdout instead",
)
args = parser.parse_args()
main(args.dry_run)
