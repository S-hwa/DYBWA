-- Grow a Garden Auto Script
-- Auto Harvest + Auto Sell GUI (with inventory full detection)

-- Kill any running loops from previous execution
_G.GardenAutoStop = true
task.wait(0.3)
_G.GardenAutoStop = false

-- Cleanup any existing GUI instances
local CoreGui = game:GetService("CoreGui")
pcall(function()
    for _, v in pairs(CoreGui:GetChildren()) do
        if v.Name == "GardenAutoGUI" then v:Destroy() end
    end
end)
pcall(function()
    for _, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do
        if v.Name == "GardenAutoGUI" then v:Destroy() end
    end
end)
task.wait(0.1)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local playerGui = player.PlayerGui
local gardens = workspace:WaitForChild("Gardens")
local npcs = workspace:WaitForChild("NPCS")
local steven = npcs:WaitForChild("Steven")
local stevenHRP = steven:WaitForChild("HumanoidRootPart")
local stevenPrompt = stevenHRP:WaitForChild("ProximityPrompt")

-- State
local autoHarvestEnabled = false
local autoSellEnabled = false
local autoSellFullEnabled = false
local harvestCount = 0
local sellCount = 0

-- ═══════════════════════════════════════
-- CORE FUNCTIONS
-- ═══════════════════════════════════════

local function getInventoryCount()
    local backpackGui = playerGui:FindFirstChild("BackpackGui")
    if not backpackGui then return 0, 100 end
    local fruitLbl = backpackGui:FindFirstChild("FruitInventory", true)
    if not fruitLbl then return 0, 100 end
    local cur, max = fruitLbl.Text:match("(%d+)/(%d+)")
    return tonumber(cur) or 0, tonumber(max) or 100
end

local function isInventoryFull()
    local cur, max = getInventoryCount()
    return cur >= max
end

local function getMyPlot()
    local closestPlot, closestDist = nil, math.huge
    for _, plot in pairs(gardens:GetChildren()) do
        local plotPart = plot:FindFirstChildWhichIsA("BasePart", true)
        if plotPart then
            local dist = (plotPart.Position - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPlot = plot
            end
        end
    end
    return closestPlot
end

local function waitForSellButton()
    local billboard = playerGui:WaitForChild("Billboard_UI", 5)
    if not billboard then return nil end
    local timeout = 0
    while timeout < 3 do
        for _, option in pairs(billboard.Objects:GetChildren()) do
            if option.Name == "Option_UI" then
                for _, lbl in pairs(option:GetDescendants()) do
                    if lbl:IsA("TextLabel") and lbl.Name == "Text_Element" then
                        if lbl.Text:find("Sell Inventory") then
                            return option.Frame.ImageButton
                        end
                    end
                end
            end
        end
        task.wait(0.1)
        timeout += 0.1
    end
    return nil
end

local function doHarvest()
    local myPlot = getMyPlot()
    if not myPlot then return 0 end
    local count = 0
    for _, v in pairs(myPlot:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Name == "HarvestPrompt" then
            fireproximityprompt(v)
            count += 1
            task.wait(0.1)
        end
    end
    return count
end

local isSelling = false
local function doSell()
    if isSelling then return false end
    isSelling = true
    local returnPos = hrp.CFrame
    hrp.CFrame = CFrame.new(stevenHRP.Position + Vector3.new(0, 0, 4))
    task.wait(0.5)
    stevenPrompt.MaxActivationDistance = 9999
    fireproximityprompt(stevenPrompt)
    task.wait(1)
    local sellBtn = waitForSellButton()
    if sellBtn then
        firesignal(sellBtn.MouseButton1Click)
        task.wait(2)
        hrp.CFrame = returnPos
        isSelling = false
        return true
    end
    hrp.CFrame = returnPos
    isSelling = false
    return false
end

-- ═══════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════

local old = playerGui:FindFirstChild("GardenAutoGUI")
if old then old:Destroy() end
local oldCG = game:GetService("CoreGui"):FindFirstChild("GardenAutoGUI")
if oldCG then oldCG:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "GardenAutoGUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() sg.Parent = game:GetService("CoreGui") end)
if not sg.Parent then sg.Parent = playerGui end

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 240, 0, 330)
main.Position = UDim2.new(0, 16, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
main.BackgroundTransparency = 0.08
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = Color3.fromRGB(60, 180, 80)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.3

local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
header.BackgroundTransparency = 0.1
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)
local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 14)
headerFix.Position = UDim2.new(0, 0, 1, -14)
headerFix.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
headerFix.BackgroundTransparency = 0.1
headerFix.BorderSizePixel = 0

local dot = Instance.new("Frame", header)
dot.Size = UDim2.new(0, 10, 0, 10)
dot.Position = UDim2.new(0, 14, 0.5, -5)
dot.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
dot.BorderSizePixel = 0
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local titleLbl = Instance.new("TextLabel", header)
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 30, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "GARDEN AUTO"
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 13
titleLbl.TextColor3 = Color3.fromRGB(80, 220, 100)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local exitBtn = Instance.new("TextButton", header)
exitBtn.Size = UDim2.new(0, 28, 0, 28)
exitBtn.Position = UDim2.new(1, -36, 0.5, -14)
exitBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
exitBtn.BackgroundTransparency = 0.2
exitBtn.Text = "✕"
exitBtn.Font = Enum.Font.GothamBold
exitBtn.TextSize = 13
exitBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
exitBtn.BorderSizePixel = 0
Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0, 6)
exitBtn.MouseButton1Click:Connect(function()
    autoHarvestEnabled = false
    autoSellEnabled = false
    autoSellFullEnabled = false
    sg:Destroy()
end)

