extends Node
## SFX.gd (Autoload)
## -------------------
## Reproductor de sonidos "de un solo disparo" (one-shot): agarrar/soltar
## ingredientes, botones, etc. Cualquier script llama SFX.play_xxx(...)
## sin tener que buscar nodos ni preocuparse por rutas.
##
## DÓNDE PONER ESTE ARCHIVO
## -------------------------
## Guárdalo en res://scripts/SFX.gd (mismo lugar que tus otros scripts).
## Luego: Project -> Project Settings -> pestaña Autoload -> Path:
## res://scripts/SFX.gd, Node Name: SFX -> botón Add.
## A partir de ahí, "SFX" queda disponible en TODO el proyecto.
##
## DÓNDE PONER LOS ARCHIVOS DE AUDIO
## -----------------------------------
## Se asume que tus .wav/.ogg/.mp3 viven en res://assets/audio/.
## Si usas otra carpeta, solo cambia las rutas dentro de las llamadas a
## _cargar(...) de más abajo (Ctrl+H para buscar/reemplazar
## "res://assets/audio/" por la tuya).
##
## PUEDES JUGAR SIN TENER TODAVÍA NINGÚN ARCHIVO DE AUDIO
## ---------------------------------------------------------
## Este script usa _cargar(ruta) en vez de preload(ruta) a propósito:
## preload() revisa que el archivo EXISTA al momento de compilar el
## script, y si falta truena el juego completo (ni siquiera abre,
## porque este es un Autoload). _cargar() en cambio primero pregunta
## "¿existe ese archivo?" con ResourceLoader.exists(); si no existe,
## devuelve null en vez de tronar, y play()/play_agarrar()/etc. ya
## están hechos para no hacer nada cuando el sonido es null (silencio,
## sin error). Así puedes jugar y probar TODO lo demás desde ya, e ir
## soltando tus archivos de audio uno por uno en res://assets/audio/
## con el nombre exacto que se pide abajo — en cuanto el archivo exista
## y vuelvas a correr el juego, ese sonido empieza a sonar solo, sin
## tocar ni una línea de código aquí.

# =====================================================================
# 1) POOL DE REPRODUCTORES
# ---------------------------------------------------------------------
# En vez de UN solo AudioStreamPlayer, usamos varios ("pool"). Así, si
# dos sonidos se disparan casi al mismo tiempo (ej. sueltas dos
# ingredientes muy rápido), no se corta uno para reproducir el otro.
# =====================================================================
const CANTIDAD_PLAYERS := 12

var _players: Array[AudioStreamPlayer] = []
var _siguiente := 0


# =====================================================================
# 2) MODERACIÓN DE VOLUMEN — AJUSTA AQUÍ
# ---------------------------------------------------------------------
# Todo se mide en decibeles (dB), no en porcentaje:
#   0.0   = el archivo se reproduce tal cual viene (volumen "normal").
#   -6.0  = aproximadamente la MITAD de fuerte.
#   -80.0 = prácticamente inaudible (así "silencias" algo sin borrarlo).
#   +6.0  = el doble de fuerte (cuidado: si subes demasiado se satura y
#           se escucha "quebrado"/distorsionado, mejor nunca pasar de
#           +6 aquí; si algo se sigue escuchando bajito, es mejor subir
#           el volumen del ARCHIVO original en un editor de audio).
#
# Aquí abajo puedes poner UN volumen general para "agarrar" y otro para
# "soltar" (por si, por ejemplo, quieres que soltar siempre suene un
# poco más fuerte que agarrar). Si además quieres afinar UN ingrediente
# en particular (p.ej. que el vidrio del vaso suene más fuerte que una
# bolsita de chamoy), usa el parámetro "extra_db" al llamar a
# play_agarrar()/play_soltar() desde el otro script — se SUMA a este.
# =====================================================================
const VOLUMEN_AGARRAR_DB := -4.0
const VOLUMEN_SOLTAR_DB := -2.0

## Bus de audio al que mandamos estos sonidos. Créalo en el panel
## inferior "Audio" -> botón "Add Bus" -> nómbralo "SFX" y conéctalo a
## "Master". Así puedes bajarle el volumen a TODOS los efectos de sonido
## de un jalón (por ejemplo, con un slider de "volumen de efectos" en un
## menú de opciones) sin tocar la música. Si todavía no creas ese bus,
## deja este valor en "Master" y funciona igual, solo que todo comparte
## el mismo control de volumen.
const BUS := "Master" # cámbialo a "SFX" cuando crees el bus


# =====================================================================
# 3) SONIDOS DE AGARRAR / SOLTAR, UNO POR CADA ELEMENTO ARRASTRABLE
# ---------------------------------------------------------------------
# Hay 10 elementos que se pueden agarrar y soltar con el mouse en este
# juego: el vaso + los 9 ingredientes. Cada uno tiene SU PROPIO sonido
# de agarrar y SU PROPIO sonido de soltar (2 versiones, como pediste).
#
# Aquí solo van los NOMBRES de archivo que yo supongo — tú tienes que
# crear/conseguir esos 20 archivos de audio y ponerlos en
# res://assets/audio/ con esos nombres exactos (o cambiar la ruta aquí
# para que apunte a los tuyos). NO hace falta comentar nada: mientras
# un archivo no exista, _cargar() devuelve null y ese sonido
# simplemente se queda callado (ver la explicación arriba).
# =====================================================================

