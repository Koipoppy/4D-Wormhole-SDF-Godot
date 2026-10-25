// ============================================================================
//  四维空间 SDF 引擎 + 虫洞 —— 平行层 + 圆盘喉口 (v22)
//
//  数学模型:
//   · 两个宇宙 = w 轴上的两张平行层: B (w=0, 家) / C (w=+24, 远·暖)。
//     每层是平直 3D 空间: 地板超平面 {z=-2, w=w_i} 的精确 2-平面距离场。
//   · 虫洞口 = 圆盘 (半径 mouth_r): 一对圆盘位于同一 (x,y,z)、只差 w ——
//     跨越盘面平面且交点在盘内时执行平移映射 p.w ±= 24 (方向不变)。
//     映射发生在盘面上 (零厚度喉极限), 等距变换 ⇒ 盘面两侧图像严格衔接,
//     穿越光影连续 —— 这是 Morris–Thorne 喉零厚度极限的标准实现。
//   · 喉口附近光线弯曲: Schwarzschild 光子轨道伪牛顿积分 (每个盘心一台"引力源"),
//     爱因斯坦环 / 盘缘多重像 = 方程的涌现。
//   · 第二对圆盘 (同在 B 层, x=±120) = 同一层内的快速远距通道 (Δ = 240m)。
//
//  圆盘对: D_B(30,3,-40,w=0) ↔ D_C(30,3,-40,w=24), Δ=(0,0,0,24)
//          D_E1(-120,3,60,w=0) ↔ D_E2(120,3,60,w=0), Δ=(240,0,0,0)
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
uniform float mouth_r = 3.0;       // 喉口圆盘半径
uniform float rs = 1.5;            // 喉口质量 (史瓦西半径): 光线弯曲强度

const int MAX_STEPS = 400;
const float MAX_DIST = 500.0;
const float FLOOR_Z = -2.0;

const float W_B = 0.0;     // 宇宙 B (家)
const float W_C = 24.0;    // 宇宙 C (远·暖)

// ---- 圆盘喉口 (与 scripts/main.gd 保持一致) ----
const float DISC_Z = 3.0;                          // 跨层虫洞对的盘面 z (悬空 5m)
const vec2 DISC_BC_XY = vec2(30.0, -40.0);         // 盘心 (x,y)
const float EX_X1 = -120.0;                        // 快速通道 E1 盘面 x
const float EX_X2 = 120.0;                         // 快速通道 E2 盘面 x
const vec2 EX_YZ = vec2(0.0, 3.0);                 // 快速通道盘心 (y,z)

// ============================================================================
//  哈希 / 星空 (按所在宇宙着色: B 中性偏冷 / C 暖金)
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

// 所在层 w → 星空 (B 中性 / C 暖金)
vec3 sky_col(vec4 rd, float w){
	float wC = smoothstep(6.0, 18.0, w);
	vec3 base = mix(vec3(0.010, 0.012, 0.030), vec3(0.030, 0.016, 0.008), wC);
	vec3 stT = mix(vec3(1.0), vec3(1.25, 0.90, 0.55), wC);
	vec4 rdw = rd + vec4(0.0, 0.0, 0.0, w * 0.01);
	vec3 col = base;
	col += star_layer(rdw, 15.0, 0.980, 1.0, stT);
	col += star_layer(rdw, 28.0, 0.970, 0.6, stT);
	col += star_layer(rdw, 52.0, 0.958, 0.45, stT);
	return col;
}

// ============================================================================
//  引力透镜: Schwarzschild 光子轨道伪牛顿积分 (每个盘心一个引力源)
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
//  场景 SDF (完整 4D): 两张层的地板超平面
// ============================================================================

vec2 map(vec4 p){
	// 地板 = 超平面 {z=FLOOR_Z, w=w_i} 的精确 2-平面距离
	// (w 项自动门控: 只有所在层附近的地板会被命中)
	float dB = length(vec2(p.z - FLOOR_Z, p.w - W_B));
	float dC = length(vec2(p.z - FLOOR_Z, p.w - W_C));
	vec2 res = vec2(dB, 1.0);
	if (dC < res.x) res = vec2(dC, 2.0);
	return res;
}

// 地板法线 (解析): {z=-2, w=w_i} 面的法向在 (z,w) 子空间内
vec4 floor_normal(float mid, vec4 p){
	float dw = (mid < 1.5) ? (p.w - W_B) : (p.w - W_C);
	return normalize(vec4(0.0, p.z - FLOOR_Z, 0.0, dw));
}

// 地板棋盘 (解析抗锯齿; 按层着色: B 中性冷 / C 暖)
vec3 floor_albedo(float mid, vec4 p){
	float ck = mod(floor(p.x * 0.5) + floor(p.y * 0.5), 2.0);
	float fw = fwidth(p.x * 0.5) + fwidth(p.y * 0.5);
	ck = mix(ck, 0.5, clamp(fw * 1.5, 0.0, 1.0));
	float uni = smoothstep(6.0, 18.0, p.w);
	vec3 a = mix(vec3(0.095, 0.105, 0.140), vec3(0.125, 0.080, 0.058), uni);
	vec3 b = mix(vec3(0.270, 0.300, 0.370), vec3(0.380, 0.270, 0.175), uni);
	return mix(a, b, ck);
}

