-- ==========================================
--      SDR ANTICHEAT - Aimbot Detection
-- ==========================================

local function Report(detType, detail)
    TriggerServerEvent('sdr_anticheat:report', detType, detail, '')
end

-- ==========================================
--  HEADSHOT RATIO TRACKING
-- ==========================================
local totalKills     = 0
local headshotKills  = 0
local sessionStart   = GetGameTimer()

-- FiveM exposes bone damage via gameEventTriggered
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim    = args[1]
    local attacker  = args[2]
    local isDead    = args[4]
    local weapHash  = args[5]
    local boneIndex = args[6]   -- bone hit

    if attacker ~= PlayerPedId() then return end
    if not isDead then return end
    if not IsPedAPlayer(victim) then return end

    totalKills = totalKills + 1

    -- Bone 31086 = head bone in GTA V
    if boneIndex == 31086 then
        headshotKills = headshotKills + 1
    end

    -- Start checking after minimum sample size
    if totalKills >= 10 then
        local ratio = headshotKills / totalKills

        if ratio >= 0.90 then
            -- 90%+ headshots is statistically impossible without aimbot
            TriggerServerEvent('sdr_anticheat:aimbotReport',
                ratio,
                totalKills,
                headshotKills
            )
            Report('AIMBOT_HEADSHOT', ('%.0f%% headshot ratio (%d/%d kills)'):format(ratio * 100, headshotKills, totalKills))

            -- Reset after flagging so we don't spam
            totalKills    = 0
            headshotKills = 0
        end
    end
end)

-- ==========================================
--  AIM SNAP DETECTION
-- ==========================================
-- Aimbot snaps the camera to a target very fast
-- Normal mouse has a maximum realistic turn speed

local lastHeading    = nil
local lastHeadingTime = 0
local snapCount      = 0
local MAX_TURN_DEG_PER_SEC = 1200  -- degrees/sec, very fast legit player ~800

CreateThread(function()
    while true do
        Wait(50)  -- 20 checks per second

        local ped       = PlayerPedId()
        local heading   = GetEntityHeading(ped)
        local camHeading = GetGameplayCamRelativeHeading()
        local combined  = heading + camHeading
        local now       = GetGameTimer()

        if lastHeading ~= nil then
            local timeDiff = (now - lastHeadingTime) / 1000.0
            if timeDiff > 0 then
                local angleDiff = math.abs(combined - lastHeading)

                -- Handle wrap-around (e.g. 350 -> 10 = 20 degrees, not 340)
                if angleDiff > 180 then angleDiff = 360 - angleDiff end

                local degreesPerSec = angleDiff / timeDiff

                if degreesPerSec > MAX_TURN_DEG_PER_SEC and angleDiff > 30 then
                    snapCount = snapCount + 1

                    if snapCount >= 5 then
                        Report('AIMBOT_SNAP', ('aim snap: %.0f deg/sec (%.0f deg in %.0fms)'):format(
                            degreesPerSec, angleDiff, timeDiff * 1000
                        ))
                        snapCount = 0
                    end
                else
                    if snapCount > 0 then snapCount = snapCount - 1 end
                end
            end
        end

        lastHeading     = combined
        lastHeadingTime = now
    end
end)

-- ==========================================
--  REACTION TIME ANALYSIS
-- ==========================================
-- Aimbot reacts in < 50ms. Human minimum ~150ms.
local shotAtTime   = nil
local reactionLog  = {}

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim    = args[1]
    local attacker  = args[2]
    local isDead    = args[4]

    -- Track when THIS player gets hit
    if victim == PlayerPedId() and not isDead then
        shotAtTime = GetGameTimer()
    end

    -- Track when THIS player shoots back
    if attacker == PlayerPedId() and shotAtTime ~= nil then
        local reaction = GetGameTimer() - shotAtTime

        if reaction < 80 and reaction > 0 then
            -- Sub-80ms reaction is inhuman
            table.insert(reactionLog, reaction)

            if #reactionLog >= 5 then
                -- 5 consecutive sub-80ms reactions
                local avg = 0
                for _, r in ipairs(reactionLog) do avg = avg + r end
                avg = avg / #reactionLog

                Report('AIMBOT_REACTION', ('avg reaction time: %dms over %d samples'):format(avg, #reactionLog))
                reactionLog = {}
            end
        else
            -- Reset if they had a normal reaction
            reactionLog = {}
        end

        shotAtTime = nil
    end
end)

-- ==========================================
--  SESSION SUMMARY (send to server every 10 min)
-- ==========================================
CreateThread(function()
    while true do
        Wait(600000)  -- 10 minutes

        if totalKills > 0 then
            local ratio = headshotKills / totalKills
            TriggerServerEvent('sdr_anticheat:sessionStats', {
                kills      = totalKills,
                headshots  = headshotKills,
                hsRatio    = ratio,
                sessionMin = math.floor((GetGameTimer() - sessionStart) / 60000),
            })
        end
    end
end)
