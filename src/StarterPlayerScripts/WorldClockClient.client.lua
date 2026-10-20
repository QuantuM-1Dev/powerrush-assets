-- POWER RUSH: WorldClockClient v2 (LocalScript in StarterPlayerScripts)
-- Moves the sun with the shared world clock and blends the lighting through the day:
-- cool blue nights, warm pink dawns, golden dusks. Daytime is your original look
-- (Brightness 3, Ambient/OutdoorAmbient 70, Atmosphere 199 / decay 106,112,125).
-- Starfall nights get a soft violet glow. Does nothing while the player is inside
-- Workspace.RaidMap, so RaidBiomeSky stays in charge there.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldClock = require(ReplicatedStorage:WaitForChild("WorldClock"))
local player = Players.LocalPlayer
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

local rgb = Color3.fromRGB
-- Lighting keyframes by ClockTime (0-24). Values blend smoothly between them.
local KEYS = {
	{ t = 0,  bright = 1.2, amb = rgb(45, 50, 80),   out = rgb(70, 80, 125),  atm = rgb(80, 95, 140),   decay = rgb(35, 45, 85),    dens = 0.10 },
	{ t = 4.8, bright = 1.2, amb = rgb(45, 50, 80),  out = rgb(70, 80, 125),  atm = rgb(80, 95, 140),   decay = rgb(35, 45, 85),    dens = 0.10 },
	{ t = 6,  bright = 2.2, amb = rgb(70, 60, 70),   out = rgb(125, 100, 110), atm = rgb(235, 185, 175), decay = rgb(200, 140, 125), dens = 0.09 },
	{ t = 7.5, bright = 3,  amb = rgb(70, 70, 70),   out = rgb(70, 70, 70),   atm = rgb(199, 199, 199), decay = rgb(106, 112, 125), dens = 0.04 },
	{ t = 16.5, bright = 3, amb = rgb(70, 70, 70),   out = rgb(70, 70, 70),   atm = rgb(199, 199, 199), decay = rgb(106, 112, 125), dens = 0.04 },
	{ t = 18, bright = 2.4, amb = rgb(80, 65, 60),   out = rgb(130, 95, 80),  atm = rgb(255, 185, 135), decay = rgb(220, 120, 90),  dens = 0.08 },
	{ t = 19.5, bright = 1.2, amb = rgb(45, 50, 80), out = rgb(70, 80, 125),  atm = rgb(80, 95, 140),   decay = rgb(35, 45, 85),    dens = 0.10 },
	{ t = 24, bright = 1.2, amb = rgb(45, 50, 80),   out = rgb(70, 80, 125),  atm = rgb(80, 95, 140),   decay = rgb(35, 45, 85),    dens = 0.10 },
}
-- Starfall night: violet instead of blue.
local STARFALL = { amb = rgb(60, 45, 90), out = rgb(105, 85, 150), atm = rgb(120, 95, 170), decay = rgb(70, 45, 110) }

local function sample(clock: number)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if clock >= a.t and clock <= b.t then
			local f = (b.t == a.t) and 0 or (clock - a.t) / (b.t - a.t)
			f = f * f * (3 - 2 * f) -- ease
			return {
				bright = a.bright + (b.bright - a.bright) * f,
				amb = a.amb:Lerp(b.amb, f),
				out = a.out:Lerp(b.out, f),
				atm = a.atm:Lerp(b.atm, f),
				decay = a.decay:Lerp(b.decay, f),
				dens = a.dens + (b.dens - a.dens) * f,
			}
		end
	end
	return KEYS[1]
end

-- Raid map box, read from the real map so no coordinates are hard-coded.
local raidCF, raidSize
local function refreshRaidBox()
	local map = workspace:FindFirstChild("RaidMap")
	if map and map:IsA("Model") then
		raidCF, raidSize = map:GetBoundingBox()
	else
		raidCF, raidSize = nil, nil
	end
end
refreshRaidBox()
workspace.ChildAdded:Connect(function(c) if c.Name == "RaidMap" then task.wait(1) refreshRaidBox() end end)

local function inRaid(): boolean
	if not raidCF then return false end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local p = raidCF:PointToObjectSpace(root.Position)
	local h = raidSize / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y + 200 and math.abs(p.Z) <= h.Z
end

local starBlend = 0
RunService.RenderStepped:Connect(function(dt)
	if inRaid() then return end
	local s = WorldClock.Now()
	Lighting.ClockTime = s.ClockTime
	-- fade the Starfall colours in and out over ~4 seconds
	local target = s.Starfall and 1 or 0
	starBlend += math.clamp(target - starBlend, -dt / 4, dt / 4)

	local k = sample(s.ClockTime)
	local amb, out, atm, decay = k.amb, k.out, k.atm, k.decay
	if starBlend > 0 then
		amb = amb:Lerp(STARFALL.amb, starBlend)
		out = out:Lerp(STARFALL.out, starBlend)
		atm = atm:Lerp(STARFALL.atm, starBlend)
		decay = decay:Lerp(STARFALL.decay, starBlend)
	end
	Lighting.Brightness = k.bright
	Lighting.Ambient = amb
	Lighting.OutdoorAmbient = out
	if atmosphere then
		atmosphere.Color = atm
		atmosphere.Decay = decay
		atmosphere.Density = k.dens
	end
end)
