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

function M.rows(parent)
  local rows, order, cards = {}, {}, parent.children
  for _, card in ipairs(cards) do
    if card.type == "frame" then
      for _, row in ipairs(card.children) do
        if row.name:match("^task_") then rows[row.name] = row order[#order + 1] = row end
      end
    end
  end
  return rows, order, cards
end

local function render_list(parent, roots, width)
  local entries = tasks.tree({}, roots)
  local rows, order, cards = M.rows(parent)
  local rebuild = parent.tags.reminder_layout ~= 4 or #order ~= #entries
  local groups, group, last_children, continuation, counts = {}, nil, {}, {}, {}
  for _, task in pairs(store.get().tasks) do
    if task.parent_id then
      local count = counts[task.parent_id] or {done = 0, total = 0}
      if task.status ~= "IGNORED" then count.total = count.total + 1 end
      if task.status == "DONE" then count.done = count.done + 1 end
      counts[task.parent_id] = count
    end
  end
  for index, entry in ipairs(entries) do
    if entry.depth == 0 then group = entry.task.id groups[#groups + 1] = group end
    entry.group = group
    local row = order[index]
    if not row or row.name ~= "task_" .. entry.task.id or row.tags.depth ~= entry.depth
      or row.parent.name ~= "goal_" .. group then rebuild = true end
    if entry.depth > 0 then last_children[entry.task.parent_id] = entry.task.id end
  end
  if #cards ~= #groups then rebuild = true end
  if rebuild then
    parent.clear()
    parent.tags = {reminder_layout = 4}
    rows = {}
    for _, id in ipairs(groups) do
      local card = parent.add{type = "frame", name = "goal_" .. id, direction = "vertical", style = "inside_shallow_frame"}
      card.style.padding = 10
      card.style.bottom_margin = 8
    end
  end
  local inner_width = width - 32
  for _, id in ipairs(groups) do parent["goal_" .. id].style.width = width - 12 end
  for _, entry in ipairs(entries) do
    local task, root = entry.task, entry.depth == 0
    local card = parent["goal_" .. entry.group]
    local count = (root and counts[task.id]) or nil
    local row = rows["task_" .. task.id]
    if not row then
      row = card.add{type = "flow", name = "task_" .. task.id, direction = "horizontal", tags = {depth = entry.depth}}
      row.style.vertical_align = "center"
      row.style.horizontal_spacing = 6
      row.style.minimal_height = root and 40 or 28
      local branches = row.add{type = "flow", name = "todo_indent", direction = "horizontal"}
      branches.style.horizontal_spacing = 0
      local icon = common.sprite(row, "show_factoriopedia", "change_recipe", task.id)
      icon.style = "slot_button"
      icon.style.size = root and {36, 36} or {24, 24}
      local placeholder = row.add{type = "sprite", name = "todo_target_space", sprite = "utility/side_menu_achievements_icon"}
      placeholder.style.size = root and {36, 36} or {24, 24}
      placeholder.style.stretch_image_to_widget_size = true
      row.add{type = "label", name = "todo_title", style = root and "heading_2_label" or "label"}
      row.add{type = "label", name = "todo_progress", tooltip = {"todo.progress-help"}}
      common.sprite(row, "show_location", "map", task.id, locations.describe(task)).style.size = root and {28, 28} or {22, 22}
      if root then
        local bar = card.add{type = "progressbar", name = "todo_progressbar", value = 0, tooltip = {"todo.progress-help"}}
        bar.style.height = 6
        bar.style.bottom_margin = 6
      end
    end
    local indent = root and 0 or math.min((entry.depth + 1) * 18, 90)
    row.todo_indent.style.width = indent
    row.todo_indent.visible = not root
    row.todo_indent.clear()
    continuation[entry.depth] = entry.depth > 0 and last_children[task.parent_id] ~= task.id
    if not root then
      row.todo_indent.add{type = "empty-widget", name = "todo_spine"}.style.width = 18
      for level = math.max(1, entry.depth - 3), entry.depth do
        local caption = level == entry.depth and (continuation[level] and "├" or "└")
          or (continuation[level] and "│" or "")
        local branch = row.todo_indent.add{type = "label", name = "level_" .. level, caption = caption}
        branch.style.width = 18
        branch.style.font_color = {r = 0.45, g = 0.45, b = 0.45}
      end
    end
    local located = task.position ~= nil and task.surface_index ~= nil
    row.todo_show_location.visible = located
    row.todo_show_location.enabled = located and game.surfaces[task.surface_index] ~= nil
    row.todo_show_location.tooltip = locations.describe(task)
    local value = task.production
    local target = value and resolver.prototype(value.type, value.name)
    row.todo_show_factoriopedia.visible = value ~= nil
    row.todo_target_space.visible = value == nil
    row.todo_target_space.sprite = task.status == "DONE" and "utility/check_mark_green" or "utility/side_menu_achievements_icon"
    row.todo_show_factoriopedia.enabled = target ~= nil
    row.todo_show_factoriopedia.sprite = target and value.type .. "/" .. value.name or "utility/change_recipe"
    row.todo_show_factoriopedia.tooltip = {"", target and target.localised_name or (value and value.name or ""),
      "\n", {"todo.open-factoriopedia"}}
    row.todo_title.caption = task.title
    row.todo_title.tooltip = {"", task.title, "\n", {"todo.status-" .. task.status},
      task.description ~= "" and "\n" .. task.description or ""}
    row.todo_title.style.font_color = root and task.status == "TODO" and {r = 1, g = 0.84, b = 0.57} or colors[task.status]
    row.todo_title.style.single_line = true
    local caption = count and (count.done .. " / " .. count.total) or ""
    local counter_width = math.max(32, #caption * 7)
    row.todo_progress.caption = caption
    row.todo_progress.visible = count ~= nil
    row.todo_progress.style.width = counter_width
    row.todo_progress.style.font = "default-bold"
    row.todo_progress.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    row.todo_title.style.width = inner_width - (root and 42 or indent + 36)
      - (count and counter_width + 6 or 0) - (located and (root and 34 or 28) or 0)
    if root then
      local bar = card.todo_progressbar
      bar.visible = count ~= nil and count.total > 0
      bar.value = count and count.total > 0 and count.done / count.total or 0
      bar.style.width = inner_width
      bar.style.color = count and count.done == count.total and {r = 0.4, g = 0.85, b = 0.4}
        or {r = 1, g = 0.65, b = 0.2}
    end
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
