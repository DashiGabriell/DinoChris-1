extends Area3D
## Checkpoint: guarda a posição para o respawn e acende quando ativado.

@onready var anel: MeshInstance3D = $Anel

var _ativo: bool = false
var _tempo: float = 0.0


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _process(delta: float) -> void:
	_tempo += delta
	anel.position.y = 1.4 + sin(_tempo * 2.0) * 0.08


func _ao_entrar(corpo: Node3D) -> void:
	if _ativo or not corpo.has_method("definir_checkpoint"):
		return
	_ativo = true

	corpo.call("definir_checkpoint", Vector3(global_position.x, 0.1, global_position.z))

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 1.0, 0.45)
	material.emission_enabled = true
	material.emission = Color(0.35, 1.0, 0.45)
	material.emission_energy_multiplier = 2.0
	anel.material_override = material
	Sons.tocar_em("coletar", global_position, -2.0, 0.8)
