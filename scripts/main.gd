extends Node
## 四维空间 SDF 引擎 + 虫洞 —— 分层宇宙 + 井道 (v20)
##
## 世界模型:
##   · 三个宇宙 = w 轴上的三张平行层: A (w=-24, 冷) / B (w=0, 家) / C (w=+24, 暖·远)。
##     每层是平直 3D 空间: 地板 {z=-2, w=w_i} (精确 2-平面距离场) + 各自色温的星空。
##   · 虫洞 = 连接层的真实 4D 管道 (SDF 实体, 空心、端口喇叭、层内平走段 + 弯入 +w 的竖井):
##       A→B 井道 (x=-30) / B→C 井道 (x=+30) / B 层内 320m 直线快速通道。
##   · 穿越 = 4D 飞行 + 管壁碰撞 (沿壁滑动): 管道在 w 方向弯折,
##     按住 I/K 把视线转入 w 就能沿竖井爬升 —— 全程连续, 无传送。
##   · 平直层内光线不弯; 虫洞的可见效果 = 管道几何本身 + 透过端口看到的另一层。
##
## 自动化截图:
##   godot --path . -- --shot=<png> [--shot-pos=x,y,z,w] [--shot-yaw=deg]
##        [--shot-pitch=deg] [--shot-ana-yaw=deg] [--shot-ana-pitch=deg]
##        [--shot-mode=0|1] [--ss=1.5]

# ---- 世界常量 (与 shaders/wormhole4d.gdshader 保持一致) ----
const SHEET_W := [-24.0, 0.0, 24.0]           # 三张平行层的 w
const FLOOR_Z := -2.0
const PORT_R := 3.4
const THROAT_R := 2.4
const EXPRESS_R := 2.6
const TUBE_WALL := 0.4

const TUBE_BC: Array = [Vector4(30.0, 0.0, 0.0, 0.0), Vector4(30.0, 0.0, -16.0, 0.0), Vector4(30.0, 0.0, -21.0, 17.0), Vector4(30.0, 0.0, -1.0, 24.0)]
const TUBE_AB: Array = [Vector4(-30.0, 0.0, 0.0, -24.0), Vector4(-30.0, 0.0, -16.0, -24.0), Vector4(-30.0, 0.0, -21.0, -7.0), Vector4(-30.0, 0.0, -1.0, 0.0)]
const TUBE_BB: Array = [Vector4(-160.0, 0.0, 0.0, 0.0), Vector4(160.0, 0.0, 0.0, 0.0)]
const TUBES: Array = [TUBE_BC, TUBE_AB, TUBE_BB]

const MODE_NAMES := ["① 第一人称", "② 楼层图 (x,w)"]
const UNI_NAMES := ["宇宙A (冷)", "宇宙B (家)", "宇宙C (暖·远)"]

const HELP_TEXT := """V 楼层图 (x,w) — 三层平行宇宙 + 井道 + 快速通道 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标
── 四维转动 (按住): I/K 俯仰进入±w (看进第四维)   J/L 滚转入w   U/O 偏摆入w   G 等角双旋转 ──
三个平行宇宙层: A (w=-24, 冷) / B (w=0, 家) / C (w=+24, 暖·远), 地板下是 4D 体空间。
· 右前方 30m: B→C 井道端口 — 飞进去, 层内平走后管道弯入 +w, 按住 I 跟随竖井爬升到宇宙 C
· 左后方 30m: A→B 井道 — 通往宇宙 A
· B 层内的 320m 直线快速通道: 两端端口, 穿过即完成远距移动 (全程可见另一端)
· 层是平直的: 光线不弯; 虫洞的全部效果 = 真实管道几何 + 透过端口看到的另一层"""

# 相机: 4D 自由飞行, 4D 正交标架 (0=fwd 1=right 2=up 3=ana)
var pos := Vector4(0.0, 1.7, 2.0, 0.0)
var frame: Array[Vector4] = [
	Vector4(0.0, 0.0, -1.0, 0.0),   # fwd    -z
	Vector4(1.0, 0.0, 0.0, 0.0),    # right  +x
	Vector4(0.0, 1.0, 0.0, 0.0),    # up     +y (层内"上")
	Vector4(0.0, 0.0, 0.0, 1.0),    # ana    +w
]
var vel := Vector4.ZERO
var speed := 7.0
var mouse_sens := 0.0021
var rot_speed := 1.05
var view_mode := 0
var ss := 1.5
var captured := false
var time_s := 0.0
var sheet := 1                 # 当前层 (0=A 1=B 2=C)
var in_tube := -1              # 所在管道索引 (-1 = 不在管内)

