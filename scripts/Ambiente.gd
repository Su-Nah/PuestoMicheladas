extends Node
## Ambiente.gd (Autoload)
## -------------------------
## Controla TODO el sonido de "ambiente" del juego, separado de SFX.gd a
## propósito: SFX.gd son sonidos cortos que reaccionan a lo que haces
## (agarrar/soltar/clic); Ambiente.gd son 3 capas que suenan solas de
## fondo, sin que el jugador haga nada:
##
##   1) MÚSICA DE FONDO       -> un solo track, en loop, todo el tiempo.
##   2) RUIDO DE FONDO        -> una capa continua en loop (ambiente de
##      calle/puesto: gente platicando de fondo, tráfico lejano, etc.),
##      separada de la música para poder subir/bajar cada una por su
##      lado.
##   3) SONIDOS ALEATORIOS    -> mínimo 5 clips distintos (un timbre de
##      campana, un perro ladrando, hielo cayendo, etc.) que van sonando
##      de vez en cuando, en momentos y con clips elegidos al azar. Estos
##      NO están en loop: suenan una vez y esperan a la siguiente vez.
##
## DÓNDE PONER ESTE ARCHIVO
## -------------------------
## Guárdalo en res://scripts/Ambiente.gd. Luego: Project -> Project
## Settings -> pestaña Autoload -> Path: res://scripts/Ambiente.gd,
## Node Name: Ambiente -> botón Add.
##
## PUEDES JUGAR SIN TENER TODAVÍA NINGÚN ARCHIVO DE AUDIO
## ---------------------------------------------------------
## Igual que en SFX.gd: se usa _cargar(ruta) en vez de preload(ruta), que
## revisa si el archivo YA existe antes de cargarlo. Si falta, no truena
## nada — simplemente esa capa (música, ruido, o alguno de los 5
## ambientes) se queda en silencio hasta que pongas el archivo con el
## nombre correcto en res://assets/audio/. No hace falta comentar ni
## descomentar nada: en cuanto el archivo exista y vuelvas a correr el
## juego, empieza a sonar solo.

# =====================================================================
# 1) ARCHIVOS DE AUDIO — pon los tuyos en res://assets/audio/
# ---------------------------------------------------------------------
# Sugerencia de contenido para tu puesto de michelada callejero:
#   musica_fondo.ogg      -> música instrumental suave, para que no
#                             canse aunque se repita mucho.
#   ruido_fondo.ogg       -> "cama" de ambiente de calle/mercado, bajita,
#                             constante (NO debe tener picos fuertes,
#                             o se va a notar mucho el loop).
#   ambiente_1..5.ogg     -> sonidos puntuales y variados. Ahora mismo el
#                             arreglo de abajo usa: tamales.wav,
#                             fierroviejo.wav, camotes.wav,
#                             ambiente_4.ogg y ambiente_5.ogg.
#
# OJO CON EL FORMATO: para música/ambiente largos usa .ogg (pesa menos
# que .wav y se importa igual de fácil). Para sonidos cortos (SFX.gd),
# .wav es más simple porque no tiene el pequeño retraso de arranque que
# a veces tiene el Ogg Vorbis.
# =====================================================================

var MUSICA_FONDO: AudioStream
var RUIDO_FONDO: AudioStream

## Mínimo 5 sonidos distintos, como pediste. Agrega más líneas si quieres
## más variedad — no hay límite. Los que todavía no existan como archivo
## quedan como null en el arreglo, y _reproducir_ambiente_aleatorio() ya
## sabe ignorarlos (ver más abajo).
var SONIDOS_AMBIENTE: Array[AudioStream] = []

# =====================================================================
# 2) MODERACIÓN DE VOLUMEN — AJUSTA AQUÍ
# ---------------------------------------------------------------------
# Igual que en SFX.gd: números en decibeles (dB). 0.0 = normal,
# negativo = más bajo, positivo = más fuerte (evita pasar de +6.0).
#
# Regla práctica para que no compitan entre sí:
#   Música   : la más "presente" pero sin tapar los demás sonidos.
#   Ruido    : bien bajito, casi de fondo — se nota más su AUSENCIA que
#              su presencia (si lo subes mucho, se siente ruidoso).
#   Ambiente : un poco más fuerte que el ruido de fondo, para que se
#              distinga cuando suena, pero sin sobresaltar.
# =====================================================================
const VOLUMEN_MUSICA_DB := -10.0
const VOLUMEN_RUIDO_DB := -13.0
const VOLUMEN_AMBIENTE_DB := -8.0

## Buses de audio (opcionales pero recomendados). Créalos en el panel
## inferior "Audio" -> "Add Bus": "Music" y "Ambiente", ambos conectados
## a "Master". Así puedes bajarle solo a la música (ej. un botón de
## "silenciar música" en un menú) sin afectar los efectos de sonido.
## Si no los creas, deja "Master" y todo comparte el mismo volumen.
const BUS_MUSICA := "Master" # cámbialo a "Music" cuando crees el bus
const BUS_AMBIENTE := "Master" # cámbialo a "Ambiente" cuando crees el bus

## Cada cuánto suena un sonido aleatorio de ambiente (en segundos).
## Se elige un número al azar EN ESE RANGO cada vez, para que no se
## sienta repetitivo/predecible. Súbelos si sientes que suenan muy
## seguido; bájalos si el ambiente se siente muy vacío/silencioso.
const TIEMPO_MIN_AMBIENTE := 30.0
const TIEMPO_MAX_AMBIENTE := 60.0

