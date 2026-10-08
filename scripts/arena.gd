extends Node3D
## Terrain de jeu, en trois formes : étape longue (build_stage : tronçons empilés vers le fond, zones de combat
## fermées par des haies sacrées, recoins), arène unique (build_room : gardien et boss, formes LAYOUTS)
## et sanctuaire de départ (build_hub : place, dojo, torii). Chaque forme jouable est une union de rectangles,
## avec son sol selon le monde, son décor et le torii de sortie qui s'allume quand le combat est fini.
## Le vide (eau, lave, encre…) se comporte comme un trou : on peut tracer au-dessus, pas y finir.
## Les tronçons d'étape mêlent les formes fixes et des formes générées (GEN : places octogonales, L, T,
## escaliers, îles, chemins qui se séparent, pont cassé…) ; des pièces de décor du monde (bateaux, bosquets,
## étangs gelés…) y bloquent la marche : `rects` est le sol praticable, `floor_rects` le sol dessiné.

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")
const Worlds = preload("res://scripts/worlds.gd")

const HALF := Vector2(4.6, 8.6)  # bornes de l'arène (comme main.gd)

signal perf(label: String, usec: int)  # mesure d'une construction différée (robot du CI : « BOT PERF »)

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
	6: ["stairs", "terraces", "ell", "twin"],
	7: ["pond", "moat", "ring", "islands"],
	8: ["hourglass", "cross", "zigzag", "spine"],
}
const MAX_USES := 2  # une forme au plus deux fois par partie
const MAX_USES_GEN := 3  # forme générée : tirée au hasard à chaque fois, elle peut revenir un peu plus
# formes générées des étapes : famille (jamais deux fois de suite) et palier (0 simple -> 2 morcelée)
const GEN := {
	"g_oct": {"fam": "plaza", "tier": 0},
	"g_twin_oct": {"fam": "plaza2", "tier": 1},
	"g_ell": {"fam": "ell", "tier": 0},
	"g_tee": {"fam": "tee", "tier": 0},
	"g_plus": {"fam": "plus", "tier": 1},
	"g_diag": {"fam": "diag", "tier": 1},
	"g_terrace": {"fam": "terrace", "tier": 0},
	"g_alcove": {"fam": "alcove", "tier": 1},
	"g_isles": {"fam": "isles", "tier": 1},
	"g_split": {"fam": "split", "tier": 2},
	"g_broken": {"fam": "broken", "tier": 2},
}
const SIDED := ["g_ell", "g_diag", "g_broken"]  # formes à côté d'entrée : on les retourne vers le passage d'arrivée
# formes fixes : [famille, palier]
const LAYOUT_FAM := {
	"full": ["open", 0], "islands": ["isles", 1], "cross": ["plus", 0], "ring": ["ring", 2], "zigzag": ["diag", 1],
	"hourglass": ["neck", 1], "twin": ["twin", 1], "pond": ["ring", 0], "terraces": ["terrace", 0], "ell": ["ell", 1],
	"stairs": ["diag", 1], "diamond": ["isles", 2], "spine": ["alcove", 1], "quad": ["isles", 2], "moat": ["ring", 2],
}
const RING_LIKE := ["ring", "pond", "moat", "islands"]  # anneau autour d'une fosse, longue jetée : moins souvent
const PIECE_GAP := 1.6  # passage laissé autour d'une pièce de décor, dans chaque plateforme qu'elle touche
const BRIDGE_W := 2.7  # un rectangle plus étroit que ça est une passerelle (pont de bois au-dessus du vide)
const WOOD := [Color("#8E6B3E"), Color("#A88452"), Color("#7A5A34")]
const MIN_AREA := 70.0  # surface jouable minimale d'une forme (m²)

# hub de départ : place (0), dojo (1), passerelle dojo-place (2), chemin de planches (3), sanctuaire du torii (4)
const HUB_RECTS := [Rect2(-4.6, 2.0, 9.2, 6.6), Rect2(-4.6, -4.0, 5.2, 5.4), Rect2(-3.2, 0.8, 2.4, 1.8),
	Rect2(1.6, -6.0, 2.4, 8.6), Rect2(-1.0, -8.6, 5.6, 3.2)]
const HUB_DOJO := 1

# étapes (expéditions) : plusieurs tronçons de la taille d'une salle, empilés vers le fond (z négatif)
const CHUNK_L := 17.2  # profondeur d'un tronçon (= HALF.y * 2)
const JOIN_MIN := 2.2  # passage minimal entre deux tronçons
const JOIN_PIECE := 1.6  # tout morceau de passage plus étroit est refusé
const ENTER_IN := 1.4  # on entre dans une zone de combat à cette distance de son bord sud

var world_id := 0
var stage := false  # vrai : étape longue (tronçons + zones de combat) ; faux : salle unique
var chunks := 1
var zones: Array = []  # zones de combat (Rect2), du sud vers le nord ; la zone i occupe le tronçon i + 1
var zone_state: Array = []  # 0 = à venir, 1 = combat, 2 = nettoyée
var stage_rect := Rect2(-4.6, -8.6, 9.2, 17.2)  # toute l'étape
var bounds := Rect2(-4.6, -8.6, 9.2, 17.2)  # là où héros et ennemis peuvent aller en ce moment
var pocket_spots: Array = []  # recoin de chaque tronçon (Vector3.INF : aucun)
var joins: Array = []  # passages entre tronçons j et j + 1 : [Vector2(x0, x1), …]
var _act: Array = []  # plateformes qui touchent `bounds` (tests rapides)
var _barriers: Array = []  # {j, node, k, want, mode, …} : haies sacrées aux passages
var _bar_meshes := {}  # maillages partagés des haies (bambou, traverse, tache, goutte, ofuda par monde)
var _bar_noise: NoiseTexture2D = null  # texture de la brume des haies
var _pending: Array = []  # tronçons dont le décor reste à construire (un morceau par image)
var _pending_us := 0  # temps passé sur le décor différé de l'étape (mesure)
var _pending_max := 0
var _pit_states: Array = []
var _stage_seed := 0
var hub_training_center := Vector3(-2.0, 0, -1.1)
var hub_training_radius := 2.0
var pieces: Array = []  # sol découpé sans recouvrement : [Rect2, passerelle ?]
var bridges: Array = []  # morceaux de passerelle au-dessus du vide (Rect2)
var layout := "full"
var mirrored := false
var rects: Array = []  # sol praticable (étape : découpé autour des pièces de décor)
var floor_rects: Array = []  # sol dessiné (sans découpe)
var set_pieces: Array = []  # pièces de décor posées sur la terre ferme : [Rect2 empreinte, nom, tronçon, quart de tour ?]
var _steps: Array = []  # marches peintes entre terrasses : Vector3(x0, x1, z)
var _gaps: Array = []  # trouées des ponts cassés (Rect2) : planches à la dérive
var _stage_n := 0  # rang de l'étape dans le monde (formes plus morcelées ensuite)
var _adj: Array = []  # voisinage des plateformes de `_act` (chemin des ennemis), calculé à la demande
var _used := {}  # forme -> nombre d'utilisations pendant la partie
var _last := ""  # dernière forme hors boss
var start := Vector3(0, 0, 6.1)
var gate_pos := Vector3(0, 0, -8.0)
var gate_open := false

var _world_root: Node3D
var _world_holder: Node3D = null  # vide + lointain du monde affiché
var _worlds_kept := {}  # monde quitté -> [racine cachée, matériau du vide, lointain]
const GROUND_SHADER = preload("res://shaders/ground.gdshader")
static var _mat_cache := {}  # matériaux des sols, bords et dessous, partagés d'une salle à l'autre (jamais modifiés)
static var _unit_tile: BoxMesh = null
static var _unit_lump: SphereMesh = null
var _far_root: Node3D  # lointain et particules : suivent la caméra le long de l'étape
var _room_root: Node3D
var _gate: Node3D
# éveil du torii (open_gate) : sceaux, corde, shide, rayons, lucioles, chemin d'encre
var _gate_t := -1.0
var _gate_flash := 0.0
var _gate_seals: Array = []  # [MeshInstance3D, matériau, délai]
var _gate_shide: Array = []  # [pivot, phase]
var _gate_dots: Array = []  # [MeshInstance3D, délai, taille]
var _gate_rope_mat: StandardMaterial3D
var _gate_ray_mat: StandardMaterial3D
var _gate_rays: MeshInstance3D
var _gate_motes: CPUParticles3D
var _void_mat: ShaderMaterial
var _t := 0.0
var _batches := {}  # matériau -> transformations des tuiles du sol
var _sbatches := {}  # matériau -> transformations des bosses (sphères) du sol
var _ink_mat: StandardMaterial3D = null  # traits d'encre sèche du sol de papier
var _deco_rng := RandomNumberGenerator.new()  # habillage du sol (n'entame pas les tirages de la salle)
var _accent_mat: Material = null  # planches de laque rares (accent du monde), null : aucune
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
## Le monde quitté reste en mémoire, caché (un seul) : y revenir ne reconstruit rien.
func set_world(id: int) -> void:
	if id == world_id:
		return
	var prev := world_id
	var back: Array = _worlds_kept.get(id, [])
	_worlds_kept.erase(id)
	for k in _worlds_kept.keys():
		var old: Array = _worlds_kept[k]
		if is_instance_valid(old[0]):
			old[0].queue_free()
	_worlds_kept.clear()
	if is_instance_valid(_world_holder):
		_world_holder.visible = false
		_world_holder.process_mode = Node.PROCESS_MODE_DISABLED
		_worlds_kept[prev] = [_world_holder, _void_mat, _far_root]
	world_id = id
	if not back.is_empty() and is_instance_valid(back[0]):
		_world_holder = back[0]
		_void_mat = back[1]
		_far_root = back[2]
		_world_holder.visible = true
		_world_holder.process_mode = Node.PROCESS_MODE_INHERIT
		_push_shore()
		return
	_world_holder = Node3D.new()
	_world_root.add_child(_world_holder)
	# eau d'estampe (shaders/water.gdshader) : lavis de profondeur, rubans de vague, écume au pied du cadre
	_void_mat = Worlds.water_material(id)
	_push_shore()
	var v := Toon.part(_world_holder, Toon.box(Vector3(600, 0.1, 600)), _void_mat, Vector3(0, -0.6, 0))
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# le lointain est peint pour une caméra au-dessus de la salle : il la suit le long de l'étape
	_far_root = Node3D.new()
	_world_holder.add_child(_far_root)
	Worlds.build_backdrop(id, _far_root)
	Worlds.build_particles(id, _far_root)


## Décalage de la caméra le long de l'étape (main) : le lointain garde son cadrage.
func follow_camera(dz: float) -> void:
	if _far_root != null and is_instance_valid(_far_root):
		_far_root.position.z = dz


## Cadre de l'arène (ou de l'étape) transmis à l'eau : l'écume lèche le pied des plateformes.
func _push_shore() -> void:
	if _void_mat == null:
		return
	_void_mat.set_shader_parameter("shore_rect", Vector4(stage_rect.position.x, stage_rect.position.y, stage_rect.end.x, stage_rect.end.y))


