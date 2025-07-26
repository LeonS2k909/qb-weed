local QBCore = exports['qb-core']:GetCoreObject()
local potEmpty = `bzzz_growing_freepot_a`
local potSoil = `bzzz_growing_freepot_b`
local potWithPlant = `bkr_prop_weed_01_small_01c`
local potWatered = `bkr_prop_weed_01_small_01a`
local potFullyGrown = `bkr_prop_weed_01_small_01b`
local potMedGrown = `bkr_prop_weed_med_01a`
local potMedFinished = `bkr_prop_weed_med_01b`
local lightProp = "prop_worklight_03b"
local lightRadius = 5.0

local placedLights = {}

function ClearAllTargets(entity)
    exports['qb-target']:RemoveTargetEntity(entity)
end

function IsPotNearLight(coords)
    for _, light in ipairs(placedLights) do
        if #(coords - GetEntityCoords(light)) < lightRadius then
            return true
        end
    end
    return false
end

function AddTargetForSoil(pot)
    ClearAllTargets(pot)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Add Soil',
                icon = 'fas fa-seedling',
                action = function(entity)
                    QBCore.Functions.TriggerCallback('qb_weed:hasSoil', function(hasSoil)
                        if hasSoil then
                            ClearAllTargets(entity)
                            ReplacePotModel(entity, potSoil, 'soil')
                            TriggerServerEvent('qb_weed:removeSoil')
                        else
                            QBCore.Functions.Notify("You need soil!", "error")
                        end
                    end)
                end
            }
        },
        distance = 2.0,
    })
end

function AddTargetForSeeds(pot)
    ClearAllTargets(pot)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Plant Seeds',
                icon = 'fas fa-cannabis',
                action = function(entity)
                    QBCore.Functions.TriggerCallback('qb_weed:hasWhiteWidowSeed', function(hasSeeds)
                        if hasSeeds then
                            ClearAllTargets(entity)
                            ReplacePotModel(entity, potWithPlant, 'planted')
                            TriggerServerEvent('qb_weed:removeWhiteWidowSeed')
                        else
                            QBCore.Functions.Notify("You need White Widow seeds!", "error")
                        end
                    end)
                end
            }
        },
        distance = 2.0,
    })
end

function AddTargetForWater(pot, stage)
    ClearAllTargets(pot)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Water Plant',
                icon = 'fas fa-tint',
                action = function(entity)
                    QBCore.Functions.TriggerCallback('qb_weed:hasWaterBottle', function(hasWater)
                        if hasWater then
                            ClearAllTargets(entity)
                            if stage == "first" then
                                ReplacePotModel(entity, potWatered, 'watered')
                            elseif stage == "second" then
                                ReplacePotModel(entity, potMedGrown, 'medgrown')
                            end
                            TriggerServerEvent('qb_weed:removeWaterBottle')
                        else
                            QBCore.Functions.Notify("You need a water bottle!", "error")
                        end
                    end)
                end
            }
        },
        distance = 2.0,
    })
end

function AddTargetForCut(pot)
    ClearAllTargets(pot)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Cut Plant',
                icon = 'fas fa-scissors',
                action = function(entity)
                    ClearAllTargets(entity)
                    local coords = GetEntityCoords(entity)
                    local heading = GetEntityHeading(entity)
                    DeleteEntity(entity)
                    -- Spawn empty pot again at the same spot
                    RequestModel(potEmpty)
                    while not HasModelLoaded(potEmpty) do Wait(50) end
                    local emptyPot = CreateObject(potEmpty, coords.x, coords.y, coords.z, true, true, false)
                    SetEntityHeading(emptyPot, heading)
                    PlaceObjectOnGroundProperly(emptyPot)
                    FreezeEntityPosition(emptyPot, true)
                    SetEntityAsMissionEntity(emptyPot, true, true)
                    SetModelAsNoLongerNeeded(potEmpty)
                    AddTargetForSoil(emptyPot)
                    TriggerServerEvent('qb_weed:giveWhiteWidow')
                end
            }
        },
        distance = 2.0,
    })
end

function AddNoInteraction(pot)
    ClearAllTargets(pot)
end

