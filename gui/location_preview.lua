local common = require("gui.common")
local locations = require("scripts.location_manager")
local M = {}

function M.create(parent, name)
  local panel = parent.add{type = "frame", name = name, direction = "vertical", style = "inside_shallow_frame"}
  panel.style.padding = 12
  panel.add{type = "label", caption = {"todo.location-heading"}, style = "heading_2_label"}
  panel.add{type = "flow", name = "todo_view", direction = "vertical"}
  local label = panel.add{type = "label", name = "todo_location"}
  label.style.single_line = false
  label.style.maximal_width = 208
  for _, action in ipairs({"location_go", "location_current", "location_clear"}) do
    local button = common.button(panel, action, {"todo." .. action .. "-label"}, nil,
      {"todo." .. action:gsub("_", "-")})
    button.style.width = 208
  end
  return panel
end

function M.refresh(panel, tags, visible)
  panel.visible = visible
  local view = panel.todo_view
  local located = tags.position and tags.surface_index
  local valid = located and game.surfaces[tags.surface_index] ~= nil
  if visible and valid then
    local camera = view.todo_camera
    if not camera then
      view.clear()
      camera = view.add{type = "camera", name = "todo_camera", position = tags.position,
        surface_index = tags.surface_index, zoom = 0.5, tags = {todo_action = "location_go"},
        tooltip = {"todo.location-go"}}
      camera.style.size = {208, 180}
    else
      camera.surface_index = tags.surface_index
      camera.position = tags.position
    end
  else
    view.clear()
    if visible then
      local placeholder = view.add{type = "sprite", sprite = "utility/map"}
      placeholder.style.size = {64, 64}
      placeholder.style.margin = 24
    end
  end
  panel.todo_location.caption = locations.describe(tags)
  panel.todo_location_go.enabled = valid == true
  panel.todo_location_clear.enabled = located and true or false
end

return M
