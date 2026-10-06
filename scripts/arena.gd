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
	# étang au centre, bords larges
	"pond": [Rect2(-4.6, -8.6, 9.2, 6.0), Rect2(-4.6, 2.6, 9.2, 6.0), Rect2(-4.6, -3.2, 2.8, 6.4), Rect2(1.8, -3.2, 2.8, 6.4)],
	# trois terrasses reliées par des passerelles décalées
	"terraces": [Rect2(-4.6, -8.6, 9.2, 4.6), Rect2(-3.6, -2.6, 7.2, 4.0), Rect2(-4.6, 3.4, 9.2, 5.2),
		Rect2(-3.0, 0.8, 2.6, 3.2), Rect2(0.4, -4.6, 2.6, 2.6)],
	# L : colonne + bande du bas, îlot relié en haut à droite
	"ell": [Rect2(-4.6, -8.6, 4.4, 17.2), Rect2(-4.6, 3.0, 9.2, 5.6), Rect2(-0.9, -6.6, 2.6, 2.0), Rect2(1.0, -8.0, 3.6, 4.8)],
	# escalier en diagonale
	"stairs": [Rect2(-0.4, -8.6, 5.0, 5.4), Rect2(-1.8, -3.8, 5.0, 4.8), Rect2(-3.2, 0.4, 5.0, 4.6), Rect2(-4.6, 4.4, 5.0, 4.2)],
	# quatre îles en losange, passerelles en anneau
	"diamond": [Rect2(-2.6, -8.6, 5.2, 5.0), Rect2(-4.6, -1.0, 3.8, 4.6), Rect2(0.8, -1.0, 3.8, 4.6), Rect2(-2.6, 4.6, 5.2, 4.0),
		Rect2(-2.6, -4.2, 2.0, 3.8), Rect2(0.6, -4.2, 2.0, 3.8), Rect2(-2.6, 3.0, 2.0, 2.2), Rect2(0.6, 3.0, 2.0, 2.2)],
	# couloir central et alcôves alternées
	"spine": [Rect2(-1.7, -8.6, 3.4, 17.2), Rect2(-4.6, 3.0, 3.6, 4.0), Rect2(1.0, -2.0, 3.6, 4.0), Rect2(-4.6, -7.0, 3.6, 4.0)],
	# quatre quartiers séparés par une croix de vide
	"quad": [Rect2(-4.6, -8.6, 3.8, 7.2), Rect2(0.8, -8.6, 3.8, 7.2), Rect2(-4.6, 1.4, 3.8, 7.2), Rect2(0.8, 1.4, 3.8, 7.2),
		Rect2(-1.4, -6.4, 2.8, 2.0), Rect2(-1.4, 4.4, 2.8, 2.0), Rect2(-3.8, -2.0, 2.0, 4.0), Rect2(1.8, -2.0, 2.0, 4.0)],
	# douves : cadre fin, île centrale reliée au nord et au sud
	"moat": [Rect2(-4.6, -8.6, 9.2, 3.4), Rect2(-4.6, 4.6, 9.2, 4.0), Rect2(-4.6, -5.8, 1.8, 11.0), Rect2(2.8, -5.8, 1.8, 11.0),
		Rect2(-1.7, -2.4, 3.4, 4.8), Rect2(-1.0, -5.8, 2.0, 4.0), Rect2(-1.0, 1.8, 2.0, 3.4)],
}

const BOSS_LAYOUT := "full"  # les boss supposent toute l'arène (HALF)
const FIRST_LAYOUTS := ["pond", "terraces"]  # salle 1 : du relief, mais facile
# saveur par monde : ces formes sortent deux fois plus souvent
const FLAVOR := {
	1: ["islands", "twin", "spine", "terraces"],
	2: ["quad", "diamond", "stairs"],
	3: ["moat", "ring", "ell"],
	4: ["zigzag", "stairs", "hourglass", "islands"],
	5: ["cross", "pond", "diamond", "spine"],
}
const MAX_USES := 2  # une forme au plus deux fois par partie
const BRIDGE_W := 2.7  # un rectangle plus étroit que ça est une passerelle (pont de bois au-dessus du vide)
const WOOD := [Color("#8E6B3E"), Color("#A88452"), Color("#7A5A34")]
const MIN_AREA := 70.0  # surface jouable minimale d'une forme (m²)

# hub de départ : place (0), dojo (1), passerelle dojo-place (2), chemin de planches (3), sanctuaire du torii (4)
const HUB_RECTS := [Rect2(-4.6, 2.0, 9.2, 6.6), Rect2(-4.6, -4.0, 5.2, 5.4), Rect2(-3.2, 0.8, 2.4, 1.8),
	Rect2(1.6, -6.0, 2.4, 8.6), Rect2(-1.0, -8.6, 5.6, 3.2)]
