extends CanvasLayer
## 常驻的场景导航：右上角"场景选择"按钮 + M 快捷键。
## 启动菜单本身不显示按钮；截图模式 (--shot=) 下自动隐藏。

const MENU_SCENE := "res://scenes/menu.tscn"

var _btn: Button
var _shot_mode := false


func _ready() -> void:
	layer = 128
	_shot_mode = _has_arg("--shot=") and not _has_arg("--chrome")

	_btn = Button.new()
	_btn.text = "场景选择  (M)"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.anchor_left = 1.0
	_btn.anchor_right = 1.0
	_btn.offset_left = -152.0
	_btn.offset_right = -16.0
	_btn.offset_top = 12.0
	_btn.offset_bottom = 46.0
	_btn.add_theme_font_size_override("font_size", 15)
	_btn.add_theme_color_override("font_color", Color(0.82, 0.88, 0.97))
	_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_btn.add_theme_stylebox_override("normal",
		_chip(Color(0.03, 0.045, 0.08, 0.72), Color(0.30, 0.40, 0.58, 0.55)))
	_btn.add_theme_stylebox_override("hover",
		_chip(Color(0.10, 0.14, 0.22, 0.90), Color(0.93, 0.75, 0.38, 0.80)))
	_btn.add_theme_stylebox_override("pressed",
		_chip(Color(0.06, 0.09, 0.14, 0.95), Color(0.93, 0.75, 0.38, 1.0)))
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


func _chip(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	return s


func _has_arg(prefix: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return true
	return false
