import ctypes
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def validate():
    lua = ctypes.CDLL("liblua5.2.so.0")
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    lua.luaL_loadfilex.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    files = sorted(path for path in ROOT.rglob("*.lua") if not {"dist", ".tools"}.intersection(path.parts))
    references = set()
    for path in files:
        state = lua.luaL_newstate()
        if not state:
            raise RuntimeError("Impossible de créer le compilateur Lua.")
        try:
            if lua.luaL_loadfilex(state, str(path).encode(), None):
                raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
        finally:
            lua.lua_close(state)
        references.update(re.findall(r'["\'](todo\.[\w-]+)["\'](?!\s*\.\.)', path.read_text()))
    locales = []
    for language in ("fr", "en"):
        keys, section = set(), None
        for line in (ROOT / "locale" / language / "todo-manager.cfg").read_text().splitlines():
            if line.startswith("["):
                section = line[1:-1]
            elif "=" in line and not line.startswith(";"):
                key = section + "." + line.split("=", 1)[0]
                if key in keys:
                    raise RuntimeError(f"Clé de traduction dupliquée : {language}/{key}")
                keys.add(key)
        if references - keys:
            raise RuntimeError(f"Traductions absentes ({language}) : {sorted(references - keys)}")
        locales.append(keys)
    if locales[0] != locales[1]:
        raise RuntimeError("Les catalogues français et anglais n'ont pas les mêmes clés.")
    print(f"Syntaxe Lua 5.2 : {len(files)} fichiers OK ; traductions FR/EN : OK", flush=True)


if __name__ == "__main__":
    validate()
