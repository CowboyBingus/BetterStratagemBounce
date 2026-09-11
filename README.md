![Better Stratagem Bounce](assets/banner.png)

# Better Stratagem Bounce

Lets stratagem balls stick and activate on more surfaces instead of bouncing away, including solid ground outside the game's navigation mesh.

[Download Better Stratagem Bounce](https://github.com/CowboyBingus/BetterStratagemBounce/releases/download/archive-v13/BetterStratagemBounce.zip), import the ZIP into **HDArsenal** or **HD2MM**, then enable and deploy it with the game closed. Use one manager for the installation. Remove any older manual installation before switching to a manager.

This prerelease introduces the shared Wwise loader. Native startup and offline HUD+ startup checks pass; gameplay validation remains pending. Import, deployment and removal pass HDArsenal 0.36.0 and HD2MM 1.3.0.1 backend checks in isolated folders.

The native slope limit remains: sufficiently steep surfaces and vertical walls still reject the ball. Sticking does not guarantee that every payload can land in every location.

The current prerelease is **archive-v13**, for Steam build **24826606** / EXE **1.8.45317.0**. Unsupported game binaries are rejected. This mod and [Hellpod Steering Unlocked](https://github.com/CowboyBingus/HellpodSteeringUnlocked) now use an identical Wwise coordinator with separate modules. Each works independently; when using both, update both packages together.

Neither package replaces `boot`, avoiding the known HD2 HUD+ 0.1.3 startup conflict. Offline checks preserve its update chain. Other Wwise replacements still need coordination; see [compatibility](docs/COMPATIBILITY.md).

## Source

- `src/`: runtime Lua modules.
- `tests/`: synthetic memory, callback and package checks.
- `scripts/`: dependency setup, build, packaging and optional Arsenal validation.
- `cmd/`: tools for extracting and inspecting game resources.
- `assets/`: README banner and Arsenal thumbnail.

[Build from source](CONTRIBUTING.md) · [Technical walkthrough](docs/TECHNICAL.md) · [Third-party dependencies](THIRD_PARTY.md)

**AI disclosure:** GPT-6 Astra was used for research, implementation, debugging, documentation and artwork.
