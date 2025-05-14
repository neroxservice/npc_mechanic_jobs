QBCore = exports['qb-core']:GetCoreObject()

local activeJob = false
local jobType = nil
local jobVehicle = nil
local vehicleBlip = nil
local targetBlip = nil
local repairParticle = nil

RegisterCommand("startjob", function()
    if activeJob then
        QBCore.Functions.Notify("Du hast bereits einen Auftrag!", "error")
        return
    end

    TriggerServerEvent("andrew_mechanicjob:generate")
end)

function CreateBlipForVehicle(vehicle)
    local pos = GetEntityCoords(vehicle)
    if vehicleBlip then
        RemoveBlip(vehicleBlip)
    end

    vehicleBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(vehicleBlip, 402)
    SetBlipScale(vehicleBlip, 0.8)
    SetBlipColour(vehicleBlip, 5)
    SetBlipAsShortRange(vehicleBlip, false)
    SetBlipRoute(vehicleBlip, true)
    SetBlipRouteColour(vehicleBlip, 5)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Fahrzeug Standort")
    EndTextCommandSetBlipName(vehicleBlip)

    -- WICHTIG: Route explizit setzen
    SetNewWaypoint(pos.x, pos.y)
end

function CreateBlipForTarget(targetCoords)
    if targetBlip then
        RemoveBlip(targetBlip)
    end

    targetBlip = AddBlipForCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    SetBlipSprite(targetBlip, 402)
    SetBlipScale(targetBlip, 1.3)
    SetBlipColour(targetBlip, 2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Fahrzeug Abgabeort")
    EndTextCommandSetBlipName(targetBlip)
    SetBlipRoute(targetBlip, true)
    SetBlipRouteColour(targetBlip, 2)
end

RegisterNetEvent("andrew_mechanicjob:startClientJob", function(data)
    activeJob = true
    jobType = data.type

    local model = `blista`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    jobVehicle = CreateVehicle(model, data.location.coords.x, data.location.coords.y, data.location.coords.z,
        data.location.heading, true, false)

    -- Fahrzeugblip + Route
    CreateBlipForVehicle(jobVehicle)

    -- Warte bis Spieler einsteigt
    CreateThread(function()
        while activeJob do
            Wait(500)
            if IsPedInVehicle(PlayerPedId(), jobVehicle, false) then
                if vehicleBlip then
                    RemoveBlip(vehicleBlip)
                    vehicleBlip = nil
                end
                local targetCoords = Config.DeliveryLocations[math.random(#Config.DeliveryLocations)]
                CreateBlipForTarget(targetCoords)
                if jobType == "tow" then
                    HandleTowJob(targetCoords)
                elseif jobType == "repair" then
                    HandleRepairJob(targetCoords)
                end
                break
            end
        end
    end)

    QBCore.Functions.Notify("Job gestartet: " .. jobType, "success")
end)

function HandleTowJob(target)
    CreateThread(function()
        while activeJob do
            Wait(2000)
            if not DoesEntityExist(jobVehicle) then break end

            local pos = GetEntityCoords(jobVehicle)
            if #(pos - target) < 10.0 then
                if targetBlip then
                    RemoveBlip(targetBlip)
                    targetBlip = nil
                end
                DeleteEntity(jobVehicle)
                TriggerServerEvent("andrew_mechanicjob:complete", "tow")
                QBCore.Functions.Notify("Fahrzeug abgeliefert!", "success")
                activeJob = false
            end
        end
    end)
end

function HandleRepairJob(target)
    QBCore.Functions.Notify("Fahre zum Fahrzeug und repariere es am Motor mit [E]!", "primary")

    CreateThread(function()
        while activeJob do
            Wait(0)
            if not DoesEntityExist(jobVehicle) then break end

            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local engineBone = GetEntityBoneIndexByName(jobVehicle, "engine")
            if engineBone == -1 then engineBone = 0 end

            local enginePos = GetWorldPositionOfEntityBone(jobVehicle, engineBone)
            local distance = #(playerCoords - enginePos)

            if distance < 4.0 then
                DrawText3D(enginePos.x, enginePos.y, enginePos.z + 0.3, "[E] Reparieren")

                if IsControlJustPressed(0, 38) then
                    QBCore.Functions.TriggerCallback('andrew_mechanicjob:hasRepairKit', function(hasItem)
                        if hasItem then
                            SetVehicleDoorOpen(jobVehicle, 4, false, false)
                            local dict = "mini@repair"
                            RequestAnimDict(dict)
                            while not HasAnimDictLoaded(dict) do Wait(10) end
                            TaskPlayAnim(ped, dict, "fixing_a_ped", 8.0, -8.0, -1, 1, 0, false, false, false)

                            StartRepairParticle(enginePos)

                            QBCore.Functions.Progressbar("repair_job", "Fahrzeug wird repariert...", 5000, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {}, {}, {}, function()
                                ClearPedTasks(ped)
                                StopRepairParticle()

                                SetVehicleEngineHealth(jobVehicle, 1000.0)
                                TriggerServerEvent("andrew_mechanicjob:removeKit")
                                SetVehicleDoorShut(jobVehicle, 4, false)
                                QBCore.Functions.Notify("Fahrzeug repariert!", "success")

                                if targetBlip then
                                    RemoveBlip(targetBlip)
                                    targetBlip = nil
                                end

                                DeleteEntity(jobVehicle)
                                TriggerServerEvent("andrew_mechanicjob:complete", "repair")
                                activeJob = false
                            end, function()
                                ClearPedTasks(ped)
                                StopRepairParticle()
                                SetVehicleDoorShut(jobVehicle, 4, false)
                                QBCore.Functions.Notify("Reparatur abgebrochen!", "error")
                            end)
                        else
                            QBCore.Functions.Notify("Du brauchst ein Reparaturkit!", "error")
                        end
                    end)
                end
            end
        end
    end)
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function StartRepairParticle(coords)
    UseParticleFxAssetNextCall("core")
    repairParticle = StartParticleFxLoopedAtCoord("ent_amb_sparking_wires", coords.x, coords.y, coords.z + 0.5, 0.0, 0.0,
        0.0, 1.0, false, false, false, false)
end

function StopRepairParticle()
    if repairParticle then
        StopParticleFxLooped(repairParticle, 0)
        repairParticle = nil
    end
end
