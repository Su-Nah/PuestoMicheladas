extends Panel
## MicheladaMixer.gd
## ------------------
## Minijuego de preparar la michelada, versión ARRASTRAR Y SOLTAR.
## El jugador arrastra íconos de ingredientes hacia el vaso; cada
## arrastre suma una unidad de ese ingrediente (máximo 10; la sal es
## simplemente "sí" o "no"). Al presionar "Servir" se compara el vaso
## contra la receta ideal del cliente para calcular calidad y precio.

signal michelada_lista(precio_final: int, calidad: float)

@onready var pedido_label: Label = $PedidoLabel
@onready var vaso: Panel = $Vaso
@onready var vaso_label: Label = $Vaso/VasoLabel
@onready var reiniciar_btn: Button = $ReiniciarBtn
@onready var result_label: Label = $ResultLabel
@onready var servir_btn: Button = $ServirBtn

var cliente: Dictionary = {}
var ya_sirvio := false

# Lo que lleva el vaso hasta ahora.
var contenido := {"clamato": 0, "limon": 0, "chile": 0, "sal": 0}


func _ready() -> void:
	vaso.ingrediente_soltado.connect(_on_ingrediente_soltado)
	reiniciar_btn.pressed.connect(_vaciar_vaso)
	servir_btn.pressed.connect(_on_servir_pressed)


## Se llama desde Main.gd justo después de instanciar la escena.
func setup(p_cliente: Dictionary) -> void:
	cliente = p_cliente
	pedido_label.text = "Pedido de %s:\n\"%s\"" % [
		cliente["nombre"],
		cliente.get("pedido_texto", "Una michelada normal."),
	]

	_vaciar_vaso()
	result_label.visible = false
	servir_btn.disabled = false
	ya_sirvio = false


func _on_ingrediente_soltado(ingrediente_id: String) -> void:
	if ya_sirvio:
		return

	if ingrediente_id == "sal":
		contenido["sal"] = 1  # la sal es todo o nada (sí lleva / no lleva)
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

	await get_tree().create_timer(1.2).timeout
	michelada_lista.emit(precio_final, calidad)


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
