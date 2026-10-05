extends Node3D
## Personnage KayKit : mis à l'échelle, recoloré dans la palette, contour d'encre, animations.
## Les modèles KayKit regardent vers +Z ; le jeu considère -Z comme « devant ».

const Toon = preload("res://scripts/toon.gd")
const SHADER = preload("res://shaders/ink_toon.gdshader")

const LOOPS := ["Idle", "Idle_B", "Idle_Combat", "2H_Melee_Idle", "Unarmed_Idle", "Walking_A", "Walking_B",
	"Walking_C", "Walking_D_Skeletons", "Running_A", "Running_B", "Running_C", "Spellcasting", "Blocking"]

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var scale_factor := 1.0
var idle := "Idle"
var _mats: Array[ShaderMaterial] = []
var _current := ""
var _once := false


## `looks` : liste de [motif du nom de maillage, couleur, intensité] — le premier motif trouvé s'applique.
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
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not mi.visible:
			continue
		if "Eyes" in String(mi.name):
			var em := StandardMaterial3D.new()
			em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			em.albedo_color = eyes
			mi.material_override = em
			continue
		var tint := Color.WHITE
		var amount := 0.0
		for look in looks:
			if String(look[0]) in String(mi.name):
				tint = look[1]
				amount = look[2]
				break
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var m := ShaderMaterial.new()
			m.shader = SHADER
			if src is BaseMaterial3D:
				m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
			m.set_shader_parameter("tint", tint)
			m.set_shader_parameter("tint_amount", amount)
			m.next_pass = outline
			mi.set_surface_override_material(i, m)
			_mats.append(m)

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
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE / scale_factor
	ba.add_child(holder)
	holder.add_child(node)


func length(a: String) -> float:
	if anim and anim.has_animation(a):
		return anim.get_animation(a).length
	return 1.0


## Animation en boucle (marche, attente…).
func play(a: String, speed := 1.0, blend := 0.15) -> void:
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
func play_once(a: String, speed := 1.0, blend := 0.08) -> void:
	if anim == null or not anim.has_animation(a):
		return
	_once = true
	_current = a
	anim.play(a, blend)
	anim.speed_scale = speed
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
		m.set_shader_parameter("flash_amount", a)


func set_glow(a: float, color := Toon.VERMILION) -> void:
	for m in _mats:
		m.set_shader_parameter("glow", a)
		m.set_shader_parameter("glow_color", color)