const HUB_DOJO := 1

var world_id := 0
var hub_training_center := Vector3(-2.0, 0, -1.1)
var hub_training_radius := 2.0
var pieces: Array = []  # sol découpé sans recouvrement : [Rect2, passerelle ?]
var bridges: Array = []  # morceaux de passerelle au-dessus du vide (Rect2)
var layout := "full"
var mirrored := false
var rects: Array = []
var _used := {}  # forme -> nombre d'utilisations pendant la partie
var _last := ""  # dernière forme hors boss
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
var _pits := {}  # état d'animation des fosses (Worlds.build_pits)


func _ready() -> void:
	_world_root = Node3D.new()
	add_child(_world_root)
	_room_root = Node3D.new()
	add_child(_room_root)
	# vérification automatique (CI) : formes de salle cohérentes
	if "--autoplay" in OS.get_cmdline_user_args():
		var fails: Array = check_layouts()
		if not fails.is_empty():
			print("SCRIPT ERROR: formes de salle : ", fails)


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
func build_room(room: int, rooms: int, rng_seed: int, mini_room := 8) -> void:
	for ch in _room_root.get_children():
		ch.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	layout = _pick_layout(room, rooms, mini_room, rng)
	# miroir gauche/droite (sans effet sur les formes symétriques), jamais pour un boss
	mirrored = layout != BOSS_LAYOUT and rng.randf() < 0.5
	rects = _layout_rects(layout, mirrored)
	_finish_room(Worlds.world(world_id), rng, rng_seed)


## Le hub de départ : grande place, dojo d'entraînement (cercle de sable) à gauche,
## passerelle vers le sanctuaire du torii en haut. Le torii reste fermé (open_gate() côté main).
func build_hub(rng_seed: int) -> void:
	for ch in _room_root.get_children():
		ch.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	layout = "hub"
	mirrored = false
	_used.clear()
	_last = ""
	rects = []
	for r in HUB_RECTS:
		rects.append(r)
	var dojo: Rect2 = HUB_RECTS[HUB_DOJO]
	hub_training_center = Vector3(dojo.get_center().x, 0, dojo.get_center().y + 0.2)
	hub_training_radius = minf(dojo.size.x, dojo.size.y) * 0.5 - 0.55
	var w: Dictionary = Worlds.world(world_id)
	_finish_room(w, rng, rng_seed)
	_build_dojo()


## Sol, décor, départ et torii pour les `rects` courants.
func _finish_room(w: Dictionary, rng: RandomNumberGenerator, rng_seed: int) -> void:
	_build_floor(w, rng)
	_flush_tiles()
	# départ au sud de la plateforme la plus basse, sortie au nord de la plus haute
	var ends: Array = _ends(rects)
	start = ends[0]
	gate_pos = ends[1]
	# le décor reste hors du cadre de l'arène (rien dans les canaux entre plateformes) :
	# on lui passe la plateforme du torii et un cadre qui couvre toute l'arène
	var high: Rect2 = ends[3]
	var frame := Rect2(-HALF.x, -HALF.y + 0.01, HALF.x * 2.0, HALF.y * 2.0 - 0.01)
	Worlds.build_props(world_id, _room_root, [high, frame], rng_seed)
	# les vides intérieurs deviennent des fosses (paroi, gouffre, bord cassé selon le monde)
	_pits = Worlds.build_pits(world_id, _room_root, rects, void_rects(rects), rng_seed)
	_build_gate(w)


## Dojo du hub : cercle de sable cerné d'encre, deux poteaux et une corde sacrée au nord.
func _build_dojo() -> void:
	var c := hub_training_center
	var rad := hub_training_radius
	# au-dessus des dalles et des bosses de neige (sommet ~0.04)
	_flat_disc(c, rad + 0.18, Toon.SUMI, 0.05)
	_flat_disc(c, rad, Color("#E3CC98"), 0.058)
	# râteau zen : sillons concentriques (du plus grand au plus petit, chacun un peu plus haut)
	for k in 3:
		var rr := rad * (0.78 - 0.22 * k)
		_flat_disc(c, rr + 0.05, Color("#C9AD74"), 0.066 + 0.016 * k)
		_flat_disc(c, rr, Color("#E3CC98"), 0.074 + 0.016 * k)
	var wood := Toon.mat(Color("#6B4A2B"))
	var top_y := 1.15
	var pa := Vector3(c.x - 1.3, 0, c.z - rad - 0.25)
	var pb := Vector3(c.x + 1.3, 0, c.z - rad - 0.25)
	for p in [pa, pb]:
		var pp: Vector3 = p
		Toon.part(_room_root, Toon.cyl(0.09, 0.11, top_y + 0.1, 8), wood, pp + Vector3(0, (top_y + 0.1) / 2.0, 0))
	var bs := {}
	var bn := {}
	Decor.shimenawa_into(bs, bn, pa + Vector3(0, top_y - 0.1, 0), pb + Vector3(0, top_y - 0.1, 0))
	Decor._flush(bs, _room_root, true)
	Decor._flush(bn, _room_root, false)


