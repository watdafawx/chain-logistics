-- Riding the chains (like Create's chain conveyors): the vehicle key by a post or pulley hooks the player's character
-- onto the chain, where it hangs from a trolley and rides the right-hand strand at the span's speed. At each post the
-- walking keys pick the next span (the one closest to the direction held; none held: it waits), and a small window
-- lists the network's named posts and unloaders: clicking one rides the shortest route there (any walking key takes
-- over again). The vehicle key again (or dying, a vehicle, the character going) drops it on the nearest free spot.
-- Cost: one teleport a tick a rider; nothing without riders.
local S = require("shared")
local N = require("names")

local R = {}
local C -- control.lua's chain: route, hop_ends, span_tier, span_level, other, nodes, pos (R.setup)

local WIN = "chl-ride"
local REACH = 2 -- hooks onto a node this close (tiles)
-- the character stands this far south of the chain's ground spot, so it's drawn hanging under the chain (the chain
-- shows LIFT up the screen; a character is about 1.6 tiles tall)
local DROP = 0.8
local TROLLEY = 0.6 -- the trolley: the package's case at this scale, just under the chain
local TURN = 0.7 -- holding a direction this close to straight back (cosine) turns round mid-span
local AHEAD = 0.2 -- at a post, a span this close to the direction held (cosine) counts; else the rider waits

-- themes (fse-std 0.6+, optional): the window in the player's theme
local theme
if script.active_mods["fse-std"] then
  local ok, t = pcall(require, "__fse-std__/theme")
  theme = ok and t.adopt and t or nil
end

function R.setup(api) C = api end

function R.init()
  -- key (player index; "c<unit>" for a player-less character, tests) -> {c = character, player = index?, node, from,
  -- to, pts = {waypoints}, x, y (on the chain, ground coordinates), speed, dest = post unit?, steer = direction?
  -- (tests), ro = {render objects}, destructible, run (its own running speed modifier)}
  storage.riders = storage.riders or {}
  storage.ride_place = storage.ride_place or {} -- player index -> where they left the window
end

-- a defines.direction as a unit vector (north is -y; 16 directions in 2.0)
local function dir_vec(d)
  local a = d / 16 * 2 * math.pi
  return math.sin(a), -math.cos(a)
end

local function unit_to(a, b)
  local p, q = C.pos(a), C.pos(b)
  local dx, dy = q.x - p.x, q.y - p.y
  local l = math.sqrt(dx * dx + dy * dy)
  return dx / l, dy / l
end

local function key_of(c, player_index) return player_index or ("c" .. c.unit_number) end

local function player_of(r) return r.player and game.get_player(r.player) end

-- the post a destination (a named post or unloader) is reached by
local function post_of(u)
  if storage.posts[u] then return u end
  local rec = storage.names[u]
  return rec and N.post_of(u, rec)
end

-- --- the window ----------------------------------------------------------------------------------------------------

local function close_window(player)
  local w = player.gui.screen[WIN]
  if w then w.destroy() end
end

-- the destinations on the rider's network, sorted by name
local function destinations(r)
  local p = storage.posts[r.node]
  if not (p and p.net) then return {} end
  local l = N.list(p.net)
  table.sort(l, function(a, b)
    if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
    return a.unit < b.unit
  end)
  return l
end

