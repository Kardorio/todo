local resolver = require("scripts.recipe_resolver")
local production = require("scripts.production_manager")
local tasks = require("scripts.task_manager")
local common = require("gui.common")
local store = require("scripts.storage")
local M = {}

function M.element(pane)
  return pane.parent.todo_production or pane.todo_production
end

local function host(pane, player)
  return player.display_resolution.width / player.display_scale >= 960 and pane.parent or pane
end

local function ingredient_height(player)
  return math.max(120, math.min(360, player.display_resolution.height / player.display_scale - 260))
end

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
  local row = M.element(pane).todo_recipe_row
  row.todo_recipe_info.visible = row.visible and tasks.has_children(pane.tags.task_id)
  row.todo_recipe.style.width = row.todo_recipe_info.visible and 218 or 238
end

function M.refresh(pane, player)
  local fields = M.element(pane)
  local value = pane.tags.production
  local target = value and resolver.prototype(value.type, value.name)
  fields.visible = value ~= false and value ~= nil
  pane.todo_title_row.todo_choose_target.elem_value = target and {type = value.type, name = value.name} or nil
  fields.todo_target_header.todo_target_name.caption = target and target.localised_name or
    {value and "todo.production-missing-target" or "todo.production-none"}
  local names, labels, selected = {""}, {{"todo.production-choose-recipe"}}, 1
  local candidates = value and value.type ~= "recipe" and target and resolver.recipes(value.type, value.name) or {}
  local show_locked = store.player(pane.player_index).show_locked_recipes ~= false
  local selected_hidden = false
  if value and value.type ~= "recipe" and target then
    for _, recipe in ipairs(candidates) do
      local unlocked = player.force.recipes[recipe.name] and player.force.recipes[recipe.name].enabled
      if show_locked or unlocked then
        names[#names + 1] = recipe.name
        labels[#labels + 1] = {"", unlocked and "" or "[color=255,90,80]", recipe.localised_name,
          unlocked and "" or "[/color]"}
        if recipe.name == value.recipe then selected = #names end
      elseif recipe.name == value.recipe then selected_hidden = true end
    end
  end
  if value and value.type ~= "recipe" and not value.recipe and #candidates == 1 and #names == 2 then
    value.recipe = names[2]
    selected = 2
    set_draft(pane, value)
  end
  if value and value.type ~= "recipe" and value.recipe and selected == 1 and not selected_hidden then
    names[#names + 1] = value.recipe
    labels[#labels + 1] = {"todo.production-missing-recipe", value.recipe}
    selected = #names
  end
  local recipe_row = fields.todo_recipe_row
  recipe_row.todo_recipe.items = labels
  recipe_row.todo_recipe.selected_index = selected
  recipe_row.visible = value ~= false and value ~= nil and value.type ~= "recipe" and (#candidates > 1 or #names > 2)
  local filter = pane.parent.parent.todo_editor_header.todo_filter_recipes
  filter.visible = value ~= false and value ~= nil and value.type ~= "recipe" and #candidates > 0
  filter.toggled = show_locked
  M.refresh_info(pane)
  fields.tags = {recipe_names = names}
  local draft, err = M.read(pane)
  local plan
  if draft then plan, err = production.plan{production = draft} end
  fields.todo_ingredient_heading.visible = plan ~= nil
  fields.todo_ingredient_heading.todo_ingredient_count.caption = plan and {"todo.production-ingredients", #plan.ingredients} or ""
  recipe_row.todo_recipe_factopedia.enabled = plan ~= nil
  fields.todo_target_header.todo_recipe_factopedia.visible = not recipe_row.visible and plan ~= nil
  fields.todo_target_header.todo_target_name.style.width = recipe_row.visible and 270 or 234
  fields.todo_plan_error.caption = err and {"todo.error-" .. err} or ""
  local list = fields.todo_ingredients
  local queued = {}
  for _, index in ipairs(pane.tags.queued_ingredients or {}) do queued[index] = true end
  local existing = plan and production.existing_children(pane.tags.task_id, plan.recipe) or {}
  list.clear()
  list.visible = plan ~= nil
  if plan and list.visible then
    for _, ingredient in ipairs(plan.ingredients) do
      local row = list.add{type = "flow", name = "ingredient_" .. ingredient.index}
      row.style.vertical_align = "center"
      row.style.horizontal_spacing = 10
      local icon = row.add{type = "sprite-button", sprite = ingredient.type .. "/" .. ingredient.name,
        style = "slot_button"}
      icon.style.size = {36, 36}
      local prototype = resolver.prototype(ingredient.type, ingredient.name)
      local amount = row.add{type = "label", caption = string.format("%.6g", ingredient.amount) .. " ×"}
      amount.style.width = 52
      amount.style.horizontal_align = "right"
      amount.style.font = "default-bold"
      local label = row.add{type = "label", caption = prototype and prototype.localised_name or ingredient.name}
      label.style.single_line = false
      label.style.width = 108
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
      icon.tooltip = {"", prototype and prototype.localised_name or ingredient.name,
        " × ", string.format("%.6g", ingredient.amount), #details > 1 and "\n" or "", details}
      if #details > 1 then label.tooltip = details end
      local added = production.match_child(existing, ingredient) ~= nil
      local selected_ingredient = queued[ingredient.index] == true
      local add = common.button(row, "queue_ingredient", (added or selected_ingredient) and "✓" or "+", nil,
        {added and "todo.ingredient-added" or selected_ingredient and "todo.ingredient-queued" or "todo.ingredient-add"})
      add.style = "tool_button"
      add.style.size = {28, 28}
      add.enabled = not added
      add.tags = {todo_action = "queue_ingredient", ingredient_index = ingredient.index}
    end
  end
end

function M.render(pane, value, player)
  local existing = M.element(pane)
  if existing then existing.destroy() end
  local parent = host(pane, player)
  local fields = parent.add{type = "frame", name = "todo_production", direction = "vertical", style = "inside_shallow_frame",
    index = parent == pane and 3 or nil}
  fields.style.width = 300
  fields.style.padding = 12
  local heading = fields.add{type = "flow", name = "todo_target_header", direction = "horizontal"}
  heading.style.vertical_align = "center"
  local label = heading.add{type = "label", name = "todo_target_name", style = "heading_2_label"}
  label.style.single_line = false
  label.style.width = 270
  common.sprite(heading, "recipe_factopedia", "side_menu_factoriopedia_icon", nil, {"todo.open-recipe-factopedia"})
  local recipe_row = fields.add{type = "flow", name = "todo_recipe_row", direction = "horizontal"}
  recipe_row.style.vertical_align = "center"
  local recipes = recipe_row.add{type = "drop-down", name = "todo_recipe", items = {{"todo.production-choose-recipe"}}, selected_index = 1,
    tags = {todo_action = "production_recipe"}}
  recipes.style.width = 238
  recipe_row.add{type = "label", name = "todo_recipe_info", caption = "(i)", tooltip = {"todo.production-children-unchanged"}}
  common.sprite(recipe_row, "recipe_factopedia", "side_menu_factoriopedia_icon", nil, {"todo.open-recipe-factopedia"})
  local ingredient_heading = fields.add{type = "flow", name = "todo_ingredient_heading", direction = "horizontal"}
  ingredient_heading.style.vertical_align = "center"
  local count = ingredient_heading.add{type = "label", name = "todo_ingredient_count", style = "heading_2_label"}
  count.style.width = 234
  local list = fields.add{type = "scroll-pane", name = "todo_ingredients", direction = "vertical"}
  list.style.width = 270
  list.style.maximal_height = ingredient_height(player)
  local error_label = fields.add{type = "label", name = "todo_plan_error", caption = ""}
  error_label.style.single_line = false
  error_label.style.maximal_width = 270
  set_draft(pane, value)
  M.refresh(pane, player)
end

function M.layout(pane, player)
  if M.element(pane).parent ~= host(pane, player) then M.render(pane, pane.tags.production, player) end
  M.element(pane).todo_ingredients.style.maximal_height = ingredient_height(player)
end

function M.set_target(pane, player, kind, name, label)
  local value = name and {type = kind, name = name, recipe = kind == "recipe" and name or nil} or false
  set_draft(pane, value)
  local tags, title = pane.tags, pane.todo_title_row.todo_title
  tags.queued_ingredients = nil
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
  local fields, value = M.element(pane), pane.tags.production
  if not value or value.type == "recipe" then return end
  local name = fields.tags.recipe_names[fields.todo_recipe_row.todo_recipe.selected_index]
  value.recipe = name ~= "" and name or nil
  local tags = pane.tags
  tags.queued_ingredients = nil
  pane.tags = tags
  set_draft(pane, value)
  M.refresh(pane, player)
end

function M.filter_recipes(pane, player)
  local prefs = store.player(player.index)
  prefs.show_locked_recipes = prefs.show_locked_recipes == false
  M.refresh(pane, player)
end

function M.queue_ingredient(pane, player, index)
  local plan = production.plan{production = M.read(pane)}
  if not plan or not plan.ingredients[index] then return end
  local tags = pane.tags
  local queued = tags.queued_ingredients or {}
  local selected
  for position, ingredient_index in ipairs(queued) do
    if ingredient_index == index then selected = position break end
  end
  if selected then table.remove(queued, selected)
  else queued[#queued + 1] = index end
  tags.queued_ingredients = queued
  pane.tags = tags
  M.refresh(pane, player)
end

return M
