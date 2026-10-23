extends SceneTree
## Inspeciona a cena importada do GLB: arvore de nos, esqueleto e animacoes.


func _arvore(no: Node, profundidade: int = 0) -> void:
	var extra := ""
	if no is AnimationPlayer:
		var ap := no as AnimationPlayer
		var nomes := ap.get_animation_list()
		extra = "  animacoes=%s" % str(nomes)
		for n in nomes:
			var a := ap.get_animation(n)
			extra += "\n%s    - %s: %.2fs loop=%d" % ["  ".repeat(profundidade + 1), n, a.length, a.loop_mode]
	if no is Skeleton3D:
		var sk := no as Skeleton3D
		extra = "  ossos=%d (%s...)" % [sk.get_bone_count(), sk.get_bone_name(0)]
	print("%s%s <%s>%s" % ["  ".repeat(profundidade), no.name, no.get_class(), extra])
	for filho in no.get_children():
		_arvore(filho, profundidade + 1)


func _initialize() -> void:
	var cena: PackedScene = load("res://assets/modelos/jogador/trexChrisAnim.glb")
	if cena == null:
		print("###ERRO### nao carregou")
		quit(1)
		return
	var raiz := cena.instantiate()
	print("###ARVORE###")
	_arvore(raiz)
	print("###FIM###")
	raiz.free()
	quit(0)
