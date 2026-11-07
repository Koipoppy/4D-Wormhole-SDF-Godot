extends Node
## 虫洞沙盒地图 —— 基于动态 Ellis 场景 (04)
##
## 初始 b₀=0: 空间是平直平面 w=0 (无虫洞)。
## 左键在视线前方放置虫洞入口 C，b₀ 长到 3，Ellis 喉口出现；
## 再次左键移动入口，右键/X 删除；删除时 b₀→0，空间回到平直。
## 玩家沿同一张 Ellis 流形连续穿过喉口，没有 portal 转移。
##
## 自动化截图:
##   godot --path . res://scenes/wormhole_map.tscn -- --shot=<png> [--shot-frame=N]
##        [--shot-pos=x,y,z,w] [--shot-yaw=deg] [--shot-pitch=deg] [--ss=1.5]

const B0 := 3.0          # Morris–Thorne 喉半径 b₀
const FLAT_EPS := 0.02   # b₀ 低于此值直接切换为平直平面 w=0
const AIM_DIST := 8.0    # 左键放置虫洞入口的距离
var b0 := 0.0            # 初始无虫洞: 平直空间
var b0_target := 0.0     # 0 = 无虫洞, B0 = 完整 Ellis 喉口
var created := false     # 当前是否已创建虫洞
var entrance_c := Vector3.ZERO   # 入口中心在房间中的位置
var vis := 0.0           # b₀/B0
var flat_side := 1.0     # 平直时保留的房间颜色: 1 红 / 0 蓝
const DIAGRAM_LIFT := 8.0   # 嵌入图中虫洞相对方格平面的悬浮高度 (ρ 单位)
const ROOM_C := Vector3(20.0, 0.0, 0.0)   # 沙盒房间中心
const ROOM_L := 14.0    # 房间半边长
const OBS1_C := Vector3(26.0, 8.0, -11.0)
const OBS1_H := Vector3(4.0, 4.0, 3.0)
const OBS2_C := Vector3(14.0, -8.0, -11.0)
const OBS2_H := Vector3(4.0, 4.0, 3.0)
const OBS3_C := Vector3(20.0, 0.0, -10.0)
const OBS3_H := Vector3(1.6, 1.6, 4.0)
const ROOM_W := 6.0     # 房间中心 / 喉口所在 |w|

# ---- 传送门物品（参照 optozorax/portal 的经典门 / 三重门 / 莫比乌斯门）----
const PORTAL_R := 1.25
const TOOL_NAMES := ["经典双门", "三重门", "虫洞枪", "莫比乌斯门", "预留"]
const PORTAL_COLORS := [
	[Color(0.35, 0.72, 0.93), Color(0.97, 0.60, 0.20)],
	[Color(0.35, 0.72, 0.93), Color(0.97, 0.60, 0.20), Color(0.55, 0.86, 0.60)],
	[],
	[Color(0.72, 0.55, 1.0), Color(0.55, 0.90, 1.0)],
	[],
]
var tool := 2                  # 当前物品；2 = 原来的虫洞枪
var portal_slots: Array = []   # 当前工具的门口；Dictionary 或 null
var triple_next := 0
var portal_cooldown := 0.0
var inv: InventoryBar

const MODE_NAMES := ["① 房间", "② 嵌入图 (w,ρ)"]

const HELP_TEXT := """虫洞沙盒 | 左键 创建/移动虫洞入口 | 右键/X 删除虫洞 | V 嵌入图 | F 超采样
鼠标 转身 | WASD 移动 | Space/C 升降 | Shift+滚轮 调速 | Q/E 翻滚 | Esc 菜单
初始空间是平直的 (b₀=0)；左键在视线前方 8m 放置入口 C:
· b₀ 长到 3，Ellis 喉口在 C 处出现；玩家沿同一张流形连续穿过到另一个房间
· 再次左键移动入口；右键/X 删除后 b₀→0，空间恢复到平直
· 平直房间保留你所在侧的红/蓝颜色；V 嵌入图显示 (w,ρ) 剖面"""

