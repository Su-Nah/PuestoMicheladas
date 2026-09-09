shader_type canvas_item;

// 1.0 = líquido lleno (se ve toda la imagen).
// 0.0 = líquido vacío (no se ve nada).
// Main.gd cambia este valor cada frame según la paciencia restante del
// cliente (ver _actualizar_nivel_michelada en Main.gd).
uniform float nivel : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// UV.y = 0.0 es la parte de ARRIBA de la imagen, 1.0 es ABAJO.
	// Si "nivel" es 0.6, se oculta el 40% de arriba (UV.y < 0.4) y se ve
	// el 60% de abajo — como si el líquido se hubiera ido vaciando desde
	// la superficie hacia el fondo del vaso.
	if (UV.y < (1.0 - nivel)) {
		color.a = 0.0;
	}
	COLOR = color;
}
