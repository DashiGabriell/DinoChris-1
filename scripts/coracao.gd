extends Area3D
## Coração solto por uma caixa: cura uma vida se o dino ainda não estiver no máximo.

@export var tempo_vida: float = 12.0
@export var atraso_coleta: float = 0.35

@onready var visual: Node3D = $Visual

var _base_y: float = 0.0
var _tempo: float = 0.0
var _coletado: bool = false
var _pode_coletar: bool = false


func _ready() -> void:
	_base_y = position.y
	monitoring = false
	body_entered.connect(_ao_entrar)
	get_tree().create_timer(atraso_coleta, false).timeout.connect(_liberar_coleta)
	get_tree().create_timer(tempo_vida, false).timeout.connect(_expirar)

	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_y + 0.65, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _coletado:
		return
	_tempo += delta
	visual.position.y = sin(_tempo * 2.2) * 0.1


func _liberar_coleta() -> void:
	if _coletado or not is_instance_valid(self):
		return
	_pode_coletar = true
	monitoring = true
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			_ao_entrar(corpo)
			break


func _ao_entrar(corpo: Node3D) -> void:
	if _coletado or not _pode_coletar or not corpo.is_in_group("jogador"):
		return
	_coletado = true
	set_deferred("monitoring", false)

	if corpo.has_method("ganhar_vida"):
		corpo.call("ganhar_vida")
	Sons.tocar_em("coletar", global_position, 0.0, 1.35)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE * 1.5, 0.15)
	tween.tween_property(visual, "position:y", visual.position.y + 0.25, 0.15)
	tween.chain().tween_callback(queue_free)


func _expirar() -> void:
	if _coletado:
		return
	_coletado = true
	queue_free()
