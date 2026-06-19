print("Pet Scanner loaded")
if not game:IsLoaded() then game.Loaded:Wait() end

local Players        = game:GetService("Players")
local HttpService    = game:GetService("HttpService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mapFolder = workspace:WaitForChild("Map", 60)
if mapFolder then mapFolder:WaitForChild("WildPetSpawns", 60)
else warn("Pet Scanner: Map folder not found!") end

-- ═══════════════════════════════════════
-- STATE MANAGEMENT & GHOST LOOP PREVENTION
-- ═══════════════════════════════════════
-- Terminate any previously running instances of this script before starting
if _G.PetScannerStop ~= nil then
    _G.PetScannerStop = true
    task.wait(0.5) -- Give old loops time to break
end
_G.PetScannerStop = false

local isScanning  = false
local loopActive  = false
local hopCooldown = false

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════

local SAVE_FILE        = "PetScannerTargets.json"
-- ⚠️ SECURITY FIX: Removed hardcoded webhook. Paste yours here.
local WEBHOOK_URL      = "" 
local LOADER_URL       = "https://raw.githubusercontent.com/hanniii1/Loader/refs/heads/main/BFLoader.lua"
local HOP_URL          = "https://raw.githubusercontent.com/LeoKholYt/roblox/main/lk_serverhop.lua"
local MAX_WAIT_FOR_PET = 120

local ALL_PETS  = { "Frog","Bunny","Bee","Raccoon","Owl","Robin","Deer","Monkey","Unicorn","GoldenDragonfly","BlackDragon","IceSerpent" }
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
        for k, v in pairs(targets) do if v == true then table.insert(data, k) end end
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

local checkedPets = loadTargets()
if _G.PetScannerTargets then
    for k, v in pairs(_G.PetScannerTargets) do checkedPets[k] = v end
end

-- ═══════════════════════════════════════
-- CORE FUNCTIONS
-- ═══════════════════════════════════════

local function sendWebhook(msg)
    if WEBHOOK_URL == "" then return end
    pcall(function()
        local body   = HttpService:JSONEncode({ content = msg, username = "Pet Scanner" })
        local httpFn = request or http_request or (syn and syn.request)
        if httpFn then
            httpFn({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end
    end)
end

local function getPets()
    local petSpawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
    if not petSpawns then return {} end
    local pets = {}
    for _, pet in pairs(petSpawns:GetChildren()) do
        local buyPrompt  = pet:FindFirstChild("BuyPrompt", true)
        if not buyPrompt or not buyPrompt.Enabled then continue end
        local costLabel  = pet:FindFirstChild("PetCostTimer", true)
        local leaveLabel = pet:FindFirstChild("PetLeaveTimer", true)
        local cost  = costLabel  and costLabel:FindFirstChildWhichIsA("TextLabel")  and costLabel:FindFirstChildWhichIsA("TextLabel").Text  or "?"
        local leave = leaveLabel and leaveLabel:FindFirstChildWhichIsA("TextLabel") and leaveLabel:FindFirstChildWhichIsA("TextLabel").Text or "?"
        local fullName = pet.Name
        local species  = fullName:match("WildPet_(.-)_WildPet") or fullName
        local size = "Normal"
        if fullName:lower():find("huge") then size = "Huge"
        elseif fullName:lower():find("big") then size = "Big" end
        table.insert(pets, { name=species, size=size, key=species.."_"..size, cost=cost, leave=leave, prompt=buyPrompt, model=pet })
    end
    return pets
end

-- 🛠️ LOGIC FIX: Removed the "or Normal" override so specific sizes work correctly
local function isTargeted(pet)
    return checkedPets[pet.key] == true
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
-- GUI CLEANUP & MEMORY LEAK PREVENTION
-- ═══════════════════════════════════════

pcall(function()
    for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if v.Name == "PetScannerGUI" then v:Destroy() end
    end
    for _, v in pairs(playerGui:GetChildren()) do
        if v.Name == "PetScannerGUI" then v:Destroy() end
    end
end)

-- 🛠️ LEAK FIX: Disconnect old drag connections
if _G.PetScannerDragConn then
    _G.PetScannerDragConn:Disconnect()
    _G.PetScannerDragConn = nil
end

-- ═══════════════════════════════════════
-- GUI BUILD
-- ═══════════════════════════════════════

local sg = Instance.new("ScreenGui")
sg.Name = "PetScannerGUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = playerGui end

-- helpers
local function makeCorner(parent, radius)
    Instance.new("UICorner", parent).CornerRadius = UDim.new(0, radius or 10)
end
local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Color = color; s.Thickness = thickness or 1
    return s
end

-- ── MAIN FRAME ───────────────────────────────────────────────────────────────
local main = Instance.new("Frame")
main.Size             = UDim2.new(0.92, 0, 0.88, 0)
main.Position         = UDim2.new(0.04, 0, 0.06, 0)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
main.BorderSizePixel  = 0
main.ClipsDescendants = true
makeCorner(main, 14)
local mainStroke = makeStroke(main, Color3.fromRGB(160, 100, 255), 1.5)
main.Parent = sg

-- ── HEADER ───────────────────────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0.07, 0)
header.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
header.BorderSizePixel  = 0
makeCorner(header, 14)
header.Parent = main

local headerFix = Instance.new("Frame")
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
headerFix.BorderSizePixel  = 0
headerFix.Parent = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size           = UDim2.new(1, -80, 1, 0)
titleLbl.Position       = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text           = "🐾 PET SCANNER"
titleLbl.Font           = Enum.Font.GothamBlack
titleLbl.TextScaled     = true
titleLbl.TextColor3     = Color3.fromRGB(180, 120, 255)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent         = header

local exitBtn = Instance.new("TextButton")
exitBtn.Size             = UDim2.new(0, 36, 0, 36)
exitBtn.Position         = UDim2.new(1, -44, 0.5, -18)
exitBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
exitBtn.Text             = "✕"
exitBtn.Font             = Enum.Font.GothamBold
exitBtn.TextScaled       = true
exitBtn.TextColor3       = Color3.fromRGB(255, 200, 200)
exitBtn.BorderSizePixel  = 0
makeCorner(exitBtn, 8)
exitBtn.Parent = header

exitBtn.MouseButton1Click:Connect(function()
    isScanning = false
    _G.PetScannerStop = true
    if _G.PetScannerDragConn then
        _G.PetScannerDragConn:Disconnect()
        _G.PetScannerDragConn = nil
    end
    sg:Destroy()
end)

-- Drag (Updated to prevent memory leaks)
do
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
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
    _G.PetScannerDragConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ── STATUS BAR ───────────────────────────────────────────────────────────────
local statusBar = Instance.new("Frame")
statusBar.Size             = UDim2.new(1, -20, 0.06, 0)
statusBar.Position         = UDim2.new(0, 10, 0.07, 5)
statusBar.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
statusBar.BorderSizePixel  = 0
makeCorner(statusBar, 8)
statusBar.Parent = main

local statusLbl = Instance.new("TextLabel")
statusLbl.Size           = UDim2.new(1, -12, 1, 0)
statusLbl.Position       = UDim2.new(0, 10, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text           = "● IDLE — scanning will start shortly"
statusLbl.Font           = Enum.Font.GothamBold
statusLbl.TextScaled     = true
statusLbl.TextColor3     = Color3.fromRGB(120, 120, 160)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent         = statusBar

local function updateStatus(text, color)
    statusLbl.Text       = text
    statusLbl.TextColor3 = color or Color3.fromRGB(120, 120, 160)
end

-- ── BODY ─────────────────────────────────────────────────────────────────────
local bodyScroll = Instance.new("ScrollingFrame")
bodyScroll.Size             = UDim2.new(1, -20, 0.70, 0)
bodyScroll.Position         = UDim2.new(0, 10, 0.14, 5)
bodyScroll.BackgroundTransparency = 1
bodyScroll.BorderSizePixel  = 0
bodyScroll.ScrollBarThickness = 4
bodyScroll.ScrollBarImageTransparency = 0.4
bodyScroll.ScrollingDirection = Enum.ScrollingDirection.Y
bodyScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
bodyScroll.Parent = main

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding   = UDim.new(0, 8)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent    = bodyScroll

local bodyPad = Instance.new("UIPadding")
bodyPad.PaddingTop    = UDim.new(0, 6)
bodyPad.PaddingBottom = UDim.new(0, 6)
bodyPad.Parent        = bodyScroll

local function updateBodyCanvas()
    bodyScroll.CanvasSize = UDim2.new(0, 0, 0, bodyLayout.AbsoluteContentSize.Y + 12)
end
bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateBodyCanvas)

local function makeSection(title, color, startOpen)
    local HEADER_H = 40
    local section = Instance.new("Frame")
    section.Size             = UDim2.new(1, 0, 0, HEADER_H)
    section.BackgroundTransparency = 1
    section.BorderSizePixel  = 0
    section.ClipsDescendants = false
    section.Parent           = bodyScroll

    local bar = Instance.new("TextButton")
    bar.Size             = UDim2.new(1, 0, 0, HEADER_H)
    bar.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
    bar.BorderSizePixel  = 0
    bar.Text             = ""
    makeCorner(bar, 10)
    makeStroke(bar, color or Color3.fromRGB(100, 80, 160), 1)
    bar.Parent = section

    local barLabel = Instance.new("TextLabel")
    barLabel.Size           = UDim2.new(1, -50, 1, 0)
    barLabel.Position       = UDim2.new(0, 12, 0, 0)
    barLabel.BackgroundTransparency = 1
    barLabel.Text           = title
    barLabel.Font           = Enum.Font.GothamBlack
    barLabel.TextScaled     = true
    barLabel.TextColor3     = color or Color3.fromRGB(180, 120, 255)
    barLabel.TextXAlignment = Enum.TextXAlignment.Left
    barLabel.Parent         = bar

    local arrow = Instance.new("TextLabel")
    arrow.Size           = UDim2.new(0, 30, 1, 0)
    arrow.Position       = UDim2.new(1, -38, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Font           = Enum.Font.GothamBold
    arrow.TextScaled     = true
    arrow.TextColor3     = color or Color3.fromRGB(180, 120, 255)
    arrow.Text           = startOpen and "▲" or "▼"
    arrow.Parent         = bar

    local content = Instance.new("Frame")
    content.Size             = UDim2.new(1, 0, 0, 0)
    content.Position         = UDim2.new(0, 0, 0, HEADER_H + 4)
    content.BackgroundTransparency = 1
    content.BorderSizePixel  = 0
    content.ClipsDescendants = false
    content.Visible          = startOpen
    content.Parent           = section

    local isOpen = startOpen

    local function setOpen(open)
        isOpen = open
        content.Visible = open
        arrow.Text = open and "▲" or "▼"
        local contentH = open and content.AbsoluteSize.Y or 0
        section.Size = UDim2.new(1, 0, 0, HEADER_H + (open and contentH + 4 or 0))
        updateBodyCanvas()
    end

    bar.MouseButton1Click:Connect(function() setOpen(not isOpen) end)

    return section, content, setOpen
end

-- ════════════════════════════════════════════════════════
-- SECTION 1: TARGET PETS
-- ════════════════════════════════════════════════════════

local targSection, targContent, setTargOpen = makeSection("🎯  TARGET PETS  (tap to toggle)", Color3.fromRGB(160, 100, 255), false)

local targScroll = Instance.new("ScrollingFrame")
targScroll.Size             = UDim2.new(1, 0, 0, 260)
targScroll.BackgroundColor3 = Color3.fromRGB(14, 10, 22)
targScroll.BackgroundTransparency = 0.2
targScroll.BorderSizePixel  = 0
targScroll.ScrollBarThickness = 4
targScroll.ScrollBarImageTransparency = 0.4
targScroll.ScrollingDirection = Enum.ScrollingDirection.Y
targScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
makeCorner(targScroll, 8)
targScroll.Parent = targContent

local targLayout = Instance.new("UIListLayout")
targLayout.Padding   = UDim.new(0, 5)
targLayout.SortOrder = Enum.SortOrder.LayoutOrder
targLayout.Parent    = targScroll

local targPad = Instance.new("UIPadding")
targPad.PaddingTop = UDim.new(0,6); targPad.PaddingBottom = UDim.new(0,6)
targPad.PaddingLeft = UDim.new(0,6); targPad.PaddingRight = UDim.new(0,6)
targPad.Parent = targScroll

targLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    targScroll.CanvasSize = UDim2.new(0, 0, 0, targLayout.AbsoluteContentSize.Y + 12)
end)

for _, petName in ipairs(ALL_PETS) do
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 58)
    row.BackgroundColor3 = Color3.fromRGB(22, 16, 36)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel  = 0
    makeCorner(row, 8)
    row.Parent = targScroll

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size           = UDim2.new(1, -16, 0, 22)
    nameLbl.Position       = UDim2.new(0, 10, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text           = petName
    nameLbl.Font           = Enum.Font.GothamBold
    nameLbl.TextScaled     = true
    nameLbl.TextColor3     = Color3.fromRGB(220, 210, 255)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent         = row

    local sizeCon = Instance.new("Frame")
    sizeCon.Size             = UDim2.new(1, -16, 0, 26)
    sizeCon.Position         = UDim2.new(0, 8, 0, 28)
    sizeCon.BackgroundTransparency = 1
    sizeCon.Parent           = row

    local sizeLayout = Instance.new("UIListLayout")
    sizeLayout.FillDirection = Enum.FillDirection.Horizontal
    sizeLayout.Padding       = UDim.new(0, 6)
    sizeLayout.Parent        = sizeCon

    for _, size in ipairs(ALL_SIZES) do
        local key = petName .. "_" .. size
        local on  = checkedPets[key] == true

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0.31, -4, 1, 0)
        btn.BackgroundColor3 = on and Color3.fromRGB(70, 40, 130) or Color3.fromRGB(28, 20, 45)
        btn.BackgroundTransparency = on and 0.1 or 0.4
        btn.Text             = (on and "✓ " or "") .. size
        btn.Font             = Enum.Font.GothamBold
        btn.TextScaled       = true
        btn.TextColor3       = on and SIZE_COLORS[size] or Color3.fromRGB(90, 80, 120)
        btn.BorderSizePixel  = 0
        makeCorner(btn, 6)
        local stroke = makeStroke(btn, on and Color3.fromRGB(160,100,255) or Color3.fromRGB(50,40,70))
        btn.Parent = sizeCon

        btn.MouseButton1Click:Connect(function()
            checkedPets[key] = not (checkedPets[key] == true)
            saveTargets(checkedPets)
            local isOn = checkedPets[key]
            btn.BackgroundColor3       = isOn and Color3.fromRGB(70,40,130) or Color3.fromRGB(28,20,45)
            btn.BackgroundTransparency = isOn and 0.1 or 0.4
            btn.Text                   = (isOn and "✓ " or "") .. size
            btn.TextColor3             = isOn and SIZE_COLORS[size] or Color3.fromRGB(90,80,120)
            stroke.Color               = isOn and Color3.fromRGB(160,100,255) or Color3.fromRGB(50,40,70)
        end)
    end
end

targContent.Size = UDim2.new(1, 0, 0, 264)
targSection.Size = UDim2.new(1, 0, 0, 40)

-- ════════════════════════════════════════════════════════
-- SECTION 2: WILD PETS IN SERVER
-- ════════════════════════════════════════════════════════

local wildSection, wildContent, setWildOpen = makeSection("🌿  WILD PETS IN SERVER", Color3.fromRGB(80, 200, 120), true)

local wildScroll = Instance.new("ScrollingFrame")
wildScroll.Size             = UDim2.new(1, 0, 0, 220)
wildScroll.BackgroundColor3 = Color3.fromRGB(10, 18, 14)
wildScroll.BackgroundTransparency = 0.2
wildScroll.BorderSizePixel  = 0
wildScroll.ScrollBarThickness = 4
wildScroll.ScrollBarImageTransparency = 0.4
wildScroll.ScrollingDirection = Enum.ScrollingDirection.Y
wildScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
makeCorner(wildScroll, 8)
wildScroll.Parent = wildContent

local wildLayout = Instance.new("UIListLayout")
wildLayout.Padding   = UDim.new(0, 4)
wildLayout.SortOrder = Enum.SortOrder.LayoutOrder
wildLayout.Parent    = wildScroll

local wildPad = Instance.new("UIPadding")
wildPad.PaddingTop = UDim.new(0,6); wildPad.PaddingBottom = UDim.new(0,6)
wildPad.PaddingLeft = UDim.new(0,6); wildPad.PaddingRight = UDim.new(0,6)
wildPad.Parent = wildScroll

wildLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    wildScroll.CanvasSize = UDim2.new(0, 0, 0, wildLayout.AbsoluteContentSize.Y + 12)
end)

