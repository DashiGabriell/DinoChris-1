extends Node3D
## Corredor infinito: o caminho é montado em pedaços à frente do dino e os
## pedaços que ficaram para trás são liberados. Cada pedaço traz chão, paredes,
## árvores, e de vez em quando uma fissura, um rio de lava, caixas ou comidas.
##
## Cair numa fissura ou na lava devolve o dino ao último ponto seguro (chão
## firme onde ele já pisou) — nunca existe game over.
##
## O início é roteirizado de propósito: pedaço 0 livre, 1 com caixas, 2 com a
## primeira fissura e 3 com o primeiro rio de lava. Depois disso é sorteio.

const CENA_CAIXA: PackedScene = preload("res://scenes/caixa.tscn")
const CENA_COMIDA: PackedScene = preload("res://scenes/coletavel.tscn")
const CENA_TRONCO: PackedScene = preload("res://scenes/tronco.tscn")
const CENA_ARVORES: PackedScene = preload("res://assets/modelos/props/arvores.glb")
const SHADER_LAVA: Shader = preload("res://assets/shaders/lava.gdshader")

## Profundidade de um pedaço do corredor (m).
const COMPRIMENTO: float = 36.0
## Quantos metros de caminho ficam prontos à frente do dino.
const PEDACOS_ADIANTE: int = 7
## Distância para trás em que um pedaço ainda é mantido vivo (m).
const DISTANCIA_APAGAR: float = 58.0
## O corredor começa esta quantidade de metros atrás do dino.
const INICIO: float = 8.0

const LARGURA_CHAO: float = 10.0
const ALTURA_PAREDE: float = 5.0
const LARGURA_TRILHA: float = 3.2

## Altura final das árvores, do chão ao topo da copa (m).
const ALTURA_ARVORE: float = 9.0
const VARIACAO_ALTURA: float = 0.12

## Abaixo desta altura o dino caiu numa fissura e volta ao ponto seguro.
const ALTURA_QUEDA: float = -7.0
## Distância mínima entre dois obstáculos que exigem pulo (m).
const ESPACO_ENTRE_OBSTACULOS: float = 20.0
## Margem de chão firme antes/depois de um buraco para o ponto seguro.
const MARGEM_SEGURA: float = 2.4

## Distância mínima e máxima de chão livre entre dois troncos rolantes (m).
const TRONCO_ESPACO_MIN: float = 26.0
const TRONCO_ESPACO_MAX: float = 42.0
## O tronco nasce esta distância à frente do dino (m), com variação.
const TRONCO_SPAWN_MIN: float = 26.0
const TRONCO_SPAWN_MAX: float = 32.0

## 0 sorteia uma semente nova a cada partida; outro valor repete o caminho.
@export var semente: int = 0
## Liga/desliga os troncos rolantes (os testes desligam para isolar o resto).
@export var troncos_ativos: bool = true

var _rng := RandomNumberGenerator.new()
var _pedacos: Array[Dictionary] = []
var _proximo_indice: int = 0
var _z_gerado: float = INICIO
var _jogador: Node3D = null
var _ponto_seguro := Vector3(0.0, 0.3, 0.0)
var _resgatando: bool = false
var _distancia: float = 0.0
var _ultimo_obstaculo_z: float = 999.0
var _proximo_tipo_comida: int = 0
var _arvores_plantadas: int = 0
var _proximo_tronco: float = 0.0
var _tronco_atual: Node3D = null

var _arvores: Array[Dictionary] = []
var _malha_cubo: BoxMesh
var _malha_samambaia: SphereMesh
var _mat_grama: StandardMaterial3D
var _mat_areia: StandardMaterial3D
var _mat_pedra: StandardMaterial3D
var _mat_rocha: StandardMaterial3D
var _mat_abismo: StandardMaterial3D
var _mat_samambaia: StandardMaterial3D
var _mat_brasa: StandardMaterial3D
var _mat_lava: ShaderMaterial


