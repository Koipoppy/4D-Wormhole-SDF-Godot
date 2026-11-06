extends Node
## 薄壳动态虫洞 —— 路线 A 的场景实现
##
## 环境: Ellis 三维空间的一个房间 (|xyz| ≤ ROOM_L, W_MIN ≤ w ≤ W_MAX)。
## 虫洞: 两个球口。口内球体被挖掉，两个球面边界按局部切标架认同；
##       光线/玩家进入一个口就从配对口出来。
## 动态: 口 A 自动沿曲面漂移（或方向键手动移动），每帧把口中心和
##       正交切标架传给 shader。这是准静态近似：冻结当前帧的几何。
##
## 操作:
##   鼠标 / WASD / Space·C / 滚轮 / Q·E   自由飞行
##   1 / 2      把口 A / B 放到准星命中的墙面
##   方向键      移动口 A（会关闭自动漂移）
##   T          自动漂移开关
##   X          启用/关闭口对
##   Backspace  重置两个口
##   F          超采样
##   M          返回场景菜单
##
## 截图:
##   godot --path . res://scenes/thinshell.tscn -- --shot=<png> [--shot-frame=N]
##        [--shot-pos=x,y,z,w] [--shot-yaw=deg] [--shot-pitch=deg] [--ss=1.5]

const THROAT_R := 3.0
const ROOM_C := Vector3(20.0, 0.0, 0.0)
const ROOM_L := 8.0
const W_MIN := 6.0
const W_MAX := 9.6
const MOUTH_R := 1.4
const BUMP_R := 3.2       # 局部形变的支撑半径（大于口半径，形变在口周围可见）
const BUMP_AMP := 4.0     # 局部 C∞ 形变强度（两个口都激活后升起）

const HELP_TEXT := """薄壳动态虫洞 | 1/2 放置口 A/B（先放一个为待定，两个都放后激活） | X 删除虫洞 | 方向键 移动口 A | T 自动漂移
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标 | F 超采样 | M 场景菜单
青色 A / 品红 B 是两个球口的边界；两个都放置后才认同成同一条通道:
· 飞进任意一个口 → 从另一个口出来（位置/速度/相机标架按口的切标架映射）
· 口 A 默认自动漂移，演示时间相关的薄壳几何（准静态光线追踪）
· 1/2 会把口放到准星命中的墙面；方向键可以手动移动口 A；X 清空这个虫洞实体"""

# 相机状态
var pos := Vector4(0.0, -13.0, 0.8, 0.0)
var n_axis := Vector4(1.0, 0.0, 0.0, 0.0)
var fwd := Vector4(0.0, 1.0, 0.0, 0.0)
var right := Vector4(1.0, 0.0, 0.0, 0.0)
var up := Vector4(0.0, 0.0, 1.0, 0.0)
var vel := Vector4.ZERO
var speed := 6.0
var mouse_sens := 0.0021
var rot_speed := 1.05
var ss := 1.5
var captured := false
var time_s := 0.0

# 口对状态（一个虫洞 = 一个实体；两个口都放置后才激活）
var a_placed := true
var b_placed := true
var pair_active := true
var auto_move := true
var mouth_r := MOUTH_R
var a_base := Vector4.ZERO
var a_center := Vector4.ZERO
var b_center := Vector4.ZERO
var a_frame: Array = []
var b_frame: Array = []
var a_path_e1 := Vector4.ZERO
var a_path_e2 := Vector4.ZERO
var a_vel := Vector4.ZERO
var b_vel := Vector4.ZERO
var a_phase := 0.0
var transfer_count := 0
var cooldown := 0.0
var bump_amp := 0.0

# 截图自检
var shot_path := ""
var shot_frame := 40
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
		pos = shot_pos
	else:
		pos = _surface_point(20.0, -7.0, 1.0)
	pos = _clamp_room(surf_project(pos), 0.30)
	_reset_mouths()
	_init_frame()
	if shot_yaw != 0.0:
		_rot_pair(1, 2, shot_yaw)
	if shot_pitch != 0.0:
		_rot_pair(1, 3, shot_pitch)
	if shot_ss > 0.0:
		ss = shot_ss
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "1/2 各放一个口；两个都放置后虫洞才激活。X 删除这个虫洞实体"
	_push_uniforms()


