print("executed")
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =============================================================================
-- [ 1. CONFIGURATION & STATE ]
-- =============================================================================
local CONFIG_FILE = "PetScannerConfig.json"
local WEBHOOK_URL = "" -- Placeholder for your safety
local MAX_WAIT_TIME = 120

local ALL_PETS = {
    "Frog", "Bunny", "Bee", "Raccoon", "Owl", "Robin", "Deer",
    "Monkey", "Unicorn", "GoldenDragonfly", "BlackDragon", "IceSerpent"
}

local MAX_PRICES = {
    Frog = 11000,
    Bunny = 21000,
    Owl = 26000,
    Deer = 51000,
    Robin = 76000,
    Bee = 1100000,
    Monkey = 3100000,
    GoldenDragonfly = 9100000,
    Unicorn = 12100000,
    Raccoon = 15100000,
    IceSerpent = 21000000
}

-- State Engine
local isScanning = false
local autoHop = true  
local hopCooldown = false
local loopActive = false
local isCollapsed = false

-- =============================================================================
-- [ 2. LOADING SCREEN SKIPPER ]
-- =============================================================================

local function performClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local clickScreen = task.spawn(function()
    while true do
        performClick()
        task.wait(0.25)
    end
end)

local function waitForLoadingScreen()
	while not player:GetAttribute("LoadingScreenDone") do
		task.wait(0.25)
	end

   task.cancel(clickScreen)
   print("✅ Loading screen skipped!")
	return true
end

-- =============================================================================
-- [ 3. DATA MANAGEMENT & WEBHOOKS ]
-- =============================================================================

-- Unified Config Handlers
local function saveConfig(targets)
    pcall(function()
        local data = {
            targets = {},
            settings = {
                autoScan = isScanning,
                autoHop = autoHop
            }
        }
        
        for k, v in pairs(targets) do
            if v == true then table.insert(data.targets, k) end
        end
        
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function loadConfig()
    local loadedTargets = {}
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(data) == "table" then
                
                -- Load Targets
                if data.targets then
                    for _, k in pairs(data.targets) do 
                        local cleanName = k:match("([^_]+)") or k
                        loadedTargets[cleanName] = true 
                    end
                end
                
                -- Load Settings
                if data.settings then
                    if _G.PetScannerAutoScan == nil and data.settings.autoScan ~= nil then
                        _G.PetScannerAutoScan = data.settings.autoScan
                    end
                    if _G.PetScannerAutoHop == nil and data.settings.autoHop ~= nil then
                        autoHop = data.settings.autoHop
                    end
                end
            end
        end
    end)
    return loadedTargets
end

local checkedPets = loadConfig()
if _G.PetScannerAutoHop ~= nil then autoHop = _G.PetScannerAutoHop end

if _G.PetScannerTargets then
    for k, v in pairs(_G.PetScannerTargets) do 
        local cleanName = k:match("([^_]+)") or k
        checkedPets[cleanName] = v 
    end
end

local autoStartScan = _G.PetScannerAutoScan or false
_G.PetScannerAutoScan = nil -- Reset local override cache after loading

