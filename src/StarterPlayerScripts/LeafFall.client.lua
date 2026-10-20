-- POWER RUSH: LeafFall (LocalScript in StarterPlayerScripts)
-- Pixel leaves drift down from the green trees closest to you and blow with the wind.
-- Runs only on your own screen. Uses a small pool of emitters that hop between the
-- nearest trees, so the cost stays the same however many trees the map has.
-- (Blossom trees already drop petals from their own emitters.)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TREE_FOLDERS = { "HubDecor.Trees", "HubDecor.GiantTrees" }
local TREE_TYPES = { Tree = true, GiantTree = true, WillowTree = true, AncientTree = true, SpireTree = true }
local LEAF_NAMES = { Leaves = true, Hang = true }

local MAX_TREES = 6        -- how many trees drop leaves at once
local RANGE = 80           -- studs from the camera
local REFRESH = 0.75       -- seconds between picking the nearest trees
local LEAVES_PER_100_STUDS = 0.9 -- emission per 100 studs² of canopy footprint (more = busier)

local ids = require(ReplicatedStorage:WaitForChild("TextureIds"))
local TEXTURES = { ids.p_leaf_pixel, ids.p_leaf_pixel2 }

local function windDir(): Vector3
	local d = workspace:GetAttribute("WindDirection")
	if typeof(d) == "Vector3" and d.Magnitude > 0 then return d.Unit end
	return Vector3.new(1, 0, 0.3).Unit
end

local function resolve(path)
	local node = workspace
	for name in string.gmatch(path, "[^%.]+") do node = node and node:FindFirstChild(name) end
	return node
end

local folder = Instance.new("Folder")
folder.Name = "LeafFallFX"
folder.Parent = workspace

local pool = {}
for i = 1, MAX_TREES do
	local p = Instance.new("Part")
	p.Name = "LeafSource"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEXTURES[(i % 2) + 1]
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 0.6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-80, 80)
	e.LightInfluence = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.45),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0),
		NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1),
	})
	e.Enabled = false
	e.Parent = p
	pool[i] = { part = p, emitter = e, tree = nil }
end

-- Canopy box and colour for a tree (from its leaf parts that have streamed in).
local cache = {} -- [model] = { cf, size, color, n }
local function canopy(model: Model)
	local c = cache[model]
	local parts, r, g, b = {}, 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and LEAF_NAMES[d.Name] then
			table.insert(parts, d)
			r += d.Color.R g += d.Color.G b += d.Color.B
		end
	end
	if #parts == 0 then return nil end
	if c and c.n == #parts then return c end
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		local h = p.Size / 2
		minV = minV:Min(p.Position - h)
		maxV = maxV:Max(p.Position + h)
	end
	local n = #parts
	c = {
		cf = CFrame.new((minV + maxV) / 2),
		size = (maxV - minV),
		color = Color3.new(r / n, g / n, b / n),
		n = n,
	}
	cache[model] = c
	return c
end

local trees = {}
local function addTree(m)
	if m:IsA("Model") and TREE_TYPES[m.Name] then trees[m] = true end
end
for _, path in TREE_FOLDERS do
	task.spawn(function()
		local root = resolve(path)
		while not root do task.wait(2) root = resolve(path) end
		for _, m in root:GetChildren() do addTree(m) end
		root.ChildAdded:Connect(addTree)
		root.ChildRemoved:Connect(function(m) trees[m] = nil cache[m] = nil end)
	end)
end

local function refresh()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local camPos = cam.CFrame.Position
	local near = {}
	for m in trees do
		if m.Parent then
			local d = (m:GetPivot().Position - camPos).Magnitude
			if d <= RANGE then table.insert(near, { m = m, d = d }) end
		end
	end
	table.sort(near, function(a, b) return a.d < b.d end)

	local wanted = {}
	for i = 1, math.min(MAX_TREES, #near) do wanted[near[i].m] = true end
	-- free slots whose tree is no longer wanted
	for _, slot in pool do
		if slot.tree and not wanted[slot.tree] then
			slot.tree = nil
			slot.emitter.Enabled = false
		end
	end
	local wind = windDir()
	for m in wanted do
		local has = false
		for _, slot in pool do if slot.tree == m then has = true break end end
		if not has then
			for _, slot in pool do
				if not slot.tree then
					local c = canopy(m)
					if c then
						slot.tree = m
						slot.part.CFrame = c.cf
						slot.part.Size = Vector3.new(c.size.X * 0.8, math.max(1, c.size.Y * 0.4), c.size.Z * 0.8)
						local e = slot.emitter
						-- slightly lighter than the canopy so leaves read against it
						e.Color = ColorSequence.new(c.color:Lerp(Color3.new(1, 1, 0.8), 0.12))
						e.Rate = math.clamp(c.size.X * c.size.Z / 100 * LEAVES_PER_100_STUDS, 0.6, 5)
						e.Acceleration = Vector3.new(wind.X * 1.1, -1.6, wind.Z * 1.1)
						e.Enabled = true
					end
					break
				end
			end
		end
	end
end

local acc = REFRESH
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= REFRESH then
		acc = 0
		refresh()
	end
end)
