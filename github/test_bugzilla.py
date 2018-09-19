# -*- coding: utf-8 -*-
from __future__ import unicode_literals
import unittest
import handle_bugzilla
import commit
from mock import patch, Mock, MagicMock

class BugParseTest(unittest.TestCase):

    @patch('commit.get_commit_message')
    def test_with_issue(self, mock):
        '''
        A commit with an issue
        '''
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: #1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertFalse(bugs)

    @patch('commit.get_commit_message')
    def test_with_bug(self, mock):
        '''
        A commit with a bug
        '''
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertEqual(bugs[0], '1234')

    @patch('commit.get_commit_message')
    def test_issue_and_bug(self, mock):
        '''
        A commit with a bug and issue
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n'
            'Fixes: #4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

    @patch('commit.get_commit_message')
    def test_two_bugs(self, mock):
        '''
        A commit with two bugs
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n'
            'Fixes: bz#4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

    @patch('commit.get_commit_message')
    def test_with_unicode(self, mock):
        '''
        A commit with an issue and bug with unicode text
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            '♥'
            'Fixes: bz#1234\n'
            'Fixes: #4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])


class BugUpdateLogicTest(unittest.TestCase):

    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_one(self, mock1, mock2):
        '''
        The first patchset event with a bug
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 1
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')
        self.assertTrue(bug.needs_update(c, 'patchset-created'))

    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_one(self, mock1, mock2):
        '''
        The first patchset event with a bug
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 1
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')
        self.assertTrue(bug.needs_update(c, 'patchset-created'))

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_two_commit_message_updated(self, mock1, mock2, mock3):
        '''
        The second patchset event with a new bug
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 2
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')

        # Mock the commit message from Gerrit
        mock3.return_value = (
            'This is the previous commit\n\n'
            'Updates: bz#4567')
        self.assertTrue(bug.needs_update(c, 'patchset-created'))

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_two_commit_message_not_updated(self, mock1, mock2, mock3):
        '''
        A second patchset event with the same bug
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 2
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')

        # Mock the commit message from Gerrit
        mock3.return_value = (
            'This is the previous commit\n\n'
            'Updates: bz#1234')
        self.assertFalse(bug.needs_update(c, 'patchset-created'))

    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_patch_merged(self, mock1, mock2):
        '''
        Change merged event
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 2
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')
        self.assertTrue(bug.needs_update(c, 'change-merged'))

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_one_no_bug_two_new_bug(self, mock1, mock2, mock3):
        '''
        A second patchset with a bug and first patchset with no bug
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 2
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')

        # Mock the commit message from Gerrit
        mock3.return_value = (
            'This is the previous commit\n\n')
        self.assertTrue(bug.needs_update(c, 'patchset-created'))

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('bugzilla.Bugzilla')
    @patch('commit.get_commit_message')
    def test_patchset_one_two_bugs_one_new_bug(self, mock1, mock2, mock3):
        '''
        A second patchset with one bug and first patchset with two different
        bugs
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')

        # Disable bz network calls
        mock2.return_value = None

        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs', issue=False)
        bugs = c.parse_commit_message(commit_msg)
        self.assertListEqual(bugs, ['1234'])

        c.revision_number = 2
        bug = handle_bugzilla.Bug(id=bugs[0], product='glusterfs')

        # Mock the commit message from Gerrit
        mock3.return_value = (
            'This is the previous commit\n'
            'Fixes: bz#4566\n'
            'Updates: bz#7890\n')
        self.assertTrue(bug.needs_update(c, 'patchset-created'))
        if hasattr(self, 'assertCountEqual'):
            # py3
            self.assertCountEqual(['4566', '7890'], bug.old_bugs)
        else:
            # py2
            self.assertItemsEqual(['4566', '7890'], bug.old_bugs)


# class BugzillaTest(unittest.TestCase):

    # def test_bugzilla_api(self):
        # bug = handle_bugzilla.Bug(id='1627620', product='glusterfs')
        # self.assertTrue(bug.product_check('GlusterFS'), "Bugzilla login needed"
                                                        # "for this test")
