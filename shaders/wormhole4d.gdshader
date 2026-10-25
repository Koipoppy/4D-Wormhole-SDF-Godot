// ============================================================================
//  四维空间 SDF 引擎 + 虫洞 —— 平行层 + 球形喉口 (v21)
//
//  数学模型 (三个参考链接的实现):
//   · 三个宇宙 = w 轴上的三张平行层: A (w=-24, 冷蓝) / B (w=0, 中性) / C (w=+24, 暖金)。
//     每层是平直 3D 空间: 地板超平面 {z=-2, w=w_i} 的精确 2-平面距离场。
//   · 虫洞口 = 球形喉口 (半径 mouth_r): 球内区域通过平移映射与另一层的对应球
//     等同 (p += Δ, Δ 沿 w 轴 = 纯第四维位移)。光线每条映射一次 (防止振荡)。
//   · 喉口附近的光线弯曲: Schwarzschild 光子轨道伪牛顿积分
//        d²x/dλ² = -(3/2)·rs·h²·rel/r⁵
//     爱因斯坦环 / 喉口边缘的多重像 = 方程的涌现。
//   · 穿越观察者 = 飞越喉口球边界 (映射为等距变换, 边界处两侧图像衔接)。
//
//  对: M1(B层) ↔ M2(C层) —— 跨层虫洞, Δ = (0,0,0,24)
//     M3(B层) ↔ M4(B层) —— 同层快速通道, Δ = (240,0,0,0)
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(0.0, 1.7, 2.0, 0.0);
uniform vec4 cam_fwd = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 cam_right = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 cam_up = vec4(0.0, 1.0, 0.0, 0.0);
uniform float fov_scale = 1.0;
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float view_mode = 0.0;     // 0 第一人称 | 1 楼层图 (x,w)
uniform float mouth_r = 3.0;       // 喉口球半径
uniform float rs = 1.5;            // 喉口质量 (史瓦西半径): 光线弯曲强度

const int MAX_STEPS = 400;
const float MAX_DIST = 500.0;
const float FLOOR_Z = -2.0;

const float W_A = -24.0;
const float W_B = 0.0;
const float W_C = 24.0;

// ---- 四个喉口球心 (与 scripts/main.gd 保持一致) ----
const vec4 M1 = vec4(30.0, 3.0, -40.0, 0.0);     // B 层 → C 层
const vec4 M2 = vec4(30.0, 3.0, -40.0, 24.0);    // C 层 → B 层
const vec4 M3 = vec4(-120.0, 3.0, 60.0, 0.0);    // B 层快速通道 A 端
const vec4 M4 = vec4(120.0, 3.0, 60.0, 0.0);     // B 层快速通道 B 端

// ============================================================================
//  哈希 / 星空 (按所在宇宙着色)
// ============================================================================

float hash14(vec4 p){
	p = fract(p * 0.1031);
	p += dot(p, p.wzxy + vec4(33.33));
	return fract((p.x + p.y) * p.z);
}

vec3 star_layer(vec4 rd, float scale, float thr, float amp, vec3 tint){
	vec4 g = rd * scale;
	vec4 id = floor(g);
	vec4 f = fract(g) - 0.5;
	float h = hash14(id + 0.5);
	vec3 col = vec3(0.0);
	if (h > thr){
		float k = (h - thr) / (1.0 - thr);
		float b = (1.0 - smoothstep(0.0, 0.4, length(f))) * (0.3 + 0.7 * k);
		b *= 0.65 + 0.35 * sin(time_s * (1.0 + k * 6.0) + h * 613.0);
		col = tint * b * amp * 1.7;
	}
	return col;
}

