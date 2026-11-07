extends CanvasLayer
## Portal 2 风格的暂停菜单（Esc / M 打开）。
## 场景选择已合并进来，不再有右上角按钮。
##
## 打开时释放鼠标并暂停场景；关闭时恢复原来的鼠标捕获状态。
## 场景选择按钮直接切场景并解除暂停。

const MENU_SCENE := "res://scenes/menu.tscn"

const SCENES := [
	{"title": "虫洞沙盒", "path": "res://scenes/wormhole_map.tscn"},
	{"title": "双房间虫洞", "path": "res://scenes/main.tscn"},
	{"title": "悬链面棋盘地板", "path": "res://scenes/floor_2dchecker.tscn"},
	{"title": "动态 Ellis 虫洞", "path": "res://scenes/dynamic_ellis.tscn"},
]

var _root: Control
var _rows: Array[Button] = []
var _k := 1.0
var _open := false
var _rebuild_queued := false
var _was_captured := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	get_viewport().size_changed.connect(_queue_rebuild)
	if "--pause-preview" in OS.get_cmdline_user_args():
		_root.visible = true
		# 场景的 HUD（四维仪表/物品栏）由 UIStyle 在场景 _ready 里创建，
		# 延后一帧再隐藏，截图预览才和真实暂停一致。
		call_deferred("_set_hud_visible", false)


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	_rebuild_queued = false
	var was_open := _open
	if _root != null:
		remove_child(_root)
		_root.queue_free()
	_rows.clear()
	_build()
	_root.visible = was_open
	if was_open:
		_set_hud_visible(false)


func _build() -> void:
	_k = UIStyle.ui_scale(self)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.013, 0.016, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0 * _k
	panel.offset_right = 300.0 * _k
	panel.offset_top = -290.0 * _k
	panel.offset_bottom = 290.0 * _k
	panel.add_theme_stylebox_override("panel",
		UIStyle.panel(Color(0.045, 0.056, 0.061, 0.84), UIStyle.EDGE,
			maxi(1, int(round(_k))), true, int(round(30.0 * _k)), int(round(24.0 * _k))))
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(2.0 * _k)))
	panel.add_child(v)

	var kicker := Label.new()
	kicker.text = "APERTURE SCIENCE   //   PORTAL TESTING"
	kicker.add_theme_font_override("font", UIStyle.font())
	kicker.add_theme_font_size_override("font_size", int(round(14.0 * _k)))
	kicker.add_theme_color_override("font_color", UIStyle.BLUE)
	v.add_child(kicker)

	var title := Label.new()
	title.text = "模拟暂停"
	title.add_theme_font_override("font", UIStyle.font())
	title.add_theme_font_size_override("font_size", int(round(42.0 * _k)))
	title.add_theme_color_override("font_color", UIStyle.INK)
	v.add_child(title)

	var sub := Label.new()
	sub.text = "SIMULATION PAUSED"
	sub.add_theme_font_override("font", UIStyle.font())
	sub.add_theme_font_size_override("font_size", int(round(14.0 * _k)))
	sub.add_theme_color_override("font_color", UIStyle.MUTED)
	v.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14.0 * _k)
	v.add_child(gap)

	_add_row(v, "", "继续模拟", _resume)

	var section := Label.new()
	section.text = "场景选择"
	section.add_theme_font_override("font", UIStyle.font())
	section.add_theme_font_size_override("font_size", int(round(14.0 * _k)))
	section.add_theme_color_override("font_color", UIStyle.BLUE)
	section.custom_minimum_size = Vector2(0, 30.0 * _k)
	section.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(section)

	for data in SCENES:
		_add_row(v, "", String(data.title),
			_open_scene.bind(String(data.path)))

	var flex := Control.new()
	flex.custom_minimum_size = Vector2(0, 10.0 * _k)
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(flex)

	_add_row(v, "", "回到主菜单", _to_menu)
	_add_row(v, "", "退出游戏", _quit)

	var hint := Label.new()
	hint.text = "ESC  继续      M  菜单"
	hint.add_theme_font_override("font", UIStyle.font())
	hint.add_theme_font_size_override("font_size", int(round(13.0 * _k)))
	hint.add_theme_color_override("font_color", Color(0.45, 0.52, 0.54))
	v.add_child(hint)

	if not _rows.is_empty():
		_select_row(_rows[0])


func _add_row(parent: Control, index: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50.0 * _k)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UIStyle.row_style(false, false, _k))
	b.add_theme_stylebox_override("hover", UIStyle.row_style(true, false, _k))
	b.add_theme_stylebox_override("pressed", UIStyle.row_style(true, false, _k))
	b.pressed.connect(action)
	parent.add_child(b)
	_rows.append(b)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(round(18.0 * _k)))
	m.add_theme_constant_override("margin_right", int(round(12.0 * _k)))
	b.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(18.0 * _k)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)

	var idx: Label = null
	if index != "":
		idx = Label.new()
		idx.text = index
		idx.custom_minimum_size = Vector2(40.0 * _k, 0)
		idx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		idx.add_theme_font_override("font", UIStyle.font())
		idx.add_theme_font_size_override("font_size", int(round(20.0 * _k)))
		idx.add_theme_color_override("font_color", UIStyle.BLUE)
		idx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(idx)

	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_override("font", UIStyle.font())
	label.add_theme_font_size_override("font_size", int(round(21.0 * _k)))
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
		r.add_theme_stylebox_override("normal", UIStyle.row_style(on, false, _k))
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
	if ui == null:
		return
	# 只隐藏 HUD 文字/仪表，保留 UILayer/Screen（游戏画面本身）。
	for name in ["CoordLabel", "PosLabel", "StatusGlass", "Toast", "FourDAxis", "InventoryBar"]:
		var c := ui.get_node_or_null(name)
		if c != null:
			c.visible = on


func _quit() -> void:
	get_tree().quit()


func _is_menu_scene() -> bool:
	var cur := get_tree().current_scene
	return cur != null and cur.scene_file_path == MENU_SCENE