func _parse_shot_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-frame="):
			shot_frame = int(a.substr(13))
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
		_rot_pair(1, 2, event.relative.x * mouse_sens)
		_rot_pair(1, 3, -event.relative.y * mouse_sens)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_set_captured(false)
			KEY_1:
				_place_mouth(0)
			KEY_2:
				_place_mouth(1)
			KEY_T:
				auto_move = not auto_move
				_flash("自动漂移: %s" % ("开" if auto_move else "关"))
			KEY_X:
				_clear_pair()
				_flash("虫洞实体已删除（1/2 重新放置两个口）")
			KEY_BACKSPACE:
				_reset_mouths()
				_flash("口对已重置")
			KEY_F:
				ss = 1.0 if ss >= 1.99 else (1.5 if ss < 1.49 else 2.0)
				_apply_scale()


func _set_captured(on: bool) -> void:
	captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	time_s += delta
	cooldown = maxf(cooldown - delta, 0.0)

	# ---- 局部流形形变：两个口都激活后才升起 ----
	var bump_target := BUMP_AMP if pair_active else 0.0
	bump_amp = lerpf(bump_amp, bump_target, 1.0 - exp(-4.0 * delta))

	# ---- 翻滚 ----
	if Input.is_key_pressed(KEY_Q):
		_rot_pair(2, 3, rot_speed * delta)
	if Input.is_key_pressed(KEY_E):
		_rot_pair(2, 3, -rot_speed * delta)

	# ---- 口 A 自动漂移 / 手动移动 ----
	_update_mouth_motion(delta)
	_handle_manual_mouth(delta)

	# ---- 切向移动 ----
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
	pos += vel * delta
	pos = _clamp_room(surf_project(pos), 0.30)

	_check_transfer()
	_make_ortho()

	_push_uniforms()
	_update_hud(delta)
	_maybe_screenshot()


# ---- 口对 ----

func _reset_mouths() -> void:
	a_placed = true
	b_placed = true
	a_base = _clamp_room_base(_surface_point(16.0, 0.0, 0.0), 0.30)
	b_center = _clamp_room_base(_surface_point(24.0, 0.0, 0.0), 0.30)
	a_center = a_base
	a_phase = 0.0
	a_vel = Vector4.ZERO
	b_vel = Vector4.ZERO
	_sync_pair()
	_update_frames()
	_rebuild_path()


func _clear_pair() -> void:
	a_placed = false
	b_placed = false
	pair_active = false
	a_frame = []
	b_frame = []
	a_vel = Vector4.ZERO
	b_vel = Vector4.ZERO


func _sync_pair() -> void:
	pair_active = a_placed and b_placed
	_update_frames()
	if pair_active:
		_rebuild_path()


func _update_mouth_motion(delta: float) -> void:
	if auto_move and a_placed and pair_active and a_path_e1.length_squared() > 0.5:
		a_phase += delta * 0.70
		var off := a_path_e1 * (2.4 * sin(a_phase)) + a_path_e2 * (1.0 * sin(1.7 * a_phase))
		var target := _clamp_room_base(base_project(a_base + off), 0.30)
		a_vel = (target - a_center) / maxf(delta, 0.0001)
		a_center = target
		_update_frames()
	else:
		a_vel = Vector4.ZERO
	b_vel = Vector4.ZERO


func _handle_manual_mouth(delta: float) -> void:
	if not a_placed:
		return
	var mdir := Vector4.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		mdir -= right
	if Input.is_key_pressed(KEY_RIGHT):
		mdir += right
	if Input.is_key_pressed(KEY_UP):
		mdir += up
	if Input.is_key_pressed(KEY_DOWN):
		mdir -= up
	if mdir.length_squared() < 0.000001:
		return
	auto_move = false
	a_base = _clamp_room_base(base_project(a_center + mdir.normalized() * 3.0 * delta), 0.30)
	a_center = a_base
	_update_frames()
	_rebuild_path()


