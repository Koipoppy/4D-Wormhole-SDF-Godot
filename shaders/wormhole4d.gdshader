// ============================================================================
//  四维空间 SDF 引擎 + 虫洞 —— 分层宇宙 + 井道 (v20)
//
//  数学模型:
//   · 三个宇宙 = w 轴上的三张平行层: A (w=-24, 冷) / B (w=0, 中) / C (w=+24, 暖)。
//     每层是平直 3D 空间: 地板超平面 {z=-2, w=w_i} (2-平面, 距离场精确) + 各自星空。
//   · 虫洞 = 连接层的真实 4D 管道 (SDF 实体, 空心、端口喇叭):
//       B→C 井道: 端口(30,0,0,0) → 层内平走16m → 弯入 +w → 升至 C 层端口(30,0,-1,24)
//       A→B 井道: 端口(-30,0,0,-24) → 对称结构 → B 层端口(-30,0,-1,0)
//       B 层快速通道: (-160,0,0,0) → (160,0,0,0) 直线 320m, 同层远距瞬移般的连续穿行
//   · 光线 = 所在层的平直 4D 直线 (平直层内不弯); 穿越靠管道几何连续爬升 w。
//   · 观察者: SDF 碰撞约束在 "当前层 ∪ 管道内"; 管壁推着观察者沿弯折走。
//   · 四维转动 (J/I/L/U/G): 把视线转入 w —— 看见并飞进竖井段的唯一方式。
//
//  渲染: 4D 梯度法线、棋盘 fwidth 解析抗锯齿、楼层图诊断视图 (x,w)、超采样。
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

const int MAX_STEPS = 300;
const float MAX_DIST = 500.0;
const float FLOOR_Z = -2.0;

// ---- 三张平行层 ----
const float W_A = -24.0;
const float W_B = 0.0;
const float W_C = 24.0;

// ---- 虫洞管道折线 (与 scripts/main.gd 保持一致) ----
const vec4 WC0 = vec4(30.0, 0.0, 0.0, 0.0);      // B 层端口
const vec4 WC1 = vec4(30.0, 0.0, -16.0, 0.0);    // 层内直行段终点
const vec4 WC2 = vec4(30.0, 0.0, -21.0, 17.0);   // 弯入 +w
const vec4 WC3 = vec4(30.0, 0.0, -1.0, 24.0);    // C 层端口
const vec4 WA0 = vec4(-30.0, 0.0, 0.0, -24.0);   // A 层端口
const vec4 WA1 = vec4(-30.0, 0.0, -16.0, -24.0);
const vec4 WA2 = vec4(-30.0, 0.0, -21.0, -7.0);
const vec4 WA3 = vec4(-30.0, 0.0, -1.0, 0.0);    // B 层端口
const vec4 WB0 = vec4(-160.0, 0.0, 0.0, 0.0);    // B 层快速通道 A 端
const vec4 WB1 = vec4(160.0, 0.0, 0.0, 0.0);     // B 层快速通道 B 端
const float PORT_R = 3.4;      // 端口半径
const float THROAT_R = 2.4;    // 管道中段半径
const float EXPRESS_R = 2.6;   // 快速通道半径 (全长等径)
const float TUBE_WALL = 0.4;

// ============================================================================
//  哈希 / 星空 / 光照
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

// 所在层 w → 星空基色与星色 (A 冷蓝 / B 中性 / C 暖金)
vec3 sky_col(vec4 rd, float w){
	float wA = 1.0 - smoothstep(-20.0, -8.0, w);
	float wC = smoothstep(8.0, 20.0, w);
	float wB = clamp(1.0 - wA - wC, 0.0, 1.0);
	vec3 base = vec3(0.006, 0.010, 0.032) * wA + vec3(0.012, 0.012, 0.016) * wB + vec3(0.030, 0.016, 0.008) * wC;
	vec3 stT = vec3(0.70, 0.82, 1.20) * wA + vec3(1.0) * wB + vec3(1.25, 0.90, 0.55) * wC;
	vec4 rdw = rd + vec4(0.0, 0.0, 0.0, w * 0.01);
	vec3 col = base;
	col += star_layer(rdw, 15.0, 0.982, 1.0, stT);
	col += star_layer(rdw, 28.0, 0.972, 0.6, stT);
	col += star_layer(rdw, 52.0, 0.958, 0.45, stT);
	return col;
}

vec4 sun_dir(){
	return normalize(vec4(0.35, 0.30, 0.55, 0.20));
}

// ============================================================================
//  SDF 基元
// ============================================================================

float sd_seg4(vec4 p, vec4 a, vec4 b){
	vec4 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - (a + ab * t));
}

vec4 seg_center(vec4 p, vec4 a, vec4 b){
	vec4 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return a + ab * t;
}

