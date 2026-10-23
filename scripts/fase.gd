extends Node3D
## Fase 1: gera a decoração lateral e evita o "softlock" (dino preso).

@onready var jogador: CharacterBody3D = $TRex

var _ultimo_z: float = 0.0
var _tempo_parado: float = 0.0


func _ready() -> void:
	_ultimo_z = jogador.global_position.z
	_gerar_decoracao()


func _physics_process(delta: float) -> void:
	var z: float = jogador.global_position.z
	if absf(z - _ultimo_z) < 0.03:
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
