extends Node
## 4D volume-handle wormhole scene (v40)
## Two spherical sky cavities in the 3D room, connected by a real 3D throat
## volume that leaves the room through the 4th dimension w.
## The player/light travels through the volume continuously; no position mapping,
## no reflection transfer.
##
## Room: 3D hyperplane w = W0, floor z = 0.
## Cavities: 3D balls at A/B, radius BALL_R, interiors are sky.
## Throat: 3D tube around a centerline below the floor, with w(t) dipping into
##         the 4th dimension. Interior sky.
## Camera: flies in x/y/z; its w is slaved to the cavity/throat volume.

const W0 := -6.0
const BALL_A := Vector3(-5.0, 0.0, 0.0)
const BALL_B := Vector3(5.0, 0.0, 0.0)
const BALL_R := 3.0
const TUBE_H := 6.0
const TUBE_W := 8.0
const TUBE_R := 1.5
const GREEN_C := Vector3(0.0, 0.0, 2.2)
const GREEN_R := 2.2
const MK1_C := Vector3(-8.3, -2.4, 0.7)   # green 4D glome
const MK2_C := Vector3(-6.7, -2.4, 0.7)   # silver 4D tesseract
const MK_R := 0.55
const FLOOR_CLEAR := 0.35

const HELP_TEXT := """4D 体积手柄虫洞 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Esc 释放鼠标
地板上的两个球形空腔内部是天空; 它们由一条从第四维 w 绕过去的三维喉口体积连接。
· 飞进球口 → 进入天空空腔 → 沿喉口体积连续穿过 → 从另一球口出来
· 全程位置连续, 没有位置映射/反射/传送; w 随喉口几何连续变化
· 入口旁: 绿色 4D 球 (glome) 与银色 4D 盒 (tesseract); 中间绿色球是参照物"""

var pos := Vector3(0.0, -11.0, 4.6)
var fwd := Vector3(0.0, 1.0, -0.18)
var right := Vector3(1.0, 0.0, 0.0)
var up := Vector3(0.0, 0.0, 1.0)
var vel := Vector3.ZERO
var speed := 6.0
var mouse_sens := 0.0021
var ss := 1.5
var captured := false
var time_s := 0.0

var view_mode := 0
var shot_path := ""
var shot_frame := 40
var shot_pos := Vector3.ZERO
var shot_pos_set := false
var shot_look := Vector3.ZERO
var shot_look_set := false
var shot_ss := 0.0
var frame_count := 0

@onready var sub: SubViewport = $SubViewport
@onready var screen: TextureRect = $UILayer/Screen
@onready var mat: ShaderMaterial = $SubViewport/View.material
@onready var coord_label: RichTextLabel = $UILayer/CoordLabel
@onready var pos_label: Label = $UILayer/PosLabel
@onready var help_label: Label = $UILayer/HelpLabel
@onready var toast: Label = $UILayer/Toast


func _ready() -> void:
	screen.texture = sub.get_texture()
	get_viewport().size_changed.connect(_apply_scale)
	_parse_shot_args()
	if shot_pos_set:
		pos = shot_pos
	_init_frame()
	if shot_look_set:
		var d := shot_look - pos
		if d.length_squared() > 0.000001:
			fwd = d.normalized()
			right = fwd.cross(up)
			if right.length_squared() < 0.0001:
				right = fwd.cross(Vector3(1, 0, 0))
			right = right.normalized()
			up = right.cross(fwd).normalized()
	if shot_ss > 0.0:
		ss = shot_ss
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "飞进地板上的玻璃球口 → 穿过 4D 喉口体积 → 从另一口出来 (无传送)"


func _parse_shot_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-frame="):
			shot_frame = int(a.substr(13))
		elif a.begins_with("--shot-pos="):
			var parts := a.substr(11).split(",")
			if parts.size() >= 3:
				shot_pos = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
				shot_pos_set = true
		elif a.begins_with("--shot-look="):
			var lp := a.substr(12).split(",")
			if lp.size() >= 3:
				shot_look = Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
				shot_look_set = true
		elif a.begins_with("--ss="):
			shot_ss = float(a.substr(5))


