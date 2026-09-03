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

## IMPORTANTE — PASO MANUAL QUE TIENES QUE HACER UNA SOLA VEZ:
## Para pintar cada nombre de ingrediente de un color distinto DENTRO
## de lo que dice Nancy, "TextoLabel" necesita ser un RichTextLabel (un
## Label normal NO puede tener partes de un color y partes de otro). En
## el editor de Godot: selecciona el nodo DialogBox/TextoLabel -> clic
## derecho -> "Change Type..." -> RichTextLabel. Este script activa
## "Bbcode Enabled" solo, así que con cambiar el tipo de nodo basta.
## Mientras no hagas ese cambio, texto_label queda en null (por el "as
## RichTextLabel" de abajo) y NO se muestra el texto de Nancy — el
## resto del tutorial (pista, botones, resaltados) sigue funcionando.
@onready var texto_label: RichTextLabel = get_node_or_null("DialogBox/TextoLabel") as RichTextLabel
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
## vive DENTRO de TutorialLayer, justo encima de "Dim" (el rectángulo negro
## semitransparente que oscurece el fondo). Antes vivía como hermana de
## Mesa, es decir POR DEBAJO de Dim en el orden de dibujado — por eso Dim
## la oscurecía a ella también y se veía como si tuviera menos opacidad,
## aunque su alpha propio siempre fue 1.0. Ahora que está encima de Dim
## (y sigue detrás de DialogBox, para no tapar el texto), se ve al 100%.
## Tampoco es un "cliente" al que se le sirve nada, así que no vive en
## CharacterDB ni ocupa un puesto.
@onready var vaso: VasoMichelada = get_node_or_null("../Mesa/Vaso")
@onready var ingredientes_grid: Node = get_node_or_null("../Mesa")
@onready var nancy_portrait: CanvasItem = get_node_or_null("NancyPortrait")

## Contorno fantasma que marca "aquí va el vaso" sobre la mesa mientras
## el paso actual pide arrastrar uno. Se crea por código en _ready()
## (ver _crear_vaso_faltante), como hijo del panel "Vaso" real, así que
## no hace falta agregar ningún nodo nuevo a mano en Main.tscn.
var _vaso_faltante: TextureRect

## Cámbiala si guardaste el asset en otra carpeta/con otro nombre.
const RUTA_VASO_FALTANTE := "res://assets/michelada_capas/vaso_faltante.png"

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

## <<< AQUÍ CAMBIAS DE QUÉ COLOR SE VE CADA INGREDIENTE EN LO QUE DICE
## NANCY >>> (el texto grande del cuadro de diálogo, no la pista).
##
## Cada línea es "id_del_ingrediente": Color(r, g, b) — tres números del
## 0.0 (nada) al 1.0 (al tope) para Rojo, Verde y Azul. También puedes
## escribir Color("#rrggbb") con un código de color de internet si te es
## más fácil (ej. buscar "color picker" y copiar el código de ahí).
##
## Ejemplo para cambiar el rojo del chamoy café a un rojo más oscuro:
##   "chamoy_cafe": Color(0.6, 0.05, 0.05),
const COLOR_TEXTO_INGREDIENTE := {
	"vaso": Color(0.6, 0.6, 0.6),              # gris
	"chamoy_cafe": Color(0.85, 0.15, 0.15),    # rojo
	"escarchado_cafe": Color(0.85, 0.15, 0.15),# rojo
	"chamoy_azul": Color(0.2, 0.45, 0.95),     # azul
	"escarchado_azul": Color(0.2, 0.45, 0.95), # azul
	"limon": Color(0.7, 0.85, 0.15),           # (no me diste un color para este; te puse un verde-limón por defecto — cámbialo cuando quieras)
	"cerveza": Color(1.0, 0.55, 0.1),          # naranja
	"vodka": Color(0.6, 0.6, 0.6),             # gris (le dicen "whisky" pero el id interno es "vodka")
	"gatorlite": Color(0.2, 0.45, 0.95),       # azul
	"gomitas": Color(0.95, 0.85, 0.1),         # amarillo
}

