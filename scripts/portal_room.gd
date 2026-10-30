extends Node
## v51: one flat room, two spherical mouths, explicit teleport loop.
##
##   mouth A -> throat (teleport) -> mouth B -> room -> mouth A
##
## The two mouths live in the same room. Entering either sphere moves the
## camera to the same angular point on the other sphere, with the velocity and
## view frame reflected across the sphere normal. The player can then fly
## through the room back to the first mouth, closing the loop. This is a fresh
## implementation for v51; it does not use the old portal / 4D code.

const PM = preload("res://scripts/portal_math.gd")

const MOUTH_A := Vector3(-4.0, 2.2, -3.0)
const MOUTH_B := Vector3(4.0, 2.2, -3.0)
const MOUTH_R := 2.0

const ROOM_CENTER := Vector3(0.0, 3.0, 0.0)
const ROOM_HALF := Vector3(12.0, 3.0, 12.0)
const START_POS := Vector3(0.0, 1.7, 8.0)

const CONTROL_LOCK := 0.12
const LOOP_MIN_TIME := 0.3

const HELP_TEXT := """v51 同房间双口传送 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | Q/E 翻滚 | 滚轮 调速 | Esc 释放鼠标
· 青色球口 A 与橙色球口 B 是同一个房间里的两个口
· 进入任一口 = 经喉（传送）从另一口的外侧出来；位置连续，没有瞬移跳点
· 完成一圈：口A → 喉(传送) → 口B → 沿房间飞回口A → 再次进入口A
· 每次传送左右手会翻转（HUD 的手性 +/−）"""

var pos := START_POS
var fwd := Vector3(0.0, 0.0, -1.0)
var right := Vector3(1.0, 0.0, 0.0)
var up := Vector3(0.0, 1.0, 0.0)
var vel := Vector3.ZERO
var speed := 6.0
var mouse_sens := 0.0021
var rot_speed := 1.2
var ss := 1.0
var captured := false
var time_s := 0.0

var handedness := 1          # +1 right-handed, -1 after a teleport
var control_lock := 0.0
var pending_return := -1     # mouth index the player should return to
var pending_timer := 0.0
var teleports := 0
var loops := 0
var flash := 0.0

# screenshot args
var shot_path := ""
var shot_frame := 40
var shot_pos := Vector3.ZERO
var shot_pos_set := false
var shot_look := Vector3.ZERO
var shot_look_set := false
var shot_yaw := 0.0
var shot_pitch := 0.0
var shot_ss := 0.0
var frame_count := 0

@onready var sub: SubViewport = $SubViewport
@onready var screen: TextureRect = $UILayer/Screen
@onready var mat: ShaderMaterial = $SubViewport/View.material
@onready var pos_label: Label = $UILayer/PosLabel
@onready var help_label: Label = $UILayer/HelpLabel
@onready var toast: Label = $UILayer/Toast


func _ready() -> void:
	screen.texture = sub.get_texture()
	get_viewport().size_changed.connect(_apply_scale)
	_parse_shot_args()

	pos = shot_pos if shot_pos_set else START_POS
	_clamp_room()
	if shot_look_set:
		_look_at(shot_look)
	else:
		fwd = Vector3(0.0, 0.0, -1.0)
		right = Vector3(1.0, 0.0, 0.0)
		up = Vector3(0.0, 1.0, 0.0)
		handedness = 1
	if shot_yaw != 0.0:
		_yaw(-shot_yaw)
	if shot_pitch != 0.0:
		_pitch(shot_pitch)
	if shot_ss > 0.0:
		ss = shot_ss
	_orthonormalize()
	_apply_scale()
	help_label.text = HELP_TEXT
	toast.text = "走进青色/橙色球口 → 喉（传送）→ 另一个口；再沿房间飞回来完成一圈"
	toast.modulate.a = 1.0


func _parse_shot_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-frame="):
			shot_frame = int(a.substr(13))
		elif a.begins_with("--shot-pos="):
			var parts := a.substr(11).split(",")
			if parts.size() == 3:
				shot_pos = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
				shot_pos_set = true
		elif a.begins_with("--shot-look="):
			var lp := a.substr(12).split(",")
			if lp.size() == 3:
				shot_look = Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
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


func _look_at(target: Vector3) -> void:
	var d := target - pos
	if d.length_squared() < 1.0e-8:
		d = Vector3(0.0, 0.0, -1.0)
	fwd = d.normalized()
	right = fwd.cross(Vector3.UP)
	if right.length_squared() < 1.0e-8:
		right = fwd.cross(Vector3.RIGHT)
	right = right.normalized()
	up = right.cross(fwd).normalized()
	handedness = 1


func _orthonormalize() -> void:
	fwd = fwd.normalized()
	right = right - fwd * right.dot(fwd)
	if right.length_squared() < 1.0e-8:
		right = fwd.cross(Vector3.UP)
		if right.length_squared() < 1.0e-8:
			right = fwd.cross(Vector3.RIGHT)
	right = right.normalized()
	# Preserve the current handedness: a teleport reflection flips it.
	up = (right.cross(fwd) * float(handedness)).normalized()


func _yaw(ang: float) -> void:
	var c := cos(ang)
	var s := sin(ang)
	var nf := fwd * c + right * s
	var nr := -fwd * s + right * c
	fwd = nf
	right = nr


func _pitch(ang: float) -> void:
	var c := cos(ang)
	var s := sin(ang)
	var nf := fwd * c + up * s
	var nu := -fwd * s + up * c
	fwd = nf
	up = nu


