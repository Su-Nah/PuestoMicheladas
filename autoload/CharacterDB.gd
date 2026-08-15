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
##   es_menor        -> true si es menor de edad (dispara el dilema moral SOLO
##                      si además la michelada que le sirves lleva cerveza)
##   especial        -> true si tiene diálogo extra que revela historia
##   puede_repetir   -> true si este personaje SÍ puede aparecer 2 veces el mismo día
##   precio_base     -> precio "de lista" de una michelada (se multiplica según calidad)
##   quiere_michelada-> false si el personaje NO compra (solo viene a hablar)
##   pedido_texto    -> frase que describe cómo la quiere (se muestra en el minijuego)
##   receta          -> Dictionary con los ingredientes que SÍ quiere, en true.
##                      Ids válidos: limon, sal, escarchado_cafe, escarchado_azul,
##                      hielo, salsa_tomate, chile_liquido, cerveza, cerveza_azul.
##                      Cualquier ingrediente que no aparezca se interpreta como
##                      "no lo quiere" (ver Main.gd -> _calcular_calidad).
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
		"paciencia": 18.0,
		"receta": {"limon": true, "sal": true, "hielo": true, "salsa_tomate": true, "cerveza": true},
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
		"paciencia": 10.0,
		# OJO: pide cerveza siendo menor de edad. Este es justo el dilema:
		# tú decides si se la sirves con cerveza o le preparas una versión
		# sin alcohol (lo cual bajará la "calidad" pero evita el problema legal).
		"receta": {"limon": true, "escarchado_cafe": true, "hielo": true, "chile_liquido": true, "cerveza": true},
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
		"pedido_texto": "Suave de chile, ando delicada del estómago. Sin cerveza, de esas preparadas.",
		"paciencia": 14.0,
		"receta": {"limon": true, "sal": true, "hielo": true, "salsa_tomate": true},
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
		"pedido_texto": "Con harta sal en el borde, así la disfruto.",
		"paciencia": 13.0,
		"receta": {"limon": true, "sal": true, "hielo": true, "salsa_tomate": true, "cerveza": true},
		"dialogo": [],
	},
]


func get_personaje(id: String) -> Dictionary:
	for p in personajes:
		if p["id"] == id:
			return p
	return {}
