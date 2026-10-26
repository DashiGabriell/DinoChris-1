extends Area3D
## Tronco rolante: desce o corredor na direção do dino e obriga um pulo.
## Bater de frente chama levar_tronco() no jogador (empurrão + dano) e
## desmancha o tronco em lascas; pular por cima deixa o tronco passar.

@export var velocidade: float = 7.0
@export var raio: float = 0.42
## Distância atrás do jogador em que o tronco é liberado (m).
@export var distancia_limpeza: float = 12.0

@onready var visual: Node3D = $Visual

var _jogador: Node3D = null
var _atingido: bool = false


func _ready() -> void:
	body_entered.connect(_ao_entrar)
	_jogador = get_tree().get_first_node_in_group("jogador") as Node3D


func _physics_process(delta: float) -> void:
	if _atingido:
		return

	global_position.z += velocidade * delta
	visual.rotate_x((velocidade / maxf(raio, 0.01)) * delta)

	if _jogador != null and global_position.z > _jogador.global_position.z + distancia_limpeza:
		queue_free()


func _ao_entrar(corpo: Node3D) -> void:
	if _atingido or not corpo.is_in_group("jogador"):
		return
	_atingido = true

	if corpo.has_method("levar_tronco"):
		corpo.call("levar_tronco")

	Sons.tocar_em("caixa", global_position, 2.0, randf_range(0.62, 0.78))
	_explodir()


func _explodir() -> void:
	var pai := get_parent()
	if pai != null:
		for i in 7:
			_soltar_lasca(pai)
	queue_free()


func _soltar_lasca(pai: Node) -> void:
	var lasca := RigidBody3D.new()
	lasca.collision_layer = 0
	lasca.collision_mask = 1

	var malha := MeshInstance3D.new()
	var cubo := BoxMesh.new()
	var lado := randf_range(0.16, 0.3)
	cubo.size = Vector3(lado, lado * randf_range(1.6, 3.2), lado)
	malha.mesh = cubo

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.29, 0.13).lerp(Color(0.3, 0.17, 0.07), randf())
	material.roughness = 1.0
	malha.material_override = material
	lasca.add_child(malha)

	var colisao := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = cubo.size
	colisao.shape = forma
	lasca.add_child(colisao)

	pai.add_child(lasca)
	lasca.global_position = global_position + Vector3(
		randf_range(-2.0, 2.0),
		randf_range(-0.1, 0.4),
		randf_range(-0.2, 0.3)
	)
	lasca.linear_velocity = Vector3(
		randf_range(-3.5, 3.5),
		randf_range(2.2, 5.2),
		randf_range(1.0, 4.0)
	)
	lasca.angular_velocity = Vector3(
		randf_range(-9.0, 9.0),
		randf_range(-9.0, 9.0),
		randf_range(-9.0, 9.0)
	)

	var timer := Timer.new()
	timer.wait_time = 1.6
	timer.one_shot = true
	lasca.add_child(timer)
	timer.timeout.connect(lasca.queue_free)
	timer.start()
