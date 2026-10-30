// ============================================================================
//  v51: one room, two spherical mouths, explicit teleport loop
//
//  Mouth A -> throat (teleport) -> mouth B -> room -> mouth A
//
//  The room is flat. The two mouths are spheres. A ray that reaches a mouth
//  sphere is mapped to the same angular point on the other mouth and reflected
//  across the sphere normal; the same mapping moves the camera. This file is a
//  fresh implementation for v51 and does not use the old portal / 4D code.
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec3 cam_pos = vec3(0.0, 1.7, 8.0);
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float flash = 0.0;

uniform vec3 mouth_a = vec3(-4.0, 2.2, -3.0);
uniform vec3 mouth_b = vec3(4.0, 2.2, -3.0);
uniform float mouth_r = 2.0;

const vec3 ROOM_C = vec3(0.0, 3.0, 0.0);
const vec3 ROOM_H = vec3(12.0, 3.0, 12.0);

const vec3 GREEN_C = vec3(0.0, 1.2, -8.5);
const float GREEN_R = 1.2;
const vec3 RED_C = vec3(8.5, 1.2, -8.0);
const vec3 RED_H = vec3(1.2);
const vec3 BLUE_C = vec3(-8.5, 2.5, 6.0);
const float BLUE_R = 1.2;
const vec3 YELLOW_C = vec3(0.0, 1.2, 10.0);
const vec3 YELLOW_H = vec3(1.0, 1.2, 1.0);
const vec3 MAGENTA_C = vec3(7.5, 4.6, 7.0);
const float MAGENTA_R = 0.8;

const vec3 LIGHT_DIR = normalize(vec3(0.4, 0.85, 0.25));

struct Hit {
	float t;
	vec3 p;
	vec3 n;
	int mat;
	bool ok;
};

float sd_room(vec3 p) {
	vec3 q = ROOM_H - abs(p - ROOM_C);
	return min(min(q.x, q.y), q.z);
}

float sd_sphere(vec3 p, vec3 c, float r) {
	return length(p - c) - r;
}

