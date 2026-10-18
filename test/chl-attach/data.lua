-- a modded logistic chest, as AAI Containers or Wide Chests make them: a copy of vanilla's, 2x2
local c = table.deepcopy(data.raw["logistic-container"]["passive-provider-chest"])
c.name = "chl-test-wide-chest"
c.minable = nil
c.collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } }
c.selection_box = { { -1, -1 }, { 1, 1 } }
data:extend({ c })
