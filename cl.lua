ESX = exports["es_extended"]:getSharedObject()

local containers = {}
local collisions = {}
local locks = {}
local clientContainer = {}
local clientLock = {}
local rndContainer = nil


function loadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
end

function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(1)
    end
end

function loadPtfxAsset(asset)
    RequestNamedPtfxAsset(asset)
    while not HasNamedPtfxAssetLoaded(asset) do
        Wait(1)
    end
end

CreateThread(function()
    RequestModel(Config.PedModel)
    while not HasModelLoaded(Config.PedModel) do
        Wait(1)
    end
    startped = CreatePed(2, Config.PedModel, Config.StartPedLoc.x, Config.StartPedLoc.y, Config.StartPedLoc.z - 1,
        Config.StartPedLoc.w, false, false)                                                                                                          -- change here the cords for the ped
    SetPedFleeAttributes(startped, 0, 0)
    SetPedDiesWhenInjured(startped, false)
    TaskStartScenarioInPlace(startped, Config.StartPedAnimation, 0, true)
    SetPedKeepTask(startped, true)
    SetBlockingOfNonTemporaryEvents(startped, true)
    SetEntityInvincible(startped, true)
    FreezeEntityPosition(startped, true)

    Wait(100)

    exports.ox_target:addLocalEntity(startped, {
        {
            name = 'ammo_robbery',
            icon = 'fas fa-user-secret',
            label = 'Ammo Rob',
            onSelect = function()
                TriggerEvent('jomidar-ammorobbery:cl:start')
            end
        }
    })

end)

RegisterNetEvent('jomidar-ammorobbery:cl:clear', function()
    for i = 1, #Config['containers'] do
        DeleteEntity(containers[i])
        DeleteEntity(locks[i])
        DeleteEntity(collisions[i])

        exports.ox_target:removeZone("opencontainers" .. i)

        Config['containers'][i]['lock']['taken'] = false

        DeleteEntity(clientContainer[i])
        DeleteEntity(clientLock[i])
    end

    exports.ox_target:removeLocalEntity(weaponBox, 'Open Crate')
    DeleteEntity(weaponBox)
    print("limpou")
end)


RegisterNetEvent('jomidar-ammorobbery:cl:start', function()
    lib.callback('jomidar-ammorobbery:sv:GetCops', false, function(cops)
        lib.callback('jomidar-ammorobbery:sv:coolc', false, function(isCooldown)
            if not isCooldown then
                if cops >= Config.CopAmount then
                    TriggerServerEvent("jomidar-ammorobbery:sv:coolout")
                    TriggerServerEvent("jomidar-ammorobbery:sv:ClearSync")
                    ClearArea(Config['containers'][1].pos)
                    SetupContainers()
                else
                    lib.notify({ description = 'No Cops', type = 'error' })
                end
            else
                lib.notify({ description = 'In Cooldown', type = 'error' })
            end
        end)
    end)
end)



