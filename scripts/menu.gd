extends Control
## 场景选择页面：游戏启动后的入口。
##
## 场景列表在 SCENES 里维护；点击卡片或按 1/2/3 进入。
## 背景画的是 Ellis 虫洞的 (w, ρ) 嵌入曲线，纯装饰。

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
		"title": "薄壳动态虫洞",
		"desc": "可移动球口对 · 准静态动态度规",
		"path": "res://scenes/thinshell.tscn",
	},
	{
		"tag": "04",
		"title": "动态 Ellis 虫洞",
		"desc": "入口移动 · 周期性隐去 · 隐去时入口消失、空间平直",
		"path": "res://scenes/dynamic_ellis.tscn",
	},
]

const BG := Color(0.016, 0.02, 0.035)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.55, 0.62, 0.74)
const GOLD := Color(0.93, 0.75, 0.38)
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
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 52)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)

	var kicker := Label.new()
	kicker.text = "GODOT 4  ·  4D SDF ENGINE"
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", GOLD)
	col.add_child(kicker)

	var title := Label.new()
	title.text = "4D 虫洞实验场"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", INK)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Ellis / Morris–Thorne 零潮汐力虫洞 · 光线沿测地线传播"
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", MUTED)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	col.add_child(gap)

	var shelf := VBoxContainer.new()
	shelf.add_theme_constant_override("separation", 12)
	col.add_child(shelf)

	for data in SCENES:
		shelf.add_child(_make_card(data))

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(flex)

	var foot := Label.new()
	foot.text = "点击场景进入  ·  数字键 1 / 2 / 3 / 4 快捷选择  ·  游戏中 M 或右上角按钮返回"
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(0.42, 0.48, 0.6))
	col.add_child(foot)

	# 右侧留给 _draw() 的嵌入曲线
	var art := Control.new()
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)


func _make_card(data: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%s    %s\n         %s" % [data.tag, data.title, data.desc]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(640, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal",
		_card_style(Color(0.055, 0.07, 0.11, 0.92), Color(0.17, 0.24, 0.36, 0.8)))
	b.add_theme_stylebox_override("hover",
		_card_style(Color(0.10, 0.13, 0.20, 0.96), Color(0.93, 0.75, 0.38, 0.85)))
	b.add_theme_stylebox_override("pressed",
		_card_style(Color(0.08, 0.10, 0.16, 0.98), GOLD))
	b.pressed.connect(_open.bind(String(data.path)))
	return b


func _card_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
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
	var x0 := size.x * 0.60
	var x1 := size.x * 0.955
	var y0 := size.y * 0.14
	var y1 := size.y * 0.86
	var w_span := 12.0
	var rho_max := 120.0

	var grid := Color(0.22, 0.30, 0.44, 0.16)
	for i in range(-12, 13, 3):
		var x := remap(float(i), -w_span, w_span, x0, x1)
		draw_line(Vector2(x, y0), Vector2(x, y1), grid, 1.0)
	for r in range(0, 121, 20):
		var y := remap(float(r), 0.0, rho_max, y1, y0)
		draw_line(Vector2(x0, y), Vector2(x1, y), grid, 1.0)

	var axis := Color(0.40, 0.50, 0.66, 0.45)
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
		draw_polyline(pts, Color(0.93, 0.75, 0.38, 0.05), 12.0, true)
		draw_polyline(pts, Color(0.93, 0.75, 0.38, 0.10), 6.0, true)
		draw_polyline(pts, Color(0.95, 0.79, 0.44, 0.88), 2.0, true)

	var yt := remap(THROAT_R, 0.0, rho_max, y1, y0)
	draw_circle(Vector2(xc, yt), 7.0, Color(0.35, 0.75, 1.0, 0.16))
	draw_circle(Vector2(xc, yt), 3.5, Color(0.55, 0.86, 1.0, 0.95))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(xc + 14.0, yt - 10.0), "喉口",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.60, 0.85, 1.0, 0.85))
	draw_string(font, Vector2(x1 - 14.0, y1 - 12.0), "w",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
	draw_string(font, Vector2(xc + 10.0, y0 + 16.0), "ρ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
	draw_string(font, Vector2(x0 + 6.0, y0 + 42.0), "ρ = b₀ · cosh(w / b₀)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.93, 0.75, 0.38, 0.7))


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
