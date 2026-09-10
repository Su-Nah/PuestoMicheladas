shader_type canvas_item;

// Grosor del contorno, en píxeles (igual idea que "outline_size" en los
// Label de Godot). Puesto en 11 para que combine con DayLabel/MoneyLabel.
uniform float contorno_px : hint_range(0.0, 40.0) = 11.0;
uniform vec4 color_contorno : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// El relleno sale blanco puro; si el nodo tiene "modulate" puesto en
// código (como el gris/verde de DayTimeline), se sigue viendo bien: el
// contorno negro no se altera (negro x cualquier color = negro), y el
// relleno blanco sí se tiñe con ese modulate, tal como se espera.
uniform vec4 color_relleno : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;

	if (tex.a > 0.5) {
		COLOR = vec4(color_relleno.rgb, tex.a);
		return;
	}

	// Píxel transparente: revisa varias direcciones alrededor buscando
	// algún píxel opaco dentro de "contorno_px" píxeles de distancia.
	float encontrado = 0.0;
	const int MUESTRAS = 16;
	for (int i = 0; i < MUESTRAS; i++) {
		float angulo = float(i) / float(MUESTRAS) * TAU;
		vec2 direccion = vec2(cos(angulo), sin(angulo));
		vec2 desplazamiento = direccion * px * contorno_px;
		float alpha_vecino = texture(TEXTURE, UV + desplazamiento).a;
		encontrado = max(encontrado, alpha_vecino);
	}
	COLOR = vec4(color_contorno.rgb, encontrado);
}