## Construit la salle : forme, sol, bords, décor, torii de sortie (caché).
func build_room(room: int, rooms: int, rng_seed: int, mini_room := 8) -> void:
	_clear_room()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	layout = _pick_layout(room, rooms, mini_room, rng)
	# miroir gauche/droite (sans effet sur les formes symétriques), jamais pour un boss
	mirrored = layout != BOSS_LAYOUT and rng.randf() < 0.5
	rects = _layout_rects(layout, mirrored)
	floor_rects = rects
	_single_frame()
	_finish_room(Worlds.world(world_id), rng, rng_seed)


## Oublie la salle ou l'étape précédente (décor, haies, zones).
func _clear_room() -> void:
	for ch in _room_root.get_children():
		ch.queue_free()
	_pending.clear()
	_pending_us = 0
	_pending_max = 0
	_barriers.clear()
	_pit_states.clear()
	_pits = {}
	stage = false
	chunks = 1
	zones = []
	zone_state = []
	pocket_spots = []
	joins = []
	set_pieces = []
	_steps = []
	_gaps = []


## Salle unique : cadre classique autour de l'origine (boss, hub, tutoriel).
func _single_frame() -> void:
	stage_rect = Rect2(-HALF.x, -HALF.y, HALF.x * 2.0, HALF.y * 2.0)
	_set_bounds(stage_rect)
	_push_shore()


## Cadre de déplacement courant ; on garde à part les plateformes qui le touchent (tests rapides).
func _set_bounds(b: Rect2) -> void:
	bounds = b
	_act = []
	_adj = []
	for r in rects:
		var rr: Rect2 = r
		var ri := rr.intersection(b)
		if ri.size.x > 0.01 and ri.size.y > 0.01:
			_act.append(rr)


# ------------------------------------------------------------------ étapes

## Étape (expédition) : un tronçon d'arrivée calme puis `n_enc` tronçons, chacun une zone de combat,
## empilés vers le fond. Passages larges entre tronçons, haies d'encre qui ferment les zones,
## torii de sortie au nord du dernier tronçon. `first` : première étape du monde (formes faciles au départ).
## Les formes générées et les pièces de décor tirent à part (`grng`) : la suite de `rng` garde son ordre.
func build_stage(n_enc: int, rng_seed: int, first: bool) -> void:
	_clear_room()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_stage_seed = rng_seed
	var grng := RandomNumberGenerator.new()
	grng.seed = rng_seed + 104729
	if first:
		_used.clear()
		_last = ""
		_stage_n = 0
	else:
		_stage_n += 1
	stage = true
	chunks = maxi(1, n_enc) + 1
	rects = []
	layout = ""
	var prev: Array = []
	var per_chunk: Array = []
	var fams := {}  # familles déjà vues dans l'étape
	var last_fam := ""
	for i in chunks:
		var key := ""
		var mir := false
		var local: Array = []
		var extra: Dictionary = {}
		if i == 0 and first:
			key = String(FIRST_LAYOUTS[rng.randi() % FIRST_LAYOUTS.size()])
			mir = rng.randf() < 0.5
			local = _layout_rects(key, mir)
		else:
			var run := _entry_run(prev)
			for attempt in 12:
				key = _pick_chunk(rng, i, fams, last_fam)
				mir = rng.randf() < 0.5
				if GEN.has(key):
					mir = false  # la forme générée choisit elle-même ses côtés
					extra = _gen_layout(key, grng, run)
					var gl: Array = extra["rects"]
					local = gl
				else:
					extra = {}
					local = _layout_rects(key, mir)
				if not local.is_empty() and (prev.is_empty() or not _join_pieces(prev, local).is_empty()):
					break
				key = ""
			if key == "":
				# repli sûr : la forme pleine se raccorde à toutes les autres
				key = BOSS_LAYOUT
				mir = false
				extra = {}
				local = _layout_rects(key, mir)
		_used[key] = int(_used.get(key, 0)) + 1
		_last = key
		last_fam = _family(key)
		fams[last_fam] = true
		if not prev.is_empty():
			joins.append(_join_pieces(prev, local))
		layout += ("" if i == 0 else "+") + key + ("~" if mir else "")
		var dz := -float(i) * CHUNK_L
		var mine: Array = []
		for r in local:
			var rr: Rect2 = r
			mine.append(Rect2(rr.position.x, rr.position.y + dz, rr.size.x, rr.size.y))
		per_chunk.append(mine)
		rects.append_array(mine)
		# marches peintes et trouées de pont cassé de la forme générée
		if not extra.is_empty():
			for s in extra["steps"]:
				var sv: Vector3 = s
				_steps.append(Vector3(sv.x, sv.y, sv.z + dz))
			for gp in extra["gaps"]:
				var gr: Rect2 = gp
				_gaps.append(Rect2(gr.position.x, gr.position.y + dz, gr.size.x, gr.size.y))
		prev = local
	floor_rects = rects.duplicate()
	mirrored = false
	var top := -HALF.y - float(chunks - 1) * CHUNK_L
	stage_rect = Rect2(-HALF.x, top, HALF.x * 2.0, HALF.y - top)
	_push_shore()
	zones = []
	zone_state = []
	for i in range(1, chunks):
		zones.append(Rect2(-HALF.x, -HALF.y - float(i) * CHUNK_L, HALF.x * 2.0, CHUNK_L))
		zone_state.append(0)
	_set_bounds(_roam_bounds())
	var w: Dictionary = Worlds.world(world_id)
	_build_floor(w, rng)
	_flush_tiles()
	var ends: Array = _ends(floor_rects)
	start = ends[0]
	gate_pos = ends[1]
	_build_gate(w)
	# recoins à l'écart du chemin, un par tronçon (tests sur toute l'étape)
	_set_bounds(stage_rect)
	pocket_spots = []
	for i in chunks:
		pocket_spots.append(_pocket_spot(per_chunk[i], -float(i) * CHUNK_L, rng))
	# pièces de décor sur la terre ferme : elles découpent le sol praticable (`rects`)
	_place_set_pieces(per_chunk, grng, first)
	var chunk_pieces: Array = []
	for i in chunks:
		chunk_pieces.append([])
	for sp in set_pieces:
		var spa: Array = sp
		var fp: Rect2 = spa[0]
		var ci: int = spa[2]
		var lst: Array = chunk_pieces[ci]
		lst.append([Rect2(fp.position.x, fp.position.y + float(ci) * CHUNK_L, fp.size.x, fp.size.y), spa[1], spa[3]])
	_set_bounds(_roam_bounds())
	# haies d'encre aux passages entre tronçons
	for j in joins.size():
		_build_barrier(j)
	refresh_barriers(true)
	# décor et fosses : les deux premiers tronçons tout de suite, les suivants une image après l'autre
	# (et en deux temps : décor, puis fosses, pour de plus petites images)
	var high: Rect2 = ends[3]
	for i in chunks:
		var job := {"i": i, "rs": per_chunk[i], "high": high if i == chunks - 1 else Rect2(), "pieces": chunk_pieces[i]}
		if i < 2:
			_build_chunk_decor(job)
		else:
			var props := job.duplicate()
			props["part"] = "props"
			_pending.append(props)
			var pits := job.duplicate()
			pits["part"] = "pits"
			_pending.append(pits)


## Décor (props hors du cadre de l'étape) et fosses (vides du tronçon), en coordonnées du tronçon.
## `job.part` : "props" ou "pits" pour n'en construire qu'une moitié (sinon les deux).
func _build_chunk_decor(job: Dictionary) -> void:
	var i: int = job["i"]
	var part := String(job.get("part", ""))
	var dz := -float(i) * CHUNK_L
	var holder := Node3D.new()
	holder.position = Vector3(0, 0, dz)
	_room_root.add_child(holder)
	var seed_i := _stage_seed + i * 7919
	if part != "pits":
		_chunk_props(job, holder, dz, seed_i)
	if part != "props":
		_chunk_pits(job, holder, dz, seed_i)


func _chunk_props(job: Dictionary, holder: Node3D, dz: float, seed_i: int) -> void:
	var frame := Rect2(stage_rect.position.x, stage_rect.position.y - dz + 0.01, stage_rect.size.x, stage_rect.size.y - 0.01)
	var prs: Array = []
	var high: Rect2 = job["high"]
	if high.has_area():
		prs.append(Rect2(high.position.x, high.position.y - dz, high.size.x, high.size.y))
	prs.append(frame)
	# une seule lumière ponctuelle par tronçon (une étape en compte 3 ou 4 à l'écran au plus) ;
	# les pièces de décor du tronçon partagent les lots (matériaux) du décor
	var pcs: Array = job.get("pieces", [])
	Worlds.build_props(world_id, holder, prs, seed_i, Rect2(-HALF.x, -HALF.y, HALF.x * 2.0, HALF.y * 2.0), 1, pcs)


func _chunk_pits(job: Dictionary, holder: Node3D, dz: float, seed_i: int) -> void:
	var local: Array = []
	for r in job["rs"]:
		var rr: Rect2 = r
		local.append(Rect2(rr.position.x, rr.position.y - dz, rr.size.x, rr.size.y))
	var ps: Dictionary = Worlds.build_pits(world_id, holder, local, void_rects(local), seed_i)
	if not ps.is_empty():
		_pit_states.append(ps)


## Morceaux de passage (Vector2(x0, x1)) entre le bord nord du tronçon `lower` et le bord sud de `upper`
## (coordonnées locales) ; vide si le passage est trop étroit ou qu'un morceau l'est.
static func _join_pieces(lower: Array, upper: Array) -> Array:
	var a := _edge_runs(lower, true)
	var b := _edge_runs(upper, false)
	var out: Array = []
	var best := 0.0
	for ia in a:
		var va: Vector2 = ia
		for ib in b:
			var vb: Vector2 = ib
			var x0 := maxf(va.x, vb.x)
			var x1 := minf(va.y, vb.y)
			if x1 - x0 <= 0.01:
				continue
			if x1 - x0 < JOIN_PIECE:
				return []
			out.append(Vector2(x0, x1))
			best = maxf(best, x1 - x0)
	if best < JOIN_MIN:
		return []
	return out


## Intervalles en x (fusionnés) des plateformes qui touchent le bord nord (`north`) ou sud du tronçon.
static func _edge_runs(rs: Array, north: bool) -> Array:
	var iv: Array = []
	for r in rs:
		var rr: Rect2 = r
		if (north and rr.position.y <= -HALF.y + 0.01) or (not north and rr.end.y >= HALF.y - 0.01):
			iv.append(Vector2(rr.position.x, rr.end.x))
	iv.sort_custom(func(p, q): return p.x < q.x)
	var out: Array = []
	for v in iv:
		var vv: Vector2 = v
		if not out.is_empty():
			var lastv: Vector2 = out[out.size() - 1]
			if vv.x <= lastv.y + 0.01:
				out[out.size() - 1] = Vector2(lastv.x, maxf(lastv.y, vv.y))
				continue
		out.append(vv)
	return out


