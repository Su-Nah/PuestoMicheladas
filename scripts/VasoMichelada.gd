class_name VasoMichelada
extends Panel
## VasoMichelada.gd
## -----------------
## El vaso YA NO existe siempre: por defecto no hay ningún vaso en el
## centro de la mesa. El jugador tiene que arrastrar el ícono "vaso" (el
## archivo mesa.png en la bandeja de ingredientes) hasta aquí para crear
## una michelada nueva (existe = true). Antes de eso, no se puede agregar
## ningún otro ingrediente.
##
## Cuando el vaso ya existe y tiene contenido, este mismo Panel se vuelve
## ARRASTRABLE (_get_drag_data): el jugador lo agarra y lo suelta encima
## del cliente al que se lo quiere servir (ver ClienteSlotDrop.gd). Al
## servirse, Main.gd llama a reset() y el vaso vuelve a desaparecer del
## centro hasta que se arrastre uno nuevo.
##
## DOS RECETAS POSIBLES
## ---------------------
## Michelada: vaso -> chamoy (rojo o azul) -> chile en polvo/escarchado
##            (rojo o azul) -> LIMÓN -> CERVEZA -> gomitas
## Azulito:   vaso -> chamoy (rojo o azul) -> chile en polvo/escarchado
##            (rojo o azul) -> VODKA -> GATORLITE -> gomitas
## Los primeros 3 pasos son iguales para las dos bebidas; el camino se
## decide en automático según si el jugador pone limón (Michelada) o
## vodka (Azulito) — después de eso ya no se puede cambiar de camino.
##
## SISTEMA DE CAPAS
## ------------------
## Igual que antes: cada ingrediente es una capa (TextureRect) que se
## muestra/oculta según el estado. Cuando no existe vaso, TODAS las capas
## están ocultas (ni siquiera se ve el vidrio).

## --- Catálogo de ingredientes -------------------------------------------
const VASO := "vaso"
const CHAMOY_CAFE := "chamoy_cafe"
const CHAMOY_AZUL := "chamoy_azul"
const ESCARCHADO_CAFE := "escarchado_cafe"
const ESCARCHADO_AZUL := "escarchado_azul"
const LIMON := "limon"
const CERVEZA := "cerveza"
const VODKA := "vodka"
const GATORLITE := "gatorlite"
const GOMITAS := "gomitas"

const CHAMOYS := [CHAMOY_CAFE, CHAMOY_AZUL]
const ESCARCHADOS := [ESCARCHADO_CAFE, ESCARCHADO_AZUL]

## Mapa ingrediente -> nombre del nodo TextureRect (capa) dentro de
## $VasoCapas. "vaso" no tiene capa propia: su capa es "VidrioBase" +
const CAPAS := {
	CHAMOY_CAFE: "ChamoyCafe",
	CHAMOY_AZUL: "ChamoyAzul",
	ESCARCHADO_CAFE: "RimEscarchadoCafe",
	ESCARCHADO_AZUL: "RimEscarchadoAzul",
	LIMON: "Limon",
	CERVEZA: "LiquidoCerveza",
	VODKA: "LiquidoVodka",
	GATORLITE: "LiquidoGatorlite",
	GOMITAS: "Gomitas",
}

## --- Señales --------------------------------------------------------------
signal ingrediente_soltado(ingrediente_id: String)
signal ingrediente_rechazado(ingrediente_id: String, motivo: String)
signal vaso_actualizado(ingredientes_presentes: Array)

## --- Estado -----------------------------------------------------------
## true si ahora mismo hay un vaso creado en el centro. Falso por defecto:
## no existe nada hasta que se arrastra "vaso" aquí.
var existe: bool = false
var ingredientes_agregados: Dictionary = {}

@onready var capas_root: Node = $VasoCapas
@onready var vidrio_base: CanvasItem = $VasoCapas/VidrioBase


