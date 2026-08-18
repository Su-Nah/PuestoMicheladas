class_name TutorialOverlay
extends Control
## TutorialOverlay.gd
## -------------------
## Tutorial estilo "novela visual" (como Ren'py) PERO interactivo: Nancy,
## la hermana del jugador, explica un paso a la vez y, si ese paso requiere
## una acción (por ejemplo "pon limón"), el tutorial NO avanza con un botón:
## avanza solo cuando el jugador de verdad suelta ese ingrediente en el
## vaso. Mientras un paso requiere una acción:
##   - Se resalta (con una animación de pulso) el/los ingrediente(s) que
##     sirven para ese paso.
##   - Se bloquean temporalmente los demás ingredientes (no se pueden
##     arrastrar) para que el jugador no se adelante y rompa el orden.
## Los pasos sin ingrediente asociado (la intro y el cierre) se avanzan con
## el botón "Siguiente".
##
## NANCY, DETRÁS DE LA MESA
## -------------------------
## El retrato de Nancy ("NancyPortrait") ya NO vive dentro de este overlay:
## vive como hermano de "Mesa" en Main.tscn (igual que los retratos de los
## clientes), colocado ANTES que "Mesa" en el árbol de nodos para que la
## mesa se dibuje encima y tape su parte de abajo — así se ve parada detrás
## del mostrador, igual que cualquier cliente, en vez de cortada por un
## rectángulo. Este script solo la muestra/oculta según si el tutorial está
## activo (get_node("../NancyPortrait")).
##
## Mientras el tutorial está visible, el día NO ha empezado
## (jornada_activa en Main.gd sigue en false), así que la mesa y el vaso
## están ahí mismo, debajo del cuadro de diálogo, listos para usarse.

signal tutorial_terminado

@onready var texto_label: Label = $DialogBox/TextoLabel
@onready var paso_label: Label = $DialogBox/PasoLabel
@onready var nombre_label: Label = $DialogBox/NombreLabel
@onready var pista_label: Label = $DialogBox/PistaLabel
@onready var siguiente_btn: Button = $DialogBox/SiguienteBtn
@onready var saltar_btn: Button = $DialogBox/SaltarBtn

## Nancy y el vaso viven como hermanos de este nodo (todos hijos directos
## de Main). Si mueves este nodo de lugar, ajusta estos paths.
@onready var vaso: VasoMichelada = get_node("../Mesa/Vaso")
@onready var ingredientes_grid: Node = get_node("../Mesa/IngredientesGrid")
@onready var nancy_portrait: CanvasItem = get_node("../NancyPortrait")

## Ingrediente -> nombre del nodo icono dentro de IngredientesGrid (debe
## coincidir con los nombres que pusimos en Main.tscn).
const NODOS_INGREDIENTE := {
	"limon": "LimonIcon",
	"sal": "SalIcon",
	"escarchado_cafe": "EscarchadoCafeIcon",
	"escarchado_azul": "EscarchadoAzulIcon",
	"hielo": "HieloIcon",
	"cerveza": "CervezaIcon",
	"cerveza_azul": "CervezaAzulIcon",
}

## Cada paso: el texto que dice Nancy, y "requiere": la lista de
## ingredientes válidos para avanzar (con soltar UNO de la lista alcanza).
## Si "requiere" está vacía, el paso se avanza con el botón "Siguiente".
var pasos: Array = [
	{
		"texto": "¡Hola! Soy Nancy, tu hermana. Antes de que te quedes tú sola/o a cargo del puesto, déjame enseñarte cómo se prepara una buena michelada. Ahí abajo tienes los ingredientes y el vaso: vamos a prepararla juntos.",
		"requiere": [],
	},
	{
		"texto": "Primero se moja el borde del vaso con LIMÓN. Arrástralo al vaso para continuar.",
		"requiere": ["limon"],
	},
	{
		"texto": "¡Muy bien! Ahora, si quieres, escarcha el borde con SAL, o con uno de los dos escarchados (café o azul) — nunca los tres juntos. Prueba con cualquiera de ellos.",
		"requiere": ["sal", "escarchado_cafe", "escarchado_azul"],
	},
	{
		"texto": "Perfecto. Ahora agrega el HIELO.",
		"requiere": ["hielo"],
	},
	{
		"texto": "Por último, la CERVEZA (o la cerveza azul, para los que quieren algo distinto). Ojo: en cuanto la sirvas, ¡la michelada queda lista y no se le puede agregar nada más!",
		"requiere": ["cerveza", "cerveza_azul"],
	},
	{
		"texto": "¡Así se prepara una michelada! Una regla de la casa muy importante: si el cliente es MENOR DE EDAD, jamás le sirvas cerveza. Prepárale una michelada sin alcohol y va a quedar igual de contento/a.",
		"requiere": [],
	},
	{
		"texto": "¡Listo! Ya sabes todo lo que necesitas. Ahora sí... ¡a atender el puesto! Buena suerte.",
		"requiere": [],
	},
]

var indice := 0
var _resaltados: Array = []
var _tween: Tween


