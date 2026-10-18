-- a requester by post C (two hops from A) asks for 50 iron; a passive provider by A holds 200. It gets exactly
-- 50, at a tier-1 post's rate (8-item packages every 32 ticks), and nothing more however long it waits
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local t = {}

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y) return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true }) end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 30 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    t.a, t.b, t.c = mk("chl-chain-post", 0.5, 0.5), mk("chl-chain-post", 10.5, 0.5), mk("chl-chain-post", 10.5, 8.5)
    t.prov = mk("passive-provider-chest", -0.5, 0.5)
    t.prov.insert({ name = "iron-plate", count = 200 })
    t.req = mk("requester-chest", 11.5, 8.5)
    local pt = t.req.get_requester_point()
    local sec = pt.get_section(1) or pt.add_section()
    sec.set_slot(1, { value = { name = "iron-plate", quality = "normal" }, min = 50 })
    check(remote.call(CL, "chest_post", t.prov.unit_number) == t.a.unit_number, "the provider is served by post A")
    check(remote.call(CL, "chest_post", t.req.unit_number) == t.c.unit_number, "the requester is served by post C")
    check(remote.call(CL, "net", t.a.unit_number) == remote.call(CL, "net", t.c.unit_number), "A and C are one network")
  elseif ev.tick == 420 then
    -- (packages leave every 32 ticks and ride about 360: by now two or three are in)
    local n = t.req.get_item_count("iron-plate")
    check(n >= 8 and n <= 24, "it comes a package at a time, not all at once (" .. n .. " at tick 420)")
  elseif ev.tick == 1500 then
    local n, p = t.req.get_item_count("iron-plate"), t.prov.get_item_count("iron-plate")
    check(n == 50, "the requester got exactly 50 (" .. n .. ")")
    check(p == 150, "the provider gave exactly 50 (" .. p .. " left)")
    check(remote.call(CL, "bound", t.req.unit_number) == nil, "nothing is counted as on its way any more")
    check(remote.call(CL, "packages") == 0, "no package left in flight")
    check(#s.find_entities_filtered({ type = "item-entity" }) == 0, "nothing spilled")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-request.txt", table.concat(out, "\n") .. "\n")
  end
end)
