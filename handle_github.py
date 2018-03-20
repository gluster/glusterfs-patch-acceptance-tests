#!/usr/bin/env python
'''
This small program should be able to verify that github issues are specified in
every commit and comment on them when there is an updated patch
'''


from __future__ import absolute_import, print_function, unicode_literals
import argparse
import os
import json
import subprocess
import re
import requests
from github3 import login


def get_commit_message():
    '''
    Run the git command line to get the commit message from the git repo in the
    current directory
    '''
    commit = subprocess.check_output(['git', 'log', '--format=%B', '-n', '1'])
    return commit


def get_commit_message_from_gerrit(project, branch, change_id, revision_number):
    '''
    Use the Gerrit API to get the commit message at any revision

    :param str project: Gerrit project name
    :param str branch: Branch name on Gerrit
    :param str change_id: Change-Id on Gerrit
    :param int revision_number: The revision number for the change on Gerrit
    :return: The commit message string
    :rtype: str
    '''
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
    try:
        parsed_output = json.loads(cleaned_output)
    except ValueError as exception:
        print(exception)
        raise Exception('Could not parse Gerrit API output')
    return parsed_output.get("message")


def parse_commit_message(msg):
    '''
    Parse the commit message and look for issues in the commit message

    :param str msg: The commit message to parse
    :return: A list of issues
    :rtype: list(int)
    '''
    regex = re.compile(r'(([fF][iI][xX][eE][sS])|([uU][pP][dD][aA][tT][eE]'
                       r'[sS])):?\s+(gluster/glusterfs)?#(\d*)')
    issues = []
    for line in msg.split('\n'):
        for match in regex.finditer(line):
            issue = match.group(5)
            if int(issue) >= 743000:
                continue
            issues.append(issue)
    if issues > 0:
        print("Issues found in the commit message: {}".format(issues))
        return issues
    print("No issues found in the commit message")
    return issues


def remove_duplicates(project, branch, change_id, revision_number, issues):
    '''
    Remove duplicate bugs between the bugs in the current commit message and
    the previous commit message. A comment is added to the issue in 3 cases:
    * The first revision of a review has issue number.
    * A later review changed the issue number, in which case both issues will
      get a commit.
    * A later review added an issue number.

    :param str project: The project name on Gerrit
    :param str branch: The branch name on Gerrit
    :param str change_id: The Change-Id for the review
    :param int revision_number: The revision number for the current change
    :param list(int) issues: The issues in the latest commit revision
    '''

    if int(revision_number) == 1:
        return issues

    oldmessage = get_commit_message_from_gerrit(project, branch, change_id,
                                                str(int(revision_number) - 1))
    oldissues = parse_commit_message(oldmessage)
    print("Old issues: {}".format(oldissues))
    newissues = list(set(issues) - (set(issues) & set(oldissues)))
    return newissues


def comment_on_issues(issues, commit, link, dry_run):
    '''
    Comment on multiple issues

    :param list(int) issues: List of issues to comment on
    :param str commit: The commit message for the review
    :param str link: A link to the review
    :param boolean dry_run: When dry run is true, the actions are not executed
    '''
    comment = ("A patch {} has been posted that references this issue.\n"
               "  Commit message: {}".format(link, commit.split('\n')[0]))
    for issue in issues:
        comment_issue(issue, comment, dry_run)


def check_issue(num):
    '''
    Verify that there is an issue with the given number and it has the
    SpecApproved and DocApproved labels.

    :param int num: The issue number
    '''
    gh_user = os.environ.get('GITHUB_USER')
    gh_pw = os.environ.get('GITHUB_PASS')
    ghub = login(gh_user, gh_pw)
    issue = ghub.issue('gluster', 'glusterfs', num)
    if issue:
        spec_approved = False
        doc_approved = False
        for label in issue.labels:
            if label == "SpecApproved":
                spec_approved = True
            if label == "DocApproved":
                doc_approved = True
        if spec_approved and doc_approved:
            print("All approvals in place")
            return 0
        print("Missing the required approvals")
        return 1
    print("Issue #{} does not exist".format(num))
    print("FAIL")
    return 1


def comment_issue(num, comment, dry_run):
    '''
    Comment on a provided issue number with the provided comment

    :param int num: The issue number to comment on
    :param str comment: The content of the comment
    :param boolean dry_run: When dry run is true, the actions are not executed

    '''
    if dry_run:
        print(comment)
    else:
        gh_user = os.environ.get('GITHUB_USER')
        gh_pw = os.environ.get('GITHUB_PASS')
        ghub = login(gh_user, gh_pw)
        issue = ghub.issue('gluster', 'glusterfs', num)
        if issue:
            issue.create_comment(comment)
            print("Updated issue #{}".format(num))
        else:
            print("Issue #{} does not exist".format(num))


def main(dry_run):
    '''
    The main function for this program. The actual program execution happens
    here
    '''
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
        for issue in newissues:
            # comment on issue: xxx about the review
            check_issue(issue)
            comment_on_issues(newissues, commit, link, dry_run)


if __name__ == '__main__':
    PARSER = argparse.ArgumentParser(description='Comment on Github issue')
    PARSER.add_argument(
        '--dry-run', '-d',
        action='store_true',
        help="Do not comment on Github. Print to stdout instead",
    )
    ARGS = PARSER.parse_args()
    main(ARGS.dry_run)