func _ready() -> void:
	siguiente_btn.pressed.connect(_on_siguiente_pressed)
	saltar_btn.pressed.connect(_on_saltar_pressed)
	if vaso != null:
		vaso.ingrediente_soltado.connect(_on_ingrediente_soltado)
	nombre_label.text = "Nancy"
	mostrar_paso(0)


## Llamar desde Main.gd para (re)iniciar el tutorial desde el primer paso.
func mostrar() -> void:
	visible = true
	if nancy_portrait:
		nancy_portrait.visible = true
	if vaso != null:
		vaso.reset()
	mostrar_paso(0)


func mostrar_paso(i: int) -> void:
	indice = i
	var paso: Dictionary = pasos[i]
	texto_label.text = paso["texto"]
	paso_label.text = "Paso %d de %d" % [i + 1, pasos.size()]

	var requiere: Array = paso.get("requiere", [])
	var necesita_accion: bool = requiere.size() > 0

	pista_label.visible = necesita_accion
	siguiente_btn.visible = not necesita_accion
	if not necesita_accion:
		siguiente_btn.text = "¡Empezar!" if i == pasos.size() - 1 else "Siguiente ▶"

	saltar_btn.visible = i < pasos.size() - 1

	_actualizar_ingredientes(requiere)


## Muestra/oculta el mensaje de pista y resalta/bloquea los ingredientes
## según lo que se necesite en el paso actual.
func _actualizar_ingredientes(requiere: Array) -> void:
	if requiere.is_empty():
		# Paso informativo (sin acción): no toca mover nada todavía, así
		# que bloqueamos TODOS los ingredientes para que el jugador no se
		# adelante y desordene el vaso antes de que le toque.
		pista_label.text = ""
		_quitar_resaltados()
		_bloquear_ingredientes(["__ninguno__"])
		return

	var nombres: Array = []
	for id in requiere:
		nombres.append(_nombre_bonito(id))
	var texto_ingredientes := ""
	for j in range(nombres.size()):
		if j > 0:
			texto_ingredientes += " o "
		texto_ingredientes += nombres[j]
	pista_label.text = "👉 Arrastra " + texto_ingredientes + " al vaso para continuar."

	_bloquear_ingredientes(requiere)
	_resaltar(requiere)


func _nombre_bonito(id: String) -> String:
	var mapa := {
		"limon": "el limón", "sal": "la sal", "escarchado_cafe": "el escarchado café",
		"escarchado_azul": "el escarchado azul", "hielo": "el hielo",
		"cerveza": "la cerveza", "cerveza_azul": "la cerveza azul",
	}
	return mapa.get(id, id)


## Deja arrastrables SOLO los ingredientes en {permitidos}; si la lista
## viene vacía, deja TODOS arrastrables de nuevo (usado al terminar el
## tutorial y en los pasos que no requieren ninguna acción).
func _bloquear_ingredientes(permitidos: Array) -> void:
	if ingredientes_grid == null:
		return
	for id in NODOS_INGREDIENTE:
		var nodo := ingredientes_grid.get_node_or_null(NODOS_INGREDIENTE[id]) as Control
		if nodo == null:
			continue
		var habilitado: bool = permitidos.is_empty() or permitidos.has(id)
		nodo.mouse_filter = Control.MOUSE_FILTER_STOP if habilitado else Control.MOUSE_FILTER_IGNORE
		nodo.modulate = Color(1, 1, 1, 1) if habilitado else Color(1, 1, 1, 0.35)


func _resaltar(ids: Array) -> void:
	_quitar_resaltados()
	if ingredientes_grid == null:
		return
	for id in ids:
		var nodo := ingredientes_grid.get_node_or_null(NODOS_INGREDIENTE.get(id, "")) as Control
		if nodo:
			nodo.pivot_offset = nodo.size / 2.0
			_resaltados.append(nodo)
	if _resaltados.is_empty():
		return
	_tween = create_tween().set_loops()
	_tween.set_trans(Tween.TRANS_SINE)
	for nodo in _resaltados:
		_tween.parallel().tween_property(nodo, "scale", Vector2(1.18, 1.18), 0.45)
	_tween.chain()
	for nodo in _resaltados:
		_tween.parallel().tween_property(nodo, "scale", Vector2(1.0, 1.0), 0.45)


func _quitar_resaltados() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	for nodo in _resaltados:
		if is_instance_valid(nodo):
			nodo.scale = Vector2(1, 1)
	_resaltados.clear()


func _on_ingrediente_soltado(ingrediente_id: String) -> void:
	if not visible:
		return
	var paso: Dictionary = pasos[indice]
	var requiere: Array = paso.get("requiere", [])
	if requiere.size() > 0 and requiere.has(ingrediente_id):
		await get_tree().create_timer(0.5).timeout
		_avanzar()


func _avanzar() -> void:
	if indice >= pasos.size() - 1:
		_terminar()
	else:
		mostrar_paso(indice + 1)


func _on_siguiente_pressed() -> void:
	_avanzar()


func _on_saltar_pressed() -> void:
	_terminar()


func _terminar() -> void:
	_quitar_resaltados()
	_bloquear_ingredientes([]) # deja todo desbloqueado para el juego real
	visible = false
	if nancy_portrait:
		nancy_portrait.visible = false
	tutorial_terminado.emit()
