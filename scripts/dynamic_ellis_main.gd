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

const B0 := 3.0          # Morris–Thorne 喉半径 b₀
const VIS_PERIOD := 12.0 # 显隐周期 (s)
const VIS_HIDDEN := 0.0  # 完全隐去：b₀ = 0
const FLAT_EPS := 0.02   # b₀ 低于此值直接切换为平直平面 w=0
var b0 := B0             # 当前喉半径（保持 Ellis 几何）
var entrance_c := Vector3.ZERO   # 入口中心在房间中的位置
var motion := true       # 入口移动开关
var motion_t := 0.0
var vis := 1.0           # 当前可见度 (1 = 完整 Ellis, 0 = 完全平直)
var vis_enabled := true  # 显隐周期开关
var flat_side := 1.0     # 隐去时保留的房间颜色: 1 红 / 0 蓝
const DIAGRAM_LIFT := 8.0   # 嵌入图中虫洞相对方格平面的悬浮高度 (ρ 单位)
const ROOM_L := 18.0    # 立方体房间半边长
const ROOM_W := 6.0     # 房间中心 / 喉口所在 |w|

const MODE_NAMES := ["① 房间", "② 嵌入图 (w,ρ)"]

const HELP_TEXT := """动态 Ellis 虫洞 | V 嵌入图 (w,ρ) | F 超采样 | T 入口移动 | Y 显隐
鼠标 转身 | WASD 移动 | Space/C 升降 | Shift+滚轮 调速 | Q/E 翻滚 | Esc 菜单
你在一蓝一红两个立方体房间之一，房间中心的球体就是 Ellis 虫洞入口:
· 走进中心虫洞 → 穿过喉口 → 从另一个房间的中心出来（w>0 红 / w<0 蓝）
· 入口中心 C(t) 在房间里移动；虫洞周期性隐去：b₀→0，入口收缩、空间趋平直
· 光线的测地线与房间曲率随几何变化；V 嵌入图显示 (w,ρ) 剖面"""

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
var shot_time := -1.0
var frame_count := 0

@onready var sub: SubViewport = $SubViewport
@onready var screen: TextureRect = $UILayer/Screen
@onready var mat: ShaderMaterial = $SubViewport/View.material
var four_axis: FourDAxis
@onready var pos_label: Label = $UILayer/PosLabel
@onready var help_label: Label = $UILayer/HelpLabel
@onready var toast: Label = $UILayer/Toast


func _ready() -> void:
	four_axis = UIStyle.apply_hud(self)
	screen.texture = sub.get_texture()
	get_viewport().size_changed.connect(_apply_scale)
	_parse_shot_args()
	if shot_time >= 0.0:
		time_s = shot_time
		motion_t = shot_time
	entrance_c = _entrance_at(motion_t)
	if shot_pos_set:
		pos = surf_project(shot_pos)
	else:
		pos = surf_project(pos)
	# 初始视线朝入口中心 (房间内的 xyz 方向)；曲面变平时这个方向仍然有意义
	fwd = Vector4(entrance_c.x - pos.x, entrance_c.y - pos.y, entrance_c.z - pos.z, 0.0)
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
	toast.text = "入口 C(t) 移动；虫洞周期性隐去——入口收缩、空间趋平直"


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
		elif a.begins_with("--shot-time="):
			shot_time = float(a.substr(12))


