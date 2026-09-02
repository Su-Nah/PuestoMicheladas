class_name ClienteSlotDrop
extends Control
## ClienteSlotDrop.gd
## -------------------
## Se pone en cada uno de los 3 "puestos" de cliente (ClienteSlot0/1/2).
## Su único trabajo es aceptar que le suelten encima el vaso (arrastrado
## desde VasoMichelada.gd) y avisarle a Main.gd mediante una señal — así
## Main.gd no tiene que adivinar en cuál Control cayó la soltada.

signal vaso_recibido(slot_index: int)

@export var slot_index: int = 0


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("es_vaso", false) == true


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	# Sonido propio de ENTREGAR el vaso a un cliente (distinto del
	# sonido de colocar el vaso vacío sobre la mesa).
	SFX.play_entregar_vaso()
	vaso_recibido.emit(slot_index)
