// ============================================================================
//  四维空间 SDF 引擎 + 虫洞 —— 度规实现 + 同空间零厚度喉口对 (v34)
//
//  · 主虫洞 = Morris–Thorne 度规的超悬链面嵌入 (与 0.0.2 同一实现):
//        ρ = b₀·cosh(w/b₀) ,  ρ = |xyz|
//    两个宇宙 = 同一张弯曲流形的两端: B (w<0, 家·冷) / C (w>0, 远·暖)。
//    光线沿流形测地线传播, 透镜与多重像是度规的真实结果。
//
//  · 第二对虫洞 (连接同一个三维空间): 两个口都开在宇宙B 内。
//    口 = 火山式圆顶顶部的球口 (地板高度场隆起 + 球面开洞)。
//    对口按 **零厚度喉口 (薄壳等同)** 连接 —— Visser 薄壳虫洞的标准做法:
//    跨过球口时位置按平移映射、方向按球面法向反射, 等距变换 ⇒ 口两侧图像严格衔接,
//    没有焊接面、没有物理管体, 因此渲染与主喉口同样干净。
//  · 两个彩色球体 (红/青) = 4D 球 ∩ 流形, 标出两个口。
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(30.16, 0.0, 1.6, -9.0);
uniform vec4 cam_fwd = vec4(-1.0, 0.0, 0.0, 0.0);
uniform vec4 cam_right = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 cam_up = vec4(0.0, 1.0, 0.0, 0.0);
uniform float fov_scale = 1.0;
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float view_mode = 0.0;     // 0 第一人称 | 1 嵌入图 (w, ρ)
uniform float throat_r = 3.0;      // Morris–Thorne 喉半径 b₀

const int MAX_STEPS = 1200;
const float W_ESCAPE = 55.0;

// ---- 同空间喉口对: 两个球口 + 火山圆顶 (与 scripts/main.gd 保持一致) ----
const vec4 MA = vec4(0.0,  20.10,  9.0,  -7.8);   // 口 A 中心 (火山顶)
const vec4 MB = vec4(0.0, -30.20,  9.0,  -9.0);   // 口 B 中心 (火山顶)
const float RM = 5.0;                              // 球口半径
const float HILL_H = 9.0;                          // 火山圆顶高度
const float HILL_S = 7.0;                          // 火山圆顶半径尺度
const vec4 OBJ0_C = vec4(0.0,  13.00,  2.50,  -6.5);  // 红球
const vec4 OBJ1_C = vec4(0.0, -23.00,  2.50,  -7.5);  // 青球
const float OBJ_R = 2.6;

// ============================================================================
//  超曲面 ρ = b₀·cosh(w/b₀)
// ============================================================================

float surf_f(vec4 p){
	return length(p.xyz) - throat_r * cosh(p.w / throat_r);
}

vec4 surf_grad(vec4 p){
	float rho = length(p.xyz);
	vec3 g3 = (rho > 0.0001) ? p.xyz / rho : vec3(0.0);
	return vec4(g3, -sinh(p.w / throat_r));
}

vec4 surf_project(vec4 p){
	for (int i = 0; i < 3; i++){
		vec4 g = surf_grad(p);
		float f = surf_f(p);
		p -= g * f / max(dot(g, g), 1e-7);
	}
	return p;
}

vec4 surf_normal(vec4 p){
	return normalize(surf_grad(p));
}

// ============================================================================
//  地板: 悬链面 θ=π/2 截面 + 火山圆顶高度场
// ============================================================================

float hill(vec4 p){
	float dA = length(vec3(p.x - MA.x, p.y - MA.y, p.w - MA.w));
	float dB = length(vec3(p.x - MB.x, p.y - MB.y, p.w - MB.w));
	return HILL_H * (exp(-pow(dA / HILL_S, 2.0)) + exp(-pow(dB / HILL_S, 2.0)));
}

float cat_sdf(vec4 p){
	float zz = p.z - hill(p);
	float rho_xy = length(p.xy);
	float dr = rho_xy - throat_r * cosh(p.w / throat_r);
	return sign(zz) * sqrt(zz * zz + dr * dr);
}

