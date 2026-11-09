local M = {}

function M.capture(player)
  return {
    position = {x = player.position.x, y = player.position.y},
    surface_index = player.surface.index
  }
end

function M.describe(task)
  if not task.position or not task.surface_index then return {"todo.no-location"} end
  local surface = game.surfaces[task.surface_index]
  return {"todo.location", surface and surface.name or {"todo.missing-surface"},
    string.format("%.1f", task.position.x), string.format("%.1f", task.position.y)}
end

function M.navigate(player, task)
  if not task.position or not task.surface_index then return nil, "no_location" end
  local surface = game.surfaces[task.surface_index]
  if not surface then return nil, "missing_surface" end
  local ok = pcall(function()
    player.set_controller{
      type = defines.controllers.remote, position = task.position, surface = surface
    }
  end)
  if not ok or player.controller_type ~= defines.controllers.remote
      or player.surface.index ~= surface.index
      or math.abs(player.position.x - task.position.x) > 1 / 256
      or math.abs(player.position.y - task.position.y) > 1 / 256 then return nil, "navigation_unavailable" end
  return true
end

return M