local function sendWebhook(pet, bought)
    -- 1. Buy-Only Notification Guard
    -- If the pet hasn't been bought yet, do nothing.
    if not bought then return end 
    
    if WEBHOOK_URL == "YOUR_DISCORD_WEBHOOK_HERE" or WEBHOOK_URL == "" then return end

    pcall(function()
        -- 2. Player Name & Sheckles Balance Tracking
        local playerName = player.Name
        local shecklesBalance = "Unknown"
        
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats and leaderstats:FindFirstChild("Sheckles") then
            shecklesBalance = tostring(leaderstats.Sheckles.Value)
        end

        -- 3. Embed Formatting
        local embedData = {
            ["title"] = "✅ Pet Successfully Bought!",
            ["color"] = 0x50DC64, -- Hex color for success green
            ["fields"] = {
                {
                    ["name"] = "🐾 Pet Details",
                    ["value"] = "**" .. pet.size .. " " .. pet.name .. "**",
                    ["inline"] = true
                },
                {
                    ["name"] = "💰 Cost",
                    ["value"] = "`" .. tostring(pet.cost) .. "`",
                    ["inline"] = true
                },
                {
                    ["name"] = "👤 Player",
                    ["value"] = "||" .. playerName .. "||", -- Spoilered for privacy
                    ["inline"] = true
                },
                {
                    ["name"] = "💎 Sheckles Remaining",
                    ["value"] = "`" .. shecklesBalance .. "`",
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = "Pet Scanner Auto-Buyer"
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }

        local payload = {
            ["content"] = "@everyone", -- Ping only triggers here on success
            ["username"] = "Pet Scanner",
            ["embeds"] = {embedData}
        }

        local body = HttpService:JSONEncode(payload)
        local httpFn = request or http_request or (http and http.request) or (syn and syn.request)
        
        if httpFn then
            httpFn({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body,
            })
        else
            warn("Executor does not support custom HTTP requests. Webhook failed.")
        end
    end)
end

-- =============================================================================
-- [ 4. CORE MECHANICS & AUTOMATION ]
-- =============================================================================
local function parseCost(costStr)
    if not costStr or costStr == "?" then return math.huge end
    costStr = string.lower(string.gsub(costStr, ",", ""))
    local num = tonumber(string.match(costStr, "[%d%.]+"))
    if not num then return math.huge end
    
    if string.find(costStr, "k") then num = num * 1000
    elseif string.find(costStr, "m") then num = num * 1000000
    elseif string.find(costStr, "b") then num = num * 1000000000 end
    
    return num
end

local function getPets()
    local petSpawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
    if not petSpawns then return {} end
    
    local pets = {}
    for _, pet in pairs(petSpawns:GetChildren()) do
        local buyPrompt = pet:FindFirstChild("BuyPrompt", true)
        if not buyPrompt or not buyPrompt.Enabled then continue end
        
        local costLabel = pet:FindFirstChild("PetCostTimer", true)
        local leaveLabel = pet:FindFirstChild("PetLeaveTimer", true)
        local cost = costLabel and costLabel:FindFirstChildWhichIsA("TextLabel") and costLabel:FindFirstChildWhichIsA("TextLabel").Text or "?"
        local leave = leaveLabel and leaveLabel:FindFirstChildWhichIsA("TextLabel") and leaveLabel:FindFirstChildWhichIsA("TextLabel").Text or "?"
        
        local fullName = pet.Name
        local species = fullName:match("WildPet_(.-)_WildPet") or fullName
        local size = fullName:lower():find("huge") and "Huge" or fullName:lower():find("big") and "Big" or "Normal"
        
        table.insert(pets, {
            name = species, size = size, key = species .. "_" .. size,
            cost = cost, leave = leave, prompt = buyPrompt, model = pet
        })
    end
    return pets
end

local function isTargeted(pet)
    if checkedPets[pet.name] == true then
        local maxPrice = MAX_PRICES[pet.name]
        if maxPrice then
            return parseCost(pet.cost) < maxPrice
        end
        return true 
    end
    return false
end

local function autoBuy(pet)
    if not pet.prompt then return false end
    
    local tweenSpeed = 50 

    while pet.model and pet.model.Parent and pet.prompt and pet.prompt.Parent do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            
            local petRoot = pet.model:FindFirstChild("RootPart") or pet.model:FindFirstChildWhichIsA("BasePart")
            if petRoot then
                local targetCFrame = petRoot.CFrame * CFrame.new(0, 0, 2)
                local distance = (hrp.Position - targetCFrame.Position).Magnitude
                
                if distance > 3 then
                    local tweenDuration = distance / tweenSpeed
                    local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
                    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
                    tween:Play()
                else
                    hrp.CFrame = targetCFrame
                end
            end
        end
        
        pet.prompt.MaxActivationDistance = 9999
        pet.prompt.HoldDuration = 0
    
        if fireproximityprompt then
            fireproximityprompt(pet.prompt)
        end
        
        task.wait(0.1)
    end
    
    task.wait(0.2)
    return true
end

local function hopServer()
    if hopCooldown then return end
    hopCooldown = true
    
    -- Save global states for the next server
    _G.PetScannerTargets = checkedPets
    _G.PetScannerAutoHop = autoHop
    _G.PetScannerAutoScan = isScanning
    
    pcall(function()
        -- 1. Setup queue_on_teleport handling for different executors
        local queueFn = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        
        -- 2. Verify the executor supports queuing AND the file exists
        if queueFn and isfile and isfile("SniperV2.txt") then
            
            -- Read the local file verbatim and queue its contents
            local codeToInject = readfile("SniperV2.txt")
            queueFn(codeToInject)
            
        else
            warn("Executor does not support queue_on_teleport, or SniperV2.txt is missing from your workspace folder!")
        end

        -- 3. Execute the actual teleport
        loadstring(game:HttpGet("https://raw.githubusercontent.com/AwesomeDudePerfect/psx-gem-farm/refs/heads/main/tp.lua"))()
    end)
    
    task.wait(10)
    hopCooldown = false
end

local function countTargetPets(nameTable)
    local count = 0
    local function scanFolder(folder)
        if not folder then return end
        for _, item in pairs(folder:GetChildren()) do
            local species = item.Name:match("WildPet_(.-)_WildPet") or item.Name
            if nameTable[species] or nameTable[item.Name] then count = count + 1 end
        end
    end
    pcall(scanFolder, player.Backpack)
    pcall(scanFolder, player.Character)
    return count
end

-- =============================================================================
-- [ 5. UI CONSTRUCTION & GENERATION ]
-- =============================================================================
local function createInstance(className, properties, parent)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

_G.PetScannerStop = true
task.wait(0.2)
_G.PetScannerStop = false

pcall(function()
    for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if v.Name == "PetScannerGUI" then v:Destroy() end
    end
    for _, v in pairs(playerGui:GetChildren()) do
        if v.Name == "PetScannerGUI" then v:Destroy() end
    end
end)
task.wait(0.1)

local sg = createInstance("ScreenGui", {Name = "PetScannerGUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = playerGui end

local MIN_WIDTH, MIN_HEIGHT = 520, 300
local main = createInstance("Frame", {
    Size = UDim2.new(0, 700, 0, 340), Position = UDim2.new(0.5, -350, 0.5, -170),
    BackgroundColor3 = Color3.fromRGB(12, 12, 20), BackgroundTransparency = 0.05, BorderSizePixel = 0, ClipsDescendants = true
}, sg)
createInstance("UICorner", {CornerRadius = UDim.new(0, 14)}, main)

local mainStroke = createInstance("UIStroke", {Color = Color3.fromRGB(180, 120, 255), Thickness = 1.5, Transparency = 0.3}, main)
local header = createInstance("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Color3.fromRGB(20, 15, 35), BackgroundTransparency = 0.1, BorderSizePixel = 0}, main)
createInstance("UICorner", {CornerRadius = UDim.new(0, 14)}, header)
createInstance("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = Color3.fromRGB(20, 15, 35), BackgroundTransparency = 0.1, BorderSizePixel = 0}, header)

local dotFrame = createInstance("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 14, 0.5, -5), BackgroundColor3 = Color3.fromRGB(180, 120, 255), BorderSizePixel = 0}, header)
createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, dotFrame)
createInstance("TextLabel", {Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1, Text = "PET SCANNER", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.fromRGB(180, 120, 255), TextXAlignment = Enum.TextXAlignment.Left}, header)

local bodyContent = createInstance("Frame", {Size = UDim2.new(1, 0, 1, -42), Position = UDim2.new(0, 0, 0, 42), BackgroundTransparency = 1, BorderSizePixel = 0}, main)
local statusBar = createInstance("Frame", {Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 6), BackgroundColor3 = Color3.fromRGB(20, 15, 35), BackgroundTransparency = 0.2, BorderSizePixel = 0}, bodyContent)
createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, statusBar)

local statusLbl = createInstance("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "● IDLE — Press SCAN to start", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(120, 120, 160)}, statusBar)

local leftCol = createInstance("Frame", {Size = UDim2.new(0.5, -8, 1, -80), Position = UDim2.new(0, 10, 0, 38), BackgroundTransparency = 1, BorderSizePixel = 0}, bodyContent)
createInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "TARGET PETS (regardless of size)", Font = Enum.Font.GothamBlack, TextSize = 9, TextColor3 = Color3.fromRGB(180, 120, 255), TextXAlignment = Enum.TextXAlignment.Left}, leftCol)

local petScroll = createInstance("ScrollingFrame", {Size = UDim2.new(1, 0, 1, -20), Position = UDim2.new(0, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(15, 10, 25), BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageTransparency = 0.5, ScrollingDirection = Enum.ScrollingDirection.Y}, leftCol)
createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, petScroll)
local petScrollLayout = createInstance("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, petScroll)
createInstance("UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, petScroll)

local rightCol = createInstance("Frame", {Size = UDim2.new(0.5, -8, 1, -80), Position = UDim2.new(0.5, 4, 0, 38), BackgroundTransparency = 1, BorderSizePixel = 0}, bodyContent)
createInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "CURRENT PETS IN SERVER", Font = Enum.Font.GothamBlack, TextSize = 9, TextColor3 = Color3.fromRGB(180, 120, 255), TextXAlignment = Enum.TextXAlignment.Left}, rightCol)

local currentFrame = createInstance("ScrollingFrame", {Size = UDim2.new(1, 0, 1, -20), Position = UDim2.new(0, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(15, 10, 25), BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageTransparency = 0.5, ScrollingDirection = Enum.ScrollingDirection.Y}, rightCol)
createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, currentFrame)
local currentLayout = createInstance("UIListLayout", {Padding = UDim.new(0, 3)}, currentFrame)
createInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, currentFrame)

local btnRow = createInstance("Frame", {Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 1, -36), BackgroundTransparency = 1}, bodyContent)
local scanBtn = createInstance("TextButton", {Size = UDim2.new(0.48, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 50, 140), BackgroundTransparency = 0.2, Text = "▶ SCAN", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(200, 180, 255), BorderSizePixel = 0}, btnRow)
createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, scanBtn)

