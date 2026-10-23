extends Node
## Testa os dois ataques e a máquina de animação do dino:
##   - mordida (ação "mordida") quebra a caixa da frente e toca Attack
##   - rugido (ação "rugido") toca Roar, mesmo com caixa perto
##   - mordida no ar não rouba a animação de pulo
##   - Idle/Run seguem a velocidade

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	add_child(fase)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var jogador: Node3D = fase.get_node_or_null("TRex")
	_checar(jogador != null, "TRex instanciado")
	if jogador == null:
		_finalizar()
		return

	var anim: AnimationPlayer = jogador.get_node_or_null("Modelo/AnimationPlayer")
	_checar(anim != null, "AnimationPlayer no Modelo")
	if anim == null:
		_finalizar()
		return

	for nome in ["Idle", "Walk", "Run", "Jump", "Attack", "Roar"]:
		_checar(anim.has_animation(nome), "animacao %s importada" % nome)
	await _pousar(jogador)
	_checar(anim.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR, "Idle em loop")
	_checar(anim.get_animation("Run").loop_mode == Animation.LOOP_LINEAR, "Run em loop")
	_checar(anim.get_animation("Attack").loop_mode == Animation.LOOP_NONE, "Attack sem loop")
	_checar(anim.current_animation == "Idle", "comeca em Idle (%s)" % anim.current_animation)

	# --- comando mordida mapeado no teclado e no controle ---
	_checar(_tem_tecla("mordida"), "mordida no teclado (F)")
	_checar(_tem_joystick("mordida"), "mordida no controle (L1/R1)")
	_checar(_tem_tecla("rugido") and _tem_joystick("rugido"), "rugido continua mapeado")

	# --- mordida: caixa logo a frente ---
	var caixa: Node3D = get_tree().get_nodes_in_group("quebravel")[0]
	var antes: int = get_tree().get_nodes_in_group("quebravel").size()
	jogador.global_position = caixa.global_position + Vector3(0, 0, 2.2)
	await _pousar(jogador)

	_apertar("mordida")
	await _esperar_fisica(6)
	_checar(anim.current_animation == "Attack", "mordida tocou Attack (%s)" % anim.current_animation)

	await _esperar_fisica(20)
	var depois: int = get_tree().get_nodes_in_group("quebravel").size()
	_checar(depois < antes, "mordida quebrou a caixa (%d -> %d)" % [antes, depois])

	await _esperar_fisica(60)
	_checar(anim.current_animation == "Idle", "volta para Idle depois da mordida (%s)" % anim.current_animation)

	# --- mordida no ar nao interrompe o pulo ---
	_apertar("pular")
	await _esperar_fisica(5)
	_apertar("mordida")
	await _esperar_fisica(3)
	_checar(anim.current_animation == "Jump", "mordida no ar nao troca a animacao (%s)" % anim.current_animation)
	await _pousar(jogador)

	# --- rugido: com caixa perto ainda e Roar, nao Attack ---
	var outra: Node3D = get_tree().get_nodes_in_group("quebravel")[0]
	jogador.global_position = outra.global_position + Vector3(0, 0, 2.2)
	await _pousar(jogador)
	_apertar("rugido")
	await _esperar_fisica(6)
	_checar(anim.current_animation == "Roar", "rugido tocou Roar com caixa perto (%s)" % anim.current_animation)
	await _esperar_fisica(100)
	_checar(anim.current_animation == "Idle", "volta para Idle depois do rugido (%s)" % anim.current_animation)

	# --- locomocao ---
	jogador.global_position = Vector3(0, 1, -40)
	await _pousar(jogador)
	Input.action_press("mover_frente")
	await _esperar_fisica(30)
	_checar(anim.current_animation == "Run", "correndo toca Run (%s)" % anim.current_animation)
	_checar(anim.speed_scale > 1.0, "speed_scale acelerado (%.2f)" % anim.speed_scale)
	Input.action_release("mover_frente")
	await _esperar_fisica(30)
	_checar(anim.current_animation == "Idle", "parou e voltou para Idle (%s)" % anim.current_animation)

	_finalizar()


func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


func _pousar(jogador: Node3D) -> void:
	for i in 90:
		await get_tree().physics_frame
		if jogador.is_on_floor():
			break
	for i in 6:
		await get_tree().physics_frame


func _esperar_fisica(quadros: int) -> void:
	for i in quadros:
		await get_tree().physics_frame


func _tem_joystick(acao: String) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventJoypadMotion or evento is InputEventJoypadButton:
			return true
	return false


func _tem_tecla(acao: String) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventKey:
			return true
	return false


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("[OK] ", descricao)
	else:
		_falhas += 1
		print("[FALHA] ", descricao)


func _finalizar() -> void:
	print("RESULTADO: %s (%d falhas)" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	get_tree().quit(0 if _falhas == 0 else 1)
