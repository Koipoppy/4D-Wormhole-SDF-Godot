extends SceneTree
## v51 portal room self-test (pure math, no scene / no rendering).
##
## Checks the teleport mapping, the swept camera intersection, the miss case,
## the room path that closes the loop, and the handedness flip.

var fails := 0


func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)


func _initialize() -> void:
	var PM = load("res://scripts/portal_math.gd")
	var a := Vector3(-4.0, 2.2, -3.0)
	var b := Vector3(4.0, 2.2, -3.0)
	var r := 2.0
	var ex := Vector3.RIGHT

	# ---- point mapping ----
	var pa := a + ex * r
	var mb = PM.map_point(pa, a, b, r)
	_check("point on A maps to the same angular point on B",
		(mb - (b + ex * r)).length() < 1.0e-5,
		"|map-B|=%.6f" % (mb - (b + ex * r)).length())

	# ---- velocity reflection ----
	var v_in := -ex * 6.0
	var v_out = PM.reflect_vec(v_in, ex)
	_check("inward velocity reflects to outward",
		v_out.dot(ex) > 0.0 and absf(v_out.length() - 6.0) < 1.0e-5,
		"v_out=(%.2f,%.2f,%.2f)" % [v_out.x, v_out.y, v_out.z])

	# ---- analytic ray entry ----
	var ro := a + ex * 4.0
	var rd := -ex
	var rh = PM.ray_sphere_entry(ro, rd, a, r)
	_check("ray from outside hits A at the front surface",
		not rh.is_empty() and absf(float(rh["t"]) - 2.0) < 1.0e-5,
		"t=%.4f" % (float(rh["t"]) if not rh.is_empty() else -1.0))

	# ---- swept camera segment ----
	var s0 := a + ex * 4.0
	var s1 := a - ex * 1.0
	var sh = PM.segment_sphere_entry(s0, s1, a, r)
	_check("swept segment enters A",
		not sh.is_empty() and absf(float(sh["t"]) - 0.4) < 1.0e-5,
		"t=%.4f" % (float(sh["t"]) if not sh.is_empty() else -1.0))

	# ---- teleport state ----
	var fwd := -ex
	var right := Vector3(0.0, 1.0, 0.0)
	var up := Vector3(0.0, 0.0, 1.0)
	var st = PM.teleport_state(v_in, fwd, right, up, b, r, ex)
	var p_exit: Vector3 = st["pos"]
	var v_exit: Vector3 = st["vel"]
	var f_exit: Vector3 = st["fwd"]
	_check("exit is just outside B", absf(p_exit.distance_to(b) - (r + PM.SKIN)) < 1.0e-5,
		"d=%.4f" % p_exit.distance_to(b))
	_check("exit velocity points outward", v_exit.dot(ex) > 0.0,
		"dot=%.3f" % v_exit.dot(ex))
	_check("exit view is reflected", f_exit.dot(ex) > 0.9,
		"fwd_x=%.3f" % f_exit.x)

	# ---- handedness ----
	var h0 := right.dot(fwd.cross(up))
	var h1: float = (st["right"] as Vector3).dot((st["fwd"] as Vector3).cross(st["up"] as Vector3))
	_check("teleport flips the camera handedness", h0 * h1 < 0.0,
		"h0=%.1f h1=%.1f" % [h0, h1])

	# ---- double teleport returns the original state (up to skin) ----
	var st2 = PM.teleport_state(st["vel"], st["fwd"], st["right"], st["up"], a, r, ex)
	var p_back: Vector3 = st2["pos"]
	var v_back: Vector3 = st2["vel"]
	_check("A->B->A returns to A", p_back.distance_to(a + ex * (r + PM.SKIN)) < 1.0e-5,
		"d=%.4f" % p_back.distance_to(a + ex * (r + PM.SKIN)))
	_check("A->B->A restores velocity", (v_back - v_in).length() < 1.0e-5,
		"err=%.6f" % (v_back - v_in).length())

	# ---- miss ----
	var miss = PM.segment_sphere_entry(a + Vector3(0.0, 3.0, 0.0),
		a + Vector3(6.0, 3.0, 0.0), a, r)
	_check("segment passing above the mouth does not transfer", miss.is_empty(), "")

	# ---- non-nearest / nearest selection ----
	var cam := Vector3(0.0, 1.7, 8.0)
	var hit_a = PM.sweep_first(cam, a + Vector3(0.0, 0.0, -1.0), [a, b], r)
	_check("sweep selects mouth A", not hit_a.is_empty() and int(hit_a["index"]) == 0,
		"index=%d" % (int(hit_a["index"]) if not hit_a.is_empty() else -1))
	var hit_b = PM.sweep_first(cam, b + Vector3(0.0, 0.0, -1.0), [a, b], r)
	_check("sweep selects mouth B", not hit_b.is_empty() and int(hit_b["index"]) == 1,
		"index=%d" % (int(hit_b["index"]) if not hit_b.is_empty() else -1))

	# ---- the room path that closes the loop ----
	# From outside B, go around the mouths at z=+2, then to outside A.
	var room_p0 := b + Vector3(0.0, 0.0, 5.0)
	var room_p1 := a + Vector3(0.0, 0.0, 5.0)
	var room_hit = PM.sweep_first(room_p0, room_p1, [a, b], r)
	_check("room path B->A does not hit either mouth", room_hit.is_empty(), "")

	# The same room path then enters A; this is the loop's last leg.
	var enter_a = PM.segment_sphere_entry(room_p1, a, a, r)
	_check("loop's last leg enters A", not enter_a.is_empty(), "")

	# ---- controller loop counter (fresh v51 script, no scene needed) ----
	var Room = load("res://scripts/portal_room.gd")
	var m = Room.new()
	m.toast = Label.new()
	m.vel = -ex * 6.0
	m.fwd = -ex
	m.right = Vector3(0.0, 1.0, 0.0)
	m.up = Vector3(0.0, 0.0, 1.0)
	m._do_teleport(0, ex)
	_check("first teleport counted", m.teleports == 1 and m.pending_return == 0,
		"teleports=%d pending=%d" % [m.teleports, m.pending_return])
	m.pending_timer = 1.0
	m._do_teleport(0, ex)
	_check("re-entering the same mouth after the room closes one loop",
		m.loops == 1, "loops=%d" % m.loops)
	m.toast.free()
	m.free()

	print("RESULT failures=", fails)
	quit(1 if fails > 0 else 0)
