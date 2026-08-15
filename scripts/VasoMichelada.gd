extends Panel
## VasoMichelada.gd
## -----------------
## Es la "zona de soltar" (drop zone): representa el vaso. Godot llama
## _can_drop_data() para preguntar si puede aceptar lo que se está
## arrastrando, y _drop_data() cuando el jugador suelta el mouse aquí.
##
## NOVEDADES:
## 1) El vaso ahora VALIDA el orden en el que se agregan los ingredientes
##    (ver _validar_orden). Si el ingrediente llega fuera de orden, se
##    rechaza (no se agrega) y se emite ingrediente_rechazado con un motivo,
##    para que la UI pueda avisarle al jugador (sonido, texto, shake, etc).
## 2) El sprite del vaso cambia según la COMBINACIÓN de ingredientes que
##    tiene actualmente, no según cuántas veces se soltó cada uno. Soltar
##    "sal" tres veces se ve exactamente igual que soltarla una sola vez.
##
## CÓMO INTEGRARLO EN LA ESCENA (MicheladaMixer.tscn):
##  - Agrega un nodo hijo TextureRect llamado exactamente "VasoSprite"
##    dentro de este Panel (o ajusta el @onready var de abajo con el path
##    correcto). Ese TextureRect es el que muestra el vaso.
##  - Copia la carpeta assets/michelada/ (incluida en este mismo paquete) a
##    res://assets/michelada/ en tu proyecto. Ahí están los sprites para
##    TODAS las combinaciones válidas de ingredientes.
##  - Cuando empiece un cliente nuevo, llama a vaso.reset() para vaciar el
##    vaso y volver al sprite vacío.

## --- Catálogo de ingredientes -------------------------------------------
const LIMON := "limon"
const SAL := "sal"
const ESCARCHADO_CAFE := "escarchado_cafe"
const ESCARCHADO_AZUL := "escarchado_azul"
const HIELO := "hielo"
const SALSA_TOMATE := "salsa_tomate"
const CHILE_LIQUIDO := "chile_liquido"
const CERVEZA := "cerveza"
const CERVEZA_AZUL := "cerveza_azul"

const RIM_COATS := [SAL, ESCARCHADO_CAFE, ESCARCHADO_AZUL] # solo se puede elegir UNO
const LIQUIDOS := [SALSA_TOMATE, CHILE_LIQUIDO]             # se pueden combinar los dos
const CERVEZAS := [CERVEZA, CERVEZA_AZUL]                   # solo se puede elegir UNA

## Orden canónico usado para construir el nombre del sprite. Debe coincidir
## EXACTO con ORDEN_CANONICO de gen_sprites.py (el generador de assets),
## para que la clave calculada aquí siempre encuentre su archivo.
const ORDEN_CANONICO := [
	LIMON, SAL, ESCARCHADO_CAFE, ESCARCHADO_AZUL,
	HIELO, SALSA_TOMATE, CHILE_LIQUIDO, CERVEZA, CERVEZA_AZUL,
]

const RUTA_SPRITES := "res://assets/michelada/michelada_%s.png"

## --- Señales --------------------------------------------------------------
signal ingrediente_soltado(ingrediente_id: String)
signal ingrediente_rechazado(ingrediente_id: String, motivo: String)
signal vaso_actualizado(textura_path: String)

## --- Estado -----------------------------------------------------------
## Set de ingredientes presentes en el vaso. Es un Dictionary usado como
## "set": si la llave existe, el ingrediente está puesto. No guardamos
## cuántas veces se soltó cada uno a propósito (el vaso no "cuenta" toppings).
var ingredientes_agregados: Dictionary = {}

## Ajusta este path si tu TextureRect vive en otro lugar del árbol.
@onready var vaso_sprite: TextureRect = $VasoSprite


