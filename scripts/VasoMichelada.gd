extends Panel
## VasoMichelada.gd
## -----------------
## Es la "zona de soltar" (drop zone): representa el vaso. Godot llama
## _can_drop_data() para preguntar si puede aceptar lo que se está
## arrastrando, y _drop_data() cuando el jugador suelta el mouse aquí.
## No calculamos nada de calidad en este script: solo avisamos qué se soltó
## mediante una señal, y MicheladaMixer.gd decide qué hacer con eso.

signal ingrediente_soltado(ingrediente_id: String)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("ingrediente_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ingrediente_soltado.emit(data["ingrediente_id"])
