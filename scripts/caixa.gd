extends StaticBody3D
## Caixa quebrável: some com rugido ou trombada e solta destroços com física.

var _quebrada: bool = false


func quebrar() -> void:
	if _quebrada:
		return
	_quebrada = true

	Sons.tocar_em("caixa", global_position, 2.0, randf_range(0.9, 1.1))
	_soltar_destrocos()
	set_deferred("collision_layer", 0)
	$Malha.visible = false
	queue_free()


func _soltar_destrocos() -> void:
	var pai := get_parent()
	if pai == null:
		return

	for i in 5:
		var pedaco := RigidBody3D.new()
		pedaco.collision_layer = 0
		pedaco.collision_mask = 1

		var malha := MeshInstance3D.new()
		var cubo := BoxMesh.new()
		var lado := randf_range(0.22, 0.34)
		cubo.size = Vector3(lado, lado, lado)
		malha.mesh = cubo

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.78, 0.55, 0.28).lerp(Color(0.5, 0.32, 0.15), randf())
		malha.material_override = material
		pedaco.add_child(malha)

		var colisao := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = Vector3(lado, lado, lado)
		colisao.shape = forma
		pedaco.add_child(colisao)

		pai.add_child(pedaco)
		pedaco.global_position = global_position + Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.2, 0.4),
			randf_range(-0.3, 0.3)
		)
		pedaco.linear_velocity = Vector3(
			randf_range(-2.5, 2.5),
			randf_range(2.0, 4.5),
			randf_range(-2.5, 2.5)
		)
		pedaco.angular_velocity = Vector3(
			randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0)
		)

		# Timer filho: o destroço se remove sozinho, sem depender da cena.
		var timer := Timer.new()
		timer.wait_time = 1.8
		timer.one_shot = true
		pedaco.add_child(timer)
		timer.timeout.connect(pedaco.queue_free)
		timer.start()
