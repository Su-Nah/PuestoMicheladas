extends Panel
## MicheladaMixer.gd
## ------------------
## Minijuego de preparar la michelada. Se instancia dentro de Main.gd cada
## vez que el jugador aprieta "Vender michelada". El jugador ajusta 3
## sliders (clamato, limón, chile) y una casilla (sal en el borde) tratando
## de acertarle a lo que pidió el cliente. Al presionar "Servir" se calcula
## una "calidad" (0.0 a 1.0) comparando lo que preparaste contra la receta
## ideal del cliente, y esa calidad determina cuánto te paga.

signal michelada_lista(precio_final: int, calidad: float)

@onready var pedido_label: Label = $PedidoLabel
@onready var clamato_slider: HSlider = $ClamatoRow/ClamatoSlider
@onready var clamato_label: Label = $ClamatoRow/ClamatoLabel
@onready var limon_slider: HSlider = $LimonRow/LimonSlider
@onready var limon_label: Label = $LimonRow/LimonLabel
@onready var chile_slider: HSlider = $ChileRow/ChileSlider
@onready var chile_label: Label = $ChileRow/ChileLabel
@onready var sal_check: CheckBox = $SalBorde
@onready var result_label: Label = $ResultLabel
@onready var servir_btn: Button = $ServirBtn

var cliente: Dictionary = {}
var ya_sirvio := false


func _ready() -> void:
	clamato_slider.value_changed.connect(func(_v): _actualizar_labels())
	limon_slider.value_changed.connect(func(_v): _actualizar_labels())
	chile_slider.value_changed.connect(func(_v): _actualizar_labels())
	servir_btn.pressed.connect(_on_servir_pressed)


## Se llama desde Main.gd justo después de instanciar la escena.
func setup(p_cliente: Dictionary) -> void:
	cliente = p_cliente
	pedido_label.text = "Pedido de %s:\n\"%s\"" % [
		cliente["nombre"],
		cliente.get("pedido_texto", "Una michelada normal."),
	]

	# Reiniciamos los controles a un punto neutral cada vez que se abre.
	clamato_slider.value = 5
	limon_slider.value = 5
	chile_slider.value = 5
	sal_check.button_pressed = false

	_actualizar_labels()
	result_label.visible = false
	servir_btn.disabled = false
	ya_sirvio = false


func _actualizar_labels() -> void:
	clamato_label.text = "Clamato: %d" % int(clamato_slider.value)
	limon_label.text = "Limón: %d" % int(limon_slider.value)
	chile_label.text = "Chile/Tajín: %d" % int(chile_slider.value)


func _on_servir_pressed() -> void:
	if ya_sirvio:
		return
	ya_sirvio = true
	servir_btn.disabled = true

	var receta: Dictionary = cliente.get("receta", {})
	var calidad := _calcular_calidad(receta)
	var multiplicador := _multiplicador_por_calidad(calidad)
	var precio_final := int(round(cliente["precio_base"] * multiplicador))

	result_label.visible = true
	result_label.text = _texto_resultado(calidad, precio_final)

	# Pequeña pausa para que el jugador alcance a leer el resultado.
	await get_tree().create_timer(1.2).timeout
	michelada_lista.emit(precio_final, calidad)


func _calcular_calidad(receta: Dictionary) -> float:
	if receta.is_empty():
		return 1.0

	# Cada ingrediente aporta un "error" entre 0.0 (perfecto) y 1.0 (pésimo).
	var errores: Array = []
	errores.append(abs(receta.get("clamato", 5) - clamato_slider.value) / 10.0)
	errores.append(abs(receta.get("limon", 5) - limon_slider.value) / 10.0)
	errores.append(abs(receta.get("chile", 5) - chile_slider.value) / 10.0)

	if receta.has("sal_borde"):
		errores.append(0.0 if receta["sal_borde"] == sal_check.button_pressed else 0.3)

	var suma := 0.0
	for e in errores:
		suma += e
	var error_promedio: float = suma / errores.size()

	return clamp(1.0 - error_promedio, 0.0, 1.0)


func _multiplicador_por_calidad(calidad: float) -> float:
	if calidad >= 0.85:
		return 1.3   # Excelente: hasta propina extra
	elif calidad >= 0.6:
		return 1.0   # Buena: precio normal
	elif calidad >= 0.35:
		return 0.7   # Regular: paga menos, no le encantó
	else:
		return 0.4   # Mala: casi no paga


func _texto_resultado(calidad: float, precio: int) -> String:
	if calidad >= 0.85:
		return "¡Excelente! Le encantó. Paga $%d." % precio
	elif calidad >= 0.6:
		return "Buena michelada. Paga $%d." % precio
	elif calidad >= 0.35:
		return "Meh... no era lo que pidió. Paga solo $%d." % precio
	else:
		return "No le gustó nada. A regañadientes paga $%d." % precio
