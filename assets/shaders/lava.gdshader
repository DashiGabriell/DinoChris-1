shader_type spatial;
render_mode unshaded, cull_disabled;

// Rio de lava do corredor infinito: ruído barato correndo no sentido do rio.
// Fica "unshaded" para brilhar por igual dentro da vala, sem depender da luz.

uniform vec4 cor_quente : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform vec4 cor_escura : source_color = vec4(0.32, 0.03, 0.01, 1.0);
uniform float velocidade = 0.45;
uniform float escala = 2.6;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// O rio corre no eixo Z (comprimento da vala): desloca o ruído em Y.
	vec2 uv = vec2(UV.x * 3.0, UV.y * escala);
	uv.y -= TIME * velocidade;
	float n = ruido(uv) * 0.62 + ruido(uv * 2.4 + 11.0) * 0.38;
	float brilho = smoothstep(0.32, 0.78, n);
	vec3 cor = mix(cor_escura.rgb, cor_quente.rgb, brilho);
	// crosta escura se mexendo devagar + veios claros
	cor = mix(cor, cor_quente.rgb, smoothstep(0.72, 0.95, n) * 0.55);
	ALBEDO = cor * 1.35;
}
