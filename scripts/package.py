"""Create a reproducible mod-manager ZIP from verified build outputs."""
import hashlib
import json
from pathlib import Path
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest().upper()


def package_release(root: Path, build: Path, report: dict) -> Path:
    files = {}
    for destination, source in report['deployment_files'].items():
        data = (root / source).read_bytes()
        if digest(data) != report['files'][source]:
            raise ValueError('Build output changed before packaging: ' + source)
        files[destination] = data
    slug = report['slug']
    files[slug + '-README.txt'] = (root / 'INSTALL.txt').read_bytes()
    files['thumbnail.png'] = (root / 'assets/thumbnail.png').read_bytes()
    provenance = {
        'name': report['name'], 'revision': report['revision'],
        'steam_build': 24826606, 'exe_version': '1.8.45317.0',
        'game_exe_sha256': report['game_exe_sha256'],
        'game_dll_sha256': report['game_dll_sha256'],
        'runtime_verified': False,
        'files': {name: digest(data) for name, data in files.items()},
    }
    files[slug + '-manifest.json'] = (json.dumps(provenance, indent=2) + '\n').encode()
    files['manifest.json'] = (json.dumps({
        'Version': 1, 'Guid': report['guid'], 'Name': report['name'], 'Description': report['description'],
        'IconPath': 'thumbnail.png',
        'Options': [{'Name': report['name'], 'Description': report['description'],
                     'Include': ['data'], 'Image': 'thumbnail.png'}],
    }, indent=2) + '\n').encode()
    release = root / 'releases' / (slug + '.zip')
    release.parent.mkdir(exist_ok=True)
    temporary = build / 'release.pending.zip'
    with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    temporary.replace(release)
    (build / (release.name + '.sha256')).write_text(digest(release.read_bytes()) + '  ' + release.name + '\n')
    return release
