extends Node
## Autoload "Sons": toca efeitos sem precisar de um AudioStreamPlayer em cada cena.
## Os arquivos são carregados em _ready() (e não com preload) para o projeto
## abrir sem erro mesmo na primeira importação dos WAVs.

var _streams: Dictionary = {}


func _ready() -> void:
	_streams = {
		"rugido": load("res://audio/rugido.wav"),
		"caixa": load("res://audio/caixa.wav"),
		"coletar": load("res://audio/coletar.wav"),
		"passo": load("res://audio/passo.wav"),
		"pulo": load("res://audio/pulo.wav"),
	}


func tocar(nome: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(nome)
	if stream == null:
		push_warning("Som indisponivel: %s" % nome)
		return
	var player := AudioStreamPlayer.new()
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
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 12.0
	add_child(player)
	player.global_position = posicao
	player.finished.connect(player.queue_free)
	player.play()
