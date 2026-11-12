local store = require("scripts.storage")
local location = require("scripts.location_manager")
local resolver = require("scripts.recipe_resolver")
local M = {}
local statuses = {TODO = true, IN_PROGRESS = true, DONE = true, IGNORED = true}
local apply_changes

local function sorted(tasks)
  table.sort(tasks, function(a, b)
    if a.order == b.order then return a.id < b.id end
    return a.order < b.order
  end)
  return tasks
end

local function child_index()
  local index = {}
  for _, task in pairs(store.get().tasks) do
    local key = task.parent_id or 0
    index[key] = index[key] or {}
    index[key][#index[key] + 1] = task
  end
  for _, siblings in pairs(index) do sorted(siblings) end
  return index
end

local function trim(value)
  if type(value) ~= "string" then return "" end
  return value:match("^%s*(.-)%s*$")
end

local function finite(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function next_order(parent_id)
  local maximum = 0
  for _, task in pairs(store.get().tasks) do
    if task.parent_id == parent_id then maximum = math.max(maximum, task.order) end
  end
  return maximum + 1
end

function M.get(id)
  return store.get().tasks[id]
end

function M.can_parent(id, parent_id)
  if parent_id == false then parent_id = nil end
  local seen = {}
  while parent_id do
    if parent_id == id or seen[parent_id] then return false end
    seen[parent_id] = true
    local parent = M.get(parent_id)
    if not parent then return false end
    parent_id = parent.parent_id
  end
  return true
end

function M.create(title, player, tick, parent_id, capture_location, initial_changes)
  title = trim(title)
  if title == "" then return nil, "title_required" end
  if parent_id == false then parent_id = nil end
  if parent_id and not M.get(parent_id) then return nil, "invalid_parent" end
  local state = store.get()
  local task = {
    id = state.next_id, title = title, description = "", status = "TODO", priority = 0,
    created_by = player.index, creator_name = player.name, created_at = tick,
    parent_id = parent_id, order = next_order(parent_id), revision = 1
  }
  if capture_location ~= false then
    local captured = location.capture(player)
    task.position, task.surface_index = captured.position, captured.surface_index
  end
  if initial_changes then
    local updated, err = apply_changes(task, initial_changes)
    if not updated then return nil, err end
  end
  state.tasks[task.id] = task
  state.next_id = task.id + 1
  return task
end

apply_changes = function(task, changes, expected_revision)
  local id = task.id
  if expected_revision and task.revision ~= expected_revision then return nil, "conflict" end
  local title = changes.title ~= nil and trim(changes.title) or task.title
  if title == "" then return nil, "title_required" end
  if changes.description ~= nil and type(changes.description) ~= "string" then return nil, "title_required" end
  if changes.status ~= nil and not statuses[changes.status] then return nil, "invalid_status" end
  if changes.priority ~= nil and (type(changes.priority) ~= "number" or changes.priority % 1 ~= 0
      or changes.priority < 0 or changes.priority > 3) then return nil, "invalid_priority" end
  local parent_id = task.parent_id
  if changes.parent_id ~= nil then
    parent_id = changes.parent_id or nil
    if parent_id and not M.get(parent_id) then return nil, "invalid_parent" end
    if not M.can_parent(id, parent_id) then return nil, "cycle" end
  end
  local position, surface_index = task.position, task.surface_index
  if changes.position == false or changes.surface_index == false then
    position, surface_index = nil, nil
  else
    if changes.position ~= nil then position = changes.position end
    if changes.surface_index ~= nil then surface_index = changes.surface_index end
    if position or surface_index then
      if type(position) ~= "table" or not finite(position.x) or not finite(position.y)
          or not finite(surface_index) or surface_index < 1 or surface_index % 1 ~= 0 then
        return nil, "invalid_location"
      end
    end
  end
  local production = task.production
  if changes.production == false then
    production = nil
  elseif changes.production ~= nil then
    local err
    production, err = resolver.validate(changes.production, task.production)
    if not production then return nil, err end
  end
  task.production = production
  task.title = title
  if changes.description ~= nil then task.description = changes.description end
  if changes.status ~= nil then task.status = changes.status end
  if changes.priority ~= nil then task.priority = changes.priority end
  if task.parent_id ~= parent_id then
    task.order = next_order(parent_id)
    task.parent_id = parent_id
  end
  task.position = position and {x = position.x, y = position.y} or nil
  task.surface_index = surface_index
  task.revision = task.revision + 1
  return task
end

function M.update(id, changes, expected_revision)
  local task = M.get(id)
  if not task then return nil, "missing" end
  return apply_changes(task, changes, expected_revision)
end

function M.children(parent_id)
  local result = {}
  for _, task in pairs(store.get().tasks) do
    if task.parent_id == parent_id then result[#result + 1] = task end
  end
  return sorted(result)
end

function M.list()
  local result = {}
  for _, task in pairs(store.get().tasks) do result[#result + 1] = task end
  return sorted(result)
end

function M.delete(id)
  local task = M.get(id)
  if not task then return nil, "missing" end
  local index = child_index()
  local siblings = index[task.parent_id or 0] or {}
  local promoted = index[id] or {}
  local result = {}
  for _, sibling in ipairs(siblings) do
    if sibling.id == id then
      for _, child in ipairs(promoted) do result[#result + 1] = child end
    else
      result[#result + 1] = sibling
    end
  end
  for order, sibling in ipairs(result) do
    if sibling.parent_id ~= task.parent_id or sibling.order ~= order then
      sibling.revision = sibling.revision + 1
    end
    sibling.parent_id, sibling.order = task.parent_id, order
  end
  store.get().tasks[id] = nil
  for _, prefs in pairs(store.get().players) do
    prefs.pinned[id], prefs.collapsed[id] = nil, nil
    if prefs.selected_id == id then prefs.selected_id = nil end
  end
  return true
end

function M.tree(collapsed, root_ids)
  collapsed = collapsed or {}
  local index = child_index()
  local roots = index[0] or {}
  if root_ids then
    roots = {}
    local selected = {}
    for _, id in ipairs(root_ids) do if M.get(id) then selected[id] = true end end
    for id in pairs(selected) do
      local task = M.get(id)
      local ancestor, seen, covered = task.parent_id, {}, false
      while ancestor and not seen[ancestor] do
        if selected[ancestor] then covered = true break end
        seen[ancestor] = true
        local parent = M.get(ancestor)
        ancestor = parent and parent.parent_id or nil
      end
      if not covered then roots[#roots + 1] = task end
    end
    sorted(roots)
  end
  local stack, result, visited = {}, {}, {}
  for position = #roots, 1, -1 do stack[#stack + 1] = {task = roots[position], depth = 0} end
  while #stack > 0 do
    local entry = table.remove(stack)
    local task = entry.task
    if not visited[task.id] then
      visited[task.id] = true
      result[#result + 1] = entry
      if not collapsed[task.id] then
        local children = index[task.id] or {}
        for position = #children, 1, -1 do
          stack[#stack + 1] = {task = children[position], depth = entry.depth + 1}
        end
      end
    end
  end
  return result
end

function M.progress(id)
  local done, total = 0, 0
  for _, child in pairs(store.get().tasks) do
    if child.parent_id == id and child.status ~= "IGNORED" then
      total = total + 1
      if child.status == "DONE" then done = done + 1 end
    end
  end
  return done, total
end

function M.has_children(id)
  for _, child in pairs(store.get().tasks) do if child.parent_id == id then return true end end
  return false
end

return M