func _ready() -> void:
	if semente == 0:
		_rng.randomize()
	else:
		_rng.seed = semente

	# O primeiro tronco só aparece depois de alguns metros de aprendizado.
	_proximo_tronco = _rng.randf_range(16.0, 24.0)

	_jogador = get_tree().get_first_node_in_group("jogador") as Node3D
	if _jogador == null:
		push_warning("Corredor sem jogador: nada sera gerado")
		return

	_criar_recursos()
	_carregar_arvores()
	_jogador.call("definir_checkpoint", _ponto_seguro)
	while _jogador.global_position.z - _z_gerado < COMPRIMENTO * PEDACOS_ADIANTE:
		_gerar_pedaco()


func _process(_delta: float) -> void:
	if _jogador == null:
		return

	_distancia = maxf(0.0, -_jogador.global_position.z)
	while _jogador.global_position.z - _z_gerado < COMPRIMENTO * PEDACOS_ADIANTE:
		_gerar_pedaco()
	_apagar_pedacos_antigos()
	_atualizar_ponto_seguro()
	_atualizar_troncos()


func _physics_process(_delta: float) -> void:
	if _jogador == null or _resgatando:
		return
	if _jogador.global_position.y < ALTURA_QUEDA:
		_resgatar("queda")


# ---------------------------------------------------------------- geração
func _criar_recursos() -> void:
	_malha_cubo = BoxMesh.new()
	_malha_cubo.size = Vector3.ONE

	_mat_grama = StandardMaterial3D.new()
	_mat_grama.albedo_color = Color(0.32, 0.6, 0.26)
	_mat_grama.roughness = 1.0

	_mat_areia = StandardMaterial3D.new()
	_mat_areia.albedo_color = Color(0.8, 0.7, 0.48)
	_mat_areia.roughness = 1.0

	_mat_pedra = StandardMaterial3D.new()
	_mat_pedra.albedo_color = Color(0.42, 0.4, 0.38)
	_mat_pedra.roughness = 1.0

	# Rocha da base do chão: só aparece nas paredes dos buracos, por isso é escura
	# e o vão parece fundo em vez de uma faixa cinza.
	_mat_rocha = StandardMaterial3D.new()
	_mat_rocha.albedo_color = Color(0.09, 0.08, 0.08)
	_mat_rocha.roughness = 1.0

	_mat_abismo = StandardMaterial3D.new()
	_mat_abismo.albedo_color = Color(0.02, 0.01, 0.02)
	_mat_abismo.roughness = 1.0
	_mat_abismo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_mat_brasa = StandardMaterial3D.new()
	_mat_brasa.albedo_color = Color(1.0, 0.45, 0.08)
	_mat_brasa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_brasa.emission_enabled = true
	_mat_brasa.emission = Color(1.0, 0.4, 0.05)
	_mat_brasa.emission_energy_multiplier = 2.0

	_mat_lava = ShaderMaterial.new()
	_mat_lava.shader = SHADER_LAVA

	_malha_samambaia = SphereMesh.new()
	_malha_samambaia.radius = 0.7
	_malha_samambaia.height = 1.0

	_mat_samambaia = StandardMaterial3D.new()
	_mat_samambaia.albedo_color = Color(0.2, 0.55, 0.25)
	_mat_samambaia.roughness = 1.0


