-- Chain Logistics: posts linked by spans (two strands, one each way); a package rides a projectile along each span
-- (the engine moves it), and the script only hears when it reaches the next post.
local S = require("shared")
local L = require("logistics")
local N = require("names")
local R = require("ride")
local G = require("rings")

local POSTS = S.POSTS
L.POST = POSTS
local TIER = {} -- post name -> its tier
for t, name in ipairs(POSTS) do TIER[name] = t end
local PULLEY = S.PULLEY
local NODES = { PULLEY } -- what spans join: posts and pulleys
for _, name in ipairs(POSTS) do NODES[#NODES + 1] = name end
local function is_node(name) return TIER[name] or name == PULLEY end

-- where a post stands: an upgrade puts the new one there
local function spot(e) return e.surface.index .. ":" .. e.position.x .. "," .. e.position.y end

local function init()
  -- unit -> {e = entity, links = {unit = true}, tier, at = spot}; a pulley: {pulley = true, arcs = {render objects}},
  -- no tier
  storage.posts = storage.posts or {}
  storage.post_at = storage.post_at or {} -- spot -> unit
  storage.replaced = storage.replaced or {} -- spot -> {u, links}: posts gone this tick (replaced_tick), for upgrades
  storage.spans = storage.spans or {} -- "lo:hi" -> {a = unit, b = unit, ro = {render objects}}
  storage.packages = storage.packages or {} -- id -> {path = {unit ...}, i = hop index, items = {...}}
  storage.inflight = storage.inflight or {} -- "from:to" -> FIFO of {id, x, y} (the hop's end)
  storage.next_id = storage.next_id or 1
  L.init()
  N.init()
  R.init()
  for u, p in pairs(storage.posts) do
    if p.e.valid then
      if not p.pulley then p.tier = TIER[p.e.name] or 1 end
      p.quality = p.e.quality.level -- (posts from before 0.3.0 are normal)
      p.at = p.at or spot(p.e)
      storage.post_at[p.at] = u
    end
  end
end

local function span_key(a, b)
  if a > b then a, b = b, a end
  return a .. ":" .. b
end

-- a span's tier: its slower post's (a pulley has none: a span to one runs at the other end's tier, one between two
-- pulleys at tier 1)
local function span_tier(pa, pb)
  if pa.pulley and pb.pulley then return 1 end
  return math.min(pa.pulley and #POSTS or pa.tier or 1, pb.pulley and #POSTS or pb.tier or 1)
end

-- and its quality level: its lower-quality post's (a pulley's counts only between two pulleys, as with tiers)
local function span_level(pa, pb)
  if pa.pulley and not pb.pulley then return pb.quality or 0 end
  if pb.pulley and not pa.pulley then return pa.quality or 0 end
  return math.min(pa.quality or 0, pb.quality or 0)
end

-- (geometry round a node is done "flat", y / SQUASH: there the camera's foreshortened chain rings are circles of
-- radius R, and lines stay lines, so a strand tangent there is tangent on screen)
local function flat(p) return p.x, p.y / S.SQUASH end
local function unflat(x, y) return { x = x, y = y * S.SQUASH } end

-- the unit vector from a to b (flat) and its right-hand normal times R
local function heading(pa, pb)
  local ax, ay = flat(pa)
  local bx, by = flat(pb)
  local dx, dy = bx - ax, by - ay
  local l = math.sqrt(dx * dx + dy * dy)
  local ux, uy = dx / l, dy / l
  return ux, uy, -uy * S.R, ux * S.R
end

-- where a package bound from post a to post b rides: the right-hand strand, tangent to both chain rings
local function strand(pa, pb)
  local _, _, nx, ny = heading(pa, pb)
  local ax, ay = flat(pa)
  local bx, by = flat(pb)
  return unflat(ax + nx, ay + ny), unflat(bx + nx, by + ny)
end

-- a strand from x through pulley p on to y (positions): t1 where it meets p's ring coming in, t2 where it leaves
-- (both flat), the turn (radians, + clockwise on screen: the right-hand strand is then the inside one), and the
-- corner where its two straight parts meet (nil for a turn too sharp to cut across)
local function passage(x, p, y)
  local ux, uy, n1x, n1y = heading(x, p)
  local vx, vy, n2x, n2y = heading(p, y)
  local px, py = flat(p)
  local dot = ux * vx + uy * vy
  local turn = math.atan2(ux * vy - uy * vx, dot)
  local corner
  if dot > -0.2 then -- (up to about 100 degrees; the corner lies R / cos(turn / 2) from the centre)
    local k = 1 / (1 + dot)
    corner = { px + (n1x + n2x) * k, py + (n1y + n2y) * k }
  end
  return { px + n1x, py + n1y }, { px + n2x, py + n2y }, turn, corner
end

-- a pulley's two neighbours, if it has exactly two spans (with one, or three and more, it bends nothing)
local function bend(u)
  local p = storage.posts[u]
  if not (p and p.pulley) then return nil end
  local a = next(p.links)
  local b = a and next(p.links, a)
  if not b or next(p.links, b) then return nil end
  return a, b
end

-- bent pulley u's neighbour other than v
local function other(u, v)
  local a, b = bend(u)
  if a == v then return b elseif b == v then return a end
end

local function pos(u) return storage.posts[u].e.position end

-- the strand from node a to node b as drawn: tangent to the rings; at a bent pulley it stops at the corner on the
-- inside of the bend, and at the ring on the outside (where an arc takes it on to the next strand)
local function strand_ends(a, b)
  local s, e = strand(pos(a), pos(b))
  local x = other(a, b)
  if x then
    local _, _, turn, corner = passage(pos(x), pos(a), pos(b))
    if turn > 0 and corner then s = unflat(corner[1], corner[2]) end
  end
  local y = other(b, a)
  if y then
    local _, _, turn, corner = passage(pos(a), pos(b), pos(y))
    if turn > 0 and corner then e = unflat(corner[1], corner[2]) end
  end
  return s, e
end

-- a package's hop from a to b, come from prev and going on to nxt (units, or nil): round a bent pulley it cuts the
-- corner, so it doesn't jump between hops (outside a bend it rides at most R / cos(turn / 2) - R off the arc)
local function hop_ends(prev, a, b, nxt)
  local s, e = strand(pos(a), pos(b))
  if prev and storage.posts[prev] and other(a, prev) == b then
    local _, t2, _, corner = passage(pos(prev), pos(a), pos(b))
    local c = corner or t2
    s = unflat(c[1], c[2])
  end
  if nxt and storage.posts[nxt] and other(b, a) == nxt then
    local t1, _, _, corner = passage(pos(a), pos(b), pos(nxt))
    local c = corner or t1
    e = unflat(c[1], c[2])
  end
  return s, e
end

-- one straight piece of chain from a to b, and its shadow (tier and level: the span's, so its links crawl as fast
-- as its packages ride)
local function draw_piece(surface, a, b, out, tier, level)
  local crawl = S.span_speed(tier, level or 0) / S.span_speed(tier, 0)
  local len = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
  -- (orientation 0 is north; the sprite runs east, so a quarter turn less)
  local o = (math.atan2(b.x - a.x, -(b.y - a.y)) / (2 * math.pi) - 0.25) % 1
  local mx, my = (a.x + b.x) / 2, (a.y + b.y) / 2
  out[#out + 1] = rendering.draw_animation({ -- its shadow on the ground
    animation = "chl-span-shadow-" .. tier,
    surface = surface,
    target = { x = mx + S.SHADOW, y = my },
    orientation = o,
    x_scale = len,
    tint = { 0, 0, 0, 0.3 },
    animation_speed = crawl,
    render_layer = "lower-object",
  })
  out[#out + 1] = rendering.draw_animation({
    animation = "chl-span-" .. tier,
    surface = surface,
    target = { x = mx, y = my - S.LIFT },
    orientation = o,
    x_scale = len,
    animation_speed = crawl,
    render_layer = "air-object",
  })
