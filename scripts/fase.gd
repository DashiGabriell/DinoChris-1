extends Node3D
## Fase infinita: quem monta o caminho é o nó Corredor (scripts/corredor.gd).
## Aqui mora só a rede de segurança do anti-softlock: se o jogador insistir no
## avanço e o dino não sair do lugar, ele volta ao último ponto seguro.

@onready var jogador: CharacterBody3D = $TRex

var _ultimo_z: float = 0.0
var _tempo_parado: float = 0.0


func _ready() -> void:
	_ultimo_z = jogador.global_position.z


func _physics_process(delta: float) -> void:
	var z: float = jogador.global_position.z
	var empurrando: bool = Input.is_action_pressed("mover_frente")

	if empurrando and jogador.global_position.y > -1.0 and absf(z - _ultimo_z) < 0.03:
		_tempo_parado += delta
		if _tempo_parado > 3.0:
			_tempo_parado = 0.0
			jogador.call("voltar_ao_checkpoint")
	else:
		_tempo_parado = 0.0
		_ultimo_z = z
