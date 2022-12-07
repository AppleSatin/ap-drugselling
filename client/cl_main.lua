QBCore = exports['qb-core']:GetCoreObject()

ZoneBlip = 0
hasTarget = false
local lastPed = {}
local Started = false
local CurrentCops = 0
local AnimDict = Config.DrugSellingAnimDic
local Anim = Config.DrugSellingAnim

--// Function 

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

--// Spawn Ped anad Ped target once near Ped
CreateThread(function()
    RequestModel(Config.PedModel)
    while not HasModelLoaded(Config.PedModel) do
        Wait(1)
    end
    local created_ped = CreatePed(0, Config.PedModel , Config.PedStartCoords.x, Config.PedStartCoords.y, Config.PedStartCoords.z -1, true)
    FreezeEntityPosition(created_ped, true)
    SetEntityHeading(created_ped, Config.PedStartCoords.w)
    SetEntityInvincible(created_ped, true)
    SetBlockingOfNonTemporaryEvents(created_ped, true)
    TaskStartScenarioInPlace(created_ped, Config.PedModelAnim, 0, true)

    while true do
        Wait(0)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(vector3(coords.x,coords.y,coords.z) - vector3(Config.PedStartCoords.x,Config.PedStartCoords.y,Config.PedStartCoords.z))
        if dist < 2.5 then
            if not Started then 
                for k, v in pairs(Config.Locations) do
                    exports['qb-target']:AddTargetModel(Config.PedModel, {
                        options = {
                            {
                                type = 'client',
                                event = "apple:start:sell:PoliceCheck",
                                icon = Config.PedIconTarget,
                                label = Config.PedLabelTarget,
                            },
                            {
                                type = 'client',
                                event = "apple:start:sell:Stop",
                                icon = Config.PedIconTargetStopSell,
                                label = Config.PedLabelTargetStopSell,
                            }
                        },
                        distance = 2.0, 
                    })
                end
            end	
            -- do shit
        else
            Wait(1500)
        end
    end
end)

--// Function to stop selling 

RegisterNetEvent("apple:start:sell:Stop", function()
    Started = false
    hasTarget = false
end)

--// Function to set cop count client sided 

RegisterNetEvent('police:SetCopCount', function(amount)
    CurrentCops = amount
end)

--// Menu for starting to sell

RegisterNetEvent("apple:start:sell:Menu", function()
    for i = 1, #Config.Locations do
        local MenuOptions = {
            {
                header = Config.MenuHeader,
                txt = Config.MenuHeaderText,
                isMenuHeader = true
            },
        }
        for k, v in pairs(Config.Locations) do
            MenuOptions[#MenuOptions+1] = { --// fww
                header = "<h8>"..v.name.."</h>",
                params = {
                    event = "apple:start:sell",
                    args = {
                        id = v.id,
                    }
                }
            }
        end
            exports['qb-menu']:openMenu(MenuOptions)
        end
  end)


--// Police Neeeded Chance 

RegisterNetEvent("apple:start:sell:PoliceCheck", function()
    if CurrentCops >= Config.PoliceNeeded then
        TriggerEvent("apple:start:sell:Menu")
    else 
        QBCore.Functions.Notify(Config.NoPoliceNotify, 'error', Config.NoPoliceNotifyTime)
    end
end)

--// Blips Stuff Below

local function CreateBlip(coords, blipradius, alpha, color)

    local ZoneBlip = AddBlipForRadius(coords.x, coords.y, coords.z, blipradius)
    SetBlipHighDetail(ZoneBlip, true)
    SetBlipColour(ZoneBlip, color)
    SetBlipAlpha(ZoneBlip, alpha)
    SetBlipAsShortRange(ZoneBlip, true)

    while alpha ~= 0 do
        if not Started then
            RemoveBlip(ZoneBlip)
        else end
        Citizen.Wait(500)
        alpha = alpha - 1
        SetBlipAlpha(ZoneBlip, alpha)

        if alpha == 0 then
            RemoveBlip(ZoneBlip)
            return
        end
    end
end

if Config.Debug then
    RegisterCommand('selltest', function()
         TriggerEvent('apple:start:sell:Menu')
    end)
end

--// Event for starting selling at location One

RegisterNetEvent("apple:start:sell", function(args)
  --  print(args.id)
    local id = tonumber(args.id)
    if Started == false then
        for i = 1, #Config.Locations do
            getLocation(id)
            QBCore.Functions.Notify(Config.JobStartedHeadToLoc, 'success', Config.JobStartedHeadToLocTextTime)
            Started = true
            bliploction = CreateBlip(Config.Locations[id].coords,  Config.Locations[id].blipradius, Config.Locations[id].blipalpha, Config.Locations[id].blipcolor)
        end
    end
end)

function getLocation(id)
  --  print(id)
    CreateThread(function()
        while true do
            Wait(5000)
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            for i = 1, #Config.Locations do
                local coords = Config.Locations[id].coords
                local dist = #(pCoords - coords) -- Use this

                if dist < Config.Locations[id].blipradius then
                    movePed()
                end
            end
        end
    end)
end

