-- Logistic chests over chains: each post serves the logistic chests next to it; requester and buffer chests get
-- what they ask for from provider / storage chests on the same chain network, in vanilla's order (active
-- provider, storage, buffer, passive provider); active providers and requesters' trash empty into storage.
-- A round-robin cursor looks at a few chests a tick (setting), so the work is spread however big the base is.
local S = require("shared")

local L = {} -- control.lua sets L.send(from_post, to_post, items, dest) and L.POST
local CHEST = "logistic-container"
local RANK = { ["active-provider"] = 1, storage = 2, buffer = 3, ["passive-provider"] = 4 }
local COLORS = { magenta = { 1, 0.1, 0.6 }, toxic = { 0.3, 1, 0.15 }, orange = { 1, 0.35, 0 }, red = { 1, 0.1, 0.1 } }

function L.init()
  storage.chests = storage.chests or {} -- unit -> {e, post = unit, mode, items = {key = n} (what it offers)}
  storage.chest_list = storage.chest_list or {} -- units, for the cursor
  storage.chest_at = storage.chest_at or {} -- unit -> index in chest_list
  storage.cursor = storage.cursor or 1
  storage.supply = storage.supply or {} -- item key -> {chest unit = count}: what supplying chests last held
  storage.bound = storage.bound or {} -- chest unit -> {item key = count} in packages on their way to it
  storage.next_net = storage.next_net or 1
end

local function key(name, quality) return name .. "|" .. (quality or "normal") end

local function unkey(k)
  local n, q = k:match("^(.*)|(.*)$")
  return n, q
end

local function tier(post) return S.TIERS[post.tier or 1] end

-- --- networks: posts joined by spans ------------------------------------------------------------------------------

