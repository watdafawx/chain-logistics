-- belts faster than express, as a mod pack has them: two at 60/s (one tier between them), one at 75/s, unlocked by
-- a technology of their own
local function belt(name, speed)
  local b = table.deepcopy(data.raw["transport-belt"]["express-transport-belt"])
  b.name, b.speed, b.next_upgrade = name, speed, nil
  b.minable = { mining_time = 0.1, result = name }
  local i = table.deepcopy(data.raw.item["express-transport-belt"])
  i.name, i.place_result = name, name
  local r = { type = "recipe", name = name, enabled = false, ingredients = { { type = "item", name = "iron-plate", amount = 1 } },
    results = { { type = "item", name = name, amount = 1 } } }
  return b, i, r
end
local all = {}
for _, spec in ipairs({ { "chl-test-belt-a", 0.125 }, { "chl-test-belt-b", 0.125 }, { "chl-test-belt-c", 0.15625 } }) do
  for _, p in ipairs({ belt(spec[1], spec[2]) }) do all[#all + 1] = p end
end
all[#all + 1] = { type = "technology", name = "chl-test-belts", icon = "__base__/graphics/technology/logistics-3.png", icon_size = 256,
  effects = { { type = "unlock-recipe", recipe = "chl-test-belt-a" }, { type = "unlock-recipe", recipe = "chl-test-belt-c" } },
  unit = { count = 1, ingredients = { { "automation-science-pack", 1 } }, time = 1 } }
data:extend(all)
