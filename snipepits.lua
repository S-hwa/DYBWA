print("Pet Scanner loaded")
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for map
local mapFolder = workspace:WaitForChild("Map", 60)
if mapFolder then
    mapFolder:WaitForChild("WildPetSpawns", 60)
else
    warn("Pet Scanner: Map folder not found!")
end

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════

local SAVE_FILE = "PetScannerTargets.json"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1407730984098467881/MpC-8-F6OKWa4oNF4EeOq9bChlZ7HKVNY-TnabLqX_7oYyD_ToO1ghR_wW2jdrWrtApV"
local LOADER_URL = "https://raw.githubusercontent.com/hanniii1/Loader/refs/heads/main/BFLoader.lua"
local HOP_URL = "https://raw.githubusercontent.com/LeoKholYt/roblox/main/lk_serverhop.lua"
local MAX_WAIT_FOR_PET = 120

local ALL_PETS = {
    "Frog", "Bunny", "Bee", "Raccoon", "Owl", "Robin", "Deer",
    "Monkey", "Unicorn", "GoldenDragonfly", "BlackDragon", "IceSerpent"
}
local ALL_SIZES = { "Normal", "Big", "Huge" }
local SIZE_COLORS = {
    Normal = Color3.fromRGB(180, 180, 220),
    Big    = Color3.fromRGB(100, 180, 255),
    Huge   = Color3.fromRGB(255, 160, 60),
}

-- ═══════════════════════════════════════
-- SAVE / LOAD
-- ═══════════════════════════════════════

local function saveTargets(targets)
    pcall(function()
        local data = {}
        for k, v in pairs(targets) do
            if v == true then table.insert(data, k) end
        end
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadTargets()
    local result = {}
    pcall(function()
        if isfile(SAVE_FILE) then
            local data = HttpService:JSONDecode(readfile(SAVE_FILE))
            for _, k in pairs(data) do result[k] = true end
        end
    end)
    return result
end

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════

_G.PetScannerStop = false
local checkedPets = loadTargets()
if _G.PetScannerTargets then
    for k, v in pairs(_G.PetScannerTargets) do checkedPets[k] = v end
end

local isScanning = false
local loopActive = false
local hopCooldown = false

-- ═══════════════════════════════════════
-- CORE FUNCTIONS
-- ═══════════════════════════════════════

local function sendWebhook(msg)
    if WEBHOOK_URL == "" then return end
    pcall(function()
        local body = HttpService:JSONEncode({ content = msg, username = "Pet Scanner" })
        local httpFn = request or http_request or (syn and syn.request)
        if httpFn then
            httpFn({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end
    end)
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
        local cost  = costLabel  and costLabel:FindFirstChildWhichIsA("TextLabel")  and costLabel:FindFirstChildWhichIsA("TextLabel").Text  or "?"
        local leave = leaveLabel and leaveLabel:FindFirstChildWhichIsA("TextLabel") and leaveLabel:FindFirstChildWhichIsA("TextLabel").Text or "?"
        local fullName = pet.Name
        local species = fullName:match("WildPet_(.-)_WildPet") or fullName
        local size = "Normal"
        if fullName:lower():find("huge") then size = "Huge"
        elseif fullName:lower():find("big") then size = "Big" end
        table.insert(pets, {
            name   = species,
            size   = size,
            key    = species .. "_" .. size,
            cost   = cost,
            leave  = leave,
            prompt = buyPrompt,
            model  = pet,
        })
    end
    return pets
end

local function isTargeted(pet)
    return checkedPets[pet.key] == true or checkedPets[pet.name .. "_Normal"] == true
end

local function countPetInBackpack(petName)
    local count = 0
    local function scan(folder)
        if not folder then return end
        for _, item in pairs(folder:GetChildren()) do
            local species = item.Name:match("WildPet_(.-)_WildPet") or item.Name
            if species == petName or item.Name == petName then count += 1 end
        end
    end
    pcall(scan, player.Backpack)
    pcall(scan, player.Character)
    return count
end

local function hopServer()
    if hopCooldown then return end
    hopCooldown = true
    _G.PetScannerTargets = checkedPets
    _G.PetScannerAutoScan = true
    pcall(function()
        local module = loadstring(game:HttpGet(HOP_URL))()
        module:Teleport(game.PlaceId)
    end)
    task.wait(10)
    hopCooldown = false
end

-- ═══════════════════════════════════════
-- GUI CLEANUP
-- ═══════════════════════════════════════

pcall(function()
    for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if v.Name == "PetScannerGUI" then v:Destroy() end
    end
    for _, v in pairs(playerGui:GetChildren()) do
        if v.Name == "PetScannerGUI" then v:Destroy() end
    end
end)

-- ═══════════════════════════════════════
-- GUI BUILD
-- ═══════════════════════════════════════

local sg = Instance.new("ScreenGui")
sg.Name = "PetScannerGUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = playerGui end

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 500)
main.Position = UDim2.new(0.5, -240, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
main.BorderSizePixel = 0
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = Color3.fromRGB(160, 100, 255)
mainStroke.Thickness = 1.5
main.Parent = sg

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
header.Parent = main

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🐾 PET SCANNER"
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 13
titleLbl.TextColor3 = Color3.fromRGB(180, 120, 255)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = header

local exitBtn = Instance.new("TextButton")
exitBtn.Size = UDim2.new(0, 26, 0, 26)
exitBtn.Position = UDim2.new(1, -32, 0.5, -13)
exitBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
exitBtn.Text = "✕"
exitBtn.Font = Enum.Font.GothamBold
exitBtn.TextSize = 12
exitBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
exitBtn.BorderSizePixel = 0
Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0, 6)
exitBtn.Parent = header

exitBtn.MouseButton1Click:Connect(function()
    isScanning = false
    _G.PetScannerStop = true
    sg:Destroy()
end)

-- Drag
do
    local dragging, dragInput, dragStart, startPos = false
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Status bar
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -20, 0, 26)
statusBar.Position = UDim2.new(0, 10, 0, 46)
statusBar.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
statusBar.BorderSizePixel = 0
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 8)
statusBar.Parent = main

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -10, 1, 0)
statusLbl.Position = UDim2.new(0, 10, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "● IDLE — Press SCAN to start"
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 10
statusLbl.TextColor3 = Color3.fromRGB(120, 120, 160)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = statusBar

local function updateStatus(text, color)
    statusLbl.Text = text
    statusLbl.TextColor3 = color or Color3.fromRGB(120, 120, 160)
end

-- Section label
local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, -20, 0, 16)
targetLabel.Position = UDim2.new(0, 10, 0, 78)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "TARGET PETS  (tap to toggle)"
targetLabel.Font = Enum.Font.GothamBlack
targetLabel.TextSize = 9
targetLabel.TextColor3 = Color3.fromRGB(180, 120, 255)
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = main

