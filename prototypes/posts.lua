-- data stage: the sprite helpers, and making tier t's chain post (data.lua makes tiers 1-3, data-updates.lua the
-- ones for faster modded belts)
local S = require("shared")
local skin = settings.startup["chl-skin"].value
local sprites = require("prototypes.sprites")[skin]
local G = "__chain-logistics__/graphics/"

local P = {}
P.E = G .. "entity/" .. skin .. "/"
P.ICON = G .. "icons/" .. skin .. "/"

function P.anim(name, speed, extra)
  local s = sprites[name]
  local a = {
    filename = P.E .. name:gsub("_", "-") .. ".png",
    priority = "high",
    width = s.width,
    height = s.height,
    shift = s.shift,
    frame_count = s.frame_count,
    line_length = s.line_length,
    animation_speed = speed,
    scale = 0.5,
  }
  for k, v in pairs(extra or {}) do a[k] = v end
  return a
end

-- the lit parts, as light: they glow in the dark (drawn over the sprite in daylight too, they'd wash it out white)
P.GLOW = { draw_as_light = true }
P.SHADOW = { draw_as_shadow = true }

-- the frames' chain moves LINK_PAIR (a span) / RING (a post) a cycle of 8: at a tier's speed, so many frames a tick
function P.span_speed(t) return S.TIERS[t].speed * 8 / S.LINK_PAIR end
function P.ring_speed(t) return S.TIERS[t].speed * 8 / S.RING end

-- tier t's post, item, recipe (r: {enabled, category, ingredients}) and span animations; tech: the technology that
-- unlocks it (none or missing: enabled from the start). S.TIERS[t] must be set
function P.make(t, r, tech, localised_name)
  local name = S.POSTS[t]
  local icon = P.ICON .. "post" .. t .. ".png"
  data:extend({
    {
      type = "item",
      name = name,
      localised_name = localised_name,
      icon = icon,
      icon_size = 64,
      subgroup = "logistic-network",
      order = "z[chain]-a[post]-" .. t,
      place_result = name,
      stack_size = 50,
    },
    {
      type = "recipe",
      name = name,
      enabled = r.enabled,
      category = r.category,
      energy_required = 1,
      ingredients = r.ingredients,
      results = { { type = "item", name = name, amount = 1 } },
    },
    {
      type = "simple-entity-with-owner",
      name = name,
      localised_name = localised_name,
      icon = icon,
      icon_size = 64,
      flags = { "placeable-neutral", "player-creation" },
      minable = { mining_time = 0.2, result = name },
      max_health = 150,
      collision_box = { { -0.25, -0.25 }, { 0.25, 0.25 } },
      selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
      drawing_box_vertical_extension = 1.5,
      fast_replaceable_group = "chl-chain-post",
      next_upgrade = S.POSTS[t + 1],
      animations = {
        layers = {
          P.anim("post" .. t, P.ring_speed(t)),
          P.anim("post" .. t .. "_glow", P.ring_speed(t), P.GLOW),
          P.anim("post" .. t .. "_shadow", P.ring_speed(t), P.SHADOW),
        },
      },
    },
    {
      -- a span between posts of this tier (or this and a faster one): its links crawl at the tier's speed
      type = "animation",
      name = "chl-span-" .. t,
      layers = { P.anim("span", P.span_speed(t)), P.anim("span_glow", P.span_speed(t), P.GLOW) },
    },
    {
      -- (its shadow: the same links, tinted dark by the script; no glow)
      type = "animation",
      name = "chl-span-shadow-" .. t,
      layers = { P.anim("span", P.span_speed(t)) },
    },
  })
  local tt = tech and data.raw.technology[tech]
  if tt then
    tt.effects = tt.effects or {}
    table.insert(tt.effects, { type = "unlock-recipe", recipe = name })
  elseif not r.enabled then
    data.raw.recipe[name].enabled = true -- (no such technology: a mod took it away)
  end
end

return P
