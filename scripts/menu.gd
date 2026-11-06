extends Control
## 场景选择页面：游戏启动后的入口。
##
## Half-Life 2 风格：暗色半透明控制台面板、琥珀色强调、方角、加大的字号。
## 场景列表在 SCENES 里维护；点击卡片或按 1/2/3/4 进入。

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
		"desc": "动态 Ellis · 平台/柱子 · 左键创建/删除",
		"path": "res://scenes/wormhole_map.tscn",
	},
	{
		"tag": "04",
		"title": "动态 Ellis 虫洞",
		"desc": "入口移动 · 周期性隐去 · 隐去时入口消失、空间平直",
		"path": "res://scenes/dynamic_ellis.tscn",
	},
]

const BG := Color(0.010, 0.013, 0.014)
const THROAT_R := 3.0

var _shot_path := ""
var _shot_frame := 24
var _frame := 0


func _ready() -> void:
	_build()
	_parse_shot_args()
	resized.connect(queue_redraw)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 84)
	margin.add_theme_constant_override("margin_right", 84)
	margin.add_theme_constant_override("margin_top", 58)
	margin.add_theme_constant_override("margin_bottom", 46)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(780, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)

	var kicker := Label.new()
	kicker.text = "GODOT 4 · 4D SDF ENGINE   /   SECTOR 04"
	kicker.add_theme_font_override("font", UIStyle.font())
	kicker.add_theme_font_size_override("font_size", 18)
	kicker.add_theme_color_override("font_color", UIStyle.AMBER)
	col.add_child(kicker)

	var title := Label.new()
	title.text = "4D 虫洞实验场"
	title.add_theme_font_override("font", UIStyle.font())
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", UIStyle.INK)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Ellis / Morris–Thorne 零潮汐力虫洞 · 光线沿测地线传播"
	sub.add_theme_font_override("font", UIStyle.font())
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", UIStyle.MUTED)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 32)
	col.add_child(gap)

	var shelf := VBoxContainer.new()
	shelf.add_theme_constant_override("separation", 11)
	col.add_child(shelf)

	for data in SCENES:
		shelf.add_child(_make_card(data))

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(flex)

	var foot := Label.new()
	foot.text = "点击场景进入   ·   数字键 1 / 2 / 3 / 4   ·   游戏中 M 或右上角按钮返回"
	foot.add_theme_font_override("font", UIStyle.font())
	foot.add_theme_font_size_override("font_size", 17)
	foot.add_theme_color_override("font_color", Color(0.44, 0.50, 0.52))
	col.add_child(foot)

	# 右侧留给 _draw() 的嵌入曲线
	var art := Control.new()
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)


func _make_card(data: Dictionary) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(780, 106)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", _card_style(false))
	b.add_theme_stylebox_override("hover", _card_style(true))
	b.add_theme_stylebox_override("pressed", _card_style(true, true))
	b.pressed.connect(_open.bind(String(data.path)))

	# HL2 面板左侧的琥珀色刻线
	var bar := ColorRect.new()
	bar.color = UIStyle.AMBER
	bar.anchor_bottom = 1.0
	bar.offset_right = 4.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bar)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 26)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	b.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)

	var tag := Label.new()
	tag.text = String(data.tag)
	tag.custom_minimum_size = Vector2(56, 0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_font_override("font", UIStyle.font())
	tag.add_theme_font_size_override("font_size", 26)
	tag.add_theme_color_override("font_color", UIStyle.AMBER)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tag)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)

	var title := Label.new()
	title.text = String(data.title)
	title.add_theme_font_override("font", UIStyle.font())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIStyle.INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var desc := Label.new()
	desc.text = String(data.desc)
	desc.add_theme_font_override("font", UIStyle.font())
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", UIStyle.MUTED)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)

	return b


