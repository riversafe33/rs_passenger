local balloonSeats = {
    passenger1 = {
        occupied = false,
        position = vector3(0.31, 0.45, 1.1), -- Front-right 
        occupant = nil
    },
    passenger2 = {
        occupied = false,
        position = vector3(-0.40, 0.45, 1.1), -- Front-left
        occupant = nil
    },
    passenger3 = {
        occupied = false,
        position = vector3(0.37, -0.5, 1.1), -- Back-right
        occupant = nil
    },
    passenger4 = {
        occupied = false,
        position = vector3(-0.0, -0.0, 1.1), -- Back-left
        occupant = nil
    }
}

local isNearBalloon = false
local nearestBalloon = nil
local playerRole = nil -- "captain", "passenger1", "passenger2", or nil
local currentBalloonEntity = nil -- Store the balloon entity the player is currently in
local currentBalloonNetId = nil -- Store the network ID of the current balloon

-- Register network events
RegisterNetEvent("rs_passenger:seatConfirmed")
RegisterNetEvent("rs_passenger:seatDenied")
RegisterNetEvent("rs_passenger:seatUpdate")

-- Balloon entry prompts
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local passengerPrompt -- Ya no usaremos Prompt para mostrar, solo NUI

local function SetupPrompts()
    -- No creamos prompt, porque usaremos NUI para mostrar texto
end

-- Function to find an unoccupied passenger seat
local function GetAvailablePassengerSeat()
    for i = 1, 4 do
        local seatKey = "passenger" .. i
        if balloonSeats[seatKey] and not balloonSeats[seatKey].occupied then
            return seatKey
        end
    end
    return nil
end

local function DetachPlayerFromBalloon()
    if playerRole and playerRole:find("passenger") then
        local playerId = PlayerPedId()
        local balloonNetId = nil
        if currentBalloonNetId and currentBalloonNetId ~= 0 then
            balloonNetId = currentBalloonNetId
        elseif nearestBalloon and NetworkGetNetworkIdFromEntity(nearestBalloon) ~= 0 then
            balloonNetId = NetworkGetNetworkIdFromEntity(nearestBalloon)
        end
        
        if balloonNetId then
            TriggerServerEvent("rs_passenger:vacateSeat", balloonNetId, playerRole)
        end

        DetachEntity(playerId, true, false) -- Colisiones activas al salir

        if balloonSeats[playerRole] then
            balloonSeats[playerRole].occupied = false
            balloonSeats[playerRole].occupant = nil
        end
        local exitedRole = playerRole
        playerRole = nil
        
        currentBalloonEntity = nil
        currentBalloonNetId = nil
        
        TriggerEvent("rs_passenger:exited", exitedRole) 
    end
end

Citizen.CreateThread(function()
    local lastKnownVehicle = 0
    while true do
        Citizen.Wait(250) -- Check periodically
        local playerPed = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(playerPed, false)

        if currentVehicle ~= 0 and GetEntityModel(currentVehicle) == GetHashKey('hotairballoon01') and GetPedInVehicleSeat(currentVehicle, -1) == playerPed then

            if playerRole and playerRole:find("passenger") then 
                if balloonSeats[playerRole] then -- Clear previous passenger state
                    balloonSeats[playerRole].occupied = false
                    balloonSeats[playerRole].occupant = nil
                end
                DetachEntity(playerPed, true, true) -- Detach from passenger seat
            end
            lastKnownVehicle = currentVehicle
        end
    end
end)

local nearestBalloon = nil
local canInteract = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if not playerRole then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local balloonHash = GetHashKey('hotairballoon01')
            local closest, closestDist = nil, 4.0

            for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                if GetEntityModel(vehicle) == balloonHash then
                    local balloonCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - balloonCoords)
                    if distance < closestDist then
                        closest = vehicle
                        closestDist = distance
                    end
                end
            end

            nearestBalloon = closest
        else
            nearestBalloon = nil
            canInteract = false
            SendNUIMessage({ action = "hideExit" })
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if nearestBalloon and not playerRole then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local balloonCoords = GetEntityCoords(nearestBalloon)
            local distance = #(playerCoords - balloonCoords)

            -- Verificar si el jugador es el conductor
            local isDriver = GetPedInVehicleSeat(nearestBalloon, -1) == playerPed

            if distance < 2.5 and not isDriver then
                local passengerSeatKey = GetAvailablePassengerSeat()
                local passengerSeatAvailable = passengerSeatKey ~= nil

                if passengerSeatAvailable then
                    if not canInteract then
                        canInteract = true
                        SendNUIMessage({ action = "showExit" })
                    end

                    if IsControlJustPressed(0, 0xF3830D8E) then -- J
                        local balloonNetId = NetworkGetNetworkIdFromEntity(nearestBalloon)
                        if balloonNetId ~= 0 then
                            TriggerServerEvent("rs_passenger:requestEnterSeat", balloonNetId, passengerSeatKey, GetPlayerServerId(PlayerId()))
                        end
                        canInteract = false
                        SendNUIMessage({ action = "hideExit" })
                    end
                else
                    if canInteract then
                        canInteract = false
                        SendNUIMessage({ action = "hideExit" })
                    end
                end
            else
                if canInteract then
                    canInteract = false
                    SendNUIMessage({ action = "hideExit" })
                end
            end
        else
            if canInteract then
                canInteract = false
                SendNUIMessage({ action = "hideExit" })
            end
        end
    end
