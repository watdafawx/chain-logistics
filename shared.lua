-- numbers data.lua and control.lua (and art/build.py) agree on
local M = {
  CHAIN_Z = 1.95, -- chain height above the ground, in tiles (art/build.py's CHAIN_Z)
  LIFT = 1.95 * 0.7071, -- how far up the screen that height shows (the art's camera looks down at 45 degrees)
  SHADOW = 1.95, -- the chain's shadow lies this far east of it on the ground (the art's sun: 45 degrees, from the west)
  R = 0.36, -- a strand's distance from the post's centre (the sprocket's chain ring)
  SQUASH = 0.7071, -- the camera's foreshortening of north-south offsets around a post
    RANGE = 16, -- longest span, tiles
  REACH = 1.0, -- a post serves the logistic chests it stands within this far of (its 8 neighbours for a 1x1 chest)
  -- per tier: items a package (times the map setting), ticks between a post's packages, tiles a tick. About a
  -- yellow / red / blue belt's 15 / 30 / 45 items/s a post. A span runs at its slower post's tier
  -- (speeds are whole 1/256ths of a tile: a projectile's speed is floored to one, so the chain sprites crawl exactly
  -- as fast as the packages ride. About 0.05, 0.075, 0.1)
  TIERS = {
    { package = 8, cooldown = 32, speed = 13 / 256 },
    { package = 15, cooldown = 30, speed = 19 / 256 },
    { package = 30, cooldown = 40, speed = 26 / 256 },
  },
  -- per quality level (normal 0 ... legendary 5) of a post: more items a package (+30% a level), longer spans (tiles),
  -- a longer reach to chests (tiles), faster chains (a span runs at its lower-quality post's level)
  QUALITY = { throughput = 0.3, range = 2, reach = 0.5, speed = 0.15 },
  POSTS = { "chl-chain-post", "chl-chain-post-2", "chl-chain-post-3" }, -- tier t's post
  MAX_TIERS = 6, -- tiers past 3 match modded belts faster than express (data-updates.lua; art/build.py renders 6)
  PULLEY = "chl-chain-pulley", -- a node that only bends a line: no tier, no chests, no cooldown
  LINK_PAIR = 0.5, -- the span sprite crawls this far over its 8 frames (one lit pattern: 4 links)
  RING = 0.377, -- and the post's chain ring this far (60 degrees at R)
}

-- a span's projectile speed at a tier and quality level: whole 1/256ths of a tile a tick (the engine floors it to one)
function M.span_speed(tier, level)
  local base = math.floor(M.TIERS[tier].speed * 256 + 0.5)
  return math.floor(base * (1 + M.QUALITY.speed * level) + 1e-6) / 256
end

-- a post's longest span and its reach to chests (tiles) at a quality level
function M.range(level) return M.RANGE + M.QUALITY.range * level end
function M.reach(level) return M.REACH + M.QUALITY.reach * level end

-- a tier for a belt moving per_s items a second (speed x 480): a package every 40 ticks holding that much, riding a
-- little faster per tier the way 13 / 19 / 26 do for 15 / 30 / 45
function M.belt_tier(per_s)
  return { package = math.ceil(per_s * 40 / 60 - 1e-6), cooldown = 40,
    speed = math.floor(13 + (per_s - 15) * 13 / 30 + 1e-6) / 256, items_per_second = per_s }
end

-- (control stage: the tier table data-updates.lua finished, with the modded belts' tiers, comes in a mod-data
-- prototype; in the data stages there is no `prototypes`)
local ok, md = pcall(function() return prototypes.mod_data["chl-tiers"] end)
if ok and md then M.TIERS, M.POSTS = md.data.tiers, md.data.posts end

return M
