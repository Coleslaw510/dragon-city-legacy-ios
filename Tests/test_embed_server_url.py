#!/usr/bin/env python3
"""Portable integration tests for the post-build plist injector."""

import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / ".github" / "scripts" / "embed_server_url.py"


class EmbedServerURLTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(dir=ROOT)
        self.plist = Path(self.work.name) / "Info.plist"
        with self.plist.open("wb") as f:
            plistlib.dump({"CFBundleName": "Example"}, f)

    def tearDown(self):
        self.work.cleanup()

    def invoke(self, value):
        env = dict(os.environ)
        if value is None:
            env.pop("SERVER_URL", None)
        else:
            env["SERVER_URL"] = value
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.plist)],
                                env=env, capture_output=True, text=True, check=False)
        if value:
            self.assertNotIn(value, result.stdout)
            self.assertNotIn(value, result.stderr)
        return result

    def test_valid_http_and_https_round_trip_without_output(self):
        for value in ("http://game.example.invalid/play", "https://game.example.invalid:8443/play?mode=1"):
            result = self.invoke(value)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "")
            with self.plist.open("rb") as f:
                data = plistlib.load(f)
            self.assertEqual(data["SERVER_URL"], value)
            self.assertEqual(data["CFBundleName"], "Example")

    def test_missing_and_invalid_urls_fail_without_modification_or_echo(self):
        before = self.plist.read_bytes()
        for value in (None, "", "not-a-url", "ftp://game.example.invalid/",
                      "https://user:password@game.example.invalid/", "https://game.example.invalid:99999/",
                      "https://game.example.invalid/has space", "https://game.example.invalid/\nleak"):
            result = self.invoke(value)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.plist.read_bytes(), before)

    def test_unreadable_or_missing_plist_has_generic_error(self):
        self.plist.unlink()
        result = self.invoke("https://game.example.invalid/")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
