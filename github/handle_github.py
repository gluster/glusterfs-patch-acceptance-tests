#!/usr/bin/env python
'''
This small program should be able to verify that github issues are specified in
every commit and comment on them when there is an updated patch
'''


from __future__ import absolute_import, print_function, unicode_literals
import argparse
import os
import sys
from github3 import login
from commit import CommitHandler, get_commit_message


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
                if label.name == "SpecApproved":
                    spec_approved = True
                if label.name == "DocApproved":
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
        for issue in issues:
            if not github.check_issue(issue):
                issue_check_success = 1
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
    ARGS = PARSER.parse_args()
    main(ARGS.repo, ARGS.dry_run)
