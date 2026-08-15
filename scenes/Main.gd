extends Control
## Main.gd
## -------
## Escena única del juego, 100% automática:
##  - Los clientes aparecen uno tras otro sin botones de "siguiente".
##  - Cada cliente tiene una barra de paciencia (+ un emoji) que se agota
##    con el tiempo. Si llegas a servir antes de que se agote, hay venta;
##    si se agota, el cliente se va sin comprar. No hay botones de
##    "vender" / "no vender": la paciencia decide.
##  - Los ingredientes están siempre visibles en la mesa de abajo, listos
##    para arrastrarse al vaso.
##  - La calidad promedio del día sube o baja cuántos clientes llegan
##    al día siguiente (reputación).

@onready var day_label: Label = $InfoBar/DayLabel
@onready var money_label: Label = $InfoBar/MoneyLabel
@onready var day_timeline: HBoxContainer = $DayTimeline

@onready var emoji_icon: TextureRect = $EmojiIcon
@onready var patience_bar: ProgressBar = $PatienceBar
@onready var customer_portrait: TextureRect = $CustomerPortrait
@onready var customer_name: Label = $CustomerName
@onready var dialogue_label: Label = $DialogueLabel

@onready var vaso: Panel = $Mesa/Vaso
@onready var vaso_label: Label = $Mesa/Vaso/VasoLabel
@onready var reiniciar_btn: Button = $Mesa/ReiniciarBtn
@onready var servir_btn: Button = $Mesa/ServirBtn
@onready var result_label: Label = $Mesa/ResultLabel

const CARA_FELIZ := preload("res://assets/sprites/faces/happy.png")
const CARA_NEUTRAL := preload("res://assets/sprites/faces/neutral.png")
const CARA_ENOJADA := preload("res://assets/sprites/faces/angry.png")

var fila_hoy: Array = []
var indice_actual := 0
var cliente_actual: Dictionary = {}

var paciencia_actual := 0.0
var paciencia_maxima := 0.0
var resolviendo := false
var jornada_activa := false # false mientras se muestra el resumen del día

# Contenido actual del vaso (lo que llevas arrastrado hasta ahora).
var contenido := {"clamato": 0, "limon": 0, "chile": 0, "sal": 0}

# Calidad de cada venta del día (0.0 si el cliente se fue sin comprar).
var calidades_del_dia: Array = []


func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.game_over.connect(_on_game_over)

	vaso.ingrediente_soltado.connect(_on_ingrediente_soltado)
	reiniciar_btn.pressed.connect(_vaciar_vaso)
	servir_btn.pressed.connect(_on_servir_pressed)

	_actualizar_info_bar()
	_iniciar_dia()


func _process(delta: float) -> void:
	if not jornada_activa or resolviendo:
		return
	if indice_actual >= fila_hoy.size():
		return

	paciencia_actual -= delta
	patience_bar.value = max(paciencia_actual, 0.0)

	var ratio := 0.0
	if paciencia_maxima > 0:
		ratio = paciencia_actual / paciencia_maxima
	_actualizar_emoji(ratio)

	if paciencia_actual <= 0.0:
		_resolver_cliente(false) # se le acabó la paciencia


# ---------------------------------------------------------------------
# FLUJO DEL DÍA
# ---------------------------------------------------------------------

func _iniciar_dia() -> void:
	jornada_activa = true
	fila_hoy = CustomerSpawner.generar_dia(GameManager.clientes_por_dia)
	indice_actual = 0
	calidades_del_dia.clear()
	_construir_timeline()
	_mostrar_cliente_actual()


func _mostrar_cliente_actual() -> void:
	_actualizar_timeline()

	if indice_actual >= fila_hoy.size():
		_fin_del_dia()
		return

	cliente_actual = fila_hoy[indice_actual]
	resolviendo = false
	result_label.text = ""

	customer_name.text = cliente_actual["nombre"]

	var ruta_retrato: String = cliente_actual.get("retrato", "")
	if ruta_retrato != "" and ResourceLoader.exists(ruta_retrato):
		customer_portrait.texture = load(ruta_retrato)
	else:
		customer_portrait.texture = load("res://assets/sprites/placeholder.png")

	if cliente_actual["especial"] and cliente_actual["dialogo"].size() > 0:
		dialogue_label.text = cliente_actual["dialogo"][randi() % cliente_actual["dialogo"].size()]
	elif cliente_actual.get("quiere_michelada", true):
		dialogue_label.text = "\"%s\"" % cliente_actual.get("pedido_texto", "Quiere una michelada.")
	else:
		dialogue_label.text = "Solo vino a platicar un rato."

	_vaciar_vaso()

	paciencia_maxima = cliente_actual.get("paciencia", 14.0)
	paciencia_actual = paciencia_maxima
	patience_bar.max_value = paciencia_maxima
	patience_bar.value = paciencia_maxima
	_actualizar_emoji(1.0)

	servir_btn.disabled = not cliente_actual.get("quiere_michelada", true)


func _resolver_cliente(hubo_tiempo: bool) -> void:
	if resolviendo:
		return
	resolviendo = true
	servir_btn.disabled = true

	if not cliente_actual.get("quiere_michelada", true):
		result_label.text = "%s se despide y sigue su camino." % cliente_actual["nombre"]
	elif hubo_tiempo:
		var receta: Dictionary = cliente_actual.get("receta", {})
		var calidad := _calcular_calidad(receta)
		var multiplicador := _multiplicador_por_calidad(calidad)
		var precio_final := int(round(cliente_actual["precio_base"] * multiplicador))

		GameManager.registrar_venta(cliente_actual["id"], precio_final, cliente_actual["es_menor"])
		calidades_del_dia.append(calidad)
		result_label.text = _texto_resultado(calidad, precio_final)
	else:
		calidades_del_dia.append(0.0)
		result_label.text = "%s se cansó de esperar y se fue sin comprar." % cliente_actual["nombre"]

	await get_tree().create_timer(1.3).timeout
	indice_actual += 1
	_mostrar_cliente_actual()


