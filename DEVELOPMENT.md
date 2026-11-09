# Local development with mise

`mise.toml` selects Crystal 1.22.2 and its bundled Shards for this checkout.
The tools are stored by mise; build caches stay in the ignored `.cache/` folder.
Test state uses a short temporary directory to avoid macOS Unix socket limits.

```sh
mise trust
mise install
mise run test
mise run build
```

`test` and `build` both install the dependencies from `shard.lock` first.
Check the selected tool versions with:

```sh
mise exec -- crystal --version
mise exec -- shards --version
```

The loader prefers the compiled `bin/tmux-fingers` in this checkout over a
Homebrew executable on PATH. The compiled executable runs without mise.
Rebuild after updating the source, then reload the tmux configuration.

To use a local checkout, replace the upstream plugin entry with its absolute
loader path, for example:

```tmux
run-shell '/absolute/path/to/tmux-fingers/tmux-fingers.tmux'
```

The layout fix and its tests are in the preceding commit. Toolchain selection
and this local binary preference are separate so the layout fix can be reviewed
or cherry-picked without changing upstream's development setup.
