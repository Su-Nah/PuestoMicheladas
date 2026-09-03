extends Control
## Main.gd
## -------
## Escena única del juego, 100% automática:
##  - Hasta 3 clientes pueden estar en la mesa AL MISMO TIEMPO, en 3
##    "puestos" fijos (izquierda / centro / derecha) que nunca se
##    encimian. Cuál puesto ocupa cada cliente nuevo es aleatorio.
##  - Cada cliente tiene su propia barra de paciencia; si se agota, se va
##    sin comprar.
##  - Por defecto NO hay ningún vaso en el centro de la mesa: hay que
##    arrastrar el ícono "vaso" desde la bandeja de ingredientes para
##    crear uno nuevo (ver VasoMichelada.gd).
##  - Para servir, SE ARRASTRA el vaso ya preparado directo hacia el
##    cliente que lo va a recibir (no hay botón "Servir"). Así nunca hay
##    confusión de a quién le tocaba qué bebida cuando hay varios clientes
##    a la vez.
##  - A los clientes que NO quieren comprar (solo vienen a hablar) se les
##    atiende con un toque/clic directo, sin necesidad de vaso.
##  - La calidad promedio del día sube o baja cuántos clientes llegan al
##    día siguiente (reputación).

const NUM_SLOTS := 3

## NOTA IMPORTANTE: los nodos de UI puramente informativos (etiqueta de
## día, de dinero, resultado, línea de tiempo, tutorial) ahora se buscan
## con get_node_or_null() en vez de "$Nodo" directo. La diferencia es que
## "$Nodo" hace TRONAR el juego entero si ese nodo no existe en la escena
## (por ejemplo, si se borró la etiqueta de dinero al editar Main.tscn);
## get_node_or_null() simplemente devuelve null, y el resto del código ya
## revisa "if money_label:" antes de usarlo. Así, si falta o se renombra
## algún nodo puramente decorativo, el juego sigue siendo JUGABLE (solo se
## deja de ver ese textito), en vez de trabarse por completo.
@onready var day_label: Label = get_node_or_null("InfoBar/DayLabel")
@onready var money_label: Label = get_node_or_null("InfoBar/MoneyLabel")
@onready var day_timeline: HBoxContainer = get_node_or_null("DayTimeline")

## Estos SÍ son parte del juego (no solo informativos): si faltan, el
## juego de verdad no puede funcionar, así que se buscan igual con
## get_node_or_null() pero se avisa fuerte por consola para que sea fácil
## detectar el problema en vez de fallar en silencio más adelante.
@onready var vaso: VasoMichelada = get_node_or_null("Mesa/Vaso")
@onready var vaso_label: Label = get_node_or_null("Mesa/Vaso/VasoLabel")
@onready var reiniciar_btn: Button = get_node_or_null("Mesa/ReiniciarBtn")
@onready var result_label: Label = get_node_or_null("Mesa/ResultLabel")

@onready var tutorial: TutorialOverlay = get_node_or_null("TutorialLayer")

## Usados por el oscurecido de fin de día (ver más abajo): "fondo" es el
## fondo de toda la pantalla, "mesa" es el contenedor de la mesa (que ya
## incluye, como hijos, la mesa misma, todos los íconos de ingredientes,
## y el vaso) — así que basta con teñir a "mesa" para que se tiña TODO lo
## que hay encima de ella.
@onready var fondo: TextureRect = get_node_or_null("Fondo")
@onready var mesa: ColorRect = get_node_or_null("Mesa")

## Nodos de los 3 "puestos" de cliente, en orden. Cada uno es un
## ClienteSlotDrop (Control clickeable + zona de soltar el vaso) con un
## TextureRect (retrato), Label (nombre), TextureRect (emoji), ProgressBar
## (paciencia) y Label (diálogo) adentro.
@onready var slot_nodes: Array = [
	get_node_or_null("ClienteSlot0"), get_node_or_null("ClienteSlot1"), get_node_or_null("ClienteSlot2"),
]
@onready var slot_portraits: Array = [
	get_node_or_null("ClienteSlot0/Portrait"), get_node_or_null("ClienteSlot1/Portrait"), get_node_or_null("ClienteSlot2/Portrait"),
]
@onready var slot_nombres: Array = [
	get_node_or_null("ClienteSlot0/NombreLabel"), get_node_or_null("ClienteSlot1/NombreLabel"), get_node_or_null("ClienteSlot2/NombreLabel"),
]
@onready var slot_emojis: Array = [
	get_node_or_null("ClienteSlot0/EmojiIcon"), get_node_or_null("ClienteSlot1/EmojiIcon"), get_node_or_null("ClienteSlot2/EmojiIcon"),
]
@onready var slot_barras: Array = [
	get_node_or_null("ClienteSlot0/PatienceBar"), get_node_or_null("ClienteSlot1/PatienceBar"), get_node_or_null("ClienteSlot2/PatienceBar"),
]
@onready var slot_dialogos: Array = [
	get_node_or_null("ClienteSlot0/DialogueLabel"), get_node_or_null("ClienteSlot1/DialogueLabel"), get_node_or_null("ClienteSlot2/DialogueLabel"),
]

