extends Node
## v50: same-space A<->B wormhole on ONE smooth profile surface.
##
## F(p) = |p_xyz| - f(p.w) = 0
## f(w) = R_L*exp(-((w-a)/s)^2) + R_L*exp(-((w+a)/s)^2)
##        + R_N*exp(-(w/sn)^2)
##
## One 3D surface of revolution around w: two lobes (the same space at two
## positions) + one neck. No spheres/tubes/unions/rims/rooms; the neck is the
## surface's own shape. The observer/lights live on this surface: enter lobe A,
## cross the neck, exit lobe B.

const R_LOBE := 2.6
const R_NECK := 1.1
const SIG_LOBE := 1.0
const SIG_NECK := 1.2
const A_W := 2.0
const W_MAX := 5.0

const HELP_TEXT := """v50 单一母线双叶曲面 | V 母线图 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标
世界 = |p_xyz| = f(w) 的一张光滑旋转曲面：两个叶瓣 + 一个颈部。
· 两个叶瓣是同一张曲面的两个位置；颈部是它们之间的连接
· 从叶瓣 A 进入 → 沿同一张曲面通过颈部 → 从叶瓣 B 出来
· 没有球/管/并集/rim；颈部就是母线自身的形状
· 全程位置连续，没有位置映射/传送"""

var pos := Vector4(0.0, 0.0, 0.0, -A_W)
var n_axis := Vector4(1, 0, 0, 0)
var fwd := Vector4(-1.0, 0.0, 0.0, 1.0)
var right := Vector4(0.0, 1.0, 0.0, 0.0)
var up := Vector4(0.0, 0.0, 1.0, 0.0)
var vel := Vector4.ZERO
var speed := 6.0
var mouse_sens := 0.0021
var rot_speed := 1.05
var view_mode := 0
var ss := 1.5
var captured := false
var time_s := 0.0

var shot_path := ""
var shot_frame := 40
var shot_mode := -1
var shot_pos := Vector4.ZERO
var shot_pos_set := false
var shot_yaw := 0.0
var shot_pitch := 0.0
var shot_look := Vector4.ZERO
var shot_look_set := false
var shot_ss := 0.0
var frame_count := 0

@onready var sub: SubViewport = $SubViewport
@onready var screen: TextureRect = $UILayer/Screen
@onready var mat: ShaderMaterial = $SubViewport/View.material
@onready var pos_label: Label = $UILayer/PosLabel
@onready var help_label: Label = $UILayer/HelpLabel
@onready var toast: Label = $UILayer/Toast


func profile(w: float) -> float:
	return R_LOBE * exp(-pow((w - A_W) / SIG_LOBE, 2.0)) \
		+ R_LOBE * exp(-pow((w + A_W) / SIG_LOBE, 2.0)) \
		+ R_NECK * exp(-pow(w / SIG_NECK, 2.0))


func profile_d(w: float) -> float:
	var e := 0.001
	return (profile(w + e) - profile(w - e)) / (2.0 * e)


func surf_f(p: Vector4) -> float:
	return Vector3(p.x, p.y, p.z).length() - profile(p.w)


func surf_grad(p: Vector4) -> Vector4:
	var rho := Vector3(p.x, p.y, p.z).length()
	var g3 := Vector3.ZERO
	if rho > 0.0001:
		g3 = Vector3(p.x, p.y, p.z) / rho
	return Vector4(g3.x, g3.y, g3.z, -profile_d(p.w))


func surf_project(p: Vector4) -> Vector4:
	for i in 4:
		var g := surf_grad(p)
		p -= g * surf_f(p) / maxf(g.dot(g), 1e-6)
	return p


func surf_normal(p: Vector4) -> Vector4:
	return surf_grad(p).normalized()


func _ready() -> void:
	screen.texture = sub.get_texture()
	get_viewport().size_changed.connect(_apply_scale)
	_parse_shot_args()
	# start on lobe A at a fixed angular direction (+x)
	pos = Vector4(profile(-A_W), 0.0, 0.0, -A_W)
	if shot_pos_set:
		pos = surf_project(shot_pos)
	else:
		pos = surf_project(pos)
	_init_frame()
	if shot_look_set:
		var d := shot_look - pos
		d -= n_axis * d.dot(n_axis)
		if d.length_squared() > 1e-6:
			fwd = d.normalized()
			up = Vector4(0, 0, 1, 0)
			up -= n_axis * up.dot(n_axis)
			up -= fwd * up.dot(fwd)
			up = up.normalized()
			var r3 := Vector3(fwd.x, fwd.y, fwd.z).cross(Vector3(up.x, up.y, up.z))
			right = Vector4(r3.x, r3.y, r3.z, 0.0)
			right -= n_axis * right.dot(n_axis)
			right = right.normalized()
	if shot_yaw != 0.0:
		_rot_pair(1, 2, shot_yaw)
	if shot_pitch != 0.0:
		_rot_pair(1, 3, shot_pitch)
	if shot_mode >= 0:
		view_mode = shot_mode
	if shot_ss > 0.0:
		ss = shot_ss
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "从叶瓣 A 进入 → 穿过同一张曲面的颈部 → 从叶瓣 B 出来 (无传送)"


