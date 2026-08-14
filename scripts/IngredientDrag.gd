extends Panel
## IngredientDrag.gd
## ------------------
## Ícono de un ingrediente que el jugador puede ARRASTRAR con el mouse
## hacia el vaso. "ingrediente_id" y "etiqueta" se configuran por cada
## ícono directamente en MicheladaMixer.tscn (o desde el Inspector).

@export var ingrediente_id: String = "clamato"  # clamato | limon | chile | sal
@export var etiqueta: String = "Clamato"

@onready var label: Label = $Label


func _ready() -> void:
	label.text = etiqueta


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Godot llama esta función automáticamente en cuanto detecta que el
	# jugador empezó a arrastrar este control con el mouse (clic + mover).
	var preview := Label.new()
	preview.text = etiqueta
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)

	# Lo que regresamos aquí es lo que recibe la zona donde se suelte.
	return {"ingrediente_id": ingrediente_id}
