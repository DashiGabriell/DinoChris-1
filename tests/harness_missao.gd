extends Node

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	add_child(fase)
	await _esperar_fisica(3)

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

	_checar(nivel_label.text == "NÍVEL 1", "HUD mostra nível 1 (achei '%s')" % nivel_label.text)
	_checar(contador.text == "COMIDA: 0 / 8", "HUD mostra 0/8 (achei '%s')" % contador.text)
	_checar(barra.max_value == 8.0 and barra.value == 0.0, "barra começa vazia com meta 8")
	_checar(total_label.text == "TOTAL: 0", "HUD mostra total 0 (achei '%s')" % total_label.text)

	var tipos: Array[int] = []
	var posicoes: Array[Vector3] = []
	for no in get_tree().get_nodes_in_group("coletavel"):
		if not fase.is_ancestor_of(no):
			continue
		tipos.append(int(no.get("tipo")))
		posicoes.append(no.global_position)

	_checar(tipos.size() == 24, "24 comidas na fase (achei %d)" % tipos.size())

	var alternado: bool = true
	for i in tipos.size():
		if tipos[i] != i % 4:
			alternado = false
	_checar(alternado, "comidas alternam carne, fruta, vegetal e água")

	var primeiro: Node = get_tree().get_nodes_in_group("coletavel")[0]
	_checar(
		primeiro.get_node("Visual").get_child_count() > 0,
		"comida tem desenho 3D montado"
	)

	var total := 0
	for i in 8:
		jogador.global_position = posicoes[i]
		await _esperar_fisica(6)
		total = int(jogador.get("total_comida"))
	_checar(total == 8, "dino comeu 8 comidas (achei %d)" % total)

	await _esperar_fisica(6)
	_checar(int(jogador.get("nivel")) == 2, "subiu para o nível 2 (achei %d)" % int(jogador.get("nivel")))
	_checar(int(jogador.get("comida_no_nivel")) == 0, "barra do nível reiniciou em 0")
	_checar(aviso.text == "NÍVEL 2!", "aviso de nível 2 apareceu (achei '%s')" % aviso.text)
	_checar(nivel_label.text == "NÍVEL 2", "HUD mostra nível 2 (achei '%s')" % nivel_label.text)
	_checar(contador.text == "COMIDA: 0 / 9", "HUD mostra nova meta 9 (achei '%s')" % contador.text)
	_checar(barra.max_value == 9.0, "barra agora vai até 9 (achei %.1f)" % barra.max_value)
	_checar(total_label.text == "TOTAL: 8", "HUD mostra total 8 (achei '%s')" % total_label.text)

	var comidas_depois: int = 0
	for no in get_tree().get_nodes_in_group("coletavel"):
		if fase.is_ancestor_of(no):
			comidas_depois += 1
	_checar(
		comidas_depois == 23,
		"comidas foram repostas ao subir de nível (achei %d)" % comidas_depois
	)

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
