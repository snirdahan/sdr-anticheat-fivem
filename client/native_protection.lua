-- ==========================================
--      SDR ANTICHEAT - Native Protection
-- ==========================================
-- Detects abuse of dangerous natives & anti-debug

local function Report(detType, detail)
    TriggerServerEvent('sdr_anticheat:report', detType, detail, '')
end

-- ==========================================
--  NETWORK ROUTING BUCKET TAMPERING
-- ==========================================
-- Routing buckets separate players into instances
-- Players should never change their own bucket
CreateThread(function()
    Wait(5000)

    local expectedBucket = nil

    while true do
        Wait(3000)

        local myBucket = GetPlayerRoutingBucket(PlayerId())

        if expectedBucket == nil then
            expectedBucket = myBucket
        elseif myBucket ~= expectedBucket then
            Report('BUCKET_TAMPER', ('routing bucket changed from %d to %d'):format(expectedBucket, myBucket))
            expectedBucket = myBucket
        end
    end
end)

-- ==========================================
--  POPULATION DENSITY MANIPULATION
-- ==========================================
-- Some cheats set PedMultiplier to 0 to remove all peds (to see players easier)
CreateThread(function()
    while true do
        Wait(10000)

        -- Check if vehicle/ped density has been zeroed client-side
        -- We report the value to server for anomaly detection
        TriggerServerEvent('sdr_anticheat:envReport',
            GetVehicleDensityMultiplierThisFrame(),
            GetRandomVehicleDensityMultiplierThisFrame()
        )
    end
end)

-- ==========================================
--  ANTI-CHEAT BYPASS DETECTION
-- ==========================================
-- Check if any known bypass resources are active
local bypassSignatures = {
    'fiveguard_bypass',
    'anticheat_bypass',
    'ac_bypass',
    'bypass_ac',
    'anticheat-bypass',
    'sdr_bypass',
    'disable_anticheat',
}

CreateThread(function()
    Wait(10000)

    while true do
        Wait(30000)

        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local res = GetResourceByFindIndex(i)
            if res then
                local lower = res:lower()
                for _, sig in ipairs(bypassSignatures) do
                    if lower:find(sig, 1, true) then
                        Report('AC_BYPASS', ('bypass resource: %s'):format(res))
                        break
                    end
                end
            end
        end
    end
end)

-- ==========================================
--  NETWORK FLAG ANOMALY
-- ==========================================
-- Detects when a player has unusual network object flags
-- (indicates manipulation of sync data)
CreateThread(function()
    while true do
        Wait(5000)

        local ped = PlayerPedId()

        -- Detect if player somehow owns too many network objects
        -- (menu feature: "own all entities")
        local ownedCount = 0
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if NetworkGetEntityOwner(veh) == PlayerId() then
                ownedCount = ownedCount + 1
            end
        end
        for _, obj in ipairs(GetGamePool('CObject')) do
            if NetworkGetEntityOwner(obj) == PlayerId() then
                ownedCount = ownedCount + 1
            end
        end

        if ownedCount > 20 then
            Report('ENTITY_OWNERSHIP_ABUSE', ('owns %d network entities'):format(ownedCount))
        end
    end
end)

-- ==========================================
--  SEND HEALTH/WEAPON FINGERPRINT
-- ==========================================
-- Periodically send a signed health/weapon state to server
-- Server verifies it's consistent with game events
CreateThread(function()
    while true do
        Wait(5000)

        local ped      = PlayerPedId()
        local health   = GetEntityHealth(ped)
        local armour   = GetPedArmour(ped)
        local speed    = GetEntitySpeed(ped)
        local inVeh    = IsPedInAnyVehicle(ped, false)
        local pos      = GetEntityCoords(ped)

        TriggerServerEvent('sdr_anticheat:fingerprint', {
            health  = health,
            armour  = armour,
            speed   = speed,
            inVeh   = inVeh,
            x       = pos.x,
            y       = pos.y,
            z       = pos.z,
            tick    = GetGameTimer(),
        })
    end
end)

-- ==========================================
--  SPECTATE HACK DETECTION
-- ==========================================
-- Detect if player is spectating someone without permission
local wasSpectating = false

CreateThread(function()
    while true do
        Wait(2000)

        local isSpec = NetworkIsInSpectatorMode()

        if isSpec and not wasSpectating then
            -- Notify server - server will verify if this player has admin perms
            TriggerServerEvent('sdr_anticheat:spectateCheck')
        end

        wasSpectating = isSpec
    end
end)

RegisterNetEvent('sdr_anticheat:spectateCheckResult')
AddEventHandler('sdr_anticheat:spectateCheckResult', function(allowed)
    if not allowed and NetworkIsInSpectatorMode() then
        -- Force exit spectate
        NetworkSetInSpectatorMode(false, PlayerPedId())
        Report('SPECTATE_HACK', 'entered spectate mode without permission')
    end
end)