## Recoin d'un tronçon : point de terre ferme le plus à l'écart de l'axe, loin des passages et du torii.
func _pocket_spot(rs: Array, dz: float, rng: RandomNumberGenerator) -> Vector3:
	var best := Vector3.INF
	var best_s := -INF
	for attempt in 28:
		var r: Rect2 = rs[rng.randi() % rs.size()]
		if _is_bridge_rect(r):
			continue
		var g := r.grow(-0.9)
		if g.size.x <= 0.0 or g.size.y <= 0.0:
			continue
		var p := Vector3(rng.randf_range(g.position.x, g.end.x), 0, rng.randf_range(g.position.y, g.end.y))
		var lz := p.z - dz
		if absf(lz) > HALF.y - 2.4 or p.distance_to(start) < 3.5 or p.distance_to(gate_pos) < 3.5:
			continue
		if not walkable(p, 0.7) or is_bridge(p, 1.0):
			continue
		var s := absf(p.x) + rng.randf() * 0.8
		if s > best_s:
			best_s = s
			best = p
	return best


## Haie sacrée d'un passage : palissade basse de bambous liés, shimenawa lumineuse et ofuda,
## voile de brume d'encre derrière. Ici on ne fait que la tracer (données) ; les nœuds sont créés
## quand elle se ferme (_barrier_show) et libérés quand elle s'est ouverte.
func _build_barrier(j: int) -> void:
	var zb := -HALF.y - float(j) * CHUNK_L
	var rng := RandomNumberGenerator.new()
	rng.seed = _stage_seed + j * 131
	var sty: Dictionary = _barrier_style()
	var pole_c: Color = sty["pole"]
	var xmin := INF
	var xmax := -INF
	for pc in joins[j]:
		var pv: Vector2 = pc
		xmin = minf(xmin, pv.x)
		xmax = maxf(xmax, pv.y)
	var span := maxf(xmax - xmin, 0.5)
	var poles: Array = []  # [Transform3D de base, hauteur, délai, teinte]
	var rails: Array = []  # [x0, x1, y, z]
	var ropes: Array = []  # PackedVector3Array par morceau
	var ofuda: Array = []  # [point d'attache, phase, délai]
	var blots: Array = []  # [Transform3D, délai]
	var drops: Array = []  # [origine, vitesse, délai]
	var rope_y := 0.76
	for pc in joins[j]:
		var piece: Vector2 = pc
		var w := piece.y - piece.x
		# palissade : bambous hauts et bas en alternance, sur la ligne du bord
		var n := maxi(4, int((w - 0.24) / 0.19))
		for k in n + 1:
			var x := lerpf(piece.x + 0.12, piece.y - 0.12, float(k) / float(n))
			var h: float = 1.05 + rng.randf_range(-0.05, 0.05) if k % 2 == 0 else 0.88 + rng.randf_range(-0.03, 0.04)
			var tb := Basis(Vector3(0, 0, 1), rng.randf_range(-0.05, 0.05)) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.05, 0.05))
			var z := rng.randf_range(-0.03, 0.03)
			var d := 0.44 * (x - xmin) / span + rng.randf_range(0.0, 0.04)
			var c: Color = pole_c.lightened(rng.randf_range(0.0, 0.14)) if rng.randf() < 0.5 else pole_c.darkened(rng.randf_range(0.0, 0.14))
			poles.append([Transform3D(tb, Vector3(x, 0, z)), h, d, c])
			if k % 2 == 0:
				var bb := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(rng.randf_range(0.14, 0.24), 1, rng.randf_range(0.09, 0.16)))
				blots.append([Transform3D(bb, Vector3(x + rng.randf_range(-0.05, 0.05), 0.014, z + rng.randf_range(-0.02, 0.1))), d])
				for _q in 2:
					drops.append([Vector3(x, 0.06, z + 0.03), Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(1.1, 1.9), rng.randf_range(0.1, 0.8)), d])
		rails.append([piece.x + 0.06, piece.y - 0.06, 0.24, 0.055])
		rails.append([piece.x + 0.06, piece.y - 0.06, 0.56, 0.055])
		# shimenawa en festons, ofuda suspendus au creux de chaque feston
		var spans := maxi(1, roundi((w - 0.24) / 1.15))
		var path := PackedVector3Array()
		for sp in spans:
			var xa := lerpf(piece.x + 0.12, piece.y - 0.12, float(sp) / float(spans))
			var xb := lerpf(piece.x + 0.12, piece.y - 0.12, float(sp + 1) / float(spans))
			var sag := 0.05 + 0.04 * (xb - xa)
			for q in 9:
				if sp > 0 and q == 0:
					continue
				var tq := float(q) / 8.0
				path.append(Vector3(lerpf(xa, xb, tq), rope_y - sag * sin(PI * tq), 0.1))
			var no: int = 1 if xb - xa < 0.9 else 2
			for oi in no:
				var to := (float(oi) + 1.0) / float(no + 1)
				ofuda.append([Vector3(lerpf(xa, xb, to), rope_y - sag * sin(PI * to) - 0.025, 0.14), rng.randf_range(0.0, TAU), rng.randf_range(0.0, 0.12)])
		ropes.append(path)
	_barriers.append({"j": j, "node": null, "k": 0.0, "want": 0.0, "mode": "", "zb": zb, "poles": poles,
		"rails": rails, "ropes": ropes, "ofuda": ofuda, "blots": blots, "drops": drops, "mist": joins[j]})


## Teintes d'une haie selon le monde.
func _barrier_style() -> Dictionary:
	match world_id:
		2:  # bambouseraie de Tanabata
			return {"pole": Color("#6F9B4C"), "rope": Color("#D8C084"), "glow": Color("#FFE7A6"), "glow_e": 0.75,
				"paper": Color("#F3ECD8"), "stripe": Color("#C8342A"), "ink": Color("#15211C"),
				"mist": Color("#A9CFC2"), "mist_a": 0.3, "burn": Color("#FF9A45")}
		3:  # corde de givre
			return {"pole": Color("#A7BAC6"), "rope": Color("#DDEFF8"), "glow": Color("#8FD6FF"), "glow_e": 0.95,
				"paper": Color("#F4F8FB"), "stripe": Color("#1F3A5F"), "ink": Color("#22303E"),
				"mist": Color("#F2F7FB"), "mist_a": 0.5, "burn": Color("#9FE0FF")}
		4:  # braises du Fuji
			return {"pole": Color("#4A3530"), "rope": Color("#C99A60"), "glow": Color("#FF6A24"), "glow_e": 1.15,
				"paper": Color("#F0E2C8"), "stripe": Color("#D7372B"), "ink": Color("#1A1010"),
				"mist": Color("#7A3A2A"), "mist_a": 0.36, "burn": Color("#FF7A2E")}
		5:  # monde d'encre
			return {"pole": Color("#2B2729"), "rope": Color("#EDE2C8"), "glow": Color("#FFF1D6"), "glow_e": 0.6,
				"paper": Color("#F5EEDD"), "stripe": Color("#D7372B"), "ink": Color("#0E0D10"),
				"mist": Color("#1B1A1E"), "mist_a": 0.34, "burn": Color("#FF8A3A")}
		6:  # cordes de Kurama, ofuda vermillon
			return {"pole": Color("#5A3A2A"), "rope": Color("#D8C084"), "glow": Color("#FFD27A"), "glow_e": 0.65,
				"paper": Color("#F3ECD8"), "stripe": Color("#B8352A"), "ink": Color("#1A1E1A"),
				"mist": Color("#C9D2BF"), "mist_a": 0.4, "burn": Color("#FF8A3A")}
		7:  # cordes d'algues du palais, lueur de perle
			return {"pole": Color("#B8452E"), "rope": Color("#6A8E5A"), "glow": Color("#9FF0E6"), "glow_e": 0.85,
				"paper": Color("#EAF4EE"), "stripe": Color("#C49A45"), "ink": Color("#10262A"),
				"mist": Color("#7FC0BE"), "mist_a": 0.36, "burn": Color("#7FE8FF")}
		8:  # cordes de Yomi, feu des âmes
			return {"pole": Color("#3A3440"), "rope": Color("#8E8A94"), "glow": Color("#C9B8FF"), "glow_e": 0.9,
				"paper": Color("#E8E2EE"), "stripe": Color("#5A3A7A"), "ink": Color("#0E0C10"),
				"mist": Color("#4A4452"), "mist_a": 0.42, "burn": Color("#B98AFF")}
	return {"pole": Color("#C2A66E"), "rope": Color("#D9C38C"), "glow": Color("#FFD98A"), "glow_e": 0.55,
		"paper": Color("#F4ECD8"), "stripe": Color("#D7372B"), "ink": Color("#1B1A1E"),
		"mist": Color("#E8EEF2"), "mist_a": 0.42, "burn": Color("#FF8A3A")}


