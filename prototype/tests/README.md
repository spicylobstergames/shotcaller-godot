# Automated tests

The gameplay/debug fixture lives in `tests/test_map`. Automated, deterministic
logic tests live in `tests/unit` and run without loading a map or starting a
game.

Run the suite from the repository root with:

```sh
godot --headless --path prototype res://tests/test_runner.tscn
```

The runner exits with status `0` when every assertion passes and a non-zero
status when a check fails. No third-party test addon is required. Add focused
unit tests here for deterministic logic, and use separate scene-based
integration tests when behavior depends on actual nodes, physics frames, or
loaded maps.
