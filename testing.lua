-- Safeguard to prevent multiple instances of the script running
if _G.DeltaMobileMenuLoaded then
    return
end
_G.DeltaMobileMenuLoaded = true

-- Services
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- Create ScreenGui (Protected under CoreGui so it stays active)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaMobileUtilityGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Handle execution environment safety
if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
elseif getgui then
    ScreenGui.Parent = getgui()
else
    ScreenGui.Parent = CoreGui
end

-- Shared Styling Function to keep both buttons looking identical
local function styleButton(btn, text, yOffset)
    btn.Size = UDim2.new(0, 90, 0, 35)
    btn.Position = UDim2.new(1, -105, 0, yOffset) -- Aligned to the top right
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16

    -- Rounded Corners
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = btn

    -- Delta Blue/Cyan Border Stroke
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(0, 180, 255)
    UIStroke.Thickness = 1.5
    UIStroke.Parent = btn
end

-- 1. Create Rejoin Button (Top Button)
local RejoinButton = Instance.new("TextButton")
RejoinButton.Name = "RejoinButton"
RejoinButton.Parent = ScreenGui
styleButton(RejoinButton, "Rejoin", 50) -- Positioned at Y: 50

-- 2. Create Reset Button (Bottom Button)
local ResetButton = Instance.new("TextButton")
ResetButton.Name = "ResetButton"
ResetButton.Parent = ScreenGui
styleButton(ResetButton, "Reset", 95) -- Positioned perfectly below Rejoin (Y: 95)

-- Rejoin Functionality
local function rejoinServer()
    RejoinButton.Text = "Joining..."
    RejoinButton.TextColor3 = Color3.fromRGB(150, 150, 150)
    
    local success, err = pcall(function()
        if #Players:GetPlayers() <= 1 then
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
    
    if not success then
        RejoinButton.Text = "Failed!"
        RejoinButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(2)
        RejoinButton.Text = "Rejoin"
        RejoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- Reset Character Functionality
local function resetCharacter()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end
end

-- Mobile-friendly Click Listeners
RejoinButton.MouseButton1Click:Connect(rejoinServer)
ResetButton.MouseButton1Click:Connect(resetCharacter)
