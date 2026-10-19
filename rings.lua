-- Reach markers while placing: a player holding a post or pulley (the item, a ghost of one, or a blueprint or
-- blueprint-book page with one in it) sees the farthest tile the previous post reaches in each of 8 directions (N, NE,
-- E, ... at its own quality's range), as dim squares, like show-max-underground-distance marks an underground's reach.
-- Hovering a spot brightens its square and says how far it is. The previous post: the node this player placed last,
-- else the one nearest them. Only that player sees them; they go when the cursor holds something else.
-- (Scripts can't read the mouse position, so each spot has an invisible entity to hover: chl-reach-spot, data.lua.)
local S = require("shared")

local G = {}
local NODES = {} -- entity (and item) names of posts and pulleys
for _, n in ipairs(S.POSTS) do NODES[n] = true end
NODES[S.PULLEY] = true
local NODE_LIST = {}
for n in pairs(NODES) do NODE_LIST[#NODE_LIST + 1] = n end
local SPOT = "chl-reach-spot"

local NEAR = 96 -- with no post placed by this player, the nearest node this close
local MOVE = 16 -- (the nearest node is looked for again once the player moves this far)
local DIM = { 0.35, 0.3, 0.04, 0.35 } -- (tints are premultiplied: yellow at 35%)
local BRIGHT = { 1, 0.85, 0.1, 1 }
local DIRS = { { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 } }

local function st()
  storage.reach = storage.reach or {} -- player index -> {anchor, x, y, surface, marks = {{spot, sprite, d}}, lit}
  storage.last_node = storage.last_node or {} -- player index -> unit of the node they placed last
  storage.spot_of = storage.spot_of or {} -- spot unit -> {player index, mark index}
  return storage.reach
end

local function has_node(entities)
  for _, e in pairs(entities or {}) do
    if NODES[e.name] then return true end
  end
  return false
end

-- whether a blueprint-like thing (an item stack) has a post or pulley in it
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
  local r = st()[index]
  if not r then return end
  for _, m in pairs(r.marks) do
    if m.sprite.valid then m.sprite.destroy() end
    if m.text and m.text.valid then m.text.destroy() end
    if m.spot.valid then
      storage.spot_of[m.spot.unit_number] = nil
      m.spot.destroy()
    end
  end
  storage.reach[index] = nil
end

-- the node the markers are for: the one this player placed last, else the nearest
local function anchor(player)
  local u = storage.last_node[player.index]
  local p = u and storage.posts[u]
  if p and p.e.valid and p.e.surface == player.surface then return p.e, true end
  local best, bd
  for _, e in pairs(player.surface.find_entities_filtered({ name = NODE_LIST, position = player.position, radius = NEAR })) do
    if storage.posts[e.unit_number] and (e.force == player.force or player.force.get_friend(e.force)) then
      local d = (e.position.x - player.position.x) ^ 2 + (e.position.y - player.position.y) ^ 2
      if not bd or d < bd then best, bd = e, d end
    end
  end
  return best, false
end

local function draw(player)
  clear(player.index)
  local e, placed = anchor(player)
  if not e then return end
  local range = S.range(e.quality.level)
  local straight, diag = math.floor(range + 1e-6), math.floor(range / math.sqrt(2) + 1e-6)
  local marks = {}
  for i, d in ipairs(DIRS) do
    local k = (d[1] ~= 0 and d[2] ~= 0) and diag or straight
    local pos = { x = e.position.x + d[1] * k, y = e.position.y + d[2] * k }
    local spot = e.surface.create_entity({ name = SPOT, position = pos, force = player.force, create_build_effect_smoke = false })
    if spot then
      spot.destructible = false
      spot.minable = false
      storage.spot_of[spot.unit_number] = { player.index, i }
      marks[#marks + 1] = {
        spot = spot,
        dist = math.sqrt((d[1] * k) ^ 2 + (d[2] * k) ^ 2),
        sprite = rendering.draw_sprite({ sprite = "chl-reach-marker", target = pos, surface = e.surface, tint = DIM,
          players = { player.index }, render_layer = "light-effect" }),
      }
    end
  end
  st()[player.index] = { anchor = e.unit_number, placed = placed, x = player.position.x, y = player.position.y,
    surface = player.surface.index, marks = marks }
end

-- show or hide a player's markers for what their cursor holds now
function G.update(player)
  if not (player and player.valid) then return end
  if G.holding(player) then draw(player) else clear(player.index) end
end

function G.on_cursor_changed(ev) G.update(game.get_player(ev.player_index)) end

function G.on_moved(ev)
  local r = st()[ev.player_index]
  if not r or r.placed then return end -- (markers on a post the player placed stay put)
  local player = game.get_player(ev.player_index)
  local p = player.position
  if player.surface.index ~= r.surface or (p.x - r.x) ^ 2 + (p.y - r.y) ^ 2 > MOVE * MOVE then draw(player) end
end

function G.on_left(ev) clear(ev.player_index) end

-- hovering a spot lights its marker and says how far it is from the post
function G.on_selected(ev)
  local player = game.get_player(ev.player_index)
  local r = st()[ev.player_index]
  if not r then return end
  if r.lit then
    local m = r.marks[r.lit]
    if m then
      if m.sprite.valid then m.sprite.color = DIM end
      if m.text and m.text.valid then m.text.destroy() end
      m.text = nil
    end
    r.lit = nil
  end
  local sel = player.selected
  local owner = sel and sel.valid and sel.name == SPOT and storage.spot_of[sel.unit_number]
  if owner and owner[1] == player.index then
    local m = r.marks[owner[2]]
    if m then
      if m.sprite.valid then m.sprite.color = BRIGHT end
      m.text = rendering.draw_text({ text = { "chl.reach-tiles", string.format("%.0f", m.dist) }, target = { entity = sel, offset = { 0, 0.6 } },
        surface = sel.surface, color = BRIGHT, scale = 1.6, alignment = "center", players = { player.index } })
      -- (below the square: the post ghost in the cursor covers what's above it)
      r.lit = owner[2]
    end
  end
end

-- a node was built or removed: a player's own new node becomes their previous post; markers redrawn for everyone
-- holding one
function G.nodes_changed(entity, player_index)
  st()
  if entity and player_index and entity.valid and NODES[entity.name] then storage.last_node[player_index] = entity.unit_number end
  for index in pairs(storage.reach) do
    local player = game.get_player(index)
    if player and player.valid then draw(player) else clear(index) end
  end
end

-- (for tests) how many markers a player sees, the unit they are around, how many are lit
function G.count(index)
  local r = st()[index]
  return { marks = r and #r.marks or 0, anchor = r and r.anchor, lit = r and r.lit }
end

return G
