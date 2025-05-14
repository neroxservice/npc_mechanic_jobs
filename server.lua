QBCore = exports['qb-core']:GetCoreObject()

RegisterServerEvent("andrew_mechanicjob:generate", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    local jobName = Player.PlayerData.job.name
    if --[[ jobName ~= "mechanic" and ]] jobName ~= "cardealer" then
        TriggerClientEvent('QBCore:Notify', src, "Du hast einen neuen Einsatz!", "success")
        return
    end

    local loc = Config.JobLocations[math.random(#Config.JobLocations)]
    local jobType = math.random(1, 2) == 1 and "repair" or "tow"

    TriggerClientEvent("andrew_mechanicjob:startClientJob", src, { location = loc, type = jobType })
end)

RegisterServerEvent("andrew_mechanicjob:complete", function(type)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local reward = Config.Payment[type] or 200

    Player.Functions.AddMoney("cash", reward, "npcjob-complete")
    TriggerClientEvent('QBCore:Notify', src, "Du hast $" .. reward .. " erhalten.", "success")
end)

QBCore.Functions.CreateCallback('andrew_mechanicjob:hasRepairKit', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(Player.Functions.GetItemByName("repairkit") ~= nil)
end)

RegisterServerEvent("andrew_mechanicjob:removeKit", function()
    local Player = QBCore.Functions.GetPlayer(source)
    Player.Functions.RemoveItem("repairkit", 1)
    TriggerClientEvent("inventory:client:ItemBox", source, QBCore.Shared.Items["repairkit"], "remove")
end)


function isMechanicOnduty()
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in pairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local job = Player.PlayerData.job
            if job.name == "cardealer" or job.name == "mechanic" and job.onduty then
                return true
            end
        end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(Config.SpawnInterval)

        local players = QBCore.Functions.GetPlayers()
        local jobSent = false

        for _, playerId in pairs(players) do
            local Player = QBCore.Functions.GetPlayer(playerId)
            if Player then
                local job = Player.PlayerData.job
                if (job.name == "cardealer" --[[ or job.name == "mechanic" ]]) and job.onduty then
                    local loc = Config.JobLocations[math.random(#Config.JobLocations)]
                    local jobType = math.random(1, 2) == 1 and "repair" or "tow"

                    TriggerClientEvent("andrew_mechanicjob:startClientJob", playerId, {
                        location = loc,
                        type = jobType
                    })
                    TriggerClientEvent('QBCore:Notify', Player, "Du hast einen neuen Einsatz!", "success")
                    print("📦 Auftrag gesendet an Spieler " .. playerId)
                    jobSent = true
                end
            end
        end

        if not jobSent then
            print("⚠️ Keine Mechaniker/Cardealer im Dienst – kein Auftrag versendet")
        end
    end
end)

local currentVersion = "v1.1.0"

local githubUser = "neroxservice"
local githubRepo = "npc_mechanic_jobs"

local function checkVersion()
    local url = ("https://api.github.com/repos/%s/%s/releases/latest"):format(githubUser, githubRepo)
    PerformHttpRequest(url, function(statusCode, response, headers)
        if statusCode == 200 and response then
            local data = json.decode(response)
            if data and data.tag_name then
                local latestVersion = data.tag_name
                local changelog = data.body or "Kein Changelog vorhanden."

                print(yellow .. "--------------------------------------------------------" .. reset)
                print(magenta .. "[nx_mechanicjob]" .. reset)
                print(cyan .. "📦 Aktuelle Version: " .. blue .. currentVersion .. reset)
                print(cyan .. "🔄 Verfügbare Version: " .. blue .. latestVersion .. reset)

                if currentVersion == latestVersion then
                    print(green .. "✅ Du verwendest die neueste Version." .. reset)
                else
                    print("")
                    print(red .. "⚠️ Eine neue Version ist verfügbar!" .. reset)
                    print("🔗 " ..
                        cyan ..
                        "Update hier: " ..
                        blue .. "https://github.com/" .. githubUser .. "/" .. githubRepo .. "/releases/latest" .. reset)
                    print("")
                    print(magenta .. "📋 Änderungen in dieser Version:" .. reset)
                    for line in changelog:gmatch("[^\r\n]+") do
                        print("  " .. cyan .. " " .. line .. reset)
                    end
                end
                print(yellow .. "--------------------------------------------------------" .. reset)
            else
            end
        else
            print(red .. "[Fehler] Konnte keine Verbindung zu GitHub aufbauen (Code: " .. statusCode .. ")." .. reset)
        end
    end, "GET", "", { ["User-Agent"] = "FiveMResourceVersionChecker" })
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.SetTimeout(500, function()
            checkVersion()
        end)
    end
end)
