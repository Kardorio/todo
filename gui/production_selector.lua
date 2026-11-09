local common = require("gui.common")
local tasks = require("scripts.task_manager")
local production = require("scripts.production_manager")
local resolver = require("scripts.recipe_resolver")
local store = require("scripts.storage")
local M = {}

function M.close(player)
  local frame = player.gui.screen.todo_manager_production
  if frame then frame.destroy() end
end

function M.is_window(element)
  return element and element.valid and element.name == "todo_manager_production"
end

function M.open(player, id)
  local task = tasks.get(id)
  if not task then return end
  M.close(player)
  local frame = player.gui.screen.add{type = "frame", name = "todo_manager_production", direction = "vertical",
    tags = {task_id = id, revision = task.revision}}
  local header = common.header(frame, {"todo.production-decompose"})
  common.sprite(header, "close_production", "close", nil, {"todo.close"})
  local title = frame.add{type = "label", caption = task.title, style = "heading_2_label"}
  title.style.single_line = false
  title.style.maximal_width = 510
  local plan, err = production.plan(task)
  if plan then
    frame.add{type = "label", caption = {"todo.production-ingredients", #plan.ingredients}}
    local note = frame.add{type = "label", caption = {"todo.production-theoretical"}}
    note.style.single_line = false
    note.style.maximal_width = 510
    local list = frame.add{type = "scroll-pane", name = "todo_ingredients", direction = "vertical"}
    list.style.width = 530
    list.style.maximal_height = math.max(150, math.min(400, player.display_resolution.height / player.display_scale - 260))
    local existing = production.existing_children(id, plan.recipe)
    for _, ingredient in ipairs(plan.ingredients) do
      local added = production.match_child(existing, ingredient) ~= nil
      local row = list.add{type = "flow", name = "ingredient_" .. ingredient.index}
      row.add{type = "checkbox", name = "todo_select", state = false, caption = "", enabled = not added,
        tags = {todo_action = "production_ingredient", ingredient_index = ingredient.index}}
      row.add{type = "sprite", sprite = ingredient.type .. "/" .. ingredient.name}
      local prototype = resolver.prototype(ingredient.type, ingredient.name)
      row.add{type = "label", caption = {"", prototype and prototype.localised_name or ingredient.name,
        " × ", string.format("%.6g", ingredient.amount), added and {"todo.production-already-added"} or ""}}
      if ingredient.temperature or ingredient.minimum_temperature or ingredient.maximum_temperature then
        row.add{type = "label", caption = {"todo.production-temperature", ingredient.temperature or ingredient.minimum_temperature or "?",
          ingredient.temperature or ingredient.maximum_temperature or "?"}}
      end
      if ingredient.quality_min or ingredient.quality_max or ingredient.quality_change then
        row.add{type = "label", caption = {"todo.production-quality", tostring(ingredient.quality_min or "normal"),
          tostring(ingredient.quality_max or "*"), ingredient.quality_change or 0}}
      end
    end
    common.button(frame, "production_add", {"todo.production-add"}).enabled = false
  else
    frame.add{type = "label", caption = {"todo.error-" .. err}}
  end
  common.button(frame, "production_edit", {"todo.production-edit"}, id)
  local error_label = frame.add{type = "label", name = "todo_production_error", caption = ""}
  error_label.style.font_color = {r = 1, g = 0.35, b = 0.25}
  error_label.style.single_line = false
  error_label.style.maximal_width = 510
  frame.auto_center = true
  player.opened = frame
end

function M.selection_changed(player)
  local frame = player.gui.screen.todo_manager_production
  if not frame or not frame.todo_ingredients then return end
  local any = false
  for _, row in ipairs(frame.todo_ingredients.children) do
    if row.todo_select.enabled and row.todo_select.state then any = true break end
  end
  frame.todo_production_add.enabled = any
end

function M.add(player)
  local frame = player.gui.screen.todo_manager_production
  if not frame or not frame.todo_ingredients then return end
  local selected = {}
  for _, row in ipairs(frame.todo_ingredients.children) do
    if row.todo_select.enabled and row.todo_select.state then selected[#selected + 1] = row.todo_select.tags.ingredient_index end
  end
  local children, err = production.expand(frame.tags.task_id, selected, player, game.tick, frame.tags.revision)
  if not children then frame.todo_production_error.caption = {"todo.error-" .. err} return end
  store.player(player.index).collapsed[frame.tags.task_id] = nil
  return children
end

return M
