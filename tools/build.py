#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from validate import validate

ROOT = Path(__file__).resolve().parents[1]
FILES = ("info.json", "control.lua", "scripts", "gui", "locale")


def metadata():
    return json.loads((ROOT / "info.json").read_text())


def stage(destination):
    destination.mkdir(parents=True)
    for name in FILES:
        source = ROOT / name
        if source.is_dir():
            shutil.copytree(source, destination / name)
        else:
            shutil.copy2(source, destination / name)


def test(binary):
    validate()
    subprocess.run([sys.executable, str(ROOT / "tests/test_build.py")], check=True)
    if not binary:
        raise SystemExit("Définir FACTORIO_BIN vers un moteur autonome Factorio 2.1.")
    binary = Path(binary).expanduser().resolve()
    if any(part.lower() in ("steamapps", ".steam") for part in binary.parts) or (binary.parent / "libsteam_api.so").exists():
        raise SystemExit("Utiliser un moteur autonome : les moteurs Steam sont refusés.")
    env = dict(os.environ)
    for key in ("SteamAppId", "SteamGameId", "SteamOverlayGameId"):
        env.pop(key, None)
    version = subprocess.check_output([str(binary), "--version"], text=True, env=env, timeout=10)
    if not version.startswith("Version: 2.1.") or "steam" in version.lower():
        raise SystemExit("Un moteur autonome Factorio 2.1 est nécessaire.")
    print(version.splitlines()[0], flush=True)
    with tempfile.TemporaryDirectory(prefix="todo-manager-test-") as directory:
        work = Path(directory)
        mods = work / "mods"
        target = mods / "todo-manager"
        stage(target)
        shutil.copy2(ROOT / "tests/engine_smoke.lua", target / "engine_smoke.lua")
        shutil.copy2(ROOT / "tests/model_checks.lua", target / "model_checks.lua")
        with (target / "control.lua").open("a") as control:
            control.write('\nrequire("engine_smoke")\n')
        data = binary.parents[2] / "data"
        builtin = {path.parent.name for path in data.glob("*/info.json")}
        (mods / "mod-list.json").write_text(json.dumps({"mods": [
            {"name": name, "enabled": name in ("base", "todo-manager")}
            for name in sorted((builtin - {"core"}) | {"todo-manager"})
        ]}))
        config = work / "config.ini"
        config.write_text(f"[path]\nread-data={data}\nwrite-data={work / 'write'}\n")
        common = [str(binary), "--config", str(config), "--mod-directory", str(mods)]
        if "headless" not in version.lower():
            common.append("--disable-audio")
        save = work / "test.zip"
        steps = [
            (["--create", str(save)], ("TODO_STORAGE_WRITTEN",)),
            (["--test-save", str(save), "--test-ticks", "5"], ("TODO_RELOAD_OK", "TODO_MODEL_OK", "TODO_UI_RELOAD_OK", "TODO_RUNTIME_OK")),
        ]
        for arguments, markers in steps:
            result = subprocess.run(common + arguments, env=env, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=120)
            if result.returncode or any(marker not in result.stdout for marker in markers):
                print(result.stdout)
                raise SystemExit(f"Échec du test moteur : {markers} (code {result.returncode}).")
            for marker in markers:
                print(f"{marker} : OK", flush=True)
        legacy = work / "legacy.zip"
        for name in ("legacy_seed", "upgrade_checks"):
            shutil.copy2(ROOT / "tests" / f"{name}.lua", target / f"{name}.lua")
        upgrade_steps = [
            ('require("legacy_seed")\n', ["--create", str(legacy)], "TODO_LEGACY_WRITTEN"),
            ((ROOT / "control.lua").read_text() + '\nrequire("upgrade_checks")\n',
             ["--benchmark", str(legacy), "--benchmark-ticks", "2", "--benchmark-runs", "1"], "TODO_UPGRADE_OK"),
        ]
        for control, arguments, marker in upgrade_steps:
            (target / "control.lua").write_text(control)
            result = subprocess.run(common + arguments, env=env, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=120)
            if result.returncode or marker not in result.stdout:
                print(result.stdout)
                raise SystemExit(f"Échec migration : {marker} (code {result.returncode}).")
            print(f"{marker} : OK", flush=True)


def package():
    info = metadata()
    name = f"{info['name']}_{info['version']}"
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    archive_path = dist / f"{name}.zip"
    with tempfile.TemporaryDirectory(prefix="todo-manager-package-") as directory:
        staged = Path(directory) / name
        stage(staged)
        with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(staged.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(staged.parent))
    print(archive_path)


def devlink(destination, unlink=False):
    destination = Path(destination).expanduser().resolve()
    name = metadata()["name"]
    link = destination / name
    if link.is_symlink():
        if link.resolve() != ROOT:
            raise SystemExit(f"Un autre lien existe déjà : {link}")
        if unlink:
            link.unlink()
            print(f"Lien retiré : {link}")
            return
    elif link.exists():
        raise SystemExit(f"Un dossier existe déjà : {link}. Il est conservé.")
    elif unlink:
        print("Aucun lien à retirer.")
        return
    destination.mkdir(parents=True, exist_ok=True)
    archives = sorted(destination.glob(f"{name}_*.zip"))
    if archives:
        backup = destination / ".todo-manager-backups" / str(time.time_ns())
        backup.mkdir(parents=True)
        for archive in archives:
            shutil.move(str(archive), backup / archive.name)
        print(f"Archives précédentes conservées dans {backup}")
    if not link.is_symlink():
        link.symlink_to(ROOT, target_is_directory=True)
    print(f"Lien installé : {link}")


def main():
    parser = argparse.ArgumentParser(description="Construction et tests de Todo Manager")
    parser.add_argument("action", choices=("test", "check", "package", "link", "devlink", "unlink", "clean"))
    parser.add_argument("--mods-dir", default="~/.factorio/mods")
    args = parser.parse_args()
    if args.action == "test":
        test(os.environ.get("FACTORIO_BIN"))
    elif args.action == "check":
        validate()
    elif args.action in ("link", "devlink", "unlink"):
        devlink(args.mods_dir, args.action == "unlink")
    elif args.action == "clean":
        for archive in (ROOT / "dist").glob(f"{metadata()['name']}_*.zip"):
            archive.unlink()
    else:
        package()


if __name__ == "__main__":
    main()
