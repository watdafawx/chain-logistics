-- belts faster than express get chain post tiers that move as much: 60/s and 75/s belts -> tiers 4 and 5 (the two
-- 60/s belts share one), each made from the tier before + that belt, unlocked with it, upgrading the one before; a
-- tier-4 pair delivers at about 60 items a second
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
    local tt = remote.call(CL, "tiers")
    check(#tt.posts == 5, "two more tiers for three faster belts (" .. #tt.posts .. " tiers)")
    local t4, t5 = tt.tiers[4], tt.tiers[5]
    local function per_s(x) return x.package * 60 / x.cooldown end
    check(t4 and math.abs(per_s(t4) - 60) < 2, "tier 4 moves about 60/s (" .. (t4 and per_s(t4) or -1) .. ")")
    check(t5 and math.abs(per_s(t5) - 75) < 2, "tier 5 moves about 75/s (" .. (t5 and per_s(t5) or -1) .. ")")
    check(t4 and t5 and t5.speed > t4.speed and t4.speed > tt.tiers[3].speed, "each rides faster than the one before")
    local p3, p4 = prototypes.entity["chl-chain-post-3"], prototypes.entity["chl-chain-post-4"]
    check(p3 and p3.next_upgrade and p3.next_upgrade.name == "chl-chain-post-4", "express posts upgrade to tier 4")
    check(p4 and p4.next_upgrade and p4.next_upgrade.name == "chl-chain-post-5", "and tier 4 to tier 5")
    local r = prototypes.recipe["chl-chain-post-4"]
    local has = {}
    for _, i in pairs(r.ingredients) do has[i.name] = i.amount end
    check(has["chl-chain-post-3"] == 1 and (has["chl-test-belt-a"] or has["chl-test-belt-b"]), "made from an express post + its belt")
    local unlocks = false
    for _, e in pairs(prototypes.technology["chl-test-belts"].effects) do
      if e.type == "unlock-recipe" and e.recipe == "chl-chain-post-5" then unlocks = true end
    end
    check(unlocks, "tier 5 unlocks with its belt's technology")
    local tiles = {}
    for x = -10, 30 do for y = -10, 20 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    mk("chl-chain-post-4", 0.5, 0.5)
    mk("chl-chain-post-4", 10.5, 0.5)
    t.prov = mk("passive-provider-chest", -0.5, 0.5)
    t.prov.insert({ name = "iron-plate", count = 1000 })
    t.req = mk("requester-chest", 11.5, 0.5)
    local pt = t.req.get_requester_point()
    local sec = pt.get_section(1) or pt.add_section()
    sec.set_slot(1, { value = { name = "iron-plate", quality = "normal" }, min = 1000 })
  elseif ev.tick == 400 then
    t.n0 = t.req.get_item_count("iron-plate") -- (by now the first packages are in: count from here)
  elseif ev.tick == 700 then
    local per_s = (t.req.get_item_count("iron-plate") - t.n0) / 5
    check(math.abs(per_s - 60) <= 10, "a tier-4 pair moves about 60 items a second (" .. per_s .. ")")
    out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
    helpers.write_file("chl-belt-tiers.txt", table.concat(out, "\n") .. "\n")
  end
end)
