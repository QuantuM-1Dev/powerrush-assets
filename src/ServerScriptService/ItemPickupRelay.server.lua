-- POWER RUSH: ItemPickupRelay (Script in ServerScriptService)
-- When a player picks up a material drop, mark it as found in their Index.
-- (Adding it to the Backpack comes later, with the material backpack system.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemDrops = require(ReplicatedStorage:WaitForChild("Items"):WaitForChild("ItemDrops"))
local InventorySystem = require(ServerScriptService:WaitForChild("InventorySystem"))

ItemDrops.PickedUp.Event:Connect(function(player, itemId)
	local ok, err = pcall(InventorySystem.Discover, player, "Materials", itemId)
	if not ok then warn("[ItemPickupRelay] " .. tostring(err)) end
end)
