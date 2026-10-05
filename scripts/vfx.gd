extends Node3D
## Effets de combat : traînée de lame lumineuse, éclairs d'impact, anneaux de choc, étincelles,
## confettis de papier, grand idéogramme 斬 à la mise à mort. Les matériaux émissifs brillent
## grâce au halo (glow) de l'environnement, sans délaver le reste de l'image.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

const TRAIL_LIFE := 0.28

var main: Node
var _fx: Array = []  # {node, t, life, kind, ...}
var _trail_pts: Array = []  # [position, âge]
var _trail_mesh := ImmediateMesh.new()
var _trail_live := false  # la traînée a des surfaces à effacer
var _trail_mat: StandardMaterial3D
var _glow_mats := {}
# maillages partagés par tous les impacts (forme constante ; l'échelle se fait sur le nœud)
var _star_quad: QuadMesh
var _arc_mesh: ArrayMesh
var _ring_torus: TorusMesh
var _spark_boxes := {}  # couleur -> BoxMesh (matériau lumineux de cette couleur)
var _confetti: QuadMesh


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _trail_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	# mélange normal (pas additif) : les couleurs restent franches même sur un sol clair
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(minf(c.r * 1.15, 1.0), minf(c.g * 1.15, 1.0), minf(c.b * 1.15, 1.0), 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mats[key] = m
	return m


# ------------------------------------------------------------------ traînée de lame

func trail_point(p: Vector3) -> void:
	_trail_pts.append([p + Vector3(0, 0.75, 0), 0.0])


func _update_trail(dt: float) -> void:
	if _trail_pts.is_empty():
		if _trail_live:
			_trail_mesh.clear_surfaces()
			_trail_live = false
		return
	for tp in _trail_pts:
		tp[1] = float(tp[1]) + dt
	_trail_pts = _trail_pts.filter(func(tp): return float(tp[1]) < TRAIL_LIFE)
	_trail_mesh.clear_surfaces()
	_trail_live = false
	var n := _trail_pts.size()
	if n < 2:
		return
	_trail_live = true
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
	if _star_quad == null:
		_star_quad = QuadMesh.new()
		_star_quad.size = Vector2(1.0, 0.18)
	for r in [0.0, PI / 2.0, PI / 4.0, -PI / 4.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _star_quad
		mi.material_override = glow_mat(Color(1, 0.95, 0.8), 4.0)
		mi.rotation.z = r
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.add_child(mi)
	# sobre : un éclair court et l'arc de sabre ; l'anneau seulement sur un coup fort
	_fx.append({"node": star, "t": 0.0, "life": 0.18, "kind": "star", "s": 1.9 if strong else 1.3})
	if strong:
		ring(Vector3(pos.x, 0.06, pos.z), Toon.GOLD, 1.4)
	sparks(p, dir, 8 if strong else 5, Toon.GOLD)
	arc(p, dir, strong)


## Arc de sabre : un croissant lumineux tracé dans le sens du coup.
func arc(pos: Vector3, dir: Vector3, strong := false) -> void:
	if _arc_mesh == null:
		_arc_mesh = _make_arc_mesh()
	var node := Node3D.new()
	add_child(node)
	node.position = pos
	var d := dir
	d.y = 0
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	node.rotation.y = atan2(-d.x, -d.z)
	node.rotation.z = randf_range(-0.5, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = _arc_mesh
	mi.material_override = glow_mat(Color(1.0, 0.95, 0.85) if not strong else Toon.VERMILION, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	_fx.append({"node": node, "t": 0.0, "life": 0.26, "kind": "arc", "s": 1.6 if strong else 1.2})


## Croissant de l'arc de sabre (forme fixe, construite une fois).
func _make_arc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var a0 := lerpf(-1.2, 1.2, float(i) / n)
		var a1 := lerpf(-1.2, 1.2, float(i + 1) / n)
		var w0 := 0.28 * sin(PI * float(i) / n) + 0.02
		var w1 := 0.28 * sin(PI * float(i + 1) / n) + 0.02
		var o0 := Vector3(sin(a0), 0, -cos(a0)) * 1.2
		var o1 := Vector3(sin(a1), 0, -cos(a1)) * 1.2
		var i0 := Vector3(sin(a0), 0, -cos(a0)) * (1.2 - w0)
		var i1 := Vector3(sin(a1), 0, -cos(a1)) * (1.2 - w1)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.add_vertex(i0)
	return st.commit()


## Anneau de choc qui s'étend au sol.
func ring(pos: Vector3, c: Color, r: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	if _ring_torus == null:
		_ring_torus = TorusMesh.new()
		_ring_torus.inner_radius = 0.88
		_ring_torus.outer_radius = 1.0
		_ring_torus.rings = 24
		_ring_torus.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_torus
	mi.scale = Vector3(1, 0.05, 1)
	mi.material_override = glow_mat(c, 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	_fx.append({"node": n, "t": 0.0, "life": 0.35, "kind": "ring", "r": r})


## Étincelles lumineuses projetées dans la direction du coup.
func sparks(pos: Vector3, dir: Vector3, amount: int, c: Color) -> void:
	var p := CPUParticles3D.new()
	var key := c.to_html()
	if not _spark_boxes.has(key):
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, 0.36)
		bm.material = glow_mat(c, 3.5)
		_spark_boxes[key] = bm
	p.mesh = _spark_boxes[key]
	p.amount = amount
	p.lifetime = 0.6
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


## Mise à mort : éclat d'or, quelques confettis de papier ; le grand 斬 seulement sur un beau coup (`big`).
func kill_burst(pos: Vector3, dir: Vector3, big := false) -> void:
	impact(pos, dir, true)
	# confettis de washi
	var p := CPUParticles3D.new()
	if _confetti == null:
		_confetti = QuadMesh.new()
		_confetti.size = Vector2(0.14, 0.1)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.albedo_color = Toon.WASHI
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_confetti.material = pm
	p.mesh = _confetti
	p.amount = 7
	p.lifetime = 0.9
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
	if not big:
		return
	# grand idéogramme au pinceau
	var l := Label3D.new()
	l.font = UiKit.TITLE_FONT
	l.text = "斬"
	l.font_size = 220
	l.pixel_size = 0.0038
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
	var dt := UiKit.unscaled(delta, 0.05)
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
			"arc":
				var sa: float = fx.s
				node.scale = Vector3.ONE * sa * (0.8 + 0.5 * k)
				node.visible = k < 0.85
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