func _apply_scale() -> void:
	var sz := get_viewport().get_visible_rect().size
	sub.size = Vector2i(maxi(int(sz.x * ss), 16), maxi(int(sz.y * ss), 16))
	mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not captured:
			_set_captured(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.shift_pressed:
			speed = minf(speed * 1.18, 80.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.shift_pressed:
			speed = maxf(speed / 1.18, 1.0)
	elif event is InputEventMouseMotion and captured:
		_rot_pair(1, 2, event.relative.x * mouse_sens)    # 偏航: 右移右转
		_rot_pair(1, 3, -event.relative.y * mouse_sens)   # 俯仰: 下移下视
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			view_mode = (view_mode + 1) % 2
		elif event.keycode == KEY_F:
			ss = 1.0 if ss >= 1.99 else (1.5 if ss < 1.49 else 2.0)
			_apply_scale()
		elif event.keycode == KEY_T:
			motion = not motion
			_flash("入口移动: %s" % ("开" if motion else "关"))
		elif event.keycode == KEY_Y:
			vis_enabled = not vis_enabled
			_flash("显隐周期: %s" % ("开" if vis_enabled else "关（保持完整 Ellis）"))


func _set_captured(on: bool) -> void:
	captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


# ---- 超曲面 ρ = b₀·cosh(w/b₀) 的 GDScript 副本 ----

func surf_f(p: Vector4) -> float:
	if b0 < FLAT_EPS:
		return p.w
	return Vector3(p.x - entrance_c.x, p.y - entrance_c.y, p.z - entrance_c.z).length() - b0 * cosh(p.w / b0)


func surf_grad(p: Vector4) -> Vector4:
	if b0 < FLAT_EPS:
		return Vector4(0.0, 0.0, 0.0, 1.0)
	var q := Vector3(p.x - entrance_c.x, p.y - entrance_c.y, p.z - entrance_c.z)
	var rho := q.length()
	var g3 := Vector3.ZERO
	if rho > 0.0001:
		g3 = q / rho
	return Vector4(g3.x, g3.y, g3.z, -sinh(p.w / b0))


func surf_project(p: Vector4) -> Vector4:
	if b0 < FLAT_EPS:
		p.w = 0.0
		return p
	for i in 3:
		var g := surf_grad(p)
		var f := surf_f(p)
		p -= g * f / maxf(g.dot(g), 0.000001)
	return p


func surf_normal(p: Vector4) -> Vector4:
	if b0 < FLAT_EPS:
		return Vector4(0.0, 0.0, 0.0, 1.0)
	return surf_grad(p).normalized()


# ---- 悬链面地板 (θ=π/2 截面) ----

func cat_sdf(p: Vector4) -> float:
	if b0 < FLAT_EPS:
		var zf := p.z - entrance_c.z
		return signf(zf) * absf(zf)
	var q := Vector3(p.x - entrance_c.x, p.y - entrance_c.y, p.z - entrance_c.z)
	var rho_xy := Vector2(q.x, q.y).length()
	var dr := rho_xy - b0 * cosh(p.w / b0)
	return signf(q.z) * sqrt(q.z * q.z + dr * dr)


func cat_normal(p: Vector4) -> Vector4:
	var e := 0.01
	return Vector4(
		cat_sdf(p + Vector4(e, 0, 0, 0)) - cat_sdf(p - Vector4(e, 0, 0, 0)),
		cat_sdf(p + Vector4(0, e, 0, 0)) - cat_sdf(p - Vector4(0, e, 0, 0)),
		cat_sdf(p + Vector4(0, 0, e, 0)) - cat_sdf(p - Vector4(0, 0, e, 0)),
		cat_sdf(p + Vector4(0, 0, 0, e)) - cat_sdf(p - Vector4(0, 0, 0, e))
	).normalized()


func _entrance_at(t: float) -> Vector3:
	return Vector3(
		5.0 * sin(t * 0.55),
		3.0 * sin(t * 0.37 + 1.0),
		0.0)


## 显隐周期: 4s 可见 → 2s 淡出 → 2s 隐去 → 2s 淡入 → 循环。
func _visibility_at(t: float) -> float:
	var cyc := fmod(t, VIS_PERIOD)
	if cyc < 4.0:
		return 1.0
	if cyc < 6.0:
		return 1.0 - smoothstep(0.0, 1.0, (cyc - 4.0) / 2.0)
	if cyc < 8.0:
		return VIS_HIDDEN
	if cyc < 10.0:
		return smoothstep(0.0, 1.0, (cyc - 8.0) / 2.0)
	return 1.0


## 形状/入口改变时，保持玩家在房间里的绝对 xyz 不动，只重算玩家的 w，
## 使玩家重新落在当前 Ellis 曲面上。这样入口移动/消失不会把玩家拖向喉口。
func _snap_player_to_surface() -> void:
	var q := Vector3(pos.x - entrance_c.x, pos.y - entrance_c.y, pos.z - entrance_c.z)
	var rho := q.length()
	if b0 < FLAT_EPS:
		pos.w = 0.0
		return
	var side := 1.0
	if pos.w < 0.0:
		side = -1.0
	elif absf(pos.w) < 0.000001 and flat_side < 0.5:
		side = -1.0
	if rho < b0:
		if rho > 0.0001:
			var n := q / rho
			pos.x = entrance_c.x + n.x * b0
			pos.y = entrance_c.y + n.y * b0
			pos.z = entrance_c.z + n.z * b0
		rho = b0
	var u := rho / b0
	var w := b0 * log(u + sqrt(u * u - 1.0))
	pos.w = side * w


## 标架维持: n_axis 对齐曲面法线, 其余三轴施密特正交化。
## 曲面变平时 fwd 的 w 分量会变成法向，投影后可能退化；退化时回退到“朝向入口”。
func _make_ortho() -> void:
	n_axis = surf_normal(pos)
	var f := fwd - n_axis * fwd.dot(n_axis)
	if f.length_squared() < 0.01:
		f = Vector4(entrance_c.x - pos.x, entrance_c.y - pos.y, entrance_c.z - pos.z, 0.0)
		f -= n_axis * f.dot(n_axis)
	if f.length_squared() < 0.001:
		f = Vector4(1.0, 0.0, 0.0, 0.0) - n_axis * n_axis.x
		if f.length_squared() < 0.001:
			f = Vector4(0.0, 0.0, 1.0, 0.0) - n_axis * n_axis.z
	fwd = f.normalized()

	var r := right - n_axis * right.dot(n_axis) - fwd * right.dot(fwd)
	if r.length_squared() < 0.001:
		r = Vector4(0.0, 0.0, 1.0, 0.0) - n_axis * n_axis.z - fwd * fwd.z
	right = r.normalized()

	var u := up - n_axis * up.dot(n_axis) - fwd * up.dot(fwd) - right * up.dot(right)
	if u.length_squared() < 0.001:
		u = Vector4(0.0, 1.0, 0.0, 0.0) - n_axis * n_axis.y - fwd * fwd.y
	up = u.normalized()


## 房间“上方” = 空间 z 轴在切空间中的投影
func room_up(p: Vector4) -> Vector4:
	var u := Vector4(0.0, 0.0, 1.0, 0.0)
	var n := surf_normal(p)
	u -= n * u.dot(n)
	if u.length_squared() < 0.000001:
		u = Vector4(0.0, 1.0, 0.0, 0.0)
		u -= n * u.dot(n)
	return u.normalized()


## 标架初始化: fwd = 指向房间中心 (虫洞入口); up = 房间上方;
## right = fwd × up (右手系, 保证画面不镜像)
func _init_frame() -> void:
	n_axis = surf_normal(pos)
	var room_center_w := ROOM_W * signf(pos.w)
	fwd = Vector4(0.0, 0.0, 0.0, room_center_w) - pos
	fwd -= n_axis * fwd.dot(n_axis)
	fwd = fwd.normalized()
	up = room_up(pos)
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

	# ---- 入口位置移动 ----
	if motion:
		motion_t += delta
		entrance_c = _entrance_at(motion_t)

	# ---- 显隐周期: b₀ → 0，喉口收缩、空间趋平直 ----
	var v := 1.0
	if vis_enabled:
		v = _visibility_at(time_s)
	var b0_new := B0 * v
	if b0_new < FLAT_EPS and b0 >= FLAT_EPS:
		flat_side = 1.0 if pos.w >= 0.0 else 0.0
	if absf(b0_new - b0) > 0.00001:
		b0 = b0_new
		_snap_player_to_surface()
		var nn := surf_normal(pos)
		vel -= nn * vel.dot(nn)
	vis = v
	b0 = b0_new

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

	# ---- 立方体房间边界 ----
	var lim := ROOM_L - 0.8
	pos.x = clampf(pos.x, -lim, lim)
	pos.y = clampf(pos.y, -lim, lim)
	pos.z = clampf(pos.z, -lim, lim)

	# ---- 约束在超曲面上; 穿过 w=0 的喉口即进入另一个房间 ----
	pos = surf_project(pos)
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
	mat.set_shader_parameter("throat_r", b0)
	mat.set_shader_parameter("vis", vis)
	mat.set_shader_parameter("flat_side", flat_side)
	mat.set_shader_parameter("entrance_c", entrance_c)
	mat.set_shader_parameter("diagram_lift", DIAGRAM_LIFT)


func _update_hud(delta: float) -> void:
	var u := 0.0
	var k2 := 0.0
	var state := "虫洞可见" if vis > 0.7 else "隐去中"
	var uni := "红房间 (w>0)" if pos.w > 0.0 else "蓝房间 (w<0)"
	if b0 >= FLAT_EPS:
		u = pos.w / b0
		k2 = -1.0 / (b0 * b0)
	else:
		state = "空间完全平直"
		uni = "平直空间（红）" if flat_side > 0.5 else "平直空间（蓝）"
	var q := Vector3(pos.x - entrance_c.x, pos.y - entrance_c.y, pos.z - entrance_c.z)
	var lift_txt := ("   h %.1f" % DIAGRAM_LIFT) if view_mode == 1 else ""
	if four_axis != null:
		four_axis.set_frame(pos, fwd, right, up, n_axis)
	pos_label.text = "[%s]  u %+.2f   w %7.1f   ρ %6.1f%s   入口 C (%+.1f, %+.1f, %+.1f)   可见度 %.2f   b₀ %.2f   K₂ %+.3f   %s   %s   速度 %.1f   SS %.1fx" % [
		MODE_NAMES[view_mode], u, pos.w, q.length(), lift_txt,
		entrance_c.x, entrance_c.y, entrance_c.z, vis, b0, k2, state, uni, speed, ss]
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
