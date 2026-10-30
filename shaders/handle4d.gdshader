// ============================================================================
//  v50 same-space A<->B wormhole on ONE smooth profile surface
//
//  F(p) = |p_xyz| - f(p.w) = 0
//  f(w) = two Gaussian lobes + one neck
//     = R_L*exp(-((w-a)/s)^2) + R_L*exp(-((w+a)/s)^2)
//       + R_N*exp(-(w/sn)^2)
//
//  One 3D surface of revolution around w: two lobes (the same space at two
//  positions) + one neck. No spheres/tubes/unions/rims/rooms; the neck is the
//  surface's own shape. The observer/lights live on it: enter A, cross the
//  neck, exit B.
// ============================================================================

shader_type canvas_item;
render_mode unshaded;

uniform vec4 cam_pos = vec4(2.6, 0.0, 0.0, -2.0);
uniform vec4 cam_fwd = vec4(-1.0, 0.0, 0.0, 1.0);
uniform vec4 cam_right = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 cam_up = vec4(0.0, 0.0, 1.0, 0.0);
uniform float aspect = 1.7778;
uniform float time_s = 0.0;
uniform float view_mode = 0.0;
uniform float r_lobe = 2.6;
uniform float r_neck = 1.1;
uniform float sig_lobe = 1.0;
uniform float sig_neck = 1.2;
uniform float a_w = 2.0;
uniform float w_max = 5.0;

const int MAX_STEPS = 900;
const float PI_F = 3.14159265;

float profile(float w){
	return r_lobe * exp(-pow((w - a_w) / sig_lobe, 2.0))
		+ r_lobe * exp(-pow((w + a_w) / sig_lobe, 2.0))
		+ r_neck * exp(-pow(w / sig_neck, 2.0));
}
float profile_d(float w){
	float e = 0.001;
	return (profile(w + e) - profile(w - e)) / (2.0 * e);
}
float surf_f(vec4 p){
	return length(p.xyz) - profile(p.w);
}
vec4 surf_grad(vec4 p){
	float rho = length(p.xyz);
	vec3 g3 = (rho > 0.0001) ? p.xyz / rho : vec3(0.0);
	return vec4(g3, -profile_d(p.w));
}
vec4 surf_project(vec4 p){
	for (int i = 0; i < 4; i++){
		vec4 g = surf_grad(p);
		p -= g * surf_f(p) / max(dot(g, g), 1e-6);
	}
	return p;
}
vec4 surf_normal(vec4 p){
	return normalize(surf_grad(p));
}

vec3 surface_col(vec4 p, vec4 n, vec4 v){
	float w = p.w;
	float ang = atan(p.y, p.x);
	// two lobes colored differently; neck highlighted
	float lobe = smoothstep(-0.8, 0.8, w);
	vec3 ca = vec3(0.12, 0.44, 0.86);
	vec3 cb = vec3(0.90, 0.46, 0.16);
	vec3 c = mix(ca, cb, lobe);
	// grid in (w, angle)
	float gw = abs(fract(w * 1.6 + 0.5) - 0.5);
	float ga = abs(fract(ang / PI_F * 8.0 + 0.5) - 0.5);
	float grid = 1.0 - smoothstep(0.0, 0.08, min(gw, ga));
	c *= 0.72 + 0.28 * grid;
	// neck highlight
	float neck = exp(-pow(w / 0.75, 2.0));
	c += vec3(0.30, 0.80, 1.0) * neck * 0.35;
	float fres = pow(1.0 - abs(dot(normalize(n), normalize(v))), 2.0);
	c += vec3(0.45, 0.72, 1.0) * fres * 0.35;
	return c;
}

vec3 render_scene(vec2 uv){
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	ndc.x *= aspect;
	vec4 v = normalize(cam_fwd + (cam_right * ndc.x + cam_up * ndc.y));
	vec4 p = surf_project(cam_pos);
	float travel = 0.0;
	vec4 n = surf_normal(p);
	for (int i = 0; i < MAX_STEPS; i++){
		float F = surf_f(p);
		float h = clamp(0.5 * abs(F) + 0.04, 0.05, 0.6);
		float near_neck = exp(-pow(p.w / 1.2, 2.0));
		h *= 1.0 - 0.35 * near_neck;
		p += v * h;
		p = surf_project(p);
		n = surf_normal(p);
		v -= n * dot(v, n);
		v = normalize(v);
		travel += h;
	}
	vec3 col = surface_col(p, n, v);
	col = mix(col, vec3(0.02, 0.03, 0.06), clamp(1.0 - exp(-0.006 * travel), 0.0, 0.75));
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

// V: profile rho = f(w), two lobes + neck, camera marker
vec3 profile_diagram(vec2 uv){
	float w = mix(-w_max, w_max, uv.x);
	float r = mix(w_max * 1.15, 0.0, uv.y);
	float curve = profile(w);
	vec3 col = vec3(0.012, 0.015, 0.028);
	vec2 g = abs(fract(vec2(uv.x * 24.0, uv.y * 18.0)) - 0.5);
	col += vec3(0.05, 0.07, 0.10) * (1.0 - smoothstep(0.0, 0.06, min(g.x, g.y)));
	// profile curve
	float dc = abs(r - curve);
	col = mix(col, vec3(0.90, 0.95, 1.0), (1.0 - smoothstep(0.0, 0.08, dc)));
	// filled tube interior (for readability)
	if (r < curve){
		float lobe = smoothstep(-0.8, 0.8, w);
		col = mix(vec3(0.62, 0.30, 0.10), vec3(0.10, 0.38, 0.78), lobe) * 0.55;
		float neck = exp(-pow(w / 0.75, 2.0));
		col += vec3(0.25, 0.70, 1.0) * neck * 0.55;
	}
	// camera marker
	float dc_cam = length(vec2(w - cam_pos.w, r - length(cam_pos.xyz)));
	col = mix(col, vec3(0.3, 1.0, 0.45), (1.0 - smoothstep(0.0, 0.16, dc_cam)));
	// neck marker
	float dc_neck = length(vec2(w, r - profile(0.0)));
	col = mix(col, vec3(0.35, 0.75, 1.0), (1.0 - smoothstep(0.0, 0.10, dc_neck)));
	return col;
}

void fragment(){
	vec3 col;
	if (view_mode > 0.5){
		col = profile_diagram(UV);
	} else {
		col = render_scene(UV);
	}
	COLOR = vec4(col, 1.0);
}
