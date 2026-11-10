local store = require("scripts.storage")
local tasks = require("scripts.task_manager")
local window = require("gui.main_window")
local panel = require("gui.compact_panel")
local editor = require("gui.task_editor")
local common = require("gui.common")
local locations = require("scripts.location_manager")
local selector = require("gui.production_selector")
local factopedia = require("integrations.factopedia")
local M = {}
local gui_revision = 15

local function open_list(player)
  selector.close(player)
  editor.close(player)
  window.open(player)
end

local function open_editor(player, id, parent_id)
  selector.close(player)
  window.close(player)
  editor.open(player, id, parent_id)
end

local function render(player)
  window.render(player)
  panel.render(player)
  editor.refresh_location(player)
end

function M.refresh()
  M.ensure_ready()
  for _, player in pairs(game.connected_players) do render(player) end
end

function M.initialize()
  store.initialize().gui_revision = gui_revision
  for _, player in pairs(game.players) do
    local prefs = store.player(player.index)
    prefs.pending_hover, prefs.native_crafts = nil, nil
    window.ensure_button(player)
    local old = player.gui.screen.todo_manager_window
    if old then
      window.close(player)
      window.open(player)
    end
    editor.close(player)
    selector.close(player)
    local old_picker = player.gui.screen.todo_manager_target_picker
    if old_picker then old_picker.destroy() end
    store.player(player.index).target_picker = nil
    local old_panel = player.gui.screen.todo_manager_panel
    if old_panel then old_panel.destroy() end
    panel.render(player)
  end
end

function M.ensure_ready()
  local state = store.get()
  if not state or state.schema_version ~= 3 or state.gui_revision ~= gui_revision then M.initialize() end
end

function M.first_tick()
  M.ensure_ready()
  script.on_event(defines.events.on_tick, nil)
end

function M.loaded()
  local state = store.get()
  local needs_migration = not state or state.schema_version ~= 3 or state.gui_revision ~= gui_revision
  script.on_event(defines.events.on_tick, needs_migration and M.first_tick or nil)
end

function M.player_created(event)
  M.ensure_ready()
  local player = game.get_player(event.player_index)
  if not player then return end
  local prefs = store.player(player.index)
  prefs.pending_hover, prefs.native_crafts = nil, nil
  window.ensure_button(player)
  render(player)
end

function M.player_removed(event)
  M.ensure_ready()
  store.get().players[event.player_index] = nil
end

function M.command(command)
  M.ensure_ready()
  if not command.player_index then game.print({"todo.player-only"}) return end
  local player = game.get_player(command.player_index)
  if not player then return end
  local title = (command.parameter or ""):match("^%s*(.-)%s*$")
  if title == "" then open_list(player) return end
  local task, err = tasks.create(title, player, game.tick)
  if not task then player.print({"todo.error-" .. err}) return end
  store.player(player.index).pinned[task.id] = true
  player.print({"todo.created", task.id, task.title})
  M.refresh()
end

local function open_hover_target(player, kind, name)
  if player.gui.screen.todo_manager_editor or player.gui.screen.todo_manager_production then
    editor.error(player, "draft_open")
    player.print({"todo.error-draft_open"})
    return
  end
  player.close_factoriopedia_gui()
  open_editor(player)
  editor.set_target(player, kind, name)
end

function M.from_hover(event)
  M.ensure_ready()
  local player = game.get_player(event.player_index)
  if not player then return end
  -- Stack and quality-aware slots already use Shift-click for transfers.
  if not event.in_gui or event.element or not event.selected_prototype or event.selected_prototype.quality then return end
  local kind, name, err = factopedia.target(event.selected_prototype)
  if not kind then
    if err ~= "unsupported_hovered_target" then player.print({"todo.error-" .. err}) end
    return
  end
  if kind == "recipe" and player.opened_gui_type == defines.gui_type.controller then
    local prefs = store.player(player.index)
    local crafts = prefs.native_crafts
    if crafts and crafts.tick == game.tick and crafts.recipes[name] then return end
    -- Native crafting and the custom input may be delivered in either order.
    prefs.pending_hover = {kind = kind, name = name, tick = game.tick}
    return
  end
  open_hover_target(player, kind, name)
end

function M.crafting_queued(event)
  M.ensure_ready()
  local prefs = store.player(event.player_index)
  if not prefs.native_crafts or prefs.native_crafts.tick ~= game.tick then
    prefs.native_crafts = {tick = game.tick, recipes = {}}
  end
  prefs.native_crafts.recipes[event.recipe.name] = true
  local pending = prefs.pending_hover
  if pending and pending.tick == game.tick and pending.name == event.recipe.name then prefs.pending_hover = nil end
