local M = {}
local kinds = {item = true, fluid = true, recipe = true}

local function finite(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function M.prototype(kind, name)
  if not kinds[kind] or type(name) ~= "string" then return nil end
  return prototypes[kind][name]
end

function M.recipes(kind, name)
  if not M.prototype(kind, name) then return {} end
  if kind == "recipe" then return {prototypes.recipe[name]} end
  local result = {}
  local candidates = prototypes.get_recipe_filtered{
    {filter = "has-product-" .. kind, elem_filters = {{filter = "name", name = name}}},
    {filter = "hidden", invert = true, mode = "and"}
  }
  for _, recipe in pairs(candidates) do result[#result + 1] = recipe end
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

function M.yield(recipe, kind, name)
  local amount = 0
  for index, product in ipairs(recipe.products) do
    if product.type == kind and product.name == name then
      amount = amount + recipe.get_product_amount(index, 0)
    end
  end
  return amount
end

function M.validate(value, previous)
  if type(value) ~= "table" or not kinds[value.type] or type(value.name) ~= "string" or value.name == "" then
    return nil, "invalid_target"
  end
  if value.quantity ~= nil and (not finite(value.quantity) or value.quantity <= 0
      or (value.type ~= "fluid" and value.quantity % 1 ~= 0)) then return nil, "invalid_quantity" end
  if value.recipe ~= nil and (type(value.recipe) ~= "string" or value.recipe == "") then
    return nil, "invalid_recipe"
  end
  local normalized = {type = value.type, name = value.name, recipe = value.recipe, quantity = value.quantity}
  if normalized.type == "recipe" then normalized.recipe = normalized.name end
  if previous and normalized.type == previous.type and normalized.name == previous.name
      and normalized.recipe == previous.recipe and normalized.quantity == previous.quantity then return normalized end
  if not M.prototype(normalized.type, normalized.name) then return nil, "missing_prototype" end
  if normalized.recipe then
    local recipe = prototypes.recipe[normalized.recipe]
    if not recipe then return nil, "invalid_recipe" end
    if normalized.type ~= "recipe" then
      local amount = M.yield(recipe, normalized.type, normalized.name)
      if not finite(amount) then return nil, "overflow" end
      if amount <= 0 then return nil, "zero_yield" end
    end
  end
  return normalized
end

return M
