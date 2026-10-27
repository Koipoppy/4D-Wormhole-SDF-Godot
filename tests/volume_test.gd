extends SceneTree
## 4D volume-handle continuity self-test:
## the camera's w must change continuously along the throat volume,
## with no position mapping between the two mouths.

var fails := 0

func _check(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)

func _initialize() -> void:
	var Main = load("res://scripts/volume_main.gd")
	var m = Main.new()
	m.toast = Label.new()
	# throat centerline: 3D continuous + w dip, ends at the two cavity centers
	var w0: float = m.W0
	var max_wjump := 0.0
	var last_w: float = m._center_w(0.0)
	var max_3djump := 0.0
	var last_p: Vector3 = m._centerline(0.0)
	for i in 101:
		var t := float(i) / 100.0
		var p: Vector3 = m._centerline(t)
		var w: float = m._center_w(t)
		max_wjump = maxf(max_wjump, absf(w - last_w))
		max_3djump = maxf(max_3djump, p.distance_to(last_p))
		last_w = w
		last_p = p
	_check("throat w starts at W0", absf(m._center_w(0.0) - w0) < 0.01, "w0=%.2f" % m._center_w(0.0))
	_check("throat w ends at W0", absf(m._center_w(1.0) - w0) < 0.01, "w1=%.2f" % m._center_w(1.0))
	_check("throat has a real 4D dip", absf(m._center_w(0.5) - w0) > 4.0, "w_mid=%.2f" % m._center_w(0.5))
	_check("w continuous along throat", max_wjump < 0.35, "max dw=%.4f" % max_wjump)
	_check("3D path continuous", max_3djump < 0.30, "max dp=%.4f" % max_3djump)
	_check("throat starts at mouth A", m._centerline(0.0).distance_to(m.BALL_A) < 0.01, "")
	_check("throat ends at mouth B", m._centerline(1.0).distance_to(m.BALL_B) < 0.01, "")
	_check("mouth A is a 3D cavity", m._in_ball(m.BALL_A) and m._in_ball(m.BALL_A + Vector3(0, 0, 2.0)), "")
	_check("mouth B is a 3D cavity", m._in_ball(m.BALL_B), "")
	_check("throat mid is inside sky volume", m._in_throat3(m._centerline(0.5)), "")
	print("RESULT failures=", fails)
	m.toast.free()
	m.free()
	quit(1 if fails > 0 else 0)
