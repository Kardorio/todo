local common = require("gui.common")
local store = require("scripts.storage")
local resolver = require("scripts.recipe_resolver")
local M = {}
local window_name = "todo_manager_target_picker"
local page_size = 40
local batch_size = 64
local kinds = {"item", "fluid", "recipe"}
local order = {item = 1, fluid = 2, recipe = 3}

local function searchable(text)
  text = text:lower()
  for _, accent in ipairs({
    {"à", "À", "a"}, {"â", "Â", "a"}, {"ä", "Ä", "a"},
    {"é", "É", "e"}, {"è", "È", "e"}, {"ê", "Ê", "e"}, {"ë", "Ë", "e"},
    {"î", "Î", "i"}, {"ï", "Ï", "i"}, {"ô", "Ô", "o"}, {"ö", "Ö", "o"},
    {"ù", "Ù", "u"}, {"û", "Û", "u"}, {"ü", "Ü", "u"}, {"ç", "Ç", "c"},
    {"œ", "Œ", "oe"}, {"æ", "Æ", "ae"}
  }) do
    text = text:gsub(accent[1], accent[3]):gsub(accent[2], accent[3])
  end
  return text:gsub("[%s_%-]+", " "):match("^%s*(.-)%s*$")
end

local function state_for(player)
  return store.player(player.index).target_picker
end

