import unittest
import handle_github
from mock import patch


class IssueTest(unittest.TestCase):

    @patch('handle_github.get_commit_message')
    def test_with_no_issue(self, mock):
        '''
        A commit with no issue mentioned
        '''
        mock.return_value = (
                'This is a test commit with no issue\n\n'
                'Fixes: bz#1234\n')
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, [])

    @patch('handle_github.get_commit_message')
    @patch('handle_github.GitHubHandler._github_login')
    def test_with_valid_issue(self, mock1, mock2):
        '''
        A commit with valid issue
        '''
        mock1.return_value = (
                'This is a test commit with a valid issue\n\n'
                'Fixes: #1234\n')
        mock2.side_effect = None
        commit_msg = handle_github.get_commit_message()
        commit = handle_github.CommitHandler('glusterfs')
        issues = commit.parse_commit_message(commit_msg)
        self.assertListEqual(issues, ['1234'])

        # Hanndle a valid issue
        g = handle_github.GitHubHandler('glusterfs', True)
        g._github_login()
        print(g.ghub)
        for issue in issues:
            g.check_issue(issue)




# Test with invalid issue
# Test with valid issue
# Test with two valid issues
# Test with one valid and one invalid issues
# Test with two invalid issues
