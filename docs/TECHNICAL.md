# How Better Stratagem Bounce works

The game tests more than whether a stratagem ball has touched something solid. For stratagems with `deploy_on_navmesh_only` enabled, its collision handler also checks the navigation mesh. A solid roof or rock can fail that check, so the ball keeps bouncing.

The mod clears that navigation requirement in the loaded stratagem definitions. It lets the game's existing collision, attachment and deployment path handle the result.

## Runtime scope

The supported `game.dll` tests `StratagemInfo +0x170` with mask `0x02` at RVA `0x69CD25`. `src/navigation_patch.lua` clears that bit in the 101 definitions that enable it, out of 147 records in an eleven-group, 79,296-byte settings buffer.

Before writing, it verifies the complete layout, record identities, table pointers and expected flags. The Windows adapter accepts only committed, writable, private data. The patch rechecks its snapshot before writing and verifies the entire buffer afterward. Recovery after a partial failure is limited to records that still match the expected state.

The earlier normal-Z comparison against `0.7` remains, so the native contact limit is about 45.6 degrees from horizontal. Separate location/entity checks and the native deployment path remain. The mod does not directly accept a landing or change cooldown/charge fields. Other consumers of the navigation flag also see its cleared value; these implementation boundaries do not themselves prove every jammer or multiplayer case behaves correctly.

## Startup and lifecycle

`scripts/build.py` verifies the original `boot` resource and embeds its bytecode unchanged before the three runtime modules. LuaJIT compiles the wrapper with debug information stripped. The archive replaces Lua resource `f476df93691895fa`, type `a14e8dfa2cd117e2`.

`src/archive_loader.lua` verifies both game-module SHA256 values, applies the settings change on the first update and removes its wrapper when it still owns that callback. It preserves an existing callback chain and installs no shutdown callback. The process owns the changed memory; removing the archive prevents the edit on the next launch.

The game reads the underlying stratagem settings through a separate loose-file loader with a content check. This implementation leaves that file and the check intact. The built-in Lua interface accesses the already loaded data through Windows APIs; no custom DLL is shipped and no executable pages are modified.

## Tests and evidence

The runtime suite uses synthetic allocations to verify layout rejection, memory permissions, the exact 101-bit scope, partial-write recovery and callback behavior. It also executes the compiled wrapper to check preservation of the original boot code. Package checks verify the archive identity, payload hashes, Arsenal manifest, artwork and relocation.

With `HD2_HELLPOD_SOURCE` set, fresh LuaJIT processes test both actual Windows adapters in both initialization orders. Their FFI declarations share one VM; explicit `void *` handling avoids conflicting structure-pointer declarations. No peer source is required for a standalone build.

The user has reported the two mods working together. Remaining validation must distinguish first-impact sticking, native slope rejection, payload clearance, jammer/cooldown behavior and host/client ownership. Offline success establishes code and package properties, not all gameplay outcomes.

Both module fingerprints and vanilla resource fingerprints are in `scripts/archive.py`; the native layout and expected flags are in `src/navigation_patch.lua`. They must be revalidated together when the game updates.
