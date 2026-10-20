-- /time: jump the World Clock for testing (added by Claude, 20 Oct 2026).
--   /time                 show the time now
--   /time dawn|day|dusk|night   jump to the start of that part of the day
--   /time starfall        jump to the next Starfall Night
--   /time 18              jump to that hour (0-24, 18.5 = half past six)
--   /time reset           back to the real shared clock
-- It moves the clock for everyone on the server. Live games: admins only, like /give.
COMMANDS.time = function(player, args)
	local wcModule = ReplicatedStorage:FindFirstChild("WorldClock")
	if not wcModule then
		reply(player, "The World Clock isn't installed", false)
		return
	end
	local WorldClock = require(wcModule)
	local offset = WorldClock.Offset()
	local now = workspace:GetServerTimeNow() + offset
	local arg = args[1] and string.lower(args[1]) or ""
	local phases = { dawn = "Dawn", day = "Day", dusk = "Dusk", night = "Night" }

	local jump
	if arg == "" then
		local s = WorldClock.At(now)
		local h = math.floor(s.ClockTime)
		local m = math.floor((s.ClockTime - h) * 60)
		reply(player, ("It's %02d:%02d, %s of day %d%s%s"):format(h, m, s.Phase, s.DayNumber,
			s.Starfall and " (Starfall Night!)" or "", offset ~= 0 and " [test time, /time reset to undo]" or ""))
		return
	elseif arg == "reset" then
		wcModule:SetAttribute("DevOffset", 0)
		reply(player, "Clock back to normal")
		return
	elseif phases[arg] then
		jump = WorldClock.SecondsUntil(now, phases[arg]) + 1
	elseif arg == "starfall" then
		jump = WorldClock.SecondsUntilStarfall(now) + 1
	elseif tonumber(arg) and tonumber(arg) >= 0 and tonumber(arg) <= 24 then
		jump = WorldClock.SecondsUntilHour(now, tonumber(arg))
	else
		reply(player, "Use: /time   /time dawn|day|dusk|night|starfall   /time 18   /time reset", false)
		return
	end
	wcModule:SetAttribute("DevOffset", offset + jump)
	local s = WorldClock.Now()
	local h = math.floor(s.ClockTime)
	reply(player, ("Clock set to %02d:%02d, %s%s"):format(h, math.floor((s.ClockTime - h) * 60), s.Phase,
		s.Starfall and " (Starfall Night!)" or ""))
end