local function fill_list(player, r)
  local w = player.gui.screen[WIN]
  local list = w and w.chl_ride_inner and w.chl_ride_inner.chl_ride_body.chl_ride_list
  if not list then return end
  list.clear()
  local l = destinations(r)
  local sig = {}
  for _, d in ipairs(l) do
    local here = d.post == r.node and not r.to
    local b = list.add({ type = "button", style = "list_box_item", tags = { chl_ride_to = d.unit },
      caption = (d.post == r.dest and "> " or "") .. d.name, tooltip = { "chl.ride-to-" .. d.kind } })
    b.style.horizontally_stretchable = true
    b.enabled = not here
    sig[#sig + 1] = d.unit .. "=" .. d.name .. (here and "*" or "")
  end
  if #l == 0 then list.add({ type = "label", caption = { "chl.ride-none" } }).style.single_line = false end
  r.shown = table.concat(sig, ",") .. "|" .. tostring(r.dest)
  if theme then theme.adopt(w) end
end

-- the list again if what it would show changed (a new network, names, the destination)
local function refresh(r)
  local player = player_of(r)
  if not (player and player.gui.screen[WIN]) then return end
  local sig = {}
  for _, d in ipairs(destinations(r)) do
    sig[#sig + 1] = d.unit .. "=" .. d.name .. ((d.post == r.node and not r.to) and "*" or "")
  end
  if table.concat(sig, ",") .. "|" .. tostring(r.dest) ~= r.shown then fill_list(player, r) end
end

local function open_window(player, r)
  close_window(player)
  local f = player.gui.screen.add({ type = "frame", name = WIN, direction = "vertical" })
  local bar = f.add({ type = "flow", direction = "horizontal" })
  bar.drag_target = f
  bar.add({ type = "label", style = "frame_title", caption = { "chl.ride-title" }, ignored_by_interaction = true })
  local grip = bar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true })
  grip.style.horizontally_stretchable, grip.style.height, grip.style.minimal_width = true, 24, 24
  local inner = f.add({ type = "frame", name = "chl_ride_inner", style = "inside_shallow_frame_with_padding",
    direction = "vertical" }).add({ type = "flow", name = "chl_ride_body", direction = "vertical" })
  inner.style.vertical_spacing = 6
  local hint = inner.add({ type = "label", caption = { "chl.ride-hint" } })
  hint.style.single_line = false
  hint.style.maximal_width = 200
  local list = inner.add({ type = "scroll-pane", name = "chl_ride_list", direction = "vertical" })
  list.style.maximal_height = 300
  list.style.minimal_width = 200
  -- (the main action, pinned under the list)
  local off = f.add({ type = "button", caption = { "chl.ride-off" }, tooltip = { "chl.ride-off-tooltip" },
    tags = { chl_ride_off = true } })
  off.style.horizontally_stretchable = true
  off.style.top_margin = 4
  fill_list(player, r)
  -- (left of the screen's middle, where it doesn't hide the rider)
  f.location = storage.ride_place[player.index] or { x = math.floor(24 * player.display_scale),
    y = math.floor(player.display_resolution.height * 0.3) }
end

-- --- hanging on and off --------------------------------------------------------------------------------------------

local function draw(r)
  local c = r.c
  r.ro = {
    -- (the case's art hangs 1.125 tiles up from its spot: its middle a little under the chain)
    rendering.draw_animation({ animation = "chl-trolley", x_scale = TROLLEY, y_scale = TROLLEY, surface = c.surface,
      target = { entity = c, offset = { 0, -DROP - S.LIFT + 0.15 + 1.125 * TROLLEY } }, render_layer = "air-object" }),
  }
  -- the harness: two straps from under the trolley down to the shoulders
  local under = -DROP - S.LIFT + 0.15 + 0.17
  for _, dx in ipairs({ -0.1, 0.1 }) do
    r.ro[#r.ro + 1] = rendering.draw_line({ color = { 0.12, 0.12, 0.14 }, width = 2, surface = c.surface,
      from = { entity = c, offset = { dx * 0.5, under } }, to = { entity = c, offset = { dx * 1.6, -1.15 } },
      render_layer = "air-object" })
  end
end

local function undraw(r)
  for _, o in pairs(r.ro or {}) do if o.valid then o.destroy() end end
  r.ro = {}
end

local function place(r)
  if r.c.valid then r.c.teleport({ r.x, r.y + DROP }) end
end

-- hooks character c onto node u (player_index: its player, nil for a player-less one) -> its rider key
function R.hook(c, u, player_index)
  local key = key_of(c, player_index)
  if storage.riders[key] or not storage.posts[u] then return nil end
  local p = C.pos(u)
  -- (it waits on the post's south side, where an east-west line's strands pass)
  local r = { c = c, player = player_index, node = u, pts = {}, x = p.x, y = p.y + S.R * S.SQUASH,
    destructible = c.destructible }
  -- (it sets off at once, along the span closest to the way the character faces)
  r.hx, r.hy = dir_vec(c.direction)
  storage.riders[key] = r
  c.destructible = false -- (hanging up there: nothing on the ground reaches it)
  -- (it can't walk off: the walking keys only say where to go. Its walking state stays as the keys have it, so a key
  -- held on through posts keeps steering)
  r.run = c.character_running_speed_modifier
  c.character_running_speed_modifier = -1
  place(r)
  draw(r)
  local player = player_of(r)
  if player then open_window(player, r) end
  return key
