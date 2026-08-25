class_name BamboleoDrag
extends Control
## BamboleoDrag.gd
## ----------------
## El "preview" que sigue al mouse mientras arrastras el vaso YA PREPARADO
## hacia un cliente (ver VasoMichelada._get_drag_data). Antes era una
## imagen fija del vidrio; ahora es un nodo con FÍSICA DE BAMBOLEO:
##
##  1. Se ve el vaso REAL (una copia de sus capas: chamoy, líquido,
##     gomitas...), no un vidrio vacío.
##  2. El vaso se inclina según cómo mueves el mouse, con un modelo de
##     PÉNDULO: se queda atrás cuando aceleras y luego oscila de regreso,
##     igual que un café que llevas caminando.
##  3. El LÍQUIDO de adentro tiene su PROPIA física + un shader
##     (shaders/liquido_bamboleo.gdshader): su superficie persigue la
##     horizontal del mundo mientras el vaso gira, con retraso, rebote y
##     olas — así el líquido de verdad se mueve dentro del vaso en vez de
##     ir pegado como calcomanía. Las gomitas flotan encima y se mecen.
##  4. Si la superficie se ladea demasiado RESPECTO al vaso (el líquido
##     trepando la pared), empiezan a caer GOTAS (aviso visual). Si
##     sigues así, el contenido se DERRAMA de verdad: se pierde del vaso
##     (ver VasoMichelada.derramar_liquidos) y hay que volver a servirlo.
##
## ¿Por qué la física vive AQUÍ y no en VasoMichelada? Porque este nodo
## existe EXACTAMENTE mientras dura el arrastre: Godot lo crea al empezar
## y lo destruye solo al soltar. Así no hay que "acordarse" de apagar el
## seguimiento del mouse ni de reiniciar contadores — el estado del
## bamboleo nace y muere con el arrastre, sin banderas globales.
##
## FÍSICA EN CORTO (péndulo forzado, 3 ingredientes):
##   aceleración_angular = -RIGIDEZ * inclinación      (resorte: quiere volver a 0)
##                         - AMORTIGUACION * vel_ang   (fricción: se va calmando)
##                         - ACOPLE * acel_mouse.x     (empujón: mover el mouse lo mece)
## Mover a velocidad CONSTANTE no inclina nada (aceleración = 0): lo que
## derrama son los JALONES (cambios bruscos de velocidad), que es justo
## lo que se siente intuitivo.

