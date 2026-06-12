-- Safeguard to prevent multiple instances of the script running
if _G.RejoinButtonLoaded then
    return
end
_G.RejoinButtonLoaded = true

-- Services
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Create ScreenGui (Protected under CoreGui so it doesn't clear on death)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaRejoinGUI"
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

-- Create Rejoin Button
local RejoinButton = Instance.new("TextButton")
RejoinButton.Name = "RejoinButton"
RejoinButton.Parent = ScreenGui

-- Position and Size (Tailored for Mobile Top-Right)
-- Placed slightly below the standard Roblox topbar buttons to avoid overlapping UI
RejoinButton.Size = UDim2.new(0, 90, 0, 35)
RejoinButton.Position = UDim2.new(1, -105, 0, 50) 

-- Styling (Sleek Dark Theme)
RejoinButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RejoinButton.BorderSizePixel = 0
RejoinButton.Text = "Rejoin"
RejoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RejoinButton.Font = Enum.Font.SourceSansBold
RejoinButton.TextSize = 16

-- Rounded Corners
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = RejoinButton

-- Stroke/Border
local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 180, 255) -- Delta Blue/Cyan accent
UIStroke.Thickness = 1.5
UIStroke.Parent = RejoinButton

-- Rejoin Functionality
local function rejoinServer()
    RejoinButton.Text = "Joining..."
    RejoinButton.TextColor3 = Color3.fromRGB(150, 150, 150)
    
    local success, err = pcall(function()
        if #Players:GetPlayers() <= 1 then
            -- Solo server: Teleport to a new instance of the same place
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            -- Public/Multiplayer server: Rejoin the exact same server instance
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

-- Mobile friendly activation
RejoinButton.MouseButton1Click:Connect(rejoinServer)
