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

var personajes_que_repitieron_2_ayer: Array = []


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
		var candidato: Dictionary = pool[randi() % pool.size()]
		var cid: String = candidato["id"]

		# Regla 1: no repetir inmediatamente el mismo personaje.
		if cid == ultimo_id:
			continue

		var veces_usado: int = conteo.get(cid, 0)
		var limite := 2 if permitidos_doble.has(cid) else 1

		if veces_usado >= limite:
			continue

		fila.append(candidato)
		conteo[cid] = veces_usado + 1
		ultimo_id = cid

	# 3. Guardamos quién se repitió 2 veces HOY, para bloquearlo mañana.
	personajes_que_repitieron_2_ayer.clear()
	for id in conteo.keys():
		if conteo[id] >= 2:
			personajes_que_repitieron_2_ayer.append(id)

	return fila
