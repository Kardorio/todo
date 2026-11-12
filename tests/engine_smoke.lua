local runtime = require("scripts.runtime")
local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local editor = require("gui.task_editor")
local locations = require("scripts.location_manager")
local model_checks = require("model_checks")
local window = require("gui.main_window")
local tree_renderer = require("gui.task_tree")
local common = require("gui.common")
local production_checks = require("production_checks")
local production_gui_checks = require("production_gui_checks")
local factopedia_checks = require("factopedia_checks")
local mod_gui = require("mod-gui")
local panel_renderer = require("gui.compact_panel")
local loaded = false

local function find(root, name)
  local stack = {root}
  while #stack > 0 do
    local element = table.remove(stack)
    if element.name == name then return element end
    for _, child in ipairs(element.children) do stack[#stack + 1] = child end
  end
  error("Missing GUI element " .. name)
end

local function check_header(frame)
  local header = frame.children[1]
  assert(header.tags.todo_header)
  for _, element in ipairs(header.children) do
    if element.type == "sprite-button" then assert(element.style.name == "frame_action_button") end
  end
end

script.on_init(function()
  runtime.initialize()
  local player = {index = 1, name = "Fixture", position = {x = 12, y = 34}, surface = game.surfaces[1]}
  local root = assert(tasks.create("Persistence fixture", player, game.tick))
  local child = assert(tasks.create("Saved child", player, game.tick, root.id, false))
  assert(tasks.update(root.id, {production = {type = "item", name = "todo-test-goal", recipe = "todo-test-alpha", quantity = 5}}))
  assert(tasks.update(child.id, {production = {type = "item", name = "todo-test-part", recipe = "todo-test-part", quantity = 6}}))
  child.source_recipe, child.source_ingredient = "todo-test-alpha", 1
  assert(tasks.update(child.id, {status = "DONE", priority = 3, description = "Saved notes"}))
  local prefs = store.player(1)
  prefs.pinned[root.id] = true
  prefs.collapsed[root.id] = true
  prefs.panel_visible = false
  prefs.panel_location = {x = 40, y = 80}
  prefs.panel_width = 380
  log("TODO_STORAGE_WRITTEN")
end)

script.on_load(function()
  runtime.loaded()
  loaded = true
end)

local function run_checks()
  local handlers = {
    on_player_created = runtime.player_created, on_player_joined_game = runtime.player_created,
    on_player_removed = runtime.player_removed, on_gui_click = runtime.clicked,
    on_gui_checked_state_changed = runtime.checked, on_gui_closed = runtime.closed,
    on_gui_elem_changed = runtime.production_changed, on_gui_selection_state_changed = runtime.production_changed,
    on_gui_text_changed = runtime.production_changed,
    on_string_translated = runtime.translated,
    on_gui_value_changed = runtime.setting_changed,
    on_lua_shortcut = runtime.shortcut,
    on_gui_location_changed = runtime.moved, on_player_display_resolution_changed = runtime.resized,
    on_player_display_scale_changed = runtime.resized, on_surface_deleted = runtime.refresh
  }
  for name, handler in pairs(handlers) do
    assert(script.get_event_handler(defines.events[name]) == handler, "Event wiring missing: " .. name)
  end
  assert(commands.commands.todo, "The /todo command must be registered")
  assert(loaded, "V1-AC2: checks must run after a real save/load")
  assert(store.get().schema_version == 3 and store.get().next_id == 3)
  assert(tasks.get(1).title == "Persistence fixture")
  assert(tasks.get(1).position.x == 12 and tasks.get(1).position.y == 34)
  assert(tasks.get(2).parent_id == 1 and tasks.get(2).status == "DONE")
  assert(tasks.get(2).description == "Saved notes" and tasks.get(2).priority == 3)
  assert(tasks.get(1).production.name == "todo-test-goal" and tasks.get(1).production.quantity == 5)
  assert(tasks.get(2).production.recipe == "todo-test-part" and tasks.get(2).source_ingredient == 1)
  assert(not tasks.get(2).position)
  local prefs = store.player(1)
  assert(prefs.pinned[1] and prefs.collapsed[1] and not prefs.panel_visible)
  assert(prefs.panel_location.x == 40 and prefs.panel_location.y == 80)
  assert(prefs.panel_width == 380)
  log("TODO_RELOAD_OK")
  local player = assert(game.get_player(1))
  player.set_controller{type = defines.controllers.god}
  model_checks(player)
  production_checks(player)
  runtime.player_created{player_index = player.index}
  local function click(element)
    assert(element and element.valid)
    runtime.clicked{player_index = player.index, element = element}
  end
  local function frame() return player.gui.screen.todo_manager_window end
  local function edit_frame() return player.gui.screen.todo_manager_editor end
  local function pane() return edit_frame().todo_body.todo_editor end
  local function tree() return frame().todo_tree end
  local function rows() return tree_renderer.rows(tree()) end
  local function panel() return player.gui.screen.todo_manager_panel end
  local function reminder_rows() return panel_renderer.rows(panel().todo_panel_tree) end
  assert(not panel())
  local open_button = mod_gui.get_button_flow(player).todo_manager_open
  assert(not player.gui.top.todo_manager_open and not player.gui.top.todo_manager_toggle_panel)
  assert(open_button.type == "sprite-button" and open_button.style.name == mod_gui.button_style)
  assert(helpers.is_valid_sprite_path(open_button.sprite))
  local shared_buttons = mod_gui.get_button_flow(player)
  assert(not shared_buttons.todo_manager_toggle_panel)
  local peer = shared_buttons.add{type = "sprite-button", name = "todo_test_peer", style = mod_gui.button_style,
    sprite = "item/iron-plate"}
  runtime.player_created{player_index = player.index}
  assert(peer.valid and peer.parent == open_button.parent and open_button.valid)
  peer.destroy()
  click(open_button)
  click(find(frame(), "todo_toggle_panel"))
  assert(panel() and prefs.panel_visible)
  local _, reminder_order = panel_renderer.rows(panel().todo_panel_tree)
  assert(#reminder_order == 2, "Reminder must show children even if the management tree is collapsed")
  local reminder = panel()
  check_header(frame())
  assert(find(frame(), "todo_new").sprite == "utility/add_white")
  assert(find(frame(), "todo_toggle_panel").sprite == "utility/track_button_white")
  check_header(reminder)
  local revision = tasks.get(1).revision
  assert(panel_renderer.rows(reminder.todo_panel_tree).task_1.todo_show_factoriopedia.sprite == "item/todo-test-goal")
  click(panel_renderer.rows(reminder.todo_panel_tree).task_1.todo_show_factoriopedia)
  assert(panel() == reminder and tasks.get(1).revision == revision)
  player.close_factoriopedia_gui()
  click(open_button)
  assert(frame() and not edit_frame() and not frame().todo_content)
  assert(rows().task_1 and not rows().task_2)
  click(rows().task_1.todo_collapse)
  assert(rows().task_2)
  assert(rows().task_1.parent == rows().task_2.parent)
  assert(rows().task_1.parent.name == "branch_1" and rows().task_1.parent.type == "frame")
  assert(rows().task_1.todo_collapse.visible and not rows().task_1.todo_branch_space.visible)
  assert(not rows().task_2.todo_collapse.visible and rows().task_2.todo_branch_space.visible)
  assert(not rows().task_1.todo_up and not rows().task_1.todo_down)
  assert(not rows().task_2.todo_up and not rows().task_2.todo_down)
  local function column_offsets(row)
    local offsets, cursor = {}, 0
    for _, element in ipairs(row.children) do
      if element.visible then
        offsets[element.name] = cursor
        cursor = cursor + element.style.minimal_width + row.style.horizontal_spacing
      end
    end
    return offsets
  end
  local root_columns = column_offsets(rows().task_1)
  local child_columns = column_offsets(rows().task_2)
  for _, name in ipairs({"todo_priority_label", "todo_progress", "todo_pin", "todo_new_child"}) do
    assert(root_columns[name] == child_columns[name], "Misaligned task column: " .. name)
  end
  assert(root_columns.todo_show_location == child_columns.todo_location_space)
  assert(child_columns.todo_done == root_columns.todo_done + 24)
  assert(child_columns.todo_branch_space == root_columns.todo_collapse + 24)
  assert(child_columns.todo_edit == root_columns.todo_edit + 24)
  assert(rows().task_1.todo_edit.style.minimal_width == rows().task_2.todo_edit.style.minimal_width + 24)
  assert(rows().task_1.todo_priority_label.caption == "" and rows().task_2.todo_priority_label.caption == "!!!")
  local compact_root = reminder_rows().task_1
  local compact_child = reminder_rows().task_2
  assert(compact_root.todo_title.type == "label" and compact_child.todo_title.type == "label")
  assert(compact_child.todo_indent.style.minimal_width == compact_root.todo_indent.style.minimal_width + 36)
  assert(compact_root.parent == compact_child.parent and compact_root.parent.type == "frame")
  assert(compact_root.parent.todo_progressbar.value == 1)
  assert(tasks.update(2, {status = "TODO"}))
  panel_renderer.render(player)
  assert(compact_root.parent.todo_progressbar.value == 0 and tasks.get(1).status == "TODO")
  assert(tasks.update(2, {status = "IGNORED"}))
  panel_renderer.render(player)
  assert(not compact_root.parent.todo_progressbar.visible)
  assert(tasks.update(2, {status = "DONE"}))
  panel_renderer.render(player)
  assert(#compact_root.todo_indent.children == 0)
  assert(compact_child.todo_indent.level_1.caption == "└")
  local reminder_root_columns = column_offsets(compact_root)
  local reminder_child_columns = column_offsets(compact_child)
  assert(reminder_child_columns.todo_show_factoriopedia > reminder_root_columns.todo_show_factoriopedia)
  assert(reminder_child_columns.todo_title == reminder_root_columns.todo_title + 30)
  for _, row in pairs(reminder_rows()) do
    for _, element in ipairs(row.children) do
      assert(element.type ~= "checkbox")
      if element.type == "sprite-button" then
        assert(element.tags.todo_action == "show_location" or element.tags.todo_action == "show_factoriopedia")
      else assert(not element.tags.todo_action) end
    end
  end
  assert(reminder_rows().task_2)
  local original_width = reminder_rows().task_1.todo_title.style.minimal_width
  click(find(frame(), "todo_open_settings"))
  local settings = player.gui.screen.todo_manager_settings
  assert(settings and not frame())
  check_header(settings)
  local slider = settings.todo_settings_body.todo_panel_width
  local visible = settings.todo_settings_body.todo_panel_visible
  visible.state = false
  runtime.checked{player_index = player.index, element = visible}
  assert(not prefs.panel_visible and not panel())
  visible.state = true
  runtime.checked{player_index = player.index, element = visible}
  assert(prefs.panel_visible and panel())
  prefs.panel_width = 10000
  slider.slider_value = 444
  runtime.setting_changed{player_index = player.index, element = slider}
  assert(prefs.panel_width == 444 and panel().todo_panel_tree.style.minimal_width == 444)
  assert(reminder_rows().task_1.todo_title.style.minimal_width == original_width + 64)
  assert(reminder_rows().task_2.todo_indent.style.minimal_width == 36)
  click(find(panel(), "todo_toggle_panel"))
  panel_renderer.toggle(player)
  assert(panel().todo_panel_tree.style.minimal_width == 444)
  slider.slider_value = 380
  runtime.setting_changed{player_index = player.index, element = slider}
  assert(prefs.panel_width == 380)
  click(find(settings, "todo_close_settings"))
  assert(frame() and not player.gui.screen.todo_manager_settings)
  panel_renderer.change_width(player, -10000)
  assert(prefs.panel_width == 300)
  panel_renderer.change_width(player, 10000)
  local maximum = math.max(300, math.floor(player.display_resolution.width / player.display_scale - 48))
  assert(prefs.panel_width == maximum)
  panel_renderer.resized{index = player.index, gui = player.gui, display_resolution = {width = 800, height = 600}, display_scale = 1.25}
  assert(panel().todo_panel_tree.style.minimal_width == 592 and prefs.panel_width == maximum)
  assert(not store.player(987654).panel_width)
  prefs.panel_width = 380
  panel_renderer.resized(player)
  local children_reads, actual_tree = 0, tree()
  local proxy = setmetatable({}, {__index = function(_, key)
    if key == "children" then children_reads = children_reads + 1 end
    return actual_tree[key]
  end})
  tree_renderer.render(proxy, player, false)
  assert(children_reads == 1, "Refresh must fetch the copied GUI children array only once")

  -- V1-AC1: command captures the current controller's position and surface.
  local before = store.get().next_id
  runtime.command{player_index = player.index, parameter = "  Augmenter les fondeurs  "}
  local root = assert(tasks.get(before))
  assert(rows()["task_" .. root.id].parent ~= rows().task_1.parent)
  assert(root.title == "Augmenter les fondeurs" and root.created_by == player.index)
  assert(root.position.x == player.position.x and root.surface_index == player.surface.index)
  assert(prefs.pinned[root.id] and reminder_rows()["task_" .. root.id])
  local plain_columns = column_offsets(reminder_rows()["task_" .. root.id])
  assert(plain_columns.todo_title == reminder_root_columns.todo_title)
  assert(plain_columns.todo_target_space == reminder_root_columns.todo_show_factoriopedia)
  runtime.command{player_index = player.index, parameter = " "}
  assert(store.get().next_id == before + 1)
  click(find(frame(), "todo_new"))
  assert(not frame() and edit_frame() and pane().todo_title_row.todo_title)
  check_header(edit_frame())
  click(find(pane(), "todo_save"))
  assert(not frame() and edit_frame())
  assert(store.get().next_id == before + 1)
  assert(pane().todo_error.caption[1] == "todo.error-title_required")
  pane().todo_title_row.todo_title.text = "Créée dans la fenêtre"
  pane().todo_description.text = "Prévoir une gare"
  pane().todo_options.todo_status.selected_index = 2
  pane().todo_options.todo_priority.selected_index = 4
  click(find(pane(), "todo_save"))
  assert(frame() and not edit_frame())
  local ui_task = assert(tasks.get(before + 1))
  assert(ui_task.description == "Prévoir une gare" and ui_task.status == "IN_PROGRESS")
  assert(ui_task.priority == 3 and not ui_task.position)
  click(rows()["task_" .. ui_task.id].todo_new_child)
  pane().todo_title_row.todo_title.text = "Enfant"
  click(find(pane(), "todo_save"))
  local child = assert(tasks.get(before + 2))
  assert(child.parent_id == ui_task.id)
  local row = rows()["task_" .. child.id]
  row.todo_done.state = true
  runtime.checked{player_index = player.index, element = row.todo_done}
  assert(child.status == "DONE" and ui_task.status == "IN_PROGRESS")
  local done, total = tasks.progress(ui_task.id)
  assert(done == 1 and total == 1)
  click(rows()["task_" .. child.id].todo_edit)
  assert(tasks.update(child.id, {description = "Concurrent change"}))
  assert(not editor.save(player))
  assert(pane().todo_error.caption[1] == "todo.error-conflict")
  click(find(pane(), "todo_reload_editor"))
  assert(not pane().todo_parent)
  click(find(pane(), "todo_save"))
  assert(child.parent_id == ui_task.id)
  assert(tasks.update(child.id, {parent_id = false}))
  runtime.refresh()

  -- V1-AC4: location removal preserves the task; position changes require saving.
  window.resize{index = player.index, gui = player.gui, display_resolution = {width = 900, height = 600}, display_scale = 1}
  assert(tree().style.minimal_width == 740)
  window.resize{index = player.index, gui = player.gui, display_resolution = {width = 900, height = 600}, display_scale = 1.5}
  assert(tree().style.minimal_width == 536)
  window.resize(player)
  assert(rows()["task_" .. root.id].todo_show_location.visible)
  assert(rows()["task_" .. root.id].todo_show_location.tooltip[2] == player.surface.name)
  local original_window = frame()
  click(rows()["task_" .. root.id].todo_show_location)
  assert(player.controller_type == defines.controllers.remote)
  assert(original_window.valid and frame() == original_window and player.opened == original_window)
  assert(player.position.x == root.position.x and player.position.y == root.position.y)
  local action_ok = pcall(function()
    common.preserve_window(player, function() error("Navigation fixture failure") end)
  end)
  assert(not action_ok and not common.is_preserving(player.index))
  click(rows()["task_" .. root.id].todo_edit)
  pane().todo_description.text = "Draft kept while another task changes"
  editor.resize{gui = player.gui, force = player.force, display_resolution = {width = 900, height = 600}, display_scale = 1}
  assert(pane().style.maximal_height == 450)
  assert(pane().todo_description.text == "Draft kept while another task changes")
  editor.resize{gui = player.gui, force = player.force, display_resolution = {width = 900, height = 600}, display_scale = 1.5}
  assert(pane().style.maximal_height == 250)
  assert(pane().todo_description.text == "Draft kept while another task changes")
  editor.resize(player)
  runtime.command{player_index = player.index, parameter = "Refresh"}
  assert(pane().todo_description.text == "Draft kept while another task changes")
  local original_editor = edit_frame()
  local function location_panel() return edit_frame().todo_body.todo_location_side end
  assert(location_panel().todo_view.todo_camera.type == "camera")
  assert(location_panel().todo_view.todo_camera.position.x == root.position.x)
  local draft_location = pane().tags
  local preview_surface = game.create_surface("todo-preview-surface", {width = 32, height = 32})
  local preview_tags = pane().tags
  preview_tags.position, preview_tags.surface_index = {x = 1, y = 2}, preview_surface.index
  pane().tags = preview_tags
  editor.refresh_location(player)
  assert(location_panel().todo_view.todo_camera.surface_index == preview_surface.index)
  game.delete_surface(preview_surface)
  preview_tags.surface_index = 987654321
  pane().tags = preview_tags
  editor.refresh_location(player)
  assert(not location_panel().todo_view.todo_camera and not location_panel().todo_location_go.enabled)
  assert(location_panel().todo_location_clear.enabled)
  assert(pane().todo_description.text == "Draft kept while another task changes")
  pane().tags = draft_location
  editor.refresh_location(player)
  click(find(location_panel(), "todo_location_go"))
  assert(original_editor.valid and edit_frame() == original_editor and player.opened == original_editor)
  assert(pane().todo_description.text == "Draft kept while another task changes")
  click(find(location_panel(), "todo_location_clear"))
  assert(not location_panel().todo_view.todo_camera and not location_panel().todo_location_go.enabled)
  assert(root.position)
  click(find(pane(), "todo_save"))
  assert(tasks.get(root.id) and not root.position and not root.surface_index)
  assert(not rows()["task_" .. root.id].todo_show_location.visible)
  click(rows()["task_" .. root.id].todo_edit)
  assert(not location_panel().todo_location_go.enabled and not common.is_preserving(player.index))
  click(find(location_panel(), "todo_location_current"))
  assert(location_panel().todo_view.todo_camera.surface_index == player.surface.index)
  click(find(pane(), "todo_save"))
  assert(root.position.x == player.position.x)
  assert(rows()["task_" .. root.id].todo_show_location.visible)
  local physical = player.physical_position
  local physical_surface = player.physical_surface.index
  click(rows()["task_" .. root.id].todo_show_location)
  assert(player.controller_type == defines.controllers.remote)
  assert(player.physical_position.x == physical.x and player.physical_surface.index == physical_surface)

  local surface = game.create_surface("todo-remote-test", {width = 64, height = 64})
  surface.request_to_generate_chunks({0, 0}, 1)
  surface.force_generate_chunk_requests()
  player.force.chart(surface, {{-32, -32}, {32, 32}})
  player.set_controller{type = defines.controllers.remote, surface = surface, position = {24, -12}}
  local remote_id = store.get().next_id
  runtime.command{player_index = player.index, parameter = "Vue distante"}
  assert(tasks.get(remote_id).position.x == 24 and tasks.get(remote_id).position.y == -12)
  assert(tasks.get(remote_id).surface_index == surface.index)
  storage.todo_smoke_surface, storage.todo_smoke_task = surface.index, remote_id
  player.set_controller{type = defines.controllers.god}
  player.teleport({0, 0}, game.surfaces[1])
  assert(game.delete_surface(surface))

  runtime.command{player_index = player.index}
  click(rows()["task_" .. ui_task.id].todo_edit)
  click(find(pane(), "todo_delete"))
  assert(tasks.get(ui_task.id) and pane().todo_delete_confirm.visible)
  click(find(pane(), "todo_cancel_delete"))
  assert(tasks.get(ui_task.id) and not pane().todo_delete_confirm.visible)
  click(find(pane(), "todo_delete"))
  click(find(pane(), "todo_confirm_delete"))
  assert(not tasks.get(ui_task.id) and tasks.get(child.id))
  assert(frame() and not edit_frame())
  panel().location = {x = 42, y = 99}
  runtime.moved{player_index = player.index, element = panel()}
  assert(prefs.panel_location.x == 42 and prefs.panel_location.y == 99)
  click(find(frame(), "todo_toggle_panel"))
  assert(not panel() and not prefs.panel_visible)
  click(find(frame(), "todo_toggle_panel"))
  assert(panel().location.x == 42 and panel().location.y == 99)
  local other = store.player(987654)
  assert(other.panel_visible and not other.pinned[root.id] and not other.collapsed[1])
  prefs.collapsed[1] = true
  assert(not other.collapsed[1])
  runtime.player_removed{player_index = 987654}
  assert(not store.get().players[987654])
  runtime.resized{player_index = player.index}
  runtime.closed{player_index = player.index, element = frame()}
  assert(not frame() and panel())
  runtime.command{}
  runtime.command{player_index = player.index}
  assert(frame())
  click(rows()["task_" .. root.id].todo_edit)
  runtime.closed{player_index = player.index, element = edit_frame()}
  assert(frame() and not edit_frame())
  local pinned = prefs.pinned
  prefs.pinned = {}
  runtime.refresh()
  assert(not panel() and prefs.panel_visible)
  runtime.player_created{player_index = player.index}
  assert(not panel())
  prefs.pinned = pinned
  runtime.refresh()
  assert(panel())
  original_window = frame()
  click(rows()["task_" .. root.id].todo_show_location)
  storage.todo_smoke_navigation_window = original_window
  storage.todo_smoke_started = true
end

script.on_nth_tick(1, function()
  if storage.todo_smoke_gui_reloaded then
    local player = game.get_player(1)
    assert(store.get().gui_revision == 28)
    assert(not player.gui.screen.todo_manager_panel, "Legacy empty pinned panel survived reload")
    assert(player.gui.screen.todo_manager_window.todo_tree, "Legacy listing layout survived reload")
    assert(not player.gui.screen.todo_manager_window.todo_content)
    assert(not player.gui.screen.todo_manager_target_picker and not store.player(1).target_picker)
    assert(not player.gui.top.todo_manager_open and not player.gui.top.todo_manager_toggle_panel)
    assert(mod_gui.get_button_flow(player).todo_manager_open.type == "sprite-button")
    assert(store.player(1).panel_visible and tasks.get(1).title == "Persistence fixture")
    log("TODO_UI_RELOAD_OK")
    log("TODO_RUNTIME_OK")
    script.finish_test()
    return
  end
  if not storage.todo_smoke_started then run_checks() return end
  assert(storage.todo_smoke_navigation_window.valid)
  assert(game.get_player(1).opened == storage.todo_smoke_navigation_window)
  assert(not game.surfaces[storage.todo_smoke_surface])
  local task = assert(tasks.get(storage.todo_smoke_task))
  assert(locations.describe(task)[2][1] == "todo.missing-surface")
  local player = game.get_player(1)
  local marker = tree_renderer.rows(player.gui.screen.todo_manager_window.todo_tree)["task_" .. task.id].todo_show_location
  assert(marker.visible and not marker.enabled and marker.tooltip[2][1] == "todo.missing-surface")
  local ok, err = locations.navigate(game.get_player(1), task)
  assert(not ok and err == "missing_surface")
  editor.open(player, task.id)
  local missing_preview = player.gui.screen.todo_manager_editor.todo_body.todo_location_side
  assert(not missing_preview.todo_view.todo_camera and not missing_preview.todo_location_go.enabled)
  editor.close(player)
  production_gui_checks(player)
  factopedia_checks(player)
  store.player(1).pinned = {}
  local old_panel = player.gui.screen.todo_manager_panel
  old_panel.todo_panel_tree.clear()
  old_panel.todo_panel_tree.add{type = "label", caption = "Legacy empty panel"}
  window.close(player)
  local old_window = player.gui.screen.add{type = "frame", name = "todo_manager_window"}
  old_window.add{type = "flow", name = "todo_content"}
  player.gui.screen.add{type = "frame", name = "todo_manager_target_picker"}
  store.player(1).target_picker = {entries = {{kind = "item", name = "iron-plate"}}}
  player.gui.top.add{type = "button", name = "todo_manager_open", caption = "Legacy tasks"}
  player.gui.top.add{type = "button", name = "todo_manager_toggle_panel", caption = "Legacy pin"}
  store.get().gui_revision = nil
  storage.todo_smoke_gui_reloaded = true
  game.reload_mods()
end)
