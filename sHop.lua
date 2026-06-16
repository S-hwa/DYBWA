local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Settings
local FILE_NAME = "ServerHopQueue.json"
local MIN_PLAYERS = 1
local MAX_PLAYERS = 5
local BATCH_SIZE = 50
local REFILL_THRESHOLD = 3

-- Global state to prevent overlapping execution loops
local isHopping = false

-- 1. Database Helpers (File I/O)
local function loadQueue()
    if isfile and isfile(FILE_NAME) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(FILE_NAME))
        end)
        if success and type(data) == "table" then
            return data
        end
    end
    return {}
end

local function saveQueue(queue)
    if writefile then
        writefile(FILE_NAME, HttpService:JSONEncode(queue))
    end
end

-- 2. The Fetching Engine
local function gatherServers(placeId, amountToGather)
    print(string.format("Gathering a fresh batch of %d servers...", amountToGather))
    local collectedServers = {}
    local currentCursor = ""
    local baseUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"
    
    local pagesToSkip = math.random(5, 15)
    
    for i = 1, pagesToSkip do
        local url = string.format(baseUrl, tostring(placeId))
        if currentCursor ~= "" then url = url .. "&cursor=" .. currentCursor end
        
        local success, response = pcall(function() return request({ Url = url, Method = "GET" }) end)
        if success and response.StatusCode == 200 then
            local body = HttpService:JSONDecode(response.Body)
            if body and body.nextPageCursor then
                currentCursor = body.nextPageCursor
            else
                break
            end
        end
        task.wait(0.05)
    end

    while #collectedServers < amountToGather do
        local url = string.format(baseUrl, tostring(placeId))
        if currentCursor ~= "" then url = url .. "&cursor=" .. currentCursor end
        
        local success, response = pcall(function() return request({ Url = url, Method = "GET" }) end)
        if not success or not response or response.StatusCode ~= 200 then break end
        
        local body = HttpService:JSONDecode(response.Body)
        if not body or not body.data then break end
        
        for _, server in ipairs(body.data) do
            if type(server) == "table" 
                and server.playing 
                and server.playing >= MIN_PLAYERS 
                and server.playing <= MAX_PLAYERS 
                and server.id ~= game.JobId then
                
                table.insert(collectedServers, server.id)
                if #collectedServers >= amountToGather then break end
            end
        end
        
        if body.nextPageCursor then
            currentCursor = body.nextPageCursor
        else
            break
        end
        task.wait(0.05)
    end
    
    return collectedServers
end

-- 3. The Main Execution Logic
local function executeSmartHop(placeId)
    if isHopping then return end
    isHopping = true

    local localPlayer = Players.LocalPlayer
    if not localPlayer then 
        isHopping = false 
        return 
    end
    
    local queue = loadQueue()
    
    -- Check if we need to refill the database
    if #queue <= REFILL_THRESHOLD then
        local newServers = gatherServers(placeId, BATCH_SIZE)
        for _, id in ipairs(newServers) do
            table.insert(queue, id)
        end
        saveQueue(queue)
        print("Database refilled! Total servers stored: " .. #queue)
    end
    
    -- Teleport to the next server in line
    if #queue > 0 then
        local targetServerId = table.remove(queue, 1)
        saveQueue(queue) -- Scrub it out immediately so we don't retry it on failure
        
        print(string.format("Attempting teleport to server %s... (%d remaining in queue)", tostring(targetServerId), #queue))
        
        local teleportSuccess, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, targetServerId, localPlayer)
        end)
        
        if not teleportSuccess then
            warn("Script-level failure initiating teleport: " .. tostring(err))
            isHopping = false
            task.wait(1)
            executeSmartHop(placeId) -- Try next server if the call itself broke
        end
    else
        warn("No servers left in the queue.")
        isHopping = false
    end
end

-- 4. The Magic Safeguard: Listen for Roblox Teleport Failures
-- This event fires if the server is full, shut down, or errors out.
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, targetPlaceId)
    if player == Players.LocalPlayer and targetPlaceId == game.PlaceId then
        warn(string.format("Teleport rejected by Roblox! Reason: %s (%s)", teleportResult.Name, errorMessage))
        
        -- Unlock our loop block, wait briefly, and cycle to the next server
        isHopping = false
        task.wait(0.5)
        executeSmartHop(game.PlaceId)
    end
end)

-- Execute the initial hop
executeSmartHop(game.PlaceId)
