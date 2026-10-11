extends RefCounted
## Lueurs des sources de feu du décor (lanternes de pierre, chōchin, tōrō, braseros, torches) : flaque de
## lumière chaude au sol et halo doux autour de la flamme, qui palpitent chacun à leur rythme.
## Aucune vraie lumière (téléphone) : toutes les lueurs d'un même nœud parent tiennent dans un seul
## MultiMesh additif (1 draw call, shaders/lueur.gdshader). Les constructeurs de decor.gd / worlds.gd les
## déclarent dans leurs lots (clé KEY), _flush les pose à côté des pièces fusionnées, dans le même repère.

const SHADER = preload("res://shaders/lueur.gdshader")
const KEY := "_lueurs"  # clé (texte) posée dans les lots bs / bn : Array de [flamme, sol, couleur, rayon, feu]
const NODE := &"Lueurs"

static var _mat: ShaderMaterial = null
static var _quad: QuadMesh = null


## Matière partagée par toutes les lueurs (force réglée par monde : set_world).
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	return _mat


## Force des flaques et des halos selon la clarté du monde (main.apply_world) : plein jour, à peine une
## tache tiède ; nuit, de vraies flaques de lumière.
static func set_world(day: float) -> void:
	var m := material()
	var k := clampf(day, 0.0, 1.0)
	m.set_shader_parameter("gain", lerpf(0.7, 0.28, k))
	m.set_shader_parameter("halo_gain", lerpf(0.45, 0.3, k))


static func _mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1.0, 1.0)
	return _quad


## Déclare une lueur dans le lot `b` : flamme en `flame`, flaque centrée en `ground` (repère du lot), de rayon
## `r` (m) ; `fire` : flamme vive (palpite plus fort que le papier).
static func add(b: Dictionary, flame: Vector3, ground: Vector3, col: Color, r: float, fire := false) -> void:
	if not b.has(KEY):
		b[KEY] = []
	var list: Array = b[KEY]
	list.append([flame, ground, col, r, fire])


## Pose les lueurs déclarées dans `b` sous `parent` (fusionnées avec celles qu'il porte déjà).
static func flush(b: Dictionary, parent: Node3D) -> void:
	if not b.has(KEY):
		return
	var list: Array = b[KEY]
	b.erase(KEY)
	if list.is_empty() or parent == null:
		return
	var mmi: MultiMeshInstance3D = parent.get_node_or_null(NodePath(NODE)) as MultiMeshInstance3D
	var all: Array = []
	if mmi != null:
		all = mmi.get_meta(&"list", [])
	all.append_array(list)
	if mmi == null:
		mmi = MultiMeshInstance3D.new()
		mmi.name = NODE
		mmi.material_override = material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	mmi.set_meta(&"list", all)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh()
	mm.instance_count = all.size() * 2
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	var i := 0
	var aabb := AABB()
	for e in all:
		var flame: Vector3 = e[0]
		var ground: Vector3 = e[1]
		var col: Color = e[2]
		var r: float = e[3]
		var fire: bool = e[4]
		var seed := fposmod(flame.x * 0.731 + flame.z * 0.377 + flame.y * 0.113, 1.0) * 0.999
		var fk := 2.0 if fire else 0.0
		# flaque au sol (2 r de diamètre), juste au-dessus de la surface
		mm.set_instance_transform(i, Transform3D(flat.scaled(Vector3(r * 2.0, 1.0, r * 2.0)), ground + Vector3(0, 0.03, 0)))
		mm.set_instance_custom_data(i, Color(col.r, col.g, col.b, seed + fk))
		i += 1
		# halo autour de la flamme
		var hs := clampf(r * 0.5, 0.35, 1.8)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * hs), flame))
		mm.set_instance_custom_data(i, Color(col.r, col.g, col.b, seed + 1.0 + fk))
		i += 1
		var bx := AABB(ground - Vector3(r, 0.1, r), Vector3(r * 2.0, 0.2, r * 2.0)).merge(AABB(flame - Vector3.ONE * hs, Vector3.ONE * hs * 2.0))
		aabb = bx if i == 2 else aabb.merge(bx)
	mm.custom_aabb = aabb
	mmi.multimesh = mm


## Couleur de lueur d'une source (papier, pierre ou flamme) : chaude, assez claire pour la flaque.
static func tint(c: Color) -> Color:
	var warm := Color(1.0, 0.72, 0.38)
	return warm.lerp(c, 0.35)
