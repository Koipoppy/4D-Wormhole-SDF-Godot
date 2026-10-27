// ============================================================================
//  v45 光滑双喉口：两个 Morris–Thorne 超悬链面喉口，共享 B/C 宇宙对
//    每个喉口:  rho_i = R*cosh(w/R)  around C_i (i=1,2)
//    世界 = smin(F1,F2) = 0，smin 是 C∞ 光滑最小值；不是 min 硬并集。
//    喉口附近权重饱和 -> 精确 Ellis；重叠区用宽度 κ 的光滑颈连接。
//    玩家/光线在这张 C∞ 超曲面上的测地线连续前进: B -> 喉口1 -> C -> 喉口2 -> B.
//    没有位置映射/反射/传送，接缝处法向/切空间连续。
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(0.0, -11.0, 4.6, -6.0);
uniform vec4 cam_fwd = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 cam_right = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 cam_up = vec4(0.0, 0.0, 1.0, 0.0);
uniform float fov_scale = 1.0;
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float view_mode = 0.0;
uniform float throat_r = 3.0;
uniform float blend_k = 0.35;   // C∞ 光滑混合宽度 κ
uniform vec3 c1;
uniform vec3 c2;
uniform vec3 green_c;
uniform float green_r;
uniform vec3 mk1_c;
uniform vec3 mk2_c;
uniform float mk1_r;
uniform float mk2_r;

const int MAX_STEPS = 1200;
const float W_ESCAPE = 55.0;

// ----------------------------------------------------------------------------
//  0.0.2 hyper-catenoid (two copies)
// ----------------------------------------------------------------------------
float f1(vec4 p){
	return length(p.xyz - c1) - throat_r * cosh(p.w / throat_r);
}
float f2(vec4 p){
	return length(p.xyz - c2) - throat_r * cosh(p.w / throat_r);
}
vec4 g1(vec4 p){
	vec3 v = normalize(p.xyz - c1);
	return vec4(v, -sinh(p.w / throat_r));
}
vec4 g2(vec4 p){
	vec3 v = normalize(p.xyz - c2);
	return vec4(v, -sinh(p.w / throat_r));
}
// ---- C∞ 光滑最小值 smin(F1,F2) ----
// smin(a,b;κ) = min(a,b) - κ log(1 + exp(-|a-b|/κ))
// 喉口附近一项权重饱和 -> 精确 Ellis；重叠区用宽度 κ 的光滑颈连接。
float sigmoid_k(float x){
	return 1.0 / (1.0 + exp(clamp(x, -60.0, 60.0)));
}
float smin(float a, float b){
	float m = min(a, b);
	float d = abs(a - b);
	return m - blend_k * log(1.0 + exp(-d / blend_k));
}
vec4 smin_grad(vec4 p){
	float a = f1(p);
	float b = f2(p);
	// wa = 1/(1+exp((a-b)/κ))：a<b 时 wa≈1，a>b 时 wa≈0
	float wa = sigmoid_k((a - b) / blend_k);
	return wa * g1(p) + (1.0 - wa) * g2(p);
}
float world_f(vec4 p){ return smin(f1(p), f2(p)); }
vec4 world_grad(vec4 p){ return smin_grad(p); }
vec4 world_project(vec4 p){
	for (int i = 0; i < 4; i++){
		vec4 g = world_grad(p);
		p -= g * world_f(p) / max(dot(g, g), 1e-6);
	}
	return p;
}
vec4 world_normal(vec4 p){ return normalize(world_grad(p)); }

