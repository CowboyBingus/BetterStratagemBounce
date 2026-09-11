"""Check both published layouts as the engine's last-resource-wins map."""
from pathlib import Path
import struct
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from archive import resource_hash


def resources(path):
    with zipfile.ZipFile(path) as package:
        data = package.read('data/9ba626afa44a3aa3.patch_0')
    assert struct.unpack_from('<III', data) == (0xF0000011, 1, 2)
    result = {}
    for index in range(2):
        entry = struct.unpack_from('<7Q6I', data, 104 + index * 80)
        assert entry[1] == 0xA14E8DFA2CD117E2 and entry[0] not in result
        result[entry[0]] = data[entry[2]:entry[2] + entry[7]]
    return result


def main():
    bounce, hellpod = map(resources, sys.argv[1:3])
    assert resource_hash('boot') == 0xF476DF93691895FA
    shared = resource_hash('core/wwise/lua/wwise_flow_callbacks')
    assert shared == 0x7251FDD9BB62480A
    assert set(bounce) == {shared, resource_hash('mods/cowboybingus/better_stratagem_bounce')}
    assert set(hellpod) == {shared, resource_hash('mods/cowboybingus/hellpod_steering_unlocked')}
    assert bounce.keys() & hellpod.keys() == {shared}
    assert bounce[shared] == hellpod[shared], 'The shared loader must be byte-for-byte identical'
    expected = {**bounce, **hellpod}
    for installed in ([bounce, hellpod], [hellpod, bounce]):
        active = {}
        for package in installed:
            active.update(package)
        assert active == expected
    for remaining in (bounce, hellpod):
        assert len(remaining) == 2 and remaining[shared] == expected[shared]
    print('PASS: identical shared loader, unique modules, either override order and independent removal')


if __name__ == '__main__':
    main()
