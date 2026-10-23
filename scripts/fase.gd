extends Node3D
## Fase 1: gera a decoração lateral, evita o "softlock" (dino preso),
## repõe as comidas ao subir de nível e ao recomeçar o corredor.
## Ficar parado é permitido agora: o dino só avança quando o jogador manda.
## O resgate só acontece se o jogador INSISTIR no avanço e o dino não sair do lugar.

const CENA_COMIDA: PackedScene = preload("res://scenes/coletavel.tscn")

@onready var jogador: CharacterBody3D = $TRex
@onready var objetos: Node3D = $Objetos

var _ultimo_z: float = 0.0
var _tempo_parado: float = 0.0
var _comidas: Array[Dictionary] = []
var _reponto_em_andamento: bool = false


func _ready() -> void:
	_ultimo_z = jogador.global_position.z
	_gerar_decoracao()
	_guardar_comidas()
	jogador.connect("subiu_nivel", _ao_subir_nivel)
	jogador.connect("reiniciou", _ao_reiniciar)


func _ao_subir_nivel(_nivel: int) -> void:
	_repor_comidas()


func _ao_reiniciar() -> void:
	_repor_comidas()


func _guardar_comidas() -> void:
	_comidas.clear()
	for no in objetos.get_children():
		if not no.is_in_group("coletavel"):
			continue
		_comidas.append({
			"posicao": no.global_position,
			"tipo": int(no.get("tipo")),
		})


func _repor_comidas() -> void:
	if _comidas.is_empty() or _reponto_em_andamento:
		return
	_reponto_em_andamento = true

	for no in get_tree().get_nodes_in_group("coletavel"):
		if is_ancestor_of(no):
			no.queue_free()
	await get_tree().process_frame

	for dados in _comidas:
		var posicao: Vector3 = dados["posicao"]
		# Não repõe comida no exato lugar onde o dino está (evita pegar de graça).
		# As comidas vizinhas ficam a 1.5 m, então só a do próprio ponto é pulada.
		if jogador.global_position.distance_to(posicao) < 1.4:
			continue
		var comida := CENA_COMIDA.instantiate()
		comida.set("tipo", int(dados["tipo"]))
		objetos.add_child(comida)
		comida.global_position = posicao

	_reponto_em_andamento = false


func _physics_process(delta: float) -> void:
	var z: float = jogador.global_position.z
	var empurrando: bool = Input.is_action_pressed("mover_frente")

	if empurrando and absf(z - _ultimo_z) < 0.03:
		_tempo_parado += delta
		if _tempo_parado > 2.5:
			_tempo_parado = 0.0
			jogador.call("voltar_ao_checkpoint")
	else:
		_tempo_parado = 0.0
		_ultimo_z = z


func _gerar_decoracao() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261023

	var mat_tronco := StandardMaterial3D.new()
	mat_tronco.albedo_color = Color(0.4, 0.26, 0.15)
	mat_tronco.roughness = 1.0

	var mat_copa := StandardMaterial3D.new()
	mat_copa.albedo_color = Color(0.13, 0.45, 0.2)
	mat_copa.roughness = 1.0

	var mat_samambaia := StandardMaterial3D.new()
	mat_samambaia.albedo_color = Color(0.2, 0.55, 0.25)
	mat_samambaia.roughness = 1.0

	var malha_tronco := CylinderMesh.new()
	malha_tronco.top_radius = 0.22
	malha_tronco.bottom_radius = 0.38
	malha_tronco.height = 5.0

	var malha_copa := SphereMesh.new()
	malha_copa.radius = 1.5
	malha_copa.height = 3.0

	var malha_samambaia := SphereMesh.new()
	malha_samambaia.radius = 0.7
	malha_samambaia.height = 1.0

	var decoracao := Node3D.new()
	decoracao.name = "Decoracao"
	add_child(decoracao)

	var z := 4.0
	while z > -138.0:
		for lado in [-1.0, 1.0]:
			var x: float = lado * rng.randf_range(6.5, 9.0)
			var variacao_z := z + rng.randf_range(-1.5, 1.5)

			var tronco := MeshInstance3D.new()
			tronco.mesh = malha_tronco
			tronco.material_override = mat_tronco
			tronco.position = Vector3(x, 2.5, variacao_z)
			decoracao.add_child(tronco)

			var copa := MeshInstance3D.new()
			copa.mesh = malha_copa
			copa.material_override = mat_copa
			copa.position = Vector3(x, 5.8, variacao_z)
			decoracao.add_child(copa)

			if rng.randf() > 0.45:
				var samambaia := MeshInstance3D.new()
				samambaia.mesh = malha_samambaia
				samambaia.material_override = mat_samambaia
				samambaia.position = Vector3(
					lado * rng.randf_range(4.4, 4.9),
					0.5,
					variacao_z + rng.randf_range(-2.0, 2.0)
				)
				decoracao.add_child(samambaia)

		z -= rng.randf_range(7.0, 11.0)
