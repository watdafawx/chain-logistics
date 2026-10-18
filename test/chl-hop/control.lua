-- a package rides two spans (a -> b -> c) into a chest beside c, on time; a second one, sent on a line whose middle
-- post is mined while it rides, falls to the ground with nothing lost
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local t = {}

local function count(s, area, name)
  local n = 0
  for _, e in pairs(s.find_entities_filtered({ area = area, type = "item-entity" })) do
    if e.stack.name == name then n = n + e.stack.count end
  end
  return n
end

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y) return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true }) end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 40 do for y = -10, 30 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    t.a, t.b, t.c = mk("chl-chain-post", 0.5, 0.5), mk("chl-chain-post", 10.5, 0.5), mk("chl-chain-post", 10.5, 8.5)
    t.chest = mk("steel-chest", 11.5, 8.5)
    check(remote.call(CL, "links", t.c.unit_number)[t.b.unit_number] and remote.call(CL, "links", t.b.unit_number)[t.a.unit_number],
      "posts link to the nearest one in reach")
    t.id = remote.call(CL, "send", t.a.unit_number, t.c.unit_number, { { name = "iron-plate", count = 50 } })
    t.sent = ev.tick
    check(t.id ~= nil, "send finds a route")
    check(#s.find_entities_filtered({ name = "chl-package" }) == 1, "a package projectile rides")
    -- a second line: d - e - g, e mined mid-ride
    t.d, t.e, t.g = mk("chl-chain-post", 0.5, 20.5), mk("chl-chain-post", 12.5, 20.5), mk("chl-chain-post", 24.5, 20.5)
    remote.call(CL, "send", t.d.unit_number, t.g.unit_number, { { name = "copper-plate", count = 30 } })
  elseif ev.tick == 100 then
    t.e.destroy({ raise_destroy = true })
  elseif ev.tick == 500 then
    local got = t.chest.get_item_count("iron-plate")
    check(got == 50, "the chest got 50 iron plates (" .. got .. ")")
    local last = remote.call(CL, "last_delivered")
    -- strands run 10 and 8 tiles at 0.05 a tick: 360 ticks
    local took = last and last.arrived - last.sent or -1
    check(last and last.hops == 2 and math.abs(took - 360) <= 3, "two hops in about 360 ticks (" .. took .. ")")
    local spilled = count(s, { { -2, 17 }, { 16, 24 } }, "copper-plate")
    check(spilled == 30, "the package whose post went fell with all 30 copper plates (" .. spilled .. ")")
    check(remote.call(CL, "packages") == 0, "no package left in flight")
    check(#s.find_entities_filtered({ name = "chl-package" }) == 0, "no projectile left")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-hop.txt", table.concat(out, "\n") .. "\n")
  end
end)
