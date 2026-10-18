-- a loader addressed "smelt*" by post A holds 40 iron: all of it goes to the unloader named "Smelter-1" by post C,
-- none to the one named "mall" by post B (nearer). A loader whose address matches nothing keeps what it holds. A
-- loader with no address supplies a requester like a passive provider chest would (the mall asks for copper).
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
    t.load = mk("chl-loader", -0.5, 0.5)
    t.load.insert({ name = "iron-plate", count = 40 })
    remote.call(CL, "set_name", t.load, nil, "smelt*")
    t.lost = mk("chl-loader", 0.5, 1.5)
    t.lost.insert({ name = "stone", count = 10 })
    remote.call(CL, "set_name", t.lost, nil, "nowhere")
    t.plain = mk("chl-loader", 1.5, 0.5)
    t.plain.insert({ name = "copper-plate", count = 30 })
    t.mall = mk("chl-unloader", 11.5, 0.5)
    remote.call(CL, "set_name", t.mall, "mall")
    local pt = t.mall.get_requester_point()
    local sec = pt.get_section(1) or pt.add_section()
    sec.set_slot(1, { value = { name = "copper-plate", quality = "normal" }, min = 10 })
    t.smelt = mk("chl-unloader", 11.5, 8.5)
    remote.call(CL, "set_name", t.smelt, "Smelter-1")
    check(remote.call(CL, "chest_post", t.load.unit_number) == t.a.unit_number, "the loader is served by post A")
    check(remote.call(CL, "chest_post", t.smelt.unit_number) == t.c.unit_number, "the smelter unloader by post C")
    check(remote.call(CL, "address", t.load.unit_number) == "smelt*", "the loader has its address")
    check(remote.call(CL, "name", t.smelt.unit_number) == "Smelter-1", "the unloader has its name")
    local named = remote.call(CL, "named", remote.call(CL, "net", t.a.unit_number))
    check(#named == 2, "the network lists its two named unloaders (" .. #named .. ")")
  elseif ev.tick == 1500 then
    local n = t.smelt.get_item_count("iron-plate")
    check(n == 40, "Smelter-1 got all 40 iron (" .. n .. ")")
    check(t.mall.get_item_count("iron-plate") == 0, "the mall got no iron")
    check(t.load.get_item_count("iron-plate") == 0, "the loader is empty")
    check(t.lost.get_item_count("stone") == 10, "the loader addressed to nowhere kept its stone")
    local cu = t.mall.get_item_count("copper-plate")
    check(cu == 10, "the mall got the 10 copper it asks for from the loader with no address (" .. cu .. ")")
    check(t.plain.get_item_count("copper-plate") == 20, "that loader gave exactly 10")
    check(t.smelt.get_item_count("copper-plate") == 0, "the smelter (no requests) got no copper")
    check(remote.call(CL, "packages") == 0, "no package left in flight")
    check(#s.find_entities_filtered({ type = "item-entity" }) == 0, "nothing spilled")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-address.txt", table.concat(out, "\n") .. "\n")
  end
end)
