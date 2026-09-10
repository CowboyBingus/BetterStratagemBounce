![Better Stratagem Bounce](assets/banner.png)

# Better Stratagem Bounce

Lets stratagem balls stick and activate on more surfaces instead of bouncing away, including solid ground outside the game's navigation mesh.

[Download Better Stratagem Bounce](https://github.com/CowboyBingus/BetterStratagemBounce/releases/download/archive-v12/BetterStratagemBounce.zip), import the ZIP into **HDArsenal** or **HD2MM**, then enable and deploy it with the game closed. Use one manager for the installation. Remove any older manual installation before switching to a manager.

If an earlier HD2MM import reported empty options, remove that entry from its library and import the corrected ZIP again. Import, deployment and removal are verified with the HDArsenal 0.36.0 and HD2MM 1.3.0.1 backends in isolated folders.

The native slope limit remains: sufficiently steep surfaces and vertical walls still reject the ball. Sticking does not guarantee that every payload can land in every location.

The current source revision is **archive-v12**, for Steam build **24826606** / EXE **1.8.45317.0**. Unsupported game binaries are rejected. Combined operation with [Hellpod Steering Unlocked](https://github.com/CowboyBingus/HellpodSteeringUnlocked) has been reported working; offline tests also cover both initialization orders. Neither result establishes compatibility with every other mod or multiplayer situation.

Mods replacing the same `boot` resource, including the inspected HD2 HUD+ 0.1.3 package, need a combined startup resource. Changing load order alone does not preserve both implementations. See [compatibility](docs/COMPATIBILITY.md).

## Source

- `src/`: runtime Lua modules.
- `tests/`: synthetic memory, callback and package checks.
- `scripts/`: dependency setup, build, packaging and optional Arsenal validation.
- `cmd/`: tools for extracting and inspecting game resources.
- `assets/`: README banner and Arsenal thumbnail.

[Build from source](CONTRIBUTING.md) · [Technical walkthrough](docs/TECHNICAL.md) · [Third-party dependencies](THIRD_PARTY.md)

**AI disclosure:** GPT-6 Astra was used for research, implementation, debugging, documentation and artwork.
