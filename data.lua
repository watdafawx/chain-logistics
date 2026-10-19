local S = require("shared")
local P = require("prototypes.posts")
local anim, GLOW, SHADOW, ring_speed, ICON = P.anim, P.GLOW, P.SHADOW, P.ring_speed, P.ICON

-- tier t's post: like belts, each tier is made from the one before and upgrades it in place (tiers for faster
-- modded belts: data-updates.lua)
local RECIPES = {
  { enabled = true, ingredients = { { type = "item", name = "iron-plate", amount = 4 }, { type = "item", name = "iron-gear-wheel", amount = 2 } } },
  { enabled = false, ingredients = { { type = "item", name = "chl-chain-post", amount = 1 }, { type = "item", name = "iron-gear-wheel", amount = 5 } } },
  { enabled = false, category = "crafting-with-fluid", ingredients = { { type = "item", name = "chl-chain-post-2", amount = 1 },
    { type = "item", name = "iron-gear-wheel", amount = 10 }, { type = "fluid", name = "lubricant", amount = 20 } } },
}
local TECH = { nil, "logistics-2", "logistics-3" } -- (where fast / express belts unlock)

for t = 1, #S.POSTS do P.make(t, RECIPES[t], TECH[t]) end

-- a pulley: a cheap node that only bends a line (the chain wraps round it; packages pass without stopping)
data:extend({
  {
    type = "item",
    name = S.PULLEY,
    icon = ICON .. "pulley.png",
    icon_size = 64,
    subgroup = "logistic-network",
    order = "z[chain]-b[pulley]",
    place_result = S.PULLEY,
    stack_size = 50,
  },
  {
    type = "recipe",
    name = S.PULLEY,
    enabled = true,
    energy_required = 0.5,
    ingredients = { { type = "item", name = "iron-plate", amount = 2 }, { type = "item", name = "iron-gear-wheel", amount = 1 } },
    results = { { type = "item", name = S.PULLEY, amount = 1 } },
  },
  {
    type = "simple-entity-with-owner",
    name = S.PULLEY,
    icon = ICON .. "pulley.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.1, result = S.PULLEY },
    max_health = 100,
    collision_box = { { -0.25, -0.25 }, { 0.25, 0.25 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    drawing_box_vertical_extension = 1.5,
    radius_visualisation_specification = P.range_ring(),
    -- (its ring turns at a tier-1 chain's speed: it has no tier of its own)
    animations = {
      layers = {
        anim("pulley", ring_speed(1)),
        anim("pulley_glow", ring_speed(1), GLOW),
        anim("pulley_shadow", ring_speed(1), SHADOW),
      },
    },
  },
})

data:extend({
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
})

-- loaders and unloaders: chests a post serves, filled and emptied by vanilla inserters. A loader ships what it holds
-- (to the unloader its address names, else to whatever chest asks for it); an unloader is a requester that also
-- takes addressed packages. (Graphics: tinted vanilla chests for now)
local LOADER_TINT = { 0.45, 1, 1 }
local UNLOADER_TINT = { 1, 0.45, 1 }

local function tinted(icon_of, tint)
  return { { icon = icon_of.icon, icon_size = icon_of.icon_size or 64, tint = tint } }
end

-- every layer of a sprite (or animation) but the shadow, tinted
local function tint_layers(sprite, tint)
  for _, l in pairs(sprite.layers or { sprite }) do
    if not l.draw_as_shadow then l.tint = tint end
  end
end

local loader = table.deepcopy(data.raw.container["iron-chest"])
loader.name = "chl-loader"
loader.icons, loader.icon = tinted(data.raw.container["iron-chest"], LOADER_TINT), nil
loader.inventory_size = 8
loader.minable = { mining_time = 0.2, result = "chl-loader" }
loader.next_upgrade = nil
tint_layers(loader.picture, LOADER_TINT)

local unloader = table.deepcopy(data.raw["logistic-container"]["requester-chest"])
unloader.name = "chl-unloader"
unloader.icons, unloader.icon = tinted(data.raw["logistic-container"]["requester-chest"], UNLOADER_TINT), nil
unloader.inventory_size = 8
unloader.max_logistic_slots = 8
unloader.trash_inventory_size = 0
unloader.minable = { mining_time = 0.2, result = "chl-unloader" }
unloader.next_upgrade = nil
tint_layers(unloader.animation, UNLOADER_TINT)

-- a name pastes (shift-click) from post to post (data-updates.lua, once every tier is made), loader to loader,
-- unloader to unloader
loader.additional_pastable_entities = { "chl-loader" }

local function item_recipe(name, icons, order)
  return {
    {
      type = "item",
      name = name,
      icons = icons,
      subgroup = "logistic-network",
      order = "z[chain]-b[" .. order .. "]",
      place_result = name,
      stack_size = 50,
    },
    {
      type = "recipe",
      name = name,
      enabled = true,
      energy_required = 0.5,
      ingredients = { { type = "item", name = "iron-chest", amount = 1 }, { type = "item", name = "iron-gear-wheel", amount = 2 } },
      results = { { type = "item", name = name, amount = 1 } },
    },
  }
end

data:extend({ loader, unloader })
data:extend(item_recipe("chl-loader", loader.icons, "a-loader"))
data:extend(item_recipe("chl-unloader", unloader.icons, "b-unloader"))

-- clicking a post opens its name window (posts have no window of their own)
data:extend({
  { type = "custom-input", name = "chl-open", key_sequence = "", linked_game_control = "open-gui" },
})

-- riding the chains: the vehicle key by a post hooks the character on; it hangs from a trolley (the package's case
-- for now)
data:extend({
  { type = "custom-input", name = "chl-ride", key_sequence = "RETURN", linked_game_control = "toggle-driving" },
  -- (linked: it takes whatever key "Enter or exit vehicle" is bound to, Enter by default)
  { type = "animation", name = "chl-trolley", layers = { anim("package", 0.15), anim("package_glow", 0.15, GLOW) } },
})
