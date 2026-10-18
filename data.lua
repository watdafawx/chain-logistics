local S = require("shared")
local skin = settings.startup["chl-skin"].value
local sprites = require("prototypes.sprites")[skin]
local G = "__chain-logistics__/graphics/"
local E = G .. "entity/" .. skin .. "/"
local ICON = G .. "icons/" .. skin .. "/"

local function anim(name, speed, extra)
  local s = sprites[name]
  local a = {
    filename = E .. name:gsub("_", "-") .. ".png",
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
local GLOW = { draw_as_light = true }
local SHADOW = { draw_as_shadow = true }

-- the frames' chain moves LINK_PAIR / RING a cycle of 8: at SPEED, so many frames a tick
local span_speed = S.SPEED * 8 / S.LINK_PAIR
local ring_speed = S.SPEED * 8 / S.RING

data:extend({
  {
    type = "item",
    name = "chl-chain-post",
    icon = ICON .. "post.png",
    icon_size = 64,
    subgroup = "logistic-network",
    order = "z[chain]-a[post]",
    place_result = "chl-chain-post",
    stack_size = 50,
  },
  {
    type = "recipe",
    name = "chl-chain-post",
    enabled = true,
    energy_required = 1,
    ingredients = { { type = "item", name = "iron-plate", amount = 4 }, { type = "item", name = "iron-gear-wheel", amount = 2 } },
    results = { { type = "item", name = "chl-chain-post", amount = 1 } },
  },
  {
    type = "simple-entity-with-owner",
    name = "chl-chain-post",
    icon = ICON .. "post.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.2, result = "chl-chain-post" },
    max_health = 150,
    collision_box = { { -0.25, -0.25 }, { 0.25, 0.25 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    drawing_box_vertical_extension = 1.5,
    animations = {
      layers = {
        anim("post", ring_speed),
        anim("post_glow", ring_speed, GLOW),
        anim("post_shadow", ring_speed, SHADOW),
      },
    },
  },
  {
    -- a package on its way along one span: the engine moves it, the script only hears when it gets there
    type = "projectile",
    name = "chl-package",
    icon = ICON .. "package.png",
    icon_size = 64,
    flags = { "not-on-map" },
    hidden = true,
    acceleration = 0,
    rotatable = false,
    height = 0, -- (projectiles draw a tile up by default; the art already holds the chain's height)
    hit_collision_mask = { layers = {} },
    animation = { layers = { anim("package", 0.15), anim("package_glow", 0.15, GLOW) } },
    shadow = anim("package_shadow", 0.15, SHADOW),
    final_action = {
      type = "direct",
      action_delivery = { type = "instant", target_effects = { { type = "script", effect_id = "chl-arrive" } } },
    },
  },
  {
    type = "animation",
    name = "chl-span",
    layers = { anim("span", span_speed), anim("span_glow", span_speed, GLOW) },
  },
  {
    -- (its shadow: the same links, tinted dark by the script; no glow)
    type = "animation",
    name = "chl-span-shadow",
    layers = { anim("span", span_speed) },
  },
})
