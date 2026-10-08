extends Node3D
## Personnage KayKit : mis à l'échelle, recoloré dans la palette, contour d'encre, animations.
## Les modèles KayKit regardent vers +Z ; le jeu considère -Z comme « devant ».

const Toon = preload("res://scripts/toon.gd")

const LOOPS := ["Idle", "Idle_B", "Idle_Combat", "2H_Melee_Idle", "Unarmed_Idle", "Walking_A", "Walking_B",
	"Walking_C", "Walking_D_Skeletons", "Running_A", "Running_B", "Running_C", "Spellcasting", "Blocking"]

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var scale_factor := 1.0
var idle := "Idle"
var _mats: Array[StandardMaterial3D] = []
var _current := ""
var _once := false
var _slots := {}  # os -> support déjà accroché (un seul BoneAttachment3D par os)


## `looks` : liste de [motif du nom de maillage, texture recolorée] — le premier motif trouvé s'applique.
func setup(scene: PackedScene, height: float, looks: Array, hidden: Array = [], eyes := Toon.VERMILION) -> void:
	model = scene.instantiate()
	add_child(model)
	model.rotation.y = PI

	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var box := AABB()
	var first := true
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi.name in hidden:
			mi.visible = false
			continue
		var b := mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	scale_factor = height / maxf(box.size.y, 0.01)
	model.scale = Vector3.ONE * scale_factor
	model.position.y = -box.position.y * scale_factor

	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Toon.SUMI
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.028 / scale_factor

	for n in meshes:
		var mi := n as MeshInstance3D
		if not mi.visible:
			continue
		if "Eyes" in String(mi.name):
			var em := StandardMaterial3D.new()
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.albedo_color = eyes
			mi.material_override = em
			continue
		var tex: Texture2D = null
		for look in looks:
			if String(look[0]) in String(mi.name):
				tex = look[1]
				break
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex if tex else (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_TOON
			m.roughness = 0.9
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.5
			m.emission_enabled = true
			m.emission = Color.WHITE
			m.emission_energy_multiplier = 0.0
			m.next_pass = outline
			mi.set_surface_override_material(i, m)
			_mats.append(m)
		# l'import glTF peut poser un material_override, prioritaire sur les matériaux par surface
		mi.material_override = _mats.back() if mi.mesh.get_surface_count() == 1 else null

	skeleton = model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	anim = model.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if anim:
		for a in LOOPS:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_finished)
		play(idle)


## Accroche un objet (modélisé en unités du monde) à un os, ex. « handslot.r ».
func attach(bone: String, node: Node3D) -> void:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		add_child(node)
		return
	var holder: Node3D = _slots.get(bone)
	if holder == null:
		var ba := BoneAttachment3D.new()
		ba.bone_name = bone
		skeleton.add_child(ba)
		holder = Node3D.new()
		holder.scale = Vector3.ONE / scale_factor
		ba.add_child(holder)
		_slots[bone] = holder
	holder.add_child(node)


## Accroche un maillage partagé (unités du monde) à un os ; `shadow` : projette une ombre.
func attach_mesh(bone: String, mesh: Mesh, material: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(bone, mi)
	return mi


## Cache après coup les sous-maillages dont le nom contient un des motifs (l'échelle de setup ne change pas).
func hide_meshes(patterns: Array) -> void:
	if model == null or patterns.is_empty():
		return
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for p in patterns:
			if String(p) in String(mi.name):
				mi.visible = false
				break


func length(a: String) -> float:
	if anim and anim.has_animation(a):
		return anim.get_animation(a).length
	return 1.0


## Animation en boucle (marche, attente…).
func play(a: String, speed := 1.0, blend := 0.2) -> void:
	if anim == null or not anim.has_animation(a):
		return
	if a == _current and not _once:
		anim.speed_scale = speed
		return
	_once = false
	_current = a
	anim.play(a, blend)
	anim.speed_scale = speed


## Animation jouée une fois, puis retour à `idle`.
func play_once(a: String, speed := 1.0, blend := 0.1) -> void:
	if anim == null or not anim.has_animation(a):
		return
	_once = true
	_current = a
	var again := anim.current_animation == a
	anim.play(a, blend)
	anim.speed_scale = speed
	# même animation déjà en cours : on la relance ; sinon on garde le fondu (pas de saut de pose)
	if again:
		anim.seek(0.0, true)


## Fige la pose finale (mort) : la boucle ne reprend pas.
func hold() -> void:
	_once = false
	idle = ""


func _on_finished(_a: StringName) -> void:
	if _once and idle != "":
		_once = false
		_current = ""
		play(idle)


func set_flash(a: float) -> void:
	for m in _mats:
		m.emission = Color.WHITE
		m.emission_energy_multiplier = a


func set_glow(a: float, color := Toon.VERMILION) -> void:
	for m in _mats:
		m.emission = color
		m.emission_energy_multiplier = a