// 所在层 w → 星空 (A 冷蓝 / B 中性 / C 暖金)
vec3 sky_col(vec4 rd, float w){
	float wA = 1.0 - smoothstep(-20.0, -8.0, w);
	float wC = smoothstep(8.0, 20.0, w);
	float wB = clamp(1.0 - wA - wC, 0.0, 1.0);
	vec3 base = vec3(0.006, 0.010, 0.032) * wA + vec3(0.012, 0.012, 0.016) * wB + vec3(0.030, 0.016, 0.008) * wC;
	vec3 stT = vec3(0.70, 0.82, 1.20) * wA + vec3(1.0) * wB + vec3(1.25, 0.90, 0.55) * wC;
	vec4 rdw = rd + vec4(0.0, 0.0, 0.0, w * 0.01);
	vec3 col = base;
	col += star_layer(rdw, 15.0, 0.980, 1.0, stT);
	col += star_layer(rdw, 28.0, 0.970, 0.6, stT);
	col += star_layer(rdw, 52.0, 0.958, 0.45, stT);
	return col;
}

// ============================================================================
//  引力透镜: Schwarzschild 光子轨道伪牛顿积分
// ============================================================================

void bend_ray(inout vec4 v, vec4 p, vec4 m, float dt){
	vec4 rel = p - m;
	float r2 = dot(rel, rel);
	if (r2 < 400.0 && r2 > 0.04){
		float h2 = max(r2 - dot(rel, v) * dot(rel, v), 0.0);
		float r5 = r2 * r2 * sqrt(r2);
		v = normalize(v - (1.5 * rs * h2 / r5) * rel * dt);
	}
}

// ============================================================================
//  场景 SDF (完整 4D): 三张层的地板超平面
// ============================================================================

vec2 map(vec4 p){
	// 地板 = 超平面 {z=FLOOR_Z, w=w_i} 的精确 2-平面距离
	// (w 项自动门控: 只有所在层附近的地板会被命中)
	float dA = length(vec2(p.z - FLOOR_Z, p.w - W_A));
	float dB = length(vec2(p.z - FLOOR_Z, p.w - W_B));
	float dC = length(vec2(p.z - FLOOR_Z, p.w - W_C));
	vec2 res = vec2(dA, 1.0);
	if (dB < res.x) res = vec2(dB, 2.0);
	if (dC < res.x) res = vec2(dC, 3.0);
	return res;
}

// 地板法线 (解析)
vec4 floor_normal(float mid, vec4 p){
	float dz = p.z - FLOOR_Z;
	float dw = (mid < 1.5) ? (p.w - W_A) : ((mid < 2.5) ? (p.w - W_B) : (p.w - W_C));
	return normalize(vec4(0.0, dz, 0.0, dw));
}

// 地板棋盘 (解析抗锯齿; 按层着色)
vec3 floor_albedo(float mid, vec4 p){
	float ck = mod(floor(p.x * 0.5) + floor(p.y * 0.5), 2.0);
	float fw = fwidth(p.x * 0.5) + fwidth(p.y * 0.5);
	ck = mix(ck, 0.5, clamp(fw * 1.5, 0.0, 1.0));
	float uni = smoothstep(-16.0, 16.0, p.w);
	vec3 a = mix(vec3(0.085, 0.095, 0.130), vec3(0.115, 0.075, 0.055), uni);
	vec3 b = mix(vec3(0.255, 0.290, 0.360), vec3(0.360, 0.260, 0.170), uni);
	return mix(a, b, ck);
}

