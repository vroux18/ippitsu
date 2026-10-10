extends Node3D
## Effets de combat : traînée de lame lumineuse, éclairs d'impact, anneaux de choc, traits d'étincelles,
## giclée d'encre et grand sceau « entaille » à la mise à mort, éclat doré et pièces des coffres.
## Les matériaux émissifs brillent grâce au halo (glow) de l'environnement, sans délaver le reste de l'image.
## Lisibilité : chaque élément a sa forme (flammes, arcs d'eau, zigzag, croissants, fumée) ; au sol, les ondes
## passent SOUS les annonces d'attaque (priorité de rendu négative) et restent pâles.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")  # hex des pictos v2 (sceau de mise à mort)
const FX_BRUSH = preload("res://shaders/fx_brush.gdshader")
const InkStroke = preload("res://scripts/ink_stroke.gd")

const TRAIL_LIFE := 0.16
const TRAIL_TIP := 0.96  # pointe de la traînée : largeur pleine à ~0,7 m de la tête (0,45 par point à 60 Hz, ruée 28 m/s)
const TRAIL_W := 0.25

# palette des écoles : chaque élément a sa couleur ET sa forme
const FIRE := Color("#FF5A1F")  # flammes orange-rouge
const FIRE_HOT := Color("#FFC23A")  # cœur jaune, braises
const WATER := Color("#1E9BE0")  # anneaux bleu-cyan
const WATER_FOAM := Color("#D6F4FF")  # écume
const BOLT := Color("#FFE600")  # éclair jaune vif
const BOLT_CORE := Color("#FFFDF0")  # cœur blanc
const WIND := Color("#5FD6A8")  # jade
const WIND_PALE := Color("#E6FFF4")
const SHADOW := Color("#8A4FD8")  # violet
const SHADOW_DARK := Color("#1F1530")
const INK := Color("#1B1A1E")  # sumi
# teintes profondes (contours) et cœurs clairs des pouvoirs
const FIRE_DEEP := Color("#5A1408")
const WATER_DEEP := Color("#0F2F57")
const WIND_DEEP := Color("#1E4B3E")
const SHADOW_GLOW := Color("#C9A2FF")
const BLADE := Color(1.0, 0.97, 0.92)  # blanc du tranchant (papier)
const SCHOOL_FX := {"fire": FIRE, "water": WATER, "bolt": BOLT, "wind": WIND, "shadow": SHADOW, "ink": INK}

# annonces d'attaque (ennemis et boss) : même langage partout
const TELE_Y := 0.07  # au-dessus des dalles et des bosses de neige (~0.04)
const TELE_INK := 0.09  # contour d'encre (à cheval sur le bord, surtout dehors)
const TELE_RIM := 0.07  # liseré vermillon juste dedans
const TELE_FLASH := 0.15

var main: Node
var _fx: Array = []  # {node, t, life, kind, ...}
var _trail_pts: Array = []  # [position, âge]
var _trail_mesh := ImmediateMesh.new()
var _trail_live := false  # la traînée a des surfaces à effacer
var _trail_mat: Material
var _trail_clock := 0.0  # horloge des poils du pinceau (coordonnée fixe le long du trait)
var _glow_mats := {}
# maillages partagés par tous les impacts (forme constante ; l'échelle se fait sur le nœud)
var _star_quad: QuadMesh
var _arc_mesh: ArrayMesh
var _ring_torus: TorusMesh
var _mats := {}  # matériaux plats partagés (clé -> StandardMaterial3D)
var _meshes := {}  # maillages partagés (clé -> Mesh)
var _tmat := {}  # matériaux des annonces
var _flame_ramp: Gradient
var _smoke_ramp: Gradient
var _flame_curve: Curve
var _smoke_curve: Curve
# jus des pouvoirs : rampes d'estompage partagées, budget des effets riches, préchauffage silencieux
const FADE_N := 8
var _ramps := {}  # clé -> Array de FADE_N matériaux, du plein au presque transparent
var _budget := 18.0
var _warming := false  # préchauffage : ni son, ni secousse, ni éclair d'écran
var _frame_big := false  # un gros effet riche a déjà été lancé cette image : les suivants restent simples
var _drop_curve: Curve  # gouttes et traits d'étincelles : s'amincissent en fin de vie


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _trail_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# pinceau (shaders/brush.gdshader) : les poils s'effilochent vers la queue du trait
	_trail_mat = Toon.brush_mat()
	mi.material_override = _trail_mat
	add_child(mi)
	_dbg_init()


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
	_trail_pts.append([p + Vector3(0, 0.75, 0), 0.0, _trail_clock])


func _update_trail(dt: float) -> void:
	_trail_clock = fmod(_trail_clock + dt, 1000.0)
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
	# distance à la tête, en mètres : la pointe s'effile sur une longueur fixe, quelle que soit la cadence
	# (compter les points la rendait 4 fois plus courte à 120 Hz qu'à 30 Hz)
	var head_d := PackedFloat32Array()
	head_d.resize(n)
	head_d[n - 1] = 0.0
	for i in range(n - 2, -1, -1):
		var pa: Vector3 = _trail_pts[i][0]
		var pb: Vector3 = _trail_pts[i + 1][0]
		head_d[i] = head_d[i + 1] + pa.distance_to(pb)
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
		# pointe effilée à la tête (le pinceau se pose), queue qui s'amincit avec l'âge
		var tip := minf(1.0, head_d[i] * TRAIL_TIP + 0.35)
		var w := TRAIL_W * k * tip
		# fil blanc net côté tranchant, lavis d'encre de l'autre ; une pointe de vermillon en fin de trace
		var col := Color(1.0, 0.97, 0.92).lerp(Toon.VERMILION, (1.0 - k) * 0.35)
		col.a = k * 0.9
		var u := float(_trail_pts[i][2]) * 7.0
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_set_uv(Vector2(u, 0.0))
		_trail_mesh.surface_set_uv2(Vector2(1.0 - k, 0.0))
		_trail_mesh.surface_add_vertex(p + side * w + Vector3(0, 0.12 * k, 0))
		_trail_mesh.surface_set_color(Color(Toon.SUMI, 0.38 * k))
		_trail_mesh.surface_set_uv(Vector2(u, 1.0))
		_trail_mesh.surface_set_uv2(Vector2(1.0 - k, 0.0))
		_trail_mesh.surface_add_vertex(p - side * w - Vector3(0, 0.06, 0))
	_trail_mesh.surface_end()


# ------------------------------------------------------------------ impacts

## Coup porté : croix blanche brève et deux traits de lame blancs ; sur un coup fort (mise à mort), l'arc du sabre.
## (plus d'anneau ni d'étincelles dorées : le blanc du tranchant et l'encre suffisent, pas de « confettis »)
func impact(pos: Vector3, dir: Vector3, strong := false) -> void:
	var p := pos + Vector3(0, 0.9, 0)
	# éclair en étoile (deux quads croisés face caméra)
	var star := Node3D.new()
	add_child(star)
	star.position = p
	if _star_quad == null:
		_star_quad = QuadMesh.new()
		_star_quad.size = Vector2(0.8, 0.1)
	for r in [0.0, PI / 2.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _star_quad
		mi.material_override = glow_mat(Color(1, 0.97, 0.92), 4.0)
		mi.rotation.z = r
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.add_child(mi)
	_fx.append({"node": star, "t": 0.0, "life": 0.1, "kind": "star", "s": 1.4 if strong else 1.0})
	if strong:
		arc(p, dir, true)
	sparks(p, dir, 3 if strong else 2, BLADE, 7.0, 12.0, 35.0)


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
	mi.material_override = glow_mat(Color(1.0, 0.96, 0.9), 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	_fx.append({"node": node, "t": 0.0, "life": 0.2, "kind": "arc", "s": 1.25 if strong else 1.0})


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


## Étincelles : traits lumineux effilés projetés dans la direction du coup (étirés dans le sens de leur course).
func sparks(pos: Vector3, dir: Vector3, amount: int, c: Color, vmin := 6.0, vmax := 12.0, spread := 55.0) -> void:
	_drops("spark" + c.to_html(), _drop_mesh("streak_p", 0.035, 0.42), glow_mat(c, 3.0), pos, dir, amount, vmin, vmax, spread, 0.32, -10.0)


## Gouttes d'encre (couleur c) projetées vers dir, qui retombent : giclées de mise à mort.
func ink_drops(pos: Vector3, dir: Vector3, amount: int, c: Color) -> void:
	var key := "inkdrop" + c.to_html()
	_drops(key, _drop_mesh("drop_p", 0.07, 0.26), _mat(key, c, 1), pos, dir, amount, 3.5, 7.5, 50.0, 0.5, -18.0)


## Émetteur ponctuel de gouttes ou de traits, repris de la réserve (sorte `key`) : maillage, matériau et
## tous les réglages variables sont reposés à chaque tir.
func _drops(key: String, mesh: Mesh, mat: Material, pos: Vector3, dir: Vector3, amount: int, vmin: float, vmax: float, spread: float, life: float, grav: float) -> void:
	var p := _pooled(key)
	var fresh := p == null
	if fresh:
		p = CPUParticles3D.new()
		p.set_meta("pool", key)
	p.mesh = mesh
	p.material_override = mat
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	var d := dir.normalized() if dir.length_squared() > 0.001 else Vector3.UP
	p.direction = (d + Vector3(0, 0.5, 0)).normalized()
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, grav, 0)
	p.particle_flag_align_y = true  # la goutte s'étire dans le sens de sa course
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _drop_shrink()
	p.position = pos
	_emit(p, fresh)
	_fx.append({"node": p, "t": 0.0, "life": life + 0.15, "kind": "none"})


## Courbe partagée : la goutte garde sa taille puis s'amincit jusqu'à disparaître.
func _drop_shrink() -> Curve:
	if _drop_curve == null:
		_drop_curve = Curve.new()
		_drop_curve.add_point(Vector2(0.0, 1.0))
		_drop_curve.add_point(Vector2(0.6, 0.8))
		_drop_curve.add_point(Vector2(1.0, 0.0))
	return _drop_curve


## Goutte étirée le long de +y (deux plans croisés : tête ronde devant, queue effilée derrière),
## demi-largeur w, longueur l. Construite une fois par clé.
func _drop_mesh(key: String, w: float, l: float) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var prof: Array = [Vector2(0.0, 0.5), Vector2(0.8, 0.38), Vector2(1.0, 0.22), Vector2(0.55, -0.05), Vector2(0.0, -0.5)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in 2:
		for i in prof.size() - 1:
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[i + 1]
			var ar := Vector3(a.x * w, a.y * l, 0.0) if plane == 0 else Vector3(0.0, a.y * l, a.x * w)
			var al := Vector3(-a.x * w, a.y * l, 0.0) if plane == 0 else Vector3(0.0, a.y * l, -a.x * w)
			var br := Vector3(b.x * w, b.y * l, 0.0) if plane == 0 else Vector3(0.0, b.y * l, b.x * w)
			var bl := Vector3(-b.x * w, b.y * l, 0.0) if plane == 0 else Vector3(0.0, b.y * l, -b.x * w)
			_quad(st, al, ar, br, bl)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


# ------------------------------------------------------------------ réserve d'émetteurs
# Étincelles, gouttes, pièces : un émetteur ponctuel (one_shot) par coup. Fini, il est caché et rangé par sorte
# au lieu d'être libéré, puis relancé (restart) au coup suivant : pas de nœud créé à chaque impact.

const PPOOL_MAX := 10  # émetteurs gardés par sorte
var _ppool := {}  # sorte -> Array de CPUParticles3D éteints et cachés


func _pooled(key: String) -> CPUParticles3D:
	if not _ppool.has(key):
		return null
	var pool: Array = _ppool[key]
	while not pool.is_empty():
		var pv = pool.pop_back()
		if is_instance_valid(pv):
			var p: CPUParticles3D = pv
			return p
	return null


## Lance un émetteur ponctuel : neuf, il entre dans l'arbre ; repris, il réapparaît et repart de zéro.
func _emit(p: CPUParticles3D, fresh: bool) -> void:
	if fresh:
		add_child(p)
		p.emitting = true
	else:
		p.visible = true
		p.restart()


## Émetteur fini : rangé (caché, éteint) s'il vient de la réserve et qu'il y a la place. Faux sinon.
func _recycle(node: Node3D) -> bool:
	if not node.has_meta("pool") or not (node is CPUParticles3D):
		return false
	var key := String(node.get_meta("pool"))
	if not _ppool.has(key):
		_ppool[key] = []
	var pool: Array = _ppool[key]
	if pool.size() >= PPOOL_MAX:
		return false
	var p := node as CPUParticles3D
	p.emitting = false
	p.visible = false
	pool.append(p)
	return true


## Mise à mort : giclée d'encre (gouttes de sumi lancées dans le sens du coup, quelques gouttes à la couleur du
## yōkai `tint`), éclat d'encre face caméra, tache étoilée au sol qui sèche ; le grand sceau « entaille » seulement sur un beau
## coup (`big`). La croix et l'arc blancs viennent d'impact() (main l'appelle avec strong = tué).
func kill_burst(pos: Vector3, dir: Vector3, big := false, tint := Color(0, 0, 0, 0)) -> void:
	var p := pos + Vector3(0, 0.9, 0)
	# éclat bref au cœur du coup (le « tchac » de la mise à mort), blanc papier
	if _rich(1.0):
		_flare(p, Color(1.0, 0.97, 0.9), 0.8 if big else 0.6, 0.1)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.UP
	ink_drops(p, d.normalized(), 9 if big else 7, INK)
	if tint.a > 0.01:
		ink_drops(p, d.normalized(), 3, Color(tint, 1.0))
	# éclat d'encre face caméra qui jaillit derrière la croix (dessiné avant les lueurs)
	var burst := Node3D.new()
	add_child(burst)
	burst.position = p
	_mi(burst, _splat_mesh(), _mat("ink_burst", Color(Toon.SUMI, 0.8), -1, false, 2))
	burst.scale = Vector3.ONE * 0.2
	_fx.append({"node": burst, "t": 0.0, "life": 0.3, "kind": "burst", "s": 0.75 if big else 0.6})
	# tache d'encre étoilée au sol, qui s'étale d'un coup puis sèche
	_decal(Vector3(pos.x, 0.0, pos.z), 0.7 if big else 0.55, Color(Toon.SUMI, 0.5), 1.3)
	# (plus de sceau « entaille » à la mise à mort : les deux traits rouges à chaque coup gênaient)
	return
	var tex := UiKit.icon("hud/slash", 128.0, {"*": UIColors.hex(Toon.VERMILION)})
	if tex == null:
		return
	var l := Sprite3D.new()
	l.texture = tex
	l.pixel_size = 0.0095
	l.shaded = false
	l.render_priority = 3
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0.6, 2.0, 0)
	add_child(l)
	_fx.append({"node": l, "t": 0.0, "life": 0.55, "kind": "kanji"})


# ------------------------------------------------------------------ coffre

## Coffre ouvert : éclat de lumière dorée, halo doux au sol, quelques pièces percées (mon) qui jaillissent
## en tournoyant et trois traits de lumière. Rien de multicolore.
func chest_burst(pos: Vector3) -> void:
	var g := Vector3(pos.x, 0.06, pos.z)
	_flare(pos + Vector3(0, 0.9, 0), Color(1.0, 0.86, 0.45), 1.5, 0.3)
	# halo doux au sol (disque additif doré qui s'ouvre et s'efface)
	var node := Node3D.new()
	add_child(node)
	node.position = g
	var gr := _sramp("chest_glow", Color(1.0, 0.8, 0.35, 0.45), 0, true)
	var gm := _mi(node, _unit_disc(), gr[0])
	_anim(node, 0.7, Vector3.ONE * 0.5, Vector3.ONE * 1.8, {"g": 0.35, "f": 0.3, "lay": [[gm, -1, gr]]})
	# pièces mon : elles jaillissent en tournant sur la tranche (émetteur repris de la réserve)
	var p := _pooled("mon")
	var fresh := p == null
	if fresh:
		p = CPUParticles3D.new()
		p.set_meta("pool", "mon")
	p.mesh = _mon_mesh()
	p.material_override = _mon_mat()
	p.amount = 4 if Toon.lite else 6
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 32.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -13, 0)
	p.particle_flag_rotate_y = true  # la pièce tourne sur la tranche : face, profil, face
	p.angle_min = 0.0
	p.angle_max = 180.0
	p.angular_velocity_min = 420.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _drop_shrink()
	p.position = pos + Vector3(0, 0.6, 0)
	_emit(p, fresh)
	_fx.append({"node": p, "t": 0.0, "life": 1.05, "kind": "none"})
	sparks(pos + Vector3(0, 0.7, 0), Vector3.UP, 3, Color(1.0, 0.9, 0.55), 4.0, 8.0, 40.0)


## Pièce mon (plan XY, rayon ~0.17) : disque d'or au liseré sombre, trou carré des deux côtés. Couleurs de sommets.
func _mon_mesh() -> Mesh:
	if _meshes.has("mon"):
		return _meshes["mon"]
	var gold := Color("#F2C14E")
	var light := Color("#FFE08A")
	var rim := Color("#8A5A12")
	var hole := Color("#3A2A10")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		st.set_color(light)
		st.add_vertex(Vector3.ZERO)
		st.set_color(gold)
		st.add_vertex(d0 * 0.145)
		st.add_vertex(d1 * 0.145)
		# liseré sombre
		st.set_color(rim)
		st.add_vertex(d0 * 0.145)
		st.add_vertex(d0 * 0.175)
		st.add_vertex(d1 * 0.175)
		st.add_vertex(d0 * 0.145)
		st.add_vertex(d1 * 0.175)
		st.add_vertex(d1 * 0.145)
	# trou carré, posé un peu devant et un peu derrière le disque
	var h := 0.042
	for z: float in [0.004, -0.004]:
		st.set_color(hole)
		st.add_vertex(Vector3(-h, -h, z))
		st.add_vertex(Vector3(h, -h, z))
		st.add_vertex(Vector3(h, h, z))
		st.add_vertex(Vector3(-h, -h, z))
		st.add_vertex(Vector3(h, h, z))
		st.add_vertex(Vector3(-h, h, z))
	var mesh := st.commit()
	_meshes["mon"] = mesh
	return mesh


func _mon_mat() -> StandardMaterial3D:
	if _mats.has("mon"):
		return _mats["mon"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["mon"] = m
	return m


## Flaque d'encre au sol : elle s'ouvre (apparition d'un yōkai, il en sort) ou l'avale (mort, il s'y enfonce),
## puis se résorbe. `late` : la flaque s'ouvre un peu plus tard (pendant la chute du corps).
func spawn_ink(pos: Vector3, r: float, late := false) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.045, pos.z)
	node.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	node.scale = Vector3(0.01, 0.01, 1.0)
	_mi(node, _splat_mesh(), _mat("ink_pool", Color(Toon.SUMI, 0.7), 1))
	_fx.append({"node": node, "t": 0.0, "life": 1.3 if late else 1.15, "kind": "pool", "r": r * 1.45, "d": 0.25 if late else 0.0})
	if main and not Toon.lite and not late:
		main.splash(Vector3(pos.x, 0.3, pos.z), Toon.SUMI, 5)


## Tache d'encre étoilée (plan XY, rayon ~1) : bord déchiqueté, coulures en pointe, gouttes autour.
func _splat_mesh() -> ArrayMesh:
	if _meshes.has("splat"):
		return _meshes["splat"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 22
	var pts: Array[Vector3] = []
	for i in n:
		var a := TAU * float(i) / n
		var r := rng.randf_range(0.72, 1.0)
		if i % 3 == 0:
			r = rng.randf_range(1.05, 1.35)
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for i in n:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[i])
		st.add_vertex(pts[(i + 1) % n])
	for k in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.3, 1.75)
		var s := rng.randf_range(0.06, 0.13)
		var c := Vector3(cos(a) * d, sin(a) * d, 0)
		for j in 6:
			var a0 := TAU * float(j) / 6.0
			var a1 := TAU * float(j + 1) / 6.0
			st.add_vertex(c)
			st.add_vertex(c + Vector3(cos(a0), sin(a0), 0) * s)
			st.add_vertex(c + Vector3(cos(a1), sin(a1), 0) * s)
	var mesh := st.commit()
	_meshes["splat"] = mesh
	return mesh


# ------------------------------------------------------------------ outils partagés