## --- Perillas para ajustar la sensación (el equipo puede jugar con esto) ---
## Qué tan fuerte "jala" el resorte de regreso al centro. La frecuencia
## natural del columpio es sqrt(RIGIDEZ) rad/s: con 250 sale ~2.5 Hz, que
## es el ritmo al que de verdad chapotea el líquido en un vaso chico. (Si
## la bajas mucho, el vaso reacciona "en cámara lenta" y una sacudida
## rápida ni lo despeina — lo comprobamos afinando la prueba automática.)
const RIGIDEZ := 250.0
## Fricción del líquido. Más alto = las oscilaciones mueren antes.
## (Con RIGIDEZ 250, un valor de 5 deja que rebote un par de veces.)
const AMORTIGUACION := 5.0
## Cuánto empuja la aceleración del mouse (px/s²) a la inclinación.
const ACOPLE := 0.003
## Inclinación máxima visual, en radianes (0.9 rad ≈ 52°).
const MAX_INCLINACION := 0.9
## --- El JUEZ del derrame: la AGITACIÓN de la mano --------------------------
## Lección aprendida a base de playtests: el derrame NO se juzga con el
## chapoteo del líquido. El líquido es un oscilador (~2 Hz) y solo
## responde fuerte a sacudidas cercanas a SU frecuencia — una sacudida de
## muñeca rápida (~7-10 Hz) lo deja casi quieto aunque la mano vaya
## violentísima, y el castigo se volvía una lotería de frecuencias.
## El juez correcto es la VIOLENCIA DE LA MANO: la aceleración del mouse
## (px/s²) suavizada en el tiempo. Sacudir fuerte da aceleraciones
## enormes SIN IMPORTAR la frecuencia; llevarlo con calma no. El líquido
## y sus olas quedan como puro espectáculo (que para eso son geniales).
## Agitación (px/s²) a partir de la cual empieza a gotear y a llenarse la
## barra de derrame. Valores MEDIDOS por maniobra (con el test e2e, que
## los imprime): viaje con calma ~5.7k, flick de servida ~16k, servida
## normal con arrancón/frenón PICA ~34k un instante, sacudida (de muñeca
## rápida o de brazadas) SOSTIENE 55-60k. El umbral vive entre la servida
## y la sacudida: la servida lo cruza apenas un parpadeo (suelta 2-3
## gotas de aviso y nada más) y la sacudida lo revienta.
const UMBRAL_AGITACION := 8000.0
## Cuánta agitación por encima del umbral equivale a "exceso 1.0".
## FILOSOFÍA (afinada en playtests): esto es un LÍQUIDO DE VERDAD — el
## mouse se maneja con delicadeza o se derrama. El único camino seguro
## es el viaje sereno; todo lo demás es riesgo creciente:
##  - viaje sereno/delicado (~6k): en silencio, cero riesgo.
##  - servida rapidita "controlada" (~16k): gotea y llena ~2/5 de barra —
##    ya es jugar con fuego.
##  - servida PRECIPITADA (~34k de pico): al borde o derrama ella sola.
##  - sacudida (~55k+): derrama en ~0.25 s.
const ESCALA_AGITACION := 15000.0
## Qué tan rápido responde el medidor de agitación (1/s). Bajito = ignora
## espasmos de un frame; alto = reacciona al instante.
const RITMO_AGITACION := 6.0
## Llenado de la barra por segundo por unidad de exceso (el exceso se
## topa en 2.0 para que un pico absurdo no vacíe el vaso en dos frames).
const TASA_DERRAME := 2.0
## Qué tan rápido se vacía la barra al volver a la calma.
const RECUPERACION := 0.5
## Gotas por segundo mientras estás pasado del umbral (aviso visual).
const GOTAS_POR_SEGUNDO := 14.0
## Suavizado de la velocidad del mouse (filtra el ruido del sensor).
const SUAVIZADO_VELOCIDAD := 18.0

## Colores de las gotas según la bebida que lleve el vaso.
const COLOR_GOTA_CERVEZA := Color(0.96, 0.72, 0.18, 0.9)
const COLOR_GOTA_AZULITO := Color(0.25, 0.55, 0.95, 0.9)

## --- Perillas del LÍQUIDO (el shader liquido_bamboleo.gdshader) -----------
## El líquido tiene su PROPIO resorte, separado del vaso: su superficie
## siempre quiere quedar horizontal respecto al MUNDO (la gravedad manda),
## mientras el vaso gira por su lado. Ese desfase — vaso ladeado, líquido
## nivelado pero llegando tarde y pasándose de largo — es lo que hace que
## de verdad se lea como líquido y no como calcomanía.
## Qué tan rápido persigue la superficie su posición de equilibrio.
const RIGIDEZ_LIQUIDO := 180.0
## Fricción de esa persecución (bajita = chapotea varias veces).
const AMORTIGUACION_LIQUIDO := 4.0
## "Gravedad" en px/s²: contra ella se compara la aceleración del mouse
## para decidir cuánto se ladea la superficie en equilibrio
## (objetivo = atan(acel_x / GRAVEDAD)). Más chica = líquido más sensible.
const GRAVEDAD_PX := 1500.0
## Conversión de pendiente real -> pendiente en UV del arte (ancho/alto de
## los PNG de líquido: 300/380).
const ASPECTO_ARTE := 300.0 / 380.0
## La ola de la superficie: amplitud ambiente (siempre viva, aunque vayas
## despacio — un líquido nunca está 100% quieto), tope, y cómo crece con
## la agitación (velocidad angular del líquido).
const OLA_AMBIENTE := 0.004
const OLA_MAXIMA := 0.045
const OLA_POR_AGITACION := 0.006
const OLA_VELOCIDAD_BASE := 7.0
const OLA_VELOCIDAD_AGITACION := 6.0

## Dónde está la superficie del líquido en cada PNG (medido con el alpha
## de assets/michelada_capas: fila superior de pixeles opacos / alto 380).
const NIVEL_ART := {
	VasoMichelada.CERVEZA: 0.055,
	VasoMichelada.GATORLITE: 0.087,
	VasoMichelada.VODKA: 0.782,
}