func _parse_shot_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-frame="):
			shot_frame = int(a.substr(13))
		elif a.begins_with("--shot-mode="):
			shot_mode = int(a.substr(12))
		elif a.begins_with("--shot-pos="):
			var parts := a.substr(11).split(",")
			if parts.size() == 4:
				shot_pos = Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
				shot_pos_set = true
		elif a.begins_with("--shot-look="):
			var lp := a.substr(12).split(",")
			if lp.size() == 4:
				shot_look = Vector4(float(lp[0]), float(lp[1]), float(lp[2]), float(lp[3]))
				shot_look_set = true
		elif a.begins_with("--shot-yaw="):
			shot_yaw = deg_to_rad(float(a.substr(11)))
		elif a.begins_with("--shot-pitch="):
			shot_pitch = deg_to_rad(float(a.substr(13)))
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
		_rot_pair(1, 2, event.relative.x * mouse_sens)
		_rot_pair(1, 3, -event.relative.y * mouse_sens)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_captured(false)
		elif event.keycode == KEY_V:
			view_mode = (view_mode + 1) % 2
		elif event.keycode == KEY_F:
			ss = 1.0 if ss >= 1.99 else (1.5 if ss < 1.49 else 2.0)
			_apply_scale()


func _set_captured(on: bool) -> void:
	captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _init_frame() -> void:
	n_axis = surf_normal(pos)
	var neck := Vector4(profile(0.0), 0.0, 0.0, 0.0)
	fwd = neck - pos
	fwd -= n_axis * fwd.dot(n_axis)
	fwd = fwd.normalized()
	up = Vector4(0, 0, 1, 0)
	up -= n_axis * up.dot(n_axis)
	up -= fwd * up.dot(fwd)
	up = up.normalized()
	var r3 := Vector3(fwd.x, fwd.y, fwd.z).cross(Vector3(up.x, up.y, up.z))
	right = Vector4(r3.x, r3.y, r3.z, 0.0)
	right -= n_axis * right.dot(n_axis)
	right = right.normalized()


func _make_ortho() -> void:
	n_axis = surf_normal(pos)
	fwd -= n_axis * fwd.dot(n_axis)
	right -= n_axis * right.dot(n_axis) + fwd * right.dot(fwd)
	up -= n_axis * up.dot(n_axis) + fwd * up.dot(fwd) + right * up.dot(right)
	fwd = fwd.normalized()
	right = right.normalized()
	up = up.normalized()


func _rot_pair(i: int, j: int, ang: float) -> void:
	if ang == 0.0:
		return
	var vi := _frame_get(i)
	var vj := _frame_get(j)
	var c := cos(ang)
	var s := sin(ang)
	_frame_set(i, vi * c + vj * s)
	_frame_set(j, -vi * s + vj * c)


func _frame_get(i: int) -> Vector4:
	match i:
		0: return n_axis
		1: return fwd
		2: return right
		_: return up


func _frame_set(i: int, v: Vector4) -> void:
	match i:
		0: n_axis = v
		1: fwd = v
		2: right = v
		_: up = v


func _process(delta: float) -> void:
	time_s += delta
	if Input.is_key_pressed(KEY_Q):
		_rot_pair(2, 3, rot_speed * delta)
	if Input.is_key_pressed(KEY_E):
		_rot_pair(2, 3, -rot_speed * delta)

	var dir := Vector4.ZERO
	if Input.is_key_pressed(KEY_W): dir += fwd
	if Input.is_key_pressed(KEY_S): dir -= fwd
	if Input.is_key_pressed(KEY_D): dir += right
	if Input.is_key_pressed(KEY_A): dir -= right
	if Input.is_key_pressed(KEY_SPACE): dir += up
	if Input.is_key_pressed(KEY_C): dir -= up
	var target := dir.normalized() * speed if dir.length_squared() > 1e-6 else Vector4.ZERO
	vel = vel.lerp(target, 1.0 - exp(-8.0 * delta))
	pos += vel * delta
	pos = surf_project(pos)
	_make_ortho()
	_push_uniforms()
	_update_hud(delta)
	_maybe_screenshot()


func _push_uniforms() -> void:
	mat.set_shader_parameter("cam_pos", pos)
	mat.set_shader_parameter("cam_fwd", fwd)
	mat.set_shader_parameter("cam_right", right)
	mat.set_shader_parameter("cam_up", up)
	mat.set_shader_parameter("time_s", time_s)
	mat.set_shader_parameter("view_mode", float(view_mode))
	mat.set_shader_parameter("r_lobe", R_LOBE)
	mat.set_shader_parameter("r_neck", R_NECK)
	mat.set_shader_parameter("sig_lobe", SIG_LOBE)
	mat.set_shader_parameter("sig_neck", SIG_NECK)
	mat.set_shader_parameter("a_w", A_W)
	mat.set_shader_parameter("w_max", W_MAX)


func _update_hud(delta: float) -> void:
	var lobe := "叶瓣 A" if pos.w < 0.0 else "叶瓣 B"
	if absf(pos.w) < 0.6:
		lobe = "颈部"
	pos_label.text = "v50 单一母线双叶曲面 | %s | w %+.2f | ρ %.2f | 速度 %.1f | SS %.1fx" % [
		lobe, pos.w, Vector3(pos.x, pos.y, pos.z).length(), speed, ss]
	toast.modulate.a = maxf(toast.modulate.a - delta * 0.5, 0.0)


func _maybe_screenshot() -> void:
	if shot_path == "":
		return
	frame_count += 1
	if frame_count >= shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT_SAVED ", shot_path)
		get_tree().quit()