end

local function draw_strand(surface, s, e, out, tier, level)
  local n = math.max(1, math.ceil(math.sqrt((e.x - s.x) ^ 2 + (e.y - s.y) ^ 2) - 2 * S.R))
  local prev = s
  for k = 1, n do
    local q = { x = s.x + (e.x - s.x) * k / n, y = s.y + (e.y - s.y) * k / n }
    draw_piece(surface, prev, q, out, tier, level)
    prev = q
  end
end

-- a span's two strands, drawn (again)
local function draw_span(sp)
  for _, r in pairs(sp.ro) do if r.valid then r.destroy() end end
  sp.ro = {}
  local pa, pb = storage.posts[sp.a], storage.posts[sp.b]
  if not (pa and pb and pa.e.valid and pb.e.valid) then return end
  local tier, level = span_tier(pa, pb), span_level(pa, pb)
  local s, e = strand_ends(sp.a, sp.b)
  draw_strand(pa.e.surface, s, e, sp.ro, tier, level)
  s, e = strand_ends(sp.b, sp.a)
  draw_strand(pa.e.surface, s, e, sp.ro, tier, level)
end

-- a bent pulley's arcs: on the outside of the bend a strand wraps the ring, in a few short pieces
local function draw_arcs(u)
  local p = storage.posts[u]
  for _, r in pairs(p.arcs or {}) do if r.valid then r.destroy() end end
  p.arcs = {}
  local a, b = bend(u)
  if not a then return end
  local tier = math.min(span_tier(p, storage.posts[a]), span_tier(p, storage.posts[b]))
  local level = math.min(span_level(p, storage.posts[a]), span_level(p, storage.posts[b]))
  local px, py = flat(p.e.position)
  for _, way in ipairs({ { a, b }, { b, a } }) do
    local t1, _, turn = passage(pos(way[1]), p.e.position, pos(way[2]))
    if turn < 0 then
      local a0 = math.atan2(t1[2] - py, t1[1] - px)
      local n = math.max(1, math.ceil(-turn / (math.pi / 6))) -- (30 degrees a piece)
      local prev = unflat(t1[1], t1[2])
      for k = 1, n do
        local ang = a0 + turn * k / n
        local q = unflat(px + math.cos(ang) * S.R, py + math.sin(ang) * S.R)
        draw_piece(p.e.surface, prev, q, p.arcs, tier, level)
        prev = q
      end
    end
  end
