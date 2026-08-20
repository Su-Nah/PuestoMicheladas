class_name TutorialOverlay
extends Control
## TutorialOverlay.gd
## -------------------
## Tutorial estilo "novela visual" interactivo: Nancy explica un paso a la
## vez y, si el paso requiere una acción concreta, el tutorial avanza solo
## cuando el jugador la hace de verdad (arrastrar tal ingrediente, o el
## vaso mismo). Los pasos sin acción (intro, explicaciones, cierre) usan
## el botón "Siguiente".

signal tutorial_terminado

@onready var texto_label: Label = $DialogBox/TextoLabel
@onready var paso_label: Label = $DialogBox/PasoLabel
@onready var nombre_label: Label = $DialogBox/NombreLabel
@onready var pista_label: Label = $DialogBox/PistaLabel
@onready var siguiente_btn: Button = $DialogBox/SiguienteBtn
@onready var saltar_btn: Button = $DialogBox/SaltarBtn

## El vaso y los íconos de ingredientes viven como hermanos/nietos de este
## nodo (todos dentro de Main). Se usa get_node_or_null en vez de get_node
## para que, si algo se renombra o se borra en Main.tscn, el tutorial se
## desactive solo (con un aviso en consola) en vez de trabar el juego.
##
## OJO: "IngredientesGrid" ya no existe como contenedor propio — los
## íconos de ingredientes (VodkaIcon, LimonIcon, etc.) ahora son hijos
## directos de "Mesa". Por eso buscamos "../Mesa" y no
## "../Mesa/IngredientesGrid" (ese path viejo ya no resuelve a nada y
## dejaba sin funcionar el resaltado/bloqueo de ingredientes del tutorial).
##
## Nancy SÍ sigue en la escena (es la narradora del tutorial), pero ahora
## empieza con visible = false en Main.tscn: nunca es un "cliente" al que
## se le sirve nada, así que no vive en CharacterDB ni ocupa un puesto.
## Este mismo script la muestra (mostrar_paso/mostrar) y la oculta
## (_terminar) cuando corresponde.
@onready var vaso: VasoMichelada = get_node_or_null("../Mesa/Vaso")
@onready var ingredientes_grid: Node = get_node_or_null("../Mesa")
@onready var nancy_portrait: CanvasItem = get_node_or_null("../NancyPortrait")

## Ingrediente -> nombre del nodo icono dentro de IngredientesGrid.
const NODOS_INGREDIENTE := {
	"vaso": "VasoIcon",
	"chamoy_cafe": "ChamoyCafeIcon",
	"chamoy_azul": "ChamoyAzulIcon",
	"escarchado_cafe": "EscarchadoCafeIcon",
	"escarchado_azul": "EscarchadoAzulIcon",
	"limon": "LimonIcon",
	"cerveza": "CervezaIcon",
	"vodka": "VodkaIcon",
	"gatorlite": "GatorliteIcon",
	"gomitas": "GomitasIcon",
}

## Cada paso: texto de Nancy y "requiere" (ingredientes válidos para
## avanzar solo; vacío = se avanza con el botón "Siguiente").
var pasos: Array = [
	{
		"texto": "¡Hola! Soy Nancy, tu hermana. Aquí se preparan dos bebidas: la Michelada y el Azulito. Te voy a enseñar los pasos con una Michelada — el Azulito se prepara casi igual.",
		"requiere": [],
	},
	{
		"texto": "Todo empieza igual: no hay ningún vaso puesto todavía. Arrastra un VASO al centro de la mesa para crear una bebida nueva.",
		"requiere": ["vaso"],
	},
	{
		"texto": "Ahora dale sabor al borde con CHAMOY: rojo o azul, el que gustes (aquí vamos a usar el rojo).",
		"requiere": ["chamoy_cafe", "chamoy_azul"],
	},
	{
		"texto": "Encima del chamoy va el CHILE EN POLVO (el escarchado): también rojo o azul.",
		"requiere": ["escarchado_cafe", "escarchado_azul"],
	},
	{
		"texto": "Aquí el camino se divide en dos: si sigues con LIMÓN, es una Michelada; si sigues con VODKA, es un Azulito. Vamos a hacer una Michelada — dale LIMÓN.",
		"requiere": ["limon"],
	},
	{
		"texto": "Después del limón va la CERVEZA. (Si hubieras elegido vodka, aquí iría GATORLITE en su lugar.)",
		"requiere": ["cerveza"],
	},
	{
		"texto": "Por último, unas GOMITAS para decorar — y con eso la bebida ya queda lista.",
		"requiere": ["gomitas"],
	},
	{
		"texto": "Para servirla, ya no hay botón: arrastra el VASO COMPLETO directo hacia el cliente al que se la vas a dar. Así, si hay dos o tres clientes a la vez, no hay forma de confundirte.",
		"requiere": [],
	},
	{
		"texto": "Última regla, muy importante: tanto la Michelada (cerveza) como el Azulito (vodka) llevan alcohol. Si el cliente es MENOR DE EDAD, mejor no le completes ninguna de las dos.",
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
	# Nancy tiene que verse desde YA (no solo cuando se llama a mostrar()),
	# porque el tutorial arranca visible por defecto apenas carga la escena.
	if nancy_portrait:
		nancy_portrait.visible = true
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


func _actualizar_ingredientes(requiere: Array) -> void:
	if requiere.is_empty():
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
		"vaso": "el vaso", "chamoy_cafe": "el chamoy rojo", "chamoy_azul": "el chamoy azul",
		"escarchado_cafe": "el chile en polvo rojo", "escarchado_azul": "el chile en polvo azul",
		"limon": "el limón", "cerveza": "la cerveza", "vodka": "el vodka",
		"gatorlite": "el gatorlite", "gomitas": "las gomitas",
	}
	return mapa.get(id, id)


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
	_bloquear_ingredientes([])
	visible = false
	if nancy_portrait:
		nancy_portrait.visible = false
	if vaso != null:
		vaso.reset()
	tutorial_terminado.emit()