## Globo de cómic con el "pedido" del cliente (una michelada/azulito en
## miniatura, armada con las mismas capas que el vaso real). Ver
## _mostrar_pedido_burbuja() / _ocultar_pedido_burbuja() más abajo.
@onready var slot_burbujas: Array = [
	get_node_or_null("ClienteSlot0/PedidoBubble"), get_node_or_null("ClienteSlot1/PedidoBubble"), get_node_or_null("ClienteSlot2/PedidoBubble"),
]
@onready var slot_burbuja_vasos: Array = [
	get_node_or_null("ClienteSlot0/PedidoBubble/MiniVaso"), get_node_or_null("ClienteSlot1/PedidoBubble/MiniVaso"), get_node_or_null("ClienteSlot2/PedidoBubble/MiniVaso"),
]

const CARA_FELIZ := preload("res://assets/sprites/faces/happy.png")
const CARA_NEUTRAL := preload("res://assets/sprites/faces/neutral.png")
const CARA_ENOJADA := preload("res://assets/sprites/faces/angry.png")

## Todos los ingredientes que SÍ cuentan para la calidad de la bebida (el
## "vaso" no cuenta: es solo el recipiente, no una preferencia de sabor).
const ORDEN_CANONICO := [
	"chamoy_cafe", "chamoy_azul", "escarchado_cafe", "escarchado_azul",
	"limon", "vodka", "cerveza", "gatorlite", "gomitas",
]

const ETIQUETAS := {
	"chamoy_cafe": "Chamoy (rojo)",
	"chamoy_azul": "Chamoy azul",
	"escarchado_cafe": "Chile en polvo (rojo)",
	"escarchado_azul": "Chile en polvo azul",
	"limon": "Limón",
	"vodka": "Vodka",
	"cerveza": "Cerveza",
	"gatorlite": "Gatorlite",
	"gomitas": "Gomitas",
}

## Nombre del nodo TextureRect (capa) dentro de PedidoBubble/MiniVaso para
## cada ingrediente. Es EXACTAMENTE el mismo mapeo que usa el vaso real
## (VasoMichelada.CAPAS), así que lo reutilizamos en vez de duplicarlo:
## así, si algún día cambia un nombre de capa allá, no hay que acordarse
## de tocarlo aquí también.
var CAPAS_BURBUJA: Dictionary = VasoMichelada.CAPAS

## Texto que se le muestra al jugador cuando VasoMichelada rechaza un
## ingrediente por estar fuera de orden.
const MOTIVOS_TEXTO := {
	"falta_vaso_primero": "Primero arrastra un vaso al centro.",
	"ya_hay_vaso": "Ya hay un vaso aquí. Sírvelo o vacíalo antes de poner otro.",
	"solo_un_chamoy": "El borde ya tiene chamoy. Solo se usa un color.",
	"chamoy_fuera_de_tiempo": "El chamoy va justo después del vaso.",
	"falta_chamoy_primero": "Primero hay que ponerle chamoy.",
	"solo_un_escarchado": "El borde ya tiene chile en polvo. Solo se usa un color.",
	"falta_escarchado_primero": "Primero hay que ponerle chile en polvo.",
	"ya_es_azulito": "Ya le pusiste vodka: este va a ser un Azulito, no una Michelada.",
	"ya_es_michelada": "Ya le pusiste limón: esta va a ser una Michelada, no un Azulito.",
	"orden_incorrecto": "Eso no va en este paso.",
	"falta_limon_primero": "Antes de la cerveza va el limón.",
	"falta_vodka_primero": "Antes del gatorlite va el vodka.",
	"falta_segundo_paso": "Falta completar el paso anterior antes de las gomitas.",
	"vaso_completo": "¡Esta bebida ya está lista! Sírvela (arrástrala al cliente) o vacíala.",
	"ingrediente_desconocido": "Ese ingrediente no se reconoce.",
}

