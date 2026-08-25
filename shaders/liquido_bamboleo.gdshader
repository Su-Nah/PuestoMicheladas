shader_type canvas_item;
// liquido_bamboleo.gdshader
// --------------------------
// Hace que el LÍQUIDO pintado dentro del vaso se mueva de verdad mientras
// lo cargas (ver BamboleoDrag.gd, que actualiza estos uniforms cada frame).
//
// La idea, columna por columna de pixeles:
//   1. Calculamos dónde está la SUPERFICIE del líquido AHORITA en esta
//      columna:  nivel original + inclinación + una ola que viaja.
//   2. Todo pixel ARRIBA de esa superficie se vuelve transparente (ahí ya
//      no hay líquido), y todo pixel abajo se pinta con el arte original,
//      re-estirando la columna para que no queden huecos ni se vea
//      cortado el degradado.
//
// Así la superficie se queda "horizontal" cuando el vaso se ladea (el
// vaso gira, el líquido no) y chapotea con olas — que es justo lo que el
// ojo espera de un líquido, sin tocar el PNG pintado.

// Dónde está la superficie del líquido en el ARTE original, en UV
// (0 = borde de arriba de la textura, 1 = el de abajo). Se mide una vez
// por textura: cerveza ~0.055, gatorlite ~0.087, vodka ~0.782.
uniform float nivel_art : hint_range(0.0, 1.0) = 0.06;

// Inclinación de la superficie: cuánto sube/baja (en UV) por cada unidad
// de distancia horizontal al centro. BamboleoDrag lo calcula como
// tan(ángulo del líquido - ángulo del vaso) por el aspecto de la textura.
uniform float pendiente = 0.0;

// La ola: amplitud (en UV), fase (avanza con el tiempo y la agitación) y
// cuántas ondas completas caben a lo ancho del vaso.
uniform float amp_ola = 0.0;
uniform float fase_ola = 0.0;
uniform float ondas = 1.6;

void fragment() {
	// Superficie actual de ESTA columna. El sin() es la ola viajera; la
	// pendiente inclina la línea alrededor del centro del vaso.
	float sup = nivel_art
		+ pendiente * (UV.x - 0.5)
		+ amp_ola * sin(TAU * ondas * UV.x + fase_ola);
	sup = clamp(sup, 0.0, 0.98);

	if (UV.y < sup) {
		// Arriba de la superficie: aquí ya no hay líquido.
		COLOR = vec4(0.0);
	} else {
		// Abajo: re-mapeamos la columna [sup..1] del vaso a la columna
		// [nivel_art..1] del arte. El fondo (UV.y = 1) queda anclado y la
		// parte de arriba se estira/encoge para seguir a la superficie —
		// sin huecos cuando baja, sin repetir pixeles cuando sube.
		float y_art = nivel_art + (UV.y - sup) * (1.0 - nivel_art) / max(1.0 - sup, 0.001);
		COLOR = texture(TEXTURE, vec2(UV.x, y_art));
	}
}