func _ready() -> void:
	_actualizar_capas()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("ingrediente_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	intentar_agregar(data["ingrediente_id"])


## El vaso mismo se puede arrastrar (para servírselo a un cliente) SOLO si
## ya existe. Godot llama esto cuando el jugador empieza a arrastrar desde
## este Panel.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not existe:
		return null
	var preview := TextureRect.new()
	preview.texture = vidrio_base.texture
	preview.custom_minimum_size = Vector2(70, 110)
	preview.expand_mode = 1
	preview.stretch_mode = 5
	set_drag_preview(preview)
	return {"es_vaso": true}


## Intenta agregar un ingrediente (o crear el vaso, si id == "vaso").
## Devuelve true si quedó agregado/creado, false si se rechazó.
func intentar_agregar(id: String) -> bool:
	if id == VASO:
		if existe:
			ingrediente_rechazado.emit(id, "ya_hay_vaso")
			return false
		existe = true
		ingredientes_agregados.clear()
		ingrediente_soltado.emit(id)
		_actualizar_capas()
		return true

	if ingredientes_agregados.has(id):
		return true

	var motivo := _validar_orden(id)
	if motivo != "":
		ingrediente_rechazado.emit(id, motivo)
		return false

	ingredientes_agregados[id] = true
	ingrediente_soltado.emit(id)
	_actualizar_capas()
	return true


## Devuelve "" si {id} se puede agregar ahora mismo, o un código de motivo
## de rechazo si no.
func _validar_orden(id: String) -> String:
	if not existe:
		return "falta_vaso_primero"

	var ya_chamoy: bool = ingredientes_agregados.has(CHAMOY_CAFE) or ingredientes_agregados.has(CHAMOY_AZUL)
	var ya_escarchado: bool = ingredientes_agregados.has(ESCARCHADO_CAFE) or ingredientes_agregados.has(ESCARCHADO_AZUL)
	var ya_segundo: bool = ingredientes_agregados.has(CERVEZA) or ingredientes_agregados.has(GATORLITE)
	var ya_gomitas: bool = ingredientes_agregados.has(GOMITAS)

	if ya_gomitas:
		return "vaso_completo"

	if id in CHAMOYS:
		for otro in CHAMOYS:
			if otro != id and ingredientes_agregados.has(otro):
				return "solo_un_chamoy"
		if ya_escarchado:
			return "chamoy_fuera_de_tiempo"
		return ""

	if id in ESCARCHADOS:
		if not ya_chamoy:
			return "falta_chamoy_primero"
		for otro in ESCARCHADOS:
			if otro != id and ingredientes_agregados.has(otro):
				return "solo_un_escarchado"
		return ""

	if id == LIMON:
		if not ya_escarchado:
			return "falta_escarchado_primero"
		if ingredientes_agregados.has(VODKA):
			return "ya_es_azulito"
		if ya_segundo:
			return "orden_incorrecto"
		return ""

	if id == VODKA:
		if not ya_escarchado:
			return "falta_escarchado_primero"
		if ingredientes_agregados.has(LIMON):
			return "ya_es_michelada"
		if ya_segundo:
			return "orden_incorrecto"
		return ""

	if id == CERVEZA:
		if not ingredientes_agregados.has(LIMON):
			return "falta_limon_primero"
		return ""

	if id == GATORLITE:
		if not ingredientes_agregados.has(VODKA):
			return "falta_vodka_primero"
		return ""

	if id == GOMITAS:
		if not ya_segundo:
			return "falta_segundo_paso"
		return ""

	return "ingrediente_desconocido"


func _actualizar_capas() -> void:
	if capas_root == null:
		push_warning("VasoMichelada: no se encontró el nodo VasoCapas. Revisa la escena.")
		return

	vidrio_base.visible = existe

	for id in CAPAS:
		var nombre_nodo: String = CAPAS[id]
		var nodo := capas_root.get_node_or_null(nombre_nodo)
		if nodo == null:
			push_warning("VasoMichelada: falta la capa '%s' dentro de VasoCapas." % nombre_nodo)
			continue
		nodo.visible = existe and ingredientes_agregados.has(id)

	vaso_actualizado.emit(obtener_ingredientes())


## Vacía y hace desaparecer el vaso del centro (llamar tras servir a un
## cliente, o cuando el jugador presiona "Vaciar vaso").
func reset() -> void:
	ingredientes_agregados.clear()
	existe = false
	_actualizar_capas()


func obtener_ingredientes() -> Array:
	return ingredientes_agregados.keys()


## true si el vaso contiene alcohol (cerveza O vodka) — útil para el
## dilema de venta a menores.
func tiene_alcohol() -> bool:
	return ingredientes_agregados.has(CERVEZA) or ingredientes_agregados.has(VODKA)
