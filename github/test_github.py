import unittest
import handle_github
import commit
from mock import patch, Mock, MagicMock


class IssueCheckTest(unittest.TestCase):

    @patch('commit.get_commit_message')
    def test_with_no_issue(self, mock):
        '''
        A commit with no issue mentioned
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, [])

    @patch('commit.get_commit_message')
    def test_issue_and_bug(self, mock):
        '''
        A commit with an issue and bug
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: bz#1234\n'
            'Fixes: #4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['4567'])

    @patch('handle_github.GitHubHandler._github_login')
    @patch('commit.get_commit_message')
    def test_with_valid_issue(self, mock1, mock2):
        '''
        A commit with an existing issue with correct labels
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: #1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        # Handle a valid issue
        mock2.side_effect = None
        ghub = handle_github.GitHubHandler('glusterfs', True)
        ghub.ghub = Mock(name='mockedgithub')
        ghub.ghub.issue.return_value.labels = ['SpecApproved', 'DocApproved']
        self.assertTrue(ghub.check_issue(issues[0]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('commit.get_commit_message')
    def test_with_invalid_issue(self, mock1, mock2):
        '''
        A commit with an existing issue with incorrect labels
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: #1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        # Handle a valid issue
        mock2.side_effect = None
        ghub = handle_github.GitHubHandler('glusterfs', True)
        ghub.ghub = Mock(name='mockedgithub')
        ghub.ghub.issue.return_value.labels = ['SpecApproved']
        self.assertFalse(ghub.check_issue(issues[0]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('commit.get_commit_message')
    def test_with_nonexistent(self, mock1, mock2):
        '''
        A commit with a non-existing issue
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit with\n\n'
            'Fixes: #123456\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['123456'])

        # Handle a valid issue
        mock2.side_effect = None
        ghub = handle_github.GitHubHandler('glusterfs', True)
        ghub.ghub = Mock(name='mockedgithub')
        ghub.ghub.issue.return_value = None
        self.assertFalse(ghub.check_issue(issues[0]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('commit.get_commit_message')
    def test_with_two_valid_issues(self, mock1, mock2):
        '''
        A commit with two issues with correct labels
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: #1234\n'
            'Updates: #4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Handle a valid issue
        mock2.side_effect = None
        ghub = handle_github.GitHubHandler('glusterfs', True)
        ghub.ghub = Mock(name='mockedgithub')
        ghub.ghub.issue.return_value.labels = ['SpecApproved', 'DocApproved']
        for issue in issues:
            self.assertTrue(ghub.check_issue(issue))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('commit.get_commit_message')
    def test_with_valid_invalid_issues(self, mock1, mock2):
        '''
        A commit with one valid and one with incorrect labels
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: #1234\n'
            'Updates: #4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Handle a valid issue
        mock2.side_effect = None
        ghub = handle_github.GitHubHandler('glusterfs', True)
        with MagicMock(name='mockedgithub') as m:
            ghub.ghub = m
            ghub.ghub.issue.return_value.labels = ['SpecApproved', 'DocApproved']
            self.assertTrue(ghub.check_issue(issues[0]))

        with MagicMock(name='mockedgithub') as m:
            ghub.ghub = m
            ghub.ghub.issue.return_value.labels = ['DocApproved']
            self.assertFalse(ghub.check_issue(issues[1]))

    @patch('handle_github.GitHubHandler._github_login')
    @patch('commit.get_commit_message')
    def test_with_two_invalid_issues(self, mock1, mock2):
        '''
        A commit with two issues with incorrect labels
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Fixes: #1234\n'
            'Updates: #4567')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Handle a valid issue
        mock2.side_effect = None
        ghub = handle_github.GitHubHandler('glusterfs', True)
        with MagicMock(name='mockedgithub') as m:
            ghub.ghub = m
            ghub.ghub.issue.return_value.labels = ['SpecApproved']
            self.assertFalse(ghub.check_issue(issues[0]))

        with MagicMock(name='mockedgithub') as m:
            ghub.ghub = m
            ghub.ghub.issue.return_value.labels = ['DocApproved']
            self.assertFalse(ghub.check_issue(issues[1]))

    @patch('commit.get_commit_message')
    def test_issue_with_same_repo_name(self, mock):
        '''
        A commit with issue mentioning current repo
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: gluster/glusterfs#1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

    @patch('commit.get_commit_message')
    def test_issue_with_different_repo_name(self, mock):
        '''
        A commit with issue mentioning current repo
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Fixes: gluster/glusterdocs#1234\n')
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, [])


class IssueDuplicationTest(unittest.TestCase):
    '''
    Test Handling of issue de-duplication by the Github handling code
    '''

    @patch('commit.get_commit_message')
    def test_first_revision(self, mock):
        '''
        A test to check deduplication when the revision number is 1
        '''
        # Mock the commit message
        mock.return_value = (
            'This is a test commit\n\n'
            'Updates: #1234')

        # Parse the commit message
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        c.revision_number = 1
        deduped = c.remove_duplicates(issues)
        self.assertListEqual(deduped, issues)

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('commit.get_commit_message')
    def test_second_revision_same_issue(self, mock1, mock2):
        '''
        A test to check deduplication when revision number is 2 with same issue
        in commit message
        '''
        # Mock the commit message
        mock1.return_value = (
            'This is a test commit\n\n'
            'Updates: #1234')
        # Parse the commit message
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        # Mock the commit message from Gerrit
        mock2.return_value = (
            'This is the previous commit\n\n'
            'Updates: #1234')
        c.revision_number = 2
        deduped = c.remove_duplicates(issues)
        self.assertListEqual(deduped, [])

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('commit.get_commit_message')
    def test_second_revision_different_issue(self, mock1, mock2):
        '''
        A test to check deduplication when second revision has a different
        issue from the first revision
        '''
        mock1.return_value = (
            'This is a test commit\n\n'
            'Updates: #4567')
        # Parse the commit message
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['4567'])

        # Mock the commit message from Gerrit
        mock2.return_value = (
            'This is the previous commit\n\n'
            'Fixes: #1234')
        c.revision_number = 2
        deduped = c.remove_duplicates(issues)
        self.assertListEqual(deduped, ['4567'])

    @patch('commit.CommitHandler.get_commit_message_from_gerrit')
    @patch('commit.get_commit_message')
    def test_second_revision_new_issue(self, mock1, mock2):
        '''
        A test to check deduplication when the secon revision has an added
        issue
        '''
        mock1.return_value = (
            'This is a test commit\n\n'
            'Updates: #1234'
            'Fixes: #4567')
        # Parse the commit message
        commit_msg = commit.get_commit_message()
        c = commit.CommitHandler('glusterfs')
        issues = c.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234', '4567'])

        # Mock the commit message from Gerrit
        mock2.return_value = (
            'This is the previous commit\n\n'
            'Updates: #1234')
        c.revision_number = 2
        deduped = c.remove_duplicates(issues)
        self.assertListEqual(deduped, ['4567'])
