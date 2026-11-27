# AutoClip

<img src="assets/icon.png" alt="AutoClip icon" width="128" align="right">

Saves the last 2 minutes of WoW in OBS when something worth keeping happens: a PvP kill (an honorable kill), a
level up, a boss kill, or (off by default) your own death. Made for one Linux PC (CachyOS, KDE,
WoW under Lutris, OBS 30+ with instant replay and its websocket on); tested on that setup only.

```
/autoclip            what's on
/autoclip pvp        turn one on or off (pvp, level, boss, death)
/autoclip test       make a clip now (12 s from now)
/autoclip wait 12    how long it waits after the moment (8 to 30 s; 8 was the wait before Nov 26)
```

Your own key: Esc, Options, Keybindings, AddOns, AutoClip, **Save a clip (the last 5 minutes)**. It saves right away, no wait,
the whole 5 minutes into `~/Videos/OBS/Clips` (like Win + C; kept under 100 GB). Automatic clips keep the last 2 minutes
in `~/Videos/OBS/Auto` (kept under 50 GB). The PC tells them apart by the gap between the two screenshots (2.6 s for the
key, 1.5 s for an event). Instant replay is 5 minutes for this (OBS, Output, Replay Buffer).

## How it works

An addon can't talk to OBS, so AutoClip waits 12 s after the moment (so the clip shows what came right after) and takes
**two screenshots 1.5 s apart**. On the PC, `wow-autoclip.path` (systemd, inotify, nothing polls) wakes on any change in
WoW's Screenshots folder and runs `obs-record auto`: a pair like that (0.8 to 3 s apart) is the signal. Both screenshots
move to `~/.cache/wow-autoclip` (the last 6 kept), OBS saves its instant replay, and the clip lands in
`~/Videos/OBS/Auto`, which rotates: past 50 GB the oldest go. Your own single screenshots are left alone.

WoW prints "Screen Captured" on screen for each screenshot, and an addon can't hide that here. So the PC cuts the last
3.5 s off each automatic clip (`AUTO_TRIM_END` in `obs-record`; the text shows from 2.9 s before the save). With the
12 s wait that leaves about 11 s after the moment. The old way: `/autoclip wait 8` and `AUTO_TRIM_END = 0`.

A second moment in the last 4 s before the screenshots, or during them, would be cut off or missing from that clip.
It gets a clip of its own right after (earlier ones share the first clip, as before).

PvP kills come from `PLAYER_PVP_KILLS_CHANGED` (your honorable kill count went up), plus `PARTY_KILL` where its GUIDs
are readable: they are secret values when unit identity is restricted, which is when the victim is an enemy player, so
`PARTY_KILL` alone misses PvP kills. A grey-level player is no honorable kill and makes no clip. Not from the combat log: `COMBAT_LOG_EVENT_UNFILTERED` is restricted in this
client, and registering it brings up "blocked from an action only available to the Blizzard UI" at every load. Also
blocked here: changing the `screenshotFormat` CVar and muting "Screen captured" on `ActionStatus`. A refused call is
printed in chat and kept in `AutoClipDB.blocked`.

## The PC side (`pc/`)

| File | Where it goes | What it is |
| --- | --- | --- |
| `obs-record` | `~/.local/bin/` | OBS over its local websocket: Win + R record (a chime on start and stop, heard over a full-screen game), Win + C clip, Win + M mark, `buffer-on` / `buffer-off` (Battle.net's Lutris pre and post commands), `auto` (this watcher) |
| `wow-autoclip.path`, `.service` | `~/.config/systemd/user/` | the watcher; `systemctl --user enable --now wow-autoclip.path` |
| `sdr-copy` | `~/.local/bin/` | Dolphin's "Make SDR copy": an H.264 copy of an HDR clip for Discord, with every sound track kept |
| `vshare`, `vshare.desktop` | `~/.local/bin/`, `~/.local/share/kio/servicemenus/` | Dolphin's right-click "jackafur.com" menu: **Share** (web copies of a clip: AV1 + HEVC HDR for HDR screens, H.264 SDR for the rest, with an HDR / SDR button, on a page at `/v/<id>/`; link on the clipboard; the clip moves into `~/Videos/OBS/Shared`, so that folder is what's online), **Copy link**, **Take down** (off the site, the clip back to where it came from). Both rebuild the **clips page** at `/v/`: every shared clip, newest first, with its thumbnail, length, an HDR tag and a Copy link button (`vshare index` rebuilds it by hand; hidden from search engines, open to anyone who visits). Change `HOST`, `WEBROOT` and `SITE` at the top for your own server (uploads over SSH with rsync) |

| `jackwowfollow/` | `~/.local/share/kwin/scripts/` | KDE (KWin) script for **two WoWs open**: clicking into one runs `obs-record follow <pid>` so OBS films the WoW you are in. Nothing runs with one WoW open. Turn it on in System Settings, Window Management, KWin Scripts ("OBS follows your WoW") |
| `wow-follow@.service` | `~/.config/systemd/user/` | what the KWin script starts: `obs-record follow <pid>` |
| `obs-vkcapture-follow/` | build with `makepkg -si` (Arch) | obs-vkcapture 1.5.6 with a small patch: the game layer can be told which game to film by its process id (a hidden `follow_pid` setting), so it films the WoW you are in, in HDR. OBS's log says "follow_pid patch" when it loads. Add `IgnorePkg = obs-vkcapture` to `/etc/pacman.conf` so an update doesn't put the stock one back |

**Two WoWs open.** OBS's game capture (obs-vkcapture) films the game started last and can't tell two WoWs apart, so
the clip may show the other WoW. With the patched obs-vkcapture, `follow` points the game layer at the WoW you clicked
into. Without the patch, `follow` falls back: in the WoW the game layer isn't filming, the game layer goes off and a
screen capture layer films instead (SDR). `obs-record` expects a scene `Game` with a game capture layer `Game (HDR)`
and a screen capture layer `Screen (ultrawide)`: change `SCENE`, `GAME_LAYER` and `SCREEN_LAYER` at its top to your
own names.

Before enabling the watcher, change the `PathChanged=` line in `wow-autoclip.path` to your own WoW `Screenshots` folder.
`obs-record` reads the OBS websocket password from `~/.config/obs-studio/websocket-password`.

## Install

Copy the `AutoClip` folder into `Interface/AddOns` of WoW Forever (`_forever_`), then `/reload`.
