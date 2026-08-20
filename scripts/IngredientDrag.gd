extends TextureRect
## IngredientDrag.gd
## ------------------
## Ícono (sprite) de un ingrediente que el jugador puede ARRASTRAR con el
## mouse hacia el vaso. La imagen (textura) se asigna directamente en
## Main.tscn; aquí solo definimos su identificador y el preview que se ve
## mientras arrastras.

## OJO: esta línea es la que faltaba y rompía la escena. "ingrediente_id"
## se usa más abajo (en _get_drag_data) y también lo lee VasoMichelada.gd
## para saber qué ingrediente soltaste — sin declararlo aquí como
## propiedad, Godot no puede asignarle el valor que cada ícono trae
## configurado en Main.tscn (ej. "limon", "vodka", "gomitas"...), y esa
## falla al cargar la escena es la causa más probable de que el juego se
## trabara.
@export var ingrediente_id: String = ""

## Ya no se usa para mostrar texto (quitamos las labels de nombre), pero lo
## dejamos declarado por si algún nodo en Main.tscn todavía tiene este
## valor asignado — así Godot no truena al cargar la escena por una
## propiedad "fantasma". Si ya no aparece en ningún nodo, no pasa nada por
## dejarlo aquí sin usar.
@export var etiqueta: String = ""


func _ready() -> void:
	# expand_mode = Ignore Size: el nodo respeta SU propio tamaño (definido
	# en la escena) en vez de crecer al tamaño real del archivo importado.
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# stretch_mode = Keep Aspect Centered: la imagen se encoge/agranda
	# proporcionalmente para caber en esa caja, sin deformarse.
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_drag_data(_at_position: Vector2) -> Variant:
	# El preview es una copia visual que sigue al mouse mientras arrastras.
	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(64, 64)

	# Mismo par de propiedades que en el ícono original: sin expand_mode,
	# el preview crece al tamaño real del archivo (por eso se veía enorme).
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Por defecto el preview se dibuja con su esquina superior-izquierda
	# EN el mouse, no centrado. Lo desplazamos medio ancho/alto hacia
	# arriba-izquierda para que quede centrado justo en el cursor.
	preview.position = -preview.custom_minimum_size / 2.0

	set_drag_preview(preview)

	return {"ingrediente_id": ingrediente_id}