wildContent.Size = UDim2.new(1, 0, 0, 224)
wildSection.Size = UDim2.new(1, 0, 0, 40 + 224 + 4)

local function refreshWildPets()
    for _, v in pairs(wildScroll:GetChildren()) do
        if v:IsA("Frame") or v:IsA("TextLabel") then v:Destroy() end
    end

    local pets = getPets()

    if #pets == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size           = UDim2.new(1, 0, 0, 34)
        empty.BackgroundTransparency = 1
        empty.Text           = "No wild pets in this server"
        empty.Font           = Enum.Font.GothamBold
        empty.TextScaled     = true
        empty.TextColor3     = Color3.fromRGB(80, 100, 80)
        empty.Parent         = wildScroll
        return
    end

    for _, pet in pairs(pets) do
        local isTarget = isTargeted(pet)

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 44)
        row.BackgroundColor3 = isTarget and Color3.fromRGB(20, 50, 25) or Color3.fromRGB(16, 22, 16)
        row.BackgroundTransparency = 0.2
        row.BorderSizePixel  = 0
        makeCorner(row, 7)
        if isTarget then makeStroke(row, Color3.fromRGB(80, 220, 100), 1) end
        row.Parent = wildScroll

        local badge = Instance.new("Frame")
        badge.Size             = UDim2.new(0, 52, 0, 24)
        badge.Position         = UDim2.new(0, 8, 0.5, -12)
        badge.BackgroundColor3 = pet.size == "Huge" and Color3.fromRGB(80, 50, 10)
                               or pet.size == "Big"  and Color3.fromRGB(10, 40, 80)
                               or Color3.fromRGB(30, 28, 50)
        badge.BorderSizePixel  = 0
        makeCorner(badge, 5)
        badge.Parent = row

        local badgeLbl = Instance.new("TextLabel")
        badgeLbl.Size           = UDim2.new(1, 0, 1, 0)
        badgeLbl.BackgroundTransparency = 1
        badgeLbl.Text           = pet.size
        badgeLbl.Font           = Enum.Font.GothamBold
        badgeLbl.TextScaled     = true
        badgeLbl.TextColor3     = SIZE_COLORS[pet.size]
        badgeLbl.Parent         = badge

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size           = UDim2.new(0.45, 0, 1, -4)
        nameLbl.Position       = UDim2.new(0, 68, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text           = (isTarget and "★ " or "") .. pet.name
        nameLbl.Font           = Enum.Font.GothamBold
        nameLbl.TextScaled     = true
        nameLbl.TextColor3     = isTarget and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(200, 200, 220)
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent         = row

        local infoLbl = Instance.new("TextLabel")
        infoLbl.Size           = UDim2.new(0.32, 0, 1, -4)
        infoLbl.Position       = UDim2.new(0.68, 0, 0, 2)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text           = "💰" .. pet.cost .. "  ⏱" .. pet.leave
        infoLbl.Font           = Enum.Font.Gotham
        infoLbl.TextScaled     = true
        infoLbl.TextColor3     = Color3.fromRGB(140, 160, 140)
        infoLbl.TextXAlignment = Enum.TextXAlignment.Right
        infoLbl.Parent         = row
    end
end

-- ── SCAN BUTTON ──────────────────────────────────────────────────────────────
local scanBtn = Instance.new("TextButton")
scanBtn.Size             = UDim2.new(1, -20, 0.08, 0)
scanBtn.Position         = UDim2.new(0, 10, 0.91, 0)
scanBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 130)
scanBtn.Text             = "▶  START SCANNING"
scanBtn.Font             = Enum.Font.GothamBold
scanBtn.TextScaled       = true
scanBtn.TextColor3       = Color3.fromRGB(200, 170, 255)
scanBtn.BorderSizePixel  = 0
makeCorner(scanBtn, 10)
scanBtn.Parent = main

