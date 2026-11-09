local common = require("gui.common")
local tree = require("gui.task_tree")
local store = require("scripts.storage")
local tasks = require("scripts.task_manager")
local M = {}

function M.render(player)
  local prefs = store.player(player.index)
  local frame = player.gui.screen.todo_manager_panel
  local has_pins = false
  for id, pinned in pairs(prefs.pinned) do
    if pinned and tasks.get(id) then has_pins = true break end
  end
  if not prefs.panel_visible or not has_pins then
    if frame then frame.destroy() end
    return
  end
  if not frame then
    frame = player.gui.screen.add{type = "frame", name = "todo_manager_panel", direction = "vertical"}
    local header = common.header(frame, {"todo.pinned"})
    common.sprite(header, "open", "expand_dots", nil, {"todo.open"})
    common.sprite(header, "toggle_panel", "close", nil, {"todo.hide-panel"})
    local list = frame.add{type = "scroll-pane", name = "todo_panel_tree", direction = "vertical"}
    list.style.width = 380
    list.style.maximal_height = math.max(150, math.min(400, player.display_resolution.height / player.display_scale - 230))
    frame.location = common.clamp(player, prefs.panel_location or {x = 12, y = 200}, 416, 460)
  end
  tree.render(frame.todo_panel_tree, player, true)
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
    prefs.panel_location = common.clamp(player, frame.location, 416, 460)
    frame.destroy()
  end
  M.render(player)
end

return M
