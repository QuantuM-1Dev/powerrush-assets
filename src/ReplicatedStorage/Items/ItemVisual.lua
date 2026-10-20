-- POWER RUSH: ItemVisual (ModuleScript in ReplicatedStorage > Items)
-- Builds the look of a dropped material on each player's device: the 2D icon as a thick,
-- extruded "chunky coin" sprite (stacked layers, so it has real depth when it spins), floating
-- and bobbing over a rarity-coloured glow disc. Rarer items get more:
--   all        soft glow pool (white for Common, rarity colour above)        Rare+  light beam + glow light
--   Epic+      pixel sparkles            Mythic colour-cycling glow
-- Used by StarterPlayerScripts > ItemDropFX. Tune everything in CONFIG.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TraitConfig = require(ReplicatedStorage:WaitForChild("TraitConfig"))
local Icons = require(ReplicatedStorage:WaitForChild("Icons"))
local TextureIds = require(ReplicatedStorage:WaitForChild("TextureIds"))

local ItemVisual = {}

ItemVisual.CONFIG = {
	SIZE = 3,           -- icon size in studs
	LAYERS = 7,         -- how many stacked layers make the thickness
	DEPTH = 0.3,        -- total thickness in studs
	HOVER = 2.5,        -- height of the icon's centre above the ground
	BOB = 0.22,         -- bob up/down amount
	SPIN = 45,          -- degrees per second
	BEAM_HEIGHT = { Rare = 7, Epic = 10, Legendary = 14, Mythic = 18 },
	NAME_DISTANCE = 22, -- the name tag shows within this many studs
}

local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
ItemVisual.RANK = RANK

local function part(name, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Transparency = 1
	return p
end

local function face(p, faceId, image, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = faceId
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0 -- coloured drop lights never tint the icon itself
	gui.Brightness = 1
	gui.Parent = p
	if not image or image == "" or image == "rbxassetid://0" then
		-- no icon uploaded yet: a chunky "?" so the drop still reads as an item
		local q = Instance.new("TextLabel")
		q.BackgroundTransparency = 1
		q.Size = UDim2.fromScale(1, 1)
		q.Font = Enum.Font.FredokaOne
		q.TextScaled = true
		q.Text = "?"
		q.TextColor3 = color
		q.TextStrokeTransparency = 0
		q.TextStrokeColor3 = Color3.fromRGB(20, 20, 35)
		q.Parent = gui
		return q
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = color
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = gui
	return img
end

function ItemVisual.Color(rarity)
	return TraitConfig.GetRarityColor(rarity or "Common")
end

-- Returns a Model (not parented). Call ItemVisual.Pose every frame to move it.
function ItemVisual.Build(itemId, rarity, displayName)
	local C = ItemVisual.CONFIG
	local color = ItemVisual.Color(rarity)
	local rank = RANK[rarity] or 1
	local icon = Icons.Get("Items", itemId)

	local model = Instance.new("Model")
	model.Name = "Drop_" .. itemId
	local pivot = part("Pivot", Vector3.new(0.2, 0.2, 0.2))
	pivot.Parent = model
	model.PrimaryPart = pivot

	-- the chunky sprite: front layer full colour, inner layers darker = the "side" of the coin
	local card = Instance.new("Model")
	card.Name = "Card"
	local step = C.DEPTH / C.LAYERS
	local edge = Color3.fromRGB(175, 172, 195):Lerp(color, rank == 6 and 0 or 0.15) -- the coin's side: a shaded copy of the icon
	for i = 0, C.LAYERS - 1 do
		local layer = part("Layer" .. i, Vector3.new(C.SIZE, C.SIZE, step))
		layer.CFrame = CFrame.new(0, 0, C.DEPTH / 2 - (i + 0.5) * step)
		if i == 0 then
			face(layer, Enum.NormalId.Front, icon, Color3.new(1, 1, 1))
		else
			face(layer, Enum.NormalId.Front, icon, edge:Lerp(Color3.new(0, 0, 0), i / C.LAYERS * 0.15))
		end
		if i == C.LAYERS - 1 then
			face(layer, Enum.NormalId.Back, icon, Color3.new(1, 1, 1))
		end
		layer.Parent = card
	end
	card.PrimaryPart = card:FindFirstChild("Layer0")
	card.Parent = model

	-- soft shadow + rarity glow pool on the ground (flat parts showing a soft radial glow)
	local function pool(name, size, tint, transparency)
		local p = part(name, Vector3.new(size, 0.05, size))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 32
		gui.Parent = p
		local img = Instance.new("ImageLabel")
		img.Name = "Img"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = TextureIds.p_soft_glow
		img.ImageColor3 = tint
		img.ImageTransparency = transparency
		img.Parent = gui
		p.Parent = model
		return p
	end
	pool("Shadow", 2.6, Color3.new(0, 0, 0), 0.45)
	pool("Glow", 3 + rank * 0.35, rank == 1 and Color3.new(1, 1, 1) or color, rank == 1 and 0.6 or 0.15)

	-- light beam + light (Rare and up)
	if rank >= 3 then
		local a0 = Instance.new("Attachment") a0.Name = "BeamBottom" a0.Position = Vector3.new(0, C.HOVER + C.SIZE / 2 + 0.4, 0) a0.Parent = pivot -- starts above the icon so it never covers it
		local a1 = Instance.new("Attachment") a1.Name = "BeamTop" a1.Position = Vector3.new(0, C.BEAM_HEIGHT[rarity] or 8, 0) a1.Parent = pivot
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Texture = TextureIds.beam_light_shaft
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Color = rank == 6 and ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 90)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 90, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 220, 255)) }) or ColorSequence.new(color)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		beam.Width0, beam.Width1 = 1.6, 2.6
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = pivot
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6 + rank
		light.Brightness = 0.6 + (rank - 3) * 0.15
		light.Shadows = false
		light.Parent = pivot
	end

	-- pixel sparkles (Epic and up)
	if rank >= 4 then
		local holder = card.PrimaryPart
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Sparkles"
		pe.Texture = TextureIds.p_spark_pixel
		pe.Rate = 2 + (rank - 4) * 2.5
		pe.Lifetime = NumberRange.new(0.9, 1.6)
		pe.Speed = NumberRange.new(0.3, 0.9)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.32), NumberSequenceKeypoint.new(1, 0) })
		pe.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.Parent = holder
	end

	-- name tag
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromScale(6, 0.9)
	tag.StudsOffset = Vector3.new(0, C.HOVER + C.SIZE / 2 + 0.7, 0)
	tag.MaxDistance = C.NAME_DISTANCE
	tag.LightInfluence = 0
	tag.Adornee = pivot
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = displayName or itemId
	label.TextColor3 = rank == 1 and Color3.new(1, 1, 1) or color
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 35)
	label.Parent = tag
	tag.Parent = pivot

	model:SetAttribute("Rank", rank)
	model:SetAttribute("Phase", math.random() * 6)
	return model
