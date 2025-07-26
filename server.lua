local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('qb_weed:hasSoil', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local soil = Player.Functions.GetItemByName('soil')
        cb(soil ~= nil and soil.amount > 0)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb_weed:hasWhiteWidowSeed', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local seeds = Player.Functions.GetItemByName('weed_whitewidow_seed')
        cb(seeds ~= nil and seeds.amount > 0)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb_weed:hasWaterBottle', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local water = Player.Functions.GetItemByName('water_bottle')
        cb(water ~= nil and water.amount > 0)
    else
        cb(false)
    end
end)

RegisterNetEvent('qb_weed:removeSoil', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.RemoveItem('soil', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["soil"], "remove")
    end
end)

RegisterNetEvent('qb_weed:removeWhiteWidowSeed', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.RemoveItem('weed_whitewidow_seed', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["weed_whitewidow_seed"], "remove")
    end
end)

RegisterNetEvent('qb_weed:removeWaterBottle', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.RemoveItem('water_bottle', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["water_bottle"], "remove")
    end
end)

RegisterNetEvent('qb_weed:giveWhiteWidow', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.AddItem('weed_whitewidow', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["weed_whitewidow"], "add")
    end
end)

RegisterNetEvent('qb_weed:givePotItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.AddItem('weed_pot', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["weed_pot"], "add")
    end
end)

RegisterNetEvent('qb_weed:placePot', function()
    local src = source
    TriggerClientEvent('qb_weed:placePot', src)
end)