func _apply_scale() -> void:
	var sz := get_viewport().get_visible_rect().size
	sub.size = Vector2i(maxi(int(sz.x * ss), 16), maxi(int(sz.y * ss), 16))
	mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not captured:
			_set_captured(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(speed * 1.18, 80.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(speed / 1.18, 1.0)
	elif event is InputEventMouseMotion and captured:
		_rotate(Vector3.UP, -event.relative.x * mouse_sens)
		_rotate(right, -event.relative.y * mouse_sens)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_captured(false)
		elif event.keycode == KEY_F:
			ss = 1.0 if ss >= 1.99 else (1.5 if ss < 1.49 else 2.0)
			_apply_scale()


func _set_captured(on: bool) -> void:
	captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _rotate(axis: Vector3, ang: float) -> void:
	if ang == 0.0:
		return
	fwd = fwd.rotated(axis, ang).normalized()
	right = right.rotated(axis, ang).normalized()
	up = up.rotated(axis, ang).normalized()


func _init_frame() -> void:
	fwd = (Vector3(0.0, 0.0, 1.6) - pos)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0, 1, 0)
	fwd = fwd.normalized()
	up = Vector3(0, 0, 1)
	right = fwd.cross(up)
	if right.length_squared() < 0.0001:
		right = Vector3(1, 0, 0)
	right = right.normalized()
	up = right.cross(fwd).normalized()


func _centerline(t: float) -> Vector3:
	return Vector3(lerpf(BALL_A.x, BALL_B.x, t), 0.0, -TUBE_H * sin(PI * t))


func _center_w(t: float) -> float:
	# 两端在 w=W0 处平缓, 中段才进入第四维, 保证球腔→喉口的 w 连续
	var a := smoothstep(0.15, 0.50, t)
	var b := smoothstep(0.50, 0.85, t)
	return W0 - TUBE_W * a * (1.0 - b)


## closest throat parameter t for a 3D point
func _throat_t(p: Vector3) -> float:
	var best := 0.0
	var best_d := 1e18
	for i in 33:
		var t := float(i) / 32.0
		var c := _centerline(t)
		var d := p.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = t
	return best


func _in_ball(p: Vector3) -> bool:
	return p.distance_to(BALL_A) <= BALL_R or p.distance_to(BALL_B) <= BALL_R


func _in_throat3(p: Vector3) -> bool:
	var t := _throat_t(p)
	return p.distance_to(_centerline(t)) <= TUBE_R


func _sky_inside(p: Vector3) -> bool:
	return _in_ball(p) or _in_throat3(p)


func _camera_w(p: Vector3) -> float:
	if _in_ball(p):
		return W0
	if _in_throat3(p):
		return _center_w(_throat_t(p))
	return W0


func _push_out_floor(p: Vector3) -> Vector3:
	if not _sky_inside(p) and p.z < FLOOR_CLEAR:
		p.z = FLOOR_CLEAR
	return p


func _process(delta: float) -> void:
	time_s += delta
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir += fwd
	if Input.is_key_pressed(KEY_S):
		dir -= fwd
	if Input.is_key_pressed(KEY_D):
		dir += right
	if Input.is_key_pressed(KEY_A):
		dir -= right
	if Input.is_key_pressed(KEY_SPACE):
		dir += up
	if Input.is_key_pressed(KEY_C):
		dir -= up
	var target := dir.normalized() * speed if dir.length_squared() > 0.000001 else Vector3.ZERO
	vel = vel.lerp(target, 1.0 - exp(-8.0 * delta))
	pos += vel * delta
	pos = _push_out_floor(pos)
	var w := _camera_w(pos)
	var p4 := Vector4(pos.x, pos.y, pos.z, w)
	_push_uniforms(p4)
	_update_hud(w)
	_maybe_screenshot()


func _push_uniforms(p4: Vector4) -> void:
	mat.set_shader_parameter("cam_pos", p4)
	mat.set_shader_parameter("cam_fwd", Vector4(fwd.x, fwd.y, fwd.z, 0.0))
	mat.set_shader_parameter("cam_right", Vector4(right.x, right.y, right.z, 0.0))
	mat.set_shader_parameter("cam_up", Vector4(up.x, up.y, up.z, 0.0))
	mat.set_shader_parameter("aspect", get_viewport().get_visible_rect().size.x / maxf(get_viewport().get_visible_rect().size.y, 1.0))
	mat.set_shader_parameter("time_s", time_s)
	mat.set_shader_parameter("ball_a", Vector4(BALL_A.x, BALL_A.y, BALL_A.z, W0))
	mat.set_shader_parameter("ball_b", Vector4(BALL_B.x, BALL_B.y, BALL_B.z, W0))
	mat.set_shader_parameter("ball_r", BALL_R)
	mat.set_shader_parameter("tube_h", TUBE_H)
	mat.set_shader_parameter("tube_w", TUBE_W)
	mat.set_shader_parameter("tube_r", TUBE_R)
	mat.set_shader_parameter("green_c", Vector4(GREEN_C.x, GREEN_C.y, GREEN_C.z, W0))
	mat.set_shader_parameter("green_r", GREEN_R)
	mat.set_shader_parameter("mk1_c", Vector4(MK1_C.x, MK1_C.y, MK1_C.z, W0))
	mat.set_shader_parameter("mk2_c", Vector4(MK2_C.x, MK2_C.y, MK2_C.z, W0))
	mat.set_shader_parameter("mk1_r", MK_R)
	mat.set_shader_parameter("mk2_r", MK_R)


func _update_hud(w: float) -> void:
	coord_label.text = "[color=#7ee787]X[/color] %+.1f  [color=#79c0ff]Y[/color] %+.1f  [color=#ffd166]Z[/color] %+.1f  [color=#d2a8ff]W[/color] %+.1f" % [pos.x, pos.y, pos.z, w]
	pos_label.text = "4D 体积手柄 | 口 A (%.0f,0) / 口 B (%.0f,0) | 速度 %.1f | SS %.1fx" % [BALL_A.x, BALL_B.x, speed, ss]


func _maybe_screenshot() -> void:
	if shot_path == "":
		return
	frame_count += 1
	if frame_count >= shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT_SAVED ", shot_path)
		get_tree().quit()
