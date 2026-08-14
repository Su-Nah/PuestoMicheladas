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
##   id             -> identificador único (String, sin espacios)
##   nombre         -> nombre que se muestra en pantalla
##   es_menor       -> true si es menor de edad (dispara el dilema moral)
##   especial       -> true si tiene diálogo extra que revela historia
##   puede_repetir  -> true si este personaje SÍ puede aparecer 2 veces el mismo día
##   precio_base    -> cuánto paga por una michelada
##   dialogo        -> array de posibles frases si especial == true

var personajes: Array = [
	{
		"id": "don_ramiro",
		"nombre": "Don Ramiro",
		"es_menor": false,
		"especial": true,
		"puede_repetir": true,
		"precio_base": 35,
		"dialogo": [
			"Antes este puesto lo llevaba mi compadre... hasta que dejó de pagar la cuota.",
			"Cuídate, aquí las cosas se ponen feas para el que no coopera.",
		],
	},
	{
		"id": "chavo_prepa",
		"nombre": "Chavo de prepa",
		"es_menor": true,
		"especial": false,
		"puede_repetir": false,
		"precio_base": 40,
		"dialogo": [],
	},
	{
		"id": "sra_lupe",
		"nombre": "Señora Lupe",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 30,
		"dialogo": [],
	},
	{
		"id": "policia_erick",
		"nombre": "Oficial Erick",
		"es_menor": false,
		"especial": true,
		"puede_repetir": false,
		"precio_base": 0,
		"dialogo": [
			"Sé lo que pasa aquí con el cobro de piso... si algún día quieres hablar, aquí ando.",
		],
	},
	{
		"id": "obrero_tony",
		"nombre": "Tony, el obrero",
		"es_menor": false,
		"especial": false,
		"puede_repetir": true,
		"precio_base": 32,
		"dialogo": [],
	},
]


func get_personaje(id: String) -> Dictionary:
	for p in personajes:
		if p["id"] == id:
			return p
	return {}