var SONIDOS_AGARRAR: Dictionary = {}
var SONIDOS_SOLTAR: Dictionary = {}

## Sonido genérico para botones (Vaciar vaso, Siguiente/Saltar del
## tutorial, etc.) que no necesitan un sonido único.
var SONIDO_BOTON: AudioStream
const VOLUMEN_BOTON_DB := -3.0

## NUEVO: sonido de "se derramó" cuando sacudes demasiado el vaso
## caminando (ver VasoMichelada.derramar_liquidos()). Pon aquí un
## chapoteo/salpicón corto.
var SONIDO_DERRAME: AudioStream
const VOLUMEN_DERRAME_DB := 0.0


func _ready() -> void:
	for i in CANTIDAD_PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.bus = BUS
		_players.append(p)

	SONIDOS_AGARRAR = {
		"vaso": _cargar("res://assets/audio/agarrar_vaso.wav"),
		"chamoy_cafe": _cargar("res://assets/audio/agarrar_chamoy_cafe.wav"),
		"chamoy_azul": _cargar("res://assets/audio/agarrar_chamoy_azul.wav"),
		"escarchado_cafe": _cargar("res://assets/audio/agarrar_escarchado_cafe.wav"),
		"escarchado_azul": _cargar("res://assets/audio/agarrar_escarchado_azul.wav"),
		"limon": _cargar("res://assets/audio/agarrar_limon.wav"),
		"vodka": _cargar("res://assets/audio/agarrar_vodka.wav"),
		"cerveza": _cargar("res://assets/audio/agarrar_cerveza.wav"),
		"gatorlite": _cargar("res://assets/audio/agarrar_gatorlite.wav"),
		"gomitas": _cargar("res://assets/audio/agarrar_gomitas.wav"),
	}

	SONIDOS_SOLTAR = {
		"vaso": _cargar("res://assets/audio/soltar_vaso.wav"),
		"chamoy_cafe": _cargar("res://assets/audio/soltar_chamoy_cafe.wav"),
		"chamoy_azul": _cargar("res://assets/audio/soltar_chamoy_azul.wav"),
		"escarchado_cafe": _cargar("res://assets/audio/soltar_escarchado_cafe.wav"),
		"escarchado_azul": _cargar("res://assets/audio/soltar_escarchado_azul.wav"),
		"limon": _cargar("res://assets/audio/soltar_limon.wav"),
		"vodka": _cargar("res://assets/audio/soltar_vodka.wav"),
		"cerveza": _cargar("res://assets/audio/soltar_cerveza.wav"),
		"gatorlite": _cargar("res://assets/audio/soltar_gatorlite.wav"),
		"gomitas": _cargar("res://assets/audio/soltar_gomitas.wav"),
	}

	SONIDO_BOTON = _cargar("res://assets/audio/click_boton.wav")
	SONIDO_DERRAME = _cargar("res://assets/audio/derrame.wav")


## Carga un audio SOLO SI el archivo ya existe en el proyecto. Si
## todavía no lo has puesto, devuelve null sin tronar nada (a diferencia
## de preload(), que si truena el juego completo cuando el archivo no
## existe). Así puedes ir soltando tus .wav/.ogg uno por uno.
func _cargar(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta)


## Reproduce un AudioStream cualquiera. volumen_db es la moderación
## final en decibeles (ver sección 2 de arriba).
func play(stream: AudioStream, volumen_db: float = 0.0) -> void:
	if stream == null:
		return
	var p := _players[_siguiente]
	_siguiente = (_siguiente + 1) % _players.size()
	p.stream = stream
	p.volume_db = volumen_db
	p.play()


## Sonido de AGARRAR el elemento con ese id ("vaso", "limon", "vodka"...)
## extra_db: moderación EXTRA solo para esta llamada, se suma a
## VOLUMEN_AGARRAR_DB (ej. pásale -3.0 si ese ingrediente en particular
## se escucha muy fuerte comparado a los demás).
func play_agarrar(id: String, extra_db: float = 0.0) -> void:
	if SONIDOS_AGARRAR.has(id):
		play(SONIDOS_AGARRAR[id], VOLUMEN_AGARRAR_DB + extra_db)


## Sonido de SOLTAR el elemento con ese id.
func play_soltar(id: String, extra_db: float = 0.0) -> void:
	if SONIDOS_SOLTAR.has(id):
		play(SONIDOS_SOLTAR[id], VOLUMEN_SOLTAR_DB + extra_db)


## Sonido genérico de clic de botón.
func play_boton(extra_db: float = 0.0) -> void:
	play(SONIDO_BOTON, VOLUMEN_BOTON_DB + extra_db)


## NUEVO: sonido de derrame (ver VasoMichelada.derramar_liquidos()).
func play_derrame(extra_db: float = 0.0) -> void:
	play(SONIDO_DERRAME, VOLUMEN_DERRAME_DB + extra_db)
