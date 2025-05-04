-- Server-side configuration
local config = {
    debug = true, -- Enabled for detailed logging
    checkInterval = 30000, -- Check every 30 seconds
    maxIdleTime = 1800000, -- 30 minutes until cleanup
    maxCheckDistance = 50.0, -- Max distance to consider for occupancy (meters)
    warningIntervals = {
        120000, -- 2 minute warning
        60000,  -- 1 minute warning
        30000   -- 30 second warning
    },
    cleanupCommand = "cleanupvehicles",
    cleanupPermission = "command.cleanupvehicles",
    warningMessage = "Your vehicle will be cleaned up in {time} due to inactivity",
    cleanupMessage = "Your vehicle was cleaned up due to inactivity"
}

local playerVehicles = {}

-- Fixed debug print function that handles all value types
local function debugPrint(...)
    if config.debug then
        local args = {...}
        local strings = {}
        for i = 1, #args do
            local arg = args[i]
            if type(arg) == "boolean" then
                table.insert(strings, arg and "true" or "false")
            elseif type(arg) == "table" then
                table.insert(strings, "table")
            elseif type(arg) == "nil" then
                table.insert(strings, "nil")
            else
                table.insert(strings, tostring(arg))
            end
        end
        print("[AntiDespawn] " .. table.concat(strings, " "))
    end
end

-- Format time for messages
local function formatTime(ms)
    local seconds = math.floor(ms / 1000)
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        return minutes.." minute"..(minutes > 1 and "s" or "")
    else
        return seconds.." second"..(seconds > 1 and "s" or "")
    end
end

-- Send warning to vehicle owner
local function sendWarning(playerId, timeLeft)
    local timeString = formatTime(timeLeft)
    TriggerClientEvent('chat:addMessage', playerId, {
        color = {255, 165, 0},
        args = {"[Vehicle Cleanup]", config.warningMessage:gsub("{time}", timeString)}
    })
end

-- Improved vehicle occupancy check with distance verification
local function isVehicleOccupied(vehicleId)
    local entity = NetworkGetEntityFromNetworkId(vehicleId)
    if not DoesEntityExist(entity) then
        debugPrint("Vehicle", vehicleId, "doesn't exist in occupancy check")
        return false
    end
    
    local vehicleCoords = GetEntityCoords(entity)
    local players = GetPlayers()
    local occupied = false

    for _, playerId in ipairs(players) do
        local ped = GetPlayerPed(playerId)
        if DoesEntityExist(ped) then
            local distance = #(vehicleCoords - GetEntityCoords(ped))
            
            if distance < config.maxCheckDistance then
                local veh = GetVehiclePedIsIn(ped, false)
                
                if veh ~= 0 and veh == entity then
                    local seat = GetPedInVehicleSeat(veh, -1)
                    if seat == ped or IsPedSittingInAnyVehicle(ped) then
                        debugPrint("Vehicle", vehicleId, "occupied by player", playerId, 
                                  "seat:", (seat == ped and "driver" or "passenger"), 
                                  "distance:", string.format("%.1fm", distance))
                        occupied = true
                        break
                    end
                end
            end
        end
    end

    if not occupied then
        debugPrint("Vehicle", vehicleId, "is not occupied (no players within", 
                  config.maxCheckDistance, "m)")
    end

    return occupied
end

-- Register a vehicle as player-spawned
RegisterNetEvent('antiDespawn:registerVehicle')
AddEventHandler('antiDespawn:registerVehicle', function(vehicleId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(vehicleId)
    
    if not DoesEntityExist(entity) then
        debugPrint("Vehicle", vehicleId, "doesn't exist, ignoring registration from player", src)
        return
    end
    
    playerVehicles[vehicleId] = {
        owner = src,
        lastUsed = GetGameTimer(),
        networkId = vehicleId,
        warningsSent = {}
    }
    
    debugPrint("Registered vehicle", vehicleId, "for player", src, 
              "model:", GetEntityModel(entity))
end)

-- Cleanup old vehicles
function cleanupOldVehicles(manual)
    local currentTime = GetGameTimer()
    local toRemove = {}
    local cleaned = 0
    
    debugPrint("Starting cleanup check", "manual:", manual, "total vehicles:", tableCount(playerVehicles))

    for vehicleId, data in pairs(playerVehicles) do
        local entity = NetworkGetEntityFromNetworkId(vehicleId)
        
        if not DoesEntityExist(entity) then
            table.insert(toRemove, vehicleId)
            debugPrint("Vehicle", vehicleId, "no longer exists, removing from tracking")
            goto continue
        end
        
        if isVehicleOccupied(vehicleId) then
            data.lastUsed = currentTime
            data.warningsSent = {}
            debugPrint("Vehicle", vehicleId, "is occupied, updating last used time")
            goto continue
        end
        
        local timeSinceLastUse = currentTime - data.lastUsed
        local timeUntilCleanup = config.maxIdleTime - timeSinceLastUse
        
        -- Send warnings at configured intervals
        if not manual and timeUntilCleanup > 0 then
            for _, interval in ipairs(config.warningIntervals) do
                if timeUntilCleanup <= interval and not data.warningsSent[interval] then
                    sendWarning(data.owner, timeUntilCleanup)
                    data.warningsSent[interval] = true
                    debugPrint("Sent warning for vehicle", vehicleId, "time left:", formatTime(timeUntilCleanup))
                end
            end
        end
        
        -- Cleanup if time expired or manual cleanup
        if manual or timeUntilCleanup <= 0 then
            if not manual then
                TriggerClientEvent('chat:addMessage', data.owner, {
                    color = {255, 0, 0},
                    args = {"[Vehicle Cleanup]", config.cleanupMessage}
                })
            end
            
            DeleteEntity(entity)
            table.insert(toRemove, vehicleId)
            cleaned = cleaned + 1
            debugPrint("Removing vehicle", vehicleId, manual and "manual" or "inactive for "..formatTime(timeSinceLastUse))
        end
        
        ::continue::
    end
    
    -- Remove cleaned up vehicles
    for _, vehicleId in ipairs(toRemove) do
        playerVehicles[vehicleId] = nil
    end
    
    debugPrint("Cleanup completed", "removed:", cleaned, "vehicles")
    return cleaned
end

-- Helper function to count table elements
function tableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Manual cleanup command
RegisterCommand(config.cleanupCommand, function(source, args, rawCommand)
    if source ~= 0 then -- If not server console
        local hasPerm = IsPlayerAceAllowed(source, config.cleanupPermission)
        if not hasPerm then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                args = {"[AntiDespawn]", "You don't have permission to use this command!"}
            })
            return
        end
    end
    
    local cleaned = cleanupOldVehicles(true)
    
    if source ~= 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {"[AntiDespawn]", ("Cleaned up %d vehicles"):format(cleaned)}
        })
    else
        print(("[AntiDespawn] Cleaned up %d vehicles"):format(cleaned))
    end
end, false)

-- Periodic cleanup
Citizen.CreateThread(function()
    while true do
        cleanupOldVehicles()
        Citizen.Wait(config.checkInterval)
    end
end)

-- Handle resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        debugPrint("Resource stopping - cleaning up all tracked vehicles")
        for vehicleId, _ in pairs(playerVehicles) do
            local entity = NetworkGetEntityFromNetworkId(vehicleId)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
    end
end)

debugPrint("Anti-Vehicle Despawn system started")