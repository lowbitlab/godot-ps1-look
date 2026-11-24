@tool
extends EditorPlugin
## Editor glue for Lowbit PS1 Look.
##
## The look itself lives in LowbitPS1Look (a plain node, usable without enabling this plugin).
## Enabling the plugin adds one entry to Project > Tools that drops a ready-made node into the open scene.

const MENU_TEXT := "Lowbit PS1 Look: add to open scene"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_TEXT, _add_to_open_scene)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TEXT)


func _add_to_open_scene() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("Lowbit PS1 Look: open a scene first.")
		return
	var existing := root.find_children("*", "LowbitPS1Look", true, true)
	if not existing.is_empty():
		push_warning("Lowbit PS1 Look: this scene already has one.")
		return
	var node := LowbitPS1Look.new()
	node.name = "PS1Look"
	node.settings = LowbitPS1Settings.new()
	var undo := get_undo_redo()
	undo.create_action("Add Lowbit PS1 Look")
	undo.add_do_method(root, "add_child", node, true)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(root, "remove_child", node)
	undo.commit_action()
