local QBCore = exports['qb-core']:GetCoreObject()
local potEmpty = `bzzz_growing_freepot_a`
local potSoil = `bzzz_growing_freepot_b`
local potWithPlant = `bkr_prop_weed_01_small_01c`
local potWatered = `bkr_prop_weed_01_small_01a`
local potFullyGrown = `bkr_prop_weed_01_small_01b`
local potMedGrown = `bkr_prop_weed_med_01a`
local potMedFinished = `bkr_prop_weed_med_01b`
local lightProp = "prop_worklight_03b"
local fanProp = `prop_fan_01`
local lightRadius = 5.0

local placedLights = {}
local placedFans = {}
local carryingPot = false
local carriedPot = nil
local potsAttachedToVehicles = {}
local lastPotModel = nil

function GetPotCountInVehicle(vehicle)
    local count = 0
    for pot, veh in pairs(potsAttachedToVehicles) do
        if veh == vehicle and DoesEntityExist(pot) then
            count = count + 1
        end
    end
    return count
end

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

function StartCarryingPot(model)
    if carryingPot then return end
    carryingPot = true
    lastPotModel = model

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local ped = PlayerPedId()
    local pot = CreateObject(model, 0, 0, 0, true, true, false)
    AttachEntityToEntity(
        pot,
        ped,
        GetPedBoneIndex(ped, 57005),
        0.13,
        0.04,
        -0.15,
        10.0,
        90.0,
        0.0,
        false, false, false, false, 2, true
    )
    carriedPot = pot

    RequestAnimDict("anim@heists@box_carry@")
    while not HasAnimDictLoaded("anim@heists@box_carry@") do Wait(10) end
    TaskPlayAnim(ped, "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)

    QBCore.Functions.Notify("You are now carrying the pot. Press [G] to drop.", "primary")
end

function StopCarryingPot(dropCoords, dropHeading)
    if not carryingPot or not carriedPot then return end

    local pot = carriedPot
    local ped = PlayerPedId()
    local attachedToVehicle = false

    local vehicle = GetVehicleInDirection(ped, 3.0)
    if vehicle and vehicle ~= 0 then
        local vehModel = GetEntityModel(vehicle)
        local vehCoords = GetEntityCoords(vehicle)
        local vehHeading = GetEntityHeading(vehicle)
        local min, max = GetModelDimensions(vehModel)

        local positions = {
            [1] = { x =  0.0,   y = -1.30 },
            [2] = { x =  0.0,   y = -1.75 },
            [3] = { x =  0.0,   y = -2.25 },
            [4] = { x = -0.33,  y = -2.10 },
            [5] = { x =  0.33,  y = -2.10 },
        }
        local offsetZ = 0.30

        local currentPotCount = GetPotCountInVehicle(vehicle) + 1
        local grid = positions[currentPotCount] or positions[5]

        DetachEntity(pot, true, true)
        AttachEntityToEntity(pot, vehicle, 0, grid.x, grid.y, offsetZ, 0.0, 0.0, 0.0, false, false, true, false, 2, true)
        SetEntityAsMissionEntity(pot, true, true)
        potsAttachedToVehicles[pot] = vehicle
        attachedToVehicle = true
        QBCore.Functions.Notify("You put the pot in the vehicle bed.", "success")
        AddTargetForVehiclePot(pot)
    else
        DetachEntity(pot, true, true)
        SetEntityCoords(pot, dropCoords.x, dropCoords.y, dropCoords.z, false, false, false, true)
        SetEntityHeading(pot, dropHeading or GetEntityHeading(ped))
        PlaceObjectOnGroundProperly(pot)
        FreezeEntityPosition(pot, true)
        SetEntityAsMissionEntity(pot, true, true)
        QBCore.Functions.Notify("You have placed the pot.", "success")
        AddTargetsByModel(pot, lastPotModel)
    end

    carriedPot = nil
    carryingPot = false
    ClearPedTasks(ped)
end

function GetVehicleInDirection(ped, dist)
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local destination = coords + (forward * (dist or 3.0))
    local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 10, ped, 0)
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    if hit == 1 and IsEntityAVehicle(entityHit) then
        return entityHit
    else
        return nil
    end
