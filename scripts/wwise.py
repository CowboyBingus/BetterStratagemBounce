"""Build the identical coordinator and one independently owned mod resource."""
import os
from pathlib import Path
import struct
import subprocess

from archive import BOOT, BOOT_SHA, LUA, EXE_SHA, GAME_DLL_SHA, sha, resource_hash

CALLBACK_SHA = '05BBF52978028758B39F5B91A30A695D20069CEABD774D88755F0582A296BEC9'
CALLBACK_PATH = 'core/wwise/lua/wwise_flow_callbacks'
CALLBACK_NAME = 0x7251FDD9BB62480A


def build_resources(root, build, module_name, patch_name, revision):
    callback = Path(os.environ.get('HD2_CALLBACK_RESOURCE',
                    root / 'artifacts/vanilla/wwise_flow_callbacks.lua.main')).read_bytes()
    boot = BOOT.read_bytes()
    if sha(boot) != BOOT_SHA or struct.unpack('<II', boot[:8]) != (326, 2):
        raise ValueError('Vanilla boot resource changed')
    if sha(callback) != CALLBACK_SHA or struct.unpack('<II', callback[:8]) != (10263, 2):
        raise ValueError('Vanilla audio callback resource changed')
    build.mkdir(parents=True, exist_ok=True)
    (build / 'vanilla-boot.ljbc').write_bytes(boot[8:])
    (build / 'vanilla-callbacks.ljbc').write_bytes(callback[8:])
    literal = '"' + ''.join(f'\\{byte:03d}' for byte in callback[8:]) + '"'
    coordinator = f"assert(loadstring({literal}, '@vanilla_wwise_callbacks'))()\n"
    coordinator += (root / 'src/shared_loader.lua').read_text(encoding='utf-8')
    module = ''
    for variable, filename in [('create_api', 'windows_api.lua'), ('patch', patch_name),
                               ('install_loader', 'archive_loader.lua')]:
        code = (root / 'src' / filename).read_text(encoding='utf-8')
        for forbidden in ('VirtualProtect', 'FlushInstructionCache', 'CreateRemoteThread', 'LoadLibrary'):
            if forbidden in code:
                raise ValueError(f'Forbidden code-modification API in {filename}: {forbidden}')
        module += f'local {variable} = (function()\n{code}\nend)()\n'
    module += f"install_loader(create_api, patch, {{revision = '{revision}', "
    module += f"exe_sha256 = '{EXE_SHA}', game_sha256 = '{GAME_DLL_SHA}'" + '})\n'
    resources = {}
    env = dict(os.environ, LUA_PATH=str(LUA.parent / '?.lua') + ';;')
    for stem, name, source in [('callbacks', CALLBACK_PATH, coordinator), ('mod', module_name, module)]:
        path = build / (stem + '.wrapper.lua')
        path.write_text(source, encoding='utf-8', newline='\n')
        bytecode_path = build / (stem + '.ljbc')
        subprocess.run([str(LUA), '-bsdW', str(path), str(bytecode_path)], env=env, check=True)
        bytecode = bytecode_path.read_bytes()
        if bytecode[:5] != callback[8:13]:
            raise ValueError('LuaJIT bytecode mode differs from the game')
        resource = struct.pack('<II', len(bytecode), 2) + bytecode
        (build / (stem + '.lua.main')).write_bytes(resource)
        resources[resource_hash(name)] = resource
    return resources


def verify_peer(root, peer_source):
    peer = peer_source.parent
    for relative in ('src/shared_loader.lua', 'scripts/wwise.py', 'scripts/archive.py'):
        if (root / relative).read_bytes() != (peer / relative).read_bytes():
            raise ValueError('Shared-loader sources differ between repositories: ' + relative)
