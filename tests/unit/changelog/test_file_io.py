import unittest
import os
import sys

# Add the script path to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../skills/changelog/scripts')))

from update_log import update_changelog

class TestFileIO(unittest.TestCase):
    def test_update_changelog_standard(self):
        content = "# Changelog\n\n## [1.0.0] - 2026-01-01\n- Old entry"
        with open("test_CHANGELOG_io.md", "w") as f:
            f.write(content)
        
        new_entry = "## [1.1.0] - 2026-06-12\n### Added\n- New entry"
        try:
            update_changelog("test_CHANGELOG_io.md", new_entry)
            with open("test_CHANGELOG_io.md", "r") as f:
                updated = f.read()
            self.assertIn("# Changelog", updated)
            self.assertIn("## [1.1.0] - 2026-06-12", updated)
            self.assertTrue(updated.index("## [1.1.0]") < updated.index("## [1.0.0]"))
        finally:
            if os.path.exists("test_CHANGELOG_io.md"):
                os.remove("test_CHANGELOG_io.md")

    def test_update_changelog_no_header(self):
        content = "## [1.0.0] - 2026-01-01\n- Old entry"
        with open("test_CHANGELOG_no_header.md", "w") as f:
            f.write(content)
        
        new_entry = "## [1.1.0] - 2026-06-12\n### Added\n- New entry"
        try:
            update_changelog("test_CHANGELOG_no_header.md", new_entry)
            with open("test_CHANGELOG_no_header.md", "r") as f:
                updated = f.read()
            self.assertTrue(updated.startswith("## [1.1.0]"))
        finally:
            if os.path.exists("test_CHANGELOG_no_header.md"):
                os.remove("test_CHANGELOG_no_header.md")

if __name__ == '__main__':
    unittest.main()
