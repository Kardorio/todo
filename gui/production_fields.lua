local resolver = require("scripts.recipe_resolver")
local production = require("scripts.production_manager")
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
  local pickers = fields.add{type = "flow", name = "todo_target_pickers"}
  for _, kind in ipairs({"item", "fluid", "recipe"}) do
    local picker = pickers.add{type = "choose-elem-button", name = "todo_target_" .. kind,
      elem_type = kind, tooltip = {"todo.production-pick-" .. kind}, tags = {todo_action = "production_target", kind = kind}}
    if value and value.type == kind and resolver.prototype(kind, value.name) then picker.elem_value = value.name end
  end
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

function M.target_changed(pane, player, element)
  local name, kind = element.elem_value, element.tags.kind
  local value = name and {type = kind, name = name, recipe = kind == "recipe" and name or nil} or false
  set_draft(pane, value)
  for _, other in ipairs({"item", "fluid", "recipe"}) do
    if other ~= kind then pane.todo_production.todo_target_pickers["todo_target_" .. other].elem_value = nil end
  end
  M.refresh(pane, player)
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
