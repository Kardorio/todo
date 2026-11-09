local resolver = require("scripts.recipe_resolver")
local production = require("scripts.production_manager")
local common = require("gui.common")
local M = {}

local function set_draft(pane, value)
  local tags = pane.tags
  tags.production = value or false
  pane.tags = tags
end

function M.read(pane)
  local value = pane.tags.production
  if not value then return false end
  local text = pane.todo_production.todo_quantity.text:match("^%s*(.-)%s*$")
  local quantity = text ~= "" and tonumber((text:gsub(",", "."))) or nil
  if text ~= "" and not quantity then return nil, "invalid_quantity" end
  return {type = value.type, name = value.name, recipe = value.recipe, quantity = quantity}
end

function M.refresh(pane, player)
  local fields = pane.todo_production
  local value = pane.tags.production
  local target = value and resolver.prototype(value.type, value.name)
  fields.visible = value ~= false and value ~= nil
  pane.todo_title_row.todo_choose_target.elem_value = target and {type = value.type, name = value.name} or nil
  fields.todo_target_name.caption = target and target.localised_name or
    {value and "todo.production-missing-target" or "todo.production-none"}
  fields.todo_quantity_label.caption = {value and value.type == "recipe" and "todo.production-crafts" or "todo.production-quantity"}
  local names, labels, selected = {""}, {{"todo.production-choose-recipe"}}, 1
  if value and value.type ~= "recipe" and target then
    for _, recipe in ipairs(resolver.recipes(value.type, value.name)) do
      names[#names + 1] = recipe.name
      local unlocked = player.force.recipes[recipe.name] and player.force.recipes[recipe.name].enabled
      labels[#labels + 1] = {"", recipe.localised_name, unlocked and "" or {"todo.production-locked"}}
      if recipe.name == value.recipe then selected = #names end
    end
  end
  if value and value.type ~= "recipe" and value.recipe and selected == 1 then
    names[#names + 1] = value.recipe
    labels[#labels + 1] = {"todo.production-missing-recipe", value.recipe}
    selected = #names
  end
  fields.todo_recipe.items = labels
  fields.todo_recipe.selected_index = selected
  fields.todo_recipe.visible = value ~= false and value ~= nil and value.type ~= "recipe"
  fields.todo_clear_target.visible = value ~= false and value ~= nil
  fields.tags = {recipe_names = names}
  local draft, err = M.read(pane)
  local plan
  if draft then plan, err = production.plan{production = draft} end
  fields.todo_preview.caption = plan and {"todo.production-preview", plan.crafts, #plan.ingredients}
    or (err and {"todo.error-" .. err} or "")
end

function M.render(pane, value, player)
  local fields = pane.add{type = "flow", name = "todo_production", direction = "vertical"}
  fields.add{type = "line"}
  fields.add{type = "label", caption = {"todo.production"}, style = "heading_2_label"}
  common.button(fields, "clear_target", {"todo.target-clear"})
  local label = fields.add{type = "label", name = "todo_target_name"}
  label.style.single_line = false
  label.style.maximal_width = 310
  fields.add{type = "label", name = "todo_quantity_label"}
  local quantity = fields.add{type = "textfield", name = "todo_quantity", text = value and value.quantity and tostring(value.quantity) or "",
    tooltip = {"todo.production-quantity-help"}, tags = {todo_action = "production_quantity"}}
  quantity.style.width = 310
  local recipes = fields.add{type = "drop-down", name = "todo_recipe", items = {{"todo.production-choose-recipe"}}, selected_index = 1,
    tags = {todo_action = "production_recipe"}}
  recipes.style.width = 310
  local preview = fields.add{type = "label", name = "todo_preview"}
  preview.style.single_line = false
  preview.style.maximal_width = 310
  local note = fields.add{type = "label", caption = {"todo.production-children-unchanged"}}
  note.style.single_line = false
  note.style.maximal_width = 310
  set_draft(pane, value)
  M.refresh(pane, player)
end

function M.set_target(pane, player, kind, name, label)
  local value = name and {type = kind, name = name, recipe = kind == "recipe" and name or nil} or false
  set_draft(pane, value)
  local tags, title = pane.tags, pane.todo_title_row.todo_title
  tags.title_translation = false
  if value and (title.text:match("^%s*$") or title.text == tags.auto_title) then
    title.text = label and label ~= "" and label or name
    tags.auto_title = title.text
    if not label or label == "" then
      local target = resolver.prototype(kind, name)
      if target then
        tags.title_translation = {id = player.request_translation(target.localised_name),
          expected = title.text, kind = kind, name = name, tick = game.tick}
      end
    end
  end
  pane.tags = tags
  M.refresh(pane, player)
end

function M.target_changed(pane, player, element)
  local signal = element.elem_value
  local kind = signal and (signal.type or "item")
  if signal and (kind ~= "item" and kind ~= "fluid" and kind ~= "recipe"
      or not resolver.prototype(kind, signal.name)) then
    M.refresh(pane, player)
    return nil, "invalid_target_signal"
  end
  M.set_target(pane, player, kind, signal and signal.name)
  return true
end

function M.retry_translation(pane, player)
  local tags = pane.tags
  local pending = tags.title_translation
  if not pending or game.tick - pending.tick < 180 then return end
  local target = resolver.prototype(pending.kind, pending.name)
  if target and pane.todo_title_row.todo_title.text == pending.expected then
    pending.id, pending.tick = player.request_translation(target.localised_name), game.tick
  else tags.title_translation = false end
  pane.tags = tags
end

function M.title_changed(pane)
  local tags = pane.tags
  if pane.todo_title_row.todo_title.text ~= tags.auto_title then
    tags.auto_title, tags.title_translation = false, false
    pane.tags = tags
  end
end

function M.translated(pane, event)
  local tags = pane.tags
  local pending = tags.title_translation
  if not pending or pending.id ~= event.id then return end
  local target, title = tags.production, pane.todo_title_row.todo_title
  if target and target.type == pending.kind and target.name == pending.name
    and title.text == pending.expected and tags.auto_title == pending.expected then
    title.text = event.translated and event.result ~= "" and event.result or pending.expected
    tags.auto_title = title.text
  end
  tags.title_translation = false
  pane.tags = tags
end

function M.recipe_changed(pane, player)
  local fields, value = pane.todo_production, pane.tags.production
  if not value or value.type == "recipe" then return end
  local name = fields.tags.recipe_names[fields.todo_recipe.selected_index]
  value.recipe = name ~= "" and name or nil
  set_draft(pane, value)
  M.refresh(pane, player)
end

return M
