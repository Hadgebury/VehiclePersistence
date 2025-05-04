-- Client-side configuration
local config = {
    checkInterval = 5000, -- Check every 5 seconds
    maxDistance = 100.0, -- Max distance to check for owned vehicles
    debug = false -- Set to true for debug logs
}

local registeredVehicles = {}
local isChecking = false

-- Debug print function
local function debugPrint(...)
    if config.debug then
        print("[AntiDespawn-Client] " .. ...)
    end
end

-- Check if player is in or near their spawned vehicles
function checkForPlayerVehicles()
    if isChecking then return end
    isChecking = true

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Check if player is in a vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        local vehicleId = NetworkGetNetworkIdFromEntity(vehicle)

        if not registeredVehicles[vehicleId] then
            registeredVehicles[vehicleId] = true
            TriggerServerEvent('antiDespawn:registerVehicle', vehicleId)
            debugPrint("Registered occupied vehicle: " .. vehicleId)
        end
    end

    -- Check nearby vehicles (if player recently exited one)
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local distance = #(playerCoords - GetEntityCoords(vehicle))
        
        if distance < config.maxDistance then
            local vehicleId = NetworkGetNetworkIdFromEntity(vehicle)
            
            -- Check if player is the driver (owner)
            if GetPedInVehicleSeat(vehicle, -1) == playerPed and not registeredVehicles[vehicleId] then
                registeredVehicles[vehicleId] = true
                TriggerServerEvent('antiDespawn:registerVehicle', vehicleId)
                debugPrint("Registered nearby owned vehicle: " .. vehicleId)
            end
        end
    end

    isChecking = false
end

-- Main thread
Citizen.CreateThread(function()
    while true do
        checkForPlayerVehicles()
        Citizen.Wait(config.checkInterval)
    end
end)

-- Reset registration when player exits vehicle
local lastVehicle = 0
Citizen.CreateThread(function()
    while true do
        local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        
        -- Detect vehicle exit
        if lastVehicle ~= 0 and currentVehicle == 0 then
            local vehicleId = NetworkGetNetworkIdFromEntity(lastVehicle)
            if registeredVehicles[vehicleId] then
                debugPrint("Player exited vehicle " .. vehicleId)
                -- The server will handle tracking usage time
            end
        end
        
        lastVehicle = currentVehicle
        Citizen.Wait(1000)
    end
end)

-- Handle resource restart
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        registeredVehicles = {}
    end
end)

debugPrint("Anti-Vehicle Despawn client script started")