end

function AddTargetsByModel(pot, model)
    ClearAllTargets(pot)
    if model == potEmpty then
        AddTargetForSoilAndFan(pot)
    elseif model == potSoil then
        AddTargetForSeeds(pot)
    elseif model == potWithPlant then
        AddTargetForWater(pot, "first")
    elseif model == potWatered then
        AddNoInteraction(pot)
    elseif model == potFullyGrown then
        AddTargetForWater(pot, "second")
    elseif model == potMedGrown then
        AddTargetForFan(pot)
    elseif model == potMedFinished then
        AddTargetForCut(pot)
    else
        AddPickupTarget(pot)
    end
end

function AddTargetForSoilAndFan(pot)
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
            },
            {
                label = 'Place Test Fan',
                icon = 'fas fa-fan',
                action = function(entity)
                    local coords = GetEntityCoords(entity)
                    local heading = GetEntityHeading(entity)
                    RequestModel(fanProp)
                    while not HasModelLoaded(fanProp) do Wait(10) end
                    local fanCoords = coords + GetEntityForwardVector(entity) * -1.0
                    local fan = CreateObject(fanProp, fanCoords.x, fanCoords.y, fanCoords.z, true, true, false)
                    SetEntityHeading(fan, heading + 180.0)
                    PlaceObjectOnGroundProperly(fan)
                    FreezeEntityPosition(fan, true)
                    SetEntityAsMissionEntity(fan, true, true)
                    SetModelAsNoLongerNeeded(fanProp)
                    table.insert(placedFans, fan)
                    QBCore.Functions.Notify("Test Fan placed.", "success")
                    AddTargetForRemoveFan(fan)
                end
            },
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    ClearAllTargets(entity)
                    local model = GetEntityModel(entity)
                    DeleteEntity(entity)
                    StartCarryingPot(model)
                end
            }
        },
        distance = 2.0,
    })
end

function AddTargetForRemoveFan(fan)
    exports['qb-target']:AddTargetEntity(fan, {
        options = {
            {
                label = 'Pick Up Fan',
                icon = 'fas fa-trash',
                action = function(entity)
                    DeleteEntity(entity)
                    QBCore.Functions.Notify("Fan removed.", "success")
                end
            }
        },
        distance = 2.0,
    })
end

function AddPickupTarget(pot, stage)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    ClearAllTargets(entity)
                    local model = GetEntityModel(entity)
                    DeleteEntity(entity)
                    StartCarryingPot(model)
                end
            }
        },
        distance = 2.0,
    })
end

function AddTargetForVehiclePot(pot)
    ClearAllTargets(pot)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    if potsAttachedToVehicles[entity] then
                        DetachEntity(entity, true, true)
                        SetEntityCollision(entity, true, true)
                        potsAttachedToVehicles[entity] = nil
                        local model = GetEntityModel(entity)
                        DeleteEntity(entity)
                        StartCarryingPot(model)
                    end
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
            },
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    ClearAllTargets(entity)
                    local model = GetEntityModel(entity)
                    DeleteEntity(entity)
                    StartCarryingPot(model)
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
            },
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    ClearAllTargets(entity)
                    local model = GetEntityModel(entity)
                    DeleteEntity(entity)
                    StartCarryingPot(model)
                end
            }
        },
        distance = 2.0,
    })
end