-- ═══════════════════════════════════════
-- SCAN LOOP
-- ═══════════════════════════════════════

local function runLoop()
    if loopActive then return end
    loopActive = true

    while isScanning and not _G.PetScannerStop do
        local petSpawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
        if petSpawns then
            while petSpawns and #petSpawns:GetChildren() == 0 and isScanning and not _G.PetScannerStop do
                updateStatus("⏳ Waiting for wild pets to spawn...", Color3.fromRGB(160, 160, 80))
                task.wait(3)
            end
        end

        refreshWildPets()

        local pets    = getPets()
        local targets = {}
        for _, pet in pairs(pets) do
            if isTargeted(pet) then table.insert(targets, pet) end
        end

        if #targets > 0 then
            for _, pet in ipairs(targets) do
                updateStatus("🐾 FOUND: " .. pet.size .. " " .. pet.name .. " — executing loader...", Color3.fromRGB(80, 220, 100))
                sendWebhook("@everyone\n🐾 **FOUND: " .. pet.size .. " " .. pet.name .. "**\nCost: `" .. pet.cost .. "`\nExecuting loader...")

                pcall(function() loadstring(game:HttpGet(LOADER_URL))() end)

                updateStatus("⏳ Waiting for " .. pet.name .. " to arrive...", Color3.fromRGB(80, 200, 255))
                local startTime    = os.clock()
                local initialCount = countPetInBackpack(pet.name)

                repeat task.wait(0.5)
                until countPetInBackpack(pet.name) > initialCount or os.clock() - startTime > MAX_WAIT_FOR_PET

                if countPetInBackpack(pet.name) > initialCount then
                    updateStatus("✅ Got " .. pet.name .. "! Hopping server...", Color3.fromRGB(100, 255, 120))
                    sendWebhook("@everyone\n✅ **BOUGHT: " .. pet.size .. " " .. pet.name .. "**\nHopping to next server...")
                else
                    updateStatus("⚠️ Timed out on " .. pet.name .. ". Hopping anyway...", Color3.fromRGB(255, 120, 80))
                    sendWebhook("⚠️ **TIMEOUT** on " .. pet.size .. " " .. pet.name .. ". Hopping...")
                end

                task.wait(1)
                hopServer()
                task.wait(10)
            end
        else
            updateStatus("✗ No targets — hopping to small server...", Color3.fromRGB(255, 170, 50))
            hopServer()
            task.wait(10)
        end

        task.wait(2)
    end

    loopActive = false
    isScanning = false
    -- Reset UI once the loop completely exits
    scanBtn.Text             = "▶  START SCANNING"
    scanBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 130)
    scanBtn.TextColor3       = Color3.fromRGB(200, 170, 255)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(160, 100, 255) }):Play()
    updateStatus("● IDLE — Press SCAN to start")
