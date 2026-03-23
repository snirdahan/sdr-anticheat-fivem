-- ==========================================
--      SDR ANTICHEAT - Entity Monitor
-- ==========================================
-- Detects client-side entity spawning, object abuse, ped spawning

local function Report(detType, detail)
    TriggerServerEvent('sdr_anticheat:report', detType, detail, '')
end

-- ==========================================
--  CLIENT-SIDE ENTITY SPAWN DETECTION
-- ==========================================
-- Players should NEVER spawn vehicles/peds via client without server auth
-- We detect when nearby entities have no network owner or wrong owner

local knownEntities = {}
local spawnSpikeCount = 0

CreateThread(function()
    Wait(10000) -- allow initial world to load

    while true do
        Wait(3000)

        local ped     = PlayerPedId()
        local pos     = GetEntityCoords(ped)
        local myId    = GetPlayerServerId(PlayerId())

        -- Check vehicles near player
        local vehicles = GetGamePool('CVehicle')
        local currentVehs = {}

        for _, veh in ipairs(vehicles) do
            local vehPos = GetEntityCoords(veh)
            local dist   = #(pos - vehPos)

            if dist < 100.0 then
                local netId = NetworkGetNetworkIdFromEntity(veh)
                currentVehs[netId] = true

                if not knownEntities['veh_' .. netId] then
                    knownEntities['veh_' .. netId] = true

                    -- Check if this vehicle was spawned by this player without server event
                    if NetworkGetEntityOwner(veh) == PlayerId() then
                        -- Notify server to validate
                        TriggerServerEvent('sdr_anticheat:validateVehicle', netId, GetEntityModel(veh))
                    end
                end
            end
        end

        -- Detect sudden spike in nearby vehicles (spawn bomb)
        local nearCount = #GetGamePool('CVehicle')
        if nearCount > 50 then
            spawnSpikeCount = spawnSpikeCount + 1
            if spawnSpikeCount >= 2 then
                Report('SPAWN_BOMB', ('%d vehicles in pool'):format(nearCount))
                spawnSpikeCount = 0
            end
        else
            spawnSpikeCount = 0
        end
    end
end)

-- ==========================================
--  PED SPAWNING DETECTION
-- ==========================================
local lastPedCount = 0

CreateThread(function()
    Wait(10000)

    while true do
        Wait(5000)

        local peds = GetGamePool('CPed')
        local count = #peds

        if count - lastPedCount > 20 then
            Report('PED_SPAWN_SPIKE', ('%d new peds spawned in 5 seconds'):format(count - lastPedCount))
        end

        lastPedCount = count
    end
end)

-- ==========================================
--  OBJECT SPAWN DETECTION (prop abuse)
-- ==========================================
local lastObjCount = 0

CreateThread(function()
    Wait(10000)

    while true do
        Wait(3000)

        local objs  = GetGamePool('CObject')
        local count = #objs

        if count - lastObjCount > 30 then
            Report('OBJECT_SPAM', ('%d objects spawned in 3 seconds'):format(count - lastObjCount))
        end

        lastObjCount = count
    end
end)

-- ==========================================
--  BLACKLISTED OBJECTS (crash objects)
-- ==========================================
local crashObjects = {
    `prop_mp_ramp_01`,
    `prop_mp_ramp_02`,
    `prop_mp_ramp_03`,
    `prop_mp_ramp_04`,
    `prop_mp_ramp_05`,
    `prop_mp_ramp_06`,
    `prop_mp_ramp_07`,
    `prop_mp_ramp_08`,
    -- crash props
    `prop_dummy_01`,
    `prop_dummy_car`,
}

CreateThread(function()
    while true do
        Wait(5000)

        local ped  = PlayerPedId()
        local pos  = GetEntityCoords(ped)
        local objs = GetGamePool('CObject')

        for _, obj in ipairs(objs) do
            local model = GetEntityModel(obj)
            local opos  = GetEntityCoords(obj)
            local dist  = #(pos - opos)

            if dist < 200.0 then
                for _, banned in ipairs(crashObjects) do
                    if model == banned then
                        -- Delete the object locally and report
                        if NetworkGetEntityOwner(obj) == PlayerId() then
                            DeleteEntity(obj)
                        end
                        Report('CRASH_OBJECT', ('crash object spawned: %s'):format(model))
                        break
                    end
                end
            end
        end
    end
end)
