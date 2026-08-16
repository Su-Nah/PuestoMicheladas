class_name VasoMichelada
extends Panel
## VasoMichelada.gd
## -----------------
## Es la "zona de soltar" (drop zone): representa el vaso. Godot llama
## _can_drop_data() para preguntar si puede aceptar lo que se está
## arrastrando, y _drop_data() cuando el jugador suelta el mouse aquí.
##
## SISTEMA DE CAPAS (nuevo)
## -------------------------
## En vez de tener UN sprite distinto por cada una de las 65 combinaciones
## válidas de ingredientes, el vaso ahora se dibuja apilando varias capas
## (una por ingrediente, más el vidrio y el contorno). Cada capa es un
## TextureRect que se muestra u oculta según si ese ingrediente está en el
## vaso. Al estar unas encima de otras (con transparencia), el motor las
## "encima" visualmente y genera cualquier combinación sin necesitar un
## PNG por combinación.
##
## Orden de las capas de abajo hacia arriba (ver CAPAS y ORDEN_VISUAL):
##   1. vidrio_base       (siempre visible)
##   2. líquidos (salsa de tomate / chile líquido / cerveza / cerveza azul)
##   3. hielo
##   4. escarchado del borde (sal / escarchado café / escarchado azul)
##   5. limón (gajo decorativo)
##   6. contorno           (siempre visible, va arriba de todo)
##
## CÓMO INTEGRARLO EN LA ESCENA (Main.tscn):
##  - Dentro de este Panel, agrega un nodo Control hijo llamado
##    "VasoCapas", y dentro de él un TextureRect por cada capa, con el
##    nombre exacto que aparece en CAPAS (ver más abajo) y todos del mismo
##    tamaño/posición (para que calcen perfectamente al superponerse).
##  - Copia la carpeta assets/michelada_capas/ (incluida en este paquete) a
##    res://assets/michelada_capas/ en tu proyecto.
##  - Cuando empiece un cliente nuevo, llama a vaso.reset().

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

## Mapa ingrediente -> nombre del nodo TextureRect (capa) que lo representa
## dentro de $VasoCapas. "sal" / "escarchado_cafe" / "escarchado_azul"
## comparten la misma "ranura" visual (el borde del vaso) pero cada uno
## tiene su propia capa, porque solo una puede estar visible a la vez.
const CAPAS := {
	LIMON: "Limon",
	SAL: "RimSal",
	ESCARCHADO_CAFE: "RimEscarchadoCafe",
	ESCARCHADO_AZUL: "RimEscarchadoAzul",
	HIELO: "Hielo",
	SALSA_TOMATE: "LiquidoSalsaTomate",
	CHILE_LIQUIDO: "LiquidoChileLiquido",
	CERVEZA: "LiquidoCerveza",
	CERVEZA_AZUL: "LiquidoCervezaAzul",
}

## --- Señales --------------------------------------------------------------
signal ingrediente_soltado(ingrediente_id: String)
signal ingrediente_rechazado(ingrediente_id: String, motivo: String)
## Emite la lista de ingredientes presentes cada vez que el vaso cambia
## (por si alguna UI externa quiere reaccionar a esto).
signal vaso_actualizado(ingredientes_presentes: Array)

## --- Estado -----------------------------------------------------------
## Set de ingredientes presentes en el vaso. Es un Dictionary usado como
## "set": si la llave existe, el ingrediente está puesto. No guardamos
## cuántas veces se soltó cada uno a propósito (el vaso no "cuenta" toppings,
## y visualmente tampoco: la capa de "hielo" se ve igual si se soltó 1 o 10
## veces, porque solo se muestra/oculta, nunca se duplica).
var ingredientes_agregados: Dictionary = {}

## Contenedor de las capas visuales. Ajusta el path si lo ubicas distinto.
@onready var capas_root: Node = $VasoCapas


func _ready() -> void:
	_actualizar_capas()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("ingrediente_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	intentar_agregar(data["ingrediente_id"])


## Intenta agregar un ingrediente al vaso respetando el orden. Devuelve
## true si quedó agregado (o ya estaba agregado), false si se rechazó.
func intentar_agregar(id: String) -> bool:
	if ingredientes_agregados.has(id):
		# Ya estaba puesto: no pasa nada. Así evitamos que "contar" repeticiones
		# afecte el vaso o la receta.
		return true

	var motivo := _validar_orden(id)
	if motivo != "":
		ingrediente_rechazado.emit(id, motivo)
		return false

	ingredientes_agregados[id] = true
	ingrediente_soltado.emit(id)
	_actualizar_capas()
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
		if ya_hay_hielo or ya_hay_liquido:
			return "escarchado_fuera_de_tiempo"
		return ""

	if id in RIM_COATS:
		if not ingredientes_agregados.has(LIMON):
			return "falta_limon_primero"
		for otro_coat in RIM_COATS:
			if otro_coat != id and ingredientes_agregados.has(otro_coat):
				return "solo_un_escarchado"
		if ya_hay_hielo or ya_hay_liquido:
			return "escarchado_fuera_de_tiempo"
		return ""

	if id == HIELO:
		return ""

	if id in LIQUIDOS:
		if not ya_hay_hielo:
			return "falta_hielo_primero"
		return ""

	if id in CERVEZAS:
		if not ya_hay_hielo:
			return "falta_hielo_primero"
		for otra_cerveza in CERVEZAS:
			if otra_cerveza != id and ingredientes_agregados.has(otra_cerveza):
				return "solo_una_cerveza"
		return ""

	return "ingrediente_desconocido"


## Muestra/oculta cada capa según los ingredientes presentes. A diferencia
## del sistema anterior, aquí NO se carga ningún recurso en tiempo real:
## todas las capas ya existen como nodos en la escena, solo cambiamos su
## visibilidad. Esto es más barato y evita el típico "no existe el sprite
## para esta combinación" cuando falta generar un PNG.
func _actualizar_capas() -> void:
	if capas_root == null:
		push_warning("VasoMichelada: no se encontró el nodo VasoCapas. Revisa la escena.")
		return

	for id in CAPAS:
		var nombre_nodo: String = CAPAS[id]
		var nodo := capas_root.get_node_or_null(nombre_nodo)
		if nodo == null:
			push_warning("VasoMichelada: falta la capa '%s' dentro de VasoCapas." % nombre_nodo)
			continue
		nodo.visible = ingredientes_agregados.has(id)

	vaso_actualizado.emit(obtener_ingredientes())


## Vacía el vaso (llamar al empezar a atender a un cliente nuevo).
func reset() -> void:
	ingredientes_agregados.clear()
	_actualizar_capas()


## Devuelve la lista de ingredientes actualmente en el vaso (sin conteo).
func obtener_ingredientes() -> Array:
	return ingredientes_agregados.keys()


## true si el vaso contiene alcohol (útil para el dilema de venta a menores).
func tiene_alcohol() -> bool:
	return ingredientes_agregados.has(CERVEZA) or ingredientes_agregados.has(CERVEZA_AZUL)
