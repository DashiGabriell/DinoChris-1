extends CanvasLayer
## HUD da fase: crachá do jogador, cartão de missão, pips de comida,
## aviso de nível e vinheta suave de dano.

const ICONES_COMIDA := {
	0: preload("res://assets/ui/icone_carne.svg"),
	1: preload("res://assets/ui/icone_fruta.svg"),
	2: preload("res://assets/ui/icone_folha.svg"),
	3: preload("res://assets/ui/icone_agua.svg"),
}
const ICONE_SEMENTE := preload("res://assets/ui/icone_semente.svg")
const ICONE_CORACAO := preload("res://assets/ui/icone_coracao.svg")
const ICONE_CORACAO_VAZIO := preload("res://assets/ui/icone_coracao_vazio.svg")
const TOTAL_CORACOES: int = 7

@onready var placa_nome: PanelContainer = $PlacaNome
@onready var icone_nome: TextureRect = $IconeNome
@onready var nome: Label = $Nome
@onready var coracoes: HBoxContainer = $Coracoes
@onready var missao: PanelContainer = $Missao
@onready var icone_missao: TextureRect = $Missao/Margem/Conteudo/IconeMissao
@onready var nivel_label: Label = $Missao/Margem/Conteudo/Nivel
@onready var contador: Label = $Missao/Margem/Conteudo/Contador
@onready var pips: HBoxContainer = $Missao/Margem/Conteudo/Pips
@onready var barra: ProgressBar = $Missao/Margem/Conteudo/Barra
@onready var total: Label = $Missao/Margem/Conteudo/Total
@onready var aviso_fundo: PanelContainer = $AvisoFundo
@onready var aviso: Label = $Aviso

var _jogador: Node = null
var _tween_aviso: Tween = null
var _tween_dano: Tween = null
var _vinheta: TextureRect = null
var _pips: Array[TextureRect] = []
var _coracoes: Array[TextureRect] = []
var _no_nivel_atual: int = 0
var _meta_atual: int = 0
var _vidas_atuais: int = 5


func _ready() -> void:
	nome.text = Dados.nome_jogador
	aviso.modulate.a = 0.0
	aviso_fundo.modulate.a = 0.0
	_criar_vinheta()
	_criar_coracoes()
	_atualizar_vidas(5, TOTAL_CORACOES)
	_atualizar_pips(8, 0)
	_aplicar_area_segura()
	get_viewport().size_changed.connect(_aplicar_area_segura)

	_jogador = get_tree().get_first_node_in_group("jogador")
	if _jogador == null:
		return

	_jogador.connect("comida_coletada", _ao_coletar)
	_jogador.connect("subiu_nivel", _ao_subir_nivel)
	_jogador.connect("vidas_alteradas", _ao_vidas_alteradas)
	_atualizar_vidas(int(_jogador.get("vidas")), int(_jogador.call("vidas_maximas")))
	if _jogador.has_signal("comida_tipo_coletada"):
		_jogador.connect("comida_tipo_coletada", _ao_tipo_comida)
	if _jogador.has_signal("levou_dano"):
		_jogador.connect("levou_dano", _ao_levar_dano)
	_atualizar(0, int(_jogador.call("meta_nivel")), 1, 0)


func _criar_vinheta() -> void:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.45, 0.76, 1.0])
	gradiente.colors = PackedColorArray([
		Color(1.0, 0.24, 0.05, 0.0),
		Color(1.0, 0.24, 0.05, 0.0),
		Color(1.0, 0.18, 0.03, 0.34),
		Color(0.82, 0.08, 0.01, 0.9),
	])

	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.width = 512
	textura.height = 512
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)

	_vinheta = TextureRect.new()
	_vinheta.texture = textura
	_vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vinheta.z_index = 45
	_vinheta.modulate.a = 0.0
	add_child(_vinheta)
	_vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _criar_coracoes() -> void:
	for coracao_antigo in _coracoes:
		coracao_antigo.queue_free()
	_coracoes.clear()

	for i in TOTAL_CORACOES:
		var coracao := TextureRect.new()
		coracao.texture = ICONE_CORACAO_VAZIO
		coracao.custom_minimum_size = Vector2(26, 26)
		coracao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coracao.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coracao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coracao.set_meta("cheio", false)
		coracoes.add_child(coracao)
		_coracoes.append(coracao)


