extends Node3D
## Tremor de camera aplicado no CameraRig (o SpringArm3D controla a Camera3D).

var _intensidade: float = 0.0
var _duracao: float = 0.0
var _tempo: float = 0.0
var _base: Vector3


func _ready() -> void:
	_base = position


func tremer(intensidade: float = 0.15, duracao: float = 0.25) -> void:
	_intensidade = intensidade
	_duracao = duracao
	_tempo = 0.0


func _process(delta: float) -> void:
	if _tempo >= _duracao:
		return

	_tempo += delta
	var forca := _intensidade * maxf(0.0, 1.0 - _tempo / _duracao)
	position = _base + Vector3(
		randf_range(-forca, forca),
		randf_range(-forca, forca),
		0.0
	)

	if _tempo >= _duracao:
		position = _base