end

-- Places the visual for time t (seconds). groundCF = the drop point on the ground.
-- lift adds height (used by the drop arc).
function ItemVisual.Pose(model, groundCF, t, lift)
	local C = ItemVisual.CONFIG
	local phase = model:GetAttribute("Phase") or 0
	local pivot = model.PrimaryPart
	pivot.CFrame = groundCF
	local y = C.HOVER + math.sin(t * 2.2 + phase) * C.BOB + (lift or 0)
	local yaw = math.rad((t * C.SPIN + phase * 57) % 360)
	local card = model:FindFirstChild("Card")
	if card then
		local glitch = CFrame.identity
		if model:GetAttribute("Rank") == 6 and (t * 0.9 + phase) % 1 < 0.07 then
			-- Mythic: a quick glitch twitch now and then
			glitch = CFrame.new((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.25, 0)
		end
		card:PivotTo(groundCF * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, math.rad(math.sin(t * 1.3 + phase) * 6)) * glitch)
	end
	local flat = groundCF * CFrame.new(0, 0.22, 0) -- above the studs on the floor
	local shadow = model:FindFirstChild("Shadow")
	if shadow then shadow.CFrame = flat end
	local glow = model:FindFirstChild("Glow")
	if glow then
		glow.CFrame = flat * CFrame.new(0, 0.02, 0)
		local img = glow:FindFirstChild("Img", true)
		local rank = model:GetAttribute("Rank") or 1
		if img then
			img.ImageTransparency = (rank == 1 and 0.6 or 0.15) + math.sin(t * 3 + phase) * 0.12
			if rank == 6 then img.ImageColor3 = Color3.fromHSV((t * 0.15) % 1, 0.8, 1) end
		end
	end
end

return ItemVisual
