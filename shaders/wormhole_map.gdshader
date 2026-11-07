// ============================================================================
//  四维空间 SDF 引擎 + 虫洞 —— 度规实现 (v19)
//
//  数学模型 (来自三个参考链接的真实实现):
//
//  · 虫洞空间 = Morris–Thorne 零潮汐力度规
//        ds² = dl² + (l² + b₀²)·dΩ²
//    代入 l = b₀·sinh(u) 化为 b₀²cosh²u·(du² + dΩ²), 它有 **4D 欧氏空间中的
//    精确等距嵌入**:
//        P(u, θ, φ) = ( b₀·u ,  b₀·cosh(u)·n̂(θ,φ) ),   n̂ ∈ S² ⊂ ℝ³
//    即超曲面  ρ = b₀·cosh(w/b₀)  (ρ = |xyz|, 把悬链线绕 w 轴旋转)。
//    喉口 = w=0 处半径 b₀ 的球; u→±∞ 两侧 = 两个渐近平直宇宙。
//    这个超曲面就是"弯曲的三维空间"本身 —— 4D SDF 引擎的舞台。
//
//  · 观察者是生活在该超曲面上的三维生物: 位置始终被投影回超曲面,
//    视线/移动都在切向 3-空间内。
//  · 光线 = 超曲面上的 **测地线** (约束积分器: 直线步进 → 投影回曲面 →
//    速度重新切向化)。光线弯曲来自度规本身 —— 真实的引力透镜效果:
//    喉口附近的星光多重像、爱因斯坦环, 全部是方程的涌现。
//  · 场景: 悬链面地板 (θ=π/2 截面, 即 Wikipedia 的嵌入图曲面,
//    棋盘材质) + 两侧宇宙的星空 (A 冷色 / B 暖色, 由逃逸侧决定)。
//    没有任何装饰几何。
//
//  视图 ② = (w, ρ) 平面的嵌入图 —— Wikipedia 里的 Flamm 型图。
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(30.16, 0.0, 1.6, 9.0);   // 在超曲面上 (每帧投影保证)
uniform vec4 cam_fwd = vec4(-1.0, 0.0, 0.0, 0.0);    // 切向
uniform vec4 cam_right = vec4(0.0, 0.0, 1.0, 0.0);   // 切向
uniform vec4 cam_up = vec4(0.0, 1.0, 0.0, 0.0);      // 切向
uniform float fov_scale = 1.0;
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float view_mode = 0.0;     // 0 第一人称 | 1 嵌入图 (w, ρ)
uniform float throat_r = 3.0;      // Morris–Thorne 喉半径 b₀
uniform float vis = 1.0;           // 1 = 完整 Ellis, 0 = 完全平直
uniform float flat_side = 1.0;     // 平直时保留的房间颜色: 1 红 / 0 蓝
uniform vec3 entrance_c = vec3(0.0, 0.0, 0.0);   // 入口中心在房间中的位置
uniform float diagram_lift = 8.0;  // 嵌入图中虫洞相对方格平面的悬浮高度 (ρ 单位)

// ---- 欧氏传送门（Portal explorer 风格）----
uniform int portal_count = 0;
uniform vec4 portal_center[5];   // xyz 中心, w 半径
uniform vec4 portal_normal[5];   // xyz 法线, w 出口索引
uniform vec4 portal_right[5];    // xyz 右轴, w 出口滚转
uniform vec4 portal_up[5];       // xyz 上轴
uniform vec4 portal_color[5];    // rgb 边框颜色

const int MAX_STEPS = 1200;
const float W_ESCAPE = 55.0;

// 两个立方体房间: 房间中心 = Ellis 喉口入口; |w| 分开两个宇宙。
const vec3 ROOM_C = vec3(20.0, 0.0, 0.0);
const float ROOM_L = 14.0;   // 立方体半边长

// ============================================================================
//  超曲面 ρ = b₀·cosh(w/b₀)   (Ellis 虫洞的等距嵌入)
// ============================================================================

float surf_f(vec4 p){
	if (throat_r < 0.02) return p.w;   // b₀=0: 平直平面 w=0
	return length(p.xyz - entrance_c) - throat_r * cosh(p.w / throat_r);
}