# ---- 截图自检 ----
var shot_path := ""
var shot_frame := 40
var shot_mode := -1
var shot_pos := Vector4.ZERO
var shot_pos_set := false
var shot_yaw := 0.0
var shot_pitch := 0.0
var shot_ana_yaw := 0.0
var shot_ana_pitch := 0.0
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
	if shot_yaw != 0.0:
		_rot_pair(0, 1, shot_yaw)       # 正 = 向右转
	if shot_pitch != 0.0:
		_rot_pair(0, 2, shot_pitch)     # 正 = 抬头
	if shot_ana_yaw != 0.0:
		_rot_pair(0, 3, shot_ana_yaw)   # 正 = 视线转入 +w
	if shot_ana_pitch != 0.0:
		_rot_pair(2, 3, shot_ana_pitch)
	if shot_mode >= 0:
		view_mode = shot_mode
	if shot_ss > 0.0:
		ss = shot_ss
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "点击窗口捕获鼠标 → 右前方 30m 是 B→C 井道端口, 飞进去 (按住 I 跟随竖井爬升)"


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
		elif a.begins_with("--shot-ana-yaw="):
			shot_ana_yaw = deg_to_rad(float(a.substr(15)))
		elif a.begins_with("--shot-ana-pitch="):
			shot_ana_pitch = deg_to_rad(float(a.substr(17)))
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
		_rot_pair(0, 1, event.relative.x * mouse_sens)    # 偏航: 右移右转
		_rot_pair(0, 2, -event.relative.y * mouse_sens)   # 俯仰: 下移下视
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


## 初始标架: fwd 指向 B→C 井道端口 (层内方向), up = 层内竖直 (+z), right/ana 补全
func _init_frame() -> void:
	var to_port := Vector4(30.0, 0.0, 0.0, 0.0) - pos
	to_port.w = 0.0
	frame[0] = to_port.normalized()
	frame[2] = Vector4(0.0, 0.0, 1.0, 0.0) - frame[0] * frame[2].dot(frame[0])
	frame[2] = frame[2].normalized()
	var f3 := Vector3(frame[0].x, frame[0].y, frame[0].z)
	var u3 := Vector3(frame[2].x, frame[2].y, frame[2].z)
	var r3 := f3.cross(u3)
	frame[1] = Vector4(r3.x, r3.y, r3.z, 0.0)
	frame[1] -= frame[3] * frame[1].dot(frame[3])
	frame[1] = frame[1].normalized()
	frame[3] = Vector4(0.0, 0.0, 0.0, 1.0) - frame[0] * frame[3].dot(frame[0]) - frame[1] * frame[3].dot(frame[1]) - frame[2] * frame[3].dot(frame[2])
	frame[3] = frame[3].normalized()


## 在 (frame[i], frame[j]) 平面内旋转 4D 标架
func _rot_pair(i: int, j: int, ang: float) -> void:
	if ang == 0.0:
		return
	var vi := frame[i]
	var vj := frame[j]
	var c := cos(ang)
	var s := sin(ang)
	frame[i] = vi * c + vj * s
	frame[j] = -vi * s + vj * c


## 施密特正交化 (保持 fwd 方向), 抑制浮点漂移
func _make_ortho() -> void:
	frame[0] = frame[0].normalized()
	frame[1] -= frame[0] * frame[1].dot(frame[0])
	frame[2] -= frame[0] * frame[2].dot(frame[0]) + frame[1] * frame[2].dot(frame[1])
	frame[3] -= frame[0] * frame[3].dot(frame[0]) + frame[1] * frame[3].dot(frame[1]) + frame[2] * frame[3].dot(frame[2])
	frame[1] = frame[1].normalized()
	frame[2] = frame[2].normalized()
	frame[3] = frame[3].normalized()


# ---- 4D SDF 的 GDScript 副本 (与着色器同一数学, 用于碰撞) ----

func _seg_dist(p: Vector4, a: Vector4, b: Vector4) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return (p - (a + ab * t)).length()


func _seg_center(p: Vector4, a: Vector4, b: Vector4) -> Vector4:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return a + ab * t


func _nearest_on_path(p: Vector4, pts: Array) -> Vector4:
	var best := _seg_center(p, pts[0], pts[1])
	var bd := (p - best).length()
	for i in range(1, pts.size() - 1):
		var c := _seg_center(p, pts[i], pts[i + 1])
		var d := (p - c).length()
		if d < bd:
			bd = d
			best = c
	return best