func _gerar_pedaco() -> void:
	var indice := _proximo_indice
	_proximo_indice += 1

	var z0 := _z_gerado
	var z1 := z0 - COMPRIMENTO
	_z_gerado = z1

	var pedaco := Node3D.new()
	pedaco.name = "Pedaco_%03d" % indice
	pedaco.position = Vector3(0.0, 0.0, z0)
	add_child(pedaco)

	var desafio := _sortear_desafio(indice, z0)
	var buracos: Array = desafio["buracos"]

	var solido := StaticBody3D.new()
	solido.name = "Solido"
	solido.collision_layer = 1
	solido.collision_mask = 0
	pedaco.add_child(solido)

	_construir_chao(pedaco, solido, _intervalos(buracos))
	_construir_paredes(pedaco, solido)
	for buraco in buracos:
		_construir_buraco(pedaco, buraco)
	_decorar(pedaco, buracos)
	_por_conteudo(pedaco, desafio, buracos)

	var buracos_mundo: Array[Dictionary] = []
	for buraco in buracos:
		var inicio := z0 - float(buraco["inicio"])
		buracos_mundo.append({
			"inicio": inicio,
			"fim": inicio - float(buraco["largura"]),
		})
		_ultimo_obstaculo_z = inicio

	_pedacos.append({
		"no": pedaco,
		"z0": z0,
		"z1": z1,
		"indice": indice,
		"buracos": buracos_mundo,
	})


func _sortear_desafio(indice: int, z0: float) -> Dictionary:
	match indice:
		0:
			return {"buracos": [], "caixas": 2, "comida": 1}
		1:
			return {
				"buracos": [{"inicio": 14.0, "largura": 2.0, "lava": false}],
				"caixas": 0,
				"comida": 1,
			}
		2:
			return {
				"buracos": [{"inicio": 14.0, "largura": 2.2, "lava": true}],
				"caixas": 0,
				"comida": 1,
			}
		3:
			return {"buracos": [], "caixas": 3, "comida": 1}

	var dificuldade := clampf(_distancia / 800.0, 0.0, 1.0)
	var largura := 0.0
	var lava := false
	var sorte := _rng.randf()
	if sorte < 0.26:
		largura = minf(1.8 + 0.8 * dificuldade, 2.5)
	elif sorte < 0.50:
		largura = minf(2.0 + 0.7 * dificuldade, 2.6)
		lava = true
	elif sorte < 0.76:
		return {"buracos": [], "caixas": _rng.randi_range(2, 4), "comida": 1}
	else:
		return {"buracos": [], "caixas": 0, "comida": 2}

	largura = minf(largura + _rng.randf_range(-0.1, 0.2), 2.6)
	var inicio := _rng.randf_range(11.0, COMPRIMENTO - 11.0 - largura)
	if absf((z0 - inicio) - _ultimo_obstaculo_z) < ESPACO_ENTRE_OBSTACULOS:
		return {"buracos": [], "caixas": 0, "comida": 2}

	return {
		"buracos": [{"inicio": inicio, "largura": largura, "lava": lava}],
		"caixas": 0,
		"comida": 1,
	}


func _construir_chao(pedaco: Node3D, solido: StaticBody3D, trechos: Array[Vector2]) -> void:
	for trecho in trechos:
		var comprimento := trecho.y - trecho.x
		if comprimento <= 0.05:
			continue
		var centro := -(trecho.x + comprimento * 0.5)

		# Base de pedra (as laterais do buraco ficam com cara de rocha).
		var base := MeshInstance3D.new()
		base.mesh = _malha_cubo
		base.material_override = _mat_rocha
		base.scale = Vector3(LARGURA_CHAO, 0.94, comprimento)
		base.position = Vector3(0.0, -0.53, centro)
		pedaco.add_child(base)

		# Grama por cima, como uma lâmina fininha.
		var grama := MeshInstance3D.new()
		grama.mesh = _malha_cubo
		grama.material_override = _mat_grama
		grama.scale = Vector3(LARGURA_CHAO, 0.06, comprimento)
		grama.position = Vector3(0.0, -0.03, centro)
		pedaco.add_child(grama)

		# Trilha de areia, só visual (sem colisão), como na fase original.
		var trilha := MeshInstance3D.new()
		trilha.mesh = _malha_cubo
		trilha.material_override = _mat_areia
		trilha.scale = Vector3(LARGURA_TRILHA, 0.04, comprimento)
		trilha.position = Vector3(0.0, 0.02, centro)
		pedaco.add_child(trilha)

		var forma := BoxShape3D.new()
		forma.size = Vector3(LARGURA_CHAO, 1.0, comprimento)
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		colisao.position = Vector3(0.0, -0.5, centro)
		solido.add_child(colisao)


