shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// shift the sprite colour toward rich gold
	vec3 gold = vec3(1.0, 0.75, 0.05);
	vec3 tinted = mix(tex.rgb, gold * length(tex.rgb), 0.88);

	// pulsing additive shimmer
	float pulse = sin(TIME * 2.5) * 0.3 + 0.7;
	tinted += vec3(1.0, 0.65, 0.0) * pulse * tex.a * 0.7;

	COLOR = vec4(tinted, tex.a);
}
