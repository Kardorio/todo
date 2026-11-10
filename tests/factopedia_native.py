from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from capture_helpers import complete_png

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
from build import stage

binary = Path(os.environ.get("FACTORIO_GUI_BIN", root / ".tools/factorio-standalone/bin/x64/factorio")).resolve()
xvfb = Path(os.environ.get("XVFB_BIN", shutil.which("Xvfb") or root / ".tools/xvfb/root/usr/bin/Xvfb"))
if any(part.lower() in ("steamapps", ".steam") for part in binary.parts) or (binary.parent / "libsteam_api.so").exists():
    raise SystemExit("Client Steam refusé ; utiliser un client autonome Factorio 2.1.")
if not binary.is_file() or not xvfb.is_file() or not shutil.which("xdotool"):
    raise SystemExit("Ce test nécessite un client graphique autonome Factorio 2.1, Xvfb et xdotool.")
version_env = dict(os.environ)
for key in ("SteamAppId", "SteamGameId", "SteamOverlayGameId"):
    version_env.pop(key, None)
version = subprocess.check_output([str(binary), "--version"], env=version_env, text=True, timeout=10).lower()
if not version.startswith("version: 2.1.") or "steam" in version or "headless" in version:
    raise SystemExit("Un client graphique autonome Factorio 2.1 est nécessaire.")
output = root / "tests/visual-output"
output.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix="todo-native-input-") as directory:
    work = Path(directory)
    display = next(f":{number}" for number in range(98, 108) if not Path(f"/tmp/.X11-unix/X{number}").exists())
    server_log = (work / "xvfb.log").open("w")
    server = subprocess.Popen([str(xvfb), display, "-screen", "0", "1280x900x24", "-nolisten", "tcp", "-ac"],
                              stdout=server_log, stderr=subprocess.STDOUT)
    process = None
    try:
        time.sleep(0.5)
        assert server.poll() is None, (work / "xvfb.log").read_text()
        mods, write = work / "mods", work / "write"
        write.mkdir()
        target = mods / "todo-manager"
        stage(target)
        shutil.copy2(root / "tests/factopedia_native.lua", target / "native_probe.lua")
        with (target / "control.lua").open("a") as control:
            control.write('\nrequire("native_probe")\n')
        (mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": "base", "enabled": True},
                                                                  {"name": "todo-manager", "enabled": True}]}))
        config = work / "config.ini"
        config.write_text(f"[path]\nread-data={binary.parents[2] / 'data'}\nwrite-data={write}\n"
                          "[general]\nlocale=fr\n[other]\ncheck-updates=false\n"
                          "[interface]\nui-scale-mode=manual-pixels\ncustom-ui-scale=1.25\n"
                          "[graphics]\nfull-screen=false\ngraphics-quality=normal\nmax-threads=4\n")
        env = dict(os.environ)
        for key in ("SteamAppId", "SteamGameId", "SteamOverlayGameId", "WAYLAND_DISPLAY", "XAUTHORITY"):
            env.pop(key, None)
        env.update(DISPLAY=display, SDL_VIDEODRIVER="x11")
        base = [str(binary), "--config", str(config), "--mod-directory", str(mods), "--disable-audio"]
        created = subprocess.run(base + ["--create", str(work / "test.zip")], env=env,
                                 capture_output=True, text=True, timeout=60)
        assert created.returncode == 0, created.stdout[-4000:] + created.stderr[-4000:]
        game_log = (work / "game.log").open("w")
        process = subprocess.Popen(base + ["--window-size", "1280x900", "--force-graphics-preset", "very-low",
                                           "--load-game", str(work / "test.zip")], env=env,
                                   stdout=game_log, stderr=subprocess.STDOUT)
        scripts = write / "script-output"
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and not complete_png(scripts / "todo-native-before.png"):
            assert process.poll() is None, (work / "game.log").read_text()[-7000:]
            time.sleep(0.2)
        assert complete_png(scripts / "todo-native-before.png"), (work / "game.log").read_text()[-7000:]
        shutil.copy2(scripts / "todo-native-before.png", output / "todo-native-before.png")
        window = subprocess.check_output(["xdotool", "search", "--onlyvisible", "--pid", str(process.pid)], env=env, text=True).splitlines()[0]
        subprocess.run(["xdotool", "windowfocus", "--sync", window], env=env, check=True)
        subprocess.run(["xdotool", "mousemove", "--window", window, "335", "470"], env=env, check=True)
        time.sleep(0.5)
        subprocess.run(["xdotool", "key", "ctrl+shift+t"], env=env, check=True)
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline and not ((scripts / "todo-native-done.txt").exists()
                                                 and complete_png(scripts / "todo-native-after.png")):
            if process.poll() is not None:
                break
            time.sleep(0.2)
        raw = (scripts / "todo-native-selected.txt").read_text() if (scripts / "todo-native-selected.txt").exists() else "no event"
        assert (scripts / "todo-native-done.txt").exists() and complete_png(scripts / "todo-native-after.png"), raw + "\n" + (work / "game.log").read_text()[-5000:]
        shutil.copy2(scripts / "todo-native-after.png", output / "todo-native-after.png")
        print("REAL FACTOPEDIA KEYBOARD INPUT OK:", raw)
        print(output / "todo-native-after.png")
    finally:
        for child in (process, server):
            if child and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
        server_log.close()
