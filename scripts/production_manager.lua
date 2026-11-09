local resolver = require("scripts.recipe_resolver")
local tasks = require("scripts.task_manager")
local M = {}

local function finite(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function M.validate(value, previous)
  return resolver.validate(value, previous)
end

function M.craft_count(quantity, amount)
  if not finite(quantity) or quantity <= 0 then return nil, "invalid_quantity" end
  if not finite(amount) or amount <= 0 then return nil, "zero_yield" end
  local crafts = math.max(1, math.ceil(quantity / amount))
  if not finite(crafts) then return nil, "overflow" end
  local previous_output = (crafts - 1) * amount
  local tolerance = 4 * 2.220446049250313e-16 * math.max(quantity, previous_output)
  if crafts > 1 and previous_output >= quantity - tolerance then crafts = crafts - 1 end
  return crafts
end

function M.plan(task)
  local target, err = resolver.validate(task.production)
  if not target then return nil, err end
  if not target.recipe then return nil, "recipe_required" end
  local recipe = prototypes.recipe[target.recipe]
  if not recipe then return nil, "invalid_recipe" end
  local crafts, expected_output = 1, nil
  if target.type == "recipe" then
    crafts = target.quantity or 1
  else
    local amount = resolver.yield(recipe, target.type, target.name)
    if not finite(amount) then return nil, "overflow" end
    if amount <= 0 then return nil, "zero_yield" end
    if target.quantity then
      crafts, err = M.craft_count(target.quantity, amount)
      if not crafts then return nil, err end
    end
    expected_output = amount * crafts
    if not finite(expected_output) then return nil, "overflow" end
  end
  if not finite(crafts) or crafts < 1 then return nil, "overflow" end
  local plan = {recipe = recipe.name, crafts = crafts, expected_output = expected_output, ingredients = {}}
  for index, ingredient in ipairs(recipe.ingredients) do
    local amount = ingredient.amount * crafts
    if not finite(amount) or amount <= 0 then return nil, "overflow" end
    plan.ingredients[#plan.ingredients + 1] = {
      index = index, type = ingredient.type, name = ingredient.name, amount = amount,
      temperature = ingredient.temperature, minimum_temperature = ingredient.minimum_temperature,
      maximum_temperature = ingredient.maximum_temperature, quality_min = ingredient.quality_min,
      quality_max = ingredient.quality_max, quality_change = ingredient.quality_change
    }
  end
  return plan
end

function M.existing_children(id, recipe)
  local existing = {}
  for _, child in ipairs(tasks.children(id)) do
    local target = child.production
    if child.source_recipe == recipe and child.source_ingredient and target then
      local index = child.source_ingredient
      existing[index] = existing[index] or {}
      existing[index][target.type] = existing[index][target.type] or {}
      existing[index][target.type][target.name] = existing[index][target.type][target.name] or child
    end
  end
  return existing
end

function M.match_child(existing, ingredient)
  local index = existing[ingredient.index]
  local kind = index and index[ingredient.type]
  return kind and kind[ingredient.name]
end

function M.expand(id, selected_indices, player, tick, expected_revision)
  local task = tasks.get(id)
  if not task then return nil, "missing" end
  if expected_revision and task.revision ~= expected_revision then return nil, "conflict" end
  local plan, err = M.plan(task)
  if not plan then return nil, err end
  if type(selected_indices) ~= "table" or #selected_indices == 0 then return nil, "invalid_selection" end
  local selected, seen, array_size = {}, {}, 0
  for key in pairs(selected_indices) do
    array_size = array_size + 1
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #selected_indices then
      return nil, "invalid_selection"
    end
  end
  if array_size ~= #selected_indices then return nil, "invalid_selection" end
  for _, index in ipairs(selected_indices) do
    if type(index) ~= "number" or index % 1 ~= 0 or not plan.ingredients[index] or seen[index] then
      return nil, "invalid_selection"
    end
    seen[index] = true
    local ingredient = plan.ingredients[index]
    local production, validation_error = resolver.validate{
      type = ingredient.type, name = ingredient.name, quantity = ingredient.amount
    }
    if not production then return nil, validation_error end
    selected[#selected + 1] = {ingredient = ingredient, production = production}
  end
  local existing = M.existing_children(id, plan.recipe)
  local result = {}
  for _, entry in ipairs(selected) do
    local ingredient = entry.ingredient
    local child = M.match_child(existing, ingredient)
    if not child then
      child = assert(tasks.create(ingredient.name, player, tick, id, false))
      assert(tasks.update(child.id, {production = entry.production}, child.revision))
      child.source_recipe, child.source_ingredient = plan.recipe, ingredient.index
    end
    result[#result + 1] = child
  end
  return result
end

return M
