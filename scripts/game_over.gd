extends CanvasLayer
## Tela fofa de fim de vidas. O fluxo de cena é coordenado por Fase1.

signal tentar_novamente
signal sair

@onready var botao_tentar: Button = $Centro/Caixa/Margem/Conteudo/Botoes/BotaoTentar
@onready var botao_sair: Button = $Centro/Caixa/Margem/Conteudo/Botoes/BotaoSair

var _jogador: Node = null


func _ready() -> void:
	visible = false
	botao_tentar.pressed.connect(_pedir_tentar)
	botao_sair.pressed.connect(_pedir_sair)

	_jogador = get_tree().get_first_node_in_group("jogador")
	if _jogador != null and _jogador.has_signal("morreu"):
		_jogador.connect("morreu", _ao_morrer)


func _ao_morrer() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	Sons.tocar_musica("game_over", 0.7)
	Sons.tocar("caixa", -16.0, 0.55)
	botao_tentar.grab_focus()


func _pedir_tentar() -> void:
	Sons.tocar("pulo", -10.0, 1.2)
	tentar_novamente.emit()


func _pedir_sair() -> void:
	Sons.tocar("caixa", -20.0, 1.15)
	sair.emit()
