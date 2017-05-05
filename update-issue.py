#!/usr/bin/env python

import argparse
import requests
import os
import json
import subprocess
import re
from github3 import login


def commit_message_edited(project, branch, change_id, revision_id):
    r = requests.get('https://review.gluster.org/changes/{}~{}~{}'
                     '/revisions/{}/files/'.format(
                         project,
                         branch,
                         change_id,
                         revision_id,
                    )
    )
    output = r.text
    cleaned_output = '\n'.join(output.split('\n')[1:])
    parsed_output = json.loads(cleaned_output)
    if '/COMMIT_MSG' in parsed_output:
        return True
    return False


def get_commit_message():
    commit = subprocess.check_output(['git', 'log', '--format=%B', '-n', '1'])
    return commit


def parse_commit_message(msg):
    regex = re.compile(
            r'((fixes)|(updates)):\s*(gluster/glusterfs)?#(\d*)',
            re.I
    )
    bugs = []
    for line in msg.split('\n'):
        if (line.lower().startswith('fixes') or
                line.lower().startswith('updates')):
            bugs.append(regex.match(line).group(5))
    return bugs


def comment_on_issues(issues, commit, link, dry_run):
    comment = ("This patch will update or fix this issue: {}\n"
               "Commit Message: {}".format(link, commit.split('\n')[0]))
    for issue in issues:
        comment_issue(issue, comment, dry_run)


def comment_issue(num, comment, dry_run):
    if dry_run:
        print comment
    else:
        gh_user = os.environ.get('GITHUB_USER')
        gh_pw = os.environ.get('GITHUB_PASS')
        gh = login(gh_user, gh_pw)
        issue = gh.issue('gluster', 'test', num)
        if issue:
            issue.create_comment(comment)
            print "Updated issue #{}".format(num)
        else:
            print "Issue #{} does not exist".format(num)


def main(dry_run, force):
    project = os.environ.get('GERRIT_PROJECT')
    branch = os.environ.get('GERRIT_BRANCH')
    change_id = os.environ.get('GERRIT_CHANGE_ID')
    revision_id = os.environ.get('GERRIT_PATCHSET_REVISION')
    link = os.environ.get('GERRIT_CHANGE_URL')

    if not force:
        check = commit_message_edited(project, branch, change_id, revision_id)
        if not check:
            return

    # get commit message
    commit = get_commit_message()

    # check if updates/fixes: xxx appears in the commit
    issues = parse_commit_message(commit)

    # comment on bug: xxx about the review
    comment_on_issues(issues, commit, link, dry_run)


parser = argparse.ArgumentParser(description='Comment on Github issue')
parser.add_argument(
        '--dry-run', '-d',
        action='store_true',
        help="Do not comment on Github. Print to stdout instead",
)
parser.add_argument(
        '--force', '-f',
        action='store_true',
        help="Comment on the issue without checking if the commit is modified",
)
args = parser.parse_args()
main(args.dry_run, args.force)