end

-- a pulley's spans changed: their ends and its arcs drawn again
local function touch(u)
  local p = storage.posts[u]
  if not (p and p.pulley and p.e.valid) then return end
  for o in pairs(p.links) do
    local sp = storage.spans[span_key(u, o)]
    if sp then draw_span(sp) end
  end
  draw_arcs(u)
end

local function connect(a, b)
  local pa, pb = storage.posts[a], storage.posts[b]
  if a == b or not pa or not pb or pa.links[b] then return false end
  local p, q = pa.e.position, pb.e.position
  local range = math.min(S.range(pa.quality or 0), S.range(pb.quality or 0)) -- (the shorter-reaching end decides)
  if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 > range ^ 2 then return false end
  local sp = { a = a, b = b, ro = {} }
  storage.spans[span_key(a, b)] = sp
  pa.links[b], pb.links[a] = true, true
  draw_span(sp)
  touch(a)
  touch(b)
  L.renet(a)
  return true
end

local function disconnect(a, b)
  local k = span_key(a, b)
  local sp = storage.spans[k]
  if not sp then return end
  for _, r in pairs(sp.ro) do if r.valid then r.destroy() end end
  storage.spans[k] = nil
  if storage.posts[a] then storage.posts[a].links[b] = nil end
  if storage.posts[b] then storage.posts[b].links[a] = nil end
  touch(a)
  touch(b)
  L.renet(a)
  L.renet(b)
end

local function remove_post(u)
  local p = storage.posts[u]
  if not p then return end
  -- (kept for a tick: a post built on the same spot this tick is its upgrade, and takes over its spans)
  if storage.replaced_tick ~= game.tick then storage.replaced, storage.replaced_tick = {}, game.tick end
  if p.at then
    local links = {}
    for o in pairs(p.links) do links[o] = true end
    storage.replaced[p.at] = { u = u, links = links }
    if storage.post_at[p.at] == u then storage.post_at[p.at] = nil end
  end
  for o in pairs(p.links) do disconnect(u, o) end
  for _, r in pairs(p.arcs or {}) do if r.valid then r.destroy() end end
  storage.posts[u] = nil
  L.post_gone(u)
end

