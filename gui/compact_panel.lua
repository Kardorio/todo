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

local function render_list(parent, roots)
  local entries = tasks.tree({}, roots)
  local rows = parent.children
  local rebuild = parent.tags.reminder_layout ~= 2 or #rows ~= #entries
  if not rebuild then
    for index, entry in ipairs(entries) do
      if rows[index].name ~= "task_" .. entry.task.id then rebuild = true break end
    end
  end
  if rebuild then parent.clear() parent.tags = {reminder_layout = 2} end
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
      row.add{type = "empty-widget", name = "todo_indent"}
      row.add{type = "label", name = "todo_title"}
    end
    local indent = math.min(entry.depth * 24, 96)
    row.todo_indent.style.width = indent
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
    row.todo_title.style.width = 296 - indent
  end
end

function M.render(player)
  local prefs = store.player(player.index)
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
    common.sprite(header, "toggle_panel", "close", nil, {"todo.hide-panel"})
    local list = frame.add{type = "scroll-pane", name = "todo_panel_tree", direction = "vertical"}
    list.style.width = 380
    list.style.maximal_height = math.max(150, math.min(400, player.display_resolution.height / player.display_scale - 230))
    frame.location = common.clamp(player, prefs.panel_location or {x = 12, y = 200}, 416, 460)
  end
  render_list(frame.todo_panel_tree, roots)
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
    prefs.panel_location = common.clamp(player, frame.location, 416, 460)
    frame.destroy()
  end
  M.render(player)
end

return M
