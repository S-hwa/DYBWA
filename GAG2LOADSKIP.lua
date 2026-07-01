local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local function performClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local player = Players.LocalPlayer

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

waitForLoadingScreen()