vec4 surf_grad(vec4 p){
	if (throat_r < 0.02) return vec4(0.0, 0.0, 0.0, 1.0);
	vec3 q = p.xyz - entrance_c;
	float rho = length(q);
	vec3 g3 = (rho > 0.0001) ? q / rho : vec3(0.0);
	return vec4(g3, -sinh(p.w / throat_r));
}

vec4 surf_project(vec4 p){
	if (throat_r < 0.02){
		p.w = 0.0;
		return p;
	}
	for (int i = 0; i < 3; i++){
		vec4 g = surf_grad(p);
		float f = surf_f(p);
		p -= g * f / max(dot(g, g), 1e-6);
	}
	return p;
}

vec4 surf_normal(vec4 p){
	if (throat_r < 0.02) return vec4(0.0, 0.0, 0.0, 1.0);
	return normalize(surf_grad(p));
}

// ============================================================================
//  悬链面地板 (θ=π/2 截面): Z=0, ρxy = b₀·cosh(w/b₀)
// ============================================================================

float cat_sdf(vec4 p){
	if (throat_r < 0.02){
		float zf = p.z - entrance_c.z;
		return sign(zf) * abs(zf);
	}
	vec3 q = vec3(p.x - entrance_c.x, p.y - entrance_c.y, p.z - entrance_c.z);
	float rho_xy = length(q.xy);
	float dr = rho_xy - throat_r * cosh(p.w / throat_r);
	return sign(q.z) * sqrt(q.z * q.z + dr * dr);
}

vec4 cat_normal(vec4 p){
	float e = 0.01;
	return normalize(vec4(
		cat_sdf(p + vec4(e, 0.0, 0.0, 0.0)) - cat_sdf(p - vec4(e, 0.0, 0.0, 0.0)),
		cat_sdf(p + vec4(0.0, e, 0.0, 0.0)) - cat_sdf(p - vec4(0.0, e, 0.0, 0.0)),
		cat_sdf(p + vec4(0.0, 0.0, e, 0.0)) - cat_sdf(p - vec4(0.0, 0.0, e, 0.0)),
		cat_sdf(p + vec4(0.0, 0.0, 0.0, e)) - cat_sdf(p - vec4(0.0, 0.0, 0.0, e))));
}

// 悬链面地板棋盘 (解析抗锯齿; 强畸变处导数可能爆炸, 做 NaN/INF 防护)
vec3 cat_albedo(vec4 p){
	// 地板使用同一个三维立方网格: 世界 xyz (a,b,c)，不用 xyw
	vec3 q = p.xyz * 0.5;
	vec3 f = abs(fract(q) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.04, min(f.x, min(f.y, f.z)));
	float ck = mod(floor(q.x) + floor(q.y) + floor(q.z), 2.0);
	vec3 dq = fwidth(q);
	float aa = clamp(max(dq.x, max(dq.y, dq.z)) * 4.0, 0.0, 1.0);
	ck = mix(ck, 0.5, aa);
	line *= (1.0 - aa);
	vec3 alb = mix(vec3(0.30, 0.31, 0.34), vec3(0.62, 0.61, 0.62), ck);
	alb = mix(alb, vec3(0.88, 0.90, 0.94), line * 0.30);
	return alb;
}

// ============================================================================
//  星空 (两个宇宙不同色温)
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

// 逃逸方向 → 所属宇宙 (w<0 冷色 / w>0 暖色) 的星空
vec3 sky_col(vec4 v){
	float uni = smoothstep(-3.0, 3.0, v.w * 6.0);
	vec3 col = mix(vec3(0.008, 0.010, 0.026), vec3(0.026, 0.012, 0.008), uni);
	col += star_layer(v, 15.0, 0.980, 1.0, uni);
	col += star_layer(v, 28.0, 0.970, 0.65, uni);
	col += star_layer(v, 52.0, 0.958, 0.45, uni);
	return col;
}

// 平行光方向 (缓慢的 4D 黄道)
vec4 sun_dir(float t){
	return normalize(vec4(0.35 + 0.2 * sin(t * 0.05), 0.25, 0.6, 0.25 * sin(t * 0.03)));
}

// ============================================================================
//  诊断视图 ②: (w, ρ) 嵌入图 (Wikipedia 的 Flamm 型图)
//  超曲面曲线整体悬浮在方格平面之上 h = diagram_lift；
//  平面上的虚线是投影，竖线是投影线，喉口/相机旁是高度尺。
// ============================================================================