func _update_frames() -> void:
	a_frame = _mouth_frame(a_center) if a_placed else []
	b_frame = _mouth_frame(b_center) if b_placed else []


func _rebuild_path() -> void:
	if a_placed and a_frame.size() == 3:
		a_path_e1 = a_frame[0]
		a_path_e2 = a_frame[1]


## 口中心的正交切标架: 3 个与曲面法向正交的单位向量。
## 用房间的 z 向上优先，保证两个口的“上”尽量一致。
func _mouth_frame(c: Vector4) -> Array:
	var n := base_normal(c)
	var refs := [
		Vector4(0.0, 0.0, 1.0, 0.0),
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, 1.0, 0.0, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0),
	]
	var e1 := Vector4.ZERO
	for r in refs:
		var t: Vector4 = r - n * r.dot(n)
		if t.length_squared() > 0.05:
			e1 = t.normalized()
			break
	var e2 := Vector4.ZERO
	for r in refs:
		var t: Vector4 = r - n * r.dot(n)
		t -= e1 * t.dot(e1)
		if t.length_squared() > 0.05:
			e2 = t.normalized()
			break
	var e3 := Vector4.ZERO
	for r in refs:
		var t: Vector4 = r - n * r.dot(n)
		t -= e1 * t.dot(e1) + e2 * t.dot(e2)
		if t.length_squared() > 0.05:
			e3 = t.normalized()
			break
	# 两个标架相对法向的手性一致，避免镜像
	if _det4(e1, e2, e3, n) < 0.0:
		e2 = -e2
	return [e1, e2, e3]


func _det4(a: Vector4, b: Vector4, c: Vector4, d: Vector4) -> float:
	var m := [
		[a.x, a.y, a.z, a.w],
		[b.x, b.y, b.z, b.w],
		[c.x, c.y, c.z, c.w],
		[d.x, d.y, d.z, d.w],
	]
	var det := 1.0
	for i in 4:
		var piv := i
		for j in range(i + 1, 4):
			if absf(m[j][i]) > absf(m[piv][i]):
				piv = j
		if absf(m[piv][i]) < 1e-9:
			return 0.0
		if piv != i:
			var tmp = m[i]
			m[i] = m[piv]
			m[piv] = tmp
			det = -det
		det *= m[i][i]
		for j in range(i + 1, 4):
			var f: float = m[j][i] / m[i][i]
			for k in range(i, 4):
				m[j][k] -= f * m[i][k]
	return det


func _check_transfer() -> void:
	if not pair_active or cooldown > 0.0:
		return
	if a_frame.size() != 3 or b_frame.size() != 3:
		return
	if (pos - a_center).length() < mouth_r:
		_do_transfer(a_center, b_center, a_frame, b_frame, a_vel, "A → B")
	elif (pos - b_center).length() < mouth_r:
		_do_transfer(b_center, a_center, b_frame, a_frame, b_vel, "B → A")


func _do_transfer(from_c: Vector4, to_c: Vector4, from_f: Array, to_f: Array, to_vel: Vector4, label: String) -> void:
	var d := pos - from_c
	var local := Vector3(d.dot(from_f[0]), d.dot(from_f[1]), d.dot(from_f[2]))
	var mapped: Vector4 = local.x * to_f[0] + local.y * to_f[1] + local.z * to_f[2]
	if mapped.length_squared() < 1e-8:
		mapped = _map_dir(fwd, from_f, to_f)
	var dir := mapped.normalized()

	pos = to_c + dir * (mouth_r + 0.15)
	pos = _clamp_room(surf_project(pos), 0.30)
	n_axis = surf_normal(pos)

	var lv := Vector3(vel.dot(from_f[0]), vel.dot(from_f[1]), vel.dot(from_f[2]))
	var nv: Vector4 = lv.x * to_f[0] + lv.y * to_f[1] + lv.z * to_f[2]
	nv += to_vel                     # 动态薄壳: 出口口的速度会带来一个冲量
	nv -= n_axis * nv.dot(n_axis)
	nv -= 2.0 * nv.dot(dir) * dir    # 出口径向分量翻向外
	if nv.length() > 30.0:
		nv = nv.normalized() * 30.0
	vel = nv

	fwd = _map_dir(fwd, from_f, to_f)
	fwd -= 2.0 * fwd.dot(dir) * dir
	fwd = fwd.normalized()
	right = _map_dir(right, from_f, to_f)
	up = _map_dir(up, from_f, to_f)
	_make_ortho()

	cooldown = 0.35
	transfer_count += 1
	_flash("穿越 %s" % label)