-- an upgraded post's packages ride on as the new one's
local function remap(old, new)
  for _, pkg in pairs(storage.packages) do
    for i, v in ipairs(pkg.path) do
      if v == old then pkg.path[i] = new end
    end
  end
  local moved = {}
  for k, q in pairs(storage.inflight) do
    local a, b = k:match("^(%d+):(%d+)$")
    a, b = tonumber(a), tonumber(b)
    if a == old or b == old then moved[k] = (a == old and new or a) .. ":" .. (b == old and new or b) end
  end
  for k, k2 in pairs(moved) do
    storage.inflight[k2], storage.inflight[k] = storage.inflight[k], nil
  end
end

local function add_post(e)
  local u = e.unit_number
  local at = spot(e)
  -- (a fast-replace may take the old post away without an event)
  local old = storage.post_at[at]
  if old and old ~= u and storage.posts[old] and not storage.posts[old].e.valid then remove_post(old) end
  local prev = storage.replaced_tick == game.tick and storage.replaced[at]
  local pulley = e.name == PULLEY or nil
  storage.posts[u] = { e = e, links = {}, tier = TIER[e.name], quality = e.quality.level, at = at, pulley = pulley,
    arcs = pulley and {} or nil }
  storage.post_at[at] = u
  L.renet(u)
  if prev then
    -- an upgrade (or a post put back where one just went): the same spans, drawn at the new tier
    storage.replaced[at] = nil
    for o in pairs(prev.links) do connect(u, o) end
    remap(prev.u, u)
    N.remap(prev.u, u)
  else
    -- like a pole: link to the nearest post (or pulley) in reach
    local best, bd
    for _, o in pairs(e.surface.find_entities_filtered({ name = NODES, position = e.position, radius = S.range(e.quality.level) })) do
      local po = storage.posts[o.unit_number]
      local d = (o.position.x - e.position.x) ^ 2 + (o.position.y - e.position.y) ^ 2
      if o ~= e and po and d <= S.range(po.quality or 0) ^ 2 then
        if not bd or d < bd then best, bd = o.unit_number, d end
      end
    end
    if best then connect(u, best) end
  end
  if not pulley then L.post_built(e) end
end

