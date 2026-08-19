# KGB Admin Color Chat

KGB Admin Color Chat is an AMX Mod X plugin for Counter-Strike 1.6 servers. It
adds colored admin broadcasts, admin-only chat, and private messages while
leaving normal player chat untouched. It also carries the default AMX Mod X
`adminchat.amxx` HUD announcement features, so it should be used as a
replacement for that plugin.

## Features

- Sends colored chat messages through `SayText`.
- Adds admin broadcasts, admin-only chat, and private messages.
- Adds the default `amx_tsay`, `amx_csay`, and `say @` HUD announcements.
- Supports in-game shortcuts and console/RCON commands.
- Resolves private-message targets by nickname, auth ID, or `#userid`.
- Logs staff chat actions through AMXX and server logs.
- Creates a default config file on first load.
- Stops itself when the default `adminchat.amxx` plugin is loaded, preventing
  duplicate command handlers.

## Install

Download `kgb_admin_color_chat.amxx` from the latest release and copy it into:

```text
addons/amxmodx/plugins/
```

Disable the default AMX Mod X admin chat plugin:

```text
;adminchat.amxx		; console chat commands
```

Then add this line to `addons/amxmodx/configs/plugins.ini`:

```text
kgb_admin_color_chat.amxx
```

Start or restart the server. On first load, the plugin creates:

```text
addons/amxmodx/configs/kgb_admin_color_chat.cfg
```

Edit that file to enable or disable features.

## Commands

| Command | Access | Description |
| --- | --- | --- |
| `amx_say <message>` | `ADMIN_CHAT` | Send a colored message to all players. |
| `amx_chat <message>` | `ADMIN_CHAT` | Send a message to online admins only. |
| `amx_psay <target> <message>` | `ADMIN_CHAT` | Send a private message to one player. |
| `amx_tsay <color> <message>` | `ADMIN_CHAT` | Send a left-side HUD message to all players. |
| `amx_csay <color> <message>` | `ADMIN_CHAT` | Send a centered HUD message to all players. |
| `say @<message>` | `ADMIN_CHAT` | Send a left-side HUD message to all players. |
| `say @@<message>` | `ADMIN_CHAT` | Send a top-center HUD message to all players. |
| `say @@@<message>` | `ADMIN_CHAT` | Send a lower-center HUD message to all players. |
| `say # <target> <message>` | `ADMIN_CHAT` | Send a private message from normal chat. |
| `say_team @ <message>` | Any player | Send a message to online admins. |
| `say_team # <target> <message>` | `ADMIN_CHAT` | Send a private message from team chat. |

`ADMIN_CHAT` is the standard AMX Mod X admin chat flag, usually flag `i`.

HUD shortcut colors are `r`, `g`, `b`, `y`, `m`, `c`, and `o`; white is used
when no shortcut color is given. `amx_tsay`/`amx_csay` support the default AMXX
color names from `adminchat.txt`.

Private-message targets can be `#userid`, auth IDs such as `STEAM_...`, or
player nicknames.

## Cvars

| Cvar | Default | Description |
| --- | --- | --- |
| `kgb_acc_broadcasts` | `1` | Enable `amx_say` broadcasts. |
| `kgb_acc_admin_chat` | `1` | Enable admin-only chat. |
| `kgb_acc_private_messages` | `1` | Enable private messages. |
| `kgb_acc_logging` | `1` | Enable chat action logging. |

The plugin also uses the standard AMXX `amx_show_activity` and
`amx_flood_time` cvars for HUD identity display and `say_team @` flood control.

## Build

Docker is required for the bundled build flow.

```sh
./scripts/build.sh
```

The script downloads the pinned AMX Mod X compiler when needed, verifies it,
and writes the compiled plugin to `compiled/kgb_admin_color_chat.amxx`.

```sh
./scripts/check-compatibility.sh
```

Use the compatibility check to compile against AMX Mod X `1.8.2`, `1.9`, and
`1.10`.

## Release Files

- `kgb_admin_color_chat.amxx`
- `kgb_admin_color_chat.amxx.sha256`
