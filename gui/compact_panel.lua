local common = require("gui.common")
local store = require("scripts.storage")
local tasks = require("scripts.task_manager")
local locations = require("scripts.location_manager")
local resolver = require("scripts.recipe_resolver")
local M = {}
local colors = {
  TODO = {r = 0.95, g = 0.95, b = 0.95},
  IN_PROGRESS = {r = 1, g = 0.75, b = 0.25},
  DONE = {r = 0.4, g = 0.85, b = 0.4},
  IGNORED = {r = 0.55, g = 0.55, b = 0.55}
}

local function maximum_width(player)
  return math.max(300, math.floor(player.display_resolution.width / player.display_scale - 48))
end

local function panel_width(player, prefs)
  return math.max(300, math.min(prefs.panel_width or 380, maximum_width(player)))
end

local function render_list(parent, roots, width)
  local entries = tasks.tree({}, roots)
  local rows = parent.children
  local rebuild = parent.tags.reminder_layout ~= 3 or #rows ~= #entries
  if not rebuild then
    for index, entry in ipairs(entries) do
      if rows[index].name ~= "task_" .. entry.task.id then rebuild = true break end
    end
  end
  if rebuild then parent.clear() parent.tags = {reminder_layout = 3} end
  local last_children, continuation = {}, {}
  for _, entry in ipairs(entries) do
    if entry.depth > 0 then last_children[entry.task.parent_id] = entry.task.id end
  end
  for _, entry in ipairs(entries) do
    local task = entry.task
    local row = parent["task_" .. task.id]
    if not row then
      row = parent.add{type = "flow", name = "task_" .. task.id, direction = "horizontal"}
      row.style.vertical_align = "center"
      row.style.horizontal_spacing = 4
      row.style.minimal_height = 28
      common.sprite(row, "show_location", "map", task.id)
      local location_space = row.add{type = "empty-widget", name = "todo_location_space"}
      location_space.style.width = 28
      common.sprite(row, "show_factoriopedia", "change_recipe", task.id)
      local target_space = row.add{type = "empty-widget", name = "todo_target_space"}
      target_space.style.width = 28
      local branches = row.add{type = "flow", name = "todo_indent", direction = "horizontal"}
      branches.style.horizontal_spacing = 0
      row.add{type = "label", name = "todo_title"}
    end
    local indent = math.min(entry.depth * 24, 96)
    row.todo_indent.style.width = indent
    row.todo_indent.clear()
    continuation[entry.depth] = entry.depth > 0 and last_children[task.parent_id] ~= task.id
    for level = math.max(1, entry.depth - 3), entry.depth do
      local caption = level == entry.depth and (continuation[level] and "├" or "└")
        or (continuation[level] and "│" or "")
      local branch = row.todo_indent.add{type = "label", name = "level_" .. level, caption = caption}
      branch.style.width = 24
      branch.style.font_color = {r = 0.65, g = 0.65, b = 0.65}
    end
    local located = task.position ~= nil and task.surface_index ~= nil
    row.todo_show_location.visible = located
    row.todo_location_space.visible = not located
    row.todo_show_location.enabled = located and game.surfaces[task.surface_index] ~= nil
    row.todo_show_location.tooltip = locations.describe(task)
    local value = task.production
    local target = value and resolver.prototype(value.type, value.name)
    row.todo_show_factoriopedia.visible = value ~= nil
    row.todo_target_space.visible = value == nil
    row.todo_show_factoriopedia.enabled = target ~= nil
    row.todo_show_factoriopedia.sprite = target and value.type .. "/" .. value.name or "utility/change_recipe"
    row.todo_show_factoriopedia.tooltip = {"", target and target.localised_name or (value and value.name or ""),
      "\n", {"todo.open-factoriopedia"}}
    row.todo_title.caption = task.title
    row.todo_title.tooltip = {"", task.title, "\n", {"todo.status-" .. task.status},
      task.description ~= "" and "\n" .. task.description or ""}
    row.todo_title.style.font_color = colors[task.status]
    row.todo_title.style.single_line = true
    row.todo_title.style.width = width - 84 - indent
  end
end

function M.render(player)
  local prefs = store.player(player.index)
  local width = panel_width(player, prefs)
  local frame = player.gui.screen.todo_manager_panel
  local roots = {}
  for id, pinned in pairs(prefs.pinned) do
    if pinned and tasks.get(id) then roots[#roots + 1] = id end
  end
  if not prefs.panel_visible or #roots == 0 then
    if frame then frame.destroy() end
    return
  end
  if not frame then
    frame = player.gui.screen.add{type = "frame", name = "todo_manager_panel", direction = "vertical"}
    local header = common.header(frame, {"todo.pinned"})
    for _, action in ipairs({"narrow_panel", "widen_panel"}) do
      local button = common.button(header, action, action == "narrow_panel" and "−" or "+", nil, {"todo." .. action})
      button.style = "tool_button"
      button.style.size = {28, 28}
    end
    common.sprite(header, "toggle_panel", "close", nil, {"todo.hide-panel"})
    local list = frame.add{type = "scroll-pane", name = "todo_panel_tree", direction = "vertical"}
    list.style.maximal_height = math.max(150, math.min(400, player.display_resolution.height / player.display_scale - 230))
    frame.location = common.clamp(player, prefs.panel_location or {x = 12, y = 200}, width + 36, 460)
  end
  frame.todo_panel_tree.style.width = width
  render_list(frame.todo_panel_tree, roots, width)
end

function M.change_width(player, delta)
  local prefs = store.player(player.index)
  prefs.panel_width = math.max(300, math.min(panel_width(player, prefs) + delta, maximum_width(player)))
  M.resized(player)
end

function M.toggle(player)
  local prefs = store.player(player.index)
  prefs.panel_visible = not prefs.panel_visible
  M.render(player)
end

function M.moved(player, element)
  if element.name == "todo_manager_panel" then
    store.player(player.index).panel_location = {x = element.location.x, y = element.location.y}
  end
end

function M.resized(player)
  local frame = player.gui.screen.todo_manager_panel
  if frame then
    local prefs = store.player(player.index)
    local width = panel_width(player, prefs)
    prefs.panel_location = common.clamp(player, frame.location, width + 36, 460)
    frame.destroy()
  end
  M.render(player)
end

return M
