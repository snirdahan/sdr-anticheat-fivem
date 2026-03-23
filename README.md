# 🛡 SDR AntiCheat

Advanced FiveM anti-cheat resource. Detects speed hacks, god mode, teleport, aimbot, mod menus, resource injection, damage hacks, entity spam and more. Features HWID banning, Discord logging, automatic screenshots, and a real-time in-game admin panel.

---

## Features

### Movement & Position
| Detection | Description |
|---|---|
| Speed Hack | Flags players moving faster than physically possible on foot or in a vehicle |
| Teleport | Detects position jumps over 300 units per second |
| NoClip | Detects vertical movement without a vehicle or jump animation |
| Super Jump | Catches abnormal vertical gain without a jump animation |
| Position Spoof | Server cross-checks reported speed against actual position change |
| Freeze Position | Detects players who froze their own entity |

### Combat
| Detection | Description |
|---|---|
| God Mode | Monitors HP/armor that never decreases after taking damage |
| Vehicle God Mode | Detects vehicle health locked while under fire |
| Heal Hack | Flags health regeneration above 50 HP/second |
| Armor Inject | Detects armor gain over 100 units per 500ms |
| Damage Hack | Flags single hits over 500 damage or 10,000 total damage in 10 seconds |
| One-Shot Kill | Detects killing the same player twice within 500ms |
| Explosive Ammo | Detects explosions triggered within 100ms of a gunshot |
| Rapid Fire | Flags more than 15 shots per second |

### Aimbot
| Detection | Description |
|---|---|
| Headshot Ratio | Flags players with 90%+ headshot rate over 10+ kills |
| Aim Snap | Detects camera rotation above 1200°/second |
| Reaction Time | Flags sub-80ms reaction time across 5 consecutive samples |
| Session Stats | Posts kill/headshot summary to Discord every 10 minutes |

### Mod Menus & Injection
| Detection | Description |
|---|---|
| Menu Resource Scan | Scans for 30+ known mod menu names (Eulen, Lynx, Impulse, Lambda, Dolu, Loaf, etc.) |
| Resource Injection | Detects any resource running on the client not on the server whitelist |
| AC Bypass Detection | Scans for known anti-cheat bypass resource signatures |
| Native Hook Detection | Server detects if native return values have been tampered with |
| NUI Focus Anomaly | Detects suspicious NUI overlay activity used by menus |
| ScriptHookV | Checks for native call anomalies caused by ScriptHookV |

### Entities & World
| Detection | Description |
|---|---|
| Spawn Bomb | Detects sudden spikes of 50+ vehicles or 20+ peds spawned at once |
| Crash Objects | Removes and flags blacklisted crash props |
| Unauth Vehicle Spawn | Server validates every vehicle against an authorized spawn list |
| Entity Ownership Abuse | Detects players owning 20+ network entities simultaneously |
| Blacklisted Vehicles | Auto-deletes banned vehicle models (Hydra, Lazer, Oppressor, etc.) |
| Blacklisted Weapons | Removes banned weapon hashes instantly |
| Object Spam | Detects 30+ objects spawned within 3 seconds |

### Player Manipulation
| Detection | Description |
|---|---|
| Wanted Level Clear | Detects 4+ stars dropping to 0 instantly |
| Spectate Hack | Detects spectate mode without admin permission |
| Invisible Player | Detects and corrects invisible entity state |
| Time Hack | Detects large in-game clock jumps |
| Cam Hack | Detects rendering camera placed 200+ units from the player |
| Routing Bucket Tamper | Detects players changing their own network instance |
| Event Spam | Rate-limits server events per player (20/sec max) |
| Movement Spoof | Detects non-zero speed reported while position is unchanged |

---

## Ban System

- **License Ban** — stored in `bans.json`, persists across server restarts
- **HWID Ban** — fingerprints 7 identifiers (`license`, `license2`, `steam`, `discord`, `xbl`, `live`, `fivem`). If 3+ identifiers match a banned player, the connection is blocked — even if they changed accounts
- **IP Ban** — catches alt accounts connecting from the same IP
- **Strike System** — configurable strike limit before an automatic ban is issued
- **Instant Ban** — resource injection triggers an immediate permanent ban

---

## Admin Panel

Open with **F9** in-game (admins only).

- Live player list with strike count, headshot %, and hardware fingerprint
- Real-time detection feed with filter by detection type
- Full ban list with one-click unban
- Quick actions per player: **Kick, Warn, Ban, Screenshot, Teleport**
- All admin actions logged to Discord

---

## Discord Logging

All events are sent to a Discord webhook with color-coded embeds:

| Event | Color |
|---|---|
| Detection | Yellow |
| Ban | Red |
| Screenshot | Blue |
| Admin Action | Blue |
| Session Stats | Green / Red |

---

## Installation

1. Drop the `sdr_anticheat` folder into your server's `resources` directory
2. Add to `server.cfg`:
```
ensure sdr_anticheat
```
3. Open `config.lua` and configure:
```lua
Config.AdminGroup     = 'admin'        -- ACE permission group for admins
Config.DiscordWebhook = ''             -- Discord webhook URL for logs
Config.ScreenshotURL  = ''             -- Discord webhook URL for screenshots
Config.MaxStrikes     = 5              -- Strikes before auto-ban
```
4. Add all your server's resource names to `Config.AllowedResources` to prevent false positives on the resource injection check
5. Make sure `screenshot-basic` is started **before** `sdr_anticheat` in `server.cfg`

---

## Commands

| Command | Description | Permission |
|---|---|---|
| `/acban <id> [reason]` | Manually ban a player | Admin |
| `/acunban <license>` | Unban a player by license | Admin |
| `/acstrikes <id>` | View a player's current strike count | Admin |
| `/acbans` | List all active bans in console | Admin |
| `/achwidban <id> [reason]` | Manually HWID ban a player | Admin |
| `/achwidlist` | List all active HWID bans in console | Admin |
| `/acpanel` | Open the admin panel (or press F9) | Admin |

---

## Requirements

- [screenshot-basic](https://github.com/citizenfx/screenshot-basic) — for automatic screenshots on detection

---

## Configuration

All settings are in `config.lua`. Key options:

```lua
Config.MaxStrikes     = 5       -- total strikes before auto-ban
Config.Screenshots    = true    -- take screenshot on detection
Config.DiscordLogs    = true    -- send logs to Discord

-- Per-detection settings example:
Config.Detections.SpeedHackFoot.maxSpeed  = 14.0   -- m/s
Config.Detections.Teleport.maxDistance    = 300.0  -- units/sec
Config.AdvancedDetections.RapidFire.maxShotsPerSec = 15
```

---

## License

This project is open source. Feel free to use, modify, and contribute.
