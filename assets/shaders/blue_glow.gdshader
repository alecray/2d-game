shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// shift the sprite colour toward bright blue
	vec3 blue = vec3(0.1, 0.45, 1.0);
	vec3 tinted = mix(tex.rgb, blue * length(tex.rgb), 0.85);

	// pulsing additive glow on top
	float pulse = sin(TIME * 3.0) * 0.3 + 0.7;
	tinted += vec3(0.0, 0.25, 1.0) * pulse * tex.a * 0.6;

	COLOR = vec4(tinted, tex.a);
}
