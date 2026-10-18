-- tiers: a tier-2 pair moves about twice a tier-1 pair's items; a package rides a tier-3 span in half a tier-1
-- span's time, and a tier-1/tier-3 span at tier 1's speed (its links crawl at that speed too). Then the mixed
-- span's tier-1 post is fast-replaced by a tier-2 one: it keeps its span (now at tier 2) and its chest
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local t = { at = {} }

-- the span animations drawn between y0 and y1
local function spans(y0, y1)
  local names = {}
  for _, o in pairs(rendering.get_all_objects(CL)) do
    if o.type == "animation" then
      local y = o.target.position.y
      if y >= y0 and y <= y1 then names[o.animation] = true end
    end
  end
  local l = {}
  for n in pairs(names) do l[#l + 1] = n end
  table.sort(l)
  return table.concat(l, ",")
end

-- the tick each chest first got something
script.on_event(defines.events.on_tick, function(ev)
  for k, c in pairs({ mixed = t.mixed_chest, fast = t.fast_chest }) do
    if c and c.valid and not t.at[k] and c.get_item_count() > 0 then t.at[k] = ev.tick end
  end
  if t.mixed_chest and t.mixed_chest.valid and not t.at.up and t.mixed_chest.get_item_count("copper-plate") > 0 then
    t.at.up = ev.tick
  end
end)

script.on_nth_tick(10, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y, fr)
    return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true, fast_replace = fr, spill = false })
  end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 30 do for y = -10, 100 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    -- rate: a tier-1 and a tier-2 pair, a provider by one post and a requester by the other, 10 tiles apart
    for i, tier in ipairs({ 1, 2 }) do
      local y = (i - 1) * 30 + 0.5
      local name = tier == 1 and "chl-chain-post" or "chl-chain-post-2"
      local a, b = mk(name, 0.5, y), mk(name, 10.5, y)
      local prov = mk("passive-provider-chest", -0.5, y)
      prov.insert({ name = "iron-plate", count = 4000 })
      local req = mk("requester-chest", 11.5, y)
      local pt = req.get_requester_point()
      local sec = pt.get_section(1) or pt.add_section()
      sec.set_slot(1, { value = { name = "iron-plate", quality = "normal" }, min = 4000 })
      t["req" .. tier] = req
      check(remote.call(CL, "tier", b.unit_number) == tier, "a " .. name .. " is tier " .. tier)
    end
    -- speed: a tier-1/tier-3 span and a tier-3/tier-3 one, a package each
    t.m1, t.m3 = mk("chl-chain-post", 0.5, 60.5), mk("chl-chain-post-3", 10.5, 60.5)
    t.mixed_chest = mk("steel-chest", 11.5, 60.5)
    t.f1, t.f2 = mk("chl-chain-post-3", 0.5, 90.5), mk("chl-chain-post-3", 10.5, 90.5)
    t.fast_chest = mk("steel-chest", 11.5, 90.5)
    check(remote.call(CL, "links", t.m3.unit_number)[t.m1.unit_number], "posts of different tiers link")
    remote.call(CL, "send", t.m1.unit_number, t.m3.unit_number, { { name = "iron-plate", count = 10 } })
    remote.call(CL, "send", t.f1.unit_number, t.f2.unit_number, { { name = "iron-plate", count = 10 } })
    t.sent = ev.tick
    check(spans(55, 65) == "chl-span-1,chl-span-shadow-1", "the mixed span's links crawl at tier 1 (" .. spans(55, 65) .. ")")
    check(spans(85, 95) == "chl-span-3,chl-span-shadow-3", "the tier-3 span's links crawl at tier 3 (" .. spans(85, 95) .. ")")
  elseif ev.tick == 300 then
    -- 10-tile strands: 197 ticks at tier 1's 13/256, 99 at tier 3's 26/256
    local mixed, fast = (t.at.mixed or 0) - t.sent, (t.at.fast or 0) - t.sent
    check(math.abs(fast - 99) <= 3, "a tier-3 span takes about 99 ticks (" .. fast .. ")")
    check(math.abs(mixed - 197) <= 3, "a tier-1/tier-3 span runs at tier 1: about 197 ticks (" .. mixed .. ")")
    -- the upgrade
    local old = t.m1.unit_number
    local up = mk("chl-chain-post-2", 0.5, 60.5, true)
    check(up and up.valid and not t.m1.valid, "fast-replace swaps the post")
    if up and up.valid then
      t.m1 = up
      check(remote.call(CL, "tier", up.unit_number) == 2, "the new post is tier 2")
      check(remote.call(CL, "tier", old) == nil, "the old one is forgotten")
      local links = remote.call(CL, "links", up.unit_number) or {}
      check(links[t.m3.unit_number] and remote.call(CL, "links", t.m3.unit_number)[up.unit_number],
        "it keeps the old post's span")
      check(spans(55, 65) == "chl-span-2,chl-span-shadow-2", "the span is redrawn at tier 2 (" .. spans(55, 65) .. ")")
      remote.call(CL, "send", up.unit_number, t.m3.unit_number, { { name = "copper-plate", count = 10 } })
      t.sent_up = ev.tick
    end
  elseif ev.tick == 400 then
    t.n1, t.n2 = t.req1.get_item_count("iron-plate"), t.req2.get_item_count("iron-plate")
  elseif ev.tick == 1000 then
    -- 600 ticks: tier 1 sends 8 every 32 (150), tier 2 15 every 30 (300)
    local d1, d2 = t.req1.get_item_count("iron-plate") - t.n1, t.req2.get_item_count("iron-plate") - t.n2
    check(math.abs(d1 - 150) <= 16, "a tier-1 pair moves about 15 items/s (" .. d1 .. " in 600 ticks)")
    check(math.abs(d2 - 300) <= 30, "a tier-2 pair moves about 30 items/s (" .. d2 .. " in 600 ticks)")
    check(d1 > 0 and d2 / d1 > 1.8 and d2 / d1 < 2.2, "tier 2 moves about twice tier 1 (" .. string.format("%.2f", d2 / math.max(d1, 1)) .. "x)")
    local took = (t.at.up or 0) - (t.sent_up or 0)
    -- 10 tiles at tier 2's 19/256: 135 ticks
    check(math.abs(took - 135) <= 3, "after the upgrade the span runs at tier 2: about 135 ticks (" .. took .. ")")
    check(#s.find_entities_filtered({ type = "item-entity" }) == 0, "nothing spilled")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-tiers.txt", table.concat(out, "\n") .. "\n")
  end
end)
