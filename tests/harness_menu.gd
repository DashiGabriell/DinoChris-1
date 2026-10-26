extends Node
## Testa a tela inicial: botoes, painel de nome e persistencia.

var _falhas: int = 0


func _ready() -> void:
	var nome_original: String = Dados.nome_jogador

	var tela: Control = load("res://scenes/tela_inicial.tscn").instantiate()
	add_child(tela)
	await get_tree().process_frame
	await get_tree().process_frame

	var botao_comecar: Button = tela.get_node_or_null("Centro/Conteudo/BotaoComecar")
	var botao_nome: Button = tela.get_node_or_null("Centro/Conteudo/BotaoNome")
	var painel: CenterContainer = tela.get_node_or_null("PainelNome")
	var entrada: LineEdit = tela.get_node_or_null("PainelNome/Caixa/Margem/ConteudoNome/EntradaNome")
	var salvar: Button = tela.get_node_or_null(
		"PainelNome/Caixa/Margem/ConteudoNome/BotoesNome/BotaoSalvar"
	)
	var cancelar: Button = tela.get_node_or_null(
		"PainelNome/Caixa/Margem/ConteudoNome/BotoesNome/BotaoCancelar"
	)
	var rotulo: Label = tela.get_node_or_null("Centro/Conteudo/RotuloNome")

	_checar(botao_comecar != null and botao_comecar.text == "COMEÇAR", "botao COMECAR presente")
	_checar(botao_nome != null and botao_nome.text == "SEU NOME", "botao SEU NOME presente")
	_checar(painel != null and entrada != null and salvar != null, "painel de nome montado")
	_checar(
		ResourceLoader.exists("res://scenes/fase_1.tscn"),
		"cena da fase existe"
	)
	_checar(painel != null and not painel.visible, "painel comeca escondido")
	_checar(Sons.musica_atual() == "menu", "menu toca a trilha do menu")
	_checar(InputMap.has_action("iniciar"), "acao iniciar existe")
	_checar(_tem_botao_start(), "botao Start mapeado no controle")
	if painel == null or entrada == null or salvar == null or botao_nome == null:
		_finalizar(nome_original)
		return

	botao_nome.pressed.emit()
	await get_tree().process_frame
	_checar(painel.visible, "painel abre ao clicar em SEU NOME")
	_checar(tela.get_node("Escurecer").visible, "fundo escurece junto")

	entrada.text = "  Chris  "
	entrada.text_submitted.emit(entrada.text)
	await get_tree().process_frame
	_checar(Dados.nome_jogador == "Chris", "nome salvo sem espacos (%s)" % Dados.nome_jogador)
	_checar(not painel.visible, "painel fecha ao salvar")
	_checar(rotulo.text == "JOGADOR: Chris", "rotulo atualizado (%s)" % rotulo.text)

	Dados.definir_nome("")
	_checar(Dados.nome_jogador == "AMIGO", "nome vazio vira AMIGO")

	Dados.definir_nome("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	_checar(Dados.nome_jogador.length() == 16, "nome limitado a 16 letras")

	botao_nome.pressed.emit()
	await get_tree().process_frame
	cancelar.pressed.emit()
	await get_tree().process_frame
	_checar(not painel.visible, "CANCELAR fecha o painel")

	_finalizar(nome_original)


func _tem_botao_start() -> bool:
	for evento in InputMap.action_get_events("iniciar"):
		if evento is InputEventJoypadButton and evento.button_index == JOY_BUTTON_START:
			return true
	return false


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