func _fin_del_dia() -> void:
	jornada_activa = false
	customer_name.text = "Fin del día"
	dialogue_label.text = ""
	servir_btn.disabled = true
	patience_bar.value = 0
	customer_portrait.texture = load("res://assets/sprites/placeholder.png")

	var promedio := 0.5
	if calidades_del_dia.size() > 0:
		var suma := 0.0
		for c in calidades_del_dia:
			suma += c
		promedio = suma / calidades_del_dia.size()

	var mensaje := ""
	if GameManager.money >= GameManager.DAILY_EXTORTION:
		GameManager.pagar_extorsion()
		mensaje = "Pagaste el derecho de piso ($%d)." % GameManager.DAILY_EXTORTION
	else:
		GameManager.no_pagar_extorsion()
		mensaje = "No te alcanzó para pagar el derecho de piso..."

	GameManager.ajustar_clientes_por_dia(promedio)
	mensaje += "\nCalidad promedio del día: %d%%" % int(round(promedio * 100))
	mensaje += "\nMañana esperas %d clientes." % GameManager.clientes_por_dia

	dialogue_label.text = mensaje

	var resultado := GameManager.avanzar_dia()
	if resultado == "":
		_actualizar_info_bar()
		await get_tree().create_timer(3.0).timeout
		_iniciar_dia()
	# Si resultado != "", GameManager ya emitió game_over.


# ---------------------------------------------------------------------
# LÍNEA DE TIEMPO DEL DÍA (cuadritos de progreso)
# ---------------------------------------------------------------------

func _construir_timeline() -> void:
	for child in day_timeline.get_children():
		child.queue_free()

	for i in range(fila_hoy.size()):
		var segmento := ColorRect.new()
		segmento.custom_minimum_size = Vector2(30, 20)
		segmento.color = Color(0.6, 0.6, 0.6)
		day_timeline.add_child(segmento)


func _actualizar_timeline() -> void:
	var segmentos := day_timeline.get_children()
	for i in range(segmentos.size()):
		var segmento: ColorRect = segmentos[i]
		if i < indice_actual:
			segmento.color = Color(0.3, 0.8, 0.3)
		elif i == indice_actual:
			segmento.color = Color(0.9, 0.8, 0.2)
		else:
			segmento.color = Color(0.6, 0.6, 0.6)


# ---------------------------------------------------------------------
# PACIENCIA / EMOJI
# ---------------------------------------------------------------------

func _actualizar_emoji(ratio: float) -> void:
	if ratio > 0.66:
		emoji_icon.texture = CARA_FELIZ
	elif ratio > 0.33:
		emoji_icon.texture = CARA_NEUTRAL
	else:
		emoji_icon.texture = CARA_ENOJADA


# ---------------------------------------------------------------------
# MESA / VASO (arrastrar y soltar)
# ---------------------------------------------------------------------

func _on_ingrediente_soltado(ingrediente_id: String) -> void:
	if resolviendo or not jornada_activa:
		return

	if ingrediente_id == "sal":
		contenido["sal"] = 1
	elif contenido.has(ingrediente_id):
		contenido[ingrediente_id] = min(contenido[ingrediente_id] + 1, 10)

	_actualizar_vaso_label()


func _vaciar_vaso() -> void:
	contenido = {"clamato": 0, "limon": 0, "chile": 0, "sal": 0}
	_actualizar_vaso_label()


func _actualizar_vaso_label() -> void:
	var sal_texto := "sí" if contenido["sal"] >= 1 else "no"
	vaso_label.text = "Clamato: %d\nLimón: %d\nChile: %d\nSal al borde: %s" % [
		contenido["clamato"], contenido["limon"], contenido["chile"], sal_texto,
	]


func _on_servir_pressed() -> void:
	if resolviendo or not jornada_activa:
		return
	_resolver_cliente(true)


# ---------------------------------------------------------------------
# CÁLCULO DE CALIDAD Y PRECIO
# ---------------------------------------------------------------------

func _calcular_calidad(receta: Dictionary) -> float:
	if receta.is_empty():
		return 1.0

	var errores: Array = []
	errores.append(abs(receta.get("clamato", 5) - contenido["clamato"]) / 10.0)
	errores.append(abs(receta.get("limon", 5) - contenido["limon"]) / 10.0)
	errores.append(abs(receta.get("chile", 5) - contenido["chile"]) / 10.0)

	if receta.has("sal_borde"):
		var sal_correcta: bool = receta["sal_borde"] == (contenido["sal"] >= 1)
		errores.append(0.0 if sal_correcta else 0.3)

	var suma := 0.0
	for e in errores:
		suma += e

	return clamp(1.0 - (suma / errores.size()), 0.0, 1.0)


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
		return "Buena michelada. Paga $%d." % precio
	elif calidad >= 0.35:
		return "Meh... no era lo que pidió. Paga solo $%d." % precio
	else:
		return "No le gustó nada. A regañadientes paga $%d." % precio


# ---------------------------------------------------------------------
# UI GENERAL / SEÑALES DE GameManager
# ---------------------------------------------------------------------

func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Dinero: $%d" % new_amount


func _actualizar_info_bar() -> void:
	day_label.text = "Día %d / %d" % [GameManager.current_day, GameManager.TOTAL_DAYS]
	money_label.text = "Dinero: $%d" % GameManager.money


func _on_game_over(_ending_id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/Ending.tscn")
