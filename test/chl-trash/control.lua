-- what lands in a requester's trash slots goes to a storage chest on the network
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
    for x = -10, 30 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    mk("chl-chain-post", 0.5, 0.5)
    mk("chl-chain-post", 12.5, 0.5)
    t.storage = mk("storage-chest", -0.5, 0.5)
    t.req = mk("requester-chest", 13.5, 0.5)
    local trash = t.req.get_inventory(defines.inventory.logistic_container_trash)
    check(trash ~= nil and #trash > 0, "a requester has trash slots")
    trash.insert({ name = "stone", count = 30 })
  elseif ev.tick == 900 then
    local trash = t.req.get_inventory(defines.inventory.logistic_container_trash)
    check(trash.is_empty(), "its trash slots emptied")
    check(t.storage.get_item_count("stone") == 30, "into storage (" .. t.storage.get_item_count("stone") .. ")")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-trash.txt", table.concat(out, "\n") .. "\n")
  end
end)
