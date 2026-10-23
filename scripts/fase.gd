extends Node3D
## Fase 1: gera a decoração lateral, evita o "softlock" (dino preso),
## repõe as comidas ao subir de nível e ao recomeçar o corredor.
## Ficar parado é permitido agora: o dino só avança quando o jogador manda.
## O resgate só acontece se o jogador INSISTIR no avanço e o dino não sair do lugar.

const CENA_COMIDA: PackedScene = preload("res://scenes/coletavel.tscn")
const CENA_ARVORES: PackedScene = preload("res://assets/modelos/props/arvores.glb")

## Altura final das arvores do cenario, do chao ao topo da copa (m).
## Os tres modelos do GLB vem com alturas diferentes (~16 m e ~20 m), entao
## cada um e normalizado para esta medida. A variacao evita arvores identicas.
const ALTURA_ARVORE: float = 9.0
const VARIACAO_ALTURA: float = 0.12

@onready var jogador: CharacterBody3D = $TRex
@onready var objetos: Node3D = $Objetos

var _ultimo_z: float = 0.0
var _tempo_parado: float = 0.0
var _comidas: Array[Dictionary] = []
var _reponto_em_andamento: bool = false

## Um item por modelo de arvore do GLB: o no pronto para duplicar, a altura
## original e onde fica o pe do tronco (o GLB nao tem o pivô no chao do tronco).
var _arvores: Array[Dictionary] = []
var _arvores_plantadas: int = 0


func _ready() -> void:
	_ultimo_z = jogador.global_position.z
	_carregar_arvores()
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

	var mat_samambaia := StandardMaterial3D.new()
	mat_samambaia.albedo_color = Color(0.2, 0.55, 0.25)
	mat_samambaia.roughness = 1.0

	var malha_samambaia := SphereMesh.new()
	malha_samambaia.radius = 0.7
	malha_samambaia.height = 1.0

	var decoracao := Node3D.new()
	decoracao.name = "Decoracao"
	add_child(decoracao)

	var z := 0.0
	while z > -138.0:
		for lado in [-1.0, 1.0]:
			var x: float = lado * rng.randf_range(6.5, 9.0)
			var variacao_z := z + rng.randf_range(-1.5, 1.5)
			_plantar_arvore(decoracao, Vector3(x, 0.0, variacao_z), rng)

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


## Prepara os tres modelos de arvore do GLB: mede cada um, normaliza o pivô
## e guarda um no pronto para ser duplicado pela decoracao.
func _carregar_arvores() -> void:
	_arvores.clear()
	_arvores_plantadas = 0

	var cena := CENA_ARVORES.instantiate()
	add_child(cena)
	var raiz := cena.find_child("RootNode", true, false)
	if raiz == null:
		push_warning("arvores.glb sem RootNode: o cenario fica sem arvores")
		remove_child(cena)
		cena.free()
		return

	for filho in raiz.get_children():
		if not (filho is Node3D):
			continue
		var no := filho as Node3D
		if no.find_children("*", "MeshInstance3D", true, false).is_empty():
			continue

		var caixa := _caixa_das_malhas(no)
		if caixa.size.y <= 0.0:
			continue

		# O pivô do GLB não fica no pé do tronco: a madeira dá o centro da base.
		# Se o nome da malha mudar no futuro, cai no centro do modelo.
		var tronco := _caixa_das_malhas(no, "Madera")
		var pe := Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
		if tronco.size.x > 0.0:
			pe = Vector3(tronco.get_center().x, caixa.position.y, tronco.get_center().z)

		# A arvore fica dentro do GLB num pivô fora do tronco e com o eixo Z
		# para cima. A copia leva o giro do GLB embutido e vira o "molde".
		var molde := Node3D.new()
		molde.name = no.name
		var copia := no.duplicate() as Node3D
		copia.transform = no.global_transform
		molde.add_child(copia)

		_arvores.append({
			"molde": molde,
			"altura": caixa.size.y,
			"pe": pe,
		})

	remove_child(cena)
	cena.free()


## Planta uma arvore com o pe do tronco exatamente em `alvo`.
func _plantar_arvore(pai: Node3D, alvo: Vector3, rng: RandomNumberGenerator) -> void:
	if _arvores.is_empty():
		return

	var dados: Dictionary = _arvores[rng.randi_range(0, _arvores.size() - 1)]
	var escala: float = ALTURA_ARVORE / float(dados["altura"])
	escala *= rng.randf_range(1.0 - VARIACAO_ALTURA, 1.0 + VARIACAO_ALTURA)
	var angulo := rng.randf_range(0.0, TAU)
	var giro := Basis(Vector3.UP, angulo)
	var pe: Vector3 = dados["pe"]

	var arvore := (dados["molde"] as Node3D).duplicate() as Node3D
	_arvores_plantadas += 1
	arvore.name = "%s_%02d" % [dados["molde"].name, _arvores_plantadas]
	arvore.rotation.y = angulo
	arvore.scale = Vector3.ONE * escala
	arvore.position = alvo - giro * (pe * escala)
	pai.add_child(arvore)


## Caixa que envolve as malhas do no, em coordenadas globais.
## Com `filtro`, so entram as malhas cujo nome contem o texto (ex.: "Madera").
func _caixa_das_malhas(no: Node3D, filtro: String = "") -> AABB:
	var caixa := AABB()
	var primeiro := true
	for filho in no.find_children("*", "MeshInstance3D", true, false):
		var malha := filho as MeshInstance3D
		if malha.mesh == null:
			continue
		if not filtro.is_empty() and not malha.name.contains(filtro):
			continue
		var atual: AABB = malha.global_transform * malha.get_aabb()
		if primeiro:
			caixa = atual
			primeiro = false
		else:
			caixa = caixa.merge(atual)
	return caixa