function movePed()
    local startLocation = GetEntityCoords(PlayerPedId())
    CreateThread(function()
        while hasTarget == false do
            local player = PlayerPedId()
            local coords = GetEntityCoords(player)
            local PlayerPeds = {}
            if next(PlayerPeds) == nil then
                for _, activePlayer in ipairs(GetActivePlayers()) do
                    local ped = GetPlayerPed(activePlayer)
                    PlayerPeds[#PlayerPeds + 1] = ped
                end
            end
            closestPed, closestDistance = QBCore.Functions.GetClosestPed(coords, PlayerPeds)
            if closestDistance < 15.0 and closestPed ~= 0 and not IsPedInAnyVehicle(closestPed) and GetPedType(closestPed) ~= 28 then
                targetPed(closestPed)
            end
            Wait(5000)
        end
    end)
end

function targetPed(ped)
    QBCore.Functions.TriggerCallback('apple:start:sell:getAvailableDrugs', function(result)
      --  print(result)
        if result then
            availableDrugs = result
            hasTarget = true

            for i = 1, #lastPed, 1 do
                if lastPed[i] == ped then
                    hasTarget = false
                    return
                end
            end

            SetEntityAsNoLongerNeeded(ped)
            ClearPedTasks(ped)

            local coords = GetEntityCoords(PlayerPedId(), true)
            local pedCoords = GetEntityCoords(ped)
            local pedDist = #(coords - pedCoords)

            TaskGoStraightToCoord(ped, coords, 15.0, -1, 0.0, 0.0)

            while pedDist > 1.5 do
                coords = GetEntityCoords(PlayerPedId(), true)
                pedCoords = GetEntityCoords(ped)
                TaskGoStraightToCoord(ped, coords, 1.2, -1, 0.0, 0.0)
                pedDist = #(coords - pedCoords)
                Wait(100)
            end

            TaskLookAtEntity(ped, PlayerPedId(), 5500.0, 2048, 3)
            TaskTurnPedToFaceEntity(ped, PlayerPedId(), 5500)
            TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT", 0, false)

            while pedDist < 1.5 and not IsPedDeadOrDying(ped) do
                local coords2 = GetEntityCoords(PlayerPedId(), true)
                local pedCoords2 = GetEntityCoords(ped)
                local pedDist2 = #(coords2 - pedCoords2)


                local drugType = math.random(1, #availableDrugs)
                local bagAmount = math.random(1, availableDrugs[drugType].amount)
                if bagAmount > 15 then bagAmount = math.random(9, 15) end
            
                currentOfferDrug = availableDrugs[drugType]
            
                local ddata = Config.DrugsPrice[currentOfferDrug.item]
                local randomPrice = math.random(ddata.min, ddata.max) * bagAmount


                if pedDist2 < 1.5 then
                    exports['qb-target']:AddEntityZone('sellingPed', ped, {
                        name = 'sellingPed',
                        debugPoly = false,
                    }, {
                        options = {
                            {
                                icon = 'fas fa-hand-holding-dollar',
                                label = bagAmount ..'x ' ..currentOfferDrug.label .. ' for $'..randomPrice,
                                action = function(entity)
                                    TriggerServerEvent('ap-drugselling:server:sellCornerDrugs', drugType, bagAmount, randomPrice)
                                    hasTarget = false
                                    LoadAnimDict(AnimDict)
                                    TaskPlayAnim(PlayerPedId(), AnimDict, Anim, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
                                    Wait(650)
                                    ClearPedTasks(PlayerPedId())
                                    SetPedKeepTask(entity, false)
                                    SetEntityAsNoLongerNeeded(entity)
                                    ClearPedTasksImmediately(entity)
                                    lastPed[#lastPed + 1] = entity
                                    exports['qb-target']:RemoveZone('sellingPed')
                                   -- print("calling police")
                                    AlertoPoliciaChanceThing()
                                end,
                            },
                            {
                                icon = 'fas fa-x',
                                label = 'Decline offer',
                                action = function(entity)
                                  QBCore.Functions.Notify(Config.DeclineSellDrugNotify, 'error', Config.DeclineSellDrugNotifyTime)
                                    hasTarget = false
                                    SetPedKeepTask(entity, false)
                                    SetEntityAsNoLongerNeeded(entity)
                                    ClearPedTasksImmediately(entity)
                                    lastPed[#lastPed + 1] = entity
                                    exports['qb-target']:RemoveZone('sellingPed')
                                   -- print("calling police for delcline")
                                    AlertoPoliciaChanceThingDelcine()
                                end,
                            },
                        },
                        distance = 1.5,
                    })
                end
                Wait(0)
            end
        end
    end)
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == "ap-drugselling" then
        if DoesBlipExist(bliploction) then
            RemoveBlip(bliploction)
        end
    end
end)


--// Call polcie stuff

local chance = math.random(1, 100)

--// Functions to call police chance you can edit line 9 and line 16 to the dispatch you use defualt ps-dispatch

function AlertoPoliciaChanceThing() --// Chance to call police on sale 
	if chance < Config.CallPoliceOnDeclineChance then
        exports['ps-dispatch']:DrugSale()
    end
end

--// Function to call police if player declines drug sale
function AlertoPoliciaChanceThingDelcine() --// Chance to call police on cancelling sale 
	if chance < Config.CallPoliceOnDeclineChance then
        exports['ps-dispatch']:DrugSale()
    end
end