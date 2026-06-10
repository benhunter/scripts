import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_zfsdash():
    spec = importlib.util.spec_from_file_location("zfsdash", ROOT / "zfsdash.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class StaticSecurityTests(unittest.TestCase):
    def test_userscript_has_no_remote_dependencies(self):
        text = (ROOT / "tampermonkey/edx-download-transcripts.js").read_text(encoding="utf-8-sig")
        self.assertNotIn("@require", text)
        self.assertNotIn("http://", text)

    def test_file_manager_does_not_interpolate_records_into_html(self):
        text = (ROOT / "file-manager.html").read_text(encoding="utf-8-sig")
        self.assertNotIn("li.innerHTML", text)
        self.assertNotIn("${fileRecord.name}", text)

    def test_zfs_dashboard_is_local_only(self):
        module = load_zfsdash()
        self.assertEqual(module.HOST, "127.0.0.1")

    def test_retired_installers_fail_closed(self):
        for relative_path in (
            "setup-kali.sh",
            "example-deploy.sh",
            "macos/ruby/ruby-install_local.sh",
            "macos/ruby/chruby_local.sh",
            "gitlab-clone-group.sh",
        ):
            text = (ROOT / relative_path).read_text(encoding="utf-8-sig")
            self.assertIn("retired", text)
            self.assertIn("exit 1", text)


class ZfsCacheTests(unittest.TestCase):
    def test_status_is_cached(self):
        module = load_zfsdash()
        module._status_cache.update(at=0.0, output="")
        completed = subprocess.CompletedProcess([], 0, "pool output\n", "")
        with mock.patch.object(module.subprocess, "run", return_value=completed) as run:
            self.assertEqual(module.get_zpool_status(), "pool output")
            self.assertEqual(module.get_zpool_status(), "pool output")
        run.assert_called_once()


@unittest.skipUnless(os.name == "posix", "requires POSIX shell and symlinks")
class RecursiveDeletionTests(unittest.TestCase):
    def test_symlink_does_not_escape_selected_root(self):
        with tempfile.TemporaryDirectory() as workspace:
            workspace = Path(workspace)
            root = workspace / "root"
            outside = workspace / "outside"
            inside_target = root / "project" / "node_modules"
            outside_target = outside / "node_modules"
            inside_target.mkdir(parents=True)
            outside_target.mkdir(parents=True)
            (root / "external-link").symlink_to(outside, target_is_directory=True)

            subprocess.run(
                ["bash", str(ROOT / "rm-recursive-node_modules.sh"), "--yes", str(root)],
                check=True,
            )

            self.assertFalse(inside_target.exists())
            self.assertTrue(outside_target.exists())

    def test_filesystem_root_is_rejected(self):
        result = subprocess.run(
            ["bash", str(ROOT / "rm-recursive-node_modules.sh"), "--yes", "/"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing", result.stderr)