func _ao_vidas_alteradas(atuais: int, maximas: int) -> void:
	_atualizar_vidas(atuais, maximas)


func _atualizar_vidas(atuais: int, maximas: int) -> void:
	var total := maxi(maximas, TOTAL_CORACOES)
	if _coracoes.size() != total:
		_criar_coracoes()
		if _coracoes.size() != total:
			return

	var anteriores := _vidas_atuais
	_vidas_atuais = clampi(atuais, 0, total)
	for i in _coracoes.size():
		var cheio := i < _vidas_atuais
		_coracoes[i].texture = ICONE_CORACAO if cheio else ICONE_CORACAO_VAZIO
		_coracoes[i].set_meta("cheio", cheio)

	if _vidas_atuais < anteriores:
		_pulsar_coracao(mini(_vidas_atuais, total - 1), false)
	elif _vidas_atuais > anteriores:
		_pulsar_coracao(maxi(_vidas_atuais - 1, 0), true)


func _pulsar_coracao(indice: int, ganho: bool) -> void:
	if Dados.modo_calmo or indice < 0 or indice >= _coracoes.size():
		return
	var coracao := _coracoes[indice]
	coracao.pivot_offset = coracao.size * 0.5
	coracao.scale = Vector2(1.45, 1.45) if ganho else Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.tween_property(coracao, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _aplicar_area_segura() -> void:
	var janela := Vector2(DisplayServer.window_get_size())
	if janela.x <= 0.0 or janela.y <= 0.0:
		return

	var seguro := Rect2i(DisplayServer.get_display_safe_area())
	if seguro.size.x <= 0 or seguro.size.y <= 0:
		seguro = Rect2i(Vector2i.ZERO, DisplayServer.window_get_size())

	var escala := get_viewport().get_visible_rect().size / janela
	var margem_esq := 20 + int(float(seguro.position.x) * escala.x)
	var margem_dir := 20 + int(float(maxi(0, DisplayServer.window_get_size().x - (seguro.position.x + seguro.size.x))) * escala.x)
	var margem_topo := 16 + int(float(seguro.position.y) * escala.y)

	var largura_placa := 380
	placa_nome.offset_left = float(margem_esq)
	placa_nome.offset_top = float(margem_topo)
	placa_nome.offset_right = float(margem_esq + largura_placa)
	placa_nome.offset_bottom = float(margem_topo + 66)
	icone_nome.offset_left = float(margem_esq + 14)
	icone_nome.offset_top = float(margem_topo + 8)
	icone_nome.offset_right = float(margem_esq + 58)
	icone_nome.offset_bottom = float(margem_topo + 52)
	nome.offset_left = float(margem_esq + 68)
	nome.offset_top = float(margem_topo + 7)
	nome.offset_right = float(margem_esq + largura_placa - 14)
	nome.offset_bottom = float(margem_topo + 57)

	coracoes.offset_left = float(margem_esq)
	coracoes.offset_top = float(margem_topo + 76)
	coracoes.offset_right = float(margem_esq + 230)
	coracoes.offset_bottom = float(margem_topo + 110)

	var largura_missao := 384
	missao.offset_left = float(-margem_dir - largura_missao)
	missao.offset_top = float(margem_topo)
	missao.offset_right = float(-margem_dir)
	missao.offset_bottom = float(margem_topo + 300)


func _ao_levar_dano() -> void:
	if _vinheta == null:
		return
	if _tween_dano != null and _tween_dano.is_valid():
		_tween_dano.kill()

	_vinheta.modulate.a = 0.35 if Dados.modo_calmo else 0.95
	_tween_dano = create_tween().set_parallel(true)
	_tween_dano.tween_property(_vinheta, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	if not Dados.modo_calmo:
		missao.pivot_offset = missao.size * 0.5
		_tween_dano.tween_property(missao, "scale", Vector2(1.04, 0.96), 0.07)
		_tween_dano.tween_property(missao, "scale", Vector2.ONE, 0.28).set_delay(0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ao_coletar(no_nivel: int, meta: int, nivel: int, total_comida: int) -> void:
	var anterior := _no_nivel_atual
	_atualizar(no_nivel, meta, nivel, total_comida)
	if no_nivel > anterior and no_nivel > 0:
		_pulsar_pip(no_nivel - 1)
	_pulsar_contador()


func _ao_tipo_comida(tipo: int) -> void:
	var textura: Texture2D = ICONES_COMIDA.get(tipo)
	if textura == null or icone_missao.texture == textura:
		return
	icone_missao.texture = textura
	if Dados.modo_calmo:
		return
	icone_missao.pivot_offset = icone_missao.size * 0.5
	var tween := create_tween()
	tween.tween_property(icone_missao, "scale", Vector2(1.18, 1.18), 0.08)
	tween.tween_property(icone_missao, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ao_subir_nivel(nivel: int) -> void:
	aviso.text = "NÍVEL %d!" % nivel
	var calmo := Dados.modo_calmo
	for no in [aviso, aviso_fundo]:
		no.pivot_offset = no.size * 0.5
		no.modulate.a = 0.0
		no.scale = Vector2.ONE if calmo else Vector2(0.84, 0.84)

	if _tween_aviso and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_property(aviso, "modulate:a", 1.0, 0.16)
	_tween_aviso.parallel().tween_property(aviso_fundo, "modulate:a", 1.0, 0.16)
	if not calmo:
		_tween_aviso.parallel().tween_property(aviso, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween_aviso.parallel().tween_property(aviso_fundo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_aviso.tween_interval(0.9)
	_tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.3)
	_tween_aviso.parallel().tween_property(aviso_fundo, "modulate:a", 0.0, 0.3)

	if calmo:
		return
	nivel_label.pivot_offset = nivel_label.size * 0.5
	nivel_label.scale = Vector2(0.8, 0.8)
	var tween_nivel := create_tween()
	tween_nivel.tween_property(nivel_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pulsar_contador() -> void:
	if Dados.modo_calmo:
		return
	contador.pivot_offset = contador.size * 0.5
	var tween := create_tween()
	tween.tween_property(contador, "scale", Vector2(1.06, 1.06), 0.08)
	tween.tween_property(contador, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pulsar_pip(indice: int) -> void:
	if Dados.modo_calmo or indice < 0 or indice >= _pips.size():
		return
	var pip := _pips[indice]
	pip.pivot_offset = pip.size * 0.5
	pip.scale = Vector2(1.7, 1.7)
	var tween := create_tween()
	tween.tween_property(pip, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _atualizar(no_nivel: int, meta: int, nivel: int, total_comida: int) -> void:
	_no_nivel_atual = no_nivel
	_meta_atual = meta
	nivel_label.text = "NÍVEL %d" % nivel
	contador.text = "COMIDA: %d / %d" % [no_nivel, meta]
	total.text = "TOTAL: %d" % total_comida
	barra.max_value = meta
	barra.value = no_nivel
	_atualizar_pips(meta, no_nivel)


func _atualizar_pips(meta: int, preenchidos: int) -> void:
	if _pips.size() != meta:
		for pip_antigo in _pips:
			pip_antigo.queue_free()
		_pips.clear()
		for i in meta:
			var pip := TextureRect.new()
			pip.texture = ICONE_SEMENTE
			pip.custom_minimum_size = Vector2(16, 16)
			pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
			_pips.append(pip)

	for i in _pips.size():
		_pips[i].modulate = Color(1, 0.95, 0.72, 1) if i < preenchidos else Color(0.48, 0.38, 0.24, 0.62)
