-- POWER RUSH: WorldClockServer (Script in ServerScriptService)
-- Publishes the current phase as attributes on ReplicatedStorage.WorldClock and fires
-- ReplicatedStorage.WorldClock.PhaseChanged (BindableEvent) for other server scripts.
--
-- Hook other systems in like this (server side):
--   local WC = game.ReplicatedStorage:WaitForChild("WorldClock")
--   WC:WaitForChild("PhaseChanged").Event:Connect(function(phase, day, starfall)
--       if phase == "Dawn" then --[[ restock shop, refresh daily contracts ]] end
--   end)
--
-- Attributes (readable from any script, server or client):
--   Phase (string), DayNumber (number), Starfall (bool), StarfallTonight (bool),
--   RareSpawnBoost (number: 1 normally, 3 during Starfall). CreatureSpawner can read
--   RareSpawnBoost to multiply the chance of Rare-and-up variants (not wired yet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local module = ReplicatedStorage:WaitForChild("WorldClock")
local WorldClock = require(module)

local changed = module:FindFirstChild("PhaseChanged")
if not changed then
	changed = Instance.new("BindableEvent")
	changed.Name = "PhaseChanged"
	changed.Parent = module
end

local lastPhase, lastDay = nil, nil
local acc = 0

local function publish()
	local s = WorldClock.Now()
	module:SetAttribute("Phase", s.Phase)
	module:SetAttribute("DayNumber", s.DayNumber)
	module:SetAttribute("Starfall", s.Starfall)
	module:SetAttribute("StarfallTonight", s.StarfallTonight)
	module:SetAttribute("RareSpawnBoost", s.RareSpawnBoost)
	if s.Phase ~= lastPhase or s.DayNumber ~= lastDay then
		local first = lastPhase == nil
		lastPhase, lastDay = s.Phase, s.DayNumber
		if not first then
			changed:Fire(s.Phase, s.DayNumber, s.Starfall)
		end
	end
end

publish()
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 1 then
		acc = 0
		publish()
	end
end)
