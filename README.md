# Hide Development Notice

A standalone UE4SS Lua mod for Manor Lords that automatically dismisses the specific **“This game is still in development”** notice when the main menu opens.

It checks the notice's exact widget class, menu ownership, child widgets, complete English text, focus, and normal dismissal function before acting. If any check fails, the notice stays visible. Detection is limited to this widget; unmatched dialogs remain under the game's normal menu system.

## Status and compatibility

Version **0.1.0**. Verified automatic dismissal, normal menu interaction, and restoration of the notice after removal. The regression suite passes **72 tests**. All **29 save files** retained their original SHA-256 hashes during testing. See [validation results](docs/VALIDATION.md).

Investigated environment:

- Manor Lords **0.8.104**, Steam build **24905706**.
- Unreal Engine **5.5**.
- Installed UE4SS **v3.0.1 Beta #0**, commit **0bfec09e**.

This version deliberately supports only the verified English notice. A different language, changed text, or changed menu structure causes it to leave the notice alone. Compatibility with other builds is unverified.

## Installation

Use an existing, working UE4SS installation. Copy the mod's `HideDevelopmentNotice` folder into its `Mods` directory:

```text
ManorLords/Binaries/Win64/ue4ss/Mods/
└── HideDevelopmentNotice/
    ├── enabled.txt
    └── Scripts/
        └── main.lua
```

Keep `enabled.txt` in the mod folder to enable it. If your UE4SS setup manages mods through `mods.txt`, enable the entry `HideDevelopmentNotice : 1` there. Do not overwrite another mod or replace the game's assets.

Launch Manor Lords normally. The game creates its notice as usual; this mod validates it and calls the same `DoFinish` action used by the player's dismiss button. The game's normal dismissal sounds may play.

## Removal

Close the game, then remove the `HideDevelopmentNotice` folder. Remove or disable its `mods.txt` entry if you added one. The next launch uses the original notice behavior; no save or persistent setting needs restoring.

## Scope

The mod uses one specific main-menu lifecycle hook. It has no Tick hook, polling loop, delayed retry, or general dialog scan. It changes no gameplay, saves, global notification settings, or startup-dialog gates. UE4SS is its only dependency.

See [the investigation report](docs/INVESTIGATION.md) for the evidence, dismissal choice, and conservative behavior after updates.
