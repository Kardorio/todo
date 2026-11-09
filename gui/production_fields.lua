local resolver = require("scripts.recipe_resolver")
local production = require("scripts.production_manager")
local tasks = require("scripts.task_manager")
local M = {}

local function set_draft(pane, value)
  local tags = pane.tags
  tags.production = value or false
  pane.tags = tags
end

function M.read(pane)
  local value = pane.tags.production
  if not value then return false end
  return {type = value.type, name = value.name, recipe = value.recipe, quantity = value.quantity}
end

function M.refresh_info(pane)
  local row = pane.todo_production.todo_recipe_row
  row.todo_recipe_info.visible = row.visible and tasks.has_children(pane.tags.task_id)
end

function M.refresh(pane, player)
  local fields = pane.todo_production
  local value = pane.tags.production
  local target = value and resolver.prototype(value.type, value.name)
  fields.visible = value ~= false and value ~= nil
  pane.todo_title_row.todo_choose_target.elem_value = target and {type = value.type, name = value.name} or nil
  fields.todo_target_name.caption = target and target.localised_name or
    {value and "todo.production-missing-target" or "todo.production-none"}
  local names, labels, selected = {""}, {{"todo.production-choose-recipe"}}, 1
  if value and value.type ~= "recipe" and target then
    for _, recipe in ipairs(resolver.recipes(value.type, value.name)) do
      names[#names + 1] = recipe.name
      local unlocked = player.force.recipes[recipe.name] and player.force.recipes[recipe.name].enabled
      labels[#labels + 1] = {"", recipe.localised_name, unlocked and "" or {"todo.production-locked"}}
      if recipe.name == value.recipe then selected = #names end
    end
  end
  if value and value.type ~= "recipe" and not value.recipe and #names == 2 then
    value.recipe = names[2]
    selected = 2
    set_draft(pane, value)
  end
  if value and value.type ~= "recipe" and value.recipe and selected == 1 then
    names[#names + 1] = value.recipe
    labels[#labels + 1] = {"todo.production-missing-recipe", value.recipe}
    selected = #names
  end
  local recipe_row = fields.todo_recipe_row
  recipe_row.todo_recipe.items = labels
  recipe_row.todo_recipe.selected_index = selected
  recipe_row.visible = value ~= false and value ~= nil and value.type ~= "recipe" and #names > 2
  M.refresh_info(pane)
  fields.tags = {recipe_names = names}
  local draft, err = M.read(pane)
  local plan
  if draft then plan, err = production.plan{production = draft} end
  fields.todo_preview.visible = plan ~= nil
  fields.todo_preview.caption = plan and {pane.tags.ingredients_open and "todo.production-hide-ingredients"
    or "todo.production-view-ingredients", #plan.ingredients} or ""
  fields.todo_plan_error.caption = err and {"todo.error-" .. err} or ""
  local list = fields.todo_ingredients
  list.clear()
  list.visible = plan ~= nil and pane.tags.ingredients_open == true
  if plan and list.visible then
    for _, ingredient in ipairs(plan.ingredients) do
      local row = list.add{type = "flow", name = "ingredient_" .. ingredient.index}
      row.style.vertical_align = "center"
      local icon = row.add{type = "sprite", sprite = ingredient.type .. "/" .. ingredient.name}
      icon.style.size = {24, 24}
      local prototype = resolver.prototype(ingredient.type, ingredient.name)
      local label = row.add{type = "label", caption = {"", prototype and prototype.localised_name or ingredient.name,
        " × ", string.format("%.6g", ingredient.amount)}}
      label.style.single_line = false
      label.style.maximal_width = 300
      local details = {""}
      if ingredient.temperature or ingredient.minimum_temperature or ingredient.maximum_temperature then
        details[#details + 1] = {"todo.production-temperature", ingredient.temperature or ingredient.minimum_temperature or "?",
          ingredient.temperature or ingredient.maximum_temperature or "?"}
      end
      if ingredient.quality_min or ingredient.quality_max or ingredient.quality_change then
        if #details > 1 then details[#details + 1] = "\n" end
        details[#details + 1] = {"todo.production-quality", tostring(ingredient.quality_min or "normal"),
          tostring(ingredient.quality_max or "*"), ingredient.quality_change or 0}
      end
      if #details > 1 then label.tooltip = details end
    end
  end
end

function M.render(pane, value, player)
  local fields = pane.add{type = "flow", name = "todo_production", direction = "vertical"}
  local recipe_row = fields.add{type = "flow", name = "todo_recipe_row", direction = "horizontal"}
  recipe_row.style.vertical_align = "center"
  local recipes = recipe_row.add{type = "drop-down", name = "todo_recipe", items = {{"todo.production-choose-recipe"}}, selected_index = 1,
    tags = {todo_action = "production_recipe"}}
  recipes.style.width = 350
  recipe_row.add{type = "label", name = "todo_recipe_info", caption = "(i)", tooltip = {"todo.production-children-unchanged"}}
  local label = fields.add{type = "label", name = "todo_target_name"}
  label.style.single_line = false
  label.style.maximal_width = 310
  fields.add{type = "button", name = "todo_preview", tags = {todo_action = "preview_ingredients"}}
  local list = fields.add{type = "scroll-pane", name = "todo_ingredients", direction = "vertical"}
  list.style.width = 350
  list.style.maximal_height = 180
  local error_label = fields.add{type = "label", name = "todo_plan_error", caption = ""}
  error_label.style.single_line = false
  error_label.style.maximal_width = 350
  set_draft(pane, value)
  M.refresh(pane, player)
end

function M.toggle_ingredients(pane, player)
  local tags = pane.tags
  tags.ingredients_open = not tags.ingredients_open
  pane.tags = tags
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
  local name = fields.tags.recipe_names[fields.todo_recipe_row.todo_recipe.selected_index]
  value.recipe = name ~= "" and name or nil
  set_draft(pane, value)
  M.refresh(pane, player)
end

return M
