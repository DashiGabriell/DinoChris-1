extends Node
## Script temporario de verificacao: roda a fase e salva prints do dino em acao.

var _jogador: Node3D


func _esperar(quadros: int) -> void:
	for i in quadros:
		await get_tree().process_frame


func _print(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var imagem: Image = get_viewport().get_texture().get_image()
	var caminho := ProjectSettings.globalize_path("res://tools/rig/out/") + nome + ".png"
	var erro := imagem.save_png(caminho)
	print("###PRINT### ", nome, " erro=", erro)


func _ready() -> void:
	var cena: Node3D = load("res://scenes/fase_1.tscn").instantiate()
	add_child(cena)
	_jogador = cena.get_node_or_null("TRex")

	await _esperar(20)
	await _print("jogo_01_idle")

	Input.action_press("mover_frente")
	await _esperar(50)
	await _print("jogo_02_correndo")

	Input.action_press("mover_esquerda")
	await _esperar(25)
	await _print("jogo_03_desviando")
	Input.action_release("mover_esquerda")
	Input.action_release("mover_frente")

	await _esperar(30)
	_jogador.call("executar_rugido")
	await _esperar(18)
	await _print("jogo_04_rugindo")

	await _esperar(60)
	Input.action_press("pular")
	await _esperar(10)
	Input.action_release("pular")
	await _print("jogo_05_pulando")

	await _esperar(20)
	await _print("jogo_06_aterrissando")

	# mordida: encosta na caixa mais prÃ³xima e usa o comando dedicado
	var caixa: Node3D = null
	for candidato in get_tree().get_nodes_in_group("quebravel"):
		if caixa == null or candidato.global_position.distance_to(_jogador.global_position) < caixa.global_position.distance_to(_jogador.global_position):
			caixa = candidato
	if caixa != null:
		_jogador.global_position = caixa.global_position + Vector3(0, 0, 2.4)
		await _esperar(40)
		await _print("jogo_07_antes_da_mordida")
		Input.action_press("mordida")
		await _esperar(2)
		Input.action_release("mordida")
		await _esperar(14)
		await _print("jogo_08_mordendo")
		await _esperar(14)
		await _print("jogo_09_depois_da_mordida")

	get_tree().quit(0)

