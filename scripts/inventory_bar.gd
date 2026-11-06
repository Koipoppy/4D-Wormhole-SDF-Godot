class_name InventoryBar
extends Control
## 底部中央的五格拨轮物品栏：透明背景，只有槽位与图标。
## 滚轮 / 数字键 1-5 切换槽位；选中槽滑到中央，形成拨轮效果。
## 虫洞枪占第 1 格，其余四格预留给后续物品。

const BLUE := Color(0.35, 0.72, 0.93)
const ORANGE := Color(0.97, 0.60, 0.20)
const INK := Color(0.91, 0.94, 0.93)
const MUTED := Color(0.60, 0.67, 0.69)
const SELECT := Color(0.87, 0.89, 0.88)

const SLOT_COUNT := 5
const GUN_SLOT := 2
const STEP := 84.0
const SHOW_TIME := 1.8

var font: Font
var ui_scale := 1.0
var _selected := GUN_SLOT
var _offset := 0.0
var _target := 0.0
var _show_timer := 0.0


func _ready() -> void:
	set_process(true)
	modulate.a = 0.0
	if "--hotbar-show" in OS.get_cmdline_user_args():
		_show_timer = 999.0
		modulate.a = 1.0


func _process(delta: float) -> void:
	var target := (float(SLOT_COUNT - 1) * 0.5 - float(_selected)) * STEP * ui_scale
	if absf(_offset - target) > 0.05:
		_offset = lerpf(_offset, target, 1.0 - exp(-14.0 * delta))
		queue_redraw()
	elif _offset != target:
		_offset = target
		queue_redraw()

	if _show_timer > 0.0:
		_show_timer -= delta
	var target_a := 1.0 if _show_timer > 0.0 else 0.0
	if absf(modulate.a - target_a) > 0.005:
		modulate.a = lerpf(modulate.a, target_a, 1.0 - exp(-10.0 * delta))
	elif modulate.a != target_a:
		modulate.a = target_a


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Shift+滚轮 留给场景调速，普通滚轮切物品栏
		if event.shift_pressed:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select((_selected - 1 + SLOT_COUNT) % SLOT_COUNT)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select((_selected + 1) % SLOT_COUNT)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + SLOT_COUNT:
			_select(int(event.keycode - KEY_1))
			get_viewport().set_input_as_handled()


func _select(idx: int) -> void:
	_show_timer = SHOW_TIME
	if idx == _selected:
		queue_redraw()
		return
	_selected = idx
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var k := ui_scale
	var step := STEP * k

	# 先画未选中的槽，再画选中槽，保证选中槽压在最上层
	for pass_i in 2:
		for i in SLOT_COUNT:
			var sel := i == _selected
			if (pass_i == 0) == sel:
				continue
			var x := cx + (float(i) - (SLOT_COUNT - 1) * 0.5) * step + _offset
			var sz := (78.0 if sel else 62.0) * k
			var rect := Rect2(x - sz * 0.5, cy - sz * 0.5, sz, sz)
			if sel:
				draw_rect(rect, Color(SELECT.r, SELECT.g, SELECT.b, 0.10))
				draw_rect(rect, Color(SELECT.r, SELECT.g, SELECT.b, 0.95), false, maxf(1.0, 2.0 * k))
				draw_rect(Rect2(x - 20.0 * k, rect.position.y - 4.0 * k, 40.0 * k, 2.0 * k), BLUE)
			else:
				draw_rect(rect, Color(0.85, 0.88, 0.88, 0.58), false, maxf(1.0, 2.0 * k))

			if i == GUN_SLOT:
				_draw_gun(Vector2(x, cy), sz / 72.0)
			else:
				draw_circle(Vector2(x, cy), 2.2 * k, Color(0.85, 0.88, 0.88, 0.55))



func _draw_gun(c: Vector2, s: float) -> void:
	draw_set_transform(c - Vector2(36.0, 36.0) * s, 0.0, Vector2(s, s))
	var body := Color(0.86, 0.90, 0.89)
	var dark := Color(0.09, 0.11, 0.12)
	var grey := Color(0.58, 0.64, 0.65)

	var body_pts := PackedVector2Array([
		Vector2(9, 27), Vector2(41, 23), Vector2(47, 30),
		Vector2(41, 37), Vector2(9, 36),
	])
	draw_colored_polygon(body_pts, body)
	draw_rect(Rect2(46, 25, 13, 10), grey)
	draw_line(Vector2(59, 25), Vector2(64, 20), body, 2.0)
	draw_line(Vector2(59, 35), Vector2(64, 40), body, 2.0)
	var grip := PackedVector2Array([
		Vector2(15, 35), Vector2(24, 35), Vector2(20, 58), Vector2(10, 58),
	])
	draw_colored_polygon(grip, dark)
	draw_rect(Rect2(22, 28, 14, 3), dark)
	draw_circle(Vector2(61, 25), 2.6, BLUE)
	draw_circle(Vector2(61, 35), 2.6, ORANGE)
	draw_circle(Vector2(61, 25), 4.6, Color(BLUE.r, BLUE.g, BLUE.b, 0.18))
	draw_circle(Vector2(61, 35), 4.6, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