local hopBtn = createInstance("TextButton", {Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(30, 80, 40), BackgroundTransparency = 0.2, Text = "🔀 AUTO HOP: ON", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(150, 255, 150), BorderSizePixel = 0}, btnRow)
createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, hopBtn)

local collapseBtn = createInstance("TextButton", {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -64, 0.5, -13), BackgroundColor3 = Color3.fromRGB(40, 80, 140), BackgroundTransparency = 0.2, Text = "—", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(180, 210, 255), BorderSizePixel = 0}, header)
createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, collapseBtn)

local exitBtn = createInstance("TextButton", {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -34, 0.5, -13), BackgroundColor3 = Color3.fromRGB(180, 40, 40), BackgroundTransparency = 0.2, Text = "✕", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255, 200, 200), BorderSizePixel = 0}, header)
createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, exitBtn)

local resizeHandle = createInstance("TextButton", {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -18, 1, -18), BackgroundColor3 = Color3.fromRGB(180, 120, 255), BackgroundTransparency = 0.5, Text = "⤡", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(220, 200, 255), BorderSizePixel = 0}, main)
createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, resizeHandle)

-- =============================================================================
-- [ 6. UI DYNAMICS & REFRESH LOGIC ]
-- =============================================================================
local function refreshCurrentPets()
    for _, v in pairs(currentFrame:GetChildren()) do
        if v:IsA("Frame") or v:IsA("TextLabel") then v:Destroy() end
    end
    local pets = getPets()
    if #pets == 0 then
        createInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "No pets in server", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.fromRGB(100, 90, 130)}, currentFrame)
        return
    end
    for _, pet in pairs(pets) do
        local isTarget = isTargeted(pet)
        local row = createInstance("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = isTarget and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(30, 20, 50), BackgroundTransparency = 0.3, BorderSizePixel = 0}, currentFrame)
        createInstance("UICorner", {CornerRadius = UDim.new(0, 5)}, row)
        createInstance("TextLabel", {Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = (isTarget and "✓ " or " ") .. pet.size .. " " .. pet.name .. " " .. pet.cost .. " " .. pet.leave, Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = isTarget and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(160, 150, 190), TextXAlignment = Enum.TextXAlignment.Left}, row)
    end
end

for _, petName in ipairs(ALL_PETS) do
    local isChecked = checkedPets[petName] == true

    local petRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 32), 
        BackgroundColor3 = isChecked and Color3.fromRGB(40, 30, 70) or Color3.fromRGB(20, 15, 35), 
        BackgroundTransparency = 0.3, 
        BorderSizePixel = 0
    }, petScroll)
    createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, petRow)
    
    local nameLbl = createInstance("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0), 
        Position = UDim2.new(0, 10, 0, 0), 
        BackgroundTransparency = 1, 
        Text = petName, 
        Font = Enum.Font.GothamBold, 
        TextSize = 11, 
        TextColor3 = isChecked and Color3.fromRGB(220, 180, 255) or Color3.fromRGB(150, 140, 170), 
        TextXAlignment = Enum.TextXAlignment.Left
    }, petRow)

    local statusFrame = createInstance("Frame", {
        Size = UDim2.new(0, 80, 0, 22), 
        Position = UDim2.new(1, -90, 0.5, -11), 
        BackgroundColor3 = isChecked and Color3.fromRGB(80, 50, 140) or Color3.fromRGB(35, 25, 55), 
        BackgroundTransparency = 0.2, 
        BorderSizePixel = 0
    }, petRow)
    createInstance("UICorner", {CornerRadius = UDim.new(0, 5)}, statusFrame)
    local statusStroke = createInstance("UIStroke", {Color = isChecked and Color3.fromRGB(180, 120, 255) or Color3.fromRGB(60, 50, 80), Thickness = 1}, statusFrame)
    
    local statusLblText = createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), 
        BackgroundTransparency = 1, 
        Text = isChecked and "✓ ON" or "OFF", 
        Font = Enum.Font.GothamBold, 
        TextSize = 9, 
        TextColor3 = isChecked and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(120, 110, 140)
    }, statusFrame)

    local btn = createInstance("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", BorderSizePixel = 0}, statusFrame)

    btn.MouseButton1Click:Connect(function()
        checkedPets[petName] = not (checkedPets[petName] == true)
        _G.PetScannerTargets = checkedPets
        saveConfig(checkedPets)
        
        local active = checkedPets[petName]
        petRow.BackgroundColor3 = active and Color3.fromRGB(40, 30, 70) or Color3.fromRGB(20, 15, 35)
        nameLbl.TextColor3 = active and Color3.fromRGB(220, 180, 255) or Color3.fromRGB(150, 140, 170)
        statusFrame.BackgroundColor3 = active and Color3.fromRGB(80, 50, 140) or Color3.fromRGB(35, 25, 55)
        statusStroke.Color = active and Color3.fromRGB(180, 120, 255) or Color3.fromRGB(60, 50, 80)
        statusLblText.Text = active and "✓ ON" or "OFF"
        statusLblText.TextColor3 = active and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(120, 110, 140)
    end)