local function catalogue()
  local entries = {}
  for _, kind in ipairs(kinds) do
    local filtered = prototypes["get_" .. kind .. "_filtered"]{{filter = "hidden", invert = true}}
    for name in pairs(filtered) do
      entries[#entries + 1] = {kind = kind, name = name, search_name = searchable(name)}
    end
  end
  table.sort(entries, function(a, b)
    if a.kind ~= b.kind then return order[a.kind] < order[b.kind] end
    return a.name < b.name
  end)
  return entries
end

local function render(player)
  local frame, state = player.gui.screen[window_name], state_for(player)
  if not frame or not state then return end
  local selected_kind = kinds[state.filter - 1]
  local matches = {}
  for index, entry in ipairs(state.entries) do
    if (not selected_kind or entry.kind == selected_kind) and
        (state.query == "" or entry.search_name:find(state.query, 1, true) or
          (entry.search_label and entry.search_label:find(state.query, 1, true))) then
      matches[#matches + 1] = index
    end
  end
  local pages = math.max(1, math.ceil(#matches / page_size))
  state.page = math.max(1, math.min(state.page, pages))
  frame.todo_target_results.clear()
  if #matches == 0 then
    frame.todo_target_results.add{type = "label", caption = {"todo.target-picker-empty"}}
  end
  local width = state.width - 132
  for position = (state.page - 1) * page_size + 1, math.min(state.page * page_size, #matches) do
    local index = matches[position]
    local entry = state.entries[index]
    local prototype = resolver.prototype(entry.kind, entry.name)
    if prototype then
      local row = frame.todo_target_results.add{type = "flow", name = "target_" .. index}
      row.style.vertical_align = "center"
      local icon = row.add{type = "sprite", sprite = entry.kind .. "/" .. entry.name}
      icon.style.size = {28, 28}
      local button = row.add{type = "button", name = "todo_target_pick", style = "list_box_item",
        caption = prototype.localised_name, tooltip = entry.name,
        tags = {todo_action = "target_pick", target_index = index}}
      button.style.width = width
      local kind = row.add{type = "label", caption = {"todo.target-picker-" .. entry.kind}}
      kind.style.width = 70
    end
  end
  local navigation = frame.todo_target_navigation
  navigation.todo_target_prev.enabled = state.page > 1
  navigation.todo_target_next.enabled = state.page < pages
  navigation.todo_target_count.caption = {"todo.target-picker-results", #matches, state.page, pages}
  frame.todo_target_indexing.caption = {"todo.target-picker-indexing", state.completed, #state.entries}
  frame.todo_target_indexing.visible = state.completed < #state.entries
  state.dirty = false
end

function M.close(player)
  local frame = player.gui.screen[window_name]
  if frame then frame.destroy() end
  store.player(player.index).target_picker = nil
end

function M.is_window(element)
  return element and element.valid and element.name == window_name
end

function M.open(player)
  M.close(player)
  local width = math.max(300, math.min(600, player.display_resolution.width / player.display_scale - 80))
  store.player(player.index).target_picker = {
    entries = catalogue(), pending = {}, cursor = 1, completed = 0,
    query = "", filter = 1, page = 1, width = width, dirty = true
  }
  local frame = player.gui.screen.add{type = "frame", name = window_name, direction = "vertical"}
  local header = common.header(frame, {"todo.target-picker-title"})
  common.sprite(header, "close_target_picker", "close", nil, {"todo.close"})
  frame.add{type = "label", caption = {"todo.target-picker-search"}}
  local controls = frame.add{type = "flow", name = "todo_target_controls"}
  local search = controls.add{type = "textfield", name = "todo_target_search", text = "",
    tags = {todo_action = "target_search"}}
  search.style.width = math.max(120, width - 170)
  local filter = controls.add{type = "drop-down", name = "todo_target_filter", selected_index = 1,
    items = {{"todo.target-picker-all"}, {"todo.target-picker-item"}, {"todo.target-picker-fluid"}, {"todo.target-picker-recipe"}},
    tags = {todo_action = "target_filter"}}
  filter.style.width = 160
  local results = frame.add{type = "scroll-pane", name = "todo_target_results", direction = "vertical"}
  results.style.width = width
  results.style.maximal_height = math.max(100, math.min(400, player.display_resolution.height / player.display_scale - 250))
  local navigation = frame.add{type = "flow", name = "todo_target_navigation"}
  common.sprite(navigation, "target_prev", "backward_arrow", nil, {"todo.target-picker-previous"})
  navigation.add{type = "label", name = "todo_target_count"}
  common.sprite(navigation, "target_next", "forward_arrow", nil, {"todo.target-picker-next"})
  local indexing = frame.add{type = "label", name = "todo_target_indexing"}
  indexing.style.single_line = false
  indexing.style.maximal_width = width
  frame.auto_center = true
  render(player)
  player.opened = frame
  search.focus()
end

function M.changed(player, element)
  local state = state_for(player)
  if not state then return end
  local action = element.tags.todo_action
  if action == "target_search" then
    state.query = searchable(element.text)
    state.page = 1
  elseif action == "target_filter" then
    state.filter = element.selected_index
    state.page = 1
  elseif action == "target_prev" then state.page = state.page - 1
  elseif action == "target_next" then state.page = state.page + 1
  else return end
  render(player)
end

function M.choice(player, element)
  local state, frame = state_for(player), player.gui.screen[window_name]
  if not state or not frame or not element or not element.valid then return end
  local ancestor = element
  while ancestor and ancestor ~= frame do ancestor = ancestor.parent end
  if ancestor ~= frame or element.tags.todo_action ~= "target_pick" then return end
  local index = element.tags.target_index
  if type(index) ~= "number" or index % 1 ~= 0 then return end
  local entry = state.entries[index]
  if entry and resolver.prototype(entry.kind, entry.name) then return entry.kind, entry.name, entry.label end
end

function M.translated(event)
  local prefs = store.get().players[event.player_index]
  local state = prefs and prefs.target_picker
  if not state then return end
  local index = state.pending[event.id]
  if not index then return end
  state.pending[event.id] = nil
  local entry = state.entries[index]
  if not entry or entry.translated then return end
  if event.translated then
    entry.label = event.result
    entry.search_label = searchable(event.result)
  end
  state.completed = state.completed + 1
  entry.translated = true
  state.dirty = true
end

function M.tick()
  for _, player in pairs(game.connected_players) do
    local state = state_for(player)
    local frame = player.gui.screen[window_name]
    if state and not frame then store.player(player.index).target_picker = nil end
    if state and frame then
      if state.last_request_tick and game.tick - state.last_request_tick >= 180 and next(state.pending) then
        state.pending, state.cursor = {}, 1
      end
      local strings, indices = {}, {}
      while state.cursor <= #state.entries and #strings < batch_size do
        local index = state.cursor
        local entry = state.entries[index]
        state.cursor = index + 1
        local prototype = resolver.prototype(entry.kind, entry.name)
        if not entry.translated and prototype then
          strings[#strings + 1] = prototype.localised_name
          indices[#indices + 1] = index
        elseif not entry.translated then
          entry.translated = true
          state.completed = state.completed + 1
          state.dirty = true
        end
      end
      if #strings > 0 then
        state.last_request_tick = game.tick
        local ids = player.request_translations(strings)
        for position, id in ipairs(ids) do state.pending[id] = indices[position] end
      end
      if state.dirty then render(player) end
    end
  end
end

return M
