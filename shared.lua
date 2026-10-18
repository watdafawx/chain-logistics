-- numbers data.lua and control.lua (and art/build.py) agree on
return {
  CHAIN_Z = 1.95, -- chain height above the ground, in tiles (art/build.py's CHAIN_Z)
  LIFT = 1.95 * 0.7071, -- how far up the screen that height shows (the art's camera looks down at 45 degrees)
  SHADOW = 1.95, -- the chain's shadow lies this far east of it on the ground (the art's sun: 45 degrees, from the west)
  R = 0.36, -- a strand's distance from the post's centre (the sprocket's chain ring)
  SQUASH = 0.7071, -- the camera's foreshortening of north-south offsets around a post
  SPEED = 0.05, -- tiles a tick a package rides at tier 1 (3 tiles/s): the chain sprites crawl at this speed
  RANGE = 16, -- longest span, tiles
  REACH = 1.0, -- a post serves the logistic chests it stands within this far of (its 8 neighbours for a 1x1 chest)
  -- per tier: items a package (times the map setting), ticks between a post's packages, tiles a tick. About a
  -- yellow / red / blue belt's 15 / 30 / 45 items/s a post; only tier 1 has a post yet
  TIERS = {
    { package = 8, cooldown = 32, speed = 0.05 },
    { package = 15, cooldown = 30, speed = 0.075 },
    { package = 30, cooldown = 40, speed = 0.1 },
  },
  LINK_PAIR = 0.5, -- the span sprite crawls this far over its 8 frames (one lit pattern: 4 links)
  RING = 0.377, -- and the post's chain ring this far (60 degrees at R)
}