-- every post reachable from u gets a fresh network id
function L.renet(u)
  if not storage.posts[u] then return end
  local id = storage.next_net
  storage.next_net = id + 1
  local todo, seen = { u }, { [u] = true }
  while #todo > 0 do
    local v = table.remove(todo)
    local p = storage.posts[v]
    p.net = id
    for w in pairs(p.links) do
      if not seen[w] and storage.posts[w] then
        seen[w] = true
        todo[#todo + 1] = w
      end
    end
  end
end

-- --- attaching chests to posts -------------------------------------------------------------------------------------

local function reach_area(e, extra)
  local b = e.bounding_box
  return { { b.left_top.x - extra, b.left_top.y - extra }, { b.right_bottom.x + extra, b.right_bottom.y + extra } }
end

local function nearest_post(chest, skip)
  local best, bd
  for _, p in pairs(chest.surface.find_entities_filtered({ name = L.POST, area = reach_area(chest, S.REACH), force = chest.force })) do
    local u = p.unit_number
    if u ~= skip and storage.posts[u] then
      local d = (p.position.x - chest.position.x) ^ 2 + (p.position.y - chest.position.y) ^ 2
      if not bd or d < bd then best, bd = u, d end
    end
  end
  return best
end

local function forget_supply(c, unit)
  for k in pairs(c.items or {}) do
    local s = storage.supply[k]
    if s then
      s[unit] = nil
      if next(s) == nil then storage.supply[k] = nil end
    end
  end
  c.items = {}
end

local function draw_link(c)
  if c.ro and c.ro.valid then c.ro.destroy() end
  local post = storage.posts[c.post]
  local col = COLORS[settings.startup["chl-skin"].value] or COLORS.magenta
  -- (a tile long at most: drawn on the ground, the sprites hide it)
  c.ro = rendering.draw_line({ color = { col[1], col[2], col[3], 0.9 }, width = 2, from = post.e, to = c.e,
    surface = c.e.surface, only_in_alt_mode = true, render_layer = "higher-object-above" })
end

local function attach(chest, post_u)
  local u = chest.unit_number
  local c = storage.chests[u]
  if not c then
    c = { e = chest, mode = chest.prototype.logistic_mode, items = {} }
    storage.chests[u] = c
    local list = storage.chest_list
    list[#list + 1] = u
    storage.chest_at[u] = #list
  end
  c.post = post_u
  draw_link(c)
end

local function detach(u)
  local c = storage.chests[u]
  if not c then return end
  forget_supply(c, u)
  if c.ro and c.ro.valid then c.ro.destroy() end
  storage.chests[u] = nil
  -- (swap-remove from the cursor's list)
  local list, at = storage.chest_list, storage.chest_at
  local i = at[u]
  local last = list[#list]
  list[i], at[last] = last, i
  list[#list], at[u] = nil, nil
end

function L.chest_built(chest)
  local p = nearest_post(chest)
  if p then attach(chest, p) end
end

function L.chest_gone(chest)
  detach(chest.unit_number)
end

-- a new post takes the chests in its reach that have none, and those it stands nearer to
function L.post_built(post)
  for _, chest in pairs(post.surface.find_entities_filtered({ type = CHEST, area = reach_area(post, S.REACH + 2), force = post.force })) do
    local best = nearest_post(chest)
    local c = storage.chests[chest.unit_number]
    if best and (not c or c.post ~= best) then attach(chest, best) end
  end
end

-- a post going: its chests move to another post in reach, or stop being served
function L.post_gone(u)
  for cu, c in pairs(storage.chests) do
    if c.post == u then
      local p = c.e.valid and nearest_post(c.e, u)
      if p then attach(c.e, p) else detach(cu) end
    end
  end
end

-- --- the scheduler ------------------------------------------------------------------------------------------------

local function contents(c)
  return c.e.get_inventory(defines.inventory.chest).get_contents()
end

-- what a supplying chest holds now, into the supply index
local function offer(c, u)
  local now = {}
  for _, it in pairs(contents(c)) do now[key(it.name, it.quality)] = it.count end
  for k in pairs(c.items) do
    if not now[k] then
      local s = storage.supply[k]
      if s then
        s[u] = nil
        if next(s) == nil then storage.supply[k] = nil end
      end
    end
  end
  for k, n in pairs(now) do
    local s = storage.supply[k] or {}
    storage.supply[k] = s
    s[u] = n
  end
  c.items = now
end

local function ready(post) return (post.ready or 0) <= game.tick end

local function capacity(post) return tier(post).package * settings.global["chl-package-size"].value end

-- take up to n of k from a source chest, launch it toward dest; the count sent (0: nothing)
local function ship(src_u, src, dest_u, dest, k, n)
  local post = storage.posts[src.post]
  local name, quality = unkey(k)
  local got = src.e.get_inventory(defines.inventory.chest).remove({ name = name, quality = quality, count = math.min(n, capacity(post)) })
  if got <= 0 then
    if storage.supply[k] then storage.supply[k][src_u] = nil end
    return 0
  end
  local s = storage.supply[k]
  if s and s[src_u] then s[src_u] = math.max(0, s[src_u] - got) end
  local b = storage.bound[dest_u] or {}
  storage.bound[dest_u] = b
  b[k] = (b[k] or 0) + got
  post.ready = game.tick + tier(post).cooldown
  L.send(src.post, dest.post, { { name = name, quality = quality, count = got } }, dest_u)
  return got
end

-- the best source of k for a chest on network net: highest priority, then nearest. Priority is strict, as with
-- bots: if the best one's post is still sending its last package, the request waits (the caller checks ready)
local function source(k, net, dest_u, dest)
  local s = storage.supply[k]
  if not s then return nil end
  local best, br, bd
  local dp = dest.e.position
  for u, n in pairs(s) do
    local c = storage.chests[u]
    local post = c and storage.posts[c.post]
    if n > 0 and u ~= dest_u and post and post.net == net and c.e.valid
        and not (c.mode == "buffer" and dest.mode == "buffer") then
      local r = RANK[c.mode] or 9
      local p = c.e.position
      local d = (p.x - dp.x) ^ 2 + (p.y - dp.y) ^ 2
      if not br or r < br or (r == br and d < bd) then best, br, bd = u, r, d end
    end
  end
  return best
end

local function bots_serve(c)
  if settings.global["chl-share-with-bots"].value then return false end
  local pt = c.e.get_requester_point()
  local net = pt and pt.logistic_network
  -- (outside any roboport's reach the point still hands back a network object, an invalid one)
  return net ~= nil and net.valid and net.all_logistic_robots > 0
end

local function request(u, c)
  local pt = c.e.get_requester_point()
  if not pt or not pt.enabled or bots_serve(c) then return end
  local post = storage.posts[c.post]
  local have, bound, bots = {}, storage.bound[u] or {}, {}
  for _, it in pairs(contents(c)) do have[key(it.name, it.quality)] = it.count end
  for _, it in pairs(pt.targeted_items_deliver or {}) do bots[key(it.name, it.quality)] = it.count end
  for _, f in pairs(pt.filters or {}) do
    if f.name and (f.count or 0) > 0 then
      local k = key(f.name, f.quality)
      local need = f.count - (have[k] or 0) - (bound[k] or 0) - (bots[k] or 0)
      if need > 0 then
        local src = source(k, post.net, u, c)
        local sc = src and storage.chests[src]
        if sc and ready(storage.posts[sc.post]) and ship(src, sc, u, c, k, need) > 0 then return end
      end
    end
  end
end

-- a storage chest on net to put k into: one holding k already, else any with room
local function store_for(k, net, from_u)
  local name, quality = unkey(k)
  for u in pairs(storage.supply[k] or {}) do
    local c = storage.chests[u]
    if c and c.mode == "storage" and u ~= from_u and c.e.valid and storage.posts[c.post].net == net
        and c.e.can_insert({ name = name, quality = quality }) then return u end
  end
  for u, c in pairs(storage.chests) do
    if c.mode == "storage" and u ~= from_u and c.e.valid and storage.posts[c.post] and storage.posts[c.post].net == net
        and c.e.can_insert({ name = name, quality = quality }) then return u end
  end
end

-- empty an inventory into storage, a package at a time
local function push(u, c, inv)
  local post = storage.posts[c.post]
  if not ready(post) then return end
  for _, it in pairs(inv.get_contents()) do
    local k = key(it.name, it.quality)
    local to = store_for(k, post.net, u)
    if to then
      local got = inv.remove({ name = it.name, quality = it.quality, count = math.min(it.count, capacity(post)) })
      if got > 0 then
        local b = storage.bound[to] or {}
        storage.bound[to] = b
        b[k] = (b[k] or 0) + got
        post.ready = game.tick + tier(post).cooldown
        L.send(c.post, storage.chests[to].post, { { name = it.name, quality = it.quality, count = got } }, to)
        return
      end
    end
  end
end

local function turn(u)
  local c = storage.chests[u]
  if not c then return end
  if not c.e.valid or not storage.posts[c.post] then
    detach(u)
    return
  end
  local mode = c.mode
  if RANK[mode] then offer(c, u) end
  if mode == "requester" or mode == "buffer" then request(u, c) end
  if mode == "active-provider" then push(u, c, c.e.get_inventory(defines.inventory.chest)) end
  if mode == "requester" then
    local trash = c.e.get_inventory(defines.inventory.logistic_container_trash)
    if trash and not trash.is_empty() then push(u, c, trash) end
  end
end

function L.tick()
  local list = storage.chest_list
  local n = #list
  if n == 0 then return end
  for _ = 1, math.min(n, settings.global["chl-chests-per-tick"].value) do
    if storage.cursor > #list then storage.cursor = 1 end
    local u = list[storage.cursor]
    storage.cursor = storage.cursor + 1
    if u then turn(u) end
  end
end

-- a package reached its destination chest's post: into that chest, else any chest the post serves; what's left
-- over is returned (the caller spills it)
function L.deliver(pkg, post_u)
  local left = {}
  local dest = pkg.dest and storage.chests[pkg.dest]
  local b = pkg.dest and storage.bound[pkg.dest]
  for _, it in pairs(pkg.items) do
    local n = it.count
    if b then
      local k = key(it.name, it.quality)
      if b[k] then
        b[k] = b[k] - n
        if b[k] <= 0 then b[k] = nil end
      end
    end
    if dest and dest.e.valid then n = n - dest.e.insert({ name = it.name, quality = it.quality, count = n }) end
    if n > 0 then
      for _, c in pairs(storage.chests) do
        if n <= 0 then break end
        if c.post == post_u and c.e.valid then n = n - c.e.insert({ name = it.name, quality = it.quality, count = n }) end
      end
    end
    if n > 0 then left[#left + 1] = { name = it.name, quality = it.quality, count = n } end
  end
  if b and next(b) == nil then storage.bound[pkg.dest] = nil end
  return left
end

-- a package fell (its route went): what it carried is no longer on its way
function L.dropped(pkg)
  local b = pkg.dest and storage.bound[pkg.dest]
  if not b then return end
  for _, it in pairs(pkg.items) do
    local k = key(it.name, it.quality)
    if b[k] then
      b[k] = b[k] - it.count
      if b[k] <= 0 then b[k] = nil end
    end
  end
  if next(b) == nil then storage.bound[pkg.dest] = nil end
end

-- (after a migration: every post a network, every chest in reach of one attached)
function L.rebuild()
  for u, p in pairs(storage.posts) do
    if not p.net then L.renet(u) end
  end
  for _, p in pairs(storage.posts) do
    if p.e.valid then L.post_built(p.e) end
  end
end

return L
