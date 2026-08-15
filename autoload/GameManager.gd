extends Node
## GameManager
## -----------
## Este es el "cerebro" del juego. Vive durante toda la partida (es un
## Autoload / Singleton) y guarda todo lo que importa: dinero, día actual,
## si pagaste o no la extorsión, y las "flags" (banderas) de decisiones
## morales que determinan el final.
##
## IMPORTANTE sobre finales irreversibles:
## En Godot no existe un sistema especial para "finales irreversibles",
## simplemente se logra con lógica normal: en cuanto una condición se
## cumple, cambiamos de escena a la escena de Ending y YA NO dejamos que
## el jugador regrese a jugar esa partida (solo puede reiniciar desde cero).
## Es 100% viable y es el mismo patrón que usan juegos como Papers, Please.

signal money_changed(new_amount: int)
signal day_changed(new_day: int)
signal game_over(ending_id: String)

const TOTAL_DAYS := 7
const DAILY_EXTORTION := 150 # "derecho de piso" que se cobra cada noche
const CLIENTES_MIN := 3
const CLIENTES_MAX := 10

var current_day := 1
var money := 0
var clientes_por_dia := 6 # cuántos clientes llegan; sube o baja según la calidad del día anterior

var extortion_paid_days: Array = []   # días en que sí pagaste
var extortion_missed_days: Array = [] # días en que NO pagaste

var last_ending := "" # aquí guardamos el id del final para que Ending.tscn lo lea

# Banderas de decisiones importantes. Se usan para decidir el final.
var flags := {
	"vendio_a_menores": false,
	"veces_vendio_a_menores": 0,
	"nunca_pago_extorsion": true,
	"ayudo_a_personaje_especial": false,
}

# Historial simple: cuántas veces apareció cada personaje cada día.
# Ejemplo: {1: {"chavo_prepa": 1, "sra_lupe": 2}, 2: {...}}
var historial_dia: Dictionary = {}


func _ready() -> void:
	_reset_dia_historial()


func reset() -> void:
	# Se llama cuando el jugador reinicia una partida nueva.
	current_day = 1
	money = 0
	clientes_por_dia = 6
	extortion_paid_days.clear()
	extortion_missed_days.clear()
	last_ending = ""
	flags = {
		"vendio_a_menores": false,
		"veces_vendio_a_menores": 0,
		"nunca_pago_extorsion": true,
		"ayudo_a_personaje_especial": false,
	}
	historial_dia.clear()
	_reset_dia_historial()
	CustomerSpawner.personajes_que_repitieron_2_ayer.clear()


func _reset_dia_historial() -> void:
	historial_dia[current_day] = {}


func registrar_venta(char_id: String, monto: int, es_menor: bool) -> void:
	add_money(monto)
	if es_menor:
		flags["vendio_a_menores"] = true
		flags["veces_vendio_a_menores"] += 1

	if not historial_dia.has(current_day):
		historial_dia[current_day] = {}
	historial_dia[current_day][char_id] = historial_dia[current_day].get(char_id, 0) + 1


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func pagar_extorsion() -> bool:
	if money >= DAILY_EXTORTION:
		money -= DAILY_EXTORTION
		extortion_paid_days.append(current_day)
		flags["nunca_pago_extorsion"] = false
		money_changed.emit(money)
		return true
	return false


func no_pagar_extorsion() -> void:
	extortion_missed_days.append(current_day)


func ajustar_clientes_por_dia(calidad_promedio: float) -> void:
	# Buena fama = más clientes al día siguiente; mala fama = menos.
	if calidad_promedio >= 0.75:
		clientes_por_dia = min(clientes_por_dia + 1, CLIENTES_MAX)
	elif calidad_promedio < 0.4:
		clientes_por_dia = max(clientes_por_dia - 1, CLIENTES_MIN)
	# Entre 0.4 y 0.75 se queda igual (calidad "normal").


func avanzar_dia() -> String:
	# Devuelve "" si el juego continúa, o un ending_id si terminó.
	var ending := revisar_finales_irreversibles()
	if ending != "":
		last_ending = ending
		game_over.emit(ending)
		return ending

	current_day += 1
	_reset_dia_historial()
	day_changed.emit(current_day)

	if current_day > TOTAL_DAYS:
		var final_id := calcular_final_final()
		last_ending = final_id
		game_over.emit(final_id)
		return final_id

	return ""


func revisar_finales_irreversibles() -> String:
	# Ejemplo de final irreversible #1:
	# No pagar la extorsión dos días SEGUIDOS = destruyen el puesto.
	if extortion_missed_days.size() >= 2:
		var ultimos := extortion_missed_days.slice(extortion_missed_days.size() - 2, extortion_missed_days.size())
		if ultimos[1] - ultimos[0] == 1:
			return "final_puesto_destruido"

	# Ejemplo de final irreversible #2:
	# Vender a menores 3 veces o más en toda la partida = clausura.
	if flags["veces_vendio_a_menores"] >= 3:
		return "final_clausura_autoridades"

	return ""


func calcular_final_final() -> String:
	# Se evalúa solo si el jugador sobrevive los 7 días sin activar
	# ningún final irreversible antes.
	if flags["nunca_pago_extorsion"]:
		return "final_libre_pero_perseguido"
	if flags["vendio_a_menores"]:
		return "final_exito_con_culpa"
	if flags["ayudo_a_personaje_especial"]:
		return "final_comunidad"
	return "final_sobrevivio"