## Matériau plat (non éclairé, transparent) partagé par clé. bill : 0 aucun, 1 particules, 2 face caméra.
## add : mélange additif (cœurs lumineux ; toujours posés sur une couche d'encre pour rester lisibles sur sol clair).
func _mat(key: String, c: Color, prio := 0, vcol := false, bill := 0, add := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.render_priority = prio
	m.vertex_color_use_as_albedo = vcol
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if bill == 1:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	elif bill == 2:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	_mats[key] = m
	return m


func _mi(parent: Node3D, mesh: Mesh, mat: Material, y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = y
	parent.add_child(mi)
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Repère qui va de a vers b : -Z local pointe vers b et mesure |b - a| (maillages tracés de 0 à -1 en z).
func _seg_xform(a: Vector3, b: Vector3) -> Transform3D:
	var d := b - a
	var l := maxf(d.length(), 0.01)
	var fwd := d / l
	var up := Vector3.UP if absf(fwd.y) < 0.9 else Vector3.FORWARD
	var zax := -fwd
	var xax := up.cross(zax).normalized()
	var yax := zax.cross(xax)
	return Transform3D(Basis(xax, yax, zax * l), a)


## Disque plein (plan XY, rayon 1, bord fondu par les couleurs de sommets) : halos face caméra.
func _disc_xy() -> Mesh:
	if _meshes.has("disc_xy"):
		return _meshes["disc_xy"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		st.set_color(Color(1, 1, 1, 1))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(cos(a0), sin(a0), 0))
		st.add_vertex(Vector3(cos(a1), sin(a1), 0))
	var mesh := st.commit()
	_meshes["disc_xy"] = mesh
	return mesh


func _unit_disc() -> Mesh:
	if not _meshes.has("disc"):
		_meshes["disc"] = Toon.cyl(1.0, 1.0, 0.004, 18)
	return _meshes["disc"]


func _ball() -> Mesh:
	if not _meshes.has("ball"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 4
		_meshes["ball"] = s
	return _meshes["ball"]


func _unit_box() -> Mesh:
	if not _meshes.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["box"] = b
	return _meshes["box"]


# ------------------------------------------------------------------ jus des pouvoirs : boîte à outils
# Un effet riche = des nœuds animés par _anim (échelle avec coup d'échelle, rotation, dérive, départ différé)
# dont les couches s'estompent par paliers : chaque couche passe d'un matériau partagé de sa « rampe » au suivant
# (FADE_N paliers construits une fois). Rien n'est alloué par image ; tout se libère seul en fin de vie.
# Pinceau : shaders/fx_brush.gdshader (les poils sèchent et s'effilochent à mesure que l'effet s'estompe).

## Budget des effets riches (se recharge en temps réel) : en rafale ou en foule, on retombe sur la version simple.
## Un seul gros effet riche (coût >= 3) par image : quand plusieurs pouvoirs partent ensemble, le premier
## garde son jus, les autres se contentent de leur forme simple (même couleur, même silhouette).
func _rich(cost: float) -> bool:
	if _warming:
		return true
	if cost >= 3.0 and _frame_big:
		return false
	if _budget < cost:
		return false
	_budget -= cost
	if cost >= 3.0:
		_frame_big = true
	return true


func _play(sound: String, pitch := 1.0, vol := 0.0) -> void:
	if main and not _warming:
		main.sfx.play(sound, pitch, vol)


## Secousse d'écran brève (la plus forte demandée l'emporte).
func _shake(v: float) -> void:
	if main and not _warming:
		var m = main
		m.shake = maxf(float(m.shake), v)


## Éclair d'écran (papier) pour les très grands moments.
func _flash(v: float) -> void:
	if main == null or _warming:
		return
	var h = main.hud
	if h != null and is_instance_valid(h):
		h.screen_flash = maxf(float(h.screen_flash), v)


## Rampe de matériaux plats : du plein (c.a) au presque transparent. add : additif ; bill : comme _mat.
func _sramp(key: String, c: Color, prio := 0, add := false, bill := 0) -> Array:
	var rk := "s" + key
	if _ramps.has(rk):
		return _ramps[rk]
	var out := []
	for i in FADE_N:
		var a := c.a * (1.0 - float(i) / float(FADE_N))
		out.append(_mat("%s#%d" % [key, i], Color(c, a), prio, false, bill, add))
	_ramps[rk] = out
	return out


## Rampe de matériaux au pinceau (teinte c) : plus le palier est haut, plus les poils sont secs.
func _bramp(c: Color, prio := 4) -> Array:
	var rk := "b%s_%d" % [c.to_html(), prio]
	if _ramps.has(rk):
		return _ramps[rk]
	var out := []
	for i in FADE_N:
		var m := ShaderMaterial.new()
		m.shader = FX_BRUSH
		m.render_priority = prio
		m.set_shader_parameter("tint", c)
		m.set_shader_parameter("fade", float(i) / float(FADE_N))
		m.set_shader_parameter("dry", 0.6 if Toon.lite else 0.9)
		out.append(m)
	_ramps[rk] = out
	return out


## Un MeshInstance3D sur `mesh`, une rampe par surface ; renvoie les couches à estomper ([mi, surface, rampe]).
func _layers(parent: Node3D, mesh: Mesh, ramps: Array) -> Array:
	var mi := _mi(parent, mesh, null)
	var out := []
	var n := mini(ramps.size(), mesh.get_surface_count())
	for s in n:
		var r: Array = ramps[s]
		mi.set_surface_override_material(s, r[0])
		out.append([mi, s, r])
	return out


func _lay_set(ly: Array, idx: int) -> void:
	var mi = ly[0]
	if not is_instance_valid(mi):
		return
	var r: Array = ly[2]
	var s: int = ly[1]
	if s < 0:
		mi.material_override = r[idx]
	else:
		mi.set_surface_override_material(s, r[idx])


func _safe_scale(v: Vector3) -> Vector3:
	return Vector3(maxf(v.x, 0.002), maxf(v.y, 0.002), maxf(v.z, 0.002))


## Effet animé générique (temps réel). Clés de `ex` : g (part de la vie pour aller de s0 à s1, ease-out),
## pu (coup d'échelle), sh (part finale où l'on rétrécit, sur les axes sm), spin (rad/s autour de y),
## vel (dérive freinée : déplacement total ≈ vel × life), up (montée m/s), fol/off (suit un nœud),
## f (début de l'estompage des couches `lay`), t (< 0 : départ différé, caché), ns (ne touche pas l'échelle).
func _anim(node: Node3D, life: float, s0: Vector3, s1: Vector3, ex := {}) -> Dictionary:
	var fx := {"node": node, "t": 0.0, "life": life, "kind": "anim", "s0": s0, "s1": s1, "g": 0.35, "pu": 0.0,
		"sh": 0.0, "sm": Vector3.ONE, "spin": 0.0, "vel": Vector3.ZERO, "up": 0.0, "f": 2.0, "lay": [], "fi": 0,
		"ns": false}
	fx.merge(ex, true)
	if not bool(fx["ns"]):
		node.scale = _safe_scale(s0)
	if float(fx["t"]) < 0.0:
		node.visible = false
	_fx.append(fx)
	return fx


func _anim_step(fx: Dictionary, node: Node3D, k: float, dt: float) -> void:
	if k < 0.0:
		return
	if not node.visible:
		node.visible = true
	var fo = fx.get("fol")
	if fo != null and is_instance_valid(fo):
		var off: Vector3 = fx.get("off", Vector3.ZERO)
		node.position = fo.position + off
	var vel: Vector3 = fx["vel"]
	if vel != Vector3.ZERO:
		node.position += vel * (dt * maxf(1.0 - k, 0.0) * 2.0)
	var up: float = fx["up"]
	if up != 0.0:
		node.position.y += up * dt
	var spin: float = fx["spin"]
	if spin != 0.0:
		node.rotation.y += spin * dt
	if not bool(fx["ns"]):
		var g: float = fx["g"]
		var kg := clampf(k / maxf(g, 0.001), 0.0, 1.0)
		var s0: Vector3 = fx["s0"]
		var s1: Vector3 = fx["s1"]
		var sc := s0.lerp(s1, UiKit.ease_out(kg))
		var pu: float = fx["pu"]
		if pu > 0.0:
			sc *= 1.0 + pu * sin(kg * PI)
		var sh: float = fx["sh"]
		if sh > 0.0 and k > 1.0 - sh:
			var q := clampf((1.0 - k) / sh, 0.0, 1.0)
			var sm: Vector3 = fx["sm"]
			sc *= Vector3.ONE - sm * (1.0 - q)
		node.scale = _safe_scale(sc)
	var f: float = fx["f"]
	if k > f:
		var idx := clampi(int((k - f) / maxf(1.0 - f, 0.001) * float(FADE_N)), 0, FADE_N - 1)
		if idx != int(fx["fi"]):
			fx["fi"] = idx
			for ly in fx["lay"]:
				_lay_set(ly, idx)


# --- maillages de pinceau (construits une fois, partagés ; plan XZ sauf mention)

func _bv(st: SurfaceTool, p: Vector3, u: float, v: float, ulen: float) -> void:
	st.set_color(Color.WHITE)
	st.set_uv(Vector2(u * ulen, v))
	st.set_uv2(Vector2(u, 0.0))
	st.add_vertex(p)


## Ruban le long des points `c`, entre les décalages o_out et o_in (distances signées le long de `nrm`).
func _strip(st: SurfaceTool, c: PackedVector3Array, nrm: PackedVector3Array, o_out: PackedFloat32Array, o_in: PackedFloat32Array, y: float, ulen: float) -> void:
	var n := c.size()
	var lift := Vector3(0, y, 0)
	for i in n - 1:
		var u0 := float(i) / float(n - 1)
		var u1 := float(i + 1) / float(n - 1)
		var a0 := c[i] + nrm[i] * o_out[i] + lift
		var a1 := c[i] + nrm[i] * o_in[i] + lift
		var b0 := c[i + 1] + nrm[i + 1] * o_out[i + 1] + lift
		var b1 := c[i + 1] + nrm[i + 1] * o_in[i + 1] + lift
		_bv(st, a0, u0, 0.0, ulen)
		_bv(st, a1, u0, 1.0, ulen)
		_bv(st, b1, u1, 1.0, ulen)
		_bv(st, a0, u0, 0.0, ulen)
		_bv(st, b1, u1, 1.0, ulen)
		_bv(st, b0, u1, 0.0, ulen)


## Trait à trois couches (surface 0 : contour d'encre, 1 : corps, 2 : cœur) ; lay = [[o_out, o_in], ×3].
func _brush_mesh(c: PackedVector3Array, nrm: PackedVector3Array, lay: Array, ulen: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for li in lay.size():
		var pair: Array = lay[li]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_strip(st, c, nrm, pair[0], pair[1], 0.004 * float(li), ulen)
		st.commit(mesh)
	return mesh


## Anneau d'ensō (rayon 1) : attaque pointue, pression qui ondule, queue qui chevauche le départ.
func _ring_mesh() -> ArrayMesh:
	if _meshes.has("bring"):
		return _meshes["bring"]
	var n := 32 if Toon.lite else 48
	var c := PackedVector3Array()
	var nrm := PackedVector3Array()
	var io := PackedFloat32Array()
	var ii := PackedFloat32Array()
	var bo := PackedFloat32Array()
	var bi := PackedFloat32Array()
	var co := PackedFloat32Array()
	var ci := PackedFloat32Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var a := u * TAU * 1.06
		var d := Vector3(cos(a), 0, sin(a))
		c.append(d)
		nrm.append(d)
		var p := smoothstep(0.0, 0.08, u) * (1.0 - 0.6 * smoothstep(0.72, 1.0, u)) * (0.82 + 0.18 * sin(u * 31.0))
		var hw := 0.13 * p
		var ol := 0.03 * minf(1.0, p * 3.0)
		io.append(hw + ol)
		ii.append(-hw - ol)
		bo.append(hw * 0.78)
		bi.append(-hw * 0.78)
		co.append(hw * 0.22 + 0.004)
		ci.append(-hw * 0.22)
	var mesh := _brush_mesh(c, nrm, [[io, ii], [bo, bi], [co, ci]], 18.0)
	_meshes["bring"] = mesh
	return mesh


## Croissant de lame (rayon 1, bombé vers -z) : pointes effilées, tranchant clair côté extérieur.
func _cres_mesh() -> ArrayMesh:
	if _meshes.has("bcres"):
		return _meshes["bcres"]
	var n := 16
	var c := PackedVector3Array()
	var nrm := PackedVector3Array()
	var io := PackedFloat32Array()
	var ii := PackedFloat32Array()
	var bo := PackedFloat32Array()
	var bi := PackedFloat32Array()
	var co := PackedFloat32Array()
	var ci := PackedFloat32Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var a := lerpf(-1.25, 1.25, u)
		var d := Vector3(sin(a), 0, -cos(a))
		c.append(d)
		nrm.append(d)
		var sn := maxf(sin(PI * u), 0.0)
		var w := 0.3 * pow(sn, 0.75)
		var ol := 0.03 * minf(1.0, sn * 4.0)
		io.append(ol)
		ii.append(-w - ol)
		bo.append(0.0)
		bi.append(-w)
		co.append(-0.008)
		ci.append(-w * 0.38)
	var mesh := _brush_mesh(c, nrm, [[io, ii], [bo, bi], [co, ci]], 6.0)
	_meshes["bcres"] = mesh
	return mesh


## Estoc : fer de lance de z = 0 (talon, sec) à z = -1 (pointe), le plus large aux trois quarts.
func _streak_mesh() -> ArrayMesh:
	if _meshes.has("bstreak"):
		return _meshes["bstreak"]
	var n := 12
	var c := PackedVector3Array()
	var nrm := PackedVector3Array()
	var io := PackedFloat32Array()
	var ii := PackedFloat32Array()
	var bo := PackedFloat32Array()
	var bi := PackedFloat32Array()
	var co := PackedFloat32Array()
	var ci := PackedFloat32Array()
	for i in n + 1:
		# de la pointe (i = 0, encre fraîche) vers le talon (queue sèche)
		var uu := 1.0 - float(i) / float(n)
		c.append(Vector3(0, 0, -uu))
		nrm.append(Vector3.RIGHT)
		var hw := 0.13 * pow(uu, 0.6) * (1.0 - pow(uu, 5.0))
		var ol := 0.028 * minf(1.0, hw * 20.0)
		io.append(hw + ol)
		ii.append(-hw - ol)
		bo.append(hw * 0.75)
		bi.append(-hw * 0.75)
		co.append(hw * 0.28)
		ci.append(-hw * 0.28)
	var mesh := _brush_mesh(c, nrm, [[io, ii], [bo, bi], [co, ci]], 5.0)
	_meshes["bstreak"] = mesh
	return mesh


## Fil de pinceau droit de z = 0.5 à -0.5, effilé aux deux bouts (moitiés de la coupe d'iaï).
func _line_mesh() -> ArrayMesh:
	if _meshes.has("bline"):
		return _meshes["bline"]
	var n := 12
	var c := PackedVector3Array()
	var nrm := PackedVector3Array()
	var io := PackedFloat32Array()
	var ii := PackedFloat32Array()
	var bo := PackedFloat32Array()
	var bi := PackedFloat32Array()
	var co := PackedFloat32Array()
	var ci := PackedFloat32Array()
	for i in n + 1:
		var u := float(i) / float(n)
		c.append(Vector3(0, 0, 0.5 - u))
		nrm.append(Vector3.RIGHT)
		var hw := 0.05 * sqrt(maxf(sin(PI * u), 0.0))
		var ol := 0.022 * minf(1.0, hw * 40.0)
		io.append(hw + ol)
		ii.append(-hw - ol)
		bo.append(hw * 0.8)
		bi.append(-hw * 0.8)
		co.append(hw * 0.3)
		ci.append(-hw * 0.3)
	var mesh := _brush_mesh(c, nrm, [[io, ii], [bo, bi], [co, ci]], 9.0)
	_meshes["bline"] = mesh
	return mesh


## Étoile d'éclat (plan XY, face caméra par le matériau) : quatre longues branches, quatre courtes, cœur.
func _star_mesh() -> ArrayMesh:
	if _meshes.has("star8"):
		return _meshes["star8"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var ln := 1.0 if k % 2 == 0 else 0.45
		var w := 0.15 if k % 2 == 0 else 0.09
		var dir := Vector3(cos(a), sin(a), 0)
		var perp := Vector3(-sin(a), cos(a), 0)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(perp * w)
		st.add_vertex(dir * ln)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(dir * ln)
		st.add_vertex(-perp * w)
	var mesh := st.commit()
	_meshes["star8"] = mesh
	return mesh


## Éclaboussures d'encre au sol (rayon ~1) : gouttes rondes et quelques coulures qui fusent vers l'extérieur.
func _spatter_mesh() -> ArrayMesh:
	if _meshes.has("spatter"):
		return _meshes["spatter"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 913
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.75, 1.2)
		var s := rng.randf_range(0.025, 0.075)
		var dir := Vector3(cos(a), 0, sin(a))
		var cen := dir * d
		for j in 6:
			var a0 := TAU * float(j) / 6.0
			var a1 := TAU * float(j + 1) / 6.0
			st.add_vertex(cen)
			st.add_vertex(cen + Vector3(cos(a0), 0, sin(a0)) * s)
			st.add_vertex(cen + Vector3(cos(a1), 0, sin(a1)) * s)
		if k % 4 == 0:
			# coulure : goutte étirée qui file vers l'extérieur
			var side := Vector3(-dir.z, 0, dir.x) * s * 0.6
			st.add_vertex(cen + side)
			st.add_vertex(cen - side)
			st.add_vertex(cen + dir * s * 4.0)
	var mesh := st.commit()
	_meshes["spatter"] = mesh
	return mesh


# profil de la crête (avancée vers -z, hauteur) : dos de la vague, puis la lèvre qui s'enroule ; creux sous la lèvre
const CURL_OUT := [Vector2(-0.6, 0.0), Vector2(-0.42, 0.18), Vector2(-0.26, 0.4), Vector2(-0.1, 0.62), Vector2(0.06, 0.8),
	Vector2(0.22, 0.9), Vector2(0.38, 0.9), Vector2(0.5, 0.82), Vector2(0.56, 0.7), Vector2(0.53, 0.58),
	Vector2(0.45, 0.52), Vector2(0.37, 0.53)]
const CURL_IN := [Vector2(0.3, 0.0), Vector2(0.26, 0.12), Vector2(0.22, 0.26), Vector2(0.2, 0.4), Vector2(0.22, 0.54),
	Vector2(0.28, 0.66), Vector2(0.36, 0.72), Vector2(0.43, 0.72), Vector2(0.47, 0.67), Vector2(0.47, 0.61),
	Vector2(0.44, 0.565), Vector2(0.38, 0.535)]


func _curl_col(u: float, inner: bool) -> Color:
	var c := WATER_DEEP.lerp(WATER, clampf(u / 0.55, 0.0, 1.0))
	if u > 0.55:
		c = WATER.lerp(WATER_FOAM, clampf((u - 0.55) / 0.3, 0.0, 1.0))
	if u > 0.88:
		c = WATER_FOAM.lerp(Color.WHITE, clampf((u - 0.88) / 0.12, 0.0, 1.0))
	if inner:
		c = c.darkened(0.28)
	return c


func _cv(st: SurfaceTool, c: Color, x: float, p: Vector2) -> void:
	st.set_color(c)
	st.add_vertex(Vector3(x, p.y, -p.x))


func _cquad(st: SurfaceTool, ca: Color, cb: Color, x0: float, x1: float, pa: Vector2, pb: Vector2) -> void:
	_cv(st, ca, x0, pa)
	_cv(st, ca, x1, pa)
	_cv(st, cb, x1, pb)
	_cv(st, ca, x0, pa)
	_cv(st, cb, x1, pb)
	_cv(st, cb, x0, pb)


## Crête de vague à la Hokusai (largeur 1 en x, hauteur ~0.9, s'enroule vers -z) : dos bleu de Prusse qui
## s'éclaircit jusqu'à l'écume, flancs cernés d'encre, lignes d'écume, griffes d'écume sous la lèvre.
## Couleurs de sommets (un seul matériau opaque partagé, _curl_mat).
func _curl_mesh() -> ArrayMesh:
	if _meshes.has("curl"):
		return _meshes["curl"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := CURL_OUT.size()
	for i in n - 1:
		var u0 := float(i) / float(n - 1)
		var u1 := float(i + 1) / float(n - 1)
		var oa: Vector2 = CURL_OUT[i]
		var ob: Vector2 = CURL_OUT[i + 1]
		var ia: Vector2 = CURL_IN[i]
		var ib: Vector2 = CURL_IN[i + 1]
		# dos (extérieur) et creux (intérieur), sur toute la largeur
		_cquad(st, _curl_col(u0, false), _curl_col(u1, false), -0.5, 0.5, oa, ob)
		_cquad(st, _curl_col(u0, true), _curl_col(u1, true), -0.5, 0.5, ia, ib)
		# flancs (coupe de la vague) aux deux bouts
		for x: float in [-0.5, 0.5]:
			_cv(st, _curl_col(u0, false), x, oa)
			_cv(st, _curl_col(u0, true), x, ia)
			_cv(st, _curl_col(u1, true), x, ib)
			_cv(st, _curl_col(u0, false), x, oa)
			_cv(st, _curl_col(u1, true), x, ib)
			_cv(st, _curl_col(u1, false), x, ob)
		# contour d'encre du profil, juste à l'extérieur des flancs
		var t := ob - oa
		var nrm := Vector2(-t.y, t.x).normalized() * 0.035
		for x2: float in [-0.506, 0.506]:
			_cv(st, INK, x2, oa)
			_cv(st, INK, x2, ob)
			_cv(st, INK, x2, ob + nrm)
			_cv(st, INK, x2, oa)
			_cv(st, INK, x2, ob + nrm)
			_cv(st, INK, x2, oa + nrm)
		# lignes d'écume sur le dos
		if i == 2 or i == 4 or i == 6:
			var lift := Vector2(-t.y, t.x).normalized() * 0.008
			_cquad(st, WATER_FOAM, WATER_FOAM, -0.48, 0.48, oa + lift, oa + t * 0.16 + lift)
	# griffes d'écume qui pendent de la lèvre
	var lip: Vector2 = CURL_OUT[9]
	var lip2: Vector2 = CURL_OUT[10]
	for x3: float in [-0.38, -0.13, 0.13, 0.38]:
		_cv(st, Color.WHITE, x3 - 0.08, lip)
		_cv(st, Color.WHITE, x3 + 0.08, lip)
		_cv(st, WATER_FOAM, x3, lip + Vector2(0.09, -0.17))
		_cv(st, Color.WHITE, x3 - 0.05 + 0.06, lip2)
		_cv(st, Color.WHITE, x3 + 0.05 + 0.06, lip2)
		_cv(st, WATER_FOAM, x3 + 0.06, lip2 + Vector2(-0.02, -0.13))
	var mesh := st.commit()
	_meshes["curl"] = mesh
	return mesh


func _curl_mat() -> StandardMaterial3D:
	if _mats.has("curl"):
		return _mats["curl"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["curl"] = m
	return m


# --- briques d'effet

## Éclat lumineux face caméra (étoile additive + cœur blanc) : gonfle d'un coup puis se résorbe.
func _flare(p: Vector3, c: Color, s: float, life: float, delay := 0.0) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = p
	var rs := _sramp("flare" + c.to_html(), Color(c, c.a * 0.9), 8, true, 2)
	var rc := _sramp("flare_core", Color(1, 1, 1, 0.9), 9, true, 2)
	var a := _mi(node, _star_mesh(), rs[0])
	var b := _mi(node, _ball(), rc[0])
	b.scale = Vector3.ONE * 0.42
	_anim(node, life, Vector3.ONE * s * 0.25, Vector3.ONE * s, {"g": 0.3, "sh": 0.55, "f": 0.4, "t": -delay,
		"lay": [[a, -1, rs], [b, -1, rc]]})


## Onde de choc au pinceau (anneau d'ensō qui s'ouvre jusqu'au rayon r) : contour `outer`, corps `body`,
## cœur `core` (additif si core_add) ; les poils sèchent en fin de vie.
## Au ras du sol : dessinée SOUS les annonces d'attaque (priorités -3..-1 < 1..2 des annonces), un peu pâlie
## et écourtée, pour ne jamais masquer un ennemi ni son disque rouge.
func _shock(pos: Vector3, r: float, outer: Color, body: Color, core: Color, core_add: bool, life: float, delay := 0.0) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = pos
	node.rotation.y = randf() * TAU
	var cc := Color(core, core.a * 0.8)
	var cr := _sramp(("shk_a" if core_add else "shk_n") + cc.to_html(), cc, -1, core_add)
	var lay := _layers(node, _ring_mesh(), [_bramp(Color(outer, outer.a * 0.75), -3), _bramp(Color(body, body.a * 0.75), -2), cr])
	_anim(node, life * 0.85, Vector3.ONE * r * 0.2, Vector3.ONE * r, {"g": 0.42, "f": 0.3, "lay": lay, "t": -delay, "spin": 1.2})


## Tache au sol (brûlure, ombre) au bord déchiqueté, qui s'étale vite puis s'estompe.
func _decal(g: Vector3, r: float, c: Color, life: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(g.x, 0.05, g.z)
	var rr := _sramp("decal" + c.to_html(), c, -4)
	var mi := _mi(node, _splat_mesh(), rr[0])
	mi.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	_anim(node, minf(life, 1.3), Vector3.ONE * r * 0.35, Vector3.ONE * r, {"g": 0.12, "f": 0.45, "lay": [[mi, -1, rr]]})


## Éclat d'encre face caméra qui jaillit puis se disperse (même langage que la mise à mort).
func _ink_pop(p: Vector3, s: float) -> void:
	var burst := Node3D.new()
	add_child(burst)
	burst.position = p
	_mi(burst, _splat_mesh(), _mat("ink_burst", Color(Toon.SUMI, 0.8), -1, false, 2))
	burst.scale = Vector3.ONE * 0.2
	_fx.append({"node": burst, "t": 0.0, "life": 0.3, "kind": "burst", "s": s})


## Éclaboussures d'encre au sol, en couronne de rayon r.
func _spatter(g: Vector3, r: float, c: Color, life: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(g.x, 0.06, g.z)
	node.rotation.y = randf() * TAU
	var rr := _sramp("spat" + c.to_html(), Color(c, 0.7), -4)
	var mi := _mi(node, _spatter_mesh(), rr[0])
	_anim(node, life, Vector3.ONE * r * 0.55, Vector3.ONE * r * 1.05, {"g": 0.22, "f": 0.5, "lay": [[mi, -1, rr]]})


## Silhouette d'ombre laissée au départ d'un estoc (rémanence violette qui se dissipe).
func _ghost(p: Vector3) -> void:
	if not _meshes.has("ghost_body"):
		_meshes["ghost_body"] = Toon.capsule(0.3, 1.15)
		_meshes["ghost_head"] = Toon.sphere(0.22)
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(p.x, 0, p.z)
	var rr := _sramp("ghost", Color(0.14, 0.08, 0.24, 0.55), 1)
	var b := _mi(node, _meshes["ghost_body"], rr[0], 0.72)
	var h := _mi(node, _meshes["ghost_head"], rr[0], 1.45)
	_anim(node, 0.45, Vector3.ONE, Vector3(1.2, 1.05, 1.2), {"g": 1.0, "f": 0.0, "lay": [[b, -1, rr], [h, -1, rr]]})


## Crête de vague qui se dresse face à `dir`, court (vel) puis s'abat (rétrécit en hauteur).
func _crest(g: Vector3, dir: Vector3, s: float, life: float, vel := Vector3.ZERO) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(g.x, 0.02, g.z)
	node.rotation.y = atan2(-d.x, -d.z)
	_mi(node, _curl_mesh(), _curl_mat())
	_anim(node, life, Vector3(s * 0.8, s * 0.1, s * 0.7), Vector3.ONE * s, {"g": 0.4, "pu": 0.12, "sh": 0.4,
		"sm": Vector3(0.0, 1.0, 0.0), "vel": vel})


## Croissant de pinceau qui file vers d en tournoyant (lames de vent, toupie).
func _brush_crescent(p: Vector3, d: Vector3, s: float, ink: Color, body: Color, core: Color, life: float, spin: float, vel: Vector3) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = p
	node.rotation.y = atan2(-d.x, -d.z)
	var lay := _layers(node, _cres_mesh(), [_bramp(ink, 4), _bramp(body, 5), _sramp("cres" + core.to_html(), core, 6, true)])
	_anim(node, life, Vector3.ONE * s * 0.55, Vector3.ONE * s * 1.15, {"g": 0.3, "f": 0.4, "lay": lay, "spin": spin,
		"vel": vel, "pu": 0.15})


## Trait de vitesse (fer d'estoc étiré) qui part de p vers d.
func _streak_line(p: Vector3, d: Vector3, ln: float, w: float, ink: Color, body: Color, core: Color, life: float, delay := 0.0) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = p
	node.rotation.y = atan2(-d.x, -d.z)
	var lay := _layers(node, _streak_mesh(), [_bramp(ink, 4), _bramp(body, 5), _sramp("strk" + core.to_html(), core, 6, true)])
	_anim(node, life, Vector3(w * 1.6, 1.0, ln * 0.25), Vector3(w, 1.0, ln), {"g": 0.18, "f": 0.35, "lay": lay, "t": -delay})


# ------------------------------------------------------------------ annonces d'attaque
# Une annonce = un nœud racine (posé par l'appelant) avec : fond vermillon + contour d'encre (un seul maillage,
# deux surfaces), remplissage qui grandit jusqu'au contour, liseré vermillon qui pulse. Les 0.15 dernières
# secondes, le remplissage flashe. Tout est partagé (maillages par taille, matériaux uniques), rien par instance.
#   tele_disc(parent, r)                       disque centré
#   tele_rect(parent, hx, hz, grow)            rectangle centré (demi-tailles) ; grow = côté d'où part le remplissage
#                                              (Vector2.ZERO : du centre ; (±1, 0) : du bord ±x ; (0, ±1) : du bord ±z)
#   tele_fan(parent, half_angle, length)       cône depuis l'origine vers +z
#   tele_update(zone, k, t_left)               k = avancement 0..1, t_left = temps avant le coup
#   tele_dot(parent, r) / tele_dot_flash(dot, on)   petite marque de chemin (même langage)

func _tele_init() -> void:
	if not _tmat.is_empty():
		return
	_tmat["base"] = _mat("tele_base", Color(Toon.VERMILION, 0.24), 1)
	_tmat["fill"] = _mat("tele_fill", Color(0.88, 0.2, 0.13, 0.58), 2)
	_tmat["flash"] = _mat("tele_flash", Color(1.0, 0.95, 0.86, 0.92), 2)
	_tmat["rim"] = _mat("tele_rim", Color(0.95, 0.24, 0.15, 0.95), 3)
	_tmat["ink"] = _mat("tele_ink", Color(Toon.SUMI, 0.9), 4)
	_tmat["dot"] = _mat("tele_dot", Color(0.92, 0.22, 0.14, 0.9), 2)


func _circle(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


func _rect_pts(hx: float, hz: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)])


func _fan_pts(half: float, length: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2.ZERO])
	var steps := 12
	for i in steps + 1:
		var a := lerpf(-half, half, float(i) / float(steps))
		out.append(Vector2(sin(a), cos(a)) * length)
	return out


func _edge_normal(a: Vector2, b: Vector2, cen: Vector2) -> Vector2:
	var e := b - a
	var nrm := Vector2(-e.y, e.x).normalized()
	if nrm.dot((a + b) * 0.5 - cen) < 0.0:
		nrm = -nrm
	return nrm


## Bande le long du contour d'un polygone convexe, de d0 à d1 (négatif = dedans).
func _poly_band(st: SurfaceTool, pts: PackedVector2Array, d0: float, d1: float) -> void:
	var n := pts.size()
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(n)
	var offs := PackedVector2Array()
	for i in n:
		var na := _edge_normal(pts[(i - 1 + n) % n], pts[i], cen)
		var nb := _edge_normal(pts[i], pts[(i + 1) % n], cen)
		var m := (na + nb).normalized()
		offs.append(m / maxf(m.dot(nb), 0.35))
	for i in n:
		var j := (i + 1) % n
		var a0 := pts[i] + offs[i] * d0
		var a1 := pts[i] + offs[i] * d1
		var b0 := pts[j] + offs[j] * d0
		var b1 := pts[j] + offs[j] * d1
		_quad(st, Vector3(a0.x, 0, a0.y), Vector3(a1.x, 0, a1.y), Vector3(b1.x, 0, b1.y), Vector3(b0.x, 0, b0.y))


## Intérieur d'un polygone convexe (éventail depuis le barycentre).
func _poly_fill(st: SurfaceTool, pts: PackedVector2Array) -> void:
	var n := pts.size()
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(n)
	var c3 := Vector3(cen.x, 0, cen.y)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		st.add_vertex(c3)
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, 0, b.y))


func _tele_mesh(key: String, pts: PackedVector2Array, part: String) -> ArrayMesh:
	var ck := part + key
	if _meshes.has(ck):
		return _meshes[ck]
	var mesh := ArrayMesh.new()
	if part == "frame":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_fill(st, pts)
		st.commit(mesh)
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_band(st2, pts, -0.02, TELE_INK)
		st2.commit(mesh)
		mesh.surface_set_material(0, _tmat["base"])
		mesh.surface_set_material(1, _tmat["ink"])
	elif part == "rim":
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_band(st3, pts, -0.02 - TELE_RIM, -0.02)
		st3.commit(mesh)
		mesh.surface_set_material(0, _tmat["rim"])
	else:
		var st4 := SurfaceTool.new()
		st4.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_fill(st4, pts)
		st4.commit(mesh)
	_meshes[ck] = mesh
	return mesh


func _tele_make(parent: Node3D, key: String, pts: PackedVector2Array, fill_mesh: Mesh, fs: Vector3, grow: Vector2) -> Node3D:
	_tele_init()
	var root := Node3D.new()
	parent.add_child(root)
	_mi(root, _tele_mesh(key, pts, "frame"), null, TELE_Y)
	var fill := _mi(root, fill_mesh, _tmat["fill"], TELE_Y + 0.004)
	var rim := _mi(root, _tele_mesh(key, pts, "rim"), null, TELE_Y + 0.008)
	root.set_meta("fill", fill)
	root.set_meta("rim", rim)
	root.set_meta("fs", fs)
	root.set_meta("grow", grow)
	tele_update(root, 0.0, 99.0)
	return root


func tele_disc(parent: Node3D, r: float) -> Node3D:
	_tele_init()
	var unit := _tele_mesh("u", _circle(1.0, 40), "fdisc")
	return _tele_make(parent, "d%.2f" % r, _circle(r, 40), unit, Vector3(r, 1, r), Vector2.ZERO)


func tele_rect(parent: Node3D, hx: float, hz: float, grow := Vector2.ZERO) -> Node3D:
	_tele_init()
	var unit := _tele_mesh("u", _rect_pts(1.0, 1.0), "frect")
	# tailles arrondies à 5 cm : le cache de maillages reste petit même si les longueurs varient
	var sx := maxf(snappedf(hx, 0.05), 0.05)
	var sz := maxf(snappedf(hz, 0.05), 0.05)
	return _tele_make(parent, "r%.2f_%.2f" % [sx, sz], _rect_pts(sx, sz), unit, Vector3(sx, 1, sz), grow)


func tele_fan(parent: Node3D, half_angle: float, length: float) -> Node3D:
	_tele_init()
	var unit := _tele_mesh("u%.3f" % half_angle, _fan_pts(half_angle, 1.0), "ffan")
	var sl := maxf(snappedf(length, 0.05), 0.05)
	return _tele_make(parent, "f%.3f_%.2f" % [half_angle, sl], _fan_pts(half_angle, sl), unit, Vector3(sl, 1, sl), Vector2.ZERO)


## Avance une annonce : remplissage k (0..1) jusqu'au contour, pulsation, flash final.
func tele_update(zone_v: Variant, k: float, t_left: float) -> void:
	# argument non typé : un repère déjà libéré ne doit pas faire planter l'appel
	if zone_v == null or not is_instance_valid(zone_v):
		return
	var zone: Node3D = zone_v
	if not zone.has_meta("fill"):
		return
	var kk := clampf(k, 0.01, 1.0)
	var fill: MeshInstance3D = zone.get_meta("fill")
	var rim: MeshInstance3D = zone.get_meta("rim")
	var fs: Vector3 = zone.get_meta("fs")
	var g: Vector2 = zone.get_meta("grow")
	if g.x != 0.0:
		fill.scale = Vector3(fs.x * kk, 1, fs.z)
		fill.position.x = g.x * fs.x * (1.0 - kk)
	elif g.y != 0.0:
		fill.scale = Vector3(fs.x, 1, fs.z * kk)
		fill.position.z = g.y * fs.z * (1.0 - kk)
	else:
		fill.scale = Vector3(fs.x * kk, 1, fs.z * kk)
	var flash := t_left < TELE_FLASH
	var m: Material = _tmat["flash"] if flash else _tmat["fill"]
	if fill.material_override != m:
		fill.material_override = m
	# pulsation du liseré, plus marquée à l'approche du coup
	var w := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.014)
	rim.scale = Vector3.ONE * (1.0 - (0.01 + 0.035 * kk) * w)
	rim.visible = not flash


func tele_dot(parent: Node3D, r: float) -> MeshInstance3D:
	_tele_init()
	if not _meshes.has("tele_dot"):
		var mesh := ArrayMesh.new()
		var pts := _circle(1.0, 16)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_fill(st, pts)
		st.commit(mesh)
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_band(st2, pts, 0.0, 0.45)
		st2.commit(mesh)
		mesh.surface_set_material(0, _tmat["dot"])
		mesh.surface_set_material(1, _tmat["ink"])
		_meshes["tele_dot"] = mesh
	var mi := _mi(parent, _meshes["tele_dot"], null, TELE_Y)
	mi.scale = Vector3(r, 1, r)
	return mi


func tele_dot_flash(dot: MeshInstance3D, on: bool) -> void:
	_tele_init()
	if on:
		if dot.material_override == null:
			dot.material_override = _tmat["flash"]
	elif dot.material_override != null:
		dot.material_override = null


# ------------------------------------------------------------------ foudre (雷) : éclair en zigzag

## Éclair brisé de a à b : contour d'encre, corps jaune, cœur blanc ; petit flash blanc et étincelles au bout.
## hero (pouvoirs du héros) : trait qui claque plus épais puis s'affine, éclats aux deux bouts, fourche,
## rémanence lumineuse du tracé ; retombe sur la version simple si le budget d'effets est épuisé.
## gold (Statique, Paratonnerre) : éclair or / écume au lieu du jaune.
func bolt(a: Vector3, b: Vector3, sparks_n := 3, hero := false, gold := false) -> void:
	var l := a.distance_to(b)
	if l < 0.05:
		return
	var rich := hero and _rich(3.0)
	var body := GOLD if gold else BOLT
	var core := Toon.WASHI if gold else BOLT_CORE
	var mi := _bolt_node(a, b, 0.24 if rich else 0.2, 1.0, rich, gold)
	_pop(b, core, 0.7 if rich else 0.55)
	_play("zap", randf_range(0.9, 1.15), -5.0)
	if sparks_n > 0:
		sparks(b, b - a, sparks_n + (1 if rich else 0), body)
	if not rich:
		return
	# éclats : départ blanc, arrivée jaune (ou or) plus large
	_flare(a, core, 0.42, 0.1)
	_flare(b, body, 0.85, 0.16)
	sparks(b, Vector3.UP, 2, core, 4.0, 8.0, 80.0)
	# fourche : une branche fine part du milieu
	if not Toon.lite and l > 1.0:
		var m := a.lerp(b, randf_range(0.35, 0.6))
		var side := (b - a).cross(Vector3.UP).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var tip := m + (b - a) * 0.22 + side * randf_range(-1.0, 1.0) * l * 0.28 + Vector3(0, randf_range(-0.25, 0.25), 0)
		_bolt_node(m, tip, 0.16, 0.55, false, gold)
	# rémanence : le même tracé, additif, qui s'estompe juste après l'éclair
	var ghost := MeshInstance3D.new()
	ghost.mesh = mi.mesh
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	ghost.transform = mi.transform
	var gr := _sramp("bolt_ghost_g", Color(GOLD, 0.6), 4, true) if gold else _sramp("bolt_ghost", Color(1.0, 0.95, 0.55, 0.55), 4, true)
	ghost.material_override = gr[0]
	_anim(ghost, 0.26, Vector3.ONE, Vector3.ONE, {"ns": true, "t": -0.12, "f": 0.0, "lay": [[ghost, -1, gr]]})


## Nœud d'éclair de a à b (life s). thin : épaisseur relative ; punch : claque plus épais puis s'affine.
func _bolt_node(a: Vector3, b: Vector3, life: float, thin: float, punch: bool, gold := false) -> MeshInstance3D:
	var l := a.distance_to(b)
	var bucket := maxi(1, int(round(l / 0.5)))
	var v := randi() % 3
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh(bucket, v)
	if gold:
		_bolt_gold(mi)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var xf := _seg_xform(a, b)
	if thin != 1.0:
		xf.basis = Basis(xf.basis.x * thin, xf.basis.y * thin, xf.basis.z)
	mi.transform = xf
	var fx := {"node": mi, "t": 0.0, "life": life, "kind": "bolt", "alt": _bolt_mesh(bucket, (v + 1) % 3), "swap": false}
	if punch:
		fx["b0"] = xf.basis
	_fx.append(fx)
	return mi


## Foudre qui tombe du ciel sur p (Raijū, Raijin, orage) : éclair, fourche, éclat au sol, onde jaune
## cernée d'encre, gerbe d'étincelles et brûlure étoilée.
func sky_bolt(p: Vector3, big := false, gold := false) -> void:
	var g := Vector3(p.x, 0.05, p.z)
	var top := g + Vector3(randf_range(-0.6, 0.6), 7.0, randf_range(-0.6, 0.6))
	var body := GOLD if gold else BOLT
	var core := Toon.WASHI if gold else BOLT_CORE
	var rich := _rich(3.0)
	if not rich:
		bolt(top, g, 0, false, gold)
		ring(Vector3(p.x, 0.07, p.z), body, 1.0 if big else 0.7)
		sparks(g + Vector3(0, 0.2, 0), Vector3.UP, 6 if big else 4, body)
		scorch(p, 0.35 if big else 0.25, 0.8)
	else:
		_bolt_node(top, g, 0.26, 1.35 if big else 1.15, true, gold)
		_pop(g + Vector3(0, 0.3, 0), core, 0.9 if big else 0.7)
		if not Toon.lite:
			var mid := top.lerp(g, randf_range(0.3, 0.5))
			_bolt_node(mid, g + Vector3(randf_range(-1.2, 1.2), 0.3, randf_range(-1.2, 1.2)), 0.18, 0.6, false, gold)
		_flare(g + Vector3(0, 0.35, 0), body, 1.3 if big else 0.95, 0.18)
		_shock(Vector3(p.x, 0.07, p.z), 1.25 if big else 0.9, Color(INK, 0.8), body, core, true, 0.38)
		sparks(g + Vector3(0, 0.2, 0), Vector3.UP, 7 if big else 5, body, 5.0, 11.0, 70.0)
		sparks(g + Vector3(0, 0.2, 0), Vector3.UP, 3, core, 3.0, 7.0, 85.0)
		_decal(g, 0.45 if big else 0.32, Color(0.12, 0.09, 0.05, 0.5), 1.0)
		if big:
			_shake(0.14)
	_play("thunder", randf_range(0.85, 0.95) if big else randf_range(1.0, 1.15), -3.0 if big else -7.0)


func _bolt_mats() -> Array:
	return [_mat("bolt_ink", Color(Toon.SUMI, 0.6), 5), _mat("bolt_body", BOLT, 6), _mat("bolt_core", BOLT_CORE, 7)]


## Maillage d'éclair (longueur bucket × 0.5 m, variante v), tracé de 0 à -1 en z (mis à l'échelle par _seg_xform).
func _bolt_mesh(bucket: int, v: int) -> ArrayMesh:
	var key := "bolt%d_%d" % [bucket, v]
	if _meshes.has(key):
		return _meshes[key]
	var length := float(bucket) * 0.5
	var n := clampi(bucket * 2, 3, 12)
	var jit := clampf(length * 0.12, 0.08, 0.3)
	var path := PackedVector3Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var j := 0.0 if (i == 0 or i == n) else 1.0
		var side := 1.0 if i % 2 == 0 else -1.0  # alterne : vrai zigzag
		path.append(Vector3(side * randf_range(0.4, 1.0) * jit * j, randf_range(-0.5, 0.5) * jit * j, -u * length))
	var mesh := ArrayMesh.new()
	var widths := [0.11, 0.065, 0.025]
	var mats := _bolt_mats()
	for s in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w: float = widths[s]
		for i in n:
			var pa := path[i] / length
			var pb := path[i + 1] / length
			# largeur perpendiculaire au segment (en vraie grandeur), ramenée à l'échelle unité en z
			var seg := path[i + 1] - path[i]
			var sx := seg.cross(Vector3.UP).normalized() * w
			var sy := sx.cross(seg).normalized() * w
			var ox := Vector3(sx.x, sx.y, sx.z / length)
			var oy := Vector3(sy.x, sy.y, sy.z / length)
			var a3 := Vector3(path[i].x, path[i].y, pa.z)
			var b3 := Vector3(path[i + 1].x, path[i + 1].y, pb.z)
			_quad(st, a3 - ox, a3 + ox, b3 + ox, b3 - ox)
			_quad(st, a3 - oy, a3 + oy, b3 + oy, b3 - oy)
		st.commit(mesh)
		mesh.surface_set_material(s, mats[s])
	_meshes[key] = mesh
	return mesh


## Petit flash (boule qui gonfle puis disparaît).
func _pop(p: Vector3, c: Color, s: float) -> void:
	var mi := _mi(self, _ball(), _mat("pop" + c.to_html(), Color(c, 0.9), 8), 0.0)
	mi.position = p
	_fx.append({"node": mi, "t": 0.0, "life": 0.12, "kind": "pop", "s": s})


# ------------------------------------------------------------------ feu (火) : flammes, braises, roussi

func _flame_res() -> void:
	if _flame_ramp != null:
		return
	_flame_ramp = Gradient.new()
	_flame_ramp.set_color(0, Color(1.0, 0.86, 0.35, 1.0))
	_flame_ramp.set_color(1, Color(0.3, 0.08, 0.04, 0.0))
	_flame_ramp.add_point(0.3, Color(1.0, 0.5, 0.12, 1.0))
	_flame_ramp.add_point(0.7, Color(0.86, 0.2, 0.1, 0.85))
	_flame_curve = Curve.new()
	_flame_curve.add_point(Vector2(0.0, 0.55))
	_flame_curve.add_point(Vector2(0.25, 1.0))
	_flame_curve.add_point(Vector2(1.0, 0.15))


## Langue de flamme (face caméra, pointe en haut).
func _tongue() -> Mesh:
	if _meshes.has("tongue"):
		return _meshes["tongue"]
	var pts := [Vector2(0, 0.5), Vector2(0.13, 0.1), Vector2(0.11, -0.08), Vector2(0, -0.17), Vector2(-0.11, -0.08), Vector2(-0.13, 0.1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		st.add_vertex(Vector3(0, 0.05, 0))
		st.add_vertex(Vector3(a.x, a.y, 0))
		st.add_vertex(Vector3(b.x, b.y, 0))
	var m := st.commit()
	_meshes["tongue"] = m
	return m


## Langue de flamme statique (halos des pouvoirs) : maillage et matériau face caméra partagés.
func flame_mesh() -> Mesh:
	return _tongue()


func flame_mat(c: Color) -> StandardMaterial3D:
	return _mat("tongue" + c.to_html(), c, 3, false, 2)


## Émetteur de flammes : disque de rayon r au sol (ou points `pts`). emit > 0 : émission continue pendant emit s.
func _flame_emitter(pos: Vector3, r: float, amount: int, emit: float) -> CPUParticles3D:
	_flame_res()
	var p := CPUParticles3D.new()
	p.mesh = _tongue()
	p.material_override = _mat("flame_p", Color.WHITE, 3, true, 1)
	p.amount = amount
	p.lifetime = 0.5
	p.one_shot = emit <= 0.0
	p.explosiveness = 0.75 if emit <= 0.0 else 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.05
	p.emission_ring_radius = maxf(r, 0.05)
	p.emission_ring_inner_radius = 0.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 2.5, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _flame_curve
	p.color_ramp = _flame_ramp
	p.position = pos + Vector3(0, 0.12, 0)
	return p


## Gerbe de flammes (brève) : langues qui montent et vacillent.
func flames(pos: Vector3, r: float, amount := 8) -> void:
	var p := _flame_emitter(pos, r, amount, 0.0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 0.8, "kind": "none"})


## Flammes continues accrochées à `parent` (brûlure, roue de feu, halo) ; l'appelant libère le nœud.
func burner(parent: Node3D, r: float, amount := 5, offset := Vector3.ZERO) -> CPUParticles3D:
	var p := _flame_emitter(Vector3.ZERO, r, amount, 1.0)
	p.position = offset + Vector3(0, 0.12, 0)
	parent.add_child(p)
	p.emitting = true
	return p


func _ember_mesh() -> Mesh:
	if not _meshes.has("ember"):
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = glow_mat(FIRE_HOT, 3.0)
		_meshes["ember"] = sm
	return _meshes["ember"]


## Braises : petits points chauds qui montent (life : durée de vie d'une braise).
func embers(pos: Vector3, r: float, amount := 5, life := 0.8) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _ember_mesh()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(r, 0.05)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 1.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.position = pos + Vector3(0, 0.3, 0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": life + 0.2, "kind": "none"})


## Tache de roussi au sol (suie), qui se résorbe à la fin.
func scorch(pos: Vector3, r: float, life := 1.2) -> void:
	var mi := _mi(self, _unit_disc(), _mat("soot", Color(0.13, 0.08, 0.06, 0.42), 0), 0.0)
	mi.position = Vector3(pos.x, 0.05, pos.z)
	var s := Vector3(r, 1, r * randf_range(0.7, 1.0))
	mi.scale = s
	mi.rotation.y = randf() * TAU
	_fx.append({"node": mi, "t": 0.0, "life": life, "kind": "shrink", "s3": s})


## Cercle de feu : couronne de flammes, anneau orange, braises, roussi.
## hero (Foyer, Hibana, Hōō…) : embrasement blanc-or, couronne de langues de flamme qui jaillit puis retombe,
## onde de chaleur au pinceau cernée de braise sombre, braises qui s'attardent, brûlure étoilée.
func fire_burst(pos: Vector3, r: float, hero := false) -> void:
	flames(pos, r * 0.85, clampi(int(6.0 + r * 4.0), 6, 16))
	_play("fire", randf_range(0.9, 1.1), -4.0)
	if not hero or not _rich(4.0):
		ring(Vector3(pos.x, 0.07, pos.z), FIRE, r)
		embers(pos, r * 0.5, 5)
		scorch(pos, r * 0.6, 1.0)
		return
	var g := Vector3(pos.x, 0.07, pos.z)
	# anticipation : embrasement bref au centre
	_flare(g + Vector3(0, 0.45, 0), FIRE_HOT, clampf(r * 0.7, 0.7, 1.8), 0.14)
	_flame_crown(g, r)
	_shock(g, r * 1.05, Color(FIRE_DEEP, 0.85), FIRE, FIRE_HOT, true, 0.45)
	embers(pos, r * 0.6, 6 if Toon.lite else 12, 1.3)
	sparks(g + Vector3(0, 0.3, 0), Vector3.UP, 3 if Toon.lite else 5, FIRE_HOT, 4.0, 9.0, 60.0)
	_decal(g, r * 0.7, Color(0.13, 0.06, 0.04, 0.5), 1.6)
	var sv := minf(0.1 + 0.06 * r, 0.3)
	_shake(maxf(0.08, sv * sv * 3.4))  # secousse linéaire (main) : même ressenti qu'avant
	if r >= 2.2:
		_flash(0.18)


## Couronne de langues de flamme (face caméra) posée en cercle : jaillit, vacille, retombe.
func _flame_crown(g: Vector3, r: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = g
	var n := clampi(int(r * 5.0), 6, 12)
	if Toon.lite:
		n = maxi(4, int(n * 0.5))
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		var hot := i % 2 == 0
		var f := _mi(node, _tongue(), flame_mat(FIRE_HOT if hot else FIRE))
		f.position = Vector3(cos(a) * r * 0.8, 0.0, sin(a) * r * 0.8)
		f.scale = Vector3.ONE * randf_range(1.5, 2.3) * (1.15 if hot else 1.0)
	# cœur : une grande langue au centre
	var c := _mi(node, _tongue(), flame_mat(FIRE_HOT))
	c.scale = Vector3.ONE * clampf(r * 0.9, 1.2, 2.2)
	_anim(node, 0.55, Vector3(1.0, 0.25, 1.0), Vector3.ONE, {"g": 0.3, "pu": 0.25, "sh": 0.45, "sm": Vector3(0.2, 1.0, 0.2)})


## Flammes le long d'un trait (sillage) : un seul émetteur sur des points, plus une traînée de suie.
## Temps du jeu (le sillage blesse en temps du jeu).
func fire_trail(points: PackedVector3Array, dur: float) -> void:
	if points.size() < 2:
		return
	var pts := PackedVector3Array()
	var acc := 0.0
	for i in range(1, points.size()):
		acc += points[i].distance_to(points[i - 1])
		if acc >= 0.5:
			acc = 0.0
			pts.append(Vector3(points[i].x, 0.12, points[i].z))
	if pts.is_empty():
		pts.append(Vector3(points[0].x, 0.12, points[0].z))
	var p := _flame_emitter(Vector3.ZERO, 0.1, clampi(pts.size() * 3, 6, 36), dur)
	p.position = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.lifetime = 0.55
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": dur + 0.6, "kind": "emit", "stop": dur, "game": true})
	if main:
		_play("crackle", randf_range(0.9, 1.1), -6.0)
	# suie : ruban au sol, propre à ce trait (il s'efface d'un bloc)
	# + fil de braise incandescent au milieu, qui refroidit vite (additif, propre au trait aussi)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var d := b - a
		d.y = 0
		if d.length_squared() < 0.0001:
			continue
		var nrm := Vector3(-d.z, 0, d.x).normalized()
		var side := nrm * 0.22
		var ya := Vector3(a.x, 0.05, a.z)
		var yb := Vector3(b.x, 0.05, b.z)
		_quad(st, ya - side, ya + side, yb + side, yb - side)
		var hs := nrm * 0.07
		var ha := ya + Vector3(0, 0.006, 0)
		var hb := yb + Vector3(0, 0.006, 0)
		_quad(st2, ha - hs, ha + hs, hb + hs, hb - hs)
		quads += 1
	var m := Toon.flat(Color(0.14, 0.08, 0.05, 0.32))
	var mi := _mi(self, st.commit(), m, 0.0)
	_fx.append({"node": mi, "t": 0.0, "life": dur, "kind": "fade_mat", "mat": m, "a": 0.32, "game": true})
	if quads > 0:
		var hm := Toon.flat(Color(FIRE_HOT, 0.7))
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.render_priority = 1
		var hmi := _mi(self, st2.commit(), hm, 0.0)
		_fx.append({"node": hmi, "t": 0.0, "life": minf(dur, 1.1), "kind": "fade_mat", "mat": hm, "a": 0.7, "game": true})
	# braises qui s'échappent du sillage pendant qu'il brûle
	if not Toon.lite:
		var ep := CPUParticles3D.new()
		ep.mesh = _ember_mesh()
		ep.amount = clampi(pts.size() * 2, 4, 14)
		ep.lifetime = 0.9
		ep.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		ep.emission_points = pts
		ep.direction = Vector3.UP
		ep.spread = 30.0
		ep.initial_velocity_min = 1.0
		ep.initial_velocity_max = 2.4
		ep.gravity = Vector3(0, 0.8, 0)
		ep.damping_min = 0.5
		ep.damping_max = 1.5
		ep.scale_amount_min = 0.5
		ep.scale_amount_max = 1.1
		add_child(ep)
		ep.emitting = true
		_fx.append({"node": ep, "t": 0.0, "life": dur + 1.0, "kind": "emit", "stop": dur, "game": true})


# ------------------------------------------------------------------ eau (水) : anneaux, écume, vagues

## Vague en croissant (arc cyan à plat) qui part dans la direction dir.
## hero (Marée qui pousse) : une petite crête de vague à griffes d'écume se dresse et s'abat dans ce sens.
func wave_arc(pos: Vector3, dir: Vector3, s := 1.0, hero := false) -> void:
	if hero and _rich(1.0):
		_crest(Vector3(pos.x, 0.0, pos.z), dir, s * 0.75, 0.42)
	if _arc_mesh == null:
		_arc_mesh = _make_arc_mesh()
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.25, pos.z)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	node.rotation.y = atan2(-d.x, -d.z)
	_mi(node, _arc_mesh, glow_mat(WATER, 2.2))
	var foam := _mi(node, _arc_mesh, glow_mat(WATER_FOAM, 2.0))
	foam.scale = Vector3(0.8, 1, 0.8)
	foam.position.y = 0.02
	_fx.append({"node": node, "t": 0.0, "life": 0.3, "kind": "arc", "s": s})
	if main:
		_play("splash", randf_range(1.2, 1.4), -10.0)


## Éclat d'eau : anneau bleu, anneau d'écume, croissants de vague, gouttes.
## hero (Marée, écume, tourbillon) : éclat d'écume, crêtes de vague à la Hokusai qui se dressent tout autour,
## courent vers l'extérieur et s'abattent ; ondes au pinceau en cascade ; gerbes de gouttes.
func water_burst(pos: Vector3, r: float, hero := false) -> void:
	_play("splash", randf_range(0.9, 1.1), -4.0)
	if hero and _rich(5.0):
		var g := Vector3(pos.x, 0.0, pos.z)
		_flare(g + Vector3(0, 0.4, 0), WATER_FOAM, clampf(r * 0.55, 0.6, 1.4), 0.14)
		var n := 3 if Toon.lite else 5
		var wa0 := randf() * TAU
		for i in n:
			var wa := wa0 + TAU * float(i) / float(n) + randf_range(-0.25, 0.25)
			var wd := Vector3(cos(wa), 0, sin(wa))
			_crest(g + wd * r * 0.3, wd, clampf(r * 0.5, 0.55, 1.2) * randf_range(0.85, 1.1), 0.55, wd * r * 1.5)
		_shock(Vector3(pos.x, 0.07, pos.z), r * 1.05, Color(WATER_DEEP, 0.85), WATER, WATER_FOAM, true, 0.5)
		if not Toon.lite:
			_shock(Vector3(pos.x, 0.08, pos.z), r * 0.7, Color(WATER_DEEP, 0.7), WATER, WATER_FOAM, true, 0.45, 0.1)
			_shock(Vector3(pos.x, 0.09, pos.z), r * 1.35, Color(WATER_DEEP, 0.5), Color(WATER, 0.7), WATER_FOAM, true, 0.5, 0.2)
		if main:
			main.splash(pos, WATER, 10)
			main.splash(pos, WATER_FOAM, 7)
		_shake(0.08)
		return
	ring(Vector3(pos.x, 0.07, pos.z), WATER, r)
	ring(Vector3(pos.x, 0.09, pos.z), WATER_FOAM, r * 0.6)
	var a0 := randf() * TAU
	for i in 3:
		var a := a0 + TAU * float(i) / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		wave_arc(pos + d * r * 0.45, d, maxf(r * 0.45, 0.6))
	if main:
		main.splash(pos, WATER, 8)
		main.splash(pos, WATER_FOAM, 5)


# ------------------------------------------------------------------ vent (風) : croissants, spirales

## Lame de vent : croissant jade qui tourne à plat.
## hero (Kamaitachi, Tsumuji) : croissant au pinceau cerné de vert profond, au tranchant clair, qui file en
## tournoyant, deux traits de vitesse et une poussière d'étincelles pâles.
func wind_slash(pos: Vector3, dir: Vector3, s := 0.9, hero := false) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	if hero and _rich(2.0):
		var p := pos + Vector3(0, 0.7, 0)
		_brush_crescent(p, d, s * 1.1, Color(WIND_DEEP, 0.85), WIND, WIND_PALE, 0.32, 9.0, d * 3.5)
		var side := Vector3(-d.z, 0, d.x)
		_streak_line(p - d * 0.6 + side * 0.32, d, 1.7 * s, 0.6, Color(WIND_DEEP, 0.5), WIND_PALE, WIND_PALE, 0.24)
		if not Toon.lite:
			_streak_line(p - d * 0.9 - side * 0.28, d, 1.3 * s, 0.45, Color(WIND_DEEP, 0.5), WIND_PALE, WIND_PALE, 0.22, 0.04)
		sparks(p, d, 2, WIND_PALE, 5.0, 9.0, 25.0)
		_play("swish", randf_range(0.9, 1.15), -6.0)
		return
	if _arc_mesh == null:
		_arc_mesh = _make_arc_mesh()
	var node := Node3D.new()
	add_child(node)
	node.position = pos + Vector3(0, 0.7, 0)
	node.rotation.y = atan2(-d.x, -d.z)
	node.rotation.z = randf_range(-0.3, 0.3)
	_mi(node, _arc_mesh, glow_mat(WIND, 2.4))
	var core := _mi(node, _arc_mesh, glow_mat(WIND_PALE, 2.0))
	core.scale = Vector3(0.88, 1, 0.88)
	_fx.append({"node": node, "t": 0.0, "life": 0.22, "kind": "spinarc", "s": s})
	if main:
		_play("swish", randf_range(0.9, 1.15), -6.0)


func _swirl_mesh() -> Mesh:
	if _meshes.has("swirl"):
		return _meshes["swirl"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	for arm in 2:
		var a0 := PI * float(arm)
		for i in n:
			var u0 := float(i) / float(n)
			var u1 := float(i + 1) / float(n)
			var r0 := lerpf(0.2, 1.0, u0)
			var r1 := lerpf(0.2, 1.0, u1)
			var g0 := a0 + u0 * 4.2
			var g1 := a0 + u1 * 4.2
			var w0 := 0.09 * sin(PI * u0) + 0.01
			var w1 := 0.09 * sin(PI * u1) + 0.01
			var d0 := Vector3(cos(g0), 0, sin(g0))
			var d1 := Vector3(cos(g1), 0, sin(g1))
			_quad(st, d0 * (r0 - w0), d0 * (r0 + w0), d1 * (r1 + w1), d1 * (r1 - w1))
	var m := st.commit()
	_meshes["swirl"] = m
	return m


## Tourbillon : deux spirales (jade et blanche) qui tournent vite en s'ouvrant.
func swirl(pos: Vector3, r: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.35, pos.z)
	_mi(node, _swirl_mesh(), glow_mat(WIND, 2.2))
	var inner := _mi(node, _swirl_mesh(), glow_mat(WIND_PALE, 2.0))
	inner.scale = Vector3(0.6, 1, 0.6)
	inner.rotation.y = PI / 2.0
	inner.position.y = 0.15
	_fx.append({"node": node, "t": 0.0, "life": 0.45, "kind": "swirl", "r": r})
	if main:
		_play("gust", randf_range(0.9, 1.1), -5.0)


## Spirale persistante (zones des pouvoirs) : l'appelant la fait tourner et la libère.
func swirl_mesh() -> Mesh:
	return _swirl_mesh()


## Toupie (figure en boucle) : spirales de vent, et trois lames de pinceau blanches cernées d'encre qui
## tournoient autour du héros (elles le suivent) ; onde vermillon au sol.
func toupie(pos: Vector3, r: float) -> void:
	swirl(pos, r)
	if not _rich(4.0):
		return
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.55, pos.z)
	node.rotation.y = randf() * TAU
	var rs := [_bramp(Color(INK, 0.9), 4), _bramp(BLADE, 5), _sramp("toupie_core", Color(1, 1, 1, 0.9), 6, true)]
	var n := 2 if Toon.lite else 3
	var lay := []
	for i in n:
		var arm := Node3D.new()
		node.add_child(arm)
		arm.rotation.y = TAU * float(i) / float(n)
		lay.append_array(_layers(arm, _cres_mesh(), rs))
	var ex := {"g": 0.22, "f": 0.55, "lay": lay, "spin": -17.0, "pu": 0.18}
	if main and is_instance_valid(main.hero) and not _warming:
		ex["fol"] = main.hero
		ex["off"] = Vector3(0, 0.55, 0)
	_anim(node, 0.75, Vector3.ONE * r * 0.45, Vector3.ONE * r * 0.9, ex)
	_shock(Vector3(pos.x, 0.07, pos.z), r * 0.9, Color(INK, 0.8), fig_ink("loop"), BLADE, false, 0.45)
	sparks(pos + Vector3(0, 0.6, 0), Vector3.UP, 3, BLADE, 4.0, 8.0, 90.0)
	_shake(0.08)


## Souffle de Fūjin (arrivée de ruée) : ondes jade au pinceau, croissants qui fusent tout autour, spirale.
func wind_burst(pos: Vector3, r: float) -> void:
	swirl(pos, r * 1.12)
	var g := Vector3(pos.x, 0.07, pos.z)
	if not _rich(4.0):
		ring(g, WIND, r)
		return
	_shock(g, r, Color(WIND_DEEP, 0.85), WIND, WIND_PALE, true, 0.42)
	if not Toon.lite:
		_shock(g + Vector3(0, 0.01, 0), r * 0.62, Color(WIND_DEEP, 0.7), WIND, WIND_PALE, true, 0.38, 0.08)
	var n := 3 if Toon.lite else 5
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		var d := Vector3(cos(a), 0, sin(a))
		_brush_crescent(pos + Vector3(0, 0.5, 0) + d * r * 0.25, d, 0.7, Color(WIND_DEEP, 0.85), WIND, WIND_PALE, 0.34, 0.0, d * r * 2.2)
	sparks(pos + Vector3(0, 0.5, 0), Vector3.UP, 3, WIND_PALE, 4.0, 8.0, 90.0)
	_shake(0.08)


# ------------------------------------------------------------------ ombre (影) : fumée violette, estoc

func _smoke_res() -> void:
	if _smoke_ramp != null:
		return
	_smoke_ramp = Gradient.new()
	_smoke_ramp.set_color(0, Color(0.6, 0.38, 0.92, 0.85))
	_smoke_ramp.set_color(1, Color(0.08, 0.05, 0.12, 0.0))
	_smoke_ramp.add_point(0.45, Color(0.2, 0.12, 0.3, 0.7))
	_smoke_curve = Curve.new()
	_smoke_curve.max_value = 2.0
	_smoke_curve.add_point(Vector2(0.0, 0.5))
	_smoke_curve.add_point(Vector2(1.0, 1.4))


## Bouffées de fumée violette et noire.
func smoke(pos: Vector3, r: float, amount := 6) -> void:
	_smoke_res()
	var p := CPUParticles3D.new()
	p.mesh = _ball()
	p.material_override = _mat("smoke_p", Color.WHITE, 2, true)
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(r, 0.05)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	p.scale_amount_curve = _smoke_curve
	p.color_ramp = _smoke_ramp
	p.position = pos + Vector3(0, 0.5, 0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 0.8, "kind": "none"})


## Estoc d'ombre : pique sombre liserée de violet de a vers b, bouffée de fumée au bout.
## hero (crochet, contre, mue) : fer de pinceau qui jaillit d'un coup (ink, corps violet, cœur lumineux),
## éclat violet et giclée d'encre à la pointe, silhouette d'ombre et fumée laissées au départ.
func shadow_stab(a: Vector3, b: Vector3, hero := false) -> void:
	var pa := a + Vector3(0, 0.8, 0)
	var pb := b + Vector3(0, 0.8, 0)
	var d := pb - pa
	d.y = 0.0
	var l := d.length()
	if hero and l > 0.05 and _rich(3.0):
		var dn := d / l
		var spear := Node3D.new()
		add_child(spear)
		spear.position = pa - dn * 0.3
		spear.rotation.y = atan2(-dn.x, -dn.z)
		var lay := _layers(spear, _streak_mesh(), [_bramp(Color(INK, 0.95), 4), _bramp(SHADOW, 5),
			_sramp("stab_core", Color(SHADOW_GLOW, 0.95), 6, true)])
		var ln := l + 0.6
		_anim(spear, 0.34, Vector3(1.8, 1.0, ln * 0.25), Vector3(1.0, 1.0, ln), {"g": 0.16, "f": 0.35, "lay": lay})
		_flare(pb, SHADOW_GLOW, 0.75, 0.14, 0.03)
		_ink_pop(pb, 0.55)
		sparks(pb, dn, 3, SHADOW, 5.0, 10.0, 35.0)
		if not Toon.lite:
			_ghost(a)
		smoke(a, 0.25, 3)
		smoke(b, 0.3, 5)
		_play("stab", randf_range(0.9, 1.1), -4.0)
		return
	var node := Node3D.new()
	add_child(node)
	node.transform = _seg_xform(pa, pb)
	var edge := _mi(node, _unit_box(), _mat("stab_edge", Color(SHADOW, 0.9), 5))
	edge.scale = Vector3(0.14, 0.14, 1.0)
	edge.position.z = -0.5
	var core := _mi(node, _unit_box(), _mat("stab_core", SHADOW_DARK, 6))
	core.scale = Vector3(0.06, 0.06, 1.02)
	core.position.z = -0.5
	_fx.append({"node": node, "t": 0.0, "life": 0.2, "kind": "stab"})
	smoke(b, 0.3, 5)
	if main:
		_play("stab", randf_range(0.9, 1.1), -4.0)


## Éclat d'ombre (instant volé, voile) : tache d'ombre au sol, onde violette au pinceau, fumée, éclat.
func shadow_burst(pos: Vector3, r: float) -> void:
	smoke(pos, 0.6, 7)
	var g := Vector3(pos.x, 0.06, pos.z)
	if not _rich(3.0):
		ring(g, SHADOW, r)
		return
	_decal(g, r * 0.55, Color(SHADOW_DARK, 0.6), 1.3)
	_shock(g + Vector3(0, 0.01, 0), r, Color(INK, 0.9), SHADOW, SHADOW_GLOW, true, 0.5)
	_flare(pos + Vector3(0, 0.8, 0), SHADOW_GLOW, 0.9, 0.16)
	_ink_pop(pos + Vector3(0, 0.8, 0), 0.7)
	_shake(0.08)


# ------------------------------------------------------------------ encre (墨) : onde, coupe

## Onde d'encre : anneau noir bordé de papier (lisible sur sol clair et sombre), gouttes d'encre.
## hero (ensō, onde de choc) : giclée d'encre au point d'impact, grand anneau d'ensō au pinceau bordé de papier
## et filet vermillon qui s'ouvre jusqu'à 1.5 r puis sèche, écho plus serré, éclaboussures en couronne au sol.
func ink_wave(pos: Vector3, r: float, hero := false) -> void:
	if main:
		main.splash(pos, INK, 10)
	_play("ink", randf_range(0.9, 1.1), -4.0)
	if not hero or not _rich(5.0):
		ring(Vector3(pos.x, 0.09, pos.z), INK, r)
		ring(Vector3(pos.x, 0.07, pos.z), Toon.WASHI, r * 1.08)
		return
	var g := Vector3(pos.x, 0.08, pos.z)
	_ink_pop(pos + Vector3(0, 0.6, 0), 0.9)
	_flare(pos + Vector3(0, 0.5, 0), Toon.VERMILION, 0.75, 0.12)
	_shock(g, r * 1.5, Color(Toon.WASHI, 0.9), INK, Toon.VERMILION, false, 0.8)
	if not Toon.lite:
		_shock(g + Vector3(0, 0.012, 0), r * 1.12, Color(INK, 0.55), Color(INK, 0.85), Color(INK, 0.9), false, 0.5, 0.08)
	_spatter(g, r * 1.5, INK, 1.3)
	if main:
		main.splash(pos, Toon.WASHI, 6)
	_shake(0.31)
	if r >= 1.3:
		_flash(0.08)


func _blade_mesh() -> ArrayMesh:
	if _meshes.has("blade"):
		return _meshes["blade"]
	var mesh := ArrayMesh.new()
	var widths := [0.17, 0.09]
	var mats := [_mat("iai_ink", Color(Toon.SUMI, 0.85), 5), _mat("iai_white", Color(1, 1, 1, 1), 6)]
	for s in 2:
		var w: float = widths[s]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# losange effilé de z = 0.5 à -0.5
		_quad(st, Vector3(0, 0, 0.5), Vector3(w, 0, 0.1), Vector3(0, 0, -0.5), Vector3(-w, 0, 0.1))
		st.commit(mesh)
		mesh.surface_set_material(s, mats[s])
	_meshes["blade"] = mesh
	return mesh


## Coupe d'iaï : long trait blanc cerné d'encre sur toute la ligne, qui s'affine et disparaît.
## hero (Ittō) : fil de lumière d'abord (anticipation), puis la lame tombe d'un coup très large et se resserre,
## s'attarde, et se fend en deux fils de pinceau qui s'écartent en séchant ; giclée d'encre au bout.
func slash_line(a: Vector3, b: Vector3, hero := false) -> void:
	var d := b - a
	d.y = 0
	var mid := (a + b) / 2.0 + Vector3(0, 0.6, 0)
	var ry := 0.0
	if d.length_squared() > 0.0001:
		ry = atan2(-d.x, -d.z)
	var l := d.length() + 1.0
	if main:
		main.splash(b, INK, 6)
	_play("iai", randf_range(0.95, 1.05), -3.0)
	if hero and _rich(4.0):
		var pre := Node3D.new()
		add_child(pre)
		pre.position = mid
		pre.rotation.y = ry
		var pr := _sramp("iai_pre", Color(1, 1, 1, 0.95), 7, true)
		var pm := _mi(pre, _blade_mesh(), pr[0])
		_anim(pre, 0.12, Vector3(0.12, 1.0, l * 0.5), Vector3(0.3, 1.0, l), {"g": 0.5, "f": 0.3, "lay": [[pm, -1, pr]]})
		var blade := Node3D.new()
		add_child(blade)
		blade.position = mid
		blade.rotation.y = ry
		_mi(blade, _blade_mesh(), null)
		_anim(blade, 0.5, Vector3(2.6, 1.0, l), Vector3(1.4, 1.0, l), {"t": -0.05, "g": 0.3, "sh": 0.4, "sm": Vector3(1.0, 0.0, 0.0)})
		var side := Vector3(-d.z, 0, d.x).normalized() if d.length_squared() > 0.0001 else Vector3.RIGHT
		# les deux fils qui s'écartent portent l'encre rouge du trait droit (FIG_INK « straight »)
		var hr := [_bramp(Color(INK, 0.85), 5), _bramp(fig_ink("straight"), 6), _sramp("iai_core", Color(1, 1, 1, 0.8), 7, true)]
		for sg: float in [-1.0, 1.0]:
			var half := Node3D.new()
			add_child(half)
			half.position = mid
			half.rotation.y = ry
			var lay := _layers(half, _line_mesh(), hr)
			_anim(half, 0.55, Vector3(1.0, 1.0, l), Vector3(1.0, 1.0, l * 1.04), {"t": -0.3, "f": 0.0, "lay": lay, "vel": side * sg * 0.6})
		sparks(mid, side, 3, BLADE, 4.0, 9.0, 40.0)
		_ink_pop(b + Vector3(0, 0.6, 0), 0.6)
		_flash(0.1)
		return
	var node := Node3D.new()
	add_child(node)
	node.position = mid
	node.rotation.y = ry
	var mi := _mi(node, _blade_mesh(), null)
	mi.scale = Vector3(1.3, 1, l)
	_fx.append({"node": node, "t": 0.0, "life": 0.3, "kind": "iai", "l": l})


## Garde (figure retour) : cercle au pinceau à l'encre de la figure (bleu) qui se referme sur le héros, éclat, traits.
func guard(pos: Vector3, r: float) -> void:
	var g := Vector3(pos.x, 0.07, pos.z)
	var fc := fig_ink("return")
	if not _rich(2.0):
		ring(g, fc, r)
		return
	var node := Node3D.new()
	add_child(node)
	node.position = g
	node.rotation.y = randf() * TAU
	var lay := _layers(node, _ring_mesh(), [_bramp(Color(INK, 0.85), 4), _bramp(fc, 5),
		_sramp("guard_core", Color(0.85, 0.93, 1.0, 0.9), 6, true)])
	_anim(node, 0.45, Vector3.ONE * r * 1.25, Vector3.ONE * r * 0.75, {"g": 0.45, "f": 0.5, "lay": lay, "spin": 4.0})
	_flare(pos + Vector3(0, 0.9, 0), fc.lightened(0.45), 0.8, 0.15)
	sparks(pos + Vector3(0, 0.8, 0), Vector3.UP, 3, fc.lightened(0.5), 3.0, 7.0, 90.0)


## Encre d'une figure (ink_stroke.gd FIG_INK), sumi par défaut.
func fig_ink(shape: String) -> Color:
	var c: Color = InkStroke.FIG_INK.get(shape, INK)
	return c


## Habille la grande vague de Kanagawa (balayage des pouvoirs) : crête principale à la Hokusai et deux
## crêtes d'appoint. Le nœud appartient à l'appelant (il le déplace, l'oriente vers -z et le libère).
func dress_wave(node: Node3D) -> void:
	var m := _curl_mat()
	var big := _mi(node, _curl_mesh(), m)
	big.scale = Vector3(2.8, 1.3, 1.25)
	for sg: float in [-1.0, 1.0]:
		var side := _mi(node, _curl_mesh(), m)
		side.scale = Vector3(1.3, 0.85, 0.9)
		side.position = Vector3(sg * 1.25, 0.0, 0.35)


# ------------------------------------------------------------------ pouvoirs récents : douze animations complètes
# Chaque effet a trois temps lisibles (apparition, tenue, disparition) et la palette de son école (UNIVERS §4) :
# feu vermillon/or, eau Prusse/écume, foudre or/écume, vent écume/washi, ombre sumi/or, encre sumi.
# Tout est en maillages procéduraux partagés, matériaux par rampes (rien d'alloué par image) ; les nœuds qui
# appartiennent à powers.gd (zones) sont habillés ici et suivis par un effet « keep » (jamais libérés d'ici).

const GOLD := Color("#F2C14E")  # or des éclairs et des sceaux de la foudre
const GOLD_DEEP := Color("#7A4E10")
const HANKO := Color("#9E3028")  # rouge-brun du tampon du peintre
const ASH_DARK := Color(0.22, 0.2, 0.22)
const ASH_PALE := Color(0.46, 0.44, 0.45)
const SEAL_ICON := {"loop": "figures/boucle", "zigzag": "figures/zigzag", "return": "figures/aller_retour",
	"straight": "figures/trait_droit", "enso": "figures/enso", "hook": "figures/crochet"}

var _static_fx := {}  # aura de charge en cours (Statique) : une seule à la fois
# capture des effets (`--q=fx=<id>[&fxshot=<dossier>]`) : l'effet est rejoué devant le héros ; captures à 0,1 / 0,3 / 0,6 / 1,0 s
var _dbg_fx := ""
var _dbg_dir := ""
var _dbg_t := 3.0
var _dbg_since := -1.0
var _dbg_shot := 0
var _dbg_shots: Array = [0.1, 0.3, 0.6, 1.0]


## Suivi d'un nœud (fol) : remet l'effet au-dessus de la cible à chaque image.
func _fol(ex: Dictionary, target: Node3D, off: Vector3) -> Dictionary:
	if target != null and is_instance_valid(target):
		ex["fol"] = target
		ex["off"] = off
	return ex


# --- Encre épaisse (Nōboku) : taches qui se déposent une à une

## Tache d'encre (plan XZ, rayon ~1) : 3 à 5 lobes, bord vivant ; surface 0 corps + gouttes satellites,
## surface 1 reflet humide (ovale décalé), surface 2 craquelures (fils qui partent du centre, montrées à la fin).
func _blot_mesh(v: int) -> ArrayMesh:
	var key := "blot%d" % v
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4451 + v * 97
	var mesh := ArrayMesh.new()
	var lobes := rng.randi_range(3, 5)
	var la := PackedFloat32Array()
	var lr := PackedFloat32Array()
	var lw := PackedFloat32Array()
	for i in lobes:
		la.append(TAU * float(i) / float(lobes) + rng.randf_range(-0.3, 0.3))
		lr.append(rng.randf_range(0.3, 0.55))
		lw.append(rng.randf_range(0.35, 0.7))
	var n := 44
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 0.52
		for j in lobes:
			var d := angle_difference(a, la[j])
			r += lr[j] * exp(-(d * d) / (lw[j] * lw[j]))
		r += 0.035 * sin(a * 9.0 + float(v)) + 0.02 * sin(a * 17.0)
		pts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for i in n:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[(i + 1) % n])
		st.add_vertex(pts[i])
	# gouttes satellites : au bout de deux lobes
	for k in 3:
		var j := k % lobes
		var a := la[j] + rng.randf_range(-0.15, 0.15)
		var d := 0.52 + lr[j] + rng.randf_range(0.12, 0.3)
		var s := rng.randf_range(0.05, 0.11)
		var c := Vector3(cos(a) * d, 0, sin(a) * d)
		for q in 7:
			var a0 := TAU * float(q) / 7.0
			var a1 := TAU * float(q + 1) / 7.0
			st.add_vertex(c)
			st.add_vertex(c + Vector3(cos(a1), 0, sin(a1)) * s)
			st.add_vertex(c + Vector3(cos(a0), 0, sin(a0)) * s)
	st.commit(mesh)
	# reflet humide : ovale décalé vers l'arrière-gauche (la lumière vient de face)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wc := Vector3(-0.14, 0.003, 0.1)
	for q in 12:
		var a0 := TAU * float(q) / 12.0
		var a1 := TAU * float(q + 1) / 12.0
		st2.add_vertex(wc)
		st2.add_vertex(wc + Vector3(cos(a1) * 0.26, 0, sin(a1) * 0.15))
		st2.add_vertex(wc + Vector3(cos(a0) * 0.26, 0, sin(a0) * 0.15))
	st2.commit(mesh)
	# craquelures : quatre fils brisés du centre vers le bord
	var st3 := SurfaceTool.new()
	st3.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a := TAU * float(k) / 4.0 + rng.randf_range(-0.4, 0.4)
		var p := Vector3(0, 0.004, 0)
		for seg in 3:
			var a2 := a + rng.randf_range(-0.5, 0.5)
			var q := p + Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(0.18, 0.3)
			var side := Vector3(-sin(a2), 0, cos(a2)) * (0.016 - 0.004 * float(seg))
			_quad(st3, p - side, p + side, q + side, q - side)
			p = q
	st3.commit(mesh)
	_meshes[key] = mesh
	return mesh


## Tache d'encre au sol en `g` (rayon r), vie `life` s, posée après `delay` s : s'étale depuis le centre en 0,25 s,
## brille humide puis sèche (mat), se craquèle et s'évapore sur les 0,4 dernières secondes.
## sc : étirement (traces de pas) ; dir : orientation ; game : vie en temps du jeu (tache d'une zone de powers).
func blot(g: Vector3, r: float, life: float, delay := 0.0, sc := Vector3.ONE, dir := Vector3.ZERO, game := false) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(g.x, 0.05, g.z)
	node.rotation.y = randf() * TAU if dir.length_squared() < 0.001 else atan2(-dir.x, -dir.z)
	node.visible = delay <= 0.0
	var mi := _mi(node, _blot_mesh(randi() % 4), null)
	var rb := _sramp("blot_body", Color(Toon.SUMI, 0.82), -4)
	var rw := _sramp("blot_wet", Color(0.56, 0.58, 0.66, 0.6), -3)
	var rc := _sramp("blot_crack", Color(Toon.WASHI, 0.85), -3)
	mi.set_surface_override_material(0, rb[0])
	mi.set_surface_override_material(1, rw[0])
	mi.set_surface_override_material(2, rc[FADE_N - 1])
	node.scale = _safe_scale(sc * r * 0.1)
	_fx.append({"node": node, "t": 0.0, "life": life + delay, "kind": "blot", "d": delay, "r": r, "sc": sc, "mi": mi,
		"rb": rb, "rw": rw, "rc": rc, "ib": 0, "iw": 0, "ic": FADE_N - 1})
	if game:
		_fx[_fx.size() - 1]["game"] = true
	if delay <= 0.0 and not _warming:
		_play("ink", randf_range(1.1, 1.3), -12.0)


func _blot_step(fx: Dictionary, node: Node3D, dt: float) -> void:
	var u := float(fx["t"]) - float(fx["d"])
	if u < 0.0:
		return
	if not node.visible:
		node.visible = true
		_play("ink", randf_range(1.1, 1.3), -12.0)
	var r: float = fx["r"]
	var sc: Vector3 = fx["sc"]
	var mi: MeshInstance3D = fx["mi"]
	# étalement : le centre d'abord, les lobes suivent (ease-out), léger surplus puis la tache se pose
	var ks := UiKit.ease_out(minf(u / 0.25, 1.0))
	var grow := 0.18 + 0.82 * ks + 0.06 * sin(minf(u / 0.25, 1.0) * PI)
	var left := float(fx["life"]) - float(fx["t"])
	var q := 0.0
	if left < 0.4:
		q = 1.0 - clampf(left / 0.4, 0.0, 1.0)
	node.scale = _safe_scale(sc * r * grow * (1.0 - 0.12 * q))
	# reflet humide : plein à la pose, séché après 0,8 s
	var iw := clampi(int(clampf(u / 0.8, 0.0, 1.0) * float(FADE_N - 1)), 0, FADE_N - 1)
	if iw != int(fx["iw"]):
		fx["iw"] = iw
		mi.set_surface_override_material(1, fx["rw"][iw])
	if q > 0.0:
		# fin : les craquelures paraissent puis tout s'évapore
		var ib := clampi(int(q * float(FADE_N)), 0, FADE_N - 1)
		if ib != int(fx["ib"]):
			fx["ib"] = ib
			mi.set_surface_override_material(0, fx["rb"][ib])
		var ic := clampi(int(absf(q * 2.0 - 1.0) * float(FADE_N - 1)), 0, FADE_N - 1)
		if ic != int(fx["ic"]):
			fx["ic"] = ic
			mi.set_surface_override_material(2, fx["rc"][ic])


## Trace de pas d'encre d'un ennemi englué : petite tache étirée dans le sens de la marche, décalée à gauche
## ou à droite (side ±1).
func ink_step(pos: Vector3, dir: Vector3, side: float) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	d = d.normalized()
	var perp := Vector3(-d.z, 0, d.x) * 0.13 * side
	blot(pos + perp, 0.17, 1.3, 0.0, Vector3(0.7, 1.0, 1.25), d)


# --- Statique (Seidenki) : charge visible, puis la nova

## Arcs courts qui crépitent sur `target` : `level` paliers (1, 2, 3 : plus denses), pendant `life` s.
## Une seule aura par cible : la précédente s'éteint.
func static_charge(target: Node3D, level: int, life := 2.2) -> void:
	if target == null or not is_instance_valid(target):
		return
	# auras éteintes (cibles mortes, paratonnerre sans Statique : rien ne vidait la table) : on les oublie
	for key in _static_fx.keys():
		if not is_instance_valid(_static_fx[key].get("node")):
			_static_fx.erase(key)
	var old = _static_fx.get(target.get_instance_id())
	if old != null and is_instance_valid(old.get("node")):
		old["life"] = minf(float(old["life"]), float(old["t"]) + 0.05)
	var node := Node3D.new()
	add_child(node)
	node.position = target.position + Vector3(0, 0.9, 0)
	var n := clampi(1 + level, 2, 6)
	if Toon.lite:
		n = maxi(2, n - 1)
	var arcs := []
	for i in n:
		var mi := _mi(node, _bolt_mesh(1, i % 3), null)
		_bolt_gold(mi)
		mi.scale = Vector3(1.1, 1.1, 1.0 + 0.25 * float(i % 3))
		arcs.append(mi)
	# anneau d'or au sol, plus large et plus franc à chaque palier
	var ring := Node3D.new()
	node.add_child(ring)
	ring.position.y = -0.83
	var lv := clampf(float(level) / 4.0, 0.25, 1.0)
	_layers(ring, _ring_mesh(), [_bramp(Color(Toon.SUMI, 0.35 + 0.3 * lv), -3), _bramp(Color(GOLD, 0.5 + 0.45 * lv), -2), _sramp("charge_core", Color(Toon.WASHI, 0.5 + 0.4 * lv), -1, true)])
	ring.scale = Vector3.ONE * (0.55 + 0.3 * float(level))
	# étincelles d'or qui montent du corps, de plus en plus denses
	var p := CPUParticles3D.new()
	p.mesh = _drop_mesh("streak_p", 0.035, 0.42)
	p.material_override = glow_mat(GOLD, 3.0)
	p.amount = 2 + 2 * level
	p.lifetime = 0.45
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -4.0, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	p.scale_amount_curve = _drop_shrink()
	node.add_child(p)
	p.emitting = true
	var fx := {"node": node, "t": 0.0, "life": life, "kind": "crackle", "arcs": arcs, "tick": 0.0, "lvl": level,
		"fol": target, "off": Vector3(0, 0.9, 0), "ring": ring, "emit": p}
	_fx.append(fx)
	_static_fx[target.get_instance_id()] = fx
	_crackle_place(fx)
	_flare(node.position, GOLD, 0.45 + 0.2 * float(level), 0.12)
	sparks(node.position, Vector3.UP, 2 + level, GOLD, 3.0, 6.0, 90.0)
	_play("zap", 0.7 + 0.18 * float(level), -11.0 + float(level))


## Teinte un éclair en or / écume (surfaces 0 encre, 1 corps, 2 cœur).
func _bolt_gold(mi: MeshInstance3D) -> void:
	mi.set_surface_override_material(0, _mat("gbolt_ink", Color(Toon.SUMI, 0.6), 5))
	mi.set_surface_override_material(1, _mat("gbolt_body", GOLD, 6))
	mi.set_surface_override_material(2, _mat("gbolt_core", Toon.WASHI, 7))


## Repose les arcs de l'aura au hasard autour du corps (tangents à un cylindre de rayon 0,38).
func _crackle_place(fx: Dictionary) -> void:
	var arcs: Array = fx["arcs"]
	for a in arcs:
		var mi: MeshInstance3D = a
		var ang := randf() * TAU
		var h := randf_range(-0.5, 0.6)
		mi.position = Vector3(cos(ang) * 0.48, h, sin(ang) * 0.48)
		mi.rotation = Vector3(randf_range(-0.6, 0.6), ang + PI / 2.0 + randf_range(-0.5, 0.5), 0.0)
		mi.visible = randf() < 0.8
		mi.mesh = _bolt_mesh(1, randi() % 3)


func _crackle_step(fx: Dictionary, node: Node3D, k: float, dt: float) -> void:
	var fo = fx.get("fol")
	if fo != null and is_instance_valid(fo):
		var off: Vector3 = fx["off"]
		node.position = fo.position + off
	fx["tick"] = float(fx["tick"]) - dt
	# l'anneau au sol tourne et palpite ; en fin de vie il se referme et les étincelles cessent
	var ring = fx.get("ring")
	if ring != null and is_instance_valid(ring):
		var rn: Node3D = ring
		rn.rotation.y += dt * 1.5
		var lvl: int = fx["lvl"]
		var gone := clampf((1.0 - k) / 0.2, 0.0, 1.0)
		rn.scale = Vector3.ONE * (0.55 + 0.3 * float(lvl)) * (1.0 + 0.05 * sin(float(fx["t"]) * 14.0)) * maxf(gone, 0.01)
		if k > 0.8:
			var em = fx.get("emit")
			if em != null and is_instance_valid(em):
				(em as CPUParticles3D).emitting = false
	if float(fx["tick"]) <= 0.0:
		fx["tick"] = 0.06 + 0.02 * randf()
		_crackle_place(fx)
		# en fin de vie, de moins en moins d'arcs allumés
		if k > 0.75:
			var arcs: Array = fx["arcs"]
			for a in arcs:
				if randf() < (k - 0.75) * 4.0:
					(a as MeshInstance3D).visible = false


## Anneau d'éclairs brisés (rayon 1, plan XZ) : zigzag qui fait le tour, huit pointes radiales.
## Trois surfaces au pinceau (contour, corps, cœur) comme _ring_mesh.
func _nova_mesh() -> ArrayMesh:
	if _meshes.has("nova"):
		return _meshes["nova"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var mesh := ArrayMesh.new()
	var widths := [[0.11, 0.045, 0.018], [-0.11, -0.045, -0.018]]
	var n := 40
	var ring := PackedVector3Array()
	var rn := PackedVector3Array()
	for i in n + 1:
		var a := TAU * float(i % n) / float(n)
		var rr := 1.0 + (0.07 if i % 2 == 0 else -0.07) + rng.randf_range(-0.02, 0.02)
		var d := Vector3(cos(a), 0, sin(a))
		ring.append(d * rr)
		rn.append(d)
	var spikes := []
	for s in 8:
		var a := TAU * float(s) / 8.0 + rng.randf_range(-0.12, 0.12)
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x)
		var c := PackedVector3Array()
		var nn := PackedVector3Array()
		var steps := 4
		for i in steps + 1:
			var u := float(i) / float(steps)
			var zig := 0.0 if (i == 0 or i == steps) else (0.07 if i % 2 == 0 else -0.07)
			c.append(d * (0.95 + u * rng.randf_range(0.42, 0.6)) + side * zig)
			nn.append(side)
		spikes.append([c, nn])
	for li in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w: float = widths[0][li]
		var wo := PackedFloat32Array()
		var wi := PackedFloat32Array()
		for i in n + 1:
			wo.append(w)
			wi.append(-w)
		_strip(st, ring, rn, wo, wi, 0.004 * float(li), 16.0)
		for sp in spikes:
			var c: PackedVector3Array = sp[0]
			var so := PackedFloat32Array()
			var si := PackedFloat32Array()
			for i in c.size():
				var taper := 1.0 - 0.7 * float(i) / float(c.size() - 1)
				so.append(w * taper)
				si.append(-w * taper)
			_strip(st, c, sp[1], so, si, 0.004 * float(li), 2.0)
		st.commit(mesh)
	_meshes["nova"] = mesh
	return mesh


## Nova de Statique en `pos` (rayon r) : flash blanc deux images, anneau d'éclairs brisés or / écume qui s'étend
## en 0,3 s, ondulation du sol, gerbe d'étincelles d'or ; les éclairs vers les cibles viennent de bolt(…, gold).
func static_nova(pos: Vector3, r: float) -> void:
	var hid = _static_fx.keys()
	for key in hid:
		var old = _static_fx[key]
		if old != null and is_instance_valid(old.get("node")):
			old["life"] = minf(float(old["life"]), float(old["t"]) + 0.03)
	_static_fx.clear()
	var g := Vector3(pos.x, 0.07, pos.z)
	var p := pos + Vector3(0, 0.9, 0)
	_flash(0.3)
	_flare(p, Toon.WASHI, 1.7, 0.14)
	_flare(p, GOLD, 1.1, 0.22, 0.05)
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.55, pos.z)
	node.rotation.y = randf() * TAU
	var lay := _layers(node, _nova_mesh(), [_bramp(Color(Toon.SUMI, 0.7), 4), _bramp(GOLD, 5),
		_sramp("nova_core", Color(Toon.WASHI, 0.95), 6, true)])
	_anim(node, 0.6, Vector3.ONE * r * 0.2, Vector3.ONE * r, {"g": 0.5, "f": 0.45, "lay": lay, "spin": 1.6})
	if not Toon.lite:
		# second anneau plus serré, en retard d'une image
		var node2 := Node3D.new()
		add_child(node2)
		node2.position = Vector3(pos.x, 0.9, pos.z)
		node2.rotation.y = randf() * TAU
		var lay2 := _layers(node2, _nova_mesh(), [_bramp(Color(Toon.SUMI, 0.5), 4), _bramp(Color(GOLD, 0.8), 5),
			_sramp("nova_core", Color(Toon.WASHI, 0.95), 6, true)])
		_anim(node2, 0.42, Vector3.ONE * r * 0.15, Vector3.ONE * r * 0.7, {"g": 0.6, "f": 0.4, "lay": lay2, "spin": -2.2, "t": -0.04})
	_shock(g, r * 1.15, Color(Toon.SUMI, 0.8), GOLD, Toon.WASHI, true, 0.7)
	_shock(g + Vector3(0, 0.01, 0), r * 0.7, Color(Toon.SUMI, 0.6), Color(GOLD, 0.8), Toon.WASHI, true, 0.6, 0.08)
	sparks(p, Vector3.UP, 8 if Toon.lite else 14, GOLD, 5.0, 11.0, 80.0)
	sparks(p, Vector3.UP, 4, Toon.WASHI, 4.0, 8.0, 90.0)
	_shake(0.31)
	_play("thunder", 1.35, -4.0)
	_play("zap", 0.8, -3.0)


# --- Cendres (Hai) : tas qui retombe, braises qui pulsent, fumée fine

## Tas de cendres (plan XZ, rayon ~1) : dôme bas au bord déchiqueté (surface 0), coiffe plus pâle (surface 1).
func _heap_mesh() -> ArrayMesh:
	if _meshes.has("heap"):
		return _meshes["heap"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	var mesh := ArrayMesh.new()
	var n := 26
	for s in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := Vector3(0.05, 0.16 if s == 0 else 0.19, -0.04)
		var rad := 1.0 if s == 0 else 0.55
		var pts := PackedVector3Array()
		for i in n:
			var a := TAU * float(i) / float(n)
			var r := rad * rng.randf_range(0.8, 1.0) * (1.0 + 0.12 * sin(a * 5.0 + float(s)))
			pts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		for i in n:
			st.add_vertex(top)
			st.add_vertex(pts[(i + 1) % n])
			st.add_vertex(pts[i])
		st.commit(mesh)
	_meshes["heap"] = mesh
	return mesh


## Flocon de cendre (petit quad face caméra par le matériau des particules).
func _flake_mesh() -> Mesh:
	if not _meshes.has("flake"):
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.07)
		_meshes["flake"] = q
	return _meshes["flake"]


## Habille `node` (zone de powers) en tas de cendres de rayon r pendant `dur` s : le tas se dépose, les flocons
## retombent lentement, quatre braises pulsent en vermillon, un fil de fumée grise monte. Le nœud reste à powers.
func ash_pile(node: Node3D, r: float, dur: float) -> void:
	var heap := _mi(node, _heap_mesh(), null, 0.03)
	heap.set_surface_override_material(0, _mat("ash_dark", ASH_DARK, -2))
	heap.set_surface_override_material(1, _mat("ash_pale", ASH_PALE, -1))
	heap.scale = Vector3(r * 0.85, 1.0, r * 0.7)
	heap.rotation.y = randf() * TAU
	_anim(heap, 0.5, Vector3(r * 0.35, 1.6, r * 0.3), Vector3(r * 0.85, 1.0, r * 0.7), {"g": 0.7, "keep": true})
	_decal(node.position, r * 0.9, Color(0.16, 0.12, 0.12, 0.45), minf(dur, 1.3))
	var embers := []
	var em := _mat("ember_disc", Color(Toon.VERMILION, 0.95), 0)
	for i in 4:
		var a := TAU * float(i) / 4.0 + randf_range(-0.4, 0.4)
		var d := r * randf_range(0.15, 0.45)
		var e := _mi(node, _unit_disc(), em, 0.2 if d < r * 0.3 else 0.12)
		e.position.x = cos(a) * d
		e.position.z = sin(a) * d
		e.scale = Vector3.ONE * 0.08
		embers.append(e)
	var core := _mi(node, _unit_disc(), _mat("ember_core", Color(FIRE_HOT, 0.9), 1), 0.21)
	core.scale = Vector3.ONE * 0.06
	embers.append(core)
	# temps du jeu : la zone de powers compte en temps du jeu (ralentis, arrêts sur image) ; en temps réel les
	# braises s'éteignaient et la brume se dissipait alors que la zone agissait encore
	_fx.append({"node": node, "t": 0.0, "life": dur, "kind": "pulse", "keep": true, "items": embers, "ph": randf() * TAU, "game": true})
	# flocons : ils retombent du nuage de la mort, en tournant
	var p := _pooled("flake")
	var fresh := p == null
	if fresh:
		p = CPUParticles3D.new()
		p.set_meta("pool", "flake")
	p.mesh = _flake_mesh()
	p.material_override = _mat("flake_p", Color(0.3, 0.28, 0.3, 0.9), 2, false, 1)
	p.amount = 7 if Toon.lite else 12
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.5
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, -1.6, 0)
	p.damping_min = 0.8
	p.damping_max = 1.4
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _drop_shrink()
	p.position = node.position + Vector3(0, 1.1, 0)
	_emit(p, fresh)
	_fx.append({"node": p, "t": 0.0, "life": 1.3, "kind": "none"})
	# fumée fine et grise, continue
	_smoke_res()
	var sm := CPUParticles3D.new()
	sm.mesh = _ball()
	sm.material_override = _mat("ash_smoke_p", Color(0.5, 0.48, 0.5, 0.5), 2, true)
	sm.amount = 3 if Toon.lite else 5
	sm.lifetime = 1.4
	sm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = r * 0.25
	sm.direction = Vector3.UP
	sm.spread = 15.0
	sm.initial_velocity_min = 0.35
	sm.initial_velocity_max = 0.7
	sm.gravity = Vector3(0, 0.3, 0)
	sm.scale_amount_min = 0.18
	sm.scale_amount_max = 0.3
	sm.scale_amount_curve = _smoke_curve
	sm.color_ramp = _ash_smoke_ramp()
	sm.position = Vector3(0, 0.25, 0)
	node.add_child(sm)
	sm.emitting = true
	_fx.append({"node": sm, "t": 0.0, "life": dur + 1.5, "kind": "emit", "stop": maxf(dur - 0.6, 0.1), "keep": true, "game": true})
	embers_pop(node.position, r * 0.5, 5)


func _ash_smoke_ramp() -> Gradient:
	if not _ramps.has("ash_smoke"):
		var g := Gradient.new()
		g.set_color(0, Color(0.42, 0.4, 0.42, 0.0))
		g.set_color(1, Color(0.55, 0.53, 0.55, 0.0))
		g.add_point(0.25, Color(0.46, 0.44, 0.46, 0.55))
		_ramps["ash_smoke"] = g
	return _ramps["ash_smoke"]


## Braises (vermillon) et quelques traits chauds : réutilise embers() avec la couleur du feu.
func embers_pop(pos: Vector3, r: float, n: int) -> void:
	embers(pos, r, n, 0.9)


## Bouffée quand un ennemi traverse les cendres : braises qui giclent, langues de flamme, il s'enflamme.
func ash_puff(pos: Vector3) -> void:
	embers(pos, 0.35, 5 if Toon.lite else 8, 0.9)
	flames(pos, 0.3, 5)
	sparks(pos + Vector3(0, 0.4, 0), Vector3.UP, 3, FIRE_HOT, 3.0, 7.0, 70.0)
	_flare(pos + Vector3(0, 0.5, 0), Toon.VERMILION, 0.55, 0.12)
	_play("crackle", randf_range(1.0, 1.2), -7.0)


func _pulse_step(fx: Dictionary, k: float) -> void:
	var items: Array = fx["items"]
	var t := float(fx["t"]) * 6.0 + float(fx["ph"])
	var fade := clampf((1.0 - k) * 4.0, 0.0, 1.0)  # les braises s'éteignent sur le dernier quart
	for i in items.size():
		var e: MeshInstance3D = items[i]
		if not is_instance_valid(e):
			continue
		var s := (0.11 + 0.05 * sin(t + float(i) * 1.7)) * fade
		if i == items.size() - 1:
			s *= 0.7
		e.scale = Vector3(s, 1.0, s)
		e.visible = s > 0.005


# --- Lanterne (Chōchin) : la lueur gonfle, puis la gerbe

## Lueur de lanterne sur `target` : halo or qui respire, de plus en plus vite et plus large, pendant `dur` s.
func lantern_glow(target: Node3D, dur: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var node := Node3D.new()
	add_child(node)
	node.position = target.position + Vector3(0, 1.0, 0)
	var halo := _mi(node, _disc_xy(), _mat("lant_halo", Color(GOLD, 0.6), 3, true, 2, true))
	halo.scale = Vector3.ONE * 0.6
	var core := _mi(node, _tongue(), flame_mat(FIRE_HOT))
	core.scale = Vector3.ONE * 1.3
	core.position.y = 0.1
	var rim := _mi(node, _ring_mesh(), _mat("lant_rim", Color(Toon.VERMILION, 0.9), 4))
	rim.scale = Vector3.ONE * 0.5
	# temps du jeu, comme l'attente de powers (_lantern_wait) : la lueur ne s'éteint pas avant la gerbe au ralenti
	_fx.append({"node": node, "t": 0.0, "life": dur, "kind": "breathe", "fol": target, "off": Vector3(0, 1.0, 0),
		"halo": halo, "core": core, "rim": rim, "game": true})
	_play("fire", 1.6, -12.0)


func _breathe_step(fx: Dictionary, node: Node3D, k: float, dt: float) -> void:
	var fo = fx.get("fol")
	if fo != null and is_instance_valid(fo):
		var off: Vector3 = fx["off"]
		node.position = fo.position + off
	var t := float(fx["t"])
	# respiration qui s'accélère (3 → 9 Hz) et s'amplifie ; le halo gonfle jusqu'au double
	var ph := t * (3.0 + 6.0 * k) * TAU
	var breath := 1.0 + (0.12 + 0.2 * k) * sin(ph)
	var halo: MeshInstance3D = fx["halo"]
	var core: MeshInstance3D = fx["core"]
	var rim: MeshInstance3D = fx["rim"]
	halo.scale = Vector3.ONE * (0.6 + 0.9 * k) * breath
	core.scale = Vector3.ONE * (1.2 + 0.8 * k) * (2.0 - breath)
	rim.scale = Vector3.ONE * (0.5 + 0.6 * k) * breath
	rim.rotation.y += dt * 2.5


## Gerbe de la lanterne en `pos` : colonne de flammes vermillon / or qui monte, éclats vers les voisins,
## onde de chaleur, braises.
func lantern_burst(pos: Vector3) -> void:
	var g := Vector3(pos.x, 0.07, pos.z)
	_flare(pos + Vector3(0, 0.9, 0), GOLD, 1.2, 0.16)
	var col := Node3D.new()
	add_child(col)
	col.position = Vector3(pos.x, 0.1, pos.z)
	var n := 4 if Toon.lite else 6
	for i in n:
		var hot := i % 2 == 0
		var f := _mi(col, _tongue(), flame_mat(FIRE_HOT if hot else Toon.VERMILION))
		var u := float(i) / float(n - 1)
		f.position = Vector3(randf_range(-0.12, 0.12), 0.25 + u * 1.7, randf_range(-0.12, 0.12))
		f.scale = Vector3.ONE * lerpf(3.0, 1.4, u) * (1.15 if hot else 1.0)
	_anim(col, 0.65, Vector3(0.7, 0.15, 0.7), Vector3.ONE, {"g": 0.35, "pu": 0.12, "sh": 0.5, "sm": Vector3(0.35, 1.0, 0.35), "up": 0.9})
	flames(pos, 0.5, 8)
	_shock(g, 1.6, Color(FIRE_DEEP, 0.85), Toon.VERMILION, GOLD, true, 0.45)
	embers(pos, 0.5, 6 if Toon.lite else 10, 1.2)
	# éclats vers les voisins : quatre traits horizontaux
	var a0 := randf() * TAU
	for i in 4:
		var a := a0 + TAU * float(i) / 4.0
		var d := Vector3(cos(a), 0, sin(a))
		_streak_line(pos + Vector3(0, 0.75, 0) + d * 0.3, d, 1.3, 0.6, Color(FIRE_DEEP, 0.7), Toon.VERMILION, GOLD, 0.3, 0.04 * float(i))
	sparks(pos + Vector3(0, 0.8, 0), Vector3.UP, 5, GOLD, 4.0, 9.0, 85.0)
	_decal(g, 0.7, Color(0.13, 0.06, 0.04, 0.5), 1.4)
	_shake(0.1)
	_play("fire", randf_range(0.85, 0.95), -3.0)
	_play("crackle", 1.0, -5.0)


# --- Brume (Kiri) : nappe de washi en volutes

## Volute de brume (plan XZ, rayon 1) : disque au bord ondulé, plein au centre, transparent au bord (couleurs de sommets).
func _puff_mesh() -> ArrayMesh:
	if _meshes.has("puff"):
		return _meshes["puff"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var pts := PackedVector3Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 1.0 + 0.12 * sin(a * 3.0) + 0.06 * sin(a * 7.0 + 1.0)
		pts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for i in n:
		st.set_color(Color(1, 1, 1, 1))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(pts[(i + 1) % n])
		st.add_vertex(pts[i])
	# second anneau intérieur plus dense (le cœur de la volute)
	for i in n:
		st.set_color(Color(1, 1, 1, 1))
		st.add_vertex(Vector3(0, 0.002, 0))
		st.set_color(Color(1, 1, 1, 0.25))
		st.add_vertex(pts[(i + 1) % n] * 0.55 + Vector3(0, 0.002, 0))
		st.add_vertex(pts[i] * 0.55 + Vector3(0, 0.002, 0))
	var mesh := st.commit()
	_meshes["puff"] = mesh
	return mesh


## Habille `node` (zone de powers) en nappe de brume de rayon r pendant `dur` s : volutes washi qui s'étalent
## en tournant à l'arrivée, respirent, puis se dissipent en bancs qui s'écartent. Le nœud reste à powers.
func mist(node: Node3D, r: float, dur: float) -> void:
	var rm := _sramp("mist_puff", Color(Toon.WASHI, 0.55), 2, false, 0)
	# le matériau des volutes module les couleurs de sommets (dégradé vers le bord)
	for m in rm:
		(m as StandardMaterial3D).vertex_color_use_as_albedo = true
	var items := []
	var n := 5 if Toon.lite else 8
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n) + randf_range(-0.3, 0.3)
		var d := r * (0.15 if i == 0 else randf_range(0.3, 0.62))
		var mi := _mi(node, _puff_mesh(), rm[0])
		var base := Vector3(cos(a) * d, randf_range(0.12, 0.7), sin(a) * d)
		mi.position = base
		mi.rotation.y = randf() * TAU
		var s := r * randf_range(0.5, 0.7) * (1.3 if i == 0 else 1.0)
		mi.scale = Vector3.ONE * 0.01
		items.append([mi, base, randf() * TAU, s, randf_range(0.4, 0.9) * (1.0 if i % 2 == 0 else -1.0)])
	_fx.append({"node": node, "t": 0.0, "life": dur, "kind": "mist", "keep": true, "items": items, "ramp": rm, "fi": 0, "r": r, "game": true})
	_shock(node.position + Vector3(0, 0.07, 0), r * 0.9, Color(WATER_DEEP, 0.6), Color(WATER_FOAM, 0.8), Toon.WASHI, false, 0.6)
	_flare(node.position + Vector3(0, 0.6, 0), Toon.WASHI, 0.9, 0.2)
	_play("gust", 0.7, -8.0)


func _mist_step(fx: Dictionary, k: float, dt: float) -> void:
	var items: Array = fx["items"]
	var t := float(fx["t"])
	var left := float(fx["life"]) - t
	var gone := 1.0 - clampf(left / 0.8, 0.0, 1.0)  # dissipation sur les 0,8 dernières secondes
	for i in items.size():
		var it: Array = items[i]
		var mi: MeshInstance3D = it[0]
		if not is_instance_valid(mi):
			continue
		var base: Vector3 = it[1]
		var ph: float = it[2]
		var s: float = it[3]
		var spin: float = it[4]
		var u := clampf((t - float(i) * 0.07) / 0.5, 0.0, 1.0)
		var appear := UiKit.ease_out(u)
		var breath := 1.0 + 0.08 * sin(t * 1.3 + ph)
		var sc := s * appear * breath * (1.0 + 0.35 * gone)
		mi.scale = Vector3(sc, 1.0, sc)
		mi.rotation.y += spin * dt
		# dérive lente en rond ; à la fin les bancs s'écartent du centre
		var drift := Vector3(sin(t * 0.5 + ph), 0, cos(t * 0.45 + ph)) * 0.18
		var out := Vector3(base.x, 0, base.z).normalized() * gone * 1.2
		mi.position = base + drift + out + Vector3(0, gone * 0.5, 0)
	var fi := clampi(int(gone * float(FADE_N)), 0, FADE_N - 1)
	if fi != int(fx["fi"]):
		fx["fi"] = fi
		var rm: Array = fx["ramp"]
		for it in items:
			var mi: MeshInstance3D = it[0]
			if is_instance_valid(mi):
				mi.material_override = rm[fi]


## Un tir entre dans la brume : il se dissout en gouttelettes d'écume.
func mist_pop(pos: Vector3) -> void:
	_pop(pos, WATER_FOAM, 0.6)
	ink_drops(pos, Vector3.UP, 6, WATER_FOAM)
	ink_drops(pos, Vector3.UP, 3, WATER)
	_play("splash", randf_range(1.5, 1.7), -12.0)


# --- Source (Izumi) : jaillissement et cœur

## Jet au pinceau de p le long de dir (longueur ln, largeur w) : se dresse puis retombe sur lui-même.
func _jet(p: Vector3, dir: Vector3, ln: float, w: float, life: float, delay := 0.0) -> void:
	var node := Node3D.new()
	add_child(node)
	var d := dir.normalized() if dir.length_squared() > 0.001 else Vector3.UP
	var xf := _seg_xform(p, p + d)
	node.transform = xf
	var lay := _layers(node, _streak_mesh(), [_bramp(Color(WATER_DEEP, 0.9), 4), _bramp(WATER, 5), _sramp("jet_core", Color(WATER_FOAM, 0.95), 6, true)])
	_anim(node, life, Vector3(w * 1.4, 1.0, ln * 0.15), Vector3(w, 1.0, ln), {"g": 0.3, "f": 0.5, "lay": lay, "t": -delay,
		"sh": 0.45, "sm": Vector3(0.0, 0.0, 1.0)})


## Source en `pos` : gerbe de jets Prusse / écume, gouttes qui retombent, anneaux d'ondes, le cœur monte vers la jauge.
func spring(pos: Vector3) -> void:
	var g := Vector3(pos.x, 0.05, pos.z)
	_flare(pos + Vector3(0, 0.5, 0), WATER_FOAM, 1.0, 0.14)
	var n := 4 if Toon.lite else 6
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		var d := Vector3(cos(a) * 0.32, 1.0, sin(a) * 0.32)
		_jet(g + Vector3(cos(a), 0, sin(a)) * 0.15, d, randf_range(2.0, 2.8), 0.8, 0.6, 0.03 * float(i))
	_jet(g, Vector3.UP, 3.2, 1.1, 0.65, 0.0)
	ink_drops(pos + Vector3(0, 1.4, 0), Vector3.UP, 8 if Toon.lite else 12, WATER)
	ink_drops(pos + Vector3(0, 1.6, 0), Vector3.UP, 6, WATER_FOAM)
	_shock(g, 1.3, Color(WATER_DEEP, 0.85), WATER, WATER_FOAM, true, 0.55)
	if not Toon.lite:
		_shock(g + Vector3(0, 0.01, 0), 1.9, Color(WATER_DEEP, 0.6), Color(WATER, 0.7), WATER_FOAM, true, 0.6, 0.15)
		_shock(g + Vector3(0, 0.02, 0), 0.8, Color(WATER_DEEP, 0.7), WATER, WATER_FOAM, true, 0.45, 0.3)
	_sprite_rise("effets/cur", Toon.VERMILION, pos + Vector3(0, 1.6, 0), 0.9, 0.009)
	if main:
		main.splash(pos, WATER_FOAM, 8)
	_play("splash", 1.05, -4.0)
	_play("coin", 1.2, -10.0)


## Pictogramme face caméra qui rebondit, monte et s'efface (cœur de la source, …).
func _sprite_rise(key: String, col: Color, pos: Vector3, life: float, px := 0.0095) -> void:
	var tex := UiKit.icon(key, 128.0, {"*": UIColors.hex(col)})
	if tex == null:
		return
	var l := Sprite3D.new()
	l.texture = tex
	l.pixel_size = px
	l.shaded = false
	l.render_priority = 3
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	_fx.append({"node": l, "t": 0.0, "life": life, "kind": "kanji"})


# --- Paratonnerre (Hiraishin) : tige d'or, la foudre tombe, cerné d'étincelles

## Tige d'or qui paraît au-dessus de `target` pendant `dur` s (elle appelle l'éclair).
func rod_mark(target: Node3D, dur: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var node := Node3D.new()
	add_child(node)
	node.position = target.position + Vector3(0, 2.4, 0)
	var rod := _mi(node, _unit_box(), _mat("rod_gold", GOLD, 5), 0.0)
	rod.scale = Vector3(0.09, 1.3, 0.09)
	var ink := _mi(node, _unit_box(), _mat("rod_ink", Color(Toon.SUMI, 0.8), 4), 0.0)
	ink.scale = Vector3(0.15, 1.38, 0.15)
	var tip := _mi(node, _ball(), _mat("rod_tip", Color(Toon.WASHI, 0.95), 6, false, 0, true), 0.7)
	tip.scale = Vector3.ONE * 0.26
	var rt := _sramp("rod_tipflare", Color(GOLD, 0.8), 7, true, 2)
	var fl := _mi(node, _star_mesh(), rt[0], 0.7)
	fl.scale = Vector3.ONE * 0.6
	# temps du jeu, comme l'attente de powers (_rod_wait)
	_anim(node, dur, Vector3(1.0, 0.1, 1.0), Vector3.ONE, _fol({"g": 0.35, "f": 0.6, "lay": [[fl, -1, rt]], "sh": 0.25,
		"sm": Vector3(1.0, 0.0, 1.0), "game": true}, target, Vector3(0, 2.4, 0)))
	_play("zap", 1.7, -12.0)


## La foudre d'or tombe sur `target` (ou en `pos`) : éclair du ciel or / écume, puis l'ennemi reste cerné
## d'étincelles 0,5 s.
func rod_strike(pos: Vector3, target: Node3D) -> void:
	sky_bolt(pos, false, true)
	if target != null and is_instance_valid(target):
		static_charge(target, 2, 0.5)


# --- Rafale (Shippū) : les tirs soufflés tournoient et laissent une traînée de vent

## Traînée accrochée au tir `bullet` soufflé vers dir : deux traits d'écume derrière, un croissant washi qui tournoie.
func gale_blow(bullet: Node3D, dir: Vector3) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	var node := Node3D.new()
	add_child(node)
	node.position = bullet.position
	node.rotation.y = atan2(-d.x, -d.z)
	var side := Vector3.RIGHT
	var lay := []
	var ink := Color(0.45, 0.52, 0.52, 0.7)
	for sg: float in [-1.0, 1.0]:
		var s := Node3D.new()
		node.add_child(s)
		s.position = side * sg * 0.3 + Vector3(0, 0, 0.5)
		s.scale = Vector3(0.9, 1.0, 2.0)
		lay.append_array(_layers(s, _streak_mesh(), [_bramp(ink, 4), _bramp(Toon.WASHI, 5), _sramp("gale_core", Color(1, 1, 1, 0.9), 6, true)]))
	var cres := Node3D.new()
	node.add_child(cres)
	lay.append_array(_layers(cres, _cres_mesh(), [_bramp(ink, 4), _bramp(Toon.WASHI, 5), _sramp("gale_core", Color(1, 1, 1, 0.9), 6, true)]))
	cres.scale = Vector3.ONE * 0.8
	_anim(node, 0.55, Vector3.ONE * 0.6, Vector3.ONE, {"g": 0.25, "f": 0.45, "lay": lay, "fol": bullet, "off": Vector3.ZERO})
	_anim(cres, 0.5, Vector3.ONE, Vector3.ONE, {"ns": true, "spin": 16.0, "keep": true})
	sparks(bullet.position, d, 2, Toon.WASHI, 3.0, 6.0, 40.0)
	_play("swish", randf_range(1.1, 1.3), -8.0)


# --- Vent arrière (Oikaze) : traits de vent dans le dos du héros

## Pendant `dur` s, des traits de vent écume / washi poussent `hero` dans le dos (sens dir), par deux salves.
func tailwind(hero: Node3D, dir: Vector3, dur: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	var ink := Color(0.45, 0.52, 0.52, 0.65)
	var ry := atan2(-d.x, -d.z)
	for salve in 2:
		var node := Node3D.new()
		add_child(node)
		node.position = hero.position
		node.rotation.y = ry
		var lay := []
		var n := 2 if Toon.lite else 3
		for i in n:
			var s := Node3D.new()
			node.add_child(s)
			var sx := (float(i) - float(n - 1) * 0.5) * 0.42
			s.position = Vector3(sx, 0.25 + 0.22 * float(i % 2), 1.0 + 0.4 * float(i))
			s.scale = Vector3(0.85, 1.0, 2.4 + 0.5 * float(i % 2))
			lay.append_array(_layers(s, _streak_mesh(), [_bramp(ink, 4), _bramp(Toon.WASHI, 5), _sramp("gale_core", Color(1, 1, 1, 0.9), 6, true)]))
		var cres := Node3D.new()
		node.add_child(cres)
		cres.position = Vector3(0, 0.6, 1.5)
		cres.scale = Vector3.ONE * 1.0
		lay.append_array(_layers(cres, _cres_mesh(), [_bramp(ink, 4), _bramp(Toon.WASHI, 5), _sramp("gale_core", Color(1, 1, 1, 0.9), 6, true)]))
		var life := dur * (0.65 if salve == 0 else 0.55)
		_anim(node, life, Vector3(0.7, 1.0, 0.5), Vector3.ONE, {"g": 0.3, "f": 0.45, "lay": lay, "fol": hero,
			"off": Vector3(0, 0.55, 0), "t": -(dur * 0.4 * float(salve))})
	_play("gust", 1.15, -6.0)


# --- Doublure (Kagemusha) : silhouette d'encre du ronin

## Silhouette plate du ronin (plan XY, pieds en y = 0, ~1,7 m) : tête, buste, jambes, écharpe, sabre.
## Surface 0 : encre ; surface 1 : fil d'or du tranchant.
func _ronin_mesh() -> ArrayMesh:
	if _meshes.has("ronin"):
		return _meshes["ronin"]
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# tête
	var hc := Vector3(0.0, 1.5, 0)
	for i in 14:
		var a0 := TAU * float(i) / 14.0
		var a1 := TAU * float(i + 1) / 14.0
		st.add_vertex(hc)
		st.add_vertex(hc + Vector3(cos(a0) * 0.19, sin(a0) * 0.21, 0))
		st.add_vertex(hc + Vector3(cos(a1) * 0.19, sin(a1) * 0.21, 0))
	# chignon
	_quad(st, Vector3(-0.05, 1.68, 0), Vector3(0.08, 1.74, 0), Vector3(0.11, 1.66, 0), Vector3(0.0, 1.62, 0))
	# cou et épaules, buste qui s'évase vers le bas (manches), ceinture
	_quad(st, Vector3(-0.07, 1.32, 0), Vector3(0.07, 1.32, 0), Vector3(0.06, 1.2, 0), Vector3(-0.06, 1.2, 0))
	_quad(st, Vector3(-0.36, 1.26, 0), Vector3(0.36, 1.26, 0), Vector3(0.42, 0.78, 0), Vector3(-0.42, 0.78, 0))
	_quad(st, Vector3(-0.3, 0.8, 0), Vector3(0.3, 0.8, 0), Vector3(0.33, 0.66, 0), Vector3(-0.33, 0.66, 0))
	# hakama : deux jambes évasées
	_quad(st, Vector3(-0.3, 0.68, 0), Vector3(-0.02, 0.68, 0), Vector3(-0.08, 0.0, 0), Vector3(-0.4, 0.0, 0))
	_quad(st, Vector3(0.02, 0.68, 0), Vector3(0.3, 0.68, 0), Vector3(0.4, 0.0, 0), Vector3(0.1, 0.0, 0))
	# écharpe : pan qui flotte vers la droite
	var sc := [Vector3(0.05, 1.3, 0), Vector3(0.3, 1.36, 0), Vector3(0.55, 1.28, 0), Vector3(0.78, 1.34, 0), Vector3(0.95, 1.22, 0)]
	for i in sc.size() - 1:
		var w0 := 0.07 - 0.012 * float(i)
		var w1 := 0.07 - 0.012 * float(i + 1)
		var a: Vector3 = sc[i]
		var b: Vector3 = sc[i + 1]
		_quad(st, a + Vector3(0, w0, 0), b + Vector3(0, w1, 0), b - Vector3(0, w1, 0), a - Vector3(0, w0, 0))
	# sabre : lame tendue en diagonale vers la gauche
	var h0 := Vector3(-0.38, 0.95, 0)
	var h1 := Vector3(-1.05, 1.42, 0)
	var sd := (h1 - h0).normalized()
	var sp := Vector3(-sd.y, sd.x, 0)
	_quad(st, h0 + sp * 0.035, h1 + sp * 0.012, h1 - sp * 0.012, h0 - sp * 0.035)
	# poignée
	_quad(st, h0 + sp * 0.05, h0 - sd * 0.22 + sp * 0.05, h0 - sd * 0.22 - sp * 0.05, h0 - sp * 0.05)
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st2, h0 + sp * 0.04 + Vector3(0, 0, 0.004), h1 + sp * 0.016 + Vector3(0, 0, 0.004), h1 + sp * 0.0 + Vector3(0, 0, 0.004), h0 + sp * 0.02 + Vector3(0, 0, 0.004))
	st2.commit(mesh)
	_meshes["ronin"] = mesh
	return mesh


## Habille `node` (zone de powers) en doublure : silhouette d'encre translucide du ronin, face caméra, qui ondule
## comme un lavis dans l'eau pendant `dur` s ; flaque d'encre aux pieds. Le nœud reste à powers.
func double_dress(node: Node3D, dur: float) -> void:
	var mi := _mi(node, _ronin_mesh(), null, 0.0)
	mi.set_surface_override_material(0, _mat("ronin_ink", Color(Toon.SUMI, 0.6), 2, false, 2))
	mi.set_surface_override_material(1, _mat("ronin_gold", Color(GOLD, 0.95), 3, false, 2, true))
	mi.scale = Vector3.ONE * 0.01
	_fx.append({"node": node, "t": 0.0, "life": dur, "kind": "wobble", "keep": true, "mi": mi, "ph": randf() * TAU, "game": true})
	spawn_ink(node.position, 0.5)
	_ink_pop(node.position + Vector3(0, 0.9, 0), 0.6)
	_play("ink", 0.85, -8.0)


func _wobble_step(fx: Dictionary, k: float) -> void:
	var mi: MeshInstance3D = fx["mi"]
	if not is_instance_valid(mi):
		return
	var t := float(fx["t"])
	var ph: float = fx["ph"]
	var appear := UiKit.ease_out(minf(t / 0.3, 1.0))
	var gone := clampf((1.0 - k) / 0.25, 0.0, 1.0)  # fin : la silhouette s'étire vers le haut et s'efface
	var sx := (1.0 + 0.06 * sin(t * 4.3 + ph)) * appear * (0.6 + 0.4 * gone)
	var sy := (1.0 + 0.04 * sin(t * 3.1 + ph + 1.0)) * appear * (1.0 + 0.6 * (1.0 - gone))
	mi.scale = Vector3(sx, sy, 1.0)
	mi.rotation.z = 0.06 * sin(t * 2.7 + ph)
	mi.position.y = 0.03 * sin(t * 2.0 + ph) + (1.0 - gone) * 0.5
	mi.visible = gone > 0.02


## La doublure frappe : trait de sabre d'encre de a vers b (croissant sumi au fil d'or), giclée au bout.
func double_strike(a: Vector3, b: Vector3) -> void:
	var d := b - a
	d.y = 0
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	var l := d.length()
	d = d.normalized()
	var p := a + Vector3(0, 0.85, 0)
	_brush_crescent(p + d * 0.5, d, 1.1, Color(Toon.SUMI, 0.95), Toon.SUMI, GOLD, 0.34, 11.0, d * l * 1.6)
	_streak_line(p, d, l + 0.4, 0.8, Color(Toon.SUMI, 0.9), Color(Toon.SUMI, 0.85), GOLD, 0.3)
	_ink_pop(b + Vector3(0, 0.8, 0), 0.6)
	ink_drops(b + Vector3(0, 0.8, 0), d, 6, INK)
	_flare(b + Vector3(0, 0.8, 0), GOLD, 0.6, 0.12, 0.05)
	_play("iai", randf_range(0.9, 1.1), -6.0)


# --- Pas d'ombre (Kage-ashi) : l'arrivée est couverte

## Bouffée d'ombre aux pieds à l'arrivée : silhouette d'ombre qui se dissipe, flaque d'encre, fumée sumi / or.
func shadow_step(pos: Vector3) -> void:
	smoke(pos, 0.3, 4)
	if not _rich(1.5):
		return
	_ghost(pos)
	spawn_ink(pos, 0.45)
	_flare(pos + Vector3(0, 0.3, 0), GOLD, 0.5, 0.12)
	_play("puff", 1.1, -9.0)


# --- Crépuscule (Tasogare) : croissant de lune d'encre

## Croissant de lune (plan XY, rayon 1, ouvert vers +x) : corps d'encre (surface 0), fil d'or au bord (surface 1).
func _moon_mesh() -> ArrayMesh:
	if _meshes.has("moon"):
		return _meshes["moon"]
	var mesh := ArrayMesh.new()
	var n := 18
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	for i in n + 1:
		var a := lerpf(0.55, TAU - 0.55, float(i) / float(n))
		outer.append(Vector3(cos(a), sin(a), 0))
		# bord intérieur : cercle décalé vers +x, qui rejoint les pointes
		var u := float(i) / float(n)
		var pinch := sin(PI * u)
		inner.append(Vector3(cos(a) * (1.0 - 0.55 * pinch) + 0.3 * pinch, sin(a) * (1.0 - 0.5 * pinch), 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		_quad(st, outer[i], outer[i + 1], inner[i + 1], inner[i])
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		_quad(st2, outer[i] * 1.0 + Vector3(0, 0, 0.004), outer[i + 1] + Vector3(0, 0, 0.004),
			outer[i + 1] * 0.94 + Vector3(0, 0, 0.004), outer[i] * 0.94 + Vector3(0, 0, 0.004))
	st2.commit(mesh)
	_meshes["moon"] = mesh
	return mesh


## Premier coup critique sur un ennemi : un croissant de lune d'encre passe sur lui, fil d'or, fumée d'encre.
func dusk_crit(pos: Vector3) -> void:
	var p := pos + Vector3(0, 1.15, 0)
	var node := Node3D.new()
	add_child(node)
	node.position = p + Vector3(-0.7, -0.15, 0)
	var mi := _mi(node, _moon_mesh(), null)
	var rb := _sramp("moon_ink", Color(Toon.SUMI, 0.92), 5, false, 2)
	var rg := _sramp("moon_gold", Color(GOLD, 0.95), 6, true, 2)
	mi.set_surface_override_material(0, rb[0])
	mi.set_surface_override_material(1, rg[0])
	_anim(node, 0.5, Vector3.ONE * 0.45, Vector3.ONE * 0.95, {"g": 0.3, "f": 0.45, "lay": [[mi, 0, rb], [mi, 1, rg]],
		"vel": Vector3(1.4, 0.3, 0)})
	_flare(p, GOLD, 0.7, 0.12, 0.08)
	ink_drops(p, Vector3.UP, 5, INK)
	_play("puff", 1.3, -8.0)


# --- Sceau (Hanko) : les figures s'inscrivent, le tampon claque

## Cercle au sol qui suit `hero` : anneau d'encre pâle au pinceau ; les glyphes s'y inscrivent (seal_add).
func seal_ring(hero: Node3D) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.position = hero.position + Vector3(0, 0.06, 0)
	var ring := Node3D.new()
	node.add_child(ring)
	var lay := _layers(ring, _ring_mesh(), [_bramp(Color(Toon.SUMI, 0.55), -3), _bramp(Color(HANKO, 0.5), -2), _sramp("seal_core", Color(Toon.WASHI, 0.6), -1)])
	ring.scale = Vector3.ONE * 1.15
	_anim(ring, 0.5, Vector3.ONE * 0.4, Vector3.ONE * 1.15, {"g": 0.6, "keep": true, "spin": 0.5})
	# suivi du héros : gardé par powers (_seal_ring) jusqu'au tampon (seal_stamp le libère) ou au combat suivant
	var ffx := _anim(node, 9999.0, Vector3.ONE, Vector3.ONE, _fol({"ns": true, "keep": true}, hero, Vector3(0, 0.06, 0)))
	node.set_meta("ring", ring)
	node.set_meta("fx", ffx)
	_play("ink", 1.0, -10.0)
	return node


## Glyphe de la figure `shape` inscrit à la place `idx` (0..2) du cercle `ring`, avec un rebond.
func seal_add(ring: Node3D, shape: String, idx: int) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	var key := String(SEAL_ICON.get(shape, "figures/enso"))
	var tex := UiKit.icon(key, 96.0, {"*": UIColors.hex(HANKO)})
	if tex == null:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 0.0052
	s.shaded = false
	s.render_priority = -1
	s.rotation.x = -PI / 2.0
	var a := -PI / 2.0 + TAU * float(idx) / 3.0
	s.position = Vector3(cos(a) * 0.72, 0.012, sin(a) * 0.72)
	ring.add_child(s)
	_anim(s, 0.35, Vector3.ONE * 1.9, Vector3.ONE, {"g": 1.0, "keep": true})
	_ink_pop(ring.position + Vector3(cos(a) * 0.72, 0.3, sin(a) * 0.72), 0.35)
	_play("ink", 1.15 + 0.1 * float(idx), -8.0)


## Tampon hanko (plan XZ, demi-côté 1) : cadre épais, barres de « sceau » à l'intérieur ; au pinceau (poils).
func _hanko_mesh() -> ArrayMesh:
	if _meshes.has("hanko"):
		return _meshes["hanko"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sq := PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)])
	var nrm := PackedVector3Array([Vector3(-1, 0, -1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized()])
	var o := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var i2 := PackedFloat32Array([-0.36, -0.36, -0.36, -0.36, -0.36])
	_strip(st, sq, nrm, o, i2, 0.0, 8.0)
	# barres intérieures : deux verticales, une horizontale brisée (écriture sigillaire stylisée)
	var bars := [[Vector3(-0.45, 0, -0.62), Vector3(-0.45, 0, 0.62)], [Vector3(0.42, 0, -0.62), Vector3(0.42, 0, 0.1)],
		[Vector3(-0.62, 0, 0.12), Vector3(0.1, 0, 0.12)], [Vector3(0.1, 0, 0.35), Vector3(0.62, 0, 0.35)], [Vector3(-0.1, 0, -0.4), Vector3(0.62, 0, -0.4)]]
	for b in bars:
		var a: Vector3 = b[0]
		var c: Vector3 = b[1]
		var dd := (c - a).normalized()
		var side := Vector3(-dd.z, 0, dd.x)
		var pts := PackedVector3Array([a, c])
		var nn := PackedVector3Array([side, side])
		_strip(st, pts, nn, PackedFloat32Array([0.09, 0.09]), PackedFloat32Array([-0.09, -0.09]), 0.002, 3.0)
	var mesh := st.commit()
	_meshes["hanko"] = mesh
	return mesh


## Onde carrée (plan XZ, demi-côté 1) : bande fine au pinceau.
func _square_mesh() -> ArrayMesh:
	if _meshes.has("square"):
		return _meshes["square"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sq := PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)])
	var nrm := PackedVector3Array([Vector3(-1, 0, -1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized()])
	var o := PackedFloat32Array([0.07, 0.07, 0.07, 0.07, 0.07])
	var i2 := PackedFloat32Array([-0.07, -0.07, -0.07, -0.07, -0.07])
	_strip(st, sq, nrm, o, i2, 0.0, 8.0)
	var mesh := st.commit()
	_meshes["square"] = mesh
	return mesh


## Le sceau claque en `pos` : le tampon rouge-brun tombe et s'imprime au sol d'un coup sec, onde d'encre carrée,
## éclat, giclée de sumi ; le cercle `ring` (seal_ring) se referme et disparaît.
func seal_stamp(pos: Vector3, ring: Node3D) -> void:
	var g := Vector3(pos.x, 0.08, pos.z)
	if ring != null and is_instance_valid(ring):
		var rn = ring.get_meta("ring", null)
		if rn != null and is_instance_valid(rn):
			_anim(rn, 0.2, Vector3.ONE * 1.15, Vector3.ONE * 0.05, {"g": 1.0, "keep": true})
		for ch in ring.get_children():
			if ch is Sprite3D:
				_anim(ch, 0.2, Vector3.ONE, Vector3.ONE * 0.1, {"g": 1.0, "keep": true})
		# le cercle refermé est libéré d'ici (powers lâche _seal_ring au tampon : sans cela il suivait le héros
		# jusqu'à la fin du combat, glyphes rétrécis compris, et son effet restait dans _fx)
		var ffx = ring.get_meta("fx", null)
		if ffx is Dictionary:
			ffx.erase("keep")
			ffx["life"] = float(ffx["t"]) + 0.25
	var node := Node3D.new()
	add_child(node)
	node.position = g
	node.rotation.y = randf_range(-0.2, 0.2)
	var hr := _bramp(Color(HANKO, 0.92), -1)
	var mi := _mi(node, _hanko_mesh(), hr[0])
	# tombe de haut (grand, pâle) et s'imprime : rapide, un petit rebond, puis il reste, puis il sèche
	_anim(node, 1.6, Vector3.ONE * 2.3, Vector3.ONE * 1.3, {"g": 0.08, "pu": 0.0, "f": 0.6, "lay": [[mi, -1, hr]], "t": -0.02})
	var sq := Node3D.new()
	add_child(sq)
	sq.position = g + Vector3(0, 0.01, 0)
	sq.rotation.y = node.rotation.y
	var sr := _bramp(Color(Toon.SUMI, 0.85), -2)
	var smi := _mi(sq, _square_mesh(), sr[0])
	_anim(sq, 0.6, Vector3.ONE * 0.6, Vector3.ONE * 3.2, {"g": 0.55, "f": 0.3, "lay": [[smi, -1, sr]], "t": -0.1})
	if not Toon.lite:
		var sq2 := Node3D.new()
		add_child(sq2)
		sq2.position = g + Vector3(0, 0.02, 0)
		sq2.rotation.y = node.rotation.y
		var sr2 := _sramp("seal_sq2", Color(Toon.WASHI, 0.9), -1)
		var smi2 := _mi(sq2, _square_mesh(), sr2[0])
		_anim(sq2, 0.5, Vector3.ONE * 0.5, Vector3.ONE * 2.4, {"g": 0.5, "f": 0.3, "lay": [[smi2, -1, sr2]], "t": -0.18})
	_flare(pos + Vector3(0, 0.8, 0), Toon.WASHI, 1.3, 0.12, 0.1)
	_ink_pop(pos + Vector3(0, 0.6, 0), 0.9)
	ink_drops(pos + Vector3(0, 0.4, 0), Vector3.UP, 10, INK)
	_spatter(g, 1.6, INK, 1.2)
	_shake(0.42)
	_flash(0.12)
	_play("strike", 0.8, -4.0)
	_play("ink", 0.7, -2.0)


# --- capture des effets (`--q=fx=<id>&fxshot=<dossier>`)

func _dbg_init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if not s.begins_with("--q="):
			continue
		for part in s.substr(4).split("&"):
			if part.begins_with("fx="):
				_dbg_fx = part.substr(3)
			elif part.begins_with("fxshot="):
				_dbg_dir = part.substr(7)
			elif part.begins_with("fxt="):
				_dbg_shots = []
				for v in part.substr(4).split(","):
					_dbg_shots.append(float(v))


## Joue l'effet `id` en `p` (devant le héros) avec une cible factice `tgt` si l'effet en veut une.
func _dbg_trigger(id: String, p: Vector3, tgt: Node3D) -> void:
	var hero = main.hero
	var fwd: Vector3 = hero.facing if hero.facing.length_squared() > 0.001 else Vector3.FORWARD
	match id:
		"ink_thick":
			for i in 4:
				blot(p + fwd * (float(i) - 1.5) * 1.1 + Vector3(0.3 * float(i % 2), 0, 0), 0.75, 2.2, 0.08 * float(i))
			ink_step(p + Vector3(1.2, 0, 0.6), Vector3.FORWARD, 1.0)
			ink_step(p + Vector3(1.2, 0, 0.2), Vector3.FORWARD, -1.0)
		"bolt_static":
			_dbg_cycle = (_dbg_cycle % 3) + 1
			static_charge(hero, _dbg_cycle, 1.6)
		"bolt_nova":
			static_nova(p, 2.5)
			for i in 3:
				var a := TAU * float(i) / 3.0
				bolt(p + Vector3(0, 0.9, 0), p + Vector3(cos(a) * 2.2, 0.9, sin(a) * 2.2), 3, true, true)
		"fire_ash":
			ash_pile(tgt, 1.1, 1.9)
		"fire_lantern":
			lantern_glow(tgt, 0.6)
			_dbg_later(0.6, "lantern_burst", p)
		"water_mist":
			mist(tgt, 2.3, 1.9)
			_dbg_later(0.5, "mist_pop", p + Vector3(0.8, 0.6, 0))
		"water_spring":
			spring(p)
		"bolt_rod":
			rod_mark(tgt, 0.25)
			_dbg_later(0.25, "rod_strike", p)
		"wind_gale":
			gale_blow(tgt, fwd)
			tgt.set_meta("vel", fwd * 6.0)
		"wind_current":
			tailwind(hero, fwd, 0.7)
		"shadow_double":
			double_dress(tgt, 1.9)
			_dbg_later(0.6, "double_strike", p)
		"shadow_dusk":
			dusk_crit(p)
			if main:
				main.float_text(p, "×2", GOLD)
		"ink_seal":
			var ring := seal_ring(hero)
			seal_add(ring, "loop", 0)
			seal_add(ring, "zigzag", 1)
			seal_add(ring, "enso", 2)
			_dbg_later(0.5, "seal_stamp", hero.position)
			_dbg_ring = ring


var _dbg_ring: Node3D
var _dbg_tgt: Node3D
var _dbg_cycle := 0
var _dbg_later_q: Array = []  # [délai, nom, point]


func _dbg_later(delay: float, what: String, p: Vector3) -> void:
	_dbg_later_q.append([delay, what, p])


func _dbg_step(dt: float) -> void:
	if main == null or main.hero == null or not is_instance_valid(main.hero):
		return
	var hero = main.hero
	for i in range(_dbg_later_q.size() - 1, -1, -1):
		var it: Array = _dbg_later_q[i]
		it[0] = float(it[0]) - dt
		if float(it[0]) > 0.0:
			continue
		_dbg_later_q.remove_at(i)
		var p: Vector3 = it[2]
		match String(it[1]):
			"lantern_burst":
				lantern_burst(p)
			"mist_pop":
				mist_pop(p)
			"rod_strike":
				rod_strike(p, _dbg_tgt)
			"double_strike":
				double_strike(p, p + Vector3(1.6, 0, -0.4))
			"seal_stamp":
				seal_stamp(p, _dbg_ring)
	if is_instance_valid(_dbg_tgt) and _dbg_tgt.has_meta("vel"):
		_dbg_tgt.position += (_dbg_tgt.get_meta("vel") as Vector3) * dt
	_dbg_t -= dt
	if _dbg_t <= 0.0:
		_dbg_t = 2.6
		_dbg_since = 0.0
		_dbg_shot = 0
		if is_instance_valid(_dbg_tgt):
			_dbg_tgt.queue_free()
		if is_instance_valid(_dbg_ring):
			_dbg_ring.queue_free()
		var fwd: Vector3 = hero.facing if hero.facing.length_squared() > 0.001 else Vector3.FORWARD
		var p: Vector3 = hero.position + fwd * 2.4
		_dbg_tgt = Node3D.new()
		add_child(_dbg_tgt)
		_dbg_tgt.position = Vector3(p.x, 0.0, p.z)
		_dbg_trigger(_dbg_fx, p, _dbg_tgt)
	elif _dbg_since >= 0.0:
		_dbg_since += dt
		if _dbg_dir != "" and _dbg_shot < _dbg_shots.size() and _dbg_since >= float(_dbg_shots[_dbg_shot]):
			var path := "%s/%s_%d.png" % [_dbg_dir, _dbg_fx, _dbg_shot]
			get_viewport().get_texture().get_image().save_png(path)
			print("FXSHOT ", path)
			_dbg_shot += 1
			if _dbg_shot >= _dbg_shots.size():
				get_tree().quit()


## Préchauffage (main._warmup) : joue une fois chaque effet riche en `p` (caché), sans son ni secousse,
## pour compiler d'avance le pinceau des effets, les variantes additives et la crête de vague.
func warm(p: Vector3) -> void:
	_warming = true
	var first := get_child_count()
	var q := p + Vector3(1.5, 0, 0)
	bolt(p, q, 2, true)  # (pas d'éclair du ciel : il dépasserait de la cachette ; ses briques sont toutes ici)
	fire_burst(p, 1.5, true)
	fire_trail(PackedVector3Array([p, p + Vector3(0.6, 0, 0), q]), 0.3)
	water_burst(p, 1.2, true)
	wave_arc(p, Vector3.FORWARD, 0.8, true)
	wind_slash(p, Vector3.FORWARD, 0.9, true)
	wind_burst(p, 1.2)
	toupie(p, 1.2)
	shadow_stab(p, q, true)
	shadow_burst(p, 1.2)
	ink_wave(p, 1.2, true)
	slash_line(p, q, true)
	guard(p, 1.2)
	chest_burst(p)
	kill_burst(p, Vector3.FORWARD, false, Toon.VERMILION)
	var wave := Node3D.new()
	add_child(wave)
	wave.position = p
	dress_wave(wave)
	_fx.append({"node": wave, "t": 0.0, "life": 0.5, "kind": "none"})
	# les douze pouvoirs récents : cibles factices (libérées après coup) pour les effets qui suivent un nœud
	var dums := []
	for i in 4:
		var d := Node3D.new()
		add_child(d)
		d.position = p + Vector3(0.4 * float(i), 0, 0)
		dums.append(d)
		_fx.append({"node": d, "t": 0.0, "life": 1.2, "kind": "none"})
	static_charge(dums[0], 2, 0.5)
	static_nova(p, 1.5)
	blot(p, 0.6, 0.6)
	ash_pile(dums[1], 1.0, 0.8)
	mist(dums[2], 1.5, 0.8)
	lantern_glow(dums[0], 0.3)
	lantern_burst(p)
	rod_mark(dums[0], 0.2)
	gale_blow(dums[0], Vector3.FORWARD)
	tailwind(dums[0], Vector3.FORWARD, 0.3)
	double_dress(dums[3], 0.6)
	double_strike(p, q)
	dusk_crit(p)
	seal_stamp(p, null)
	shadow_step(p)
	# les effets posés au ras du sol (ondes, taches, sillage) descendent eux aussi dans la cachette
	for i in range(first, get_child_count()):
		var ch := get_child(i) as Node3D
		if ch != null:
			ch.position.y -= 3.0
	# puis tous passent en miniature (× 0,002 autour de p) : l'eau de l'accueil est transparente (et absente sous la
	# mer de Ryūgū-jō), les effets additifs ou à priorité de rendu haute se voyaient en grand au pied du héros
	# (éclair jaune, flamme, éclats d'encre) pendant les premières secondes de l'accueil
	var hold := Node3D.new()
	add_child(hold)
	hold.position = p
	hold.scale = Vector3.ONE * 0.002
	var made: Array = []
	for i in range(first, get_child_count() - 1):
		made.append(get_child(i))
	for ch in made:
		var n := ch as Node
		var p3 := (n as Node3D).position if n is Node3D else Vector3.ZERO
		remove_child(n)
		hold.add_child(n)
		if n is Node3D:
			(n as Node3D).position = p3 - p
	if main != null and main.has_method("_warm_shrink"):
		main.call("_warm_shrink", hold)
	get_tree().create_timer(1.5, true, false, true).timeout.connect(hold.queue_free)
	_warming = false


func _process(delta: float) -> void:
	# temps réel : les effets ne ralentissent pas avec le jeu
	var dt := UiKit.unscaled(delta, 0.05)
	_frame_big = false
	if main and main.hero and is_instance_valid(main.hero) and main.hero.dashing:
		trail_point(main.hero.position)
	_update_trail(dt)
	_budget = minf(_budget + dt * (12.0 if Toon.lite else 26.0), 9.0 if Toon.lite else 18.0)
	var gdt := minf(delta, 0.05)  # temps du jeu (sillage de feu)
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Dictionary = _fx[i]
		# non typé d'abord : le nœud peut avoir été libéré (parent libéré par un appelant)
		var nv = fx.node
		if not is_instance_valid(nv):
			_fx.remove_at(i)
			continue
		var node: Node3D = nv
		var sdt := gdt if fx.has("game") else dt
		fx.t = float(fx.t) + sdt
		var k: float = float(fx.t) / float(fx.life)
		match fx.kind:  # déjà une String : pas de copie par effet et par image
			"anim":
				_anim_step(fx, node, k, sdt)
			"blot":
				_blot_step(fx, node, sdt)
			"crackle":
				_crackle_step(fx, node, k, sdt)
			"pulse":
				_pulse_step(fx, k)
			"breathe":
				_breathe_step(fx, node, k, sdt)
			"mist":
				_mist_step(fx, k, sdt)
			"wobble":
				_wobble_step(fx, k)
			"bolt":
				# scintille : change de tracé une fois, puis s'éteint
				if not bool(fx.swap) and k > 0.4:
					fx.swap = true
					(node as MeshInstance3D).mesh = fx.alt
				node.visible = k < 0.85
				# claque : plus épais au départ, puis s'affine
				if fx.has("b0"):
					var b0: Basis = fx.b0
					var th := 1.0 + 0.9 * pow(maxf(1.0 - k * 2.5, 0.0), 2.0)
					node.transform.basis = Basis(b0.x * th, b0.y * th, b0.z)
			"pop":
				var ps: float = fx.s
				node.scale = Vector3.ONE * ps * (0.4 + 0.8 * k)
				node.visible = k < 0.8
			"spinarc":
				var sw: float = fx.s
				node.scale = Vector3.ONE * sw * (0.8 + 0.5 * k)
				node.rotation.y += dt * 9.0
				node.visible = k < 0.85
			"swirl":
				var rr: float = fx.r
				node.scale = Vector3.ONE * rr * (0.6 + 0.6 * k)
				node.rotation.y += dt * 12.0
				node.visible = k < 0.9
			"stab":
				node.visible = k < 0.85
			"burst":
				# jaillit vite puis se disperse (rétrécit)
				var bsz: float = fx.s
				var b_grow := 1.0 - pow(1.0 - clampf(k / 0.35, 0.0, 1.0), 3.0)
				var b_gone := clampf((1.0 - k) / 0.45, 0.0, 1.0)
				node.scale = Vector3.ONE * maxf(bsz * (0.3 + 0.8 * b_grow) * b_gone, 0.01)
			"pool":
				var pr: float = fx.r
				var kd := clampf((float(fx.t) - float(fx.d)) / maxf(float(fx.life) - float(fx.d), 0.01), 0.0, 1.0)
				var p_open := 1.0 - pow(1.0 - clampf(kd / 0.3, 0.0, 1.0), 3.0)
				var p_shut := clampf((1.0 - kd) / 0.45, 0.0, 1.0)
				var pz := maxf(pr * p_open * p_shut, 0.01)
				node.scale = Vector3(pz, pz, 1.0)
			"iai":
				var mi := node.get_child(0) as MeshInstance3D
				mi.scale = Vector3(1.3 * sqrt(maxf(1.0 - k, 0.0)), 1, float(fx.l))
			"shrink":
				var s3: Vector3 = fx.s3
				var sk := clampf((1.0 - k) / 0.3, 0.0, 1.0)
				node.scale = Vector3(s3.x * maxf(sk, 0.01), 1, s3.z * maxf(sk, 0.01))
			"emit":
				if float(fx.t) >= float(fx.stop):
					(node as CPUParticles3D).emitting = false
			"fade_mat":
				var fm: StandardMaterial3D = fx.mat
				fm.albedo_color.a = float(fx.a) * clampf((1.0 - k) * 3.0, 0.0, 1.0)
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
				# sceau « entaille » de la mise à mort : rebond, montée, fondu
				var l := node as Sprite3D
				var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 5.0)
				l.scale = Vector3.ONE * pop
				l.modulate.a = clampf((1.0 - k) * 2.5, 0.0, 1.0)
				l.position.y += dt * 1.2
		if k >= 1.0:
			# keep : le nœud appartient à l'appelant (zone de powers, enfant d'un autre effet) : on le lâche seulement
			if not fx.has("keep") and not _recycle(node):
				node.queue_free()
			_fx.remove_at(i)
	if _dbg_fx != "":
		_dbg_step(dt)