do
    local down, ds, sp
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            down = true; ds = i.Position; sp = main.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then down = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not down then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - ds
            main.Position = UDim2.new(0, sp.X.Offset + d.X, 0, sp.Y.Offset + d.Y)
        end
    end)
end

local div = Instance.new("Frame", main)
div.Size = UDim2.new(1, -24, 0, 1)
div.Position = UDim2.new(0, 12, 0, 44)
div.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
div.BackgroundTransparency = 0.6
div.BorderSizePixel = 0

local body = Instance.new("Frame", main)
body.Size = UDim2.new(1, -20, 1, -55)
body.Position = UDim2.new(0, 10, 0, 52)
body.BackgroundTransparency = 1
local bodyList = Instance.new("UIListLayout", body)
bodyList.Padding = UDim.new(0, 7)
bodyList.SortOrder = Enum.SortOrder.LayoutOrder

local function makeToggleRow(parent, label, sublabel, icon, color, onToggle)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = Color3.fromRGB(40, 100, 50)
    rowStroke.Thickness = 1
    rowStroke.Transparency = 0.5

    local iconLbl = Instance.new("TextLabel", row)
    iconLbl.Size = UDim2.new(0, 28, 1, 0)
    iconLbl.Position = UDim2.new(0, 10, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 18
    iconLbl.TextColor3 = color

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -90, 0, 16)
    nameLbl.Position = UDim2.new(0, 42, 0, 7)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = Color3.fromRGB(200, 220, 200)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local subLbl = Instance.new("TextLabel", row)
    subLbl.Size = UDim2.new(1, -90, 0, 13)
    subLbl.Position = UDim2.new(0, 42, 0, 26)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = sublabel
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 9
    subLbl.TextColor3 = Color3.fromRGB(120, 120, 120)
    subLbl.TextXAlignment = Enum.TextXAlignment.Left

    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0, 42, 0, 22)
    pill.Position = UDim2.new(1, -50, 0.5, -11)
    pill.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(160, 160, 160)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.BorderSizePixel = 0

    local isOn = false
    local function refresh()
        TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = isOn and color or Color3.fromRGB(40, 40, 40)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = isOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = isOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        }):Play()
        subLbl.Text = isOn and "RUNNING" or sublabel
        subLbl.TextColor3 = isOn and color or Color3.fromRGB(120, 120, 120)
        rowStroke.Color = isOn and color or Color3.fromRGB(40, 100, 50)
        rowStroke.Transparency = isOn and 0.1 or 0.5
    end

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        refresh()
        onToggle(isOn)
    end)

    return row
end

local function makeStatRow(parent, label, color)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(10, 20, 10)
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextColor3 = Color3.fromRGB(140, 160, 140)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel", row)
    val.Size = UDim2.new(0.4, -10, 1, 0)
    val.Position = UDim2.new(0.6, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "0"
    val.Font = Enum.Font.GothamBlack
    val.TextSize = 11
    val.TextColor3 = color
    val.TextXAlignment = Enum.TextXAlignment.Right

    return row, val
end

-- Auto Harvest
makeToggleRow(body, "Auto Harvest", "Every 2 seconds", "🌿", Color3.fromRGB(80, 220, 100), function(on)
    autoHarvestEnabled = on
    if on then
        task.spawn(function()
            while autoHarvestEnabled and not _G.GardenAutoStop do
                local count = doHarvest()
                if count > 0 then harvestCount += count end
                task.wait(2)
            end
        end)
    end
end)

-- Auto Sell (timer)
makeToggleRow(body, "Auto Sell", "Every 60 seconds", "💰", Color3.fromRGB(255, 200, 50), function(on)
    autoSellEnabled = on
    if on then
        task.spawn(function()
            while autoSellEnabled and not _G.GardenAutoStop do
                local ok = doSell()
                if ok then sellCount += 1 end
                task.wait(60)
            end
        end)
    end
end)

-- Auto Sell when Full
makeToggleRow(body, "Sell When Full", "Detects inventory", "📦", Color3.fromRGB(100, 180, 255), function(on)
    autoSellFullEnabled = on
    if on then
        task.spawn(function()
            while autoSellFullEnabled and not _G.GardenAutoStop do
                if isInventoryFull() then
                    local ok = doSell()
                    if ok then sellCount += 1 end
                    task.wait(5) -- cooldown after selling
                end
                task.wait(1)
            end
        end)
    end
end)

-- Divider
local div2 = Instance.new("Frame", body)
div2.Size = UDim2.new(1, 0, 0, 1)
div2.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
div2.BackgroundTransparency = 0.6
div2.BorderSizePixel = 0

-- Stats
local _, harvestVal = makeStatRow(body, "Harvested", Color3.fromRGB(80, 220, 100))
local _, sellVal = makeStatRow(body, "Times Sold", Color3.fromRGB(255, 200, 50))
local _, invVal = makeStatRow(body, "Inventory", Color3.fromRGB(100, 180, 255))

task.spawn(function()
    while not _G.GardenAutoStop do
        task.wait(0.5)
        harvestVal.Text = tostring(harvestCount)
        sellVal.Text = tostring(sellCount)
        local cur, max = getInventoryCount()
        invVal.Text = cur .. "/" .. max
    end
end)

print("Garden Auto GUI loaded!")