shader_type canvas_item;

uniform sampler2D fog_mask      : filter_nearest;
uniform sampler2D fog_noise_tex : repeat_enable, filter_linear;
uniform vec4  fog_color        = vec4(0.0, 0.0, 0.0, 0.94);
uniform vec2  maze_origin      = vec2(-1648.0, -1456.0);
uniform vec2  maze_size        = vec2(3296.0, 2912.0);
uniform float time             = 0.0;

// The ColorRect covers exactly the maze in world space (follow_viewport_enabled = true),
// so UV(0,0) = maze top-left and UV(1,1) = maze bottom-right.  No camera math needed.

float fog_sample(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
	return texture(fog_mask, uv).r;
}

void fragment() {
	vec2 fog_uv    = UV;
	vec2 world_pos = maze_origin + UV * maze_size;

	float revealed = fog_sample(fog_uv);
	float alpha = (1.0 - revealed) * fog_color.a;

	if (alpha > 0.0) {
		vec2 t = vec2(1.0) / vec2(textureSize(fog_mask, 0));

		float n1 = 0.0;
		n1 = max(n1, fog_sample(fog_uv + vec2( t.x,  0.0)));
		n1 = max(n1, fog_sample(fog_uv + vec2(-t.x,  0.0)));
		n1 = max(n1, fog_sample(fog_uv + vec2( 0.0,  t.y)));
		n1 = max(n1, fog_sample(fog_uv + vec2( 0.0, -t.y)));
		n1 = max(n1, fog_sample(fog_uv + vec2( t.x,  t.y)));
		n1 = max(n1, fog_sample(fog_uv + vec2(-t.x,  t.y)));
		n1 = max(n1, fog_sample(fog_uv + vec2( t.x, -t.y)));
		n1 = max(n1, fog_sample(fog_uv + vec2(-t.x, -t.y)));

		float n2 = n1;
		n2 = max(n2, fog_sample(fog_uv + vec2( 2.0*t.x,  0.0)));
		n2 = max(n2, fog_sample(fog_uv + vec2(-2.0*t.x,  0.0)));
		n2 = max(n2, fog_sample(fog_uv + vec2( 0.0,  2.0*t.y)));
		n2 = max(n2, fog_sample(fog_uv + vec2( 0.0, -2.0*t.y)));
		n2 = max(n2, fog_sample(fog_uv + vec2( 2.0*t.x,  2.0*t.y)));
		n2 = max(n2, fog_sample(fog_uv + vec2(-2.0*t.x,  2.0*t.y)));
		n2 = max(n2, fog_sample(fog_uv + vec2( 2.0*t.x, -2.0*t.y)));
		n2 = max(n2, fog_sample(fog_uv + vec2(-2.0*t.x, -2.0*t.y)));

		// Animate the fog boundary: shift the sample point using slow sin/cos waves.
		// Only applied near the edge (n1/n2 rings) so interior fog stays static.
		float edge_prox = 0.0;
		if      (n1 > 0.01) edge_prox = 1.0;
		else if (n2 > 0.01) edge_prox = 0.5;

		if (edge_prox > 0.0) {
			vec2 world_shift = vec2(
				sin(world_pos.x * 0.028 + world_pos.y * 0.013 + time * 1.1)
					* cos(world_pos.y * 0.019 + time * 0.7),
				cos(world_pos.y * 0.026 + world_pos.x * 0.017 + time * 0.9)
					* sin(world_pos.x * 0.022 + time * 1.3)
			) * 14.0 * edge_prox;
			// Nearest-neighbour re-sample: the shift snaps to whole fog cells
			vec2 shifted_uv = (world_pos + world_shift - maze_origin) / maze_size;
			revealed = fog_sample(shifted_uv);
			alpha = (1.0 - revealed) * fog_color.a;
		}

		if      (n1 > 0.01) alpha *= 0.5;
		else if (n2 > 0.01) alpha *= 0.75;

		// Density patches from precomputed noise texture — one cheap texture sample.
		// UV drifts slowly so patches appear to roll through the fog.
		vec2 noise_uv = world_pos * 0.0006 + vec2(time * 0.015, time * 0.010);
		float density = texture(fog_noise_tex, noise_uv).r;
		alpha *= mix(0.65, 1.0, density);
	}

	COLOR = vec4(fog_color.rgb, alpha);
}
