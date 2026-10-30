extends SceneTree
## 0.0.2 single-throat self-test:
## ONE Morris-Thorne hyper-catenoid, ONE throat at w=0. Its two sides are the
## two universes A (w<0, cold) and B (w>0, warm). Walking through the same
## throat must be continuous: w changes sign, position stays on F=0, and there
## is no second copy / no position mapping.

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
	var R: float = m.THROAT_R

	# A radial curve on the single surface: fixed +y direction, w from +2 to -2.
	var w_values: Array[float] = [2.0, 1.5, 1.0, 0.5, 0.0, -0.5, -1.0, -1.5, -2.0]
	var max_res := 0.0
	var max_dw := 0.0
	var max_dp := 0.0
	var last_p := Vector4.ZERO
	var first := true
	var crossed := false
	var start_w := 0.0
	var end_w := 0.0
	var throat_rho := 0.0
	for wi in w_values:
		var w: float = wi
		var rho: float = R * cosh(w / R)
		var p := Vector4(0.0, rho, 0.0, w)
		p = m.surf_project(p)
		max_res = maxf(max_res, absf(m.surf_f(p)))
		if absf(w) < 1e-6:
			throat_rho = Vector3(p.x, p.y, p.z).length()
		if not first:
			max_dw = maxf(max_dw, absf(p.w - last_p.w))
			max_dp = maxf(max_dp, (p - last_p).length())
			if last_p.w > 0.0 and p.w <= 0.0:
				crossed = true
		else:
			start_w = p.w
		last_p = p
		first = false
		end_w = p.w

	_check("single surface: all samples on F=0", max_res < 1e-4,
		"max|F|=%f" % max_res)
	_check("starts on B side (w>0)", start_w > 1.0, "start_w=%.2f" % start_w)
	_check("ends on A side (w<0)", end_w < -1.0, "end_w=%.2f" % end_w)
	_check("crosses the single throat w=0", crossed, "")
	_check("throat radius at w=0 is R", absf(throat_rho - R) < 1e-4,
		"rho_throat=%.3f" % throat_rho)
	_check("w continuous through the throat", max_dw < 0.6, "max dw=%.3f" % max_dw)
	_check("3D position continuous through the throat", max_dp < 0.8, "max dp=%.3f" % max_dp)

	# The same single surface on both sides: rho(w) = rho(-w); no second copy.
	var pB: Vector4 = m.surf_project(Vector4(0.0, R * cosh(2.0 / R), 0.0, 2.0))
	var pA: Vector4 = m.surf_project(Vector4(0.0, R * cosh(-2.0 / R), 0.0, -2.0))
	_check("A and B sides are the same hyper-catenoid",
		absf(Vector3(pB.x, pB.y, pB.z).length() - Vector3(pA.x, pA.y, pA.z).length()) < 1e-4,
		"rhoB=%.3f rhoA=%.3f" % [Vector3(pB.x, pB.y, pB.z).length(), Vector3(pA.x, pA.y, pA.z).length()])

	print("RESULT failures=", fails, "  (single throat R=%.1f)" % R)
	m.toast.free()
	m.free()
	quit(1 if fails > 0 else 0)
