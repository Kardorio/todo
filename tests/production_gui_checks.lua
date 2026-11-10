local runtime = require("scripts.runtime")
local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local production = require("scripts.production_manager")
local editor = require("gui.task_editor")

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
  local function select_target(kind, name)
    local original = player.gui.screen.todo_manager_editor
    local button = pane().todo_title_row.todo_choose_target
    assert(button.type == "choose-elem-button" and button.elem_type == "signal")
    button.elem_value = name and {type = kind, name = name} or nil
    changed(button)
    assert(original.valid and original.visible and player.opened == original)
    assert(not player.gui.screen.todo_manager_target_picker)
    if name then assert(pane().tags.production.type == kind and pane().tags.production.name == name) end
  end
  local function recipe(name)
    local fields = pane().todo_production
    for index, candidate in ipairs(fields.tags.recipe_names) do
      if candidate == name then
        fields.todo_recipe_row.todo_recipe.selected_index = index
        changed(fields.todo_recipe_row.todo_recipe)
        return
      end
    end
    error("Recipe missing in selector: " .. name)
  end
  runtime.command{player_index = player.index}
  click(find(player.gui.screen.todo_manager_window, "todo_new"))
  pane().todo_title_row.todo_title.text = "Objectif de production"
  assert(pane().todo_title_row.todo_title.parent == pane().todo_title_row.todo_choose_target.parent)
  assert(not pane().todo_production.todo_target_pickers)
  assert(not pane().todo_production.todo_quantity and not pane().todo_production.todo_quantity_label)
  assert(pane().children[3] == pane().todo_production)
  select_target("item", "todo-test-ore")
  assert(not pane().tags.production.recipe and not pane().todo_production.todo_recipe_row.visible)
  select_target("item", "todo-test-empty")
  assert(pane().tags.production.recipe == "todo-test-no-input" and not pane().todo_production.todo_recipe_row.visible)
  select_target("item", "todo-test-goal")
  assert(pane().todo_title_row.todo_title.text == "Objectif de production")
  assert(pane().tags.production.name == "todo-test-goal" and not pane().tags.production.recipe)
  assert(pane().todo_production.todo_recipe_row.todo_recipe.selected_index == 1)
  assert(pane().todo_production.todo_recipe_row.visible)
  assert(pane().todo_production.todo_recipe_row.todo_recipe.style.minimal_width == 318)
  assert(not pane().todo_production.todo_recipe_row.todo_recipe_info.visible)
  assert(not pane().todo_production.todo_clear_target)
  recipe("todo-test-alpha")
  local original_editor = player.gui.screen.todo_manager_editor
  pane().todo_description.text = "Brouillon des ingrédients"
  assert(pane().todo_production.type == "frame")
  assert(pane().todo_production.todo_ingredients.visible)
  click(pane().todo_production.todo_preview)
  assert(player.opened == original_editor and pane().todo_description.text == "Brouillon des ingrédients")
  assert(not pane().todo_production.todo_ingredients.visible)
  click(pane().todo_production.todo_preview)
  assert(pane().todo_production.todo_ingredients.visible and #pane().todo_production.todo_ingredients.children == 2)
  recipe("todo-test-beta")
  assert(#pane().todo_production.todo_ingredients.children == 1)
  recipe("todo-test-alpha")
  click(pane().todo_production.todo_preview)
  assert(not pane().todo_production.todo_ingredients.visible)
  local id = store.get().next_id
  click(find(pane(), "todo_save"))
  local task = assert(tasks.get(id))
  assert(not task.production.quantity and task.production.recipe == "todo-test-alpha")
  assert(#tasks.children(id) == 0)
  click(list()["task_" .. id].todo_edit)
  local temporary_child = assert(tasks.create("Sous-tâche temporaire", player, game.tick, id, false))
  runtime.refresh()
  assert(pane().todo_production.todo_recipe_row.todo_recipe_info.visible)
  assert(tasks.delete(temporary_child.id))
  runtime.refresh()
  assert(not pane().todo_production.todo_recipe_row.todo_recipe_info.visible)
  runtime.closed{player_index = player.index, element = player.gui.screen.todo_manager_editor}
  local marker = list()["task_" .. id].todo_decompose
  assert(marker.visible and marker.sprite == "item/todo-test-goal" and helpers.is_valid_sprite_path(marker.sprite))
  click(marker)
  assert(chooser() and not player.gui.screen.todo_manager_window and not chooser().todo_production_add.enabled)
  local plan = assert(production.plan(task))
  assert(plan.crafts == 1)
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
  assert(#children == 1 and children[1].production.name == "todo-test-part" and children[1].production.quantity == 2)
  assert(not children[1].production.recipe and not tasks.has_children(children[1].id))
  click(list()["task_" .. id].todo_decompose)
  assert(not chooser().todo_ingredients["ingredient_" .. part_index].todo_select.enabled)
  assert(chooser().todo_ingredients["ingredient_" .. ore_index].todo_select.enabled)
  runtime.closed{player_index = player.index, element = chooser()}
  local child = children[1]
  click(list()["task_" .. child.id].todo_edit)
  assert(pane().todo_production.todo_recipe_row.visible and not pane().tags.production.recipe)
  recipe("todo-test-part")
  click(find(pane(), "todo_save"))
  click(list()["task_" .. child.id].todo_decompose)
  local child_plan = assert(production.plan(child))
  assert(child.production.quantity == 2 and #child_plan.ingredients == 1 and child_plan.ingredients[1].amount == 4)
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
  assert(pane().todo_production.todo_recipe_row.todo_recipe_info.visible)
  assert(pane().todo_production.todo_recipe_row.todo_recipe_info.tooltip[1] == "todo.production-children-unchanged")
  select_target("item", "todo-test-empty")
  assert(not pane().todo_production.todo_recipe_row.visible and not pane().todo_production.todo_recipe_row.todo_recipe_info.visible)
  select_target("item", "todo-test-goal")
  assert(pane().todo_production.todo_recipe_row.todo_recipe_info.visible)
  recipe("todo-test-beta")
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
  select_target("fluid", "todo-test-fluid")
  assert(pane().tags.production.type == "fluid")
  assert(pane().todo_production.todo_recipe_row.visible and not pane().tags.production.recipe)
  recipe("todo-test-fluid")
  click(find(pane(), "todo_save"))
  assert(task.production.type == "fluid" and not task.production.quantity)
  click(list()["task_" .. id].todo_edit)
  select_target()
  click(find(pane(), "todo_save"))
  assert(not task.production and not list()["task_" .. id].todo_decompose.visible)
  click(find(player.gui.screen.todo_manager_window, "todo_new"))
  pane().todo_title_row.todo_title.text = "Objectif recette"
  select_target("recipe", "todo-test-alpha")
  assert(pane().tags.production.recipe == "todo-test-alpha" and not pane().todo_production.todo_recipe_row.visible)
  local recipe_id = store.get().next_id
  click(find(pane(), "todo_save"))
  assert(tasks.get(recipe_id).production.type == "recipe")
  assert(production.plan(tasks.get(recipe_id)).crafts == 1)
  click(find(player.gui.screen.todo_manager_window, "todo_new"))
  pane().todo_description.text = "Brouillon conservé"
  select_target("item", "todo-test-goal")
  assert(pane().todo_description.text == "Brouillon conservé")
  assert(pane().todo_title_row.todo_choose_target.elem_value.type == nil)
  local target_button = pane().todo_title_row.todo_choose_target
  local original_title = pane().todo_title_row.todo_title.text
  target_button.elem_value = {type = "virtual", name = "signal-A"}
  changed(target_button)
  assert(pane().todo_error.caption[1] == "todo.error-invalid_target_signal")
  assert(pane().tags.production.name == "todo-test-goal" and target_button.elem_value.name == "todo-test-goal")
  assert(pane().todo_title_row.todo_title.text == original_title)
  local pending = pane().tags.title_translation
  assert(pending and pane().todo_title_row.todo_title.text == "todo-test-goal")
  click(find(pane(), "todo_save"))
  assert(pane().todo_error.caption[1] == "todo.error-title_translation_pending")
  local expired_id = pending.id
  local title_tags = pane().tags
  title_tags.title_translation.tick = game.tick - 180
  pane().tags = title_tags
  editor.retry_translation(player)
  pending = pane().tags.title_translation
  assert(pending.id ~= expired_id)
  runtime.translated{player_index = player.index, id = expired_id, translated = true, result = "Réponse expirée"}
  assert(pane().todo_title_row.todo_title.text == "todo-test-goal")
  runtime.translated{player_index = player.index, id = pending.id, translated = true, result = "Nom localisé de l'objet"}
  assert(pane().todo_title_row.todo_title.text == "Nom localisé de l'objet")
  select_target("fluid", "todo-test-fluid")
  local fluid_pending = pane().tags.title_translation
  runtime.translated{player_index = player.index, id = pending.id, translated = true, result = "Ancienne réponse"}
  assert(pane().todo_title_row.todo_title.text == "todo-test-fluid")
  runtime.translated{player_index = player.index, id = fluid_pending.id, translated = true, result = "Fluide traduit"}
  assert(pane().todo_title_row.todo_title.text == "Fluide traduit")
  select_target()
  assert(not pane().tags.production and not pane().todo_production.visible)
  assert(not pane().todo_title_row.todo_choose_target.elem_value)
  pane().todo_title_row.todo_title.text = "Mon titre personnel"
  changed(pane().todo_title_row.todo_title)
  select_target("recipe", "todo-test-alpha")
  assert(pane().todo_title_row.todo_title.text == "Mon titre personnel" and not pane().tags.title_translation)
  click(find(pane(), "todo_save"))
  assert(not player.gui.screen.todo_manager_editor)
  log("TODO_PRODUCTION_GUI_OK")
end
