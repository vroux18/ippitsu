extends RefCounted
## Occlusion ambiante feinte au pied des props (Compatibility : pas de SSAO) : à chaque lot de décor fusionné qui
## porte une ombre (worlds.gd / decor.gd _flush), on relève les sommets au ras du sol, regroupés par cases de
## CELL m, et on pose un disque d'ombre doux (shaders/ombre_contact.gdshader, en multiplication) sous chaque
## case : un seul MultiMesh par lot (1 appel de dessin), caché en GRAPHISMES ÉCO (groupe Gfx.GROUP_RICH).
## Les sommets sont lus un sur STRIDE : le relevé d'un lot de 20 000 sommets tient en quelques millisecondes.

const Gfx = preload("res://scripts/graphismes.gd")
const SHADER = preload("res://shaders/ombre_contact.gdshader")

const CELL := 0.55  # case de regroupement (m)
const STRIDE := 3
const Y_MIN := -0.06  # sommets retenus : au ras du sol (au-dessus : pas de contact ; dessous : dans le vide)
const Y_MAX := 0.24
const MIN_HITS := 2  # sommets au sol au moins par case
const R_MAX := 1.1
const NODE := &"OmbresContact"

static var _mat: ShaderMaterial = null
static var _quad: QuadMesh = null


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	return _mat


static func _on_floor(p: Vector2, floor: Array) -> bool:
	for r in floor:
		if (r as Rect2).grow(0.12).has_point(p):
			return true
	return false


static func _mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1.0, 1.0)
	return _quad


## Disques de contact des maillages `meshes` (déjà dans le repère de `parent`), posés sous `parent`.
## `floor_rects` : rectangles de sol (x, z) ; donnés, seuls les disques centrés sur le sol sont gardés (rien au-dessus du vide).
static func build(parent: Node3D, meshes: Array, floor_rects: Array = []) -> void:
	var cells := {}  # Vector2i -> [somme xz, n, min xz, max xz]
	for mesh in meshes:
		var am := mesh as Mesh
		if am == null:
			continue
		for s in am.get_surface_count():
			var arr: Array = am.surface_get_arrays(s)
			if arr.is_empty():
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var i := 0
			var n := vs.size()
			while i < n:
				var v := vs[i]
				i += STRIDE
				if v.y < Y_MIN or v.y > Y_MAX:
					continue
				var key := Vector2i(int(floor(v.x / CELL)), int(floor(v.z / CELL)))
				var c: Array = cells.get(key, [])
				if c.is_empty():
					c = [Vector2(v.x, v.z), 1, Vector2(v.x, v.z), Vector2(v.x, v.z)]
					cells[key] = c
				else:
					c[0] = (c[0] as Vector2) + Vector2(v.x, v.z)
					c[1] = int(c[1]) + 1
					c[2] = (c[2] as Vector2).min(Vector2(v.x, v.z))
					c[3] = (c[3] as Vector2).max(Vector2(v.x, v.z))
	var list: Array = []
	for key in cells:
		var c: Array = cells[key]
		var n := int(c[1])
		if n < MIN_HITS:
			continue
		var ctr: Vector2 = (c[0] as Vector2) / float(n)
		if not floor_rects.is_empty() and not _on_floor(ctr, floor_rects):
			continue
		var ext: Vector2 = (c[3] as Vector2) - (c[2] as Vector2)
		var r := clampf(maxf(ext.x, ext.y) * 0.5 + 0.32, 0.4, R_MAX)
		var dens := clampf(0.45 + 0.08 * float(n), 0.5, 1.0)
		list.append([ctr, r, dens])
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh()
	mm.instance_count = list.size()
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	var aabb := AABB()
	for i in list.size():
		var e: Array = list[i]
		var ctr: Vector2 = e[0]
		var r: float = e[1]
		var pos := Vector3(ctr.x, 0.022, ctr.y)
		mm.set_instance_transform(i, Transform3D(flat.scaled(Vector3(r * 2.0, 1.0, r * 2.0)), pos))
		mm.set_instance_custom_data(i, Color(float(e[2]), 0.0, 0.0, 0.0))
		var bx := AABB(pos - Vector3(r, 0.1, r), Vector3(r * 2.0, 0.2, r * 2.0))
		aabb = bx if i == 0 else aabb.merge(bx)
	mm.custom_aabb = aabb
	var mmi := MultiMeshInstance3D.new()
	mmi.name = NODE
	mmi.multimesh = mm
	mmi.material_override = material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.add_to_group(Gfx.GROUP_RICH)
	mmi.visible = not Gfx.is_eco()
	parent.add_child(mmi)