func _tube_bore_r(p: Vector4, pts: Array) -> float:
	var d_end := minf((p - pts[0]).length(), (p - pts[pts.size() - 1]).length())
	var blend := 9.0 if pts.size() > 2 else 10.0
	var s: float = 1.0 - clampf(d_end / blend, 0.0, 1.0)
	var r_mid := THROAT_R if pts.size() > 2 else EXPRESS_R
	var r_port := PORT_R if pts.size() > 2 else EXPRESS_R + 0.8
	return r_mid + (r_port - r_mid) * s * s


func _shaft_sdf(p: Vector4, pts: Array) -> float:
	var axis := 1e9
	for i in pts.size() - 1:
		axis = minf(axis, _seg_dist(p, pts[i], pts[i + 1]))
	var d_end := minf((p - pts[0]).length(), (p - pts[pts.size() - 1]).length())
	var blend := 9.0 if pts.size() > 2 else 10.0
	var s: float = 1.0 - clampf(d_end / blend, 0.0, 1.0)
	var r_mid := THROAT_R if pts.size() > 2 else EXPRESS_R
	var r_port := PORT_R if pts.size() > 2 else EXPRESS_R + 0.8
	var r := r_mid + (r_port - r_mid) * s * s
	var shell := maxf(axis - r, (r - TUBE_WALL) - axis)
	shell = maxf(shell, (p - pts[0]).dot((pts[0] - pts[1]).normalized()))
	shell = maxf(shell, (p - pts[pts.size() - 1]).dot((pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()))
	return shell


func _straight_sdf(p: Vector4, a: Vector4, b: Vector4) -> float:
	var ab := b - a
	var dir := ab.normalized()
	var t := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	var axis := (p - (a + ab * t)).length()
	var d_end := minf((p - a).length(), (p - b).length())
	var s: float = 1.0 - clampf(d_end / 10.0, 0.0, 1.0)
	var r := EXPRESS_R + (PORT_R + 0.8 - EXPRESS_R) * s * s
	var shell := maxf(axis - r, (r - TUBE_WALL) - axis)
	shell = maxf(shell, (p - a).dot(-dir))
	shell = maxf(shell, (p - b).dot(dir))
	return shell


func _tubes_sdf(p: Vector4) -> float:
	return minf(_shaft_sdf(p, TUBE_BC), minf(_shaft_sdf(p, TUBE_AB), _straight_sdf(p, TUBE_BB[0], TUBE_BB[1])))


func _tubes_grad(p: Vector4) -> Vector4:
	var e := 0.01
	return Vector4(
		_tubes_sdf(p + Vector4(e, 0, 0, 0)) - _tubes_sdf(p - Vector4(e, 0, 0, 0)),
		_tubes_sdf(p + Vector4(0, e, 0, 0)) - _tubes_sdf(p - Vector4(0, e, 0, 0)),
		_tubes_sdf(p + Vector4(0, 0, e, 0)) - _tubes_sdf(p - Vector4(0, 0, e, 0)),
		_tubes_sdf(p + Vector4(0, 0, 0, e)) - _tubes_sdf(p - Vector4(0, 0, 0, e))
	).normalized()


func _nearest_sheet(w: float) -> int:
	if w < -12.0:
		return 0
	if w < 12.0:
		return 1
	return 2


## 碰撞: ① 管壁实体推出 (4D 梯度); ② 管内约束在内壁并沿壁滑动;
## ③ 不在管内时锁定所在层 (w + 地板)。没有传送: 层的切换只发生在管道内。
func _collide() -> void:
	# 管壁实体: 在壳内沿 4D 梯度推出
	var d := _tubes_sdf(pos)
	if d < 0.0:
		var g := _tubes_grad(pos)
		pos -= g * d

	# 最近管道
	var bi := -1
	var bc := Vector4.ZERO
	var bd := 1e9
	var bb := 0.35
	for ti in TUBES.size():
		var pts: Array = TUBES[ti]
		var c := _nearest_on_path(pos, pts)
		var dd := (pos - c).length()
		var bore := _tube_bore_r(pos, pts) - 0.15
		if dd < bd:
			bd = dd
			bc = c
			bi = ti
			bb = bore

	# 端口外判定 (沿轴越过端口平面)
	var beyond_a: bool = (pos - TUBE_BC[0]).dot((TUBE_BC[0] - TUBE_BC[1]).normalized()) > 0.05
	var beyond_b: bool = (pos - TUBE_BC[3]).dot((TUBE_BC[3] - TUBE_BC[2]).normalized()) > 0.05
	var beyond_c: bool = (pos - TUBE_AB[0]).dot((TUBE_AB[0] - TUBE_AB[1]).normalized()) > 0.05
	var beyond_d: bool = (pos - TUBE_AB[3]).dot((TUBE_AB[3] - TUBE_AB[2]).normalized()) > 0.05

	if bd < bb * 0.95 and not beyond_a and not beyond_b and not beyond_c and not beyond_d:
		# 管内: 约束在内壁, 沿壁滑动
		if in_tube != bi:
			in_tube = bi
			_flash("进入虫洞管道 —— 沿 4D 几何连续穿行")
		if bd > bb - 0.05 and bd > 0.0001:
			var outward := (pos - bc) / bd
			pos = bc + outward * (bb - 0.05)
			var vout := vel.dot(outward)
			if vout > 0.0:
				vel -= outward * vout
	else:
		if in_tube >= 0:
			in_tube = -1
			sheet = _nearest_sheet(pos.w)
			_flash("离开管道 → %s" % UNI_NAMES[sheet])
		# 层约束: w 锁定本层, 地板之上
		pos.w = SHEET_W[sheet]
		if pos.z < FLOOR_Z + 0.35:
			pos.z = FLOOR_Z + 0.35
			if vel.z < 0.0:
				vel.z = 0.0


func _process(delta: float) -> void:
	time_s += delta

	# ---- 翻滚 (right, up) ----
	if Input.is_key_pressed(KEY_Q):
		_rot_pair(1, 2, rot_speed * delta)
	if Input.is_key_pressed(KEY_E):
		_rot_pair(1, 2, -rot_speed * delta)
	# ---- 四维转动: 视线/机动 进入 ±w ----
	if Input.is_key_pressed(KEY_I):
		_rot_pair(0, 3, rot_speed * delta)    # 俯仰进入 +w (看进第四维)
	if Input.is_key_pressed(KEY_K):
		_rot_pair(0, 3, -rot_speed * delta)
	if Input.is_key_pressed(KEY_J):
		_rot_pair(1, 3, rot_speed * delta)    # 滚转进入 +w
	if Input.is_key_pressed(KEY_L):
		_rot_pair(1, 3, -rot_speed * delta)
	if Input.is_key_pressed(KEY_U):
		_rot_pair(2, 3, rot_speed * delta)    # 偏摆进入 +w
	if Input.is_key_pressed(KEY_O):
		_rot_pair(2, 3, -rot_speed * delta)
	if Input.is_key_pressed(KEY_G):
		_rot_pair(0, 3, rot_speed * 0.8 * delta)
		_rot_pair(1, 2, rot_speed * 0.8 * delta)
	_make_ortho()

	# ---- 4D 移动 ----
	var dir := Vector4.ZERO
	if Input.is_key_pressed(KEY_W):
		dir += frame[0]
	if Input.is_key_pressed(KEY_S):
		dir -= frame[0]
	if Input.is_key_pressed(KEY_D):
		dir += frame[1]
	if Input.is_key_pressed(KEY_A):
		dir -= frame[1]
	if Input.is_key_pressed(KEY_SPACE):
		dir += frame[2]
	if Input.is_key_pressed(KEY_C):
		dir -= frame[2]
	var target := dir.normalized() * speed if dir.length_squared() > 0.000001 else Vector4.ZERO
	vel = vel.lerp(target, 1.0 - exp(-8.0 * delta))
	pos += vel * delta

	# ---- 碰撞 (层约束 + 管壁) ----
	_collide()

	_push_uniforms()
	_update_hud(delta)
	_maybe_screenshot()


func _push_uniforms() -> void:
	mat.set_shader_parameter("cam_pos", pos)
	mat.set_shader_parameter("cam_fwd", frame[0])
	mat.set_shader_parameter("cam_right", frame[1])
	mat.set_shader_parameter("cam_up", frame[2])
	mat.set_shader_parameter("time_s", time_s)
	mat.set_shader_parameter("view_mode", float(view_mode))


func _update_hud(delta: float) -> void:
	coord_label.text = "[color=#ff8a80]X[/color] %+.1f    [color=#7ee787]Y[/color] %+.1f    [color=#79c0ff]Z[/color] %+.1f    [color=#d2a8ff]W[/color] %+.1f" % [
		pos.x, pos.y, pos.z, pos.w]
	var tag := "  [管内]" if in_tube >= 0 else ""
	pos_label.text = "[%s]  宇宙 %s   w %+.1f   速度 %.1f   SS %.1fx%s" % [
		MODE_NAMES[view_mode], UNI_NAMES[sheet], pos.w, speed, ss, tag]
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
