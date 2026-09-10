# Startup resource compatibility

Better Stratagem Bounce replaces the existing `boot` Lua resource. The inspected HD2 HUD+ 0.1.3 package replaces that same resource. An archive manager can select and deploy both packages, but that does not merge two bodies of code with the same resource identity.

Hellpod Steering Unlocked uses `core/wwise/lua/wwise_flow_callbacks`, a different resource reached through vanilla boot initialization. The two mods preserve the existing update chain and have offline tests for their shared Windows API declarations.

## Why a new resource is insufficient

A uniquely named resource can contain mod code, but an existing execution path must call it. A bounded investigation of the supported build found no independent startup slot in the paths examined:

| Engine RVA | Verified behavior |
| --- | --- |
| `0x686AD5` | Reads one `boot_script` setting. |
| `0x686B4A` and `0x686B9F` | Calls the named Lua globals `require` and `init`; the referenced strings were read directly. |
| `0x7A3D8` through `0x7A6CA` | Reads optional `pre_boot_package` from configuration. A new archive does not supply that configuration value. |
| `0x852C5` through `0x8542F` | Loads the selected pre-boot, fallback and boot packages. |
| `0x7E4AF` and `0x5DB4D0` | Registers Lua with a generic resource-data constructor that initializes data without calling Lua. |

Vanilla `boot` explicitly requires the existing Wwise callbacks from `init()`. Its optional `debug` resource already exists and is excluded by the release branch. The inspected boot does not load Appkit, so Appkit's project-script convention is not evidence of an HD2 startup hook.

Loading a package and executing its Lua are separate operations in [Stingray's script-loading documentation](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/creating_gameplay/scripting_with_lua/loading_scripts.html). The [settings reference](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/reference/engine_settings.html) also describes `autoload` as resource loading on demand, rather than script autorun. These sources provide engine background; the addresses above are HD2-specific evidence.

## Remaining approaches

A shared loader could own one startup resource and load separately named modules from cooperating mods. A manager or packaging tool could instead compose one startup resource from the enabled mods and regenerate it when they update. Neither approach inherently requires a custom DLL, but both need explicit composition rules and compatibility checks. Moving to another existing resource only moves the potential conflict.

No shared loader, automatic HUD+ merge or independent fabricated-resource entry point is implemented here. The investigation was not exhaustive across every native plugin, component, level and indirect call. A new candidate needs a concrete caller or registration consumer that executes an independently added resource without replacing shared resources or configuration.