func _ready() -> void:
	_actualizar_sprite()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("ingrediente_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	intentar_agregar(data["ingrediente_id"])


## Intenta agregar un ingrediente al vaso respetando el orden. Devuelve
## true si quedó agregado (o ya estaba agregado), false si se rechazó.
func intentar_agregar(id: String) -> bool:
	if ingredientes_agregados.has(id):
		# Ya estaba puesto: no pasa nada. Así evitamos que "contar" repeticiones
		# afecte el sprite o la receta.
		return true

	var motivo := _validar_orden(id)
	if motivo != "":
		ingrediente_rechazado.emit(id, motivo)
		return false

	ingredientes_agregados[id] = true
	ingrediente_soltado.emit(id)
	_actualizar_sprite()
	return true


## Devuelve "" si {id} se puede agregar ahora mismo, o un código de motivo
## de rechazo si no. Orden exigido:
##   1) Escarchado del borde: primero limón, luego (opcional) sal O
##      escarchado café O escarchado azul (solo uno).
##   2) Hielo.
##   3) Salsa de tomate y/o chile líquido (requieren que ya haya hielo).
##   4) Cerveza O cerveza azul (requiere que ya haya hielo; es el último paso,
##      después de la cerveza el vaso queda cerrado).
func _validar_orden(id: String) -> String:
	var ya_hay_hielo := ingredientes_agregados.has(HIELO)
	var ya_hay_liquido := ingredientes_agregados.has(SALSA_TOMATE) or ingredientes_agregados.has(CHILE_LIQUIDO)
	var ya_hay_cerveza := ingredientes_agregados.has(CERVEZA) or ingredientes_agregados.has(CERVEZA_AZUL)

	# Nada se agrega después de la cerveza: la michelada ya está lista.
	if ya_hay_cerveza:
		return "vaso_completo"

	if id == LIMON:
		# El limón (paso 1a) debe llegar antes del hielo o los líquidos.
		if ya_hay_hielo or ya_hay_liquido:
			return "escarchado_fuera_de_tiempo"
		return ""

	if id in RIM_COATS:
		# Sal / escarchado café / escarchado azul (paso 1b): necesitan limón
		# antes, solo puede haber UNO de los tres, y deben llegar antes del
		# hielo o los líquidos.
		if not ingredientes_agregados.has(LIMON):
			return "falta_limon_primero"
		for otro_coat in RIM_COATS:
			if otro_coat != id and ingredientes_agregados.has(otro_coat):
				return "solo_un_escarchado"
		if ya_hay_hielo or ya_hay_liquido:
			return "escarchado_fuera_de_tiempo"
		return ""

	if id == HIELO:
		# El hielo (paso 2) siempre se puede agregar, salvo que ya haya
		# cerveza (ya filtrado arriba). No exigimos escarchado antes: el
		# escarchado es opcional, pero SI el jugador quería ponerlo, ya no
		# podrá hacerlo después de agregar hielo (ver arriba).
		return ""

	if id in LIQUIDOS:
		# Salsa de tomate / chile líquido (paso 3): requieren hielo primero.
		if not ya_hay_hielo:
			return "falta_hielo_primero"
		return ""

	if id in CERVEZAS:
		# Cerveza / cerveza azul (paso 4): requiere hielo primero, y solo
		# puede haber una de las dos.
		if not ya_hay_hielo:
			return "falta_hielo_primero"
		for otra_cerveza in CERVEZAS:
			if otra_cerveza != id and ingredientes_agregados.has(otra_cerveza):
				return "solo_una_cerveza"
		return ""

	return "ingrediente_desconocido"


## Recalcula qué sprite corresponde a la combinación actual y lo aplica.
func _actualizar_sprite() -> void:
	var path := RUTA_SPRITES % _calcular_clave_combo()
	if ResourceLoader.exists(path):
		vaso_sprite.texture = load(path)
	else:
		push_warning("VasoMichelada: no existe sprite para la combinación '%s'" % path)
	vaso_actualizado.emit(path)


## Construye la clave del sprite en el mismo orden canónico usado por
## gen_sprites.py, por ejemplo: "limon_sal_hielo_salsa_tomate_cerveza".
## Si no hay ningún ingrediente, la clave es "vacio".
func _calcular_clave_combo() -> String:
	var partes: Array = []
	for id in ORDEN_CANONICO:
		if ingredientes_agregados.has(id):
			partes.append(id)
	if partes.is_empty():
		return "vacio"
	return "_".join(partes)


## Vacía el vaso (llamar al empezar a atender a un cliente nuevo).
func reset() -> void:
	ingredientes_agregados.clear()
	_actualizar_sprite()


## Devuelve la lista de ingredientes actualmente en el vaso (sin conteo).
func obtener_ingredientes() -> Array:
	return ingredientes_agregados.keys()


## true si el vaso contiene alcohol (útil para el dilema de venta a menores).
func tiene_alcohol() -> bool:
	return ingredientes_agregados.has(CERVEZA) or ingredientes_agregados.has(CERVEZA_AZUL)
