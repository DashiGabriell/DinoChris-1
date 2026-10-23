extends Node
## Autoload "Dados": estado persistente entre cenas (nome do jogador).

const CAMINHO := "user://dados.cfg"
const NOME_PADRAO := "AMIGO"

var nome_jogador: String = NOME_PADRAO


func _ready() -> void:
	carregar()


func carregar() -> void:
	var config := ConfigFile.new()
	if config.load(CAMINHO) != OK:
		return
	var valor := str(config.get_value("jogador", "nome", NOME_PADRAO)).strip_edges()
	nome_jogador = valor if not valor.is_empty() else NOME_PADRAO


func definir_nome(valor: String) -> void:
	var limpo := valor.strip_edges().substr(0, 16)
	if limpo.is_empty():
		limpo = NOME_PADRAO
	nome_jogador = limpo

	var config := ConfigFile.new()
	config.set_value("jogador", "nome", nome_jogador)
	config.save(CAMINHO)
