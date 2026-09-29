# Hide Development Notice — validation

Version **0.1.0**, tested September 29, 2026 against Manor Lords **0.8.104**, Steam build **24905706**, Unreal Engine **5.5**, installed UE4SS **v3.0.1 Beta #0 / 0bfec09e**.

## Live checks

| Check | Result |
| --- | --- |
| Development notice identity | Current assets and live objects agreed on the exact widget, menu owner, text, children, viewport, and focus. |
| Normal launch | The notice completed automatically through `DoFinish`; the main menu appeared without manual dismissal. |
| Exact release source | Installed `main.lua` matched the repository source by SHA-256; `DEBUG` was false. |
| Menu interaction | Settings opened, Return worked, and the separate Load Game screen opened normally. Settings values were not changed and no save was loaded or deleted. |
| Same-session menu navigation | Navigating these menu screens did not recreate the development notice or generate repeated mod output. |
| Removal | The mod folder was removed entirely. A fresh launch displayed the normal development notice and contained no mod output. |
| Reinstallation | The release files were restored and automatically dismissed the notice on another fresh launch. |
| Release logging | One successful-dismissal message in the release launch; no ongoing or per-frame messages. |
| Saves | Before/after inventories contained **29 files** with identical paths, lengths, and SHA-256 hashes. No file was added or removed. |
| Cleanup | Temporary investigation mod removed; only the standalone release mod remains installed. The test game was closed. |

## Automated checks

The real `main.lua` was loaded in a fresh mocked UE4SS environment for each case using Lua 5.4: **72 passed, 0 failed**.

The suite covers exact positive identification, harmless formatting whitespace, case-insensitive reflected FNames, separate wrappers for the same UObject, allocation-watcher removal, and retention of the exact startup hook. Rejection cases include unrelated widget classes, generic dialogs, changed title/body, unsupported language, missing properties, wrong child classes or owners, different owning players, another map/menu/focused dialog, invalid objects, missing or changed dismissal functions, argument/return signature changes, reflection errors, and hook-registration errors.

Write-trapping UObject proxies and forbidden-action spies reject property writes, alternate UI mutation, generic fallback actions, broad scans, timers, and unrelated hooks. A target already outside the viewport is not dismissed twice. Errors in the normal action never trigger a second dismissal method.

Run instructions are in the [repository's tests/README.md](https://github.com/zachsem/Hide-Development-Notice/blob/main/tests/README.md). Development interpreters, asset tools, mappings, proprietary assets, screenshots, logs, and save inventories are excluded from the repository and package.

## Scope and limits

The source has no gameplay hooks, simulation writes, save access, global startup gate changes, recurring work, or dependencies beyond UE4SS. Gameplay isolation is established by this narrow source scope and mutation checks; a gameplay session was not required or exercised during this menu-only test.

Actual future announcements and future game versions were not available to test. Changed-message rejection is exercised in the automated suite. An update that preserves every checked identifier, complete message, ownership relationship, and function signature while changing hidden internal behavior remains a reflection-based compatibility limit. Other languages and platforms remain unverified and are left visible when the English identity does not match.