end

-- the rider off the chain, on the nearest free spot under it
function R.drop(key)
  local r = storage.riders[key]
  if not r then return end
  storage.riders[key] = nil
  undraw(r)
  local player = player_of(r)
  if player then close_window(player) end
  local c = r.c
  if not c.valid then return end
  c.destructible = r.destructible ~= false
  c.character_running_speed_modifier = r.run or 0
  local at = c.surface.find_non_colliding_position(c.name, { r.x, r.y }, 10, 0.1) or { r.x, r.y }
  c.teleport(at)
end

-- --- riding --------------------------------------------------------------------------------------------------------

-- on its way from node a to node b along the right-hand strand (round a bent pulley it cuts the corner, as packages do)
local function start(r, a, b)
  local pa, pb = storage.posts[a], storage.posts[b]
  local s, e = C.hop_ends(r.from, a, b, C.other(b, a))
  r.to, r.pts = b, { s, e }
  r.speed = S.span_speed(C.span_tier(pa, pb), C.span_level(pa, pb))
end

-- turned round mid-span: back to where it came from, on the other strand
local function turn_round(r)
  local a, b = r.to, r.node
  r.node, r.from = a, nil
  start(r, a, b)
  -- (straight across to the other strand, then on along it)
  local s, e = r.pts[1], r.pts[2]
  local dx, dy = e.x - s.x, e.y - s.y
  local l2 = dx * dx + dy * dy
  local t = l2 > 0 and math.max(0, math.min(1, ((r.x - s.x) * dx + (r.y - s.y) * dy) / l2)) or 0
  r.pts = { { x = s.x + dx * t, y = s.y + dy * t }, e }
end

local function say(r, text)
  local player = player_of(r)
  if player then player.create_local_flying_text({ text = text, position = { r.x, r.y - 2 } }) end
end

-- at node r.node: where next (nil: wait). dir: the direction held, or nil. With no key held a rider keeps going like a
-- train: on along the straightest span, and at the end of a line back the way it came, until it gets off, a key
-- steers it, or it parks at a destination it was sent to (a key starts it again)
local function next_node(r, dir)
  local n = r.node
  local p = storage.posts[n]
  if r.dest then
    if n == r.dest then
      r.dest = nil
      r.parked = true
      say(r, { "chl.ride-arrived" })
      return nil
    end
    local path = C.route(n, r.dest)
    if path and path[2] then return path[2] end
    r.dest = nil -- (no way there any more)
    say(r, { "chl.ride-no-route" })
    return nil
  end
  -- a bent pulley only bends the line: on round it
  local through = r.from and C.other(n, r.from)
  if through then return through end
  if dir then
    local dx, dy = dir_vec(dir)
    local best, bd
    for v in pairs(p.links) do
      local ux, uy = unit_to(n, v)
      local d = ux * dx + uy * dy
      if d > AHEAD and (not bd or d > bd) then best, bd = v, d end
    end
    if best then return best end -- (no span that way: on as before)
  end
  if r.parked then return nil end
  -- momentum: the heading it came in on (or, just hooked on, the way the character faced)
  local hx, hy = r.hx or 0, r.hy or 0
  if r.from and storage.posts[r.from] then hx, hy = unit_to(r.from, n) end
  local best, bd
  for v in pairs(p.links) do
    if v ~= r.from then
      local ux, uy = unit_to(n, v)
      local d = ux * hx + uy * hy
      if not bd or d > bd then best, bd = v, d end
    end
  end
  if best then return best end
  if r.from and p.links[r.from] then return r.from end -- (the end of the line: back the way it came)
  return nil
end

-- the direction the player holds, or the test's
local function held(r)
  if r.steer ~= nil then return r.steer or nil end
  if not r.player then return nil end
  local ws = r.c.walking_state
  if not ws.walking then return nil end
  return ws.direction
