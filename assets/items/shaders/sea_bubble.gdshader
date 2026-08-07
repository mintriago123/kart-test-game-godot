shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.82, 0.86, 1.0);
uniform vec4 rim_color : source_color = vec4(0.78, 1.0, 0.94, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.48;
uniform float rim_power : hint_range(0.1, 8.0) = 2.4;

void fragment() {
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), rim_power);
	ALBEDO = mix(shallow_color.rgb, rim_color.rgb, fresnel);
	EMISSION = rim_color.rgb * fresnel * 0.55;
	ALPHA = base_alpha + fresnel * rim_alpha;
	ROUGHNESS = 0.12;
}
