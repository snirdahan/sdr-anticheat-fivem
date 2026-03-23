-- ==========================================
--      SDR ANTICHEAT - Admin Panel Server
-- ==========================================

local detectionHistory = {}  -- last 100 detections for panel
local MAX_HISTORY = 100

-- ==========================================
--  HOOK INTO REPORT SYSTEM - PUSH TO PANEL
-- ==========================================
local originalReport = AddEventHandler
local function PushDetectionToAdmins(src, detType, detail)
    local name = GetPlayerName(src) or 'Unknown'
    local h, m, s = GetClockHours(), GetClockMinutes(), GetClockSeconds()
    local timeStr = ('%02d:%02d:%02d'):format(h, m, s)

    local det = {
        src    = src,
        name   = name,
        type   = detType,
        detail = detail,
        time   = timeStr,
    }

    table.insert(detectionHistory, 1, det)
    if #detectionHistory > MAX_HISTORY then
        table.remove(detectionHistory)
    end

    -- Push live to all open admin panels
    for _, adminSrc in ipairs(GetPlayers()) do
        if IsPlayerAceAllowed(adminSrc, Config.AdminGroup) then
            TriggerClientEvent('sdr_anticheat:panelDetection', adminSrc, det)
        end
    end
end

-- Override the report event to also feed the panel
AddEventHandler('sdr_anticheat:report', function(detType, detail)
    local src = source
    -- Push to panel (after a tick so main handler runs first)
    SetTimeout(0, function()
        PushDetectionToAdmins(src, detType, detail)

        -- Push updated strikes
        local strikes = playerStrikes and playerStrikes[src] or 0
        for _, adminSrc in ipairs(GetPlayers()) do
            if IsPlayerAceAllowed(adminSrc, Config.AdminGroup) then
                TriggerClientEvent('sdr_anticheat:panelStrikes', adminSrc, src, strikes)
            end
        end
    end)
end)

-- ==========================================
--  BUILD PLAYER LIST FOR PANEL
-- ==========================================
local function BuildPlayerList()
    local list = {}
    for _, src in ipairs(GetPlayers()) do
        local srcNum = tonumber(src)
        list[#list+1] = {
            id          = srcNum,
            name        = GetPlayerName(srcNum) or 'Unknown',
            strikes     = playerStrikes and playerStrikes[srcNum] or 0,
            maxStrikes  = Config.MaxStrikes,
            hsRatio     = nil,  -- populated from aimbot data if available
            fingerprint = exports['sdr_anticheat']:getPlayerFingerprint(srcNum) or '',
        }
    end
    return list
end

-- ==========================================
--  BUILD BAN LIST FOR PANEL
-- ==========================================
local function BuildBanList()
    local list = {}
    if bans then
        for license, ban in pairs(bans) do
            list[#list+1] = {
                name    = ban.name,
                reason  = ban.reason,
                license = license,
                time    = ban.time,
            }
        end
    end
    return list
end

-- ==========================================
--  REQUEST PANEL (from client)
-- ==========================================
RegisterServerEvent('sdr_anticheat:requestPanel')
AddEventHandler('sdr_anticheat:requestPanel', function()
    local src = source

    -- Check admin permission
    if not IsPlayerAceAllowed(src, Config.AdminGroup) then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 0, 0 },
            args  = { '[SDR-AC]', 'You do not have permission to open the panel.' }
        })
        return
    end

    TriggerClientEvent('sdr_anticheat:openPanel', src, {
        players    = BuildPlayerList(),
        detections = detectionHistory,
        bans       = BuildBanList(),
    })
end)

-- ==========================================
--  ADMIN ACTIONS FROM PANEL
-- ==========================================
RegisterServerEvent('sdr_anticheat:adminAction')
AddEventHandler('sdr_anticheat:adminAction', function(actionType, target)
    local src = source

    if not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local adminName = GetPlayerName(src) or 'Admin'

    if actionType == 'kick' then
        local targetNum = tonumber(target)
        if GetPlayerName(targetNum) then
            local name = GetPlayerName(targetNum)
            DropPlayer(targetNum, 'You have been kicked by an admin.')
            NotifyAdmins(('👢 %s kicked %s'):format(adminName, name))
            LogAdminAction(adminName, 'KICK', name)
        end

    elseif actionType == 'ban' then
        local targetNum = tonumber(target)
        if GetPlayerName(targetNum) then
            local name    = GetPlayerName(targetNum)
            local license = GetPlayerIdentifierByType(targetNum, 'license') or 'unknown'
            local discord = GetPlayerIdentifierByType(targetNum, 'discord') or 'none'
            local ip      = GetPlayerEndpoint(targetNum) or 'unknown'
            BanPlayer(targetNum, name, license, discord, ip, 'Admin ban by ' .. adminName)
            NotifyAdmins(('🔨 %s banned %s'):format(adminName, name))
            LogAdminAction(adminName, 'BAN', name)
        end

    elseif actionType == 'warn' then
        local targetNum = tonumber(target)
        if GetPlayerName(targetNum) then
            local name = GetPlayerName(targetNum)
            TriggerClientEvent('sdr_anticheat:notify', targetNum,
                ('You have received a warning from an admin. Behave yourself!'))
            NotifyAdmins(('⚠ %s warned %s'):format(adminName, name))
        end

    elseif actionType == 'ss' then
        local targetNum = tonumber(target)
        if GetPlayerName(targetNum) then
            TriggerClientEvent('sdr_anticheat:takeScreenshot', targetNum, 'Admin request')
        end

    elseif actionType == 'tp' then
        -- Teleport admin to target
        local targetNum = tonumber(target)
        if GetPlayerName(targetNum) then
            TriggerClientEvent('sdr_anticheat:tpToPlayer', src, targetNum)
        end

    elseif actionType == 'unban' then
        -- target is license string for unban
        if UnbanPlayer(target) then
            NotifyAdmins(('✅ %s removed ban: %s'):format(adminName, target))
        end
    end
end)

-- ==========================================
--  LOG ADMIN ACTIONS TO DISCORD
-- ==========================================
function LogAdminAction(adminName, actionType, targetName)
    if not Config.DiscordLogs or Config.DiscordWebhook == '' then return end

    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST',
        json.encode({
            username = 'SDR AntiCheat - Admin',
            embeds = {{
                title  = '👮 Admin Action: ' .. actionType,
                color  = 3447003,
                fields = {
                    { name = 'Admin',  value = adminName,  inline = true },
                    { name = 'Action', value = actionType, inline = true },
                    { name = 'Target', value = targetName, inline = true },
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                footer    = { text = Config.ServerName .. ' | SDR AntiCheat' },
            }}
        }),
        { ['Content-Type'] = 'application/json' }
    )
end
