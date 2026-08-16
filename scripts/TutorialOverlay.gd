class_name TutorialOverlay
extends Control
## TutorialOverlay.gd
## -------------------
## Tutorial estilo "novela visual" (como Ren'py): Nancy, la hermana del
## jugador, le explica paso a paso cómo se prepara una michelada usando un
## cuadro de diálogo con su retrato y un botón de "Siguiente". Se muestra
## automáticamente al empezar la partida, encima de todo lo demás, y
## bloquea la interacción con el juego de fondo (Main._process no corre
## mientras tanto, porque jornada_activa sigue en false hasta que el
## tutorial termina y Main.gd llama a _iniciar_dia()).

signal tutorial_terminado

@onready var texto_label: Label = $DialogBox/TextoLabel
@onready var paso_label: Label = $DialogBox/PasoLabel
@onready var nombre_label: Label = $DialogBox/NombreLabel
@onready var siguiente_btn: Button = $DialogBox/SiguienteBtn
@onready var saltar_btn: Button = $DialogBox/SaltarBtn

## Cada paso es una frase que dice Nancy. Están alineados 1 a 1 con las
## reglas de orden de VasoMichelada.gd (_validar_orden), así que si cambian
## el orden allá, hay que actualizar el texto aquí también.
var pasos: Array = [
	"¡Hola! Soy Nancy, tu hermana. Antes de que te quedes tú sola/o a cargo del puesto, déjame enseñarte cómo se prepara una buena michelada.",
	"Paso 1: primero se moja el borde del vaso con LIMÓN. Si el cliente quiere, después se escarcha con SAL o con UNO de los dos escarchados (café o azul). Nunca los tres juntos, ¿eh?",
	"Paso 2: ya con el borde listo —o sin nada, si así lo pide el cliente— se agrega el HIELO.",
	"Paso 3: después del hielo puedes poner salsa de tomate, chile líquido, o los dos. Le dan sabor, color y su toque picoso.",
	"Paso 4: al final va la CERVEZA (o la cerveza azul, para los que quieren algo distinto). Ojo: en cuanto sirves la cerveza, ¡la michelada ya quedó lista y no se le puede agregar nada más!",
	"Una regla de la casa muy importante: si el cliente es MENOR DE EDAD, jamás le sirvas cerveza. Prepárale una michelada sin alcohol y va a quedar igual de contento/a.",
	"¡Listo! Ya sabes todo lo que necesitas. Ahora sí... ¡a atender el puesto! Buena suerte.",
]

var indice := 0


func _ready() -> void:
	siguiente_btn.pressed.connect(_on_siguiente_pressed)
	saltar_btn.pressed.connect(_on_saltar_pressed)
	nombre_label.text = "Nancy"
	mostrar_paso(0)


## Llamar desde Main.gd si se quiere reiniciar el tutorial manualmente
## (por ejemplo, desde un botón de "Ver tutorial" en un menú futuro).
func mostrar() -> void:
	visible = true
	mostrar_paso(0)


func mostrar_paso(i: int) -> void:
	indice = i
	texto_label.text = pasos[i]
	paso_label.text = "Paso %d de %d" % [i + 1, pasos.size()]
	siguiente_btn.text = "¡Empezar!" if i == pasos.size() - 1 else "Siguiente ▶"
	saltar_btn.visible = i < pasos.size() - 1


func _on_siguiente_pressed() -> void:
	if indice >= pasos.size() - 1:
		_terminar()
	else:
		mostrar_paso(indice + 1)


func _on_saltar_pressed() -> void:
	_terminar()


func _terminar() -> void:
	visible = false
	tutorial_terminado.emit()
