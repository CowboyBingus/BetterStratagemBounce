# Startup compatibility

Current gameplay packages require **Bingus Shared Loader**, installed and enabled separately. They do not require one another. The loader has no gameplay effect on its own.

| Package | Sole Lua resource |
| --- | --- |
| Bingus Shared Loader | `core/wwise/lua/wwise_flow_callbacks` |
| Better Stratagem Bounce | `mods/cowboybingus/better_stratagem_bounce` |
| Hellpod Steering Unlocked | `mods/cowboybingus/hellpod_steering_unlocked` |
| Reinforcement Beacons Fixed | `mods/cowboybingus/reinforcement_beacon_fix_data` |

These packages have no resource overlap. A loader update requires replacing only BingusSharedLoader.zip. Gameplay changes remain in their respective packages. API 1 has an explicit list of optional module names; adding another module name requires a loader update, not rebuilding existing gameplay packages.

The loader executes the original Wwise callbacks, then checks `stingray.Application.can_get('lua', name)` before requiring each installed module. Missing modules are skipped, Lua errors are isolated, and initialization runs once per Lua VM. It neither changes gameplay memory nor installs update or shutdown callbacks itself. Gameplay modules retain their own validated data writes and lifecycle behavior.

## HUD+ and other mods

None of these packages replaces `boot`. The inspected HUD+ 0.1.3 boot preserves the initialization that reaches Wwise; its original bytecode and optional fragments pass the isolated startup test with each Bounce/Steering combination. No HUD+ code is redistributed. Rendering and gameplay still require in-game validation.

Another Wwise replacement can still conflict with Bingus Shared Loader. A boot replacement that omits Wwise initialization also prevents startup. The manager does not automatically merge Lua code. Changing ownership removes overlap between our packages; it does not solve arbitrary third-party startup conflicts.

## Upgrade and removal

Close the game, remove old library entries, purge deployment, then import BingusSharedLoader.zip and the current gameplay ZIPs. Enable the loader and the gameplay mods you want, then deploy using one manager. Managers do not automatically install or enforce this dependency.

Do not mix these module-only packages with older releases that bundled a coordinator. An older Wwise override can win load order and select its older module list. Remove old manual installations before using a manager. Do not enable withdrawn native reinforcement prototypes. The current Reinforcement Beacons Fixed data-v3 prerelease is an optional module; each diver needs it locally for their own pod.

Disabling a gameplay mod removes its distinct resource. Keep the loader while any dependent mod remains. Removing the loader leaves module resources without a startup caller, so the mods will not activate. A fresh game process is required after every deployment change.

## Verification

The local candidates are Bingus Shared Loader loader-v2, Bounce archive-v15, Steering data-v7 and Reinforcement Beacons Fixed data-v3 prerelease. Tests verify distinct resource ownership, all load orders and removal subsets, optional-module failures, repeated initialization, original audio callbacks and the HUD+ update chain. Both gameplay modules retain their synthetic memory, permission and recovery tests. Manager backend verification uses isolated libraries and game folders; it does not edit live manager profiles.

Gameplay validation of this packaging transition remains pending. Package and startup tests do not establish jammer behavior, every terrain contact, multiplayer ownership or anti-cheat acceptance of unrelated native prototypes.

Bingus Shared Loader was formerly Shared Mod Loader. Its manager GUID, API marker and module resource names remain unchanged. Install only one copy of the loader. Reinforcement multiplayer verification is pending and a small solo landing offset remains unresolved.
