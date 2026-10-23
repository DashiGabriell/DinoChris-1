extends Area3D
## Coletável (carne dourada): gira, flutua e some com som ao ser pego.

@onready var visual: Node3D = $Visual

var _base_y: float = 0.0
var _tempo: float = 0.0
var _coletado: bool = false


func _ready() -> void:
	_base_y = visual.position.y
	body_entered.connect(_ao_entrar)


func _process(delta: float) -> void:
	_tempo += delta
	visual.rotation.y += delta * 2.5
	visual.position.y = _base_y + sin(_tempo * 2.0) * 0.12


func _ao_entrar(corpo: Node3D) -> void:
	if _coletado or not corpo.is_in_group("jogador"):
		return
	_coletado = true

	Sons.tocar_em("coletar", global_position, 0.0, randf_range(0.95, 1.08))
	if corpo.has_method("coletar"):
		corpo.call("coletar")
	queue_free()
