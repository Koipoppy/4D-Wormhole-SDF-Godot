extends Node
## 四维空间 SDF 引擎 + 虫洞 —— 平行层 + 圆盘喉口 (v22)
##
## 世界模型:
##   · 两个宇宙 = w 轴上的两张平行层: B (w=0, 家) / C (w=+24, 远·暖)。
##     每层是平直 3D 空间: 地板超平面 {z=-2, w=w_i} 的精确 2-平面距离场。
##   · 虫洞口 = 圆盘 (半径 3m): 一对圆盘位于同一 (x,y,z)、只差 w ——
##     跨越盘面平面且交点在盘内时执行平移映射 p.w ±= 24 (方向不变)。
##     映射发生在盘面上 (零厚度喉极限), 等距变换 ⇒ 盘面两侧图像严格衔接:
##     穿越时前向视野与回望视野均连续 —— 无画面突变, 不是传送。
##   · 第二对圆盘同在 B 层 (x=±120) = 同层快速远距通道 (Δ = 240m)。
##   · 喉口附近光线弯曲: Schwarzschild 光子轨道伪牛顿积分 ——
##     爱因斯坦环 / 盘缘多重像 = 方程的涌现。
##
## 自动化截图:
##   godot --path . -- --shot=<png> [--shot-pos=x,y,z,w] [--shot-yaw=deg]
##        [--shot-pitch=deg] [--shot-mode=0|1] [--ss=1.5]

# ---- 世界常量 (与 shaders/wormhole4d.gdshader 保持一致) ----
const SHEET_W := [0.0, 24.0]                  # 两张平行层的 w: B=0 / C=24
const FLOOR_Z := -2.0
const DISC_Z := 3.0                           # 跨层虫洞对的盘面 z (悬空 5m)
const DISC_XY := Vector2(30.0, -40.0)         # 盘心 (x,y)
const EX_X1 := -120.0                         # 快速通道 E1 盘面 x
const EX_X2 := 120.0                          # 快速通道 E2 盘面 x
const EX_YZ := Vector2(0.0, 3.0)              # 快速通道盘心 (y,z)
const MOUTH_R := 3.0

const MODE_NAMES := ["① 第一人称", "② 楼层图 (x,w)"]
const UNI_NAMES := ["宇宙B (家)", "宇宙C (远·暖)"]

const HELP_TEXT := """V 楼层图 (x,w) — 两层平行宇宙与圆盘喉口的位置 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | 滚轮 调速 | Q/E 翻滚 | Esc 释放鼠标
── 四维转动 (按住): I/K 俯仰进入±w (看进第四维)   J/L 横滚   U/O 偏摆   G 等角双旋转 ──
两张平行层沿 w 轴堆叠: B (w=0, 家) / C (w=+24, 远·暖), 层与层之间是 4D 体空间。
· 右前方的圆形窗口 = 跨层虫洞喉口: 透过它看到的是宇宙 C (暖色)
· 飞越窗口平面 → 到达宇宙 C (映射为等距变换, 盘面两侧图像严格衔接, 无突变)
· 喉口附近星光被弯成爱因斯坦环; 楼层图 (V) 显示两层与喉口的位置"""

# 相机: 4D 自由飞行, 4D 正交标架 (0=fwd 1=right 2=up 3=ana)
# 层内竖直方向 = +z (地板 z=-2), 水平面 = (x,y)
var pos := Vector4(0.0, 1.7, 4.0, 0.0)
var frame: Array[Vector4] = [
	Vector4(1.0, 0.0, 0.0, 0.0),    # fwd    +x (水平, 指向喉口方向由 _init_frame 修正)
	Vector4(0.0, -1.0, 0.0, 0.0),   # right  -y
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
var sheet := 1                 # 当前所在层 (0=B 1=C)
var used_bc := false            # 跨层虫洞: 本条"旅程"已使用 (离开盘面区域后重置)
var used_ex := false            # 快速通道: 同上

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
		pos = shot_pos
	_init_frame()
	if shot_yaw != 0.0:
		_rot_pair(0, 1, shot_yaw)       # 正 = 向右转
	if shot_pitch != 0.0:
		_rot_pair(0, 2, shot_pitch)     # 正 = 抬头
	if shot_mode >= 0:
		view_mode = shot_mode
	if shot_ss > 0.0:
		ss = shot_ss
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "点击窗口捕获鼠标 → 右前方是跨层虫洞窗口 (通向宇宙 C); V 看楼层图"


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


## 初始标架: fwd 指向 B→C 喉口圆盘 (层内水平方向), up = 层内竖直 (+z), right = fwd × up
func _init_frame() -> void:
	var to_mouth := Vector4(30.0, -40.0, 3.0, 0.0) - pos
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


func _nearest_sheet(w: float) -> int:
	return 0 if w < 12.0 else 1


## 喉口平面穿越 (玩家版, 与着色器同一映射): 跨越盘面平面且交点在盘内
## → 沿 w 平移到对侧层。映射发生在盘面上 (零厚度喉极限),
## 等距变换保证盘面两侧图像严格衔接 —— 无缝, 无传送感。
func _portal_cross(prev: Vector4) -> void:
	# ---- 跨层对 (B ↔ C): 平面 z = DISC_Z ----
	if not used_bc and (prev.z - DISC_Z) * (pos.z - DISC_Z) < 0.0:
		var t := (DISC_Z - prev.z) / (pos.z - prev.z)
		var pc := prev.lerp(pos, t)
		var off := Vector2(pc.x - DISC_XY.x, pc.y - DISC_XY.y)
		if off.length() < MOUTH_R:
			pos.w += (24.0 if pos.w < 12.0 else -24.0)
			used_bc = true
			sheet = _nearest_sheet(pos.w)
			_flash("穿过跨层虫洞 → %s" % UNI_NAMES[sheet])
	# ---- 快速通道对 (B 层内): 平面 x = ±120 ----
	if not used_ex:
		if (prev.x - EX_X1) * (pos.x - EX_X1) < 0.0:
			var t2 := (EX_X1 - prev.x) / (pos.x - prev.x)
			var pc2 := prev.lerp(pos, t2)
			var off2 := Vector2(pc2.y - EX_YZ.x, pc2.z - EX_YZ.y)
			if off2.length() < MOUTH_R:
				pos.x += EX_X2 - EX_X1
				used_ex = true
				_flash("穿过快速通道 → 到达 +240m 处")
		elif (prev.x - EX_X2) * (pos.x - EX_X2) < 0.0:
			var t3 := (EX_X2 - prev.x) / (pos.x - prev.x)
			var pc3 := prev.lerp(pos, t3)
			var off3 := Vector2(pc3.y - EX_YZ.x, pc3.z - EX_YZ.y)
			if off3.length() < MOUTH_R:
				pos.x += EX_X1 - EX_X2
				used_ex = true
				_flash("穿过快速通道 → 返回 -240m 处")


func _process(delta: float) -> void:
	time_s += delta

	# ---- 翻滚 (right, up) ----
	if Input.is_key_pressed(KEY_Q):
		_rot_pair(1, 2, rot_speed * delta)
	if Input.is_key_pressed(KEY_E):
		_rot_pair(1, 2, -rot_speed * delta)
	# ---- 四维转动: 视线进入 ±w ----
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
	var prev := pos
	pos += vel * delta

	# ---- 喉口平面穿越 (与着色器同一映射) ----
	_portal_cross(prev)

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
	mat.set_shader_parameter("mouth_r", MOUTH_R)


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
