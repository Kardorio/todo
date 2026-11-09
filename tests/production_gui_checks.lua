local runtime = require("scripts.runtime")
local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local production = require("scripts.production_manager")

local function find(root, name)
  local stack = {root}
  while #stack > 0 do
    local element = table.remove(stack)
    if element.name == name then return element end
    for _, child in ipairs(element.children) do stack[#stack + 1] = child end
  end
  error("Missing production GUI element " .. name)
end

return function(player)
  local function click(element)
    runtime.clicked{player_index = player.index, element = element}
  end
  local function changed(element)
    runtime.production_changed{player_index = player.index, element = element}
  end
  local function list() return player.gui.screen.todo_manager_window.todo_tree end
  local function pane() return player.gui.screen.todo_manager_editor.todo_editor end
  local function chooser() return player.gui.screen.todo_manager_production end
  local function recipe(name)
    local fields = pane().todo_production
    for index, candidate in ipairs(fields.tags.recipe_names) do
      if candidate == name then
        fields.todo_recipe.selected_index = index
        changed(fields.todo_recipe)
        return
      end
    end
    error("Recipe missing in selector: " .. name)
  end
  runtime.command{player_index = player.index}
  click(find(player.gui.screen.todo_manager_window, "todo_new"))
  pane().todo_title.text = "Objectif de production"
  local picker = pane().todo_production.todo_target_pickers.todo_target_item
  picker.elem_value = "todo-test-goal"
  changed(picker)
  assert(pane().tags.production.name == "todo-test-goal" and not pane().tags.production.recipe)
  assert(pane().todo_production.todo_recipe.selected_index == 1)
  pane().todo_production.todo_quantity.text = "5"
  changed(pane().todo_production.todo_quantity)
  recipe("todo-test-alpha")
  local id = store.get().next_id
  local before_invalid = {}
  for existing_id, existing_task in pairs(store.get().tasks) do
    before_invalid[existing_id] = {order = existing_task.order, revision = existing_task.revision}
  end
  pane().todo_production.todo_quantity.text = "0"
  click(find(pane(), "todo_save"))
  assert(store.get().next_id == id and not tasks.get(id))
  assert(pane().todo_error.caption[1] == "todo.error-invalid_quantity")
  for existing_id, snapshot in pairs(before_invalid) do
    assert(tasks.get(existing_id).order == snapshot.order and tasks.get(existing_id).revision == snapshot.revision)
  end
  pane().todo_production.todo_quantity.text = "5"
  click(find(pane(), "todo_save"))
  local task = assert(tasks.get(id))
  assert(task.production.quantity == 5 and task.production.recipe == "todo-test-alpha")
  assert(#tasks.children(id) == 0)
  local marker = list()["task_" .. id].todo_decompose
  assert(marker.visible and marker.sprite == "item/todo-test-goal" and helpers.is_valid_sprite_path(marker.sprite))
  click(marker)
  assert(chooser() and not player.gui.screen.todo_manager_window and not chooser().todo_production_add.enabled)
  local plan = assert(production.plan(task))
  assert(plan.crafts == 3)
  local part_index, ore_index
  for _, ingredient in ipairs(plan.ingredients) do
    if ingredient.name == "todo-test-part" then part_index = ingredient.index end
    if ingredient.name == "todo-test-ore" then ore_index = ingredient.index end
  end
  local selected = chooser().todo_ingredients["ingredient_" .. part_index].todo_select
  selected.state = true
  runtime.checked{player_index = player.index, element = selected}
  assert(chooser().todo_production_add.enabled)
  click(chooser().todo_production_add)
  local children = tasks.children(id)
  assert(#children == 1 and children[1].production.name == "todo-test-part" and children[1].production.quantity == 6)
  assert(not children[1].production.recipe and not tasks.has_children(children[1].id))
  click(list()["task_" .. id].todo_decompose)
  assert(not chooser().todo_ingredients["ingredient_" .. part_index].todo_select.enabled)
  assert(chooser().todo_ingredients["ingredient_" .. ore_index].todo_select.enabled)
  runtime.closed{player_index = player.index, element = chooser()}
  local child = children[1]
  click(list()["task_" .. child.id].todo_edit)
  recipe("todo-test-part")
  click(find(pane(), "todo_save"))
  click(list()["task_" .. child.id].todo_decompose)
  local child_plan = assert(production.plan(child))
  assert(#child_plan.ingredients == 1 and child_plan.ingredients[1].amount == 12)
  selected = chooser().todo_ingredients.ingredient_1.todo_select
  selected.state = true
  runtime.checked{player_index = player.index, element = selected}
  click(chooser().todo_production_add)
  assert(#tasks.children(child.id) == 1 and tasks.children(child.id)[1].production.name == "todo-test-ore")
  assert(tasks.update(child.id, {production = {type = "item", name = "todo-test-ore", quantity = 6}}))
  click(list()["task_" .. id].todo_decompose)
  selected = chooser().todo_ingredients["ingredient_" .. part_index].todo_select
  assert(selected.enabled)
  selected.state = true
  runtime.checked{player_index = player.index, element = selected}
  click(chooser().todo_production_add)
  local replacement
  for _, candidate in ipairs(tasks.children(id)) do
    if candidate.id ~= child.id then replacement = candidate end
  end
  assert(replacement and replacement.production.name == "todo-test-part")
  assert(tasks.move(child.id, 1))
  click(list()["task_" .. id].todo_decompose)
  assert(not chooser().todo_ingredients["ingredient_" .. part_index].todo_select.enabled)
  local before_repeat = store.get().next_id
  assert(production.expand(id, {part_index}, player, game.tick, task.revision)[1].id == replacement.id)
  assert(store.get().next_id == before_repeat)
  runtime.closed{player_index = player.index, element = chooser()}
  assert(tasks.delete(replacement.id))
  assert(tasks.update(child.id, {production = {type = "item", name = "todo-test-part", recipe = "todo-test-part", quantity = 6}}))
  runtime.refresh()
  click(list()["task_" .. id].todo_edit)
  recipe("todo-test-beta")
  pane().todo_production.todo_quantity.text = "2"
  click(find(pane(), "todo_save"))
  assert(task.production.recipe == "todo-test-beta" and #tasks.children(id) == 1)
  assert(child.production.quantity == 6)
  click(list()["task_" .. id].todo_decompose)
  assert(tasks.update(id, {description = "Concurrent plan change"}))
  selected = chooser().todo_ingredients.ingredient_1.todo_select
  selected.state = true
  runtime.checked{player_index = player.index, element = selected}
  click(chooser().todo_production_add)
  assert(chooser().todo_production_error.caption[1] == "todo.error-conflict")
  runtime.closed{player_index = player.index, element = chooser()}
  click(list()["task_" .. id].todo_edit)
  picker = pane().todo_production.todo_target_pickers.todo_target_fluid
  picker.elem_value = "todo-test-fluid"
  changed(picker)
  assert(not pane().todo_production.todo_target_pickers.todo_target_item.elem_value)
  pane().todo_production.todo_quantity.text = "2,5"
  recipe("todo-test-fluid")
  click(find(pane(), "todo_save"))
  assert(task.production.type == "fluid" and task.production.quantity == 2.5)
  click(list()["task_" .. id].todo_edit)
  picker = pane().todo_production.todo_target_pickers.todo_target_fluid
  picker.elem_value = nil
  changed(picker)
  click(find(pane(), "todo_save"))
  assert(not task.production and not list()["task_" .. id].todo_decompose.visible)
  click(find(player.gui.screen.todo_manager_window, "todo_new"))
  pane().todo_title.text = "Objectif recette"
  picker = pane().todo_production.todo_target_pickers.todo_target_recipe
  picker.elem_value = "todo-test-alpha"
  changed(picker)
  assert(pane().tags.production.recipe == "todo-test-alpha" and not pane().todo_production.todo_recipe.visible)
  pane().todo_production.todo_quantity.text = "invalid"
  click(find(pane(), "todo_save"))
  assert(pane().todo_error.caption[1] == "todo.error-invalid_quantity")
  pane().todo_production.todo_quantity.text = "2"
  local recipe_id = store.get().next_id
  click(find(pane(), "todo_save"))
  assert(tasks.get(recipe_id).production.type == "recipe")
  assert(production.plan(tasks.get(recipe_id)).crafts == 2)
  log("TODO_PRODUCTION_GUI_OK")
end