vec4 seg_nearest(vec4 p, vec4 a, vec4 b, vec4 c, vec4 d){
	vec4 best = seg_center(p, a, b);
	float bd = length(p - best);
	vec4 c2 = seg_center(p, b, c);
	float d2 = length(p - c2);
	if (d2 < bd){ bd = d2; best = c2; }
	vec4 c3 = seg_center(p, c, d);
	float d3 = length(p - c3);
	if (d3 < bd){ bd = d3; best = c3; }
	return best;
}

// 三条管道全部折线段中离 p 最近的轴点 (用于内外壁判定)
vec4 seg_nearest_all(vec4 p){
	vec4 best = seg_center(p, WC0, WC1);
	float bd = length(p - best);
	vec4 c = seg_center(p, WC1, WC2);
	float d = length(p - c);
	if (d < bd){ bd = d; best = c; }
	c = seg_center(p, WC2, WC3); d = length(p - c);
	if (d < bd){ bd = d; best = c; }
	c = seg_center(p, WA0, WA1); d = length(p - c);
	if (d < bd){ bd = d; best = c; }
	c = seg_center(p, WA1, WA2); d = length(p - c);
	if (d < bd){ bd = d; best = c; }
	c = seg_center(p, WA2, WA3); d = length(p - c);
	if (d < bd){ bd = d; best = c; }
	c = seg_center(p, WB0, WB1); d = length(p - c);
	if (d < bd){ bd = d; best = c; }
	return best;
}

// 直管/折线管通用: 轴线折线 + 端距喇叭半径 + 空心壁 + 端口切平面 (敞口)
float sd_tube(vec4 p, vec4 a, vec4 b, vec4 c, vec4 d, float r_port, float r_mid, float wall){
	float axis = min(min(sd_seg4(p, a, b), sd_seg4(p, b, c)), sd_seg4(p, c, d));
	float d_end = min(length(p - a), length(p - d));
	float s = 1.0 - clamp(d_end / 9.0, 0.0, 1.0);
	float r = r_mid + (r_port - r_mid) * s * s;
	float shell = max(axis - r, (r - wall) - axis);
	shell = max(shell, dot(p - a, normalize(a - b)));   // A 端口切开
	shell = max(shell, dot(p - d, normalize(d - c)));   // D 端口切开
	return shell;
}

// 两点直管 (快速通道)
float sd_tube2(vec4 p, vec4 a, vec4 b, float r_port, float r_mid, float wall){
	vec4 ab = b - a;
	vec4 dir = normalize(ab);
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	float axis = length(p - (a + ab * t));
	float d_end = min(length(p - a), length(p - b));
	float s = 1.0 - clamp(d_end / 10.0, 0.0, 1.0);
	float r = r_mid + (r_port - r_mid) * s * s;
	float shell = max(axis - r, (r - wall) - axis);
	shell = max(shell, dot(p - a, -dir));
	shell = max(shell, dot(p - b, dir));
	return shell;
}

// ============================================================================
//  场景 SDF (完整 4D): 三层地板 + 三条虫洞管道
// ============================================================================

vec2 map(vec4 p){
	// 三张层的地板: 超平面 {z=FLOOR_Z, w=w_i} 的精确 2-平面距离
	// (w 项自动门控: 只有所在层附近的地板会被命中)
	float dA = length(vec2(p.z - FLOOR_Z, p.w - W_A));
	float dB = length(vec2(p.z - FLOOR_Z, p.w - W_B));
	float dC = length(vec2(p.z - FLOOR_Z, p.w - W_C));
	vec2 res = vec2(dA, 1.0);
	if (dB < res.x) res = vec2(dB, 2.0);
	if (dC < res.x) res = vec2(dC, 3.0);

	float d = sd_tube(p, WC0, WC1, WC2, WC3, PORT_R, THROAT_R, TUBE_WALL);
	if (d < res.x) res = vec2(d, 4.0);
	d = sd_tube(p, WA0, WA1, WA2, WA3, PORT_R, THROAT_R, TUBE_WALL);
	if (d < res.x) res = vec2(d, 4.0);
	d = sd_tube2(p, WB0, WB1, EXPRESS_R + 0.8, EXPRESS_R, TUBE_WALL);
	if (d < res.x) res = vec2(d, 4.0);

	return res;
}

vec4 calc_normal(vec4 p){
	float e = 0.0015;
	return normalize(vec4(
		map(p + vec4(e, 0.0, 0.0, 0.0)).x - map(p - vec4(e, 0.0, 0.0, 0.0)).x,
		map(p + vec4(0.0, e, 0.0, 0.0)).x - map(p - vec4(0.0, e, 0.0, 0.0)).x,
		map(p + vec4(0.0, 0.0, e, 0.0)).x - map(p - vec4(0.0, 0.0, e, 0.0)).x,
		map(p + vec4(0.0, 0.0, 0.0, e)).x - map(p - vec4(0.0, 0.0, 0.0, e)).x));
}