// ============================================================================
//  引力透镜下的喉口窗口: 主渲染
// ============================================================================

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = cam_pos;

	// 每条光线每对喉口只映射一次
	bool used1 = false;
	bool used2 = false;
	float travel = 0.0;
	bool hit = false;
	float hit_mid = 1.0;

	for (int i = 0; i < MAX_STEPS; i++){
		// ---- 喉口球穿越: 向内进入球域 → 平移到对侧球 (方向不变) ----
		float d1 = length(p - M1);
		float d2 = length(p - M2);
		float d3 = length(p - M3);
		float d4 = length(p - M4);
		if (!used1 && d1 < mouth_r && d1 < d2 && dot(v, M1 - p) > 0.0){
			p += M2 - M1;
			used1 = true;
		} else if (!used1 && d2 < mouth_r && d2 < d1 && dot(v, M2 - p) > 0.0){
			p += M1 - M2;
			used1 = true;
		}
		if (!used2 && d3 < mouth_r && d3 < d4 && dot(v, M3 - p) > 0.0){
			p += M4 - M3;
			used2 = true;
		} else if (!used2 && d4 < mouth_r && d4 < d3 && dot(v, M4 - p) > 0.0){
			p += M3 - M4;
			used2 = true;
		}

		vec2 s = map(p);
		if (s.x < 0.0015 + 0.0025 * travel){
			hit = true;
			hit_mid = s.y;
			break;
		}
		if (travel > MAX_DIST){
			break;
		}

		// 喉口外侧收紧步长 (透镜充分积分)
		float dm = min(min(d1, d2), min(d3, d4));
		float dt = min(s.x * 0.9, 3.0);
		if (dm > mouth_r){
			dt = min(dt, max((dm - mouth_r) * 0.35, 0.06));
		}

		// 引力弯曲 (四喉口)
		bend_ray(v, p, M1, dt);
		bend_ray(v, p, M2, dt);
		bend_ray(v, p, M3, dt);
		bend_ray(v, p, M4, dt);

		p += v * dt;
		travel += dt;
	}

	vec3 sky = sky_col(v, cam_pos.w);
	vec3 col;

	if (hit){
		vec4 n = floor_normal(hit_mid, p);
		vec4 ldir = normalize(vec4(0.35, 0.30, 0.55, 0.20));
		float dif = clamp(dot(n, ldir), 0.0, 1.0);
		float amb = 0.30;
		vec3 alb = floor_albedo(hit_mid, p);
		col = alb * (amb + 0.9 * dif);
		float uni = smoothstep(-16.0, 16.0, p.w);
		vec3 fogc = mix(vec3(0.050, 0.060, 0.100), vec3(0.090, 0.055, 0.040), uni);
		float fog = 1.0 - exp(-0.010 * travel);
		col = mix(col, fogc, clamp(fog, 0.0, 1.0));
	} else {
		col = sky;
	}

	// 色调映射 + gamma
	col = col / (1.0 + col);
	col = pow(col, vec3(0.6));

	// 晕影 + 准星 (清晰小点, 纵横比校正)
	vec2 vq = uv - 0.5;
	col *= 1.0 - 0.5 * dot(vq, vq);
	vec2 cs = uv - 0.5;
	cs.x *= aspect;
	float cdist = length(cs);
	col = mix(col, vec3(0.0), (1.0 - smoothstep(0.0036, 0.0046, cdist)) * 0.45);
	col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0022, 0.0030, cdist));

	return col;
}

// ============================================================================
//  诊断视图 ②: 楼层图 (x, w) —— 三层平行宇宙 + 四个喉口
// ============================================================================

vec3 floor_map(vec2 uv){
	vec2 suv = uv - 0.5;
	float qx = cam_pos.x + suv.x * 400.0 * aspect;
	float qw = cam_pos.w + suv.y * 70.0;
	vec3 col = vec3(0.012, 0.015, 0.028);
	// 三层地板线 (w = W_A/W_B/W_C)
	float dfl = min(min(abs(qw - W_A), abs(qw - W_B)), abs(qw - W_C));
	col = mix(col, vec3(0.45, 0.70, 0.55), (1.0 - smoothstep(0.0, 0.4, dfl)) * 0.9);
	// 四个喉口位置 (圆点)
	float dm = 1e9;
	dm = min(dm, length(vec2(qx - M1.x, qw - M1.w)));
	dm = min(dm, length(vec2(qx - M2.x, qw - M2.w)));
	dm = min(dm, length(vec2(qx - M3.x, qw - M3.w)));
	dm = min(dm, length(vec2(qx - M4.x, qw - M4.w)));
	col = mix(col, vec3(0.35, 0.8, 1.0), (1.0 - smoothstep(0.0, 1.0, dm)) * 0.95);
	// 相机标记
	float dc = length(vec2(qx - cam_pos.x, qw - cam_pos.w));
	col = mix(col, vec3(0.3, 1.0, 0.5), (1.0 - smoothstep(0.0, 1.2, dc)) * 0.9);
	col *= 1.0 - 0.35 * dot(suv, suv) * 2.0;
	return col;
}

void fragment(){
	vec3 col;
	if (view_mode > 0.5){
		col = floor_map(UV);
	} else {
		col = render_scene(UV);
	}
	COLOR = vec4(col, 1.0);
}