## Maillages partagés des haies : bambou (nœuds), traverse (de x = 0 à 1), tache d'encre, goutte.
func _barrier_meshes() -> Dictionary:
	if _bar_meshes.has("pole"):
		return _bar_meshes
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(Toon.cyl(0.036, 0.046, 1.0, 7), 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
	st.append_from(Toon.cyl(0.052, 0.052, 0.035, 7), 0, Transform3D(Basis(), Vector3(0, 0.36, 0)))
	st.append_from(Toon.cyl(0.05, 0.05, 0.035, 7), 0, Transform3D(Basis(), Vector3(0, 0.7, 0)))
	_bar_meshes["pole"] = st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(Toon.cyl(0.024, 0.024, 1.0, 6), 0, Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), Vector3(0.5, 0, 0)))
	_bar_meshes["rail"] = st.commit()
	# tache d'encre au bord dentelé
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var seg := 14
	var rim: Array = []
	for i in seg:
		var a := TAU * float(i) / float(seg)
		var r: float = rng.randf_range(1.0, 1.35) if i % 3 == 0 else rng.randf_range(0.7, 1.0)
		rim.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for i in seg:
		for v in [Vector3.ZERO, rim[i], rim[(i + 1) % seg]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	_bar_meshes["blot"] = st.commit()
	var dm := SphereMesh.new()
	dm.radius = 0.032
	dm.height = 0.064
	dm.radial_segments = 6
	dm.rings = 3
	_bar_meshes["drop"] = dm
	return _bar_meshes


## Ofuda : bande de papier suspendue (pivot en haut), liseré, trait d'encre et sceau.
func _bar_ofuda_mesh(sty: Dictionary) -> ArrayMesh:
	var key: String = "ofuda" + str(world_id)
	if _bar_meshes.has(key):
		return _bar_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paper: Color = sty["paper"]
	var red: Color = sty["stripe"]
	_st_box(st, Vector3(0, -0.15, 0), Vector3(0.095, 0.3, 0.01), paper)
	_st_box(st, Vector3(0, -0.035, 0.0045), Vector3(0.097, 0.03, 0.005), red)
	_st_box(st, Vector3(0, -0.165, 0.0045), Vector3(0.016, 0.15, 0.004), Toon.SUMI)
	_st_box(st, Vector3(0, -0.12, 0.005), Vector3(0.05, 0.012, 0.004), Toon.SUMI)
	_st_box(st, Vector3(0, -0.268, 0.0045), Vector3(0.032, 0.032, 0.004), red)
	var m := st.commit()
	_bar_meshes[key] = m
	return m


## Pavé à couleur de sommet (faces dans le sens horaire vu de l'extérieur).
func _st_box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var fs: Array = [[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]
	for f in fs:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n * absf(n.dot(h))
		var du := u * absf(u.dot(h))
		var dv := v * absf(v.dot(h))
		for p in [o - du - dv, o - du + dv, o + du + dv, o - du - dv, o + du + dv, o + du - dv]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(p)


## Shimenawa : tube torsadé (bandes de couleur en spirale) le long de chaque tracé.
func _bar_rope_mesh(paths: Array, sty: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ca: Color = sty["rope"]
	var cb := ca.darkened(0.3)
	var sides := 6
	var r := 0.038
	for path in paths:
		var pts: PackedVector3Array = path
		var n := pts.size()
		if n < 2:
			continue
		var rings: Array = []
		var along := 0.0
		for i in n:
			if i > 0:
				along += pts[i].distance_to(pts[i - 1])
			var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var s1 := t.cross(Vector3.UP).normalized()
			var s2 := s1.cross(t)
			var ps := PackedVector3Array()
			var ns := PackedVector3Array()
			var cs := PackedColorArray()
			for q in sides:
				var a := TAU * float(q) / float(sides)
				var dir := s1 * cos(a) + s2 * sin(a)
				ps.append(pts[i] + dir * r)
				ns.append(dir)
				cs.append(ca.lerp(cb, 0.5 + 0.5 * sin(a * 2.0 + along * 30.0)))
			rings.append([ps, ns, cs])
		for i in n - 1:
			var ra: Array = rings[i]
			var rb: Array = rings[i + 1]
			for q in sides:
				var q1 := (q + 1) % sides
				_st_ring_v(st, ra, q)
				_st_ring_v(st, ra, q1)
				_st_ring_v(st, rb, q1)
				_st_ring_v(st, ra, q)
				_st_ring_v(st, rb, q1)
				_st_ring_v(st, rb, q)
	return st.commit()


func _st_ring_v(st: SurfaceTool, ring: Array, q: int) -> void:
	var ps: PackedVector3Array = ring[0]
	var ns: PackedVector3Array = ring[1]
	var cs: PackedColorArray = ring[2]
	st.set_color(cs[q])
	st.set_normal(ns[q])
	st.add_vertex(ps[q])


## Brume d'encre : trois voiles inclinés vers l'arrière, opacité en dégradé (bas doux, haut nul, bords fondus).
func _bar_mist_mesh(runs: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers: Array = [[1.05, -0.14, 1.0], [1.4, -0.34, 0.75], [1.75, -0.56, 0.55]]  # hauteur, recul, opacité
	var rows: Array = [0.0, 0.3, 1.0]
	var row_a: Array = [0.5, 1.0, 0.0]
	for pc in runs:
		var piece: Vector2 = pc
		for li in layers.size():
			var ly: Array = layers[li]
			var hh: float = ly[0]
			var z0: float = ly[1]
			var la: float = ly[2]
			var x0 := piece.x - 0.15 - 0.15 * float(li)
			var x1 := piece.y + 0.15 + 0.15 * float(li)
			var f := minf(0.7, (x1 - x0) * 0.3)
			var cols: Array = [x0, x0 + f, x1 - f, x1]
			var col_a: Array = [0.0, 1.0, 1.0, 0.0]
			for ci in 3:
				for ri in 2:
					var xa: float = cols[ci]
					var xb: float = cols[ci + 1]
					var ya: float = rows[ri]
					var yb: float = rows[ri + 1]
					var a00: float = la * float(col_a[ci]) * float(row_a[ri])
					var a01: float = la * float(col_a[ci]) * float(row_a[ri + 1])
					var a11: float = la * float(col_a[ci + 1]) * float(row_a[ri + 1])
					var a10: float = la * float(col_a[ci + 1]) * float(row_a[ri])
					_st_mist_v(st, xa, ya, a00, hh, z0, li)
					_st_mist_v(st, xa, yb, a01, hh, z0, li)
					_st_mist_v(st, xb, yb, a11, hh, z0, li)
					_st_mist_v(st, xa, ya, a00, hh, z0, li)
					_st_mist_v(st, xb, yb, a11, hh, z0, li)
					_st_mist_v(st, xb, ya, a10, hh, z0, li)
	return st.commit()


func _st_mist_v(st: SurfaceTool, x: float, fy: float, a: float, hh: float, z0: float, li: int) -> void:
	var y := fy * hh
	st.set_color(Color(1, 1, 1, a))
	st.set_uv(Vector2(x * 0.32 + float(li) * 0.37, -y * 0.45 + float(li) * 0.21))
	st.set_normal(Vector3.BACK)
	st.add_vertex(Vector3(x, y, z0 - y * 0.42))


## Bruit blanc à alpha variable : la brume s'effiloche.
func _barrier_noise() -> NoiseTexture2D:
	if _bar_noise != null:
		return _bar_noise
	var n := FastNoiseLite.new()
	n.frequency = 0.045
	n.fractal_octaves = 3
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.15), Color(1, 1, 1, 1)])
	var t := NoiseTexture2D.new()
	t.noise = n
	t.seamless = true
	t.color_ramp = g
	t.width = 128
	t.height = 128
	_bar_noise = t
	return t


func _bar_mm(parent: Node3D, mesh: Mesh, m: Material, count: int, colors: Array, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = count
	for i in colors.size():
		mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Construit les nœuds d'une haie (une poignée d'appels de dessin) ; ils sont libérés à l'ouverture.
func _barrier_show(b: Dictionary) -> void:
	var cur = b["node"]
	if is_instance_valid(cur):
		return
	var sty: Dictionary = _barrier_style()
	b["style"] = sty
	var ms: Dictionary = _barrier_meshes()
	var node := Node3D.new()
	_room_root.add_child(node)
	node.position = Vector3(0, 0, float(b["zb"]))
	b["node"] = node
	# bambous : pieux et traverses, une teinte par instance
	var bm := Toon.mat(Color.WHITE, true, 0.012)
	bm.vertex_color_use_as_albedo = true
	var poles: Array = b["poles"]
	var pcol: Array = []
	for pl in poles:
		var pa: Array = pl
		pcol.append(pa[3])
	b["mm_p"] = _bar_mm(node, ms["pole"], bm, poles.size(), pcol, true).multimesh
	var rails: Array = b["rails"]
	var rcol: Array = []
	var pole_c: Color = sty["pole"]
	for i in rails.size():
		rcol.append(pole_c.darkened(0.12))
	var rmi := _bar_mm(node, ms["rail"], bm, rails.size(), rcol, true)
	b["mm_r"] = rmi.multimesh
	b["n_rails"] = rmi
	# shimenawa lumineuse, sur un pivot (elle tombe à l'ouverture)
	var rope := Node3D.new()
	node.add_child(rope)
	b["n_rope"] = rope
	var rm := Toon.mat(Color.WHITE, true, 0.01)
	rm.vertex_color_use_as_albedo = true
	rm.emission_enabled = true
	rm.emission = sty["glow"]
	rm.emission_energy_multiplier = 0.0
	b["m_rope"] = rm
	var rmesh := Toon.part(rope, _bar_rope_mesh(b["ropes"], sty), rm, Vector3.ZERO)
	rmesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ofuda (ils brûlent à l'ouverture)
	var om := Toon.mat(Color.WHITE, false)
	om.vertex_color_use_as_albedo = true
	om.cull_mode = BaseMaterial3D.CULL_DISABLED
	om.emission_enabled = true
	om.emission = sty["burn"]
	om.emission_energy_multiplier = 0.0
	b["m_ofuda"] = om
	var ofs: Array = b["ofuda"]
	b["mm_o"] = _bar_mm(node, _bar_ofuda_mesh(sty), om, ofs.size(), [], false).multimesh
	# brume d'encre derrière la haie
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mm.vertex_color_use_as_albedo = true
	mm.albedo_texture = _barrier_noise()
	mm.disable_receive_shadows = true
	b["m_mist"] = mm
	var mist := Toon.part(node, _bar_mist_mesh(b["mist"]), mm, Vector3.ZERO)
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b["n_mist"] = mist
	# taches et gouttes d'encre (même matériau, fondu commun)
	var ic: Color = sty["ink"]
	var im := Toon.flat(Color(ic.r, ic.g, ic.b, 0.0))
	b["m_ink"] = im
	var blots: Array = b["blots"]
	b["mm_b"] = _bar_mm(node, ms["blot"], im, blots.size(), [], false).multimesh
	var drops: Array = b["drops"]
	var dmi := _bar_mm(node, ms["drop"], im, drops.size(), [], false)
	b["mm_d"] = dmi.multimesh
	b["n_drops"] = dmi


func _barrier_hide(b: Dictionary) -> void:
	var cur = b["node"]
	if is_instance_valid(cur):
		cur.queue_free()
	b["node"] = null
	b["mode"] = ""


## Retombée avec léger dépassement (0 -> 1).
static func _bar_back(q: float) -> float:
	var c := q - 1.0
	return 1.0 + 2.70158 * c * c * c + 1.70158 * c * c


## Pose d'une haie : montée (mode "rise", k de 0 à 1) ou dissolution (mode "fall", k de 1 à 0).
## `full` faux : haie dressée au repos, seuls les ofuda, la corde et la brume bougent.
func _barrier_pose(b: Dictionary, full: bool) -> void:
	var k: float = b["k"]
	var rise: bool = str(b["mode"]) != "fall"
	var p := 1.0 - k
	var sty: Dictionary = b["style"]
	var ph0: float = float(b["j"]) * 1.7
	# shimenawa : descend en place en s'illuminant ; à l'ouverture elle tombe et s'enfonce
	var rope: Node3D = b["n_rope"]
	var rope_m: StandardMaterial3D = b["m_rope"]
	var ge: float = sty["glow_e"]
	var ry := 0.0
	if rise:
		var rr := clampf((k - 0.5) / 0.4, 0.0, 1.0)
		ry = (1.0 - smoothstep(0.0, 1.0, rr)) * 0.3
		rope.visible = rr > 0.0
		rope.position = Vector3(0, ry, 0)
		rope.rotation = Vector3.ZERO
		rope_m.emission_energy_multiplier = ge * (rr + 1.4 * sin(PI * rr) + 0.25 * rr * sin(_t * 2.4 + ph0))
	else:
		var pr := clampf((p - 0.08) / 0.45, 0.0, 1.0)
		ry = -0.7 * pr * pr - 0.35 * clampf((p - 0.55) / 0.4, 0.0, 1.0)
		rope.position = Vector3(0, ry, 0.12 * pr)
		rope.rotation = Vector3(0.3 * pr, 0, 0)
		rope.visible = p < 0.97
		rope_m.emission_energy_multiplier = ge * (1.0 - pr) + 2.2 * sin(PI * clampf(p / 0.25, 0.0, 1.0))
	# ofuda : se déroulent sous la corde ; à l'ouverture ils s'embrasent et s'envolent
	var om: StandardMaterial3D = b["m_ofuda"]
	if not rise:
		var burn := smoothstep(0.0, 1.0, clampf((p - 0.1) / 0.3, 0.0, 1.0))
		om.albedo_color = Color.WHITE.lerp(Color(0.3, 0.2, 0.16), burn)
		om.emission_energy_multiplier = 2.6 * sin(PI * clampf(p / 0.55, 0.0, 1.0))
	elif full:
		om.albedo_color = Color.WHITE
		om.emission_energy_multiplier = 0.0
	var mmo: MultiMesh = b["mm_o"]
	var ofs: Array = b["ofuda"]
	for i in ofs.size():
		var oa: Array = ofs[i]
		var pos: Vector3 = oa[0]
		var oph: float = oa[1]
		var od: float = oa[2]
		var sx := 1.0
		var sy := 1.0
		var rx := 0.07 * sin(_t * 2.1 + oph)
		var rz := 0.05 * sin(_t * 1.7 + oph * 1.3)
		var at := pos + Vector3(0, ry, 0)
		if rise:
			var qo := clampf((k - 0.62 - od) / 0.25, 0.0, 1.0)
			sy = maxf(smoothstep(0.0, 1.0, qo), 0.001)
			rx += 0.25 * (1.0 - qo)
		else:
			var po := clampf((p - od * 1.2) / 0.42, 0.0, 1.0)
			at = pos + Vector3(sin(oph + p * 9.0) * 0.14 * po, 0.25 * po + 0.9 * po * po, 0.2 * po)
			rx += 0.7 * sin(oph + p * 14.0) * po
			rz += 0.6 * po * (1.0 if i % 2 == 0 else -1.0)
			sx = maxf(1.0 - 0.6 * po, 0.001)
			sy = maxf(1.0 - po, 0.001)
		var ob := Basis.from_euler(Vector3(rx, 0, rz)) * Basis.from_scale(Vector3(sx, sy, 1))
		mmo.set_instance_transform(i, Transform3D(ob, at))
	# brume : monte avec la haie, s'élève en se dissipant à l'ouverture
	var mist_m: StandardMaterial3D = b["m_mist"]
	var mist: Node3D = b["n_mist"]
	var ma := 1.0
	if rise:
		ma = smoothstep(0.0, 1.0, clampf((k - 0.15) / 0.85, 0.0, 1.0))
		mist.position = Vector3(0, -0.35 * (1.0 - ma), 0)
	else:
		ma = 1.0 - smoothstep(0.0, 1.0, clampf(p / 0.75, 0.0, 1.0))
		mist.position = Vector3(0, 0.55 * p, 0)
	var mc: Color = sty["mist"]
	var mist_a: float = sty["mist_a"]
	mist_m.albedo_color = Color(mc.r, mc.g, mc.b, mist_a * ma * (0.92 + 0.08 * sin(_t * 0.9 + ph0)))
	mist_m.uv1_offset = Vector3(_t * 0.018 + ph0, _t * 0.05, 0)
	mist.visible = ma > 0.01
	if not full:
		return
	# bambous : vague de gauche à droite à la fermeture ; ils s'enfoncent en basculant à l'ouverture
	var mmp: MultiMesh = b["mm_p"]
	var poles: Array = b["poles"]
	for i in poles.size():
		var pl: Array = poles[i]
		var tb: Transform3D = pl[0]
		var h: float = pl[1]
		var d: float = pl[2]
		var bs := tb.basis
		var org := tb.origin
		var hy := h
		if rise:
			hy = h * _bar_back(clampf((k - d) / 0.42, 0.0, 1.0))
		else:
			var ps := smoothstep(0.0, 1.0, clampf((p - 0.15 - d * 0.1) / 0.75, 0.0, 1.0))
			hy = h * (1.0 - ps)
			bs = Basis(Vector3.RIGHT, -0.3 * ps) * bs
			org.y -= 0.12 * ps
		mmp.set_instance_transform(i, Transform3D(bs * Basis.from_scale(Vector3(1, maxf(hy, 0.001), 1)), org))
	var rails: Array = b["rails"]
	var mmr: MultiMesh = b["mm_r"]
	var rail_n: Node3D = b["n_rails"]
	var rk := smoothstep(0.0, 1.0, clampf((k - 0.25) / 0.55, 0.0, 1.0))
	var rs := smoothstep(0.0, 1.0, clampf((p - 0.15) / 0.75, 0.0, 1.0))
	rail_n.visible = not rise or rk > 0.0
	for i in rails.size():
		var rl: Array = rails[i]
		var x0: float = rl[0]
		var x1: float = rl[1]
		var y: float = rl[2]
		var z: float = rl[3]
		var ln := x1 - x0
		var yy := y
		if rise:
			ln *= rk
		else:
			yy = y * (1.0 - rs) - 0.12 * rs
		mmr.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(maxf(ln, 0.001), 1, 1)), Vector3(x0, yy, z)))
	# taches d'encre au pied des bambous, gouttes projetées pendant la montée
	var im: StandardMaterial3D = b["m_ink"]
	var ic: Color = sty["ink"]
	var ia := 0.0
	if rise:
		ia = lerpf(0.85, 0.3, smoothstep(0.0, 1.0, clampf((k - 0.45) / 0.55, 0.0, 1.0)))
	else:
		ia = 0.3 * (1.0 - smoothstep(0.0, 1.0, clampf(p / 0.7, 0.0, 1.0)))
	im.albedo_color = Color(ic.r, ic.g, ic.b, ia)
	var mmb: MultiMesh = b["mm_b"]
	var blots: Array = b["blots"]
	for i in blots.size():
		var bl: Array = blots[i]
		var bt: Transform3D = bl[0]
		var bd: float = bl[1]
		var s := 1.0
		if rise:
			var qs := clampf((k - bd) / 0.16, 0.0, 1.0)
			s = maxf(qs * (2.0 - qs) * (1.0 + 0.25 * sin(PI * qs)), 0.001)
		mmb.set_instance_transform(i, Transform3D(bt.basis * Basis.from_scale(Vector3(s, 1, s)), bt.origin))
	var dn: Node3D = b["n_drops"]
	dn.visible = rise and k < 1.0
	if dn.visible:
		var mmd: MultiMesh = b["mm_d"]
		var drops: Array = b["drops"]
		for i in drops.size():
			var dr: Array = drops[i]
			var o: Vector3 = dr[0]
			var v: Vector3 = dr[1]
			var dd: float = dr[2]
			var tt := (k - dd) * 0.55
			var dp := o + v * tt + Vector3(0, -4.5 * tt * tt, 0)
			var ds := 0.001
			if tt > 0.0 and dp.y > 0.0:
				ds = maxf(1.0 - tt, 0.001)
			mmd.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(ds, ds, ds)), dp))


