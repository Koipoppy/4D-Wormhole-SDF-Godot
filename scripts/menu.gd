extends Control
## 场景选择页面：游戏启动后的入口。
##
## Portal 2 / Aperture 风格：白色 DIN 字、蓝色强调、选中行浅灰亮条。
## 背景直接复用 02「悬链面棋盘地板」的着色器（悬链面地板 + 双宇宙星空），
## 左侧压一层暗面板保证文字可读。场景列表在 SCENES 里维护。

const SCENES := [
	{
		"tag": "01",
		"title": "双房间虫洞",
		"desc": "Ellis 超曲面 · 红 / 蓝立方体房间 · 中心喉口",
		"path": "res://scenes/main.tscn",
	},
	{
		"tag": "02",
		"title": "悬链面棋盘地板",
		"desc": "4D-002 · 2D 棋盘地板 + 双宇宙星空",
		"path": "res://scenes/floor_2dchecker.tscn",
	},
	{
		"tag": "03",
		"title": "虫洞沙盒",
		"desc": "虫洞枪 + 经典/三重/莫比乌斯传送门 · 平台/柱子",
		"path": "res://scenes/wormhole_map.tscn",
	},
	{
		"tag": "04",
		"title": "动态 Ellis 虫洞",
		"desc": "入口移动 · 周期性隐去 · 隐去时入口消失、空间平直",
		"path": "res://scenes/dynamic_ellis.tscn",
	},
]

const FLOOR_SHADER := preload("res://shaders/floor_2dchecker.gdshader")
const THROAT_R := 3.0

var _shot_path := ""
var _shot_frame := 24
var _frame := 0
var _cards: Array[Button] = []
var _k := 1.0
var _bg_mat: ShaderMaterial
var _bg_time := 0.0
var _rebuild_queued := false


func _ready() -> void:
	_build()
	_parse_shot_args()
	resized.connect(_queue_rebuild)
	_update_bg_aspect()


func _build() -> void:
	_k = UIStyle.ui_scale(self)
	_make_background()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(round(84.0 * _k)))
	margin.add_theme_constant_override("margin_right", int(round(84.0 * _k)))
	margin.add_theme_constant_override("margin_top", int(round(58.0 * _k)))
	margin.add_theme_constant_override("margin_bottom", int(round(46.0 * _k)))
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(48.0 * _k)))
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(780.0 * _k, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(round(8.0 * _k)))
	row.add_child(col)

	var kicker := Label.new()
	kicker.text = "APERTURE SCIENCE   //   TEST TRACK 04"
	kicker.add_theme_font_override("font", UIStyle.font())
	kicker.add_theme_font_size_override("font_size", int(round(18.0 * _k)))
	kicker.add_theme_color_override("font_color", UIStyle.BLUE)
	col.add_child(kicker)

	var title := Label.new()
	title.text = "4D 虫洞实验场"
	title.add_theme_font_override("font", UIStyle.font())
	title.add_theme_font_size_override("font_size", int(round(66.0 * _k)))
	title.add_theme_color_override("font_color", UIStyle.INK)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Ellis / Morris–Thorne 零潮汐力虫洞 · 光线沿测地线传播"
	sub.add_theme_font_override("font", UIStyle.font())
	sub.add_theme_font_size_override("font_size", int(round(20.0 * _k)))
	sub.add_theme_color_override("font_color", UIStyle.MUTED)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30.0 * _k)
	col.add_child(gap)

	var shelf := VBoxContainer.new()
	shelf.add_theme_constant_override("separation", int(round(2.0 * _k)))
	col.add_child(shelf)

	for data in SCENES:
		var card := _make_card(data)
		_cards.append(card)
		shelf.add_child(card)

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(flex)

	var foot := Label.new()
	foot.text = "点击场景进入   ·   数字键 1 / 2 / 3 / 4   ·   游戏中 Esc 打开菜单"
	foot.add_theme_font_override("font", UIStyle.font())
	foot.add_theme_font_size_override("font_size", int(round(17.0 * _k)))
	foot.add_theme_color_override("font_color", Color(0.52, 0.58, 0.60))
	col.add_child(foot)

	# 右侧留空，让 02 的悬链面地板/星空露出来
	var art := Control.new()
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	if not _cards.is_empty():
		_select_card(_cards[0])


func _make_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = FLOOR_SHADER
	bg.material = _bg_mat
	add_child(bg)
	var cam := _bg_camera()
	_bg_mat.set_shader_parameter("cam_pos", cam.pos)
	_bg_mat.set_shader_parameter("cam_fwd", cam.fwd)
	_bg_mat.set_shader_parameter("cam_right", cam.right)
	_bg_mat.set_shader_parameter("cam_up", cam.up)
	_bg_mat.set_shader_parameter("view_mode", 0.0)
	_bg_mat.set_shader_parameter("throat_r", THROAT_R)
	_bg_mat.set_shader_parameter("time_s", 0.0)

	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.006, 0.010, 0.013, 0.44)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	# 左侧暗面板，保证白字可读
	var panel := ColorRect.new()
	panel.anchor_right = 0.565
	panel.anchor_bottom = 1.0
	panel.offset_left = 56.0 * _k
	panel.offset_top = 34.0 * _k
	panel.offset_right = 0.0
	panel.offset_bottom = -34.0 * _k
	panel.color = Color(0.008, 0.012, 0.014, 0.64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var line := ColorRect.new()
	line.anchor_left = 0.565
	line.anchor_right = 0.565
	line.anchor_bottom = 1.0
	line.offset_left = -2.0 * _k
	line.offset_top = 34.0 * _k
	line.offset_right = 0.0
	line.offset_bottom = -34.0 * _k
	line.color = Color(0.35, 0.72, 0.93, 0.55)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)


