extends Control
## InicioMenu.gd
## -------------
## Menú de inicio del juego: Jugar / Créditos / Opciones.
##
## DÓNDE PONER ESTE ARCHIVO Y LA ESCENA
## -------------------------------------
## Guarda InicioMenu.gd en res://scenes/InicioMenu.gd (junto a Main.gd y
## Ending.gd) e InicioMenu.tscn en res://scenes/InicioMenu.tscn — el script
## de la escena ya apunta a esa ruta exacta.
##
## PARA QUE EL JUEGO ABRA AQUÍ EN VEZ DE EN Main.tscn
## -----------------------------------------------------
## En el editor: Project -> Project Settings -> pestaña "Application" ->
## "Run" -> "Main Scene" -> selecciona res://scenes/InicioMenu.tscn.
## Así, al darle Play (F5) o al exportar el juego, arranca en este menú.
##
## "Jugar" cambia a Main.tscn con change_scene_to_file(), exactamente
## igual que como Ending.gd vuelve a Main.tscn al reiniciar.
##
## OPCIONES: usa LOS MISMOS 3 buses de audio que ya creaste para el menú
## de pausa ("Music", "Ambiente", "SFX" — panel inferior "Audio" del
## editor). Si esos buses no existen todavía, los sliders simplemente no
## tienen efecto (ver _ajustar_volumen_bus), sin romper nada.

@onready var jugar_btn: Button = $MenuPrincipal/VBoxContainer/JugarBtn
@onready var creditos_btn: Button = $MenuPrincipal/VBoxContainer/CreditosBtn
@onready var opciones_btn: Button = $MenuPrincipal/VBoxContainer/OpcionesBtn

@onready var creditos_panel: Control = $CreditosPanel
@onready var creditos_volver_btn: Button = $CreditosPanel/Panel/VBoxContainer/VolverBtn

@onready var opciones_panel: Control = $OpcionesPanel
@onready var opciones_volver_btn: Button = $OpcionesPanel/Panel/VBoxContainer/VolverBtn
@onready var musica_slider: HSlider = $OpcionesPanel/Panel/VBoxContainer/MusicaRow/MusicaSlider
@onready var ruido_slider: HSlider = $OpcionesPanel/Panel/VBoxContainer/RuidoRow/RuidoSlider
@onready var sonidos_slider: HSlider = $OpcionesPanel/Panel/VBoxContainer/SonidosRow/SonidosSlider


func _ready() -> void:
	jugar_btn.pressed.connect(_on_jugar_pressed)
	creditos_btn.pressed.connect(_on_creditos_pressed)
	opciones_btn.pressed.connect(_on_opciones_pressed)
	creditos_volver_btn.pressed.connect(_on_volver_pressed)
	opciones_volver_btn.pressed.connect(_on_volver_pressed)

	musica_slider.value_changed.connect(_on_musica_slider_changed)
	ruido_slider.value_changed.connect(_on_ruido_slider_changed)
	sonidos_slider.value_changed.connect(_on_sonidos_slider_changed)

	# Los sliders arrancan reflejando el volumen REAL de cada bus (por si
	# el jugador ya los había bajado desde el menú de pausa en una
	# partida anterior), en vez de arrancar siempre marcando 100%.
	musica_slider.value = _volumen_actual_bus("Music")
	ruido_slider.value = _volumen_actual_bus("Ambiente")
	sonidos_slider.value = _volumen_actual_bus("SFX")


func _on_jugar_pressed() -> void:
	SFX.play_boton()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_creditos_pressed() -> void:
	SFX.play_boton()
	creditos_panel.visible = true


func _on_opciones_pressed() -> void:
	SFX.play_boton()
	opciones_panel.visible = true


## Un solo botón "Volver" les sirve a los dos paneles: como solo uno de
## los dos puede estar abierto a la vez, cerrar ambos de un jalón no
## causa ningún problema y evita duplicar la función.
func _on_volver_pressed() -> void:
	SFX.play_boton()
	creditos_panel.visible = false
	opciones_panel.visible = false


# ---------------------------------------------------------------------
# VOLUMEN (idéntico al menú de pausa de Main.gd, para que ambos menús
# controlen exactamente los mismos buses de la misma forma).
# ---------------------------------------------------------------------

func _ajustar_volumen_bus(nombre_bus: String, valor: float) -> void:
	var idx := AudioServer.get_bus_index(nombre_bus)
	if idx == -1:
		return # el bus todavía no existe — créalo en el panel Audio (Add Bus)
	AudioServer.set_bus_mute(idx, valor <= 0.0)
	if valor > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(valor))


## Lee el volumen ACTUAL de un bus (0.0 a 1.0) para que el slider arranque
## en la posición correcta en vez de siempre en 100%.
func _volumen_actual_bus(nombre_bus: String) -> float:
	var idx := AudioServer.get_bus_index(nombre_bus)
	if idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clamp(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func _on_musica_slider_changed(valor: float) -> void:
	_ajustar_volumen_bus("Music", valor)


func _on_ruido_slider_changed(valor: float) -> void:
	_ajustar_volumen_bus("Ambiente", valor)


func _on_sonidos_slider_changed(valor: float) -> void:
	_ajustar_volumen_bus("SFX", valor)
