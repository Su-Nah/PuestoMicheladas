extends SceneTree
## Prueba e2e del DERRAME POR BAMBOLEO (BamboleoDrag + VasoMichelada +
## el shader del líquido). Corre desde la raíz del proyecto con:
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/test_derrame.gd
##
## (sale con código 0 si todo pasó, 1 si algo falló)
##
## Simula el arrastre REAL del vaso con eventos de mouse inyectados (press
## + motion por el mismo pipeline de gui que usa el juego) y recorre SEIS
## maniobras humanas medidas, en este orden:
##   1  viaje con calma          -> NO derrama (el camino seguro del juego)
##   1.5 servida PRECIPITADA     -> queda AL BORDE (barra > 0.5) o derrama:
##                                  ambas válidas por diseño ("la prisa es
##                                  el riesgo"); si derrama, re-sirve solo
##   1.6 flick rápido controlado -> gotea pero NO derrama
##   2a  sacudida de muñeca 8 Hz -> SÍ derrama (el péndulo del líquido casi
##                                  no la oye; el juez por AGITACIÓN sí)
##   2b  sacudida de brazadas 2 Hz (medida de video real) -> SÍ derrama
##   3   recuperación            -> se re-sirven cerveza y gomitas; el borde
##                                  (chamoy/escarchado/limón) sobrevivió
##
## CADA FASE IMPRIME SUS MÉTRICAS (chapoteo, AGITACIÓN en px/s², barra de
## derrame): si ajustas las constantes de BamboleoDrag.gd (UMBRAL_AGITACION,
## TASA_DERRAME...), corre esto y esos números te dicen exactamente dónde
## quedó la frontera entre "servida" y "derrame" — calibra con datos, no a
## ciegas.

var _nivel: Node = null
var _vaso = null
var _frame := 0
var _fase := "cargar"
var _fallos: Array = []
var _ultima_pos := Vector2.ZERO
var _centro_vaso := Vector2.ZERO
var _derrame_detectado := false
var _perdidos_reportados: Array = []
var _drag_confirmado := false
var _amp_max := 0.0
var _agit_max := 0.0
var _derrame_max := 0.0


## Muestrea el estado del preview activo: la envolvente del chapoteo
## (visual) y la AGITACION de la mano (el juez del derrame). Guarda el
## maximo de cada una por fase — para VER la separacion real entre
## maniobras al calibrar los umbrales.
func _muestrear_amplitud() -> void:
	var pv := _buscar_bamboleo(root)
	if pv == null:
		return
	var rel: float = pv._angulo_liquido - pv._inclinacion
	var vel_rel: float = pv._vel_liquido - pv._vel_angular
	var amp: float = sqrt(rel * rel + pow(vel_rel / pv._omega_liquido, 2.0))
	_amp_max = maxf(_amp_max, amp)
	_agit_max = maxf(_agit_max, pv._agitacion)
	_derrame_max = maxf(_derrame_max, pv._derrame)


func _reporte_fase() -> void:
	print("  (chapoteo max: %.2f | AGITACION max: %.0f px/s2 | BARRA max: %.2f)" % [_amp_max, _agit_max, _derrame_max])
	_amp_max = 0.0
	_agit_max = 0.0
	_derrame_max = 0.0


func _buscar_bamboleo(nodo: Node) -> Control:
	if nodo is BamboleoDrag:
		return nodo
	for hijo in nodo.get_children(true):
		var res := _buscar_bamboleo(hijo)
		if res != null:
			return res
	return null


func _initialize() -> void:
	# En headless la ventana nace de 64x64 pero el canvas (stretch
	# canvas_items) mide 1920x1080: los eventos de mouse se dan en coords de
	# VENTANA y se escalan x30 -> todo caeria fuera. Igualamos la ventana al
	# canvas para que pantalla == canvas y las coordenadas sean 1:1.
	root.size = Vector2i(1920, 1080)
	var escena := load("res://scenes/Main.tscn")
	_nivel = escena.instantiate()
	root.add_child(_nivel)
	current_scene = _nivel


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  - %s" % msg)
	else:
		_fallos.append(msg)
		printerr("  FALLO - %s" % msg)