## Haies : elles se dressent (≈0,55 s) ou brûlent et s'enfoncent (≈0,6 s), puis leurs nœuds sont libérés.
func _animate_barriers(delta: float) -> void:
	for b in _barriers:
		var cur = b["node"]
		var has: bool = is_instance_valid(cur)
		var k: float = b["k"]
		if float(b["want"]) > 0.5:
			if not has:
				_barrier_show(b)
			b["mode"] = "rise"
			if k < 1.0:
				b["k"] = minf(1.0, k + delta / 0.55)
				_barrier_pose(b, true)
			else:
				_barrier_pose(b, false)
		else:
			if not has:
				b["k"] = 0.0
				continue
			b["mode"] = "fall"
			k = maxf(0.0, k - delta / 0.6)
			b["k"] = k
			if k <= 0.0:
				_barrier_hide(b)
			else:
				_barrier_pose(b, true)


## Une haie est fermée si la zone au sud n'est pas nettoyée, ou si la zone au nord est en plein combat.
func refresh_barriers(snap := false) -> void:
	for b in _barriers:
		var j: int = b["j"]
		var closed := false
		if j - 1 >= 0 and j - 1 < zone_state.size() and int(zone_state[j - 1]) != 2:
			closed = true
		if j < zone_state.size() and int(zone_state[j]) == 1:
			closed = true
		b["want"] = 1.0 if closed else 0.0
		if snap:
			b["k"] = b["want"]
			if closed:
				_barrier_show(b)
				b["mode"] = "rise"
				_barrier_pose(b, true)
			else:
				_barrier_hide(b)


## Cadre de marche hors combat : de l'arrivée jusqu'au nord de la première zone pas encore nettoyée.
func _roam_bounds() -> Rect2:
	var top := stage_rect.position.y
	for i in zones.size():
		if int(zone_state[i]) != 2:
			var z: Rect2 = zones[i]
			top = z.position.y
			break
	return Rect2(stage_rect.position.x, top, stage_rect.size.x, stage_rect.end.y - top)


## Zone de combat où le héros vient d'entrer (bien passé la haie sud), sinon -1.
func zone_entered(p: Vector3) -> int:
	for i in zones.size():
		if int(zone_state[i]) != 0:
			continue
		var z: Rect2 = zones[i]
		if p.z < z.end.y - ENTER_IN and p.z > z.position.y:
			return i
		return -1  # seule la première zone à venir compte
	return -1


func begin_zone(i: int) -> void:
	zone_state[i] = 1
	_set_bounds(zones[i])
	refresh_barriers()


func clear_zone(i: int) -> void:
	if i >= 0 and i < zone_state.size():
		zone_state[i] = 2
	_set_bounds(_roam_bounds())
	refresh_barriers()


func zones_left() -> int:
	var n := 0
	for s in zone_state:
		if int(s) != 2:
			n += 1
	return n


func zones_done() -> int:
	return zone_state.size() - zones_left()


## Prochain but du chemin : l'entrée de la première zone à venir (au milieu de son plus large passage),
## sinon le torii. Vector3.INF s'il n'y a rien (zone en cours).
func next_goal() -> Vector3:
	for i in zones.size():
		var s := int(zone_state[i])
		if s == 1:
			return Vector3.INF
		if s == 0:
			var z: Rect2 = zones[i]
			var best := Vector2(-1.0, 1.0)
			for pc in joins[i]:
				var v: Vector2 = pc
				if v.y - v.x > best.y - best.x:
					best = v
			var p := Vector3((best.x + best.y) / 2.0, 0, z.end.y - ENTER_IN - 1.8)
			return clamp_walk(p, 0.6)
	return gate_pos


## Avancée dans l'étape (0 au départ, 1 au torii), pour la barre du HUD.
func progress_of(p: Vector3) -> float:
	if not stage:
		return 0.0
	return clampf((stage_rect.end.y - 1.0 - p.z) / maxf(stage_rect.size.y - 2.0, 1.0), 0.0, 1.0)


## Zone i en fraction de l'étape (sud -> nord) : Vector2(début, fin).
func zone_span(i: int) -> Vector2:
	var z: Rect2 = zones[i]
	var a := clampf((stage_rect.end.y - 1.0 - z.end.y) / maxf(stage_rect.size.y - 2.0, 1.0), 0.0, 1.0)
	var b := clampf((stage_rect.end.y - 1.0 - z.position.y) / maxf(stage_rect.size.y - 2.0, 1.0), 0.0, 1.0)
	return Vector2(a, b)


