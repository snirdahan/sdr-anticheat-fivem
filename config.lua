Config = {}

-- ==========================================
--          SDR ANTICHEAT CONFIG
-- ==========================================

-- General
Config.Prefix         = '^1[SDR-AC]^7'   -- Chat prefix color
Config.AdminGroup     = 'admin'           -- ACE permission for admins: e.g. "group.admin"
Config.Language       = 'en'             -- 'he' or 'en'

-- Ban System
Config.BanPermanently = true             -- Permanent ban on detection?
Config.BanDuration    = 0               -- 0 = permanent, otherwise hours
Config.BanMessage     = 'You have been banned from the server by the anti-cheat system.'
Config.UseDatabase    = false           -- true = oxmysql persistent bans | false = runtime only (resets on restart)

-- Screenshot on detection
Config.Screenshots    = true
Config.ScreenshotURL  = ''              -- Discord webhook URL for screenshots (leave empty to disable)

-- Discord Logs
Config.DiscordLogs    = true
Config.DiscordWebhook = ''              -- Discord webhook for AC alerts
Config.ServerName     = 'My Server'

-- ==========================================
--              DETECTION SETTINGS
-- ==========================================

Config.Detections = {

    -- Speed Hack (on foot)
    SpeedHackFoot = {
        enabled   = true,
        maxSpeed  = 14.0,    -- m/s (~50 km/h), sprint is ~7 m/s
        strikes   = 3,       -- violations before action
    },

    -- Speed Hack (in vehicle)
    SpeedHackVehicle = {
        enabled   = true,
        maxSpeed  = 120.0,   -- m/s (~432 km/h)
        strikes   = 5,
    },

    -- God Mode
    GodMode = {
        enabled    = true,
        checkDelay = 1000,   -- ms between health checks
        strikes    = 3,
    },

    -- Teleport
    Teleport = {
        enabled     = true,
        maxDistance = 300.0, -- units per check interval
        checkDelay  = 1000,
        strikes     = 2,
    },

    -- NoClip
    NoClip = {
        enabled = true,
        strikes = 2,
    },

    -- Weapon Injection (weapons not allowed by server)
    WeaponInjection = {
        enabled = true,
        strikes = 2,
    },

    -- Explosion Spam
    ExplosionSpam = {
        enabled      = true,
        maxPerSecond = 3,
        strikes      = 2,
    },

    -- Resource Injection (unknown resources running on client)
    ResourceInjection = {
        enabled = true,
        strikes = 1,     -- instant ban (very serious)
    },

    -- Event Spam (server event flooding)
    EventSpam = {
        enabled    = true,
        maxPerSec  = 20,  -- max server events per second per player
    },

    -- Blacklisted Weapons (always banned regardless of inventory)
    BlacklistedWeapons = {
        enabled = true,
        list = {
            `WEAPON_RAILGUN`,
            `WEAPON_MINIGUN`,
            `WEAPON_WIDOWMAKER`,
            `WEAPON_RAYMONDSCOPED`,
        },
    },

    -- Blacklisted Vehicles
    BlacklistedVehicles = {
        enabled = true,
        list = {
            `rhino`,
            `hydra`,
            `lazer`,
            `b11`,
            `scramjet`,
            `oppressor2`,
        },
    },

    -- Blacklisted Peds
    BlacklistedPeds = {
        enabled = true,
        list = {
            `mp_m_freemode_01`,   -- example whitelist reverse: block non-standard peds
        },
        blockAll = false,  -- if true, blocks ALL peds not in a whitelist
    },
}

-- Allowed resources (client-side) - add your server's resource names here
Config.AllowedResources = {
    'sdr_anticheat',
    'mapmanager',
    'chat',
    'spawnmanager',
    'sessionmanager',
    'fivem',
    'hardcap',
    'rconlog',
    'baseevents',
}

-- Strike system: how many total strikes before ban
Config.MaxStrikes = 5

-- Cooldown between same-type detections (ms)
Config.DetectionCooldown = 5000

-- ==========================================
--          ADVANCED DETECTION SETTINGS
-- ==========================================

Config.AdvancedDetections = {

    -- Mod Menu resource scan
    MenuResourceScan = {
        enabled  = true,
        interval = 15000,  -- ms between scans
    },

    -- Super Jump
    SuperJump = {
        enabled       = true,
        maxZGain      = 8.0,   -- units per 200ms
        strikes       = 3,
    },

    -- Rapid Fire
    RapidFire = {
        enabled       = true,
        maxShotsPerSec = 15,
    },

    -- Explosive Ammo
    ExplosiveAmmo = {
        enabled = true,
        strikes = 3,
    },

    -- Vehicle God Mode
    VehicleGodMode = {
        enabled = true,
        strikes = 3,
    },

    -- Damage Hack (single hit)
    DamageHack = {
        enabled     = true,
        maxPerHit   = 500,   -- max legit damage per hit
        maxPer10sec = 10000, -- max total damage in 10 seconds
    },

    -- Heal Hack
    HealHack = {
        enabled     = true,
        maxRate     = 50,    -- HP/sec before flagging
    },

    -- Armour Inject
    ArmourInject = {
        enabled     = true,
        maxGain     = 100,   -- max armour gain per 500ms
    },

    -- Entity Spawn Bomb
    SpawnBomb = {
        enabled        = true,
        maxVehicles    = 50,
        maxPedSpike    = 20,   -- peds spawned in 5 seconds
        maxObjectSpike = 30,   -- objects spawned in 3 seconds
    },

    -- Entity Ownership Abuse
    EntityOwnership = {
        enabled  = true,
        maxOwned = 20,  -- max network entities owned at once
    },

    -- Spectate Hack
    SpectateHack = {
        enabled = true,
    },

    -- Wanted Level Manipulation
    WantedClear = {
        enabled    = true,
        minLevel   = 4,     -- flag if wanted drops from this level instantly
        timeWindow = 3,     -- seconds
    },

    -- Time Hack
    TimeHack = {
        enabled    = true,
        maxJump    = 2,     -- hours difference allowed in 5 seconds
        strikes    = 3,
    },

    -- NUI Focus Anomaly
    NuiAnomaly = {
        enabled    = true,
        maxStrikes = 10,
    },

    -- Position Spoof
    PositionSpoof = {
        enabled  = true,
        -- Flagged server-side via fingerprint
    },

    -- Native Hook Detection
    NativeHook = {
        enabled = true,
    },
}