# 相机状态: 4D 位置 + 4D 正交标架 (n_axis = 超曲面法线, 其余三个切向)
# 初始: 悬浮在宇宙B (w=+6) 的悬链面上空, 朝漏斗轴心 (−w) 看: 前方是喉口与宇宙A
var pos := Vector4(20.0, -10.0, 2.0, 6.0)
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
	inv = get_node_or_null("UILayer/InventoryBar") as InventoryBar
	if inv != null:
		inv.item_selected.connect(_on_tool_selected)
	get_viewport().size_changed.connect(_restyle_hud)
	screen.texture = sub.get_texture()
	get_viewport().size_changed.connect(_apply_scale)
	_parse_shot_args()
	# 初始无虫洞: b₀=0，空间是平直平面 w=0
	b0 = 0.0
	b0_target = 0.0
	created = false
	entrance_c = Vector3(20.0, 0.0, 0.0)
	if shot_pos_set:
		pos = surf_project(shot_pos)
	else:
		pos = surf_project(pos)
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
	if "--wormhole-demo" in OS.get_cmdline_user_args():
		_create_or_move_wormhole()
	if "--portal-demo-triple" in OS.get_cmdline_user_args():
		_setup_portal_demo_triple()
	elif "--portal-demo-mobius" in OS.get_cmdline_user_args():
		_setup_portal_demo_mobius()
	elif "--portal-demo" in OS.get_cmdline_user_args():
		_setup_portal_demo()
	help_label.text = HELP_TEXT
	toast.text = "点击窗口捕获鼠标 → 左键在视线前方创建虫洞；右键/X 删除，空间回到平直"


func _restyle_hud() -> void:
	four_axis = UIStyle.apply_hud(self)


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
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_use_left()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_use_right()
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
		elif event.keycode == KEY_X:
			_use_clear()


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


## 左键放置/移动虫洞入口: 视线前方 8m，再夹到房间内。
func _aim_point() -> Vector3:
	var d := Vector3(fwd.x, fwd.y, fwd.z)
	if d.length_squared() < 0.000001:
		d = Vector3(0.0, 1.0, 0.0)
	var p := Vector3(pos.x, pos.y, pos.z) + d.normalized() * AIM_DIST
	return Vector3(
		clampf(p.x, ROOM_C.x - ROOM_L + 3.0, ROOM_C.x + ROOM_L - 3.0),
		clampf(p.y, ROOM_C.y - ROOM_L + 3.0, ROOM_C.y + ROOM_L - 3.0),
		clampf(p.z, ROOM_C.z - ROOM_L + 3.0, ROOM_C.z + ROOM_L - 3.0))


func _create_or_move_wormhole() -> void:
	var aim := _aim_point()
	var safe := _safe_entrance(aim)
	entrance_c = safe
	created = true
	b0_target = B0
	if safe.distance_to(aim) > 0.05:
		_flash("入口已避开障碍物")
	else:
		_flash("虫洞已创建 / 入口已移动")


