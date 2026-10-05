extends Node3D
## Une salle : sa forme jouable (union de rectangles), son sol selon le monde, son décor
## et le torii de sortie qui s'allume quand la salle est vidée.
## Le vide (eau, lave, encre…) se comporte comme un trou : on peut tracer au-dessus, pas y finir.

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")
const Worlds = preload("res://scripts/worlds.gd")

const HALF := Vector2(4.6, 8.6)  # bornes de l'arène (comme main.gd)

# Rect2 : position = (x min, z min), size = (largeur x, profondeur z)
const LAYOUTS := {
	"full": [Rect2(-4.6, -8.6, 9.2, 17.2)],
	"islands": [Rect2(-4.6, -8.6, 9.2, 6.4), Rect2(-0.9, -2.6, 1.8, 5.2), Rect2(-4.6, 2.2, 9.2, 6.4)],
	"cross": [Rect2(-1.8, -8.6, 3.6, 17.2), Rect2(-4.6, -2.8, 9.2, 5.6)],
	"ring": [Rect2(-4.6, -8.6, 2.8, 17.2), Rect2(1.8, -8.6, 2.8, 17.2), Rect2(-4.6, -8.6, 9.2, 2.8), Rect2(-4.6, 5.8, 9.2, 2.8)],
	"zigzag": [Rect2(-4.6, -8.6, 6.0, 6.0), Rect2(-1.4, -3.4, 6.0, 6.8), Rect2(-4.6, 2.6, 6.0, 6.0)],
	"hourglass": [Rect2(-4.6, -8.6, 9.2, 5.0), Rect2(-1.6, -3.8, 3.2, 7.6), Rect2(-4.6, 3.6, 9.2, 5.0)],
	"twin": [Rect2(-4.6, -8.6, 3.6, 17.2), Rect2(1.0, -8.6, 3.6, 17.2), Rect2(-1.2, -6.4, 2.4, 1.8), Rect2(-1.2, 4.6, 2.4, 1.8)],
}

var world_id := 0
var layout := "full"
var rects: Array = []
var start := Vector3(0, 0, 6.1)
var gate_pos := Vector3(0, 0, -8.0)
var gate_open := false

var _world_root: Node3D
var _room_root: Node3D
var _gate: Node3D
var _gate_ring: MeshInstance3D
var _void_mat: StandardMaterial3D
var _t := 0.0
var _batches := {}  # matériau -> transformations des tuiles du sol


func _ready() -> void:
	_world_root = Node3D.new()
	add_child(_world_root)
	_room_root = Node3D.new()
	add_child(_room_root)


## Change de monde : le vide sous l'arène, le lointain et les particules.
func set_world(id: int) -> void:
	if id == world_id:
		return
	world_id = id
	for ch in _world_root.get_children():
		ch.queue_free()
	var w: Dictionary = Worlds.world(id)
	_void_mat = StandardMaterial3D.new()
	_void_mat.albedo_color = w["void"]
	if bool(w.get("void_metal", true)):
		_void_mat.roughness = 0.25
		_void_mat.metallic_specular = 0.7
		var noise := FastNoiseLite.new()
		noise.frequency = 0.035
		var ntex := NoiseTexture2D.new()
		ntex.noise = noise
		ntex.seamless = true
		ntex.as_normal_map = true
		ntex.bump_strength = 6.0
		ntex.width = 256
		ntex.height = 256
		_void_mat.normal_enabled = true
		_void_mat.normal_texture = ntex
		_void_mat.normal_scale = 0.6
		_void_mat.uv1_scale = Vector3(60, 60, 1)
	else:
		_void_mat.roughness = 0.9
	var v := Toon.part(_world_root, Toon.box(Vector3(600, 0.1, 600)), _void_mat, Vector3(0, -0.6, 0))
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Worlds.build_backdrop(id, _world_root)
	Worlds.build_particles(id, _world_root)


