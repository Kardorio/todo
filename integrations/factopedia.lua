local resolver = require("scripts.recipe_resolver")
local M = {}

function M.open(player, task)
  local value = task and task.production
  local target = value and resolver.prototype(value.type, value.name)
  if not target then return false end
  player.open_factoriopedia_gui(target)
  return true
end

return M