vec3 embed_diagram(vec2 uv){
	if (throat_r < 0.02){
		// 完全平直: 只画 w=0 轴和方格背景
		vec3 col = vec3(0.035, 0.040, 0.055);
		vec2 g = abs(fract(vec2(uv.x * 16.0, uv.y * 11.0)) - 0.5);
		col += vec3(0.05, 0.07, 0.10) * (1.0 - smoothstep(0.0, 0.06, min(g.x, g.y)));
		float axis = 1.0 - smoothstep(0.0, 0.004, abs(uv.x - 0.5));
		col += vec3(0.35, 0.42, 0.50) * axis * 0.55;
		return col;
	}
	// b₀ 变小时曲线指数变尖；w 轴跟着缩放，避免整屏只剩一根黑刺
	float wspan = clamp(10.0 * throat_r, 1.2, 32.0);
	float W = mix(-wspan, wspan, uv.x);
	float R = mix(44.0, 0.0, uv.y);
	float lift = max(diagram_lift, 0.0);
	float curvePlane = throat_r * cosh(W / throat_r);
	float curveLift = curvePlane + lift;
	vec3 bg = mix(vec3(0.035, 0.040, 0.055), vec3(0.012, 0.015, 0.028), clamp(vis, 0.0, 1.0));
	vec3 col = bg;
	// 方格演示平面
	vec2 g = abs(fract(vec2(uv.x * 16.0, uv.y * 11.0)) - 0.5);
	col += vec3(0.05, 0.07, 0.10) * (1.0 - smoothstep(0.0, 0.06, min(g.x, g.y)));
	// 平面上的投影: 虚线 ρ = b₀cosh(w/b₀)
	float dash = step(0.45, fract(W * 0.55));
	float dcPlane = abs(R - curvePlane);
	col = mix(col, vec3(0.30, 0.27, 0.16), (1.0 - smoothstep(0.0, 0.30, dcPlane)) * 0.55 * dash);
	// 悬浮面到平面的投影线
	float drop = 1.0 - smoothstep(0.0, 0.018, abs(fract(uv.x * 24.0) - 0.5));
	float gap = step(curvePlane, R) * step(R, curveLift);
	col += vec3(0.10, 0.14, 0.18) * drop * gap * 0.65;
	// 悬浮在平面之上的超曲面: ρ = b₀cosh(w/b₀) + h
	float dcLift = abs(R - curveLift);
	col = mix(col, vec3(0.95, 0.85, 0.45), (1.0 - smoothstep(0.0, 0.35, dcLift)) * 0.95);
	// 相机: 平面投影 + 悬浮标记
	float Rcam = length(cam_pos.xyz - entrance_c);
	float dcCamPlane = length(vec2(W - cam_pos.w, R - Rcam));
	float dcCamLift = length(vec2(W - cam_pos.w, R - (Rcam + lift)));
	col = mix(col, vec3(0.16, 0.30, 0.20), (1.0 - smoothstep(0.0, 0.8, dcCamPlane)) * 0.55);
	col = mix(col, vec3(0.3, 0.9, 0.5), (1.0 - smoothstep(0.0, 0.8, dcCamLift)) * 0.9);
	float camGauge = 1.0 - smoothstep(0.0, 0.12, abs(W - cam_pos.w));
	float camGap = step(Rcam, R) * step(R, Rcam + lift);
	col += vec3(0.10, 0.25, 0.18) * camGauge * camGap * 0.6;
	// 喉口: 平面投影 + 悬浮标记
	float dthPlane = length(vec2(W, R - throat_r));
	float dthLift = length(vec2(W, R - (throat_r + lift)));
	col = mix(col, vec3(0.16, 0.25, 0.32), (1.0 - smoothstep(0.0, 0.5, dthPlane)) * 0.55);
	col = mix(col, vec3(0.4, 0.75, 1.0), (1.0 - smoothstep(0.0, 0.5, dthLift)) * 0.8);
	// 喉口高度尺: 从平面 ρ=b₀ 到悬浮面 ρ=b₀+h
	float gauge = 1.0 - smoothstep(0.0, 0.15, abs(W));
	float gaugeGap = step(throat_r, R) * step(R, throat_r + lift);
	col += vec3(0.25, 0.35, 0.45) * gauge * gaugeGap * 0.6;
	col *= 1.0 - 0.35 * dot(uv - 0.5, uv - 0.5) * 2.0;
	return col;
}

