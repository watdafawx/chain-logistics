# Chain Logistics

Packages ride overhead chains between chain posts: belts on the ground, items in the air. Inspired by Create's
chain conveyors and frogports. Status: **0.1**: posts, spans, and logistic chests served over the chain network.

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
- **Throughput**: a tier-1 post sends one 8-item package every 32 ticks (about a yellow belt, 15 items/s); the map
  setting *Package size* multiplies it. `shared.lua`'s `TIERS` already holds red/blue-belt tiers for later posts.
- **Cost**: a round-robin cursor looks at *Chests checked a tick* (default 4) chests a tick. 200 chests on a
  50-post network: 0.23 ms a tick on average, 20 us a package hop.

Known: vanilla shows its "not in a logistic network" icon on logistic chests outside roboport reach, chains or not.

## How it works
- A **chain post** links to the nearest post within 16 tiles. A span is two strands, one each way, drawn with
  `rendering` (no per-tick cost).
- A package rides each span as a **projectile**: the engine moves it, and the script only hears when it reaches
  the next post (`on_script_trigger_effect`). Cost: one event per hop, nothing per tick.
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
