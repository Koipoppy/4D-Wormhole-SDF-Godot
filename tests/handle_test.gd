extends SceneTree
## v50 same-space A<->B wormhole self-test.
## One smooth profile surface: F = |p_xyz| - f(w) = 0,
## f(w) = two Gaussian lobes + one neck. The two lobes are the same surface at
## two positions; the neck is the surface's own connection. Walk from lobe A,
## through the neck, to lobe B on the same surface.

var fails := 0


func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)


func _initialize() -> void:
	var Main = load("res://scripts/handle_main.gd")
	var m = Main.new()
	m.toast = Label.new()
	var A_W: float = m.A_W
	var W_MAX: float = m.W_MAX

	# Path at a fixed angular direction (+x): p(w) = (f(w),0,0,w).
	var max_res := 0.0
	var max_dw := 0.0
	var max_dp := 0.0
	var last := Vector4.ZERO
	var first := true
	var start := Vector4.ZERO
	var finish := Vector4.ZERO
	var neck := Vector4.ZERO
	var lobe_a := Vector4.ZERO
	var lobe_b := Vector4.ZERO
	var n := 160
	for i in n + 1:
		var w := lerpf(-W_MAX + 1.0, W_MAX - 1.0, float(i) / float(n))
		var p := Vector4(m.profile(w), 0.0, 0.0, w)
		var pj: Vector4 = m.surf_project(p)
		max_res = maxf(max_res, absf(m.surf_f(pj)))
		if not first:
			max_dw = maxf(max_dw, absf(pj.w - last.w))
			max_dp = maxf(max_dp, (pj - last).length())
		else:
			start = pj
		last = pj
		first = false
		finish = pj
		if absf(w + A_W) < 0.1:
			lobe_a = pj
		if absf(w - A_W) < 0.1:
			lobe_b = pj
		if absf(w) < 0.1:
			neck = pj

	var r_lobe_a := Vector3(lobe_a.x, lobe_a.y, lobe_a.z).length()
	var r_lobe_b := Vector3(lobe_b.x, lobe_b.y, lobe_b.z).length()
	var r_neck := Vector3(neck.x, neck.y, neck.z).length()

	_check("single surface: F=0 along the path", max_res < 1e-3, "max|F|=%f" % max_res)
	_check("start is on lobe A (w<0)", start.w < -A_W + 0.5, "start_w=%.2f" % start.w)
	_check("end is on lobe B (w>0)", finish.w > A_W - 0.5, "end_w=%.2f" % finish.w)
	_check("path crosses the neck w=0", absf(neck.w) < 0.2, "neck_w=%.2f" % neck.w)
	_check("neck is narrower than lobe A", r_neck < r_lobe_a - 0.3,
		"r_neck=%.2f rA=%.2f" % [r_neck, r_lobe_a])
	_check("neck is narrower than lobe B", r_neck < r_lobe_b - 0.3,
		"r_neck=%.2f rB=%.2f" % [r_neck, r_lobe_b])
	_check("two lobes are the same surface", absf(r_lobe_a - r_lobe_b) < 0.3,
		"rA=%.2f rB=%.2f" % [r_lobe_a, r_lobe_b])
	_check("w continuous along the surface", max_dw < 0.2, "max dw=%.3f" % max_dw)
	_check("4D position continuous along the surface", max_dp < 0.3, "max dp=%.3f" % max_dp)
	_check("no second copy: start/end/neck all satisfy F=0",
		absf(m.surf_f(start)) < 1e-3 and absf(m.surf_f(finish)) < 1e-3 and absf(m.surf_f(neck)) < 1e-3, "")

	print("RESULT failures=", fails, "  (R_lobe=%.2f R_neck=%.2f A_W=%.1f)" % [r_lobe_a, r_neck, A_W])
	m.toast.free()
	m.free()
	quit(1 if fails > 0 else 0)
