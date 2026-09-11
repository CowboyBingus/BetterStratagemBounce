# Better Stratagem Bounce — archive-v15

Prepared for the Bingus Shared Loader release. The manager description, dependency metadata, installation instructions and compatibility notes now use the loader's new name. The gameplay Lua, manager GUID, resource identity and runtime revision are unchanged.

Install `BetterStratagemBounce.zip` with `BingusSharedLoader.zip` (loader-v2 / API 1). With the game closed, replace old library entries, Purge, then Deploy. Remove older gameplay packages that bundled their own loader. Managers do not fetch dependencies automatically.

The existing banner and square Arsenal cover are retained. Source exports exclude private research, game resources, manager profiles, generated outputs and Git history.

Offline regression, callback interoperability, combined HUD/resource ownership and isolated Arsenal/HD2MM deployment checks validate this release preparation. Gameplay validation of the packaging transition remains pending; retain prerelease status until that is confirmed.

Reinforcement Beacons Fixed is an optional separate mod. Its installed multiplayer behavior remains unverified and a small solo landing offset is unresolved.

[Download this release](https://github.com/CowboyBingus/BetterStratagemBounce/releases/tag/archive-v15) · [Download the required loader](https://github.com/CowboyBingus/BingusSharedLoader/releases/tag/loader-v2)