end

-- 🛠️ UX FIX: Reset scan button visuals immediately upon clicking Stop
scanBtn.MouseButton1Click:Connect(function()
    isScanning = not isScanning
    if isScanning then
        scanBtn.Text             = "■  STOP"
        scanBtn.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
        scanBtn.TextColor3       = Color3.fromRGB(255, 150, 150)
        TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(80, 220, 100) }):Play()
        task.spawn(runLoop)
    else
        -- Instant UI feedback for stopping
        scanBtn.Text             = "▶  START SCANNING"
        scanBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 130)
        scanBtn.TextColor3       = Color3.fromRGB(200, 170, 255)
        updateStatus("⏹ Stopping after current cycle...", Color3.fromRGB(200, 150, 255))
        TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(160, 100, 255) }):Play()
    end
end)

task.spawn(function()
    while sg.Parent and not _G.PetScannerStop do
        task.wait(4)
        if not isScanning then refreshWildPets() end
    end
end)

-- 🛠️ LOGIC FIX: Auto-scan correctly respects server hop states
task.wait(1)
refreshWildPets()

isScanning = _G.PetScannerAutoScan == true 
_G.PetScannerAutoScan = false -- Reset for future manual executions

if isScanning then
    scanBtn.Text             = "■  STOP"
    scanBtn.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
    scanBtn.TextColor3       = Color3.fromRGB(255, 150, 150)
    TweenService:Create(mainStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(80, 220, 100) }):Play()
    task.spawn(runLoop)
end

print("Pet Scanner ready!")