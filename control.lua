-- Chain Logistics: posts linked by spans (two strands, one each way); a package rides a projectile along each span
-- (the engine moves it), and the script only hears when it reaches the next post.
local S = require("shared")
local L = require("logistics")

local POST = "chl-chain-post"
L.POST = POST

local function init()
  storage.posts = storage.posts or {} -- unit -> {e = entity, links = {unit = true}}
  storage.spans = storage.spans or {} -- "lo:hi" -> {a = unit, b = unit, ro = {render objects}}
  storage.packages = storage.packages or {} -- id -> {path = {unit ...}, i = hop index, items = {...}}
  storage.inflight = storage.inflight or {} -- "from:to" -> FIFO of {id, x, y} (the hop's end)
  storage.next_id = storage.next_id or 1
  L.init()
end

local function span_key(a, b)
  if a > b then a, b = b, a end
  return a .. ":" .. b
end

-- where a package bound from post a to post b rides: the right-hand strand (a sprocket radius off the centres)
local function strand(pa, pb)
  local dx, dy = pb.x - pa.x, pb.y - pa.y
  local len = math.sqrt(dx * dx + dy * dy)
  local ux, uy = dx / len, dy / len
  local ox, oy = -uy * S.R, ux * S.R * S.SQUASH
  return { x = pa.x + ox, y = pa.y + oy }, { x = pb.x + ox, y = pb.y + oy }, len
end

local function draw_strand(surface, pa, pb, out)
  local s, e, len = strand(pa, pb)
  local n = math.max(1, math.ceil(len - 2 * S.R))
  -- (orientation 0 is north; the sprite runs east, so a quarter turn less)
  local o = (math.atan2(e.x - s.x, -(e.y - s.y)) / (2 * math.pi) - 0.25) % 1
  local piece = len / n
  for k = 0, n - 1 do
    local f = (k + 0.5) / n
    out[#out + 1] = rendering.draw_animation({ -- its shadow on the ground
      animation = "chl-span-shadow",
      surface = surface,
      target = { x = s.x + (e.x - s.x) * f + S.SHADOW, y = s.y + (e.y - s.y) * f },
      orientation = o,
      x_scale = piece,
      tint = { 0, 0, 0, 0.3 },
      render_layer = "lower-object",
    })
    out[#out + 1] = rendering.draw_animation({
      animation = "chl-span",
      surface = surface,
      target = { x = s.x + (e.x - s.x) * f, y = s.y + (e.y - s.y) * f - S.LIFT },
      orientation = o,
      x_scale = piece,
      render_layer = "air-object",
    })
  end
end

local function connect(a, b)
  local pa, pb = storage.posts[a], storage.posts[b]
  if a == b or not pa or not pb or pa.links[b] then return false end
  local p, q = pa.e.position, pb.e.position
  if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 > S.RANGE ^ 2 then return false end
  local ro = {}
  draw_strand(pa.e.surface, p, q, ro)
  draw_strand(pa.e.surface, q, p, ro)
  storage.spans[span_key(a, b)] = { a = a, b = b, ro = ro }
  pa.links[b], pb.links[a] = true, true
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
  L.renet(a)
  L.renet(b)
end

local function add_post(e)
  local u = e.unit_number
  storage.posts[u] = { e = e, links = {}, tier = 1 }
  L.renet(u)
  -- like a pole: link to the nearest post in reach
  local best, bd
  for _, o in pairs(e.surface.find_entities_filtered({ name = POST, position = e.position, radius = S.RANGE })) do
    if o ~= e and storage.posts[o.unit_number] then
      local d = (o.position.x - e.position.x) ^ 2 + (o.position.y - e.position.y) ^ 2
      if not bd or d < bd then best, bd = o.unit_number, d end
    end
  end
  if best then connect(u, best) end
  L.post_built(e)
end

local function remove_post(u)
  local p = storage.posts[u]
  if not p then return end
  for o in pairs(p.links) do disconnect(u, o) end
  storage.posts[u] = nil
  L.post_gone(u)
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
  local chests = e.surface.find_entities_filtered({ type = { "container", "logistic-container" }, position = e.position, radius = 2 })
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
  local s, e = strand(a.e.position, b.e.position)
  local speed = S.TIERS[math.min(a.tier or 1, b.tier or 1)].speed -- (a span runs at its slower post's tier)
  a.e.surface.create_entity({ name = "chl-package", position = s, target = e, speed = speed, source = a.e, force = a.e.force })
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

script.on_init(init)
script.on_configuration_changed(function()
  init()
  L.rebuild()
end)

local built = { defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built,
  defines.events.script_raised_revive, defines.events.on_space_platform_built_entity }
local gone = { defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_entity_died,
  defines.events.script_raised_destroy, defines.events.on_space_platform_mined_entity }
local filters = { { filter = "name", name = POST }, { filter = "type", type = "logistic-container" } }
for _, ev in pairs(built) do
  script.on_event(ev, function(e)
    if e.entity.name == POST then add_post(e.entity) else L.chest_built(e.entity) end
  end, filters)
end
for _, ev in pairs(gone) do
  script.on_event(ev, function(e)
    if e.entity.name == POST then remove_post(e.entity.unit_number) else L.chest_gone(e.entity) end
  end, filters)
end
script.on_event(defines.events.on_tick, L.tick)
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
  -- (for tests) the post serving a chest, a post's network, what is on its way to a chest
  chest_post = function(u) return storage.chests[u] and storage.chests[u].post end,
  net = function(u) return storage.posts[u] and storage.posts[u].net end,
  bound = function(u) return storage.bound[u] end,
  -- (only the owning mod may write its runtime settings)
  set_setting = function(name, value) settings.global[name] = { value = value } end,
})
L.send = send
