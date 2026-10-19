-- Range rings while placing: a player holding a post or pulley (the item, a ghost of one, or a blueprint or
-- blueprint-book page with one in it) sees the span range of every post and pulley around them, at each one's own
-- quality, the way vanilla shows every pole's supply area while you hold a pole. Only that player sees them; they go
-- when the cursor holds something else. (The prototype's own ring, data.lua, only shows a normal post's range.)
local S = require("shared")

local G = {}
local NODES = {} -- entity (and item) names of posts and pulleys
for _, n in ipairs(S.POSTS) do NODES[n] = true end
NODES[S.PULLEY] = true
local NODE_LIST = {}
for n in pairs(NODES) do NODE_LIST[#NODE_LIST + 1] = n end

local RADIUS = 96 -- rings for the nodes this close to the player
local MOVE = 24 -- redrawn once the player moves this far from where they were drawn
local CAP = 400 -- at most this many rings a player
local TINT = { magenta = { 1, 0.1, 0.6 }, toxic = { 0.3, 1, 0.15 }, orange = { 1, 0.35, 0 }, red = { 1, 0.1, 0.1 } }

local function color()
  local c = TINT[settings.startup["chl-skin"].value] or TINT.magenta
  return { c[1] * 0.75, c[2] * 0.75, c[3] * 0.75, 0.75 }
end

local function has_node(entities)
  for _, e in pairs(entities or {}) do
    if NODES[e.name] then return true end
  end
  return false
end

-- whether a blueprint-like thing (an item stack or a library record) has a post or pulley in it
local function blueprint_has(bp)
  if not bp then return false end
  if bp.is_blueprint then
    return bp.is_blueprint_setup() and has_node(bp.get_blueprint_entities())
  end
  if bp.is_blueprint_book then
    local inv = bp.get_inventory(defines.inventory.item_main)
    local page = inv and bp.active_index and inv[bp.active_index]
    return page ~= nil and page.valid_for_read and blueprint_has(page)
  end
  return false
end

function G.holding(player)
  local cs = player.cursor_stack
  if cs and cs.valid_for_read then
    if NODES[cs.name] then return true end
    if blueprint_has(cs) then return true end
  end
  local ghost = player.cursor_ghost
  if ghost and ghost.name and NODES[ghost.name.name or ghost.name] then return true end
  local ok, rec = pcall(function() return player.cursor_record end)
  if ok and rec and rec.valid then
    local ok2, has = pcall(function()
      if rec.type == "blueprint" then return has_node(rec.get_blueprint_entities()) end
      return false
    end)
    if ok2 and has then return true end
  end
  return false
end

local function clear(index)
  local r = storage.rings and storage.rings[index]
  if not r then return end
  for _, o in pairs(r.objs) do if o.valid then o.destroy() end end
  storage.rings[index] = nil
end

local function draw(player)
  clear(player.index)
  local pos, surface = player.position, player.surface
  local objs = {}
  local col = color()
  for _, e in pairs(surface.find_entities_filtered({ name = NODE_LIST, position = pos, radius = RADIUS })) do
    if #objs >= CAP then break end
    if e.force == player.force or player.force.get_friend(e.force) then
      objs[#objs + 1] = rendering.draw_circle({
        color = col, radius = S.range(e.quality.level), width = 2, filled = false, target = e, surface = surface,
        players = { player.index }, draw_on_ground = true,
      })
    end
  end
  storage.rings = storage.rings or {}
  storage.rings[player.index] = { objs = objs, x = pos.x, y = pos.y, surface = surface.index }
end

-- show or hide a player's rings for what their cursor holds now
function G.update(player)
  if not (player and player.valid) then return end
  if G.holding(player) then draw(player) else clear(player.index) end
end

function G.on_cursor_changed(ev) G.update(game.get_player(ev.player_index)) end

function G.on_moved(ev)
  local r = storage.rings and storage.rings[ev.player_index]
  if not r then return end
  local player = game.get_player(ev.player_index)
  local p = player.position
  if player.surface.index ~= r.surface or (p.x - r.x) ^ 2 + (p.y - r.y) ^ 2 > MOVE * MOVE then draw(player) end
end

function G.on_left(ev) clear(ev.player_index) end

-- a node was built or removed: redrawn for everyone holding one (so the new post's ring shows straight away)
function G.nodes_changed()
  for index in pairs(storage.rings or {}) do
    local player = game.get_player(index)
    if player and player.valid then draw(player) else clear(index) end
  end
end

-- (for tests) how many rings a player sees
function G.count(index)
  local r = storage.rings and storage.rings[index]
  return r and #r.objs or 0
end

return G
