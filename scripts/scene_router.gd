extends CanvasLayer
## 常驻的场景导航：右上角"场景选择"按钮 + M 快捷键。
## Half-Life 2 风格：暗色面板、琥珀色边框、放大字号。
## 启动菜单本身不显示按钮；截图模式 (--shot=) 下自动隐藏。

const MENU_SCENE := "res://scenes/menu.tscn"

var _btn: Button
var _shot_mode := false


func _ready() -> void:
	layer = 128
	_shot_mode = _has_arg("--shot=") and not _has_arg("--chrome")

	_btn = Button.new()
	_btn.text = "场景选择   (M)"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.anchor_left = 1.0
	_btn.anchor_right = 1.0
	_btn.offset_left = -222.0
	_btn.offset_right = -18.0
	_btn.offset_top = 14.0
	_btn.offset_bottom = 62.0
	_btn.add_theme_font_override("font", UIStyle.font())
	_btn.add_theme_font_size_override("font_size", 19)
	_btn.add_theme_color_override("font_color", UIStyle.AMBER)
	_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_btn.add_theme_color_override("font_pressed_color", UIStyle.AMBER_BRIGHT)
	_btn.add_theme_stylebox_override("normal",
		UIStyle.panel(Color(0.015, 0.020, 0.022, 0.88), Color(0.72, 0.45, 0.15, 0.9), 2, false, 16, 8))
	_btn.add_theme_stylebox_override("hover",
		UIStyle.panel(Color(0.12, 0.085, 0.035, 0.95), UIStyle.AMBER_BRIGHT, 2, false, 16, 8))
	_btn.add_theme_stylebox_override("pressed",
		UIStyle.panel(Color(0.20, 0.13, 0.045, 0.98), UIStyle.AMBER_BRIGHT, 2, false, 16, 8))
	_btn.pressed.connect(_to_menu)
	_btn.visible = false
	add_child(_btn)


func _process(_delta: float) -> void:
	var cur := get_tree().current_scene
	_btn.visible = not _shot_mode and cur != null and cur.scene_file_path != MENU_SCENE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_to_menu()


func _to_menu() -> void:
	var cur := get_tree().current_scene
	if cur != null and cur.scene_file_path == MENU_SCENE:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


func _has_arg(prefix: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return true
	return false