## --- Estado interno del péndulo -------------------------------------------
var _vaso: VasoMichelada = null
var _capas_copia: Control = null
var _tam_visual := Vector2.ZERO

var _inclinacion := 0.0
var _vel_angular := 0.0
var _pos_anterior := Vector2.ZERO
var _vel_suave := Vector2.ZERO
var _primer_frame := true

var _derrame := 0.0
var _acumulador_gotas := 0.0
var _ya_derramado := false

## Estado del líquido: su ángulo en el MUNDO (0 = superficie horizontal),
## su velocidad angular, y la ola.
var _angulo_liquido := 0.0
var _vel_liquido := 0.0
var _amp_ola := 0.0
var _fase_ola := 0.0
## Materiales de shader de las capas de líquido visibles en la copia.
var _materiales_liquido: Array = []
var _nodo_gomitas: Control = null
var _gomitas_pos_base := Vector2.ZERO
## Medidor de violencia de la mano (px/s² suavizados) — el juez del derrame.
var _agitacion := 0.0
## La barrita de peligro que aparece junto al vaso cuando vas a derramar.
var _barra_peligro: Panel = null
var _barra_relleno: Panel = null
## Frecuencia natural del líquido (rad/s), derivada de su rigidez — se usa
## para convertir velocidad angular en "ángulo pico equivalente" al medir
## la envolvente del chapoteo. Se calcula en _ready para que siga valiendo
## si el equipo ajusta RIGIDEZ_LIQUIDO.
var _omega_liquido := 1.0


## Fabrica el preview completo a partir del vaso real. Se usa así desde
## VasoMichelada._get_drag_data():  set_drag_preview(BamboleoDrag.crear(self))
static func crear(vaso: VasoMichelada) -> BamboleoDrag:
	var preview := BamboleoDrag.new()
	preview._vaso = vaso
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El nodo "Mesa" de Main.tscn tiene z_index = 1, o sea que se dibuja
	# ENCIMA de todo lo que tenga z_index 0 — incluidos los previews de
	# arrastre, que Godot cuelga en la raíz de la escena. Sin esta línea,
	# el vaso "en la mano" desaparece en cuanto pasa por encima de la mesa
	# (lo descubrimos con capturas: se veía arriba de la mesa y se
	# esfumaba abajo). Con z_index alto, lo que llevas cargando siempre
	# queda hasta arriba, como debe ser.
	preview.z_index = 10

	# Copiamos el árbol de capas tal como está AHORITA (duplicate copia
	# también la visibilidad de cada TextureRect), y lo encogemos para que
	# el vaso "en la mano" no tape media pantalla.
	var capas := vaso.capas_root.duplicate() as Control
	capas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var escala := 0.45
	capas.scale = Vector2(escala, escala)
	preview.add_child(capas)
	preview._capas_copia = capas
	preview._tam_visual = capas.size * escala

	# DATO CLAVE (comprobado con una sonda): Godot escribe la posición del
	# mouse DIRECTO en la propiedad position de este nodo en cada frame del
	# arrastre — cualquier offset que pongamos ahí se pisa de inmediato.
	# Por eso el "punto de agarre" (los dedos, arriba-al-centro del vaso) se
	# logra desplazando al HIJO: así ese punto del dibujo cae justo en
	# nuestro origen, que ES el cursor. Y como rotation gira alrededor del
	# pivote (que dejamos en el origen por defecto), el vaso columpia
	# alrededor de los dedos, como péndulo de verdad.
	capas.position = Vector2(-preview._tam_visual.x * 0.5, -preview._tam_visual.y * 0.12)

	# A cada capa de LÍQUIDO visible se le monta su propio material con el
	# shader del bamboleo (uno por capa, porque cada arte tiene su nivel de
	# superficie distinto). Solo en la COPIA — el vaso de la mesa no se toca.
	var shader := load("res://shaders/liquido_bamboleo.gdshader") as Shader
	for id in NIVEL_ART:
		var nombre_capa: String = VasoMichelada.CAPAS.get(id, "")
		var capa_liq := capas.get_node_or_null(nombre_capa) as CanvasItem
		if capa_liq == null or not capa_liq.visible:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("nivel_art", NIVEL_ART[id])
		capa_liq.material = mat
		preview._materiales_liquido.append(mat)

	# Las gomitas van FLOTANDO encima del líquido: guardamos el nodo para
	# ladearlas y mecerlas junto con la superficie.
	var gomitas := capas.get_node_or_null(VasoMichelada.CAPAS[VasoMichelada.GOMITAS]) as Control
	if gomitas != null and gomitas.visible:
		gomitas.pivot_offset = gomitas.size / 2.0
		preview._nodo_gomitas = gomitas
		preview._gomitas_pos_base = gomitas.position

	# La barrita de peligro (oculta hasta que empieces a agitar de más):
	# un marco oscuro a la derecha del vaso con un relleno que sube del
	# amarillo al rojo conforme se acerca el derrame.
	var barra := Panel.new()
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.size = Vector2(11.0, preview._tam_visual.y * 0.55)
	barra.position = Vector2(preview._tam_visual.x * 0.62, -preview._tam_visual.y * 0.05)
	var estilo_marco := StyleBoxFlat.new()
	estilo_marco.bg_color = Color(0.08, 0.08, 0.08, 0.75)
	estilo_marco.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("panel", estilo_marco)
	barra.visible = false
	# Pivote al centro: la barra se contra-rota cada frame para quedar
	# siempre VERTICAL aunque el vaso se ladee (es UI, no parte del vaso).
	barra.pivot_offset = barra.size / 2.0
	preview.add_child(barra)
	preview._barra_peligro = barra

	var relleno := Panel.new()
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_relleno := StyleBoxFlat.new()
	estilo_relleno.bg_color = Color(1.0, 0.85, 0.2)
	estilo_relleno.set_corner_radius_all(3)
	relleno.add_theme_stylebox_override("panel", estilo_relleno)
	barra.add_child(relleno)
	preview._barra_relleno = relleno
	return preview


