local runtime = require("scripts.runtime")
local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local factopedia = require("integrations.factopedia")
local mod_gui = require("mod-gui")

local function find(root, name)
  if root.name == name then return root end
  for _, child in ipairs(root.children) do
    local found = find(child, name)
    if found then return found end
  end
end

return function(player)
  local input = assert(prototypes.custom_input["todo-manager-add-target"])
  assert(input.include_selected_prototype and input.key_sequence == "CONTROL + SHIFT + mouse-button-1")
  assert(prototypes.shortcut["todo-manager-new-task"])
  local handler = assert(script.get_event_handler("todo-manager-add-target"))
  assert(handler == runtime.from_hover)
  local function frame() return player.gui.screen.todo_manager_editor end
  local function pane() return frame().todo_editor end
  local function invoke(kind, name)
    handler{player_index = player.index, in_gui = true, selected_prototype = kind and {base_type = kind, name = name} or nil}
  end
  local function close()
    runtime.closed{player_index = player.index, element = frame()}
  end
  local before = store.get().next_id
  invoke()
  invoke("technology", "automation")
  invoke("item", "todo-unknown-prototype")
  assert(not frame() and store.get().next_id == before)
  handler{player_index = player.index, in_gui = false, selected_prototype = {base_type = "item", name = "locomotive"}}
  assert(frame() and pane().tags.production.name == "locomotive")
  close()
  handler{player_index = player.index, in_gui = true, selected_prototype = {base_type = "item", name = "locomotive", quality = "normal"}}
  assert(frame() and pane().tags.production.name == "locomotive")
  close()
  handler{player_index = player.index, in_gui = true, element = mod_gui.get_button_flow(player).todo_manager_open,
    selected_prototype = {base_type = "item", name = "locomotive"}}
  assert(frame() and pane().tags.production.name == "locomotive")
  close()
  local shortcut = assert(script.get_event_handler(defines.events.on_lua_shortcut))
  shortcut{player_index = player.index, prototype_name = "another-mod-shortcut"}
  assert(not frame())
  shortcut{player_index = player.index, prototype_name = "todo-manager-new-task"}
  assert(frame() and pane().todo_title_row.todo_title.text == "" and not pane().tags.production)
  local blank = frame()
  pane().todo_description.text = "Brouillon depuis le raccourci"
  shortcut{player_index = player.index, prototype_name = "todo-manager-new-task"}
  assert(frame() == blank and pane().todo_description.text == "Brouillon depuis le raccourci")
  close()
  assert(not frame() and store.get().next_id == before)
  local kind, name = factopedia.target{base_type = "entity", name = "locomotive"}
  assert(kind == "item" and name == "locomotive")
  local _, _, err = factopedia.target{base_type = "entity", name = "todo-test-building"}
  assert(err == "ambiguous_hovered_entity")
  invoke("entity", "todo-test-building")
  assert(not frame() and store.get().next_id == before)
  invoke("item", "todo-test-goal")
  assert(frame() and pane().tags.production.type == "item" and pane().tags.production.name == "todo-test-goal")
  assert(not pane().tags.production.recipe and not pane().tags.position and not pane().tags.surface_index)
  assert(store.get().next_id == before)
  pane().todo_description.text = "Brouillon existant"
  local draft, pending = frame(), pane().tags.title_translation
  invoke("fluid", "todo-test-fluid")
  assert(frame() == draft and pane().todo_description.text == "Brouillon existant")
  assert(pane().todo_error.caption[1] == "todo.error-draft_open" and pane().tags.production.name == "todo-test-goal")
  runtime.translated{player_index = player.index, id = pending.id, translated = true, result = "Objectif traduit"}
  assert(pane().todo_title_row.todo_title.text == "Objectif traduit")
  close()
  assert(store.get().next_id == before)
  invoke("recipe", "todo-test-alpha")
  assert(pane().tags.production.type == "recipe" and pane().tags.production.recipe == "todo-test-alpha")
  pending = pane().tags.title_translation
  runtime.translated{player_index = player.index, id = pending.id, translated = true, result = "Recette choisie"}
  runtime.clicked{player_index = player.index, element = assert(find(frame(), "todo_save"))}
  local created = assert(tasks.get(before))
  assert(not frame() and store.get().next_id == before + 1)
  assert(created.title == "Recette choisie" and created.created_by == player.index)
  assert(created.production.type == "recipe" and created.production.recipe == "todo-test-alpha")
  assert(not created.position and not created.surface_index and store.player(player.index).pinned[created.id])
  local row = player.gui.screen.todo_manager_window.todo_tree["task_" .. created.id]
  runtime.clicked{player_index = player.index, element = row.todo_decompose}
  local selection = player.gui.screen.todo_manager_production
  local checkbox = selection.todo_ingredients.ingredient_1.todo_select
  checkbox.state = true
  runtime.checked{player_index = player.index, element = checkbox}
  invoke("item", "todo-test-goal")
  assert(player.gui.screen.todo_manager_production == selection and checkbox.state and not frame())
  runtime.closed{player_index = player.index, element = selection}
  invoke("fluid", "todo-test-fluid")
  assert(pane().tags.production.type == "fluid" and not pane().tags.production.recipe)
  close()
  invoke("entity", "locomotive")
  assert(pane().tags.production.type == "item" and pane().tags.production.name == "locomotive")
  pending = pane().tags.title_translation
  close()
  runtime.translated{player_index = player.index, id = pending.id, translated = true, result = "Réponse tardive"}
  assert(not frame() and store.get().next_id == before + 1)
  log("TODO_FACTOPEDIA_OK")
end
