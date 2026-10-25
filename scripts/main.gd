extends Node
## 四维空间 SDF 引擎 + 虫洞 —— 度规实现 (v19)
##
## 数学模型 (来自三个参考链接):
##   · 虫洞空间 = Morris–Thorne 零潮汐力度规 ds² = dl² + (l²+b₀²)dΩ²,
##     它在 4D 欧氏空间中有精确等距嵌入 (超悬链面):
##         P(u,θ,φ) = (b₀·u, b₀·cosh(u)·n̂(θ,φ))  ⇔  ρ = b₀·cosh(w/b₀)
##     喉口 = w=0 处半径 b₀ 的球; u>0 / u<0 = 两个宇宙。
##   · 观察者生活在这个弯曲的三维空间 (超曲面) 上: 位置每帧投影回曲面,
##     移动/视线都在切向 3-空间内。
##   · 光线 = 超曲面上的测地线 (约束积分器: 直线步进 → 投影回曲面 →
##     速度重新切向化)。弯曲来自度规 —— 喉口附近的星光多重像与
##     爱因斯坦环是真实结果, 没有任何特效。
##   · 穿越 = 飞过喉口 (纯飞行, 连续, 无传送)。
##
## 自动化截图:
##   godot --path . -- --shot=<png> [--shot-frame=N] [--shot-mode=0|1]
##        [--shot-pos=x,y,z,w] [--shot-yaw=deg] [--shot-pitch=deg] [--ss=1.5]

const THROAT_R := 3.0   # Morris–Thorne 喉半径 b₀

const MODE_NAMES := ["① 第一人称", "② 嵌入图 (w,ρ)"]

const HELP_TEXT := """V 嵌入图 (w,ρ) — Morris–Thorne 度规的 Flamm 型嵌入图 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标
你悬浮在 Ellis 虫洞 (零潮汐力 Morris–Thorne 度规) 的悬链面地板上空:
· 面前地板向喉口 (半径 3m 的球) 收窄, 穿过它就是另一个宇宙 (星空色温不同, 回头可返回)
· 光线沿弯曲空间的测地线传播: 喉口附近的星光多重像与爱因斯坦环是度规的真实结果
· 嵌入图 (V) 显示这条弯曲空间在 4D 欧氏空间中的等距嵌入 ρ = b₀·cosh(w/b₀)"""

# 相机状态: 4D 位置 + 4D 正交标架 (n_axis = 超曲面法线, 其余三个切向)
# 初始: 悬浮在宇宙B (w=+6) 的悬链面上空, 朝漏斗轴心 (−w) 看: 前方是喉口与宇宙A
var pos := Vector4(11.45, 0.0, 1.6, 6.0)
var n_axis := Vector4(1, 0, 0, 0)
var fwd := Vector4(0.0, 0.0, -0.12, -1.0)
var right := Vector4(0.0, 0.0, 1.0, 0.0)
var up := Vector4(0.0, 1.0, 0.0, 0.0)
var vel := Vector4.ZERO
var speed := 6.0
var mouse_sens := 0.0021
var rot_speed := 1.05
var view_mode := 0
var ss := 1.5
var captured := false
var time_s := 0.0

# ---- 截图自检 ----
var shot_path := ""
var shot_frame := 40
var shot_mode := -1
var shot_pos := Vector4.ZERO
var shot_pos_set := false
var shot_yaw := 0.0
var shot_pitch := 0.0
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
		pos = surf_project(shot_pos)
	else:
		pos = surf_project(pos)
	_init_frame()
	if shot_yaw != 0.0:
		_rot_pair(1, 2, shot_yaw)      # 正 = 向右转
	if shot_pitch != 0.0:
		_rot_pair(1, 3, shot_pitch)    # 正 = 抬头
	if shot_mode >= 0:
		view_mode = shot_mode
	if shot_ss > 0.0:
		ss = shot_ss
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "点击窗口捕获鼠标 → 面前是通向喉口的悬链面; 穿过喉口 = 到达另一个宇宙"


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
		_rot_pair(1, 2, event.relative.x * mouse_sens)    # 偏航: 右移右转
		_rot_pair(1, 3, -event.relative.y * mouse_sens)   # 俯仰: 下移下视
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


# ---- 超曲面 ρ = b₀·cosh(w/b₀) 的 GDScript 副本 ----

func surf_f(p: Vector4) -> float:
	return Vector3(p.x, p.y, p.z).length() - THROAT_R * cosh(p.w / THROAT_R)


