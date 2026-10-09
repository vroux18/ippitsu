extends Node3D
## Butin au sol : gemmes d'expérience (jade) et pièces d'or. Elles flottent, sont aspirées quand
## le héros passe près, et volent toutes vers lui à la fin de la salle (gather()).
## main.collect(kind, value) est appelé au ramassage.

const Toon = preload("res://scripts/toon.gd")

const MAGNET := 2.6
const GRAB := 0.6
const JADE := Color("#3FD1B2")

var main: Node
var _items: Array = []  # {node, kind, value, vel, t, pull}
var _gem_mesh: SphereMesh
var _coin_mesh: CylinderMesh
var _gem_mat: StandardMaterial3D
var _coin_mat: StandardMaterial3D
var _hole_mesh: BoxMesh
var _hole_mat: StandardMaterial3D
var _disc_mesh: CylinderMesh
var _gem_glow: StandardMaterial3D
var _coin_glow: StandardMaterial3D
var _star_mesh: QuadMesh
var _star_mat: StandardMaterial3D
var _gather := false
const POOL_MAX := 24  # objets gardés en réserve par sorte (gemme, pièce) au lieu d'être recréés
var _pool := {"xp": [], "coin": []}  # [nœud, halo, étincelle] cachés, prêts à resservir


func _ready() -> void:
	# cristal de jade à facettes (octaèdre étiré) et pièce percée d'un trou carré, cerclés d'encre
	_gem_mesh = SphereMesh.new()
	_gem_mesh.radius = 0.2
	_gem_mesh.height = 0.56
	_gem_mesh.radial_segments = 4
	_gem_mesh.rings = 2
	_coin_mesh = CylinderMesh.new()
	_coin_mesh.top_radius = 0.24
	_coin_mesh.bottom_radius = 0.24
	_coin_mesh.height = 0.06
	_coin_mesh.radial_segments = 16
	_gem_mat = _emissive(JADE, 2.4)
	_coin_mat = _emissive(Toon.GOLD, 1.9)
	_hole_mesh = BoxMesh.new()
	_hole_mesh.size = Vector3(0.09, 0.08, 0.09)
	_hole_mat = StandardMaterial3D.new()
	_hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hole_mat.albedo_color = Color("#3A2A10")
	# halo coloré au sol, qui pulse
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.height = 0.004
	_disc_mesh.radial_segments = 20
	_gem_glow = _glow(JADE)
	_coin_glow = _glow(Toon.GOLD)
	# étincelle qui scintille au-dessus
	_star_mesh = QuadMesh.new()
	_star_mesh.size = Vector2(0.32, 0.32)
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_star_mat.albedo_texture = _star_tex()
	_star_mat.albedo_color = Color(1, 1, 1, 0.9)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, 0.32)
	m.render_priority = 1
	return m