## --- Paciencia: dura más al principio, y se acorta poco a poco cada día
## para que el juego se ponga más difícil gradualmente.
const PACIENCIA_MULTIPLICADOR_DIA1 := 2.2
const PACIENCIA_MULTIPLICADOR_MINIMO := 1.1

## slots[i] es null (vacío) o {"cliente": Dictionary, "paciencia_actual":
## float, "paciencia_maxima": float}.
var slots: Array = [null, null, null]
var resolviendo_slot: Array = [false, false, false]

var cola_del_dia: Array = []
var total_clientes_dia := 0
var clientes_resueltos := 0
var calidades_del_dia: Array = []
var jornada_activa := false # false mientras se muestra el resumen del día o el tutorial

var _mostrando_rechazo := false


# =====================================================================
# OSCURECIDO DE FIN DE DÍA (efecto "atardecer")
# ---------------------------------------------------------------------
# Conforme avanza el día (se van resolviendo clientes), tres grupos de
# nodos se ponen progresivamente más oscuros y con un tinte azulado:
#   1. PERSONAJES -> los retratos de los 3 clientes (slot_portraits).
#   2. FONDO      -> el fondo de toda la pantalla (nodo "Fondo").
#   3. MESA       -> el nodo "Mesa" (y, como consecuencia, TODO lo que
#      cuelga de él: el tablero, los íconos de ingredientes, el vaso).
#
# Los indicadores (MoneyLabel, DayLabel, DayTimeline con los clientes
# que van a aparecer) NUNCA se tocan aquí a propósito, para que sigan
# siendo legibles pase lo que pase.
#
# CÓMO FUNCIONA POR DENTRO: cada CanvasItem (TextureRect, ColorRect,
# etc.) tiene una propiedad "modulate" — un color que se MULTIPLICA
# sobre lo que dibuja ese nodo Y TODOS SUS HIJOS. Blanco (1,1,1,1) =
# "sin filtro, color normal". Bajar los 3 números = oscurecer; subir el
# azul (el 3er número) por encima del rojo/verde = tinte azul. Aquí
# simplemente interpolamos (lerp) entre el color de día y un color de
# "noche" propio de cada grupo, según _progreso_del_dia().
# =====================================================================

## Color normal ("de día", sin filtro) para los 3 grupos. Prácticamente
## nunca hace falta tocar esto.
const COLOR_DIA := Color(1.0, 1.0, 1.0, 1.0)

## <<< AJUSTA AQUÍ EL COLOR "DE NOCHE" DE CADA GRUPO >>>
## Es el color que alcanza cada grupo justo cuando se fue el ÚLTIMO
## cliente del día (progreso = 100%). Para cada uno:
##   - Bájale los 3 números (R, G, B) por igual para oscurecer más.
##   - Sube el B (azul) por encima de R y G para que se vea más azulado.
##   - Deja el 4to número (alpha) en 1.0 casi siempre.
const COLOR_NOCHE_PERSONAJES := Color(0.55, 0.60, 0.85, 1.0)
const COLOR_NOCHE_FONDO := Color(0.35, 0.42, 0.75, 1.0)
const COLOR_NOCHE_MESA := Color(0.50, 0.56, 0.82, 1.0)

## Cuánto tarda (en segundos) en verse el cambio de color cada vez que
## se actualiza (cuando se resuelve un cliente), en vez de saltar de
## golpe al nuevo tono. Súbelo para una transición más lenta/suave.
const DURACION_TRANSICION_TINTE := 1.5

## Cuánto tarda el "amanecer" entre el fin de un día y el inicio del
## siguiente (ver _amanecer() y _fin_del_dia() más abajo).
const DURACION_AMANECER := 2.0


## Llamar cada vez que cambie cuántos clientes del día ya se resolvieron.
## progreso: 0.0 = arranca el día (colores normales), 1.0 = ya se fue el
## último cliente (colores "de noche" al 100%). Anima suavemente hacia
## el color nuevo en vez de saltar de golpe.
func _actualizar_oscurecido(progreso: float) -> void:
	progreso = clamp(progreso, 0.0, 1.0)

	var tween := create_tween()
	tween.set_parallel(true)

	for portrait in slot_portraits:
		if portrait:
			tween.tween_property(portrait, "modulate", COLOR_DIA.lerp(COLOR_NOCHE_PERSONAJES, progreso), DURACION_TRANSICION_TINTE)

	if fondo:
		tween.tween_property(fondo, "modulate", COLOR_DIA.lerp(COLOR_NOCHE_FONDO, progreso), DURACION_TRANSICION_TINTE)

	if mesa:
		tween.tween_property(mesa, "modulate", COLOR_DIA.lerp(COLOR_NOCHE_MESA, progreso), DURACION_TRANSICION_TINTE)