func _construir_paredes(pedaco: Node3D, solido: StaticBody3D) -> void:
	for lado in [-1.0, 1.0]:
		var parede := MeshInstance3D.new()
		parede.mesh = _malha_cubo
		parede.material_override = _mat_pedra
		parede.scale = Vector3(0.6, ALTURA_PAREDE, COMPRIMENTO)
		parede.position = Vector3(lado * 5.3, ALTURA_PAREDE * 0.5, -COMPRIMENTO * 0.5)
		pedaco.add_child(parede)

		var forma := BoxShape3D.new()
		forma.size = Vector3(0.6, ALTURA_PAREDE, COMPRIMENTO)
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		colisao.position = parede.position
		solido.add_child(colisao)


func _construir_buraco(pedaco: Node3D, buraco: Dictionary) -> void:
	var largura := float(buraco["largura"])
	var inicio := float(buraco["inicio"])
	var lava := bool(buraco["lava"])
	var centro := -(inicio + largura * 0.5)

	var zona := Node3D.new()
	zona.name = "Lava" if lava else "Fissura"
	zona.position = Vector3(0.0, 0.0, centro)
	zona.add_to_group("buraco")
	zona.set_meta("lava", lava)
	zona.set_meta("largura", largura)
	pedaco.add_child(zona)

	if lava:
		# A lava fica quase no nível do chão (só 30 cm abaixo): assim o rio
		# aparece de verdade na câmera de trás e não vira uma linha no fundo.
		var superficie := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(LARGURA_CHAO, largura)
		superficie.mesh = plano
		superficie.material_override = _mat_lava
		superficie.position = Vector3(0.0, -0.28, 0.0)
		zona.add_child(superficie)

		# Borda acesa nas duas margens: marca o rio mesmo de longe.
		for lado_borda in [-1.0, 1.0]:
			var brasa := MeshInstance3D.new()
			brasa.mesh = _malha_cubo
			brasa.material_override = _mat_brasa
			brasa.scale = Vector3(LARGURA_CHAO, 0.03, 0.22)
			brasa.position = Vector3(0.0, 0.015, lado_borda * (largura * 0.5 + 0.1))
			zona.add_child(brasa)

		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.45, 0.12)
		luz.light_energy = 3.2
		luz.omni_range = 9.0
		luz.position = Vector3(0.0, -0.1, 0.0)
		zona.add_child(luz)

		var area := Area3D.new()
		area.name = "Perigo"
		area.collision_layer = 8
		area.collision_mask = 2
		var forma := BoxShape3D.new()
		forma.size = Vector3(LARGURA_CHAO, 0.64, largura)
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		colisao.position = Vector3(0.0, -0.6, 0.0)
		area.add_child(colisao)
		zona.add_child(area)
		area.body_entered.connect(_ao_encostar_lava)
	else:
		# Fundo escuro: sem ele o buraco mostraria o céu do outro lado.
		var fundo := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(LARGURA_CHAO, largura)
		fundo.mesh = plano
		fundo.material_override = _mat_abismo
		fundo.position = Vector3(0.0, -6.0, 0.0)
		zona.add_child(fundo)


