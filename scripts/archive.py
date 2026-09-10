"""Supported game inputs and single-resource archive encoding."""
import hashlib
import os
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get('HD2_GAME_ROOT', r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2'))
LUA = Path(os.environ.get('HD2_LUAJIT', ROOT / 'tools/src/LuaJIT/src/luajit.exe'))
BOOT = Path(os.environ.get('HD2_BOOT_RESOURCE', ROOT / 'artifacts/vanilla/boot.lua.main'))
BOOT_SHA = '85D7C6A9981E3288286C63BDB75E4256DCF859D6FC5F712CB72E9B329B1712E6'
EXE_SHA = 'A09FF52663E73B94FB0CAC0DCB5BA84FFD10ECF44F74A8921AC66AF923988CC3'
GAME_DLL_SHA = 'CC75948D90FDFDE259DCB519E9933DB7FFA3CCB281CE4FB89E6B1B011557470C'
ARCHIVE = '9ba626afa44a3aa3.patch_0'
NAME, TYPE = 0xF476DF93691895FA, 0xA14E8DFA2CD117E2


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def make_archive(resource, name=NAME):
    offset = 192
    size = offset + len(resource)
    header = struct.pack('<III20sQQ24s', 0xF0000011, 1, 1, b'', (size + 15) & ~15, 0, b'')
    types = struct.pack('<IIQIIII', 0, 0, TYPE, 1, 0, 16, 16)
    entry = struct.pack('<7Q6I', name, TYPE, offset, 0, 0, 0, 0, len(resource), 0, 0, 16, 16, 0)
    return (header + types + entry).ljust(offset, b'\0') + resource
