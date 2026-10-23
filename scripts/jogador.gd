extends CharacterBody3D
## T-Rex do jogador: anda apenas quando o jogador manda,
## desvia com o analógico, pula, morde e ruge.
## A missão é comer bem: cada comida pega conta para o nível atual.
##
## Controles de ataque (dois comandos separados):
##   rugido  -> onda de choque que quebra as caixas em volta
##   mordida -> morde a caixa que estiver logo à frente
##
## As animações vêm do GLB rigado (trexChrisAnim.glb) e são tocadas por um
## AnimationPlayer dentro do nó Modelo: Idle, Walk, Run, Jump, Attack e Roar.

signal comida_coletada(no_nivel: int, meta: int, nivel: int, total: int)
signal subiu_nivel(nivel: int)
signal reiniciou

## Quantas comidas saudáveis o dino precisa por nível (sobe 1 a cada nível).
const META_BASE: int = 8
const META_MAXIMA: int = 15

## Velocidade usada como referência para a animação de corrida (m/s).
## Fica abaixo da velocidade real de propósito: pernas mais rápidas disfarçam
## melhor o deslize dos pés do que um ciclo lento em velocidade alta.
const VELOCIDADE_CORRIDA: float = 4.5
const VELOCIDADE_CAMINHADA: float = 2.4
const DISTANCIA_MORDIDA: float = 3.6

@export var velocidade_frente: float = 6.0
@export var velocidade_tras: float = 3.5
@export var velocidade_lateral: float = 7.0
@export var forca_pulo: float = 7.5
@export var limite_lateral: float = 4.0
@export var limite_tras: float = 1.5
@export var tempo_rugido: float = 0.45

@onready var modelo: Node3D = $Modelo
@onready var anim: AnimationPlayer = $Modelo/AnimationPlayer
@onready var rugido_area: Area3D = $RugidoArea
@onready var camera_rig: Node3D = $CameraRig

var gravidade: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var posicao_inicial: Vector3
var checkpoint: Vector3
var nivel: int = 1
var comida_no_nivel: int = 0
var total_comida: int = 0

var _rugindo: bool = false
var _acao: String = ""
var _tempo_passo: float = 0.0
var _movendo: bool = false


func _ready() -> void:
	posicao_inicial = global_position
	checkpoint = posicao_inicial
	rugido_area.monitoring = true
	_preparar_animacoes()


# ---------------------------------------------------------------- animação
func _preparar_animacoes() -> void:
	if anim == null:
		push_warning("AnimationPlayer nao encontrado em Modelo")
		return
	for nome in ["Idle", "Walk", "Run"]:
		if anim.has_animation(nome):
			anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	for nome in ["Jump", "Attack", "Roar"]:
		if anim.has_animation(nome):
			anim.get_animation(nome).loop_mode = Animation.LOOP_NONE
	anim.animation_finished.connect(_ao_terminar_animacao)
	anim.play("Idle", 0.0)


func _tocar(nome: String, mistura: float = 0.18) -> void:
	if anim == null or not anim.has_animation(nome):
		return
	if anim.current_animation == nome:
		return
	anim.play(nome, mistura)


func _iniciar_acao(nome: String, velocidade_anim: float = 1.0, mistura: float = 0.06) -> void:
	if anim == null or not anim.has_animation(nome):
		return
	_acao = nome
	anim.speed_scale = velocidade_anim
	anim.play(nome, mistura)


func _ao_terminar_animacao(nome: String) -> void:
	if nome != _acao:
		return
	_acao = ""
	if anim != null:
		anim.speed_scale = 1.0
	_atualizar_animacao(0.0)


func _atualizar_animacao(delta: float) -> void:
	if anim == null:
		return

	# No ar sem ação declarada (caiu de uma beirada): segura a pose aérea.
	if not is_on_floor():
		if _acao == "":
			_acao = "queda"
			anim.speed_scale = 1.0
			anim.play("Jump", 0.1)
			anim.seek(0.45, true)
			anim.speed_scale = 0.0
		return
	if _acao == "queda":
		_acao = ""
		anim.speed_scale = 1.0

	if _acao != "":
		return

	var velocidade: float = Vector2(velocity.x, velocity.z).length()
	if velocidade < 0.2:
		_tocar("Idle")
		anim.speed_scale = 1.0
		_tempo_passo = 0.0
		return

	var correndo: bool = velocidade > 4.5
	_tocar("Run" if correndo else "Walk")
	var referencia: float = VELOCIDADE_CORRIDA if correndo else VELOCIDADE_CAMINHADA
	anim.speed_scale = clampf(velocidade / referencia, 0.65, 1.6)

	# passos sincronizados com o ciclo
	_tempo_passo += delta * (velocidade / referencia)
	if _tempo_passo >= 0.32:
		_tempo_passo = 0.0
		Sons.tocar("passo", -8.0, randf_range(0.9, 1.1))


# ---------------------------------------------------------------- laço
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("pular") and is_on_floor() and _acao == "":
		velocity.y = forca_pulo
		Sons.tocar("pulo")
		# 1.35x deixa o clipe com a mesma duração do pulo físico (~0.62 s)
		_iniciar_acao("Jump", 1.35)

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
	_atualizar_animacao(delta)

	if Input.is_action_just_pressed("mordida") and _acao == "" and is_on_floor():
		_morder(_alvo_na_frente())
	elif Input.is_action_just_pressed("rugido") and not _rugindo and _acao == "":
		executar_rugido()


func _quebrar_no_impacto() -> void:
	for i in get_slide_collision_count():
		var alvo := get_slide_collision(i).get_collider() as Node3D
		if alvo and alvo.is_in_group("quebravel") and alvo.has_method("quebrar"):
			alvo.call("quebrar")


# ---------------------------------------------------------------- ataque
func _alvo_na_frente() -> Node3D:
	var frente := -global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var melhor: Node3D = null
	var melhor_distancia: float = DISTANCIA_MORDIDA
	for corpo in get_tree().get_nodes_in_group("quebravel"):
		var alvo := corpo as Node3D
		if alvo == null:
			continue
		var diferenca := alvo.global_position - global_position
		diferenca.y = 0.0
		var distancia := diferenca.length()
		if distancia > melhor_distancia or distancia < 0.01:
			continue
		if diferenca.normalized().dot(frente) < 0.35:
			continue
		melhor = alvo
		melhor_distancia = distancia
	return melhor


func _morder(alvo: Node3D = null) -> void:
	if _acao != "" or not is_on_floor():
		return
	# a animação começa sempre; se não houver alvo, é uma mordida no ar
	_iniciar_acao("Attack", 1.1)
	if alvo == null:
		return
	Sons.tocar("caixa", -4.0, 1.35)
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(alvo) and alvo.has_method("quebrar"):
		alvo.call("quebrar")
		camera_rig.call("tremer", 0.1, 0.2)


func executar_rugido() -> void:
	if _rugindo:
		return
	_rugindo = true
	_iniciar_acao("Roar", 1.2)

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


# ---------------------------------------------------------------- progresso
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