## 保证喉口球 (半径 b0) 不和平台/柱子/墙体重叠，否则玩家穿喉时会被
## 实体碰撞推住，出现“在喉口卡一下”。
func _safe_entrance(p: Vector3) -> Vector3:
	var clearance := B0 + 0.6
	for iteration in 4:
		var moved := false
		for b in [[OBS1_C, OBS1_H], [OBS2_C, OBS2_H], [OBS3_C, OBS3_H]]:
			var c: Vector3 = b[0]
			var h: Vector3 = b[1]
			var q := Vector3(
				clampf(p.x, c.x - h.x, c.x + h.x),
				clampf(p.y, c.y - h.y, c.y + h.y),
				clampf(p.z, c.z - h.z, c.z + h.z))
			var d := p - q
			if d.length() >= clearance:
				continue
			if d.length_squared() < 0.000001:
				# 入口落在障碍物内部：沿最近的面推出去
				var px := h.x - absf(p.x - c.x)
				var py := h.y - absf(p.y - c.y)
				var pz := h.z - absf(p.z - c.z)
				if px <= py and px <= pz:
					p.x = c.x + signf(p.x - c.x) * (h.x + clearance)
				elif py <= pz:
					p.y = c.y + signf(p.y - c.y) * (h.y + clearance)
				else:
					p.z = c.z + signf(p.z - c.z) * (h.z + clearance)
			else:
				p = q + d.normalized() * clearance
			moved = true
		# 也留出到房间墙体的喉口半径
		var wc := 3.2
		p.x = clampf(p.x, ROOM_C.x - (ROOM_L - wc), ROOM_C.x + (ROOM_L - wc))
		p.y = clampf(p.y, ROOM_C.y - (ROOM_L - wc), ROOM_C.y + (ROOM_L - wc))
		p.z = clampf(p.z, ROOM_C.z - (ROOM_L - wc), ROOM_C.z + (ROOM_L - wc))
		if not moved:
			break
	return p


func _delete_wormhole() -> void:
	if not created:
		return
	created = false
	b0_target = 0.0
	_flash("虫洞已删除，空间回到平直")


# ============================================================================
#  传送门物品：经典双门 / 三重门 / 莫比乌斯门
#  参考 optozorax/portal 的 portal explorer 场景
# ============================================================================

func _on_tool_selected(idx: int) -> void:
	if idx == tool:
		return
	tool = idx
	portal_cooldown = 0.4
	if tool == 2:
		_clear_portals()
		_flash("虫洞枪：左键创建/移动，右键删除")
	elif tool == 0 or tool == 3:
		if created:
			_delete_wormhole()
		_clear_portals(false)
		portal_slots = [null, null]
		_flash("%s：左键 / 右键各放一个门" % TOOL_NAMES[tool])
	elif tool == 1:
		if created:
			_delete_wormhole()
		_clear_portals(false)
		portal_slots = [null, null, null]
		_flash("三重门：左键依次放 3 个门，右键清空")
	else:
		_clear_portals()
		_flash("这个槽位预留给后续物品")
	_push_uniforms()


func _use_left() -> void:
	match tool:
		0, 3:
			_place_pair(0)
		1:
			_place_triple()
		2:
			_create_or_move_wormhole()


func _use_right() -> void:
	match tool:
		0, 3:
			_place_pair(1)
		1:
			_clear_portals()
			_flash("三重门已清空")
		2:
			_delete_wormhole()


func _use_clear() -> void:
	if tool == 2:
		_delete_wormhole()
	else:
		_clear_portals()
		_flash("传送门已清空")


func _clear_portals(push := true) -> void:
	portal_slots.clear()
	triple_next = 0
	if push:
		_push_uniforms()


func _portals_active() -> bool:
	if portal_slots.is_empty():
		return false
	for p in portal_slots:
		if p == null:
			return false
	return true


func _portal_link(i: int) -> int:
	if tool == 1:
		return (i + 1) % 3
	return 1 - i


func _place_pair(slot: int) -> void:
	if portal_slots.size() != 2:
		portal_slots = [null, null]
	var rec := _make_portal(slot)
	if rec.is_empty():
		return
	portal_slots[slot] = rec
	_push_uniforms()
	var n := 0
	for p in portal_slots:
		if p != null:
			n += 1
	_flash("%s：%d / 2 已放置" % [TOOL_NAMES[tool], n])


func _place_triple() -> void:
	if portal_slots.size() != 3:
		portal_slots = [null, null, null]
	var i := 0
	while i < 3 and portal_slots[i] != null:
		i += 1
	if i >= 3:
		i = triple_next
		triple_next = (i + 1) % 3
	var rec := _make_portal(i)
	if rec.is_empty():
		return
	portal_slots[i] = rec
	_push_uniforms()
	var n := 0
	for p in portal_slots:
		if p != null:
			n += 1
	_flash("三重门：%d / 3 已放置" % n)


