-- POWER RUSH: ItemDrops (ModuleScript in ReplicatedStorage > Items, used by the SERVER)
-- Drops a material into the world. The server only keeps a tiny invisible anchor part
-- (tag "ItemDrop", in Workspace > ItemDrops); every device builds the look itself with
-- ItemVisual (StarterPlayerScripts > ItemDropFX), so drops cost almost no network.
--
--   local ItemDrops = require(game.ReplicatedStorage.Items.ItemDrops)
--   ItemDrops.Spawn("GemGear", landingPosition, player, { From = enemyPosition })
--     player = owner (personal loot: only they see it and can pick it up). nil = anyone.
--     From   = where it pops out of (it arcs from there to landingPosition).
--     Lifetime = seconds before it vanishes (default 60).
--
--   ItemDrops.PickedUp.Event:Connect(function(player, itemId) ... end)
--     (ItemPickupRelay already uses this to add the item to the Index.)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ItemConfig = require(script.Parent:WaitForChild("ItemConfig"))

local ItemDrops = {}

ItemDrops.CONFIG = {
	LIFETIME = 60,
	PICKUP_RANGE = 6,
	PICKUP_DELAY = 0.8, -- seconds after landing before it can be picked up
	ARC_TIME = 0.6,     -- seconds of the pop-out arc (keep in sync with ItemDropFX)
}

local pickedUp = Instance.new("BindableEvent")
pickedUp.Name = "ItemPickedUp"
ItemDrops.PickedUp = pickedUp

local function folder()
	local f = workspace:FindFirstChild("ItemDrops")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ItemDrops"
		f.Parent = workspace
	end
	return f
end

-- snaps a point onto the ground below it
local function ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder() }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or pos
end

function ItemDrops.Spawn(itemId, position, owner, options)
	assert(RunService:IsServer(), "ItemDrops.Spawn must run on the server")
	options = options or {}
	local def = ItemConfig.Get(itemId)
	if not def then
		warn("[ItemDrops] unknown item id: " .. tostring(itemId))
		return nil
	end
	local landing = ground(position)
	local anchor = Instance.new("Part")
	anchor.Name = itemId
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Position = landing
	anchor:SetAttribute("ItemId", itemId)
	anchor:SetAttribute("Rarity", def.Rarity)
	anchor:SetAttribute("SpawnTime", workspace:GetServerTimeNow())
	anchor:SetAttribute("From", options.From or (landing + Vector3.new(0, 3, 0)))
	if owner then anchor:SetAttribute("OwnerUserId", owner.UserId) end
	CollectionService:AddTag(anchor, "ItemDrop")
	anchor.Parent = folder()

	local born = os.clock()
	local lifetime = options.Lifetime or ItemDrops.CONFIG.LIFETIME
	local canPickAt = born + ItemDrops.CONFIG.ARC_TIME + ItemDrops.CONFIG.PICKUP_DELAY
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not anchor.Parent then conn:Disconnect() return end
		local now = os.clock()
		if now - born > lifetime then
			conn:Disconnect()
			anchor:Destroy()
			return
		end
		if now < canPickAt or options.NoPickup then return end
		local candidates = owner and { owner } or Players:GetPlayers()
		for _, plr in ipairs(candidates) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and (root.Position - landing).Magnitude <= ItemDrops.CONFIG.PICKUP_RANGE then
				conn:Disconnect()
				-- tell every device who grabbed it (for the fly-to-player effect), then remove it
				anchor:SetAttribute("PickedBy", plr.UserId)
				task.delay(0.1, function() anchor:Destroy() end)
				pickedUp:Fire(plr, itemId)
				return
			end
		end
	end)
	return anchor
end

-- removes every drop (used by /drops clear)
function ItemDrops.ClearAll()
	local f = workspace:FindFirstChild("ItemDrops")
	if f then f:ClearAllChildren() end
end

return ItemDrops
