extends Node
## Teste de integração: Start no menu carrega a fase e o nome aparece no HUD.

var _falhas: int = 0


func _ready() -> void:
	var nome_original: String = Dados.nome_jogador
	Dados.definir_nome("Chris")

	var tela: Node = load("res://scenes/tela_inicial.tscn").instantiate()
	get_tree().root.add_child.call_deferred(tela)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = tela
	await get_tree().process_frame
	await get_tree().process_frame

	var botao: Button = tela.get_node_or_null("Centro/Conteudo/BotaoComecar")
	_checar(botao != null, "botao COMECAR encontrado")
	if botao == null:
		_finalizar(nome_original)
		return

	_checar(botao.pressed.get_connections().size() > 0, "botao COMECAR conectado")
	var evento_iniciar := InputEventJoypadButton.new()
	evento_iniciar.button_index = JOY_BUTTON_START
	evento_iniciar.pressed = true
	evento_iniciar.device = 0
	tela.call("_unhandled_input", evento_iniciar)
	for i in 8:
		await get_tree().process_frame

	var cena: Node = get_tree().current_scene
	var nome_cena := "null" if cena == null else str(cena.name)
	_checar(nome_cena == "Fase1", "Start carrega a fase (atual: %s)" % nome_cena)

	if cena != null and cena.name == "Fase1":
		var hud: Label = cena.get_node_or_null("HUD/Nome")
		_checar(hud != null and hud.text == "Chris", "nome do jogador aparece no HUD")
		_checar(cena.get_node_or_null("TRex") != null, "TRex existe na fase carregada")
		var trilha := "calmo" if Dados.modo_calmo else "fase"
		_checar(Sons.musica_atual() == trilha, "fase troca para a trilha %s" % trilha)

	_finalizar(nome_original)


func _finalizar(nome_original: String) -> void:
	Dados.definir_nome(nome_original)
	print("RESULTADO: %s (%d falhas)" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	get_tree().quit(0 if _falhas == 0 else 1)


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("[OK] ", descricao)
	else:
		_falhas += 1
		print("[FALHA] ", descricao)
