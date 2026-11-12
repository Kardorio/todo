local store = require("scripts.storage")
local tasks = require("scripts.task_manager")
local resolver = require("scripts.recipe_resolver")
local M = {}

function M.request(player, task)
  local target = task.production
  local prototype = target and resolver.prototype(target.type, target.name)
  if not prototype then return end
  local prefs = store.player(player.index)
  prefs.task_titles = prefs.task_titles or {}
  prefs.task_titles[player.request_translation(prototype.localised_name)] = {
    task_id = task.id, expected = task.title, kind = target.type, name = target.name, tick = game.tick
  }
end

local function current(pending)
  local task = tasks.get(pending.task_id)
  local target = task and task.production
  return task and task.title == pending.expected and target
    and target.type == pending.kind and target.name == pending.name and task
end

function M.translated(event)
  local prefs = store.get().players[event.player_index]
  local pending = prefs and prefs.task_titles and prefs.task_titles[event.id]
  if not pending then return end
  local task = current(pending)
  if not task then prefs.task_titles[event.id] = nil return end
  if event.translated and event.result ~= "" then
    prefs.task_titles[event.id] = nil
    tasks.update(task.id, {title = event.result}, task.revision)
    return true
  end
end

function M.retry(player)
  local pending = store.player(player.index).task_titles or {}
  local retries = {}
  for id, entry in pairs(pending) do
    local task = current(entry)
    if not task then pending[id] = nil
    elseif game.tick - entry.tick >= 180 then
      pending[id] = nil
      retries[#retries + 1] = task
    end
  end
  for _, task in ipairs(retries) do M.request(player, task) end
end

return M
