# Lua regression tests

Run from the repository root with a Lua 5.2 or newer interpreter:

```text
lua tests/test_main.lua
```

An optional first argument selects the actual source file to exercise. The suite
loads that real file in a fresh mocked UE4SS environment for each case. It does
not copy the mod's validation logic and requires no UE4SS or game installation.
No interpreter or third-party binary belongs in the mod package.

The positive cases require the normal completion action on exactly the validated
notice and verify allocation-watcher removal after hook installation. The
negative cases vary notice type, content, localization, ownership, properties,
focus, function signature, reflection availability, and registration failures.
Every mocked UObject is a proxy that traps property writes; rejected targets
must produce zero normal completion calls and zero property writes.

These tests check Lua control flow and fail-open behavior. They cannot establish
engine-thread behavior, actual UE4SS semantics, native focus behavior, or save
safety; use the [live validation report](../docs/VALIDATION.md) for those checks.
