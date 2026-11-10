local store = require("scripts.storage")

script.on_nth_tick(1, function()
  local state = store.get()
  local task, prefs = state.tasks[1], state.players[1]
  assert(state.schema_version == 3 and state.gui_revision == 17 and state.next_id == 2)
  assert(task.title == "V1 saved task" and task.description == "V1 notes")
  assert(task.status == "IN_PROGRESS" and task.priority == 3 and task.revision == 9 and task.order == 7)
  assert(task.position.x == 12 and task.position.y == -8 and not task.production)
  assert(prefs.pinned[1] and prefs.collapsed[1] and not prefs.panel_visible)
  assert(prefs.panel_location.x == 42 and prefs.panel_location.y == 99)
  log("TODO_V1_UPGRADE_OK")
  script.on_nth_tick(1, nil)
end)
