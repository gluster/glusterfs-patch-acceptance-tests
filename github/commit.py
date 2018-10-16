# -*- coding: utf-8
'''
This code handles extracting data from the commit message
'''
from __future__ import unicode_literals, absolute_import, print_function
import json
import os
import re
import subprocess
import requests

def get_commit_message():
    '''
    Run the git command line to get the commit message from the git repo in the
    current directory
    '''
    commit = subprocess.check_output(['git', 'log', '--format=%B', '-n', '1'])
    return commit.decode('utf-8')


class CommitHandler(object):
    '''
    This class fetches and handles commit-related information from Gerrit and
    parses it for use later in the code
    '''

    def __init__(self, repo, issue=True):
        # TODO: Do not fetch this from env
        self.project = os.environ.get('GERRIT_PROJECT')
        self.branch = os.environ.get('GERRIT_BRANCH')
        self.change_id = os.environ.get('GERRIT_CHANGE_ID')
        self.revision_number = int(os.environ.get('GERRIT_PATCHSET_NUMBER', 1))
        self.repo = repo
        self.issue = issue

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
                             str(self.revision_number - 1)
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
        '''

        if self.revision_number == 1:
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
        if self.issue:
            regex = re.compile(''.join([r'^\s*(([fF][iI][xX][eE][sS])|',
                                        r'([uU][pP][dD][aA][tT][eE]',
                                        r'[sS])):?\s+(gluster/',
                                        self.repo,
                                        r')?#(\d*)']))
            group_index = 5
        else:
            regex = re.compile(''.join([r'^\s*(([fF][iI][xX][eE][sS])|',
                                        r'([uU][pP][dD][aA][tT][eE]',
                                        r'[sS])):?\sbz#(\d*)']))
            group_index = 4

        issues = []
        for line in msg.split('\n'):
            for match in regex.finditer(line):
                issues.append(match.group(group_index))
        if issues:
            print("Issues found in the commit message: {}".format(issues))
            return issues
        print("No issues found in the commit message")
        return issues