func _ready() -> void:
	_pos_anterior = _posicion_de_la_mano()
	_omega_liquido = sqrt(RIGIDEZ_LIQUIDO)


## La posición de "la mano" es nuestra propia propiedad position: Godot la
## sobreescribe con el cursor en cada frame del arrastre (ver crear()). Se
## usa la PROPIEDAD position (no la transform global) a propósito: la
## rotación del bamboleo gira alrededor del pivote sin tocar position, así
## que el columpio no se cuela en la medición — si midiéramos la esquina
## transformada, el vaso "leería" su propio meneo como velocidad del mouse
## y se retroalimentaría solo.
func _posicion_de_la_mano() -> Vector2:
	return position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	# Si el juego se traba un instante (carga, hipo del sistema), delta
	# llega gigante y la integración de los resortes se vuelve inestable
	# (explota) — el vaso se derramaría "solo" por culpa de la máquina,
	# no del jugador. Tratamos cualquier tirón como máximo ~33 ms.
	delta = minf(delta, 1.0 / 30.0)

	# 1) ¿Qué tan brusco se mueve la mano? De la posición sacamos la
	# velocidad y, del cambio de velocidad, la aceleración.
	var pos_mano := _posicion_de_la_mano()
	var vel_cruda := (pos_mano - _pos_anterior) / delta
	_pos_anterior = pos_mano
	if _primer_frame:
		# La primera medición se DESCARTA entera: el preview nace en (0,0)
		# y Godot lo teletransporta al cursor en el primer movimiento. Esa
		# distancia no es velocidad real de la mano — si se colara al
		# suavizado, nacería una aceleración fantasma gigante que clavaba
		# el líquido en el tope y pre-cargaba el derrame (nos pasó).
		_primer_frame = false
		_vel_suave = Vector2.ZERO
		return

	var vel_suave_anterior := _vel_suave
	var mezcla := 1.0 - exp(-SUAVIZADO_VELOCIDAD * delta)
	_vel_suave = _vel_suave.lerp(vel_cruda, mezcla)
	var acel_mouse := (_vel_suave - vel_suave_anterior) / delta

	# El medidor de AGITACIÓN (el juez del derrame): magnitud de la
	# aceleración de la mano, suavizada. El eje Y cuenta a la mitad
	# (sacudir vertical también derrama, pero menos que el vaivén lateral
	# que sí empuja el líquido contra las paredes).
	var violencia := absf(acel_mouse.x) + 0.5 * absf(acel_mouse.y)
	_agitacion = lerpf(_agitacion, violencia, 1.0 - exp(-RITMO_AGITACION * delta))

	# 2) Péndulo forzado (ver comentario de cabecera).
	var acel_angular := -RIGIDEZ * _inclinacion - AMORTIGUACION * _vel_angular - ACOPLE * acel_mouse.x
	_vel_angular = clampf(_vel_angular + acel_angular * delta, -25.0, 25.0)
	_inclinacion = clampf(_inclinacion + _vel_angular * delta, -MAX_INCLINACION, MAX_INCLINACION)
	rotation = _inclinacion

	# 3) La física del LÍQUIDO, separada de la del vaso: la superficie
	# persigue su equilibrio (horizontal del mundo, ladeada por la
	# aceleración de la mano como si la gravedad se inclinara), llegando
	# tarde y pasándose de largo. atan2(acel, GRAVEDAD) es el ángulo al
	# que se acomodaría el líquido si esa aceleración durara para siempre.
	var objetivo_liquido := atan2(acel_mouse.x, GRAVEDAD_PX)
	var acel_liquido := RIGIDEZ_LIQUIDO * (objetivo_liquido - _angulo_liquido) - AMORTIGUACION_LIQUIDO * _vel_liquido
	_vel_liquido = clampf(_vel_liquido + acel_liquido * delta, -30.0, 30.0)
	_angulo_liquido = clampf(_angulo_liquido + _vel_liquido * delta, -1.2, 1.2)

	# La ola: crece con el chapoteo Y con la agitación de la mano (una
	# sacudida rápida de muñeca casi no mece el péndulo del líquido, pero
	# SÍ debe picar la superficie — sin esto, el vaso se veía tranquilo
	# justo cuando el jugador más lo agitaba), y nunca muere del todo.
	var chapoteo_visual := absf(_vel_liquido) * OLA_POR_AGITACION
	var picado_por_mano := _agitacion / (UMBRAL_AGITACION + ESCALA_AGITACION) * OLA_MAXIMA
	var amp_objetivo := clampf(maxf(chapoteo_visual, picado_por_mano), OLA_AMBIENTE, OLA_MAXIMA)
	_amp_ola = lerpf(_amp_ola, amp_objetivo, 1.0 - exp(-6.0 * delta))
	_fase_ola += (OLA_VELOCIDAD_BASE + absf(_vel_liquido) * OLA_VELOCIDAD_AGITACION + _agitacion * 0.0002) * delta

	# Lo que se DIBUJA es la diferencia entre ambos ángulos: las capas ya
	# giran físicamente con el vaso, así que al shader le pasamos cuánto
	# se desvía la superficie DENTRO del vaso.
	var angulo_relativo := _angulo_liquido - _inclinacion
	var pendiente := tan(clampf(angulo_relativo, -1.1, 1.1)) * ASPECTO_ARTE
	for mat in _materiales_liquido:
		mat.set_shader_parameter("pendiente", pendiente)
		mat.set_shader_parameter("amp_ola", _amp_ola)
		mat.set_shader_parameter("fase_ola", _fase_ola)

	# Las gomitas van flotando: se ladean con la superficie y se mecen
	# suavecito al ritmo de la ola.
	if _nodo_gomitas != null:
		_nodo_gomitas.rotation = clampf(angulo_relativo * 0.7, -0.35, 0.35)
		_nodo_gomitas.position = _gomitas_pos_base + Vector2(0.0, sin(_fase_ola) * _amp_ola * 180.0)

	# 4) ¿Se derrama? Lo juzga la AGITACIÓN de la mano (ver el bloque de
	# constantes): el líquido dibujado es espectáculo; el veredicto sale
	# de qué tan violento mueves el mouse, a cualquier frecuencia.
	if _ya_derramado or _vaso == null or not _vaso.tiene_liquido():
		_actualizar_barra_peligro()
		return

	var exceso := (_agitacion - UMBRAL_AGITACION) / ESCALA_AGITACION
	if exceso <= 0.0:
		_derrame = maxf(_derrame - RECUPERACION * delta, 0.0)
		_actualizar_barra_peligro()
		return

	_derrame += minf(exceso, 2.0) * TASA_DERRAME * delta
	_acumulador_gotas += GOTAS_POR_SEGUNDO * delta
	while _acumulador_gotas >= 1.0:
		_acumulador_gotas -= 1.0
		_soltar_gota()

	_actualizar_barra_peligro()
	if _derrame >= 1.0:
		_derramar_todo()


