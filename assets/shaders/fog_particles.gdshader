shader_type canvas_item;

uniform sampler2D fog_mask : filter_nearest;
uniform vec2 player_world_pos;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float camera_zoom  = 1.0;
uniform vec2 maze_origin;
uniform vec2 maze_size;

void fragment() {
	vec2 screen_uv = FRAGCOORD.xy / viewport_size;
	vec2 offset    = (screen_uv - vec2(0.5)) * viewport_size / camera_zoom;
	vec2 world_pos = player_world_pos + offset;
	vec2 fog_uv    = (world_pos - maze_origin) / maze_size;
	float fog_val  = 0.0;
	if (fog_uv.x >= 0.0 && fog_uv.x <= 1.0 && fog_uv.y >= 0.0 && fog_uv.y <= 1.0) {
		fog_val = texture(fog_mask, fog_uv).r;
	}
	// visible only where fog exists; fade out as fog thins toward revealed area
	COLOR.a *= (1.0 - fog_val);
}
