class_name DemoWorld
extends Node3D
## Builds the demo yard from primitive meshes and the procedural textures. Everything rests on the ground.

var _materials := {}


func _ready() -> void:
	_ground()
	_house()
	_tower()
	_props()
	_fence()
	_trees()


func _mat(kind: String, tile: Vector2 = Vector2.ONE) -> StandardMaterial3D:
	var key := "%s_%s" % [kind, tile]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = DemoTextures.make(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(tile.x, tile.y, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_materials[key] = m
	return m


func _box(size: Vector3, pos: Vector3, kind: String, tile := Vector2.ONE, rot_y := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(kind, tile)
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)
	return mi


func _cylinder(radius: float, top_radius: float, height: float, pos: Vector3, kind: String, tile := Vector2.ONE) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(kind, tile)
	mi.position = pos
	add_child(mi)
	return mi


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _mat("grass", Vector2(120, 120))
	add_child(mi)
	# A dirt path 5 cm thick (a flat slab on the ground would fight with it in the depth buffer).
	_box(Vector3(2.4, 0.05, 16.0), Vector3(0.5, 0.025, 2.0), "path", Vector2(1.2, 8.0))


func _house() -> void:
	var c := Vector3(-5.5, 0.0, -2.0)
	_box(Vector3(6, 3, 4), c + Vector3(0, 1.5, 0), "brick", Vector2(3, 1.5))
	var roof := PrismMesh.new()
	roof.size = Vector3(6.6, 1.8, 4.8)
	var r := MeshInstance3D.new()
	r.mesh = roof
	r.material_override = _mat("roof", Vector2(3, 1))
	r.position = c + Vector3(0, 3.0 + 0.9, 0)
	add_child(r)
	_box(Vector3(1.1, 2.0, 0.2), c + Vector3(0.0, 1.0, 2.0), "wood")            # door: 10 cm proud of the wall
	_box(Vector3(1.0, 1.0, 0.2), c + Vector3(-2.0, 1.7, 2.0), "wood")            # windows
	_box(Vector3(1.0, 1.0, 0.2), c + Vector3(2.0, 1.7, 2.0), "wood")
	_box(Vector3(0.9, 1.6, 0.9), c + Vector3(1.8, 3.0 + 1.0, -1.0), "stone")     # chimney through the roof ridge
	_box(Vector3(1.4, 0.15, 1.2), c + Vector3(0.0, 0.075, 2.7), "stone")          # step


func _tower() -> void:
	var c := Vector3(6.0, 0.0, -6.0)
	_cylinder(1.5, 1.5, 7.0, c + Vector3(0, 3.5, 0), "stone", Vector2(4, 3))
	_cylinder(2.0, 0.0, 2.4, c + Vector3(0, 7.0 + 1.2, 0), "roof", Vector2(3, 1))
	_box(Vector3(0.7, 1.4, 0.3), c + Vector3(0, 0.7, 1.45), "wood")


func _props() -> void:
	# Crates: the top one sits on the lower one.
	_box(Vector3(1, 1, 1), Vector3(2.0, 0.5, 3.0), "crate", Vector2.ONE, 0.15)
	_box(Vector3(1, 1, 1), Vector3(3.2, 0.5, 3.3), "crate", Vector2.ONE, -0.2)
	_box(Vector3(0.9, 0.9, 0.9), Vector3(2.0, 1.45, 3.0), "crate", Vector2.ONE, 0.6)
	# Barrels.
	for p in [Vector3(-9.0, 0.55, 3.0), Vector3(-9.9, 0.55, 2.4), Vector3(-9.3, 0.55, 3.9)]:
		_cylinder(0.45, 0.45, 1.1, p, "barrel", Vector2(2, 1.5))
	# Stone ring (half buried).
	for i in 8:
		var a := TAU * i / 8.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.4
		sm.height = 0.8
		sm.radial_segments = 8
		sm.rings = 4
		s.mesh = sm
		s.material_override = _mat("stone", Vector2(2, 2))
		s.position = Vector3(cos(a) * 1.8 - 1.0, 0.1, sin(a) * 1.8 - 6.0)
		s.scale = Vector3(1, 0.6, 1)
		add_child(s)
	# Lamp post.
	_cylinder(0.08, 0.08, 3.0, Vector3(3.4, 1.5, -0.8), "barrel", Vector2(1, 2))
	_box(Vector3(0.4, 0.4, 0.4), Vector3(3.4, 3.2, -0.8), "crate")


func _fence() -> void:
	var step := 1.5
	var z := 7.0
	for i in 15:
		var x := -10.5 + i * step
		_box(Vector3(0.16, 1.3, 0.16), Vector3(x, 0.65, z), "wood")
		if i < 14:
			_box(Vector3(step, 0.1, 0.06), Vector3(x + step * 0.5, 0.5, z), "wood", Vector2(2, 1))
			_box(Vector3(step, 0.1, 0.06), Vector3(x + step * 0.5, 1.0, z), "wood", Vector2(2, 1))


func _trees() -> void:
	for p in [Vector2(-11, -8), Vector2(-9, 2), Vector2(10, 1), Vector2(11.5, -3), Vector2(1, -10), Vector2(-12, 9), Vector2(-14, -1)]:
		_cylinder(0.28, 0.3, 2.4, Vector3(p.x, 1.2, p.y), "wood", Vector2(1, 2))
		_cylinder(1.7, 0.0, 2.6, Vector3(p.x, 2.4 + 0.9, p.y), "leaf", Vector2(3, 2))
		_cylinder(1.3, 0.0, 2.2, Vector3(p.x, 2.4 + 2.2, p.y), "leaf", Vector2(3, 2))
