// ============================================================================
//  4D volume-handle wormhole — v40
//  Room: 3D hyperplane w = W0, floor z = 0.
//  Sky cavities: 4D balls at A/B (w=W0), interiors = sky.
//  Throat: 4D tube around a centerline below the floor; the centerline leaves
//          the room through w, so the connection is genuinely 4D.
//  The player/light travels through the volume; no position mapping/transfer.
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(0.0, -11.0, 4.6, -6.0);
uniform vec4 cam_fwd = vec4(0.0, 1.0, -0.18, 0.0);
uniform vec4 cam_right = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 cam_up = vec4(0.0, 0.0, 1.0, 0.0);
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float fov_scale = 1.0;

uniform vec4 ball_a;
uniform vec4 ball_b;
uniform float ball_r;
uniform float tube_h;
uniform float tube_w;
uniform float tube_r;

uniform vec4 green_c;
uniform float green_r;
uniform vec4 mk1_c;
uniform vec4 mk2_c;
uniform float mk1_r;
uniform float mk2_r;

const int MAX_STEPS = 220;
const int TUBE_SAMPLES = 18;
const float RIM_TUBE = 0.16;

// ----------------------------------------------------------------------------
//  noise / cloud sky
// ----------------------------------------------------------------------------
float hash13(vec3 p){
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p){
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float fbm3(vec3 p){
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++){
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

vec3 cloud_sky(vec4 v){
	// 球口内部看到的是上方的天空: 给方向一个向上的偏置, 避免直视地平线发白
	vec3 d = normalize(vec3(v.x, v.y, abs(v.z) * 0.55 + 0.45));
	float h = clamp(d.z * 0.5 + 0.5, 0.0, 1.0);
	vec3 sky = mix(vec3(0.52, 0.74, 0.97), vec3(0.07, 0.30, 0.78), h);
	float n = fbm3(d * 3.6 + vec3(time_s * 0.008, time_s * 0.004, 0.0));
	float cl = smoothstep(0.50, 0.74, n);
	sky = mix(sky, vec3(1.0), cl * 0.90);
	float sun = pow(max(dot(d, normalize(vec3(0.42, 0.28, 0.86))), 0.0), 110.0);
	sky += vec3(1.0, 0.94, 0.78) * sun * 1.1;
	return sky;
}

vec3 sun_dir(){
	return normalize(vec3(0.42, 0.28, 0.86));
}

// ----------------------------------------------------------------------------
//  geometry
// ----------------------------------------------------------------------------
vec4 tube_center(float t){
	float a = smoothstep(0.15, 0.50, t);
	float b = smoothstep(0.50, 0.85, t);
	float s = a * (1.0 - b);
	return vec4(mix(ball_a.x, ball_b.x, t), 0.0, -tube_h * sin(3.14159265 * t), ball_a.w - tube_w * s);
}

float tube_sdf(vec4 p){
	// cheap bounding rejection: the tube is below the floor and near the x span
	float best = 1e9;
	float bt = 0.0;
	for (int i = 0; i < TUBE_SAMPLES; i++){
		float t = float(i) / float(TUBE_SAMPLES - 1);
		vec4 c = tube_center(t);
		float d = length(p - c);
		if (d < best){ best = d; bt = t; }
	}
	return best - tube_r;
}

float sd_ball_a(vec4 p){ return length(p - ball_a) - ball_r; }
float sd_ball_b(vec4 p){ return length(p - ball_b) - ball_r; }

float sky_sdf(vec4 p){
	float s = min(sd_ball_a(p), sd_ball_b(p));
	return min(s, tube_sdf(p));
}

float sd_green(vec4 p){ return length(p - green_c) - green_r; }

float sd_mk1(vec4 p){ return length(p - mk1_c) - mk1_r; }
float sd_mk2(vec4 p){
	vec4 d = abs(p - mk2_c);
	return max(max(d.x, d.y), max(d.z, d.w)) - mk2_r;
}

float sd_floor(vec4 p){ return p.z; }

float rim_torus(vec4 p, vec4 c, float R){
	float rad = length(p.xy - c.xy);
	return length(vec2(rad - R, p.z)) - RIM_TUBE;
}

// ----------------------------------------------------------------------------
//  shading helpers
// ----------------------------------------------------------------------------
vec3 glass_tint(vec4 n, vec4 v){
	float fres = pow(1.0 - abs(dot(normalize(n), normalize(v))), 3.0);
	vec3 glass = vec3(0.75, 0.90, 1.0);
	float spec = pow(max(dot(reflect(-normalize(v), normalize(n)).xyz, sun_dir()), 0.0), 24.0);
	return glass * (0.35 + 0.65 * fres) + vec3(1.0) * spec * 0.8;
}

vec3 floor_albedo(vec3 p){
	vec3 coord = p * 0.55;
	float ck = mod(floor(coord.x) + floor(coord.y) + floor(coord.z), 2.0);
	float fw = fwidth(coord.x) + fwidth(coord.y) + fwidth(coord.z);
	if (isnan(fw) || isinf(fw) || fw < 0.0){
		fw = 1.0;
	}
	ck = mix(ck, 0.5, clamp(fw * 1.5, 0.0, 1.0));
	return mix(vec3(0.58, 0.59, 0.61), vec3(0.90, 0.91, 0.92), ck);
}

// ----------------------------------------------------------------------------
//  renderer: free 4D ray marching through the volume handle
// ----------------------------------------------------------------------------
vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = cam_pos;

	float travel = 0.0;
	int hit = 0;          // 1 floor, 2 green, 3 mk1, 4 mk2, 5 rim, 6 sky
	vec4 hit_n = vec4(0.0);
	for (int i = 0; i < MAX_STEPS; i++){
		float sky = sky_sdf(p);
		float fl = sd_floor(p);
		float gr = sd_green(p);
		float m1 = sd_mk1(p);
		float m2 = sd_mk2(p);
		// rims around both mouths
		float rim = 1e9;
		if (sky > -0.01){
			rim = min(rim_torus(p, ball_a, ball_r), rim_torus(p, ball_b, ball_r));
		}
		if (sky < 0.0){
			hit = 6;
			hit_n = normalize(p - ((sd_ball_a(p) < sd_ball_b(p)) ? ball_a : ball_b));
			break;
		}
		if (abs(fl) < 0.02){
			hit = 1;
			hit_n = vec4(0.0, 0.0, 1.0, 0.0);
			break;
		}
		if (gr < 0.02){ hit = 2; hit_n = normalize(p - green_c); break; }
		if (m1 < 0.02){ hit = 3; hit_n = normalize(p - mk1_c); break; }
		if (m2 < 0.02){ hit = 4; hit_n = vec4(0.0); break; }
		if (rim < 0.02){ hit = 5; break; }

		float h = clamp(0.5 * min(min(abs(fl), gr), min(min(m1, m2), rim)) + 0.03, 0.04, 0.6);
		h = min(h, max(sky * 0.7, 0.04));
		p += v * h;
		travel += h;
		if (travel > 120.0){
			break;
		}
	}

	vec3 col;
	if (hit == 6){
		vec3 sky = cloud_sky(v);
		col = sky * 0.94 + glass_tint(hit_n, v) * 0.16;
	} else if (hit == 1){
		vec3 n = vec3(0.0, 0.0, 1.0);
		float dif = clamp(dot(n, sun_dir()), 0.0, 1.0);
		vec3 alb = floor_albedo(p.xyz);
		float sg = smoothstep(4.4, 1.8, length(p.xy - green_c.xy));
		float sb = smoothstep(3.8, 2.5, min(length(p.xy - ball_a.xy), length(p.xy - ball_b.xy)));
		col = alb * (0.55 + 0.50 * dif) * (1.0 - 0.38 * sg - 0.22 * sb);
		float fres = pow(1.0 - abs(dot(n, normalize(v.xyz))), 4.0);
		col = mix(col, vec3(0.58, 0.72, 0.90), 0.10 * fres);
	} else if (hit == 2){
		float dif = clamp(dot(hit_n.xyz, sun_dir()), 0.0, 1.0);
		float fres = pow(1.0 - abs(dot(hit_n.xyz, normalize(v.xyz))), 3.0);
		col = vec3(0.06, 0.62, 0.26) * (0.40 + 0.70 * dif) + vec3(0.3, 0.9, 0.5) * fres * 0.25;
	} else if (hit == 3){
		col = vec3(0.10, 0.80, 0.35) * (0.45 + 0.70 * clamp(abs(dot(hit_n.xyz, sun_dir())), 0.0, 1.0));
	} else if (hit == 4){
		col = vec3(0.85, 0.88, 0.92) * (0.45 + 0.70 * clamp(abs(dot(hit_n.xyz, sun_dir())), 0.0, 1.0));
	} else if (hit == 5){
		col = vec3(0.82, 0.93, 1.0);
	} else {
		// outer sky (room environment)
		vec3 d = normalize(v.xyz);
		float h = clamp(d.z * 0.5 + 0.5, 0.0, 1.0);
		col = mix(vec3(0.72, 0.82, 0.95), vec3(0.16, 0.36, 0.72), h);
	}

	col = col / (1.0 + col);
	col = pow(col, vec3(0.6));

	vec2 vq = uv - 0.5;
	col *= 1.0 - 0.45 * dot(vq, vq);
	vec2 cs = uv - 0.5;
	cs.x *= aspect;
	float cdist = length(cs);
	col = mix(col, vec3(0.0), (1.0 - smoothstep(0.0036, 0.0046, cdist)) * 0.45);
	col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0022, 0.0030, cdist));
	return col;
}

void fragment(){
	COLOR = vec4(render_scene(UV), 1.0);
}
