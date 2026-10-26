extends Node
## Teste do tronco rolante: nasce, rola, machuca de frente e é inofensivo
## quando o dino pula por cima.

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	var corredor: Node3D = fase.get_node("Corredor")
	corredor.set("semente", 20261026)
	corredor.set("troncos_ativos", false)
	add_child(fase)

	await _esperar_fisica(60)

	var jogador: Node3D = fase.get_node_or_null("TRex")
	_checar(jogador != null, "TRex instanciado")
	if jogador == null:
		_finalizar()
		return
	_checar(jogador.is_on_floor(), "dino no chao antes do teste")

	var danos: Array[int] = [0]
	jogador.connect("levou_dano", func() -> void: danos[0] += 1)

	# ---------------------------------------------------------- rolagem
	# O tronco precisa nascer à frente (z menor) e rolar no +z até o dino.
	var tronco: Node3D = corredor.call("forcar_tronco", 30.0)
	_checar(tronco != null, "tronco instanciado")
	if tronco == null:
		_finalizar()
		return
	_checar(tronco.is_in_group("tronco"), "tronco no grupo tronco")
	_checar(corredor.call("tronco_ativo"), "corredor registra o tronco ativo")

	var z_inicial: float = tronco.global_position.z
	var rotacao_inicial: float = (tronco.get_node("Visual") as Node3D).rotation.x
	await _esperar_fisica(20)
	_checar(
		tronco.global_position.z > z_inicial + 1.0,
		"tronco rola na direcao do dino (z %.2f -> %.2f)" % [z_inicial, tronco.global_position.z]
	)
	_checar(
		not is_equal_approx((tronco.get_node("Visual") as Node3D).rotation.x, rotacao_inicial),
		"tronco gira enquanto rola"
	)

	# ---------------------------------------------------------- impacto
	jogador.global_position = Vector3(0.0, 0.2, tronco.global_position.z + 1.2)
	var z_antes: float = jogador.global_position.z
	await _esperar_fisica(30)

	_checar(danos[0] == 1, "impacto emite levou_dano uma vez (achei %d)" % danos[0])
	_checar(
		jogador.global_position.z > z_antes + 0.4,
		"impacto empurra o dino para tras (z %.2f -> %.2f)" % [z_antes, jogador.global_position.z]
	)
	_checar(not is_instance_valid(tronco), "tronco desmancha depois do impacto")

	# ---------------------------------------------------------- pulo por cima
	await _esperar_fisica(50)
	var z_seguro_2: float = float(corredor.call("z_seguro_perto", -40.0))
	var tronco_2: Node3D = corredor.call("forcar_tronco", 12.0)
	_checar(tronco_2 != null, "segundo tronco instanciado")
	if tronco_2 == null:
		_finalizar()
		return
	tronco_2.global_position.z = z_seguro_2

	jogador.global_position = Vector3(0.0, 1.5, z_seguro_2)
	await _esperar_fisica(10)

	_checar(danos[0] == 1, "pular por cima nao machuca (achei %d danos)" % danos[0])
	_checar(is_instance_valid(tronco_2), "tronco continua rolando depois do pulo")

	_finalizar()


func _esperar_fisica(quadros: int) -> void:
	for i in quadros:
		await get_tree().physics_frame


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("[OK] ", descricao)
	else:
		_falhas += 1
		print("[FALHA] ", descricao)


func _finalizar() -> void:
	print("RESULTADO: %s (%d falhas)" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	get_tree().quit(0 if _falhas == 0 else 1)
