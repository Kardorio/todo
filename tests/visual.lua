local runtime = require("scripts.runtime")
local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local window = require("gui.main_window")
local editor = require("gui.task_editor")

script.on_init(function()
  runtime.initialize()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  surface.daytime = 0
  surface.freeze_daytime = true
  storage.todo_visual_phase = 0
end)

local function tick(event)
  local player = game.get_player(1)
  if not player or storage.todo_visual_phase == nil then return end
  if storage.todo_visual_phase == 0 and event.tick >= 60 then
    player.teleport({0, 0}, game.surfaces[1])
    player.zoom = 1
    local locomotive = assert(tasks.create("Automatiser les locomotives", player, game.tick))
    storage.todo_visual_task = locomotive.id
    local surface = player.surface
    local tiles = {}
    for x = -5, 9 do
      for y = -5, 5 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end
    end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered{area = {{-5, -5}, {10, 6}}, type = {"tree", "simple-entity"}}) do
      entity.destroy()
    end
    for x = -3, 6, 3 do surface.create_entity{name = "assembling-machine-2", position = {x, 0}, force = player.force} end
    for x = -5, 8 do surface.create_entity{name = "transport-belt", position = {x, 3}, direction = defines.direction.east, force = player.force} end
    assert(tasks.update(locomotive.id, {production = {type = "item", name = "locomotive", recipe = "locomotive"}}))
    local engines = assert(tasks.create("Renforcer la production de moteurs", player, game.tick, locomotive.id, false))
    assert(tasks.update(engines.id, {status = "IN_PROGRESS", production = {type = "item", name = "engine-unit"}}))
    local gears = assert(tasks.create("Assembler les engrenages", player, game.tick, engines.id, false))
    local steel = assert(tasks.create("Prévoir un stock d'acier", player, game.tick, locomotive.id, false))
    assert(tasks.update(steel.id, {status = "DONE"}))
    local station = assert(tasks.create("Construire la gare de ravitaillement", player, game.tick))
    local note = assert(tasks.create("Vérifier les priorités des répartiteurs", player, game.tick, nil, false))
    local prefs = store.player(player.index)
    prefs.pinned = {[locomotive.id] = true, [station.id] = true, [note.id] = true}
    prefs.panel_visible = true
    prefs.panel_width = 508
    prefs.panel_location = {x = 36, y = 110}
    runtime.refresh()
    local rows = player.gui.screen.todo_manager_panel.todo_panel_tree
    assert(rows["task_" .. engines.id].todo_indent.level_1.caption == "├")
    assert(rows["task_" .. gears.id].todo_indent.level_1.caption == "│")
    assert(rows["task_" .. gears.id].todo_indent.level_2.caption == "└")
    assert(rows["task_" .. steel.id].todo_indent.level_1.caption == "└")
    storage.todo_visual_phase = 1
  elseif storage.todo_visual_phase == 1 and event.tick >= 100 then
    game.take_screenshot{player = player, position = {0, 0}, resolution = {1280, 900}, zoom = 1,
      show_gui = true, path = "todo-reminder.png", force_render = true}
    storage.todo_visual_phase = 2
  elseif storage.todo_visual_phase == 2 and event.tick >= 130 then
    runtime.command{player_index = player.index}
    storage.todo_visual_phase = 3
  elseif storage.todo_visual_phase == 3 and event.tick >= 160 then
    game.take_screenshot{player = player, position = {0, 0}, resolution = {1280, 900}, zoom = 1,
      show_gui = true, path = "todo-management.png", force_render = true}
    storage.todo_visual_phase = 4
  elseif storage.todo_visual_phase == 4 and event.tick >= 190 then
    window.close(player)
    player.open_factoriopedia_gui(prototypes.item.locomotive)
    storage.todo_visual_phase = 5
  elseif storage.todo_visual_phase == 5 and event.tick >= 220 then
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-factopedia.png", force_render = true}
    storage.todo_visual_phase = 6
  elseif storage.todo_visual_phase == 6 and event.tick >= 250 then
    storage.todo_visual_next_id = store.get().next_id
    runtime.from_hover{player_index = player.index, in_gui = true, selected_prototype = {base_type = "item", name = "locomotive"}}
    storage.todo_visual_phase = 7
  elseif storage.todo_visual_phase == 7 and event.tick >= 310 then
    local pane = player.gui.screen.todo_manager_editor.todo_body.todo_editor
    if pane.tags.title_translation then return end
    assert(pane.tags.production.name == "locomotive" and not pane.tags.position)
    assert(pane.todo_title_row.todo_title.text ~= "locomotive")
    assert(store.get().next_id == storage.todo_visual_next_id)
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-from-factopedia.png", force_render = true}
    storage.todo_visual_phase = 8
    storage.todo_visual_next_tick = event.tick + 30
  elseif storage.todo_visual_phase == 8 and event.tick >= storage.todo_visual_next_tick then
    editor.open(player, storage.todo_visual_task)
    storage.todo_visual_phase = 9
    storage.todo_visual_next_tick = event.tick + 30
  elseif storage.todo_visual_phase == 9 and event.tick >= storage.todo_visual_next_tick then
    game.take_screenshot{player = player, resolution = {1280, 900}, show_gui = true,
      path = "todo-location-editor.png", force_render = true}
    helpers.write_file("todo-visual-result.txt", "TODO VISUAL OK\n", false)
    storage.todo_visual_phase = nil
  end
end

script.on_event(defines.events.on_tick, tick)
script.on_load(function()
  runtime.loaded()
  script.on_event(defines.events.on_tick, tick)
end)
