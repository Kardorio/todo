local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local locations = require("scripts.location_manager")
local common = require("gui.common")
local production_fields = require("gui.production_fields")
local location_preview = require("gui.location_preview")
local production = require("scripts.production_manager")
local M = {}
local statuses = {"TODO", "IN_PROGRESS", "DONE", "IGNORED"}

local function holder(player)
  local frame = player.gui.screen.todo_manager_editor
  return frame and frame.todo_body.todo_editor
end

local function refresh_preview(player)
  local pane = holder(player)
  if not pane then return end
  local wide = player.display_resolution.width / player.display_scale >= 740
  location_preview.refresh(pane.parent.todo_location_side, pane.tags, wide)
  location_preview.refresh(pane.todo_location_inline, pane.tags, not wide)
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
  pane.style.width = 340
  pane.style.top_padding = 12
  pane.style.maximal_height = math.max(180, math.min(570, player.display_resolution.height / player.display_scale - 150))
  refresh_preview(player)
  production_fields.layout(pane, player)
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
    header.name = "todo_editor_header"
    header.children[1].name = "todo_editor_heading"
    common.sprite(header, "close_editor", "close", nil, {"todo.cancel"})
    local body = frame.add{type = "flow", name = "todo_body", direction = "horizontal"}
    body.style.horizontal_spacing = 12
    location_preview.create(body, "todo_location_side")
    body.add{type = "scroll-pane", name = "todo_editor", direction = "vertical"}
    frame.auto_center = true
  end
  local pane = holder(player)
  if not pane then return end
  frame.todo_editor_header.todo_editor_heading.caption = {id and "todo.details" or "todo.new"}
  pane.clear()
  local task = id and tasks.get(id)
  local prefs = store.player(player.index)
  prefs.selected_id = task and task.id or nil
  pane.tags = {task_id = task and task.id or 0, revision = task and task.revision or 0,
    position = task and task.position or false, surface_index = task and task.surface_index or false,
    parent_id = parent_id or false}
  pane.add{type = "label", caption = {"todo.field-title"}, style = "heading_2_label"}
  local title_row = pane.add{type = "flow", name = "todo_title_row", direction = "horizontal"}
  local title = title_row.add{type = "textfield", name = "todo_title", text = task and task.title or "",
    tags = {todo_action = "production_title"}}
  title.style.width = 250
  title_row.style.vertical_align = "center"
  title_row.add{type = "choose-elem-button", name = "todo_choose_target", elem_type = "signal",
    tooltip = {"todo.target-choose-help"}, tags = {todo_action = "production_target"}}
  production_fields.render(pane, task and task.production or false, player)
  local description = field(pane, "todo.description", {type = "text-box", name = "todo_description",
    text = task and task.description or ""})
  description.word_wrap = true
  description.style.width = 300
  description.style.height = 80
  local status_items, selected = {}, 1
  for i, value in ipairs(statuses) do
    status_items[i] = {"todo.status-" .. value}
    if task and value == task.status then selected = i end
  end
  local options = pane.add{type = "table", name = "todo_options", column_count = 2}
  options.style.horizontal_spacing = 12
  options.add{type = "label", caption = {"todo.status"}}
  options.add{type = "label", caption = {"todo.priority"}}
  options.add{type = "drop-down", name = "todo_status", items = status_items, selected_index = selected}.style.width = 144
  local priorities = {}
  for priority = 0, 3 do priorities[#priorities + 1] = {"todo.priority-" .. priority} end
  options.add{type = "drop-down", name = "todo_priority", items = priorities,
    selected_index = (task and task.priority or 0) + 1}.style.width = 144
  if task then
    local author = pane.add{type = "label", caption = {"todo.author", task.creator_name, task.created_at}}
    author.style.font_color = {r = 0.65, g = 0.65, b = 0.65}
  end
  location_preview.create(pane, "todo_location_inline")
  local actions = pane.add{type = "flow"}
  local save = common.button(actions, "save", {"todo.save"})
  save.style = "confirm_button"
  save.style.width = 170
  common.button(actions, "reload_editor", {"todo.reload"}, nil, {"todo.reload-help"}).style.width = 90
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
  if pane then
    refresh_preview(player)
    production_fields.refresh_info(pane)
  end
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
  refresh_preview(player)
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
  local parent_id = tags.parent_id
  local selected = {}
  for index, queued in pairs(tags.queued_ingredients or {}) do
    if queued then selected[#selected + 1] = index end
  end
  table.sort(selected)
  if #selected > 0 then
    local plan, plan_error = production.plan{production = target}
    if not plan then M.error(player, plan_error) return nil end
    for _, index in ipairs(selected) do
      local ingredient = plan.ingredients[index]
      if not ingredient then M.error(player, "invalid_selection") return nil end
      local valid, validation_error = production.validate{type = ingredient.type, name = ingredient.name, quantity = ingredient.amount}
      if not valid then M.error(player, validation_error) return nil end
    end
  end
  local changes = {
    title = pane.todo_title_row.todo_title.text, description = pane.todo_description.text,
    status = statuses[pane.todo_options.todo_status.selected_index], priority = pane.todo_options.todo_priority.selected_index - 1,
    position = tags.position, surface_index = tags.surface_index, production = target
  }
  local task, err
  if tags.task_id == 0 then
    task, err = tasks.create(changes.title, player, game.tick, parent_id or nil, false, changes)
  else
    task, err = tasks.update(tags.task_id, changes, tags.revision)
  end
  if not task then M.error(player, err) return nil end
  if tags.task_id == 0 then store.player(player.index).pinned[task.id] = true end
  if #selected > 0 then
    local children, expand_error = production.expand(task.id, selected, player, game.tick, task.revision)
    if not children then M.error(player, expand_error) return nil end
  end
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
  elseif action == "preview_ingredients" then production_fields.toggle_ingredients(pane, player)
  elseif action == "filter_recipes" then production_fields.filter_recipes(pane, player)
  elseif action == "queue_ingredient" then production_fields.queue_ingredient(pane, player, element.tags.ingredient_index)
  elseif action == "production_title" then production_fields.title_changed(pane)
  end
end

function M.set_target(player, kind, name)
  local pane = holder(player)
  if pane then production_fields.set_target(pane, player, kind, name) end
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
  if pane then M.open(player, pane.tags.task_id ~= 0 and pane.tags.task_id or nil, pane.tags.parent_id) end
end

return M
