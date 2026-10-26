extends Node
## Teste do sistema de vidas, corações e game over.

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	var corredor: Node3D = fase.get_node("Corredor")
	corredor.set("semente", 20261027)
	corredor.set("troncos_ativos", false)
	add_child(fase)

	await _esperar_fisica(60)

	var jogador: Node3D = fase.get_node_or_null("TRex")
	var hud: CanvasLayer = fase.get_node_or_null("HUD")
	var game_over: CanvasLayer = fase.get_node_or_null("GameOver")
	_checar(jogador != null, "TRex instanciado")
	_checar(hud != null, "HUD instanciado")
	_checar(game_over != null, "GameOver instanciado")
	if jogador == null or hud == null or game_over == null:
		_finalizar()
		return

	_checar(int(jogador.get("vidas")) == 5, "comeca com 5 vidas")
	_checar(hud.get_node("Coracoes").get_child_count() == 7, "HUD mostra 7 espacos de coracao")
	_checar(_contar_cheios(hud) == 5, "HUD comeca com 5 coracoes cheios")

	# ---------------------------------------------------------- coracao na caixa
	var caixas := get_tree().get_nodes_in_group("quebravel")
	_checar(caixas.size() > 0, "caixa disponivel para o teste")
	if caixas.is_empty():
		_finalizar()
		return

	var caixa: Node3D = caixas[0]
	caixa.set("chance_coracao", 1.0)
	caixa.call("quebrar")
	await _esperar_fisica(30)

	var coracoes := get_tree().get_nodes_in_group("coracao")
	_checar(coracoes.size() == 1, "caixa soltou um coracao")
	if coracoes.is_empty():
		_finalizar()
		return

	var coracao: Node3D = coracoes[0]
	jogador.global_position = coracao.global_position
	await _esperar_fisica(40)
	_checar(int(jogador.get("vidas")) == 6, "coracao cura uma vida")
	_checar(_contar_cheios(hud) == 6, "HUD acompanha a cura")

	_checar(bool(jogador.call("ganhar_vida")), "pode chegar a 7 vidas")
	_checar(int(jogador.get("vidas")) == 7, "vidas chegam ao maximo 7")
	_checar(_contar_cheios(hud) == 7, "HUD mostra 7 coracoes cheios")
	_checar(not bool(jogador.call("ganhar_vida")), "nao passa de 7 vidas")

	var caixas_depois := get_tree().get_nodes_in_group("quebravel")
	for candidata in caixas_depois:
		if not is_instance_valid(candidata) or candidata.is_queued_for_deletion():
			continue
		var caixa_cheia: Node3D = candidata
		caixa_cheia.set("chance_coracao", 1.0)
		caixa_cheia.call("quebrar")
		break
	await _esperar_fisica(20)
	_checar(get_tree().get_nodes_in_group("coracao").is_empty(), "com 7 vidas a caixa nao solta coracao")

	# ---------------------------------------------------------- tronco
	var antes_tronco: int = int(jogador.get("vidas"))
	jogador.call("levar_tronco")
	_checar(int(jogador.get("vidas")) == antes_tronco - 1, "tronco tira uma vida")
	_checar(_tocou_som("dano"), "dano toca efeito sonoro")
	jogador.call("levar_tronco")
	_checar(int(jogador.get("vidas")) == antes_tronco - 1, "invulnerabilidade evita dano duplicado")
	await _esperar_fisica(100)

	# ---------------------------------------------------------- buraco
	var fissura: Node3D = null
	for buraco in get_tree().get_nodes_in_group("buraco"):
		if not bool(buraco.get_meta("lava")):
			fissura = buraco
			break
	_checar(fissura != null, "fissura localizada")
	if fissura != null:
		var antes_buraco: int = int(jogador.get("vidas"))
		var largura := float(fissura.get_meta("largura"))
		jogador.global_position = Vector3(0, 1.5, fissura.global_position.z)
		await _esperar_fisica(120)
		_checar(int(jogador.get("vidas")) == antes_buraco - 1, "buraco tira uma vida")
		_checar(jogador.global_position.y > -1.0, "dino volta ao chao depois do buraco")
		_checar(
			jogador.global_position.z < fissura.global_position.z - largura * 0.5 - 1.0,
			"dino volta depois do buraco"
		)
		_checar(_contar_cheios(hud) == int(jogador.get("vidas")), "HUD acompanha o dano do buraco")

	await _esperar_fisica(100)

	# ---------------------------------------------------------- lava
	var lava: Node3D = null
	for buraco in get_tree().get_nodes_in_group("buraco"):
		if bool(buraco.get_meta("lava")):
			lava = buraco
			break
	_checar(lava != null, "lava localizada")
	if lava != null:
		var antes_lava: int = int(jogador.get("vidas"))
		var largura_lava := float(lava.get_meta("largura"))
		jogador.global_position = Vector3(0, 1.5, lava.global_position.z)
		await _esperar_fisica(120)
		_checar(int(jogador.get("vidas")) == antes_lava - 1, "lava tira uma vida")
		_checar(jogador.global_position.y > -1.0, "dino volta ao chao depois da lava")
		_checar(
			jogador.global_position.z < lava.global_position.z - largura_lava * 0.5 - 1.0,
			"dino volta depois da lava"
		)

	await _esperar_fisica(100)

	# ---------------------------------------------------------- game over
	jogador.set("vidas", 1)
	jogador.call("receber_dano", "teste")
	_checar(int(jogador.get("vidas")) == 0, "chega a 0 vidas")
	_checar(not bool(jogador.call("esta_vivo")), "jogador fica sem vidas")
	_checar(game_over.visible, "game over aparece")
	_checar(get_tree().paused, "jogo pausa no game over")
	_checar(Sons.musica_atual() == "game_over", "game over troca a trilha")
	_checar(Sons.esta_tocando_musica(), "trilha continua durante a pausa")
	_checar(
		game_over.get_node("Centro/Caixa/Margem/Conteudo/Titulo").text == "QUASE!",
		"titulo fofo do game over"
	)
	_checar(
		game_over.get_node("Centro/Caixa/Margem/Conteudo/Botoes/BotaoTentar").text == "TENTAR NOVAMENTE",
		"botao Tentar Novamente existe"
	)
	_checar(
		game_over.get_node("Centro/Caixa/Margem/Conteudo/Botoes/BotaoSair").text == "SAIR",
		"botao Sair existe"
	)
	_checar(game_over.tentar_novamente.get_connections().size() > 0, "Tentar Novamente conectado ao fluxo")
	_checar(game_over.sair.get_connections().size() > 0, "Sair conectado ao fluxo")

	get_tree().paused = false
	_finalizar()


func _contar_cheios(hud: Node) -> int:
	var total := 0
	for coracao in hud.get_node("Coracoes").get_children():
		if bool(coracao.get_meta("cheio", false)):
			total += 1
	return total


func _tocou_som(nome: String) -> bool:
	for filho in Sons.get_children():
		if filho is AudioStreamPlayer:
			var player := filho as AudioStreamPlayer
			if player.stream != null and player.stream.resource_path.get_file().begins_with(nome + "."):
				return true
	return false


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