func _decorar(pedaco: Node3D, buracos: Array) -> void:
	var z := 2.0
	while z < COMPRIMENTO - 1.0:
		for lado in [-1.0, 1.0]:
			if _rng.randf() > 0.12:
				var x: float = lado * _rng.randf_range(6.5, 9.0)
				var posicao := Vector3(x, 0.0, -(z + _rng.randf_range(-1.2, 1.2)))
				_plantar_arvore(pedaco, posicao)

			if _rng.randf() > 0.5:
				var z_samambaia := z + _rng.randf_range(-2.0, 2.0)
				if not _dentro_de_buraco(z_samambaia, buracos, 1.2):
					var samambaia := MeshInstance3D.new()
					samambaia.mesh = _malha_samambaia
					samambaia.material_override = _mat_samambaia
					samambaia.position = Vector3(
						lado * _rng.randf_range(4.4, 4.9),
						0.5,
						-z_samambaia
					)
					pedaco.add_child(samambaia)
		z += _rng.randf_range(7.0, 10.0)


# ---------------------------------------------------------------- conteúdo
func _por_conteudo(pedaco: Node3D, desafio: Dictionary, buracos: Array) -> void:
	var zonas := _zonas_livres(buracos)

	var caixas := int(desafio["caixas"])
	if caixas > 0 and not zonas.is_empty():
		var indice := _rng.randi_range(0, zonas.size() - 1)
		var zona: Vector2 = zonas[indice]
		zonas.remove_at(indice)
		_por_caixas(pedaco, zona, caixas)

	for i in int(desafio["comida"]):
		if zonas.is_empty():
			break
		var indice_comida := _rng.randi_range(0, zonas.size() - 1)
		var zona: Vector2 = zonas[indice_comida]
		zonas.remove_at(indice_comida)
		_por_comida(pedaco, zona)

	for buraco in buracos:
		_por_recompensa(pedaco, buraco)


func _por_caixas(pedaco: Node3D, zona: Vector2, quantidade: int) -> void:
	var passo := 1.45
	var disponivel := zona.y - zona.x
	var largura := (quantidade - 1) * passo + 1.2
	var inicio := zona.x + maxf(0.6, (disponivel - largura) * 0.5)
	for i in quantidade:
		var caixa := CENA_CAIXA.instantiate()
		pedaco.add_child(caixa)
		var faixa: float = [-2.2, 0.0, 2.2][i % 3]
		caixa.position = Vector3(
			faixa + _rng.randf_range(-0.2, 0.2),
			0.6,
			-(inicio + i * passo)
		)


func _por_comida(pedaco: Node3D, zona: Vector2) -> void:
	var passo := 1.6
	var disponivel := zona.y - zona.x
	var faixa: float = [-1.5, 0.0, 1.5][_rng.randi_range(0, 2)]
	if disponivel < 3.4:
		_criar_comida(pedaco, Vector3(faixa, 0.0, -(zona.x + disponivel * 0.5)))
		return

	var quantidade := clampi(int(disponivel / passo) + 1, 3, 5)
	var largura := (quantidade - 1) * passo
	var inicio := zona.x + (disponivel - largura) * 0.5
	for i in quantidade:
		_criar_comida(pedaco, Vector3(faixa, 0.0, -(inicio + i * passo)))


func _por_recompensa(pedaco: Node3D, buraco: Dictionary) -> void:
	var meio := float(buraco["inicio"]) + float(buraco["largura"]) * 0.5
	_criar_comida(pedaco, Vector3(0.0, 0.8, -meio))


func _criar_comida(pedaco: Node3D, posicao: Vector3) -> void:
	var comida := CENA_COMIDA.instantiate()
	comida.set("tipo", _proximo_tipo_comida)
	_proximo_tipo_comida = (_proximo_tipo_comida + 1) % 4
	pedaco.add_child(comida)
	comida.position = posicao


# ---------------------------------------------------------------- utilidades
func _intervalos(buracos: Array) -> Array[Vector2]:
	var trechos: Array[Vector2] = []
	var cursor := 0.0
	for buraco in buracos:
		trechos.append(Vector2(cursor, float(buraco["inicio"])))
		cursor = float(buraco["inicio"]) + float(buraco["largura"])
	trechos.append(Vector2(cursor, COMPRIMENTO))
	return trechos


