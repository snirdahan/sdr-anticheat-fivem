-- ==========================================
--      SDR ANTICHEAT - Extra Detections
-- ==========================================

-- ==========================================
--      BLACKLISTED PED MODEL
-- ==========================================
CreateThread(function()
    while true do
        Wait(5000)

        if not Config.Detections.BlacklistedPeds.enabled then break end

        local ped   = PlayerPedId()
        local model = GetEntityModel(ped)

        if Config.Detections.BlacklistedPeds.blockAll then
            -- Whitelist mode: only allowed models pass
            local allowed = false
            for _, m in ipairs(Config.Detections.BlacklistedPeds.list) do
                if model == m then allowed = true break end
            end
            if not allowed then
                TriggerServerEvent('sdr_anticheat:report', 'PED_MODEL', ('model hash: %s'):format(model), '')
            end
        else
            -- Blacklist mode: block specific models
            for _, m in ipairs(Config.Detections.BlacklistedPeds.list) do
                if model == m then
                    TriggerServerEvent('sdr_anticheat:report', 'PED_MODEL', ('blacklisted model: %s'):format(m), '')
                    break
                end
            end
        end
    end
end)

-- ==========================================
--      INVISIBLE / NULL ENTITY DETECTION
-- ==========================================
CreateThread(function()
    while true do
        Wait(5000)

        local ped = PlayerPedId()

        -- Detect if player is invisible (common cheat)
        if not IsEntityVisible(ped) and not IsEntityDead(ped) then
            -- Try to fix first
            SetEntityVisible(ped, true, false)
            TriggerServerEvent('sdr_anticheat:report', 'INVISIBLE', 'player was invisible', '')
        end
    end
end)

-- ==========================================
--      FREEZE / SUSPENDED ANIMATION BYPASS
-- ==========================================
CreateThread(function()
    while true do
        Wait(5000)

        local ped = PlayerPedId()

        -- Detect if player froze themselves (immortality trick)
        if IsEntityPositionFrozen(ped) and not IsEntityDead(ped) then
            FreezeEntityPosition(ped, false)
            TriggerServerEvent('sdr_anticheat:report', 'FREEZE_POSITION', 'entity position frozen', '')
        end
    end
end)

-- ==========================================
--      SPECTATE / CAM HACK DETECTION
-- ==========================================
local lastCamPos = nil

CreateThread(function()
    while true do
        Wait(2000)

        local ped = PlayerPedId()

        -- Detect if rendering camera is very far from player (spectate cheat)
        if not IsCamRendering(GetRenderingCam()) then
            local camCoords = GetGameplayCamCoord()
            local pedCoords = GetEntityCoords(ped)
            local dist      = #(camCoords - pedCoords)

            if dist > 200.0 then
                TriggerServerEvent('sdr_anticheat:report', 'CAM_HACK', ('cam %.1f units from player'):format(dist), '')
            end
        end
    end
end)
