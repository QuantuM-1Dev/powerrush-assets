-- POWER RUSH: WindController (LocalScript in StarterPlayerScripts)
-- Wind trail lines from boatbomber's open-source WindShake/WindLines
-- (https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806/1).
-- Moved here from Workspace, where LocalScripts don't run. The demo's debug UI was removed.
-- Tree/grass sway is done by TreeSwayClient, and falling leaves by LeafFall; both read
-- workspace's "WindDirection" attribute, so everything blows the same way.
-- Original Toolbox copy: ServerStorage > PowerRush_Backups > WindController_Toolbox.

local WIND_DIRECTION = Vector3.new(1, 0, 0.3).Unit
local WIND_SPEED = 20

workspace:SetAttribute("WindDirection", WIND_DIRECTION)

local WindLines = require(script:WaitForChild("WindLines"))
WindLines:Init({
	Direction = WIND_DIRECTION,
	Speed = WIND_SPEED,
	Lifetime = 2,
	SpawnRate = 15,
})