## Centre (z) du passage j, pour les effets à l'ouverture d'une haie.
func join_center(j: int) -> Vector3:
	if j < 0 or j >= joins.size():
		return gate_pos
	var best := Vector2(-1.0, 1.0)
	for pc in joins[j]:
		var v: Vector2 = pc
		if v.y - v.x > best.y - best.x:
			best = v
	return Vector3((best.x + best.y) / 2.0, 0, -HALF.y - float(j) * CHUNK_L)


## Le hub de départ : grande place, dojo d'entraînement (cercle de sable) à gauche,
## passerelle vers le sanctuaire du torii en haut. Le torii reste fermé (open_gate() côté main).
func build_hub(rng_seed: int) -> void:
	_clear_room()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	layout = "hub"
	mirrored = false
	_used.clear()
	_last = ""
	rects = []
	for r in HUB_RECTS:
		rects.append(r)
	floor_rects = rects
	var dojo: Rect2 = HUB_RECTS[HUB_DOJO]
	hub_training_center = Vector3(dojo.get_center().x, 0, dojo.get_center().y + 0.2)
	hub_training_radius = minf(dojo.size.x, dojo.size.y) * 0.5 - 0.55
	_single_frame()
	var w: Dictionary = Worlds.world(world_id)
	_finish_room(w, rng, rng_seed)
	_build_dojo()


## Sol, décor, départ et torii pour les `rects` courants.
func _finish_room(w: Dictionary, rng: RandomNumberGenerator, rng_seed: int) -> void:
	_build_floor(w, rng)
	_flush_tiles()
	# départ au sud de la plateforme la plus basse, sortie au nord de la plus haute
	var ends: Array = _ends(floor_rects)
	start = ends[0]
	gate_pos = ends[1]
	# le décor reste hors du cadre de l'arène (rien dans les canaux entre plateformes) :
	# on lui passe la plateforme du torii et un cadre qui couvre toute l'arène
	var high: Rect2 = ends[3]
	var frame := Rect2(-HALF.x, -HALF.y + 0.01, HALF.x * 2.0, HALF.y * 2.0 - 0.01)
	Worlds.build_props(world_id, _room_root, [high, frame], rng_seed)
	# les vides intérieurs deviennent des fosses (paroi, gouffre, bord cassé selon le monde)
	_pits = Worlds.build_pits(world_id, _room_root, floor_rects, void_rects(floor_rects), rng_seed)
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
	var m := _shared_mat(col, true)
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
	var pick := _pick_key(rng)
	_used[pick] = int(_used.get(pick, 0)) + 1
	_last = pick
	return pick


## Tirage d'une forme (hors boss), sans la noter comme utilisée.
func _pick_key(rng: RandomNumberGenerator) -> String:
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
	var dec: Dictionary = _decompose(floor_rects)
	pieces = dec["pieces"]
	bridges = []
	var style := String(w.ground_style)
	var look: Dictionary = Worlds.floor_look(world_id)
	var mats: Array = []
	for col in w.ground:
		mats.append(_ground_mat(col, style, look))
	var woods: Array = []
	for col in WOOD:
		woods.append(_ground_mat(col, "wood", look))
	var under := _ground_mat(w.under, "under", look)
	var deck := _ground_mat(Color("#3E2C1C"), "wood", look)
	# tirages du décor du sol à part : la forme de la salle et ses recoins ne changent pas
	_deco_rng = RandomNumberGenerator.new()
	_deco_rng.seed = rng.seed + 7717
	_accent_mat = null
	var accent: Color = look.get("accent", Color(0, 0, 0, 0))
	if accent.a > 0.0:
		_accent_mat = _ground_mat(accent, style, look)
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
			_floor_dressing(r, style, look)
	_build_edges(dec, w, woods[2])
	_build_steps(w)


## Marches entre terrasses peintes au sol (nez clair, contremarche sombre ; la marche reste plate pour
## marcher) ; à Kurama, une volée de trois marches de pierre. Planches à la dérive sous les ponts cassés.
func _build_steps(w: Dictionary) -> void:
	if _steps.is_empty() and _gaps.is_empty():
		return
	var gcols: Array = w.ground
	var g0: Color = gcols[0]
	var nose := _shared_mat(g0.lightened(0.22), true)
	var riser := _shared_mat(g0.darkened(0.5), true)
	var flight := 3 if world_id == 6 else 1
	for s in _steps:
		var sv: Vector3 = s
		var l := sv.y - sv.x
		var cx := (sv.x + sv.y) * 0.5
		for k in flight:
			var z := sv.z + 0.34 * float(k)
			_tile(Vector3(l, 0.03, 0.14), Vector3(cx, 0.008, z - 0.07), nose)
			_tile(Vector3(l, 0.03, 0.09), Vector3(cx, 0.006, z + 0.045), riser)
	for gp in _gaps:
		var r: Rect2 = gp
		var c := r.get_center()
		for k in 3:
			var m := _shared_mat(WOOD[k % WOOD.size()], true)
			var p := Vector3(c.x + _deco_rng.randf_range(-0.3, 0.3) * r.size.x, -0.5, c.y + _deco_rng.randf_range(-0.3, 0.3) * r.size.y)
			_tile(Vector3(r.size.x * 0.45, 0.05, 0.16), p, m, _deco_rng.randf_range(-0.6, 0.6))
		# bouts de planches éclatés qui dépassent du tablier, de part et d'autre de la trouée
		var dark := _shared_mat(WOOD[2], true)
		for q in 3:
			var x := lerpf(r.position.x + 0.3, r.end.x - 0.3, float(q) / 2.0)
			var ln := _deco_rng.randf_range(0.12, 0.3)
			_tile(Vector3(0.16, 0.06, ln), Vector3(x, -0.07, r.position.y + ln * 0.5), dark)
			ln = _deco_rng.randf_range(0.12, 0.3)
			_tile(Vector3(0.16, 0.06, ln), Vector3(x, -0.07, r.end.y - ln * 0.5), dark)


## Matière du sol (shaders/ground.gdshader), partagée par couleur, style et monde.
## Styles : planks, stones, basalt, snow, paper (sols), wood (ponts, poutres), under (flancs des plateformes).
func _ground_mat(col: Color, style: String, look: Dictionary) -> ShaderMaterial:
	var key := "g%s_%s_%d_%d" % [col.to_html(true), style, world_id, 1 if Toon.lite else 0]
	if _mat_cache.has(key):
		var cached: ShaderMaterial = _mat_cache[key]
		return cached
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("ink", Toon.SUMI)
	m.set_shader_parameter("fine", not Toon.lite)
	# [variation, joint, largeur du joint, flanc, grain, échelle du grain, mouchetis, 2e teinte, mousse, usure]
	var p := [0.07, 0.25, 0.08, 0.4, 0.06, Vector2(5, 5), 0.18, 1.0, 1.0, 1.0]
	match style:
		"planks":
			p = [0.07, 0.3, 0.06, 0.45, 0.09, Vector2(22, 1.5), 0.1, 1.0, 0.4, 1.0]  # fil du bois le long des planches
		"stones":
			p = [0.08, 0.32, 0.1, 0.45, 0.06, Vector2(5, 5), 0.16, 1.0, 1.0, 0.8]
		"basalt":
			p = [0.1, 0.35, 0.1, 0.45, 0.07, Vector2(6, 6), 0.0, 1.0, 0.0, 1.0]
		"snow":
			p = [0.03, 0.16, 0.25, 0.3, 0.025, Vector2(3, 3), 0.03, 0.6, 0.0, 0.0]
		"paper":
			p = [0.0, 0.22, 0.3, 0.4, 0.07, Vector2(4, 9), 0.32, 0.0, 0.0, 1.0]
		"wood":
			p = [0.09, 0.28, 0.05, 0.45, 0.08, Vector2(6, 6), 0.06, 0.6, 0.3, 0.6]
		"under":
			p = [0.0, 0.0, 0.08, 0.55, 0.05, Vector2(4, 4), 0.0, 0.0, 0.0, 0.0]
	m.set_shader_parameter("tile_var", float(p[0]))
	m.set_shader_parameter("edge_ao", float(p[1]))
	m.set_shader_parameter("edge_w", float(p[2]))
	m.set_shader_parameter("side_ao", float(p[3]))
	m.set_shader_parameter("grain", float(p[4]))
	m.set_shader_parameter("grain_scale", p[5])
	m.set_shader_parameter("speckle", float(p[6]))
	m.set_shader_parameter("alt", look.get("alt", col))
	m.set_shader_parameter("alt_k", float(look.get("alt_k", 0.0)) * float(p[7]))
	m.set_shader_parameter("moss", look.get("moss", col))
	m.set_shader_parameter("moss_k", float(look.get("moss_k", 0.0)) * float(p[8]))
	m.set_shader_parameter("wear_k", float(look.get("wear", 0.0)) * float(p[9]))
	_mat_cache[key] = m
	return m


## Habillage d'un morceau de sol (tirages à part) : planches de laque rares (accent du monde), ferrures en
## travers des planches, feuilles / pétales tombés. Tout part dans les lots de tuiles (MultiMesh par matériau).
func _floor_dressing(r: Rect2, style: String, look: Dictionary) -> void:
	var drng := _deco_rng
	if style == "planks":
		var band := _shared_mat(Color("#2B2622"), true)
		var pw := 0.62
		var x := -HALF.x + floorf((r.position.x + HALF.x) / pw + 0.001) * pw
		while x < r.end.x - 0.02:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + pw, r.end.x)
			if x1 - x0 > 0.2:
				# ferrures : une ou deux par colonne, en travers
				var nb := drng.randi_range(0, 2)
				for k in nb:
					var z := drng.randf_range(r.position.y + 0.3, r.end.y - 0.3)
					_tile(Vector3(x1 - x0 - 0.06, 0.024, 0.06), Vector3((x0 + x1) / 2.0, 0.0, z), band)
			x += pw
	var leaves: Array = look.get("leaves", [])
	if leaves.is_empty() or style == "snow" or style == "paper":
		return
	var lmats: Array = []
	for lc in leaves:
		lmats.append(_shared_mat(lc, true))
	var n := int(r.size.x * r.size.y / (6.0 if Toon.lite else 3.0))
	for i in n:
		# en grappes : quelques feuilles autour d'un point
		var cx := drng.randf_range(r.position.x + 0.3, r.end.x - 0.3)
		var cz := drng.randf_range(r.position.y + 0.3, r.end.y - 0.3)
		var m: Material = lmats[drng.randi() % lmats.size()]
		_tile(Vector3(drng.randf_range(0.08, 0.14), 0.006, drng.randf_range(0.05, 0.08)), Vector3(cx, 0.014, cz), m, drng.randf() * PI)