func _map_dir(v: Vector4, from_f: Array, to_f: Array) -> Vector4:
	var c := Vector3(v.dot(from_f[0]), v.dot(from_f[1]), v.dot(from_f[2]))
	var r: Vector4 = c.x * to_f[0] + c.y * to_f[1] + c.z * to_f[2]
	if r.length_squared() < 1e-8:
		return v
	return r.normalized()


func _place_mouth(which: int) -> void:
	var hit := _raycast_room()
	if not hit["hit"]:
		_flash("准星没有命中墙面")
		return
	var hp: Vector4 = hit["p"]
	var hn: Vector4 = hit["n"]
	var c: Vector4 = base_project(hp - hn * 0.25)
	c = _clamp_room_base(c, 0.30)
	if which == 0:
		a_base = c
		a_center = c
		a_placed = true
		auto_move = false
		_sync_pair()
		_flash("口 A 已放置；等待口 B" if not pair_active else "虫洞已激活（A ↔ B）")
	else:
		b_center = c
		b_placed = true
		_sync_pair()
		_flash("口 B 已放置；等待口 A" if not pair_active else "虫洞已激活（A ↔ B）")


func _raycast_room() -> Dictionary:
	var p := pos
	var v := fwd
	var n := surf_normal(p)
	v -= n * v.dot(n)
	v = v.normalized()
	for i in 1200:
		var d := room_sdf(p)
		if d < 0.06:
			return {"hit": true, "p": p, "n": room_normal(p)}
		var h := clampf(0.5 * d + 0.02, 0.02, 0.5)
		p += v * h
		p = surf_project(p)
		n = surf_normal(p)
		v -= n * v.dot(n)
		v = v.normalized()
	return {"hit": false}


## 由普通 xyz 坐标构造超曲面上的点: ρ = b₀·cosh(w/b₀) ⇒ w = b₀·arcosh(ρ/b₀)。
func _surface_point(x: float, y: float, z: float) -> Vector4:
	var rho := sqrt(x * x + y * y + z * z)
	var rr := maxf(rho, THROAT_R * 1.0001)
	var scale := rr / maxf(rho, 1e-6)
	var u := rr / THROAT_R
	var w := THROAT_R * log(u + sqrt(u * u - 1.0))
	return base_project(Vector4(x * scale, y * scale, z * scale, w))


# ---- Ellis 基面 + 局部 C∞ 形变 ----
# bump(x) = exp(1 - 1/(1-x²))，|x|≥1 处及其所有导数为 0。
# 两个口球边界 |p-c|=mouth_r 处与 Ellis 光滑拼接；曲率变化只在球内。

func bump_val(x: float) -> float:
	if absf(x) >= 1.0:
		return 0.0
	var y := 1.0 - x * x
	return exp(1.0 - 1.0 / y)


func bump_deriv(x: float) -> float:
	if absf(x) >= 1.0:
		return 0.0
	var y := 1.0 - x * x
	return bump_val(x) * (-2.0 * x / (y * y))


func bump_pair(p: Vector4) -> float:
	var r := maxf(BUMP_R, 0.0001)
	return bump_val((p - a_center).length() / r) + bump_val((p - b_center).length() / r)


func bump_grad_pair(p: Vector4) -> Vector4:
	var g := Vector4.ZERO
	var r := maxf(BUMP_R, 0.0001)
	var da := (p - a_center).length()
	if da > 0.00001 and da < r:
		g += (bump_deriv(da / r) / r) * (p - a_center) / da
	var db := (p - b_center).length()
	if db > 0.00001 and db < r:
		g += (bump_deriv(db / r) / r) * (p - b_center) / db
	return g