vec4 cat_normal(vec4 p){
	float e = 0.01;
	return normalize(vec4(
		cat_sdf(p + vec4(e, 0.0, 0.0, 0.0)) - cat_sdf(p - vec4(e, 0.0, 0.0, 0.0)),
		cat_sdf(p + vec4(0.0, e, 0.0, 0.0)) - cat_sdf(p - vec4(0.0, e, 0.0, 0.0)),
		cat_sdf(p + vec4(0.0, 0.0, e, 0.0)) - cat_sdf(p - vec4(0.0, 0.0, e, 0.0)),
		cat_sdf(p + vec4(0.0, 0.0, 0.0, e)) - cat_sdf(p - vec4(0.0, 0.0, 0.0, e))));
}

vec3 cat_albedo(vec4 p){
	vec3 coord = vec3(p.x, p.y, p.w) * 0.55;
	float ck = mod(floor(coord.x) + floor(coord.y) + floor(coord.z), 2.0);
	float fw = fwidth(coord.x) + fwidth(coord.y) + fwidth(coord.z);
	if (isnan(fw) || isinf(fw) || fw < 0.0){
		fw = 1.0;
	}
	ck = mix(ck, 0.5, clamp(fw * 1.5, 0.0, 1.0));
	return mix(vec3(0.30, 0.31, 0.34), vec3(0.62, 0.61, 0.62), ck);
}

// ============================================================================
//  星空
// ============================================================================

float hash14(vec4 p){
	p = fract(p * 0.1031);
	p += dot(p, p.wzxy + vec4(33.33));
	return fract((p.x + p.y) * p.z);
}

vec3 star_layer(vec4 rd, float scale, float thr, float amp, float uni){
	vec4 g = rd * scale;
	vec4 id = floor(g);
	vec4 f = fract(g) - 0.5;
	float h = hash14(id + 0.5);
	vec3 col = vec3(0.0);
	if (h > thr){
		float k = (h - thr) / (1.0 - thr);
		float b = (1.0 - smoothstep(0.0, 0.4, length(f))) * (0.3 + 0.7 * k);
		b *= 0.65 + 0.35 * sin(time_s * (1.0 + k * 6.0) + h * 613.0);
		vec3 tint = mix(vec3(1.0, 0.82, 0.62), vec3(0.65, 0.78, 1.0), fract(h * 37.0));
		tint = mix(tint, tint.zyx, uni * 0.55);
		col = tint * b * amp * 1.7;
	}
	return col;
}

vec3 sky_col(vec4 v){
	float uni = smoothstep(-3.0, 3.0, v.w * 6.0);
	vec3 col = mix(vec3(0.008, 0.010, 0.026), vec3(0.026, 0.012, 0.008), uni);
	col += star_layer(v, 15.0, 0.980, 1.0, uni);
	col += star_layer(v, 28.0, 0.970, 0.65, uni);
	col += star_layer(v, 52.0, 0.958, 0.45, uni);
	return col;
}

vec4 sun_dir(float t){
	return normalize(vec4(0.35 + 0.2 * sin(t * 0.05), 0.25, 0.6, 0.25 * sin(t * 0.03)));
}

// ============================================================================
//  同空间零厚度喉口: 段与球口相交 → 平移映射 + 球面法向反射 (等距)
// ============================================================================

bool ball_transfer(vec4 prev, inout vec4 p, inout vec4 v, vec4 m1, vec4 m2){
	vec4 d = p - prev;
	float a = dot(d, d);
	if (a < 1e-12){
		return false;
	}
	vec4 f = prev - m1;
	float b = 2.0 * dot(f, d);
	float c = dot(f, f) - RM * RM;
	float disc = b * b - 4.0 * a * c;
	if (disc < 0.0){
		return false;
	}
	float sq = sqrt(disc);
	float t = (-b - sq) / (2.0 * a);
	if (t < 0.0 || t > 1.0){
		return false;
	}
	vec4 hitp = prev + d * t;
	vec4 nrm = (hitp - m1) / RM;
	vec4 dir = normalize(v - 2.0 * dot(v, nrm) * nrm);
	vec4 base = m2 + (hitp - m1);
	p = base + dir * (sqrt(a) * (1.0 - t));
	v = dir;
	return true;
}

// ============================================================================
//  嵌入图 (w, ρ)
// ============================================================================

