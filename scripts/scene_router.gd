extends CanvasLayer
## Portal 2 风格的暂停菜单（Esc / M 打开）。
## 场景选择已合并进来，不再有右上角按钮。
##
## 打开时释放鼠标并暂停场景；关闭时恢复原来的鼠标捕获状态。
## 场景选择按钮直接切场景并解除暂停。

const MENU_SCENE := "res://scenes/menu.tscn"

const SCENES := [
	{"tag": "01", "title": "双房间虫洞", "path": "res://scenes/main.tscn"},
	{"tag": "02", "title": "悬链面棋盘地板", "path": "res://scenes/floor_2dchecker.tscn"},
	{"tag": "03", "title": "虫洞沙盒", "path": "res://scenes/wormhole_map.tscn"},
	{"tag": "04", "title": "动态 Ellis 虫洞", "path": "res://scenes/dynamic_ellis.tscn"},
]

var _root: Control
var _rows: Array[Button] = []
var _open := false
var _was_captured := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	if "--pause-preview" in OS.get_cmdline_user_args():
		_root.visible = true
		_set_hud_visible(false)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.013, 0.016, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.offset_left = 64.0
	panel.offset_top = 78.0
	panel.offset_right = 632.0
	panel.offset_bottom = 78.0 + 596.0
	panel.add_theme_stylebox_override("panel",
		UIStyle.panel(Color(0.045, 0.056, 0.061, 0.95), UIStyle.EDGE, 1, true, 30, 24))
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var kicker := Label.new()
	kicker.text = "APERTURE SCIENCE   //   TEST TRACK 04"
	kicker.add_theme_font_override("font", UIStyle.font())
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", UIStyle.BLUE)
	v.add_child(kicker)

	var title := Label.new()
	title.text = "模拟暂停"
	title.add_theme_font_override("font", UIStyle.font())
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UIStyle.INK)
	v.add_child(title)

	var sub := Label.new()
	sub.text = "SIMULATION PAUSED"
	sub.add_theme_font_override("font", UIStyle.font())
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", UIStyle.MUTED)
	v.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)

	_add_row(v, "", "继续模拟", _resume)

	var section := Label.new()
	section.text = "场景选择"
	section.add_theme_font_override("font", UIStyle.font())
	section.add_theme_font_size_override("font_size", 14)
	section.add_theme_color_override("font_color", UIStyle.BLUE)
	section.custom_minimum_size = Vector2(0, 30)
	section.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(section)

	for data in SCENES:
		_add_row(v, String(data.tag), String(data.title),
			_open_scene.bind(String(data.path)))

	var flex := Control.new()
	flex.custom_minimum_size = Vector2(0, 10)
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(flex)

	_add_row(v, "", "回到主菜单", _to_menu)
	_add_row(v, "", "退出游戏", _quit)

	var hint := Label.new()
	hint.text = "ESC  继续      M  菜单"
	hint.add_theme_font_override("font", UIStyle.font())
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.52, 0.54))
	v.add_child(hint)

	if not _rows.is_empty():
		_select_row(_rows[0])


func _add_row(parent: Control, index: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UIStyle.row_style(false))
	b.add_theme_stylebox_override("hover", UIStyle.row_style(true))
	b.add_theme_stylebox_override("pressed", UIStyle.row_style(true))
	b.pressed.connect(action)
	parent.add_child(b)
	_rows.append(b)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 12)
	b.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)

	var idx: Label = null
	if index != "":
		idx = Label.new()
		idx.text = index
		idx.custom_minimum_size = Vector2(40, 0)
		idx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		idx.add_theme_font_override("font", UIStyle.font())
		idx.add_theme_font_size_override("font_size", 20)
		idx.add_theme_color_override("font_color", UIStyle.BLUE)
		idx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(idx)

	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_override("font", UIStyle.font())
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", UIStyle.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label)

	if idx != null:
		b.set_meta("idx_label", idx)
	b.set_meta("text_label", label)
	b.mouse_entered.connect(_select_row.bind(b))
	return b


## Portal 2 的选中行：浅灰亮条 + 深色字，同一时间只有一行被选中。
func _select_row(b: Button) -> void:
	for r in _rows:
		var on: bool = r == b
		r.add_theme_stylebox_override("normal", UIStyle.row_style(on))
		var idx: Label = r.get_meta("idx_label") if r.has_meta("idx_label") else null
		var label: Label = r.get_meta("text_label")
		if idx != null:
			idx.add_theme_color_override("font_color",
				UIStyle.SELECT_TEXT if on else UIStyle.BLUE)
		label.add_theme_color_override("font_color",
			UIStyle.SELECT_TEXT if on else UIStyle.INK)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE and event.keycode != KEY_M:
		return
	if _is_menu_scene():
		return
	_toggle()
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _open:
		_resume()
	else:
		_pause()


func _pause() -> void:
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var cur := get_tree().current_scene
	if cur != null and cur.has_method("_set_captured"):
		cur._set_captured(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	_root.visible = true
	_set_hud_visible(false)
	get_tree().paused = true


func _resume() -> void:
	_root.visible = false
	_open = false
	get_tree().paused = false
	_set_hud_visible(true)
	if _was_captured:
		var cur := get_tree().current_scene
		if cur != null and cur.has_method("_set_captured"):
			cur._set_captured(true)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_scene(path: String) -> void:
	_leave_menu()
	get_tree().change_scene_to_file(path)


func _to_menu() -> void:
	_leave_menu()
	get_tree().change_scene_to_file(MENU_SCENE)


func _leave_menu() -> void:
	_root.visible = false
	_open = false
	get_tree().paused = false
	_set_hud_visible(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_hud_visible(on: bool) -> void:
	var cur := get_tree().current_scene
	if cur == null:
		return
	var ui := cur.get_node_or_null("UILayer")
	if ui != null:
		ui.visible = on


func _quit() -> void:
	get_tree().quit()


func _is_menu_scene() -> bool:
	var cur := get_tree().current_scene
	return cur != null and cur.scene_file_path == MENU_SCENE
