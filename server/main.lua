-- ==========================================
--      SDR ANTICHEAT - Server Main
-- ==========================================

local playerStrikes = {}  -- [source] = number
local eventCount    = {}  -- [source] = { count, timer }

-- ==========================================
--      PLAYER CONNECT: send allowed resources
-- ==========================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    playerStrikes[src] = 0
    eventCount[src]    = { count = 0, t = os.time() }

    -- Check if player is banned
    if IsBanned(src) then
        deferrals.done(Config.BanMessage)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    playerStrikes[src] = nil
    eventCount[src]    = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Push allowed resources to all players
    for _, src in ipairs(GetPlayers()) do
        TriggerClientEvent('sdr_anticheat:setAllowedResources', src, Config.AllowedResources)
    end
end)

-- Send allowed resources to each new player
AddEventHandler('playerJoining', function()
    local src = source
    Wait(3000)
    TriggerClientEvent('sdr_anticheat:setAllowedResources', src, Config.AllowedResources)
end)

-- ==========================================
--      REPORT HANDLER
-- ==========================================
RegisterServerEvent('sdr_anticheat:report')
AddEventHandler('sdr_anticheat:report', function(detType, detail, evidence)
    local src     = source
    local name    = GetPlayerName(src) or 'Unknown'
    local license = GetPlayerIdentifierByType(src, 'license') or 'unknown'
    local discord = GetPlayerIdentifierByType(src, 'discord') or 'none'
    local ip      = GetPlayerEndpoint(src) or 'unknown'

    -- Init strikes if needed
    if not playerStrikes[src] then playerStrikes[src] = 0 end
    playerStrikes[src] = playerStrikes[src] + 1

    local strikes = playerStrikes[src]

    print(('[SDR-AC] DETECTION | Player: %s (%s) | Type: %s | Detail: %s | Strikes: %d/%d'):format(
        name, src, detType, detail, strikes, Config.MaxStrikes
    ))

    -- Log to Discord
    LogDetection(src, name, license, discord, ip, detType, detail, strikes)

    -- Notify admins
    NotifyAdmins(('[SDR-AC] %s (%s) - %s: %s [%d/%d strikes]'):format(
        name, src, detType, detail, strikes, Config.MaxStrikes
    ))

    -- Screenshot if available
    if Config.Screenshots then
        TriggerClientEvent('sdr_anticheat:takeScreenshot', src, detType .. ': ' .. detail)
    end

    -- Instant ban types (very serious detections)
    local instantBan = {
        RESOURCE_INJECTION = true,
    }

    if instantBan[detType] or strikes >= Config.MaxStrikes then
        BanPlayer(src, name, license, discord, ip, detType .. ' | ' .. detail)
    end
end)

-- ==========================================
--      SCREENSHOT RESULT
-- ==========================================
RegisterServerEvent('sdr_anticheat:screenshotResult')
AddEventHandler('sdr_anticheat:screenshotResult', function(reason, url)
    local src     = source
    local name    = GetPlayerName(src) or 'Unknown'
    local license = GetPlayerIdentifierByType(src, 'license') or 'unknown'

    LogScreenshot(name, license, reason, url)
end)

-- ==========================================
--      EVENT SPAM PROTECTION
-- ==========================================
local function checkEventSpam(src)
    if not Config.Detections.EventSpam.enabled then return false end

    if not eventCount[src] then
        eventCount[src] = { count = 0, t = os.time() }
    end

    local now = os.time()
    if now - eventCount[src].t >= 1 then
        eventCount[src].count = 0
        eventCount[src].t     = now
    end

    eventCount[src].count = eventCount[src].count + 1

    if eventCount[src].count > Config.Detections.EventSpam.maxPerSec then
        return true
    end

    return false
end

-- Hook all incoming events to detect spam
local originalTrigger = TriggerServerEvent
AddEventHandler('__cfx_internal:serverCallback', function()
    -- This hooks are not directly possible in Lua without C# natives,
    -- so we use a workaround via a rate-limiter on common events
end)

-- Rate limiter wrapper for your server's events (add your events here)
local function RateLimitedEvent(eventName, handler)
    RegisterServerEvent(eventName)
    AddEventHandler(eventName, function(...)
        local src = source
        if checkEventSpam(src) then
            local name = GetPlayerName(src) or 'Unknown'
            print(('[SDR-AC] EVENT SPAM | %s (%s) | event: %s'):format(name, src, eventName))
            DropPlayer(src, 'Event spam detected.')
            return
        end
        handler(src, ...)
    end)
end

-- ==========================================
--      ADMIN COMMANDS
-- ==========================================

-- View strikes
RegisterCommand('acstrikes', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local target = tonumber(args[1])
    if not target then
        print('[SDR-AC] Usage: /acstrikes <playerid>')
        return
    end

    local strikes = playerStrikes[target] or 0
    local name    = GetPlayerName(target) or 'Unknown'

    if src == 0 then
        print(('[SDR-AC] %s (%s): %d strikes'):format(name, target, strikes))
    else
        TriggerClientEvent('chat:addMessage', src, {
            args = { '[SDR-AC]', ('%s (%s): %d/%d strikes'):format(name, target, strikes, Config.MaxStrikes) }
        })
    end
end, true)

-- Manual ban
RegisterCommand('acban', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local target = tonumber(args[1])
    local reason = table.concat(args, ' ', 2) or 'Manual ban by admin'

    if not target or not GetPlayerName(target) then
        print('[SDR-AC] Usage: /acban <playerid> [reason]')
        return
    end

    local name    = GetPlayerName(target)
    local license = GetPlayerIdentifierByType(target, 'license') or 'unknown'
    local discord = GetPlayerIdentifierByType(target, 'discord') or 'none'
    local ip      = GetPlayerEndpoint(target) or 'unknown'

    BanPlayer(target, name, license, discord, ip, 'Admin ban: ' .. reason)
end, true)

-- Unban
RegisterCommand('acunban', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local license = args[1]
    if not license then
        print('[SDR-AC] Usage: /acunban <license>')
        return
    end

    UnbanPlayer(license)

    if src == 0 then
        print('[SDR-AC] Unbanned: ' .. license)
    else
        TriggerClientEvent('chat:addMessage', src, {
            args = { '[SDR-AC]', 'Unbanned: ' .. license }
        })
    end
end, true)

-- ==========================================
--      NOTIFY ADMINS
-- ==========================================
function NotifyAdmins(msg)
    for _, src in ipairs(GetPlayers()) do
        if IsPlayerAceAllowed(src, Config.AdminGroup) then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 0, 0 },
                multiline = true,
                args = { '🛡 SDR-AC', msg }
            })
        end
    end
end
