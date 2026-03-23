-- ==========================================
--      SDR ANTICHEAT - Damage Monitor
-- ==========================================

local function Report(detType, detail)
    TriggerServerEvent('sdr_anticheat:report', detType, detail, '')
end

-- ==========================================
--  ONE-HIT KILL DETECTION (dealt by this player)
-- ==========================================
-- We track when this player kills someone too fast
local recentKills = {}

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim     = args[1]
    local attacker   = args[2]
    local isDead     = args[4]
    local weapHash   = args[5]

    -- Only care about kills this player caused
    if attacker ~= PlayerPedId() then return end
    if not isDead then return end
    if not IsPedAPlayer(victim) then return end

    local now = GetGameTimer()
    local victimId = PedToNet(victim)

    if recentKills[victimId] then
        local timeSinceLast = now - recentKills[victimId]
        -- If killed same player again within 500ms = one-shot exploit
        if timeSinceLast < 500 then
            Report('ONE_SHOT_KILL', ('killed player %d twice in %dms'):format(victimId, timeSinceLast))
        end
    end

    recentKills[victimId] = now
end)

-- ==========================================
--  DAMAGE AMOUNT MONITOR
-- ==========================================
-- Track outgoing damage - report to server for validation
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim    = args[1]
    local attacker  = args[2]
    local damageRaw = args[3] or 0
    local isDead    = args[4]
    local weapHash  = args[5]

    if attacker ~= PlayerPedId() then return end
    if not IsPedAPlayer(victim) then return end

    -- Max legit damage per hit varies by weapon, ~500 for heavy sniper
    if damageRaw > 500 then
        Report('DAMAGE_HACK', ('dealt %d damage in one hit with weapon %s'):format(damageRaw, weapHash))
    end

    -- Report to server for cross-validation
    TriggerServerEvent('sdr_anticheat:damageEvent',
        GetPlayerServerId(NetworkGetPlayerIndexFromPed(victim)),
        damageRaw,
        weapHash,
        isDead
    )
end)

-- ==========================================
--  HEAL HACK DETECTION (instant heal)
-- ==========================================
local healthHistory = {}
local MAX_HEAL_RATE = 5 -- HP per second natural regen is ~1/sec

CreateThread(function()
    while true do
        Wait(200)

        local ped    = PlayerPedId()
        local health = GetEntityHealth(ped)
        local now    = GetGameTimer()

        table.insert(healthHistory, { hp = health, t = now })

        -- Keep last 5 seconds
        local cutoff = now - 5000
        local cleaned = {}
        for _, entry in ipairs(healthHistory) do
            if entry.t >= cutoff then cleaned[#cleaned+1] = entry end
        end
        healthHistory = cleaned

        -- Check heal rate over last 1 second
        if #healthHistory >= 5 then
            local oldest = healthHistory[1]
            local newest = healthHistory[#healthHistory]
            local timeDiff = (newest.t - oldest.t) / 1000.0
            local hpDiff   = newest.hp - oldest.hp

            if timeDiff > 0 and hpDiff > 0 then
                local rate = hpDiff / timeDiff

                if rate > MAX_HEAL_RATE * 10 then
                    Report('HEAL_HACK', ('healed %.1f HP/sec'):format(rate))
                    healthHistory = {}
                end
            end
        end
    end
end)

-- ==========================================
--  ARMOUR HACK DETECTION
-- ==========================================
local lastArmourValue = nil

CreateThread(function()
    while true do
        Wait(500)

        local ped    = PlayerPedId()
        local armour = GetPedArmour(ped)

        if lastArmourValue ~= nil then
            local gain = armour - lastArmourValue
            -- Max armour pickup is 100 units. More than that = injected.
            if gain > 100 then
                Report('ARMOUR_INJECT', ('armour jumped +%d in 500ms'):format(gain))
            end
        end

        lastArmourValue = armour
    end
end)
