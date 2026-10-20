-- POWER RUSH: ItemDropFX (LocalScript in StarterPlayerScripts)
-- Draws every material drop (tag "ItemDrop") on this device with ItemVisual:
-- it pops out in an arc, bounces, then floats and spins. Picking one up makes it fly
-- into the player with a burst of sparkles. Other players' personal loot isn't drawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = ReplicatedStorage:WaitForChild("Items")
local ItemVisual = require(Items:WaitForChild("ItemVisual"))
local ItemConfig = require(Items:WaitForChild("ItemConfig"))
local TextureIds = require(ReplicatedStorage:WaitForChild("TextureIds"))

local me = Players.LocalPlayer
local ARC_TIME, ARC_HEIGHT = 0.6, 5
local drops = {} -- [anchor] = { model, groundCF, from, spawn }

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ItemDropVisuals"
fxFolder.Parent = workspace

local function add(anchor)
	if drops[anchor] or not anchor:IsA("BasePart") then return end
	local owner = anchor:GetAttribute("OwnerUserId")
	if owner and owner ~= me.UserId then return end
	local id = anchor:GetAttribute("ItemId")
	local def = id and ItemConfig.Get(id)
	if not def then return end
	local model = ItemVisual.Build(id, def.Rarity, def.DisplayName)
	model.Parent = fxFolder
	drops[anchor] = {
		model = model,
		groundCF = CFrame.new(anchor.Position),
		from = anchor:GetAttribute("From") or anchor.Position,
		spawn = anchor:GetAttribute("SpawnTime") or workspace:GetServerTimeNow(),
	}
end

-- a quick burst of sparkles at a point, coloured by rarity
local function burst(pos, color, amount)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.Position = pos
	p.Parent = fxFolder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TextureIds.p_spark_pixel
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.35, 0.7)
	pe.Speed = NumberRange.new(6, 12)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 4
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Parent = p
	pe:Emit(amount)
	task.delay(1, function() p:Destroy() end)
end

local function remove(anchor)
	local d = drops[anchor]
	if not d then return end
	drops[anchor] = nil
	local by = anchor:GetAttribute("PickedBy")
	local picker = by and Players:GetPlayerByUserId(by)
	local root = picker and picker.Character and picker.Character:FindFirstChild("HumanoidRootPart")
	local rarity = anchor:GetAttribute("Rarity") or "Common"
	local color = ItemVisual.Color(rarity)
	if not root then
		burst(d.groundCF.Position + Vector3.new(0, ItemVisual.CONFIG.HOVER, 0), color, 6)
		d.model:Destroy()
		return
	end
	-- fly into the player who grabbed it
	local card = d.model:FindFirstChild("Card")
	local tag = d.model.PrimaryPart and d.model.PrimaryPart:FindFirstChild("NameTag")
	if tag then tag.Enabled = false end
	local start = card and card:GetPivot() or d.groundCF
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / 0.28)
		local target = root.Parent and root.Position or start.Position
		local pos = start.Position:Lerp(target, k * k) + Vector3.new(0, math.sin(k * math.pi) * 2, 0)
		if card then card:PivotTo(CFrame.new(pos) * (start - start.Position) * CFrame.Angles(0, k * 8, 0)) end
		if k >= 1 then
			conn:Disconnect()
			burst(target, color, 10 + (ItemVisual.RANK[rarity] or 1) * 3)
			d.model:Destroy()
		end
	end)
end

for _, a in CollectionService:GetTagged("ItemDrop") do task.spawn(add, a) end
CollectionService:GetInstanceAddedSignal("ItemDrop"):Connect(add)
CollectionService:GetInstanceRemovedSignal("ItemDrop"):Connect(remove)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for anchor, d in drops do
		local age = now - d.spawn
		if age < ARC_TIME then
			-- pop-out arc from `from` to the landing spot
			local k = math.max(0, age / ARC_TIME)
			local pos = d.from:Lerp(d.groundCF.Position, k)
			ItemVisual.Pose(d.model, CFrame.new(pos), age, math.sin(k * math.pi) * ARC_HEIGHT)
		elseif age < ARC_TIME + 0.35 then
			-- little bounce on landing
			local b = (age - ARC_TIME) / 0.35
			ItemVisual.Pose(d.model, d.groundCF, age, math.sin(b * math.pi) * 0.8)
		else
			ItemVisual.Pose(d.model, d.groundCF, age, 0)
		end
	end
end)