## Qué tan avanzado va el día (0.0 a 1.0), calculado con cuántos de los
## clientes de HOY ya se resolvieron (fueron atendidos o se cansaron de
## esperar). No depende de un reloj/tiempo real: avanza por clientes, así
## que funciona igual sin importar cuánto tarde cada uno.
func _progreso_del_dia() -> float:
	if total_clientes_dia <= 0:
		return 0.0
	return clamp(float(clientes_resueltos) / float(total_clientes_dia), 0.0, 1.0)


## "Amanece": anima los 3 grupos de vuelta a colores de día normales, y
## SE ESPERA (await) a que termine. A diferencia de _actualizar_oscurecido()
## (que se dispara y sigue, sin bloquear nada, mientras el día transcurre),
## aquí sí queremos bloquear: ni el indicador de "Día X" ni los clientes
## del día siguiente deben aparecer hasta que la pantalla ya se vea
## completamente de día otra vez. Se usa desde _fin_del_dia().
func _amanecer() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	for portrait in slot_portraits:
		if portrait:
			tween.tween_property(portrait, "modulate", COLOR_DIA, DURACION_AMANECER)
	if fondo:
		tween.tween_property(fondo, "modulate", COLOR_DIA, DURACION_AMANECER)
	if mesa:
		tween.tween_property(mesa, "modulate", COLOR_DIA, DURACION_AMANECER)

	await tween.finished


func _ready() -> void:
	if vaso == null:
		push_error("Main.gd: no se encontró Mesa/Vaso. Revisa Main.tscn — el juego no puede funcionar sin él.")
		return
	for i in range(NUM_SLOTS):
		if slot_nodes[i] == null:
			push_error("Main.gd: no se encontró ClienteSlot%d. Revisa Main.tscn." % i)
			return

	GameManager.money_changed.connect(_on_money_changed)
	GameManager.game_over.connect(_on_game_over)

	vaso.ingrediente_soltado.connect(_on_ingrediente_soltado)
	vaso.ingrediente_rechazado.connect(_on_ingrediente_rechazado)
	if reiniciar_btn:
		reiniciar_btn.pressed.connect(_on_reiniciar_btn_pressed)

	for i in range(NUM_SLOTS):
		slot_nodes[i].gui_input.connect(_on_slot_gui_input.bind(i))
		slot_nodes[i].vaso_recibido.connect(_on_vaso_recibido)
		_actualizar_slot_ui(i)

	_actualizar_info_bar()

	# El día 1 no arranca de inmediato: primero el tutorial (si existe)
	# explica cómo se preparan las bebidas (ver TutorialOverlay.gd).
	# jornada_activa sigue en false mientras tanto, así que _process() no
	# hace avanzar ninguna paciencia hasta que el tutorial termine.
	# Si ya no tienes el nodo del tutorial en la escena, el juego arranca
	# directo en vez de quedarse esperando una señal que nunca llegaría.
	if tutorial:
		tutorial.tutorial_terminado.connect(_iniciar_dia)
	else:
		_iniciar_dia()


func _process(delta: float) -> void:
	if not jornada_activa:
		return
	for i in range(NUM_SLOTS):
		if slots[i] == null or resolviendo_slot[i]:
			continue
		slots[i]["paciencia_actual"] -= delta
		_actualizar_barra_paciencia(i)
		if slots[i]["paciencia_actual"] <= 0.0:
			_resolver_slot(i, false)


# ---------------------------------------------------------------------
# FLUJO DEL DÍA
# ---------------------------------------------------------------------

func _iniciar_dia() -> void:
	jornada_activa = true
	cola_del_dia = CustomerSpawner.generar_dia(GameManager.clientes_por_dia)
	total_clientes_dia = cola_del_dia.size()
	clientes_resueltos = 0
	slots = [null, null, null]
	resolviendo_slot = [false, false, false]
	calidades_del_dia.clear()
	if result_label:
		result_label.text = ""
	_actualizar_oscurecido(0.0) # arranca el día con colores normales
	_construir_timeline()
	for i in range(NUM_SLOTS):
		_actualizar_slot_ui(i)
	_rellenar_slots()


