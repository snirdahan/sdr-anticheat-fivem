-- ==========================================
--      SDR ANTICHEAT - Mod Menu Detection
-- ==========================================

local function Report(detType, detail)
    TriggerServerEvent('sdr_anticheat:report', detType, detail, '')
end

-- ==========================================
--  KNOWN MOD MENU RESOURCE SIGNATURES
-- ==========================================
local knownMenuResources = {
    -- Lua/NUI menus often injected as resources
    'eulen', 'eulencheats', 'eulen-client',
    'lynx', 'lynxmenu',
    'impulse', 'impulse-menu',
    'lambda', 'lambdamenu', 'lambda-menu',
    'rebound', 'reboundmenu',
    'skript', 'skripted',
    'hydra', 'hydramenu',
    'menyoo', 'menyoomenu',
    'otaku', 'otakumenu',
    'redengine', 'red-engine',
    'loaf', 'loafmenu',
    'dolu', 'dolu-menu', 'dolutool',
    'nexus', 'nexusmenu',
    'vega', 'vegamenu',
    'orion', 'orionmenu',
    'north', 'northmenu',
    'chaos', 'chaosmenu',
    'eclipse', 'eclipsemenu',
    'soothe',
    'cobalt', 'cobaltmenu',
    'renegade',
    'executor',
    'xhawk',
    'fiveguard_bypass', 'bypass',
    'txadmin_bypass',
    'injector',
    'trainer', 'simpletrainer',
    'hacks', 'cheat', 'cheats', 'aimbot',
}

CreateThread(function()
    Wait(8000)

    while true do
        Wait(15000)

        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local res = GetResourceByFindIndex(i)
            if res then
                local resLower = res:lower()
                for _, menuName in ipairs(knownMenuResources) do
                    if resLower == menuName or resLower:find(menuName, 1, true) then
                        Report('MOD_MENU_RESOURCE', ('known menu resource found: %s'):format(res))
                        break
                    end
                end
            end
        end
    end
end)

-- ==========================================
--  SCRIPTHOOKV DETECTION
-- ==========================================
-- ScriptHookV allows native injection outside FiveM sandbox
CreateThread(function()
    Wait(5000)

    while true do
        Wait(20000)

        -- ScriptHookV patches certain natives - we test for anomalies
        -- If SHVDN is present, certain return values will be wrong
        local model = `adder`
        local result1 = IsModelInCdimage(model)
        local result2 = IsModelValid(model)

        -- A hacked client may return unexpected values on these
        -- We log for server cross-reference
        TriggerServerEvent('sdr_anticheat:integrityPing', result1, result2, GetGameTimer())
    end
end)

-- ==========================================
--  NUI FOCUS ANOMALY DETECTION
-- ==========================================
-- Many mod menus use NUI (HTML overlays) - detect unusual NUI focus
local lastNuiFocus = false
local nuiFocusStrikes = 0

CreateThread(function()
    while true do
        Wait(500)

        local isFocused = IsNuiFocused()

        if isFocused and not lastNuiFocus then
            -- NUI just gained focus - check if it's from a known resource
            -- Unknown NUI focus can indicate a menu opening
            nuiFocusStrikes = nuiFocusStrikes + 1

            if nuiFocusStrikes > 10 then
                Report('NUI_FOCUS_ANOMALY', ('NUI focus triggered %d times suspiciously'):format(nuiFocusStrikes))
                nuiFocusStrikes = 0
            end
        elseif not isFocused then
            -- Reset gradually
            if nuiFocusStrikes > 0 then
                nuiFocusStrikes = nuiFocusStrikes - 1
            end
        end

        lastNuiFocus = isFocused
    end
end)

-- ==========================================
--  WANTED LEVEL MANIPULATION
-- ==========================================
CreateThread(function()
    while true do
        Wait(3000)

        local ped     = PlayerPedId()
        local wanted  = GetPlayerWantedLevel(PlayerId())

        -- If player was at 5 stars and suddenly 0 without dying = cheat
        -- We track transitions
        TriggerServerEvent('sdr_anticheat:wantedLevel', wanted)
    end
end)

-- ==========================================
--  TIME / WEATHER HACK
-- ==========================================
-- Detect if client is manipulating time/weather locally to gain advantage
local lastHour = nil
local timeChangeCount = 0

