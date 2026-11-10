local common = require("gui.common")
local tree = require("gui.task_tree")
local M = {}
local window_name = "todo_manager_window"

function M.resize(player)
  local frame = player.gui.screen[window_name]
  if not frame then return end
  local width = math.max(300, math.min(740, player.display_resolution.width / player.display_scale - 64))
  local height = math.max(100, math.min(440, player.display_resolution.height / player.display_scale - 150))
  local list = frame.todo_tree
  list.style.width = width
  list.style.maximal_height = height
  list.style.minimal_height = 64
  tree.render(list, player, false)
end

function M.ensure_button(player)
  if not player.gui.top.todo_manager_open then
    player.gui.top.add{type = "button", name = "todo_manager_open", caption = {"todo.title"},
      tooltip = {"todo.open"}, tags = common.tags("open")}
  end
  if not player.gui.top.todo_manager_toggle_panel then
    player.gui.top.add{type = "sprite-button", name = "todo_manager_toggle_panel",
      sprite = "utility/track_button", tooltip = {"todo.toggle-panel"}, tags = common.tags("toggle_panel")}
  end
  player.gui.top.todo_manager_open.tags = common.tags("open")
  player.gui.top.todo_manager_toggle_panel.tags = common.tags("toggle_panel")
end

function M.close(player)
  local frame = player.gui.screen[window_name]
  if frame then frame.destroy() end
end

function M.render(player)
  local frame = player.gui.screen[window_name]
  if frame then
    if not frame.todo_tree then
      M.close(player)
      M.open(player)
      return
    end
    M.resize(player)
  end
end

function M.open(player)
  local frame = player.gui.screen[window_name]
  if frame and not frame.todo_tree then M.close(player) frame = nil end
  if not frame then
    frame = player.gui.screen.add{type = "frame", name = window_name, direction = "vertical"}
    local header = common.header(frame, {"todo.title"})
    common.sprite(header, "new", "add", nil, {"todo.new-help"})
    common.sprite(header, "toggle_panel", "track_button", nil, {"todo.toggle-panel"})
    common.sprite(header, "close", "close", nil, {"todo.close"})
    frame.add{type = "scroll-pane", name = "todo_tree", direction = "vertical"}
    frame.auto_center = true
  end
  M.render(player)
  player.opened = frame
end

function M.is_window(element)
  return element and element.valid and element.name == window_name
end

return M