end

petScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    petScroll.CanvasSize = UDim2.new(0, 0, 0, petScrollLayout.AbsoluteContentSize.Y + 10)
end)
currentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    currentFrame.CanvasSize = UDim2.new(0, 0, 0, currentLayout.AbsoluteContentSize.Y + 8)
end)

-- =============================================================================
-- [ 7. UNIFIED SINGLE PROCESSING LOOP (BATCH BUY) ]
-- =============================================================================
local function updateStatus(text, color)
    statusLbl.Text = text
    statusLbl.TextColor3 = color or Color3.fromRGB(120, 120, 160)
end

local function runScanningLoop()
    if loopActive then return end
    loopActive = true
    
    local processedPets = {} 
    setmetatable(processedPets, {__mode = "k"}) 

    while isScanning and not _G.PetScannerStop do
        local petSpawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
        if not petSpawns or #petSpawns:GetChildren() == 0 then
            updateStatus("⏳ Waiting for wild pets/map to load...", Color3.fromRGB(160, 160, 80))
            task.wait(3)
            continue 
        end

        refreshCurrentPets()
        
        local found = false
        local justBought = false
        
        local petsToBuy = {}
        local uniqueNamesToBuy = {}
        
        for _, pet in pairs(getPets()) do
            if isTargeted(pet) and not processedPets[pet.model] then
                table.insert(petsToBuy, pet)
                uniqueNamesToBuy[pet.name] = true
                found = true
            end
        end
        
        if #petsToBuy > 0 then
            local initialSpecificCount = countTargetPets(uniqueNamesToBuy)
            local successfulBuys = 0
            if waitForLoadingScreen() then
                for _, pet in ipairs(petsToBuy) do
                    processedPets[pet.model] = true 
                
                    updateStatus("⏳ BUYING: " .. pet.size .. " " .. pet.name, Color3.fromRGB(80, 220, 100))
                
                    if autoBuy(pet) then
                        successfulBuys = successfulBuys + 1
                    end
                    task.wait(1) 
                end
            end
            
            if successfulBuys > 0 then
                local targetCount = initialSpecificCount + successfulBuys
                updateStatus("⏳ WAITING FOR " .. successfulBuys .. " PET(S) TO APPEAR...", Color3.fromRGB(80, 220, 255))
                
                local startTime = os.time()
                local currentSpecificCount = 0
                
                repeat 
                    task.wait(0.3)
                    currentSpecificCount = countTargetPets(uniqueNamesToBuy)
                until (currentSpecificCount >= targetCount) or (os.time() - startTime >= MAX_WAIT_TIME)
                
                if currentSpecificCount >= targetCount then
                    updateStatus("✨ ALL PETS SECURED!", Color3.fromRGB(100, 255, 100))
                    sendWebhook(pet, true)
                    task.wait(1)
                else
                    updateStatus("⚠️ TIMEOUT: Some pets didn't arrive.", Color3.fromRGB(255, 100, 100))
                    task.wait(1)
                end
                
                justBought = true
            end
        end
        
        if not found and not justBought then
            if autoHop then
                updateStatus("✗ NOT FOUND — HOPPING SERVER...", Color3.fromRGB(255, 180, 50))
                hopServer()
                task.wait(8)
            else
                updateStatus("● SCANNING... NO TARGET PET YET", Color3.fromRGB(180, 120, 255))
            end
        end
        task.wait(2)
    end
    
    loopActive = false
    isScanning = false
    scanBtn.Text = "▶ SCAN"
    scanBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 140)
    scanBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(180, 120, 255)}):Play()
    updateStatus("● IDLE — Press SCAN to start", Color3.fromRGB(120, 120, 160))
