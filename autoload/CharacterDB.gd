extends Node
## CharacterDB
## -----------
## Lista de todos los personajes que pueden llegar al puesto.
## Usamos Dictionary (diccionarios) en vez de crear "Resources" personalizados
## porque para el MVP es más simple de editar y entender siendo nueva/o en Godot.
## Más adelante, si quieres, esto se puede migrar a archivos .tres (Resources)
## para poder editarlos visualmente desde el editor de Godot.
##
## Campos de cada personaje:
##   id              -> identificador único (String, sin espacios)
##   nombre          -> nombre que se muestra en pantalla
##   es_menor        -> true si es menor de edad (dispara el dilema moral)
##   especial        -> true si tiene diálogo extra que revela historia
##   puede_repetir   -> true si este personaje SÍ puede aparecer 2 veces el mismo día
##   precio_base     -> precio "de lista" de una michelada (se multiplica según calidad)
##   quiere_michelada-> false si el personaje NO compra (solo viene a hablar)
##   pedido_texto    -> frase que describe cómo la quiere (se muestra en el minijuego)
##   receta          -> valores ideales 0-10 de clamato/limon/chile + sal_borde (bool)
##   dialogo         -> array de posibles frases si especial == true

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
		"pedido_texto": "Como siempre, m'ija/o: bien equilibradita.",
		"receta": {"clamato": 5, "limon": 5, "chile": 4, "sal_borde": true},
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
		"pedido_texto": "Bien cargada y picosa, porfa.",
		"receta": {"clamato": 6, "limon": 3, "chile": 8, "sal_borde": true},
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
		"pedido_texto": "Suave de chile, ando delicada del estómago.",
		"receta": {"clamato": 7, "limon": 6, "chile": 2, "sal_borde": false},
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
		"pedido_texto": "Con harta sal en el borde, así la disfruto.",
		"receta": {"clamato": 5, "limon": 4, "chile": 6, "sal_borde": true},
		"dialogo": [],
	},
]


func get_personaje(id: String) -> Dictionary:
	for p in personajes:
		if p["id"] == id:
			return p
	return {}