func _card_style(hover: bool, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if pressed:
		s.bg_color = Color(0.10, 0.085, 0.055, 0.96)
	elif hover:
		s.bg_color = Color(0.065, 0.070, 0.070, 0.94)
	else:
		s.bg_color = Color(0.022, 0.028, 0.030, 0.88)
	s.border_color = UIStyle.AMBER_BRIGHT if (hover or pressed) else Color(0.24, 0.28, 0.29, 0.95)
	s.set_border_width_all(2 if (hover or pressed) else 1)
	s.set_corner_radius_all(0)
	return s


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1: _open(String(SCENES[0].path))
			KEY_2, KEY_KP_2: _open(String(SCENES[1].path))
			KEY_3, KEY_KP_3: _open(String(SCENES[2].path))
			KEY_4, KEY_KP_4: _open(String(SCENES[3].path))


# ---- 装饰: (w, ρ) 嵌入图里的悬链线 ρ = b₀·cosh(w/b₀) ----

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if size.x < 1100.0 or size.y < 560.0:
		return

	# 左侧控制台面板
	var px0 := 56.0
	var px1 := size.x * 0.565
	draw_rect(Rect2(px0, 34.0, px1 - px0, size.y - 68.0), Color(0.014, 0.018, 0.019, 0.66))
	draw_rect(Rect2(px1 - 2.0, 34.0, 2.0, size.y - 68.0), Color(0.92, 0.58, 0.18, 0.85))

	var x0 := size.x * 0.62
	var x1 := size.x * 0.955
	var y0 := size.y * 0.14
	var y1 := size.y * 0.86
	var w_span := 12.0
	var rho_max := 120.0

	var grid := Color(0.42, 0.33, 0.20, 0.14)
	for i in range(-12, 13, 3):
		var x := remap(float(i), -w_span, w_span, x0, x1)
		draw_line(Vector2(x, y0), Vector2(x, y1), grid, 1.0)
	for r in range(0, 121, 20):
		var y := remap(float(r), 0.0, rho_max, y1, y0)
		draw_line(Vector2(x0, y), Vector2(x1, y), grid, 1.0)

	var axis := Color(0.55, 0.42, 0.24, 0.45)
	draw_line(Vector2(x0, y1), Vector2(x1, y1), axis, 1.0)
	var xc := remap(0.0, -w_span, w_span, x0, x1)
	draw_line(Vector2(xc, y0), Vector2(xc, y1), axis, 1.0)

	var pts := PackedVector2Array()
	var n := 180
	for i in n + 1:
		var w := lerpf(-w_span, w_span, float(i) / float(n))
		var rho := THROAT_R * cosh(w / THROAT_R)
		if rho > rho_max:
			continue
		pts.append(Vector2(
			remap(w, -w_span, w_span, x0, x1),
			remap(rho, 0.0, rho_max, y1, y0)))
	if pts.size() > 1:
		draw_polyline(pts, Color(0.95, 0.60, 0.18, 0.05), 14.0, true)
		draw_polyline(pts, Color(0.98, 0.66, 0.22, 0.11), 7.0, true)
		draw_polyline(pts, Color(1.0, 0.76, 0.34, 0.92), 2.0, true)

	var yt := remap(THROAT_R, 0.0, rho_max, y1, y0)
	draw_circle(Vector2(xc, yt), 8.0, Color(1.0, 0.62, 0.20, 0.16))
	draw_circle(Vector2(xc, yt), 3.5, Color(1.0, 0.78, 0.38, 0.95))

	var font := UIStyle.font()
	draw_string(font, Vector2(xc + 16.0, yt - 12.0), "喉口",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIStyle.AMBER_BRIGHT)
	draw_string(font, Vector2(x1 - 18.0, y1 - 12.0), "w",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UIStyle.MUTED)
	draw_string(font, Vector2(xc + 12.0, y0 + 18.0), "ρ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UIStyle.MUTED)
	draw_string(font, Vector2(x0 + 8.0, y0 + 44.0), "ρ = b₀ · cosh(w / b₀)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.76, 0.34, 0.72))
	draw_string(font, Vector2(x1 - 150.0, size.y - 46.0), "BUILD 0.0.4",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.36, 0.41, 0.42))


# ---- 截图自检: --shot=<png> [--shot-frame=N] ----

func _parse_shot_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--shot-frame="):
			_shot_frame = int(a.substr(13))


func _process(_delta: float) -> void:
	if _shot_path == "":
		return
	_frame += 1
	if _frame >= _shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("SHOT_SAVED ", _shot_path)
		get_tree().quit()
