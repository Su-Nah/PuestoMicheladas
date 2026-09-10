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
		"id": "aura",
		"retrato": "res://assets/sprites/personajes/aura.png",
		"nombre": "El aura",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 35,
		"quiere_michelada": true,
		"paciencia": 18.0,
		"dialogo": [
			"Antes este puesto lo llevaba mi compadre... hasta que dejó de pagar la cuota.",
			"Cuídate, aquí las cosas se ponen feas para el que no coopera.",
			"No le vendas al de polo azul. No tiene aura.",
		],
	},
	{
		"id": "botargajolote",
		"retrato": "res://assets/sprites/personajes/botargajolote.png",
		"nombre": "Botarga de ajolote",
		"es_menor": false,
		"especial": true,
		"puede_repetir": false,
		"precio_base": 40,
		"quiere_michelada": true,
		"paciencia": 10.0,
		# OJO: tanto la Michelada (cerveza) como el Azulito (vodka) llevan
		# alcohol, y le puede tocar cualquiera de las dos al azar (ver
		# CustomerSpawner.gd). Este personaje es menor de edad: este es
		# justo el dilema, tú decides si se lo completas o no.
		"dialogo": [
			"Necesitaba algo refrescante. Ya me estaba asando en esta botarga. ",
			"El único trabajo que encontré fue como botarga afuera del Simi.",
		],
	},
	{
		"id": "chamaco",
		"retrato": "res://assets/sprites/personajes/chamaco.png",
		"nombre": "Chamaco",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 32,
		"quiere_michelada": true,
		"paciencia": 13.0,
		"dialogo": [],
	},
	{
		"id": "elazulito",
		"retrato": "res://assets/sprites/personajes/elazulito.png",
		"nombre": "El que tiene cara de azulito",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 40,
		"quiere_michelada": true,
		"paciencia": 9.0,
		"dialogo": [
			"Mi camisa es Gucci. Puro dinero aquí."
		],
	},
	{
		"id": "elchelas",
		"retrato": "res://assets/sprites/personajes/elchelas.png",
		"nombre": "El chelas",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 21,
		"quiere_michelada": true,
		"paciencia": 14.0,
		"dialogo": [
			"Otra vez ganó el América. LES DIJEEE."
		],
	},
	{
		"id": "kimkardashian",
		"retrato": "res://assets/sprites/personajes/kimkardashian.png",
		"nombre": "¿Es Kim Kardashian?",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 28,
		"quiere_michelada": true,
		"paciencia": 16.0,
		"dialogo": [
			"¡Qué rico! ¡Deberías hacer KityMicheladas!"
		],
	},
	{
		"id": "tlaloc",
		"retrato": "res://assets/sprites/personajes/tlaloc.png",
		"nombre": "Tlaloc",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 44,
		"quiere_michelada": true,
		"paciencia": 11.0,
		"dialogo": [
			"Si te vuelves a tardar invocaré lluvia para que se te moje el puesto."
		],
	},
	{
		"id": "youtuber",
		"retrato": "res://assets/sprites/personajes/youtuber.png",
		"nombre": "Youtuber",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 35,
		"quiere_michelada": true,
		"paciencia": 16.0,
		"dialogo": [
			"¿¿¿Tan poquitas gomitas???"
		],
	},
]

func get_personaje(id: String) -> Dictionary:
	for p in personajes:
		if p["id"] == id:
			return p
	return {}
