"""Tests for the fork's <upstream>-sub.<n> version scheme.

    python3 -m unittest discover -s tooling -p 'test_*.py'
"""

import pathlib
import shutil
import tempfile
import unittest

import sub_version


class SubVersionTest(unittest.TestCase):
    def test_next_starts_at_one_without_tags(self):
        self.assertEqual(sub_version.next_version("1.3.0", []), "1.3.0-sub.1")
        self.assertEqual(sub_version.next_version("1.3.0", ["v1.2.13", "v1.3.0"]), "1.3.0-sub.1")

    def test_next_uses_the_highest_tag_for_that_base(self):
        tags = ["v1.3.0-sub.1", "v1.3.0-sub.2", "v1.3.0-sub.10", "v1.4.0-sub.3"]
        self.assertEqual(sub_version.next_version("1.3.0", tags), "1.3.0-sub.11")
        self.assertEqual(sub_version.next_version("1.4.0", tags), "1.4.0-sub.4")

    def test_next_ignores_lookalike_tags(self):
        tags = ["v1.3.0-sub.1-extra", "v1.3.0-sub.x", "1.3.0-sub.9", "v1.30-sub.4"]
        self.assertEqual(sub_version.next_version("1.3.0", tags), "1.3.0-sub.1")

    def test_read_pubspec_and_check(self):
        base, sub = sub_version.read_pubspec()
        self.assertEqual(base, "1.3.0")
        self.assertGreaterEqual(sub, 1)
        sub_version.check()

    def test_write_bumps_both_files(self):
        # The counter moves with each release, so derive the expected bump
        # from the tree under test instead of hardcoding the current number.
        base, sub = sub_version.read_pubspec()
        expected = f"{base}-sub.{sub + 1}"
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            shutil.copytree(sub_version.ROOT / "app", root / "app")
            self.assertEqual(sub_version.write(root, tags=[f"v{base}-sub.{sub}"]), expected)
            self.assertEqual(sub_version.read_pubspec(root), (base, sub + 1))
            sub_version.check(root)
            text = (root / "app" / "lib" / "state" / "app_info.dart").read_text(encoding="utf-8")
            self.assertIn(f"defaultValue: '{expected}+1'", text)
            self.assertIn(f"DSH_APP_VERSION={expected}+7", text)

    def test_check_rejects_a_stale_app_info(self):
        base, sub = sub_version.read_pubspec()
        current = f"{base}-sub.{sub}+1"
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            shutil.copytree(sub_version.ROOT / "app", root / "app")
            info = root / "app" / "lib" / "state" / "app_info.dart"
            info.write_text(info.read_text(encoding="utf-8").replace(current, "1.2.13+1"), encoding="utf-8")
            with self.assertRaises(ValueError):
                sub_version.check(root)


if __name__ == "__main__":
    unittest.main()
