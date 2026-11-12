script.on_init(function()
  storage.todo_manager = {
    schema_version = 2, gui_revision = 5, next_id = 2,
    tasks = {[1] = {
      id = 1, title = "V1 saved task", description = "V1 notes", status = "IN_PROGRESS",
      priority = 3, revision = 9, order = 7,
      created_by = 1, creator_name = "V1 player", created_at = 123,
      position = {x = 12, y = -8}, surface_index = 1
    }},
    players = {[1] = {pinned = {[1] = true}, collapsed = {[1] = true}, panel_visible = false, panel_location = {x = 42, y = 99}}}
  }
  log("TODO_V1_WRITTEN")
end)
