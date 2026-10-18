-- machines and belts through vanilla inserters: an assembler makes gears, an inserter puts them into a loader
-- addressed "GEARS", the chains carry them to the unloader named "gears", and an inserter takes them out onto a belt
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local t = {}
local W, S = defines.direction.west, defines.direction.south

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y, d)
    return s.create_entity({ name = n, position = { x, y }, force = f, direction = d, raise_built = true })
  end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 30 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    -- power: an endless source and a substation over everything
    local eei = mk("electric-energy-interface", 9, 8)
    eei.power_production, eei.electric_buffer_size = 1e9, 1e9
    mk("substation", 9, 4)
    t.asm = mk("assembling-machine-1", 1.5, 1.5)
    t.asm.set_recipe("iron-gear-wheel")
    t.asm.insert({ name = "iron-plate", count = 100 })
    mk("inserter", 3.5, 1.5, W) -- (an inserter's direction is the side it takes from)
    t.load = mk("chl-loader", 4.5, 1.5)
    remote.call(CL, "set_name", t.load, nil, "GEARS")
    mk("chl-chain-post", 4.5, 2.5)
    mk("chl-chain-post", 14.5, 2.5)
    t.unload = mk("chl-unloader", 14.5, 1.5)
    remote.call(CL, "set_name", t.unload, "gears")
    mk("inserter", 14.5, 0.5, S)
    t.belts = {}
    for x = 14, 20 do t.belts[#t.belts + 1] = mk("transport-belt", x + 0.5, -0.5, defines.direction.east) end
  elseif ev.tick == 2400 then
    local on = 0
    for _, b in pairs(t.belts) do
      for i = 1, 2 do on = on + b.get_transport_line(i).get_item_count("iron-gear-wheel") end
    end
    check(on >= 10, "gears reach the belt through loader, chains and unloader (" .. on .. " on the belt)")
    local made = t.asm.products_finished
    local inside = t.load.get_item_count("iron-gear-wheel") + t.unload.get_item_count("iron-gear-wheel")
    check(made >= on, "no more on the belt than the assembler made (" .. made .. " made, " .. inside .. " in chests)")
    check(#s.find_entities_filtered({ type = "item-entity" }) == 0, "nothing spilled")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-loader.txt", table.concat(out, "\n") .. "\n")
  end
end)