func _zonas_livres(buracos: Array) -> Array[Vector2]:
	var zonas: Array[Vector2] = []
	var cursor := 2.0
	for buraco in buracos:
		var fim := float(buraco["inicio"]) - 3.0
		if fim - cursor > 2.0:
			zonas.append(Vector2(cursor, fim))
		cursor = float(buraco["inicio"]) + float(buraco["largura"]) + 3.0
	if COMPRIMENTO - 2.0 - cursor > 2.0:
		zonas.append(Vector2(cursor, COMPRIMENTO - 2.0))
	return zonas


func _dentro_de_buraco(distancia: float, buracos: Array, margem: float) -> bool:
	for buraco in buracos:
		var inicio := float(buraco["inicio"])
		if distancia > inicio - margem and distancia < inicio + float(buraco["largura"]) + margem:
			return true
	return false


func _apagar_pedacos_antigos() -> void:
	var limite := _jogador.global_position.z + DISTANCIA_APAGAR
	for i in range(_pedacos.size() - 1, -1, -1):
		var dados: Dictionary = _pedacos[i]
		if float(dados["z1"]) > limite:
			(dados["no"] as Node3D).queue_free()
			_pedacos.remove_at(i)


func _atualizar_ponto_seguro() -> void:
	if _resgatando or not _jogador.is_on_floor():
		return
	var posicao := _jogador.global_position
	if posicao.y > 0.6:
		return
	if _perto_de_buraco(posicao.z):
		return
	_ponto_seguro = Vector3(clampf(posicao.x, -3.2, 3.2), 0.25, posicao.z)
	_jogador.call("definir_checkpoint", _ponto_seguro)


func _perto_de_buraco(z: float) -> bool:
	for dados in _pedacos:
		for buraco in dados["buracos"]:
			if z < float(buraco["inicio"]) + MARGEM_SEGURA and z > float(buraco["fim"]) - MARGEM_SEGURA:
				return true
	return false


# ---------------------------------------------------------------- troncos
func _atualizar_troncos() -> void:
	if not troncos_ativos or _resgatando or _jogador == null:
		return

	if _tronco_atual != null and not is_instance_valid(_tronco_atual):
		_tronco_atual = null
	if _tronco_atual != null:
		return
	if _distancia < _proximo_tronco:
		return
	if not _jogador.is_on_floor():
		return
	if _perto_de_buraco(_jogador.global_position.z):
		return
	if _perto_de_buraco(_jogador.global_position.z - 5.0):
		return

	var z_spawn := _jogador.global_position.z - _rng.randf_range(TRONCO_SPAWN_MIN, TRONCO_SPAWN_MAX)
	if not _chao_firme_em(z_spawn) or not _caminho_livre_ate(z_spawn, _jogador.global_position.z - 2.0):
		# Não insiste a cada quadro: só tenta de novo depois de andar mais um pouco.
		_proximo_tronco = _distancia + 2.0
		return

	_tronco_atual = _criar_tronco(z_spawn)
	_proximo_tronco = _distancia + _rng.randf_range(TRONCO_ESPACO_MIN, TRONCO_ESPACO_MAX)


func _criar_tronco(z_spawn: float) -> Node3D:
	var tronco := CENA_TRONCO.instantiate() as Node3D
	add_child(tronco)
	tronco.global_position = Vector3(0.0, 0.42, z_spawn)
	return tronco


## Usado pelo teste e por ferramentas: cria um tronco sem esperar o sorteio.
func forcar_tronco(distancia: float = 18.0) -> Node3D:
	if _jogador == null:
		return null
	_tronco_atual = _criar_tronco(_jogador.global_position.z - distancia)
	return _tronco_atual


func tronco_ativo() -> bool:
	return _tronco_atual != null and is_instance_valid(_tronco_atual)


