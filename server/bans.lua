-- ==========================================
--      SDR ANTICHEAT - Ban System
-- ==========================================

local bans = {}  -- runtime ban list: { [license] = { name, reason, time, ip, discord } }

-- Load bans from file on start
local function LoadBans()
    local data = LoadResourceFile(GetCurrentResourceName(), 'bans.json')
    if data then
        local ok, parsed = pcall(json.decode, data)
        if ok and parsed then
            bans = parsed
            print(('[SDR-AC] Loaded %d bans from file.'):format(#bans))
        end
    end
end

-- Save bans to file
local function SaveBans()
    local ok, data = pcall(json.encode, bans)
    if ok then
        SaveResourceFile(GetCurrentResourceName(), 'bans.json', data, -1)
    end
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        LoadBans()
    end
end)

-- ==========================================
--      BAN A PLAYER
-- ==========================================
function BanPlayer(src, name, license, discord, ip, reason)
    -- Kick with message
    DropPlayer(src, Config.BanMessage .. '\n\nReason: ' .. reason)

    -- Store ban
    bans[license] = {
        name    = name,
        reason  = reason,
        license = license,
        discord = discord,
        ip      = ip,
        time    = os.time(),
    }

    SaveBans()

    print(('[SDR-AC] BANNED | %s | License: %s | Reason: %s'):format(name, license, reason))

    -- Log to Discord
    LogBan(name, license, discord, ip, reason)
end

-- ==========================================
--      CHECK IF A PLAYER IS BANNED
-- ==========================================
function IsBanned(src)
    local license = GetPlayerIdentifierByType(src, 'license')
    local ip      = GetPlayerEndpoint(src)

    if not license then return false end

    -- Check by license
    if bans[license] then return true end

    -- Check by IP (catch alt accounts)
    for _, ban in pairs(bans) do
        if ban.ip == ip then return true end
    end

    return false
end

-- ==========================================
--      UNBAN
-- ==========================================
function UnbanPlayer(license)
    if bans[license] then
        bans[license] = nil
        SaveBans()
        return true
    end
    return false
end

-- ==========================================
--      LIST BANS (console)
-- ==========================================
RegisterCommand('acbans', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local count = 0
    for license, ban in pairs(bans) do
        print(('[SDR-AC] BAN | %s | %s | %s'):format(ban.name, license, ban.reason))
        count = count + 1
    end
    print(('[SDR-AC] Total bans: %d'):format(count))
end, true)