function SetupContainers()
    containersBlip = AddBlipForCoord(1088.02, -3193.23, 5.9)
    SetBlipSprite(containersBlip, 677)
    SetBlipColour(containersBlip, 1)
    SetBlipScale(containersBlip, 0.7)
    SetBlipRoute(containersBlip, true)
    SetBlipRouteColour(containersBlip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('Containers')
    EndTextCommandSetBlipName(containersBlip)

    loadModel('prop_ld_container')
    rndContainer = math.random(1, #Config['containers'])

    local containerCodes = { "S8B5", "8E7T", "S92H", "9C0B", "B09W", "0B06" }
    exports['jomidar-ui']:Show('Ammunation Containers', 'Rob the container ' .. (containerCodes[rndContainer] or "0B06"))

    for k, v in pairs(Config['containers']) do
        loadModel(v.containerModel)
        Wait(100)
        containers[k] = CreateObject(GetHashKey(v.containerModel), v.pos, true, true, false)
        SetEntityHeading(containers[k], v.heading)
        FreezeEntityPosition(containers[k], true)

        Wait(math.random(100, 500))
        collisions[k] = CreateObject(GetHashKey('prop_ld_container'), v.pos, true, true, false)
        SetEntityHeading(collisions[k], v.heading)
        SetEntityVisible(collisions[k], false)
        FreezeEntityPosition(collisions[k], true)

        Wait(math.random(100, 500))
        locks[k] = CreateObject(GetHashKey('tr_prop_tr_lock_01a'), v.lock.pos, true, true, false)
        SetEntityHeading(locks[k], v.heading)
        FreezeEntityPosition(locks[k], true)

        exports.ox_target:addSphereZone({
            coords = v.target,
            radius = 1.0,
            debug = false,
            options = {
                {
                    icon = "fas fa-user-secret",
                    label = "Open Container",
                    onSelect = function()
                        lib.callback('checkPlayerHasItem', false, function(hasItem)
                            if hasItem then
                                if not Config['containers'][k]['lock']['taken'] then
                                    OpenContainer(k)
                                else
                                    lib.notify({ description = "Already Open", type = "error" })
                                end
                            else
                                lib.notify({ description = "No Item", type = "error" })
                            end
                        end, Config.requiredItem)
                    end
                }
            }
        })
    end

    weaponBox = CreateObject(GetHashKey("ex_prop_crate_ammo_sc"),
        vector3(Config['containers'][rndContainer].box.x, Config['containers'][rndContainer].box.y, Config['containers'][rndContainer].box.z),
        true, true, false)
    SetEntityHeading(weaponBox, Config['containers'][rndContainer].box.w)
    FreezeEntityPosition(weaponBox, true)

    TriggerServerEvent("jomidar-ammorobbery:sv:synctarget")
end


function OpenContainer(index)
    lib.progressBar({
        duration = 11500,
        label = 'Opening the container...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = false,
            mouse = false,
            combat = true
        }
    })

    AlertCops()

    local ped = PlayerPedId()
    local pedCo = GetEntityCoords(ped)
    local pedRotation = GetEntityRotation(ped)
    local animDict = 'anim@scripted@player@mission@tunf_train_ig1_container_p1@male@'

    loadAnimDict(animDict)
    loadPtfxAsset('scr_tn_tr')

    TriggerServerEvent('jomidar-ammorobbery:sv:lockSync', index)

    for i = 1, #ContainerAnimation['objects'] do
        loadModel(ContainerAnimation['objects'][i])
        ContainerAnimation['sceneObjects'][i] = CreateObject(GetHashKey(ContainerAnimation['objects'][i]), pedCo, true, true, false)
    end

    sceneObject = GetClosestObjectOfType(pedCo, 2.5, GetHashKey(Config['containers'][index].containerModel), false, false, false)
    lockObject = GetClosestObjectOfType(pedCo, 2.5, GetHashKey('tr_prop_tr_lock_01a'), false, false, false)

    NetworkRegisterEntityAsNetworked(sceneObject)
    NetworkRegisterEntityAsNetworked(lockObject)

    scene = NetworkCreateSynchronisedScene(GetEntityCoords(sceneObject), GetEntityRotation(sceneObject), 2, true, false, 1065353216, 0, 1065353216)

    NetworkAddPedToSynchronisedScene(ped, scene, animDict, ContainerAnimation['animations'][1][1], 4.0, -4.0, 1033, 0, 1000.0, 0)
    NetworkAddEntityToSynchronisedScene(sceneObject, scene, animDict, ContainerAnimation['animations'][1][2], 1.0, -1.0, 1148846080)
    NetworkAddEntityToSynchronisedScene(lockObject, scene, animDict, ContainerAnimation['animations'][1][3], 1.0, -1.0, 1148846080)
    NetworkAddEntityToSynchronisedScene(ContainerAnimation['sceneObjects'][1], scene, animDict, ContainerAnimation['animations'][1][4], 1.0, -1.0, 1148846080)
    NetworkAddEntityToSynchronisedScene(ContainerAnimation['sceneObjects'][2], scene, animDict, ContainerAnimation['animations'][1][5], 1.0, -1.0, 1148846080)

    SetEntityCoords(ped, GetEntityCoords(sceneObject))
    NetworkStartSynchronisedScene(scene)

    Wait(4000)
    UseParticleFxAssetNextCall('scr_tn_tr')
    sparks = StartParticleFxLoopedOnEntity("scr_tn_tr_angle_grinder_sparks", ContainerAnimation['sceneObjects'][1], 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    Wait(1000)
    StopParticleFxLooped(sparks, true)

    Wait(GetAnimDuration(animDict, 'action') * 1000 - 5000)

    TriggerServerEvent('jomidar-ammorobbery:sv:containerSync', GetEntityCoords(sceneObject), GetEntityRotation(sceneObject), index)
    TriggerServerEvent('jomidar-ammorobbery:sv:objectSync', NetworkGetNetworkIdFromEntity(sceneObject))
    TriggerServerEvent('jomidar-ammorobbery:sv:objectSync', NetworkGetNetworkIdFromEntity(lockObject))

    DeleteObject(ContainerAnimation['sceneObjects'][1])
    DeleteObject(ContainerAnimation['sceneObjects'][2])
    ClearPedTasks(ped)

    if rndContainer == index then
        SpawnGuards()
        exports['jomidar-ui']:Close()
        RemoveBlip(containersBlip)
    end
end


local guardPeds = {}

function SpawnGuards()
    for _, guard in ipairs(Config.GuardPeds) do
        local model = GetHashKey(guard.model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(1)
        end

        local guardPed = CreatePed(4, model, guard.coords.x, guard.coords.y, guard.coords.z, guard.heading, true, true)

        GiveWeaponToPed(guardPed, GetHashKey("WEAPON_ASSAULTRIFLE"), 250, false, true)
        SetPedCombatAttributes(guardPed, 46, true)
        SetPedFleeAttributes(guardPed, 0, false)
        SetPedCombatAbility(guardPed, 2)
        SetPedCombatRange(guardPed, 2)
        SetPedCombatMovement(guardPed, 2)
        SetPedRelationshipGroupHash(guardPed, GetHashKey("HATES_PLAYER"))
        TaskCombatPed(guardPed, PlayerPedId(), 0, 16)

        local blip = AddBlipForEntity(guardPed)
        SetBlipSprite(blip, 110) -- Garde armé
        SetBlipScale(blip, 0.75)
        SetBlipColour(blip, 1)
        SetBlipAsFriendly(blip, false)

        table.insert(guardPeds, { ped = guardPed, blip = blip })
    end
end


Citizen.CreateThread(function()
    AddRelationshipGroup("GUARDS")
    AddRelationshipGroup("PLAYER")

    SetRelationshipBetweenGroups(5, GetHashKey("GUARDS"), GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("GUARDS"))
end)


Citizen.CreateThread(function()
    while true do
        Wait(1000)
        for i, guard in ipairs(guardPeds) do
            if IsPedDeadOrDying(guard.ped, true) then
                RemoveBlip(guard.blip)
                table.remove(guardPeds, i)
            end
        end
    end
end)






RegisterNetEvent('jomidar-ammorobbery:cl:containerSync', function(coords, rotation, index)
    local animDict = 'anim@scripted@player@mission@tunf_train_ig1_container_p1@male@'
    loadAnimDict(animDict)

    clientContainer[index] = CreateObject(GetHashKey(Config['containers'][index].containerModel), coords, false, false, false)
    clientLock[index] = CreateObject(GetHashKey('tr_prop_tr_lock_01a'), coords, false, false, false)

    clientScene = CreateSynchronizedScene(coords, rotation, 2, true, false, 1065353216, 0, 1065353216)

    PlaySynchronizedEntityAnim(clientContainer[index], clientScene, ContainerAnimation['animations'][1][2], animDict, 1.0, -1.0, 0, 1148846080)
    ForceEntityAiAndAnimationUpdate(clientContainer[index])

    PlaySynchronizedEntityAnim(clientLock[index], clientScene, ContainerAnimation['animations'][1][3], animDict, 1.0, -1.0, 0, 1148846080)
    ForceEntityAiAndAnimationUpdate(clientLock[index])

    SetSynchronizedScenePhase(clientScene, 0.99)
    SetEntityCollision(clientContainer[index], false, true)
    FreezeEntityPosition(clientContainer[index], true)
end)


RegisterNetEvent('jomidar-ammorobbery:cl:lockSync')
AddEventHandler('jomidar-ammorobbery:cl:lockSync', function(index)
    Config['containers'][index]['lock']['taken'] = true
end)

RegisterNetEvent('jomidar-ammorobbery:cl:objectSync')
AddEventHandler('jomidar-ammorobbery:cl:objectSync', function(e)
    local entity = NetworkGetEntityFromNetworkId(e)
    DeleteEntity(entity)
    DeleteObject(entity)
end)


RegisterNetEvent('jomidar-ammorobbery:cl:targetsync', function()
    exports.ox_target:addLocalEntity(weaponBox, {
        {
            name = 'open_weapon_crate',
            icon = 'fas fa-user-secret',
            label = 'Open Crate',
            onSelect = function()
                openCrate()
            end
        }
    })
end)




function getRandomItem(items)
    local itemIndex = math.random(1, #items)
    return items[itemIndex]
end

-- Open crate function
function openCrate()
    local success = lib.skillCheck({'easy', 'medium', 'medium', 'hard', 'hard'}, {'W', 'A', 'S', 'D', 'SPACE'})

    if success then
        if Config.UseStash then
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', "WeaponCrate", {
                maxweight = 1000000,
                slots = 10,
            })
            TriggerEvent('inventory:client:SetCurrentStash', "WeaponCrate")
        else
            lib.progressBar({
                duration = 7000,
                label = 'Opening the crate...',
                useWhileDead = false,
                canCancel = false,
                disable = {
                    move = true,
                    car = false,
                    mouse = false,
                    combat = true
                }
            })

            exports.ox_target:removeLocalEntity(weaponBox)
            local item = getRandomItem(Config.WithoutStashItem)
            TriggerServerEvent('Jommidar-ammorobbery:AddItem', item.name, item.amount)
        end
    else
        lib.notify({ description = "You Failed, Try again!", type = "error" })
    end
end



function checkStash()
    if Config.UseStash then
        print("if you get stash issue then make Config.UseStash = true to Config.UseStash = false")
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        checkStash()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for i = 1, #Config['containers'] do
            DeleteEntity(containers[i])
            DeleteEntity(locks[i])
            DeleteEntity(collisions[i])
            exports.ox_target:removeZone("opencontainers" .. i)
            Config['containers'][i]['lock']['taken'] = false
            DeleteEntity(clientContainer[i])
            DeleteEntity(clientLock[i])
        end

        exports.ox_target:removeLocalEntity(weaponBox, 'Open Crate')
        DeleteEntity(weaponBox)

        exports['jomidar-ui']:Close()
    end
end)

