-- ==========================================
--      SDR ANTICHEAT - Screenshot Module
-- ==========================================
-- Uses the built-in FiveM screenshot-basic resource
-- Make sure screenshot-basic is started on your server

RegisterNetEvent('sdr_anticheat:takeScreenshot', function(reason)
    if not Config.Screenshots then return end
    if not Config.ScreenshotURL or Config.ScreenshotURL == '' then return end

    -- Use screenshot-basic if available
    if exports['screenshot-basic'] then
        exports['screenshot-basic']:requestScreenshotUpload(
            Config.ScreenshotURL,
            'files[]',
            function(data)
                local resp = json.decode(data)
                if resp and resp.attachments and resp.attachments[1] then
                    local url = resp.attachments[1].url
                    TriggerServerEvent('sdr_anticheat:screenshotResult', reason, url)
                end
            end
        )
    end
end)
