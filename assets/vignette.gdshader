shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.2);
	float edge = smoothstep(0.28, 0.71, length(p));
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898,78.233))) * 43758.5453);
	COLOR = vec4(vec3(0.024, 0.049, 0.033), edge * 0.43 + grain * 0.024);
}
