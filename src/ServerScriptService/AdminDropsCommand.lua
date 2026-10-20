-- /drops: show every material in a straight row on the training ground.  /drops clear removes them.
-- Each one pops out of the sky above its spot, so you see the real drop animation too.
COMMANDS.drops = function(player, args)
	local items = ReplicatedStorage:FindFirstChild("Items")
	if not (items and items:FindFirstChild("ItemDrops")) then
		reply(player, "The material drop system isn't installed", false)
		return
	end
	local ItemDrops = require(items.ItemDrops)
	local ItemConfig = require(items.ItemConfig)
	if args[1] and string.lower(args[1]) == "clear" then
		ItemDrops.ClearAll()
		reply(player, "Drops cleared")
		return
	end
	ItemDrops.ClearAll()
	local ids = ItemConfig.SortedIds()
	local x0, x1, z = -232, -158, 40 -- training ground, in front of the dummies
	local step = (#ids > 1) and (x1 - x0) / (#ids - 1) or 0
	for i, id in ipairs(ids) do
		local spot = Vector3.new(x0 + (i - 1) * step, 40, z)
		ItemDrops.Spawn(id, spot, nil, { From = spot + Vector3.new(0, 4, 6), Lifetime = 3600, NoPickup = true })
		task.wait(0.08)
	end
	reply(player, ("Dropped all %d materials on the training ground (/drops clear to remove)"):format(#ids))
end