func _chao_firme_em(z: float) -> bool:
	var espaco := get_world_3d().direct_space_state
	var deslocamentos: Array[float] = [-0.7, 0.0, 0.7]
	for deslocamento in deslocamentos:
		var de := Vector3(0.0, 2.0, z + deslocamento)
		var ate := Vector3(0.0, -1.5, z + deslocamento)
		var consulta := PhysicsRayQueryParameters3D.create(de, ate)
		consulta.collision_mask = 1
		if espaco.intersect_ray(consulta).is_empty():
			return false
	return true


func _caminho_livre_ate(z_inicio: float, z_fim: float) -> bool:
	var z := z_inicio
	while z < z_fim:
		if _perto_de_buraco(z):
			return false
		z += 2.0
	return true


func _ao_encostar_lava(corpo: Node3D) -> void:
	if corpo.is_in_group("jogador"):
		_resgatar("lava")


func _resgatar(motivo: String) -> void:
	if _resgatando or _jogador == null:
		return
	_resgatando = true
	var cor: Color = Color(1.0, 0.55, 0.15) if motivo == "lava" else Color(0.85, 0.9, 1.0)
	_jogador.call("voltar_ao_checkpoint")
	# O anel nasce no ponto de retorno (não no fundo do buraco): é o aviso de
	# "voltei" que a criança vê.
	_estouro(_jogador.global_position, cor)
	await get_tree().create_timer(0.35).timeout
	_resgatando = false


func _estouro(posicao: Vector3, cor: Color) -> void:
	var anel := MeshInstance3D.new()
	var malha := TorusMesh.new()
	malha.inner_radius = 0.35
	malha.outer_radius = 0.5
	anel.mesh = malha
	anel.rotation_degrees = Vector3(90, 0, 0)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = cor
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = 1.4
	anel.material_override = material

	add_child(anel)
	anel.global_position = posicao
	anel.scale = Vector3.ONE * 0.8

	var tween := create_tween()
	tween.tween_property(anel, "scale", Vector3.ONE * 2.6, 0.4)
	tween.tween_callback(anel.queue_free)


# ---------------------------------------------------------------- árvores
func _carregar_arvores() -> void:
	_arvores.clear()
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
		var tronco := _caixa_das_malhas(no, "Madera")
		var pe := Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
		if tronco.size.x > 0.0:
			pe = Vector3(tronco.get_center().x, caixa.position.y, tronco.get_center().z)

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


func _plantar_arvore(pai: Node3D, alvo: Vector3) -> void:
	if _arvores.is_empty():
		return

	var dados: Dictionary = _arvores[_rng.randi_range(0, _arvores.size() - 1)]
	var escala: float = ALTURA_ARVORE / float(dados["altura"])
	escala *= _rng.randf_range(1.0 - VARIACAO_ALTURA, 1.0 + VARIACAO_ALTURA)
	var angulo := _rng.randf_range(0.0, TAU)
	var giro := Basis(Vector3.UP, angulo)
	var pe: Vector3 = dados["pe"]

	var arvore := (dados["molde"] as Node3D).duplicate() as Node3D
	_arvores_plantadas += 1
	arvore.name = "%s_%03d" % [dados["molde"].name, _arvores_plantadas]
	arvore.add_to_group("arvore")
	arvore.rotation.y = angulo
	arvore.scale = Vector3.ONE * escala
	arvore.position = alvo - giro * (pe * escala)
	pai.add_child(arvore)


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


# ---------------------------------------------------------------- leitura
func distancia_percorrida() -> float:
	return _distancia


func pedacos_ativos() -> int:
	return _pedacos.size()


func ponto_seguro() -> Vector3:
	return _ponto_seguro


## Chão firme perto de `z`: começo do pedaço que contém a posição. Os buracos
## só aparecem 11 m depois da borda do pedaço, então esse ponto é sempre seguro.
func z_seguro_perto(z: float) -> float:
	var indice := int(floor((INICIO - z) / COMPRIMENTO))
	return INICIO - float(indice) * COMPRIMENTO - 2.0
