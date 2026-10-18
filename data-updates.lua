-- Tiers for faster belts: every transport belt faster than express (Space Age's turbo belt, Krastorio 2's, ...) gets
-- a chain post tier that moves as much (items a second = belt speed x 480), made from the tier before and that belt,
-- unlocked with it. Here, not in data.lua: every mod's belts are defined by now. (Up to S.MAX_TIERS; belts of the
-- same speed share a tier.) The finished tier table reaches control.lua as the "chl-tiers" mod-data.
local S = require("shared")
local P = require("prototypes.posts")

local belts = {}
for name, b in pairs(data.raw["transport-belt"]) do
  local per_s = (b.speed or 0) * 480
  if not b.hidden and per_s > 45 + 1e-6 then belts[#belts + 1] = { name = name, per_s = per_s, belt = b } end
end
table.sort(belts, function(a, b)
  if math.abs(a.per_s - b.per_s) > 1e-6 then return a.per_s < b.per_s end
  return a.name < b.name
end)

-- the item that places a belt, and the technology that unlocks a recipe making it
local function item_of(b)
  local m = b.minable
  local name = m and (m.result or (m.results and m.results[1] and m.results[1].name))
  return name and data.raw.item[name] and name
end

local function tech_for(item)
  local recipes = {}
  for rname, r in pairs(data.raw.recipe) do
    for _, res in pairs(r.results or {}) do
      if res.name == item then recipes[rname] = true end
    end
  end
  for tname, t in pairs(data.raw.technology) do
    for _, e in pairs(t.effects or {}) do
      if e.type == "unlock-recipe" and recipes[e.recipe] then return tname end
    end
  end
end

local last = -1
for _, b in ipairs(belts) do
  if #S.POSTS >= S.MAX_TIERS then
    log("chain-logistics: no tier left for " .. b.name .. " (" .. b.per_s .. "/s): it gets the fastest one")
  elseif math.abs(b.per_s - last) > 1e-6 then
    last = b.per_s
    local t = #S.POSTS + 1
    S.TIERS[t] = S.belt_tier(b.per_s)
    S.POSTS[t] = "chl-chain-post-" .. t
    local item = item_of(b.belt)
    local ingredients = { { type = "item", name = S.POSTS[t - 1], amount = 1 } }
    ingredients[2] = item and { type = "item", name = item, amount = 5 } or { type = "item", name = "iron-gear-wheel", amount = 20 }
    P.make(t, { enabled = false, ingredients = ingredients }, item and tech_for(item),
      { "chl.post-for", b.belt.localised_name or { "entity-name." .. b.name } })
    data.raw["simple-entity-with-owner"][S.POSTS[t - 1]].next_upgrade = S.POSTS[t]
  end
end

-- a name pastes (shift-click) from any post to any post
for _, name in ipairs(S.POSTS) do
  data.raw["simple-entity-with-owner"][name].additional_pastable_entities = S.POSTS
end

data:extend({ { type = "mod-data", name = "chl-tiers", data = { tiers = S.TIERS, posts = S.POSTS } } })
