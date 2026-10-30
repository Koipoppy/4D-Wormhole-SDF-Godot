class_name PortalMath
extends RefCounted
## v51: pure math for two spherical mouths in one room.
##
## A mouth is a sphere. A point/ray that reaches the sphere surface is mapped
## to the same angular point on the other sphere:
##
##     n   = (hit - from_center) / r
##     p'  = to_center + n * r
##     v'  = v - 2 * (v . n) * n
##
## The normal reflection is what makes the traveller leave the destination
## sphere on its outside instead of immediately entering it again. It also
## flips the handedness of a camera frame, which the controller tracks.

const SKIN := 0.02
const EPS := 1.0e-6


static func reflect_vec(v: Vector3, n: Vector3) -> Vector3:
	return v - 2.0 * n * v.dot(n)


static func map_point(p: Vector3, from_center: Vector3, to_center: Vector3, radius: float) -> Vector3:
	var n := (p - from_center).normalized()
	return to_center + n * radius


## Ray/sphere entry. `ro` may be inside (returns t=0 with the current normal).
## Returns {} when there is no forward intersection.
static func ray_sphere_entry(ro: Vector3, rd: Vector3, center: Vector3, radius: float) -> Dictionary:
	var oc := ro - center
	var b := oc.dot(rd)
	var cc := oc.dot(oc) - radius * radius
	var h := b * b - cc
	if h < 0.0:
		return {}
	h = sqrt(h)
	var t := -b - h
	if t <= EPS:
		# Started inside, or exactly on the surface moving inward.
		if cc < 0.0 or (absf(cc) <= EPS and b < 0.0):
			var n0 := ro - center
			if n0.length_squared() < EPS:
				return {}
			return {"t": 0.0, "point": ro, "normal": n0.normalized()}
		t = -b + h
		if t <= EPS:
			return {}
	var p := ro + rd * t
	var n := p - center
	if n.length_squared() < EPS:
		return {}
	return {"t": t, "point": p, "normal": n.normalized()}


## Swept segment/sphere entry. Returns the first crossing with t in [0,1].
## If the segment starts inside the sphere, returns t=0 as a safety fallback.
static func segment_sphere_entry(p0: Vector3, p1: Vector3, center: Vector3, radius: float) -> Dictionary:
	var d := p1 - p0
	var a := d.dot(d)
	if a <= 1.0e-12:
		return {}
	var m := p0 - center
	var b := 2.0 * m.dot(d)
	var cc := m.dot(m) - radius * radius
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return {}
	var sq := sqrt(disc)
	var t0 := (-b - sq) / (2.0 * a)
	var t1 := (-b + sq) / (2.0 * a)
	if t0 >= 0.0 and t0 <= 1.0:
		var p := p0 + d * t0
		var n := p - center
		if n.length_squared() < EPS:
			return {}
		return {"t": t0, "point": p, "normal": n.normalized()}
	if cc < 0.0 and t1 >= 0.0 and t1 <= 1.0:
		var n0 := p0 - center
		if n0.length_squared() < EPS:
			return {}
		return {"t": 0.0, "point": p0, "normal": n0.normalized()}
	return {}


## First mouth hit by a swept camera segment. `centers` is an Array[Vector3].
static func sweep_first(p0: Vector3, p1: Vector3, centers: Array, radius: float) -> Dictionary:
	var best := {}
	for i in centers.size():
		var c: Vector3 = centers[i]
		var hit := segment_sphere_entry(p0, p1, c, radius)
		if hit.is_empty():
			continue
		if best.is_empty() or float(hit["t"]) < float(best["t"]):
			best = hit
			best["index"] = i
	return best


## Teleport state: position just outside the destination sphere, reflected
## velocity and camera frame. `entry_normal` comes from the entry hit.
static func teleport_state(vel: Vector3, fwd: Vector3, right: Vector3, up: Vector3,
		to_center: Vector3, radius: float, entry_normal: Vector3) -> Dictionary:
	var n := entry_normal.normalized()
	return {
		"pos": to_center + n * (radius + SKIN),
		"vel": reflect_vec(vel, n),
		"fwd": reflect_vec(fwd, n),
		"right": reflect_vec(right, n),
		"up": reflect_vec(up, n),
		"normal": n,
	}
