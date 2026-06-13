local Loader = (pcall(dofile, "LoadScripts/Modules/Loader.lua") and getgenv().Loader) or loadstring(game:HttpGet("https://loadstr.ing/scripts/Loader.lua"))()
local Networking = require(game.ReplicatedStorage.SharedModules.Networking)
local Modules = Loader({"Loop"})

if getgenv().SellAllLoop then getgenv().SellAllLoop.Stop() end
getgenv().SellAllLoop = Modules.Loop(function()
    Networking.NPCS.SellAll:Fire()
end, 0.5, "S", true)
