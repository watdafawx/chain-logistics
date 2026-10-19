# Chain Logistics

Packages ride overhead chains between chain posts: belts on the ground, items in the air. Inspired by Create's
chain conveyors and frogports. Status: **0.2**: posts in three tiers, spans, logistic chests served over the chain network, and package
loaders / unloaders with names and addresses.

## Logistic chests (0.1)
Every chain post serves the logistic chests next to it (within a tile of the chest's edge: any `logistic-container`,
so AAI Containers, Wide Chests and the like work too). Alt mode shows a line from each post to the chests it serves.
- **Requester / buffer** chests get what they ask for from chests on the same chain network, in vanilla's order:
  active provider, storage, buffer (never buffer to buffer), passive provider; nearest first within a rank. Priority
  is strict: if the best source's post is busy, the request waits for it.
- **Active providers** and **requesters' trash** empty into storage chests (one already holding the item first).
- Items leave the source chest when the package is sent; packages on their way count towards the request, so nothing
  is over-delivered.
- **Robots**: a requester or buffer chest in a logistic network that has robots is left to them (they can't see
  packages on the way). The map setting *Chains also serve chests bots reach* lets chains help (a little extra may
  arrive).
- **Tiers**, like belts (`shared.lua`'s `TIERS`): a chain post sends one 8-item package every 32 ticks (about a
  yellow belt, 15 items/s), a fast chain post 15 every 30 (30/s, red belt, Logistics 2), an express one 30 every 40
  (45/s, blue belt, Logistics 3, needs lubricant). Packages ride 13, 19 and 26 /256 tiles a tick (whole 1/256ths: the
  engine floors a projectile's speed to that, and each tier's chain sprite crawls at exactly its speed). A span runs
  at its slower post's tier. The map setting *Package size* multiplies the package. A post shows its tier as 1-3
  neon collars on its spike. Building a tier over another (or the upgrade planner) upgrades in place: the post keeps
  its spans, its chests and the packages riding to it.
- **Cost**: a round-robin cursor looks at *Chests checked a tick* (default 4) chests a tick. 200 chests on a
  50-post network: 0.23 ms a tick on average, 20 us a package hop.