// ============================================================================
//  材质
// ============================================================================

vec3 floor_albedo(float mid, vec4 p){
	float ck = mod(floor(p.x * 0.5) + floor(p.y * 0.5), 2.0);
	float fw = fwidth(p.x * 0.5) + fwidth(p.y * 0.5);
	ck = mix(ck, 0.5, clamp(fw * 1.5, 0.0, 1.0));
	float uni = smoothstep(-16.0, 16.0, p.w);
	vec3 a = mix(vec3(0.085, 0.095, 0.130), vec3(0.115, 0.075, 0.055), uni);
	vec3 b = mix(vec3(0.255, 0.290, 0.360), vec3(0.360, 0.260, 0.170), uni);
	return mix(a, b, ck);
}

vec3 tube_albedo(vec4 p, vec4 n, vec4 axis_c){
	float radial_out = dot(n, normalize(p - axis_c + vec4(0.0001)));
	vec3 coord = vec3(p.x, p.y, p.w) * 0.9;
	float ck = mod(floor(coord.x) + floor(coord.y) + floor(coord.z), 2.0);
	float fw = fwidth(coord.x) + fwidth(coord.y) + fwidth(coord.z);
	ck = mix(ck, 0.5, clamp(fw * 1.5, 0.0, 1.0));
	vec3 alb_in = mix(vec3(0.40, 0.38, 0.42), vec3(0.60, 0.58, 0.60), ck);
	vec3 alb_out = vec3(0.10, 0.095, 0.11);
	return (radial_out < 0.0) ? alb_in : alb_out;
}

// ============================================================================
//  诊断视图 ②: 楼层图 (x, w) —— 三层平行宇宙 + 井道 + 快速通道
// ============================================================================

vec3 floor_map(vec2 uv){
	vec2 suv = uv - 0.5;
	float qx = cam_pos.x + suv.x * 420.0 * aspect;
	float qw = cam_pos.w + suv.y * 70.0;
	vec3 col = vec3(0.012, 0.015, 0.028);
	// 三层地板线
	float dfl = min(min(abs(qw - W_A), abs(qw - W_B)), abs(qw - W_C));
	col = mix(col, vec3(0.45, 0.70, 0.55), (1.0 - smoothstep(0.0, 0.4, dfl)) * 0.9);
	// 井道竖线 (B→C 在 x=+30, w∈[0,24]; A→B 在 x=-30, w∈[-24,0])
	float shaftBC = (1.0 - smoothstep(0.0, 1.0, abs(qx - 30.0))) * step(0.0, qw) * step(qw, 24.0);
	float shaftAB = (1.0 - smoothstep(0.0, 1.0, abs(qx + 30.0))) * step(-24.0, qw) * step(qw, 0.0);
	col = mix(col, vec3(0.35, 0.75, 1.0), max(shaftBC, shaftAB) * 0.9);
	// B 层快速通道 (w=0, x∈[-160,160])
	float in_x = 1.0 - smoothstep(0.0, 2.0, abs(qx));
	float expr = (1.0 - smoothstep(0.0, 0.8, abs(qw - W_B))) * in_x;
	col = mix(col, vec3(1.0, 0.72, 0.28), expr * 0.8);
	// 相机标记
	float dc = length(vec2(qx - cam_pos.x, qw - cam_pos.w));
	col = mix(col, vec3(0.3, 1.0, 0.5), (1.0 - smoothstep(0.0, 1.6, dc)) * 0.9);
	col *= 1.0 - 0.35 * dot(suv, suv) * 2.0;
	return col;
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

	for (int i = 0; i < MAX_STEPS; i++){
		vec2 s = map(p);
		if (s.x < 0.0015 + 0.0025 * travel){
			hit = true;
			break;
		}
		if (travel > MAX_DIST){
			break;
		}
		p += v * (s.x * 0.9);
		travel += s.x * 0.9;
	}

	vec3 sky = sky_col(v, cam_pos.w);
	vec3 col;

	if (hit){
		float mid = map(p).y;
		vec4 n = calc_normal(p);
		vec4 ldir = sun_dir();
		float dif = clamp(dot(n, ldir), 0.0, 1.0);
		float amb = 0.26 + 0.07 * n.y;
		vec3 alb = (mid < 3.5) ? floor_albedo(mid, p) : tube_albedo(p, n, seg_nearest_all(p));
		col = alb * (amb + 0.9 * dif);
		if (mid >= 3.5){
			col += alb * 0.4 * pow(1.0 - abs(dot(n, v)), 2.0);
		}
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

void fragment(){
	vec3 col;
	if (view_mode > 0.5){
		col = floor_map(UV);
	} else {
		col = render_scene(UV);
	}
	COLOR = vec4(col, 1.0);
}