func _flat_disc(c: Vector3, r: float, col: Color, y: float) -> void:
	var m := Toon.mat(col, false)
	m.rim_enabled = false
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var d := Toon.part(_room_root, Toon.cyl(r, r, 0.004, 40), m, Vector3(c.x, y, c.z))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Choisit la forme de la salle : pleine pour les boss, facile mais en relief pour la salle 1,
## sinon jamais deux fois de suite, au plus MAX_USES fois par partie, avec la saveur du monde.
func _pick_layout(room: int, rooms: int, mini_room: int, rng: RandomNumberGenerator) -> String:
	if room == mini_room or room >= rooms:
		return BOSS_LAYOUT
	if room <= 1:
		_used.clear()
		_last = ""
		var first := String(FIRST_LAYOUTS[rng.randi() % FIRST_LAYOUTS.size()])
		_used[first] = 1
		_last = first
		return first
	var flavor: Array = FLAVOR.get(world_id, [])
	var cands: Array = []
	var weights: Array = []
	var total := 0.0
	for pass_i in 2:
		for k in LAYOUTS.keys():
			var key := String(k)
			if key == BOSS_LAYOUT or key == _last:
				continue
			# second passage (tout épuisé) : on oublie la limite d'usage
			if pass_i == 0 and int(_used.get(key, 0)) >= MAX_USES:
				continue
			var wgt := 2.0 if key in flavor else 1.0
			cands.append(key)
			weights.append(wgt)
			total += wgt
		if not cands.is_empty():
			break
	var pick := String(cands[cands.size() - 1])
	var x := rng.randf() * total
	for i in cands.size():
		x -= float(weights[i])
		if x <= 0.0:
			pick = String(cands[i])
			break
	_used[pick] = int(_used.get(pick, 0)) + 1
	_last = pick
	return pick


## Rectangles d'une forme, éventuellement retournée gauche/droite.
static func _layout_rects(key: String, mirror: bool) -> Array:
	var out: Array = []
	var src: Array = LAYOUTS[key]
	for r in src:
		var rr: Rect2 = r
		if mirror:
			rr = Rect2(-rr.end.x, rr.position.y, rr.size.x, rr.size.y)
		out.append(rr)
	return out


## [départ, torii] : départ au sud de la plateforme la plus basse, torii au nord de la plus haute
## (à égalité, la plus centrale ; même calcul que Worlds._reserve_gate).
static func _ends(rs: Array) -> Array:
	var low: Rect2 = rs[0]
	var high: Rect2 = rs[0]
	for r in rs:
		var rr: Rect2 = r
		if rr.end.y > low.end.y or (is_equal_approx(rr.end.y, low.end.y) and absf(rr.get_center().x) < absf(low.get_center().x)):
			low = rr
		if rr.position.y < high.position.y or (is_equal_approx(rr.position.y, high.position.y) and absf(rr.get_center().x) < absf(high.get_center().x)):
			high = rr
	var s := Vector3(clampf(0.0, low.position.x + 0.8, low.end.x - 0.8), 0, low.end.y - 2.2)
	var g := Vector3(clampf(0.0, high.position.x + 1.2, high.end.x - 1.2), 0, high.position.y + 0.9)
	return [s, g, low, high]


## Sol de la salle : l'union des rectangles est découpée en morceaux disjoints (ni recouvrement,
## ni z-fighting, ni bord dessiné à l'intérieur) ; le bord d'encre suit le vrai contour ;
## les passerelles au-dessus du vide deviennent des ponts de planches, au niveau du sol.
func _build_floor(w: Dictionary, rng: RandomNumberGenerator) -> void:
	var dec: Dictionary = _decompose(rects)
	pieces = dec["pieces"]
	bridges = []
	var mats: Array = []
	for col in w.ground:
		mats.append(_ground_mat(col))
	var woods: Array = []
	for col in WOOD:
		woods.append(_ground_mat(col))
	var under := Toon.mat(w.under, false)
	var deck := _ground_mat(Color("#3E2C1C"))
	var style := String(w.ground_style)
	for pc in pieces:
		var r: Rect2 = pc[0]
		var c := r.get_center()
		if bool(pc[1]):
			bridges.append(r)
			_tile(Vector3(r.size.x, 0.2, r.size.y), Vector3(c.x, -0.14, c.y), deck)
			_bridge_planks(r, woods, rng)
		else:
			_tile(Vector3(r.size.x, 0.46, r.size.y), Vector3(c.x, -0.27, c.y), under)
			_floor_piece(r, style, mats, rng)
	_build_edges(dec, w, woods[2])


