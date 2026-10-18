-- a requester inside a logistic network with robots is left to the robots (no double delivery); with
-- "Chains also serve chests bots reach" on, chains serve it too. The provider is out of the robots' reach.
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
    for x = -60, 40 do for y = -30, 30 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    for x = -45, 0, 15 do mk("chl-chain-post", x + 0.5, 0.5) end
    t.prov = mk("passive-provider-chest", -45.5, 0.5)
    t.prov.insert({ name = "iron-plate", count = 100 })
    t.req = mk("requester-chest", 1.5, 0.5)
    local pt = t.req.get_requester_point()
    local sec = pt.get_section(1) or pt.add_section()
    sec.set_slot(1, { value = { name = "iron-plate", quality = "normal" }, min = 20 })
    local port = mk("roboport", 5, 5)
    port.insert({ name = "logistic-robot", count = 10 })
    mk("electric-energy-interface", 9, 9)
    mk("medium-electric-pole", 7.5, 7.5)
  elseif ev.tick == 100 then
    local net = t.req.get_requester_point().logistic_network
    check(net ~= nil and net.valid and net.all_logistic_robots > 0, "the requester is in a network with robots")
  elseif ev.tick == 800 then
    check(t.req.get_item_count("iron-plate") == 0, "chains left it to the robots (" .. t.req.get_item_count("iron-plate") .. ")")
    check(remote.call(CL, "bound", t.req.unit_number) == nil, "nothing on its way to it")
    remote.call(CL, "set_setting", "chl-share-with-bots", true)
  elseif ev.tick == 2400 then -- (45 tiles of chain: about 900 ticks a package)
    check(t.req.get_item_count("iron-plate") == 20, "with sharing on, chains served it (" .. t.req.get_item_count("iron-plate") .. ")")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-bots.txt", table.concat(out, "\n") .. "\n")
  end
end)
