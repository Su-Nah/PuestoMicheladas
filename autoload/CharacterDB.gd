extends Node
## CharacterDB
## -----------
## Lista de todos los personajes que pueden llegar al puesto.
##
## Campos de cada personaje:
##   id, nombre, es_menor, especial, puede_repetir, precio_base,
##   quiere_michelada, paciencia -> igual que antes.
##   dialogo -> array de posibles frases si especial == true
##
## "receta" y "pedido_texto" YA NO se definen aquí: CustomerSpawner.gd le
## arma un pedido distinto y al azar (pero siempre una combinación VÁLIDA
## de la receta) cada vez que este personaje aparece, para que hasta un
## personaje que se repite pueda pedir algo distinto cada vez. Ver
## CustomerSpawner.generar_pedido_aleatorio().

var personajes: Array = [
	{
		"id": "don_ramiro",
		"retrato": "res://assets/sprites/don_ramiro.png",
		"nombre": "Don Ramiro",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 35,
		"quiere_michelada": true,
		"paciencia": 18.0,
		"dialogo": [
			"Antes este puesto lo llevaba mi compadre... hasta que dejó de pagar la cuota.",
			"Cuídate, aquí las cosas se ponen feas para el que no coopera.",
		],
	},
	{
		"id": "chavo_prepa",
		"retrato": "res://assets/sprites/chavo_prepa.png",
		"nombre": "Chavo de prepa",
		"es_menor": true,
		"especial": false,
		"puede_repetir": false,
		"precio_base": 40,
		"quiere_michelada": true,
		"paciencia": 10.0,
		# OJO: tanto la Michelada (cerveza) como el Azulito (vodka) llevan
		# alcohol, y le puede tocar cualquiera de las dos al azar (ver
		# CustomerSpawner.gd). Este personaje es menor de edad: este es
		# justo el dilema, tú decides si se lo completas o no.
		"dialogo": [],
	},
	{
		"id": "obrero_tony",
		"retrato": "res://assets/sprites/obrero_tony.png",
		"nombre": "Tony, el obrero",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 32,
		"quiere_michelada": true,
		"paciencia": 13.0,
		"dialogo": [],
	},
]

func get_personaje(id: String) -> Dictionary:
	for p in personajes:
		if p["id"] == id:
			return p
	return {}
