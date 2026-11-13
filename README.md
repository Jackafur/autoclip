# AutoClip

<img src="assets/icon.png" alt="AutoClip icon" width="128" align="right">

Saves the last 2 minutes of WoW in OBS when something worth keeping happens: a PvP killing blow by you or your pet, a
level up, a boss kill, or (off by default) your own death. Made for one Linux PC (CachyOS, KDE,
WoW under Lutris, OBS 30+ with instant replay and its websocket on); tested on that setup only.

```
/autoclip            what's on
/autoclip pvp        turn one on or off (pvp, level, boss, death)
/autoclip test       make a clip now (8 s from now)
```

## How it works

An addon can't talk to OBS, so AutoClip waits 8 s after the moment (so the clip shows what came right after) and takes
**two screenshots 1.5 s apart**. On the PC, `wow-autoclip.path` (systemd, inotify, nothing polls) wakes on any change in
WoW's Screenshots folder and runs `obs-record auto`: a pair like that (0.8 to 3 s apart) is the signal. Both screenshots
move to `~/.cache/wow-autoclip` (the last 6 kept), OBS saves its instant replay, and the clip lands in
`~/Videos/OBS/Auto`, which rotates: past 50 GB the oldest go. Your own single screenshots are left alone.

PvP kills come from the `PARTY_KILL` event. Not from the combat log: `COMBAT_LOG_EVENT_UNFILTERED` is restricted in this
client, and registering it brings up "blocked from an action only available to the Blizzard UI" at every load. Also
blocked here: changing the `screenshotFormat` CVar and muting "Screen captured" on `ActionStatus`. A refused call is
printed in chat and kept in `AutoClipDB.blocked`.

## The PC side (`pc/`)

| File | Where it goes | What it is |
| --- | --- | --- |
| `obs-record` | `~/.local/bin/` | OBS over its local websocket: Win + R record, Win + C clip, Win + M mark, `buffer-on` / `buffer-off` (Battle.net's Lutris pre and post commands), `auto` (this watcher) |
| `wow-autoclip.path`, `.service` | `~/.config/systemd/user/` | the watcher; `systemctl --user enable --now wow-autoclip.path` |
| `sdr-copy` | `~/.local/bin/` | Dolphin's "Make SDR copy": an H.264 copy of an HDR clip for Discord |

Before enabling the watcher, change the `PathChanged=` line in `wow-autoclip.path` to your own WoW `Screenshots` folder.
`obs-record` reads the OBS websocket password from `~/.config/obs-studio/websocket-password`.

## Install

Copy the `AutoClip` folder into `Interface/AddOns` of WoW Forever (`_forever_`), then `/reload`.