func _make_portal(slot: int) -> Dictionary:
	var hit := _raycast_surface()
	if hit.is_empty():
		_flash("没有瞄准可放置的表面")
		return {}
	var n: Vector3 = hit.normal
	var upv := Vector3(0, 0, 1)
	if absf(n.dot(upv)) > 0.92:
		upv = Vector3(0, 1, 0)
	upv = (upv - n * upv.dot(n)).normalized()
	var rightv := upv.cross(n).normalized()
	var colors: Array = PORTAL_COLORS[tool]
	var col: Color = colors[slot] if slot < colors.size() else Color.WHITE
	return {
		"center": hit.point + n * 0.04,
		"normal": n,
		"up": upv,
		"right": rightv,
		"radius": PORTAL_R,
		"roll": PI if tool == 3 else 0.0,
		"color": col,
	}


## 从相机沿视线找最近的房间墙或盒面（xyz 平直近似）。
func _raycast_surface() -> Dictionary:
	var o := Vector3(pos.x, pos.y, pos.z)
	var d := Vector3(fwd.x, fwd.y, fwd.z)
	if d.length_squared() < 0.000001:
		return {}
	d = d.normalized()
	var best := 1e20
	var best_p := Vector3.ZERO
	var best_n := Vector3.ZERO

	# 房间内壁（法线朝房间内）
	for axis in 3:
		for sgn in [-1, 1]:
			var da := _axis(d, axis)
			if absf(da) < 0.00001:
				continue
			var bound := _axis(ROOM_C, axis) + float(sgn) * ROOM_L
			var t := (bound - _axis(o, axis)) / da
			if t <= 0.02 or t >= best:
				continue
			var hp := o + d * t
			var inside := true
			for a2 in 3:
				if a2 == axis:
					continue
				if absf(_axis(hp, a2) - _axis(ROOM_C, a2)) > ROOM_L - 0.01:
					inside = false
			if not inside:
				continue
			var n := Vector3.ZERO
			if axis == 0:
				n.x = -float(sgn)
			elif axis == 1:
				n.y = -float(sgn)
			else:
				n.z = -float(sgn)
			best = t
			best_p = hp
			best_n = n

	# 平台 / 柱子（法线朝外）
	for b in [[OBS1_C, OBS1_H], [OBS2_C, OBS2_H], [OBS3_C, OBS3_H]]:
		var c: Vector3 = b[0]
		var h: Vector3 = b[1]
		var tmin := -1e20
		var tmax := 1e20
		var axis_hit := -1
		var sgn_hit := 0.0
		for a in 3:
			var da := _axis(d, a)
			if absf(da) < 0.00001:
				if _axis(o, a) < _axis(c, a) - _axis(h, a) or _axis(o, a) > _axis(c, a) + _axis(h, a):
					tmin = 1e20
				continue
			var inv := 1.0 / da
			var t1 := (_axis(c, a) - _axis(h, a) - _axis(o, a)) * inv
			var t2 := (_axis(c, a) + _axis(h, a) - _axis(o, a)) * inv
			var near := minf(t1, t2)
			var far := maxf(t1, t2)
			if near > tmin:
				tmin = near
				axis_hit = a
				sgn_hit = -signf(da)
			tmax = minf(tmax, far)
		if axis_hit < 0 or tmin > tmax or tmin <= 0.02 or tmin >= best:
			continue
		var n := Vector3.ZERO
		if axis_hit == 0:
			n.x = sgn_hit
		elif axis_hit == 1:
			n.y = sgn_hit
		else:
			n.z = sgn_hit
		best = tmin
		best_p = o + d * tmin
		best_n = n

	if best > 1e19:
		return {}
	return {"point": best_p, "normal": best_n}


func _axis(v: Vector3, i: int) -> float:
	if i == 0:
		return v.x
	if i == 1:
		return v.y
	return v.z