// ============================================================================
//  双房间场景: 立方体墙 + 中心 Ellis 喉口
// ============================================================================

float room_dist(vec4 p){
	return ROOM_L - max(abs(p.x - ROOM_C.x), max(abs(p.y - ROOM_C.y), abs(p.z - ROOM_C.z)));
}

vec4 room_normal(vec4 p){
	float ax = abs(p.x - ROOM_C.x);
	float ay = abs(p.y - ROOM_C.y);
	float az = abs(p.z - ROOM_C.z);
	if (ax >= ay && ax >= az) return vec4(sign(p.x - ROOM_C.x), 0.0, 0.0, 0.0);
	if (ay >= az) return vec4(0.0, sign(p.y - ROOM_C.y), 0.0, 0.0);
	return vec4(0.0, 0.0, sign(p.z - ROOM_C.z), 0.0);
}

// 蓝房间 w<0, 红房间 w>0; 棋盘/方格墙面。
vec3 room_surface(vec4 p, vec4 n, vec3 ldir){
	bool red = (throat_r < 0.02) ? (flat_side > 0.5) : (p.w > 0.0);
	vec3 base = red ? vec3(0.42, 0.055, 0.050) : vec3(0.045, 0.09, 0.40);
	vec3 tile = red ? vec3(0.68, 0.14, 0.11) : vec3(0.13, 0.28, 0.70);
	// 外部三维立方网格: 世界 xyz (a,b,c)，不用 per-face (x,y,w)
	vec3 q = p.xyz * 0.5;
	vec3 f = abs(fract(q) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.035, min(f.x, min(f.y, f.z)));
	float ck = mod(floor(q.x) + floor(q.y) + floor(q.z), 2.0);
	vec3 dq = fwidth(q);
	float aa = clamp(max(dq.x, max(dq.y, dq.z)) * 4.0, 0.0, 1.0);
	ck = mix(ck, 0.5, aa);
	line *= (1.0 - aa);
	vec3 col = mix(base, tile, ck);
	col = mix(col, vec3(0.92), line * 0.40);
	float dif = clamp(dot(normalize(n.xyz), normalize(ldir)), 0.0, 1.0);
	float fill = clamp(dot(normalize(n.xyz), normalize(-cam_fwd.xyz)), 0.0, 1.0);
	col *= 0.55 + 0.55 * dif + 0.22 * fill;
	return col;
}

// ============================================================================
//  沙盒障碍物: 两块平台 + 中央柱
// ============================================================================

const vec3 OBS1_C = vec3(26.0, 8.0, -11.0);
const vec3 OBS1_H = vec3(4.0, 4.0, 3.0);
const vec3 OBS2_C = vec3(14.0, -8.0, -11.0);
const vec3 OBS2_H = vec3(4.0, 4.0, 3.0);
const vec3 OBS3_C = vec3(20.0, 0.0, -10.0);
const vec3 OBS3_H = vec3(1.6, 1.6, 4.0);

float box_dist(vec4 p, vec3 c, vec3 h){
	// 真欧氏盒 SDF: 用 max-norm 时射线会在盒角附近穿进盒内,
	// 命中点落在内部不同深度, 格纹被切成同心条带。
	vec3 d = abs(p.xyz - c) - h;
	vec3 q = max(d, vec3(0.0));
	return length(q) + min(max(d.x, max(d.y, d.z)), 0.0);
}

vec4 box_normal(vec4 p, vec3 c, vec3 h){
	vec3 d = abs(p.xyz - c) - h;
	if (d.x >= d.y && d.x >= d.z) return vec4(sign(p.x - c.x), 0.0, 0.0, 0.0);
	if (d.y >= d.z) return vec4(0.0, sign(p.y - c.y), 0.0, 0.0);
	return vec4(0.0, 0.0, sign(p.z - c.z), 0.0);
}

float map_dist(vec4 p){
	float d = room_dist(p);
	d = min(d, box_dist(p, OBS1_C, OBS1_H));
	d = min(d, box_dist(p, OBS2_C, OBS2_H));
	d = min(d, box_dist(p, OBS3_C, OBS3_H));
	return d;
}

