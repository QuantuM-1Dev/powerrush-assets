-- POWER RUSH: ItemConfig (ModuleScript in ReplicatedStorage > Items)
-- Every material, one line each. Icons come from ReplicatedStorage > Icons > Items[<Id>]
-- (and Icons > IndexLocked[<Id>] for the dark Index version), so art is pasted there, not here.
--
-- RULE (same as swords and creatures): never rename an Id once players can own it.
-- Change DisplayName instead.
--
-- Rarities were suggested on 20 Oct 2026; change any of them freely.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = {}

ItemConfig.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
ItemConfig.CATEGORIES = { "Material" }

-- Cash a material sells for, by rarity (used when an item has no SellPrice of its own)
ItemConfig.SELL_BY_RARITY = { Common = 15, Uncommon = 40, Rare = 120, Epic = 400, Legendary = 1500, Mythic = 6000 }

ItemConfig.Items = {
	-- Common
	OldBoot      = { DisplayName = "Old Boot",      Rarity = "Common",    Category = "Material", Description = "Smells like adventure. And feet." },
	RustyBolt    = { DisplayName = "Rusty Bolt",    Rarity = "Common",    Category = "Material", Description = "Holds things together. Barely." },
	NailedPlank  = { DisplayName = "Nailed Plank",  Rarity = "Common",    Category = "Material", Description = "Watch your fingers." },
	Rope         = { DisplayName = "Rope",          Rarity = "Common",    Category = "Material", Description = "Tie it, climb it, trip on it." },
	ScrapMetal   = { DisplayName = "Scrap Metal",   Rarity = "Common",    Category = "Material", Description = "One player's junk..." },
	GlassBottle  = { DisplayName = "Glass Bottle",  Rarity = "Common",    Category = "Material", Description = "Empty, for now." },
	-- Uncommon
	CopperWire   = { DisplayName = "Copper Wire",   Rarity = "Uncommon",  Category = "Material", Description = "Shiny and slightly buzzy." },
	Battery      = { DisplayName = "Battery",       Rarity = "Uncommon",  Category = "Material", Description = "Still has a little power left." },
	LeatherScroll = { DisplayName = "Leather Scroll", Rarity = "Uncommon", Category = "Material", Description = "Rolled up tight. What's inside?" },
	Radio        = { DisplayName = "Radio",         Rarity = "Uncommon",  Category = "Material", Description = "Only plays one song." },
	AquaOre      = { DisplayName = "Aqua Ore",      Rarity = "Uncommon",  Category = "Material", Description = "Cool to the touch." },
	-- Rare
	Toolbox      = { DisplayName = "Toolbox",       Rarity = "Rare",      Category = "Material", Description = "Everything a builder needs." },
	FancySpoons  = { DisplayName = "Fancy Spoons",  Rarity = "Rare",      Category = "Material", Description = "Too fancy for soup." },
	-- Epic
	GemGear      = { DisplayName = "Gem Gear",      Rarity = "Epic",      Category = "Material", Description = "A gear with a gem heart." },
	-- Legendary
	Hourglass    = { DisplayName = "Hourglass",     Rarity = "Legendary", Category = "Material", Description = "The sand flows upward." },
	MagicSeed    = { DisplayName = "Magic Seed",    Rarity = "Legendary", Category = "Material", Description = "Something wants to grow." },
	-- Mythic
	GlitchCube   = { DisplayName = "Glitch Cube",   Rarity = "Mythic",    Category = "Material", Description = "It shouldn't exist." },
}

function ItemConfig.Get(id)
	return ItemConfig.Items[id]
end

function ItemConfig.SellPrice(id)
	local def = ItemConfig.Items[id]
	if not def then return 0 end
	return def.SellPrice or ItemConfig.SELL_BY_RARITY[def.Rarity] or 0
end

function ItemConfig.Color(rarity)
	local ok, TraitConfig = pcall(require, ReplicatedStorage:WaitForChild("TraitConfig"))
	return ok and TraitConfig.GetRarityColor(rarity) or Color3.new(1, 1, 1)
end

-- ids sorted Common -> Mythic, then by name (for showcases and lists)
function ItemConfig.SortedIds()
	local rank = {}
	for i, r in ipairs(ItemConfig.RARITIES) do rank[r] = i end
	local ids = {}
	for id in pairs(ItemConfig.Items) do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local ra, rb = rank[ItemConfig.Items[a].Rarity] or 0, rank[ItemConfig.Items[b].Rarity] or 0
		if ra ~= rb then return ra < rb end
		return a < b
	end)
	return ids
end

-- Returns a list of problems (empty = all good).
--   for _,p in require(game.ReplicatedStorage.Items.ItemConfig).Validate() do warn(p) end
function ItemConfig.Validate()
	local problems = {}
	local okRarity = {}
	for _, r in ipairs(ItemConfig.RARITIES) do okRarity[r] = true end
	for id, item in pairs(ItemConfig.Items) do
		if not string.match(id, "^%a[%w]*$") then table.insert(problems, id .. ": Id must be letters/numbers and start with a letter") end
		if not okRarity[item.Rarity] then table.insert(problems, id .. ": unknown Rarity '" .. tostring(item.Rarity) .. "'") end
		if type(item.DisplayName) ~= "string" or item.DisplayName == "" then table.insert(problems, id .. ": missing DisplayName") end
	end
	table.sort(problems)
	return problems
end

return ItemConfig