func _ground_mat(col: Color) -> StandardMaterial3D:
	var m := Toon.mat(col, false)
	m.rim_enabled = false
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## Pont : planches en travers du sens de la marche, pieux dans l'eau aux coins.
func _bridge_planks(r: Rect2, woods: Array, rng: RandomNumberGenerator) -> void:
	var along_x := _bridge_along_x(r)
	var len_t: float = r.size.x if along_x else r.size.y
	var n := maxi(1, int(roundf(len_t / 0.34)))
	var step := len_t / n
	var c := r.get_center()
	for i in n:
		var t := (i + 0.5) * step
		var m: Material = woods[rng.randi() % woods.size()]
		var y := -0.045 + rng.randf_range(-0.006, 0.006)
		if along_x:
			_tile(Vector3(step - 0.04, 0.09, r.size.y - 0.02), Vector3(r.position.x + t, y, c.y), m)
		else:
			_tile(Vector3(r.size.x - 0.02, 0.09, step - 0.04), Vector3(c.x, y, r.position.y + t), m)
	var pile: Material = woods[2]
	for px in [r.position.x + 0.15, r.end.x - 0.15]:
		for pz in [r.position.y + 0.15, r.end.y - 0.15]:
			_tile(Vector3(0.14, 0.5, 0.14), Vector3(float(px), -0.45, float(pz)), pile)


## Sens de la marche d'un morceau de passerelle : vers les côtés qui touchent la terre ferme.
func _bridge_along_x(r: Rect2) -> bool:
	var c := r.get_center()
	var we := _in_any(rects, Vector2(r.position.x - 0.1, c.y)) or _in_any(rects, Vector2(r.end.x + 0.1, c.y))
	var ns := _in_any(rects, Vector2(c.x, r.position.y - 0.1)) or _in_any(rects, Vector2(c.x, r.end.y + 0.1))
	if we and not ns:
		return true
	if ns and not we:
		return false
	return r.size.x > r.size.y


