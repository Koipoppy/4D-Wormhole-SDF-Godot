extends SceneTree
## v52 self-test: same-universe A/B teleport on top of the 0.0.2 Ellis surface.
##
## Checks:
##  - both mouths are in universe B (w>0) and on the hyper-catenoid;
##  - a swept camera segment enters A and teleports just outside B;
##  - the exit state is on the surface and its velocity points outward;
##  - the loop counter increments after returning to the entrance mouth;
##  - a detour through universe B exists without touching either mouth.

var fails := 0


func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)


func _initialize() -> void:
	var Main = load("res://scripts/main.gd")
	var m = Main.new()
	m.toast = Label.new()
	m._build_mouths()

	var a: Vector4 = m.mouth_a
	var b: Vector4 = m.mouth_b
	var r: float = m.MOUTH_R

	_check("mouth A is in universe B", a.w > 0.0, "w=%.2f" % a.w)
	_check("mouth B is in universe B", b.w > 0.0, "w=%.2f" % b.w)
	_check("mouth A is on the 0.0.2 surface", absf(m.surf_f(a)) < 1.0e-4,
		"F=%s" % m.surf_f(a))
	_check("mouth B is on the 0.0.2 surface", absf(m.surf_f(b)) < 1.0e-4,
		"F=%s" % m.surf_f(b))
	_check("mouths are distinct", (a - b).length() > 2.0 * r,
		"d=%.2f" % (a - b).length())

	# ---- camera enters A, should exit just outside B ----
	var n: Vector4 = m.surf_normal(a)
	var start: Vector4 = a + n * (r + 4.0)
	var end := a
	var hit: Dictionary = m._sweep_mouths(start, end)
	_check("swept segment enters mouth A", not hit.is_empty() and int(hit["index"]) == 0,
		"index=%d" % (int(hit["index"]) if not hit.is_empty() else -1))

	m.pos = start
	m.vel = (end - start).normalized() * 6.0
	m.fwd = (end - start).normalized()
	m.right = Vector4(1.0, 0.0, 0.0, 0.0)
	m.up = Vector4(0.0, 1.0, 0.0, 0.0)
	m._do_teleport(0, hit["point"] as Vector4)

	var d_exit: float = (m.pos - b).length()
	_check("teleport exits outside B", d_exit >= r - 0.02 and d_exit <= r + 0.3,
		"d=%.3f" % d_exit)
	_check("teleport exit is on the surface", absf(m.surf_f(m.pos)) < 1.0e-3,
		"F=%s" % m.surf_f(m.pos))
	var nq: Vector4 = m.pos - b
	var surf_n: Vector4 = m.surf_normal(m.pos)
	var mq: Vector4 = nq - surf_n * nq.dot(surf_n)
	mq = mq.normalized()
	_check("exit velocity points outward", m.vel.dot(mq) > 0.0,
		"dot=%.3f" % m.vel.dot(mq))
	_check("first teleport counted", m.teleports == 1 and m.pending_return == 0,
		"teleports=%d pending=%d" % [m.teleports, m.pending_return])

	# ---- loop counter: re-enter the same mouth after the detour ----
	m.pending_timer = 1.0
	m._do_teleport(0, m.mouth_a + m.surf_normal(m.mouth_a) * r)
	_check("re-entering the same mouth closes one loop", m.loops == 1,
		"loops=%d" % m.loops)

	# ---- a miss ----
	var miss: Dictionary = m._sweep_mouths(a + Vector4(0.0, 0.0, 0.0, 10.0),
		a + Vector4(0.0, 0.0, 0.0, 11.0))
	_check("segment offset in w misses both mouths", miss.is_empty(), "")

	# ---- detour through universe B, away from both mouths ----
	var w := 6.0
	var rho := 3.0 * cosh(w / 3.0)
	var max_res := 0.0
	var min_mouth := 1.0e9
	var mid := Vector4.ZERO
	var samples := 0
	for i in 25:
		var y := lerpf(-6.0, 6.0, float(i) / 24.0)
		var x2 := rho * rho - y * y - 64.0
		if x2 <= 0.0:
			continue
		var p: Vector4 = m.surf_project(Vector4(sqrt(x2), y, 8.0, w))
		max_res = maxf(max_res, absf(m.surf_f(p)))
		min_mouth = minf(min_mouth, minf((p - a).length(), (p - b).length()))
		mid = p
		samples += 1
	_check("detour through universe B stays on the surface", samples > 10 and max_res < 1.0e-3,
		"samples=%d max|F|=%s" % [samples, max_res])
	_check("detour stays outside both mouths", min_mouth > r,
		"min d=%.2f r=%.2f" % [min_mouth, r])
	_check("detour has a finite point", mid != Vector4.ZERO, "")

	print("RESULT failures=", fails)
	m.toast.free()
	m.free()
	quit(1 if fails > 0 else 0)