func _fin_del_dia() -> void:
	jornada_activa = false
	for i in range(NUM_SLOTS):
		slots[i] = null
		_actualizar_slot_ui(i)

	var promedio := 0.5
	if calidades_del_dia.size() > 0:
		var suma := 0.0
		for c in calidades_del_dia:
			suma += c
		promedio = suma / calidades_del_dia.size()

	var mensaje := "Fin del día %d.\n" % GameManager.current_day
	if GameManager.money >= GameManager.DAILY_EXTORTION:
		GameManager.pagar_extorsion()
		mensaje += "Pagaste el derecho de piso ($%d).\n" % GameManager.DAILY_EXTORTION
	else:
		GameManager.no_pagar_extorsion()
		mensaje += "No te alcanzó para pagar el derecho de piso...\n"

	GameManager.ajustar_clientes_por_dia(promedio)
	mensaje += "Calidad promedio del día: %d%%\n" % int(round(promedio * 100))
	mensaje += "Mañana esperas %d clientes." % GameManager.clientes_por_dia

	# OJO: esta línea faltaba en la versión que subiste — por eso el
	# resumen del día nunca se veía en pantalla. La regresé.
	if result_label:
		result_label.text = mensaje

	var resultado := GameManager.avanzar_dia()
	if resultado == "":
		await get_tree().create_timer(3.0).timeout
		if result_label:
			result_label.text = ""
		# Primero amanece del todo (colores normales)...
		await _amanecer()
		# ...y SOLO ya que amaneció se actualiza el indicador de "Día X"
		# de arriba y empiezan a llegar los clientes del día siguiente.
		_actualizar_info_bar()
		_iniciar_dia()
	# Si resultado != "", GameManager ya emitió game_over.


# ---------------------------------------------------------------------
# SLOTS: llenar (aleatorio), resolver, recibir el vaso arrastrado
# ---------------------------------------------------------------------

func _rellenar_slots() -> void:
	var vacios: Array = []
	for i in range(NUM_SLOTS):
		if slots[i] == null:
			vacios.append(i)

	if vacios.is_empty():
		return

	if cola_del_dia.is_empty():
		if _todos_los_slots_vacios():
			_fin_del_dia()
		return

	# Aleatorizamos EN CUÁL de los puestos vacíos entra el primero, para
	# que los clientes no siempre aparezcan del mismo lado. Si de todas
	# formas los ves siempre en el centro, revisa en Main.tscn que
	# ClienteSlot0 / ClienteSlot1 / ClienteSlot2 tengan offsets DISTINTOS
	# (izquierda / centro / derecha) — este shuffle() elige el ÍNDICE al
	# azar, pero si los 3 nodos están en la misma posición en la escena,
	# siempre se va a VER igual sin importar cuál se llene.
	vacios.shuffle()

	var cuantos := _decidir_cuantos_llenar(vacios.size())
	for k in range(cuantos):
		var candidato := _tomar_siguiente_no_repetido()
		if candidato.is_empty():
			break
		_colocar_cliente(vacios[k], candidato)


func _todos_los_slots_vacios() -> bool:
	for s in slots:
		if s != null:
			return false
	return true


## Cuántos clientes nuevos aparecen de golpe cuando hay {max_vacios} huecos.
func _decidir_cuantos_llenar(max_vacios: int) -> int:
	if max_vacios <= 1:
		return max_vacios
	if randf() >= _probabilidad_simultaneos():
		return 1
	if max_vacios >= 3:
		var progreso := _progreso_dificultad()
		var prob_triple: float = clamp(progreso - 0.3, 0.0, 0.6)
		if randf() < prob_triple:
			return 3
	return 2


func _progreso_dificultad() -> float:
	var total_dias: int = max(GameManager.TOTAL_DAYS, 1)
	return clamp(float(GameManager.current_day - 1) / float(max(total_dias - 1, 1)), 0.0, 1.0)


func _probabilidad_simultaneos() -> float:
	return lerp(0.05, 0.8, _progreso_dificultad())


## Saca de la cola el primer cliente cuyo id NO esté ya en algún slot activo
## (para que nunca se repita el mismo personaje al mismo tiempo).
func _tomar_siguiente_no_repetido() -> Dictionary:
	var ids_activos: Array = []
	for s in slots:
		if s != null:
			ids_activos.append(s["cliente"].get("id", ""))
	for i in range(cola_del_dia.size()):
		var candidato: Dictionary = cola_del_dia[i]
		if not ids_activos.has(candidato.get("id", "")):
			cola_del_dia.remove_at(i)
			return candidato
	return {}