var _boton_abajo := false


## OJO: mientras el botón está presionado, cada InputEventMouseMotion DEBE
## llevar button_mask con el botón izquierdo — el detector de arrastres de
## Godot ignora movimientos "sin dedo en el botón".
func _mover(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _ultima_pos
	if _boton_abajo:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_ultima_pos = pos
	root.push_input(ev, true)


func _boton(pos: Vector2, presionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = presionado
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if presionado else 0
	_boton_abajo = presionado
	_ultima_pos = pos
	root.push_input(ev, true)


func _capa_visible(nombre: String) -> bool:
	var capa = _vaso.get_node_or_null("VasoCapas/" + nombre)
	return capa != null and capa.visible


func _physics_process(_delta: float) -> bool:
	_frame += 1

	match _fase:
		"cargar":
			if _frame < 5:
				return false
			_vaso = _nivel.get_node("Mesa/Vaso")
			_vaso.liquido_derramado.connect(func(perdidos):
				_derrame_detectado = true
				_perdidos_reportados = perdidos)
			# Saltar el tutorial (dispara _iniciar_dia en Main).
			var tut = _nivel.get_node_or_null("TutorialLayer")
			if tut != null and tut.visible:
				tut._terminar()
			_fase = "preparar"
			_frame = 0

		"preparar":
			if _frame < 5:
				return false
			print("== Preparando una Michelada completa por código ==")
			for id in ["vaso", "chamoy_cafe", "escarchado_cafe", "limon", "cerveza", "gomitas"]:
				_check(_vaso.intentar_agregar(id), "se agrego '%s'" % id)
			_check(_vaso.tiene_liquido(), "tiene_liquido() reporta true con cerveza")
			_centro_vaso = _vaso.get_global_rect().get_center()
			print("  (centro del vaso en %s)" % _centro_vaso)
			_fase = "suave_inicio"
			_frame = 0

		"suave_inicio":
			print("== FASE 1: viaje con calma (no debe derramar) ==")
			_boton(_centro_vaso, true)
			_fase = "suave"
			_frame = 0

		"suave":
			# ~90 frames a 3.5 px/frame hacia arriba-izquierda: un viaje
			# tranquilo de ~300 px, como un jugador cuidadoso.
			if _frame <= 90:
				_mover(_centro_vaso + Vector2(-3.5, -2.0) * _frame)
				_muestrear_amplitud()
				if _frame == 20:
					_drag_confirmado = root.gui_is_dragging()
					_check(_drag_confirmado, "el arrastre nativo arranco con los eventos parseados")
				return false
			_reporte_fase()
			_check(not _derrame_detectado, "viaje suave: NO se derramo nada")
			_check(_vaso.ingredientes_agregados.has("cerveza"), "viaje suave: la cerveza sigue en el vaso")
			# Soltamos de regreso sobre el propio vaso (ahi nadie acepta
			# {es_vaso}, asi que el arrastre muere sin servir a nadie).
			_mover(_centro_vaso)
			_boton(_centro_vaso, false)
			_fase = "normal_inicio"
			_frame = 0

		"normal_inicio":
			if _frame < 5:
				return false
			print("== FASE 1.5: servida PRECIPITADA (con prisa; debe quedar AL BORDE, barra > 0.5) ==")
			_boton(_centro_vaso, true)
			_fase = "normal"
			_frame = 0

		"normal":
			# Perfil de "jerk minimo" (asi mueve la mano un humano de un
			# punto a otro): 600 px en 0.6 s con campana de velocidad
			# (pico ~1900 px/s), luego 0.35 s de correcciones chiquitas
			# (+-35 px a ~3 Hz, el ajuste fino sobre el cliente) y frenon.
			if _frame <= 36:
				var tau := float(_frame) / 36.0
				var s := 10.0 * pow(tau, 3) - 15.0 * pow(tau, 4) + 6.0 * pow(tau, 5)
				_mover(_centro_vaso + Vector2(-550.0, -320.0) * s)
				_muestrear_amplitud()
				return false
			if _frame <= 57:
				var t2 := float(_frame - 36) / 60.0
				_mover(_centro_vaso + Vector2(-550.0, -320.0) + Vector2(35.0 * sin(TAU * 3.2 * t2), 0))
				_muestrear_amplitud()
				return false
			if _frame <= 75:
				_muestrear_amplitud()
				return false
			var barra_precipitada := _derrame_max
			_reporte_fase()
			# FILOSOFIA del juego: la prisa ES el riesgo. La servida
			# precipitada debe dejar el vaso AL BORDE (mas de media barra)
			# — y si un dia derrama, es diseno valido, no bug.
			_check(barra_precipitada > 0.5, "servida precipitada: la barra paso de 0.5 (riesgo real, quedo en %.2f)" % barra_precipitada)
			_mover(_centro_vaso)
			_boton(_centro_vaso, false)
			if _derrame_detectado:
				print("  (la precipitada SI derramo esta vez — valido por diseno; re-sirviendo)")
				_check(_vaso.intentar_agregar("cerveza"), "re-servida tras precipitada")
				_check(_vaso.intentar_agregar("gomitas"), "re-gomitas tras precipitada")
				_derrame_detectado = false
				_perdidos_reportados = []
			_fase = "medio_inicio"
			_frame = 0

		"medio_inicio":
			if _frame < 5:
				return false
			print("== FASE 1.6: servida rapida (flick ~1600 px/s, tampoco debe derramar) ==")
			_boton(_centro_vaso, true)
			_fase = "medio"
			_frame = 0

		"medio":
			# Un jugador con prisa: ~12 px/frame (≈1600 px/s) directo al
			# cliente, con su arrancon y su frenon. Chapotea, gotea tal vez,
			# pero NO debe perder el liquido.
			if _frame <= 45:
				_mover(_centro_vaso + Vector2(-9.0, -8.0) * _frame)
				_muestrear_amplitud()
				return false
			_reporte_fase()
			_check(not _derrame_detectado, "flick rapido: NO se derramo (chapoteo sin castigo)")
			_check(_vaso.ingredientes_agregados.has("cerveza"), "flick rapido: la cerveza sigue en el vaso")
			_mover(_centro_vaso)
			_boton(_centro_vaso, false)
			_fase = "muneca_inicio"
			_frame = 0

		"muneca_inicio":
			if _frame < 5:
				return false
			print("== FASE 2: sacudida de MUÑECA rapida (8 Hz, +-90 px — la del usuario; DEBE derramar) ==")
			_boton(_centro_vaso, true)
			_fase = "muneca"
			_frame = 0

		"muneca":
			# Sacudida de muñeca: amplitud chica, frecuencia alta (8 Hz).
			# El pendulo del liquido casi no la oye (esta muy por encima de
			# sus 2 Hz), pero la mano va violentisima: aceleraciones de
			# ~30-100k px/s2. El juez por agitacion la DEBE castigar.
			if _frame <= 150 and not _derrame_detectado:
				var t := float(_frame) / 60.0
				var x := _centro_vaso.x + 90.0 * sin(TAU * 8.0 * t)
				_mover(Vector2(clampf(x, 10.0, 1900.0), _centro_vaso.y - 60.0))
				_muestrear_amplitud()
				return false
			_reporte_fase()
			_check(_derrame_detectado, "muñeca: la señal liquido_derramado se emitio (frame %d)" % _frame)
			_check(not _vaso.ingredientes_agregados.has("cerveza"), "muñeca: la cerveza se derramo")
			_mover(_centro_vaso)
			_boton(_centro_vaso, false)
			_fase = "reservir"
			_frame = 0

		"reservir":
			if _frame < 5:
				return false
			print("== Re-sirviendo para la segunda sacudida ==")
			_check(_vaso.intentar_agregar("cerveza"), "se re-sirvio la cerveza")
			_check(_vaso.intentar_agregar("gomitas"), "se re-sirvieron las gomitas")
			_derrame_detectado = false
			_perdidos_reportados = []
			_fase = "violento_inicio"
			_frame = 0

		"violento_inicio":
			if _frame < 5:
				return false
			print("== FASE 2: sacudidas humanas en rafagas (deben derramar) ==")
			_boton(_centro_vaso, true)
			_fase = "violento"
			_frame = 0

		"violento":
			# El escenario REAL del usuario (2026-08-24): sacudidas fuertes
			# CORTAS con pausas — no un temblor sostenido. Cada rafaga es un
			# ciclo completo a 2 Hz con pico ~4500 px/s (amplitud 358 px,
			# medido de su video), luego ~0.5 s de pausa, hasta 3 rafagas.
			# DEBE derramar (idealmente en la 1a o 2a).
			if _frame <= 180 and not _derrame_detectado:
				var ciclo := (_frame - 1) % 60
				if ciclo < 30:
					var t := float(ciclo) / 60.0
					var x := _centro_vaso.x + 358.0 * sin(TAU * 2.0 * t)
					_mover(Vector2(clampf(x, 10.0, 1900.0), _centro_vaso.y - 60.0))
				_muestrear_amplitud()
				return false
			_reporte_fase()
			print("  (derrame en frame %d => rafaga %d)" % [_frame, (_frame - 1) / 60 + 1])
			_check(_derrame_detectado, "sacudida: la señal liquido_derramado se emitio (frame %d)" % _frame)
			_check(_perdidos_reportados.has("cerveza"), "sacudida: la cerveza esta en la lista de perdidos")
			_check(_perdidos_reportados.has("gomitas"), "sacudida: las gomitas se fueron con el liquido")
			_check(not _vaso.ingredientes_agregados.has("cerveza"), "sacudida: la cerveza YA NO esta en el vaso")
			_check(not _vaso.ingredientes_agregados.has("gomitas"), "sacudida: las gomitas YA NO estan en el vaso")
			_check(_vaso.ingredientes_agregados.has("chamoy_cafe"), "sacudida: el chamoy del borde sobrevivio")
			_check(_vaso.ingredientes_agregados.has("escarchado_cafe"), "sacudida: el escarchado sobrevivio")
			_check(_vaso.ingredientes_agregados.has("limon"), "sacudida: el limon sobrevivio")
			_check(_vaso.existe, "sacudida: el vaso sigue existiendo (no es reset)")
			_check(not _capa_visible("LiquidoCerveza"), "sacudida: la capa LiquidoCerveza se apago")
			_check(_capa_visible("ChamoyCafe"), "sacudida: la capa ChamoyCafe sigue prendida")
			_mover(_centro_vaso)
			_boton(_centro_vaso, false)
			_fase = "recuperar"
			_frame = 0

		"recuperar":
			if _frame < 5:
				return false
			print("== FASE 3: recuperacion (volver a servir) ==")
			_check(_vaso.intentar_agregar("cerveza"), "se puede volver a servir la cerveza")
			_check(_vaso.intentar_agregar("gomitas"), "se pueden volver a poner las gomitas")
			_check(_capa_visible("LiquidoCerveza"), "la capa LiquidoCerveza volvio a prenderse")
			_fase = "fin"

		"fin":
			print("")
			if _fallos.is_empty():
				print("TODAS LAS PRUEBAS PASARON ✅")
			else:
				printerr("%d PRUEBAS FALLARON ❌" % _fallos.size())
				for f in _fallos:
					printerr("  - " + f)
			quit(0 if _fallos.is_empty() else 1)
			return true

	return false
