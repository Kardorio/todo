script.on_init(function()
  storage.todo_manager = {
    schema_version = 1, next_id = 2,
    tasks = {[1] = {
      id = 1, title = "Legacy saved task", description = "Legacy notes", status = "TODO",
      created_by = 1, creator_name = "Legacy player", created_at = 0,
      position = {x = 5, y = -8}, surface_index = 1
    }},
    players = {[1] = {}}
  }
  log("TODO_LEGACY_WRITTEN")
end)