func surf_grad(p: Vector4) -> Vector4:
	var rho := Vector3(p.x, p.y, p.z).length()
	var g3 := Vector3.ZERO
	if rho > 0.0001:
		g3 = Vector3(p.x, p.y, p.z) / rho
	return Vector4(g3.x, g3.y, g3.z, -sinh(p.w / THROAT_R))


func surf_project(p: Vector4) -> Vector4:
	for i in 3:
		var g := surf_grad(p)
		var f := surf_f(p)
		p -= g * f / maxf(g.dot(g), 0.000001)
	return p


func surf_normal(p: Vector4) -> Vector4:
	return surf_grad(p).normalized()


# ---- 悬链面地板 (θ=π/2 截面) ----

func cat_sdf(p: Vector4) -> float:
	var rho_xy := Vector2(p.x, p.y).length()
	var dr := rho_xy - THROAT_R * cosh(p.w / THROAT_R)
	return signf(p.z) * sqrt(p.z * p.z + dr * dr)


func cat_normal(p: Vector4) -> Vector4:
	var e := 0.01
	return Vector4(
		cat_sdf(p + Vector4(e, 0, 0, 0)) - cat_sdf(p - Vector4(e, 0, 0, 0)),
		cat_sdf(p + Vector4(0, e, 0, 0)) - cat_sdf(p - Vector4(0, e, 0, 0)),
		cat_sdf(p + Vector4(0, 0, e, 0)) - cat_sdf(p - Vector4(0, 0, e, 0)),
		cat_sdf(p + Vector4(0, 0, 0, e)) - cat_sdf(p - Vector4(0, 0, 0, e))
	).normalized()


## 标架维持: n_axis 对齐曲面法线, 其余三轴施密特正交化 (保持 fwd 方向)
func _make_ortho() -> void:
	n_axis = surf_normal(pos)
	fwd -= n_axis * fwd.dot(n_axis)
	right -= n_axis * right.dot(n_axis) + fwd * right.dot(fwd)
	up -= n_axis * up.dot(n_axis) + fwd * up.dot(fwd) + right * up.dot(right)
	fwd = fwd.normalized()
	right = right.normalized()
	up = up.normalized()


## 标架初始化: fwd = 指向喉口; up = 悬链面地板法向 (头顶方向);
## right = fwd × up (右手系, 保证画面不镜像)
func _init_frame() -> void:
	n_axis = surf_normal(pos)
	fwd = Vector4.ZERO - pos
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


## 在 (frame[i], frame[j]) 平面内旋转 (0=n 1=fwd 2=right 3=up)
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

	# ---- 翻滚 (right, up) ----
	if Input.is_key_pressed(KEY_Q):
		_rot_pair(2, 3, rot_speed * delta)
	if Input.is_key_pressed(KEY_E):
		_rot_pair(2, 3, -rot_speed * delta)

	# ---- 切向 3-空间移动 ----
	var dir := Vector4.ZERO
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
	var target := dir.normalized() * speed if dir.length_squared() > 0.000001 else Vector4.ZERO
	vel = vel.lerp(target, 1.0 - exp(-8.0 * delta))
	var prev := pos
	pos += vel * delta

	# ---- 地板碰撞: 悬链面地板之上 (cat_sdf ≥ 0.35) ----
	var dcat := cat_sdf(pos)
	if dcat < 0.35:
		var cn := cat_normal(pos)
		pos += cn * (0.35 - dcat)
		# 去掉向下的速度分量
		var vdown := vel.dot(-cn)
		if vdown > 0.0:
			vel += cn * vdown

	# ---- 约束在超曲面上, 标架跟随曲面 ----
	pos = surf_project(pos)
	var _unused_prev := prev
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


func _update_hud(delta: float) -> void:
	coord_label.text = "[color=#ff8a80]X[/color] %+.1f    [color=#7ee787]Y[/color] %+.1f    [color=#79c0ff]Z[/color] %+.1f    [color=#d2a8ff]W[/color] %+.1f" % [
		pos.x, pos.y, pos.z, pos.w]
	var u := pos.w / THROAT_R
	var uni := "宇宙B (暖)" if pos.w > 0.0 else "宇宙A (冷)"
	pos_label.text = "[%s]  u %+.2f   w %7.1f   ρ %6.1f   %s   速度 %.1f   SS %.1fx" % [
		MODE_NAMES[view_mode], u, pos.w, Vector3(pos.x, pos.y, pos.z).length(), uni, speed, ss]
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


func _flash(msg: String) -> void:
	toast.text = msg
	toast.modulate.a = 1.5