RegisterNetEvent('qb_weed:placePot', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local targetCoords = coords + forward * 1.5

    RequestModel(potEmpty)
    while not HasModelLoaded(potEmpty) do Wait(50) end

    local pot = CreateObject(potEmpty, targetCoords.x, targetCoords.y, targetCoords.z - 1.0, true, true, false)
    SetEntityHeading(pot, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(pot)
    FreezeEntityPosition(pot, true)
    SetEntityAsMissionEntity(pot, true, true)
    SetModelAsNoLongerNeeded(potEmpty)

    AddTargetForSoil(pot)
end)

RegisterCommand('placelight', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local targetCoords = coords + forward * 1.5

    local hash = GetHashKey(lightProp)
    print("^3[DEBUG] Attempting to place light prop: "..tostring(lightProp).." | hash: "..tostring(hash))
    print("^3[DEBUG] Target coords: x="..targetCoords.x.." y="..targetCoords.y.." z="..targetCoords.z)

    RequestModel(hash)
    local modelTimeout = 0
    while not HasModelLoaded(hash) do
        Wait(50)
        modelTimeout = modelTimeout + 1
        if modelTimeout > 100 then
            print("^1[ERROR] Model did not load: "..tostring(lightProp).." | hash: "..tostring(hash))
            QBCore.Functions.Notify("Could not load light prop.", "error")
            return
        end
    end

    local light = CreateObject(hash, targetCoords.x, targetCoords.y, targetCoords.z - 1.0, true, true, false)
    if DoesEntityExist(light) then
        print("^2[DEBUG] Light object created: "..light)
        SetEntityHeading(light, GetEntityHeading(ped))
        PlaceObjectOnGroundProperly(light)
        FreezeEntityPosition(light, true)
        SetEntityAsMissionEntity(light, true, true)
        SetModelAsNoLongerNeeded(hash)
        table.insert(placedLights, light)
        QBCore.Functions.Notify("Light placed!", "success")
    else
        print("^1[ERROR] Failed to create light entity.")
        QBCore.Functions.Notify("Failed to place light!", "error")
    end
end, false)

function ReplacePotModel(oldPot, newModel, context)
    if not DoesEntityExist(oldPot) then return end

    ClearAllTargets(oldPot)

    local coords = GetEntityCoords(oldPot)
    local heading = GetEntityHeading(oldPot)
    DeleteEntity(oldPot)

    RequestModel(newModel)
    while not HasModelLoaded(newModel) do Wait(50) end

    local newPot = CreateObject(newModel, coords.x, coords.y, coords.z, true, true, false)
    SetEntityHeading(newPot, heading)
    PlaceObjectOnGroundProperly(newPot)
    FreezeEntityPosition(newPot, true)
    SetEntityAsMissionEntity(newPot, true, true)
    SetModelAsNoLongerNeeded(newModel)

    if context == 'soil' then
        AddTargetForSeeds(newPot)
    elseif context == 'planted' then
        AddTargetForWater(newPot, "first")
    elseif context == 'watered' then
        local waitTime = 10000
        if IsPotNearLight(coords) then waitTime = 1000 end
        CreateThread(function()
            Wait(waitTime)
            if DoesEntityExist(newPot) then
                ClearAllTargets(newPot)
                RequestModel(potFullyGrown)
                while not HasModelLoaded(potFullyGrown) do Wait(50) end
                local coords2 = GetEntityCoords(newPot)
                local heading2 = GetEntityHeading(newPot)
                DeleteEntity(newPot)
                local potGrown = CreateObject(potFullyGrown, coords2.x, coords2.y, coords2.z, true, true, false)
                SetEntityHeading(potGrown, heading2)
                PlaceObjectOnGroundProperly(potGrown)
                FreezeEntityPosition(potGrown, true)
                SetEntityAsMissionEntity(potGrown, true, true)
                SetModelAsNoLongerNeeded(potFullyGrown)
                local waitTime2 = 10000
                if IsPotNearLight(coords2) then waitTime2 = 1000 end
                CreateThread(function()
                    Wait(waitTime2)
                    if DoesEntityExist(potGrown) then
                        AddTargetForWater(potGrown, "second")
                    end
                end)
            end
        end)
    elseif context == 'medgrown' then
        local waitTime = 10000
        if IsPotNearLight(coords) then waitTime = 1000 end
        CreateThread(function()
            Wait(waitTime)
            if DoesEntityExist(newPot) then
                ClearAllTargets(newPot)
                RequestModel(potMedFinished)
                while not HasModelLoaded(potMedFinished) do Wait(50) end
                local coords2 = GetEntityCoords(newPot)
                local heading2 = GetEntityHeading(newPot)
                DeleteEntity(newPot)
                local potMedDone = CreateObject(potMedFinished, coords2.x, coords2.y, coords2.z, true, true, false)
                SetEntityHeading(potMedDone, heading2)
                PlaceObjectOnGroundProperly(potMedDone)
                FreezeEntityPosition(potMedDone, true)
                SetEntityAsMissionEntity(potMedDone, true, true)
                SetModelAsNoLongerNeeded(potMedFinished)
                AddTargetForCut(potMedDone)
            end
        end)
    end
end

RegisterCommand('placepot', function()
    TriggerEvent('qb_weed:placePot')
end)
