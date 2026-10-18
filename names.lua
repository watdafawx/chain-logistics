-- Names: posts, loaders and unloaders may have a name, and a loader an address (a name pattern, * = anything, case
-- doesn't matter). Set in a small window: anchored to a loader's / unloader's own window, and for a post (which has
-- no window of its own) a little window of its own when it's clicked. Names ride along in blueprints (tags) and
-- copy-paste. Loaders send to unloaders by address (logistics.lua); a riding feature can list the named posts and
-- unloaders of a network.
local S = require("shared")

local N = {}
local KIND = { ["chl-loader"] = "loader", ["chl-unloader"] = "unloader" }
for _, name in ipairs(S.POSTS) do KIND[name] = "post" end
N.KIND = KIND

local REL = "chl-names" -- the frame anchored to a loader's / unloader's window
local WIN = "chl-names-post" -- a post's window

-- themes (fse-std 0.6+, optional): our frames in the player's theme
local theme
if script.active_mods["fse-std"] then
  local ok, t = pcall(require, "__fse-std__/theme")
  theme = ok and t.adopt and t or nil
end

function N.init()
  storage.names = storage.names or {} -- unit -> {kind, name?, address?}
  storage.naming = storage.naming or {} -- player index -> the entity whose name window is open
end

function N.get(unit)
  local r = storage.names[unit]
  return r and r.name
end

function N.address(unit)
  local r = storage.names[unit]
  return r and r.address
end

local function clean(s)
  if type(s) ~= "string" then return nil end
  s = s:match("^%s*(.-)%s*$")
  return s ~= "" and s or nil
end

-- name / address of a post, loader or unloader (nil or "" clears it)
function N.set(e, name, address)
  local kind = KIND[e.name]
  if not kind then return end
  local u = e.unit_number
  name, address = clean(name), kind == "loader" and clean(address) or nil
  if not name and not address then
    storage.names[u] = nil
    return
  end
  if not storage.names[u] then script.register_on_object_destroyed(e) end
  storage.names[u] = { kind = kind, name = name, address = address }
end

