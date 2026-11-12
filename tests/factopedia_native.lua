local runtime = require("scripts.runtime")
local store = require("scripts.storage")
local editor = require("gui.task_editor")
local original = assert(script.get_event_handler("todo-manager-add-target"))

script.on_event(defines.events.on_pre_player_crafted_item, function(event)
  storage.probe_crafted = event.recipe.name
  assert(not game.get_player(event.player_index).gui.screen.todo_manager_editor)
  helpers.write_file("todo-native-selected.txt", "native-craft: " .. event.recipe.name .. ";tick=" .. event.tick .. "\n", true)
  if storage.probe_phase == "craft-input" then
    storage.probe_phase, storage.probe_capture = "craft-check", game.tick + 30
  end
end)

script.on_init(function()
  runtime.initialize()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
  storage.probe_phase = "inventory-open"
end)

script.on_event("todo-manager-add-target", function(event)
  local player = game.get_player(event.player_index)
  local selected = event.selected_prototype
  helpers.write_file("todo-native-selected.txt", storage.probe_phase .. ": "
    .. (selected and (selected.base_type .. ":" .. selected.name) or "none")
    .. ";quality=" .. tostring(selected and selected.quality)
    .. ";gui=" .. tostring(player.opened_gui_type) .. ";in_gui=" .. tostring(event.in_gui)
    .. ";element=" .. tostring(event.element) .. "\n", true)
  if storage.probe_phase == "inventory-input" then
    assert(selected and selected.name == "locomotive" and selected.quality == "normal")
    original(event)
    assert(player.gui.screen.todo_manager_editor.todo_body.todo_editor.tags.production.name == "locomotive")
    storage.probe_phase, storage.probe_capture = "inventory-result", game.tick + 60
    return
  end
  local right = storage.probe_phase == "factopedia-right-input"
  assert(right or storage.probe_phase == "factopedia-input")
  local expected = right and "iron-plate" or "locomotive"
  assert(selected and selected.name == expected)
  original(event)
  local frame = assert(player.gui.screen.todo_manager_editor, "Real shortcut did not open the editor")
  assert(frame.todo_body.todo_editor.tags.production.name == expected)
  assert(not frame.todo_body.todo_editor.tags.position and store.get().next_id == 1)
  storage.probe_phase, storage.probe_capture = right and "result-right" or "result", game.tick + 60
end)

local function tick(event)
  local player = game.get_player(1)
  if not player then return end
  if storage.probe_phase == "inventory-open" and event.tick >= 60 then
    player.insert{name = "locomotive", count = 3}
    player.opened = player
    storage.probe_phase, storage.probe_capture = "inventory-capture", game.tick + 30
  elseif storage.probe_phase == "inventory-capture" and event.tick >= storage.probe_capture then
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-inventory.png", force_render = true}
    storage.probe_phase = "inventory-input"
  elseif storage.probe_phase == "inventory-result" and event.tick >= storage.probe_capture then
    local pane = player.gui.screen.todo_manager_editor.todo_body.todo_editor
    if pane.tags.title_translation then return end
    assert(pane.tags.production.name == "locomotive" and store.get().next_id == 1)
    editor.close(player)
    player.opened = player
    storage.probe_phase, storage.probe_capture = "craft-capture", game.tick + 30
  elseif storage.probe_phase == "craft-capture" and event.tick >= storage.probe_capture then
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-crafting.png", force_render = true}
    storage.probe_phase = "craft-input"
  elseif storage.probe_phase == "craft-check" and event.tick >= storage.probe_capture then
    assert(not player.gui.screen.todo_manager_editor and store.get().next_id == 1)
    assert(storage.probe_crafted == "iron-chest")
    storage.probe_phase, storage.probe_capture = "factopedia-open", game.tick + 30
  elseif storage.probe_phase == "factopedia-open" and event.tick >= storage.probe_capture then
    player.open_factoriopedia_gui(prototypes.item.locomotive)
    storage.probe_phase, storage.probe_capture = "factopedia-capture", game.tick + 30
  elseif storage.probe_phase == "factopedia-capture" and event.tick >= storage.probe_capture then
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-before.png", force_render = true}
    helpers.write_file("todo-native-ready.txt", "READY", false)
    storage.probe_phase = "factopedia-input"
  elseif storage.probe_phase == "result" and event.tick >= storage.probe_capture then
    local pane = player.gui.screen.todo_manager_editor.todo_body.todo_editor
    if pane.tags.title_translation then return end
    assert(pane.todo_title_row.todo_title.text == "Locomotive")
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-after.png", force_render = true}
    editor.close(player)
    player.opened = player
    player.open_factoriopedia_gui(prototypes.item["iron-gear-wheel"])
    storage.probe_phase, storage.probe_capture = "right-capture", game.tick + 30
  elseif storage.probe_phase == "right-capture" and event.tick >= storage.probe_capture then
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-right-before.png", force_render = true}
    storage.probe_phase = "factopedia-right-input"
  elseif storage.probe_phase == "result-right" and event.tick >= storage.probe_capture then
    local pane = player.gui.screen.todo_manager_editor.todo_body.todo_editor
    if pane.tags.title_translation then return end
    assert(pane.tags.production.name == "iron-plate" and pane.todo_title_row.todo_title.text ~= "iron-plate")
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-right-after.png", force_render = true}
    helpers.write_file("todo-native-done.txt", "OK", false)
    storage.probe_phase = "done"
  end
end

script.on_event(defines.events.on_tick, tick)
script.on_load(function()
  runtime.loaded()
  script.on_event(defines.events.on_tick, tick)
end)