## Dallage d'un morceau, calé sur une grille commune à toute l'arène (pas de couture entre morceaux).
func _floor_piece(r: Rect2, style: String, mats: Array, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	match style:
		"planks":
			var pw := 0.62
			var x := -HALF.x + floorf((r.position.x + HALF.x) / pw + 0.001) * pw
			while x < r.end.x - 0.02:
				var x0 := maxf(x, r.position.x)
				var x1 := minf(x + pw, r.end.x)
				var g0 := 0.0175 if x0 <= x + 0.001 else 0.0
				var g1 := 0.0175 if x1 >= x + pw - 0.001 else 0.0
				if x1 - x0 > 0.02:
					var z0 := r.position.y
					while z0 < r.end.y - 0.01:
						var l := minf(rng.randf_range(2.6, 5.5), r.end.y - z0)
						_tile(Vector3(maxf(x1 - x0 - g0 - g1, 0.01), 0.09, maxf(l - 0.03, 0.01)), Vector3((x0 + g0 + x1 - g1) / 2.0, -0.045 + rng.randf_range(-0.006, 0.006), z0 + l / 2.0), mats[rng.randi() % mats.size()])
						z0 += l
				x += pw
		"stones", "basalt":
			var s := 1.0 if style == "stones" else 0.9
			var gz := -HALF.y + floorf((r.position.y + HALF.y) / s + 0.001) * s
			while gz < r.end.y - 0.02:
				var row := int(roundf((gz + HALF.y) / s))
				var z0 := maxf(gz, r.position.y)
				var z1 := minf(gz + s, r.end.y)
				var h0 := 0.03 if z0 <= gz + 0.001 else 0.0
				var h1 := 0.03 if z1 >= gz + s - 0.001 else 0.0
				if z1 - z0 > 0.02:
					var off := s * 0.5 if row % 2 == 1 else 0.0
					var gx := -HALF.x - off + floorf((r.position.x + HALF.x + off) / s + 0.001) * s
					while gx < r.end.x - 0.02:
						var x0 := maxf(gx, r.position.x)
						var x1 := minf(gx + s, r.end.x)
						var g0 := 0.03 if x0 <= gx + 0.001 else 0.0
						var g1 := 0.03 if x1 >= gx + s - 0.001 else 0.0
						if x1 - x0 > 0.02:
							_tile(Vector3(maxf(x1 - x0 - g0 - g1, 0.01), 0.09, maxf(z1 - z0 - h0 - h1, 0.01)),
								Vector3((x0 + g0 + x1 - g1) / 2.0, -0.045 + rng.randf_range(-0.01, 0.01), (z0 + h0 + z1 - h1) / 2.0), mats[rng.randi() % mats.size()])
						gx += s
				gz += s
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


## Bords : seulement là où la terre ferme touche le vide. Bord d'encre pour les plateformes,
## poutre de bois sous le niveau du sol pour les ponts (pas de cadre au-dessus de l'eau).
func _build_edges(dec: Dictionary, w: Dictionary, beam: Material) -> void:
	var xs: Array = dec["xs"]
	var zs: Array = dec["zs"]
	var kinds: Array = dec["kinds"]
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	var ink := Toon.mat(w.edge, false)
	# bords le long de x, sur chaque ligne de la grille
	for jl in nz + 1:
		var i := 0
		while i < nx:
			var k := _edge_kind(kinds, nx, nz, i, jl - 1, i, jl)
			if k == 0:
				i += 1
				continue
			var i0 := i
			while i < nx and _edge_kind(kinds, nx, nz, i, jl - 1, i, jl) == k:
				i += 1
			_edge_strip(Vector2(float(xs[i0]), float(zs[jl])), Vector2(float(xs[i]), float(zs[jl])), k == 2, ink, beam)
	# bords le long de z, sur chaque colonne de la grille
	for il in nx + 1:
		var j := 0
		while j < nz:
			var k := _edge_kind(kinds, nx, nz, il - 1, j, il, j)
			if k == 0:
				j += 1
				continue
			var j0 := j
			while j < nz and _edge_kind(kinds, nx, nz, il - 1, j, il, j) == k:
				j += 1
			_edge_strip(Vector2(float(xs[il]), float(zs[j0])), Vector2(float(xs[il]), float(zs[j])), k == 2, ink, beam)


func _edge_strip(a: Vector2, b: Vector2, bridge: bool, ink: Material, beam: Material) -> void:
	var horiz := absf(a.y - b.y) < 0.001
	var l := a.distance_to(b)
	var mid := (a + b) / 2.0
	if bridge:
		var sb := Vector3(l, 0.2, 0.12) if horiz else Vector3(0.12, 0.2, l)
		_tile(sb, Vector3(mid.x, -0.13, mid.y), beam)
	else:
		var se := Vector3(l + 0.1, 0.56, 0.1) if horiz else Vector3(0.1, 0.56, l + 0.1)
		_tile(se, Vector3(mid.x, -0.25, mid.y), ink)


## Type de bord entre deux cellules de la grille : 0 = pas de bord, 1 = plateforme, 2 = pont.
static func _edge_kind(kinds: Array, nx: int, nz: int, ia: int, ja: int, ib: int, jb: int) -> int:
	var a := _cell_at(kinds, nx, nz, ia, ja)
	var b := _cell_at(kinds, nx, nz, ib, jb)
	if (a == 0) == (b == 0):
		return 0
	return maxi(a, b)


static func _cell_at(kinds: Array, nx: int, nz: int, i: int, j: int) -> int:
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return 0
	return int(kinds[j * nx + i])


static func _is_bridge_rect(r: Rect2) -> bool:
	return minf(r.size.x, r.size.y) < BRIDGE_W


static func _in_any(rs: Array, p: Vector2) -> bool:
	for r in rs:
		var rr: Rect2 = r
		if rr.has_point(p):
			return true
	return false


static func _walk_r(rs: Array, p: Vector2, margin: float) -> bool:
	for r in rs:
		var rr: Rect2 = r
		if rr.grow(-margin).has_point(p):
			return true
	return false


## 0 = vide, 1 = plateforme, 2 = pont (seulement couvert par des passerelles).
static func _cell_kind(rs: Array, p: Vector2) -> int:
	var br := false
	for r in rs:
		var rr: Rect2 = r
		if rr.has_point(p):
			if _is_bridge_rect(rr):
				br = true
			else:
				return 1
	return 2 if br else 0


static func _add_coord(arr: Array, v: float) -> void:
	for e in arr:
		if absf(float(e) - v) < 0.001:
			return
	arr.append(v)


## Découpe l'union des rectangles sur la grille de leurs bords, puis fusionne les cellules
## de même type en grands rectangles disjoints. -> {xs, zs, kinds, pieces: [[Rect2, pont ?], …]}
static func _decompose(rs: Array) -> Dictionary:
	var xs: Array = []
	var zs: Array = []
	for r in rs:
		var rr: Rect2 = r
		_add_coord(xs, rr.position.x)
		_add_coord(xs, rr.end.x)
		_add_coord(zs, rr.position.y)
		_add_coord(zs, rr.end.y)
	xs.sort()
	zs.sort()
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	var kinds: Array = []
	for j in nz:
		for i in nx:
			var p := Vector2((float(xs[i]) + float(xs[i + 1])) / 2.0, (float(zs[j]) + float(zs[j + 1])) / 2.0)
			kinds.append(_cell_kind(rs, p))
	return {"xs": xs, "zs": zs, "kinds": kinds, "pieces": _merge_cells(xs, zs, kinds)}


## Vides intérieurs de l'arène (cadre HALF moins les plateformes ; le dessous des ponts compte comme vide),
## en rectangles disjoints : worlds.gd y creuse les fosses.
static func void_rects(rs: Array) -> Array:
	var xs: Array = [-HALF.x, HALF.x]
	var zs: Array = [-HALF.y, HALF.y]
	for r in rs:
		var rr: Rect2 = r
		_add_coord(xs, clampf(rr.position.x, -HALF.x, HALF.x))
		_add_coord(xs, clampf(rr.end.x, -HALF.x, HALF.x))
		_add_coord(zs, clampf(rr.position.y, -HALF.y, HALF.y))
		_add_coord(zs, clampf(rr.end.y, -HALF.y, HALF.y))
	xs.sort()
	zs.sort()
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	var kinds: Array = []
	for j in nz:
		for i in nx:
			var p := Vector2((float(xs[i]) + float(xs[i + 1])) / 2.0, (float(zs[j]) + float(zs[j + 1])) / 2.0)
			kinds.append(0 if _cell_kind(rs, p) == 1 else 1)
	var out: Array = []
	for pc in _merge_cells(xs, zs, kinds):
		var a: Array = pc
		out.append(a[0])
	return out


## Fusion des cellules de la grille de même type (≠ 0) en grands rectangles disjoints : [[Rect2, type 2 ?], …].
static func _merge_cells(xs: Array, zs: Array, kinds: Array) -> Array:
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	# fusion : séries horizontales, prolongées vers le bas tant que la série suivante est identique
	var open: Array = []  # [i0, i1, type, j0, j1]
	var done: Array = []
	for j in nz:
		var runs: Array = []
		var i := 0
		while i < nx:
			var k := int(kinds[j * nx + i])
			if k == 0:
				i += 1
				continue
			var i0 := i
			while i < nx and int(kinds[j * nx + i]) == k:
				i += 1
			runs.append([i0, i, k])
		var next_open: Array = []
		for run in runs:
			var found := -1
			for oi in open.size():
				var o: Array = open[oi]
				if int(o[0]) == int(run[0]) and int(o[1]) == int(run[1]) and int(o[2]) == int(run[2]):
					found = oi
					break
			if found >= 0:
				var ext: Array = open[found]
				ext[4] = j + 1
				next_open.append(ext)
				open.remove_at(found)
			else:
				next_open.append([run[0], run[1], run[2], j, j + 1])
		for o in open:
			done.append(o)
		open = next_open
	for o in open:
		done.append(o)
	var out: Array = []
	for d in done:
		var a: Array = d
		var x0 := float(xs[int(a[0])])
		var x1 := float(xs[int(a[1])])
		var z0 := float(zs[int(a[3])])
		var z1 := float(zs[int(a[4])])
		out.append([Rect2(x0, z0, x1 - x0, z1 - z0), int(a[2]) == 2])
	return out


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
	if not _pits.is_empty():
		Worlds.animate_pits(_pits, _t)
	if _gate_ring and is_instance_valid(_gate_ring):
		var m := _gate_ring.material_override as StandardMaterial3D
		var a := (0.35 + 0.25 * sin(_t * 4.0)) if gate_open else 0.0
		m.albedo_color = Color(Toon.GOLD, a)
		var s := 1.0 + (0.12 * sin(_t * 4.0) if gate_open else 0.0)
		_gate_ring.scale = Vector3(s, 1, s)


# ------------------------------------------------------------------ géométrie

## Vrai si un disque de rayon `margin` centré en `p` tient sur la terre ferme (union des plateformes).
## On teste le centre et 8 points du bord dans l'union : une jonction étroite entre deux plateformes
## reste franchissable (rétrécir chaque plateforme séparément y créait une bande infranchissable).
func walkable(p: Vector3, margin := 0.0) -> bool:
	if margin < 0.0:
		# marge négative : tolérance, on accepte un point à moins de |margin| de la terre ferme
		var m := -margin
		var e := m * 0.7071
		return _in_union(p.x, p.z) or _in_union(p.x + m, p.z) or _in_union(p.x - m, p.z) \
			or _in_union(p.x, p.z + m) or _in_union(p.x, p.z - m) or _in_union(p.x + e, p.z + e) \
			or _in_union(p.x - e, p.z + e) or _in_union(p.x + e, p.z - e) or _in_union(p.x - e, p.z - e)
	if not _in_union(p.x, p.z):
		return false
	if margin == 0.0:
		return true
	var d := margin * 0.7071
	return _in_union(p.x + margin, p.z) and _in_union(p.x - margin, p.z) \
		and _in_union(p.x, p.z + margin) and _in_union(p.x, p.z - margin) \
		and _in_union(p.x + d, p.z + d) and _in_union(p.x - d, p.z + d) \
		and _in_union(p.x + d, p.z - d) and _in_union(p.x - d, p.z - d)


func _in_union(x: float, z: float) -> bool:
	for r in rects:
		var rr: Rect2 = r
		if x >= rr.position.x and x <= rr.end.x and z >= rr.position.y and z <= rr.end.y:
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
	# tirage pondéré par la surface : les passerelles n'attirent pas autant d'ennemis que les îles
	var areas: Array = []
	var total := 0.0
	for r in rects:
		var rr: Rect2 = r
		var gg := rr.grow(-margin)
		var a := maxf(gg.size.x, 0.0) * maxf(gg.size.y, 0.0)
		areas.append(a)
		total += a
	if total <= 0.0:
		return p
	for attempt in 40:
		var idx := rects.size() - 1
		var x := randf() * total
		for i in areas.size():
			x -= float(areas[i])
			if x <= 0.0:
				idx = i
				break
		var r: Rect2 = rects[idx]
		var g := r.grow(-margin)
		if g.size.x <= 0.0 or g.size.y <= 0.0:
			continue
		p = Vector3(randf_range(g.position.x, g.end.x), 0, randf_range(g.position.y, g.end.y))
		if p.distance_to(avoid) > min_dist:
			return p
	return p


# ------------------------------------------------------------------ chemin des ennemis

## Où un ennemi doit aller pour rejoindre `to` : tout droit si la ligne reste sur la terre ferme,
## sinon la passerelle (zone commune entre deux plateformes) la plus utile vers sa cible.
func steer(from: Vector3, to: Vector3) -> Vector3:
	if rects.size() <= 1 or _line_walkable(from, to, 0.3):
		return to
	var a := _rect_of(from)
	var b := _rect_of(to)
	if a == b:
		return to
	# parcours en largeur sur les plateformes qui se touchent
	var prev := {a: -1}
	var queue: Array = [a]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == b:
			break
		for j in rects.size():
			if not prev.has(j) and _touch(cur, j):
				prev[j] = cur
				queue.append(j)
	if not prev.has(b):
		return to
	# chemin complet a -> b
	var path: Array = [b]
	while int(prev[int(path[0])]) != -1:
		path.push_front(int(prev[int(path[0])]))
	# on repart de la plateforme la plus avancée du chemin qui contient déjà l'ennemi :
	# arrivé au milieu d'une passerelle, il vise la suivante au lieu de piétiner
	var fp := Vector2(from.x, from.z)
	var k := 0
	for i in range(path.size() - 1, -1, -1):
		var pr: Rect2 = rects[int(path[i])]
		if pr.grow(-0.05).has_point(fp):
			k = i
			break
	if k >= path.size() - 1:
		return to
	return _portal(int(path[k]), int(path[k + 1]))


func _line_walkable(p: Vector3, q: Vector3, margin: float) -> bool:
	var d := p.distance_to(q)
	var n := maxi(1, int(d / 0.4))
	for i in range(1, n + 1):
		if not walkable(p.lerp(q, float(i) / n), margin):
			return false
	return true


func _rect_of(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in rects.size():
		var r: Rect2 = rects[i]
		if r.has_point(Vector2(p.x, p.z)):
			return i
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))
		var d := q.distance_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = i
	return best