func _roll(ang: float) -> void:
	var c := cos(ang)
	var s := sin(ang)
	var nr := right * c + up * s
	var nu := -right * s + up * c
	right = nr
	up = nu


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not captured:
			_set_captured(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(speed * 1.18, 80.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(speed / 1.18, 1.0)
	elif event is InputEventMouseMotion and captured:
		_yaw(event.relative.x * mouse_sens)
		_pitch(-event.relative.y * mouse_sens)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_captured(false)
		elif event.keycode == KEY_F:
			ss = 1.0 if ss >= 1.99 else (1.5 if ss < 1.49 else 2.0)
			_apply_scale()


func _set_captured(on: bool) -> void:
	captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	time_s += delta
	control_lock = maxf(control_lock - delta, 0.0)
	flash = maxf(flash - delta * 3.5, 0.0)
	pending_timer += delta

	# Safety / screenshot helper: a camera that starts inside a mouth is
	# immediately resolved to the other mouth instead of rendering from the
	# sphere interior.
	if pos.distance_to(MOUTH_A) < MOUTH_R:
		var na := pos - MOUTH_A
		_do_teleport(0, na.normalized() if na.length_squared() > 1.0e-8 else Vector3(0.0, 0.0, 1.0))
	elif pos.distance_to(MOUTH_B) < MOUTH_R:
		var nb := pos - MOUTH_B
		_do_teleport(1, nb.normalized() if nb.length_squared() > 1.0e-8 else Vector3(0.0, 0.0, 1.0))

	if Input.is_key_pressed(KEY_Q):
		_roll(rot_speed * delta)
	if Input.is_key_pressed(KEY_E):
		_roll(-rot_speed * delta)

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir += fwd
	if Input.is_key_pressed(KEY_S): dir -= fwd
	if Input.is_key_pressed(KEY_D): dir += right
	if Input.is_key_pressed(KEY_A): dir -= right
	if Input.is_key_pressed(KEY_SPACE): dir += up
	if Input.is_key_pressed(KEY_C): dir -= up

	var target := Vector3.ZERO
	if control_lock > 0.0:
		# After a teleport keep the reflected velocity for a moment so the
		# camera leaves the destination sphere instead of bouncing on it.
		target = vel
	elif dir.length_squared() > 1.0e-6:
		target = dir.normalized() * speed
	vel = vel.lerp(target, 1.0 - exp(-8.0 * delta))

	var next := pos + vel * delta
	var hit := PM.sweep_first(pos, next, [MOUTH_A, MOUTH_B], MOUTH_R)
	if not hit.is_empty():
		_do_teleport(int(hit["index"]), hit["normal"])
	else:
		pos = next

	_clamp_room()
	_orthonormalize()
	_push_uniforms()
	_update_hud(delta)
	_maybe_screenshot()


func _do_teleport(entry_index: int, entry_normal: Vector3) -> void:
	var to_c := MOUTH_B if entry_index == 0 else MOUTH_A

	# A loop is: enter mouth X -> teleport -> room -> enter mouth X again.
	if pending_return == entry_index and pending_timer > LOOP_MIN_TIME:
		loops += 1
		toast.text = "完成一圈：口%s → 喉（传送）→ 口%s → 房间 → 口%s" % [
			"A" if entry_index == 0 else "B",
			"B" if entry_index == 0 else "A",
			"A" if entry_index == 0 else "B"]
	else:
		toast.text = "喉（传送）：口%s → 口%s（左右手翻转）｜沿房间飞回口%s 完成一圈" % [
			"A" if entry_index == 0 else "B",
			"B" if entry_index == 0 else "A",
			"A" if entry_index == 0 else "B"]
	toast.modulate.a = 1.0

	var st := PM.teleport_state(vel, fwd, right, up, to_c, MOUTH_R, entry_normal)
	pos = st["pos"] as Vector3
	vel = st["vel"] as Vector3
	fwd = st["fwd"] as Vector3
	right = st["right"] as Vector3
	up = st["up"] as Vector3
	handedness = -handedness
	control_lock = CONTROL_LOCK
	pending_return = entry_index
	pending_timer = 0.0
	teleports += 1
	flash = 1.0


func _clamp_room() -> void:
	pos.x = clampf(pos.x, -ROOM_HALF.x + 0.4, ROOM_HALF.x - 0.4)
	pos.y = clampf(pos.y, 0.4, ROOM_CENTER.y * 2.0 - 0.4)
	pos.z = clampf(pos.z, -ROOM_HALF.z + 0.4, ROOM_HALF.z - 0.4)


func _push_uniforms() -> void:
	mat.set_shader_parameter("cam_pos", pos)
	mat.set_shader_parameter("cam_fwd", fwd)
	mat.set_shader_parameter("cam_right", right)
	mat.set_shader_parameter("cam_up", up)
	mat.set_shader_parameter("time_s", time_s)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("mouth_a", MOUTH_A)
	mat.set_shader_parameter("mouth_b", MOUTH_B)
	mat.set_shader_parameter("mouth_r", MOUTH_R)


func _update_hud(delta: float) -> void:
	var da := pos.distance_to(MOUTH_A)
	var db := pos.distance_to(MOUTH_B)
	var zone := "房间"
	if da < MOUTH_R + 1.2:
		zone = "口A 附近"
	elif db < MOUTH_R + 1.2:
		zone = "口B 附近"
	pos_label.text = "v51 同房间双口传送 | 口A(青) ↔ 喉(传送) ↔ 口B(橙) | %s | 传送 %d | 圈 %d | 手性 %s | SS %.1fx" % [
		zone, teleports, loops, "+" if handedness > 0 else "−", ss]
	toast.modulate.a = maxf(toast.modulate.a - delta * 0.55, 0.0)


func _maybe_screenshot() -> void:
	if shot_path == "":
		return
	frame_count += 1
	if frame_count >= shot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHOT_SAVED ", shot_path)
		get_tree().quit()
