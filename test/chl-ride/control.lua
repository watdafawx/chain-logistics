-- riding: posts A - B - C in a line (10 tiles apart) and D 10 tiles south of B. A character hooked onto A and sent
-- to C (named "Dest") rides the shortest way (not by D) at the span's speed and parks there, hung from the chain
-- and not destructible. Steering: south-southwest from C goes back to B, then south to D (the closest span to the
-- direction held). With no key held it keeps going: at D, the end of the line, it turns back. Holding north then
-- south mid-span turns it round. Sent to D, it parks; getting off by D's post (and a chest) lands it on a free spot.
-- Hooked on with no destination, facing east, it sets off at once and runs straight through B to C, then back. A post
-- mined under a rider drops it
local out, fails = {}, 0
local function check(ok, what)
  out[#out + 1] = (ok and "ok   " or "FAIL ") .. what
  if not ok then fails = fails + 1 end
end
local CL = "chain-logistics"
local D = defines.direction
local t = { seen = {}, phase = "idle" }
local SPEED = 13 / 256 -- (tier 1, normal quality)

local function st() return remote.call(CL, "rider", t.key) end

local function finish()
  out[#out + 1] = fails == 0 and "ALL PASS" or (fails .. " FAILED")
  helpers.write_file("chl-ride.txt", table.concat(out, "\n") .. "\n")
  t.phase = "done"
end

-- what else stands in the character's box
local function crowding(c)
  local n = 0
  for _, e in pairs(c.surface.find_entities_filtered({ area = c.bounding_box })) do
    if e ~= c and e.type ~= "item-entity" and #e.prototype.collision_mask.layers > 0 then n = n + 1 end
  end
  return n
end

script.on_event(defines.events.on_tick, function(ev)
  local s, f = game.surfaces.nauvis, game.forces.player
  local function mk(n, x, y) return s.create_entity({ name = n, position = { x, y }, force = f, raise_built = true }) end
  if ev.tick == 10 then
    local tiles = {}
    for x = -10, 40 do for y = -10, 30 do tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } } end end
    s.set_tiles(tiles)
    t.A, t.B, t.C = mk("chl-chain-post", 0.5, 0.5), mk("chl-chain-post", 10.5, 0.5), mk("chl-chain-post", 20.5, 0.5)
    t.D = mk("chl-chain-post", 10.5, 10.5)
    mk("wooden-chest", 9.5, 10.5)
    remote.call(CL, "set_name", t.C, "Dest")
    remote.call(CL, "set_name", t.D, "South")
    check(remote.call(CL, "links", t.D.unit_number)[t.B.unit_number], "D links to B")
    t.c = s.create_entity({ name = "character", position = { 0.5, 4.5 }, force = f })
    t.key = remote.call(CL, "ride", t.c, t.A.unit_number)
    check(t.key ~= nil, "the character hooks onto A")
    check(not t.c.destructible, "a rider isn't destructible")
    local named = remote.call(CL, "named", remote.call(CL, "net", t.A.unit_number))
    check(#named == 2, "two destinations on the network (" .. #named .. ")")
    check(remote.call(CL, "ride_to", t.key, t.C.unit_number), "ride to Dest")
    t.sent, t.phase = ev.tick, "to-C"
    return
  end
  local r = t.key and st()
  if t.phase == "to-C" then
    t.seen[r.node] = true
    if r.to == t.B.unit_number and not t.on_strand then
      -- (on A->B's right-hand strand: the south one, R * SQUASH below the posts)
      t.on_strand = math.abs(r.y - (0.5 + 0.36 * 0.7071)) < 0.01 and math.abs(t.c.position.y - (r.y + 0.8)) < 0.01
    end
    if r.node == t.C.unit_number and not r.to then
      local took = ev.tick - t.sent
      local want = math.ceil(20 / SPEED) -- (20 tiles of strand)
      check(math.abs(took - want) <= 3, "A to C takes about " .. want .. " ticks (" .. took .. ")")
      check(t.seen[t.B.unit_number] and not t.seen[t.D.unit_number], "it rode by B, not by D")
      check(r.dest == nil, "the route is done")
      check(t.on_strand, "it hangs from the right-hand strand")
      t.phase, t.at = "wait", ev.tick
    elseif ev.tick - t.sent > 600 then
      check(false, "reaches C (at node " .. tostring(r.node) .. ")")
      finish()
    end
  elseif t.phase == "wait" and ev.tick - t.at == 60 then
    check(r.node == t.C.unit_number and not r.to, "sent to C, it parks there")
    remote.call(CL, "ride_steer", t.key, D.southsouthwest)
    t.phase, t.at, t.seen = "to-D", ev.tick, {}
  elseif t.phase == "to-D" then
    t.seen[r.node] = true
    if r.to == t.A.unit_number then
      check(false, "south-southwest at B takes the span to D, not A")
      finish()
    elseif r.node == t.D.unit_number or r.to == t.D.unit_number and r.from == t.B.unit_number then
      if r.node == t.D.unit_number then
        remote.call(CL, "ride_steer", t.key, nil) -- (let go at D)
        check(t.seen[t.B.unit_number], "steered back to B, then south to D")
        t.phase, t.at = "bounce", ev.tick
      end
    elseif ev.tick - t.at > 900 then
      check(false, "steers to D")
      finish()
    end
  elseif t.phase == "bounce" and ev.tick - t.at == 30 then
    check(r.to == t.B.unit_number, "no key held at D, the end of the line: it turns back towards B")
    remote.call(CL, "ride_steer", t.key, D.north)
    t.phase, t.at = "turn", ev.tick
  elseif t.phase == "turn" then
    if ev.tick - t.at == 30 then
      check(r.to == t.B.unit_number, "north from D heads for B")
      t.mid = r.y
      remote.call(CL, "ride_steer", t.key, D.south)
    elseif ev.tick - t.at == 60 then
      check(r.to == t.D.unit_number and r.y > t.mid, "south mid-span turns it round")
      remote.call(CL, "ride_steer", t.key, nil)
      check(remote.call(CL, "ride_to", t.key, t.D.unit_number), "sent to South (D)")
    elseif ev.tick - t.at > 60 and r.node == t.D.unit_number and not r.to then
      local cx, cy = r.x, r.y
      remote.call(CL, "ride_off", t.key)
      check(st() == nil, "off the chain")
      local p = t.c.position
      check(crowding(t.c) == 0, "it lands on a free spot (" .. string.format("%.2f, %.2f", p.x, p.y) .. ")")
      check((p.x - cx) ^ 2 + (p.y - cy) ^ 2 < 4, "under the chain")
      check(t.c.destructible, "destructible again")
      -- hooked on with no destination, facing east: off at once, straight on through B (not D) to C, then back
      t.c.teleport({ 0.5, 4.5 })
      t.c.direction = D.east
      t.key = remote.call(CL, "ride", t.c, t.A.unit_number)
      t.phase, t.at, t.seen = "run", ev.tick, {}
    elseif ev.tick - t.at > 600 then
      check(false, "back at D")
      finish()
    end
  elseif t.phase == "run" then
    t.seen[r.node] = true
    if ev.tick - t.at == 2 then
      check(r.to == t.B.unit_number, "hooked on facing east, it sets off for B at once")
    elseif r.node == t.C.unit_number then
      -- (it turns back the same tick it gets there)
      check(t.seen[t.B.unit_number] and not t.seen[t.D.unit_number], "straight on through B, not to D")
      check(r.to == t.B.unit_number, "at C, the end of the line, back towards B")
      t.phase, t.at = "mine", ev.tick
    elseif ev.tick - t.at > 900 then
      check(false, "runs on to C and back (at node " .. tostring(r.node) .. ")")
      finish()
    end
  elseif t.phase == "mine" and ev.tick - t.at == 1 then
    check(st() and st().to == t.B.unit_number, "riding to B")
    t.B.destroy({ raise_destroy = true })
  elseif t.phase == "mine" and ev.tick - t.at == 2 then
    check(st() == nil, "B mined: the rider is dropped")
    check(t.c.destructible and crowding(t.c) == 0, "on a free spot, destructible")
    finish()
  end
end)
