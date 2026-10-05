extends Node3D
## Effets de combat : traînée de lame lumineuse, éclairs d'impact, anneaux de choc, étincelles,
## confettis de papier, grand idéogramme 斬 à la mise à mort. Les matériaux émissifs brillent
## grâce au halo (glow) de l'environnement, sans délaver le reste de l'image.

const Toon = preload("res://scripts/toon.gd")
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")

const TRAIL_LIFE := 0.28

var main: Node
var _fx: Array = []  # {node, t, life, kind, ...}
var _trail_pts: Array = []  # [position, âge]
var _trail_mesh := ImmediateMesh.new()
var _trail_mat: StandardMaterial3D
var _glow_mats := {}


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _trail_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _trail_mat
	add_child(mi)


## Matériau lumineux (émissif) partagé par couleur.
func glow_mat(c: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), energy]
	if _glow_mats.has(key):
		return _glow_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 1)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * energy * 0.5, c.g * energy * 0.5, c.b * energy * 0.5, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mats[key] = m
	return m


# ------------------------------------------------------------------ traînée de lame

func trail_point(p: Vector3) -> void:
	_trail_pts.append([p + Vector3(0, 0.75, 0), 0.0])


func _update_trail(dt: float) -> void:
	for tp in _trail_pts:
		tp[1] = float(tp[1]) + dt
	_trail_pts = _trail_pts.filter(func(tp): return float(tp[1]) < TRAIL_LIFE)
	_trail_mesh.clear_surfaces()
	var n := _trail_pts.size()
	if n < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p: Vector3 = _trail_pts[i][0]
		var age: float = _trail_pts[i][1]
		var k := 1.0 - age / TRAIL_LIFE
		var a: Vector3 = _trail_pts[maxi(i - 1, 0)][0]
		var b: Vector3 = _trail_pts[mini(i + 1, n - 1)][0]
		var t := b - a
		t.y = 0
		if t.length_squared() < 0.0001:
			t = Vector3.FORWARD
		var side := Vector3(-t.z, 0, t.x).normalized()
		var w := 0.55 * k
		# cœur blanc-or, bords vermillon
		var col := Toon.VERMILION.lerp(Color(1.0, 0.85, 0.5), k * k)
		col.a = k * 0.9
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_add_vertex(p + side * w + Vector3(0, 0.35 * k, 0))
		_trail_mesh.surface_set_color(Color(col, 0.0))
		_trail_mesh.surface_add_vertex(p - side * w - Vector3(0, 0.2, 0))
	_trail_mesh.surface_end()


# ------------------------------------------------------------------ impacts

## Coup porté : éclair en étoile, anneau au sol, étincelles dorées.
func impact(pos: Vector3, dir: Vector3, strong := false) -> void:
	var p := pos + Vector3(0, 0.9, 0)
	# éclair en étoile (deux quads croisés face caméra)
	var star := Node3D.new()
	add_child(star)
	star.position = p
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.18)
	for r in [0.0, PI / 2.0, PI / 4.0, -PI / 4.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = glow_mat(Color(1, 0.95, 0.8), 4.0)
		mi.rotation.z = r
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.add_child(mi)
	_fx.append({"node": star, "t": 0.0, "life": 0.18, "kind": "star", "s": 2.6 if strong else 1.8})
	ring(Vector3(pos.x, 0.05, pos.z), Toon.VERMILION if not strong else Toon.GOLD, 1.6 if strong else 1.1)
	sparks(p, dir, 14 if strong else 8, Toon.GOLD)


## Anneau de choc qui s'étend au sol.
func ring(pos: Vector3, c: Color, r: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	var tor := TorusMesh.new()
	tor.inner_radius = 0.88
	tor.outer_radius = 1.0
	tor.rings = 24
	tor.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = tor
	mi.scale = Vector3(1, 0.05, 1)
	mi.material_override = glow_mat(c, 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	_fx.append({"node": n, "t": 0.0, "life": 0.35, "kind": "ring", "r": r})


## Étincelles lumineuses projetées dans la direction du coup.
func sparks(pos: Vector3, dir: Vector3, amount: int, c: Color) -> void:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.28)
	m.material = glow_mat(c, 3.5)
	p.mesh = m
	p.amount = amount
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	var d := dir.normalized() if dir.length_squared() > 0.001 else Vector3.UP
	p.direction = (d + Vector3(0, 0.6, 0)).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -14, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.position = pos
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 0.9, "kind": "none"})


## Mise à mort : explosion d'encre et d'or, confettis de papier, grand 斬.
func kill_burst(pos: Vector3, dir: Vector3) -> void:
	impact(pos, dir, true)
	sparks(pos + Vector3(0, 0.9, 0), -dir, 10, Toon.VERMILION)
	# confettis de washi
	var p := CPUParticles3D.new()
	var m := QuadMesh.new()
	m.size = Vector2(0.14, 0.1)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Toon.WASHI
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material = pm
	p.mesh = m
	p.amount = 16
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -5, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.color = Toon.WASHI
	p.position = pos + Vector3(0, 1.0, 0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 1.4, "kind": "none"})
	# grand idéogramme au pinceau
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = "斬"
	l.font_size = 220
	l.pixel_size = 0.006
	l.modulate = Toon.VERMILION
	l.outline_modulate = Toon.SUMI
	l.outline_size = 26
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0.6, 2.0, 0)
	add_child(l)
	_fx.append({"node": l, "t": 0.0, "life": 0.55, "kind": "kanji"})


func _process(delta: float) -> void:
	# temps réel : les effets ne ralentissent pas avec le jeu
	var dt := minf(delta / maxf(Engine.time_scale, 0.05), 0.05)
	if main and main.hero and is_instance_valid(main.hero) and main.hero.dashing:
		trail_point(main.hero.position)
	_update_trail(dt)
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Dictionary = _fx[i]
		var node: Node3D = fx.node
		fx.t = float(fx.t) + dt
		var k: float = float(fx.t) / float(fx.life)
		match String(fx.kind):
			"star":
				var s: float = fx.s
				node.scale = Vector3.ONE * s * (0.3 + 0.9 * k)
				if main and main.cam:
					node.look_at(main.cam.global_position, Vector3.UP)
				for ch in node.get_children():
					(ch as Node3D).visible = k < 0.9
			"ring":
				var r: float = fx.r
				node.scale = Vector3.ONE * r * (0.3 + 1.2 * k)
				node.visible = k < 0.95
			"kanji":
				var l := node as Label3D
				var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 5.0)
				l.scale = Vector3.ONE * pop
				l.modulate.a = clampf((1.0 - k) * 2.5, 0.0, 1.0)
				l.outline_modulate.a = l.modulate.a
				l.position.y += dt * 1.2
		if k >= 1.0:
			node.queue_free()
			_fx.remove_at(i)
