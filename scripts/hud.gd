extends CanvasLayer
## HUD da fase: nome do jogador, nível, comida coletada e barra do nível.

@onready var nome: Label = $Nome
@onready var nivel_label: Label = $Missao/Margem/Conteudo/Nivel
@onready var contador: Label = $Missao/Margem/Conteudo/Contador
@onready var barra: ProgressBar = $Missao/Margem/Conteudo/Barra
@onready var total: Label = $Missao/Margem/Conteudo/Total
@onready var aviso: Label = $Aviso

var _jogador: Node = null
var _tween_aviso: Tween = null
var _flash_dano: ColorRect = null
var _tween_dano: Tween = null


func _ready() -> void:
	nome.text = Dados.nome_jogador
	aviso.modulate.a = 0.0
	_criar_flash()

	_jogador = get_tree().get_first_node_in_group("jogador")
	if _jogador == null:
		return

	_jogador.connect("comida_coletada", _ao_coletar)
	_jogador.connect("subiu_nivel", _ao_subir_nivel)
	if _jogador.has_signal("levou_dano"):
		_jogador.connect("levou_dano", _ao_levar_dano)
	_atualizar(0, int(_jogador.call("meta_nivel")), 1, 0)


func _criar_flash() -> void:
	_flash_dano = ColorRect.new()
	_flash_dano.color = Color(1.0, 0.12, 0.05, 0.0)
	_flash_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_dano.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_dano.z_index = 50
	add_child(_flash_dano)


func _ao_levar_dano() -> void:
	if _flash_dano == null:
		return
	if _tween_dano != null and _tween_dano.is_valid():
		_tween_dano.kill()

	_flash_dano.color.a = 0.32
	_tween_dano = create_tween()
	_tween_dano.tween_property(_flash_dano, "color:a", 0.0, 0.35)


func _ao_coletar(no_nivel: int, meta: int, nivel: int, total_comida: int) -> void:
	_atualizar(no_nivel, meta, nivel, total_comida)


func _ao_subir_nivel(nivel: int) -> void:
	aviso.text = "NÍVEL %d!" % nivel
	aviso.pivot_offset = aviso.size * 0.5
	aviso.modulate.a = 0.0
	aviso.scale = Vector2(0.7, 0.7)

	if _tween_aviso and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_property(aviso, "modulate:a", 1.0, 0.18)
	_tween_aviso.parallel().tween_property(aviso, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_aviso.tween_interval(0.9)
	_tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.35)


func _atualizar(no_nivel: int, meta: int, nivel: int, total_comida: int) -> void:
	nivel_label.text = "NÍVEL %d" % nivel
	contador.text = "COMIDA: %d / %d" % [no_nivel, meta]
	total.text = "TOTAL: %d" % total_comida
	barra.max_value = meta
	barra.value = no_nivel
