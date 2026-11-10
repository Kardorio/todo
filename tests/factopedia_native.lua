local runtime = require("scripts.runtime")
local store = require("scripts.storage")
local original = assert(script.get_event_handler("todo-manager-add-target"))

script.on_init(function()
  runtime.initialize()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
  storage.probe_phase = 0
end)

script.on_event("todo-manager-add-target", function(event)
  local selected = event.selected_prototype
  helpers.write_file("todo-native-selected.txt", selected and (selected.base_type .. ":" .. selected.name) or "none", false)
  original(event)
  local player = game.get_player(event.player_index)
  local frame = assert(player.gui.screen.todo_manager_editor, "Real shortcut did not open the editor")
  assert(frame.todo_editor.tags.production.name == "locomotive")
  assert(not frame.todo_editor.tags.position and store.get().next_id == 1)
  storage.probe_phase, storage.probe_capture = 2, game.tick + 60
end)

local function tick(event)
  local player = game.get_player(1)
  if not player then return end
  if storage.probe_phase == 0 and event.tick >= 60 then
    player.open_factoriopedia_gui(prototypes.item.locomotive)
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-before.png", force_render = true}
    helpers.write_file("todo-native-ready.txt", "READY", false)
    storage.probe_phase = 1
  elseif storage.probe_phase == 2 and event.tick >= storage.probe_capture then
    local pane = player.gui.screen.todo_manager_editor.todo_editor
    if pane.tags.title_translation then return end
    assert(pane.todo_title_row.todo_title.text == "Locomotive")
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-native-after.png", force_render = true}
    helpers.write_file("todo-native-done.txt", "OK", false)
    storage.probe_phase = 3
  end
end

script.on_event(defines.events.on_tick, tick)
script.on_load(function()
  runtime.loaded()
  script.on_event(defines.events.on_tick, tick)
end)
