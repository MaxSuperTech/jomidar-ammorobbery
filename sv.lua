ESX = exports["es_extended"]:getSharedObject()


local Cooldown = false

RegisterNetEvent('jomidar-ammorobbery:sv:coolout', function()
    if Cooldown then return end
    Cooldown = true

    local timer = Config.Cooldown * 60000

    CreateThread(function()
        while timer > 0 do
            Wait(1000)
            timer = timer - 1000
        end

        Cooldown = false
        TriggerClientEvent("jomidar-ammorobbery:cl:clear", -1)
    end)
end)


-- Cooldown check callback
lib.callback.register("jomidar-ammorobbery:sv:coolc", function(source)
    if Cooldown then
        return true
    else
        return false
    end
end)

-- Count active cops
lib.callback.register('jomidar-ammorobbery:sv:GetCops', function(source)
    local xPlayers = ESX.GetExtendedPlayers("job", Config.PoliceJobtype)
    local onDutyCount = 0

    for _, xPlayer in pairs(xPlayers) do
        if xPlayer.job.name == Config.PoliceJobtype and xPlayer.job.grade > 0 then
            onDutyCount = onDutyCount + 1
        end
    end

    return onDutyCount
end)



-- Synchronise l'ouverture de conteneur
RegisterNetEvent('jomidar-ammorobbery:sv:containerSync', function(coords, rotation, index)
    TriggerClientEvent('jomidar-ammorobbery:cl:containerSync', -1, coords, rotation, index)
end)

-- Synchronise l'ouverture du cadenas
RegisterNetEvent('jomidar-ammorobbery:sv:lockSync', function(index)
    TriggerClientEvent('jomidar-ammorobbery:cl:lockSync', -1, index)
end)

-- Synchronise un objet spécifique
RegisterNetEvent('jomidar-ammorobbery:sv:objectSync', function(entity)
    TriggerClientEvent('jomidar-ammorobbery:cl:objectSync', -1, entity)
end)

-- Synchronise l'interaction + ajoute les objets au stash
RegisterNetEvent('jomidar-ammorobbery:sv:synctarget', function()
    TriggerClientEvent('jomidar-ammorobbery:cl:targetsync', -1)

    local index = math.random(1, #Config.Items)
    local stashName = "WeaponCrate"
    local newItems = Config.Items[index]

    AddItemsToStash(stashName, newItems)
end)


-- Ajout d'item au joueur (ox_inventory)
RegisterNetEvent('Jommidar-ammorobbery:AddItem', function(itemName, itemAmount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        exports.ox_inventory:AddItem(xPlayer.source, itemName, itemAmount)
        -- Pas besoin de ItemBox si tu utilises ox_inventory : il gère l'affichage via la config
    end
end)

-- Clear containers pour tous les clients
RegisterNetEvent('jomidar-ammorobbery:sv:ClearSync', function()
    TriggerClientEvent('jomidar-ammorobbery:cl:clear', -1)
end)


-- Function to add multiple items to the stash in the corresponding row of the database table
function AddItemsToStash(stashName, newItems)
    for _, item in ipairs(newItems) do
        exports.ox_inventory:AddItem(stashName, item.name, item.amount)
    end
    print("Items added to stash via ox_inventory")
end


if Config.CheckForUpdates then

    local function logVersion(status, message)
        local color = status == 'success' and '^2' or '^1'
        print(('^8[J0M1D4R]%s %s^7'):format(color, message))
    end

    local function logUpdate(message)
        print(('^8[J0M1D4R]^3 [Update Log] %s^7'):format(message))
    end

    local function fetchUpdateLog()
        PerformHttpRequest('https://raw.githubusercontent.com/Haaasib/updates/main/ar.txt', function(err, text)
            if not text then
                logUpdate('Unable to fetch the update log.')
                return
            end
            logUpdate('\n' .. text)
        end)
    end

    local function checkMenuVersion()
        PerformHttpRequest('https://raw.githubusercontent.com/Haaasib/updates/main/ammorob.txt', function(err, latestVersion)
            local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

            if not latestVersion then
                logVersion('error', 'Unable to check for latest version.')
                return
            end

            logVersion('success', 'Current Version: ' .. currentVersion)
            logVersion('success', 'Latest Version: ' .. latestVersion)

            if latestVersion:gsub("%s+", "") == currentVersion:gsub("%s+", "") then
                logVersion('success', 'You are running the latest version.')
            else
                logVersion('error', 'Outdated version detected. Please update to ' .. latestVersion)
                fetchUpdateLog()
            end
        end)
    end

    checkMenuVersion()
end