## Loaders, unloaders and names
Not only logistic chests: machines and belts join the chains through vanilla inserters.
- A **package loader** (an 8-slot chest next to a post) ships what inserters put in. With an **address** it sends it,
  a package at a time, to the nearest unloader on its chain network whose name matches (`*` matches anything,
  `smelt*` finds `Smelter-1`; case doesn't matter). If no unloader matches (or none has room), the items stay put.
  With no address it supplies the chests that ask, like a passive provider chest.
- A **package unloader** (an 8-slot requester chest, vanilla's request window) gets what it asks for like any
  requester, and also takes whatever loaders send to its name. Inserters take it out. If it fills up while a package
  rides, the package goes into another chest at that post, else falls by it.
- **Names**: click a post (it opens a small window), or open a loader or unloader (a panel beside its window).
  Names and addresses ride along in blueprints and copy-paste (shift right-click, shift left-click), and an
  upgraded post keeps its name. Remote: `name(unit)`, `address(unit)`, `set_name(entity, name, address)`,
  `named(network)` (the named posts and unloaders of a network: `{unit, name, kind, post}`).
- Both are cheap and there from the start (an iron chest and 2 gears). Their look is a stand-in for now (tinted
  vanilla chests: loader cyan, unloader magenta); proper art is a later pass.

## Riding the chains
Like Create's chain conveyors: hang on and ride.
- **Hook on**: the vehicle key (Enter by default, whatever *Enter or exit vehicle* is bound to) within 2 tiles of a
  post or pulley. The character hangs under a trolley on the chain and can't be hurt up there.
- **Rides on by itself** (0.3.4), like a train: it sets off at once along the span closest to the way the character
  faces, goes straight on through posts (the span closest to the way it came in), and at the end of a line turns back,
  until you get off. A walking key held at a post picks the span closest to it; holding the way back turns round
  mid-span. Bent pulleys are passed without stopping. A rider rides the span's right-hand strand at its speed (its
  tier and quality), like a package.
- **Ride to a name**: while riding, a small window lists the network's named posts and unloaders; click one and it
  rides the shortest way there and parks; a walking key sets it off again (and takes over from a route).
- **Get off**: the vehicle key again (or *Get off* in the window). Dying, getting into a vehicle, leaving the game
  or the chain going under it (a post mined) drop it too, on the nearest free spot under the chain.
- Cost: one teleport a tick a rider. Remote (tests): `ride(character, unit[, player_index])`, `ride_to(key, unit)`,
  `ride_steer(key, direction)`, `rider(key)`, `ride_off(key)` (the key: the player index, `"c<unit>"` without one).
- The look is a stand-in: the package's case as the trolley, two straps. The character's own sprite can't be hidden
  from script, so it hangs as it is (standing still).

- **Faster modded belts** (0.3): `data-updates.lua` gives every transport belt faster than express its own tier
  (items/s = belt speed x 480; a package every 40 ticks holding that much; made from the tier before + 5 of the belt,
  unlocked by the belt's technology; belts of one speed share a tier; up to 6 tiers). The finished tier table reaches
  control.lua as the `chl-tiers` mod-data prototype (`shared.lua` reads it). With Space Age: tier 4, turbo, 60/s.

Known: vanilla shows its "not in a logistic network" icon on logistic chests outside roboport reach, chains or not.

**Range ring** (0.3.1): placing a post or pulley, or hovering one, shows its span range as a ring in the skin's neon
(`radius_visualisation_specification`, the way pole supply areas and show-max-underground-distance work). A
prototype can't vary it by quality, so it shows a normal post's 16 tiles; better quality reaches farther.
**While holding** a post or pulley (the item, a ghost, or a blueprint / book page with one), the previous post (the
one you placed last, else the nearest) shows its farthest reachable tile in 8 directions as dim yellow squares, like
show-max-underground-distance marks an underground's reach (16 tiles straight, 11 diagonally at normal quality; its
own quality's range). Hovering a square lights it and says how far it is. Only you see them (`rings.lua`). Scripts
can't read the mouse, so each square has an invisible, hidden entity to hover (`chl-reach-spot`: blocks nothing, never
blueprinted or mined, real entities win the selection). (The cursor event comes a tick after a script sets the cursor;
headless tests have no player, so this was checked in a client game.)

## How it works
- A **chain post** links to the nearest post within 16 tiles. A span is two strands, one each way, drawn with
  `rendering` (no per-tick cost).
- A package rides each span as a **projectile**: the engine moves it, and the script only hears when it reaches
  the next post (`on_script_trigger_effect`). Cost: one event per hop, nothing per tick.
- A **chain pulley** (2 iron plates, a gear) bends a line: it links like a post, but serves no chests and has no
  tier (a span to it runs at the other end's tier; between two pulleys, tier 1). With two spans the chain wraps
  round it in an arc, and packages ride round the bend without stopping.
- Routes are shortest paths over spans. If a post goes while a package rides, the package reroutes or falls with
  everything in it.

Remote interface `chain-logistics`: `send(from_unit, to_unit, items)`, `connect(a, b)`, `disconnect(a, b)`,
`packages()`, `last_delivered()`, `links(unit)`.

## Art
Cyberpunk: a hex pad and spike, the head hovering over it in holo rings, a neon-link chain, a hard-case package.
Four skins (startup setting **Look**): magenta + cyan, toxic green + yellow, orange + blue, red + white. The lit
parts are a light layer too, so they glow at night.

Rendered in Blender (Steam's works) from scripts, so it can be rebuilt (about 1 minute for all skins):

    blender -b --factory-startup --python art/build.py -- OUT_DIR [SKIN ...]
    python art/pack.py OUT_DIR

`art/rig.py` holds the camera matched to vanilla (orthographic, 45 degrees, 64 px a tile, a warm sun from the west)
and the materials (rust, worn edges, crevice shading, glow); `art/calibrate.py` renders boxes to hold next to
vanilla's steel chest. `pack.py` crops each skin's frames into `graphics/entity/<skin>/` sheets (main, `-shadow`,
`-glow`) and writes `prototypes/sprites.lua` (sizes, shifts). Chain height and speeds live in `shared.lua`.
`art/concepts*.py` are the look studies the style was picked from (whole scenes in the game's camera).

## Tests
`python test/run.py --all`:
- `chl-hop`: a two-hop delivery on time, and a package whose post is mined mid-ride.
- `chl-request`: a requester two hops away gets exactly what it asks for, a package at a time.
- `chl-priority`: active provider before passive; leftovers to storage.
- `chl-trash`: a requester's trash goes to storage.
- `chl-bots`: a requester in a robot network is left to robots, unless sharing is on.
- `chl-attach`: nearest post in reach, handover when a post goes, a modded 2x2 chest.
- `chl-pulley`: an L-shaped line through a pulley delivers exactly; the pulley serves no chest and shows its arc
  with two spans only; mining it mid-ride drops the packages with nothing lost, and a new pulley restores the route.
- `chl-address`: a loader addressed `smelt*` sends all its iron to `Smelter-1`, not to the nearer `mall`; one
  addressed to nowhere keeps its items; one with no address supplies a requester (passive provider rank).
- `chl-loader`: assembler -> inserter -> loader -> chains -> unloader -> inserter -> belt, by address.
- `chl-belt-tiers`: test belts at 60 and 75/s (two at 60) make tiers 4 and 5 with the right throughput, recipes,
  unlocks and upgrade chain; a tier-4 pair moves about 60 items/s.
- `chl-names`: names and an address survive a blueprint round trip (ghosts revived with `raise_revive`) and an upgrade.
- `chl-ride`: a rider sent to a named post rides the shortest way at the span's speed and parks there; steering picks
  the span closest to the direction held and turns round mid-span; with no key it turns back at the end of a line;
  hooked on facing east it sets off at once, straight through a junction; getting off (by a post and a chest) lands
  on a free spot; a post mined under a rider drops it.
- `chl-tiers`: a tier-2 pair moves twice a tier-1 pair's items; tier-3 and mixed spans ride at the right speed (and
  draw the right crawl); a fast-replace upgrade keeps the span and redraws it at the new tier.