## Los sonidos aleatorios de ambiente empiezan APAGADOS: no arrancan
## solos en _ready(). TutorialOverlay.gd llama a
## iniciar_sonidos_aleatorios() cuando el tutorial termina (se completa
## O se salta con el botón "Saltar"), para que no empiecen a sonar
## mientras el jugador todavía está leyendo el tutorial.
## La música y el ruido de fondo NO se tocan: esos sí siguen sonando
## desde que arranca el juego, como antes.
var _ambiente_aleatorio_iniciado := false

var _musica: AudioStreamPlayer
var _ruido: AudioStreamPlayer
var _sonido_ambiente: AudioStreamPlayer
var _timer_ambiente: Timer


func _ready() -> void:
	MUSICA_FONDO = _cargar("res://assets/audio/CumbiaInstrumental-SinCopyright-LibreUso.mp3")
	RUIDO_FONDO = _cargar("res://assets/audio/ruido_mexico.wav")
	SONIDOS_AMBIENTE = [
		_cargar("res://assets/audio/tamales.wav"),
		_cargar("res://assets/audio/fierroviejo.wav"),
		_cargar("res://assets/audio/camotes.wav"),
		_cargar("res://assets/audio/ambiente_4.ogg"),
		_cargar("res://assets/audio/ambiente_5.ogg"),
	]

	_musica = _crear_player(BUS_MUSICA)
	_ruido = _crear_player(BUS_AMBIENTE)
	_sonido_ambiente = _crear_player(BUS_AMBIENTE)

	_reproducir_en_loop(_musica, MUSICA_FONDO, VOLUMEN_MUSICA_DB)
	_reproducir_en_loop(_ruido, RUIDO_FONDO, VOLUMEN_RUIDO_DB)

	_timer_ambiente = Timer.new()
	add_child(_timer_ambiente)
	_timer_ambiente.one_shot = true
	_timer_ambiente.timeout.connect(_reproducir_ambiente_aleatorio)
	# OJO: aquí YA NO se llama _programar_siguiente_ambiente(). Esperamos
	# a que TutorialOverlay.gd avise que el tutorial terminó (ver
	# iniciar_sonidos_aleatorios() más abajo).


## Llamar UNA vez que el tutorial termina (completo o saltado), para
## que empiecen a sonar los 5 sonidos aleatorios de ambiente. El "if"
## evita que se reinicie el conteo si por alguna razón se llama más de
## una vez (ej. si _terminar() se disparara dos veces).
func iniciar_sonidos_aleatorios() -> void:
	if _ambiente_aleatorio_iniciado:
		return
	_ambiente_aleatorio_iniciado = true
	_programar_siguiente_ambiente()


## Carga un audio SOLO SI el archivo ya existe en el proyecto. Si
## todavía no lo has puesto, devuelve null sin tronar nada (a diferencia
## de preload(), que sí truena el juego completo cuando el archivo no
## existe). Así puedes ir soltando tus .ogg uno por uno.
func _cargar(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta)


func _crear_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.bus = bus
	return p


## Pone un stream a reproducirse Y VOLVER A EMPEZAR SOLO cuando termina,
## para siempre (loop). Esto funciona sin importar si el archivo tiene
## o no marcada la opción "Loop" en su importación — es un respaldo a
## prueba de fallos. Si el archivo todavía no existe (stream == null),
## no hace nada — ni pone el player en marcha ni truena.
##
## TIP: para que la música/ruido hagan loop SIN un salto/silencio
## perceptible entre una vuelta y la siguiente, además de esto conviene
## seleccionar el archivo en el panel FileSystem -> pestaña "Import" ->
## activar la casilla "Loop" -> botón "Reimport". Esa opción hace que el
## loop sea "sample-accurate" (sin el pequeñísimo hueco que a veces deja
## simplemente reconectar la señal "finished" como hacemos aquí).
func _reproducir_en_loop(player: AudioStreamPlayer, stream: AudioStream, volumen_db: float) -> void:
	if stream == null:
		return
	player.stream = stream
	player.volume_db = volumen_db
	player.finished.connect(func(): player.play())
	player.play()


func _programar_siguiente_ambiente() -> void:
	_timer_ambiente.start(randf_range(TIEMPO_MIN_AMBIENTE, TIEMPO_MAX_AMBIENTE))


## Elige un sonido al azar ENTRE LOS QUE YA EXISTEN (ignora los null).
## Si todavía no has puesto ninguno de los 5 archivos, simplemente no
## suena nada esta vez y lo vuelve a intentar más tarde.
func _reproducir_ambiente_aleatorio() -> void:
	var disponibles: Array = SONIDOS_AMBIENTE.filter(func(s): return s != null)
	if disponibles.size() > 0:
		var stream: AudioStream = disponibles[randi() % disponibles.size()]
		_sonido_ambiente.stream = stream
		_sonido_ambiente.volume_db = VOLUMEN_AMBIENTE_DB
		_sonido_ambiente.play()
	_programar_siguiente_ambiente()


## Por si quieres, por ejemplo, bajar la música cuando se abre el
## tutorial y subirla de nuevo al cerrarlo. Uso: Ambiente.set_volumen_musica(-20.0)
func set_volumen_musica(db: float) -> void:
	_musica.volume_db = db


func set_volumen_ruido(db: float) -> void:
	_ruido.volume_db = db
