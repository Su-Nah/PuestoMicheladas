extends Node
## CustomerSpawner (también es Autoload)
## --------------------------------------
## Genera la fila de clientes de un día cumpliendo TUS reglas:
##
##  1) Nunca se repite el mismo personaje de forma consecutiva
##     ("no deben repetirse dos personajes en el mismo momento").
##  2) Como máximo 2 personajes DISTINTOS pueden repetirse (aparecer 2 veces)
##     en el mismo día.
##  3) No todos los personajes pueden repetirse 2 veces en un día: solo los
##     que tienen "puede_repetir" = true en CharacterDB son candidatos.
##  4) Un personaje que YA se repitió 2 veces ayer, NO puede volver a
##     repetirse 2 veces hoy (aunque sí puede aparecer 1 vez normal).
##
## Guardamos ese último dato en una variable de este mismo Autoload para
## que "recuerde" el día anterior.
##
## PEDIDO ALEATORIO (nuevo)
## -------------------------
## Cada vez que un cliente entra a la fila, se le arma un pedido nuevo con
## generar_pedido_aleatorio(): siempre sigue uno de los 8 órdenes VÁLIDOS de
## VasoMichelada.gd (chamoy rojo/azul x chile en polvo rojo/azul x
## Michelada-con-limón/Azulito-con-vodka), elegido al azar. Así, hasta un
## mismo personaje que se repite dos veces en el día puede pedir algo
## distinto cada vez.

var personajes_que_repitieron_2_ayer: Array = []

const CHAMOYS := ["chamoy_cafe", "chamoy_azul"]
const ESCARCHADOS := ["escarchado_cafe", "escarchado_azul"]

## Cada "camino" decide si la bebida termina siendo Michelada o Azulito
## (ver VasoMichelada.gd: limón -> Michelada, vodka -> Azulito).
const CAMINOS := [
	{"segundo": "limon", "tercero": "cerveza", "bebida": "Michelada"},
	{"segundo": "vodka", "tercero": "gatorlite", "bebida": "Azulito"},
]

const NOMBRES_BONITOS := {
	"chamoy_cafe": "chamoy rojo", "chamoy_azul": "chamoy azul",
	"escarchado_cafe": "chile en polvo rojo", "escarchado_azul": "chile en polvo azul",
	"limon": "limón", "cerveza": "cerveza", "vodka": "vodka",
	"gatorlite": "gatorlite", "gomitas": "gomitas",
}


## Arma un pedido nuevo y al azar, siguiendo siempre uno de los 8 órdenes
## válidos. Devuelve {"receta": Dictionary, "pedido_texto": String}.
func generar_pedido_aleatorio() -> Dictionary:
	var chamoy: String = CHAMOYS[randi() % CHAMOYS.size()]
	var escarchado: String = ESCARCHADOS[randi() % ESCARCHADOS.size()]
	var camino: Dictionary = CAMINOS[randi() % CAMINOS.size()]

	var receta := {
		chamoy: true,
		escarchado: true,
		camino["segundo"]: true,
		camino["tercero"]: true,
		"gomitas": true,
	}

	var texto := "Quiero un %s: %s, %s y %s." % [
		camino["bebida"],
		NOMBRES_BONITOS[chamoy],
		NOMBRES_BONITOS[escarchado],
		NOMBRES_BONITOS["gomitas"],
	]

	return {"receta": receta, "pedido_texto": texto}


func generar_dia(num_slots: int) -> Array:
	var pool: Array = CharacterDB.personajes.duplicate()

	# 1. ¿Quiénes pueden repetirse 2 veces HOY?
	#    Deben tener puede_repetir = true Y no haberse repetido 2 veces ayer.
	var candidatos_doble: Array = []
	for p in pool:
		if p["puede_repetir"] and not personajes_que_repitieron_2_ayer.has(p["id"]):
			candidatos_doble.append(p["id"])

	candidatos_doble.shuffle()
	# Como máximo 2 personajes distintos pueden repetirse hoy.
	var permitidos_doble: Array = candidatos_doble.slice(0, min(2, candidatos_doble.size()))

	# 2. Armamos la fila respetando los límites.
	var conteo: Dictionary = {}   # id -> veces usado hoy
	var fila: Array = []
	var ultimo_id := ""

	var intentos := 0
	var intentos_max := num_slots * 30 # para no quedar en loop infinito

	while fila.size() < num_slots and intentos < intentos_max:
		intentos += 1
		# OJO: .duplicate(true) es importante. Sin esto, "candidato" es la
		# MISMA Dictionary que vive en CharacterDB.personajes; si el mismo
		# personaje se repite 2 veces en el día, las dos apariciones
		# terminarían compartiendo el mismo pedido (porque serían
		# literalmente el mismo objeto), y el pedido de la segunda pisaría
		# el de la primera.
		var candidato: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var cid: String = candidato["id"]

		# Regla 1: no repetir inmediatamente el mismo personaje.
		if cid == ultimo_id:
			continue

		var veces_usado: int = conteo.get(cid, 0)
		var limite := 2 if permitidos_doble.has(cid) else 1

		if veces_usado >= limite:
			continue

		# Le armamos su propio pedido al azar (si de verdad quiere bebida).
		if candidato.get("quiere_michelada", true):
			var pedido := generar_pedido_aleatorio()
			candidato["receta"] = pedido["receta"]
			candidato["pedido_texto"] = pedido["pedido_texto"]

		fila.append(candidato)
		conteo[cid] = veces_usado + 1
		ultimo_id = cid

	# 3. Guardamos quién se repitió 2 veces HOY, para bloquearlo mañana.
	personajes_que_repitieron_2_ayer.clear()
	for id in conteo.keys():
		if conteo[id] >= 2:
			personajes_que_repitieron_2_ayer.append(id)

	return fila
