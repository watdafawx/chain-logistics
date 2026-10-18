-- vanilla's order: a requester wanting 30 copper is served by the active provider (20, far) before the passive one
-- (100, near); what the active provider holds beyond that goes to the storage chest
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local t = {}

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y) return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true }) end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 40 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    mk("chl-chain-post", 0.5, 0.5)
    mk("chl-chain-post", 14.5, 0.5)
    mk("chl-chain-post", 28.5, 0.5)
    t.active = mk("active-provider-chest", -0.5, 0.5)
    t.active.insert({ name = "copper-plate", count = 20 })
    t.active.insert({ name = "iron-gear-wheel", count = 5 }) -- (nobody asks for these: they go to storage)
    t.storage = mk("storage-chest", 0.5, 1.5)
    t.passive = mk("passive-provider-chest", 27.5, 0.5)
    t.passive.insert({ name = "copper-plate", count = 100 })
    t.req = mk("requester-chest", 29.5, 0.5)
    local pt = t.req.get_requester_point()
    local sec = pt.get_section(1) or pt.add_section()
    sec.set_slot(1, { value = { name = "copper-plate", quality = "normal" }, min = 30 })
  elseif ev.tick == 2400 then
    local r, p = t.req.get_item_count("copper-plate"), t.passive.get_item_count("copper-plate")
    local st = t.storage.get_item_count("copper-plate")
    check(r == 30, "the requester got 30 (" .. r .. ")")
    check(p >= 90, "the passive provider gave at most the 10 the others couldn't (" .. p .. " left)")
    check(r + p + st == 120, "no copper lost or made (" .. (r + p + st) .. ")")
    check(t.active.get_inventory(defines.inventory.chest).is_empty(), "the active provider is empty")
    check(t.storage.get_item_count("iron-gear-wheel") == 5, "its gears went to storage (" .. t.storage.get_item_count("iron-gear-wheel") .. ")")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-priority.txt", table.concat(out, "\n") .. "\n")
  end
end)