// ============================================================================
//  主渲染: 平直光线步进 + 圆盘喉口映射 + 引力弯曲
// ============================================================================

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = cam_pos;

	// 每条光线每对喉口只映射一次; 离开盘面区域后重置 (允许返回)
	bool used_bc = false;
	bool used_ex = false;
	float travel = 0.0;
	bool hit = false;
	float hit_mid = 1.0;

	for (int i = 0; i < MAX_STEPS; i++){
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
		float dB = length(p - vec4(DISC_BC_XY.x, DISC_BC_XY.y, DISC_Z, W_B));
		float dC = length(p - vec4(DISC_BC_XY.x, DISC_BC_XY.y, DISC_Z, W_C));
		float d3 = length(p - vec4(EX_E1_X, EX_YZ.x, EX_YZ.y, W_B));
		float d4 = length(p - vec4(EX_E2_X, EX_YZ.x, EX_YZ.y, W_B));
		float dm = min(min(dB, dC), min(d3, d4));
		float dt = min(s.x * 0.9, 3.0);
		if (dm > mouth_r){
			dt = min(dt, max((dm - mouth_r) * 0.35, 0.06));
		}

		// ---- 引力弯曲 (四盘心, 与步长耦合) ----
		bend_ray(v, p, vec4(DISC_BC_XY.x, DISC_BC_XY.y, DISC_Z, W_B), dt);
		bend_ray(v, p, vec4(DISC_BC_XY.x, DISC_BC_XY.y, DISC_Z, W_C), dt);
		bend_ray(v, p, vec4(EX_E1_X, EX_YZ.x, EX_YZ.y, W_B), dt);
		bend_ray(v, p, vec4(EX_E2_X, EX_YZ.x, EX_YZ.y, W_B), dt);

		// ---- 圆盘喉口穿越 (平面对应, 方向不变, 无缝) ----
		vec4 prev = p;
		p += v * dt;
		travel += dt;

		// 跨层对: 跨越 z = DISC_Z 平面且交点在盘内 → w ± 24
		if (!used_bc && (prev.z - DISC_Z) * (p.z - DISC_Z) < 0.0){
			float tt = (DISC_Z - prev.z) / (p.z - prev.z);
			vec2 off = vec2(prev.x + (p.x - prev.x) * tt - DISC_BC_XY.x,
			                prev.y + (p.y - prev.y) * tt - DISC_BC_XY.y);
			if (length(off) < mouth_r){
				p.w += (p.w < 12.0) ? W_C - W_B : W_B - W_C;
				used_bc = true;
			}
		}
		// 快速通道对: 跨越 x = EX_E1_X 或 EX_E2_X 平面且交点在盘内 → x ± 240
		if (!used_ex && (prev.x - EX_E1_X) * (p.x - EX_E1_X) < 0.0){
			float tt = (EX_E1_X - prev.x) / (p.x - prev.x);
			vec2 off = vec2(prev.y + (p.y - prev.y) * tt - EX_YZ.x,
			                prev.z + (p.z - prev.z) * tt - EX_YZ.y);
			if (length(off) < mouth_r){
				p.x += EX_E2_X - EX_E1_X;
				used_ex = true;
			}
		} else if (!used_ex && (prev.x - EX_E2_X) * (p.x - EX_E2_X) < 0.0){
			float tt = (EX_E2_X - prev.x) / (p.x - prev.x);
			vec2 off = vec2(prev.y + (p.y - prev.y) * tt - EX_YZ.x,
			                prev.z + (p.z - prev.z) * tt - EX_YZ.y);
			if (length(off) < mouth_r){
				p.x += EX_E1_X - EX_E2_X;
				used_ex = true;
			}
		}

		// 离开盘面区域后重置 (允许再次穿越)
		if (used_bc && abs(p.z - DISC_Z) > 14.0){
			used_bc = false;
		}
		if (used_ex && abs(p.x - EX_E1_X) > 30.0 && abs(p.x - EX_E2_X) > 30.0){
			used_ex = false;
		}
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
		float uni = smoothstep(6.0, 18.0, p.w);
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
//  诊断视图 ②: 楼层图 (x, w) —— 两层平行宇宙 + 圆盘喉口 + 跨层连线
// ============================================================================

vec3 floor_map(vec2 uv){
	vec2 suv = uv - 0.5;
	float qx = cam_pos.x + suv.x * 400.0 * aspect;
	float qw = cam_pos.w + suv.y * 70.0;
	vec3 col = vec3(0.012, 0.015, 0.028);
	// 两层地板线 (w = W_B / W_C)
	float dfl = min(abs(qw - W_B), abs(qw - W_C));
	col = mix(col, vec3(0.45, 0.70, 0.55), (1.0 - smoothstep(0.0, 0.4, dfl)) * 0.9);
	// 喉口圆盘位置 (点)
	float dm = 1e9;
	dm = min(dm, length(vec2(qx - DISC_BC_XY.x, qw - W_B)));
	dm = min(dm, length(vec2(qx - DISC_BC_XY.x, qw - W_C)));
	dm = min(dm, length(vec2(qx - EX_E1_X, qw - W_B)));
	dm = min(dm, length(vec2(qx - EX_E2_X, qw - W_B)));
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
