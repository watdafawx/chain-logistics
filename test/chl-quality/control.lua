-- quality: legendary posts span 25 tiles (normal ones don't), send packages of 8 x 2.5 = 20 items (a normal one 8),
-- serve a chest 2 tiles off their edge (a normal one doesn't), and a legendary pair delivers faster than a normal pair
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local t = { first = {}, count = {} }

-- the tick each requester first got something, and how much
script.on_event(defines.events.on_tick, function(ev)
  for k, c in pairs({ legendary = t.req_l, normal = t.req_n }) do
    if c and c.valid and not t.first[k] then
      local n = c.get_item_count()
      if n > 0 then t.first[k], t.count[k] = ev.tick, n end
    end
  end
end)

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y, q)
    return s.create_entity({ name = n, position = { x, y }, force = f, quality = q, raise_built = true, spill = false })
  end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 40 do for y = -10, 140 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    -- a provider by one post and a requester by the other, 15 tiles apart, legendary and normal
    for _, q in ipairs({ "legendary", "normal" }) do
      local y = (q == "legendary" and 30 or 60) + 0.5
      local a, b = mk("chl-chain-post", 0.5, y, q), mk("chl-chain-post", 15.5, y, q)
      local prov = mk("passive-provider-chest", -0.5, y)
      prov.insert({ name = "iron-plate", count = 4000 })
      local req = mk("requester-chest", 16.5, y)
      local pt = req.get_requester_point()
      local sec = pt.get_section(1) or pt.add_section()
      sec.set_slot(1, { value = { name = "iron-plate", quality = "normal" }, min = 4000 })
      t[q == "legendary" and "req_l" or "req_n"] = req
      check(remote.call(CL, "links", a.unit_number)[b.unit_number], q .. " posts 15 tiles apart link")
    end
    -- reach: a chest 2 tiles off a post's edge
    for _, q in ipairs({ "legendary", "normal" }) do
      local y = (q == "legendary" and 90 or 100) + 0.5
      local post = mk("chl-chain-post", 0.5, y, q)
      local chest = mk("storage-chest", 3.5, y)
      local served = remote.call(CL, "chest_post", chest.unit_number) == post.unit_number
      check(served == (q == "legendary"), "a chest 2 tiles off a " .. q .. " post is " .. (served and "" or "not ") .. "served")
    end
    -- span range: 25 tiles
    for _, q in ipairs({ "legendary", "normal" }) do
      local y = (q == "legendary" and 120 or 130) + 0.5
      local a, b = mk("chl-chain-post", 0.5, y, q), mk("chl-chain-post", 25.5, y, q)
      local linked = remote.call(CL, "links", a.unit_number)[b.unit_number] == true
      check(linked == (q == "legendary"), "two " .. q .. " posts 25 tiles apart " .. (linked and "link" or "don't link"))
    end
    -- a mixed pair is held to the normal post's range
    local a, b = mk("chl-chain-post", 0.5, 110.5, "legendary"), mk("chl-chain-post", 25.5, 110.5)
    check(not remote.call(CL, "links", a.unit_number)[b.unit_number], "a legendary and a normal post 25 tiles apart don't link")
  elseif ev.tick == 1000 then
    check(t.count.legendary == 20, "a legendary source sends 8 x 2.5 = 20 items (" .. tostring(t.count.legendary) .. ")")
    check(t.count.normal == 8, "a normal source sends 8 (" .. tostring(t.count.normal) .. ")")
    local l, n = t.first.legendary, t.first.normal
    check(l and n and l < n, "a legendary pair delivers first (tick " .. tostring(l) .. " vs " .. tostring(n) .. ")")
    check(#s.find_entities_filtered({ type = "item-entity" }) == 0, "nothing spilled")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-quality.txt", table.concat(out, "\n") .. "\n")
  end
end)