func _push_portal_uniforms() -> void:
	var centers := PackedVector4Array()
	var normals := PackedVector4Array()
	var rights := PackedVector4Array()
	var ups := PackedVector4Array()
	var colors := PackedVector4Array()
	centers.resize(5)
	normals.resize(5)
	rights.resize(5)
	ups.resize(5)
	colors.resize(5)
	for i in 5:
		centers[i] = Vector4.ZERO
		normals[i] = Vector4(0, 0, 0, -1)
		rights[i] = Vector4(1, 0, 0, 0)
		ups[i] = Vector4(0, 1, 0, 0)
		colors[i] = Vector4(0, 0, 0, 1)

	var count := 0
	if _portals_active():
		count = portal_slots.size()
		for i in count:
			var r: Dictionary = portal_slots[i]
			var c: Vector3 = r.center
			var n: Vector3 = r.normal
			var rr: Vector3 = r.right
			var uu: Vector3 = r.up
			var col: Color = r.color
			centers[i] = Vector4(c.x, c.y, c.z, float(r.radius))
			normals[i] = Vector4(n.x, n.y, n.z, float(_portal_link(i)))
			rights[i] = Vector4(rr.x, rr.y, rr.z, float(r.roll))
			ups[i] = Vector4(uu.x, uu.y, uu.z, 0.0)
			colors[i] = Vector4(col.r, col.g, col.b, 1.0)

	mat.set_shader_parameter("portal_count", count)
	mat.set_shader_parameter("portal_center", centers)
	mat.set_shader_parameter("portal_normal", normals)
	mat.set_shader_parameter("portal_right", rights)
	mat.set_shader_parameter("portal_up", ups)
	mat.set_shader_parameter("portal_color", colors)


func _check_portal_teleport(prev: Vector4, now: Vector4) -> void:
	if not _portals_active():
		return
	var p0 := Vector3(prev.x, prev.y, prev.z)
	var p1 := Vector3(now.x, now.y, now.z)
	var move := p1 - p0
	if move.length_squared() < 0.000001:
		return
	for i in portal_slots.size():
		var r: Dictionary = portal_slots[i]
		var c: Vector3 = r.center
		var n: Vector3 = r.normal
		var d0 := (p0 - c).dot(n)
		var d1 := (p1 - c).dot(n)
		if d0 <= 0.0 or d1 >= d0 or d1 > 0.06:
			continue
		var rel := p1 - c
		var lat := rel - n * rel.dot(n)
		if lat.length() > float(r.radius) * 0.95:
			continue
		if move.normalized().dot(n) >= -0.05:
			continue
		_teleport_player(i)
		return


func _teleport_player(i: int) -> void:
	var entry: Dictionary = portal_slots[i]
	var exit: Dictionary = portal_slots[_portal_link(i)]
	var p1 := Vector3(pos.x, pos.y, pos.z)
	var rel := p1 - Vector3(entry.center)
	var lx := rel.dot(Vector3(entry.right))
	var ly := rel.dot(Vector3(entry.up))
	var lz := rel.dot(Vector3(entry.normal))
	var roll: float = entry.roll
	var cr := cos(roll)
	var sr := sin(roll)
	var rx := -lx * cr - ly * sr
	var ry := -lx * sr + ly * cr
	# 把入口相机所在的位置完整映射到出口，再加法线与着色器一致的 0.10 m。
	# 这样传送后的相机就是门内画面所用的虚拟相机，视角不会跳。
	var rz := -lz + 0.10
	var np: Vector3 = Vector3(exit.center) + Vector3(exit.right) * rx + Vector3(exit.up) * ry + Vector3(exit.normal) * rz
	pos = surf_project(Vector4(np.x, np.y, np.z, pos.w))
	var speed_now := vel.length()
	fwd = _portal_dir(fwd, entry, exit, roll)
	right = _portal_dir(right, entry, exit, roll)
	up = _portal_dir(up, entry, exit, roll)
	n_axis = surf_normal(pos)
	_make_ortho()
	vel = _portal_dir(vel, entry, exit, roll)
	vel -= n_axis * vel.dot(n_axis)
	if vel.length_squared() > 0.000001:
		vel = vel.normalized() * speed_now
	portal_cooldown = 0.8
	_flash("穿过 %s" % TOOL_NAMES[tool])


