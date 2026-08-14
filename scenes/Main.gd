extends Control
## Main.gd
## -------
## Controla el flujo de UN día de juego:
##   1) Genera la fila de clientes del día (CustomerSpawner).
##   2) Muestra cada cliente uno por uno.
##   3) El jugador decide: Vender / No vender.
##   4) Al terminar la fila, se cobra (o no) la extorsión y se avanza de día.
##   5) Si GameManager detecta un final, cambia de escena a Ending.tscn.

const CLIENTES_POR_DIA := 6

@onready var day_label: Label = $InfoBar/DayLabel
@onready var money_label: Label = $InfoBar/MoneyLabel
@onready var customer_name: Label = $CustomerPanel/CustomerName
@onready var dialogue_label: Label = $CustomerPanel/DialogueLabel
@onready var vender_btn: Button = $CustomerPanel/ButtonsBox/VenderBtn
@onready var rechazar_btn: Button = $CustomerPanel/ButtonsBox/RechazarBtn
@onready var siguiente_btn: Button = $SiguienteBtn

var fila_hoy: Array = []
var indice_actual := 0
var dia_terminado := false


func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.game_over.connect(_on_game_over)

	vender_btn.pressed.connect(_on_vender_pressed)
	rechazar_btn.pressed.connect(_on_rechazar_pressed)
	siguiente_btn.pressed.connect(_on_siguiente_pressed)

	_actualizar_info_bar()
	_iniciar_dia()


func _iniciar_dia() -> void:
	dia_terminado = false
	fila_hoy = CustomerSpawner.generar_dia(CLIENTES_POR_DIA)
	indice_actual = 0
	_mostrar_cliente_actual()


func _mostrar_cliente_actual() -> void:
	if indice_actual >= fila_hoy.size():
		_fin_del_dia()
		return

	var cliente: Dictionary = fila_hoy[indice_actual]
	customer_name.text = cliente["nombre"]

	if cliente["especial"] and cliente["dialogo"].size() > 0:
		dialogue_label.text = cliente["dialogo"][randi() % cliente["dialogo"].size()]
	elif cliente["es_menor"]:
		dialogue_label.text = "Se ve muy joven para tomar... ¿le vendes de todos modos?"
	else:
		dialogue_label.text = "Quiere una michelada."

	vender_btn.disabled = false
	rechazar_btn.disabled = false


func _on_vender_pressed() -> void:
	var cliente: Dictionary = fila_hoy[indice_actual]
	GameManager.registrar_venta(cliente["id"], cliente["precio_base"], cliente["es_menor"])

	if cliente["id"] == "policia_erick":
		GameManager.flags["ayudo_a_personaje_especial"] = true

	_bloquear_botones()


func _on_rechazar_pressed() -> void:
	_bloquear_botones()


func _bloquear_botones() -> void:
	vender_btn.disabled = true
	rechazar_btn.disabled = true


func _on_siguiente_pressed() -> void:
	if dia_terminado:
		return
	indice_actual += 1
	_mostrar_cliente_actual()


func _fin_del_dia() -> void:
	dia_terminado = true
	customer_name.text = "Fin del día"
	vender_btn.disabled = true
	rechazar_btn.disabled = true

	var mensaje := ""
	if GameManager.money >= GameManager.DAILY_EXTORTION:
		GameManager.pagar_extorsion()
		mensaje = "Pagaste el derecho de piso ($%d)." % GameManager.DAILY_EXTORTION
	else:
		GameManager.no_pagar_extorsion()
		mensaje = "No te alcanzó para pagar el derecho de piso..."

	dialogue_label.text = mensaje

	var resultado := GameManager.avanzar_dia()
	if resultado == "":
		_actualizar_info_bar()
		siguiente_btn.text = "Empezar día %d" % GameManager.current_day
		siguiente_btn.pressed.disconnect(_on_siguiente_pressed)
		siguiente_btn.pressed.connect(_iniciar_nuevo_dia_desde_boton)
	# Si resultado != "", GameManager ya emitió game_over y _on_game_over
	# se encarga de cambiar de escena.


func _iniciar_nuevo_dia_desde_boton() -> void:
	siguiente_btn.text = "Siguiente cliente"
	siguiente_btn.pressed.disconnect(_iniciar_nuevo_dia_desde_boton)
	siguiente_btn.pressed.connect(_on_siguiente_pressed)
	_iniciar_dia()


func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Dinero: $%d" % new_amount


func _actualizar_info_bar() -> void:
	day_label.text = "Día %d / %d" % [GameManager.current_day, GameManager.TOTAL_DAYS]
	money_label.text = "Dinero: $%d" % GameManager.money


func _on_game_over(_ending_id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/Ending.tscn")
