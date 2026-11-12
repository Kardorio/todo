data:extend{{
  type = "custom-input",
  name = "todo-manager-add-target",
  key_sequence = "CONTROL + SHIFT + mouse-button-1",
  consuming = "game-only",
  include_selected_prototype = true
}, {
  type = "shortcut",
  name = "todo-manager-new-task",
  action = "lua",
  associated_control_input = "todo-manager-add-target",
  localised_name = {"todo.new"},
  icon = "__core__/graphics/icons/mip/list-view.png",
  icon_size = 32,
  small_icon = "__core__/graphics/icons/mip/list-view.png",
  small_icon_size = 32
}}
