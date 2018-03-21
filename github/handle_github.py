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


class CommitHandler(object):
    '''
    This class fetches and handles commit-related information from Gerrit and
    parses it for use later in the code
    '''

    def __init__(self, repo):
        self.project = os.environ.get('GERRIT_PROJECT')
        self.branch = os.environ.get('GERRIT_BRANCH')
        self.change_id = os.environ.get('GERRIT_CHANGE_ID')
        self.revision_number = os.environ.get('GERRIT_PATCHSET_NUMBER')
        self.repo = repo

    def get_commit_message_from_gerrit(self):
        '''
        Use the Gerrit API to get the commit message at any revision

        :return: The commit message string
        :rtype: str
        '''
        k = requests.get('https://review.gluster.org/changes/{}~{}~{}'
                         '/revisions/{}/commit'.
                         format(
                             self.project,
                             self.branch,
                             self.change_id,
                             str(int(self.revision_number) - 1)
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

    def remove_duplicates(self, issues):
        '''
        Remove duplicate bugs between the bugs in the current commit message and
        the previous commit message. A comment is added to the issue in 3 cases:
        * The first revision of a review has issue number.
        * A later review changed the issue number, in which case both issues will
          get a commit.
        * A later review added an issue number.

        :param list(int) issues: The issues in the latest commit revision
        :param str repo: The repo the to look for the issue
        '''

        if int(self.revision_number) == 1:
            return issues

        oldmessage = self.get_commit_message_from_gerrit()
        oldissues = self.parse_commit_message(oldmessage)
        print("Old issues: {}".format(oldissues))
        newissues = list(set(issues) - (set(issues) & set(oldissues)))
        return newissues

    def parse_commit_message(self, msg):
        '''
        Parse the commit message and look for issues in the commit message

        :param str msg: The commit message to parse
        :return: A list of issues
        :rtype: list(int)
        '''
        regex = re.compile(''.join([r'(([fF][iI][xX][eE][sS])|',
                                    r'([uU][pP][dD][aA][tT][eE]',
                                    r'[sS])):?\s+(gluster/',
                                    self.repo,
                                    r')?#(\d*)']))
        issues = []
        for line in msg.split('\n'):
            for match in regex.finditer(line):
                issue = match.group(5)
                if int(issue) >= 743000:
                    continue
                issues.append(issue)
        if issues:
            print("Issues found in the commit message: {}".format(issues))
            return issues
        print("No issues found in the commit message")
        return issues


class GitHubHandler(object):
    '''
    This class handles all the Github interactions
    '''

    def __init__(self, repo, dry_run):
        self.repo = repo
        self.dry_run = dry_run
        self.link = os.environ.get('GERRIT_CHANGE_URL')
        self._github_login()

    def _github_login(self):
        gh_user = os.environ.get('GITHUB_USER')
        gh_pw = os.environ.get('GITHUB_PASS')
        self.ghub = login(gh_user, gh_pw)

    def comment_on_issues(self, issues, commit):
        '''
        Comment on multiple issues

        :param list(int) issues: List of issues to comment on
        '''
        comment = ("A patch {} has been posted that references this issue.\n"
                   "Commit message: {}".format(self.link, commit.split('\n')[0]))
        for issue in issues:
            self._comment_on_issue(issue, comment)

    def _comment_on_issue(self, num, comment):
        '''
        Comment on a provided issue number with the provided comment

        :param int num: The issue number to comment on
        :param str comment: The content of the comment

        '''
        if self.dry_run:
            print(comment)
        else:
            issue = self.ghub.issue('gluster', self.repo, num)
            if issue:
                issue.create_comment(comment)
                print("Updated issue #{}".format(num))
            else:
                print("Issue #{} does not exist".format(num))


    def check_issue(self, num):
        '''
        Verify that there is an issue with the given number and it has the
        SpecApproved and DocApproved labels.

        :param int num: The issue number
        '''
        issue = self.ghub.issue('gluster', self.repo, num)
        if issue:
            spec_approved = False
            doc_approved = False
            for label in issue.labels:
                if label == "SpecApproved":
                    spec_approved = True
                if label == "DocApproved":
                    doc_approved = True
            if not spec_approved:
                print("Missing SpecApproved flag on Issue {}".format(num))
            if not doc_approved:
                print("Missing DocApproved flag on Issue {}".format(num))
            if spec_approved and doc_approved:
                print("All approvals in place")
                return True
            return False
        print("Issue #{} does not exist in {} repo".format(num, self.repo))
        return False



def main(repo, dry_run):
    '''
    The main function for this program. The actual program execution happens
    here
    '''
    github = GitHubHandler(repo, dry_run)
    commit = CommitHandler(repo)
    # get commit message
    commit_msg = get_commit_message()

    # check if updates/fixes: xxx appears in the commit
    issues = commit.parse_commit_message(commit_msg)
    issue_check_success = 0

    if issues:
        # remove duplicates from previous commit message (if any)
        newissues = commit.remove_duplicates(issues)
        # comment on issue: xxx about the review
        for issue in newissues:
            # comment on issue: xxx about the review
            if github.check_issue(issue):
                github.comment_on_issues(newissues, commit)
                continue
            issue_check_success = 1
    exit(issue_check_success)


if __name__ == '__main__':
    PARSER = argparse.ArgumentParser(description='Comment on Github issue')
    PARSER.add_argument(
        '--dry-run', '-d',
        action='store_true',
        help="Do not comment on Github. Print to stdout instead",
    )
    PARSER.add_argument(
        '--repo', '-r',
        action='store',
        help="The repo to check for issues or add comments to",
    )
    ARGS = PARSER.parse_args()
    main(ARGS.repo, ARGS.dry_run)
