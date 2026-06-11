import unittest
from unittest.mock import patch, MagicMock
import os
import sys

# Add the script path to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../skills/changelog/scripts')))

from update_log import get_latest_date_from_file, get_commits_since

class TestGitLogic(unittest.TestCase):
    def test_get_latest_date_from_file_valid(self):
        # Create a temporary CHANGELOG.md
        content = "## [5.2.0] - 2026-06-06\n### Added\n- Feature X"
        with open("test_CHANGELOG.md", "w") as f:
            f.write(content)
        
        try:
            date = get_latest_date_from_file("test_CHANGELOG.md")
            self.assertEqual(date, "2026-06-06")
        finally:
            if os.path.exists("test_CHANGELOG.md"):
                os.remove("test_CHANGELOG.md")

    def test_get_latest_date_from_file_no_date(self):
        content = "# Changelog\nNo dates here"
        with open("test_CHANGELOG_empty.md", "w") as f:
            f.write(content)
        
        try:
            date = get_latest_date_from_file("test_CHANGELOG_empty.md")
            self.assertIsNone(date)
        finally:
            if os.path.exists("test_CHANGELOG_empty.md"):
                os.remove("test_CHANGELOG_empty.md")

    @patch('subprocess.run')
    def test_get_commits_since(self, mock_run):
        mock_run.return_value = MagicMock(
            stdout="abc1234|feat: commit 1\ndef5678|fix: commit 2",
            returncode=0
        )
        
        commits = get_commits_since("2026-06-06")
        self.assertEqual(len(commits), 2)
        self.assertEqual(commits[0], "abc1234|feat: commit 1")
        self.assertEqual(commits[1], "def5678|fix: commit 2")
        
        mock_run.assert_called_once()
        args, kwargs = mock_run.call_args
        command = args[0]
        self.assertIn("--after=2026-06-06", command)

if __name__ == '__main__':
    unittest.main()