vec4 map_normal(vec4 p){
	float d = room_dist(p);
	vec4 n = room_normal(p);
	float d1 = box_dist(p, OBS1_C, OBS1_H);
	if (d1 < d){ d = d1; n = box_normal(p, OBS1_C, OBS1_H); }
	float d2 = box_dist(p, OBS2_C, OBS2_H);
	if (d2 < d){ d = d2; n = box_normal(p, OBS2_C, OBS2_H); }
	float d3 = box_dist(p, OBS3_C, OBS3_H);
	if (d3 < d){ n = box_normal(p, OBS3_C, OBS3_H); }
	return n;
}

// 用命中前一点的局部射线与轴对齐面求交。步进停止位置带有量化误差,
// 掠射面上会放大成十几厘米的横向抖动; 解析交点只由光滑的射线决定。
vec3 face_hit(vec4 p0, vec4 v, vec4 n, vec3 c, vec3 h){
	vec3 p = p0.xyz;
	if (abs(n.x) > 0.5){
		float t = (c.x + sign(n.x) * h.x - p0.x) / (abs(v.x) > 1e-5 ? v.x : 1e-5);
		p = p0.xyz + v.xyz * clamp(t, 0.0, 1.5);
	} else if (abs(n.y) > 0.5){
		float t = (c.y + sign(n.y) * h.y - p0.y) / (abs(v.y) > 1e-5 ? v.y : 1e-5);
		p = p0.xyz + v.xyz * clamp(t, 0.0, 1.5);
	} else {
		float t = (c.z + sign(n.z) * h.z - p0.z) / (abs(v.z) > 1e-5 ? v.z : 1e-5);
		p = p0.xyz + v.xyz * clamp(t, 0.0, 1.5);
	}
	return p;
}

vec3 obstacle_surface(vec4 p, vec4 n, vec4 ldir, vec3 base, vec3 tile){
	// 外部三维立方网格: 世界 xyz (a,b,c)，不用 per-face (x,y,w)
	vec3 q = p.xyz * 0.5;
	vec3 f = abs(fract(q) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.035, min(f.x, min(f.y, f.z)));
	float ck = mod(floor(q.x) + floor(q.y) + floor(q.z), 2.0);
	vec3 dq = fwidth(q);
	float aa = clamp(max(dq.x, max(dq.y, dq.z)) * 4.0, 0.0, 1.0);
	ck = mix(ck, 0.5, aa);
	line *= (1.0 - aa);
	vec3 col = mix(base, tile, ck);
	col = mix(col, vec3(0.85, 0.92, 1.0), line * 0.28);
	float dif = clamp(dot(normalize(n), normalize(ldir)), 0.0, 1.0);
	col *= 0.55 + 0.55 * dif;
	return col;
}

vec3 map_surface(vec4 p, vec4 n, vec4 ldir, vec4 v, vec4 p0){
	float d = room_dist(p);
	vec3 sp = face_hit(p0, v, n, ROOM_C, vec3(ROOM_L));
	vec3 col = room_surface(vec4(sp, p.w), n, ldir.xyz);
	float d1 = box_dist(p, OBS1_C, OBS1_H);
	if (d1 < d){
		d = d1;
		sp = face_hit(p0, v, n, OBS1_C, OBS1_H);
		col = obstacle_surface(vec4(sp, 0.0), n, ldir, vec3(0.035, 0.16, 0.19), vec3(0.06, 0.28, 0.32));
	}
	float d2 = box_dist(p, OBS2_C, OBS2_H);
	if (d2 < d){
		d = d2;
		sp = face_hit(p0, v, n, OBS2_C, OBS2_H);
		col = obstacle_surface(vec4(sp, 0.0), n, ldir, vec3(0.045, 0.12, 0.22), vec3(0.08, 0.22, 0.36));
	}
	float d3 = box_dist(p, OBS3_C, OBS3_H);
	if (d3 < d){
		sp = face_hit(p0, v, n, OBS3_C, OBS3_H);
		col = obstacle_surface(vec4(sp, 0.0), n, ldir, vec3(0.18, 0.09, 0.035), vec3(0.32, 0.16, 0.06));
	}
	return col;
}

// ============================================================================
//  欧氏传送门: 射线击中墙面上的圆盘时, 变换到配对的出口门继续步进。
// ============================================================================

int portal_hit(vec4 p, vec4 n, vec4 v){
	for (int i = 0; i < 5; i++){
		if (i >= portal_count) break;
		vec3 rel = p.xyz - portal_center[i].xyz;
		float rad = portal_center[i].w;
		if (dot(rel, rel) > (rad + 0.05) * (rad + 0.05)) continue;
		if (abs(dot(normalize(n.xyz), portal_normal[i].xyz)) < 0.65) continue;
		if (dot(normalize(v.xyz), portal_normal[i].xyz) > -0.02) continue;
		return i;
	}
	return -1;
}

