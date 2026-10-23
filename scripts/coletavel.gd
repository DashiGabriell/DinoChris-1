extends Area3D
## Comida saudável: carne, fruta, vegetal ou água.
## O tipo é escolhido na cena (0 carne, 1 fruta, 2 vegetal, 3 água) e o
## desenho é montado no _ready() com formas simples.

enum Tipo { CARNE, FRUTA, VEGETAL, AGUA }

@export_enum("Carne", "Fruta", "Vegetal", "Agua") var tipo: int = Tipo.CARNE

@onready var visual: Node3D = $Visual

var _base_y: float = 0.0
var _tempo: float = 0.0
var _coletado: bool = false


func _ready() -> void:
	_base_y = visual.position.y
	_montar_visual()
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
		corpo.call("coletar", tipo)
	queue_free()


func _montar_visual() -> void:
	for filho in visual.get_children():
		filho.queue_free()

	match tipo:
		Tipo.FRUTA:
			_montar_fruta()
		Tipo.VEGETAL:
			_montar_vegetal()
		Tipo.AGUA:
			_montar_agua()
		_:
			_montar_carne()


func _montar_carne() -> void:
	_parte("Miolo", _esfera(0.3, 0.62), Color(0.68, 0.25, 0.16), Vector3(0, 0.16, 0), Vector3(1.08, 0.9, 1.16))
	_parte("Miolo2", _esfera(0.19, 0.38), Color(0.6, 0.2, 0.13), Vector3(0.14, 0.3, 0.08), Vector3.ONE)
	_parte("Osso", _cilindro(0.052, 0.052, 0.42), Color(0.97, 0.94, 0.86), Vector3(0, -0.22, 0), Vector3.ONE, 0.15)
	_parte("OssoPonta", _esfera(0.095, 0.19), Color(0.97, 0.94, 0.86), Vector3(0, -0.44, 0), Vector3.ONE, 0.15)


func _montar_fruta() -> void:
	_parte("Polpa", _esfera(0.32, 0.64), Color(0.95, 0.32, 0.14), Vector3.ZERO, Vector3(1.0, 1.05, 1.0), 0.5)
	_parte("Cabo", _cilindro(0.028, 0.028, 0.14), Color(0.35, 0.22, 0.1), Vector3(0, 0.34, 0), Vector3.ONE, 0.1)
	_parte("Folha", _caixa(Vector3(0.26, 0.04, 0.13)), Color(0.2, 0.6, 0.18), Vector3(0.12, 0.39, 0), Vector3.ONE, 0.3, Vector3(0, 15, 14))


func _montar_vegetal() -> void:
	_parte("Cenoura", _cilindro(0.02, 0.21, 0.56), Color(0.95, 0.55, 0.12), Vector3(0, -0.04, 0), Vector3.ONE, 0.5, Vector3(180, 0, 0))
	_parte("Folha1", _esfera(0.12, 0.24), Color(0.24, 0.62, 0.2), Vector3(0.02, 0.3, 0), Vector3(0.7, 1.3, 0.7), 0.3, Vector3(0, 0, -14))
	_parte("Folha2", _esfera(0.11, 0.22), Color(0.3, 0.7, 0.24), Vector3(-0.1, 0.27, 0.03), Vector3(0.7, 1.2, 0.7), 0.3, Vector3(0, 0, 20))
	_parte("Folha3", _esfera(0.1, 0.2), Color(0.26, 0.66, 0.22), Vector3(0.1, 0.26, -0.04), Vector3(0.7, 1.1, 0.7), 0.3, Vector3(0, 0, 28))


func _montar_agua() -> void:
	_parte("Gota", _esfera(0.3, 0.62), Color(0.28, 0.62, 0.98, 0.82), Vector3(0, -0.02, 0), Vector3(1.0, 1.05, 1.0), 0.6)
	_parte("Ponta", _cilindro(0.01, 0.23, 0.4), Color(0.28, 0.62, 0.98, 0.82), Vector3(0, 0.28, 0), Vector3.ONE, 0.6)
	_parte("Brilho", _esfera(0.08, 0.16), Color(0.92, 0.97, 1.0, 0.9), Vector3(-0.11, 0.05, -0.2), Vector3.ONE, 1.0)


func _esfera(raio: float, altura: float) -> SphereMesh:
	var malha := SphereMesh.new()
	malha.radius = raio
	malha.height = altura
	return malha


func _cilindro(topo: float, base: float, altura: float) -> CylinderMesh:
	var malha := CylinderMesh.new()
	malha.top_radius = topo
	malha.bottom_radius = base
	malha.height = altura
	malha.radial_segments = 16
	return malha


func _caixa(tamanho: Vector3) -> BoxMesh:
	var malha := BoxMesh.new()
	malha.size = tamanho
	return malha


func _parte(
	nome: String,
	malha: Mesh,
	cor: Color,
	posicao: Vector3,
	escala: Vector3 = Vector3.ONE,
	brilho: float = 0.4,
	rotacao: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.name = nome
	no.mesh = malha
	no.position = posicao
	no.scale = escala
	no.rotation_degrees = rotacao

	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = Color(cor.r, cor.g, cor.b)
	material.emission_energy_multiplier = brilho
	if cor.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	no.material_override = material

	visual.add_child(no)
	return no
