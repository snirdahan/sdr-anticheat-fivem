-- ==========================================
--      SDR ANTICHEAT - Admin Panel Client
-- ==========================================

local panelOpen = false

-- ==========================================
--  OPEN PANEL
-- ==========================================
RegisterNetEvent('sdr_anticheat:openPanel')
AddEventHandler('sdr_anticheat:openPanel', function(data)
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = 'open',
        players    = data.players,
        detections = data.detections,
        bans       = data.bans,
    })
end)

-- ==========================================
--  PUSH LIVE UPDATES
-- ==========================================
RegisterNetEvent('sdr_anticheat:panelDetection')
AddEventHandler('sdr_anticheat:panelDetection', function(det)
    if not panelOpen then return end
    SendNUIMessage({ action = 'newDetection', detection = det })
end)

RegisterNetEvent('sdr_anticheat:panelStrikes')
AddEventHandler('sdr_anticheat:panelStrikes', function(src, strikes)
    if not panelOpen then return end
    SendNUIMessage({ action = 'updatePlayerStrikes', src = src, strikes = strikes })
end)

-- ==========================================
--  NUI CALLBACKS
-- ==========================================
RegisterNUICallback('closePanel', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('adminAction', function(data, cb)
    TriggerServerEvent('sdr_anticheat:adminAction', data.type, data.target)
    cb('ok')
end)

-- ==========================================
--  KEYBIND: F9 to open panel (admin only)
-- ==========================================
RegisterCommand('acpanel', function()
    TriggerServerEvent('sdr_anticheat:requestPanel')
end, false)

RegisterKeyMapping('acpanel', 'SDR AntiCheat Panel', 'keyboard', 'F9')
