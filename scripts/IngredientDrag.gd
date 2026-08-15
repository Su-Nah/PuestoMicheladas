extends TextureRect
## IngredientDrag.gd
## ------------------
## Ícono (sprite) de un ingrediente que el jugador puede ARRASTRAR con el
## mouse hacia el vaso. La imagen (textura) se asigna directamente en
## MicheladaMixer.tscn; aquí solo definimos su identificador y el preview
## que se ve mientras arrastras.

@export var ingrediente_id: String = "clamato"  # clamato | limon | chile | sal
@export var etiqueta: String = "Clamato"

@onready var label: Label = $Label


func _ready() -> void:
	label.text = etiqueta
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_drag_data(_at_position: Vector2) -> Variant:
	# El preview es una copia visual que sigue al mouse mientras arrastras.
	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(64, 64)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	return {"ingrediente_id": ingrediente_id}