func base_f(p: Vector4) -> float:
	return Vector3(p.x, p.y, p.z).length() - THROAT_R * cosh(p.w / THROAT_R)


func base_grad(p: Vector4) -> Vector4:
	var rho := Vector3(p.x, p.y, p.z).length()
	var g3 := Vector3.ZERO
	if rho > 0.0001:
		g3 = Vector3(p.x, p.y, p.z) / rho
	return Vector4(g3.x, g3.y, g3.z, -sinh(p.w / THROAT_R))


func base_project(p: Vector4) -> Vector4:
	for i in 3:
		var g := base_grad(p)
		var f := base_f(p)
		p -= g * f / maxf(g.dot(g), 0.000001)
	return p


func base_normal(p: Vector4) -> Vector4:
	return base_grad(p).normalized()


func surf_f(p: Vector4) -> float:
	return base_f(p) - bump_amp * bump_pair(p)


func surf_grad(p: Vector4) -> Vector4:
	return base_grad(p) - bump_amp * bump_grad_pair(p)


func surf_project(p: Vector4) -> Vector4:
	for i in 3:
		var g := surf_grad(p)
		var f := surf_f(p)
		p -= g * f / maxf(g.dot(g), 0.000001)
	return p


func surf_normal(p: Vector4) -> Vector4:
	return surf_grad(p).normalized()


# ---- 房间 ----

func room_sdf(p: Vector4) -> float:
	var boxd := ROOM_L - maxf(absf(p.x - ROOM_C.x), maxf(absf(p.y - ROOM_C.y), absf(p.z - ROOM_C.z)))
	return minf(boxd, minf(p.w - W_MIN, W_MAX - p.w))


func room_normal(p: Vector4) -> Vector4:
	var ax := absf(p.x - ROOM_C.x)
	var ay := absf(p.y - ROOM_C.y)
	var az := absf(p.z - ROOM_C.z)
	var boxd := ROOM_L - maxf(ax, maxf(ay, az))
	var dw := minf(p.w - W_MIN, W_MAX - p.w)
	if dw < boxd:
		return Vector4(0.0, 0.0, 0.0, -1.0 if p.w - W_MIN < W_MAX - p.w else 1.0)
	if ax >= ay and ax >= az:
		return Vector4(signf(p.x - ROOM_C.x), 0.0, 0.0, 0.0)
	if ay >= az:
		return Vector4(0.0, signf(p.y - ROOM_C.y), 0.0, 0.0)
	return Vector4(0.0, 0.0, signf(p.z - ROOM_C.z), 0.0)


func _clamp_room(p: Vector4, margin: float) -> Vector4:
	for i in 2:
		p.x = clampf(p.x, ROOM_C.x - ROOM_L + margin, ROOM_C.x + ROOM_L - margin)
		p.y = clampf(p.y, ROOM_C.y - ROOM_L + margin, ROOM_C.y + ROOM_L - margin)
		p.z = clampf(p.z, ROOM_C.z - ROOM_L + margin, ROOM_C.z + ROOM_L - margin)
		p.w = clampf(p.w, W_MIN + margin, W_MAX - margin)
		p = surf_project(p)
	return p


## 口中心用基面（不含 bump）clamp；口球边界处 bump=0，所以中心和边界几何一致。
func _clamp_room_base(p: Vector4, margin: float) -> Vector4:
	for i in 2:
		p.x = clampf(p.x, ROOM_C.x - ROOM_L + margin, ROOM_C.x + ROOM_L - margin)
		p.y = clampf(p.y, ROOM_C.y - ROOM_L + margin, ROOM_C.y + ROOM_L - margin)
		p.z = clampf(p.z, ROOM_C.z - ROOM_L + margin, ROOM_C.z + ROOM_L - margin)
		p.w = clampf(p.w, W_MIN + margin, W_MAX - margin)
		p = base_project(p)
	return p


# ---- 标架 ----