-- shortest path over spans (Dijkstra; fine for the spike's small networks)
local function route(from, to)
  local dist, prev, done = { [from] = 0 }, {}, {}
  while true do
    local u, du
    for k, d in pairs(dist) do
      if not done[k] and (not du or d < du) then u, du = k, d end
    end
    if not u then return nil end
    if u == to then break end
    done[u] = true
    local pu = storage.posts[u].e.position
    for v in pairs(storage.posts[u].links) do
      local pv = storage.posts[v].e.position
      local d = du + math.sqrt((pu.x - pv.x) ^ 2 + (pu.y - pv.y) ^ 2)
      if not dist[v] or d < dist[v] then dist[v], prev[v] = d, u end
    end
  end
  local path, u = {}, to
  while u do
    table.insert(path, 1, u)
    u = prev[u]
  end
  return path
end

local function spill(surface, pos, items)
  for _, it in pairs(items) do
    surface.spill_item_stack({ position = pos, stack = it, enable_looted = true, allow_belts = false })
  end
end

-- into the chest it was sent to (else one its post serves: logistics.lua), else any chest by the post, else it
-- falls by the post
local function deliver(pkg)
  local post = storage.posts[pkg.path[pkg.i]]
  local e = post.e
  local left = {}
  local chests = {}
  for _, c in pairs(e.surface.find_entities_filtered({ type = { "container", "logistic-container" }, position = e.position, radius = 2 })) do
    if c.name ~= L.LOADER then chests[#chests + 1] = c end -- (not into a loader: it would only send it on)
  end
  for _, it in pairs(L.deliver(pkg, pkg.path[pkg.i])) do
    local n = it.count
    for _, c in pairs(chests) do
      if n <= 0 then break end
      n = n - c.insert({ name = it.name, count = n, quality = it.quality })
    end
    if n > 0 then left[#left + 1] = { name = it.name, count = n, quality = it.quality } end
  end
  if #left > 0 then spill(e.surface, e.position, left) end
end

local function launch(id)
  local pkg = storage.packages[id]
  local a, b = storage.posts[pkg.path[pkg.i]], storage.posts[pkg.path[pkg.i + 1]]
  local s, e = hop_ends(pkg.path[pkg.i - 1] or pkg.prev, pkg.path[pkg.i], pkg.path[pkg.i + 1], pkg.path[pkg.i + 2])
  -- (a span runs at its slower post's tier. The engine floors a projectile's speed to 1/256 tiles a tick, an exact
  -- 1/256th one step lower: a quarter step more lands on the tier's speed)
  local speed = S.span_speed(span_tier(a, b), span_level(a, b)) + 0.25 / 256
  -- (unsnapped: the engine would start it on the half-tile grid, off the strand)
  a.e.surface.create_entity({ name = "chl-package", position = s, target = e, speed = speed, source = a.e, force = a.e.force,
    snap_to_grid = false })
  local k = pkg.path[pkg.i] .. ":" .. pkg.path[pkg.i + 1]
  local q = storage.inflight[k] or {}
  storage.inflight[k] = q
  q[#q + 1] = { id = id, x = e.x, y = e.y }
end

-- dest: the chest unit it is for (logistics.lua counts it as on its way there), or nil
local function send(from, to, items, dest)
  local path = storage.posts[from] and storage.posts[to] and route(from, to)
  if not path then
    if dest then L.dropped({ dest = dest, items = items }) end
    return nil
  end
  local id = storage.next_id
  storage.next_id = id + 1
  storage.packages[id] = { path = path, i = 1, items = items, sent = game.tick, dest = dest }
  if #path == 1 then
    deliver(storage.packages[id])
    storage.packages[id] = nil
  else
    launch(id)
  end
  return id
end

local function arrived(ev)
  -- which hop: the in-flight queue whose first package was bound for where this projectile ended
  local tp, best, bd = ev.target_position, nil, nil
  for k, q in pairs(storage.inflight) do
    local f = q[1]
    if f then
      local d = (f.x - tp.x) ^ 2 + (f.y - tp.y) ^ 2
      if not bd or d < bd then best, bd = k, d end
    end
  end
  if not best or bd > 0.01 then return end
  local q = storage.inflight[best]
  local id = table.remove(q, 1).id
  if #q == 0 then storage.inflight[best] = nil end
  local pkg = storage.packages[id]
  if not pkg then return end
  pkg.i = pkg.i + 1
  local here, nxt = storage.posts[pkg.path[pkg.i]], pkg.path[pkg.i + 1]
  if not here then -- its post went while it rode: it falls where it is
    L.dropped(pkg)
    spill(game.surfaces[ev.surface_index], tp, pkg.items)
    storage.packages[id] = nil
  elseif not nxt then
    deliver(pkg)
    pkg.arrived = ev.tick
    storage.last_delivered = { id = id, sent = pkg.sent, arrived = ev.tick, hops = #pkg.path - 1 }
    storage.packages[id] = nil
  elseif not here.links[nxt] then -- the way on went: reroute from here
    local path = route(pkg.path[pkg.i], pkg.path[#pkg.path])
    if path and #path > 1 then
      pkg.prev = pkg.path[pkg.i - 1]
      pkg.path, pkg.i = path, 1
      launch(id)
    else
      L.dropped(pkg)
      spill(here.e.surface, here.e.position, pkg.items)
      storage.packages[id] = nil
    end
  else
    launch(id)
  end
end

R.setup({ route = route, hop_ends = hop_ends, span_tier = span_tier, span_level = span_level, other = other,
  pos = pos, nodes = NODES })

script.on_init(init)
-- every span drawn again (after a migration: the span animations are per tier since 0.2.0)
local function redraw()
  for _, sp in pairs(storage.spans) do draw_span(sp) end
  for u, p in pairs(storage.posts) do
    if p.pulley and p.e.valid then draw_arcs(u) end
  end
end

script.on_configuration_changed(function()
  init()
  L.rebuild()
  redraw()
end)

local built = { defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built,
  defines.events.script_raised_revive, defines.events.on_space_platform_built_entity }
local gone = { defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_entity_died,
  defines.events.script_raised_destroy, defines.events.on_space_platform_mined_entity }
local filters = { { filter = "type", type = "logistic-container" }, { filter = "name", name = L.LOADER } }
for _, name in ipairs(NODES) do filters[#filters + 1] = { filter = "name", name = name } end
for _, ev in pairs(built) do
  script.on_event(ev, function(e)
    if is_node(e.entity.name) then
      add_post(e.entity)
      G.nodes_changed(e.entity, e.player_index)
    else
      L.chest_built(e.entity)
    end
    N.built(e.entity, e.tags)
  end, filters)
end
for _, ev in pairs(gone) do
  script.on_event(ev, function(e)
    if is_node(e.entity.name) then
      remove_post(e.entity.unit_number)
      G.nodes_changed()
    else
      L.chest_gone(e.entity)
    end
  end, filters)
end
script.on_event(defines.events.on_tick, function(ev)
  L.tick(ev)
  R.tick()
end)
script.on_event(defines.events.on_object_destroyed, N.destroyed)
script.on_event(defines.events.on_player_setup_blueprint, N.setup_blueprint)
script.on_event(defines.events.on_entity_settings_pasted, N.pasted)
script.on_event("chl-open", N.on_open_input)
script.on_event(defines.events.on_gui_opened, N.on_gui_opened)
script.on_event(defines.events.on_gui_closed, N.on_gui_closed)
script.on_event(defines.events.on_gui_click, function(ev)
  if not R.on_gui_click(ev) then N.on_gui_click(ev) end
end)
script.on_event("chl-ride", R.on_input)
script.on_event(defines.events.on_pre_player_died, R.on_pre_player_died)
script.on_event(defines.events.on_pre_player_left_game, function(ev)
  R.on_pre_player_left_game(ev)
  G.on_left(ev)
end)
script.on_event(defines.events.on_player_cursor_stack_changed, G.on_cursor_changed)
script.on_event(defines.events.on_player_changed_position, G.on_moved)
script.on_event(defines.events.on_player_changed_surface, G.on_cursor_changed) -- (redraws there, if still holding)
script.on_event(defines.events.on_selected_entity_changed, G.on_selected)
script.on_event(defines.events.on_player_driving_changed_state, R.on_driving_changed)
script.on_event(defines.events.on_gui_location_changed, R.on_location_changed)
script.on_event(defines.events.on_gui_text_changed, N.on_text_changed)
script.on_event(defines.events.on_gui_confirmed, N.on_confirmed)
script.on_event(defines.events.on_script_trigger_effect, function(ev)
  if ev.effect_id == "chl-arrive" then arrived(ev) end
end)

remote.add_interface("chain-logistics", {
  connect = connect,
  disconnect = disconnect,
  send = send,
  packages = function() return table_size(storage.packages) end,
  last_delivered = function() return storage.last_delivered end,
  links = function(u) return storage.posts[u] and storage.posts[u].links end,
  tier = function(u) return storage.posts[u] and storage.posts[u].tier end,
  -- (for tests) the post serving a chest, a post's network, what is on its way to a chest
  chest_post = function(u) return storage.chests[u] and storage.chests[u].post end,
  net = function(u) return storage.posts[u] and storage.posts[u].net end,
  bound = function(u) return storage.bound[u] end,
  arcs = function(u) return storage.posts[u] and storage.posts[u].arcs and #storage.posts[u].arcs end,
  -- names (and for a riding feature: the named posts and unloaders of a network, {{unit, name, kind, post}})
  name = N.get,
  address = N.address,
  set_name = function(e, name, address) N.set(e, name, address) end,
  named = N.list,
  -- (for tests: what on_player_setup_blueprint does, for a blueprint made with create_blueprint)
  tag_blueprint = N.tag_blueprint,
  -- riding: hook a character (a player's: player_index) onto a node -> its rider key; ride to a destination (a
  -- named post / unloader, or a post); (for tests) steer it (a defines.direction, nil: none held), its state; drop it
  ride = function(c, u, player_index) return R.hook(c, u, player_index) end,
  ride_to = R.ride_to,
  ride_steer = R.steer,
  rider = R.state,
  ride_off = R.drop,
  -- (only the owning mod may write its runtime settings)
  set_setting = function(name, value) settings.global[name] = { value = value } end,
  -- (for tests) the tier table, with the tiers made for faster modded belts, and each tier's post
  tiers = function() return { tiers = S.TIERS, posts = S.POSTS } end,
  rings = G.count, -- (for tests) a player's reach markers while holding a post: {marks, anchor, lit}
  holding = function(index) return G.holding(game.get_player(index)) end,
})
L.send = send