## 2D 棋盘地板场景的相机：悬链面上方看向喉口，再向左转一点，
## 让喉口落在右侧、左侧留给菜单文字。
func _bg_camera() -> Dictionary:
	var p := Vector4(11.45, 0.0, 1.6, 6.0)
	# 与 02 场景一致：先把相机投回 Ellis 超曲面
	for i in 3:
		var rr := Vector3(p.x, p.y, p.z).length()
		if rr < 1e-4:
			break
		var gg := Vector4(p.x / rr, p.y / rr, p.z / rr, -sinh(p.w / THROAT_R))
		var ff := rr - THROAT_R * cosh(p.w / THROAT_R)
		p -= gg * (ff / maxf(gg.dot(gg), 1e-6))
	var rho := Vector3(p.x, p.y, p.z).length()
	var n := Vector4(p.x / rho, p.y / rho, p.z / rho, -sinh(p.w / THROAT_R)).normalized()
	var f := -p
	f -= n * f.dot(n)
	f = f.normalized()
	var up := Vector4(0.0, 0.0, 1.0, 0.0)
	up -= n * up.dot(n)
	up -= f * up.dot(f)
	up = up.normalized()
	var r3 := Vector3(f.x, f.y, f.z).cross(Vector3(up.x, up.y, up.z))
	var right := Vector4(r3.x, r3.y, r3.z, 0.0)
	right -= n * right.dot(n)
	right = right.normalized()

	var yaw := -0.55
	var c := cos(yaw)
	var s := sin(yaw)
	var f2 := (f * c + right * s).normalized()
	var r2 := (-f * s + right * c).normalized()
	return {"pos": p, "fwd": f2, "right": r2, "up": up}


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


## 窗口被拖动/最大化后，按新的视口尺寸重建，避免 UI 比例缩水。
func _rebuild() -> void:
	_rebuild_queued = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_cards.clear()
	_bg_mat = null
	_build()
	_update_bg_aspect()


func _update_bg_aspect() -> void:
	if _bg_mat == null:
		return
	_bg_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


func _make_card(data: Dictionary) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(780.0 * _k, 100.0 * _k)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", UIStyle.row_style(false, false, _k))
	b.add_theme_stylebox_override("hover", UIStyle.row_style(true, false, _k))
	b.add_theme_stylebox_override("pressed", UIStyle.row_style(true, false, _k))
	b.pressed.connect(_open.bind(String(data.path)))

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(round(22.0 * _k)))
	m.add_theme_constant_override("margin_right", int(round(22.0 * _k)))
	m.add_theme_constant_override("margin_top", int(round(10.0 * _k)))
	m.add_theme_constant_override("margin_bottom", int(round(10.0 * _k)))
	b.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(24.0 * _k)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)

	var tag := Label.new()
	tag.text = String(data.tag)
	tag.custom_minimum_size = Vector2(54.0 * _k, 0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_font_override("font", UIStyle.font())
	tag.add_theme_font_size_override("font_size", int(round(26.0 * _k)))
	tag.add_theme_color_override("font_color", UIStyle.BLUE)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tag)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)

	var title := Label.new()
	title.text = String(data.title)
	title.add_theme_font_override("font", UIStyle.font())
	title.add_theme_font_size_override("font_size", int(round(28.0 * _k)))
	title.add_theme_color_override("font_color", UIStyle.INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var desc := Label.new()
	desc.text = String(data.desc)
	desc.add_theme_font_override("font", UIStyle.font())
	desc.add_theme_font_size_override("font_size", int(round(17.0 * _k)))
	desc.add_theme_color_override("font_color", UIStyle.MUTED)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)

	b.set_meta("tag_label", tag)
	b.set_meta("title_label", title)
	b.set_meta("desc_label", desc)
	b.mouse_entered.connect(_select_card.bind(b))
	return b


## Portal 2 的选中行：浅灰亮条 + 深色字。
func _select_card(b: Button) -> void:
	for c in _cards:
		var on: bool = c == b
		c.add_theme_stylebox_override("normal", UIStyle.row_style(on, false, _k))
		var tag: Label = c.get_meta("tag_label")
		var title: Label = c.get_meta("title_label")
		var desc: Label = c.get_meta("desc_label")
		tag.add_theme_color_override("font_color",
			UIStyle.SELECT_TEXT if on else UIStyle.BLUE)
		title.add_theme_color_override("font_color",
			UIStyle.SELECT_TEXT if on else UIStyle.INK)
		desc.add_theme_color_override("font_color",
			Color(0.24, 0.27, 0.28) if on else UIStyle.MUTED)


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1: _open(String(SCENES[0].path))
			KEY_2, KEY_KP_2: _open(String(SCENES[1].path))
			KEY_3, KEY_KP_3: _open(String(SCENES[2].path))
			KEY_4, KEY_KP_4: _open(String(SCENES[3].path))


# ---- 截图自检: --shot=<png> [--shot-frame=N] ----

func _parse_shot_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--shot-frame="):
			_shot_frame = int(a.substr(13))


func _process(delta: float) -> void:
	if _bg_mat != null:
		_bg_time += delta * 0.6
		_bg_mat.set_shader_parameter("time_s", _bg_time)
	if _shot_path == "":
		return
	_frame += 1
	if _frame >= _shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("SHOT_SAVED ", _shot_path)
		get_tree().quit()