-- Scrolling pet list
local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, -20, 1, -170)
petScroll.Position = UDim2.new(0, 10, 0, 96)
petScroll.BackgroundColor3 = Color3.fromRGB(14, 10, 22)
petScroll.BackgroundTransparency = 0.2
petScroll.BorderSizePixel = 0
petScroll.ScrollBarThickness = 3
petScroll.ScrollBarImageTransparency = 0.5
petScroll.ScrollingDirection = Enum.ScrollingDirection.Y
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", petScroll).CornerRadius = UDim.new(0, 8)
petScroll.Parent = main

local petScrollLayout = Instance.new("UIListLayout")
petScrollLayout.Padding = UDim.new(0, 4)
petScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
petScrollLayout.Parent = petScroll

local petScrollPad = Instance.new("UIPadding")
petScrollPad.PaddingTop = UDim.new(0, 6)
petScrollPad.PaddingBottom = UDim.new(0, 6)
petScrollPad.PaddingLeft = UDim.new(0, 6)
petScrollPad.PaddingRight = UDim.new(0, 6)
petScrollPad.Parent = petScroll

-- Build pet rows
for _, petName in ipairs(ALL_PETS) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 50)
    row.BackgroundColor3 = Color3.fromRGB(22, 16, 36)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    row.Parent = petScroll

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.38, 0, 0, 20)
    nameLbl.Position = UDim2.new(0, 8, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = petName
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = Color3.fromRGB(220, 210, 255)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = row

    local sizeContainer = Instance.new("Frame")
    sizeContainer.Size = UDim2.new(1, -16, 0, 20)
    sizeContainer.Position = UDim2.new(0, 8, 0, 26)
    sizeContainer.BackgroundTransparency = 1
    sizeContainer.Parent = row

    local sizeLayout = Instance.new("UIListLayout")
    sizeLayout.FillDirection = Enum.FillDirection.Horizontal
    sizeLayout.Padding = UDim.new(0, 6)
    sizeLayout.Parent = sizeContainer

    for _, size in ipairs(ALL_SIZES) do
        local key = petName .. "_" .. size
        local on = checkedPets[key] == true

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 86, 1, 0)
        btn.BackgroundColor3 = on and Color3.fromRGB(70, 40, 130) or Color3.fromRGB(28, 20, 45)
        btn.BackgroundTransparency = on and 0.1 or 0.4
        btn.Text = (on and "✓ " or "") .. size
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.TextColor3 = on and SIZE_COLORS[size] or Color3.fromRGB(90, 80, 120)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = on and Color3.fromRGB(160, 100, 255) or Color3.fromRGB(50, 40, 70)
        stroke.Thickness = 1
        btn.Parent = sizeContainer

        btn.MouseButton1Click:Connect(function()
            checkedPets[key] = not (checkedPets[key] == true)
            saveTargets(checkedPets)
            local isOn = checkedPets[key]
            btn.BackgroundColor3 = isOn and Color3.fromRGB(70, 40, 130) or Color3.fromRGB(28, 20, 45)
            btn.BackgroundTransparency = isOn and 0.1 or 0.4
            btn.Text = (isOn and "✓ " or "") .. size
            btn.TextColor3 = isOn and SIZE_COLORS[size] or Color3.fromRGB(90, 80, 120)
            stroke.Color = isOn and Color3.fromRGB(160, 100, 255) or Color3.fromRGB(50, 40, 70)
        end)
    end