function AddTargetForFan(pot)
    ClearAllTargets(pot)
    exports['qb-target']:AddTargetEntity(pot, {
        options = {
            {
                label = 'Place Fan',
                icon = 'fas fa-fan',
                action = function(entity)
                    local potCoords = GetEntityCoords(entity)
                    local potHeading = GetEntityHeading(entity)
                    RequestModel(fanProp)
                    while not HasModelLoaded(fanProp) do Wait(10) end
                    local fanCoords = potCoords + GetEntityForwardVector(entity) * -1.0
                    local fan = CreateObject(fanProp, fanCoords.x, fanCoords.y, fanCoords.z, true, true, false)
                    SetEntityHeading(fan, potHeading + 180.0)
                    PlaceObjectOnGroundProperly(fan)
                    FreezeEntityPosition(fan, true)
                    SetEntityAsMissionEntity(fan, true, true)
                    SetModelAsNoLongerNeeded(fanProp)
                    table.insert(placedFans, fan)
                    QBCore.Functions.Notify("Fan placed for the plant!", "success")
                    AddTargetForRemoveFan(fan)
                end
            },
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    ClearAllTargets(entity)
                    local model = GetEntityModel(entity)
                    DeleteEntity(entity)
                    StartCarryingPot(model)
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
                    RequestModel(potEmpty)
                    while not HasModelLoaded(potEmpty) do Wait(50) end
                    local emptyPot = CreateObject(potEmpty, coords.x, coords.y, coords.z, true, true, false)
                    SetEntityHeading(emptyPot, heading)
                    PlaceObjectOnGroundProperly(emptyPot)
                    FreezeEntityPosition(emptyPot, true)
                    SetEntityAsMissionEntity(emptyPot, true, true)
                    SetModelAsNoLongerNeeded(potEmpty)
                    AddTargetForSoilAndFan(emptyPot)
                    TriggerServerEvent('qb_weed:giveWhiteWidow')
                end
            },
            {
                label = 'Pick Up Pot',
                icon = 'fas fa-box',
                action = function(entity)
                    ClearAllTargets(entity)
                    local model = GetEntityModel(entity)
                    DeleteEntity(entity)
                    StartCarryingPot(model)
                end
            }
        },
        distance = 2.0,
    })
end

function AddNoInteraction(pot)
    ClearAllTargets(pot)
    AddPickupTarget(pot)
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

    AddTargetForSoilAndFan(pot)
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

RegisterCommand('light', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    RequestModel(lightProp)
    while not HasModelLoaded(lightProp) do Wait(10) end
    local obj = CreateObject(lightProp, coords.x, coords.y, coords.z - 1.0, true, true, false)
    if DoesEntityExist(obj) then
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        QBCore.Functions.Notify("Test light placed.", "success")
    else
        QBCore.Functions.Notify("Light prop failed to spawn.", "error")
    end
end, false)

RegisterCommand('placefan', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    RequestModel(fanProp)
    while not HasModelLoaded(fanProp) do Wait(10) end
    local fan = CreateObject(fanProp, coords.x, coords.y, coords.z - 1.0, true, true, false)
    if DoesEntityExist(fan) then
        SetEntityHeading(fan, heading)
        PlaceObjectOnGroundProperly(fan)
        FreezeEntityPosition(fan, true)
        SetEntityAsMissionEntity(fan, true, true)
        SetModelAsNoLongerNeeded(fanProp)
        QBCore.Functions.Notify("Test fan placed.", "success")
        AddTargetForRemoveFan(fan)
    else
        QBCore.Functions.Notify("Fan prop failed to spawn.", "error")
    end
end, false)

CreateThread(function()
    while true do
        Wait(2000)
        for pot, veh in pairs(potsAttachedToVehicles) do
            if not DoesEntityExist(veh) and DoesEntityExist(pot) then
                DeleteEntity(pot)
                potsAttachedToVehicles[pot] = nil
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if carryingPot and carriedPot then
            if IsControlJustPressed(0, 47) then -- [G]
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                StopCarryingPot(coords + GetEntityForwardVector(ped) * 1.0, heading)
            end
        end
    end
end)

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

    lastPotModel = newModel

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
                lastPotModel = potFullyGrown
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
                AddTargetForFan(newPot)
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
                lastPotModel = potMedFinished
                AddTargetForCut(potMedDone)
            end
        end)
    end
end

RegisterCommand('placepot', function()
    TriggerEvent('qb_weed:placePot')
end)
