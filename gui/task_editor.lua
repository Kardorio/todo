local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local locations = require("scripts.location_manager")
local common = require("gui.common")
local production_fields = require("gui.production_fields")
local M = {}
local statuses = {"TODO", "IN_PROGRESS", "DONE", "IGNORED"}

local function holder(player)
  local frame = player.gui.screen.todo_manager_editor
  return frame and frame.todo_editor
end

function M.close(player)
  local frame = player.gui.screen.todo_manager_editor
  if frame then frame.destroy() end
end

function M.is_window(element)
  return element and element.valid and element.name == "todo_manager_editor"
end

function M.resize(player)
  local pane = holder(player)
  if not pane then return end
  pane.style.width = 420
  pane.style.maximal_height = math.max(180, math.min(570, player.display_resolution.height / player.display_scale - 150))
end

local function field(parent, caption, spec)
  parent.add{type = "label", caption = {caption}}
  return parent.add(spec)
end

function M.open(player, id, parent_id)
  local frame = player.gui.screen.todo_manager_editor
  if not frame then
    frame = player.gui.screen.add{type = "frame", name = "todo_manager_editor", direction = "vertical"}
    local header = common.header(frame, {id and "todo.details" or "todo.new"})
    common.sprite(header, "close_editor", "close", nil, {"todo.cancel"})
    frame.add{type = "scroll-pane", name = "todo_editor", direction = "vertical"}
    frame.auto_center = true
  end
  local pane = holder(player)
  if not pane then return end
  pane.clear()
  local task = id and tasks.get(id)
  local prefs = store.player(player.index)
  prefs.selected_id = task and task.id or nil
  pane.tags = {task_id = task and task.id or 0, revision = task and task.revision or 0,
    position = task and task.position or false, surface_index = task and task.surface_index or false}
  pane.add{type = "label", caption = {"todo.field-title"}}
  local title_row = pane.add{type = "flow", name = "todo_title_row", direction = "horizontal"}
  local title = title_row.add{type = "textfield", name = "todo_title", text = task and task.title or "",
    tags = {todo_action = "production_title"}}
  title.style.width = 310
  title_row.add{type = "choose-elem-button", name = "todo_choose_target", elem_type = "signal",
    tooltip = {"todo.target-choose-help"}, tags = {todo_action = "production_target"}}
  production_fields.render(pane, task and task.production or false, player)
  local description = field(pane, "todo.description", {type = "text-box", name = "todo_description",
    text = task and task.description or ""})
  description.word_wrap = true
  description.style.width = 310
  description.style.height = 90
  local status_items, selected = {}, 1
  for i, value in ipairs(statuses) do
    status_items[i] = {"todo.status-" .. value}
    if task and value == task.status then selected = i end
  end
  field(pane, "todo.status", {type = "drop-down", name = "todo_status", items = status_items, selected_index = selected})
  local priorities = {}
  for priority = 0, 3 do priorities[#priorities + 1] = {"todo.priority-" .. priority} end
  field(pane, "todo.priority", {type = "drop-down", name = "todo_priority", items = priorities,
    selected_index = (task and task.priority or 0) + 1})
  local ids, parents, parent_index = {0}, {{"todo.root"}}, 1
  local desired_parent = task and task.parent_id or parent_id
  for _, candidate in ipairs(tasks.list()) do
    if not task or tasks.can_parent(task.id, candidate.id) then
      ids[#ids + 1] = candidate.id
      parents[#parents + 1] = "#" .. candidate.id .. " " .. candidate.title
      if candidate.id == desired_parent then parent_index = #ids end
    end
  end
  local parent = field(pane, "todo.parent", {type = "drop-down", name = "todo_parent",
    items = parents, selected_index = parent_index})
  parent.style.width = 310
  local tags = pane.tags
  tags.parent_ids = ids
  pane.tags = tags
  if task then
    pane.add{type = "label", caption = {"todo.author", task.creator_name, task.created_at}}
  end
  local location = pane.add{type = "label", name = "todo_location", caption = locations.describe(pane.tags)}
  location.style.single_line = false
  location.style.maximal_width = 310
  local location_buttons = pane.add{type = "flow"}
  common.sprite(location_buttons, "location_current", "gps_map_icon", nil, {"todo.location-current"})
  common.sprite(location_buttons, "location_clear", "trash", nil, {"todo.location-clear"})
  common.sprite(location_buttons, "location_go", "map", nil, {"todo.location-go"})
  local actions = pane.add{type = "flow"}
  common.button(actions, "save", {"todo.save"})
  common.button(actions, "reload_editor", {"todo.reload"}, nil, {"todo.reload-help"})
  if task then common.sprite(actions, "delete", "trash", task.id, {"todo.delete-help"}) end
  local confirm = pane.add{type = "flow", name = "todo_delete_confirm", direction = "vertical"}
  confirm.visible = false
  local warning = confirm.add{type = "label", caption = {"todo.delete-confirm"}}
  warning.style.single_line = false
  warning.style.maximal_width = 310
  common.button(confirm, "confirm_delete", {"todo.delete"})
  common.button(confirm, "cancel_delete", {"todo.cancel"})
  local error_label = pane.add{type = "label", name = "todo_error", caption = ""}
  error_label.style.font_color = {r = 1, g = 0.35, b = 0.25}
  error_label.style.single_line = false
  error_label.style.maximal_width = 310
  M.resize(player)
  frame.visible = true
  player.opened = frame
end

function M.error(player, code)
  local pane = holder(player)
  if pane then pane.todo_error.caption = {"todo.error-" .. code} end
end

function M.refresh_location(player)
  local pane = holder(player)
  if pane and pane.todo_location then pane.todo_location.caption = locations.describe(pane.tags) end
end

function M.request_delete(player, visible)
  local pane = holder(player)
  if pane then pane.todo_delete_confirm.visible = visible end
end

function M.delete(player)
  local pane = holder(player)
  if not pane then return end
  local task = tasks.get(pane.tags.task_id)
  if not task then M.error(player, "missing") return end
  if task.revision ~= pane.tags.revision then M.error(player, "conflict") return end
  local ok, err = tasks.delete(task.id)
  if not ok then M.error(player, err) return end
  return true
end

function M.location(player, clear)
  local pane = holder(player)
  if not pane then return end
  local tags = pane.tags
  local location = not clear and locations.capture(player)
  tags.position = location and location.position or false
  tags.surface_index = location and location.surface_index or false
  pane.tags = tags
  pane.todo_location.caption = locations.describe(tags)
end

function M.navigate(player)
  local pane = holder(player)
  if not pane then return end
  local ok, err = common.preserve_window(player, function()
    return locations.navigate(player, pane.tags)
  end)
  if not ok then M.error(player, err) end
  return ok
end

function M.save(player)
  local pane = holder(player)
  if not pane then return end
  local tags = pane.tags
  if tags.title_translation and pane.todo_title_row.todo_title.text == tags.title_translation.expected then
    M.error(player, "title_translation_pending")
    return
  end
  local target, target_error = production_fields.read(pane)
  if target == nil then M.error(player, target_error) return end
  local parent_id = tags.parent_ids[pane.todo_parent.selected_index]
  local changes = {
    title = pane.todo_title_row.todo_title.text, description = pane.todo_description.text,
    status = statuses[pane.todo_status.selected_index], priority = pane.todo_priority.selected_index - 1,
    parent_id = parent_id ~= 0 and parent_id or false,
    position = tags.position, surface_index = tags.surface_index, production = target
  }
  local task, err
  if tags.task_id == 0 then
    task, err = tasks.create(changes.title, player, game.tick, parent_id ~= 0 and parent_id or nil, false, changes)
  else
    task, err = tasks.update(tags.task_id, changes, tags.revision)
  end
  if not task then M.error(player, err) return nil end
  if tags.task_id == 0 then store.player(player.index).pinned[task.id] = true end
  return task
end

function M.production_changed(player, element)
  local pane = holder(player)
  if not pane then return end
  local action = element.tags.todo_action
  if action == "production_target" then
    local ok, err = production_fields.target_changed(pane, player, element)
    if not ok then M.error(player, err) end
  elseif action == "production_recipe" then production_fields.recipe_changed(pane, player)
  elseif action == "production_title" then production_fields.title_changed(pane)
  end
end

function M.set_target(player, kind, name, label)
  local pane = holder(player)
  if pane then production_fields.set_target(pane, player, kind, name, label) end
end

function M.translated(event)
  local player = game.get_player(event.player_index)
  local pane = player and holder(player)
  if pane then production_fields.translated(pane, event) end
end

function M.retry_translation(player)
  local pane = holder(player)
  if pane then production_fields.retry_translation(pane, player) end
end

function M.reload(player)
  local pane = holder(player)
  if pane then M.open(player, pane.tags.task_id ~= 0 and pane.tags.task_id or nil) end
end

return M
