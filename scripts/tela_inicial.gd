extends Control
## Tela inicial: COMEÇAR inicia a fase; SEU NOME abre o campo de digitação.

const CENA_FASE := "res://scenes/fase_1.tscn"

@onready var botao_comecar: Button = $Centro/Conteudo/BotaoComecar
@onready var botao_nome: Button = $Centro/Conteudo/BotaoNome
@onready var rotulo_nome: Label = $Centro/Conteudo/RotuloNome
@onready var escurecer: ColorRect = $Escurecer
@onready var painel_nome: CenterContainer = $PainelNome
@onready var entrada_nome: LineEdit = $PainelNome/Caixa/Margem/ConteudoNome/EntradaNome
@onready var botao_salvar: Button = $PainelNome/Caixa/Margem/ConteudoNome/BotoesNome/BotaoSalvar
@onready var botao_cancelar: Button = $PainelNome/Caixa/Margem/ConteudoNome/BotoesNome/BotaoCancelar


func _ready() -> void:
	botao_comecar.pressed.connect(_ao_comecar)
	botao_nome.pressed.connect(_abrir_nome)
	botao_salvar.pressed.connect(_salvar_nome)
	botao_cancelar.pressed.connect(_fechar_nome)
	entrada_nome.text_submitted.connect(_ao_enviar_nome)

	painel_nome.visible = false
	escurecer.visible = false
	_atualizar_rotulo()
	botao_comecar.grab_focus()


func _ao_comecar() -> void:
	if not ResourceLoader.exists(CENA_FASE):
		push_error("Cena da fase nao encontrada: %s" % CENA_FASE)
		return
	get_tree().change_scene_to_file(CENA_FASE)


func _abrir_nome() -> void:
	entrada_nome.text = Dados.nome_jogador
	painel_nome.visible = true
	escurecer.visible = true
	entrada_nome.grab_focus()
	entrada_nome.select_all()


func _fechar_nome() -> void:
	painel_nome.visible = false
	escurecer.visible = false
	botao_comecar.grab_focus()


func _salvar_nome() -> void:
	Dados.definir_nome(entrada_nome.text)
	_atualizar_rotulo()
	_fechar_nome()


func _ao_enviar_nome(_texto: String) -> void:
	_salvar_nome()


func _atualizar_rotulo() -> void:
	rotulo_nome.text = "JOGADOR: %s" % Dados.nome_jogador


func _unhandled_input(evento: InputEvent) -> void:
	if painel_nome.visible and evento.is_action_pressed("ui_cancel"):
		_fechar_nome()
		get_viewport().set_input_as_handled()
