extends Node3D
## Vie du décor d'une salle : les quelques pièces qui bougent (lanternes de papier qui se balancent à leur
## crochet, bannières qui flottent). Chaque sorte tient dans un seul MultiMesh dont les transformations sont
## recalculées à chaque image (une dizaine d'instances : quelques multiplications, un draw call par sorte).
## Déclaré par decor_dress.gd, qui connaît les points d'attache ; aucune lumière réelle ici.

const Toon = preload("res://scripts/toon.gd")

## Sortes : clé -> {mm: MultiMesh, base: [Transform3D] (repère de l'attache), phase: [float], amp, speed, axis}
var _kinds := {}
var _t := 0.0


## Déclare une instance de la sorte `key` : `mesh` partagé (pivot à l'attache, pièce qui pend sous y = 0),
## attache `base` (coordonnées de ce nœud), amplitude `amp` (rad), vitesse `speed`, axe du balancement local.
func add(key: String, mesh: Mesh, base: Transform3D, amp: float, speed: float, axis := Vector3(0, 0, 1)) -> void:
	if not _kinds.has(key):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		_kinds[key] = {"mm": mm, "base": [], "phase": [], "amp": amp, "speed": speed, "axis": axis.normalized()}
	var k: Dictionary = _kinds[key]
	(k["base"] as Array).append(base)
	(k["phase"] as Array).append(fmod(float((k["base"] as Array).size()) * 2.399, TAU) + base.origin.x * 0.7 + base.origin.z * 0.3)


## Pose les MultiMesh (à appeler une fois toutes les instances déclarées).
func commit() -> void:
	for key in _kinds:
		var k: Dictionary = _kinds[key]
		var mm: MultiMesh = k["mm"]
		var base: Array = k["base"]
		mm.instance_count = base.size()
		for i in base.size():
			mm.set_instance_transform(i, base[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Life_" + key
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	set_process(not _kinds.is_empty())


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree():
		return
	for key in _kinds:
		var k: Dictionary = _kinds[key]
		var mm: MultiMesh = k["mm"]
		var base: Array = k["base"]
		var phase: Array = k["phase"]
		var amp: float = k["amp"]
		var speed: float = k["speed"]
		var axis: Vector3 = k["axis"]
		for i in base.size():
			var ph: float = phase[i]
			# balancement principal et petit rebond désaccordé (jamais deux lanternes en phase)
			var a := sin(_t * speed + ph) * amp + sin(_t * speed * 2.3 + ph * 1.7) * amp * 0.18
			var b: Transform3D = base[i]
			mm.set_instance_transform(i, b * Transform3D(Basis(axis, a), Vector3.ZERO))