vec3 embed_diagram(vec2 uv){
	float W = mix(-32.0, 32.0, uv.x);
	float R = mix(44.0, 0.0, uv.y);
	float curve = throat_r * cosh(W / throat_r);
	vec3 col = vec3(0.012, 0.015, 0.028);
	vec2 g = abs(fract(vec2(uv.x * 16.0, uv.y * 11.0)) - 0.5);
	col += vec3(0.05, 0.07, 0.10) * (1.0 - smoothstep(0.0, 0.06, min(g.x, g.y)));
	float dc = abs(R - curve);
	col = mix(col, vec3(0.95, 0.85, 0.45), (1.0 - smoothstep(0.0, 0.35, dc)) * 0.95);
	float dc_cam = length(vec2(W - cam_pos.w, R - length(cam_pos.xyz)));
	col = mix(col, vec3(0.3, 0.9, 0.5), (1.0 - smoothstep(0.0, 0.8, dc_cam)) * 0.9);
	float dth = length(vec2(W, R - throat_r));
	col = mix(col, vec3(0.4, 0.75, 1.0), (1.0 - smoothstep(0.0, 0.5, dth)) * 0.8);
	col *= 1.0 - 0.35 * dot(uv - 0.5, uv - 0.5) * 2.0;
	return col;
}

// ============================================================================
//  主渲染: 流形上的测地线步进 + 同空间球口过渡
// ============================================================================

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = surf_project(cam_pos);

	float travel = 0.0;
	bool hit = false;
	int obj_hit = -1;

	for (int i = 0; i < MAX_STEPS; i++){
		float df = cat_sdf(p);
		float dobj = min(length(p - OBJ0_C) - OBJ_R, length(p - OBJ1_C) - OBJ_R);
		if (dobj < 0.02){
			obj_hit = (length(p - OBJ0_C) < length(p - OBJ1_C)) ? 0 : 1;
			break;
		}
		if (abs(df) < 0.02){
			hit = true;
			break;
		}
		float h = clamp(0.5 * abs(df) + 0.04, 0.05, 0.7);
		float near_throat = clamp(1.0 - length(p.xyz) / (throat_r * 6.0), 0.0, 1.0);
		h *= 1.0 - 0.55 * near_throat;

		vec4 prev = p;
		p += v * h;
		p = surf_project(p);
		vec4 n = surf_normal(p);
		v -= n * dot(v, n);
		v = normalize(v);
		travel += h;

		// 同空间球口: 跨口位置映射 + 方向反射 (等距, 无缝)
		if (ball_transfer(prev, p, v, MA, MB)){}
		else if (ball_transfer(prev, p, v, MB, MA)){}

		if (travel > 200.0){
			break;
		}
		if (abs(p.w) > W_ESCAPE){
			break;
		}
	}

	if (!hit && obj_hit < 0){
		float df_end = cat_sdf(p);
		if (abs(df_end) < 1.2){
			hit = true;
			travel = max(travel, 180.0);
		}
	}

	vec3 col;
	if (obj_hit >= 0){
		vec4 c = (obj_hit == 0) ? OBJ0_C : OBJ1_C;
		vec3 base = (obj_hit == 0) ? vec3(0.95, 0.15, 0.12) : vec3(0.05, 0.65, 1.0);
		vec4 n = normalize(p - c);
		vec4 ldir = sun_dir(time_s);
		float dif = clamp(abs(dot(n, ldir)), 0.0, 1.0);
		col = base * (0.45 + 0.65 * dif) + base * 0.18;
	} else if (hit){
		vec4 n = cat_normal(p);
		vec4 ldir = sun_dir(time_s);
		float dif = clamp(dot(n, ldir), 0.0, 1.0);
		float amb = 0.30;
		vec3 alb = cat_albedo(p);
		col = alb * (amb * 0.85 + 0.78 * dif);
		float uni = smoothstep(-3.0, 3.0, p.w * 2.0);
		vec3 fogc = mix(vec3(0.045, 0.055, 0.095), vec3(0.085, 0.050, 0.038), uni);
		float fog = 1.0 - exp(-0.010 * travel);
		col = mix(col, fogc, clamp(fog, 0.0, 1.0));
	} else {
		col = sky_col(v);
	}

	col = col / (1.0 + col);
	col = pow(col, vec3(0.6));

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
	vec3 col;
	if (view_mode > 0.5 && view_mode < 1.5){
		col = embed_diagram(UV);
	} else {
		col = render_scene(UV);
	}
	COLOR = vec4(col, 1.0);
}
