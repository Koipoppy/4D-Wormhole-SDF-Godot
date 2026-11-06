// 底栏的无色毛玻璃：取样屏幕并做低分辨率模糊，去饱和后叠一层中性玻璃雾。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.0;
uniform float darken = 0.58;
uniform float glass_alpha = 0.94;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = textureLod(screen_tex, uv, blur_lod).rgb * 0.5;
	c += textureLod(screen_tex, uv + vec2(px.x * 5.0, 0.0), blur_lod).rgb * 0.25;
	c += textureLod(screen_tex, uv - vec2(px.x * 5.0, 0.0), blur_lod).rgb * 0.25;

	// 去色：只留一点原始色相，整体是中性玻璃
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, 0.10);
	c = mix(c, vec3(0.90, 0.91, 0.91), 0.08);
	c *= darken;
	c = mix(c, vec3(0.045, 0.050, 0.050), 0.12);

	// 顶部一条极细的高光，像玻璃边缘
	c += (1.0 - smoothstep(0.0, 0.035, UV.y)) * 0.05;

	COLOR = vec4(c, glass_alpha);
}
