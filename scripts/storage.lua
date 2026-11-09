local M = {}

local function preferences(value)
  value = value or {}
  value.pinned = value.pinned or {}
  value.collapsed = value.collapsed or {}
  if value.panel_visible == nil then value.panel_visible = true end
  return value
end

function M.initialize()
  local state = storage.todo_manager
  if not state then
    state = {schema_version = 2, next_id = 1, tasks = {}, players = {}}
    storage.todo_manager = state
  end
  assert(state.schema_version == 1 or state.schema_version == 2, "Unsupported Todo Manager schema")
  local highest_id = 0
  for id, task in pairs(state.tasks) do
    task.order = task.order or id
    task.priority = task.priority or 0
    task.revision = task.revision or 1
    highest_id = math.max(highest_id, id)
  end
  state.next_id = math.max(state.next_id, highest_id + 1)
  for index, value in pairs(state.players) do state.players[index] = preferences(value) end
  state.schema_version = 2
  return state
end

function M.get()
  return storage.todo_manager
end

function M.player(index)
  local state = M.get()
  if not state.players[index] then
    state.players[index] = preferences()
  end
  return state.players[index]
end

return M
