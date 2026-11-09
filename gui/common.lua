local M = {}
local preserving = {}

function M.is_preserving(index)
  return preserving[index] == true
end

function M.preserve_window(player, action)
  local frame
  for _, name in ipairs({"todo_manager_window", "todo_manager_editor"}) do
    local candidate = player.gui.screen[name]
    if candidate and player.opened == candidate then frame = candidate break end
  end
  if not frame then return action() end
  local previous = preserving[player.index]
  preserving[player.index] = true
  local ok, result, err = pcall(function()
    local value, reason = action()
    if frame.valid then player.opened = frame end
    return value, reason
  end)
  preserving[player.index] = previous
  if not ok then error(result) end
  return result, err
end

function M.tags(action, id)
  return {todo_action = action, task_id = id}
end

function M.button(parent, action, caption, id, tooltip)
  return parent.add{type = "button", name = "todo_" .. action, caption = caption,
    tooltip = tooltip, tags = M.tags(action, id)}
end

function M.sprite(parent, action, sprite, id, tooltip)
  local button = parent.add{type = "sprite-button", name = "todo_" .. action,
    sprite = sprite:find("/") and sprite or "utility/" .. sprite, style = "tool_button", tooltip = tooltip,
    tags = M.tags(action, id)}
  button.style.size = {28, 28}
  return button
end

function M.header(frame, caption)
  local header = frame.add{type = "flow", direction = "horizontal"}
  header.add{type = "label", caption = caption, style = "frame_title"}
  local dragger = header.add{type = "empty-widget", style = "draggable_space_header"}
  dragger.style.horizontally_stretchable = true
  dragger.style.height = 24
  dragger.drag_target = frame
  return header
end

function M.owns(element)
  while element and element.valid do
    if element.name == "todo_manager_window" or element.name == "todo_manager_panel"
      or element.name == "todo_manager_editor"
      or element.name == "todo_manager_open" or element.name == "todo_manager_toggle_panel" then
      return true
    end
    element = element.parent
  end
  return false
end

function M.clamp(player, location, width, height)
  local resolution, scale = player.display_resolution, player.display_scale
  return {
    x = math.max(0, math.min(location.x, resolution.width - width * scale)),
    y = math.max(0, math.min(location.y, resolution.height - height * scale))
  }
end

return M
