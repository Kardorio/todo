local resolver = require("scripts.recipe_resolver")
local M = {}

function M.target(selected)
  if not selected then return nil, nil, "no_hovered_target" end
  if type(selected.name) ~= "string" or selected.name == "" then return nil, nil, "missing_prototype" end
  local kind, name = selected.base_type, selected.name
  if kind == "entity" then
    local entity = prototypes.entity[name]
    if not entity then return nil, nil, "missing_prototype" end
    local items = entity.items_to_place_this or {}
    if #items > 1 then return nil, nil, "ambiguous_hovered_entity" end
    if #items == 1 then kind, name = "item", items[1].name end
  end
  if kind ~= "item" and kind ~= "fluid" and kind ~= "recipe" then
    return nil, nil, "unsupported_hovered_target"
  end
  if not resolver.prototype(kind, name) then return nil, nil, "missing_prototype" end
  return kind, name
end

function M.open(player, task)
  local value = task and task.production
  local target = value and resolver.prototype(value.type, value.name)
  if not target then return false end
  player.open_factoriopedia_gui(target)
  return true
end

return M
