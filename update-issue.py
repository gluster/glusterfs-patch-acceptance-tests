#!/usr/bin/env python

import argparse
import requests
import os
import json
import subprocess
import re
from github3 import login


def get_commit_message():
    commit = subprocess.check_output(['git', 'log', '--format=%B', '-n', '1'])
    return commit


def get_commit_message_from_gerrit(project, branch, change_id, revision_number):
    k = requests.get('https://review.gluster.org/changes/{}~{}~{}'
                     '/revisions/{}/commit'.
                     format(
                            project,
                            branch,
                            change_id,
                            revision_number
                            )
                     )
    output = k.text
    cleaned_output = '\n'.join(output.split('\n')[1:])
    parsed_output = json.loads(cleaned_output)
    # TODO: check if we got valid data before returning the same?
    return parsed_output.get("message")


def parse_commit_message(msg):
    regex = re.compile(r'(([fF][iI][xX][eE][sS])|([uU][pP][dD][aA][tT][eE][sS])):?\s+(gluster/glusterfs)?#(\d*)')
    issues = []
    for line in msg.split('\n'):
        for match in regex.finditer(line):
            issues.append(unicode(match.group(5)))
    if len(issues):
        print("Issues found in the commit message: {}".format(issues))
        return issues
    print("No issues found in the commit message")
    return issues


def remove_duplicates (project, branch, change_id, revision_number, issues):
    if (int(revision_number) == 1):
        return issues

    oldmessage = get_commit_message_from_gerrit(project, branch, change_id,
                                                str(int(revision_number) - 1))
    oldissues = parse_commit_message(oldmessage)
    print("Old issues: {}".format(oldissues))
    newissues = list(set(issues) - (set(issues) & set(oldissues)))
    return newissues


def comment_on_issues(issues, commit, link, dry_run):
    comment = ("A patch {} has been posted that references this issue.\n"
               "  Commit message: {}".format(link, commit.split('\n')[0]))
    for issue in issues:
        comment_issue(issue, comment, dry_run)


def comment_issue(num, comment, dry_run):
    if dry_run:
        print comment
    else:
        gh_user = os.environ.get('GITHUB_USER')
        gh_pw = os.environ.get('GITHUB_PASS')
        gh = login(gh_user, gh_pw)
        issue = gh.issue('gluster', 'glusterfs', num)
        if issue:
            issue.create_comment(comment)
            print "Updated issue #{}".format(num)
        else:
            print "Issue #{} does not exist".format(num)


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
        # comment on issue: xxx about the review
        comment_on_issues(newissues, commit, link, dry_run)


parser = argparse.ArgumentParser(description='Comment on Github issue')
parser.add_argument(
        '--dry-run', '-d',
        action='store_true',
        help="Do not comment on Github. Print to stdout instead",
)
args = parser.parse_args()
main(args.dry_run)
