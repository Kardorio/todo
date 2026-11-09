local names = {"ore", "part", "goal", "catalyst", "probability", "empty"}
for _, name in ipairs(names) do
  data:extend{{type = "item", name = "todo-test-" .. name,
    localised_name = {"", "Test ", name},
    icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64,
    subgroup = "intermediate-product", stack_size = 100}}
end

data:extend{{
  type = "fluid", name = "todo-test-fluid", icon = "__base__/graphics/icons/fluid/water.png", icon_size = 64,
  localised_name = {"", "Test fluid"},
  default_temperature = 25, max_temperature = 500, heat_capacity = "1kJ",
  base_color = {r = 0.1, g = 0.3, b = 0.8}, flow_color = {r = 0.2, g = 0.4, b = 1}
}}

local function recipe(name, ingredients, results, extra)
  local definition = {
    type = "recipe", name = "todo-test-" .. name, enabled = true, energy_required = 1,
    localised_name = {"", "Test ", name},
    icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64,
    ingredients = ingredients, results = results, auto_recycle = false, sort_item_ingredients = false
  }
  for key, value in pairs(extra or {}) do definition[key] = value end
  data:extend{definition}
end

local function item(name, amount)
  return {type = "item", name = "todo-test-" .. name, amount = amount}
end

recipe("alpha", {item("part", 2), item("ore", 3)}, {item("goal", 2), item("catalyst", 1)})
recipe("beta", {item("ore", 1)}, {item("goal", 1)}, {enabled = false})
recipe("hidden", {item("ore", 1)}, {item("goal", 1)}, {hidden = true})
recipe("part", {item("ore", 2)}, {item("part", 1)})
recipe("cycle", {item("part", 1), item("ore", 1)}, {item("part", 1)})
recipe("catalyst", {item("catalyst", 1), item("ore", 2)}, {item("catalyst", 1), item("goal", 1)})
recipe("probability", {item("ore", 2)}, {{type = "item", name = "todo-test-probability",
  amount_min = 1, amount_max = 3, independent_probability = 0.5, shared_probability = {min = 0, max = 0.5}}})
recipe("repeated", {item("ore", 1)}, {item("goal", 1), item("goal", 2)})
recipe("fluid", {{type = "fluid", name = "todo-test-fluid", amount = 2,
  minimum_temperature = 100, maximum_temperature = 200}},
  {{type = "fluid", name = "todo-test-fluid", amount = 4, temperature = 150}}, {categories = {"chemistry"}})
recipe("cold-fluid", {item("ore", 1)},
  {{type = "fluid", name = "todo-test-fluid", amount = 2, temperature = 25}}, {categories = {"chemistry"}})
recipe("no-input", {}, {item("empty", 1)})
recipe("decimal-fluid", {item("ore", 1)},
  {{type = "fluid", name = "todo-test-fluid", amount = 0.01, temperature = 25}}, {categories = {"chemistry"}})
