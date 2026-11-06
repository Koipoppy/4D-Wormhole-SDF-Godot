class_name InventoryBar
extends Control
## 画面底部中央的物品栏：一个虫洞枪槽位。
## Portal 2 / Aperture 语言：暗色半透明面板、白色器械、蓝/橙两个发射口。

const BLUE := Color(0.35, 0.72, 0.93)
const ORANGE := Color(0.97, 0.60, 0.20)
const INK := Color(0.91, 0.94, 0.93)
const MUTED := Color(0.55, 0.62, 0.64)
const EDGE := Color(0.40, 0.46, 0.48, 0.9)

var font: Font


func _draw() -> void:
	var f := font if font != null else ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.018, 0.022, 0.80))
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 1.0)
	draw_rect(Rect2(0, 0, 3, size.y), BLUE)

	var sx := 12.0
	var sy := 10.0
	var slot := Rect2(sx, sy, 72, 72)
	draw_rect(slot, Color(0.03, 0.045, 0.05, 0.92))
	draw_rect(slot, Color(0.45, 0.55, 0.58, 0.85), false, 1.0)
	# 选中/就绪角标
	draw_line(Vector2(sx, sy), Vector2(sx + 12, sy), BLUE, 2.0)
	draw_line(Vector2(sx, sy), Vector2(sx, sy + 12), BLUE, 2.0)
	draw_string(f, Vector2(sx + 5, sy + 15), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	_draw_gun(sx, sy)
	draw_string(f, Vector2(sx + 5, sy + 66), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)

	draw_string(f, Vector2(100, 38), "虫洞枪", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_string(f, Vector2(100, 54), "WORMHOLE GUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	draw_string(f, Vector2(100, 76), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BLUE)
	draw_string(f, Vector2(size.x - 108, 54), "左键 发射", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)


func _draw_gun(sx: float, sy: float) -> void:
	var body := Color(0.86, 0.90, 0.89)
	var dark := Color(0.09, 0.11, 0.12)
	var grey := Color(0.58, 0.64, 0.65)

	# 白色主体
	var body_pts := PackedVector2Array([
		Vector2(sx + 9, sy + 27),
		Vector2(sx + 41, sy + 23),
		Vector2(sx + 47, sy + 30),
		Vector2(sx + 41, sy + 37),
		Vector2(sx + 9, sy + 36),
	])
	draw_colored_polygon(body_pts, body)
	# 枪口
	draw_rect(Rect2(sx + 46, sy + 25, 13, 10), grey)
	draw_line(Vector2(sx + 59, sy + 25), Vector2(sx + 64, sy + 20), body, 2.0)
	draw_line(Vector2(sx + 59, sy + 35), Vector2(sx + 64, sy + 40), body, 2.0)
	# 黑色握把
	var grip := PackedVector2Array([
		Vector2(sx + 15, sy + 35),
		Vector2(sx + 24, sy + 35),
		Vector2(sx + 20, sy + 58),
		Vector2(sx + 10, sy + 58),
	])
	draw_colored_polygon(grip, dark)
	# 黑色饰条
	draw_rect(Rect2(sx + 22, sy + 28, 14, 3), dark)
	# 蓝 / 橙发射口
	draw_circle(Vector2(sx + 61, sy + 25), 2.6, BLUE)
	draw_circle(Vector2(sx + 61, sy + 35), 2.6, ORANGE)
	draw_circle(Vector2(sx + 61, sy + 25), 4.6, Color(BLUE.r, BLUE.g, BLUE.b, 0.18))
	draw_circle(Vector2(sx + 61, sy + 35), 4.6, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.18))
