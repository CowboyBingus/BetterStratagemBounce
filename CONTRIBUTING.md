# Build from source

These instructions are for Windows x64 developers. Players only need the release ZIP and HDArsenal or HD2MM.

## Dependencies

Install Git, Python 3.10+, Go 1.26+, and Visual Studio C++ Build Tools with an x64 Windows SDK. Fetch the pinned sources:

```powershell
python scripts/bootstrap_dependencies.py
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

## Vanilla inputs

Use your own matching installation with the game closed. The builder verifies the EXE, game.dll and extracted resource hashes before compiling. Set `HD2_GAME_ROOT` to your game's absolute installation path:

```powershell
$env:HD2_GAME_ROOT = 'D:/SteamLibrary/steamapps/common/Helldivers 2'
./tools/bin/hd2-resource-extract.exe -game-dir $env:HD2_GAME_ROOT -name 0xf476df93691895fa -type 0xa14e8dfa2cd117e2 -out artifacts/vanilla/boot.lua.main
./tools/bin/hd2-resource-extract.exe -game-dir $env:HD2_GAME_ROOT -name 0x7251fdd9bb62480a -type 0xa14e8dfa2cd117e2 -out artifacts/vanilla/wwise_flow_callbacks.lua.main
```

The extraction tool reads the installation; it does not modify or deploy mods. Extracted files must match the vanilla hashes even if mods are installed.

## Build and verification

```powershell
python scripts/build.py
```

The builder compiles Lua, runs the runtime checks in synthetic local allocations, verifies the original embedded resource, inspects the archive and checks the final ZIP. It writes `releases/BetterStratagemBounce.zip`; intermediates, results and SHA256 are in `build/`. It never installs or launches the game.

Each repository builds independently. To include compatibility tests against the other mod's actual source, set `HD2_HELLPOD_SOURCE` to that repository's absolute root and rebuild. A supplied but invalid peer path is rejected; omission is recorded as interoperability testing not run.

| Optional override | Default |
| --- | --- |
| `HD2_GAME_ROOT` | Standard Steam `common/Helldivers 2` directory |
| `HD2_LUAJIT` | `tools/src/LuaJIT/src/luajit.exe` |
| `HD2_BOOT_RESOURCE` | `artifacts/vanilla/boot.lua.main` |
| `HD2_CALLBACK_RESOURCE` | `artifacts/vanilla/wwise_flow_callbacks.lua.main` |
| `HD2_PATCH_INSPECT` | `tools/bin/hd2-patch-inspect.exe` |

For the optional HDArsenal 0.36.0 backend check, install Node.js and set `HD2_ARSENAL_SOURCE` to an unpacked application containing `obfuscated_src/main` and its bundled `node_modules`. The check uses an isolated profile and filesystem, verifies the icon/description, import, deploy, disable, re-enable and removal. It does not change the live manager profile or game.

## Shared loader verification

Keep `src/shared_loader.lua`, `scripts/wwise.py` and `scripts/archive.py` identical across the two repositories. The optional peer-source build check rejects drift. The coordinator has a fixed version-1 module list; gameplay changes belong in the separate module. Changing the coordinator requires rebuilding and verifying both packages.

After building both, run from either repository:

```powershell
python tests/test_shared_packages.py <Bounce-ZIP> <Hellpod-ZIP>
```

For the optional HUD+ 0.1.3 test, supply privately extracted Lua resources from that package; do not commit them. The harness runs unmodified HUD+ bytecode in an isolated Lua environment and rejects the non-game host for both memory patches:

```powershell
./tools/src/LuaJIT/src/luajit.exe tests/test_hud_compatibility.lua <Bounce-build-folder> <Hellpod-build-folder> <HUD-resources-folder>
```

## Maintaining the mod

Preserve the supported module hashes, layout checks, memory permissions and callback ordering. Updating a game fingerprint alone is insufficient: the relevant native consumers and data layout must be revalidated.

Offline checks do not replace gameplay checks. Check ordinary ground, off-navigation ground, slopes, walls, jammer restrictions, charge/cooldown use and exit behavior. Verify hosting and joining separately before making multiplayer claims.

Commit authored source, tests, dependency pins and the two images. Generated files and local dependencies are ignored. Review staged content and history before publishing; use the CowboyBingus GitHub noreply identity rather than a personal email. Publish release ZIPs separately from source.
