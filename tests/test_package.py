"""Verify the release ZIP, including HDArsenal's archive option and artwork."""
import hashlib
import json
from pathlib import Path
import struct
import zlib
import sys
import tempfile
import zipfile


def main():
    archive_name = '9ba626afa44a3aa3.patch_0'
    with zipfile.ZipFile(sys.argv[1]) as package:
        payloads = {name: package.read(name) for name in package.namelist()}
        expected = {f'data/{archive_name}{suffix}' for suffix in ('', '.stream', '.gpu_resources')}
        expected |= {'manifest.json', 'BetterStratagemBounce-manifest.json', 'BetterStratagemBounce-README.txt', 'thumbnail.png'}
        assert set(payloads) == expected and len(package.namelist()) == len(expected)
        assert not any(name.lower().endswith(('.dll', '.exe', '.lua', '.ps1')) for name in payloads)
        manifest = json.loads(payloads['manifest.json'])
        assert manifest['Name'] == 'Better Stratagem Bounce'
        assert manifest['Options'] == [{'Name': 'Better Stratagem Bounce', 'Include': ['data'], 'Image': 'thumbnail.png'}]
        assert manifest['IconPath'] == 'thumbnail.png'
        assert payloads['thumbnail.png'].startswith(b'\x89PNG\r\n\x1a\n')
        png, offset = payloads['thumbnail.png'], 8
        while offset < len(png):
            size = int.from_bytes(png[offset:offset + 4], 'big')
            kind = png[offset + 4:offset + 8]
            assert kind in (b'IHDR', b'IDAT', b'IEND')
            end = offset + 8 + size
            assert end + 4 <= len(png)
            assert zlib.crc32(png[offset + 4:end]) == int.from_bytes(png[end:end + 4], 'big')
            offset = end + 4
        assert offset == len(png)
        provenance = json.loads(payloads['BetterStratagemBounce-manifest.json'])
        assert provenance['revision'] == 'archive-v12' and provenance['runtime_verified'] is False
        for name, digest in provenance['files'].items():
            assert hashlib.sha256(payloads[name]).hexdigest().upper() == digest
        main = payloads['data/' + archive_name]
        assert struct.unpack_from('<III', main) == (0xF0000011, 1, 1)
        assert struct.unpack_from('<QQ', main, 104) == (0xF476DF93691895FA, 0xA14E8DFA2CD117E2)
        assert payloads['data/' + archive_name + '.stream'] == b''
        assert payloads['data/' + archive_name + '.gpu_resources'] == b''
        for data in payloads.values():
            lowered = data.lower()
            assert b'users\\' not in lowered and b'users/' not in lowered
            assert b'asset-key' not in lowered and b'hd2_native_stick.dll' not in lowered
            assert b'virtualprotect' not in lowered and b'flushinstructioncache' not in lowered
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / 'An unrelated install location'
            package.extractall(destination)
            assert all((destination / name).read_bytes() == data for name, data in payloads.items())
    print('PASS: archive contents, HDArsenal manifest, hashes, resource identity, privacy and relocation')
    print('6 package checks passed; ZIP contains three runtime archive files and no custom DLL.')


if __name__ == '__main__':
    main()
