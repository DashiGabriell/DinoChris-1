extends Node
## Autoload "Dados": estado persistente entre cenas (nome do jogador).

const CAMINHO := "user://dados.cfg"
const NOME_PADRAO := "AMIGO"

var nome_jogador: String = NOME_PADRAO
var modo_calmo: bool = false


func _ready() -> void:
	carregar()


func carregar() -> void:
	var config := ConfigFile.new()
	if config.load(CAMINHO) != OK:
		return
	var valor := str(config.get_value("jogador", "nome", NOME_PADRAO)).strip_edges()
	nome_jogador = valor if not valor.is_empty() else NOME_PADRAO
	modo_calmo = bool(config.get_value("opcoes", "modo_calmo", false))


func definir_nome(valor: String) -> void:
	var limpo := valor.strip_edges().substr(0, 16)
	if limpo.is_empty():
		limpo = NOME_PADRAO
	nome_jogador = limpo
	_salvar("jogador", "nome", nome_jogador)


func definir_modo_calmo(valor: bool) -> void:
	modo_calmo = valor
	_salvar("opcoes", "modo_calmo", modo_calmo)


func _salvar(secao: String, chave: String, valor: Variant) -> void:
	var config := ConfigFile.new()
	config.load(CAMINHO)
	config.set_value(secao, chave, valor)
	config.save(CAMINHO)
