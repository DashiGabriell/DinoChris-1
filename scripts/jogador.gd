extends CharacterBody3D
## T-Rex do jogador: anda apenas quando o jogador manda,
## desvia com o analógico, pula e ruge.
## A missão é comer bem: cada comida pega conta para o nível atual.

signal comida_coletada(no_nivel: int, meta: int, nivel: int, total: int)
signal subiu_nivel(nivel: int)
signal reiniciou

## Quantas comidas saudáveis o dino precisa por nível (sobe 1 a cada nível).
const META_BASE: int = 8
const META_MAXIMA: int = 15

@export var velocidade_frente: float = 6.0
@export var velocidade_tras: float = 3.5
@export var velocidade_lateral: float = 7.0
@export var forca_pulo: float = 7.5
@export var limite_lateral: float = 4.0
@export var limite_tras: float = 1.5
@export var tempo_rugido: float = 0.45

@onready var modelo: Node3D = $Modelo
@onready var rugido_area: Area3D = $RugidoArea
@onready var camera_rig: Node3D = $CameraRig

var gravidade: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var posicao_inicial: Vector3
var checkpoint: Vector3
var nivel: int = 1
var comida_no_nivel: int = 0
var total_comida: int = 0

var _rugindo: bool = false
var _tempo_animacao: float = 0.0
var _tempo_passo: float = 0.0
var _base_modelo: Vector3
var _movendo: bool = false


func _ready() -> void:
	posicao_inicial = global_position
	checkpoint = posicao_inicial
	_base_modelo = modelo.position
	rugido_area.monitoring = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = forca_pulo
		Sons.tocar("pulo")
		modelo.scale = Vector3(1.12, 0.85, 1.12)
		create_tween().tween_property(modelo, "scale", Vector3.ONE, 0.2)

	var direcao: float = Input.get_axis("mover_esquerda", "mover_direita")
	var frente: float = Input.get_axis("mover_tras", "mover_frente")
	var velocidade_z: float = velocidade_frente if frente >= 0.0 else velocidade_tras

	velocity.x = direcao * velocidade_lateral
	velocity.z = -frente * velocidade_z
	_movendo = Vector2(velocity.x, velocity.z).length() > 0.1

	move_and_slide()

	# Rede de seguranca: nunca sai do corredor nem recua alem do inicio.
	global_position.x = clampf(global_position.x, -limite_lateral, limite_lateral)
	global_position.z = minf(global_position.z, posicao_inicial.z + limite_tras)

	_quebrar_no_impacto()
	_animar(delta)

	if Input.is_action_just_pressed("rugido") and not _rugindo:
		executar_rugido()


func _quebrar_no_impacto() -> void:
	for i in get_slide_collision_count():
		var alvo := get_slide_collision(i).get_collider() as Node3D
		if alvo and alvo.is_in_group("quebravel") and alvo.has_method("quebrar"):
			alvo.call("quebrar")


func executar_rugido() -> void:
	if _rugindo:
		return
	_rugindo = true

	Sons.tocar("rugido")
	camera_rig.call("tremer", 0.18, 0.3)
	_onda_de_choque()

	# Area3D sempre monitorando + consulta dos corpos sobrepostos:
	# funciona mesmo para caixas que ja estavam dentro do raio.
	for corpo in rugido_area.get_overlapping_bodies():
		if corpo.is_in_group("quebravel") and corpo.has_method("quebrar"):
			corpo.call("quebrar")

	await get_tree().create_timer(tempo_rugido).timeout
	if not is_instance_valid(self):
		return
	_rugindo = false


func _onda_de_choque() -> void:
	var onda := MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.75
	anel.outer_radius = 1.0
	onda.mesh = anel

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.9, 0.35, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1, 0.8, 0.2)
	material.emission_energy_multiplier = 2.0
	onda.material_override = material

	get_parent().add_child(onda)
	onda.global_position = rugido_area.global_position
	onda.rotation_degrees = Vector3(90, 0, 0)
	onda.scale = Vector3(0.5, 0.5, 0.5)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(onda, "scale", Vector3(2.4, 2.4, 2.4), 0.45)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(onda.queue_free)


func _animar(delta: float) -> void:
	_tempo_animacao += delta
	if not is_on_floor():
		modelo.position.y = _base_modelo.y
		modelo.rotation.z = 0.0
		return

	if not _movendo:
		# Parado esperando o jogador: so uma respirada leve.
		modelo.position.y = _base_modelo.y + sin(_tempo_animacao * 2.0) * 0.02
		modelo.rotation.z = 0.0
		_tempo_passo = 0.0
		return

	modelo.position.y = _base_modelo.y + absf(sin(_tempo_animacao * 9.0)) * 0.1
	modelo.rotation.z = sin(_tempo_animacao * 9.0) * 0.03
	_tempo_passo += delta
	if _tempo_passo >= 0.32:
		_tempo_passo = 0.0
		Sons.tocar("passo", -8.0, randf_range(0.9, 1.1))


func coletar(_tipo: int = 0) -> void:
	total_comida += 1
	comida_no_nivel += 1

	if comida_no_nivel >= meta_nivel():
		comida_no_nivel = 0
		nivel += 1
		Sons.tocar("nivel")
		camera_rig.call("tremer", 0.12, 0.25)
		comida_coletada.emit(comida_no_nivel, meta_nivel(), nivel, total_comida)
		subiu_nivel.emit(nivel)
	else:
		comida_coletada.emit(comida_no_nivel, meta_nivel(), nivel, total_comida)


func meta_nivel() -> int:
	return mini(META_BASE + (nivel - 1), META_MAXIMA)


func definir_checkpoint(posicao: Vector3) -> void:
	checkpoint = posicao


func voltar_ao_checkpoint() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	Sons.tocar("pulo", -4.0, 0.7)


func reiniciar() -> void:
	checkpoint = posicao_inicial
	global_position = posicao_inicial
	velocity = Vector3.ZERO
	reiniciou.emit()
