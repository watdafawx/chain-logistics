-- names survive a blueprint round trip (tags, built back from ghosts revived with raise_revive) and a post's upgrade
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
  for x = -10, 40 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
  s.set_tiles(tiles)
  local post = mk("chl-chain-post", 0.5, 0.5)
  local load = mk("chl-loader", 1.5, 0.5)
  local unload = mk("chl-unloader", 0.5, 1.5)
  remote.call(CL, "set_name", post, "hub")
  remote.call(CL, "set_name", load, "out", "mall*")
  remote.call(CL, "set_name", unload, "mall-2")
  local inv = game.create_inventory(1)
  local bp = inv[1]
  bp.set_stack("blueprint")
  local mapping = bp.create_blueprint({ surface = s, force = f, area = { { -1, -1 }, { 3, 3 } } })
  remote.call(CL, "tag_blueprint", bp, mapping)
  local ghosts = bp.build_blueprint({ surface = s, force = f, position = { 20.5, 0.5 }, build_mode = defines.build_mode.forced })
  check(#ghosts == 3, "the blueprint builds three ghosts (" .. #ghosts .. ")")
  local got = {}
  for _, g in pairs(ghosts) do
    local _, e = g.revive({ raise_revive = true })
    if e then got[e.name] = e end
  end
  local p2, l2, u2 = got["chl-chain-post"], got["chl-loader"], got["chl-unloader"]
  check(p2 and l2 and u2, "all three revived")
  if p2 and l2 and u2 then
    check(remote.call(CL, "name", p2.unit_number) == "hub", "the post's name came back")
    check(remote.call(CL, "name", l2.unit_number) == "out", "the loader's name came back")
    check(remote.call(CL, "address", l2.unit_number) == "mall*", "the loader's address came back")
    check(remote.call(CL, "name", u2.unit_number) == "mall-2", "the unloader's name came back")
    check(remote.call(CL, "chest_post", u2.unit_number) == p2.unit_number, "the new unloader is served by the new post")
  end
  -- an upgrade keeps the post's name
  local up = s.create_entity({ name = "chl-chain-post-2", position = post.position, force = f, fast_replace = true,
    spill = false, raise_built = true })
  check(up ~= nil and remote.call(CL, "name", up.unit_number) == "hub", "an upgraded post keeps its name")
  -- an empty name forgets it
  remote.call(CL, "set_name", unload, "")
  check(remote.call(CL, "name", unload.unit_number) == nil, "an empty name clears it")
  inv.destroy()
  out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
  helpers.write_file("chl-names.txt", table.concat(out, "\n") .. "\n")
end)