func _colocar_cliente(idx: int, cliente: Dictionary) -> void:
	var paciencia_max := _paciencia_para_cliente(cliente)
	slots[idx] = {
		"cliente": cliente,
		"paciencia_actual": paciencia_max,
		"paciencia_maxima": paciencia_max,
	}
	resolviendo_slot[idx] = false
	_actualizar_slot_ui(idx)


func _paciencia_para_cliente(cliente: Dictionary) -> float:
	var base: float = cliente.get("paciencia", 14.0)
	var rango := PACIENCIA_MULTIPLICADOR_DIA1 - PACIENCIA_MULTIPLICADOR_MINIMO
	var multiplicador: float = PACIENCIA_MULTIPLICADOR_DIA1 - _progreso_dificultad() * rango
	return base * multiplicador


## Clic/toque en un puesto: si ese cliente NO quiere michelada (solo vino a
## hablar), se le atiende de inmediato — no hace falta arrastrarle nada.
## Si SÍ quiere michelada, tocar su puesto no hace nada por sí solo: hay
## que arrastrarle el vaso (ver _on_vaso_recibido).
func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not jornada_activa:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if slots[idx] == null or resolviendo_slot[idx]:
		return
	var cliente: Dictionary = slots[idx]["cliente"]
	if not cliente.get("quiere_michelada", true):
		_resolver_slot(idx, false)


## Soltaron el vaso (arrastrado desde VasoMichelada.gd) encima del puesto
## {idx}: si hay alguien ahí y quiere comprar, se le sirve lo que trae el
## vaso ahora mismo.
func _on_vaso_recibido(idx: int) -> void:
	if not jornada_activa:
		return
	if slots[idx] == null or resolviendo_slot[idx]:
		return
	if not vaso.existe:
		return
	var cliente: Dictionary = slots[idx]["cliente"]
	if not cliente.get("quiere_michelada", true):
		return
	_resolver_slot(idx, true)


func _resolver_slot(idx: int, hubo_tiempo: bool) -> void:
	if slots[idx] == null or resolviendo_slot[idx]:
		return
	resolviendo_slot[idx] = true

	var cliente: Dictionary = slots[idx]["cliente"]
	var mensaje := ""

	if not cliente.get("quiere_michelada", true):
		mensaje = "%s se despide y sigue su camino." % cliente.get("nombre", "El cliente")
	elif hubo_tiempo:
		var receta: Dictionary = cliente.get("receta", {})
		var calidad := _calcular_calidad(receta)
		var multiplicador := _multiplicador_por_calidad(calidad)
		var precio_base: int = cliente.get("precio_base", 0)
		var precio_final := int(round(precio_base * multiplicador))

		# El dilema ético solo se activa si el cliente ES menor de edad Y la
		# bebida que le serviste SÍ lleva alcohol (cerveza o vodka).
		var es_menor: bool = cliente.get("es_menor", false)
		var tiene_alcohol := false
		if vaso != null:
			tiene_alcohol = vaso.tiene_alcohol()
		var es_venta_de_alcohol_a_menor: bool = es_menor and tiene_alcohol

		GameManager.registrar_venta(cliente.get("id", ""), precio_final, es_venta_de_alcohol_a_menor)
		calidades_del_dia.append(calidad)
		mensaje = _texto_resultado(calidad, precio_final)
		_vaciar_vaso() # el vaso ya se sirvió: desaparece del centro
	else:
		calidades_del_dia.append(0.0)
		mensaje = "%s se cansó de esperar y se fue sin comprar." % cliente.get("nombre", "El cliente")

	if slot_dialogos[idx]:
		slot_dialogos[idx].text = mensaje
	clientes_resueltos += 1
	_actualizar_timeline()
	_actualizar_oscurecido(_progreso_del_dia())

	await get_tree().create_timer(1.3).timeout

	slots[idx] = null
	resolviendo_slot[idx] = false
	_actualizar_slot_ui(idx)
	_rellenar_slots()


# ---------------------------------------------------------------------
# LÍNEA DE TIEMPO DEL DÍA (cuadritos de progreso)
# ---------------------------------------------------------------------

func _construir_timeline() -> void:
	if day_timeline == null:
		return
	for child in day_timeline.get_children():
		child.queue_free()
	for i in range(total_clientes_dia):
		var segmento := ColorRect.new()
		segmento.custom_minimum_size = Vector2(30, 20)
		segmento.color = Color(0.6, 0.6, 0.6)
		day_timeline.add_child(segmento)