## La barrita de peligro junto al vaso: aparece en cuanto empiezas a
## agitar de más y se llena (amarillo -> rojo) rumbo al derrame. Hace el
## sistema LEGIBLE: el jugador ve exactamente qué tan cerca estuvo, en
## vez de sentir que el derrame es una lotería.
func _actualizar_barra_peligro() -> void:
	if _barra_peligro == null or _barra_relleno == null:
		return
	var visible_ahora := _derrame > 0.02 and not _ya_derramado
	_barra_peligro.visible = visible_ahora
	if not visible_ahora:
		return
	# Contra-rotar: el preview entero gira con el bamboleo, pero el
	# medidor debe leerse siempre en vertical.
	_barra_peligro.rotation = -rotation
	var alto_total := _barra_peligro.size.y - 4.0
	var alto := clampf(_derrame, 0.0, 1.0) * alto_total
	_barra_relleno.size = Vector2(_barra_peligro.size.x - 4.0, alto)
	_barra_relleno.position = Vector2(2.0, 2.0 + alto_total - alto)
	var estilo := _barra_relleno.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo != null:
		estilo.bg_color = Color(1.0, 0.85, 0.2).lerp(Color(0.92, 0.15, 0.1), clampf(_derrame, 0.0, 1.0))


## El derrame total: chorro de gotas, el vaso REAL pierde su líquido (y las
## gomitas, que flotan encima), y nuestra copia visual se vacía igual.
func _derramar_todo() -> void:
	_ya_derramado = true
	for i in range(12):
		_soltar_gota()

	var perdidos := _vaso.derramar_liquidos()
	if _capas_copia != null:
		for id in perdidos:
			var nombre_capa: String = VasoMichelada.CAPAS.get(id, "")
			var capa := _capas_copia.get_node_or_null(nombre_capa)
			if capa != null:
				capa.visible = false


