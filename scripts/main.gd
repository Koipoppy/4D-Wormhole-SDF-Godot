extends Node
## 四维空间 SDF 引擎 + 虫洞 —— 平行层 + 球形喉口窗口 (v21)
##
## 世界模型:
##   · 三个宇宙 = w 轴上的三张平行层: A (w=-24, 冷) / B (w=0, 家) / C (w=+24, 暖)。
##     每层是平直 3D 空间: 地板超平面 {z=-2, w=w_i} 的精确 2-平面距离场。
##   · 虫洞口 = 球形喉口: 球内区域通过平移映射 p += Δ 与另一层的对应球等同
##     (Δ 沿 w 轴 = 纯第四维位移)。光线每条映射一次, 无振荡。
##   · 喉口附近光线弯曲: Schwarzschild 光子轨道伪牛顿积分 ——
##     爱因斯坦环 / 喉口边缘多重像 = 方程的涌现。
##   · 穿越观察者 = 飞越喉口球边界 (映射为等距变换, 边界两侧图像衔接, 无突变)。
##
## 喉口对: M1(B 层) ↔ M2(C 层) 跨层虫洞; M3 ↔ M4 (同在 B 层) 快速通道。
##
## 自动化截图:
##   godot --path . -- --shot=<png> [--shot-pos=x,y,z,w] [--shot-yaw=deg]
##        [--shot-pitch=deg] [--shot-ana-yaw=deg] [--shot-ana-pitch=deg]
##        [--shot-mode=0|1] [--ss=1.5]

const THROAT_R := 3.0            # 喉口球半径 mouth_r
const FLOOR_Z := -2.0
const SHEET_W := [-24.0, 0.0, 24.0]   # 三张平行层的 w

# ---- 喉口对 (与 shaders/wormhole4d.gdshader 的 M1..M4 保持一致) ----
const MOUTH_PAIRS: Array = [
	[Vector4(30.0, 3.0, -40.0, 0.0), Vector4(30.0, 3.0, -40.0, 24.0)],   # 跨层: B ↔ C
	[Vector4(-120.0, 3.0, 60.0, 0.0), Vector4(120.0, 3.0, 60.0, 0.0)],   # B 层内快速通道
]

const UNI_NAMES := ["宇宙A (冷)", "宇宙B (家)", "宇宙C (暖·远)"]
const MODE_NAMES := ["① 第一人称", "② 楼层图 (x,w)"]

const HELP_TEXT := """V 楼层图 (x,w) — 三层平行宇宙与四个喉口的位置图 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标
── 四维转动 (按住): I/K 俯仰进入±w (看进第四维)   J/L 横滚进入±w   U/O 偏摆进入±w ──
三个平行宇宙层 (w 轴上): A (w=-24, 冷) / B (w=0, 家) / C (w=+24, 暖·远)
· 右前方的球形窗口 = 虫洞喉口: 透过它看到的是另一个宇宙 (色温不同)
· 飞进窗口 → 到达那一层宇宙 (映射为等距变换, 无画面突变); 回头可返回
· 喉口附近星光被弯成爱因斯坦环; 楼层图 (V) 显示四张层的位置与喉口"""

