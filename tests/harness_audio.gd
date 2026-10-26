extends Node

var _falhas: int = 0


func _ready() -> void:
	await get_tree().process_frame

	_checar(AudioServer.get_bus_index("Music") >= 0, "bus Music existe")
	_checar(AudioServer.get_bus_index("SFX") >= 0, "bus SFX existe")
	_checar(Sons.process_mode == Node.PROCESS_MODE_ALWAYS, "Sons processa durante a pausa")

	var streams: Dictionary = Sons.get("_streams")
	for nome in ["musica_menu", "musica_fase", "musica_calmo", "musica_game_over"]:
		var stream: AudioStream = streams.get(nome)
		_checar(stream != null, "%s carregada" % nome)
		if stream != null:
			_checar(stream.get_length() > 10.0, "%s tem loop longo" % nome)
			_checar(stream is AudioStreamOggVorbis, "%s e OGG" % nome)
			if stream is AudioStreamOggVorbis:
				_checar((stream as AudioStreamOggVorbis).loop, "%s esta em loop" % nome)

	for nome in ["menu", "fase", "calmo", "game_over"]:
		_checar(Sons.possui_musica(nome), "Sons conhece a musica %s" % nome)

	Sons.tocar_musica("fase", 0.0)
	await get_tree().process_frame
	_checar(Sons.musica_atual() == "fase", "fase troca para a trilha da partida")
	_checar(Sons.esta_tocando_musica(), "trilha da partida esta tocando")

	Sons.tocar_musica("calmo", 0.0)
	await get_tree().process_frame
	_checar(Sons.musica_atual() == "calmo", "modo calmo tem trilha propria")

	Sons.tocar_musica("game_over", 0.0)
	await get_tree().process_frame
	_checar(Sons.musica_atual() == "game_over", "game over tem trilha propria")

	Sons.tocar_musica("menu", 0.0)
	await get_tree().process_frame
	_checar(Sons.musica_atual() == "menu", "menu tem trilha propria")

	Sons.parar_musica(0.0)
	await get_tree().process_frame
	_checar(Sons.musica_atual() == "", "parar_musica limpa a trilha atual")
	_checar(not Sons.esta_tocando_musica(), "parar_musica interrompe o player")

	_finalizar()


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("[OK] ", descricao)
	else:
		_falhas += 1
		print("[FALHA] ", descricao)


func _finalizar() -> void:
	print("RESULTADO: %s (%d falhas)" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	get_tree().quit(0 if _falhas == 0 else 1)