func _portal_dir(v: Vector4, entry: Dictionary, exit: Dictionary, roll: float) -> Vector4:
	var er := Vector3(entry.right)
	var eu := Vector3(entry.up)
	var en := Vector3(entry.normal)
	var xr := Vector3(v.x, v.y, v.z)
	var lx := xr.dot(er)
	var ly := xr.dot(eu)
	var lz := xr.dot(en)
	lx = -lx
	lz = -lz
	var cr := cos(roll)
	var sr := sin(roll)
	var rx := lx * cr - ly * sr
	var ry := lx * sr + ly * cr
	var out := Vector3(exit.right) * rx + Vector3(exit.up) * ry + Vector3(exit.normal) * lz
	return Vector4(out.x, out.y, out.z, 0.0)


func _setup_portal_demo() -> void:
	tool = 0
	portal_slots = [
		{
			"center": Vector3(20, 14, 2), "normal": Vector3(0, -1, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(1, 0, 0),
			"radius": PORTAL_R, "roll": 0.0, "color": PORTAL_COLORS[0][0],
		},
		{
			"center": Vector3(34, 0, 2), "normal": Vector3(-1, 0, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(0, -1, 0),
			"radius": PORTAL_R, "roll": 0.0, "color": PORTAL_COLORS[0][1],
		},
	]
	_push_uniforms()
	_flash("DEMO：经典双门")


func _setup_portal_demo_triple() -> void:
	tool = 1
	portal_slots = [
		{
			"center": Vector3(20, 14, 2), "normal": Vector3(0, -1, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(1, 0, 0),
			"radius": PORTAL_R, "roll": 0.0, "color": PORTAL_COLORS[1][0],
		},
		{
			"center": Vector3(34, 0, 2), "normal": Vector3(-1, 0, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(0, -1, 0),
			"radius": PORTAL_R, "roll": 0.0, "color": PORTAL_COLORS[1][1],
		},
		{
			"center": Vector3(6, 0, 2), "normal": Vector3(1, 0, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(0, 1, 0),
			"radius": PORTAL_R, "roll": 0.0, "color": PORTAL_COLORS[1][2],
		},
	]
	_push_uniforms()
	_flash("DEMO：三重门")


func _setup_portal_demo_mobius() -> void:
	tool = 3
	portal_slots = [
		{
			"center": Vector3(20, 14, 2), "normal": Vector3(0, -1, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(1, 0, 0),
			"radius": PORTAL_R, "roll": PI, "color": PORTAL_COLORS[3][0],
		},
		{
			"center": Vector3(34, 0, 2), "normal": Vector3(-1, 0, 0),
			"up": Vector3(0, 0, 1), "right": Vector3(0, -1, 0),
			"radius": PORTAL_R, "roll": PI, "color": PORTAL_COLORS[3][1],
		},
	]
	_push_uniforms()
	_flash("DEMO：莫比乌斯门")


func box_sdf(p: Vector4, c: Vector3, h: Vector3) -> float:
	var d := Vector3(absf(p.x - c.x) - h.x, absf(p.y - c.y) - h.y, absf(p.z - c.z) - h.z)
	return maxf(d.x, maxf(d.y, d.z))


func box_normal(p: Vector4, c: Vector3, h: Vector3) -> Vector4:
	var d := Vector3(absf(p.x - c.x) - h.x, absf(p.y - c.y) - h.y, absf(p.z - c.z) - h.z)
	if d.x >= d.y and d.x >= d.z:
		return Vector4(signf(p.x - c.x), 0.0, 0.0, 0.0)
	if d.y >= d.z:
		return Vector4(0.0, signf(p.y - c.y), 0.0, 0.0)
	return Vector4(0.0, 0.0, signf(p.z - c.z), 0.0)


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
	fwd = Vector4(ROOM_C.x, ROOM_C.y, ROOM_C.z, room_center_w) - pos
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
	portal_cooldown = maxf(portal_cooldown - delta, 0.0)

	# ---- 创建/删除: b₀ 平滑长到 3 或回到 0 ----
	var prev_b0 := b0
	b0 = lerpf(b0, b0_target, 1.0 - exp(-3.0 * delta))
	if b0 < FLAT_EPS and prev_b0 >= FLAT_EPS:
		flat_side = 1.0 if pos.w >= 0.0 else 0.0
	if absf(b0 - prev_b0) > 0.00001:
		_snap_player_to_surface()
		var nn := surf_normal(pos)
		vel -= nn * vel.dot(nn)
	vis = clampf(b0 / B0, 0.0, 1.0)

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
	# 传送门模式下把碰撞余量压到 4 cm，让玩家能贴到门面再穿过去；
	# 正常的虫洞模式仍保留 0.8 m 的舒适距离。
	var portal_mode := tool != 2 and _portals_active()
	var margin := 0.04 if portal_mode else 0.8
	var lim := ROOM_L - margin
	pos.x = clampf(pos.x, ROOM_C.x - lim, ROOM_C.x + lim)
	pos.y = clampf(pos.y, ROOM_C.y - lim, ROOM_C.y + lim)
	pos.z = clampf(pos.z, ROOM_C.z - lim, ROOM_C.z + lim)

	# ---- 平台/柱子碰撞 ----
	var bmargin := 0.04 if portal_mode else 0.35
	var d1 := box_sdf(pos, OBS1_C, OBS1_H)
	if d1 < bmargin:
		pos += box_normal(pos, OBS1_C, OBS1_H) * (bmargin - d1)
	var d2 := box_sdf(pos, OBS2_C, OBS2_H)
	if d2 < bmargin:
		pos += box_normal(pos, OBS2_C, OBS2_H) * (bmargin - d2)
	var d3 := box_sdf(pos, OBS3_C, OBS3_H)
	if d3 < bmargin:
		pos += box_normal(pos, OBS3_C, OBS3_H) * (bmargin - d3)

	if tool != 2 and portal_cooldown <= 0.0 and _portals_active():
		_check_portal_teleport(prev, pos)

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
	_push_portal_uniforms()


func _update_hud(delta: float) -> void:
	var u := 0.0
	var k2 := 0.0
	var state := "无虫洞（平直）" if not created else ("生成中" if b0 < B0 * 0.9 else "虫洞存在")
	var uni := "红房间 (w>0)" if pos.w > 0.0 else "蓝房间 (w<0)"
	if b0 >= FLAT_EPS:
		u = pos.w / b0
		k2 = -1.0 / (b0 * b0)
	else:
		state = "无虫洞（平直）" if not created else "消失中"
		uni = "平直空间（红）" if flat_side > 0.5 else "平直空间（蓝）"
	var q := Vector3(pos.x - entrance_c.x, pos.y - entrance_c.y, pos.z - entrance_c.z)
	var lift_txt := ("   h %.1f" % DIAGRAM_LIFT) if view_mode == 1 else ""
	if four_axis != null:
		four_axis.set_frame(pos, fwd, right, up, n_axis)
	pos_label.text = "[%s]  u %+.2f   w %7.1f   ρ %6.1f%s   入口 C (%+.1f, %+.1f, %+.1f)   b₀ %.2f   K₂ %+.3f   %s   %s   工具 %s   速度 %.1f   SS %.1fx" % [
		MODE_NAMES[view_mode], u, pos.w, q.length(), lift_txt,
		entrance_c.x, entrance_c.y, entrance_c.z, b0, k2, state, uni, TOOL_NAMES[tool], speed, ss]
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