func _actualizar_timeline() -> void:
	if day_timeline == null:
		return
	var segmentos := day_timeline.get_children()
	for i in range(segmentos.size()):
		var segmento: ColorRect = segmentos[i]
		segmento.color = Color(0.3, 0.8, 0.3) if i < clientes_resueltos else Color(0.6, 0.6, 0.6)


# ---------------------------------------------------------------------
# UI DE CADA SLOT DE CLIENTE
# ---------------------------------------------------------------------

func _actualizar_slot_ui(i: int) -> void:
	var slot = slots[i]
	if slot == null:
		if slot_portraits[i]:
			slot_portraits[i].texture = null
		if slot_nombres[i]:
			slot_nombres[i].text = ""
		if slot_barras[i]:
			slot_barras[i].max_value = 1.0
			slot_barras[i].value = 0.0
		slot_nodes[i].modulate = Color(1, 1, 1, 0.35)
		_ocultar_pedido_burbuja(i)
		return

	var cliente: Dictionary = slot["cliente"]
	if slot_nombres[i]:
		slot_nombres[i].text = cliente.get("nombre", "Cliente")

	if slot_portraits[i]:
		var ruta_retrato: String = cliente.get("retrato", "")
		if ruta_retrato != "" and ResourceLoader.exists(ruta_retrato):
			slot_portraits[i].texture = load(ruta_retrato)
		else:
			slot_portraits[i].texture = load("res://assets/sprites/placeholder.png")

	if slot_dialogos[i]:
		if cliente.get("especial", false) and cliente.get("dialogo", []).size() > 0:
			var lineas: Array = cliente["dialogo"]
			slot_dialogos[i].text = lineas[randi() % lineas.size()]
		elif cliente.get("quiere_michelada", true):
			slot_dialogos[i].text = "\"%s\"" % cliente.get("pedido_texto", "Quiere una bebida.")
		else:
			slot_dialogos[i].text = "Solo vino a platicar (toca aquí para atenderlo/a)."

	if cliente.get("quiere_michelada", true) and cliente.get("receta", {}).size() > 0:
		_mostrar_pedido_burbuja(i, cliente["receta"])
	else:
		_ocultar_pedido_burbuja(i)

	if slot_barras[i]:
		slot_barras[i].max_value = slot["paciencia_maxima"]
		slot_barras[i].value = slot["paciencia_actual"]

	# Este modulate SOLO cambia la opacidad (el canal alfa) para marcar un
	# puesto vacío vs. ocupado — nunca toca "scale", así que no debería
	# agrandar a nadie. Si en tu escena ves que el puesto de la izquierda
	# crece, busca en Main.tscn (o en cualquier script) algo que le esté
	# poniendo un valor a "scale" o a "custom_minimum_size" de
	# ClienteSlot0 o de su Portrait — este script no lo hace.
	slot_nodes[i].modulate = Color(1, 1, 1, 1)
	_actualizar_emoji_slot(i)


func _actualizar_barra_paciencia(i: int) -> void:
	var slot = slots[i]
	if slot == null or slot_barras[i] == null:
		return
	slot_barras[i].value = max(slot["paciencia_actual"], 0.0)
	_actualizar_emoji_slot(i)


func _actualizar_emoji_slot(i: int) -> void:
	var slot = slots[i]
	if slot == null or slot["paciencia_maxima"] <= 0.0 or slot_emojis[i] == null:
		return
	var ratio: float = slot["paciencia_actual"] / slot["paciencia_maxima"]
	if ratio > 0.66:
		slot_emojis[i].texture = CARA_FELIZ
	elif ratio > 0.33:
		slot_emojis[i].texture = CARA_NEUTRAL
	else:
		slot_emojis[i].texture = CARA_ENOJADA


## Muestra el globo de cómic con una miniatura de la bebida que ese
## cliente quiere (misma idea que las capas del vaso real: se prende la
## capa VidrioBase + una capa por cada ingrediente de su receta).
func _mostrar_pedido_burbuja(i: int, receta: Dictionary) -> void:
	if slot_burbujas[i] == null or slot_burbuja_vasos[i] == null:
		return
	var mini_vaso: Node = slot_burbuja_vasos[i]
	var vidrio: Node = mini_vaso.get_node_or_null("VidrioBase")
	if vidrio:
		vidrio.visible = true
	for id in CAPAS_BURBUJA:
		var nombre_nodo: String = CAPAS_BURBUJA[id]
		var capa: Node = mini_vaso.get_node_or_null(nombre_nodo)
		if capa:
			capa.visible = receta.get(id, false)
	slot_burbujas[i].visible = true


