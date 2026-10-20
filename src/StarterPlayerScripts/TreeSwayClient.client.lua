-- POWER RUSH: TreeSwayClient v2 (LocalScript in StarterPlayerScripts)
-- v2.1: the wind wave follows WindController's direction.
-- Makes the hub feel alive on each player's own screen (costs the network nothing):
--   * tree leaves sway (green AND pink), willow vines and palm fronds a bit more
--   * flowers and grass bend from the ground up
--   * a slow wind wave rolls across the map, with gusts, instead of random wobble
-- Only things near the camera move (map cells + range), updated at 30 fps with one
-- BulkMoveTo. Works with StreamingEnabled: parts that stream in later join automatically.
-- v1 is backed up in ServerStorage > PowerRush_Backups > TreeSwayClient_v1.
-- Old "SwayTree"-tagged trees still work exactly like before.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- WHERE TO LOOK -----------------------------------------------------------------------
-- Tree folders: any part with one of these names inside them sways around its own base.
local TREE_FOLDERS = { "HubDecor.Trees", "HubDecor.GiantTrees", "HubRevamp.Trees", "HubRevamp.Village" }
local TREE_PARTS = { -- part name = sway angle in degrees
	Leaves = 3, LeafSkirt = 3, LeafDrip = 4, Hang = 6, Frond = 5, Crown = 2,
}
-- Ground plants: each model sways as one clump from its lowest point.
-- Single blades (TallGrass) sway one by one.
local FLORA_FOLDERS = { "HubDecor.Flora", "HubRevamp.Flora", "HubDecor.Pack" }
local FLORA_MODELS = { -- model name (exact, or "find:" for any name containing it) = angle
	-- 0 = never sway the model as a whole (GrassPatch has a flat ground piece; its Blades
	-- still sway one by one through BLADE_PARTS).
	Flowers = 6, GrassPatch = 0, TallGrass = 0, ["find:Flower"] = 6, ["find:Grass"] = 7,
}
local BLADE_PARTS = { Blade = 8 }

-- FEEL --------------------------------------------------------------------------------
local SWAY_SPEED = 1.1        -- how fast things rock back and forth
local WAVE_SIZE = 0.012       -- how wide the wind wave is (smaller = wider waves)
local WAVE_SPEED = 0.55       -- how fast the wind wave travels across the map
local GUST_SPEED = 0.18       -- how often gusts come
local GUST_STRENGTH = 0.45    -- 0 = no gusts, 1 = strong gusts
-- Wind direction comes from WindController (workspace attribute "WindDirection").
local function windDir(): Vector3
	local d = workspace:GetAttribute("WindDirection")
	if typeof(d) == "Vector3" and d.Magnitude > 0 then return d.Unit end
	return Vector3.new(1, 0, 0.3).Unit
end

-- PERFORMANCE -------------------------------------------------------------------------
local TREE_RANGE = 170        -- studs from the camera
local FLORA_RANGE = 90
local CELL_SIZE = 64
local UPDATE_INTERVAL = 1 / 30
local REFRESH_INTERVAL = 0.5
local REBUILD_DELAY = 1       -- seconds to wait for a streamed-in model to finish arriving

-- OLD TAG SUPPORT (v1 behaviour) ------------------------------------------------------
local TAG = "SwayTree"
local GREEN_THRESHOLD = 0.15

---------------------------------------------------------------------------------------
local claimedPart = {} -- [part] = unit
local claimedModel = {} -- [model] = unit
local cells = {} -- [key] = { cx, cz, range, units = {} }
local activeCells = {}

local function resolve(path)
	local node = workspace
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function cellFor(pos: Vector3, range: number)
	local x, z = math.floor(pos.X / CELL_SIZE), math.floor(pos.Z / CELL_SIZE)
	local key = x .. "," .. z .. "," .. range
	local cell = cells[key]
	if not cell then
		cell = { cx = (x + 0.5) * CELL_SIZE, cz = (z + 0.5) * CELL_SIZE, range = range, units = {} }
		cells[key] = cell
	end
	return cell
end

local function newUnit(parts, pivot: CFrame, angle: number, range: number)
	local unit = {
		parts = parts,
		offsets = {},
		pivot = pivot,
		angle = math.rad(angle) * (0.75 + math.random() * 0.5),
		speed = 0.85 + math.random() * 0.3,
		jitter = math.random() * 0.8,
		wave = pivot.Position:Dot(windDir()) * WAVE_SIZE,
	}
	for i, p in parts do
		unit.offsets[i] = pivot:ToObjectSpace(p.CFrame)
	end
	table.insert(cellFor(pivot.Position, range).units, unit)
	return unit
end

-- One part rocking around its own base (leaves, blades).
local function addSinglePart(part: BasePart, angle: number, range: number)
	if claimedPart[part] or not part.Anchored then return end
	local pivot = part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)
	claimedPart[part] = newUnit({ part }, pivot, angle, range)
end

