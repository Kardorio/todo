import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
INFO = json.loads((ROOT / "info.json").read_text())


def command(*args, success=True):
    result = subprocess.run([sys.executable, str(ROOT / "tools/build.py"), *args],
                            capture_output=True, text=True, timeout=20)
    if success and result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return result


class BuildTests(unittest.TestCase):
    def test_archive_matches_runtime_sources(self):
        command("package")
        name = f"{INFO['name']}_{INFO['version']}"
        with zipfile.ZipFile(ROOT / "dist" / f"{name}.zip") as archive:
            expected = {"info.json", "data.lua", "control.lua"}
            for folder in ("scripts", "gui", "integrations", "locale"):
                expected.update(str(path.relative_to(ROOT)) for path in (ROOT / folder).rglob("*") if path.is_file())
            self.assertEqual(set(archive.namelist()), {f"{name}/{path}" for path in expected})
            for path in expected:
                self.assertEqual(archive.read(f"{name}/{path}"), (ROOT / path).read_bytes())

    def test_link_backup_idempotence_and_unlink(self):
        with tempfile.TemporaryDirectory(prefix="todo-link-test-") as directory:
            mods = Path(directory)
            old_zip = mods / f"{INFO['name']}_9.9.9.zip"
            old_zip.write_bytes(b"previous archive")
            command("devlink", "--mods-dir", directory)
            link = mods / INFO["name"]
            self.assertTrue(link.is_symlink())
            self.assertEqual(link.resolve(), ROOT)
            backup = list((mods / ".todo-manager-backups").rglob("*.zip"))
            self.assertEqual(len(backup), 1)
            self.assertEqual(backup[0].read_bytes(), b"previous archive")
            self.assertFalse(old_zip.exists())
            command("devlink", "--mods-dir", directory)
            command("unlink", "--mods-dir", directory)
            self.assertFalse(link.exists())
            self.assertTrue(backup[0].exists())
            command("unlink", "--mods-dir", directory)

    def test_existing_directory_is_preserved(self):
        with tempfile.TemporaryDirectory(prefix="todo-link-test-") as directory:
            target = Path(directory) / INFO["name"]
            target.mkdir()
            marker = target / "keep.txt"
            marker.write_text("preserve")
            self.assertNotEqual(command("devlink", "--mods-dir", directory, success=False).returncode, 0)
            self.assertEqual(marker.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