## Construit la salle : forme, sol, bords, décor, torii de sortie (caché).
func build_room(room: int, rooms: int, rng_seed: int) -> void:
	for ch in _room_root.get_children():
		ch.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if room <= 1 or room == 5 or room >= rooms:
		layout = "full"
	else:
		var keys: Array = LAYOUTS.keys()
		keys.erase("full")
		var prev := layout
		layout = String(keys[rng.randi() % keys.size()])
		if layout == prev:
			layout = String(keys[(keys.find(layout) + 1) % keys.size()])
	rects = LAYOUTS[layout].duplicate()
	var w: Dictionary = Worlds.world(world_id)
	for r in rects:
		_build_ground(r, w, rng)
	_flush_tiles()
	Worlds.build_props(world_id, _room_root, rects, rng_seed)
	# départ au sud de la plateforme la plus basse, sortie au nord de la plus haute
	var low: Rect2 = rects[0]
	var high: Rect2 = rects[0]
	for r in rects:
		var rr: Rect2 = r
		if rr.end.y > low.end.y or (is_equal_approx(rr.end.y, low.end.y) and absf(rr.get_center().x) < absf(low.get_center().x)):
			low = rr
		if rr.position.y < high.position.y or (is_equal_approx(rr.position.y, high.position.y) and absf(rr.get_center().x) < absf(high.get_center().x)):
			high = rr
	start = Vector3(clampf(0.0, low.position.x + 0.8, low.end.x - 0.8), 0, low.end.y - 2.2)
	gate_pos = Vector3(clampf(0.0, high.position.x + 1.2, high.end.x - 1.2), 0, high.position.y + 0.9)
	_build_gate(w)


func _build_ground(r: Rect2, w: Dictionary, rng: RandomNumberGenerator) -> void:
	var cols: Array = w.ground
	var style := String(w.ground_style)
	var c := r.get_center()
	# socle et bord d'encre
	var base := Toon.part(_room_root, Toon.box(Vector3(r.size.x, 0.46, r.size.y)), Toon.mat(w.under, false), Vector3(c.x, -0.27, c.y))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var edge := Toon.mat(w.edge, false)
	for side in [[Vector3(r.size.x + 0.1, 0.56, 0.1), Vector3(c.x, -0.25, r.position.y)], [Vector3(r.size.x + 0.1, 0.56, 0.1), Vector3(c.x, -0.25, r.end.y)],
			[Vector3(0.1, 0.56, r.size.y + 0.1), Vector3(r.position.x, -0.25, c.y)], [Vector3(0.1, 0.56, r.size.y + 0.1), Vector3(r.end.x, -0.25, c.y)]]:
		var e := Toon.part(_room_root, Toon.box(side[0]), edge, side[1])
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mats: Array = []
	for col in cols:
		var m := Toon.mat(col, false)
		m.rim_enabled = false
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mats.append(m)
	match style:
		"planks":
			var pw := 0.62
			var x := r.position.x
			while x < r.end.x - 0.05:
				var wdt := minf(pw, r.end.x - x)
				var z0 := r.position.y
				while z0 < r.end.y - 0.01:
					var l := minf(rng.randf_range(2.6, 5.5), r.end.y - z0)
					_tile(Vector3(wdt - 0.035, 0.09, l - 0.03), Vector3(x + wdt / 2.0, -0.045 + rng.randf_range(-0.006, 0.006), z0 + l / 2.0), mats[rng.randi() % mats.size()])
					z0 += l
				x += pw
		"stones", "basalt":
			var s := 1.0 if style == "stones" else 0.9
			var gz := r.position.y
			var row := 0
			while gz < r.end.y - 0.05:
				var d := minf(s, r.end.y - gz)
				var gx := r.position.x - (s * 0.5 if row % 2 == 1 else 0.0)
				while gx < r.end.x - 0.05:
					var x0 := maxf(gx, r.position.x)
					var x1 := minf(gx + s, r.end.x)
					if x1 - x0 > 0.1:
						_tile(Vector3(x1 - x0 - 0.06, 0.09, d - 0.06), Vector3((x0 + x1) / 2.0, -0.045 + rng.randf_range(-0.01, 0.01), gz + d / 2.0), mats[rng.randi() % mats.size()])
					gx += s
				gz += s
				row += 1
			if style == "basalt":
				# veines d'or dans la roche noire
				var gold := Toon.mat(Toon.GOLD, false)
				for i in int(r.size.x * r.size.y / 6.0):
					_tile(Vector3(rng.randf_range(0.4, 1.2), 0.012, 0.05), Vector3(rng.randf_range(r.position.x + 0.3, r.end.x - 0.3), 0.003, rng.randf_range(r.position.y + 0.3, r.end.y - 0.3)), gold, rng.randf() * PI)
		"snow":
			_tile(Vector3(r.size.x, 0.1, r.size.y), Vector3(c.x, -0.05, c.y), mats[0])
			for i in int(r.size.x * r.size.y / 5.0):
				var lump := Toon.part(_room_root, Toon.sphere(rng.randf_range(0.25, 0.5)), mats[rng.randi() % mats.size()],
					Vector3(rng.randf_range(r.position.x + 0.3, r.end.x - 0.3), -0.02, rng.randf_range(r.position.y + 0.3, r.end.y - 0.3)), Vector3(1, 0.12, 1))
				lump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_:
			# papier : grande feuille washi et quelques traits d'encre sèche
			_tile(Vector3(r.size.x, 0.1, r.size.y), Vector3(c.x, -0.05, c.y), mats[0])
			var ink := Toon.flat(Color(Toon.SUMI, 0.18))
			for i in int(r.size.x * r.size.y / 8.0):
				var st := Toon.part(_room_root, Toon.box(Vector3(rng.randf_range(0.6, 2.0), 0.005, rng.randf_range(0.05, 0.14))), ink,
					Vector3(rng.randf_range(r.position.x + 0.4, r.end.x - 0.4), 0.004, rng.randf_range(r.position.y + 0.4, r.end.y - 0.4)))
				st.rotation.y = rng.randf() * PI
				st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Une tuile du sol (planche, dalle…) : on les regroupe par matériau, dessinées d'un seul coup.
