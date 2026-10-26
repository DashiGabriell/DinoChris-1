extends Node3D
## Diorama vivo da tela inicial: T-Rex ocioso, arvores low-poly e camera com respiracao.

const CENA_ARVORES := "res://assets/modelos/props/arvores.glb"

@onready var camera: Camera3D = $Camera3D
@onready var dino: Node3D = $TRex

var _tempo: float = 0.0
var _cam_base: Vector3
var _cam_rot_base: Vector3
var _dino_rot_base: Vector3


func _ready() -> void:
	_cam_base = camera.position
	camera.look_at(Vector3(0.9, 1.35, 0.0))
	_cam_rot_base = camera.rotation
	_dino_rot_base = dino.rotation
	_preparar_dino()
	_plantar_arvores()


func _process(delta: float) -> void:
	_tempo += delta
	var efeito := 0.35 if Dados.modo_calmo else 1.0
	camera.position = _cam_base + Vector3(
		sin(_tempo * 0.22) * 0.16 * efeito,
		sin(_tempo * 0.31) * 0.06 * efeito,
		0.0
	)
	camera.rotation = _cam_rot_base + Vector3(
		sin(_tempo * 0.19) * 0.008 * efeito,
		sin(_tempo * 0.14) * 0.012 * efeito,
		0.0
	)
	if is_instance_valid(dino):
		dino.rotation = _dino_rot_base + Vector3(0.0, sin(_tempo * 0.4) * 0.018 * efeito, 0.0)


func _preparar_dino() -> void:
	var anim := _achar_animation(dino)
	if anim == null:
		return
	if anim.has_animation("Idle"):
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")


func _achar_animation(no: Node) -> AnimationPlayer:
	if no is AnimationPlayer:
		return no as AnimationPlayer
	for filho in no.get_children():
		var achado := _achar_animation(filho)
		if achado != null:
			return achado
	return null


func _plantar_arvores() -> void:
	var cena := load(CENA_ARVORES) as PackedScene
	if cena == null:
		return
	var raiz := cena.instantiate()
	var modelo := raiz.find_child("Tree2", true, false) as Node3D
	if modelo == null:
		raiz.free()
		return

	# O GLB original vem em escala 100 e com as arvores espalhadas por centenas
	# de metros. Duplicamos apenas o modelo Tree2 e normalizamos a escala.
	var posicoes := [
		[Vector3(-4.6, 1.45, -3.4), -18.0, 19.0],
		[Vector3(-3.1, 1.45, -7.0), 12.0, 23.0],
		[Vector3(5.1, 1.45, -4.4), 24.0, 21.0],
		[Vector3(6.4, 1.45, -8.2), -8.0, 24.0],
		[Vector3(-6.8, 1.45, -1.0), 8.0, 17.0],
		[Vector3(7.4, 1.45, 0.2), -25.0, 18.0],
	]
	for dados in posicoes:
		var arvore := modelo.duplicate() as Node3D
		arvore.position = dados[0]
		arvore.rotation_degrees = Vector3(0.0, dados[1], 0.0)
		arvore.scale = Vector3.ONE * float(dados[2])
		add_child(arvore)

	raiz.free()