end

-- =============================================================================
-- [ 8. WINDOW RIGGING CONTROLS ]
-- =============================================================================
exitBtn.MouseButton1Click:Connect(function()
    isScanning = false
    _G.PetScannerStop = true
    sg:Destroy()
end)

collapseBtn.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    bodyContent.Visible = not isCollapsed
    main.Size = isCollapsed and UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 42) or UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, math.max(main.Size.Y.Offset, MIN_HEIGHT))
    collapseBtn.Text = isCollapsed and "+" or "—"
end)

hopBtn.MouseButton1Click:Connect(function()
    autoHop = not autoHop
    hopBtn.Text = autoHop and "🔀 AUTO HOP: ON" or "🔀 AUTO HOP: OFF"
    hopBtn.BackgroundColor3 = autoHop and Color3.fromRGB(30, 80, 40) or Color3.fromRGB(40, 60, 100)
    hopBtn.TextColor3 = autoHop and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(160, 190, 255)
    saveConfig(checkedPets) -- Instantly saves unified settings file
end)

scanBtn.MouseButton1Click:Connect(function()
    isScanning = not isScanning
    scanBtn.Text = isScanning and "■ STOP" or "▶ SCAN"
    scanBtn.BackgroundColor3 = isScanning and Color3.fromRGB(100, 30, 30) or Color3.fromRGB(80, 50, 140)
    scanBtn.TextColor3 = isScanning and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(200, 180, 255)
    
    local targetColor = isScanning and Color3.fromRGB(80, 220, 100) or Color3.fromRGB(180, 120, 255)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), {Color = targetColor}):Play()
    
    saveConfig(checkedPets) -- Instantly saves unified settings file
    if isScanning then task.spawn(runScanningLoop) end
end)

do
    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    header.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

do
    local resizing, resizeStart, startSize
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then resizing = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            main.Size = UDim2.new(0, math.max(MIN_WIDTH, startSize.X + delta.X), 0, math.max(MIN_HEIGHT, startSize.Y + delta.Y))
        end
    end)
end

-- =============================================================================
-- [ 9. INITIALIZATION & BACKGROUND TASKS ]
-- =============================================================================
refreshCurrentPets()

-- Sync visual button states with loaded settings
hopBtn.Text = autoHop and "🔀 AUTO HOP: ON" or "🔀 AUTO HOP: OFF"
hopBtn.BackgroundColor3 = autoHop and Color3.fromRGB(30, 80, 40) or Color3.fromRGB(40, 60, 100)
hopBtn.TextColor3 = autoHop and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(160, 190, 255)

if autoStartScan then 
    isScanning = true
    scanBtn.Text = "■ STOP"
    scanBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
    scanBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(80, 220, 100)}):Play()
    task.spawn(runScanningLoop)
end

task.spawn(function()
    while sg.Parent and not _G.PetScannerStop do
        task.wait(3)
        if not isScanning then refreshCurrentPets() end
    end
end)

print("Pet Scanner unified settings loaded perfectly!")