end

local function event_context(event)
  M.ensure_ready()
  local element = event.element
  if not element or not element.valid or not common.owns(element) then return end
  return game.get_player(event.player_index), element, element.tags
end

function M.clicked(event)
  local player, element, tags = event_context(event)
  if not player then return end
  local action, id = tags.todo_action, tags.task_id
  if action == "open" then open_list(player)
  elseif action == "close" then window.close(player)
  elseif action == "close_editor" then open_list(player)
  elseif action == "preview_ingredients" then editor.production_changed(player, element)
  elseif action == "toggle_panel" then panel.toggle(player)
  elseif action == "new" then open_editor(player)
  elseif action == "edit" then
    if tasks.get(id) then open_editor(player, id) end
  elseif action == "new_child" then
    if tasks.get(id) then open_editor(player, nil, id) end
  elseif action == "collapse" then
    local prefs = store.player(player.index)
    prefs.collapsed[id] = not prefs.collapsed[id] or nil
    render(player)
  elseif action == "pin" then
    if tasks.get(id) then
      local prefs = store.player(player.index)
      prefs.pinned[id] = not prefs.pinned[id] or nil
      render(player)
    end
  elseif action == "up" or action == "down" then
    local _, err = tasks.move(id, action == "up" and -1 or 1)
    if err then editor.error(player, err) end
    M.refresh()
  elseif action == "save" then
    if editor.save(player) then open_list(player) M.refresh() end
  elseif action == "reload_editor" then editor.reload(player)
  elseif action == "delete" then editor.request_delete(player, true)
  elseif action == "cancel_delete" then editor.request_delete(player, false)
  elseif action == "confirm_delete" then
    if editor.delete(player) then open_list(player) M.refresh() end
  elseif action == "location_current" then editor.location(player, false)
  elseif action == "location_clear" then editor.location(player, true)
  elseif action == "location_go" then editor.navigate(player)
  elseif action == "decompose" then
    if player.gui.screen.todo_manager_editor then editor.error(player, "save_before_decompose")
    elseif tasks.get(id) then window.close(player) selector.open(player, id) end
  elseif action == "close_production" then open_list(player)
  elseif action == "production_edit" then open_editor(player, id)
  elseif action == "production_add" then
    if selector.add(player) then open_list(player) M.refresh() end
  elseif action == "show_factoriopedia" then factopedia.open(player, tasks.get(id))
  elseif action == "show_location" then
    local task = tasks.get(id)
    if task then
      local ok, err = common.preserve_window(player, function()
        return locations.navigate(player, task)
      end)
      if not ok then player.print({"todo.error-" .. err}) end
    end
  end
end

function M.checked(event)
  local player, element, tags = event_context(event)
  if not player then return end
  if tags.todo_action == "production_ingredient" then selector.selection_changed(player) return end
  if tags.todo_action ~= "done" then return end
  local task = tasks.get(tags.task_id)
  if not task then M.refresh() return end
  local _, err = tasks.update(task.id, {status = element.state and "DONE" or "TODO"}, task.revision)
  if err then editor.error(player, err) end
  M.refresh()
end

function M.closed(event)
  M.ensure_ready()
  if common.is_preserving(event.player_index) then return end
  if window.is_window(event.element) then
    local player = game.get_player(event.player_index)
    if player then window.close(player) end
  elseif editor.is_window(event.element) then
    local player = game.get_player(event.player_index)
    if player then open_list(player) end
  elseif selector.is_window(event.element) then
    local player = game.get_player(event.player_index)
    if player then open_list(player) end
  end
end

function M.production_changed(event)
  local player, element = event_context(event)
  if player then editor.production_changed(player, element) end
end

function M.translated(event)
  M.ensure_ready()
  editor.translated(event)
end

function M.translation_tick(event)
  M.ensure_ready()
  for _, player in pairs(game.connected_players) do
    editor.retry_translation(player)
    local prefs = store.player(player.index)
    local pending = prefs.pending_hover
    if pending and pending.tick < (event and event.tick or game.tick) then
      prefs.pending_hover = nil
      open_hover_target(player, pending.kind, pending.name)
    end
    if prefs.native_crafts and prefs.native_crafts.tick < game.tick then prefs.native_crafts = nil end
  end
end

function M.moved(event)
  local player, element = event_context(event)
  if player then panel.moved(player, element) end
end

function M.resized(event)
  M.ensure_ready()
  local player = game.get_player(event.player_index)
  if player then
    window.resize(player)
    editor.resize(player)
    panel.resized(player)
  end
end

return M
