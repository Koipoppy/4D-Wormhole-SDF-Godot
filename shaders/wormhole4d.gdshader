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

const int MAX_STEPS = 1200;
const float W_ESCAPE = 55.0;

// ============================================================================
//  超曲面 ρ = b₀·cosh(w/b₀)   (Ellis 虫洞的等距嵌入)
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
		float f = length(p.xyz) - throat_r * cosh(p.w / throat_r);
		p -= g * f / max(dot(g, g), 1e-6);
	}
	return p;
}

vec4 surf_normal(vec4 p){
	return normalize(surf_grad(p));
}

// ============================================================================
//  悬链面地板 (θ=π/2 截面): Z=0, ρxy = b₀·cosh(w/b₀)
// ============================================================================

float cat_sdf(vec4 p){
	float rho_xy = length(p.xy);
	float dr = rho_xy - throat_r * cosh(p.w / throat_r);
	return sign(p.z) * sqrt(p.z * p.z + dr * dr);
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
// ============================================================================

vec3 embed_diagram(vec2 uv){
	float W = mix(-32.0, 32.0, uv.x);
	float R = mix(44.0, 0.0, uv.y);
	float curve = throat_r * cosh(W / throat_r);
	vec3 col = vec3(0.012, 0.015, 0.028);
	// 网格
	vec2 g = abs(fract(vec2(uv.x * 16.0, uv.y * 11.0)) - 0.5);
	col += vec3(0.05, 0.07, 0.10) * (1.0 - smoothstep(0.0, 0.06, min(g.x, g.y)));
	// 超曲面: ρ = b₀cosh(w/b₀) (嵌入图曲线)
	float dc = abs(R - curve);
	col = mix(col, vec3(0.95, 0.85, 0.45), (1.0 - smoothstep(0.0, 0.35, dc)) * 0.95);
	// 相机位置标记
	float dc_cam = length(vec2(W - cam_pos.w, R - length(cam_pos.xyz)));
	col = mix(col, vec3(0.3, 0.9, 0.5), (1.0 - smoothstep(0.0, 0.8, dc_cam)) * 0.9);
	// 喉口标记 (w=0, ρ=b₀)
	float dth = length(vec2(W, R - throat_r));
	col = mix(col, vec3(0.4, 0.75, 1.0), (1.0 - smoothstep(0.0, 0.5, dth)) * 0.8);
	col *= 1.0 - 0.35 * dot(uv - 0.5, uv - 0.5) * 2.0;
	return col;
}

// ============================================================================
//  主渲染: 超曲面上的测地线光线步进
// ============================================================================

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y) * fov_scale);
	vec4 p = cam_pos;

	float travel = 0.0;
	bool hit = false;

	for (int i = 0; i < MAX_STEPS; i++){
		float df = cat_sdf(p);
		if (abs(df) < 0.02){
			hit = true;
			break;
		}
		// 自适应步长: 靠近地板更细; 靠近喉口也加密 (缠绕测地线的精度)
		float h = clamp(0.5 * abs(df) + 0.04, 0.05, 0.7);
		float near_throat = clamp(1.0 - length(p.xyz) / (throat_r * 6.0), 0.0, 1.0);
		h *= 1.0 - 0.55 * near_throat;

		// ---- 测地线积分器 (约束投影法) ----
		vec4 prev = p;
		p += v * h;
		p = surf_project(p);                 // 投影回超曲面
		vec4 n = surf_normal(p);
		v -= n * dot(v, n);                  // 速度重新切向化
		v = normalize(v);
		travel += h;

		// 缠绕光线终止: 绕喉多圈后用逃逸方向采星空 (物理近似, 避免纯黑)
		if (travel > 200.0){
			break;
		}

		if (abs(p.w) > W_ESCAPE){
			break;                            // 逃逸到宇宙深处 → 星空
		}
	}

	// 步数耗尽的兜底:
	// ① 仍贴近悬链面地板 → 按"无限远地板"处理 (浓雾色), 消除地平线锯齿
	// ② 绕喉光线耗尽 → 用最终方向采星空 (缠绕的高阶像), 不再是纯黑
	if (!hit){
		float df_end = cat_sdf(p);
		if (abs(df_end) < 1.2){
			hit = true;
			travel = max(travel, 180.0);
		}
	}

	vec3 col;
	if (hit){
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

	// 色调映射 + gamma
	col = col / (1.0 + col);
	col = pow(col, vec3(0.6));

	// 晕影 + 准星 (一个清晰的小点, 按纵横比校正)
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
