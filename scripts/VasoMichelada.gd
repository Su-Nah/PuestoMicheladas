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

## Ingredientes LÍQUIDOS de verdad (los que se bambolean dentro del vaso).
const LIQUIDOS := [CERVEZA, VODKA, GATORLITE]
## Lo que se pierde en un derrame: los líquidos y las gomitas (van flotando
## encima, así que se van con el líquido). El chamoy, el escarchado y el
## limón viven pegados al BORDE del vaso: esos aguantan la sacudida.
const DERRAMABLES := [CERVEZA, VODKA, GATORLITE, GOMITAS]

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
## Se emite cuando el jugador sacude tanto el mouse llevando el vaso que el
## contenido se derrama (ver BamboleoDrag.gd). Trae la lista de ingredientes
## que se perdieron, por si la UI quiere nombrarlos.
signal liquido_derramado(ingredientes_perdidos: Array)

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
##
## El preview ya no es una foto fija del vidrio: es un BamboleoDrag (ver
## scripts/BamboleoDrag.gd), una copia del vaso CON su contenido que se
## inclina según qué tan brusco mueves el mouse — y si lo sacudes de más,
## el líquido se derrama de verdad (nos llama a derramar_liquidos()).
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not existe:
		return null
	# Sonido propio de agarrar el vaso YA ARMADO (distinto del sonido de
	# agarrar el ícono de vaso vacío desde la bandeja).
	SFX.play_agarrar_vaso_listo()
	set_drag_preview(BamboleoDrag.crear(self))
	return {"es_vaso": true}


## Mientras el vaso "va en la mano" (su propio arrastre está activo), el que
## se queda en la mesa se ve translúcido — así se lee como "lo levantaste",
## no como si hubiera dos vasos. Godot manda estas notificaciones a TODOS
## los Controls cuando empieza/termina cualquier arrastre, por eso hay que
## revisar que el dato arrastrado sea justamente el vaso (y no un
## ingrediente).
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY and data.get("es_vaso", false) == true:
			capas_root.modulate = Color(1, 1, 1, 0.35)
	elif what == NOTIFICATION_DRAG_END:
		capas_root.modulate = Color(1, 1, 1, 1)


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
		SFX.play_soltar(id) # sonido de "soltar" el vaso sobre la mesa
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
	SFX.play_soltar(id) # sonido de "soltar" propio de ESTE ingrediente
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


## true si el vaso trae algún líquido servido — si no, no hay nada que
## derramar por más que se sacuda (un vaso escarchado y vacío aguanta todo).
func tiene_liquido() -> bool:
	for id in LIQUIDOS:
		if ingredientes_agregados.has(id):
			return true
	return false


## ¡Se derramó! Quita del vaso todo lo DERRAMABLE (líquidos + gomitas) y
## avisa con la señal liquido_derramado. Devuelve la lista de lo perdido
## (BamboleoDrag la usa para vaciar también su copia visual).
##
## Ojo: NO es reset() — el vaso sigue existiendo, con su chamoy, su
## escarchado y su limón intactos. El validador de orden (_validar_orden)
## ya permite volver a servir el líquido y las gomitas después de esto,
## así que el verdadero castigo es el TIEMPO perdido mientras la paciencia
## de los clientes sigue corriendo.
func derramar_liquidos() -> Array:
	var perdidos: Array = []
	for id in DERRAMABLES:
		if ingredientes_agregados.has(id):
			ingredientes_agregados.erase(id)
			perdidos.append(id)
	if perdidos.is_empty():
		return perdidos
	# EXTRA (no lo pediste, pero como agregaste un evento nuevo -el
	# derrame- te dejo el gancho de sonido listo; bórralo si no lo
	# quieres). Necesita SFX.play_derrame() en SFX.gd, ver el archivo
	# actualizado.
	SFX.play_derrame()
	_actualizar_capas()
	liquido_derramado.emit(perdidos)
	return perdidos