end

petScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    petScroll.CanvasSize = UDim2.new(0, 0, 0, petScrollLayout.AbsoluteContentSize.Y + 12)
end)

-- Bottom button row
local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1, -20, 0, 36)
btnRow.Position = UDim2.new(0, 10, 1, -46)
btnRow.BackgroundTransparency = 1
btnRow.Parent = main

local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1, 0, 1, 0)
scanBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 130)
scanBtn.BackgroundTransparency = 0.1
scanBtn.Text = "▶  START SCANNING"
scanBtn.Font = Enum.Font.GothamBold
scanBtn.TextSize = 12
scanBtn.TextColor3 = Color3.fromRGB(200, 170, 255)
scanBtn.BorderSizePixel = 0
Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 9)
scanBtn.Parent = btnRow

-- ═══════════════════════════════════════
-- SCAN LOOP
-- ═══════════════════════════════════════

local function runLoop()
    if loopActive then return end
    loopActive = true

    while isScanning and not _G.PetScannerStop do
        local pets = getPets()

        -- Find targeted pets in this server
        local targets = {}
        for _, pet in pairs(pets) do
            if isTargeted(pet) then
                table.insert(targets, pet)
            end
        end

        if #targets > 0 then
            -- ── PETS FOUND ──
            for _, pet in ipairs(targets) do
                updateStatus("🐾 FOUND: " .. pet.size .. " " .. pet.name .. " — Loading game...", Color3.fromRGB(80, 220, 100))
                sendWebhook("@everyone\n🐾 **FOUND: " .. pet.size .. " " .. pet.name .. "**\nCost: `" .. pet.cost .. "`\nExecuting loader...")

                -- Execute the loader
                pcall(function()
                    loadstring(game:HttpGet(LOADER_URL))()
                end)

                -- Wait until pet appears in backpack/character
                updateStatus("⏳ WAITING FOR " .. pet.name .. " TO ARRIVE...", Color3.fromRGB(80, 200, 255))
                local startTime = os.clock()
                local initialCount = countPetInBackpack(pet.name)

                repeat
                    task.wait(0.5)
                until countPetInBackpack(pet.name) > initialCount or os.clock() - startTime > MAX_WAIT_FOR_PET

                if countPetInBackpack(pet.name) > initialCount then
                    updateStatus("✅ GOT " .. pet.name .. "! Sending webhook & hopping...", Color3.fromRGB(100, 255, 120))
                    sendWebhook("@everyone\n✅ **BOUGHT: " .. pet.size .. " " .. pet.name .. "**\nHopping to next server...")
                else
                    updateStatus("⚠️ Timed out waiting for " .. pet.name .. ". Hopping anyway...", Color3.fromRGB(255, 120, 80))
                    sendWebhook("⚠️ **TIMEOUT** waiting for " .. pet.size .. " " .. pet.name .. " to arrive. Hopping...")
                end

                task.wait(1)
                hopServer()
                task.wait(10)
            end
        else
            -- ── NO PETS FOUND — hop to a small server ──
            updateStatus("✗ No targets found — hopping to small server...", Color3.fromRGB(255, 170, 50))
            hopServer()
            task.wait(10)
        end

        task.wait(2)
    end

    loopActive = false
    isScanning = false
    scanBtn.Text = "▶  START SCANNING"
    scanBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 130)
    scanBtn.TextColor3 = Color3.fromRGB(200, 170, 255)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(160, 100, 255) }):Play()
    updateStatus("● IDLE — Press SCAN to start")
end

scanBtn.MouseButton1Click:Connect(function()
    isScanning = not isScanning
    if isScanning then
        scanBtn.Text = "■  STOP"
        scanBtn.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
        scanBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
        TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(80, 220, 100) }):Play()
        task.spawn(runLoop)
    else
        updateStatus("⏹ Stopping after current cycle...", Color3.fromRGB(200, 150, 255))
        TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(160, 100, 255) }):Play()
    end
end)

-- Auto start if flagged
task.wait(1)
if _G.PetScannerAutoScan then
    _G.PetScannerAutoScan = false
    isScanning = true
    scanBtn.Text = "■  STOP"
    scanBtn.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
    scanBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(80, 220, 100) }):Play()
    task.spawn(runLoop)
end

print("Pet Scanner ready!")
