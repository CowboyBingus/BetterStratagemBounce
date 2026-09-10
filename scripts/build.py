"""Build and verify Better Stratagem Bounce without launching the game."""
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

from archive import BOOT, BOOT_SHA, LUA, make_archive, sha, EXE_SHA, GAME_DLL_SHA, GAME, ARCHIVE
from package import package_release

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src'
TESTS = ROOT / 'tests'
REVISION = 'archive-v12'
INSPECTOR = Path(os.environ.get('HD2_PATCH_INSPECT', ROOT / 'tools/bin/hd2-patch-inspect.exe'))


def run(arguments, **kwargs):
    result = subprocess.run([str(value) for value in arguments], capture_output=True, text=True, **kwargs)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def main():
    revision = REVISION
    build = ROOT / 'build'
    for relative, expected in [('bin/helldivers2.exe', EXE_SHA), ('data/game/game.dll', GAME_DLL_SHA)]:
        if sha((GAME / relative).read_bytes()) != expected:
            raise ValueError('Unsupported game build: ' + relative)
    vanilla = BOOT.read_bytes()
    if sha(vanilla) != BOOT_SHA or struct.unpack('<II', vanilla[:8]) != (326, 2):
        raise ValueError('Vanilla boot resource changed')
    build.mkdir(parents=True, exist_ok=True)
    literal = '"' + ''.join(f'\\{byte:03d}' for byte in vanilla[8:]) + '"'
    wrapper = f"assert(loadstring({literal}, '@vanilla_boot'))()\n"
    for variable, name in [('create_api', 'windows_api.lua'), ('patch', 'navigation_patch.lua'),
                           ('install_loader', 'archive_loader.lua')]:
        wrapper += f'local {variable} = (function()\n' + (SOURCE / name).read_text(encoding='utf-8') + '\nend)()\n'
    wrapper += "install_loader(create_api, patch, {revision = '" + revision + "', exe_sha256 = '" + EXE_SHA
    wrapper += "', game_sha256 = '" + GAME_DLL_SHA + "'})\n"
    (build / 'boot.wrapper.lua').write_text(wrapper, encoding='utf-8')
    env = dict(os.environ, LUA_PATH=str(LUA.parent / '?.lua') + ';;')
    run([LUA, '-bsdW', build / 'boot.wrapper.lua', build / 'boot.ljbc'], env=env)
    bytecode = (build / 'boot.ljbc').read_bytes()
    if bytecode[:5] != vanilla[8:13]:
        raise ValueError('LuaJIT bytecode mode differs from the game')
    tests = run([LUA, TESTS / 'test_archive.lua', SOURCE, build / 'boot.ljbc', sha(LUA.read_bytes())], env=env)
    peer = os.environ.get('HD2_HELLPOD_SOURCE')
    peer_source = Path(peer).resolve() / 'src' if peer else None
    interop_tests = []
    if peer_source is not None:
        if not (peer_source / 'windows_api.lua').is_file():
            raise ValueError('HD2_HELLPOD_SOURCE must point to the Hellpod source repository')
        for order in ('hellpod-ball', 'ball-hellpod'):
            interop_tests.append(run([LUA, TESTS / 'test_windows_interop.lua', SOURCE, peer_source,
                                      order, build / 'boot.ljbc', sha(LUA.read_bytes())], env=env))
    (build / 'offline-tests.txt').write_text(tests + ''.join(interop_tests), encoding='utf-8')
    resource = struct.pack('<II', len(bytecode), 2) + bytecode
    (build / 'boot.lua.main').write_bytes(resource)
    (build / ARCHIVE).write_bytes(make_archive(resource))
    for suffix in ('.stream', '.gpu_resources'):
        (build / (ARCHIVE + suffix)).write_bytes(b'')
    run([INSPECTOR, '--patch', build / ARCHIVE, '--out', build / 'archive-inspection.json',
         '--extract-dir', build / 'archive-resources'])
    inspection = json.loads((build / 'archive-inspection.json').read_text(encoding='utf-8'))
    resources = inspection['resources']
    if (inspection['num_files'] != 1 or len(resources) != 1 or
            resources[0]['name']['hex'] != '0xf476df93691895fa' or
            resources[0]['type']['hex'] != '0xa14e8dfa2cd117e2'):
        raise ValueError('Archive must replace only the existing boot Lua resource')
    files = {f'data/{ARCHIVE}{suffix}': f'build/{ARCHIVE}{suffix}'
             for suffix in ('', '.stream', '.gpu_resources')}
    report = {
        'revision': revision, 'delivery': 'archive', 'runtime_verified': False,
        'status': 'offline_verified_gameplay_pending', 'game_exe_sha256': EXE_SHA,
        'game_dll_sha256': GAME_DLL_SHA, 'deployment_files': files,
        'files': {path: sha((ROOT / path).read_bytes()) for path in files.values()},
        'vanilla_boot_sha256': BOOT_SHA, 'vanilla_boot_embedded_unchanged': True,
        'custom_dlls': 0, 'encrypted_settings_changed': False, 'integrity_checks_changed': False,
        'executable_memory_changed': False,
        'patch': {'target': 'loaded StratagemInfo data', 'flag_offset': '0x170',
                  'mask_cleared': '02', 'records': 147, 'changed_flags': 101},
        'continuous_update_hook': False, 'shutdown_hook': False, 'offline_tests': tests.strip().splitlines()[-1],
        'windows_adapter_interop': {'tested': bool(interop_tests),
                                    'orders': [result.splitlines()[0] for result in interop_tests]},
    }
    report.update(name='Better Stratagem Bounce', slug='BetterStratagemBounce',
                  guid='b47a63e0-9559-4bfb-a856-c816425af1d0',
                  description='Lets stratagem balls stick and activate on more surfaces instead of bouncing away.')
    sources = list(SOURCE.glob('*.lua')) + list(TESTS.glob('*.lua')) + list((ROOT / 'scripts').glob('*.py'))
    report['source_sha256'] = {path.relative_to(ROOT).as_posix(): sha(path.read_bytes()) for path in sources}
    release = package_release(ROOT, build, report)
    package_tests = run([sys.executable, TESTS / 'test_package.py', release])
    (build / 'package-tests.txt').write_text(package_tests, encoding='utf-8')
    report['package_tests'] = package_tests.strip().splitlines()[-1]
    arsenal_source = os.environ.get('HD2_ARSENAL_SOURCE')
    if arsenal_source:
        manager_tests = run(['node', ROOT / 'scripts/test_arsenal_archive.cjs', release,
                             arsenal_source, build])
        report['arsenal_tests'] = json.loads((build / 'arsenal-compatibility.json').read_text(encoding='utf-8'))
        print(manager_tests.strip())
    report['release'] = {'path': release.relative_to(ROOT).as_posix(), 'sha256': sha(release.read_bytes())}
    (build / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(tests.strip())
    for result in interop_tests: print(result.splitlines()[0])
    print(package_tests.strip())
    print('Built ' + release.name + '; no installation or game launch performed.')


if __name__ == '__main__':
    main()
