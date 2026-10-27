extends SceneTree
## 无场景自检: 直接调用 main.gd 的球面虫洞过渡。
## 验证: 从球面各个方向进入都能到另一个球口外侧, 速度/视线向外反射;
##       从旁边掠过不会触发。

var fails := 0


func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)


func _try_enter(m, a: Vector4, b: Vector4, dir: Vector4, r: float, dt: float) -> Dictionary:
	var start: Vector4 = m.surf_project(a + dir * (r + 4.0))
	var approach: Vector4 = (a - start).normalized()
	m.pos = start
	m.vel = approach * 6.0
	m.n_axis = m.surf_normal(start)
	m.fwd = approach
	# 任意两个切向作为相机右/上, 只用于一起反射
	var N: Vector4 = m.surf_normal(a)
	var t1: Vector4 = Vector4(0.0, 1.0, 0.0, 0.0)
	t1 -= N * t1.dot(N)
	if t1.length_squared() < 1e-6:
		t1 = Vector4(0.0, 0.0, 1.0, 0.0) - N * N.z
	t1 = t1.normalized()
	var t2: Vector4 = Vector4(0.0, 0.0, 1.0, 0.0)
	t2 -= N * t2.dot(N) + t1 * t2.dot(t1)
	m.up = t1
	m.right = t2.normalized()
	var crossed := false
	for i in 300:
		var prev: Vector4 = m.pos
		m.pos += m.vel * dt
		var old: Vector4 = m.pos
		m._wh_cross(prev)
		if (m.pos - old).length_squared() > 1e-8:
			crossed = true
			break
	var dist_b: float = (m.pos - b).length()
	var outw: Vector4 = (m.pos - b).normalized()
	return {
		"crossed": crossed,
		"dist": dist_b,
		"outward": m.vel.dot(outw),
		"view": m.fwd.dot(-approach),
		"dot_side": (m.pos - b).dot(-approach),
	}


func _initialize() -> void:
	var Main = load("res://scripts/main.gd")
	var m = Main.new()
	m.toast = Label.new()
	m._build_wormholes()
	_check("wormhole enabled", m.wh_radius.size() >= 1 and m.wh_radius[0] > 0.0,
		"r=%.2f" % m.wh_radius[0])

	var a: Vector4 = m.wh_a[0]
	var b: Vector4 = m.wh_b[0]
	var r: float = m.wh_radius[0]
	var N: Vector4 = m.surf_normal(a)
	var t1: Vector4 = Vector4(0.0, 1.0, 0.0, 0.0)
	t1 -= N * t1.dot(N)
	if t1.length_squared() < 1e-6:
		t1 = Vector4(0.0, 0.0, 1.0, 0.0) - N * N.z
	t1 = t1.normalized()
	var t2: Vector4 = Vector4(0.0, 0.0, 1.0, 0.0)
	t2 -= N * t2.dot(N) + t1 * t2.dot(t1)
	t2 = t2.normalized()
	var t3: Vector4 = (t1 + t2).normalized()
	var dirs: Array = [t1, -t1, t2, -t2, t3, -t3, (t1 - t2).normalized()]
	var dt := 1.0 / 60.0
	var idx := 0
	for dir in dirs:
		var d: Vector4 = dir
		var res := _try_enter(m, a, b, d, r, dt)
		var ok: bool = bool(res["crossed"]) \
			and float(res["dist"]) > r - 0.02 \
			and float(res["dist"]) < r + 1.5 \
			and float(res["outward"]) > 3.0 \
			and float(res["view"]) > 0.9 \
			and float(res["dot_side"]) > 0.0
		_check("enter dir %d" % idx, ok,
			"crossed=%s dist=%.2f out=%.2f view=%.2f" % [
				str(res["crossed"]), res["dist"], res["outward"], res["view"]])
		idx += 1

	# ---- 反方向: 从 B 球外进入, 应回到 A 球外 ----
	var res2 := _try_enter(m, b, a, t1, r, dt)
	_check("reverse enter B→A", bool(res2["crossed"]) \
		and float(res2["dist"]) > r - 0.02 \
		and float(res2["outward"]) > 3.0 \
		and float(res2["view"]) > 0.9,
		"dist=%.2f out=%.2f view=%.2f" % [res2["dist"], res2["outward"], res2["view"]])

	# ---- 从旁边掠过: 不应触发 ----
	var start_miss: Vector4 = m.surf_project(a + t1 * (r + 4.0))
	m.pos = start_miss
	m.vel = t2 * 6.0
	m.fwd = t2
	m.up = t1
	m.right = t3
	m.n_axis = m.surf_normal(start_miss)
	var miss_crossed := false
	for i in 60:
		var prev2: Vector4 = m.pos
		m.pos += m.vel * dt
		var old2: Vector4 = m.pos
		m._wh_cross(prev2)
		if (m.pos - old2).length_squared() > 1e-8:
			miss_crossed = true
			break
	_check("miss does not transfer", not miss_crossed, "")

	print("RESULT failures=", fails)
	m.toast.free()
	m.free()
	quit(1 if fails > 0 else 0)