# 相机: 4D 自由飞行, 4D 正交标架 (0=fwd 1=right 2=up 3=ana)
var pos := Vector4(0.0, 1.7, 2.0, 0.0)
var frame: Array[Vector4] = [
	Vector4(0.0, 0.0, -1.0, 0.0),   # fwd    -z (指向喉口方向由 _init_frame 修正)
	Vector4(1.0, 0.0, 0.0, 0.0),    # right
	Vector4(0.0, 0.0, 1.0, 0.0),    # up     +z (层内竖直)
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
var sheet := 1                 # 当前所在层 (0=A 1=B 2=C)
var mouth_used := [false, false]

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
	toast.text = "点击窗口捕获鼠标 → 右前方是通往宇宙 C 的球形喉口; 按 I/J 把视线转入第四维"


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


## 初始标架: fwd 指向 B→C 喉口 (层内方向), up = 层内竖直 (+z), right/ana 补全
func _init_frame() -> void:
	var to_mouth := MOUTH_PAIRS[0][0] - pos
	to_mouth.w = 0.0
	frame[0] = to_mouth.normalized()
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


func _nearest_sheet(w: float) -> int:
	if w < -12.0:
		return 0
	if w < 12.0:
		return 1
	return 2


## 喉口穿越 (玩家版, 与着色器同一映射): 向内飞越喉口球边界 → 平移到对侧球。
## 映射是等距变换 (纯平移), 边界两侧图像衔接 —— 无画面突变。
func _mouth_teleport() -> void:
	for mi in MOUTH_PAIRS.size():
		var a: Vector4 = MOUTH_PAIRS[mi][0]
		var b: Vector4 = MOUTH_PAIRS[mi][1]
		var da := (pos - a).length()
		var db := (pos - b).length()
		if mouth_used[mi]:
			# 离开这对喉口球域后重置 (允许再次使用)
			if da > THROAT_R * 1.3 and db > THROAT_R * 1.3:
				mouth_used[mi] = false
			continue
		var into_a := vel.dot(a - pos) > 0.0
		var into_b := vel.dot(b - pos) > 0.0
		if da < THROAT_R * 0.98 and da < db and into_a:
			pos += b - a
			mouth_used[mi] = true
			sheet = _nearest_sheet(pos.w)
			_flash("穿过虫洞 → %s" % UNI_NAMES[sheet])
		elif db < THROAT_R * 0.98 and db < da and into_b:
			pos += a - b
			mouth_used[mi] = true
			sheet = _nearest_sheet(pos.w)
			_flash("穿过虫洞 → %s" % UNI_NAMES[sheet])


## 三张层的地板碰撞 (2-平面, 推向最近侧)
func _floor_collide() -> void:
	for si in 3:
		var wi: float = SHEET_W[si]
		var dz := pos.z - FLOOR_Z
		var dw := pos.w - wi
		var d := sqrt(dz * dz + dw * dw)
		if d < 0.35 and d > 0.0001:
			var nz := dz / d
			var nw := dw / d
			var push := 0.35 - d
			pos.z += nz * push
			pos.w += nw * push
			var vn := vel.z * nz + vel.w * nw
			if vn < 0.0:
				vel.z -= nz * vn
				vel.w -= nw * vn


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
		_rot_pair(1, 3, rot_speed * delta)    # 横滚进入 +w
	if Input.is_key_pressed(KEY_L):
		_rot_pair(1, 3, -rot_speed * delta)
	if Input.is_key_pressed(KEY_U):
		_rot_pair(2, 3, rot_speed * delta)    # 偏摆进入 +w
	if Input.is_key_pressed(KEY_O):
		_rot_pair(2, 3, -rot_speed * delta)
	if Input.is_key_pressed(KEY_G):
		_rot_pair(0, 3, rot_speed * 0.8 * delta)
		_rot_pair(1, 2, -rot_speed * 0.8 * delta)
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

	# ---- 地板碰撞 + 喉口穿越 ----
	_floor_collide()
	_mouth_teleport()

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
	mat.set_shader_parameter("mouth_r", THROAT_R)


func _update_hud(delta: float) -> void:
	coord_label.text = "[color=#ff8a80]X[/color] %+.1f    [color=#7ee787]Y[/color] %+.1f    [color=#79c0ff]Z[/color] %+.1f    [color=#d2a8ff]W[/color] %+.1f" % [
		pos.x, pos.y, pos.z, pos.w]
	var uni: String = UNI_NAMES[_nearest_sheet(pos.w)]
	pos_label.text = "[%s]  宇宙 %s   w %+.1f   速度 %.1f   SS %.1fx" % [
		MODE_NAMES[view_mode], uni, pos.w, speed, ss]
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