func _init_frame() -> void:
	n_axis = surf_normal(pos)
	fwd -= n_axis * fwd.dot(n_axis)
	if fwd.length_squared() < 0.000001:
		fwd = Vector4(0.0, 1.0, 0.0, 0.0) - n_axis * n_axis.y
	fwd = fwd.normalized()
	up -= n_axis * up.dot(n_axis)
	up -= fwd * up.dot(fwd)
	if up.length_squared() < 0.000001:
		up = Vector4(0.0, 0.0, 1.0, 0.0) - n_axis * n_axis.z
	up = up.normalized()
	var r3 := Vector3(fwd.x, fwd.y, fwd.z).cross(Vector3(up.x, up.y, up.z))
	right = Vector4(r3.x, r3.y, r3.z, 0.0)
	right -= n_axis * right.dot(n_axis)
	right = right.normalized()


func _make_ortho() -> void:
	n_axis = surf_normal(pos)
	fwd = (fwd - n_axis * fwd.dot(n_axis)).normalized()
	right = (right - n_axis * right.dot(n_axis) - fwd * right.dot(fwd)).normalized()
	up = (up - n_axis * up.dot(n_axis) - fwd * up.dot(fwd) - right * up.dot(right)).normalized()


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


# ---- 渲染参数 / HUD ----

func _push_uniforms() -> void:
	mat.set_shader_parameter("cam_pos", pos)
	mat.set_shader_parameter("cam_fwd", fwd)
	mat.set_shader_parameter("cam_right", right)
	mat.set_shader_parameter("cam_up", up)
	mat.set_shader_parameter("time_s", time_s)
	mat.set_shader_parameter("throat_r", THROAT_R)
	mat.set_shader_parameter("pair_active", 1.0 if pair_active else 0.0)
	mat.set_shader_parameter("show_a", 1.0 if a_placed else 0.0)
	mat.set_shader_parameter("show_b", 1.0 if b_placed else 0.0)
	mat.set_shader_parameter("mouth_r", mouth_r)
	mat.set_shader_parameter("bump_r", BUMP_R)
	mat.set_shader_parameter("bump_amp", bump_amp)
	mat.set_shader_parameter("a_c", a_center)
	mat.set_shader_parameter("b_c", b_center)
	if a_frame.size() == 3:
		mat.set_shader_parameter("a_e1", a_frame[0])
		mat.set_shader_parameter("a_e2", a_frame[1])
		mat.set_shader_parameter("a_e3", a_frame[2])
	if b_frame.size() == 3:
		mat.set_shader_parameter("b_e1", b_frame[0])
		mat.set_shader_parameter("b_e2", b_frame[1])
		mat.set_shader_parameter("b_e3", b_frame[2])


func _update_hud(delta: float) -> void:
	var d_ab := 0.0
	if a_placed and b_placed:
		d_ab = (a_center - b_center).length()
	var atxt := "—"
	var btxt := "—"
	if a_placed:
		atxt = "(%+.1f, %+.1f, %+.1f) w %+.1f" % [a_center.x, a_center.y, a_center.z, a_center.w]
	if b_placed:
		btxt = "(%+.1f, %+.1f, %+.1f) w %+.1f" % [b_center.x, b_center.y, b_center.z, b_center.w]
	coord_label.text = "[color=#3ddcff]A[/color] %s    [color=#ff5cc8]B[/color] %s" % [atxt, btxt]

	var state := "空"
	if a_placed and b_placed:
		state = "激活"
	elif a_placed:
		state = "待 B"
	elif b_placed:
		state = "待 A"
	pos_label.text = "薄壳动态虫洞 | 口对 %s | 形变 %.2f | 口距 %.1f m | 穿越 %d | 自动 %s   速度 %.1f   SS %.1fx" % [
		state, bump_amp, d_ab, transfer_count,
		"开" if auto_move else "关",
		speed, ss,
	]
	toast.modulate.a = maxf(toast.modulate.a - delta * 0.5, 0.0)


func _flash(msg: String) -> void:
	toast.text = msg
	toast.modulate.a = 1.5


func _maybe_screenshot() -> void:
	if shot_path == "":
		return
	frame_count += 1
	if frame_count >= shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT_SAVED ", shot_path)
		get_tree().quit()