## Petite étoile à 4 branches (texture générée une fois).
func _star_tex() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := absf(float(x) - 15.5) / 15.5
			var dy := absf(float(y) - 15.5) / 15.5
			var v := maxf(maxf(0.0, 1.0 - dx * 6.0) * maxf(0.0, 1.0 - dy), maxf(0.0, 1.0 - dy * 6.0) * maxf(0.0, 1.0 - dx))
			v = maxf(v, maxf(0.0, 1.0 - sqrt(dx * dx + dy * dy) * 2.2))
			img.set_pixel(x, y, Color(1, 1, 0.92, clampf(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	m.next_pass = Toon.outline_mat(0.025)  # contour d'encre (passe partagée)
	return m


## Fait jaillir du butin depuis un ennemi tué.
func drop(pos: Vector3, kind: String, count: int, value := 1) -> void:
	for i in count:
		var trio := _take(kind)
		var n: Node3D = trio[0]
		var disc: Node3D = trio[1]
		var star: Node3D = trio[2]
		n.position = pos + Vector3(0, 0.6, 0)
		var a := randf() * TAU
		var v := Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.2) + Vector3(0, randf_range(3.5, 5.5), 0)
		_items.append({"node": n, "disc": disc, "star": star, "kind": kind, "value": value, "vel": v, "t": randf() * 3.0, "pull": false})


## Préchauffage (main._warmup) : gemme, pièce, trou, halos et étincelle posés une fois sous `parent`
## (shaders compilés d'avance, pas de butin ramassable).
func warm(parent: Node3D, at: Vector3) -> void:
	var meshes: Array = [_gem_mesh, _coin_mesh, _hole_mesh, _disc_mesh, _disc_mesh, _star_mesh]
	var mats: Array = [_gem_mat, _coin_mat, _hole_mat, _gem_glow, _coin_glow, _star_mat]
	for i in meshes.size():
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.material_override = mats[i]
		if i != 2:  # comme en jeu : seul le trou de la pièce projette une ombre
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = at + Vector3(float(i) * 0.6, 0.4, 0)
		parent.add_child(mi)


## Fin de salle : tout le butin restant vole vers le héros.
func gather() -> void:
	_gather = true
	for it in _items:
		it.pull = true


func clear() -> void:
	for it in _items:
		_free_item(it)
	_items.clear()
	_gather = false


func _process(delta: float) -> void:
	if main == null or main.hero == null or not is_instance_valid(main.hero):
		return
	var hp: Vector3 = main.hero.position + Vector3(0, 0.7, 0)
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		var n: Node3D = it.node
		it.t = float(it.t) + delta
		var vel: Vector3 = it.vel
		if not bool(it.pull):
			# petit saut à l'apparition, puis flottement au sol
			vel.y -= 14.0 * delta
			n.position += vel * delta
			if n.position.y < 0.3:
				n.position.y = 0.3
				vel = Vector3(vel.x * 0.6, 0, vel.z * 0.6) if absf(vel.y) > 0.5 else Vector3.ZERO
			vel.x *= 1.0 - minf(1.0, delta * 2.5)
			vel.z *= 1.0 - minf(1.0, delta * 2.5)
			if vel.length() < 0.2:
				n.position.y = 0.35 + sin(float(it.t) * 3.0) * 0.08
			it.vel = vel
			if Vector2(n.position.x - hp.x, n.position.z - hp.z).length() < MAGNET and float(it.t) > 0.35:
				it.pull = true
		else:
			# aspiré par le héros, de plus en plus vite
			var to := hp - n.position
			var spd := 9.0 + 14.0 * float(it.t) if _gather else 12.0
			n.position += to.normalized() * minf(to.length(), spd * delta)
			if to.length() < GRAB:
				main.collect(String(it.kind), int(it.value))
				if main.vfx != null:
					main.vfx.sparks(n.position, Vector3.UP, 2, JADE if it.kind == "xp" else Toon.GOLD, 3.0, 6.0, 40.0)
				_free_item(it)
				_items.remove_at(i)
				continue
		n.rotation.y += delta * (5.0 if it.kind == "coin" else 2.0)
		if it.kind == "coin":
			n.rotation.x = PI / 2.0
		# halo au sol sous l'objet (s'efface quand il est aspiré), étincelle qui scintille
		var disc: Node3D = it.disc
		var star: Node3D = it.star
		var pulse := 0.5 + 0.5 * sin(float(it.t) * 4.0)
		var on_ground := not bool(it.pull)
		disc.visible = on_ground
		disc.position = Vector3(n.position.x, 0.03, n.position.z)
		var dr := 0.32 + 0.08 * pulse
		disc.scale = Vector3(dr, 1, dr)
		star.position = n.position + Vector3(0.12, 0.3, 0)
		var tw := maxf(0.0, sin(float(it.t) * 5.0 + float(i)))
		star.scale = Vector3.ONE * (0.4 + 0.9 * tw * tw) * (1.6 if bool(it.pull) else 1.0)
	if _items.is_empty():
		_gather = false


## Gemme ou pièce (nœud, halo, étincelle) : reprise de la réserve si possible, sinon construite.
func _take(kind: String) -> Array:
	var key := "xp" if kind == "xp" else "coin"
	var pool: Array = _pool[key]
	while not pool.is_empty():
		var tr: Array = pool.pop_back()
		if is_instance_valid(tr[0]) and is_instance_valid(tr[1]) and is_instance_valid(tr[2]):
			var n0: Node3D = tr[0]
			n0.rotation = Vector3.ZERO  # comme un nœud neuf (la pièce et la gemme tournent sur elles-mêmes)
			n0.visible = true
			var s0: Node3D = tr[2]
			s0.visible = true
			return tr
	var n := MeshInstance3D.new()
	n.mesh = _gem_mesh if key == "xp" else _coin_mesh
	n.material_override = _gem_mat if key == "xp" else _coin_mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	if key != "xp":
		var hole := MeshInstance3D.new()
		hole.mesh = _hole_mesh
		hole.material_override = _hole_mat
		n.add_child(hole)
	var disc := MeshInstance3D.new()
	disc.mesh = _disc_mesh
	disc.material_override = _gem_glow if key == "xp" else _coin_glow
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh
	star.material_override = _star_mat
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star)
	return [n, disc, star]


## Objet ramassé ou effacé : ses nœuds sont cachés et rangés dans la réserve (bornée), sinon libérés.
func _free_item(it: Dictionary) -> void:
	var key := "xp" if String(it.get("kind", "")) == "xp" else "coin"
	var pool: Array = _pool[key]
	var nv = it.get("node")
	var dv = it.get("disc")
	var sv = it.get("star")
	if pool.size() < POOL_MAX and is_instance_valid(nv) and is_instance_valid(dv) and is_instance_valid(sv):
		var n: Node3D = nv
		var d: Node3D = dv
		var s: Node3D = sv
		n.visible = false
		d.visible = false
		s.visible = false
		pool.append([n, d, s])
		return
	for nd in [nv, dv, sv]:
		if is_instance_valid(nd):
			nd.queue_free()