-- A whole model rocking from its lowest point (flower clumps). Rebuilt if more parts
-- stream in later, restoring the old positions first so nothing drifts.
local pendingModels = {}
local function buildModel(model: Model, angle: number)
	local old = claimedModel[model]
	if old then
		old.dead = true
		for i, p in old.parts do
			if p.Parent then p.CFrame = old.pivot * old.offsets[i] end
		end
	end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and not claimedPart[d] then table.insert(parts, d) end
	end
	if #parts == 0 then claimedModel[model] = nil return end
	local cf, size = model:GetBoundingBox()
	local pivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	claimedModel[model] = newUnit(parts, pivot, angle, FLORA_RANGE)
end

local function floraAngle(name: string): number?
	local exact = FLORA_MODELS[name]
	if exact ~= nil then return exact > 0 and exact or nil end
	for key, angle in FLORA_MODELS do
		if string.sub(key, 1, 5) == "find:" and string.find(name, string.sub(key, 6), 1, true) then
			return angle
		end
	end
	return nil
end

local treeRoots, floraRoots = {}, {}

local function consider(inst: Instance)
	if not inst:IsA("BasePart") then return end
	-- Tree foliage
	local treeAngle = TREE_PARTS[inst.Name]
	if treeAngle then
		for _, root in treeRoots do
			if inst:IsDescendantOf(root) then addSinglePart(inst, treeAngle, TREE_RANGE) return end
		end
	end
	-- Ground plants
	for _, root in floraRoots do
		if inst:IsDescendantOf(root) then
			local blade = BLADE_PARTS[inst.Name]
			if blade then addSinglePart(inst, blade, FLORA_RANGE) return end
			-- find the plant model directly under the flora folder
			local m = inst
			while m.Parent and m.Parent ~= root do m = m.Parent end
			if m:IsA("Model") then
				local a = floraAngle(m.Name)
				if a then pendingModels[m] = { angle = a, at = os.clock() + REBUILD_DELAY } end
			end
			return
		end
	end
end

local function watch(paths, list)
	for _, path in paths do
		task.spawn(function()
			local root = resolve(path)
			while not root do task.wait(2) root = resolve(path) end
			table.insert(list, root)
			for _, d in root:GetDescendants() do consider(d) end
			root.DescendantAdded:Connect(consider)
		end)
	end
end
watch(TREE_FOLDERS, treeRoots)
watch(FLORA_FOLDERS, floraRoots)

-- Old tagged trees (v1): green parts only, as before.
local function addTagged(tree)
	local function try(p)
		local c = p.Color
		if p:IsA("BasePart") and c.G > c.R and c.G > c.B and c.G > GREEN_THRESHOLD then
			addSinglePart(p, 4, TREE_RANGE)
		end
	end
	try(tree)
	for _, d in tree:GetDescendants() do try(d) end
end
for _, t in CollectionService:GetTagged(TAG) do addTagged(t) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(addTagged)

---------------------------------------------------------------------------------------
local function refreshActiveCells()
	table.clear(activeCells)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local p = cam.CFrame.Position
	for _, cell in cells do
		local r = cell.range + CELL_SIZE
		local dx, dz = cell.cx - p.X, cell.cz - p.Z
		if dx * dx + dz * dz <= r * r then table.insert(activeCells, cell) end
	end
end

local moveParts, moveCFrames = {}, {}
local sinceUpdate, sinceRefresh = 0, REFRESH_INTERVAL

RunService.Heartbeat:Connect(function(dt)
	-- finish models that have stopped streaming in
	local now = os.clock()
	for m, info in pendingModels do
		if now >= info.at then
			pendingModels[m] = nil
			if m.Parent then buildModel(m, info.angle) end
		end
	end

	sinceRefresh += dt
	if sinceRefresh >= REFRESH_INTERVAL then
		sinceRefresh = 0
		refreshActiveCells()
	end
	sinceUpdate += dt
	if sinceUpdate < UPDATE_INTERVAL then return end
	sinceUpdate = 0

	local t = os.clock()
	local n = 0
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, cell in activeCells do
		local units = cell.units
		for i = #units, 1, -1 do
			local u = units[i]
			if u.dead or not u.parts[1].Parent then
				table.remove(units, i)
			else
				local phase = u.wave - t * WAVE_SPEED + u.jitter
				local gust = 1 - GUST_STRENGTH + GUST_STRENGTH * (0.5 + 0.5 * math.sin(t * GUST_SPEED + u.wave * 0.5))
				local ax = math.sin(t * SWAY_SPEED * u.speed + phase) * u.angle * gust
				local az = math.cos(t * SWAY_SPEED * 0.7 * u.speed + phase) * u.angle * 0.6 * gust
				local rot = u.pivot * CFrame.Angles(ax, 0, az)
				for k, p in u.parts do
					n += 1
					moveParts[n] = p
					moveCFrames[n] = rot * u.offsets[k]
				end
			end
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
