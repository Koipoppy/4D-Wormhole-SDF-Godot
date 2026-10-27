extends Node
## v45 光滑双喉口：两个 Morris–Thorne 超悬链面喉口，共享同一个 B/C 宇宙对
## 每个喉口:  rho_i = R*cosh(w/R)  (i=1,2)
## 世界 = smin(F1,F2) = 0，其中 smin 是 C∞ 光滑最小值；不是 min 硬并集。
## 喉口附近权重饱和 -> 精确 Ellis 超悬链面；重叠区用宽度 κ 的光滑颈连接。
## 玩家/光线在这张 C∞ 超曲面上的测地线连续前进:
##   B -> 喉口1 -> C(天空) -> 喉口2 -> B。没有任何位置映射/传送。

const THROAT_R := 3.0
const BLEND_K := 0.35     # 光滑混合宽度 (m)
const C1 := Vector3(-5.0, 9.24, 0.0)
const C2 := Vector3(5.0, 9.24, 0.0)
const W0 := -6.0
const GREEN_C := Vector3(0.0, 9.24, 2.2)
const GREEN_R := 2.2
const MK1_C := Vector3(-8.6, 6.8, 0.8)
const MK2_C := Vector3(-7.0, 6.0, 0.8)
const MK_R := 0.55
const FLOOR_CLEAR := 0.35

const MODE_NAMES := ["① 第一人称", "② 嵌入图"]

const HELP_TEXT := """v45 光滑双喉口 | V 嵌入图 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标
两个喉口都是 Morris–Thorne 超悬链面 rho=R*cosh(w/R):
· 世界是两张超悬链面的 C∞ 光滑混合 smin(F1,F2)，不是 min 硬并集
· 从 B 飞进任一喉口 → 沿光滑颈到 C (天空) → 从另一个喉口回到 B
· 全程位置/法向连续, 没有映射/传送; 光线沿光滑超曲面测地线传播
· 入口旁: 绿色 4D 球 / 银色 4D 盒; 中间绿色球是参照物"""

var pos := Vector4(0.0, -11.0, 4.6, W0)
var n_axis := Vector4(1, 0, 0, 0)
var fwd := Vector4(0, 1, -0.2, 0)
var right := Vector4(1, 0, 0, 0)
var up := Vector4(0, 0, 1, 0)
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
@onready var coord_label: RichTextLabel = $UILayer/CoordLabel


func _ready() -> void:
	screen.texture = sub.get_texture()
	get_viewport().size_changed.connect(_apply_scale)
	_parse_shot_args()
	if shot_pos_set:
		pos = world_project(shot_pos)
	else:
		pos = world_project(pos)
	_init_frame()
	if shot_look_set:
		var d := shot_look - pos
		d -= n_axis * d.dot(n_axis)
		if d.length_squared() > 1e-6:
			fwd = d.normalized()
			up = cat_normal(pos)
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
	toast.text = "v45 光滑双喉口: 从任一球口飞进去, 沿光滑颈穿过 C 天空, 从另一口出来"


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


# ---- 0.0.2 超悬链面：两个喉口 ----
func f1(p: Vector4) -> float:
	return Vector3(p.x, p.y, p.z).distance_to(C1) - THROAT_R * cosh(p.w / THROAT_R)

func f2(p: Vector4) -> float:
	return Vector3(p.x, p.y, p.z).distance_to(C2) - THROAT_R * cosh(p.w / THROAT_R)

func g1(p: Vector4) -> Vector4:
	var v := Vector3(p.x, p.y, p.z) - C1
	v = v.normalized()
	return Vector4(v.x, v.y, v.z, -sinh(p.w / THROAT_R))

func g2(p: Vector4) -> Vector4:
	var v := Vector3(p.x, p.y, p.z) - C2
	v = v.normalized()
	return Vector4(v.x, v.y, v.z, -sinh(p.w / THROAT_R))


# ---- C∞ 光滑最小值 smin(F1,F2) ----
# smin(a,b;κ) = min(a,b) - κ log(1 + exp(-|a-b|/κ))
# 喉口附近一项权重饱和 -> 精确 Ellis 超悬链面；重叠区用宽度 κ 的光滑颈连接。
func _sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(clampf(x, -60.0, 60.0)))


func smin(a: float, b: float) -> float:
	var m := minf(a, b)
	var d := absf(a - b)
	return m - BLEND_K * log(1.0 + exp(-d / BLEND_K))