end

local function ride(key, r)
  local c = r.c
  if not c.valid then return R.drop(key) end
  local dir = held(r)
  if dir then r.parked = nil end
  if dir and r.dest then
    r.dest = nil -- (a walking key takes over from the route)
    refresh(r)
  end
  if r.to then
    local pn, pt = storage.posts[r.node], storage.posts[r.to]
    if not (pn and pt and pn.links[r.to] and pt.e.valid) then return R.drop(key) end -- (the chain went)
    if dir and not r.dest then
      local hx, hy = unit_to(r.node, r.to)
      local dx, dy = dir_vec(dir)
      if hx * dx + hy * dy < -TURN then turn_round(r) end
    end
  elseif not storage.posts[r.node] then
    return R.drop(key)
  end
  local waiting = not r.to
  local left = waiting and 0 or r.speed
  for _ = 1, 4 do -- (a hop ending this tick: the next one starts with what's left of the tick's way)
    if not r.to then
      local v = next_node(r, dir)
      if not v then break end
      start(r, r.node, v)
      if waiting then left, waiting = r.speed, false end
    end
    while left > 0 and r.pts[1] do
      local t = r.pts[1]
      local dx, dy = t.x - r.x, t.y - r.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= left then
        r.x, r.y, left = t.x, t.y, left - d
        table.remove(r.pts, 1)
      else
        r.x, r.y, left = r.x + dx / d * left, r.y + dy / d * left, 0
      end
    end
    if r.pts[1] then break end
    r.from, r.node, r.to = r.node, r.to, nil -- (there)
    refresh(r)
  end
  place(r)
end

function R.tick()
  if not next(storage.riders) then return end
  for key, r in pairs(storage.riders) do ride(key, r) end
end

-- rides to a destination (a named post or unloader, or any post): the shortest route from the next node
function R.ride_to(key, u)
  local r = storage.riders[key]
  local post = r and post_of(u)
  if not post then return false end
  r.dest = post
  refresh(r)
  return true
end

-- --- events --------------------------------------------------------------------------------------------------------

function R.on_input(ev)
  local player = game.get_player(ev.player_index)
  if storage.riders[ev.player_index] then return R.drop(ev.player_index) end
  local c = player.character
  if not c or c.vehicle or player.controller_type ~= defines.controllers.character then return end
  local best, bd
  for _, e in pairs(c.surface.find_entities_filtered({ name = C.nodes, position = c.position, radius = REACH })) do
    local d = (e.position.x - c.position.x) ^ 2 + (e.position.y - c.position.y) ^ 2
    if storage.posts[e.unit_number] and (e.force == player.force or player.force.get_friend(e.force))
      and (not bd or d < bd) then
      best, bd = e.unit_number, d
    end
  end
  if best then R.hook(c, best, player.index) end
end

local function drop_player(ev) if storage.riders[ev.player_index] then R.drop(ev.player_index) end end
R.on_pre_player_died = drop_player
R.on_pre_player_left_game = drop_player -- (before: once it has left, its character is out of the world)
function R.on_driving_changed(ev)
  local player = game.get_player(ev.player_index)
  if player and player.vehicle then drop_player(ev) end
end

-- true if it was ours
function R.on_gui_click(ev)
  local el = ev.element
  if not el.valid then return false end
  local tags = el.tags
  if tags.chl_ride_off then
    R.drop(ev.player_index)
    return true
  elseif tags.chl_ride_to then
    R.ride_to(ev.player_index, tags.chl_ride_to)
    return true
  end
  return false
end

function R.on_location_changed(ev)
  local el = ev.element
  if el.valid and el.name == WIN then storage.ride_place[ev.player_index] = el.location end
end

-- (for tests) a rider's state
function R.state(key)
  local r = storage.riders[key]
  if not r then return nil end
  return { node = r.node, from = r.from, to = r.to, x = r.x, y = r.y, dest = r.dest, parked = r.parked, riding = true }
end

function R.steer(key, dir)
  local r = storage.riders[key]
  if r then r.steer = dir or false end
end

return R
