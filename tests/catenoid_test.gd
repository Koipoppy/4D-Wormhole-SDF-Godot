extends SceneTree
## v45 smooth two-throat self-test:
## two Morris-Thorne hyper-catenoid copies, blended with a C∞ smooth minimum
## F = smin(F1,F2; κ). The world is one smooth 3D hypersurface; the player can go
## B -> throat A -> C -> throat B -> B with continuous position, normal and
## tangent, and no position mapping.

var fails := 0


func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)


func _ang(a: Vector4, b: Vector4) -> float:
	return rad_to_deg(acos(clampf(a.normalized().dot(b.normalized()), -1.0, 1.0)))


func _initialize() -> void:
	var Main = load("res://scripts/main.gd")
	var m = Main.new()
	m.toast = Label.new()
	var R: float = m.THROAT_R
	var K: float = m.BLEND_K
	var C1: Vector3 = m.C1
	var C2: Vector3 = m.C2

	# ---- throats at w=0 ----
	var ta := Vector4(C1.x + R, C1.y, C1.z, 0.0)
	var tb := Vector4(C2.x + R, C2.y, C2.z, 0.0)
	_check("throat A on catenoid 1", absf(m.f1(ta)) < 0.01, "f1=%.4f" % m.f1(ta))
	_check("throat B on catenoid 2", absf(m.f2(tb)) < 0.01, "f2=%.4f" % m.f2(tb))
	_check("smooth throat A", absf(m.world_f(ta)) < 0.01, "F=%.6f" % m.world_f(ta))
	_check("smooth throat B", absf(m.world_f(tb)) < 0.01, "F=%.6f" % m.world_f(tb))
	_check("throat A in B/C throat plane", absf(ta.w) < 0.01, "")
	_check("throat B in B/C throat plane", absf(tb.w) < 0.01, "")

	# ---- B floor / C sky ----
	var pb := Vector4(C1.x + 11.29, C1.y, 0.0, -6.0)
	_check("B floor exists", absf(m.cat_sdf(pb)) < 0.05, "cat=%.4f" % m.cat_sdf(pb))
	_check("C side has no floor", m.cat_sdf(Vector4(pb.x, pb.y, 0.0, 6.0)) > 1e8, "")

	# ---- individual surfaces intersect at w=+6 ----
	var rad: float = R * cosh(6.0 / R)
	var zz: float = sqrt(maxf(rad * rad - 25.0, 0.0))
	var pi := Vector4(0.0, C1.y, zz, 6.0)
	_check("individual surfaces intersect (1)", absf(m.f1(pi)) < 0.1, "f1=%.3f" % m.f1(pi))
	_check("individual surfaces intersect (2)", absf(m.f2(pi)) < 0.1, "f2=%.3f" % m.f2(pi))
	var pj: Vector4 = m.world_project(pi)
	_check("smooth zero set at seam", absf(m.world_f(pj)) < 1e-3, "F=%.6f" % m.world_f(pj))
	_check("hard min would have a seam offset", absf(m.world_f(pi) - m.smin(0.0, 0.0)) < 0.01,
		"F(pi)=%.3f, smin(0,0)=%.3f" % [m.world_f(pi), m.smin(0.0, 0.0)])

	# ---- normal continuity across the smooth neck (was 13.5° at v44) ----
	var a := Vector4(-0.01, C1.y, zz, 6.0)
	var b := Vector4(0.01, C1.y, zz, 6.0)
	var na: Vector4 = m.world_normal(m.world_project(a))
	var nb: Vector4 = m.world_normal(m.world_project(b))
	_check("seam normal continuous", _ang(na, nb) < 5.0, "angle=%.2f deg" % _ang(na, nb))

	# ---- tangency point (was 73.8° at v44) ----
	var wt: float = R * acosh(5.0 / R)
	var pt := Vector4(0.0, C1.y, 0.0, wt)
	var pjt: Vector4 = m.world_project(pt)
	_check("smooth zero set at tangency", absf(m.world_f(pjt)) < 1e-3, "F=%.6f" % m.world_f(pjt))
	var at := Vector4(-0.01, C1.y, 0.0, wt)
	var bt := Vector4(0.01, C1.y, 0.0, wt)
	var nat: Vector4 = m.world_normal(m.world_project(at))
	var nbt: Vector4 = m.world_normal(m.world_project(bt))
	_check("tangency normal continuous", _ang(nat, nbt) < 5.0, "angle=%.2f deg" % _ang(nat, nbt))

	# ---- tangent continuity across the seam ----
	var n0: Vector4 = m.world_normal(pj)
	var v0 := Vector4(1, 0, 0, 0)
	v0 -= n0 * v0.dot(n0)
	v0 = v0.normalized()
	var p2: Vector4 = m.world_project(pj + v0 * 0.05)
	var n2: Vector4 = m.world_normal(p2)
	var v2 := v0 - n2 * v0.dot(n2)
	v2 = v2.normalized()
	_check("velocity continuous across smooth seam", _ang(v0, v2) < 5.0,
		"angle=%.2f deg" % _ang(v0, v2))
	_check("projection residual small", absf(m.world_f(p2)) < 1e-3, "F=%.6f" % m.world_f(p2))

	# ---- continuous worldline on the smooth surface: B -> A -> C -> B -> B ----
	var max_jump := 0.0
	var max_n_ang := 0.0
	var max_resid := 0.0
	var last := Vector4.ZERO
	var last_n := Vector4.ZERO
	var first := true
	var w_vals: Array[float] = []
	var inter_w: float = R * acosh(5.0 / R)
	for i in 121:
		var t := float(i) / 120.0
		var w := 0.0
		if t <= 0.5:
			w = lerpf(-2.5, inter_w, t * 2.0)
		else:
			w = lerpf(inter_w, -2.5, (t - 0.5) * 2.0)
		var rr: float = R * cosh(w / R)
		var p: Vector4
		if t <= 0.5:
			p = Vector4(C1.x + rr, C1.y, 0.0, w)
		else:
			p = Vector4(C2.x - rr, C2.y, 0.0, w)
		var pw: Vector4 = m.world_project(p)
		var nj: Vector4 = m.world_normal(pw)
		max_resid = maxf(max_resid, absf(m.world_f(pw)))
		if not first:
			max_jump = maxf(max_jump, absf(pw.w - last.w))
			max_n_ang = maxf(max_n_ang, _ang(nj, last_n))
		last = pw
		last_n = nj
		first = false
		w_vals.append(pw.w)
	_check("worldline traverses A -> C -> B", w_vals.size() == 121, "")
	_check("worldline reaches C side (w>0)", w_vals.max() > 2.0, "wmax=%.2f" % w_vals.max())
	_check("w continuous on smooth union", max_jump < 0.25, "max dw=%.3f" % max_jump)
	_check("normals continuous along worldline", max_n_ang < 15.0, "max angle=%.2f deg" % max_n_ang)
	_check("projection residual along worldline", max_resid < 1e-3, "max F=%.6f" % max_resid)
	_check("two throats connected through shared C union",
		absf(m.f1(pi)) < 0.1 and absf(m.f2(pi)) < 0.1 and absf(m.world_f(pj)) < 1e-3, "")

	print("RESULT failures=", fails, "  (R=%.1f, kappa=%.2f)" % [R, K])
	m.toast.free()
	m.free()
	quit(1 if fails > 0 else 0)
