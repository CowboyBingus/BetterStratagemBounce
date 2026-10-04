# How Better Stratagem Bounce works

The game tests more than whether a stratagem ball has touched something solid. For stratagems with `deploy_on_navmesh_only` enabled, its collision handler also checks the navigation mesh. A solid roof or rock can fail that check, so the ball keeps bouncing.

The mod clears that navigation requirement in the loaded stratagem definitions. It lets the game's existing collision, attachment and deployment path handle the result.

## Runtime scope

The supported `game.dll` tests `StratagemInfo +0x170` with mask `0x02` at RVA `0x69CD25`. `src/navigation_patch.lua` clears that bit in the 103 definitions that enable it on the supported build, out of 149 records in an eleven-group, 80,280-byte settings buffer.

Before writing, it verifies the complete layout, record identities and table pointers. Of each record's navigation flags it checks and writes only the bit it owns: the other bits may hold another mod's changes, and a bit another mod has already cleared is accepted as it is, never written and never restored by this mod. The Windows adapter accepts only committed, writable, private data, checked once for the whole buffer right before the writes. The patch rechecks its snapshot before writing and verifies the entire buffer afterward. Recovery after a partial failure sets the bit again only in records this mod changed, where it is still clear and the record is still the same stratagem; every other bit keeps its current value.

The earlier normal-Z comparison against `0.7` remains, so the native contact limit is about 45.6 degrees from horizontal. Separate location/entity checks and the native deployment path remain. The mod does not directly accept a landing or change cooldown/charge fields. Other consumers of the navigation flag also see its cleared value; these implementation boundaries do not themselves prove every jammer or multiplayer case behaves correctly.

## Startup and lifecycle

`scripts/module.py` compiles one named Lua resource containing Bingus Shared Runtime v1 (github.com/CowboyBingus/BingusSharedRuntime; `src/bingus_runtime.lua`, the core, `src/bingus_memory.lua`, the read side, and `src/bingus_write.lua`, the checked writes, kept byte-identical across mods), this mod's Windows adapter, gameplay patch and lifecycle code. The mod uses the runtime's memory api only; its one-shot loader keeps its own update wrapper (below). It contains no Wwise or boot override. The separately installed Bingus Shared Loader owns Wwise initialization, preserving the original callbacks before requiring installed gameplay modules. See [startup compatibility](COMPATIBILITY.md).

`src/archive_loader.lua` verifies both game-module SHA256 values, applies the settings change on the first update and removes its wrapper when it still owns that callback. It preserves an existing callback chain and installs no shutdown callback. The process owns the changed memory; removing the archive prevents the edit on the next launch.

The earlier update runs outside `pcall`, so its errors reach the game unchanged, and errors in updates below this mod leave the applied change alone. The first refusal or failed apply stops the mod for the session; a failed apply first puts back only this mod's bit. The mod deliberately does not use the runtime's update guard, which pauses a mod after an error below and applies it again later: for a one-shot edit of static data that would only toggle the flags, and a burst of errors would turn the mod off for the session.

The game reads the underlying stratagem settings through a separate loose-file loader with a content check. This implementation leaves that file and the check intact. The built-in Lua interface accesses the already loaded data through Windows APIs; no custom DLL is shipped and no executable pages are modified.

## Tests and evidence

The runtime suite uses synthetic allocations to verify layout rejection, memory permissions, the exact 103-bit scope, coexistence with another mod's flag changes, partial-write recovery, the first-frame and idle call budget and callback behavior. The separate loader project tests original audio callbacks and module-presence combinations. Package checks verify the archive identity, payload hashes, Arsenal manifest, artwork and relocation.

With `HD2_HELLPOD_SOURCE` set, fresh LuaJIT processes test both actual Windows adapters in both initialization orders, with whatever the Hellpod source vendors: no shared runtime (its published releases), the single-file runtime or the three-file runtime. This mod's adapter declares its Windows functions only under the runtime's private FFI names, so another mod's declarations cannot change them. No peer source is required for a standalone build.

In live play the module loads through the separate loader and applies its navigation settings. First-impact sticking, native slope rejection, payload clearance, jammer/cooldown behavior and host/client ownership need separate in-game checks.

Game-module fingerprints are in `scripts/archive.py`; Wwise validation belongs to the separate loader; the native layout and expected flags are in `src/navigation_patch.lua`. They must be revalidated together when the game updates.