## Toon sans contour, partagé par couleur (`plain` : sans liseré ni reflet, comme les sols).
## Les mêmes tuiles d'une salle à l'autre réutilisent leur matériau (et leurs MultiMesh fusionnent mieux).
static func _shared_mat(col: Color, plain: bool) -> StandardMaterial3D:
	var key := "%s%d" % [col.to_html(true), 1 if plain else 0]
	if _mat_cache.has(key):
		var cached: StandardMaterial3D = _mat_cache[key]
		return cached
	var m := Toon.mat(col, false)
	if plain:
		m.rim_enabled = false
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat_cache[key] = m
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
	var we := _in_any(floor_rects, Vector2(r.position.x - 0.1, c.y)) or _in_any(floor_rects, Vector2(r.end.x + 0.1, c.y))
	var ns := _in_any(floor_rects, Vector2(c.x, r.position.y - 0.1)) or _in_any(floor_rects, Vector2(c.x, r.end.y + 0.1))
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
						# même ordre de tirages qu'avant (hauteur puis teinte) : la suite de la salle est inchangée
						var py := -0.045 + rng.randf_range(-0.006, 0.006)
						var pm: Material = mats[rng.randi() % mats.size()]
						if _accent_mat != null and _deco_rng.randf() < 0.035:
							pm = _accent_mat  # planche de laque (accent du monde), rare
						_tile(Vector3(maxf(x1 - x0 - g0 - g1, 0.01), 0.09, maxf(l - 0.03, 0.01)), Vector3((x0 + g0 + x1 - g1) / 2.0, py, z0 + l / 2.0), pm)
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
					var off := s * 0.5 if posmod(row, 2) == 1 else 0.0  # (rangées négatives : étapes longues)
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
				var gold := _shared_mat(Toon.GOLD, false)
				for i in int(r.size.x * r.size.y / 6.0):
					_tile(Vector3(rng.randf_range(0.4, 1.2), 0.012, 0.05), Vector3(rng.randf_range(r.position.x + 0.3, r.end.x - 0.3), 0.003, rng.randf_range(r.position.y + 0.3, r.end.y - 0.3)), gold, rng.randf() * PI)
		"snow":
			_tile(Vector3(r.size.x, 0.1, r.size.y), Vector3(c.x, -0.05, c.y), mats[0])
			for i in int(r.size.x * r.size.y / 5.0):
				# bosses de neige : sphères aplaties, regroupées par matériau (MultiMesh)
				var lr := rng.randf_range(0.25, 0.5)
				_lump(Vector3(lr * 2.0, lr * 0.24, lr * 2.0), Vector3(rng.randf_range(r.position.x + 0.3, r.end.x - 0.3), -0.02, rng.randf_range(r.position.y + 0.3, r.end.y - 0.3)), mats[rng.randi() % mats.size()])
		_:
			# papier : grande feuille washi et quelques traits d'encre sèche
			_tile(Vector3(r.size.x, 0.1, r.size.y), Vector3(c.x, -0.05, c.y), mats[0])
			if _ink_mat == null:
				_ink_mat = Toon.flat(Color(Toon.SUMI, 0.18))
			for i in int(r.size.x * r.size.y / 8.0):
				_tile(Vector3(rng.randf_range(0.6, 2.0), 0.005, rng.randf_range(0.05, 0.14)),
					Vector3(rng.randf_range(r.position.x + 0.4, r.end.x - 0.4), 0.004, rng.randf_range(r.position.y + 0.4, r.end.y - 0.4)), _ink_mat, rng.randf() * PI)


## Bords : seulement là où la terre ferme touche le vide. Bord d'encre pour les plateformes,
## poutre de bois sous le niveau du sol pour les ponts (pas de cadre au-dessus de l'eau).
func _build_edges(dec: Dictionary, w: Dictionary, beam: Material) -> void:
	var xs: Array = dec["xs"]
	var zs: Array = dec["zs"]
	var kinds: Array = dec["kinds"]
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	var ink := _shared_mat(w.edge, false)
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
		xs.append(rr.position.x)
		xs.append(rr.end.x)
		zs.append(rr.position.y)
		zs.append(rr.end.y)
	xs = _uniq_sorted(xs)
	zs = _uniq_sorted(zs)
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	# chaque rectangle couvre des cellules entières de la grille : on les marque (la terre l'emporte
	# sur la passerelle), au lieu de tester chaque cellule contre chaque rectangle (étapes longues)
	var kinds: Array = []
	kinds.resize(maxi(nx * nz, 0))
	kinds.fill(0)
	for r in rs:
		var rr: Rect2 = r
		var land := not _is_bridge_rect(rr)
		var i0 := _coord_idx(xs, rr.position.x)
		var i1 := _coord_idx(xs, rr.end.x)
		var j0 := _coord_idx(zs, rr.position.y)
		var j1 := _coord_idx(zs, rr.end.y)
		for j in range(j0, j1):
			for i in range(i0, i1):
				var k := j * nx + i
				if land:
					kinds[k] = 1
				elif int(kinds[k]) == 0:
					kinds[k] = 2
	return {"xs": xs, "zs": zs, "kinds": kinds, "pieces": _merge_cells(xs, zs, kinds)}


## Valeurs triées sans doublon (à 0.001 près, comme _add_coord).
static func _uniq_sorted(vals: Array) -> Array:
	vals.sort()
	var out: Array = []
	for v in vals:
		var f := float(v)
		if out.is_empty() or f - float(out[out.size() - 1]) >= 0.001:
			out.append(f)
	return out


## Indice de la coordonnée la plus proche de `v` dans `arr` (trié).
static func _coord_idx(arr: Array, v: float) -> int:
	var i := arr.bsearch(v)
	if i >= arr.size():
		return arr.size() - 1
	if i > 0 and absf(float(arr[i - 1]) - v) < absf(float(arr[i]) - v):
		return i - 1
	return i


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


## Bosse du sol (sphère unité mise à l'échelle `size`), regroupée par matériau comme les tuiles.
func _lump(size: Vector3, pos: Vector3, m: Material) -> void:
	if not _sbatches.has(m):
		_sbatches[m] = []
	_sbatches[m].append(Transform3D(Basis().scaled(size), pos))


func _flush_tiles() -> void:
	# tuile et bosse unité partagées par toutes les salles (mises à l'échelle par instance)
	if _unit_tile == null:
		_unit_tile = BoxMesh.new()
		_unit_lump = SphereMesh.new()
		_unit_lump.radius = 0.5
		_unit_lump.height = 1.0
		_unit_lump.radial_segments = 12
		_unit_lump.rings = 6
	var unit: BoxMesh = _unit_tile
	var ball: SphereMesh = _unit_lump
	for pass_i in 2:
		var batches: Dictionary = _batches
		var shape: Mesh = unit
		if pass_i == 1:
			batches = _sbatches
			shape = ball
		for m in batches.keys():
			var list: Array = batches[m]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = shape
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_room_root.add_child(mi)
	_batches.clear()
	_sbatches.clear()


