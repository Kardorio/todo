"""Capture the real GUI with an isolated standalone Factorio client."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from capture_helpers import complete_png

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from build import stage


def main():
    locale = os.environ.get("TODO_VISUAL_LOCALE", "fr")
    if locale not in ("fr", "en"):
        raise SystemExit("TODO_VISUAL_LOCALE doit être fr ou en.")
    binary = Path(os.environ.get("FACTORIO_GUI_BIN", ROOT / ".tools/factorio-standalone/bin/x64/factorio")).resolve()
    if any(part.lower() in ("steamapps", ".steam") for part in binary.parts) or (binary.parent / "libsteam_api.so").exists():
        raise SystemExit("Client Steam refusé ; utiliser un client autonome Factorio 2.1.")
    if not binary.is_file():
        raise SystemExit("Client graphique autonome absent ; définir FACTORIO_GUI_BIN.")
    env = dict(os.environ)
    for key in ("SteamAppId", "SteamGameId", "SteamOverlayGameId", "DISPLAY", "WAYLAND_DISPLAY"):
        env.pop(key, None)
    env["SDL_VIDEODRIVER"] = "offscreen"
    version = subprocess.check_output([str(binary), "--version"], env=env, text=True, timeout=10).lower()
    if not version.startswith("version: 2.1.") or "steam" in version or "headless" in version:
        raise SystemExit("Un client graphique autonome Factorio 2.1 est nécessaire.")
    output = ROOT / "tests/visual-output"
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="todo-visual-") as directory:
        work = Path(directory)
        mods, write = work / "mods", work / "write"
        write.mkdir()
        target = mods / "todo-manager"
        stage(target)
        shutil.copy2(ROOT / "tests/visual.lua", target / "visual.lua")
        (target / "visual_language.lua").write_text(f'return "{locale}"\n')
        shutil.copy2(ROOT / "tests/production_data.lua", target / "data-final-fixes.lua")
        with (target / "control.lua").open("a") as control:
            control.write('\nrequire("visual")\n')
        builtin = {path.parent.name for path in (binary.parents[2] / "data").glob("*/info.json")}
        (mods / "mod-list.json").write_text(json.dumps({"mods": [
            {"name": name, "enabled": name in ("base", "todo-manager")}
            for name in sorted((builtin - {"core"}) | {"todo-manager"})
        ]}))
        config = work / "config.ini"
        config.write_text(f"[path]\nread-data={binary.parents[2] / 'data'}\nwrite-data={write}\n"
                          f"[general]\nlocale={locale}\n[other]\ncheck-updates=false\n"
                          "[interface]\nui-scale-mode=manual-pixels\ncustom-ui-scale=1.25\n"
                          "[graphics]\nfull-screen=false\ngraphics-quality=normal\nmax-threads=4\n")
        base = [str(binary), "--config", str(config), "--mod-directory", str(mods), "--disable-audio"]
        created = subprocess.run(base + ["--create", str(work / "test.zip")], env=env,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
        if created.returncode:
            raise RuntimeError(created.stdout[-8000:])
        log_path = output / "visual.log"
        marker = write / "script-output/todo-visual-result.txt"
        names = ("todo-reminder.png", "todo-management.png", "todo-factopedia.png", "todo-from-factopedia.png", "todo-location-editor.png", "todo-added-ingredient.png", "todo-locked-recipe.png", "todo-recipe-factopedia.png", "todo-settings.png")
        with log_path.open("w") as log:
            process = subprocess.Popen(base + ["--window-size", "1280x900", "--force-graphics-preset", "very-low",
                                               "--load-game", str(work / "test.zip")], env=env,
                                       stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 60
                while time.monotonic() < deadline:
                    if marker.exists() and all(complete_png(write / "script-output" / name) for name in names):
                        break
                    if process.poll() is not None:
                        break
                    time.sleep(0.2)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
        if not marker.is_file() or marker.read_text() != "TODO VISUAL OK\n":
            raise RuntimeError(log_path.read_text()[-8000:])
        for name in names:
            source = write / "script-output" / name
            if not complete_png(source):
                raise RuntimeError(f"Capture absente : {name}")
            shutil.copy2(source, output / name)
            print(output / name)


if __name__ == "__main__":
    main()
