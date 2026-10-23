extends Node
## Testa o céu HDRI da fase: panorama certo, névoa não engolindo o céu e sol com sombra.

var _falhas: int = 0


func _ready() -> void:
	var cena: PackedScene = load("res://scenes/fase_1.tscn")
	var fase: Node3D = cena.instantiate()
	add_child(fase)
	await get_tree().process_frame
	await get_tree().process_frame

	var mundo: WorldEnvironment = fase.get_node_or_null("WorldEnvironment")
	_checar(mundo != null, "WorldEnvironment na fase")
	if mundo == null:
		_finalizar()
		return

	var ambiente: Environment = mundo.environment
	_checar(ambiente != null, "environment configurado")
	if ambiente == null:
		_finalizar()
		return

	_checar(ambiente.background_mode == Environment.BG_SKY, "fundo é o céu")
	_checar(ambiente.sky != null, "Sky existe")
	if ambiente.sky == null:
		_finalizar()
		return

	var material = ambiente.sky.sky_material
	_checar(material is PanoramaSkyMaterial, "material é panorama")
	if material is PanoramaSkyMaterial:
		var textura: Texture2D = material.panorama
		_checar(textura != null, "panorama tem textura")
		if textura != null:
			_checar(textura.resource_path.ends_with("ceu-01.exr"), "textura é o ceu-01.exr (%s)" % textura.resource_path)
			_checar(textura.get_width() >= 1024, "panorama carregado (%dx%d)" % [textura.get_width(), textura.get_height()])

	# a névoa não pode substituir o céu (era o bug: fog_sky_affect = 1.0)
	_checar(ambiente.fog_sky_affect <= 0.05, "névoa não cobre o céu (%.2f)" % ambiente.fog_sky_affect)
	_checar(ambiente.background_energy_multiplier > 0.2, "céu visível (energia %.2f)" % ambiente.background_energy_multiplier)
	_checar(ambiente.tonemap_mode == Environment.TONE_MAPPER_AGX, "tonemap AgX")

	var sol: DirectionalLight3D = fase.get_node_or_null("Sol")
	_checar(sol != null, "luz direcional existe")
	if sol != null:
		_checar(sol.shadow_enabled, "sol projeta sombra")

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
