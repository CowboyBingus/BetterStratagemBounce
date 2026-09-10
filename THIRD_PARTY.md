# Third-party dependencies

The build downloads pinned dependencies into ignored directories; their source is not bundled in this repository.

| Project | Use | License |
| --- | --- | --- |
| [Filediver](https://github.com/xypwn/filediver) | Archive and resource extraction/inspection | BSD-3-Clause |
| [LuaJIT](https://github.com/LuaJIT/LuaJIT) | Compile Lua bytecode and run offline checks | MIT |

Source revisions are recorded in `dependencies.json`; transitive Go dependencies and checksums are in `go.mod` and `go.sum`. Upstream dependencies retain their own licenses. No repository-wide license has been selected.

Builders obtain the required vanilla resources from the developer's own supported game installation. Game executables, extracted resources, generated archives, crash dumps and memory captures are excluded from source control.

HDArsenal backend checks optionally use a developer-supplied installed application. Arsenal itself is not bundled.
