shader_type canvas_item;

uniform float wave_amount : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX.x += sin(VERTEX.y * 0.18 + TIME * 14.0) * wave_amount * 20.0;
	VERTEX.y += cos(VERTEX.x * 0.12 + TIME * 10.0) * wave_amount * 7.0;
}
