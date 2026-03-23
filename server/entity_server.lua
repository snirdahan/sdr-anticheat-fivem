-- ==========================================
--      SDR ANTICHEAT - Server Entity Validation
-- ==========================================

local authorizedVehicles = {}  -- [netId] = playerSrc (set when server spawns vehicle)
local playerDamageLog    = {}  -- [src] = { { target, dmg, time }, ... }
local playerHealthLog    = {}  -- [src] = { hp, armour, tick }

-- ==========================================
--  AUTHORIZE VEHICLE (call from your vehicle spawn script)
-- ==========================================
-- When your server spawns a vehicle for a player, call this:
exports('authorizeVehicle', function(src, netId)
    authorizedVehicles[netId] = src
end)

-- ==========================================
--  VALIDATE VEHICLE SPAWN
-- ==========================================
RegisterServerEvent('sdr_anticheat:validateVehicle')
AddEventHandler('sdr_anticheat:validateVehicle', function(netId, model)
    local src  = source
    local name = GetPlayerName(src) or 'Unknown'

    -- If vehicle not authorized by server, flag it
    if not authorizedVehicles[netId] then
        print(('[SDR-AC] Unauth vehicle | %s (%s) | model: %s | netId: %d'):format(name, src, model, netId))
        TriggerServerEvent('sdr_anticheat:report', 'UNAUTH_VEHICLE_SPAWN',
            ('model: %s netId: %d'):format(model, netId), '')

        -- Delete the vehicle via network
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end)

-- ==========================================
--  DAMAGE EVENT VALIDATION
-- ==========================================
RegisterServerEvent('sdr_anticheat:damageEvent')
AddEventHandler('sdr_anticheat:damageEvent', function(victimSrc, damage, weapHash, isDead)
    local src  = source
    local name = GetPlayerName(src) or 'Unknown'
    local now  = os.time()

    if not playerDamageLog[src] then playerDamageLog[src] = {} end

    table.insert(playerDamageLog[src], { target = victimSrc, dmg = damage, t = now, wep = weapHash })

    -- Keep last 10 seconds
    local cleaned = {}
    for _, entry in ipairs(playerDamageLog[src]) do
        if now - entry.t <= 10 then cleaned[#cleaned+1] = entry end
    end
    playerDamageLog[src] = cleaned

    -- Total damage in last 10 seconds
    local totalDmg = 0
    for _, entry in ipairs(playerDamageLog[src]) do
        totalDmg = totalDmg + entry.dmg
    end

    -- 10000+ damage in 10 seconds is absurd
    if totalDmg > 10000 then
        TriggerServerEvent('sdr_anticheat:report', 'DAMAGE_OVERFLOW',
            ('dealt %d total damage in 10s'):format(totalDmg), '')
        playerDamageLog[src] = {}
    end

    -- Single hit > 1000 damage (even heavy sniper is ~500)
    if damage > 1000 then
        TriggerServerEvent('sdr_anticheat:report', 'SUPER_DAMAGE',
            ('single hit: %d damage'):format(damage), '')
    end
end)

-- ==========================================
--  FINGERPRINT VALIDATION (health/pos cross-check)
-- ==========================================
RegisterServerEvent('sdr_anticheat:fingerprint')
AddEventHandler('sdr_anticheat:fingerprint', function(data)
    local src = source
    local prev = playerHealthLog[src]

    if prev then
        local timeDiff = (data.tick - prev.tick) / 1000.0

        if timeDiff > 0 then
            -- Health gain rate check (server-side)
            local hpGain = data.health - prev.health
            local rate   = hpGain / timeDiff

            if rate > 50 then  -- 50 HP/sec is impossible naturally
                TriggerServerEvent('sdr_anticheat:report', 'HEAL_SERVER_VALIDATE',
                    ('server confirmed +%.1f HP/sec'):format(rate), '')
            end

            -- Position vs speed cross-check
            local dx   = data.x - prev.x
            local dy   = data.y - prev.y
            local dz   = data.z - prev.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local calcSpeed = dist / timeDiff

            -- If claimed speed doesn't match position change
            if not data.inVeh and calcSpeed > 20.0 and data.speed < 5.0 then
                TriggerServerEvent('sdr_anticheat:report', 'POSITION_SPOOF',
                    ('moved %.1f units but speed reported %.1f'):format(dist, data.speed), '')
            end
        end
    end

    playerHealthLog[src] = data
end)

-- ==========================================
--  INTEGRITY PING VALIDATION
-- ==========================================
local integrityBaseline = {}

RegisterServerEvent('sdr_anticheat:integrityPing')
AddEventHandler('sdr_anticheat:integrityPing', function(result1, result2, tick)
    local src = source

    if not integrityBaseline[src] then
        integrityBaseline[src] = { r1 = result1, r2 = result2 }
        return
    end

    -- If native return values suddenly change, it may indicate hooking
    if integrityBaseline[src].r1 ~= result1 or integrityBaseline[src].r2 ~= result2 then
        TriggerServerEvent('sdr_anticheat:report', 'NATIVE_HOOK_DETECTED',
            ('native return changed: %s->%s | %s->%s'):format(
                tostring(integrityBaseline[src].r1), tostring(result1),
                tostring(integrityBaseline[src].r2), tostring(result2)
            ), '')
    end
end)

-- ==========================================
--  WANTED LEVEL MANIPULATION (server cross-check)
-- ==========================================
local wantedLog = {}

RegisterServerEvent('sdr_anticheat:wantedLevel')
AddEventHandler('sdr_anticheat:wantedLevel', function(level)
    local src = source
    local now = os.time()
    local prev = wantedLog[src]

    if prev and prev.level >= 4 and level == 0 and now - prev.t < 3 then
        TriggerServerEvent('sdr_anticheat:report', 'WANTED_CLEAR',
            ('wanted went from %d to 0 instantly'):format(prev.level), '')
    end

    wantedLog[src] = { level = level, t = now }
end)

-- ==========================================
--  SPECTATE CHECK (server verifies admin)
-- ==========================================
RegisterServerEvent('sdr_anticheat:spectateCheck')
AddEventHandler('sdr_anticheat:spectateCheck', function()
    local src     = source
    local allowed = IsPlayerAceAllowed(src, Config.AdminGroup)
    TriggerClientEvent('sdr_anticheat:spectateCheckResult', src, allowed)
end)

-- ==========================================
--  CLEANUP ON DISCONNECT
-- ==========================================
AddEventHandler('playerDropped', function()
    local src = source
    authorizedVehicles[src] = nil
    playerDamageLog[src]    = nil
    playerHealthLog[src]    = nil
    wantedLog[src]          = nil
    integrityBaseline[src]  = nil
end)