CreateThread(function()
    while true do
        Wait(5000)

        local h, m, s = GetClockHours(), GetClockMinutes(), GetClockSeconds()

        if lastHour ~= nil then
            local diff = math.abs(h - lastHour)
            if diff > 2 and diff ~= 23 then -- large jump that isn't normal day rollover
                timeChangeCount = timeChangeCount + 1
                if timeChangeCount >= 3 then
                    Report('TIME_HACK', ('time jumped from %d to %d hours'):format(lastHour, h))
                    timeChangeCount = 0
                end
            else
                if timeChangeCount > 0 then timeChangeCount = timeChangeCount - 1 end
            end
        end

        lastHour = h
    end
end)

-- ==========================================
--  SUPER JUMP DETECTION
-- ==========================================
local lastZ = nil
local superJumpStrikes = 0

CreateThread(function()
    while true do
        Wait(200)

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
            lastZ = nil
            goto continue
        end

        local pos = GetEntityCoords(ped)

        if lastZ ~= nil then
            local zDiff = pos.z - lastZ
            -- Normal jump is ~2-3 units. Super jump is way higher.
            if zDiff > 8.0 and not IsPedJumping(ped) and not IsPedClimbing(ped) then
                superJumpStrikes = superJumpStrikes + 1
                if superJumpStrikes >= 3 then
                    Report('SUPER_JUMP', ('vertical gain %.1f in 200ms without jump anim'):format(zDiff))
                    superJumpStrikes = 0
                end
            else
                if superJumpStrikes > 0 then superJumpStrikes = superJumpStrikes - 1 end
            end
        end

        lastZ = pos.z
        ::continue::
    end
end)

-- ==========================================
--  INFINITE AMMO / RAPID FIRE DETECTION
-- ==========================================
local shotLog = {}
local RAPID_FIRE_THRESHOLD = 15  -- shots per second (most guns max ~10)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventGunShot' or name == 'CEventNetworkEntityDamage' then
        local now = GetGameTimer()
        table.insert(shotLog, now)

        -- Clean old entries (keep last 1 second)
        local cutoff = now - 1000
        local cleaned = {}
        for _, t in ipairs(shotLog) do
            if t >= cutoff then cleaned[#cleaned+1] = t end
        end
        shotLog = cleaned

        if #shotLog > RAPID_FIRE_THRESHOLD then
            Report('RAPID_FIRE', ('%d shots in 1 second'):format(#shotLog))
            shotLog = {}
        end
    end
end)

-- ==========================================
--  SUPER BULLET / EXPLOSIVE AMMO DETECTION
-- ==========================================
-- Handled server-side via damage events, but we also monitor locally
local lastShotTime = 0
local explosionAfterShot = 0

AddEventHandler('explosionEvent', function(sender, ev)
    local now = GetGameTimer()
    -- If explosion occurs within 100ms of a shot, suspicious
    if now - lastShotTime < 100 then
        explosionAfterShot = explosionAfterShot + 1
        if explosionAfterShot >= 3 then
            Report('EXPLOSIVE_AMMO', ('explosion within 100ms of shot, %d times'):format(explosionAfterShot))
            explosionAfterShot = 0
        end
    end
end)

-- ==========================================
--  VEHICLE GODMODE DETECTION
-- ==========================================
local lastVehHealth = nil

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            lastVehHealth = nil
            goto continue
        end

        local veh    = GetVehiclePedIsIn(ped, false)
        local health = GetEntityHealth(veh)

        if lastVehHealth ~= nil then
            -- If vehicle was being shot/hit but health didn't change
            local underFire = IsEntityBeingJacked(veh)
            if underFire and health >= lastVehHealth and health < 1000 then
                Report('VEHICLE_GODMODE', ('veh health stuck at %d while under attack'):format(health))
            end
        end

        lastVehHealth = health
        ::continue::
    end
end)

-- ==========================================
--  ANTI-AFK BYPASS / MOVEMENT SPOOF
-- ==========================================
-- Detect suspiciously perfect movement patterns (bots/macros)
local movementLog = {}

CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        table.insert(movementLog, { pos = pos, heading = heading, t = GetGameTimer() })

        if #movementLog > 30 then
            table.remove(movementLog, 1)
        end

        -- Check for perfectly repeating coordinates (AFK machine / loop bot)
        if #movementLog >= 10 then
            local first = movementLog[1]
            local last  = movementLog[#movementLog]
            local dist  = #(first.pos - last.pos)

            -- Same spot for 30 seconds but sending movement events
            -- (this crosses into AFK macro territory)
            if dist < 0.5 and GetEntitySpeed(ped) > 0.1 then
                Report('MOVEMENT_SPOOF', 'entity reports speed but position unchanged')
            end
        end
    end
end)
