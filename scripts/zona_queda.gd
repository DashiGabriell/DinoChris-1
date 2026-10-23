extends Area3D
## Zona de queda: devolve o dino ao último checkpoint, sem game over.


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _ao_entrar(corpo: Node3D) -> void:
	if corpo.has_method("voltar_ao_checkpoint"):
		corpo.call("voltar_ao_checkpoint")
