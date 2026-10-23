extends Node

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	add_child(fase)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var jogador: Node3D = fase.get_node_or_null("TRex")
	_checar(jogador != null, "TRex instanciado")
	if jogador == null:
		_finalizar()
		return

	_checar(jogador.is_in_group("jogador"), "TRex no grupo jogador")

	var camera: Camera3D = fase.get_node_or_null("TRex/CameraRig/SpringArm3D/Camera3D")
	_checar(camera != null, "camera instanciada")
	if camera != null:
		_checar(
			camera.global_position.z > jogador.global_position.z + 2.0,
			"camera atras do dino (z=%.2f)" % camera.global_position.z
		)
		_checar(
			camera.global_position.y > 2.5,
			"camera acima do dino (y=%.2f)" % camera.global_position.y
		)

	var caixas_antes: int = get_tree().get_nodes_in_group("quebravel").size()
	_checar(caixas_antes == 15, "15 caixas no grupo quebravel (achei %d)" % caixas_antes)

	var itens_antes: int = get_tree().get_nodes_in_group("coletavel").size()
	_checar(itens_antes == 24, "24 coletaveis no grupo (achei %d)" % itens_antes)

	var z_inicial: float = jogador.global_position.z
	for i in 90:
		await get_tree().physics_frame
	_checar(
		jogador.global_position.z < z_inicial - 6.0,
		"dino avancou sozinho (dz=%.2f)" % (jogador.global_position.z - z_inicial)
	)

	var y_antes: float = jogador.global_position.y
	Input.action_press("pular")
	await _esperar_fisica(2)
	Input.action_release("pular")
	await _esperar_fisica(3)
	_checar(
		jogador.global_position.y > y_antes + 0.2,
		"pulo (y=%.2f)" % jogador.global_position.y
	)

	var x_antes: float = jogador.global_position.x
	Input.action_press("mover_esquerda")
	await _esperar_fisica(10)
	Input.action_release("mover_esquerda")
	_checar(
		jogador.global_position.x < x_antes - 0.3,
		"movimento lateral (x=%.2f)" % jogador.global_position.x
	)

	var caixa: Node3D = get_tree().get_nodes_in_group("quebravel")[0]
	jogador.global_position = caixa.global_position + Vector3(0, -0.4, -2.0)
	await _esperar_fisica(6)
	jogador.call("executar_rugido")
	await _esperar_fisica(4)
	var caixas_depois: int = get_tree().get_nodes_in_group("quebravel").size()
	_checar(
		caixas_depois < caixas_antes,
		"rugido quebrou caixa (%d -> %d)" % [caixas_antes, caixas_depois]
	)

	var item: Node3D = null
	for candidato in get_tree().get_nodes_in_group("coletavel"):
		if candidato.global_position.z < -50.0:
			item = candidato
			break
	_checar(item != null, "coletavel encontrado a frente")
	if item != null:
		jogador.global_position = item.global_position
		await _esperar_fisica(6)
		var itens_depois: int = get_tree().get_nodes_in_group("coletavel").size()
		_checar(
			itens_depois < itens_antes,
			"coletavel coletado (%d -> %d)" % [itens_antes, itens_depois]
		)

	var checkpoints: int = get_tree().get_nodes_in_group("checkpoint").size()
	_checar(checkpoints == 3, "3 checkpoints (achei %d)" % checkpoints)

	jogador.global_position = Vector3(0, -8, -60)
	await _esperar_fisica(6)
	_checar(
		jogador.global_position.y > -1.0,
		"respawn apos queda (y=%.2f)" % jogador.global_position.y
	)

	await _esperar_fisica(10)
	_checar(
		jogador.global_position.x >= -4.01 and jogador.global_position.x <= 4.01,
		"dino dentro dos limites laterais (x=%.2f)" % jogador.global_position.x
	)

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
