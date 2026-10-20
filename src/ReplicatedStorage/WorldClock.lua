--!strict
-- POWER RUSH: WorldClock (ModuleScript in ReplicatedStorage)
-- One 24-minute day: Dawn 3 / Day 9 / Dusk 3 / Night 9 (from the Master Game Design).
-- Every 3rd night is a Starfall Night (replaces the Blood Moon idea).
-- Pure math from the shared server clock, so every player and server agrees with
-- no networking. Server and client both call WorldClock.At(workspace:GetServerTimeNow()).

local WorldClock = {}

WorldClock.CONFIG = {
	-- Phases in order. Seconds = real length. ClockFrom/ClockTo = Lighting.ClockTime range.
	PHASES = {
		{ Name = "Dawn",  Seconds = 3 * 60, ClockFrom = 5,  ClockTo = 7 },
		{ Name = "Day",   Seconds = 9 * 60, ClockFrom = 7,  ClockTo = 17 },
		{ Name = "Dusk",  Seconds = 3 * 60, ClockFrom = 17, ClockTo = 19 },
		{ Name = "Night", Seconds = 9 * 60, ClockFrom = 19, ClockTo = 29 }, -- 29 = 5am next day
	},
	-- Starfall Night: every Nth night, stars rain down and rare creatures spawn more often.
	STARFALL_EVERY = 3, -- every 3rd night (about every 72 real minutes)
	STARFALL_RARE_BOOST = 3, -- rare-and-up creatures are this many times more likely
	-- Shift the whole cycle (seconds). Change to line days up with a launch time.
	EPOCH_OFFSET = 0,
}

export type State = {
	Phase: string,
	PhaseIndex: number,
	PhaseProgress: number, -- 0..1 through the current phase
	PhaseSecondsLeft: number,
	ClockTime: number, -- 0..24, for Lighting.ClockTime
	DayNumber: number, -- counts up forever, day 1 = first day
	Starfall: boolean, -- true only during the Night phase of a Starfall day
	StarfallTonight: boolean, -- true for the whole of a Starfall day (for the hub warning)
	RareSpawnBoost: number, -- 1 normally, STARFALL_RARE_BOOST during Starfall
}

function WorldClock.DayLength(): number
	local total = 0
	for _, p in WorldClock.CONFIG.PHASES do
		total += p.Seconds
	end
	return total
end

local function isStarfallDay(day: number): boolean
	return day % WorldClock.CONFIG.STARFALL_EVERY == 0
end

function WorldClock.At(serverTime: number): State
	local length = WorldClock.DayLength()
	local t = serverTime + WorldClock.CONFIG.EPOCH_OFFSET
	local day = math.floor(t / length) + 1
	local into = t - (day - 1) * length

	local phases = WorldClock.CONFIG.PHASES
	local index, start = #phases, 0
	local acc = 0
	for i, p in phases do
		if into < acc + p.Seconds then
			index, start = i, acc
			break
		end
		acc += p.Seconds
	end
	local phase = phases[index]

	local progress = math.clamp((into - start) / phase.Seconds, 0, 1)
	local clock = phase.ClockFrom + (phase.ClockTo - phase.ClockFrom) * progress
	clock = clock % 24

	return {
		Phase = phase.Name,
		PhaseIndex = index,
		PhaseProgress = progress,
		PhaseSecondsLeft = phase.Seconds - (into - start),
		ClockTime = clock,
		DayNumber = day,
		Starfall = phase.Name == "Night" and isStarfallDay(day),
		StarfallTonight = isStarfallDay(day),
		RareSpawnBoost = (phase.Name == "Night" and isStarfallDay(day)) and WorldClock.CONFIG.STARFALL_RARE_BOOST or 1,
	}
end

-- The clock everyone should use. Adds the test offset set by the /time command
-- (attribute "DevOffset" on this module; 0 in normal play).
function WorldClock.Offset(): number
	local ok, v = pcall(function() return (script :: any):GetAttribute("DevOffset") end)
	return (ok and type(v) == "number") and v or 0
end

function WorldClock.Now(): State
	return WorldClock.At(workspace:GetServerTimeNow() + WorldClock.Offset())
end

-- Seconds from serverTime until the clock next reads `hour` (0-24). Used by /time 18.
function WorldClock.SecondsUntilHour(serverTime: number, hour: number): number
	hour = hour % 24
	local step = 2
	local prev = WorldClock.At(serverTime).ClockTime
	for s = step, WorldClock.DayLength() + step, step do
		local c = WorldClock.At(serverTime + s).ClockTime
		local passed = (prev <= hour and c >= hour) or (c < prev and (hour >= prev or hour <= c))
		if passed then return s end
		prev = c
	end
	return 0
end

-- Seconds from serverTime until the next Starfall night begins (0 if one is on now).
function WorldClock.SecondsUntilStarfall(serverTime: number): number
	if WorldClock.At(serverTime).Starfall then return 0 end
	local length = WorldClock.DayLength()
	local t = serverTime + WorldClock.CONFIG.EPOCH_OFFSET
	local day = math.floor(t / length) + 1
	local nightStart = 0
	for _, p in WorldClock.CONFIG.PHASES do
		if p.Name == "Night" then break end
		nightStart += p.Seconds
	end
	for d = day, day + WorldClock.CONFIG.STARFALL_EVERY + 1 do
		if isStarfallDay(d) then
			local s = (d - 1) * length + nightStart - t
			if s > 0 then return s end
		end
	end
	return 0
end

-- Seconds from serverTime until the next start of the named phase.
function WorldClock.SecondsUntil(serverTime: number, phaseName: string): number
	local length = WorldClock.DayLength()
	local t = serverTime + WorldClock.CONFIG.EPOCH_OFFSET
	local into = t % length
	local acc = 0
	for _, p in WorldClock.CONFIG.PHASES do
		if p.Name == phaseName then
			local d = acc - into
			if d <= 0 then
				d += length
			end
			return d
		end
		acc += p.Seconds
	end
	error("WorldClock: unknown phase " .. phaseName)
end

return WorldClock