func _ocultar_pedido_burbuja(i: int) -> void:
	if slot_burbujas[i]:
		slot_burbujas[i].visible = false


# ---------------------------------------------------------------------
# MESA / VASO (arrastrar y soltar)
# ---------------------------------------------------------------------
# El contenido del vaso YA NO se guarda aquí: VasoMichelada.gd es la única
# fuente de verdad. Aquí solo reaccionamos a sus señales para actualizar
# la etiqueta de texto bajo el vaso.

func _on_ingrediente_soltado(_ingrediente_id: String) -> void:
	_actualizar_vaso_label()


func _on_ingrediente_rechazado(ingrediente_id: String, motivo: String) -> void:
	if vaso_label == null:
		return
	var etiqueta: String = ETIQUETAS.get(ingrediente_id, "el vaso" if ingrediente_id == "vaso" else ingrediente_id)
	var explicacion: String = MOTIVOS_TEXTO.get(motivo, "No se puede agregar ahora.")
	_mostrando_rechazo = true
	vaso_label.text = "❌ %s" % explicacion

	await get_tree().create_timer(1.4).timeout
	_mostrando_rechazo = false
	_actualizar_vaso_label()


## Este SÍ lleva el sonido de clic, porque es lo que corre cuando el
## JUGADOR presiona el botón "Vaciar vaso" con el mouse. _vaciar_vaso()
## (sin el "_on_..._pressed") es la lógica pura de reiniciar el vaso, y
## también la usa _resolver_slot() para limpiar el vaso después de
## servir a un cliente — ESA llamada no debe sonar a clic de botón,
## porque ahí nadie le dio clic a nada.
func _on_reiniciar_btn_pressed() -> void:
	SFX.play_boton()
	_vaciar_vaso()


func _vaciar_vaso() -> void:
	vaso.reset()
	_mostrando_rechazo = false
	_actualizar_vaso_label()


func _actualizar_vaso_label() -> void:
	if vaso_label == null or _mostrando_rechazo:
		return

	if not vaso.existe:
		vaso_label.text = "No hay vaso.\nArrastra uno aquí para empezar."
		return

	var presentes: Array = vaso.obtener_ingredientes()
	if presentes.is_empty():
		vaso_label.text = "Vaso vacío.\nArrastra ingredientes aquí."
		return

	var nombres: Array = []
	for id in ORDEN_CANONICO:
		if presentes.has(id):
			nombres.append(ETIQUETAS.get(id, id))
	vaso_label.text = ", ".join(nombres)


# ---------------------------------------------------------------------
# CÁLCULO DE CALIDAD Y PRECIO
# ---------------------------------------------------------------------

func _calcular_calidad(receta: Dictionary) -> float:
	if receta.is_empty():
		return 1.0

	var presentes: Array = vaso.obtener_ingredientes()
	var aciertos := 0

	for id in ORDEN_CANONICO:
		var lo_quiere: bool = receta.get(id, false)
		var lo_tiene: bool = presentes.has(id)
		if lo_quiere == lo_tiene:
			aciertos += 1

	return float(aciertos) / float(ORDEN_CANONICO.size())


func _multiplicador_por_calidad(calidad: float) -> float:
	if calidad >= 0.85:
		return 1.3
	elif calidad >= 0.6:
		return 1.0
	elif calidad >= 0.35:
		return 0.7
	else:
		return 0.4


func _texto_resultado(calidad: float, precio: int) -> String:
	if calidad >= 0.85:
		return "¡Excelente! Le encantó. Paga $%d." % precio
	elif calidad >= 0.6:
		return "Buena bebida. Paga $%d." % precio
	elif calidad >= 0.35:
		return "Meh... no era lo que pidió. Paga solo $%d." % precio
	else:
		return "No le gustó nada. A regañadientes paga $%d." % precio


# ---------------------------------------------------------------------
# UI GENERAL / SEÑALES DE GameManager
# ---------------------------------------------------------------------

func _on_money_changed(new_amount: int) -> void:
	if money_label:
		money_label.text = "$%d" % new_amount


func _actualizar_info_bar() -> void:
	if day_label:
		day_label.text = "%d / %d" % [GameManager.current_day, GameManager.TOTAL_DAYS]
	if money_label:
		money_label.text = "$%d" % GameManager.money


func _on_game_over(_ending_id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/Ending.tscn")
