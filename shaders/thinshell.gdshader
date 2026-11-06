// ============================================================================
//  薄壳动态虫洞 (thin-shell dynamic wormhole)
//
//  · 环境: Ellis / Morris–Thorne 三维空间，嵌在 R⁴ 中
//        ρ = b₀·cosh(w/b₀),  ρ = |xyz|
//    这里只取其中一个房间:  |x|,|y|,|z| ≤ ROOM_L,  W_MIN ≤ w ≤ W_MAX。
//  · 虫洞: 两个球口。口内的球体被挖掉，两个球面边界按局部切标架认同；
//    光线进入一个口就从配对口出来。两个口可以逐帧移动（uniform 更新）。
//  · 这是准静态近似: 每帧冻结当前几何，光线按瞬时空间度规积分；
//    忽略光行时与度规的时间导数项。
//
//  这不是"任意传送贴图"：转移只在两个口的边界上发生，并且用两个口中心
//  的正交切标架做等距映射（保长度、保角度）。
// ============================================================================
shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(20.0, -7.0, 1.0, 8.0);
uniform vec4 cam_fwd = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 cam_right = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 cam_up = vec4(0.0, 0.0, 1.0, 0.0);
uniform float fov_scale = 1.0;
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float throat_r = 3.0;

const int MAX_STEPS = 900;
const int MAX_BOUNCES = 6;
const vec3 ROOM_C = vec3(20.0, 0.0, 0.0);
const float ROOM_L = 8.0;
const float W_MIN = 6.0;
const float W_MAX = 9.6;

// ---- 薄壳口对 ----
uniform float pair_active = 1.0;
uniform float show_a = 1.0;
uniform float show_b = 1.0;
uniform float mouth_r = 1.4;
uniform float bump_r = 3.2;
uniform float bump_amp = 0.0;   // 局部 C∞ 形变强度；0 = 纯 Ellis
uniform vec4 a_c = vec4(16.0, 0.0, 0.0, 7.1);
uniform vec4 a_e1 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 a_e2 = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 a_e3 = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 b_c = vec4(24.0, 0.0, 0.0, 8.3);
uniform vec4 b_e1 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 b_e2 = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 b_e3 = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec3 color_a = vec3(0.15, 0.85, 1.0);
uniform vec3 color_b = vec3(1.0, 0.25, 0.65);

// ============================================================================
//  Ellis 超曲面 + 局部的 C∞ 形变
//
//  bump(x) 在 |x|<1 内为 exp(1 - 1/(1-x²))，在 |x|≥1 处及其所有导数都为 0。
//  所以表面在口球边界 |p-c|=mouth_r 处与 Ellis 光滑拼接；曲率变化只在球内。
// ============================================================================

float bump_val(float x){
	if (abs(x) >= 1.0) return 0.0;
	float y = 1.0 - x * x;
	return exp(1.0 - 1.0 / y);
}

float bump_deriv(float x){
	if (abs(x) >= 1.0) return 0.0;
	float y = 1.0 - x * x;
	return bump_val(x) * (-2.0 * x / (y * y));
}

float bump_pair(vec4 p){
	float r = max(bump_r, 0.0001);
	return bump_val(length(p - a_c) / r) + bump_val(length(p - b_c) / r);
}

vec4 bump_grad_pair(vec4 p){
	vec4 g = vec4(0.0);
	float r = max(bump_r, 0.0001);
	float da = length(p - a_c);
	if (da > 0.00001 && da < r){
		g += (bump_deriv(da / r) / r) * (p - a_c) / da;
	}
	float db = length(p - b_c);
	if (db > 0.00001 && db < r){
		g += (bump_deriv(db / r) / r) * (p - b_c) / db;
	}
	return g;
}

float surf_f(vec4 p){
	return length(p.xyz) - throat_r * cosh(p.w / throat_r) - bump_amp * bump_pair(p);
}

vec4 surf_grad(vec4 p){
	float rho = length(p.xyz);
	vec3 g3 = (rho > 0.0001) ? p.xyz / rho : vec3(0.0);
	vec4 base = vec4(g3, -sinh(p.w / throat_r));
	return base - bump_amp * bump_grad_pair(p);
}

vec4 surf_project(vec4 p){
	for (int i = 0; i < 3; i++){
		vec4 g = surf_grad(p);
		float f = surf_f(p);
		p -= g * f / max(dot(g, g), 1e-6);
	}
	return p;
}

vec4 surf_normal(vec4 p){
	return normalize(surf_grad(p));
}

// ============================================================================
//  房间: 立方体 + 两个 w 端壁
// ============================================================================

float room_dist(vec4 p){
	float boxd = ROOM_L - max(abs(p.x - ROOM_C.x), max(abs(p.y - ROOM_C.y), abs(p.z - ROOM_C.z)));
	return min(boxd, min(p.w - W_MIN, W_MAX - p.w));
}

vec4 room_normal(vec4 p){
	float ax = abs(p.x - ROOM_C.x);
	float ay = abs(p.y - ROOM_C.y);
	float az = abs(p.z - ROOM_C.z);
	float boxd = ROOM_L - max(ax, max(ay, az));
	float dw = min(p.w - W_MIN, W_MAX - p.w);
	if (dw < boxd){
		return vec4(0.0, 0.0, 0.0, (p.w - W_MIN < W_MAX - p.w) ? -1.0 : 1.0);
	}
	if (ax >= ay && ax >= az) return vec4(sign(p.x - ROOM_C.x), 0.0, 0.0, 0.0);
	if (ay >= az) return vec4(0.0, sign(p.y - ROOM_C.y), 0.0, 0.0);
	return vec4(0.0, 0.0, sign(p.z - ROOM_C.z), 0.0);
}

