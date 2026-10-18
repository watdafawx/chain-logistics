-- a chest is served by the nearest post in reach; when that post goes it moves to the other one, and with none
-- left it isn't served. A modded 2x2 logistic chest (data.lua here) is served by a post at its edge.
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"

script.on_nth_tick(10, function(ev)
  if ev.tick ~= 10 then return end
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y) return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true }) end
  local tiles = {}
  for x = -10, 30 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
  s.set_tiles(tiles)
  local chest = mk("buffer-chest", 1.5, 0.5)
  check(remote.call(CL, "chest_post", chest.unit_number) == nil, "a chest with no post isn't served")
  local a = mk("chl-chain-post", 0.5, 0.5)
  check(remote.call(CL, "chest_post", chest.unit_number) == a.unit_number, "a post built next to it takes it")
  local b = mk("chl-chain-post", 2.5, 1.5)
  check(remote.call(CL, "chest_post", chest.unit_number) == a.unit_number, "a farther post doesn't take it over")
  a.destroy({ raise_destroy = true })
  check(remote.call(CL, "chest_post", chest.unit_number) == b.unit_number, "when its post goes, the other post takes it")
  b.destroy({ raise_destroy = true })
  check(remote.call(CL, "chest_post", chest.unit_number) == nil, "with no post left, it isn't served")
  local far = mk("chl-chain-post", 6.5, 6.5)
  local wide = mk("chl-test-wide-chest", 9, 6) -- (2x2: x 8-10, y 5-7)
  local near = mk("chl-chain-post", 10.5, 7.5)
  check(remote.call(CL, "chest_post", wide.unit_number) == near.unit_number,
    "a modded 2x2 logistic chest is served by the post at its corner")
  check(remote.call(CL, "chest_post", wide.unit_number) ~= far.unit_number, "not the one out of reach")
  out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
  helpers.write_file("chl-attach.txt", table.concat(out, "\n") .. "\n")
end)