## Qué PALABRA (tal cual aparece escrita, en MAYÚSCULAS, dentro de los
## textos de Nancy en "pasos" más abajo) se pinta con el color de qué
## ingrediente. "CHAMOY" y "CHILE EN POLVO" son genéricos (Nancy no
## siempre dice si es rojo o azul en esa frase), así que aquí quedan
## apuntando al color rojo/café como representante por default.
##
## <<< PARA AGREGAR OTRA PALABRA A COLOREAR >>>: solo agrega una línea
## nueva aquí, por ejemplo "WHISKY": "vodka", y ya se va a colorear
## cualquier futuro texto de Nancy que diga "WHISKY" en mayúsculas.
const PALABRAS_COLOREADAS := {
	"VASO": "vaso",
	"CHAMOY": "chamoy_cafe",
	"CHILE EN POLVO": "escarchado_cafe",
	"LIMÓN": "limon",
	"VODKA": "vodka",
	"CERVEZA": "cerveza",
	"GATORLITE": "gatorlite",
	"GOMITAS": "gomitas",
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
		"texto": "Por último, unas GOMITAS para decorar — y con eso la Michelada ya queda lista.",
		"requiere": ["gomitas"],
	},
	{
		"texto": "¡Michelada lista! Ahora te enseño el otro camino: el Azulito. Vamos a vaciar este vaso y armar uno nuevo desde cero.",
		"requiere": [],
		"vaciar_vaso_al_mostrar": true,
	},
	{
		"texto": "Arrastra un VASO nuevo al centro de la mesa para empezar el Azulito.",
		"requiere": ["vaso"],
	},
	{
		"texto": "Otra vez, dale sabor al borde con CHAMOY: rojo o azul, el que gustes.",
		"requiere": ["chamoy_cafe", "chamoy_azul"],
	},
	{
		"texto": "Encima va el CHILE EN POLVO (el escarchado): también rojo o azul.",
		"requiere": ["escarchado_cafe", "escarchado_azul"],
	},
	{
		"texto": "Aquí está la diferencia con la Michelada: en vez de limón, ahora sí dale VODKA — esto es justo lo que hace que sea un Azulito.",
		"requiere": ["vodka"],
	},
	{
		"texto": "Después del vodka va el GATORLITE (en vez de cerveza).",
		"requiere": ["gatorlite"],
	},
	{
		"texto": "Y para cerrar, otra vez unas GOMITAS. ¡Tu Azulito ya está listo!",
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
var _tween_ingredientes: Tween
var _tween_boton: Tween


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
	if texto_label:
		texto_label.bbcode_enabled = true
	_crear_vaso_faltante()

	# BUG ARREGLADO: antes, mostrar_paso(0) se llamaba aquí mismo, en el
	# mismo frame de _ready(). El problema es que Godot llama _ready() de
	# ABAJO hacia ARRIBA y por RAMAS: como "Mesa" (con todos los íconos de
	# ingredientes) está en una rama distinta a "TutorialLayer", no había
	# garantía de que los íconos ya estuvieran completamente listos (con
	# su propio _ready() ya corrido) en ese instante — y por eso a veces
	# el bloqueo de "no se puede arrastrar nada todavía" no alcanzaba a
	# aplicarse a tiempo, dejando TODO arrastrable desde la presentación
	# de Nancy. "await process_frame" espera a que el árbol COMPLETO de
	# la escena termine su primer _ready() antes de bloquear/mostrar el
	# paso 0, así ya no importa en qué orden esté cada nodo.
	await get_tree().process_frame
	mostrar_paso(0)


## Crea (una sola vez) el contorno fantasma que marca "aquí va el vaso"
## sobre la mesa. Vive como HIJO del panel "Vaso" real, así que sea cual
## sea su posición/tamaño en Main.tscn, el contorno siempre cae
## exactamente encima de él, sin medir nada a mano. Empieza invisible;
## _actualizar_ingredientes() lo prende/apaga según el paso.
func _crear_vaso_faltante() -> void:
	if vaso == null:
		return
	_vaso_faltante = TextureRect.new()
	_vaso_faltante.name = "TutorialVasoFaltante"
	if ResourceLoader.exists(RUTA_VASO_FALTANTE):
		_vaso_faltante.texture = load(RUTA_VASO_FALTANTE)
	else:
		push_warning("TutorialOverlay: no encontré " + RUTA_VASO_FALTANTE + " — revisa RUTA_VASO_FALTANTE.")
	_vaso_faltante.visible = false
	_vaso_faltante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vaso_faltante.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vaso_faltante.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vaso_faltante.set_anchors_preset(Control.PRESET_FULL_RECT)
	vaso.add_child(_vaso_faltante)


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

	# Para el paso que introduce el Azulito: vacía el vaso de la
	# Michelada que se acaba de armar, para empezar limpio.
	if paso.get("vaciar_vaso_al_mostrar", false) and vaso != null:
		vaso.reset()

	if texto_label:
		texto_label.text = _colorear_texto_nancy(paso["texto"])
	paso_label.text = "Paso %d de %d" % [i + 1, pasos.size()]

	var requiere: Array = paso.get("requiere", [])
	var necesita_accion: bool = requiere.size() > 0

	if pista_label:
		pista_label.visible = necesita_accion
	siguiente_btn.visible = not necesita_accion
	if necesita_accion:
		_dejar_de_parpadear_boton()
	else:
		siguiente_btn.text = "¡Empezar!" if i == pasos.size() - 1 else "Siguiente ▶"
		_parpadear_boton()

	saltar_btn.visible = i < pasos.size() - 1

	_actualizar_ingredientes(requiere)


func _actualizar_ingredientes(requiere: Array) -> void:
	if _vaso_faltante:
		_vaso_faltante.visible = requiere.has("vaso")

	if requiere.is_empty():
		if pista_label:
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
	if pista_label:
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


## Envuelve cada palabra de PALABRAS_COLOREADAS que aparezca en el texto
## de Nancy con su [color=...] correspondiente (BBCode). REQUIERE que
## texto_label sea un RichTextLabel (ver la nota junto a su declaración,
## arriba del todo del archivo) — si no lo es, esta función igual
## funciona bien, solo que nadie la va a mostrar coloreada.
func _colorear_texto_nancy(texto: String) -> String:
	for palabra in PALABRAS_COLOREADAS:
		var id: String = PALABRAS_COLOREADAS[palabra]
		var color: Color = COLOR_TEXTO_INGREDIENTE.get(id, Color.WHITE)
		texto = texto.replace(palabra, "[color=#%s]%s[/color]" % [color.to_html(false), palabra])
	return texto


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
			_resaltados.append(nodo)
	# El contorno "vaso_faltante" también debe parpadear mientras haga
	# falta un vaso, igual que el ícono de la bandeja.
	if ids.has("vaso") and _vaso_faltante:
		_resaltados.append(_vaso_faltante)
	if _resaltados.is_empty():
		return
	_tween_ingredientes = _crear_parpadeo(_resaltados)


func _quitar_resaltados() -> void:
	if _tween_ingredientes:
		_tween_ingredientes.kill()
		_tween_ingredientes = null
	for nodo in _resaltados:
		if is_instance_valid(nodo):
			nodo.scale = Vector2(1, 1)
	_resaltados.clear()


## Mismo parpadeo, pero para el botón "Siguiente" cuando hay que
## clicarlo para avanzar (pasos sin "requiere").
func _parpadear_boton() -> void:
	_dejar_de_parpadear_boton()
	_tween_boton = _crear_parpadeo([siguiente_btn])


func _dejar_de_parpadear_boton() -> void:
	if _tween_boton:
		_tween_boton.kill()
		_tween_boton = null
	siguiente_btn.scale = Vector2(1, 1)


## Motor compartido del parpadeo: agranda y encoge en loop, en paralelo,
## la lista de nodos que le pases. Lo usan tanto _resaltar() (íconos +
## vaso_faltante) como _parpadear_boton() (el botón Siguiente).
func _crear_parpadeo(nodos: Array) -> Tween:
	for nodo in nodos:
		nodo.pivot_offset = nodo.size / 2.0
	var tween := create_tween().set_loops()
	# OJO: si en algún momento el juego pausa el árbol de escena mientras
	# se muestra el tutorial (get_tree().paused = true), un Tween normal
	# se detiene solo — y eso se ve exactamente como "no parpadea nada".
	# Esta línea obliga a que el parpadeo siga corriendo pase lo que pase.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	for nodo in nodos:
		tween.parallel().tween_property(nodo, "scale", Vector2(1.18, 1.18), 0.45)
	tween.chain()
	for nodo in nodos:
		tween.parallel().tween_property(nodo, "scale", Vector2(1.0, 1.0), 0.45)
	return tween


func _on_ingrediente_soltado(ingrediente_id: String) -> void:
	if not visible:
		return
	if ingrediente_id == "vaso" and _vaso_faltante:
		_vaso_faltante.visible = false
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
	SFX.play_boton()
	_avanzar()


func _on_saltar_pressed() -> void:
	SFX.play_boton()
	_terminar()


func _terminar() -> void:
	_quitar_resaltados()
	_dejar_de_parpadear_boton()
	_bloquear_ingredientes([])
	if _vaso_faltante:
		_vaso_faltante.visible = false
	visible = false
	if nancy_portrait:
		nancy_portrait.visible = false
	if vaso != null:
		vaso.reset()
	# El tutorial ya terminó (completo o saltado): a partir de ahora sí
	# pueden empezar a sonar los sonidos aleatorios de ambiente.
	Ambiente.iniciar_sonidos_aleatorios()
	tutorial_terminado.emit()
