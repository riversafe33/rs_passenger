local balloonOccupancy = {} -- { [balloonNetId] = { passenger1 = playerServerIdOrNil, ... } }

local function getSeatKeys()
    return {"passenger1", "passenger2", "passenger3", "passenger4"}
end

local function initializeBalloonSeats(balloonNetId)
    if not balloonOccupancy[balloonNetId] then
        balloonOccupancy[balloonNetId] = {}
        for _, seatKey in ipairs(getSeatKeys()) do
            balloonOccupancy[balloonNetId][seatKey] = nil
        end
    end
end

RegisterNetEvent("rs_passenger:requestEnterSeat", function(balloonNetId, seatType, requestingPlayerServerId)
    local src = source -- This is the server ID of the player who sent the event
    if requestingPlayerServerId ~= src then
        TriggerClientEvent("rs_passenger:seatDenied", src, "Security check failed.")
        return
    end

    initializeBalloonSeats(balloonNetId)

    if not balloonOccupancy[balloonNetId][seatType] then
        -- Check if player is already in another seat on this balloon
        for _, key in ipairs(getSeatKeys()) do
            if balloonOccupancy[balloonNetId][key] == src then
                balloonOccupancy[balloonNetId][key] = nil
                TriggerClientEvent("rs_passenger:seatUpdate", -1, balloonNetId, key, src, false) -- Broadcast old seat now vacant
            end
        end

        balloonOccupancy[balloonNetId][seatType] = src
        TriggerClientEvent("rs_passenger:seatConfirmed", src, balloonNetId, seatType, src)
        TriggerClientEvent("rs_passenger:seatUpdate", -1, balloonNetId, seatType, src, true) -- Broadcast to all clients
    else
        TriggerClientEvent("rs_passenger:seatDenied", src, "El asiento ya está ocupado.")
    end
end)

RegisterNetEvent("rs_passenger:vacateSeat", function(balloonNetId, seatType)
    local src = source
    if not balloonNetId then
        return
    end

    initializeBalloonSeats(balloonNetId) -- Ensure it exists

    if balloonOccupancy[balloonNetId][seatType] == src then
        balloonOccupancy[balloonNetId][seatType] = nil
        TriggerClientEvent("rs_passenger:seatUpdate", -1, balloonNetId, seatType, src, false) -- Broadcast to all clients
    end
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    for balloonNetId, seats in pairs(balloonOccupancy) do
        for seatKey, occupantId in pairs(seats) do
            if occupantId == src then
                balloonOccupancy[balloonNetId][seatKey] = nil
                TriggerClientEvent("rs_passenger:seatUpdate", -1, balloonNetId, seatKey, src, false)
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Every 5 minutes
        local emptyBalloons = {}
        for balloonNetId, seats in pairs(balloonOccupancy) do
            local isEmpty = true
            for _, occupantId in pairs(seats) do
                if occupantId then
                    isEmpty = false
                    break
                end
            end
            if isEmpty then
                table.insert(emptyBalloons, balloonNetId)
            end
        end

        if #emptyBalloons > 0 then
            for _, balloonNetId in ipairs(emptyBalloons) do
                balloonOccupancy[balloonNetId] = nil
            end
        end
    end
end)