// floor: z=0 cross-section, only on B side (w<0)
float cat_i(vec4 p, vec3 c){
	float rho_xy = length(p.xy - c.xy);
	float dr = rho_xy - throat_r * cosh(p.w / throat_r);
	return sign(p.z) * sqrt(p.z * p.z + dr * dr);
}
float cat_sdf(vec4 p){
	if (p.w > 0.0){ return 1e9; }
	// 地板也用同一套光滑权重混合，避免接缝处地板法向跳变
	float wa = sigmoid_k((f1(p) - f2(p)) / blend_k);
	return wa * cat_i(p, c1) + (1.0 - wa) * cat_i(p, c2);
}
vec4 cat_normal(vec4 p){
	float e = 0.01;
	return normalize(vec4(
		cat_sdf(p + vec4(e,0,0,0)) - cat_sdf(p - vec4(e,0,0,0)),
		cat_sdf(p + vec4(0,e,0,0)) - cat_sdf(p - vec4(0,e,0,0)),
		cat_sdf(p + vec4(0,0,e,0)) - cat_sdf(p - vec4(0,0,e,0)),
		cat_sdf(p + vec4(0,0,0,e)) - cat_sdf(p - vec4(0,0,0,e))));
}

// ----------------------------------------------------------------------------
//  sky / floor / glass
// ----------------------------------------------------------------------------
float hash13(vec3 p){
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float vnoise(vec3 p){
	vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(
		mix(mix(hash13(i), hash13(i+vec3(1,0,0)), f.x), mix(hash13(i+vec3(0,1,0)), hash13(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash13(i+vec3(0,0,1)), hash13(i+vec3(1,0,1)), f.x), mix(hash13(i+vec3(0,1,1)), hash13(i+vec3(1,1,1)), f.x), f.y),
		f.z);
}
float fbm3(vec3 p){
	float s = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++){ s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s;
}
vec3 cloud_sky(vec4 v){
	vec3 d = normalize(vec3(v.x, v.y, abs(v.z)*0.55 + 0.45));
	float h = clamp(d.z*0.5+0.5, 0.0, 1.0);
	vec3 sky = mix(vec3(0.52,0.74,0.97), vec3(0.07,0.30,0.78), h);
	float n = fbm3(d*3.6 + vec3(time_s*0.008, time_s*0.004, 0.0));
	float cl = smoothstep(0.50,0.74,n);
	sky = mix(sky, vec3(1.0), cl*0.90);
	float sun = pow(max(dot(d, normalize(vec3(0.42,0.28,0.86))),0.0),110.0);
	sky += vec3(1.0,0.94,0.78)*sun*1.1;
	return sky;
}
vec4 sun_dir(){ return normalize(vec4(0.42,0.28,0.86,0.0)); }

vec3 floor_albedo(vec4 p){
	// 纯棋盘, 不做任何 fwidth/抗锯齿混合: 喉口附近不会再出现灰色平均带。
	// 用地面 (x,y) 坐标, 避免 w 在喉口处被压缩造成的摩尔纹环带。
	float ck = mod(floor(p.x * 0.55) + floor(p.y * 0.55), 2.0);
	return mix(vec3(0.58, 0.59, 0.61), vec3(0.90, 0.91, 0.92), ck);
}

// ----------------------------------------------------------------------------
//  renderer: 0.0.2 geodesic constraint marcher on the union, plus scene props
// ----------------------------------------------------------------------------
vec3 embed_diagram(vec2 uv){
	float W = mix(-18.0, 18.0, uv.x);
	float R = mix(26.0, 0.0, uv.y);
	float curve = throat_r * cosh(W / throat_r);
	vec3 col = vec3(0.012,0.015,0.028);
	vec2 g = abs(fract(vec2(uv.x*16.0, uv.y*11.0))-0.5);
	col += vec3(0.05,0.07,0.10)*(1.0-smoothstep(0.0,0.06,min(g.x,g.y)));
	col = mix(col, vec3(0.95,0.85,0.45), (1.0-smoothstep(0.0,0.35,abs(R-curve)))*0.95);
	col *= 1.0 - 0.35*dot(uv-0.5,uv-0.5)*2.0;
	return col;
}

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x*2.0-1.0, 1.0-uv.y*2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right*ndc.x + cam_up*ndc.y)*fov_scale);
	vec4 p = world_project(cam_pos);
	float travel = 0.0;
	int hit = 0;   // 1 floor, 2 green, 3 mk1, 4 mk2, 5 rim
	vec4 hit_n = vec4(0.0);
	for (int i = 0; i < MAX_STEPS; i++){
		float fl = cat_sdf(p);
		float gr = length(p - vec4(green_c, p.w)) - green_r;
		float m1 = length(p - vec4(mk1_c, p.w)) - mk1_r;
		vec3 d2 = abs(p.xyz - mk2_c);
		float m2 = max(max(d2.x,d2.y),d2.z) - mk2_r;
		if (abs(fl) < 0.02){ hit=1; hit_n=cat_normal(p); break; }
		if (gr < 0.02){ hit=2; hit_n=normalize(p-vec4(green_c,p.w)); break; }
		if (m1 < 0.02){ hit=3; hit_n=normalize(p-vec4(mk1_c,p.w)); break; }
		if (m2 < 0.02){ hit=4; hit_n=vec4(0.0); break; }
		float h = clamp(0.5*min(min(abs(fl),gr),min(m1,m2))+0.04,0.05,0.7);
		float near_throat = clamp(1.0 - length(p.xyz)/ (throat_r*6.0), 0.0, 1.0);
		h *= 1.0 - 0.55*near_throat;
		p += v*h;
		p = world_project(p);
		vec4 n = world_normal(p);
		v -= n*dot(v,n);
		v = normalize(v);
		travel += h;
		if (travel > 220.0){ break; }
		if (abs(p.w) > W_ESCAPE){ break; }
	}
	if (hit == 0 && abs(cat_sdf(p)) < 1.2){ hit = 1; travel = max(travel, 200.0); }
	vec3 col;
	if (hit == 1){
		vec3 n = vec3(0,0,1);
		float dif = clamp(dot(n, sun_dir().xyz),0.0,1.0);
		vec3 alb = floor_albedo(p);
		float sg = smoothstep(4.4,1.8,length(p.xy-vec2(green_c.x,green_c.y)));
		col = alb*(0.55+0.50*dif)*(1.0-0.38*sg);
	} else if (hit == 2){
		col = vec3(0.06,0.62,0.26)*(0.40+0.70*clamp(dot(hit_n.xyz,sun_dir().xyz),0.0,1.0));
	} else if (hit == 3){
		col = vec3(0.10,0.80,0.35)*(0.45+0.70*clamp(abs(dot(hit_n.xyz,sun_dir().xyz)),0.0,1.0));
	} else if (hit == 4){
		col = vec3(0.85,0.88,0.92)*(0.45+0.70*clamp(abs(dot(hit_n.xyz,sun_dir().xyz)),0.0,1.0));
	} else {
		// C side (w>0) is the shared sky; B side ambient is a dimmer sky
		if (p.w > 0.0){
			col = cloud_sky(v);
		} else {
			vec3 d = normalize(v.xyz);
			float h = clamp(d.z*0.5+0.5,0.0,1.0);
			col = mix(vec3(0.50,0.62,0.80), vec3(0.10,0.22,0.45), h);
		}
	}
	col = col/(1.0+col);
	col = pow(col, vec3(0.6));
	vec2 vq = uv-0.5;
	col *= 1.0-0.45*dot(vq,vq);
	vec2 cs = uv-0.5; cs.x *= aspect;
	float cdist = length(cs);
	col = mix(col, vec3(0.0), (1.0-smoothstep(0.0036,0.0046,cdist))*0.45);
	col = mix(col, vec3(1.0), 1.0-smoothstep(0.0022,0.0030,cdist));
	return col;
}

void fragment(){
	vec3 col;
	if (view_mode > 0.5){ col = embed_diagram(UV); }
	else { col = render_scene(UV); }
	COLOR = vec4(col, 1.0);
}
