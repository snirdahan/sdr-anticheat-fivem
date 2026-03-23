-- ==========================================
--      SDR ANTICHEAT - HWID Ban System
-- ==========================================
-- FiveM doesn't expose raw hardware ID, so we build a fingerprint
-- from ALL available identifiers combined. This is much harder to
-- fully spoof than a single license change.

local hwidBans = {}   -- { [fingerprint] = { name, reason, time } }
local playerFingerprints = {}  -- { [src] = fingerprint }

-- ==========================================
--  BUILD FINGERPRINT FROM ALL IDENTIFIERS
-- ==========================================
local function BuildFingerprint(src)
    local ids = {}

    local types = { 'license', 'license2', 'steam', 'discord', 'xbl', 'live', 'fivem' }
    for _, t in ipairs(types) do
        local id = GetPlayerIdentifierByType(src, t)
        if id then
            ids[#ids+1] = id
        end
    end

    -- Sort so order doesn't matter
    table.sort(ids)
    return table.concat(ids, '|')
end

-- ==========================================
--  LOAD HWID BANS FROM FILE
-- ==========================================
local function LoadHwidBans()
    local data = LoadResourceFile(GetCurrentResourceName(), 'hwid_bans.json')
    if data then
        local ok, parsed = pcall(json.decode, data)
        if ok and parsed then
            hwidBans = parsed
            local count = 0
            for _ in pairs(hwidBans) do count = count + 1 end
            print(('[SDR-AC] Loaded %d HWID bans.'):format(count))
        end
    end
end

local function SaveHwidBans()
    local ok, data = pcall(json.encode, hwidBans)
    if ok then
        SaveResourceFile(GetCurrentResourceName(), 'hwid_bans.json', data, -1)
    end
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then LoadHwidBans() end
end)

-- ==========================================
--  CHECK HWID ON CONNECT
-- ==========================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local fp = BuildFingerprint(src)
    playerFingerprints[src] = fp

    deferrals.update('Checking identity...')

    if hwidBans[fp] then
        local ban = hwidBans[fp]
        deferrals.done(('[SDR-AC] You are hardware banned.\nReason: %s'):format(ban.reason))
        return
    end

    -- Also check partial fingerprint matches (e.g. player changed 1 identifier)
    -- Split fingerprint into individual IDs and check each
    local ids = {}
    for id in fp:gmatch('[^|]+') do ids[#ids+1] = id end

    for bannedFp, banData in pairs(hwidBans) do
        local matchCount = 0
        local bannedIds = {}
        for id in bannedFp:gmatch('[^|]+') do bannedIds[#bannedIds+1] = id end

        for _, myId in ipairs(ids) do
            for _, bannedId in ipairs(bannedIds) do
                if myId == bannedId then matchCount = matchCount + 1 end
            end
        end

        -- If 3+ identifiers match = same person (even if they changed some)
        if matchCount >= 3 then
            deferrals.done(('[SDR-AC] Hardware ban evasion detected.\nReason: %s'):format(banData.reason))
            return
        end
    end

    deferrals.done()
end)

AddEventHandler('playerDropped', function()
    playerFingerprints[source] = nil
end)

-- ==========================================
--  BAN BY HWID
-- ==========================================
function HwidBanPlayer(src, name, reason)
    local fp = playerFingerprints[src] or BuildFingerprint(src)

    hwidBans[fp] = {
        name   = name,
        reason = reason,
        time   = os.time(),
        ids    = GetPlayerIdentifiers(src),
    }

    SaveHwidBans()
    print(('[SDR-AC] HWID BANNED | %s | %s'):format(name, reason))
end

-- ==========================================
--  UNBAN HWID
-- ==========================================
function HwidUnban(fingerprint)
    if hwidBans[fingerprint] then
        hwidBans[fingerprint] = nil
        SaveHwidBans()
        return true
    end
    return false
end

-- ==========================================
--  EXPORT: get fingerprint for a player
-- ==========================================
exports('getPlayerFingerprint', function(src)
    return playerFingerprints[src] or BuildFingerprint(src)
end)

-- ==========================================
--  HOOK INTO MAIN BAN SYSTEM
-- ==========================================
-- Override BanPlayer to also do HWID ban
local originalBanPlayer = BanPlayer
function BanPlayer(src, name, license, discord, ip, reason)
    -- Call original license ban
    originalBanPlayer(src, name, license, discord, ip, reason)
    -- Also HWID ban
    HwidBanPlayer(src, name, reason)
end

-- ==========================================
--  COMMANDS
-- ==========================================
RegisterCommand('achwidban', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local target = tonumber(args[1])
    local reason = table.concat(args, ' ', 2) or 'Manual HWID ban'

    if not target or not GetPlayerName(target) then
        print('[SDR-AC] Usage: /achwidban <id> [reason]')
        return
    end

    HwidBanPlayer(target, GetPlayerName(target), reason)
    DropPlayer(target, Config.BanMessage)
    print(('[SDR-AC] HWID banned player %s'):format(GetPlayerName(target)))
end, true)

RegisterCommand('achwidlist', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminGroup) then return end

    local count = 0
    for fp, ban in pairs(hwidBans) do
        print(('[SDR-AC] HWID BAN | %s | %s | fp: %s...'):format(
            ban.name, ban.reason, fp:sub(1, 40)
        ))
        count = count + 1
    end
    print(('[SDR-AC] Total HWID bans: %d'):format(count))
end, true)
