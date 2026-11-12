local common = require("gui.common")
local store = require("scripts.storage")
local panel = require("gui.compact_panel")
local M = {}

function M.close(player)
  local frame = player.gui.screen.todo_manager_settings
  if frame then frame.destroy() end
end

function M.open(player)
  M.close(player)
  local prefs = store.player(player.index)
  local frame = player.gui.screen.add{type = "frame", name = "todo_manager_settings", direction = "vertical"}
  local header = common.header(frame, {"todo.settings"})
  common.sprite(header, "close_settings", "close", nil, {"todo.close"})
  local body = frame.add{type = "frame", name = "todo_settings_body", direction = "vertical", style = "inside_shallow_frame"}
  body.style.padding = 16
  body.add{type = "checkbox", name = "todo_panel_visible", caption = {"todo.toggle-panel"}, state = prefs.panel_visible,
    tags = {todo_action = "settings_panel_visible"}}
  body.add{type = "label", caption = {"todo.panel-width"}, style = "heading_2_label"}
  local maximum = math.max(300, math.floor(player.display_resolution.width / player.display_scale - 48))
  local width = math.max(300, math.min(prefs.panel_width or 380, maximum))
  local slider = body.add{type = "slider", name = "todo_panel_width", minimum_value = 300, maximum_value = math.max(301, maximum),
    value = width, value_step = 1, tags = {todo_action = "settings_panel_width"}}
  slider.style.width = 300
  slider.enabled = maximum > 300
  body.add{type = "label", name = "todo_width_value", caption = tostring(width)}
  frame.auto_center = true
  player.opened = frame
end

function M.changed(player, element)
  local prefs = store.player(player.index)
  if element.tags.todo_action == "settings_panel_visible" then
    prefs.panel_visible = element.state
    panel.render(player)
  elseif element.tags.todo_action == "settings_panel_width" then
    local value = math.floor(element.slider_value)
    local maximum = math.max(300, math.floor(player.display_resolution.width / player.display_scale - 48))
    prefs.panel_width = math.max(300, math.min(value, maximum))
    panel.resized(player)
    element.parent.todo_width_value.caption = tostring(prefs.panel_width)
  end
end

return M
