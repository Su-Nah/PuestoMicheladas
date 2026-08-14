extends Control
## Ending.gd
## ---------
## Muestra el final correspondiente al "ending_id" que quedó guardado en
## GameManager.last_ending. Aquí es donde se nota que el final es
## IRREVERSIBLE: la única opción del jugador es "Jugar de nuevo", que
## reinicia todo el estado desde cero (GameManager.reset()).

@onready var titulo: Label = $Titulo
@onready var texto: Label = $Texto
@onready var reiniciar_btn: Button = $ReiniciarBtn

# Textos de cada final. Puedes editar/alargar esto libremente.
var finales := {
	"final_puesto_destruido": {
		"titulo": "Final: El puesto fue destruido",
		"texto": "Dejaste de pagar el derecho de piso dos días seguidos. Una noche llegaron y destruyeron todo. No hay vuelta atrás.",
	},
	"final_clausura_autoridades": {
		"titulo": "Final: Clausura",
		"texto": "Vender alcohol a menores demasiadas veces llamó la atención equivocada. Las autoridades clausuraron tu puesto.",
	},
	"final_libre_pero_perseguido": {
		"titulo": "Final: Libre, pero con miedo",
		"texto": "Nunca pagaste el derecho de piso. Sobreviviste los 7 días, pero sabes que te seguirán buscando.",
	},
	"final_exito_con_culpa": {
		"titulo": "Final: Éxito con culpa",
		"texto": "Lograste sobrevivir los 7 días, pero a costa de vender alcohol a quien no debías. El dinero no borra esa culpa.",
	},
	"final_comunidad": {
		"titulo": "Final: Apoyo de la comunidad",
		"texto": "Construiste lazos con la gente del barrio. El camino fue difícil, pero no estás solo/a.",
	},
	"final_sobrevivio": {
		"titulo": "Final: Sobreviviste",
		"texto": "Completaste los 7 días haciendo lo que pudiste. Ni héroe ni villano, solo alguien que sobrevivió.",
	},
}


func _ready() -> void:
	reiniciar_btn.pressed.connect(_on_reiniciar_pressed)

	var id: String = GameManager.last_ending
	var data: Dictionary = finales.get(id, {"titulo": "Fin de la partida", "texto": "..."})
	titulo.text = data["titulo"]
	texto.text = data["texto"]


func _on_reiniciar_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
