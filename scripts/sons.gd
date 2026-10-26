extends Node

const VOLUME_MUSICA_DB: float = -4.9
const VOLUME_FADE_DB: float = -40.0

var _streams: Dictionary = {}
var _musica_a: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _player_atual: AudioStreamPlayer
var _musica_atual: String = ""
var _tween_musica: Tween
var _buses_prontos: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configurar_buses()
	_streams = {
		"rugido": load("res://audio/rugido.wav"),
		"caixa": load("res://audio/caixa.wav"),
		"coletar": load("res://audio/coletar.wav"),
		"passo": load("res://audio/passo.wav"),
		"pulo": load("res://audio/pulo.wav"),
		"nivel": load("res://audio/nivel.wav"),
		"dano": load("res://audio/dano.wav"),
		"musica_fase": _carregar_musica("res://audio/musica_fase.ogg"),
		"musica_calmo": _carregar_musica("res://audio/musica_calmo.ogg"),
		"musica_menu": _carregar_musica("res://audio/musica_menu.ogg"),
		"musica_game_over": _carregar_musica("res://audio/musica_game_over.ogg"),
	}
	_musica_a = _criar_player_musica()
	_musica_b = _criar_player_musica()


func _configurar_buses() -> void:
	if _buses_prontos:
		return
	_buses_prontos = true

	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx_musica := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx_musica, "Music")
		AudioServer.set_bus_send(idx_musica, "Master")
		AudioServer.set_bus_volume_db(idx_musica, VOLUME_MUSICA_DB)

	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx_sfx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx_sfx, "SFX")
		AudioServer.set_bus_send(idx_sfx, "Master")


func _carregar_musica(caminho: String) -> AudioStream:
	var stream: AudioStream = load(caminho)
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func _criar_player_musica() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = VOLUME_FADE_DB
	add_child(player)
	return player


func tocar(nome: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(nome)
	if stream == null:
		push_warning("Som indisponivel: %s" % nome)
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func tocar_em(nome: String, posicao: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(nome)
	if stream == null:
		push_warning("Som indisponivel: %s" % nome)
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 12.0
	add_child(player)
	player.global_position = posicao
	player.finished.connect(player.queue_free)
	player.play()


func tocar_musica(nome: String, fade: float = 1.4) -> void:
	var stream: AudioStream = _streams.get("musica_" + nome)
	if stream == null:
		push_warning("Musica indisponivel: %s" % nome)
		return
	if _musica_atual == nome and _player_atual != null and _player_atual.playing:
		return

	var antigo := _player_atual
	var novo: AudioStreamPlayer
	if antigo == null:
		antigo = _musica_b
		novo = _musica_a
	else:
		novo = _musica_b if antigo == _musica_a else _musica_a

	if _tween_musica != null and _tween_musica.is_valid():
		_tween_musica.kill()
	for player in [_musica_a, _musica_b]:
		if player != antigo:
			player.stop()

	novo.stream = stream
	novo.volume_db = VOLUME_FADE_DB
	novo.play()
	_player_atual = novo
	_musica_atual = nome

	if fade <= 0.0:
		antigo.stop()
		novo.volume_db = 0.0
		return

	_tween_musica = create_tween().set_parallel(true)
	_tween_musica.tween_property(antigo, "volume_db", VOLUME_FADE_DB, fade)
	_tween_musica.tween_property(novo, "volume_db", 0.0, fade)
	_tween_musica.chain().tween_callback(antigo.stop)


func parar_musica(fade: float = 0.8) -> void:
	if _player_atual == null:
		return
	var antigo := _player_atual
	_player_atual = null
	_musica_atual = ""
	if _tween_musica != null and _tween_musica.is_valid():
		_tween_musica.kill()
	if fade <= 0.0:
		antigo.stop()
		return
	_tween_musica = create_tween()
	_tween_musica.tween_property(antigo, "volume_db", VOLUME_FADE_DB, fade)
	_tween_musica.tween_callback(antigo.stop)


func musica_atual() -> String:
	return _musica_atual


func esta_tocando_musica() -> bool:
	return _player_atual != null and _player_atual.playing and _musica_atual != ""


func possui_musica(nome: String) -> bool:
	var stream: AudioStream = _streams.get("musica_" + nome)
	return stream != null and stream.get_length() > 1.0


func possui_som(nome: String) -> bool:
	var stream: AudioStream = _streams.get(nome)
	return stream != null and stream.get_length() > 0.05