## Torii de sortie, endormi : sceaux de papier éteints sur les piliers, corde sacrée (shimenawa) et ses
## shide, rayons de lumière et lucioles du monde prêts à s'allumer (open_gate).
func _build_gate(_w: Dictionary) -> void:
	gate_open = false
	_gate_t = -1.0
	_gate_flash = 0.0
	_gate_seals = []
	_gate_shide = []
	_gate_dots = []
	_gate = Node3D.new()
	_room_root.add_child(_gate)
	_gate.position = gate_pos
	var t := Decor.torii(_gate, Vector3(0, 0, -0.3), 0.55)
	t.visible = true
	# sceaux (ofuda) sur la face des piliers : ils s'allument un à un, de bas en haut
	var seal_mesh := Toon.box(Vector3(0.085, 0.17, 0.012))
	var order := 0
	for row in 3:
		for sx: float in [-1.0, 1.0]:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("#E9DEC4")
			m.emission_enabled = true
			m.emission = Color("#FFC861")
			m.emission_energy_multiplier = 0.0
			var mi := Toon.part(_gate, seal_mesh, m, Vector3(sx * 1.21, 0.42 + 0.33 * row, -0.19))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_gate_seals.append([mi, m, 0.11 * order])
			order += 1
	# shimenawa entre les piliers, sous le nuki
	_gate_rope_mat = StandardMaterial3D.new()
	_gate_rope_mat.albedo_color = Color("#D9C38C")
	_gate_rope_mat.emission_enabled = true
	_gate_rope_mat.emission = Color("#FFD27A")
	_gate_rope_mat.emission_energy_multiplier = 0.0
	var rope := Toon.part(_gate, Toon.cyl(0.042, 0.042, 2.3, 8), _gate_rope_mat, Vector3(0, 1.17, -0.3))
	rope.rotation.z = PI / 2.0
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Toon.part(_gate, Toon.sphere(0.08), _gate_rope_mat, Vector3(0, 1.15, -0.3))
	# shide : papiers en zigzag qui pendent de la corde (ils frémissent quand le torii s'éveille)
	var paper := Toon.mat(Color("#F6F0E2"), false)
	var bit := Toon.box(Vector3(0.07, 0.085, 0.01))
	for i in 4:
		var pv := Node3D.new()
		_gate.add_child(pv)
		pv.position = Vector3(-0.78 + 0.52 * i, 1.13, -0.27)
		for k in 3:
			var b := Toon.part(pv, bit, paper, Vector3(0.028 * float(k % 2), -0.05 - 0.085 * k, 0))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gate_shide.append([pv, randf() * TAU])
	# rayons de lumière qui coulent sous l'arche vers le héros (nappes inclinées, additives)
	_gate_ray_mat = StandardMaterial3D.new()
	_gate_ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gate_ray_mat.vertex_color_use_as_albedo = true
	_gate_ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gate_ray_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_gate_ray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_gate_ray_mat.albedo_color = Color(1, 1, 1, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_c := Color(1.0, 0.85, 0.55, 0.42)
	var low_c := Color(1.0, 0.8, 0.5, 0.0)
	for xc: float in [-0.62, -0.2, 0.22, 0.6]:
		var wt := 0.13
		var wb := 0.42 + absf(xc) * 0.3
		var a := Vector3(xc - wt, 1.5, -0.32)
		var b2 := Vector3(xc + wt, 1.5, -0.32)
		var c2 := Vector3(xc * 1.7 + wb, 0.03, 3.4)
		var d2 := Vector3(xc * 1.7 - wb, 0.03, 3.4)
		for v in [[a, top_c], [b2, top_c], [c2, low_c], [a, top_c], [c2, low_c], [d2, low_c]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	_gate_rays = MeshInstance3D.new()
	_gate_rays.mesh = st.commit()
	_gate_rays.material_override = _gate_ray_mat
	_gate_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gate_rays.visible = false
	_gate.add_child(_gate_rays)
	# lucioles du monde (pétales, feux, neige, braises, encre) aspirées vers l'arche
	_gate_motes = CPUParticles3D.new()
	_gate.add_child(_gate_motes)
	_gate_motes.position = Vector3(0, 1.0, -0.2)
	_gate_motes.emitting = false
	_gate_motes.amount = 26
	_gate_motes.lifetime = 1.7
	_gate_motes.local_coords = true
	_gate_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_gate_motes.emission_sphere_radius = 3.0
	_gate_motes.direction = Vector3.UP
	_gate_motes.spread = 180.0
	_gate_motes.gravity = Vector3.ZERO
	_gate_motes.initial_velocity_min = 0.1
	_gate_motes.initial_velocity_max = 0.3
	_gate_motes.radial_accel_min = -2.6
	_gate_motes.radial_accel_max = -1.8
	_gate_motes.scale_amount_min = 0.7
	_gate_motes.scale_amount_max = 1.4
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 6
	mote.rings = 3
	mote.material = Toon.flat(_mote_color())
	_gate_motes.mesh = mote
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	_gate_motes.color_ramp = g


## Couleur des lucioles de l'arche selon le monde.
func _mote_color() -> Color:
	match world_id:
		1:
			return Color("#F4BCCB")  # pétales
		2:
			return Color("#FFD27A")  # feux de renard
		3:
			return Color("#F4FBFF")  # neige
		4:
			return Color("#FF8A3A")  # braises
		6:
			return Color("#B9D98A")  # lucioles de la forêt
		7:
			return Color("#BFF4EC")  # bulles
		8:
			return Color("#C9B8FF")  # âmes
	return Color("#2A2830")  # encre


## Le torii s'éveille : on peut passer à la suite (sceaux, corde, rayons, lucioles).
func open_gate() -> void:
	if not gate_open:
		_gate_t = 0.0
	gate_open = true


## Chemin de points d'encre (pas au pinceau) du héros jusqu'au torii, tracé point après point.
func gate_path(from: Vector3) -> void:
	if not is_instance_valid(_gate):
		return
	var to := gate_pos + Vector3(0, 0, 0.7)
	var d := Vector3(to.x - from.x, 0, to.z - from.z)
	var n := int(d.length() / 0.72)
	if n < 2:
		return
	var side := Vector3(-d.z, 0, d.x).normalized()
	var m := Toon.flat(Color(Toon.SUMI, 0.5))
	var disc := Toon.cyl(1.0, 1.0, 0.004, 10)
	var shown := 0
	for i in range(1, n):
		var p := from + d * (float(i) / float(n)) + side * (0.13 if i % 2 == 0 else -0.13)
		if not walkable(p, 0.05):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = disc
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_room_root.add_child(mi)
		mi.position = Vector3(p.x, 0.022, p.z)
		mi.rotation.y = randf() * PI
		var s := randf_range(0.09, 0.13)
		mi.scale = Vector3(0.001, 1, 0.001)
		_gate_dots.append([mi, 0.85 * float(i) / float(n), s])
		shown += 1


## Éclat du torii au passage du héros.
func gate_flash() -> void:
	_gate_flash = 1.0


func _animate_gate(delta: float) -> void:
	if _gate_t < 0.0:
		return
	_gate_t += delta
	var t := _gate_t
	_gate_flash = maxf(0.0, _gate_flash - delta * 2.2)
	var fl := _gate_flash
	for s in _gate_seals:
		var k := clampf((t - 0.12 - float(s[2])) / 0.16, 0.0, 1.0)
		var m: StandardMaterial3D = s[1]
		m.emission_energy_multiplier = 2.3 * k + 2.5 * fl
		var mi: MeshInstance3D = s[0]
		mi.scale = Vector3.ONE * (1.0 + 0.45 * sin(PI * k))
	var rk := clampf((t - 0.55) / 0.4, 0.0, 1.0)
	_gate_rope_mat.emission_energy_multiplier = rk * (1.1 + 0.25 * sin(t * 3.0)) + 2.0 * fl
	for sh in _gate_shide:
		var pv: Node3D = sh[0]
		var ph: float = sh[1]
		pv.rotation.x = sin(t * 7.5 + ph) * (0.06 + 0.32 * rk) + 0.12 * rk
		pv.rotation.z = sin(t * 5.3 + ph * 1.7) * 0.12 * rk
	var ray := clampf((t - 0.7) / 0.6, 0.0, 1.0)
	_gate_rays.visible = ray > 0.0 or fl > 0.0
	_gate_ray_mat.albedo_color = Color(1, 1, 1, minf(1.0, ray * (0.78 + 0.22 * sin(t * 1.6)) + 0.9 * fl))
	_gate_rays.scale = Vector3(1.0 + 0.04 * sin(t * 1.1), 1, 1.0 + 0.25 * fl)
	if t > 0.3 and not _gate_motes.emitting:
		_gate_motes.emitting = true
	for dt in _gate_dots:
		var dm: MeshInstance3D = dt[0]
		if not is_instance_valid(dm):
			continue
		var k := clampf((t - float(dt[1])) / 0.18, 0.0, 1.0)
		var s: float = float(dt[2]) * (k + 0.35 * sin(PI * k))
		dm.scale = Vector3(maxf(s, 0.001), 1, maxf(s * 1.25, 0.001))


func gate_reached(p: Vector3) -> bool:
	return gate_open and Vector2(p.x - gate_pos.x, p.z - gate_pos.z).length() < 1.3


func _process(delta: float) -> void:
	_t += delta
	if not _pits.is_empty():
		Worlds.animate_pits(_pits, _t)
	for ps in _pit_states:
		Worlds.animate_pits(ps, _t)
	# décor des tronçons lointains : un morceau par image, après l'arrivée
	if not _pending.is_empty():
		var job: Dictionary = _pending.pop_front()
		var t0 := Time.get_ticks_usec()
		_build_chunk_decor(job)
		var spent := Time.get_ticks_usec() - t0
		_pending_us += spent
		_pending_max = maxi(_pending_max, spent)
		if _pending.is_empty():
			# mesures : tout le décor différé de l'étape, et sa plus longue image
			perf.emit("stage_decor_deferred", _pending_us)
			perf.emit("stage_decor_frame_max", _pending_max)
			_pending_us = 0
			_pending_max = 0
	# haies sacrées : elles se dressent ou brûlent et s'enfoncent
	_animate_barriers(delta)
	if is_instance_valid(_gate):
		_animate_gate(delta)


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
	# hors du cadre courant (zone de combat fermée, haie encore debout) : pas de terre ferme
	if x < bounds.position.x or x > bounds.end.x or z < bounds.position.y or z > bounds.end.y:
		return false
	for r in _act:
		var rr: Rect2 = r
		if x >= rr.position.x and x <= rr.end.x and z >= rr.position.y and z <= rr.end.y:
			return true
	return false


## Ramène un point (ou un ennemi de rayon `rad`) sur la terre ferme la plus proche (dans le cadre courant).
func clamp_walk(p: Vector3, rad: float) -> Vector3:
	if walkable(p, rad):
		return p
	var best := p
	var best_d := INF
	for r in _act:
		var rr: Rect2 = r
		var ri := rr.intersection(bounds)
		if ri.size.x <= 0.0 or ri.size.y <= 0.0:
			continue
		var g := ri.grow(-rad)
		var q := Vector3(clampf(p.x, g.position.x, g.end.x), p.y, clampf(p.z, g.position.y, g.end.y))
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best_d:
			best_d = d
			best = q
	if best_d == INF:
		best = Vector3(clampf(p.x, bounds.position.x + rad, bounds.end.x - rad), p.y, clampf(p.z, bounds.position.y + rad, bounds.end.y - rad))
	return best


## Point jouable au hasard, loin de `avoid` (dans le cadre courant : la zone de combat en cours).
func random_point(avoid: Vector3, min_dist: float, margin := 0.8) -> Vector3:
	var p := start
	# tirage pondéré par la surface : les passerelles n'attirent pas autant d'ennemis que les îles
	var areas: Array = []
	var pool: Array = []
	var total := 0.0
	for r in _act:
		var rr: Rect2 = r
		var ri := rr.intersection(bounds)
		pool.append(ri)
		var gg := ri.grow(-margin)
		var a := maxf(gg.size.x, 0.0) * maxf(gg.size.y, 0.0)
		areas.append(a)
		total += a
	if total <= 0.0:
		return clamp_walk(p, margin)
	for attempt in 40:
		var idx := pool.size() - 1
		var x := randf() * total
		for i in areas.size():
			x -= float(areas[i])
			if x <= 0.0:
				idx = i
				break
		var r: Rect2 = pool[idx]
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
	if _act.size() <= 1 or _line_walkable(from, to, 0.3):
		return to
	var a := _rect_of(from)
	var b := _rect_of(to)
	if a == b:
		return to
	# parcours en largeur sur les plateformes qui se touchent (celles du cadre courant ; voisinage gardé
	# jusqu'au prochain changement de cadre : plus de plateformes autour des pièces de décor)
	if _adj.size() != _act.size():
		_adj = []
		for i in _act.size():
			var nb: Array = []
			for j in _act.size():
				if _touch(i, j):
					nb.append(j)
			_adj.append(nb)
	var prev := {a: -1}
	var queue: Array = [a]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == b:
			break
		var nbs: Array = _adj[cur]
		for j in nbs:
			if not prev.has(j):
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
		var pr: Rect2 = _act[int(path[i])]
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
	for i in _act.size():
		var r: Rect2 = _act[i]
		if r.has_point(Vector2(p.x, p.z)):
			return i
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))
		var d := q.distance_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = i
	return best


func _touch(i: int, j: int) -> bool:
	return i != j and _touch_r(_act[i], _act[j])


static func _touch_r(a: Rect2, b: Rect2) -> bool:
	return a.grow(0.05).intersects(b.grow(0.05))


func _portal(i: int, j: int) -> Vector3:
	var a: Rect2 = _act[i]
	var b: Rect2 = _act[j]
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


## Vrai si `p` est sur une pièce de décor (bateau, bosquet, étang gelé…) ou à moins de `margin` :
## ce n'est pas du vide (hazards : on ne s'y noie pas, pas de trou à côté).
func on_set_piece(p: Vector3, margin := 0.0) -> bool:
	for sp in set_pieces:
		var spa: Array = sp
		var fp: Rect2 = spa[0]
		if fp.grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


# ------------------------------------------------------------------ vérification

## Contrôle toutes les formes (et le hub) : dans l'arène, connexes, jonctions assez larges,
## départ et torii sur la terre ferme (aussi en miroir), surface suffisante.
## Renvoie la liste des problèmes (vide si tout va bien).
static func check_layouts() -> Array:
	var fails: Array = []
	var sets := {}
	for k in LAYOUTS.keys():
		sets[String(k)] = LAYOUTS[k]
	sets["hub"] = HUB_RECTS
	var box := Rect2(-HALF.x - 0.001, -HALF.y - 0.001, HALF.x * 2.0 + 0.002, HALF.y * 2.0 + 0.002)
	for key in sets.keys():
		var tag := String(key)
		var rs: Array = sets[key]
		if rs.is_empty():
			fails.append(tag + " : vide")
			continue
		for r in rs:
			var rr: Rect2 = r
			if not box.encloses(rr):
				fails.append("%s : %s hors de l'arène" % [tag, str(rr)])
			if minf(rr.size.x, rr.size.y) < 1.6:
				fails.append("%s : %s trop étroit" % [tag, str(rr)])
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
	# étapes : la forme pleine (repli) doit se raccorder à toutes les autres, des deux côtés
	var full: Array = _layout_rects(BOSS_LAYOUT, false)
	for k in LAYOUTS.keys():
		for mir in [false, true]:
			var rs: Array = _layout_rects(String(k), mir)
			if _join_pieces(rs, full).is_empty() or _join_pieces(full, rs).is_empty():
				fails.append("étape : %s%s ne se raccorde pas à la forme pleine" % [String(k), " (miroir)" if mir else ""])
	return fails
