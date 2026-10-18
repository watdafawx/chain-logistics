-- an L-shaped line: post A, a pulley at the bend, post C. A requester by C gets exactly what it asks for from a
-- provider by A, through the pulley; a chest by the pulley isn't served. The pulley's arcs show with two spans
-- only. Mining the pulley while packages ride drops them (nothing lost), and once a new pulley joins A and C again
-- the request is met
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local t = {}

local function ground(s, name)
  local n = 0
  for _, e in pairs(s.find_entities_filtered({ type = "item-entity" })) do
    if e.stack.name == name then n = n + e.stack.count end
  end
  return n
end

local function ask(n)
  local sec = t.req.get_requester_point().get_section(1)
  sec.set_slot(1, { value = { name = "iron-plate", quality = "normal" }, min = n })
end

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y) return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true }) end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 30 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    t.a = mk("chl-chain-post", 0.5, 0.5)
    t.p = mk("chl-chain-pulley", 10.5, 0.5)
    t.c = mk("chl-chain-post", 10.5, 8.5)
    local pl = remote.call(CL, "links", t.p.unit_number)
    check(pl[t.a.unit_number] and pl[t.c.unit_number], "the pulley links to A, and C to the pulley")
    check(remote.call(CL, "arcs", t.p.unit_number) > 0, "with two spans the pulley draws its arc")
    t.prov = mk("passive-provider-chest", -0.5, 0.5)
    t.prov.insert({ name = "iron-plate", count = 200 })
    t.req = mk("requester-chest", 11.5, 8.5)
    t.req.get_requester_point().add_section()
    ask(50)
    t.side = mk("passive-provider-chest", 11.5, 0.5)
    t.side.insert({ name = "copper-plate", count = 10 })
    check(remote.call(CL, "chest_post", t.side.unit_number) == nil, "a chest by the pulley isn't served")
    check(remote.call(CL, "chest_post", t.req.unit_number) == t.c.unit_number, "the requester is served by C")
    check(remote.call(CL, "net", t.a.unit_number) == remote.call(CL, "net", t.c.unit_number), "A and C are one network")
    -- a third span takes the arc away, and losing it brings the arc back
    t.d = mk("chl-chain-post", 20.5, 0.5)
    remote.call(CL, "connect", t.d.unit_number, t.p.unit_number)
    check(remote.call(CL, "arcs", t.p.unit_number) == 0, "with three spans, no arc")
    t.d.destroy({ raise_destroy = true })
    check(remote.call(CL, "arcs", t.p.unit_number) > 0, "back to two spans, the arc again")
  elseif ev.tick == 700 then
    local n, p = t.req.get_item_count("iron-plate"), t.prov.get_item_count("iron-plate")
    check(n == 50, "the requester got exactly 50 through the pulley (" .. n .. ")")
    check(p == 150, "the provider gave exactly 50 (" .. p .. " left)")
    check(t.side.get_item_count("copper-plate") == 10, "the chest by the pulley kept its copper")
    check(ground(s, "iron-plate") == 0, "nothing spilled")
    ask(100)
  elseif ev.tick == 770 then
    -- (packages left A from tick 700 on: they ride the 10 tiles to the pulley in about 190 ticks)
    t.riding = remote.call(CL, "packages")
    check(t.riding > 0, "packages ride towards the pulley (" .. t.riding .. ")")
    t.p.destroy({ raise_destroy = true })
  elseif ev.tick == 1000 then
    t.fell = ground(s, "iron-plate")
    check(t.fell > 0, "the packages riding to the mined pulley fell (" .. t.fell .. " plates)")
    check(remote.call(CL, "packages") == 0, "nothing in flight with no way on")
    check(remote.call(CL, "net", t.a.unit_number) ~= remote.call(CL, "net", t.c.unit_number), "A and C are apart")
    local n, p = t.req.get_item_count("iron-plate"), t.prov.get_item_count("iron-plate")
    check(n + p + t.fell == 200, "what fell + what arrived + what is left = 200 (" .. n .. " + " .. p .. " + " .. t.fell .. ")")
    -- a new pulley a little off the old spot: it links to C (nearest), and then to A
    t.p2 = mk("chl-chain-pulley", 10.5, -1.5)
    remote.call(CL, "connect", t.p2.unit_number, t.a.unit_number)
    check(remote.call(CL, "net", t.a.unit_number) == remote.call(CL, "net", t.c.unit_number), "a new pulley joins A and C")
  elseif ev.tick == 1700 then
    local n, p = t.req.get_item_count("iron-plate"), t.prov.get_item_count("iron-plate")
    check(n == 100, "the request is met over the new pulley (" .. n .. ")")
    check(n + p + t.fell == 200, "nothing lost (" .. n .. " + " .. p .. " + " .. t.fell .. ")")
    check(remote.call(CL, "bound", t.req.unit_number) == nil, "nothing is counted as on its way any more")
    check(remote.call(CL, "packages") == 0, "no package left in flight")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-pulley.txt", table.concat(out, "\n") .. "\n")
  end
end)
