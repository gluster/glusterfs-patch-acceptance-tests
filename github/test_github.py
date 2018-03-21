import unittest
import handle_github
from mock import patch, Mock, MagicMock


class IssueCheckTest(unittest.TestCase):

    @patch('handle_github.get_commit_message')
    def test_with_no_issue(self, mock):
        '''
        A commit with no issue mentioned
        '''
        mock.return_value = (
                'This is a test commit\n\n'
                'Fixes: bz#1234\n')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, [])

    @patch('handle_github.GitHubHandler._github_login')
    @patch('handle_github.get_commit_message')
    def test_with_valid_issue(self, mock1, mock2):
        '''
        A commit with an existing issue with correct labels
        '''
        mock1.return_value = (
                'This is a test commit\n\n'
                'Fixes: #1234\n')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        # Handle a valid issue
        mock2.side_effect = None
        g = handle_github.GitHubHandler('glusterfs', True)
        g.ghub = Mock(name='mockedgithub')
        g.ghub.issue.return_value.labels = ['SpecApproved', 'DocApproved']
        self.assertTrue(g.check_issue(issues[0]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('handle_github.get_commit_message')
    def test_with_invalid_issue(self, mock1, mock2):
        '''
        A commit with an existing issue with incorrect labels
        '''
        mock1.return_value = (
                'This is a test commit\n\n'
                'Fixes: #1234\n')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        # Handle a valid issue
        mock2.side_effect = None
        g = handle_github.GitHubHandler('glusterfs', True)
        g.ghub = Mock(name='mockedgithub')
        g.ghub.issue.return_value.labels = ['SpecApproved']
        self.assertFalse(g.check_issue(issues[0]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('handle_github.get_commit_message')
    def test_with_nonexistent(self, mock1, mock2):
        '''
        A commit with a non-existing issue
        '''
        mock1.return_value = (
                'This is a test commit with\n\n'
                'Fixes: #123456\n')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['123456'])

        # Handle a valid issue
        mock2.side_effect = None
        g = handle_github.GitHubHandler('glusterfs', True)
        g.ghub = Mock(name='mockedgithub')
        g.ghub.issue.return_value = None
        self.assertFalse(g.check_issue(issues[0]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('handle_github.get_commit_message')
    def test_with_two_valid_issues(self, mock1, mock2):
        '''
        A commit with two issues with correct labels
        '''
        mock1.return_value = (
                'This is a test commit\n\n'
                'Fixes: #1234\n'
                'Updates: #4567')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Handle a valid issue
        mock2.side_effect = None
        g = handle_github.GitHubHandler('glusterfs', True)
        g.ghub = Mock(name='mockedgithub')
        g.ghub.issue.return_value.labels = ['SpecApproved', 'DocApproved']
        for issue in issues:
            self.assertTrue(g.check_issue(issue))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('handle_github.get_commit_message')
    def test_with_valid_invalid_issues(self, mock1, mock2):
        '''
        A commit with one valid and one with incorrect labels
        '''
        mock1.return_value = (
                'This is a test commit\n\n'
                'Fixes: #1234\n'
                'Updates: #4567')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Handle a valid issue
        mock2.side_effect = None
        g = handle_github.GitHubHandler('glusterfs', True)
        with MagicMock(name='mockedgithub') as m:
            g.ghub = m
            g.ghub.issue.return_value.labels = ['SpecApproved', 'DocApproved']
            self.assertTrue(g.check_issue(issues[0]))

        with MagicMock(name='mockedgithub') as m:
            g.ghub = m
            g.ghub.issue.return_value.labels = ['DocApproved']
            self.assertFalse(g.check_issue(issues[1]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('handle_github.get_commit_message')
    def test_with_two_invalid_issues(self, mock1, mock2):
        '''
        A commit with two issues with incorrect labels
        '''
        mock1.return_value = (
                'This is a test commit\n\n'
                'Fixes: #1234\n'
                'Updates: #4567')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Handle a valid issue
        mock2.side_effect = None
        g = handle_github.GitHubHandler('glusterfs', True)
        with MagicMock(name='mockedgithub') as m:
            g.ghub = m
            g.ghub.issue.return_value.labels = ['SpecApproved']
            self.assertFalse(g.check_issue(issues[0]))

        with MagicMock(name='mockedgithub') as m:
            g.ghub = m
            g.ghub.issue.return_value.labels = ['DocApproved']
            self.assertFalse(g.check_issue(issues[1]))


