# Build from source

These instructions are for Windows x64 developers. Players need the gameplay ZIP, Bingus Shared Loader, and HDArsenal or HD2MM.

## Dependencies

Install Git, Python 3.10+, Go 1.26+, and Visual Studio C++ Build Tools with an x64 Windows SDK. Fetch the pinned sources:

```powershell
python -B scripts/bootstrap_dependencies.py
```

From an **x64 Native Tools Command Prompt for Visual Studio**, build LuaJIT in the game's bytecode mode:

```bat
cd tools\src\LuaJIT\src
msvcbuild.bat nogc64
```

From the repository root, build the resource tools:

```powershell
go build -mod=mod -o tools/bin/hd2-resource-extract.exe ./cmd/hd2-resource-extract
go build -mod=mod -o tools/bin/hd2-patch-inspect.exe ./cmd/hd2-patch-inspect
```

Use `-mod=mod`: `vendor/filediver` is a pinned source checkout, not a Go-generated vendor directory.

## Supported installation

The builder verifies the supported EXE and game.dll hashes before compiling. Set `HD2_GAME_ROOT` if your installation is outside the standard Steam directory. This gameplay package no longer embeds vanilla boot or Wwise resources; extraction of those fixtures belongs to the separate Bingus Shared Loader build.

## Build and verification

```powershell
python -B scripts/build.py
```

The builder compiles Lua, runs the runtime checks in synthetic local allocations, inspects the archive and checks the final ZIP. It writes `releases/Better-Stratagem-Bounce-v15.zip`; intermediates, results and SHA256 are in `build/`. It never installs or launches the game.

Each repository builds independently. To include compatibility tests against the other mod's actual source, set `HD2_HELLPOD_SOURCE` to that repository's absolute root and rebuild. A supplied but invalid peer path is rejected; omission is recorded as interoperability testing not run.

| Optional override | Default |
| --- | --- |
| `HD2_GAME_ROOT` | Standard Steam `common/Helldivers 2` directory |
| `HD2_LUAJIT` | `tools/src/LuaJIT/src/luajit.exe` |
| `HD2_PATCH_INSPECT` | `tools/bin/hd2-patch-inspect.exe` |

For the optional HDArsenal 0.36.0 backend check, install Node.js and set `HD2_ARSENAL_SOURCE` to an unpacked application containing `obfuscated_src/main` and its bundled `node_modules`. The check uses an isolated profile and filesystem, verifies the icon/description, import, deploy, disable, re-enable and removal. It does not change the live manager profile or game.

## Shared loader verification

`scripts/module.py` builds only this mod's named resource. The standalone Bingus Shared Loader project owns the coordinator and composition tests. No runtime loader source needs to be synchronized between gameplay repositories.

After building the loader and gameplay packages, run from the Bingus Shared Loader repository:

```powershell
python -B tests/test_shared_packages.py <Loader-ZIP> <Bounce-ZIP> <Hellpod-ZIP> [<Reinforcement-ZIP>]
<LuaJIT> tests/test_hud_compatibility.lua <Loader-build> <Bounce-build> <Hellpod-build> <HUD-resources> [<Reinforcement-build>]
```

The HUD fixture must be privately extracted from the tested HUD+ package; do not commit it. Its unmodified bytecode runs in an isolated Lua environment that rejects the non-game host for memory patches.

## Maintaining the mod

Preserve the supported module hashes, layout checks, memory permissions and callback ordering. Updating a game fingerprint alone is insufficient: the relevant native consumers and data layout must be revalidated.

Offline checks do not replace gameplay checks. Check ordinary ground, off-navigation ground, slopes, walls, jammer restrictions, charge/cooldown use and exit behavior. Verify hosting and joining separately before making multiplayer claims.

Commit authored source, tests, dependency pins and the two images. Generated files and local dependencies are ignored. Review staged content and history before publishing; use the CowboyBingus GitHub noreply identity rather than a personal email. Publish release ZIPs separately from source.

For this release preparation, a clean allowlisted source snapshot is exported separately from the working repository. Keep local research, generated outputs, manager profiles and prior Git history outside the upload. No repository-wide license has been selected.
