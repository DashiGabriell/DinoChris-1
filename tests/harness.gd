extends Node
## Teste de fumaça do corredor infinito: geração, árvores, fissura, lava,
## ponto seguro, respawn, caixas, comidas, controles e limites.

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	fase.get_node("Corredor").set("semente", 20261023)
	add_child(fase)

	await _esperar_fisica(6)

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

	var corredor: Node3D = fase.get_node_or_null("Corredor")
	_checar(corredor != null, "no Corredor existe")
	if corredor == null:
		_finalizar()
		return

	await _esperar_fisica(60)
	_checar(jogador.is_on_floor(), "dino pousa no chao gerado")
	_checar(
		int(corredor.call("pedacos_ativos")) >= 6,
		"pedacos gerados no inicio (%d)" % int(corredor.call("pedacos_ativos"))
	)

	var arvores: int = get_tree().get_nodes_in_group("arvore").size()
	_checar(arvores > 20, "arvores do GLB plantadas (%d)" % arvores)

	var fissuras: int = 0
	var lavas: int = 0
	for buraco in get_tree().get_nodes_in_group("buraco"):
		if bool(buraco.get_meta("lava")):
			lavas += 1
		else:
			fissuras += 1
	_checar(fissuras >= 1, "fissura gerada (%d)" % fissuras)
	_checar(lavas >= 1, "rio de lava gerado (%d)" % lavas)

	var caixas_antes: int = get_tree().get_nodes_in_group("quebravel").size()
	_checar(caixas_antes >= 2, "caixas geradas (%d)" % caixas_antes)
	var itens_antes: int = get_tree().get_nodes_in_group("coletavel").size()
	_checar(itens_antes > 10, "comidas geradas (%d)" % itens_antes)

	var z_inicial: float = jogador.global_position.z
	await _esperar_fisica(90)
	_checar(
		absf(jogador.global_position.z - z_inicial) < 0.2,
		"dino fica parado sem input (dz=%.2f)" % (jogador.global_position.z - z_inicial)
	)

	Input.action_press("mover_frente")
	await _esperar_fisica(30)
	Input.action_release("mover_frente")
	_checar(
		jogador.global_position.z < z_inicial - 1.5,
		"dino avanca quando o jogador manda (dz=%.2f)" % (jogador.global_position.z - z_inicial)
	)
	_checar(
		float(corredor.call("distancia_percorrida")) > 0.0,
		"corredor mede a distancia (%.1f m)" % float(corredor.call("distancia_percorrida"))
	)

	var z_antes_tras: float = jogador.global_position.z
	Input.action_press("mover_tras")
	await _esperar_fisica(12)
	Input.action_release("mover_tras")
	_checar(
		jogador.global_position.z > z_antes_tras + 0.2,
		"dino recua com o botao de tras (dz=%.2f)" % (jogador.global_position.z - z_antes_tras)
	)

	for acao in ["mover_esquerda", "mover_direita", "mover_frente", "mover_tras", "pular", "rugido", "mordida"]:
		_checar(_tem_joystick(acao), "joystick mapeado em %s" % acao)
	_checar(
		_tem_eixo("mover_esquerda", 0) and _tem_eixo("mover_direita", 0),
		"analogico esquerdo no eixo X"
	)
	_checar(
		_tem_eixo("mover_frente", 1) and _tem_eixo("mover_tras", 1),
		"analogico esquerdo no eixo Y"
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
	await _esperar_fisica(40)

	var x_antes: float = jogador.global_position.x
	Input.action_press("mover_esquerda")
	await _esperar_fisica(10)
	Input.action_release("mover_esquerda")
	_checar(
		jogador.global_position.x < x_antes - 0.3,
		"movimento lateral (x=%.2f)" % jogador.global_position.x
	)

	# --- rugido quebra caixa ---
	var caixa: Node3D = get_tree().get_nodes_in_group("quebravel")[0]
	jogador.global_position = caixa.global_position + Vector3(0, -0.4, 2.0)
	await _esperar_fisica(6)
	jogador.call("executar_rugido")
	await _esperar_fisica(4)
	var caixas_depois: int = get_tree().get_nodes_in_group("quebravel").size()
	_checar(
		caixas_depois < caixas_antes,
		"rugido quebrou caixa (%d -> %d)" % [caixas_antes, caixas_depois]
	)

	# --- coletavel ---
	var item: Node3D = null
	for candidato in get_tree().get_nodes_in_group("coletavel"):
		if candidato.global_position.y < 0.1:
			item = candidato
			break
	_checar(item != null, "comida no chao encontrada")
	if item != null:
		var total_antes: int = int(jogador.get("total_comida"))
		jogador.global_position = item.global_position
		await _esperar_fisica(6)
		_checar(
			not is_instance_valid(item) or item.is_queued_for_deletion(),
			"comida encostada foi coletada"
		)
		_checar(
			int(jogador.get("total_comida")) == total_antes + 1,
			"contador de comida subiu (%d -> %d)" % [total_antes, int(jogador.get("total_comida"))]
		)

	# --- cai na fissura: volta ao ponto seguro ---
	var fissura: Node3D = null
	for buraco in get_tree().get_nodes_in_group("buraco"):
		if not bool(buraco.get_meta("lava")):
			fissura = buraco
			break
	_checar(fissura != null, "fissura localizada para o teste")
	if fissura != null:
		jogador.global_position = Vector3(0, 1.5, fissura.global_position.z)
		await _esperar_fisica(120)
		_checar(
			jogador.global_position.y > -1.0,
			"respawn depois de cair na fissura (y=%.2f)" % jogador.global_position.y
		)
		var meia: float = float(fissura.get_meta("largura")) * 0.5
		_checar(
			absf(jogador.global_position.z - fissura.global_position.z) > meia,
			"dino voltou para fora da fissura (z=%.1f)" % jogador.global_position.z
		)

	# --- cai na lava: volta ao ponto seguro ---
	var lava: Node3D = null
	for buraco in get_tree().get_nodes_in_group("buraco"):
		if bool(buraco.get_meta("lava")):
			lava = buraco
			break
	_checar(lava != null, "lava localizada para o teste")
	if lava != null:
		jogador.global_position = Vector3(0, 1.5, lava.global_position.z)
		await _esperar_fisica(120)
		_checar(
			jogador.global_position.y > -1.0,
			"respawn depois de encostar na lava (y=%.2f)" % jogador.global_position.y
		)

	# --- geracao infinita: avanca 600 m e o corredor acompanha ---
	var z_fuga: float = float(corredor.call("z_seguro_perto", -600.0))
	jogador.global_position = Vector3(0, 0.2, z_fuga)
	await _esperar_fisica(30)
	var pedacos: int = int(corredor.call("pedacos_ativos"))
	var z_mais_perto: float = -99999.0
	var z_mais_longe: float = 99999.0
	for filho in corredor.get_children():
		if filho is Node3D and String(filho.name).begins_with("Pedaco"):
			z_mais_perto = maxf(z_mais_perto, filho.global_position.z)
			z_mais_longe = minf(z_mais_longe, filho.global_position.z)
	_checar(
		z_mais_longe < z_fuga - 140.0,
		"corredor gerado bem a frente (z=%.0f)" % z_mais_longe
	)
	_checar(
		z_mais_perto < z_fuga + 100.0,
		"pedacos para tras foram apagados (z=%.0f)" % z_mais_perto
	)
	_checar(
		pedacos <= 20,
		"numero de pedacos controlado (%d)" % pedacos
	)

	jogador.global_position = Vector3(0, 0.2, 0)
	await _esperar_fisica(30)
	Input.action_press("mover_direita")
	await _esperar_fisica(60)
	Input.action_release("mover_direita")
	_checar(
		jogador.global_position.x <= 4.01,
		"dino dentro dos limites laterais (x=%.2f)" % jogador.global_position.x
	)

	_finalizar()


func _esperar_fisica(quadros: int) -> void:
	for i in quadros:
		await get_tree().physics_frame


func _tem_joystick(acao: String) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventJoypadMotion or evento is InputEventJoypadButton:
			return true
	return false


func _tem_eixo(acao: String, eixo: int) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventJoypadMotion and evento.axis == eixo:
			return true
	return false


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("[OK] ", descricao)
	else:
		_falhas += 1
		print("[FALHA] ", descricao)


func _finalizar() -> void:
	print("RESULTADO: %s (%d falhas)" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	get_tree().quit(0 if _falhas == 0 else 1)
