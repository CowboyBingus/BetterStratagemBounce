# Startup resource compatibility

Both mods share an identical replacement for `core/wwise/lua/wwise_flow_callbacks`. Vanilla boot calls it during `init()`. The coordinator executes the original audio callbacks unchanged, then loads each installed mod's separate Lua resource:

| Owner | Lua resource |
| --- | --- |
| Shared coordinator | `core/wwise/lua/wwise_flow_callbacks` |
| Better Stratagem Bounce | `mods/cowboybingus/better_stratagem_bounce` |
| Hellpod Steering Unlocked | `mods/cowboybingus/hellpod_steering_unlocked` |

Each ZIP contains the coordinator and only its own module. Either package supplies the same coordinator bytes, so their load order does not matter. Disabling one mod removes its module while the remaining package supplies the coordinator. A manager may still flag their shared resource as an overlap; it is intentional for these matching releases.

The coordinator checks `stingray.Application.can_get('lua', name)` before `require(name)`, so an absent module is skipped. It initializes once per Lua VM and contains each module's Lua failure independently. It does not enable global autoloading, scan files, change engine configuration or install shutdown callbacks. Adding an arbitrary resource still does not make it execute: this coordinator supplies the explicit caller.

## HUD+ and other mods

Neither package overrides `boot`. The inspected HD2 HUD+ 0.1.3 package owns `boot` and preserves the vanilla initialization that reaches Wwise. Its unmodified boot and optional Lua fragments pass an offline execution test with neither, either and both of these modules, preserving the HUD update chain. No HUD+ code is bundled. This establishes startup composition; HUD rendering and combined gameplay still need an in-game test.

An unrelated mod replacing Wwise still needs a compatible coordinator or a merged resource. A boot mod that omits vanilla Wwise initialization will also prevent these modules from starting. Mod managers do not automatically merge Lua implementations. A future HUD+ update needs reassessment if it changes these startup assumptions or replaces another resource we own.

## Updating and rollback

When using both mods, update both to the shared-loader releases: Better Stratagem Bounce `archive-v13` and Hellpod Steering Unlocked `data-v5`. Remove their older entries, purge deployment, import the two new ZIPs and redeploy enabled mods. Do not mix an older Hellpod Wwise implementation with the new Bounce package. Either new mod remains usable by itself.

To roll back, close the game, remove the new entries and redeploy the saved prior packages together. The changes affect process memory; restarting without a mod restores its vanilla behavior. Keep prior ZIPs outside active deployment.

## Verification

The supported game loaded both new resource names at startup. Bounce reported its exact 101-flag edit, and Hellpod reported the expected ship state, `waiting_for_mission`. No gameplay was performed. Offline tests cover absent modules, lookup/module failures, duplicate initialization, original audio callbacks, update arguments/returns, both package orders and independent removal. Arsenal 0.36.0 and HD2MM 1.3.0.1 backend checks use isolated profiles and compare deployed bytes to the ZIPs. Gameplay validation of the new startup route remains pending.

Stingray's [script-loading documentation](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/creating_gameplay/scripting_with_lua/loading_scripts.html) distinguishes loading a resource from executing Lua. Its [Application API](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/lua_ref/ns_stingray_Application.html) documents `can_get`; the native startup check establishes its availability in the supported HD2 build.
