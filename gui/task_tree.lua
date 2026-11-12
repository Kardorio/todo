local tasks = require("scripts.task_manager")
local store = require("scripts.storage")
local common = require("gui.common")
local locations = require("scripts.location_manager")
local resolver = require("scripts.recipe_resolver")
local M = {}
local colors = {
  TODO = {r = 0.95, g = 0.95, b = 0.95},
  IN_PROGRESS = {r = 1, g = 0.75, b = 0.25},
  DONE = {r = 0.4, g = 0.85, b = 0.4},
  IGNORED = {r = 0.55, g = 0.55, b = 0.55}
}

function M.render(parent, player, compact)
  local prefs = store.player(player.index)
  local roots
  if compact then
    roots = {}
    for id, pinned in pairs(prefs.pinned) do
      if pinned and tasks.get(id) then roots[#roots + 1] = id end
    end
  end
  local entries = tasks.tree(prefs.collapsed, roots)
  local children = parent.children
  local rebuild = parent.tags.todo_tree_layout ~= 7 or #children ~= #entries
  if not rebuild then
    for index, entry in ipairs(entries) do
      local row = children[index]
      if row.name ~= "task_" .. entry.task.id or row.tags.depth ~= entry.depth then
        rebuild = true
        break
      end
    end
  end
  if rebuild then
    parent.clear()
    parent.tags = {todo_tree_layout = 7}
  end
  local counts = {}
  for _, task in ipairs(tasks.list()) do
    if task.parent_id then
      local count = counts[task.parent_id] or {children = 0, done = 0, total = 0}
      count.children = count.children + 1
      if task.status ~= "IGNORED" then count.total = count.total + 1 end
      if task.status == "DONE" then count.done = count.done + 1 end
      counts[task.parent_id] = count
    end
  end
  if #entries == 0 then
    if not parent.todo_empty then
      local label = parent.add{type = "label", name = "todo_empty", caption = {compact and "todo.no-pins" or "todo.empty"}}
      label.style.single_line = false
      label.style.maximal_width = compact and 330 or 580
    end
  end
  local progress_width = 48
  for _, entry in ipairs(entries) do
    local count = counts[entry.task.id]
    if count then
      progress_width = math.max(progress_width, #(count.done .. "/" .. count.total) * 8)
    end
  end
  local fixed_width = (compact and 186 or 218) + progress_width
  local title_width = math.max(64, parent.style.minimal_width - fixed_width - 16)
  for _, entry in ipairs(entries) do
    local task = entry.task
    local row = parent["task_" .. task.id]
    if not row then
      row = parent.add{type = "flow", direction = "horizontal", name = "task_" .. task.id,
        tags = {depth = entry.depth}}
      row.style.vertical_align = "center"
      row.add{type = "empty-widget", name = "todo_indent"}
      common.sprite(row, "collapse", "collapse", task.id, {"todo.toggle-branch"})
      local branch_space = row.add{type = "empty-widget", name = "todo_branch_space"}
      branch_space.style.width = 28
      local checked = row.add{type = "checkbox", name = "todo_done", state = false,
        caption = "", tags = common.tags("done", task.id)}
      checked.style.width = 18
      local title = common.button(row, "edit", task.title, task.id)
      title.style = "list_box_item"
      row.add{type = "label", name = "todo_priority_label"}
      row.add{type = "label", name = "todo_progress", tooltip = {"todo.progress-help"}}
      common.sprite(row, "show_location", "map", task.id)
      local location_space = row.add{type = "empty-widget", name = "todo_location_space"}
      location_space.style.width = 28
      common.sprite(row, "decompose", "change_recipe", task.id, {"todo.details"})
      local production_space = row.add{type = "empty-widget", name = "todo_production_space"}
      production_space.style.width = 28
      common.sprite(row, "pin", "track_button", task.id)
      if not compact then
        common.sprite(row, "new_child", "add", task.id, {"todo.new-child"})
      end
    end
    local count = counts[task.id]
    local has_children = count ~= nil
    row.style.horizontal_spacing = 4
    local indent_width = math.min(entry.depth * 24, compact and 60 or 156, title_width - 64)
    row.todo_indent.style.width = indent_width
    row.todo_edit.style.width = title_width - indent_width
    row.todo_priority_label.style.width = 24
    row.todo_progress.style.width = progress_width
    row.todo_progress.style.horizontal_align = "right"
    row.todo_collapse.sprite = "utility/" .. (prefs.collapsed[task.id] and "expand" or "collapse")
    row.todo_collapse.enabled = has_children
    row.todo_collapse.visible = has_children
    row.todo_branch_space.visible = not has_children
    row.todo_done.state = task.status == "DONE"
    row.todo_done.tooltip = {"todo.status-" .. task.status}
    row.todo_edit.caption = task.title
    row.todo_edit.tooltip = {"todo.task-tooltip", task.id, task.title, {"todo.status-" .. task.status}, entry.depth}
    row.todo_edit.style.font_color = colors[task.status]
    row.todo_priority_label.caption = string.rep("!", task.priority or 0)
    row.todo_priority_label.tooltip = {"todo.priority-" .. (task.priority or 0)}
    row.todo_priority_label.visible = true
    row.todo_progress.caption = count and count.done .. "/" .. count.total or ""
    row.todo_progress.visible = true
    row.todo_progress.tooltip = count and {"", count.done .. "/" .. count.total, "\n", {"todo.progress-help"}}
      or {"todo.progress-help"}
    row.todo_show_location.visible = task.position ~= nil and task.surface_index ~= nil
    row.todo_location_space.visible = not row.todo_show_location.visible
    row.todo_show_location.tooltip = locations.describe(task)
    row.todo_show_location.enabled = task.surface_index ~= nil and game.surfaces[task.surface_index] ~= nil
    row.todo_decompose.visible = task.production ~= nil
    row.todo_production_space.visible = task.production == nil
    if task.production then
      local target = resolver.prototype(task.production.type, task.production.name)
      row.todo_decompose.sprite = target and task.production.type .. "/" .. task.production.name or "utility/change_recipe"
      row.todo_decompose.tooltip = {"", target and target.localised_name or task.production.name, "\n", {"todo.details"}}
    end
    row.todo_pin.tooltip = {prefs.pinned[task.id] and "todo.unpin" or "todo.pin"}
    row.todo_pin.toggled = prefs.pinned[task.id] == true
  end
  local selected = prefs.selected_id and parent["task_" .. prefs.selected_id]
  if rebuild and selected then parent.scroll_to_element(selected) end
end

return M