func _tile(size: Vector3, pos: Vector3, m: Material, rot_y := 0.0) -> void:
	if not _batches.has(m):
		_batches[m] = []
	var b := Basis(Vector3.UP, rot_y).scaled(size)
	_batches[m].append(Transform3D(b, pos))


func _flush_tiles() -> void:
	var unit := BoxMesh.new()
	for m in _batches.keys():
		var list: Array = _batches[m]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_room_root.add_child(mi)
	_batches.clear()


func _build_gate(_w: Dictionary) -> void:
	gate_open = false
	_gate = Node3D.new()
	_room_root.add_child(_gate)
	_gate.position = gate_pos
	var t := Decor.torii(_gate, Vector3(0, 0, -0.3), 0.55)
	t.visible = true
	_gate_ring = Toon.disc(_gate, 1.1, Color(Toon.GOLD, 0.0), 0.05)


## Le torii s'illumine : on peut passer à la salle suivante.
func open_gate() -> void:
	gate_open = true


func gate_reached(p: Vector3) -> bool:
	return gate_open and Vector2(p.x - gate_pos.x, p.z - gate_pos.z).length() < 1.3


func _process(delta: float) -> void:
	_t += delta
	if _void_mat and _void_mat.normal_enabled:
		_void_mat.uv1_offset += Vector3(0.0035, 0.0018, 0) * delta
	if _gate_ring and is_instance_valid(_gate_ring):
		var m := _gate_ring.material_override as StandardMaterial3D
		var a := (0.35 + 0.25 * sin(_t * 4.0)) if gate_open else 0.0
		m.albedo_color = Color(Toon.GOLD, a)
		var s := 1.0 + (0.12 * sin(_t * 4.0) if gate_open else 0.0)
		_gate_ring.scale = Vector3(s, 1, s)


# ------------------------------------------------------------------ géométrie

func walkable(p: Vector3, margin := 0.0) -> bool:
	for r in rects:
		var rr: Rect2 = r
		if rr.grow(-margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


## Ramène un point (ou un ennemi de rayon `rad`) sur la terre ferme la plus proche.
func clamp_walk(p: Vector3, rad: float) -> Vector3:
	if walkable(p, rad):
		return p
	var best := p
	var best_d := INF
	for r in rects:
		var rr: Rect2 = r
		var g := rr.grow(-rad)
		var q := Vector3(clampf(p.x, g.position.x, g.end.x), p.y, clampf(p.z, g.position.y, g.end.y))
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best_d:
			best_d = d
			best = q
	return best


## Point jouable au hasard, loin de `avoid`.
func random_point(avoid: Vector3, min_dist: float, margin := 0.8) -> Vector3:
	var p := start
	for attempt in 40:
		var r: Rect2 = rects[randi() % rects.size()]
		var g := r.grow(-margin)
		if g.size.x <= 0.0 or g.size.y <= 0.0:
			continue
		p = Vector3(randf_range(g.position.x, g.end.x), 0, randf_range(g.position.y, g.end.y))
		if p.distance_to(avoid) > min_dist:
			return p
	return p
