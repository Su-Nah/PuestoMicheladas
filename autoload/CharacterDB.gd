extends Node
## CharacterDB
## -----------
## Lista de todos los personajes que pueden llegar al puesto.
##
## Campos de cada personaje:
##   id, nombre, es_menor, especial, puede_repetir, precio_base,
##   quiere_michelada, pedido_texto, paciencia -> igual que antes.
##   receta -> Dictionary con los ingredientes que SÍ quiere, en true.
##      Ids válidos: chamoy_cafe, chamoy_azul, escarchado_cafe,
##      escarchado_azul, limon, cerveza, vodka, gatorlite, gomitas.
##      (El "vaso" no cuenta como preferencia: es solo el recipiente.)
##      Hay dos bebidas posibles:
##        Michelada: chamoy(*) + escarchado(*) + limon + cerveza [+ gomitas]
##        Azulito:   chamoy(*) + escarchado(*) + vodka + gatorlite [+ gomitas]
##      (*) rojo (café) o azul, cualquiera de los dos.
##   dialogo -> array de posibles frases si especial == true

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
		"pedido_texto": "Como siempre, m'ija/o: una michelada bien clásica, con gomitas.",
		"paciencia": 18.0,
		"receta": {
			"chamoy_cafe": true, "escarchado_cafe": true, "limon": true,
			"cerveza": true, "gomitas": true,
		},
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
		"pedido_texto": "Quiero un Azulito, bien cargado.",
		"paciencia": 10.0,
		# OJO: el Azulito lleva vodka (alcohol) y este cliente es menor de
		# edad. Este es justo el dilema: tú decides si se lo completas o no.
		"receta": {
			"chamoy_azul": true, "escarchado_azul": true, "vodka": true,
			"gatorlite": true, "gomitas": true,
		},
		"dialogo": [],
	},
	{
		"id": "sra_lupe",
		"retrato": "res://assets/sprites/sra_lupe.png",
		"nombre": "Señora Lupe",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 30,
		"quiere_michelada": true,
		"pedido_texto": "Una michelada normal, pero sin gomitas, porfa.",
		"paciencia": 14.0,
		"receta": {"chamoy_cafe": true, "escarchado_cafe": true, "limon": true, "cerveza": true},
		"dialogo": [],
	},
	{
		"id": "policia_erick",
		"retrato": "res://assets/sprites/policia_erick.png",
		"nombre": "Oficial Erick",
		"es_menor": false,
		"especial": true,
		"puede_repetir": false,
		"precio_base": 0,
		"quiere_michelada": false,
		"pedido_texto": "",
		"paciencia": 12.0,
		"receta": {},
		"dialogo": [
			"Sé lo que pasa aquí con el cobro de piso... si algún día quieres hablar, aquí ando.",
		],
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
		"pedido_texto": "Con harta gomita, así la disfruto.",
		"paciencia": 13.0,
		"receta": {
			"chamoy_cafe": true, "escarchado_azul": true, "limon": true,
			"cerveza": true, "gomitas": true,
		},
		"dialogo": [],
	},
	{
		"id": "dona_carmen",
		"retrato": "res://assets/sprites/dona_carmen.png",
		"nombre": "Doña Carmen",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 28,
		"quiere_michelada": true,
		"pedido_texto": "Una clasiquísima, como las de antes.",
		"paciencia": 20.0,
		"receta": {
			"chamoy_cafe": true, "escarchado_cafe": true, "limon": true,
			"cerveza": true, "gomitas": true,
		},
		"dialogo": [],
	},
	{
		"id": "turista_greg",
		"retrato": "res://assets/sprites/turista_greg.png",
		"nombre": "Greg, el turista",
		"es_menor": false,
		"especial": false,
		"puede_repetir": false,
		"precio_base": 45,
		"quiere_michelada": true,
		"pedido_texto": "Quiero probar el Azulito, ese que se ve bien llamativo.",
		"paciencia": 9.0,
		"receta": {
			"chamoy_azul": true, "escarchado_azul": true, "vodka": true,
			"gatorlite": true, "gomitas": true,
		},
		"dialogo": [],
	},
	{
		"id": "estudiante_fer",
		"retrato": "res://assets/sprites/estudiante_fer.png",
		"nombre": "Fer, la estudiante",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 20,
		"quiere_michelada": true,
		"pedido_texto": "Lo básico nomás, ando bien bruja de dinero.",
		"paciencia": 11.0,
		"receta": {"chamoy_cafe": true, "escarchado_cafe": true, "limon": true, "cerveza": true},
		"dialogo": [],
	},
]


func get_personaje(id: String) -> Dictionary:
	for p in personajes:
		if p["id"] == id:
			return p
	return {}