float sd_box(vec3 p, vec3 c, vec3 h) {
	vec3 q = abs(p - c) - h;
	return length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float scene_dist(vec3 p, out int mat) {
	float d = sd_room(p);
	mat = 0;
	float dg = sd_sphere(p, GREEN_C, GREEN_R);
	if (dg < d) { d = dg; mat = 1; }
	float dr = sd_box(p, RED_C, RED_H);
	if (dr < d) { d = dr; mat = 2; }
	float db = sd_sphere(p, BLUE_C, BLUE_R);
	if (db < d) { d = db; mat = 3; }
	float dy = sd_box(p, YELLOW_C, YELLOW_H);
	if (dy < d) { d = dy; mat = 4; }
	float dm = sd_sphere(p, MAGENTA_C, MAGENTA_R);
	if (dm < d) { d = dm; mat = 5; }
	return d;
}

vec3 room_normal(vec3 p) {
	vec3 q = p - ROOM_C;
	vec3 a = ROOM_H - abs(q);
	if (a.x < a.y && a.x < a.z) return vec3(-sign(q.x), 0.0, 0.0);
	if (a.y < a.z) return vec3(0.0, -sign(q.y), 0.0);
	return vec3(0.0, 0.0, -sign(q.z));
}

vec3 box_normal(vec3 p, vec3 c, vec3 h) {
	vec3 q = p - c;
	vec3 a = abs(q) - h;
	if (a.x > a.y && a.x > a.z) return vec3(sign(q.x), 0.0, 0.0);
	if (a.y > a.z) return vec3(0.0, sign(q.y), 0.0);
	return vec3(0.0, 0.0, sign(q.z));
}

Hit trace_room(vec3 ro, vec3 rd, float tmax) {
	float t = 0.0;
	for (int i = 0; i < 128; i++) {
		vec3 p = ro + rd * t;
		int mat = 0;
		float d = scene_dist(p, mat);
		if (d < 0.001) {
			vec3 n;
			if (mat == 0) n = room_normal(p);
			else if (mat == 1) n = normalize(p - GREEN_C);
			else if (mat == 2) n = box_normal(p, RED_C, RED_H);
			else if (mat == 3) n = normalize(p - BLUE_C);
			else if (mat == 4) n = box_normal(p, YELLOW_C, YELLOW_H);
			else n = normalize(p - MAGENTA_C);
			return Hit(t, p, n, mat, true);
		}
		t += max(d, 0.002);
		if (t > tmax) break;
	}
	return Hit(tmax, ro + rd * tmax, vec3(0.0), -1, false);
}

vec3 shade_hit(Hit h, vec3 rd) {
	vec3 n = normalize(h.n);
	vec3 albedo;
	if (h.mat == 0) {
		if (n.y > 0.5) {
			// floor: checkerboard + thin grid
			vec2 uv = h.p.xz * 0.5;
			float ck = mod(floor(uv.x) + floor(uv.y), 2.0);
			float aa = clamp(fwidth(uv.x) + fwidth(uv.y), 0.0, 1.0);
			ck = mix(ck, 0.5, aa);
			albedo = mix(vec3(0.075, 0.085, 0.105), vec3(0.27, 0.29, 0.33), ck);
			vec2 g = abs(fract(uv) - 0.5);
			float line = 1.0 - smoothstep(0.0, 0.035, min(g.x, g.y));
			albedo += vec3(0.03, 0.035, 0.045) * line;
		} else {
			// walls / ceiling: dark panels with a faint grid
			albedo = vec3(0.070, 0.082, 0.108);
			vec2 wuv;
			if (abs(n.x) > 0.5) wuv = h.p.zy;
			else if (abs(n.y) > 0.5) wuv = h.p.xz;
			else wuv = h.p.xy;
			vec2 g = abs(fract(wuv * 0.25) - 0.5);
			float line = 1.0 - smoothstep(0.0, 0.02, min(g.x, g.y));
			albedo += vec3(0.025, 0.03, 0.045) * line;
		}
	} else if (h.mat == 1) {
		albedo = vec3(0.12, 0.70, 0.32);
	} else if (h.mat == 2) {
		albedo = vec3(0.82, 0.18, 0.12);
	} else if (h.mat == 3) {
		albedo = vec3(0.16, 0.42, 0.92);
	} else if (h.mat == 4) {
		albedo = vec3(0.85, 0.68, 0.14);
	} else {
		albedo = vec3(0.75, 0.18, 0.72);
	}

	float diff = max(dot(n, LIGHT_DIR), 0.0);
	vec3 col = albedo * (0.34 + 0.66 * diff);
	vec3 hv = normalize(LIGHT_DIR - rd);
	float spec = pow(max(dot(n, hv), 0.0), 48.0);
	col += vec3(0.35) * spec * (h.mat == 0 ? 0.08 : 0.6);

	float fog = 1.0 - exp(-0.016 * h.t);
	col = mix(col, vec3(0.010, 0.014, 0.024), clamp(fog, 0.0, 0.85));
	return col;
}

// Nearest positive ray/sphere hit.
float ray_sphere(vec3 ro, vec3 rd, vec3 c, float r) {
	vec3 oc = ro - c;
	float b = dot(oc, rd);
	float cc = dot(oc, oc) - r * r;
	float h = b * b - cc;
	if (h < 0.0) return -1.0;
	h = sqrt(h);
	float t = -b - h;
	if (t > 0.001) return t;
	t = -b + h;
	if (t > 0.001) return t;
	return -1.0;
}

vec3 render_portal(vec3 ro, vec3 rd) {
	vec3 glow = vec3(0.0);

	for (int bounce = 0; bounce < 6; bounce++) {
		float ta = ray_sphere(ro, rd, mouth_a, mouth_r);
		float tb = ray_sphere(ro, rd, mouth_b, mouth_r);
		float tm = 1.0e20;
		int which = -1;
		if (ta > 0.001) { tm = ta; which = 0; }
		if (tb > 0.001 && tb < tm) { tm = tb; which = 1; }

		Hit h = trace_room(ro, rd, min(tm, 1.0e19));
		if (h.ok) {
			return shade_hit(h, rd) + glow;
		}
		if (which < 0) {
			return vec3(0.008, 0.010, 0.016) + glow;
		}

		vec3 c = (which == 0) ? mouth_a : mouth_b;
		vec3 o = (which == 0) ? mouth_b : mouth_a;
		vec3 p = ro + rd * tm;
		vec3 n = normalize(p - c);
		float facing = abs(dot(rd, n));

		vec3 rim = (which == 0) ? vec3(0.10, 0.82, 1.00) : vec3(1.00, 0.46, 0.10);
		float pulse = 0.88 + 0.12 * sin(time_s * 3.0 + float(which) * 2.1);
		rim *= pulse;

		// Visible mouth rim at grazing angles.
		if (facing < 0.020) {
			float k = 1.0 - facing / 0.020;
			return rim * (0.55 + 0.85 * k) + vec3(0.08) * k;
		}

		// Glass-like edge tint on the view through the mouth.
		glow += rim * (0.02 + 0.18 * pow(1.0 - facing, 8.0));

		// Teleport the ray to the other mouth and continue in the room.
		ro = o + n * (mouth_r + 0.02);
		rd = reflect(rd, n);
	}

	return vec3(0.010, 0.012, 0.020) + glow;
}

void fragment() {
	vec2 ndc = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	ndc.x *= aspect;
	vec3 rd = normalize(cam_fwd + cam_right * ndc.x + cam_up * ndc.y);

	vec3 col = render_portal(cam_pos, rd);

	// Teleport flash: a brief cool/warm wash.
	col += vec3(0.10, 0.22, 0.28) * flash * 0.6;

	// Tonemap + gamma.
	col = col / (1.0 + col);
	col = pow(col, vec3(0.4545));

	// Vignette + crosshair.
	vec2 q = UV - 0.5;
	col *= 1.0 - 0.32 * dot(q, q);
	vec2 cs = UV - 0.5;
	cs.x *= aspect;
	float cd = length(cs);
	col = mix(col, vec3(0.0), (1.0 - smoothstep(0.0032, 0.0042, cd)) * 0.45);
	col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0018, 0.0026, cd));

	COLOR = vec4(col, 1.0);
}