func smin_grad(p: Vector4) -> Vector4:
	var a := f1(p)
	var b := f2(p)
	# wa = 1/(1+exp((a-b)/κ))：a<b 时 wa≈1，a>b 时 wa≈0
	var wa := _sigmoid((a - b) / BLEND_K)
	return g1(p) * wa + g2(p) * (1.0 - wa)


func world_f(p: Vector4) -> float:
	return smin(f1(p), f2(p))


func world_grad(p: Vector4) -> Vector4:
	return smin_grad(p)


func world_project(p: Vector4) -> Vector4:
	for i in 4:
		var g := world_grad(p)
		p -= g * world_f(p) / maxf(g.dot(g), 1e-6)
	return p


func world_normal(p: Vector4) -> Vector4:
	return world_grad(p).normalized()


func cat_sdf_i(p: Vector4, c: Vector3) -> float:
	var rho_xy := Vector2(p.x - c.x, p.y - c.y).length()
	var dr := rho_xy - THROAT_R * cosh(p.w / THROAT_R)
	return signf(p.z) * sqrt(p.z * p.z + dr * dr)


func cat_sdf(p: Vector4) -> float:
	if p.w > 0.0:
		return 1e9   # C 侧是天空, 没有地板
	# 地板也用同一套光滑权重混合，避免接缝处地板法向跳变
	var wa := _sigmoid((f1(p) - f2(p)) / BLEND_K)
	return wa * cat_sdf_i(p, C1) + (1.0 - wa) * cat_sdf_i(p, C2)


func cat_normal(p: Vector4) -> Vector4:
	var e := 0.01
	return Vector4(
		cat_sdf(p + Vector4(e, 0, 0, 0)) - cat_sdf(p - Vector4(e, 0, 0, 0)),
		cat_sdf(p + Vector4(0, e, 0, 0)) - cat_sdf(p - Vector4(0, e, 0, 0)),
		cat_sdf(p + Vector4(0, 0, e, 0)) - cat_sdf(p - Vector4(0, 0, e, 0)),
		cat_sdf(p + Vector4(0, 0, 0, e)) - cat_sdf(p - Vector4(0, 0, 0, e))
	).normalized()


# ---- 标架 / 控制 ----
func _init_frame() -> void:
	n_axis = world_normal(pos)
	fwd = Vector4(0, 9.24, 1.8, W0) - pos
	fwd -= n_axis * fwd.dot(n_axis)
	fwd = fwd.normalized()
	up = cat_normal(pos)
	up -= n_axis * up.dot(n_axis)
	up -= fwd * up.dot(fwd)
	up = up.normalized()
	var r3 := Vector3(fwd.x, fwd.y, fwd.z).cross(Vector3(up.x, up.y, up.z))
	right = Vector4(r3.x, r3.y, r3.z, 0.0)
	right -= n_axis * right.dot(n_axis)
	right = right.normalized()


func _make_ortho() -> void:
	n_axis = world_normal(pos)
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
	var dcat := cat_sdf(pos)
	if dcat < FLOOR_CLEAR:
		var cn := cat_normal(pos)
		pos += cn * (FLOOR_CLEAR - dcat)
		var vd := vel.dot(-cn)
		if vd > 0.0:
			vel += cn * vd
	pos = world_project(pos)
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
	mat.set_shader_parameter("throat_r", THROAT_R)
	mat.set_shader_parameter("blend_k", BLEND_K)
	mat.set_shader_parameter("c1", C1)
	mat.set_shader_parameter("c2", C2)
	mat.set_shader_parameter("green_c", GREEN_C)
	mat.set_shader_parameter("green_r", GREEN_R)
	mat.set_shader_parameter("mk1_c", MK1_C)
	mat.set_shader_parameter("mk2_c", MK2_C)
	mat.set_shader_parameter("mk1_r", MK_R)
	mat.set_shader_parameter("mk2_r", MK_R)


func _update_hud(_delta: float) -> void:
	coord_label.text = "[color=#7ee787]X[/color] %+.1f  [color=#79c0ff]Y[/color] %+.1f  [color=#ffd166]Z[/color] %+.1f  [color=#d2a8ff]W[/color] %+.1f" % [pos.x, pos.y, pos.z, pos.w]
	pos_label.text = "v45 光滑双喉口 | w %+.1f | κ %.2f | 速度 %.1f | SS %.1fx" % [pos.w, BLEND_K, speed, ss]
	toast.modulate.a = maxf(toast.modulate.a - _delta * 0.5, 0.0)


func _maybe_screenshot() -> void:
	if shot_path == "": return
	frame_count += 1
	if frame_count >= shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT_SAVED ", shot_path)
		get_tree().quit()
