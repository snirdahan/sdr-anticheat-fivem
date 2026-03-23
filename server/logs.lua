-- ==========================================
--      SDR ANTICHEAT - Discord Logs
-- ==========================================

local function SendWebhook(embed)
    if not Config.DiscordLogs or Config.DiscordWebhook == '' then return end

    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST',
        json.encode({
            username = 'SDR AntiCheat',
            avatar_url = 'https://i.imgur.com/4M34hi2.png',
            embeds = { embed }
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

-- ==========================================
--      DETECTION LOG
-- ==========================================
function LogDetection(src, name, license, discord, ip, detType, detail, strikes)
    local embed = {
        title       = '⚠️ Detection: ' .. detType,
        color       = 16776960,  -- yellow
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer      = { text = Config.ServerName .. ' | SDR AntiCheat' },
        fields      = {
            { name = '👤 Player',   value = name,    inline = true },
            { name = '🆔 ID',       value = tostring(src), inline = true },
            { name = '📋 Strikes',  value = strikes .. '/' .. Config.MaxStrikes, inline = true },
            { name = '🔍 Detail',   value = detail,  inline = false },
            { name = '🪪 License',  value = license, inline = true },
            { name = '💬 Discord',  value = discord, inline = true },
            { name = '🌐 IP',       value = ip,      inline = true },
        }
    }
    SendWebhook(embed)
end

-- ==========================================
--      BAN LOG
-- ==========================================
function LogBan(name, license, discord, ip, reason)
    local embed = {
        title       = '🔨 Player Banned',
        color       = 16711680,  -- red
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer      = { text = Config.ServerName .. ' | SDR AntiCheat' },
        fields      = {
            { name = '👤 Player',   value = name,    inline = true },
            { name = '🪪 License',  value = license, inline = true },
            { name = '💬 Discord',  value = discord, inline = true },
            { name = '🌐 IP',       value = ip,      inline = true },
            { name = '📝 Reason',   value = reason,  inline = false },
        }
    }
    SendWebhook(embed)
end

-- ==========================================
--      SCREENSHOT LOG
-- ==========================================
function LogScreenshot(name, license, reason, url)
    local embed = {
        title       = '📸 Screenshot Captured',
        color       = 3447003,   -- blue
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer      = { text = Config.ServerName .. ' | SDR AntiCheat' },
        image       = { url = url },
        fields      = {
            { name = '👤 Player',  value = name,    inline = true },
            { name = '🪪 License', value = license, inline = true },
            { name = '⚠️ Reason',  value = reason,  inline = false },
        }
    }
    SendWebhook(embed)
end