void portal_teleport(inout vec4 p, inout vec4 v, int i){
	int j = clamp(int(portal_normal[i].w + 0.5), 0, 4);
	vec3 rel = p.xyz - portal_center[i].xyz;
	float lx = dot(rel, portal_right[i].xyz);
	float ly = dot(rel, portal_up[i].xyz);
	float lz = dot(rel, portal_normal[i].xyz);
	float vx = dot(v.xyz, portal_right[i].xyz);
	float vy = dot(v.xyz, portal_up[i].xyz);
	float vz = dot(v.xyz, portal_normal[i].xyz);

	// 进门 → 出门: 绕出口上轴翻转 180°，再从入口的局部坐标旋到出口标架
	lx = -lx; lz = -lz;
	vx = -vx; vz = -vz;
	float roll = portal_right[i].w;
	float cr = cos(roll);
	float sr = sin(roll);
	float rx = lx * cr - ly * sr;
	float ry = lx * sr + ly * cr;
	float wx = vx * cr - vy * sr;
	float wy = vx * sr + vy * cr;

	vec3 np = portal_center[j].xyz
		+ portal_right[j].xyz * rx
		+ portal_up[j].xyz * ry
		+ portal_normal[j].xyz * lz;
	np += portal_normal[j].xyz * 0.10;
	vec3 nv = portal_right[j].xyz * wx
		+ portal_up[j].xyz * wy
		+ portal_normal[j].xyz * vz;

	p = surf_project(vec4(np, 0.0));
	v = vec4(nv, 0.0);
	vec4 sn = surf_normal(p);
	v -= sn * dot(v, sn);
	v = normalize(v);
}

vec3 portal_rim(vec4 p, vec4 n, vec3 col){
	for (int i = 0; i < 5; i++){
		if (i >= portal_count) break;
		if (abs(dot(normalize(n.xyz), portal_normal[i].xyz)) < 0.65) continue;
		float d = length(p.xyz - portal_center[i].xyz);
		float rad = portal_center[i].w;
		float ring = 1.0 - smoothstep(0.02, 0.10, abs(d - rad));
		float glow = 1.0 - smoothstep(0.10, 0.24, abs(d - rad));
		col = mix(col, portal_color[i].rgb, ring);
		col += portal_color[i].rgb * glow * 0.10;
	}
	return col;
}

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = cam_pos;

	vec3 col = vec3(0.03, 0.035, 0.04);

	// 最多穿 3 次门；门内看到的画面由出/入口变换后的连续步进给出。
	for (int bounce = 0; bounce < 3; bounce++){
		float travel = 0.0;
		bool hit = false;
		vec4 p0 = p;

		for (int i = 0; i < MAX_STEPS; i++){
			float wd = map_dist(p);
			if (wd < 0.02){
				hit = true;
				break;
			}
			float h = clamp(0.5 * wd + 0.02, 0.04, 0.6);
			p0 = p;

			// 约束测地线: 房间墙和中心喉口都在同一张 Ellis 超曲面上。
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

		if (!hit){
			break;
		}

		vec4 n = map_normal(p);
		int pi = portal_hit(p, n, v);
		if (pi >= 0 && bounce < 2){
			portal_teleport(p, v, pi);
			continue;
		}

		// 命中点收紧: 步进在 wd<0.02 停下, 掠射面上这点提前量会被放大成
		// 十几厘米的横向抖动 (格纹扭成同心条带)。用命中前一点的局部射线
		// 与盒面解析求交, 格纹坐标只由光滑的射线决定。
		vec4 ldir = normalize(sun_dir(time_s));
		col = map_surface(p, n, ldir, v, p0);
		col = portal_rim(p, n, col);
		break;
	}

	// NaN/Inf 兜底：个别过渡帧/极掠射角不出现纯黑
	if (any(isnan(col)) || any(isinf(col))){
		col = vec3(0.05, 0.055, 0.065);
	}

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
	vec3 col;
	if (view_mode > 0.5){
		col = embed_diagram(UV);
	} else {
		col = render_scene(UV);
	}
	COLOR = vec4(col, 1.0);
}