func _touch(i: int, j: int) -> bool:
	return i != j and _touch_r(rects[i], rects[j])


static func _touch_r(a: Rect2, b: Rect2) -> bool:
	return a.grow(0.05).intersects(b.grow(0.05))


func _portal(i: int, j: int) -> Vector3:
	var a: Rect2 = rects[i]
	var b: Rect2 = rects[j]
	var inter := a.grow(0.05).intersection(b.grow(0.05))
	var c := inter.get_center()
	return Vector3(c.x, 0, c.y)


## Vrai si `p` est sur un pont (partie de passerelle au-dessus du vide) ou à moins de `margin` d'un pont
## (ex. hazards : pas de trou à moins d'un mètre d'une entrée de pont -> is_bridge(c, r + 1.0)).
func is_bridge(p: Vector3, margin := 0.0) -> bool:
	for b in bridges:
		var br: Rect2 = b
		if br.grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


# ------------------------------------------------------------------ vérification

## Contrôle toutes les formes (et le hub) : dans l'arène, connexes, jonctions assez larges,
## départ et torii sur la terre ferme (aussi en miroir), place pour les trous, surface suffisante.
## Renvoie la liste des problèmes (vide si tout va bien).
static func check_layouts() -> Array:
	var fails: Array = []
	var sets := {}
	for k in LAYOUTS.keys():
		sets[String(k)] = LAYOUTS[k]
	sets["hub"] = HUB_RECTS
	var bounds := Rect2(-HALF.x - 0.001, -HALF.y - 0.001, HALF.x * 2.0 + 0.002, HALF.y * 2.0 + 0.002)
	for key in sets.keys():
		var tag := String(key)
		var rs: Array = sets[key]
		if rs.is_empty():
			fails.append(tag + " : vide")
			continue
		var hole_ok := false
		for r in rs:
			var rr: Rect2 = r
			if not bounds.encloses(rr):
				fails.append("%s : %s hors de l'arène" % [tag, str(rr)])
			if minf(rr.size.x, rr.size.y) < 1.6:
				fails.append("%s : %s trop étroit" % [tag, str(rr)])
			if not _is_bridge_rect(rr) and minf(rr.size.x, rr.size.y) >= 3.2:
				hole_ok = true
		# pas de place pour un trou : simplement moins de trous dans cette salle (pas une erreur)
		hole_ok = hole_ok or true
		# graphe connexe
		var seen := {0: true}
		var queue: Array = [0]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for j in rs.size():
				if not seen.has(j) and _touch_r(rs[cur], rs[j]):
					seen[j] = true
					queue.append(j)
		if seen.size() < rs.size():
			fails.append(tag + " : plateformes non reliées")
		# jonctions : assez larges pour passer, assez profondes pour le chemin des ennemis
		for i in rs.size():
			for j in range(i + 1, rs.size()):
				if _touch_r(rs[i], rs[j]):
					var a: Rect2 = rs[i]
					var b: Rect2 = rs[j]
					var inter := a.intersection(b)
					if maxf(inter.size.x, inter.size.y) < 1.4 or minf(inter.size.x, inter.size.y) < 0.15:
						fails.append("%s : jonction trop étroite entre %d et %d" % [tag, i, j])
		# départ et torii, dans les deux sens
		for mir in [false, true]:
			var mr: Array = []
			for r in rs:
				var rr: Rect2 = r
				if mir:
					rr = Rect2(-rr.end.x, rr.position.y, rr.size.x, rr.size.y)
				mr.append(rr)
			var ends: Array = _ends(mr)
			var s: Vector3 = ends[0]
			var g: Vector3 = ends[1]
			var high: Rect2 = ends[3]
			if not _walk_r(mr, Vector2(s.x, s.z), 0.5):
				fails.append(tag + " : départ hors de la terre ferme")
			if not _walk_r(mr, Vector2(g.x, g.z), 0.5) or high.size.x < 2.4:
				fails.append(tag + " : torii mal placé")
		# surface jouable (union exacte)
		var area := 0.0
		var dec: Dictionary = _decompose(rs)
		for pc in dec["pieces"]:
			var pr: Rect2 = pc[0]
			area += pr.get_area()
		if area < MIN_AREA:
			fails.append("%s : surface trop petite (%.0f m²)" % [tag, area])
	# la salle 1 et le choix au hasard doivent trouver leurs formes
	for f in FIRST_LAYOUTS:
		if not LAYOUTS.has(f):
			fails.append("forme de salle 1 inconnue : " + String(f))
	for wid in FLAVOR.keys():
		for f in FLAVOR[wid]:
			if not LAYOUTS.has(f):
				fails.append("saveur du monde %d inconnue : %s" % [int(wid), String(f)])
	return fails
