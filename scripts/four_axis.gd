class_name FourDAxis
extends Control
## 左下角的四维坐标系 HUD（无背景，直接叠在画面上）：
## 用玩家当前的四维标架投影世界 x/y/z/w 轴，显示朝向；
## 右侧列出绝对坐标 (x, y, z, w)，显示位置。

const BLUE := Color(0.35, 0.72, 0.93)
const ORANGE := Color(0.97, 0.60, 0.20)
const INK := Color(0.91, 0.94, 0.93)
const MUTED := Color(0.62, 0.69, 0.71)
const WHITE_AXIS := Color(0.82, 0.92, 1.0)
const Y_AXIS := Color(0.72, 0.86, 0.70)

var font: Font
var _pos := Vector4.ZERO
var _right := Vector4(1, 0, 0, 0)
var _up := Vector4(0, 1, 0, 0)
var _n := Vector4(0, 0, 0, 1)


func set_frame(p: Vector4, _fwd: Vector4, r: Vector4, u: Vector4, n: Vector4) -> void:
	_pos = p
	_right = r
	_up = u
	_n = n
	queue_redraw()


## 4D 轴 → 屏幕方向。x/y/z 由相机切向标架决定；
## w 轴只能通过超曲面法线 n 的 w 分量露出来，所以额外加一条斜向分量。
func _project(axis: Vector4) -> Vector2:
	var sx := axis.dot(_right) + 0.42 * axis.dot(_n)
	var sy := -(axis.dot(_up) + 0.30 * axis.dot(_n))
	return Vector2(sx, sy)


## 无背景时用一层黑字影保证在亮地板和红房间上都可读。
func _txt(f: Font, p: Vector2, s: String, sz: int, col: Color) -> void:
	draw_string(f, p + Vector2(1.5, 1.5), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.80))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw() -> void:
	var f := font if font != null else ThemeDB.fallback_font

	_txt(f, Vector2(12, 21), "4D FRAME", 14, BLUE)
	_txt(f, Vector2(12, 38), "位置 / 朝向", 12, MUTED)

	var c := Vector2(78, 118)
	var scale := 44.0
	draw_circle(c, 52.0, Color(0.35, 0.72, 0.93, 0.04))
	draw_arc(c, 52.0, 0.0, TAU, 48, Color(0.35, 0.72, 0.93, 0.22), 1.0)

	var axes := [
		[Vector4(1, 0, 0, 0), ORANGE, "X"],
		[Vector4(0, 1, 0, 0), Y_AXIS, "Y"],
		[Vector4(0, 0, 1, 0), BLUE, "Z"],
		[Vector4(0, 0, 0, 1), WHITE_AXIS, "W"],
	]
	for a in axes:
		var axis: Vector4 = a[0]
		var col: Color = a[1]
		var axis_name: String = a[2]
		var d := _project(axis)
		var ln := clampf(d.length(), 0.0, 1.0)
		if ln < 0.05:
			continue
		d = d.normalized()
		var tip := c + d * (scale * ln)
		draw_line(c, tip, Color(0, 0, 0, 0.65), 4.0, true)
		draw_line(c, tip, col, 2.0, true)
		var side := Vector2(-d.y, d.x)
		draw_line(tip, tip - d * 8.0 + side * 4.0, col, 2.0)
		draw_line(tip, tip - d * 8.0 - side * 4.0, col, 2.0)
		_txt(f, tip + d * 10.0 + Vector2(-4, 4), axis_name, 13, col)

	# 坐标读数
	var x := 154.0
	_txt(f, Vector2(x, 38), "POSITION", 11, BLUE)
	var rows := [
		["X", _pos.x, ORANGE],
		["Y", _pos.y, Y_AXIS],
		["Z", _pos.z, BLUE],
		["W", _pos.w, WHITE_AXIS],
	]
	var y := 60.0
	for r in rows:
		_txt(f, Vector2(x, y), String(r[0]), 13, r[2])
		_txt(f, Vector2(x + 20, y), "%+.2f" % float(r[1]), 13, INK)
		y += 23.0