-- does the address pattern match a name? (* matches any run of characters, case doesn't matter)
local cache = {}
function N.match(pattern, name)
  if not (pattern and name) then return false end
  local lua = cache[pattern]
  if not lua then
    lua = "^" .. pattern:lower():gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*") .. "$"
    cache[pattern] = lua
  end
  return name:lower():find(lua) ~= nil
end

-- the post a named thing is on the chain network through (a post: itself; an unloader: the post serving it)
local function post_of(u, r)
  if r.kind == "post" then return storage.posts[u] and u end
  local c = storage.chests[u]
  return c and storage.posts[c.post] and c.post
end
N.post_of = post_of

-- the named posts and unloaders on network net: {{unit, name, kind, post}} (for riding: destinations)
function N.list(net)
  local out = {}
  for u, r in pairs(storage.names) do
    if r.name and r.kind ~= "loader" then
      local p = post_of(u, r)
      if p and storage.posts[p].net == net then
        out[#out + 1] = { unit = u, name = r.name, kind = r.kind, post = p }
      end
    end
  end
  return out
end

-- the unloaders (unit -> record) whose name an address matches, on any network (the caller checks)
function N.unloaders(address)
  local out = {}
  for u, r in pairs(storage.names) do
    if r.kind == "unloader" and N.match(address, r.name) then out[u] = r end
  end
  return out
end

-- an upgraded post keeps its name
function N.remap(old, new)
  if storage.names[old] then
    storage.names[new], storage.names[old] = storage.names[old], nil
    local p = storage.posts[new]
    if p and p.e.valid then script.register_on_object_destroyed(p.e) end
  end
end

function N.destroyed(ev)
  if ev.type == defines.target_type.entity and ev.useful_id then
    local r = storage.names[ev.useful_id]
    -- (an upgraded post's record moved on to the new unit: remap())
    if r then storage.names[ev.useful_id] = nil end
  end
end

-- --- blueprints and copy-paste -------------------------------------------------------------------------------------

-- names into a blueprint's entity tags; mapping: blueprint index -> entity
function N.tag_blueprint(bp, mapping)
  for i, e in pairs(mapping) do
    local r = e.valid and storage.names[e.unit_number]
    if r then
      if r.name then bp.set_blueprint_entity_tag(i, "chl_name", r.name) end
      if r.address then bp.set_blueprint_entity_tag(i, "chl_address", r.address) end
    end
  end
end

function N.setup_blueprint(ev)
  local player = game.get_player(ev.player_index)
  local bp = ev.stack
  if not (bp and bp.valid_for_read and bp.is_blueprint) then bp = player.blueprint_to_setup end
  if not (bp and bp.valid_for_read and bp.is_blueprint) then bp = ev.record end
  if not bp then return end
  local mapping = ev.mapping.get()
  for _, e in pairs(mapping) do
    if e.valid and storage.names[e.unit_number] then
      N.tag_blueprint(bp, mapping)
      return
    end
  end
end

-- built (or revived) from a blueprint: its name from the tags
function N.built(e, tags)
  if tags and KIND[e.name] and (tags.chl_name or tags.chl_address) then N.set(e, tags.chl_name, tags.chl_address) end
end

function N.pasted(ev)
  local a, b = ev.source, ev.destination
  if KIND[a.name] and KIND[a.name] == KIND[b.name] then
    local r = storage.names[a.unit_number]
    N.set(b, r and r.name, r and r.address)
  end
end

-- --- the window ----------------------------------------------------------------------------------------------------

local function field(parent, e, which, text)
  local row = parent.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  local l = row.add({ type = "label", caption = { "chl." .. which }, tooltip = { "chl." .. which .. "-tooltip" } })
  l.style.minimal_width = 60
  local t = row.add({ type = "textfield", text = text or "", tooltip = { "chl." .. which .. "-tooltip" },
    tags = { chl_field = which } })
  t.style.width = 160
  return t
end

local function fill(f, e)
  storage.naming = storage.naming or {}
  storage.naming[f.player_index] = e
  local r = storage.names[e.unit_number] or {}
  local inner = f.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
    .add({ type = "flow", direction = "vertical" })
  inner.style.vertical_spacing = 8
  local t = field(inner, e, "name", r.name)
  if KIND[e.name] == "loader" then field(inner, e, "address", r.address) end
  if theme then theme.adopt(f) end
  return t
end

-- a loader / unloader window: our frame on its right
local function open_chest(player, e)
  local old = player.gui.relative[REL]
  if old then old.destroy() end
  local f = player.gui.relative.add({ type = "frame", name = REL, direction = "vertical", caption = { "chl.name" },
    anchor = { gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right,
      names = { "chl-loader", "chl-unloader" } } })
  fill(f, e)
end

local function close_post(player)
  local w = player.gui.screen[WIN]
  if w then w.destroy() end
end

-- a post clicked: its own little window
local function open_post(player, e)
  close_post(player)
  local f = player.gui.screen.add({ type = "frame", name = WIN, direction = "vertical" })
  local bar = f.add({ type = "flow", direction = "horizontal" })
  bar.drag_target = f
  bar.add({ type = "label", style = "frame_title", caption = { "chl.title-post" }, ignored_by_interaction = true })
  local grip = bar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true })
  grip.style.horizontally_stretchable, grip.style.height, grip.style.minimal_width = true, 24, 24
  bar.add({ type = "sprite-button", style = "frame_action_button", sprite = "utility/close",
    tags = { chl_close = true } })
  local t = fill(f, e)
  f.force_auto_center()
  player.opened = f
  t.focus()
end

function N.on_open_input(ev)
  local player = game.get_player(ev.player_index)
  local e = player.selected
  if e and KIND[e.name] == "post" and player.force == e.force and player.can_reach_entity(e) then open_post(player, e) end
end

function N.on_gui_opened(ev)
  local e = ev.entity
  if e and (e.name == "chl-loader" or e.name == "chl-unloader") then
    open_chest(game.get_player(ev.player_index), e)
  end
end

function N.on_gui_closed(ev)
  if ev.element and ev.element.valid and ev.element.name == WIN then ev.element.destroy() end
end

function N.on_gui_click(ev)
  local el = ev.element
  if el.valid and el.tags.chl_close then close_post(game.get_player(ev.player_index)) end
end

function N.on_text_changed(ev)
  local el = ev.element
  local which = el.tags.chl_field
  if not which then return end
  local e = storage.naming and storage.naming[ev.player_index]
  if not (e and e.valid) then return end
  local r = storage.names[e.unit_number] or {}
  if which == "name" then N.set(e, el.text, r.address) else N.set(e, r.name, el.text) end
end

function N.on_confirmed(ev)
  local el = ev.element
  if el.valid and el.tags.chl_field then close_post(game.get_player(ev.player_index)) end
end

return N
