-- ==========================================
--      SDR ANTICHEAT - Client Main
-- ==========================================

local playerStrikes     = 0
local lastDetection     = {}
local playerPos         = nil
local lastHealth        = nil
local lastArmour        = nil
local explosionCount    = 0
local isInVehicle       = false

-- Utility: check cooldown per detection type
local function canReport(detType)
    local now = GetGameTimer()
    if not lastDetection[detType] or (now - lastDetection[detType]) >= Config.DetectionCooldown then
        lastDetection[detType] = now
        return true
    end
    return false
end

-- Report a detection to server
local function Report(detType, detail, evidence)
    if not canReport(detType) then return end
    TriggerServerEvent('sdr_anticheat:report', detType, detail, evidence or '')
end

-- ==========================================
--          POSITION LOOP (Speed + Teleport + NoClip)
-- ==========================================
CreateThread(function()
    while true do
        Wait(1000)

        local ped   = PlayerPedId()
        local pos   = GetEntityCoords(ped)
        local speed = GetEntitySpeed(ped)

        if playerPos then
            local dist = #(pos - playerPos)

            -- Teleport detection
            if Config.Detections.Teleport.enabled then
                local inVeh = IsPedInAnyVehicle(ped, false)
                local maxD  = Config.Detections.Teleport.maxDistance

                if dist > maxD and not inVeh and not IsEntityDead(ped) then
                    Report('TELEPORT', ('moved %.1f units in 1 second'):format(dist))
                end
            end

            -- NoClip detection: large vertical gain without vehicle/parachute
            if Config.Detections.NoClip.enabled then
                local vertDiff = pos.z - playerPos.z
                if vertDiff > 50.0 and not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) then
                    local hasParachute = HasPedGotWeapon(ped, `GADGET_PARACHUTE`, false)
                    if not hasParachute then
                        Report('NOCLIP', ('vertical jump %.1f units'):format(vertDiff))
                    end
                end
            end
        end

        -- Speed hack on foot
        if Config.Detections.SpeedHackFoot.enabled then
            if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                if speed > Config.Detections.SpeedHackFoot.maxSpeed then
                    Report('SPEEDHACK_FOOT', ('speed: %.2f m/s'):format(speed))
                end
            end
        end

        -- Speed hack in vehicle
        if Config.Detections.SpeedHackVehicle.enabled then
            if IsPedInAnyVehicle(ped, false) then
                if speed > Config.Detections.SpeedHackVehicle.maxSpeed then
                    Report('SPEEDHACK_VEHICLE', ('speed: %.2f m/s'):format(speed))
                end
            end
        end

        playerPos = pos
    end
end)

-- ==========================================
--              GOD MODE
-- ==========================================
CreateThread(function()
    while true do
        Wait(Config.Detections.GodMode.checkDelay)

        if not Config.Detections.GodMode.enabled then break end

        local ped     = PlayerPedId()
        local health  = GetEntityHealth(ped)
        local armour  = GetPedArmour(ped)

        -- If ped was shot/damaged but health/armor never changed
        if lastHealth ~= nil and lastArmour ~= nil then
            local wasHit = IsPedBeingJacked(ped) or IsPedBeingShotAt(ped, true)

            if wasHit then
                if health >= lastHealth and armour >= lastArmour and not IsEntityDead(ped) then
                    Report('GODMODE', ('HP: %d -> %d | ARM: %d -> %d'):format(lastHealth, health, lastArmour, armour))
                end
            end
        end

        lastHealth = health
        lastArmour = armour
    end
end)

-- ==========================================
--          WEAPON INJECTION
-- ==========================================
CreateThread(function()
    while true do
        Wait(3000)

        if not Config.Detections.WeaponInjection.enabled then break end

        local ped = PlayerPedId()

        -- Check blacklisted weapons
        if Config.Detections.BlacklistedWeapons.enabled then
            for _, weaponHash in ipairs(Config.Detections.BlacklistedWeapons.list) do
                if HasPedGotWeapon(ped, weaponHash, false) then
                    RemoveWeaponFromPed(ped, weaponHash)
                    Report('WEAPON_BLACKLIST', ('hash: %s'):format(weaponHash))
                end
            end
        end
    end
end)

-- ==========================================
--          VEHICLE BLACKLIST
-- ==========================================
CreateThread(function()
    while true do
        Wait(2000)

        if not Config.Detections.BlacklistedVehicles.enabled then break end

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh   = GetVehiclePedIsIn(ped, false)
            local model = GetEntityModel(veh)

            for _, banned in ipairs(Config.Detections.BlacklistedVehicles.list) do
                if model == banned then
                    TaskLeaveVehicle(ped, veh, 0)
                    Wait(500)
                    DeleteEntity(veh)
                    Report('VEHICLE_BLACKLIST', ('model: %s'):format(banned))
                    break
                end
            end
        end
    end
end)

-- ==========================================
--          EXPLOSION SPAM
-- ==========================================
AddEventHandler('explosionEvent', function(sender, ev)
    if not Config.Detections.ExplosionSpam.enabled then return end

    explosionCount = explosionCount + 1
end)

CreateThread(function()
    while true do
        Wait(1000)

        if not Config.Detections.ExplosionSpam.enabled then break end

        if explosionCount > Config.Detections.ExplosionSpam.maxPerSecond then
            Report('EXPLOSION_SPAM', ('%d explosions/sec'):format(explosionCount))
        end
        explosionCount = 0
    end
end)

-- ==========================================
--          RESOURCE INJECTION
-- ==========================================
CreateThread(function()
    Wait(5000) -- wait for server to send allowed list

    while true do
        Wait(10000)

        if not Config.Detections.ResourceInjection.enabled then return end

        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local res = GetResourceByFindIndex(i)
            if res and GetResourceState(res) == 'started' then
                local allowed = false
                for _, name in ipairs(Config.AllowedResources) do
                    if name == res then
                        allowed = true
                        break
                    end
                end

                if not allowed then
                    Report('RESOURCE_INJECTION', ('unknown resource: %s'):format(res))
                end
            end
        end
    end
end)

-- ==========================================
--          RECEIVE ALLOWED RESOURCES FROM SERVER
-- ==========================================
RegisterNetEvent('sdr_anticheat:setAllowedResources', function(list)
    Config.AllowedResources = list
end)

-- ==========================================
--          ADMIN: KICK/BAN FEEDBACK
-- ==========================================
RegisterNetEvent('sdr_anticheat:notify', function(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString('~r~[SDR-AC]~w~ ' .. msg)
    DrawNotification(false, true)
end)
