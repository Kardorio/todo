local runtime = require("scripts.runtime")
local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local production = require("scripts.production_manager")
local editor = require("gui.task_editor")
local production_fields = require("gui.production_fields")

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
  local function pane() return player.gui.screen.todo_manager_editor.todo_body.todo_editor end
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
    local fields = production_fields.element(pane())
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
  assert(not production_fields.element(pane()).todo_target_pickers)
  assert(not production_fields.element(pane()).todo_quantity and not production_fields.element(pane()).todo_quantity_label)
  assert(production_fields.element(pane()).parent == pane().parent)
  select_target("item", "todo-test-ore")
  assert(not pane().tags.production.recipe and not production_fields.element(pane()).todo_recipe_row.visible)
  select_target("item", "todo-test-empty")
  assert(pane().tags.production.recipe == "todo-test-no-input" and not production_fields.element(pane()).todo_recipe_row.visible)
  select_target("item", "todo-test-goal")
  assert(pane().todo_title_row.todo_title.text == "Objectif de production")
  assert(pane().tags.production.name == "todo-test-goal" and not pane().tags.production.recipe)
  assert(production_fields.element(pane()).todo_recipe_row.todo_recipe.selected_index == 1)
  assert(production_fields.element(pane()).todo_recipe_row.visible)
  assert(production_fields.element(pane()).todo_recipe_row.todo_recipe.style.minimal_width == 242)
  assert(not production_fields.element(pane()).todo_recipe_row.todo_recipe_info.visible)
  assert(not production_fields.element(pane()).todo_clear_target)
  local filter = player.gui.screen.todo_manager_editor.todo_editor_header.todo_filter_recipes
  assert(filter.parent == player.gui.screen.todo_manager_editor.todo_editor_header)
  assert(filter.get_index_in_parent() + 1 == filter.parent.todo_close_editor.get_index_in_parent())
  assert(filter.sprite == "utility/side_menu_tutorials_icon" and helpers.is_valid_sprite_path(filter.sprite))
  assert(filter.toggled and filter.tooltip[1] == "factoriopedia.show-unresearched")
  local function contains_recipe(name)
    for _, candidate in ipairs(production_fields.element(pane()).tags.recipe_names) do
      if candidate == name then return true end
    end
    return false
  end
  assert(contains_recipe("todo-test-beta"))
  click(filter)
  assert(not filter.toggled)
  assert(not contains_recipe("todo-test-beta") and not pane().tags.production.recipe)
  assert(store.player(player.index).show_locked_recipes == false)
  click(filter)
  assert(filter.toggled)
  assert(contains_recipe("todo-test-beta"))
  recipe("todo-test-alpha")
  local original_editor = player.gui.screen.todo_manager_editor
  pane().todo_description.text = "Brouillon des ingrédients"
  assert(production_fields.element(pane()).type == "frame")
  assert(production_fields.element(pane()).todo_ingredients.visible)
  assert(not production_fields.element(pane()).todo_preview)
  assert(player.opened == original_editor and pane().todo_description.text == "Brouillon des ingrédients")
  click(production_fields.element(pane()).todo_ingredient_heading.todo_recipe_factopedia)
  assert(original_editor.valid and pane().todo_description.text == "Brouillon des ingrédients")
  player.close_factoriopedia_gui()
  assert(production_fields.element(pane()).todo_ingredients.visible and #production_fields.element(pane()).todo_ingredients.children == 2)
  recipe("todo-test-beta")
  click(player.gui.screen.todo_manager_editor.todo_editor_header.todo_filter_recipes)
  assert(pane().tags.production.recipe == "todo-test-beta" and not contains_recipe("todo-test-beta"))
  click(player.gui.screen.todo_manager_editor.todo_editor_header.todo_filter_recipes)
  assert(#production_fields.element(pane()).todo_ingredients.children == 1)
  recipe("todo-test-alpha")
  assert(production_fields.element(pane()).todo_ingredients.visible)
  editor.resize{gui = player.gui, force = player.force, display_resolution = {width = 800, height = 600}, display_scale = 1}
  assert(production_fields.element(pane()).parent == pane())
  assert(pane().todo_description.text == "Brouillon des ingrédients" and pane().tags.production.recipe == "todo-test-alpha")
  assert(production_fields.element(pane()).todo_ingredients.visible)
  editor.resize(player)
  assert(production_fields.element(pane()).parent == pane().parent)
  local same_fields = production_fields.element(pane())
  editor.resize{gui = player.gui, force = player.force, display_resolution = {width = 1280, height = 420}, display_scale = 1}
  assert(production_fields.element(pane()) == same_fields)
  assert(same_fields.todo_ingredients.style.maximal_height == 160)
  assert(pane().todo_description.text == "Brouillon des ingrédients")
  editor.resize(player)
  local id = store.get().next_id
  click(find(pane(), "todo_save"))
  local task = assert(tasks.get(id))
  assert(not task.production.quantity and task.production.recipe == "todo-test-alpha")
  assert(#tasks.children(id) == 0)
  click(list()["task_" .. id].todo_edit)
  local temporary_child = assert(tasks.create("Sous-tâche temporaire", player, game.tick, id, false))
  runtime.refresh()
  assert(production_fields.element(pane()).todo_recipe_row.todo_recipe_info.visible)
  assert(tasks.delete(temporary_child.id))
  runtime.refresh()
  assert(not production_fields.element(pane()).todo_recipe_row.todo_recipe_info.visible)
  runtime.closed{player_index = player.index, element = player.gui.screen.todo_manager_editor}
  local marker = list()["task_" .. id].todo_decompose
  assert(marker.visible and marker.sprite == "item/todo-test-goal" and helpers.is_valid_sprite_path(marker.sprite))
  click(marker)
  assert(pane() and not player.gui.screen.todo_manager_production and not player.gui.screen.todo_manager_window)
  local plan = assert(production.plan(task))
  assert(plan.crafts == 1)
  local part_index, ore_index
  for _, ingredient in ipairs(plan.ingredients) do
    if ingredient.name == "todo-test-part" then part_index = ingredient.index end
    if ingredient.name == "todo-test-ore" then ore_index = ingredient.index end
  end
  click(production_fields.element(pane()).todo_ingredients["ingredient_" .. part_index].todo_queue_ingredient)
  click(find(pane(), "todo_save"))
  local children = tasks.children(id)
  assert(#children == 1 and children[1].production.name == "todo-test-part" and children[1].production.quantity == 2)
  assert(not children[1].production.recipe and not tasks.has_children(children[1].id))
  click(list()["task_" .. id].todo_decompose)
  assert(not production_fields.element(pane()).todo_ingredients["ingredient_" .. part_index].todo_queue_ingredient.enabled)
  assert(production_fields.element(pane()).todo_ingredients["ingredient_" .. ore_index].todo_queue_ingredient.enabled)
  runtime.closed{player_index = player.index, element = player.gui.screen.todo_manager_editor}
  local child = children[1]
  click(list()["task_" .. child.id].todo_edit)
  assert(production_fields.element(pane()).todo_recipe_row.visible and not pane().tags.production.recipe)
  recipe("todo-test-part")
  click(find(pane(), "todo_save"))
  click(list()["task_" .. child.id].todo_decompose)
  local child_plan = assert(production.plan(child))
  assert(child.production.quantity == 2 and #child_plan.ingredients == 1 and child_plan.ingredients[1].amount == 4)
  click(production_fields.element(pane()).todo_ingredients.ingredient_1.todo_queue_ingredient)
  click(find(pane(), "todo_save"))
  assert(#tasks.children(child.id) == 1 and tasks.children(child.id)[1].production.name == "todo-test-ore")
  assert(tasks.update(child.id, {production = {type = "item", name = "todo-test-ore", quantity = 6}}))
  click(list()["task_" .. id].todo_decompose)
  local selected = production_fields.element(pane()).todo_ingredients["ingredient_" .. part_index].todo_queue_ingredient
  assert(selected.enabled)
  click(selected)
  click(find(pane(), "todo_save"))
  local replacement
  for _, candidate in ipairs(tasks.children(id)) do
    if candidate.id ~= child.id then replacement = candidate end
  end
  assert(replacement and replacement.production.name == "todo-test-part")
  assert(tasks.move(child.id, 1))
  click(list()["task_" .. id].todo_decompose)
  assert(not production_fields.element(pane()).todo_ingredients["ingredient_" .. part_index].todo_queue_ingredient.enabled)
  local before_repeat = store.get().next_id
  assert(production.expand(id, {part_index}, player, game.tick, task.revision)[1].id == replacement.id)
  assert(store.get().next_id == before_repeat)
  runtime.closed{player_index = player.index, element = player.gui.screen.todo_manager_editor}
  assert(tasks.delete(replacement.id))
  assert(tasks.update(child.id, {production = {type = "item", name = "todo-test-part", recipe = "todo-test-part", quantity = 6}}))
  runtime.refresh()
  click(list()["task_" .. id].todo_edit)
  assert(production_fields.element(pane()).todo_recipe_row.todo_recipe_info.visible)
  assert(production_fields.element(pane()).todo_recipe_row.todo_recipe_info.tooltip[1] == "todo.production-children-unchanged")
  select_target("item", "todo-test-empty")
  assert(not production_fields.element(pane()).todo_recipe_row.visible and not production_fields.element(pane()).todo_recipe_row.todo_recipe_info.visible)
  select_target("item", "todo-test-goal")
  assert(production_fields.element(pane()).todo_recipe_row.todo_recipe_info.visible)
  recipe("todo-test-beta")
  click(find(pane(), "todo_save"))
  assert(task.production.recipe == "todo-test-beta" and #tasks.children(id) == 1)
  assert(child.production.quantity == 6)
  click(list()["task_" .. id].todo_decompose)
  assert(tasks.update(id, {description = "Concurrent plan change"}))
  click(production_fields.element(pane()).todo_ingredients.ingredient_1.todo_queue_ingredient)
  click(find(pane(), "todo_save"))
  assert(pane().todo_error.caption[1] == "todo.error-conflict")
  runtime.closed{player_index = player.index, element = player.gui.screen.todo_manager_editor}
  click(list()["task_" .. id].todo_edit)
  select_target("fluid", "todo-test-fluid")
  assert(pane().tags.production.type == "fluid")
  assert(production_fields.element(pane()).todo_recipe_row.visible and not pane().tags.production.recipe)
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
  assert(pane().tags.production.recipe == "todo-test-alpha" and not production_fields.element(pane()).todo_recipe_row.visible)
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
  assert(not pane().tags.production and not production_fields.element(pane()).visible)
  assert(not pane().todo_title_row.todo_choose_target.elem_value)
  pane().todo_title_row.todo_title.text = "Mon titre personnel"
  changed(pane().todo_title_row.todo_title)
  select_target("recipe", "todo-test-alpha")
  assert(pane().todo_title_row.todo_title.text == "Mon titre personnel" and not pane().tags.title_translation)
  click(find(pane(), "todo_save"))
  assert(not player.gui.screen.todo_manager_editor)
  editor.open(player)
  pane().todo_title_row.todo_title.text = "Objectif avec composants"
  select_target("item", "todo-test-goal")
  recipe("todo-test-alpha")
  local queued_id = store.get().next_id
  local ingredient_row = production_fields.element(pane()).todo_ingredients.ingredient_1
  click(ingredient_row.todo_queue_ingredient)
  assert(pane().tags.queued_ingredients[1] and store.get().next_id == queued_id)
  click(production_fields.element(pane()).todo_ingredients.ingredient_1.todo_queue_ingredient)
  assert(not pane().tags.queued_ingredients[1])
  click(production_fields.element(pane()).todo_ingredients.ingredient_1.todo_queue_ingredient)
  local queued_task = assert(editor.save(player))
  assert(#tasks.children(queued_task.id) == 1)
  editor.open(player, queued_task.id)
  assert(not production_fields.element(pane()).todo_ingredients.ingredient_1.todo_queue_ingredient.enabled)
  editor.close(player)
  log("TODO_PRODUCTION_GUI_OK")
end
