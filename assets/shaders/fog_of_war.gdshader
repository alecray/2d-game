shader_type canvas_item;

uniform sampler2D fog_mask;
uniform vec2 player_world_pos;
uniform vec2 viewport_size = vec2(1152.0, 648.0);
uniform float camera_zoom = 1.0;
uniform float world_size = 2000.0;

void fragment() {
	vec2 offset = (UV - vec2(0.5)) * viewport_size / camera_zoom;
	vec2 world_pos = player_world_pos + offset;

	vec2 fog_uv = world_pos / world_size + vec2(0.5);
	float explored = 0.0;
	if (fog_uv.x >= 0.0 && fog_uv.x <= 1.0 && fog_uv.y >= 0.0 && fog_uv.y <= 1.0) {
		explored = texture(fog_mask, fog_uv).r;
	}

	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - explored);
}