end)

-- Crear prompt oculto e inactivo por defecto
local showingPrompt = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Check every frame

        if playerRole and playerRole:find("passenger") then
            -- Mostrar NUI si aún no está visible
            if not showingPrompt then
                showingPrompt = true
                SendNUIMessage({ action = "show" })
            end

            -- Detectar tecla j (INPUT_DYNAMIC_SCENARIO)
            if IsControlJustPressed(0, 0xF3830D8E) then
                DetachPlayerFromBalloon()
                
                -- Ocultar NUI al salir
                if showingPrompt then
                    showingPrompt = false
                    SendNUIMessage({ action = "hide" })
                end
            end
        else
            -- Ocultar si ya no es pasajero
            if showingPrompt then
                showingPrompt = false
                SendNUIMessage({ action = "hide" })
            end
        end
    end
end)

local function AttachPlayerToSeat(playerId, balloon, seatType)
    local seatInfo = balloonSeats[seatType]
    if not seatInfo then
        return false
    end

    local pos = seatInfo.position
    AttachEntityToEntity(playerId, balloon, 0, 
        pos.x, pos.y, pos.z, 
        0.0, 0.0, 0.0, 
        false, false, false, false, 0, true)

    currentBalloonEntity = balloon
    currentBalloonNetId = NetworkGetNetworkIdFromEntity(balloon)

    return true
end


-- Server event handlers
AddEventHandler("rs_passenger:seatConfirmed", function(balloonNetId, seatType, assignedPlayerServerId)
    local playerPed = PlayerPedId()
    local localPlayerServerId = GetPlayerServerId(PlayerId())

    if assignedPlayerServerId == localPlayerServerId then
        local balloonEntity = NetworkGetEntityFromNetworkId(balloonNetId)
        if DoesEntityExist(balloonEntity) then
            if seatType:find("passenger") then
                AttachPlayerToSeat(playerPed, balloonEntity, seatType)
                playerRole = seatType
                nearestBalloon = balloonEntity -- Ensure nearestBalloon is set
                currentBalloonEntity = balloonEntity
                currentBalloonNetId = balloonNetId
                TriggerEvent("rs_passenger:enteredAsPassenger")
            end
        end
    end
end)

AddEventHandler("rs_passenger:seatDenied", function(reason)
end)

AddEventHandler("rs_passenger:seatUpdate", function(balloonNetId, seatType, occupantPlayerServerId, isOccupied)
    local balloonEntity = nil
    if nearestBalloon and NetworkGetNetworkIdFromEntity(nearestBalloon) == balloonNetId then
        balloonEntity = nearestBalloon
    elseif playerRole and GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 and NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)) == balloonNetId then
        balloonEntity = GetVehiclePedIsIn(PlayerPedId(), false)
    end

    if balloonEntity then
        if balloonSeats[seatType] then
            balloonSeats[seatType].occupied = isOccupied
            balloonSeats[seatType].occupant = isOccupied and occupantPlayerServerId or nil
            -- If this client was the occupant and is now told the seat is not occupied by them (or anyone), clear their role.
            local localPlayerServerId = GetPlayerServerId(PlayerId())
            if playerRole == seatType and occupantPlayerServerId ~= localPlayerServerId and not isOccupied then
                if seatType:find("passenger") then DetachEntity(PlayerPedId(), true, true) end -- Ensure detachment if passenger
                playerRole = nil
                TriggerEvent("rs_passenger:exited", seatType)
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if playerRole then
            DetachPlayerFromBalloon()
        end
    end
end)