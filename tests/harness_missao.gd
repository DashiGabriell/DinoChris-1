extends Node
## Teste da missão infinita: HUD, comidas geradas no corredor, subida de nível.

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	fase.get_node("Corredor").set("semente", 20261023)
	add_child(fase)
	await _esperar_fisica(6)

	var jogador: Node3D = fase.get_node_or_null("TRex")
	var hud: CanvasLayer = fase.get_node_or_null("HUD")
	_checar(jogador != null and hud != null, "fase com TRex e HUD")
	if jogador == null or hud == null:
		_finalizar()
		return

	var nivel_label: Label = hud.get_node("Missao/Margem/Conteudo/Nivel")
	var contador: Label = hud.get_node("Missao/Margem/Conteudo/Contador")
	var barra: ProgressBar = hud.get_node("Missao/Margem/Conteudo/Barra")
	var total_label: Label = hud.get_node("Missao/Margem/Conteudo/Total")
	var aviso: Label = hud.get_node("Aviso")
	var aviso_fundo: PanelContainer = hud.get_node("AvisoFundo")

	_checar(nivel_label.text == "NÍVEL 1", "HUD mostra nível 1 (achei '%s')" % nivel_label.text)
	_checar(contador.text == "COMIDA: 0 / 8", "HUD mostra 0/8 (achei '%s')" % contador.text)
	_checar(barra.max_value == 8.0 and barra.value == 0.0, "barra começa vazia com meta 8")
	_checar(total_label.text == "TOTAL: 0", "HUD mostra total 0 (achei '%s')" % total_label.text)

	var tipos: Array[int] = []
	var posicoes: Array[Vector3] = []
	for no in get_tree().get_nodes_in_group("coletavel"):
		if not fase.is_ancestor_of(no):
			continue
		if no.global_position.y > 0.1:
			continue
		tipos.append(int(no.get("tipo")))
		posicoes.append(no.global_position)

	_checar(posicoes.size() >= 8, "comidas no corredor (achei %d)" % posicoes.size())

	var vistos: Array[int] = []
	for tipo in tipos:
		if not vistos.has(tipo):
			vistos.append(tipo)
	_checar(vistos.size() == 4, "comidas têm os 4 tipos (achei %d)" % vistos.size())

	if not posicoes.is_empty():
		var primeiro: Node = get_tree().get_nodes_in_group("coletavel")[0]
		_checar(
			primeiro.find_child("Visual", true, false).get_child_count() > 0,
			"comida tem desenho 3D montado"
		)

	var total := 0
	for i in mini(8, posicoes.size()):
		jogador.global_position = posicoes[i]
		await _esperar_fisica(5)
		total = int(jogador.get("total_comida"))
	_checar(total == 8, "dino comeu 8 comidas (achei %d)" % total)

	await _esperar_fisica(6)
	_checar(int(jogador.get("nivel")) == 2, "subiu para o nível 2 (achei %d)" % int(jogador.get("nivel")))
	_checar(int(jogador.get("comida_no_nivel")) == 0, "barra do nível reiniciou em 0")
	_checar(aviso.text == "NÍVEL 2!", "aviso de nível 2 apareceu (achei '%s')" % aviso.text)
	_checar(
		aviso.get_global_rect().get_center().distance_to(aviso_fundo.get_global_rect().get_center()) < 0.5,
		"texto centralizado no pop-up"
	)
	_checar(nivel_label.text == "NÍVEL 2", "HUD mostra nível 2 (achei '%s')" % nivel_label.text)
	_checar(contador.text == "COMIDA: 0 / 9", "HUD mostra nova meta 9 (achei '%s')" % contador.text)
	_checar(barra.max_value == 9.0, "barra agora vai até 9 (achei %.1f)" % barra.max_value)
	_checar(total_label.text == "TOTAL: 8", "HUD mostra total 8 (achei '%s')" % total_label.text)

	# o corredor é infinito: depois do nível novo ainda existem comidas à frente
	var comidas_depois: int = 0
	for no in get_tree().get_nodes_in_group("coletavel"):
		if fase.is_ancestor_of(no):
			comidas_depois += 1
	_checar(comidas_depois > 0, "comidas continuam sendo geradas (%d)" % comidas_depois)

	await _esperar_fisica(54)
	_checar(aviso.modulate.a < 0.05, "pop-up some em menos de 1 s")

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
