#!/usr/bin/env python3
"""Embed the Actions secret in an unsigned built app without printing it."""

import os
import plistlib
import sys
import tempfile
from urllib.parse import urlsplit


def valid_server_url(value: str) -> bool:
    if not value or any(ch.isspace() or ord(ch) < 32 or ord(ch) == 127 for ch in value):
        return False
    try:
        parts = urlsplit(value)
        port = parts.port  # Accessing an invalid port raises ValueError.
        return (
            parts.scheme.lower() in ("http", "https")
            and bool(parts.hostname)
            and parts.username is None
            and parts.password is None
            and "\\" not in parts.netloc
            and (port is None or 1 <= port <= 65535)
        )
    except (ValueError, UnicodeError):
        return False


def main() -> int:
    # Do not echo this value, include it in exceptions, or pass it as argv.
    server_url = os.environ.pop("SERVER_URL", "")
    if len(sys.argv) != 2 or not valid_server_url(server_url):
        print("::error::SERVER_URL is missing or is not a valid HTTP(S) URL without credentials.", file=sys.stderr)
        return 1
    temp_name = None
    try:
        plist_path = sys.argv[1]
        with open(plist_path, "rb") as plist_file:
            data = plistlib.load(plist_file)
        if not isinstance(data, dict):
            raise ValueError("Invalid app metadata")
        data["SERVER_URL"] = server_url
        directory = os.path.dirname(os.path.abspath(plist_path))
        with tempfile.NamedTemporaryFile(mode="wb", dir=directory, delete=False) as temp:
            temp_name = temp.name
            plistlib.dump(data, temp, fmt=plistlib.FMT_BINARY, sort_keys=False)
        os.chmod(temp_name, os.stat(plist_path).st_mode & 0o777)
        os.replace(temp_name, plist_path)
        temp_name = None
    except Exception:
        # Exceptions can contain input values; do not expose exception details.
        print("::error::Could not configure the built app.", file=sys.stderr)
        return 1
    finally:
        if temp_name is not None:
            try:
                os.unlink(temp_name)
            except OSError:
                pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