vec3 room_surface(vec4 p, vec4 n, vec4 ldir){
	vec2 uv;
	if (abs(n.x) > 0.5) uv = p.yz;
	else if (abs(n.y) > 0.5) uv = p.xz;
	else if (abs(n.z) > 0.5) uv = p.xy;
	else uv = p.xy;   // w 端壁

	vec2 cell = floor(uv * 0.42);
	float checker = mod(cell.x + cell.y, 2.0);
	float grad = clamp((p.w - W_MIN) / (W_MAX - W_MIN), 0.0, 1.0);
	vec3 base = mix(vec3(0.055, 0.085, 0.105), vec3(0.135, 0.095, 0.055), grad);
	vec3 tile = mix(vec3(0.105, 0.150, 0.185), vec3(0.230, 0.155, 0.085), grad);
	vec3 col = mix(base, tile, checker);

	vec2 f = abs(fract(uv * 0.42) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.030, min(f.x, f.y));
	col = mix(col, vec3(0.62, 0.72, 0.85), line * 0.38);

	float dif = clamp(dot(normalize(n), normalize(ldir)), 0.0, 1.0);
	col *= 0.85 + 0.45 * dif;
	return col;
}

// ============================================================================
//  口对: 在口中心的正交切标架里做局部等距映射
// ============================================================================

vec4 map_vec(vec4 v, vec4 e1, vec4 e2, vec4 e3, vec4 f1, vec4 f2, vec4 f3){
	vec3 c = vec3(dot(v, e1), dot(v, e2), dot(v, e3));
	return c.x * f1 + c.y * f2 + c.z * f3;
}

// ============================================================================
//  主渲染
// ============================================================================

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = cam_pos;

	float travel = 0.0;
	bool hit = false;
	int bounces = 0;
	int ignore = -1;       // 刚出来的口，跳过一帧防止回穿
	float rim_a = 0.0;
	float rim_b = 0.0;

	for (int i = 0; i < MAX_STEPS; i++){
		float da = length(p - a_c);
		float db = length(p - b_c);

		if (pair_active > 0.5){
			if (ignore != 0 && da < mouth_r && bounces < MAX_BOUNCES){
				vec4 off = map_vec(p - a_c, a_e1, a_e2, a_e3, b_e1, b_e2, b_e3);
				if (length(off) < 1e-4){
					off = map_vec(v, a_e1, a_e2, a_e3, b_e1, b_e2, b_e3);
				}
				off = normalize(off);
				p = surf_project(b_c + off * (mouth_r + 0.15));
				v = normalize(map_vec(v, a_e1, a_e2, a_e3, b_e1, b_e2, b_e3));
				v -= 2.0 * dot(v, off) * off;   // 薄壳两侧反向: 出口径向分量翻向外
				v = normalize(v);
				vec4 nv = surf_normal(p);
				v -= nv * dot(v, nv);
				v = normalize(v);
				ignore = 1;
				bounces++;
				continue;
			}
			if (ignore != 1 && db < mouth_r && bounces < MAX_BOUNCES){
				vec4 off = map_vec(p - b_c, b_e1, b_e2, b_e3, a_e1, a_e2, a_e3);
				if (length(off) < 1e-4){
					off = map_vec(v, b_e1, b_e2, b_e3, a_e1, a_e2, a_e3);
				}
				off = normalize(off);
				p = surf_project(a_c + off * (mouth_r + 0.15));
				v = normalize(map_vec(v, b_e1, b_e2, b_e3, a_e1, a_e2, a_e3));
				v -= 2.0 * dot(v, off) * off;
				v = normalize(v);
				vec4 nv = surf_normal(p);
				v -= nv * dot(v, nv);
				v = normalize(v);
				ignore = 0;
				bounces++;
				continue;
			}
		}

		if (show_a > 0.5 && ignore != 0){
			rim_a = max(rim_a, (1.0 - smoothstep(mouth_r, mouth_r + 0.12, da)) * step(mouth_r, da));
		}
		if (show_b > 0.5 && ignore != 1){
			rim_b = max(rim_b, (1.0 - smoothstep(mouth_r, mouth_r + 0.12, db)) * step(mouth_r, db));
		}
		ignore = -1;

		float rd = room_dist(p);
		if (rd < 0.02){
			hit = true;
			break;
		}
		float h = clamp(0.5 * rd + 0.02, 0.04, 0.5);

		p += v * h;
		p = surf_project(p);
		vec4 n = surf_normal(p);
		v -= n * dot(v, n);
		v = normalize(v);
		travel += h;

		if (travel > 200.0){
			break;
		}
	}

	vec3 col;
	if (hit){
		vec4 n = room_normal(p);
		vec4 ldir = normalize(vec4(0.35, 0.25, 0.60, 0.18));
		col = room_surface(p, n, ldir);
	} else {
		col = vec3(0.004, 0.005, 0.008);
	}

	float rim_strength = pair_active > 0.5 ? 0.55 : 0.22;   // 待定的口只画暗环
	col = mix(col, color_a, clamp(rim_a, 0.0, 1.0) * rim_strength);
	col = mix(col, color_b, clamp(rim_b, 0.0, 1.0) * rim_strength);

	// 色调映射 + gamma
	col = col / (1.0 + col);
	col = pow(col, vec3(0.6));

	// 晕影 + 准星
	vec2 vq = uv - 0.5;
	col *= 1.0 - 0.5 * dot(vq, vq);
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
