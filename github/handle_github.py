#!/usr/bin/env python
# encoding: utf-8
'''
This small program should be able to verify that github issues are specified in
every commit and comment on them when there is an updated patch
'''

from __future__ import unicode_literals, absolute_import, print_function
import argparse
import os
import sys
from github3 import login
from commit import CommitHandler, get_commit_message


class GitHubHandler(object):
    '''
    This class handles all the Github interactions
    '''

    def __init__(self, repo, dry_run, comment_file=False):
        self.repo = repo
        self.dry_run = dry_run
        self.link = os.environ.get('GERRIT_CHANGE_URL')
        self.branch = os.environ.get('GERRIT_BRANCH')
        self.comment_file = comment_file
        self.error_string = []
        if not dry_run:
            self._github_login()

    def _github_login(self):
        gh_user = os.environ.get('GITHUB_USER')
        gh_pw = os.environ.get('GITHUB_PASS')
        self.ghub = login(gh_user, gh_pw)
        if not self.ghub:
            raise Exception('Github Authentication Error')

    def comment_on_issues(self, issues, commit):
        '''
        Comment on multiple issues

        :param list(int) issues: List of issues to comment on
        '''
        comment = ("A patch {} has been posted that references this issue.\n\n"
                   "{}".format(self.link, commit))
        for issue in issues:
            self._comment_on_issue(issue['id'], comment)

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
            if self.branch == 'experimental':
                error = "No label check for 'experimental' branch"
                print(error)
                self.error_string.append(error)
                return True

            spec_approved = False
            doc_approved = False
            issue_closed = False
            bug_fix = False
            if issue.is_closed() == True:
                issue_closed = True
            if issue_closed:
                error = "Issue #{} has been closed".format(num)
                print(error)
                self.error_string.append(error)
                return False
            # compatibility between 1.20 and 0.9.6
            if type(issue.labels) == type([]):
                l = issue.labels
            else:
                l = issue.labels()

            for label in l:
                if label.name == "SpecApproved":
                    spec_approved = True
                if label.name == "DocApproved":
                    doc_approved = True
                if label.name == "Type:Bug":
                    bug_fix = True
            if bug_fix:
                error = "Bug fix, no extra flags required"
                print(error)
                self.error_string.append(error)
                return True
            if not spec_approved:
                error = "Missing SpecApproved flag on Issue {}".format(num)
                print(error)
                self.error_string.append(error)
            if not doc_approved:
                error = "Missing DocApproved flag on Issue {}".format(num)
                print(error)
                self.error_string.append(error)
            if spec_approved and doc_approved:
                error = "All approvals in place"
                print(error)
                self.error_string.append(error)
                return True
            return False
        print("Issue #{} does not exist in {} repo".format(num, self.repo))
        return False

    def write_error_string(self):
        '''
        Verify that error string is written to file
        '''
        if not self.error_string:
            return False
        with open('gerrit_comment', 'w') as f:
            for line in self.error_string:
                f.write(line)
                f.write('\n')




def main(repo, dry_run, comment_file=False):
    '''
    The main function for this program. The actual program execution happens
    here
    '''
    github = GitHubHandler(repo, dry_run, comment_file)
    commit = CommitHandler(repo)
    # get commit message
    commit_msg = get_commit_message()

    # check if updates/fixes: xxx appears in the commit
    issues = commit.parse_commit_message(commit_msg)
    issue_check_success = 0

    if issues:
        for issue in issues:
            if not github.check_issue(issue['id']):
                issue_check_success = 1

            github.write_error_string()
        # remove duplicates from previous commit message (if any)
        newissues = commit.remove_duplicates(issues)
        # comment on issue: xxx about the review
        github.comment_on_issues(newissues, commit_msg)
    sys.exit(issue_check_success)


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
    PARSER.add_argument(
        '--comment-file', '-c',
        action='store_true',
        help="The file to store the comment for failure, if any",
    )
    ARGS = PARSER.parse_args()
    main(ARGS.repo, ARGS.dry_run, ARGS.comment_file)
