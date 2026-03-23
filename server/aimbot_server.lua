-- ==========================================
--      SDR ANTICHEAT - Aimbot Server Validation
-- ==========================================

local playerAimbotStrikes = {}
local sessionStats        = {}

-- ==========================================
--  RECEIVE AIMBOT REPORT
-- ==========================================
RegisterServerEvent('sdr_anticheat:aimbotReport')
AddEventHandler('sdr_anticheat:aimbotReport', function(ratio, kills, headshots)
    local src     = source
    local name    = GetPlayerName(src) or 'Unknown'
    local license = GetPlayerIdentifierByType(src, 'license') or 'unknown'

    if not playerAimbotStrikes[src] then playerAimbotStrikes[src] = 0 end
    playerAimbotStrikes[src] = playerAimbotStrikes[src] + 1

    local detail = ('%.0f%% HS ratio | %d/%d kills'):format(ratio * 100, headshots, kills)

    print(('[SDR-AC] AIMBOT REPORT | %s (%s) | %s | flag #%d'):format(
        name, src, detail, playerAimbotStrikes[src]
    ))

    -- Log to Discord with warning color (not instant ban - needs more evidence)
    LogDetection(src, name, license,
        GetPlayerIdentifierByType(src, 'discord') or 'none',
        GetPlayerEndpoint(src) or 'unknown',
        'AIMBOT_HEADSHOT',
        detail,
        playerAimbotStrikes[src]
    )

    NotifyAdmins(('⚠ AIMBOT SUSPECT | %s (%s) | %s'):format(name, src, detail))

    -- After 3 flags: screenshot + escalate to AC strike
    if playerAimbotStrikes[src] >= 3 then
        TriggerClientEvent('sdr_anticheat:takeScreenshot', src, 'Aimbot - ' .. detail)
        -- Feed into main strike system
        TriggerEvent('sdr_anticheat:report', src, 'AIMBOT_CONFIRMED', detail, '')
    end
end)

-- ==========================================
--  SESSION STATS (passive monitoring)
-- ==========================================
RegisterServerEvent('sdr_anticheat:sessionStats')
AddEventHandler('sdr_anticheat:sessionStats', function(data)
    local src  = source
    local name = GetPlayerName(src) or 'Unknown'

    sessionStats[src] = data

    -- Log to Discord for review (not auto-ban)
    if Config.DiscordLogs and Config.DiscordWebhook ~= '' then
        PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST',
            json.encode({
                username = 'SDR AntiCheat - Stats',
                embeds = {{
                    title  = '📊 Session Stats: ' .. name,
                    color  = data.hsRatio >= 0.70 and 16711680 or 3447003,
                    fields = {
                        { name = '👤 Player',     value = name,                                        inline = true },
                        { name = '🆔 ID',         value = tostring(src),                               inline = true },
                        { name = '🎯 Kills',      value = tostring(data.kills),                        inline = true },
                        { name = '💀 Headshots',  value = tostring(data.headshots),                    inline = true },
                        { name = '📈 HS Ratio',   value = ('%.0f%%'):format(data.hsRatio * 100),       inline = true },
                        { name = '⏱ Session',    value = data.sessionMin .. ' minutes',               inline = true },
                    },
                    footer = { text = Config.ServerName .. ' | SDR AntiCheat' },
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                }}
            }),
            { ['Content-Type'] = 'application/json' }
        )
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerAimbotStrikes[src] = nil
    sessionStats[src]        = nil
end)
