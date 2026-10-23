extends Area3D
## Fim do corredor: recomeça a fase (loop infinito, sem tela de game over).

var _usado: bool = false


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _ao_entrar(corpo: Node3D) -> void:
	if _usado or not corpo.has_method("reiniciar"):
		return
	_usado = true

	Sons.tocar("coletar", -2.0, 1.4)
	corpo.call("reiniciar")

	await get_tree().create_timer(1.5).timeout
	_usado = false