## Una gotita: un circulito del color de la bebida que cae desde la boca del
## vaso, acelerando (como con gravedad) mientras se desvanece.
func _soltar_gota() -> void:
	var escena_raiz := get_tree().current_scene
	if escena_raiz == null:
		return

	var gota := Panel.new()
	var lado := randf_range(6.0, 10.0)
	gota.size = Vector2(lado, lado)
	gota.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Mismo cuento que el preview: la Mesa tiene z_index = 1, y las gotas
	# caen justo sobre ella — sin esto, la mesa las taparía.
	gota.z_index = 10

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_GOTA_CERVEZA if _vaso.ingredientes_agregados.has(VasoMichelada.CERVEZA) else COLOR_GOTA_AZULITO
	estilo.set_corner_radius_all(int(lado / 2.0))
	gota.add_theme_stylebox_override("panel", estilo)

	# Nace en la boca del vaso (nuestro origen es el cursor/punto de agarre;
	# el dibujo del vaso está centrado en x y cuelga hacia abajo — ver
	# crear()). Los Control no tienen to_global() (eso es de Node2D); su
	# equivalente es multiplicar el punto local por get_global_transform(),
	# que ya incluye la rotación actual — así las gotas salen del borde
	# inclinado, no del centro.
	var boca_local := Vector2(randf_range(-_tam_visual.x * 0.35, _tam_visual.x * 0.35), _tam_visual.y * 0.06)
	escena_raiz.add_child(gota)
	gota.global_position = get_global_transform() * boca_local

	# Caída con tween: y acelera hacia abajo (EASE_IN = empieza lento y
	# agarra velocidad, como la gravedad), x hereda un poquito del envión
	# de la mano, y el alfa se apaga al final.
	var caida := randf_range(90.0, 170.0)
	var duracion := randf_range(0.4, 0.65)
	var tween := gota.create_tween()
	tween.set_parallel(true)
	tween.tween_property(gota, "global_position:y", gota.global_position.y + caida, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(gota, "global_position:x", gota.global_position.x + _vel_suave.x * 0.04, duracion)
	tween.tween_property(gota, "modulate:a", 0.0, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(gota.queue_free)
