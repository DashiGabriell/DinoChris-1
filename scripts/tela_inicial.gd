extends Control
## Tela inicial: COMEÇAR inicia a fase; SEU NOME abre o campo de digitação.
## COMO JOGAR mostra os controles com pictogramas.

const CENA_FASE := "res://scenes/fase_1.tscn"

@onready var botao_comecar: Button = $Centro/Conteudo/BotaoComecar
@onready var botao_nome: Button = $Centro/Conteudo/BotaoNome
@onready var botao_como_jogar: Button = $Centro/Conteudo/BotaoComoJogar
@onready var rotulo_nome: Label = $Centro/Conteudo/RotuloNome
@onready var conteudo: VBoxContainer = $Centro/Conteudo
@onready var escurecer: ColorRect = $Escurecer
@onready var painel_nome: CenterContainer = $PainelNome
@onready var entrada_nome: LineEdit = $PainelNome/Caixa/Margem/ConteudoNome/EntradaNome
@onready var botao_salvar: Button = $PainelNome/Caixa/Margem/ConteudoNome/BotoesNome/BotaoSalvar
@onready var botao_cancelar: Button = $PainelNome/Caixa/Margem/ConteudoNome/BotoesNome/BotaoCancelar
@onready var painel_controles: CenterContainer = $PainelControles
@onready var botao_efeitos: Button = $PainelControles/Caixa/Margem/ConteudoControles/BotaoEfeitos
@onready var botao_fechar_controles: Button = $PainelControles/Caixa/Margem/ConteudoControles/BotaoFecharControles
@onready var vaga_lumes: CPUParticles2D = $VagaLumes


func _ready() -> void:
	Sons.tocar_musica("menu")
	botao_comecar.pressed.connect(_ao_comecar)
	botao_nome.pressed.connect(_abrir_nome)
	botao_como_jogar.pressed.connect(_abrir_controles)
	botao_salvar.pressed.connect(_salvar_nome)
	botao_cancelar.pressed.connect(_fechar_nome)
	botao_efeitos.pressed.connect(_alternar_efeitos)
	botao_fechar_controles.pressed.connect(_fechar_controles)
	entrada_nome.text_submitted.connect(_ao_enviar_nome)

	painel_nome.visible = false
	painel_controles.visible = false
	escurecer.visible = false
	vaga_lumes.emitting = not Dados.modo_calmo
	_atualizar_rotulo()
	_atualizar_botao_efeitos()
	_conectar_sons()
	_animar_entrada()
	botao_comecar.grab_focus()


func _animar_entrada() -> void:
	conteudo.modulate.a = 0.0
	if Dados.modo_calmo:
		conteudo.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_property(conteudo, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _conectar_sons() -> void:
	for botao in [botao_comecar, botao_nome, botao_como_jogar, botao_salvar, botao_cancelar, botao_efeitos, botao_fechar_controles]:
		if botao == null:
			continue
		botao.focus_entered.connect(_som_foco)
		botao.mouse_entered.connect(_som_foco)


func _som_foco() -> void:
	Sons.tocar("passo", -26.0, 1.85)


func _ao_comecar() -> void:
	if not ResourceLoader.exists(CENA_FASE):
		push_error("Cena da fase nao encontrada: %s" % CENA_FASE)
		return
	Sons.tocar("rugido", -12.0, 1.25)
	get_tree().change_scene_to_file(CENA_FASE)


func _abrir_nome() -> void:
	Sons.tocar("coletar", -14.0, 1.35)
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
	Sons.tocar("coletar", -10.0, 1.1)
	_fechar_nome()


func _ao_enviar_nome(_texto: String) -> void:
	_salvar_nome()


func _abrir_controles() -> void:
	Sons.tocar("caixa", -20.0, 1.7)
	painel_nome.visible = false
	escurecer.visible = true
	painel_controles.visible = true
	_atualizar_botao_efeitos()
	botao_fechar_controles.grab_focus()


func _fechar_controles() -> void:
	painel_controles.visible = false
	escurecer.visible = false
	botao_como_jogar.grab_focus()


func _alternar_efeitos() -> void:
	Dados.definir_modo_calmo(not Dados.modo_calmo)
	vaga_lumes.emitting = not Dados.modo_calmo
	_atualizar_botao_efeitos()
	Sons.tocar("caixa", -22.0, 1.7)


func _atualizar_botao_efeitos() -> void:
	botao_efeitos.text = "EFEITOS: SUAVES" if Dados.modo_calmo else "EFEITOS: NORMAIS"


func _atualizar_rotulo() -> void:
	rotulo_nome.text = "JOGADOR: %s" % Dados.nome_jogador


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("ui_cancel"):
		return
	if painel_controles.visible:
		_fechar_controles()
		get_viewport().set_input_as_handled()
	elif painel_nome.visible:
		_fechar_nome()
		get_viewport().set_input_as_handled()
