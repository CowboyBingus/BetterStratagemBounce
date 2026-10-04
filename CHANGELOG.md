# v15.4

- The one-time settings check at the first update builds its expected bytes once instead of once per changed flag, cutting that frame's short-lived Lua strings from about 16 MB to about 0.6 MB. A test keeps it under 2 MB.
- The same one-time settings change checks memory protection once for the whole settings buffer instead of 104 times. In game each check costs about 0.3 ms.
- Works alongside mods that change other stratagem navigation flags or already cleared the same one: it checks and changes only its own bit instead of stopping when any flag byte differs. After a failed write it puts back only that bit.
- Calls Windows through Bingus Shared Runtime v1 under private, versioned names, so another mod's declarations of the same Windows functions can no longer change this mod's calls. Each game module's hash is read once per session for every mod that uses the runtime.
- Requires Bingus Shared Loader v18 or newer (v19 is current).
- Now licensed under the Zero-Clause BSD license (0BSD).
- Measured in live play: 0.001 ms per frame in missions and 0.001 ms on the ship.

# v15.3.1

- Documentation-only release: the mod is identical to v15.3 (same compiled resource).
- Rewrites the install notes packaged with the mod and the README status: one current status line instead of the compatibility-candidate and test-build notes left from the game-build update. In live play the mod loads and applies its stratagem navigation settings.
- Lists one loader requirement, Bingus Shared Loader v18.

# v15.3

- Support Steam build 25480438 with updated game-module guards.
- Keep the supported stratagem settings and bounce behavior.
- Offline builds and package checks pass; live gameplay validation remains pending.

# v15.2

- Update compatibility for game build 25327279.
- Refresh the supported stratagem records.

# v15.1

- Moves logs to `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`.
- Requires Bingus Shared Loader v14 for the shared log folder.
