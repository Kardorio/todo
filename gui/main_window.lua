local common = require("gui.common")
local tree = require("gui.task_tree")
local mod_gui = require("mod-gui")
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
  for _, name in ipairs({"todo_manager_open", "todo_manager_toggle_panel"}) do
    local old = player.gui.top[name]
    if old then old.destroy() end
  end
  local buttons = mod_gui.get_button_flow(player)
  if not buttons.todo_manager_open then
    buttons.add{type = "sprite-button", name = "todo_manager_open", style = mod_gui.button_style,
      sprite = "utility/list_view", tooltip = {"todo.open"}, tags = common.tags("open")}
  end
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
    common.sprite(header, "toggle_panel_settings", "expand", nil, {"todo.panel-width"})
    common.sprite(header, "close", "close", nil, {"todo.close"})
    local settings = frame.add{type = "flow", name = "todo_panel_settings", direction = "horizontal"}
    settings.visible = false
    settings.style.vertical_align = "center"
    settings.add{type = "label", caption = {"todo.panel-width"}}
    for _, action in ipairs({"narrow_panel", "widen_panel"}) do
      local button = common.button(settings, action, action == "narrow_panel" and "−" or "+", nil, {"todo." .. action})
      button.style = "tool_button"
      button.style.size = {28, 28}
    end
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
