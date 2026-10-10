extends Node3D
## Personnage procédural (héros et clan des ninjas) : modelé et animé entièrement en code, sans modèle importé.
## Proportions chibi héroïques (tête ≈ 1/3 de la hauteur, lisible à 10 m de la caméra), 1,75 m de référence.
## Deux allures sur le même squelette :
## - ninja (ennemis, cfg « ronin » absent) : cagoule (zukin) à fente unique, masque de la même étoffe, hachimaki
##   à deux pans, veste croisée (V clair), obi, tekko, hakama serré dans les kyahan, tabi ; katana au fourreau
##   laqué dans le dos (poignée au-dessus de l'épaule droite) ;
## - Ronin de papier (héros, cfg « ronin » vrai) : chapeau de paille conique (sandogasa) posé en arrière, visage
##   nu aux traits d'encre (sourcils, yeux fendus, bouche fine), queue de cheval nouée sous le chapeau, kimono
##   washi aux manches amples (ourlets et col marqués à l'encre, plis), hakama bleu de Prusse au motif seigaiha
##   (écailles claires en couleurs de sommets), tabi et zōri ; katana au fourreau à la ceinture gauche, main
##   gauche posée sur la garde au repos ; l'écharpe (hero.gd) part du nœud de la nuque.
## Squelette : hiérarchie de Node3D (articulations) ; les maillages sont enfants des articulations (pas de
## Skeleton3D). Animation : poses clés procédurales mêlées, seules les rotations des articulations bougent.
## Même interface que character.gd (setup, play, play_once, idle, _once, hold, set_flash, set_glow, length,
## attach, attach_mesh, hide_meshes, paint, model, anim, scale_factor) : le héros et les ninjas l'utilisent
## comme un Character. Palette (dict) : cloth, dark, under, accent, band, wrap, tekko, skin, glove, tabi,
## plate, saya, steel, eye, hair ; ponytail, weapon (katana / shuriken / kusarigama / smoke), combat.
## Maillages partagés (cache statique par palette et par pièce) ; deux matériaux par personnage (éclat blanc).
const Perf = preload("res://scripts/perf_probe.gd")  # relevé par image (-- --perf)

const Toon = preload("res://scripts/toon.gd")

const H_REF := 1.75  # hauteur de référence du modelé (m)
const OUTLINE := 0.022  # épaisseur du contour d'encre

# articulations
const J_HIPS := 0
const J_SPINE := 1
const J_CHEST := 2
const J_NECK := 3
const J_HEAD := 4
const J_SHO_L := 5
const J_ELB_L := 6
const J_HAND_L := 7
const J_SHO_R := 8
const J_ELB_R := 9
const J_HAND_R := 10
const J_THI_L := 11
const J_SHIN_L := 12
const J_FOOT_L := 13
const J_THI_R := 14
const J_SHIN_R := 15
const J_FOOT_R := 16
const J_COUNT := 17
const SLOT_HIP := 17  # case en plus des poses : décalage du bassin (translation)
const SLOTS := 18
const PARENT := [-1, 0, 1, 2, 3, 2, 5, 6, 2, 8, 9, 0, 11, 12, 0, 14, 15]
const OFFSET := [Vector3(0, 0.66, 0), Vector3(0, 0.08, 0), Vector3(0, 0.14, 0), Vector3(0, 0.23, 0), Vector3(0, 0.07, 0),
	Vector3(-0.21, 0.18, 0), Vector3(0, -0.22, 0), Vector3(0, -0.2, 0),
	Vector3(0.21, 0.18, 0), Vector3(0, -0.22, 0), Vector3(0, -0.2, 0),
	Vector3(-0.09, -0.04, 0), Vector3(0, -0.27, 0), Vector3(0, -0.27, 0),
	Vector3(0.09, -0.04, 0), Vector3(0, -0.27, 0), Vector3(0, -0.27, 0)]
const JOINT_NAMES := ["hips", "spine", "chest", "neck", "head", "upperarm.l", "lowerarm.l", "hand.l",
	"upperarm.r", "lowerarm.r", "hand.r", "upperleg.l", "lowerleg.l", "foot.l", "upperleg.r", "lowerleg.r", "foot.r"]

# clips (noms KayKit demandés par le jeu -> _clip_of)
const C_IDLE := 0
const C_STANCE := 1
const C_WALK := 2
const C_RUN := 3
const C_SLASH := 4
const C_SPIN := 5
const C_BLOCK := 6
const C_JUMP := 7
const C_STAB := 8
const C_HIT := 9
const C_DEATH := 10
const C_THROW := 11
const C_CAST := 12
const C_CHOP := 13
const C_INTERACT := 14
const C_SPAWN := 15
const CLIP_LEN := [2.4, 2.0, 1.0, 0.72, 1.0, 1.2, 1.0, 1.0, 1.0, 0.6, 1.3, 1.0, 1.2, 1.1, 1.3, 1.0]

# poses clés
const K_IDLE := 0  # repos ou garde selon `combat_idle`
const K_REST := 1
const K_STANCE := 2
const K_SLASH_WIND := 3
const K_SLASH_HIT := 4
const K_SLASH_END := 5
const K_SPIN := 6
const K_GUARD := 7
const K_GUARD_HIT := 8
const K_CROUCH := 9
const K_EXTEND := 10
const K_TUCK := 11
const K_STAB_WIND := 12
const K_STAB_HIT := 13
const K_HIT := 14
const K_DEATH_KNEEL := 15
const K_DEATH_DOWN := 16
const K_THROW_WIND := 17
const K_THROW_REL := 18
const K_CAST := 19
const K_CHOP_UP := 20
const K_CHOP_DOWN := 21
const K_BOW := 22
const K_SLASH_THRU := 23  # suivi du geste : la lame dépasse le point d'arrivée avant de se poser

## Enchaînements des clips joués une fois : [instant (0..1), pose clé, …], fondu lissé entre deux clés.
## Le coup tombe à mi-clip (comme les annonces des ennemis le supposent : length * 0.5 / windup).
## Taille : anticipation (armé lent), frappe (rapide), suivi au-delà de l'arrivée, puis la pose se relâche.
const SEQ := {
	C_SLASH: [0.0, K_IDLE, 0.32, K_SLASH_WIND, 0.5, K_SLASH_HIT, 0.62, K_SLASH_THRU, 0.84, K_SLASH_END, 1.0, K_SLASH_END],
	C_SPIN: [0.0, K_SPIN, 1.0, K_SPIN],
	C_BLOCK: [0.0, K_GUARD, 0.12, K_GUARD_HIT, 0.3, K_GUARD, 1.0, K_GUARD],
	C_JUMP: [0.0, K_CROUCH, 0.14, K_CROUCH, 0.28, K_EXTEND, 0.42, K_TUCK, 0.74, K_TUCK, 0.86, K_CROUCH, 1.0, K_IDLE],
	C_STAB: [0.0, K_IDLE, 0.36, K_STAB_WIND, 0.52, K_STAB_HIT, 0.78, K_STAB_HIT, 1.0, K_IDLE],
	C_HIT: [0.0, K_HIT, 0.3, K_HIT, 1.0, K_IDLE],
	C_DEATH: [0.0, K_HIT, 0.22, K_DEATH_KNEEL, 0.62, K_DEATH_DOWN, 1.0, K_DEATH_DOWN],
	C_THROW: [0.0, K_IDLE, 0.38, K_THROW_WIND, 0.54, K_THROW_REL, 0.8, K_THROW_REL, 1.0, K_IDLE],
	C_CAST: [0.0, K_IDLE, 0.2, K_CAST, 0.55, K_CAST, 0.68, K_THROW_REL, 1.0, K_IDLE],
	C_CHOP: [0.0, K_IDLE, 0.38, K_CHOP_UP, 0.54, K_CHOP_DOWN, 0.8, K_CHOP_DOWN, 1.0, K_IDLE],
	C_INTERACT: [0.0, K_REST, 0.3, K_BOW, 0.7, K_BOW, 1.0, K_REST],
	C_SPAWN: [0.0, K_CROUCH, 0.55, K_CROUCH, 1.0, K_IDLE],
}

# fourreau dans le dos (repère du buste) : de la hanche gauche à l'épaule droite
const SAYA_ROT := Vector3(0.12, 0.0, -0.78)
const SAYA_POS := Vector3(0.0, 0.04, 0.165)
# ronin : fourreau glissé dans l'obi, à la hanche gauche (repère du bassin) ; +Y du repère = vers l'embouchure
# (devant, un peu vers le centre et en l'air), la pointe dépasse derrière à gauche
const HIP_SAYA_ROT := Vector3(-1.22, -0.32, 0.0)
const HIP_SAYA_POS := Vector3(-0.17, 0.07, 0.12)
const IRON := Color("#3A3C42")
const WOOD_D := Color("#4A3A2C")
const EYE_WHITE := Color("#F6F1E6")

## Palette par défaut (héros, tenue « sumi » : indigo d'encre, vermillon, or).
const DEF := {
	"cloth": Color("#2A2C44"), "dark": Color("#1F2033"), "under": Color("#D9D2C0"), "accent": Color("#D7372B"),
	"band": Color("#D7372B"), "wrap": Color("#D9D2C0"), "tekko": Color("#1B1A22"), "skin": Color("#F2D7B6"),
	"glove": Color("#F2D7B6"), "tabi": Color("#3A3644"), "plate": Color("#C49A45"), "saya": Color("#2A1A1E"),
	"steel": Color("#E9EEF0"), "eye": Color("#1B1A1E"), "hair": Color("#1E1B22"), "gold": Color("#C49A45"),
	"hat": Color("#D8BE88"), "hatd": Color("#8F7646"), "wave": Color("#6F9BC8"), "hem": Color("#2A2733"),
}
const PAL_KEYS := ["cloth", "dark", "under", "accent", "band", "wrap", "tekko", "skin", "glove", "tabi", "plate",
	"saya", "steel", "eye", "hair", "gold", "hat", "hatd", "wave", "hem"]

## Ronin de papier (héros) : kimono washi, hakama bleu de Prusse aux vagues claires, obi d'encre, tabi blancs.
## Le vermillon est réservé à l'écharpe (hero.gd) ; le chapeau de paille est la seule touche chaude.
const RONIN_PAL := {
	"cloth": Color("#F4EAD6"), "dark": Color("#1F3A5C"), "under": Color("#FBF6EA"), "accent": Color("#2A2733"),
	"band": Color("#2A2733"), "wrap": Color("#EFE6D2"), "tekko": Color("#2A2733"), "skin": Color("#F2D7B6"),
	"glove": Color("#F2D7B6"), "tabi": Color("#EFE6D2"), "plate": Color("#C49A45"), "saya": Color("#2A1A1E"),
	"hair": Color("#1E1B22"), "hat": Color("#D8BE88"), "hatd": Color("#8F7646"), "wave": Color("#6F9BC8"),
	"hem": Color("#2A2733"),
}

## Tenues de la garde-robe (meta.OUTFITS) : couleurs de l'étoffe tirées de la teinte de chaque tenue.
const OUTFIT_PAL := {
	"sumi": {},
	"indigo": {"cloth": Color("#2B4C7E"), "dark": Color("#1E355A"), "under": Color("#E6ECF4"), "band": Color("#EFE6D2"),
		"wrap": Color("#E6ECF4")},
	"matcha": {"cloth": Color("#5E7F4A"), "dark": Color("#3F5A33"), "under": Color("#EFE6D2"), "accent": Color("#C49A45"),
		"band": Color("#2B2A36"), "wrap": Color("#EFE6D2")},
	"kaki": {"cloth": Color("#D8622A"), "dark": Color("#8E3A18"), "under": Color("#F5EEDD"), "accent": Color("#1B1A1E"),
		"band": Color("#1B1A1E"), "wrap": Color("#3A2C28")},
	"sakura": {"cloth": Color("#D98AA0"), "dark": Color("#A85A72"), "under": Color("#FBEDEE"), "accent": Color("#7A2A44"),
		"band": Color("#FFFFFF"), "wrap": Color("#FBEDEE")},
	"neige": {"cloth": Color("#ECE8E0"), "dark": Color("#B9BCC8"), "under": Color("#FFFFFF"), "accent": Color("#1F3A5F"),
		"band": Color("#D7372B"), "wrap": Color("#D5DEEA"), "tekko": Color("#3A3C48")},
	"glycine": {"cloth": Color("#7A5FA0"), "dark": Color("#54407A"), "under": Color("#EDE4F6"), "accent": Color("#E2B04A"),
		"band": Color("#E2B04A"), "wrap": Color("#EDE4F6")},
	"or": {"cloth": Color("#2A2530"), "dark": Color("#1B1A1E"), "under": Color("#E2B04A"), "accent": Color("#E2B04A"),
		"band": Color("#E2B04A"), "wrap": Color("#E2B04A"), "plate": Color("#FFD873"), "saya": Color("#7A5420")},
}

## Clan des ninjas (enemy.gd NINJA_KINDS) : shinobi indigo, lanceur gris, fumée glycine, kunoichi cramoisie.
const ENEMY_PAL := {
	"shinobi": {"cloth": Color("#2B3A66"), "dark": Color("#1E2A4A"), "under": Color("#C9D1E6"), "accent": Color("#B8352B"),
		"band": Color("#B8352B"), "wrap": Color("#C9D1E6"), "plate": Color("#B4BAC2"), "saya": Color("#1F1C24"),
		"eye": Color("#E0A020"), "weapon": "katana"},
	"shuriken": {"cloth": Color("#5B6170"), "dark": Color("#3E4350"), "under": Color("#C8CCD4"), "accent": Color("#2B2A36"),
		"band": Color("#2B2A36"), "wrap": Color("#C8CCD4"), "plate": Color("#B4BAC2"), "eye": Color("#E0A020"),
		"weapon": "shuriken"},
	"kemuri": {"cloth": Color("#6E5A92"), "dark": Color("#4A3A66"), "under": Color("#D9CCEB"), "accent": Color("#3A3448"),
		"band": Color("#D9B8FF"), "wrap": Color("#D9CCEB"), "plate": Color("#8E84A0"), "eye": Color("#9A5FE0"),
		"weapon": "smoke"},
	"kunoichi": {"cloth": Color("#9A2438"), "dark": Color("#5C1622"), "under": Color("#F2D7DC"), "accent": Color("#C2456A"),
		"band": Color("#1B1A1E"), "wrap": Color("#F2D7DC"), "plate": Color("#C49A45"), "eye": Color("#E0A020"),
		"weapon": "kusarigama", "ponytail": true},
}

static var _cache := {}  # "clé de palette|pièce" -> ArrayMesh (null : pièce absente)
static var _collar: ArrayMesh = null

var model: Node3D  # racine mise à l'échelle (hauteur demandée)
var anim: AnimationPlayer = null  # pas d'AnimationPlayer : animation procédurale
var skeleton: Skeleton3D = null
var scale_factor := 1.0
var idle := "Idle"
var spin_self := true  # la toupie tourne le bassin (le héros, lui, fait déjà tourner son corps)
var combat_idle := false  # repos = garde basse, arme pointée (ennemis)
var blade: Node3D  # arme tenue à la main droite
var hilt: MeshInstance3D  # poignée du katana au fourreau (cachée quand la lame est tirée)
var knot: Node3D  # nuque : point d'attache des pans de l'écharpe du héros
var _once := false
var _current := ""
var _cfg := {}
var _pk := ""
var _weapon := "katana"
var _ronin := false  # Ronin de papier (héros) : chapeau, visage nu, kimono, sabre à la hanche
var _built := false
var _mats: Array[StandardMaterial3D] = []
var _mat_o: StandardMaterial3D  # étoffes, contour d'encre
var _mat_f: StandardMaterial3D  # yeux, lames : sans contour
var _joints: Array[Node3D] = []
var _part_mi: Array[MeshInstance3D] = []
var _part_id := PackedStringArray()
var _tails: Array[Node3D] = []  # pans du hachimaki : [gauche 0, gauche 1, droite 0, droite 1]
var _pony: Node3D
var _slots := {}  # articulation -> support d'objets accrochés (unités du monde)
# lecture
var _clip := C_IDLE
var _t := 0.0
var _speed := 1.0
var _loop := true
var _blend := 0.0
var _blend_len := 0.0
var _from: Array[Vector3] = []  # pose figée au changement de clip
var _tgt: Array[Vector3] = []  # pose du clip à l'instant
var _out: Array[Vector3] = []  # pose affichée
var _ka: Array[Vector3] = []
var _kb: Array[Vector3] = []
var _armed := 0.0  # 0..1 : arme tirée (bras droit de course)
var _life := 0.0
var _stream := 0.0  # 0..1 : vitesse, les pans filent derrière
var _last_gp := Vector3.ZERO


# ------------------------------------------------------------------ palettes

## Palette du héros (Ronin de papier) : fixe (décision : seule l'écharpe change, voir meta « cape »). Les tenues
## de la garde-robe (meta.OUTFITS) ne teintent plus le hakama ; l'argument est gardé pour l'appelant.
static func hero_config(_outfit := "sumi") -> Dictionary:
	var d := {"weapon": "katana", "ponytail": true, "combat": false, "ronin": true}
	for k in RONIN_PAL:
		d[k] = RONIN_PAL[k]
	return d


## Palette d'un ninja ennemi (shinobi, shuriken, kemuri, kunoichi).
static func enemy_config(kind: String) -> Dictionary:
	var d := {"weapon": "katana", "ponytail": false, "combat": true}
	var o: Dictionary = ENEMY_PAL.get(kind, ENEMY_PAL["shinobi"])
	for k in o:
		d[k] = o[k]
	return d


static func _c(cfg: Dictionary, k: String) -> Color:
	var c: Color = cfg.get(k, DEF.get(k, Color.MAGENTA))
	return c


static func _pal_key(cfg: Dictionary) -> String:
	var s := ""
	for k in PAL_KEYS:
		s += _c(cfg, String(k)).to_html(false)
	s += String(cfg.get("weapon", "katana"))
	s += "p" if bool(cfg.get("ponytail", false)) else "-"
	s += "R" if bool(cfg.get("ronin", false)) else "N"
	s += "L" if Toon.lite else "F"
	return s


# ------------------------------------------------------------------ montage

## `cfg` : palette (hero_config, enemy_config) ; `height` : hauteur voulue (m).
func setup(cfg: Dictionary, height := H_REF) -> void:
	_cfg = cfg
	combat_idle = bool(cfg.get("combat", false))
	_weapon = String(cfg.get("weapon", "katana"))
	_ronin = bool(cfg.get("ronin", false))
	scale_factor = height / H_REF
	model = Node3D.new()
	model.name = "Ninja"
	add_child(model)
	model.scale = Vector3.ONE * scale_factor
	_mat_o = _toon(true)
	_mat_f = _toon(false)
	_mats.clear()
	_mats.append(_mat_o)
	_mats.append(_mat_f)
	_make_joints()
	_pk = _pal_key(cfg)
	_dress()
	_from.clear()
	_tgt.clear()
	_out.clear()
	_ka.clear()
	_kb.clear()
	for j in SLOTS:
		_from.append(Vector3.ZERO)
		_tgt.append(Vector3.ZERO)
		_out.append(Vector3.ZERO)
		_ka.append(Vector3.ZERO)
		_kb.append(Vector3.ZERO)
	_built = true
	_current = idle
	_clip = _clip_of(idle)
	_armed = 1.0 if combat_idle else 0.0
	_eval(0.0)
	for j in SLOTS:
		_out[j] = _tgt[j]
	_apply()
	if is_inside_tree():
		_last_gp = global_position


static func _toon(outline: bool) -> StandardMaterial3D:
	var m := Toon.mat(Color.WHITE, outline, OUTLINE)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.rim = 0.35
	m.rim_tint = 0.5
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	return m


func _make_joints() -> void:
	_joints.clear()
	for j in J_COUNT:
		var nd := Node3D.new()
		nd.name = String(JOINT_NAMES[j])
		var o: Vector3 = OFFSET[j]
		nd.position = o
		var p: int = PARENT[j]
		if p < 0:
			model.add_child(nd)
		else:
			_joints[p].add_child(nd)
		_joints.append(nd)
	# pans du hachimaki : deux maillons par pan, accrochés au nœud derrière la tête
	_tails.clear()
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var t0 := Node3D.new()
		t0.position = Vector3(sx * 0.03, 0.37, 0.27)
		_joints[J_HEAD].add_child(t0)
		var t1 := Node3D.new()
		t1.position = Vector3(0, -0.19, 0)
		t0.add_child(t1)
		_tails.append(t0)
		_tails.append(t1)
	if bool(_cfg.get("ponytail", false)):
		_pony = Node3D.new()
		# kunoichi : haut du crâne ; ronin : nouée sur la nuque, sous le chapeau
		_pony.position = Vector3(0, 0.33, 0.25) if _ronin else Vector3(0, 0.47, 0.21)
		_joints[J_HEAD].add_child(_pony)
	knot = Node3D.new()
	knot.position = Vector3(0, -0.03, 0.22)
	_joints[J_NECK].add_child(knot)


## Pièces posées sur les articulations (maillages du cache de la palette).
func _dress() -> void:
	_part_mi.clear()
	_part_id = PackedStringArray()
	_part(J_HIPS, "hips")
	_part(J_CHEST, "chest")
	_part(J_NECK, "neck")
	_part(J_HEAD, "head")
	_part(J_SHO_L, "upper")
	_part(J_SHO_R, "upper")
	_part(J_ELB_L, "lower")
	_part(J_ELB_R, "lower")
	_part(J_HAND_L, "hand")
	_part(J_HAND_R, "hand")
	_part(J_THI_L, "thigh")
	_part(J_THI_R, "thigh")
	_part(J_SHIN_L, "shin")
	_part(J_SHIN_R, "shin")
	_part(J_FOOT_L, "foot_l")
	_part(J_FOOT_R, "foot_r")
	if not _ronin:
		# pans du hachimaki (le ronin n'en porte pas)
		for i in _tails.size():
			_part_on(_tails[i], "tail" if i % 2 == 0 else "tail_end")
	if _pony != null:
		_part_on(_pony, "pony")
	blade = _part(J_HAND_R, "weapon_r")
	if _weapon == "kusarigama":
		_part(J_HAND_L, "weapon_l")
	if _weapon == "katana":
		# poignée au fourreau : dans le dos (ninja) ou à la hanche gauche (ronin)
		hilt = _part(J_HIPS if _ronin else J_CHEST, "hilt")
		hilt.visible = false  # ennemis : le sabre est en main ; le héros bascule poignée / lame lui-même


func _part(j: int, id: String) -> MeshInstance3D:
	return _part_on(_joints[j], id)


func _part_on(parent: Node3D, id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	parent.add_child(mi)
	if Toon.lite:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_part_mi.append(mi)
	_part_id.append(id)
	_fill(mi, id)
	return mi


func _fill(mi: MeshInstance3D, id: String) -> void:
	var m := _mesh(id)
	mi.mesh = m
	if m == null:
		return
	for i in m.get_surface_count():
		mi.set_surface_override_material(i, _mat_o if i == 0 else _mat_f)


func _mesh(id: String) -> ArrayMesh:
	var key := _pk + "|" + id
	if _cache.has(key):
		var got: ArrayMesh = _cache[key]
		return got
	var m := _build(id, _cfg, Toon.lite)
	_cache[key] = m
	return m


## Nouvelle palette (tenue de la garde-robe) : mêmes pièces, maillages recolorés (cache).
func set_palette(cfg: Dictionary) -> void:
	if not _built:
		return
	# l'arme et la queue de cheval restent celles du montage
	var d := cfg.duplicate()
	d["weapon"] = _weapon
	d["ponytail"] = _pony != null
	d["ronin"] = _ronin
	_cfg = d
	_pk = _pal_key(d)
	for i in _part_mi.size():
		var mi := _part_mi[i]
		if is_instance_valid(mi):
			_fill(mi, _part_id[i])


# ------------------------------------------------------------------ interface de Character

func has_animation(_a: String) -> bool:
	return true


func length(a: String) -> float:
	return float(CLIP_LEN[_clip_of(a)])


## Animation en boucle (attente, marche, course…).
func play(a: String, speed := 1.0, blend := 0.2) -> void:
	if a == "" or not _built:
		return
	if a == _current and not _once:
		_speed = speed
		_gait(speed)
		return
	_once = false
	_current = a
	_start(_clip_of(a), speed, blend, true)
	_gait(speed)


## Animation jouée une fois, puis retour à `idle`.
func play_once(a: String, speed := 1.0, blend := 0.1) -> void:
	if a == "" or not _built:
		return
	var again := a == _current
	_once = true
	_current = a
	if again:
		# même animation : on la relance (court fondu, pas de saut de pose)
		_start(_clip_of(a), speed, 0.05, false)
	else:
		_start(_clip_of(a), speed, blend, false)


## Fige la pose finale (mort) : la boucle ne reprend pas.
func hold() -> void:
	_once = false
	idle = ""


func set_flash(a: float) -> void:
	for m in _mats:
		m.emission = Color.WHITE
		m.emission_energy_multiplier = a


func set_glow(a: float, color := Toon.VERMILION) -> void:
	for m in _mats:
		m.emission = color
		m.emission_energy_multiplier = a


## Liseré de lumière (le héros le veut plus franc) ; `detail` (grain) ignoré : aplats.
func paint(_detail: Texture2D, rim: float, rim_tint: float) -> void:
	for m in _mats:
		m.rim = rim
		m.rim_tint = rim_tint


## Accroche un objet (unités du monde) à une articulation (noms KayKit acceptés : « handslot.r », « chest »…).
func attach(bone: String, node: Node3D) -> void:
	var j := _joint_index(bone)
	if j < 0 or j >= _joints.size():
		add_child(node)
		return
	var holder: Node3D = null
	var got = _slots.get(j)
	if got != null and is_instance_valid(got):
		holder = got
	if holder == null:
		holder = Node3D.new()
		holder.scale = Vector3.ONE / maxf(scale_factor, 0.001)
		_joints[j].add_child(holder)
		_slots[j] = holder
	holder.add_child(node)


func attach_mesh(bone: String, mesh: Mesh, material: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(bone, mi)
	return mi


## Rien à cacher : pas de sous-maillages importés.
func hide_meshes(_patterns: Array) -> void:
	pass


func _joint_index(bone: String) -> int:
	match bone:
		"handslot.r", "hand.r", "wrist.r":
			return J_HAND_R
		"handslot.l", "hand.l", "wrist.l":
			return J_HAND_L
		"hips", "root":
			return J_HIPS
		"spine":
			return J_SPINE
		"chest", "upperchest":
			return J_CHEST
		"neck":
			return J_NECK
		"head", "Head":
			return J_HEAD
		"upperarm.l":
			return J_SHO_L
		"lowerarm.l":
			return J_ELB_L
		"upperarm.r":
			return J_SHO_R
		"lowerarm.r":
			return J_ELB_R
		"upperleg.l":
			return J_THI_L
		"lowerleg.l":
			return J_SHIN_L
		"foot.l":
			return J_FOOT_L
		"upperleg.r":
			return J_THI_R
		"lowerleg.r":
			return J_SHIN_R
		"foot.r":
			return J_FOOT_R
	return -1


## Nom d'animation KayKit -> clip procédural (inconnu : attente).
func _clip_of(a: String) -> int:
	match a:
		"Idle", "Idle_B", "Unarmed_Idle":
			return C_STANCE if combat_idle else C_IDLE
		"Idle_Combat", "2H_Melee_Idle", "1H_Melee_Idle":
			return C_STANCE
		"Walking_A", "Walking_B", "Walking_C", "Walking_D_Skeletons", "Walking_Backwards":
			return C_WALK
		"Running_A", "Running_B", "Running_C":
			return C_RUN
		"1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "2H_Melee_Attack_Slice":
			return C_SLASH
		"2H_Melee_Attack_Spinning":
			return C_SPIN
		"Block", "Blocking", "Block_Hit":
			return C_BLOCK
		"Jump_Full_Short", "Jump_Full_Long", "Jump_Start":
			return C_JUMP
		"1H_Melee_Attack_Stab", "2H_Melee_Attack_Stab":
			return C_STAB
		"Hit_A", "Hit_B":
			return C_HIT
		"Death_A", "Death_B", "Death_C_Skeletons":
			return C_DEATH
		"Throw":
			return C_THROW
		"Spellcast_Shoot", "Spellcasting", "Spellcast_Raise":
			return C_CAST
		"1H_Melee_Attack_Chop", "2H_Melee_Attack_Chop":
			return C_CHOP
		"Interact", "PickUp":
			return C_INTERACT
		"Spawn_Ground_Skeletons", "Spawn_Ground":
			return C_SPAWN
	return C_STANCE if combat_idle else C_IDLE


## Marche rapide = course (les ennemis pressés jouent leur marche accélérée).
func _gait(speed: float) -> void:
	if _clip != C_WALK and _clip != C_RUN:
		return
	if _clip_of(_current) != C_WALK:
		return  # vraie course : vitesse telle quelle
	var want := C_RUN if speed >= 1.35 else C_WALK
	if want != _clip:
		# même phase du pas : pas de saut de jambes
		var k := _t / float(CLIP_LEN[_clip])
		_clip = want
		_t = k * float(CLIP_LEN[_clip])
	_speed = speed * 0.75 if want == C_RUN else speed


func _start(clip: int, speed: float, blend: float, loop: bool) -> void:
	# pose affichée figée (angles ramenés dans ]-π, π] : pas de tour complet au fondu)
	for j in SLOTS:
		var o := _out[j]
		if j == SLOT_HIP:
			_from[j] = o
		else:
			_from[j] = Vector3(wrapf(o.x, -PI, PI), wrapf(o.y, -PI, PI), wrapf(o.z, -PI, PI))
	_clip = clip
	_t = 0.0
	_speed = speed
	_loop = loop
	_blend = 0.0
	_blend_len = maxf(blend, 0.0)


# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	if not _built:
		if _pt != 0:
			Perf.add(&"ninja_rig", _pt)
		return
	var dt := clampf(delta, 0.0, 0.1)
	_life = fmod(_life + dt, 1000.0)
	_t += dt * maxf(_speed, 0.0)
	var ln := float(CLIP_LEN[_clip])
	if _t >= ln:
		if _loop:
			_t = fmod(_t, ln)
		else:
			_t = ln
			if _once and idle != "":
				_once = false
				_current = ""
				play(idle)
	var want_armed := 1.0 if blade != null and blade.visible else 0.0
	_armed = move_toward(_armed, want_armed, dt * 5.0)
	_eval(clampf(_t / float(CLIP_LEN[_clip]), 0.0, 1.0))
	if _blend < _blend_len:
		_blend += dt
		var w := clampf(_blend / maxf(_blend_len, 0.0001), 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		for j in SLOTS:
			_out[j] = _from[j].lerp(_tgt[j], w)
	else:
		for j in SLOTS:
			_out[j] = _tgt[j]
	_apply()
	_update_tails(dt)
	if _pt != 0:
		Perf.add(&"ninja_rig", _pt)


func _apply() -> void:
	for j in J_COUNT:
		_joints[j].rotation = _out[j]
	var base: Vector3 = OFFSET[J_HIPS]
	_joints[J_HIPS].position = base + _out[SLOT_HIP]


## Pose du clip courant à l'avancement `u` (0..1) dans _tgt.
func _eval(u: float) -> void:
	match _clip:
		C_IDLE, C_STANCE:
			_idle_pose(u, _clip == C_STANCE)
		C_WALK:
			_cycle(u, false)
		C_RUN:
			_cycle(u, true)
		_:
			if _clip == C_BLOCK and _loop:
				# garde tenue (« Blocking » en boucle) : souffle léger
				_key(K_GUARD, _tgt)
				_tgt[J_SPINE] += Vector3(0.02 * sin(u * TAU), 0, 0)
				return
			if not SEQ.has(_clip):
				_idle_pose(u, combat_idle)
				return
			var seq: Array = SEQ[_clip]
			_seq(seq, u)
			if _clip == C_SPIN and spin_self:
				var e := u * u * (3.0 - 2.0 * u)
				_tgt[J_HIPS] += Vector3(0, TAU * e, 0)
			elif _clip == C_CAST and u > 0.12 and u < 0.6:
				# la chaîne tournoie au-dessus de la tête
				var wv := u * TAU * 5.0
				_tgt[J_SHO_L] += Vector3(0.3 * cos(wv), 0, 0.3 * sin(wv))


func _seq(seq: Array, u: float) -> void:
	var n := seq.size() >> 1
	var i := 0
	while i < n - 2 and u > float(seq[(i + 1) * 2]):
		i += 1
	var t0 := float(seq[i * 2])
	var t1 := float(seq[(i + 1) * 2])
	var w := clampf((u - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	_key(int(seq[i * 2 + 1]), _ka)
	_key(int(seq[i * 2 + 3]), _kb)
	for j in SLOTS:
		_tgt[j] = _ka[j].lerp(_kb[j], w)


## Attente : respiration (buste, épaules), le regard levé vers la caméra.
func _idle_pose(u: float, stance: bool) -> void:
	_key(K_STANCE if stance else K_REST, _tgt)
	var b := sin(u * TAU)
	_tgt[J_SPINE] += Vector3(0.025 * b, 0, 0)
	_tgt[J_CHEST] += Vector3(-0.02 * b, 0, 0)
	_tgt[J_HEAD] += Vector3(0.02 * b, 0, 0)
	_tgt[J_SHO_L] += Vector3(0, 0, -0.03 * b)
	_tgt[J_SHO_R] += Vector3(0, 0, 0.03 * b)
	_tgt[SLOT_HIP] += Vector3(0, 0.008 * b, 0)


## Marche et course : balancier des jambes (genou levé en avant), bras opposés, bassin qui ondule ;
## course : penché, genoux hauts. Arme tirée : le bras droit tient la lame (traînée basse en course).
func _cycle(u: float, run: bool) -> void:
	_key(K_REST, _tgt)
	var p := u * TAU
	var s := sin(p)
	var c := cos(p)
	var amp := 0.95 if run else 0.5
	var knee := 1.25 if run else 0.6
	var bend := 0.3 if run else 0.1
	var tl := amp * s
	var tr := -amp * s
	var kl := -bend - knee * maxf(0.0, c)
	var kr := -bend - knee * maxf(0.0, -c)
	_tgt[J_THI_L] = Vector3(tl, 0, -0.05)
	_tgt[J_THI_R] = Vector3(tr, 0, 0.05)
	_tgt[J_SHIN_L] = Vector3(kl, 0, 0)
	_tgt[J_SHIN_R] = Vector3(kr, 0, 0)
	_tgt[J_FOOT_L] = Vector3(-0.6 * (tl + kl), 0, 0.05)
	_tgt[J_FOOT_R] = Vector3(-0.6 * (tr + kr), 0, -0.05)
	var arm := 1.0 if run else 0.45
	var elb := 1.3 if run else 0.35
	_tgt[J_SHO_L] = Vector3(-arm * s, 0, -0.25)
	_tgt[J_ELB_L] = Vector3(elb, 0, 0)
	_tgt[J_SHO_R] = Vector3(arm * s, 0, 0.25)
	_tgt[J_ELB_R] = Vector3(elb, 0, 0)
	_tgt[J_HAND_R] = Vector3.ZERO
	if run:
		_tgt[SLOT_HIP] = Vector3(0, -0.05 + 0.05 * absf(c), 0)
		_tgt[J_HIPS] = Vector3(0, 0.15 * s, 0)
		_tgt[J_SPINE] = Vector3(-0.2, 0, 0)
		_tgt[J_CHEST] = Vector3(-0.05, -0.3 * s, 0)
		_tgt[J_HEAD] = Vector3(0.28, 0.15 * s, 0)
	else:
		_tgt[SLOT_HIP] = Vector3(0, -0.02 + 0.02 * absf(c), 0)
		_tgt[J_HIPS] = Vector3(0, 0.08 * s, 0)
		_tgt[J_SPINE] = Vector3(-0.04, 0, 0)
		_tgt[J_CHEST] = Vector3(0, -0.12 * s, 0)
		_tgt[J_HEAD] = Vector3(0.14, 0.06 * s, 0)
	if _armed > 0.0:
		# lame tirée : traînée derrière en course, pointée devant à la marche
		var sho := Vector3(-0.9 + 0.12 * s, 0, 0.35) if run else Vector3(0.3 + 0.12 * s, 0, 0.22)
		var el := Vector3(0.3, 0, 0) if run else Vector3(0.5, 0, 0)
		var hd := Vector3(-2.7, 0, 0) if run else Vector3(-0.35, 0, 0)
		_tgt[J_SHO_R] = _tgt[J_SHO_R].lerp(sho, _armed)
		_tgt[J_ELB_R] = _tgt[J_ELB_R].lerp(el, _armed)
		_tgt[J_HAND_R] = _tgt[J_HAND_R].lerp(hd, _armed)


## Pans du hachimaki et queue de cheval : pendent et ondulent au repos, filent derrière à la course.
func _update_tails(dt: float) -> void:
	if not is_inside_tree():
		return
	var gp := global_position
	var sp := 0.0
	if dt > 0.0001:
		sp = minf((gp - _last_gp).length() / dt, 14.0)
	_last_gp = gp
	_stream = lerpf(_stream, clampf(sp / 7.0, 0.0, 1.0), minf(1.0, dt * 5.0))
	var rate := 2.2 + 13.0 * _stream
	var amp := 0.1 + 0.28 * _stream
	for i in _tails.size():
		var side := -1.0 if i < 2 else 1.0
		var ph := _life * rate + float(i) * 0.9
		if i % 2 == 0:
			_tails[i].rotation = Vector3(lerpf(-0.25, -1.25, _stream) + amp * 0.5 * sin(ph), 0.0,
				side * (0.18 + amp * 0.4 * sin(ph * 0.7)))
		else:
			_tails[i].rotation = Vector3(lerpf(0.12, -0.2, _stream) + amp * sin(ph + 1.2), 0.0,
				side * amp * 0.5 * sin(ph + 0.4))
	if _pony != null:
		if _ronin:
			# queue nouée sur la nuque : pend, se soulève et flotte à la course
			_pony.rotation = Vector3(lerpf(-0.35, -1.15, _stream) + amp * 0.35 * sin(_life * rate * 0.7), 0.0,
				(0.08 + amp * 0.3) * sin(_life * rate * 0.5 + 0.6))
		else:
			_pony.rotation = Vector3(lerpf(-0.75, -1.3, _stream) + 0.1 * sin(_life * rate * 0.6), 0.0, 0.15 * sin(_life * 2.0))


# ------------------------------------------------------------------ poses clés
# Repères : face vers -Z, droite = +X. Rotation x positive : membre pendant -> vers l'avant ; buste -> en
# arrière (négatif = penché en avant). Épaule z : droite + / gauche - = bras écarté. Genou (tibia) : x négatif.
# Lame en main : x cumulé épaule + coude + main = 0 -> pointée devant, π/2 -> en l'air ; main x -π/2 -> dans
# l'axe de l'avant-bras.

func _q(b: Array[Vector3], j: int, x: float, y: float, z: float) -> void:
	b[j] = Vector3(x, y, z)


func _base(b: Array[Vector3]) -> void:
	for j in SLOTS:
		b[j] = Vector3.ZERO
	b[J_SHO_L] = Vector3(0, 0, -0.15)
	b[J_SHO_R] = Vector3(0, 0, 0.15)
	b[J_HEAD] = Vector3(0.12, 0, 0)


func _key(k: int, b: Array[Vector3]) -> void:
	if k == K_IDLE:
		k = K_STANCE if combat_idle else K_REST
	_base(b)
	match k:
		K_REST:
			_q(b, SLOT_HIP, 0, -0.01, 0)
			_q(b, J_SHO_L, 0.05, 0, -0.25)
			_q(b, J_ELB_L, 0.3, 0, 0)
			_q(b, J_SHO_R, 0.08, 0, 0.25)
			_q(b, J_ELB_R, 0.4, 0, 0)
			_q(b, J_THI_L, 0.06, 0, -0.07)
			_q(b, J_SHIN_L, -0.12, 0, 0)
			_q(b, J_FOOT_L, 0.06, 0, 0.07)
			_q(b, J_THI_R, 0.0, 0, 0.07)
			_q(b, J_SHIN_R, -0.06, 0, 0)
			_q(b, J_FOOT_R, 0.06, 0, -0.07)
		K_STANCE:
			# garde basse : genoux fléchis, pied gauche devant, lame pointée vers l'adversaire
			_q(b, SLOT_HIP, 0, -0.05, 0)
			_q(b, J_HIPS, 0, 0.2, 0)
			_q(b, J_SPINE, -0.12, 0, 0)
			_q(b, J_CHEST, -0.06, -0.15, 0)
			_q(b, J_HEAD, 0.22, -0.05, 0)
			_q(b, J_SHO_L, 0.75, 0, -0.15)
			_q(b, J_ELB_L, 1.1, 0, 0)
			_q(b, J_SHO_R, 0.55, 0, 0.3)
			_q(b, J_ELB_R, 0.9, 0, 0)
			_q(b, J_HAND_R, -1.05, 0, 0)
			_q(b, J_THI_L, 0.55, 0, -0.18)
			_q(b, J_SHIN_L, -0.85, 0, 0)
			_q(b, J_FOOT_L, 0.3, 0, 0.18)
			_q(b, J_THI_R, 0.1, 0, 0.2)
			_q(b, J_SHIN_R, -0.7, 0, 0)
			_q(b, J_FOOT_R, 0.55, 0, -0.2)
		K_SLASH_WIND:
			# armé : buste tourné à droite, bras tendu vers l'arrière, lame dans l'axe du bras
			_q(b, SLOT_HIP, 0, -0.05, 0)
			_q(b, J_HIPS, 0, -0.3, 0)
			_q(b, J_SPINE, -0.1, -0.15, 0)
			_q(b, J_CHEST, -0.05, -0.45, 0)
			_q(b, J_HEAD, 0.2, 0.55, 0)
			_q(b, J_SHO_R, 0.0, -0.75, 1.35)
			_q(b, J_ELB_R, 0.15, 0, 0)
			_q(b, J_HAND_R, -1.4, 0, 0)
			_q(b, J_SHO_L, 0.9, 0, -0.3)
			_q(b, J_ELB_L, 0.7, 0, 0)
			_lunge(b, 0.45, -0.1)
		K_SLASH_HIT:
			# taille : le bras balaie devant puis à gauche, buste qui suit
			_q(b, SLOT_HIP, 0, -0.07, 0)
			_q(b, J_HIPS, 0, 0.35, 0)
			_q(b, J_SPINE, -0.15, 0.15, 0)
			_q(b, J_CHEST, -0.05, 0.45, 0)
			_q(b, J_HEAD, 0.25, -0.7, 0)
			_q(b, J_SHO_R, 0.0, 2.1, 1.35)
			_q(b, J_ELB_R, 0.1, 0, 0)
			_q(b, J_HAND_R, -1.4, 0, 0)
			_q(b, J_SHO_L, 0.3, 0, -0.65)
			_q(b, J_ELB_L, 0.4, 0, 0)
			_lunge(b, 0.65, -0.3)
		K_SLASH_THRU:
			# suivi : le corps continue de tourner, la lame file à gauche et un peu bas, la tête suit le coup
			_q(b, SLOT_HIP, 0, -0.09, 0)
			_q(b, J_HIPS, 0, 0.5, 0)
			_q(b, J_SPINE, -0.2, 0.22, 0.06)
			_q(b, J_CHEST, -0.08, 0.55, 0)
			_q(b, J_HEAD, 0.28, -0.75, 0)
			_q(b, J_SHO_R, -0.1, 2.45, 1.2)
			_q(b, J_ELB_R, 0.15, 0, 0)
			_q(b, J_HAND_R, -1.35, 0, 0)
			_q(b, J_SHO_L, 0.15, 0, -0.8)
			_q(b, J_ELB_L, 0.3, 0, 0)
			_lunge(b, 0.75, -0.35)
		K_SLASH_END:
			_q(b, SLOT_HIP, 0, -0.07, 0)
			_q(b, J_HIPS, 0, 0.25, 0)
			_q(b, J_SPINE, -0.1, 0.1, 0)
			_q(b, J_CHEST, -0.03, 0.3, 0)
			_q(b, J_HEAD, 0.2, -0.5, 0)
			_q(b, J_SHO_R, 0.35, 1.5, 0.9)
			_q(b, J_ELB_R, 0.4, 0, 0)
			_q(b, J_HAND_R, -1.1, 0, 0)
			_q(b, J_SHO_L, 0.4, 0, -0.4)
			_q(b, J_ELB_L, 0.6, 0, 0)
			_lunge(b, 0.65, -0.3)
		K_SPIN:
			# toupie : bras en croix, lame tendue à l'horizontale, jambes écartées
			_q(b, SLOT_HIP, 0, -0.08, 0)
			_q(b, J_SPINE, -0.1, 0, 0)
			_q(b, J_HEAD, 0.15, 0, 0)
			_q(b, J_SHO_R, 0.0, 0.25, 1.4)
			_q(b, J_ELB_R, 0.1, 0, 0)
			_q(b, J_HAND_R, -1.45, 0, 0)
			_q(b, J_SHO_L, 0.0, -0.25, -1.3)
			_q(b, J_ELB_L, 0.2, 0, 0)
			_q(b, J_THI_L, 0.3, 0, -0.25)
			_q(b, J_SHIN_L, -0.55, 0, 0)
			_q(b, J_FOOT_L, 0.25, 0, 0.25)
			_q(b, J_THI_R, 0.3, 0, 0.25)
			_q(b, J_SHIN_R, -0.55, 0, 0)
			_q(b, J_FOOT_R, 0.25, 0, -0.25)
		K_GUARD, K_GUARD_HIT:
			# parade haute : lame à l'horizontale devant le front, main gauche en soutien
			var hit := k == K_GUARD_HIT
			_q(b, SLOT_HIP, 0, -0.08 if hit else -0.06, 0)
			_q(b, J_SPINE, 0.18 if hit else 0.02, 0, 0)
			_q(b, J_CHEST, 0, 0.1, 0)
			_q(b, J_HEAD, 0.25 if hit else 0.1, 0, 0)
			_q(b, J_SHO_R, 2.0 if hit else 2.2, 0, -0.35)
			_q(b, J_ELB_R, 0.7, 0, 0)
			_q(b, J_HAND_R, 0, 1.57, 0)
			_q(b, J_SHO_L, 1.85 if hit else 2.0, 0, 0.35)
			_q(b, J_ELB_L, 0.9, 0, 0)
			_lunge(b, 0.35, -0.05)
		K_CROUCH:
			_q(b, SLOT_HIP, 0, -0.18, 0)
			_q(b, J_SPINE, -0.35, 0, 0)
			_q(b, J_CHEST, -0.1, 0, 0)
			_q(b, J_HEAD, 0.35, 0, 0)
			_q(b, J_THI_L, 1.0, 0, -0.12)
			_q(b, J_SHIN_L, -1.6, 0, 0)
			_q(b, J_FOOT_L, 0.6, 0, 0.12)
			_q(b, J_THI_R, 1.0, 0, 0.12)
			_q(b, J_SHIN_R, -1.6, 0, 0)
			_q(b, J_FOOT_R, 0.6, 0, -0.12)
			_q(b, J_SHO_L, -0.5, 0, -0.25)
			_q(b, J_ELB_L, 0.4, 0, 0)
			_q(b, J_SHO_R, -0.4, 0, 0.3)
			_q(b, J_ELB_R, 0.5, 0, 0)
		K_EXTEND:
			_q(b, J_SPINE, -0.1, 0, 0)
			_q(b, J_HEAD, 0.25, 0, 0)
			_q(b, J_SHIN_L, -0.1, 0, 0)
			_q(b, J_FOOT_L, -0.4, 0, 0)
			_q(b, J_SHIN_R, -0.1, 0, 0)
			_q(b, J_FOOT_R, -0.4, 0, 0)
			_q(b, J_SHO_L, 2.6, 0, -0.3)
			_q(b, J_ELB_L, 0.2, 0, 0)
			_q(b, J_SHO_R, 2.4, 0, 0.3)
			_q(b, J_ELB_R, 0.2, 0, 0)
		K_TUCK:
			# en l'air : genoux ramenés, lame devant
			_q(b, SLOT_HIP, 0, 0.05, 0)
			_q(b, J_SPINE, -0.35, 0, 0)
			_q(b, J_CHEST, -0.1, 0, 0)
			_q(b, J_HEAD, 0.4, 0, 0)
			_q(b, J_THI_L, 1.5, 0, -0.1)
			_q(b, J_SHIN_L, -2.1, 0, 0)
			_q(b, J_FOOT_L, 0.4, 0, 0)
			_q(b, J_THI_R, 1.3, 0, 0.1)
			_q(b, J_SHIN_R, -2.0, 0, 0)
			_q(b, J_FOOT_R, 0.4, 0, 0)
			_q(b, J_SHO_R, 0.9, 0, 0.4)
			_q(b, J_ELB_R, 0.6, 0, 0)
			_q(b, J_HAND_R, -0.9, 0, 0)
			_q(b, J_SHO_L, 0.6, 0, -0.4)
			_q(b, J_ELB_L, 1.2, 0, 0)
		K_STAB_WIND:
			# armé : poing ramené à la hanche, lame pointée devant
			_q(b, SLOT_HIP, 0, -0.06, 0)
			_q(b, J_HIPS, 0, -0.35, 0)
			_q(b, J_SPINE, -0.05, -0.15, 0)
			_q(b, J_CHEST, 0, -0.2, 0)
			_q(b, J_HEAD, 0.15, 0.6, 0)
			_q(b, J_SHO_R, -0.5, 0, 0.25)
			_q(b, J_ELB_R, 1.9, 0, 0)
			_q(b, J_HAND_R, -1.4, 0, 0)
			_q(b, J_SHO_L, 1.0, 0, -0.2)
			_q(b, J_ELB_L, 0.5, 0, 0)
			_lunge(b, 0.35, -0.1)
		K_STAB_HIT:
			# estoc : fente profonde, bras et lame dans le même axe
			_q(b, SLOT_HIP, 0, -0.1, 0)
			_q(b, J_HIPS, 0, 0.35, 0)
			_q(b, J_SPINE, -0.25, 0.1, 0)
			_q(b, J_CHEST, -0.1, 0.25, 0)
			_q(b, J_HEAD, 0.35, -0.65, 0)
			_q(b, J_SHO_R, 1.55, 0, 0.05)
			_q(b, J_HAND_R, -1.57, 0, 0)
			_q(b, J_SHO_L, -0.6, 0, -0.3)
			_q(b, J_ELB_L, 0.5, 0, 0)
			_lunge(b, 0.85, -0.45)
		K_HIT:
			# recul : buste rejeté, bras écartés
			_q(b, SLOT_HIP, 0, -0.03, 0)
			_q(b, J_SPINE, 0.25, 0, 0)
			_q(b, J_CHEST, 0.2, 0, 0)
			_q(b, J_HEAD, 0.3, 0, 0.1)
			_q(b, J_SHO_L, -0.3, 0, -0.6)
			_q(b, J_ELB_L, 0.6, 0, 0)
			_q(b, J_SHO_R, -0.2, 0, 0.6)
			_q(b, J_ELB_R, 0.6, 0, 0)
			_q(b, J_THI_L, 0.25, 0, -0.1)
			_q(b, J_SHIN_L, -0.3, 0, 0)
			_q(b, J_THI_R, -0.15, 0, 0.1)
			_q(b, J_SHIN_R, -0.2, 0, 0)
		K_DEATH_KNEEL:
			_q(b, SLOT_HIP, 0, -0.3, 0)
			_q(b, J_HIPS, 0.2, 0, 0)
			_q(b, J_SPINE, 0.2, 0, 0)
			_q(b, J_CHEST, 0.1, 0, 0)
			_q(b, J_HEAD, 0.3, 0, 0)
			_q(b, J_THI_L, 1.2, 0, -0.1)
			_q(b, J_SHIN_L, -2.0, 0, 0)
			_q(b, J_FOOT_L, 0.6, 0, 0)
			_q(b, J_THI_R, 0.4, 0, 0.1)
			_q(b, J_SHIN_R, -1.6, 0, 0)
			_q(b, J_FOOT_R, 0.9, 0, 0)
			_q(b, J_SHO_L, 0.2, 0, -0.3)
			_q(b, J_SHO_R, 0.2, 0, 0.3)
		K_DEATH_DOWN:
			# étendu sur le dos, bras en croix
			_q(b, SLOT_HIP, 0, -0.48, 0)
			_q(b, J_HIPS, 1.45, 0, 0)
			_q(b, J_SPINE, 0.05, 0, 0)
			_q(b, J_HEAD, 0.2, 0.4, 0)
			_q(b, J_SHO_L, 0.3, 0, -1.2)
			_q(b, J_ELB_L, 0.4, 0, 0)
			_q(b, J_SHO_R, 0.6, 0, 1.1)
			_q(b, J_ELB_R, 0.5, 0, 0)
			_q(b, J_THI_L, 0.35, 0, -0.15)
			_q(b, J_SHIN_L, -0.6, 0, 0)
			_q(b, J_FOOT_L, 0.4, 0, 0)
			_q(b, J_THI_R, 0.1, 0, 0.15)
			_q(b, J_SHIN_R, -0.3, 0, 0)
			_q(b, J_FOOT_R, 0.4, 0, 0)
		K_THROW_WIND:
			_q(b, SLOT_HIP, 0, -0.05, 0)
			_q(b, J_HIPS, 0, -0.35, 0)
			_q(b, J_SPINE, 0.1, 0, 0)
			_q(b, J_CHEST, 0, -0.4, 0)
			_q(b, J_HEAD, 0.15, 0.6, 0)
			_q(b, J_SHO_R, -2.0, 0, 0.5)
			_q(b, J_ELB_R, 0.6, 0, 0)
			_q(b, J_SHO_L, 1.3, 0, -0.2)
			_q(b, J_ELB_L, 0.2, 0, 0)
			_lunge(b, 0.4, -0.2)
		K_THROW_REL:
			_q(b, SLOT_HIP, 0, -0.08, 0)
			_q(b, J_HIPS, 0, 0.35, 0)
			_q(b, J_SPINE, -0.25, 0.1, 0)
			_q(b, J_CHEST, -0.1, 0.35, 0)
			_q(b, J_HEAD, 0.3, -0.7, 0)
			_q(b, J_SHO_R, 1.5, 0, 0)
			_q(b, J_ELB_R, 0.1, 0, 0)
			_q(b, J_SHO_L, -0.4, 0, -0.4)
			_q(b, J_ELB_L, 0.6, 0, 0)
			_lunge(b, 0.6, -0.35)
		K_CAST:
			# bras gauche levé (chaîne qui tournoie), arme droite pointée devant
			_q(b, SLOT_HIP, 0, -0.05, 0)
			_q(b, J_SPINE, 0.05, 0, 0)
			_q(b, J_CHEST, 0, -0.2, 0)
			_q(b, J_HEAD, 0.2, 0.2, 0)
			_q(b, J_SHO_L, 2.7, 0, -0.35)
			_q(b, J_ELB_L, 0.2, 0, 0)
			_q(b, J_SHO_R, 0.8, 0, 0.25)
			_q(b, J_ELB_R, 0.7, 0, 0)
			_q(b, J_HAND_R, -1.2, 0, 0)
			_lunge(b, 0.4, -0.1)
		K_CHOP_UP:
			_q(b, SLOT_HIP, 0, -0.03, 0)
			_q(b, J_SPINE, 0.15, 0, 0)
			_q(b, J_HEAD, 0.1, 0, 0)
			_q(b, J_SHO_R, 2.8, 0, 0.1)
			_q(b, J_ELB_R, 0.4, 0, 0)
			_q(b, J_HAND_R, -0.7, 0, 0)
			_q(b, J_SHO_L, 2.6, 0, -0.1)
			_q(b, J_ELB_L, 0.5, 0, 0)
			_lunge(b, 0.3, -0.05)
		K_CHOP_DOWN:
			_q(b, SLOT_HIP, 0, -0.1, 0)
			_q(b, J_SPINE, -0.35, 0, 0)
			_q(b, J_CHEST, -0.1, 0, 0)
			_q(b, J_HEAD, 0.35, 0, 0)
			_q(b, J_SHO_R, 0.9, 0, 0.05)
			_q(b, J_ELB_R, 0.2, 0, 0)
			_q(b, J_HAND_R, -1.4, 0, 0)
			_q(b, J_SHO_L, 0.9, 0, -0.05)
			_q(b, J_ELB_L, 0.3, 0, 0)
			_lunge(b, 0.75, -0.4)
		K_BOW:
			# salut : buste incliné, mains jointes
			_q(b, SLOT_HIP, 0, -0.02, 0)
			_q(b, J_SPINE, -0.45, 0, 0)
			_q(b, J_CHEST, -0.15, 0, 0)
			_q(b, J_HEAD, -0.1, 0, 0)
			_q(b, J_SHO_L, 0.5, 0, 0.2)
			_q(b, J_ELB_L, 1.4, 0, 0)
			_q(b, J_SHO_R, 0.5, 0, -0.2)
			_q(b, J_ELB_R, 1.4, 0, 0)
	if _ronin and k == K_REST:
		# repos du ronin : poids sur la jambe droite, main gauche posée sur la garde du sabre à la hanche,
		# bras droit relâché, menton un peu levé sous le chapeau
		_q(b, SLOT_HIP, 0, -0.012, 0)
		_q(b, J_HIPS, 0, 0.12, 0)
		_q(b, J_SPINE, -0.03, -0.06, 0.03)
		_q(b, J_CHEST, 0.0, -0.08, 0)
		_q(b, J_HEAD, 0.16, 0.1, -0.03)
		_q(b, J_SHO_L, 0.62, 0.35, -0.18)
		_q(b, J_ELB_L, 1.15, 0, 0)
		_q(b, J_HAND_L, -0.3, 0, 0.2)
		_q(b, J_SHO_R, 0.1, 0, 0.3)
		_q(b, J_ELB_R, 0.25, 0, 0)
		_q(b, J_THI_L, 0.12, 0, -0.14)
		_q(b, J_SHIN_L, -0.2, 0, 0)
		_q(b, J_FOOT_L, 0.08, 0, 0.14)
		_q(b, J_THI_R, -0.04, 0, 0.1)
		_q(b, J_SHIN_R, -0.02, 0, 0)
		_q(b, J_FOOT_R, 0.06, 0, -0.1)


## Fente : jambe gauche devant (cuisse `front`), jambe droite tendue derrière (cuisse `back`).
func _lunge(b: Array[Vector3], front: float, back: float) -> void:
	_q(b, J_THI_L, front, 0, -0.15)
	_q(b, J_SHIN_L, -front * 1.3, 0, 0)
	_q(b, J_FOOT_L, front * 0.3, 0, 0.15)
	_q(b, J_THI_R, back, 0, 0.18)
	_q(b, J_SHIN_R, -0.4 + back * 0.2, 0, 0)
	_q(b, J_FOOT_R, 0.45, 0, -0.18)


# ------------------------------------------------------------------ modelé (maillages partagés)

## Col de l'écharpe du héros (sommets blancs teintés par son matériau), repère du cou, nœud dans la nuque.
static func collar_mesh() -> ArrayMesh:
	if _collar == null:
		var a := Builder.new()
		var sd := 10 if Toon.lite else 16
		a.style(1.0, 1.0)
		a.bands = PackedFloat32Array([0.82, 0.95, 1.0, 1.0, 0.9, 0.8])
		a.lathe(_pv([0.17, -0.08, 0.205, -0.065, 0.218, -0.035, 0.212, 0.0, 0.19, 0.03, 0.155, 0.05]), Color.WHITE, sd,
			Transform3D.IDENTITY, 1.0, 0.88)
		a.style(0.8, 1.0)
		a.ell(Vector3(0, -0.02, 0.19), Vector3(0.075, 0.065, 0.055), Color.WHITE, Vector3.ZERO, 10, 5)
		_collar = ArrayMesh.new()
		a.add_to(_collar)
	return _collar


static func _pv(f: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	var i := 0
	while i + 1 < f.size():
		p.append(Vector2(float(f[i]), float(f[i + 1])))
		i += 2
	return p


## Maillage d'une pièce (surface 0 : avec contour ; surface 1 : détails sans contour). Null si absente.
static func _build(id: String, cfg: Dictionary, lite: bool) -> ArrayMesh:
	var a := Builder.new()
	var d := Builder.new()
	var weapon := String(cfg.get("weapon", "katana"))
	var sd := 8 if lite else 12
	var rg := 4 if lite else 6
	if bool(cfg.get("ronin", false)):
		_build_ronin(id, a, d, cfg, lite)
		return _finish(a, d)
	match id:
		"head":
			_b_head(a, d, cfg, lite)
		"neck":
			a.style(0.66, 0.9)
			a.lathe(_pv([0.18, -0.075, 0.176, -0.035, 0.148, 0.02, 0.11, 0.08, 0.0, 0.1]), _c(cfg, "cloth"), sd + 2,
				Transform3D.IDENTITY, 1.0, 0.82)
		"chest":
			_b_chest(a, cfg, lite, weapon)
		"hips":
			_b_hips(a, cfg, lite, weapon)
		"upper":
			# manche de la veste
			a.style(0.8, 1.0)
			a.pleats = 4
			a.pleat = 0.08
			a.lathe(_pv([0.0, -0.255, 0.05, -0.25, 0.073, -0.225, 0.08, -0.14, 0.078, -0.05, 0.07, 0.01, 0.045, 0.05, 0.0, 0.065]),
				_c(cfg, "cloth"), sd, Transform3D.IDENTITY, 1.0, 0.95)
		"lower":
			# tekko : manchette, bague d'or au poignet, plaque de fer
			a.style(0.8, 1.0)
			a.lathe(_pv([0.0, -0.215, 0.04, -0.21, 0.047, -0.17, 0.055, -0.06, 0.056, 0.0, 0.045, 0.03, 0.0, 0.04]),
				_c(cfg, "tekko"), sd, Transform3D.IDENTITY, 1.0, 1.0)
			a.style(0.85, 1.0)
			a.lathe(_pv([0.048, -0.19, 0.054, -0.18, 0.048, -0.17]), _c(cfg, "gold"), sd, Transform3D.IDENTITY, 1.0, 1.0)
			if not lite:
				a.ell(Vector3(0, -0.1, -0.05), Vector3(0.034, 0.065, 0.013), IRON, Vector3.ZERO, 8, 4)
		"hand":
			a.style(0.85, 1.0)
			a.ell(Vector3(0, -0.045, 0), Vector3(0.046, 0.052, 0.043), _c(cfg, "glove"), Vector3.ZERO, sd, rg)
		"thigh":
			# jambe du hakama, plissée, bouffante au-dessus du genou
			a.style(0.75, 0.95)
			a.pleats = 5
			a.pleat = 0.12
			a.lathe(_pv([0.0, -0.315, 0.06, -0.308, 0.09, -0.28, 0.1, -0.2, 0.102, -0.1, 0.098, -0.02, 0.075, 0.04, 0.0, 0.058]),
				_c(cfg, "dark"), sd, Transform3D.IDENTITY, 1.0, 0.95)
		"shin":
			# kyahan : bandes enroulées (plis plus sombres)
			a.style(0.85, 1.0)
			a.bands = PackedFloat32Array([1.0, 1.0, 0.8, 1.0, 0.8, 1.0, 0.8, 1.0, 1.0, 1.0])
			a.lathe(_pv([0.0, -0.29, 0.045, -0.282, 0.05, -0.25, 0.055, -0.2, 0.062, -0.15, 0.068, -0.1, 0.074, -0.05,
				0.078, 0.0, 0.064, 0.035, 0.0, 0.048]), _c(cfg, "wrap"), sd, Transform3D.IDENTITY, 1.0, 1.0)
		"foot_l", "foot_r":
			# tabi : gros orteil séparé (côté intérieur)
			var inner := 1.0 if id == "foot_l" else -1.0
			var tabi := _c(cfg, "tabi")
			a.style(0.72, 1.0)
			a.ell(Vector3(0, -0.04, -0.025), Vector3(0.056, 0.042, 0.095), tabi, Vector3.ZERO, sd, rg)
			a.ell(Vector3(inner * 0.03, -0.05, -0.115), Vector3(0.023, 0.03, 0.045), tabi, Vector3.ZERO, sd, rg)
			a.ell(Vector3(-inner * 0.016, -0.05, -0.108), Vector3(0.036, 0.03, 0.05), tabi, Vector3.ZERO, sd, rg)
		"hilt":
			if weapon == "katana":
				var rot := Basis.from_euler(SAYA_ROT)
				var xf := Transform3D(rot, SAYA_POS + rot * Vector3(0, 0.4, 0))
				a.style(0.85, 1.0)
				a.lathe(_pv([0.0, 0.0, 0.05, 0.003, 0.052, 0.012, 0.0, 0.016]), _c(cfg, "gold"), 10, xf, 1.0, 0.82)
				_tsuka(a, xf, 0.02, 0.24, cfg, lite)
		"weapon_r":
			_b_weapon(a, d, cfg, lite, weapon)
		"weapon_l":
			if weapon == "kusarigama":
				# chaîne et poids de la kusarigama, pendus à la main gauche
				var nl := 4 if lite else 6
				a.style(0.8, 1.0)
				for i in nl:
					a.ell(Vector3(0, -0.07 - 0.045 * float(i), 0), Vector3(0.016, 0.028, 0.008), IRON,
						Vector3(0, PI * 0.5 * float(i % 2), 0), 6, 3)
				a.ell(Vector3(0, -0.1 - 0.045 * float(nl), 0), Vector3(0.042, 0.042, 0.042), IRON, Vector3.ZERO, 8, 4)
		"tail", "tail_end":
			# pan du hachimaki : ruban plat, effilé au bout
			var band := _c(cfg, "band")
			a.style(0.78, 1.0)
			if id == "tail_end":
				a.lathe(_pv([0.0, -0.21, 0.014, -0.195, 0.032, -0.1, 0.036, 0.0, 0.0, 0.012]), band, 6,
					Transform3D.IDENTITY, 1.0, 0.28)
			else:
				a.lathe(_pv([0.0, -0.205, 0.034, -0.195, 0.036, -0.1, 0.038, 0.0, 0.0, 0.012]), band, 6,
					Transform3D.IDENTITY, 1.0, 0.28)
		"pony":
			# queue de cheval (kunoichi) : mèches marquées
			a.style(0.75, 1.0)
			a.pleats = 3
			a.pleat = 0.18
			a.lathe(_pv([0.0, -0.46, 0.03, -0.43, 0.06, -0.3, 0.07, -0.15, 0.06, -0.04, 0.045, 0.02, 0.0, 0.03]),
				_c(cfg, "hair"), sd, Transform3D.IDENTITY, 1.0, 0.85)
	return _finish(a, d)


static func _finish(a: Builder, d: Builder) -> ArrayMesh:
	if a.v.is_empty():
		return null
	var m := ArrayMesh.new()
	a.add_to(m)
	d.add_to(m)
	return m


# ------------------------------------------------------------------ Ronin de papier

## Pièces du ronin (mêmes articulations et repères que le ninja). Kimono washi : plis, ourlets et col à
## l'encre ; hakama : motif seigaiha en couleurs de sommets (Builder.scales) ; manches amples jusqu'au coude,
## avant-bras nus ; fourreau à la hanche gauche (HIP_SAYA_*), poignée vers l'avant.
static func _build_ronin(id: String, a: Builder, d: Builder, cfg: Dictionary, lite: bool) -> void:
	var sd := 8 if lite else 12
	var rg := 4 if lite else 6
	var cloth := _c(cfg, "cloth")
	var hakama := _c(cfg, "dark")
	var wave := _c(cfg, "wave")
	var hem := _c(cfg, "hem")
	var skin := _c(cfg, "skin")
	match id:
		"head":
			_b_head_ronin(a, d, cfg, lite)
		"neck":
			# cou nu, puis le col du kimono (bord d'encre) qui monte vers la nuque
			a.style(0.8, 0.95)
			a.lathe(_pv([0.1, -0.08, 0.095, 0.02, 0.085, 0.09, 0.0, 0.1]), skin, sd, Transform3D.IDENTITY, 1.0, 0.9)
			a.style(0.7, 0.92)
			a.lathe(_pv([0.19, -0.075, 0.185, -0.045, 0.165, 0.0, 0.13, 0.05, 0.0, 0.07]), cloth, sd + 2,
				Transform3D(Basis.from_euler(Vector3(0.18, 0, 0)), Vector3(0, 0, 0.02)), 1.0, 0.82)
		"chest":
			_b_chest_ronin(a, cfg, lite)
		"hips":
			_b_hips_ronin(a, cfg, lite)
		"upper":
			# manche ample de kimono : s'évase jusqu'au coude, poche de la manche (tamoto) qui pend derrière le
			# bras, ourlet d'encre tout autour, plis tombants
			a.style(0.82, 1.0)
			a.pleats = 3
			a.pleat = 0.1
			a.lathe(_pv([0.0, -0.285, 0.105, -0.278, 0.112, -0.23, 0.098, -0.15, 0.086, -0.08, 0.078, -0.02, 0.06, 0.03,
				0.0, 0.06]), cloth, sd, Transform3D.IDENTITY, 1.0, 0.95)
			a.style(0.74, 0.98)
			a.pleats = 2
			a.pleat = 0.12
			a.lathe(_pv([0.0, -0.33, 0.06, -0.325, 0.085, -0.28, 0.09, -0.2, 0.07, -0.1, 0.0, -0.06]), cloth, sd,
				Transform3D(Basis.from_euler(Vector3(-0.25, 0, 0)), Vector3(0, 0.0, 0.06)), 1.0, 0.8)
			a.style(0.9, 1.0)
			a.lathe(_pv([0.108, -0.284, 0.115, -0.268, 0.109, -0.252]), hem, sd, Transform3D.IDENTITY, 1.0, 0.95)
			a.lathe(_pv([0.07, -0.335, 0.088, -0.31, 0.086, -0.29]), hem, sd,
				Transform3D(Basis.from_euler(Vector3(-0.25, 0, 0)), Vector3(0, 0.0, 0.06)), 1.0, 0.8)
		"lower":
			# avant-bras nu (la manche s'arrête au coude)
			a.style(0.82, 1.0)
			a.lathe(_pv([0.0, -0.215, 0.036, -0.21, 0.04, -0.12, 0.045, -0.02, 0.04, 0.03, 0.0, 0.04]), skin, sd,
				Transform3D.IDENTITY, 1.0, 1.0)
		"hand":
			a.style(0.85, 1.0)
			a.ell(Vector3(0, -0.045, 0), Vector3(0.046, 0.052, 0.043), skin, Vector3.ZERO, sd, rg)
		"thigh":
			# jambe du hakama : large, vagues seigaiha
			a.style(0.78, 0.98)
			_scales(a, 5, wave, 0.7)
			a.lathe(_dense(_pv([0.0, -0.32, 0.112, -0.312, 0.13, -0.26, 0.135, -0.18, 0.13, -0.1, 0.12, -0.03, 0.1, 0.025,
				0.075, 0.048, 0.0, 0.06]), 18), hakama, sd, Transform3D.IDENTITY, 1.0, 0.95)
		"shin":
			# bas du hakama jusqu'à la cheville, ourlet d'encre
			a.style(0.74, 0.95)
			_scales(a, 5, wave, 0.7)
			a.lathe(_dense(_pv([0.0, -0.285, 0.1, -0.278, 0.11, -0.23, 0.115, -0.17, 0.118, -0.11, 0.12, -0.05, 0.116, 0.0,
				0.09, 0.03, 0.0, 0.045]), 18), hakama, sd, Transform3D.IDENTITY, 1.0, 1.0)
			a.style(0.9, 1.0)
			a.lathe(_pv([0.104, -0.286, 0.113, -0.27, 0.108, -0.255]), hem, sd, Transform3D.IDENTITY, 1.0, 1.0)
		"foot_l", "foot_r":
			# tabi blancs à l'orteil séparé, sur une semelle de zōri sombre
			var inner := 1.0 if id == "foot_l" else -1.0
			var tabi := _c(cfg, "tabi")
			a.style(0.78, 1.0)
			a.ell(Vector3(0, -0.04, -0.025), Vector3(0.056, 0.042, 0.095), tabi, Vector3.ZERO, sd, rg)
			a.ell(Vector3(inner * 0.03, -0.05, -0.115), Vector3(0.023, 0.03, 0.045), tabi, Vector3.ZERO, sd, rg)
			a.ell(Vector3(-inner * 0.016, -0.05, -0.108), Vector3(0.036, 0.03, 0.05), tabi, Vector3.ZERO, sd, rg)
			a.style(0.9, 1.0)
			a.ell(Vector3(0, -0.076, -0.045), Vector3(0.06, 0.011, 0.118), hem, Vector3.ZERO, sd, 3)
		"hilt":
			# poignée qui dépasse de l'embouchure, à la hanche gauche
			var rot := Basis.from_euler(HIP_SAYA_ROT)
			var xf := Transform3D(rot, HIP_SAYA_POS + rot * Vector3(0, 0.36, 0))
			a.style(0.85, 1.0)
			a.lathe(_pv([0.0, 0.0, 0.05, 0.003, 0.052, 0.012, 0.0, 0.016]), _c(cfg, "gold"), 10, xf, 1.0, 0.82)
			_tsuka(a, xf, 0.02, 0.24, cfg, lite)
		"weapon_r":
			_b_weapon(a, d, cfg, lite, "katana")
		"pony":
			# queue de cheval nouée (cordon clair), mèches marquées, tombe sur la nuque
			a.style(0.78, 1.0)
			a.ell(Vector3(0, -0.025, 0), Vector3(0.034, 0.03, 0.034), _c(cfg, "under"), Vector3.ZERO, 8, 4)
			a.style(0.7, 1.0)
			a.pleats = 3
			a.pleat = 0.2
			a.lathe(_pv([0.0, -0.34, 0.022, -0.32, 0.046, -0.22, 0.05, -0.12, 0.04, -0.04, 0.028, 0.0, 0.0, 0.012]),
				_c(cfg, "hair"), sd, Transform3D.IDENTITY, 1.0, 0.8)


## Motif seigaiha sur les formes suivantes : `n` écailles par tour, éclaircies vers `col`.
static func _scales(a: Builder, n: int, col: Color, amount: float) -> void:
	a.pleats = n
	a.pleat = 0.0
	a.scales = amount
	a.scale_col = col


## Profil rééchantillonné en `n` anneaux à pas régulier (rangées d'écailles de même hauteur).
static func _dense(prof: PackedVector2Array, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := prof.size()
	if m < 2 or n < 2:
		return prof
	var y0 := prof[0].y
	var y1 := prof[m - 1].y
	for i in n:
		var y := lerpf(y0, y1, float(i) / float(n - 1))
		var r := prof[m - 1].x
		for j in m - 1:
			var p0 := prof[j]
			var p1 := prof[j + 1]
			var lo := minf(p0.y, p1.y)
			var hi := maxf(p0.y, p1.y)
			if y >= lo - 0.00001 and y <= hi + 0.00001:
				var k := 0.0 if absf(p1.y - p0.y) < 0.00001 else clampf((y - p0.y) / (p1.y - p0.y), 0.0, 1.0)
				r = lerpf(p0.x, p1.x, k)
				break
		if i == 0:
			r = prof[0].x
		out.append(Vector2(r, y))
	return out


## Tête du ronin : crâne et visage nus, chevelure sombre (tempes et nuque), chapeau de paille conique posé en
## arrière (le visage reste dégagé vu d'en haut), traits d'encre sans contour : sourcils froncés, yeux fendus,
## nez, bouche fine ; oreilles.
static func _b_head_ronin(a: Builder, d: Builder, cfg: Dictionary, lite: bool) -> void:
	var hs := 12 if lite else 18
	var hr := 7 if lite else 10
	var skin := _c(cfg, "skin")
	var hair := _c(cfg, "hair")
	var hat := _c(cfg, "hat")
	var hatd := _c(cfg, "hatd")
	var ink := _c(cfg, "eye")
	a.style(0.8, 1.0)
	a.ell(Vector3(0, 0.25, 0.01), Vector3(0.258, 0.265, 0.252), skin, Vector3.ZERO, hs, hr)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		a.ell(Vector3(sx * 0.252, 0.225, 0.03), Vector3(0.022, 0.045, 0.03), skin, Vector3.ZERO, 8, 4)
	# chevelure : calotte qui déborde sur les tempes et la nuque, front dégagé
	a.style(0.7, 1.0)
	a.ell(Vector3(0, 0.32, 0.07), Vector3(0.262, 0.225, 0.262), hair, Vector3(0.1, 0, 0), hs, hr)
	# sandogasa : cône de paille à large bord, un peu en arrière ; dessus tressé (anneaux), dessous sombre
	var hxf := Transform3D(Basis.from_euler(Vector3(0.42, 0, 0)), Vector3(0, 0.425, 0.075))
	a.style(0.86, 1.0)
	a.bands = PackedFloat32Array([0.78, 1.0, 0.9, 1.0, 0.9, 1.0, 0.92, 1.0])
	a.lathe(_pv([0.385, 0.0, 0.39, 0.022, 0.345, 0.07, 0.28, 0.135, 0.205, 0.2, 0.13, 0.27, 0.055, 0.33, 0.0, 0.355]),
		hat, hs, hxf, 1.0, 1.0)
	a.style(0.6, 0.75)
	a.lathe(_pv([0.0, 0.325, 0.13, 0.255, 0.28, 0.125, 0.385, 0.0]), hatd, hs, hxf, 1.0, 1.0)
	if not lite:
		# cordon du chapeau noué sous le menton
		a.style(0.9, 1.0)
		a.ell(Vector3(0, 0.005, -0.1), Vector3(0.2, 0.009, 0.012), _c(cfg, "hem"), Vector3.ZERO, 10, 3)
	# traits d'encre (sans contour) : sourcils froncés, yeux fendus, nez, bouche
	d.style(1.0, 1.0)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		d.ell(Vector3(sx * 0.085, 0.312, -0.236), Vector3(0.056, 0.011, 0.012), ink, Vector3(0, -sx * 0.32, sx * 0.3), 8, 3)
		d.ell(Vector3(sx * 0.082, 0.258, -0.248), Vector3(0.046, 0.013, 0.012), ink, Vector3(0, -sx * 0.32, sx * 0.05), 8, 3)
	d.ell(Vector3(0.012, 0.212, -0.258), Vector3(0.007, 0.03, 0.01), skin.darkened(0.3), Vector3(0, 0, 0.1), 6, 3)
	d.ell(Vector3(0.0, 0.162, -0.244), Vector3(0.036, 0.0065, 0.012), ink, Vector3.ZERO, 8, 3)


## Buste du ronin : kimono washi croisé (plis, col et pans marqués à l'encre, juban blanc dans le V).
static func _b_chest_ronin(a: Builder, cfg: Dictionary, lite: bool) -> void:
	var sides := 10 if lite else 14
	var sd := 8 if lite else 10
	var rg := 4 if lite else 5
	var cloth := _c(cfg, "cloth")
	var hem := _c(cfg, "hem")
	a.style(0.82, 1.0)
	a.pleats = 4
	a.pleat = 0.09
	a.lathe(_pv([0.17, -0.19, 0.175, -0.12, 0.182, -0.02, 0.192, 0.08, 0.2, 0.15, 0.185, 0.2, 0.14, 0.235, 0.07, 0.25,
		0.0, 0.255]), cloth, sides, Transform3D.IDENTITY, 1.0, 0.72)
	# juban blanc dans le V ; pan droit (dessous) : son bord ne se voit que près du cou ; pan gauche (dessus) :
	# son ourlet d'encre traverse toute la poitrine en diagonale jusqu'à la hanche droite, comme un vrai kimono
	a.style(0.9, 1.0)
	a.ell(Vector3(0, 0.13, -0.13), Vector3(0.07, 0.075, 0.026), _c(cfg, "under"), Vector3(0.25, 0, 0), sd, rg)
	a.ell(Vector3(0.065, 0.13, -0.132), Vector3(0.011, 0.085, 0.014), hem, Vector3(0.1, 0.35, 0.45), 6, rg)
	a.ell(Vector3(-0.03, 0.165, -0.13), Vector3(0.03, 0.085, 0.018), cloth, Vector3(0.1, 0, -0.5), sd, rg)
	# ourlet du pan gauche : trois segments qui épousent le buste (du cou à gauche vers la hanche droite)
	for seg in [Vector3(-0.012, 0.105, -0.138), Vector3(0.048, -0.005, -0.128), Vector3(0.102, -0.115, -0.108)]:
		var c: Vector3 = seg
		a.ell(c, Vector3(0.011, 0.07, 0.014), hem, Vector3(0.0, -0.3 * (c.x / 0.1), 0.48), 6, rg)


## Bassin du ronin : haut du hakama aux vagues seigaiha, obi d'encre au cordon d'or, nœud ; fourreau laqué
## glissé dans l'obi à gauche (embouchure devant, pointe derrière).
static func _b_hips_ronin(a: Builder, cfg: Dictionary, lite: bool) -> void:
	var sides := 10 if lite else 14
	var sd := 8 if lite else 10
	var rg := 4 if lite else 5
	var accent := _c(cfg, "accent")
	var gold := _c(cfg, "gold")
	a.style(0.78, 0.98)
	_scales(a, 6, _c(cfg, "wave"), 0.7)
	a.lathe(_dense(_pv([0.15, -0.13, 0.178, -0.08, 0.19, 0.0, 0.186, 0.08, 0.176, 0.13]), 12), _c(cfg, "dark"), sides,
		Transform3D.IDENTITY, 1.0, 0.8)
	a.style(0.84, 1.0)
	a.lathe(_pv([0.183, 0.075, 0.195, 0.1, 0.198, 0.15, 0.188, 0.185]), accent, sides, Transform3D.IDENTITY, 1.0, 0.78)
	a.lathe(_pv([0.196, 0.118, 0.203, 0.126, 0.196, 0.134]), gold, sides, Transform3D.IDENTITY, 1.0, 0.79)
	a.ell(Vector3(-0.07, 0.13, -0.154), Vector3(0.05, 0.036, 0.03), accent.darkened(0.12), Vector3.ZERO, sd, rg)
	a.ell(Vector3(-0.088, 0.07, -0.152), Vector3(0.022, 0.06, 0.012), accent, Vector3(0.1, 0, 0.25), 6, 3)
	a.ell(Vector3(-0.055, 0.065, -0.154), Vector3(0.022, 0.065, 0.012), accent, Vector3(0.1, 0, -0.2), 6, 3)
	# saya laquée (reflet), embouchure et bout d'or, cordon
	var rot := Basis.from_euler(HIP_SAYA_ROT)
	var xf := Transform3D(rot, HIP_SAYA_POS)
	a.style(0.7, 1.0)
	a.side_dark = 0.25
	a.lathe(_pv([0.0, -0.4, 0.026, -0.395, 0.03, -0.35, 0.032, 0.32, 0.03, 0.355, 0.0, 0.36]), _c(cfg, "saya"), sd, xf,
		1.0, 0.62)
	a.style(0.8, 1.0)
	a.lathe(_pv([0.034, 0.3, 0.038, 0.315, 0.038, 0.335, 0.034, 0.35]), gold, sd, xf, 1.0, 0.66)
	a.lathe(_pv([0.034, 0.2, 0.038, 0.21, 0.034, 0.22]), Toon.VERMILION.darkened(0.2), sd, xf, 1.0, 0.66)
	a.ell(HIP_SAYA_POS + rot * Vector3(0, -0.38, 0), Vector3(0.034, 0.03, 0.024), gold, HIP_SAYA_ROT, 8, 4)


## Tête : cagoule (zukin), bosse du masque, fente des yeux, hachimaki et plaque, nœud ; yeux sans contour.
static func _b_head(a: Builder, d: Builder, cfg: Dictionary, lite: bool) -> void:
	var hs := 12 if lite else 18
	var hr := 7 if lite else 10
	var cloth := _c(cfg, "cloth")
	var band := _c(cfg, "band")
	a.style(0.74, 1.0)
	a.ell(Vector3(0, 0.255, 0.01), Vector3(0.268, 0.272, 0.262), cloth, Vector3.ZERO, hs, hr)
	# masque sur le nez et la bouche : même étoffe que la cagoule (aucun contraste, pas de « moustache »)
	a.style(0.7, 0.92)
	a.ell(Vector3(0, 0.15, -0.165), Vector3(0.16, 0.1, 0.1), cloth, Vector3(0.2, 0, 0), hs, hr)
	# une seule fente : bande de peau qui épouse la tête
	a.style(0.9, 1.0)
	a.ell(Vector3(0, 0.248, -0.07), Vector3(0.235, 0.075, 0.215), _c(cfg, "skin"), Vector3.ZERO, hs, hr)
	# hachimaki, un peu plus haut derrière
	a.style(0.85, 1.0)
	a.lathe(_pv([0.236, 0.31, 0.258, 0.325, 0.262, 0.355, 0.252, 0.385, 0.232, 0.398]), band, hs,
		Transform3D(Basis.from_euler(Vector3(-0.08, 0, 0)), Vector3(0, 0, 0.01)), 1.0, 0.978)
	a.style(0.8, 1.0)
	a.ell(Vector3(0, 0.355, -0.252), Vector3(0.075, 0.035, 0.018), _c(cfg, "plate"), Vector3(0.4, 0, 0), 10, 5)
	a.ell(Vector3(0, 0.37, 0.262), Vector3(0.055, 0.045, 0.04), band.darkened(0.1), Vector3.ZERO, 10, 5)
	if bool(cfg.get("ponytail", false)):
		a.ell(Vector3(0, 0.47, 0.19), Vector3(0.055, 0.05, 0.05), _c(cfg, "hair"), Vector3.ZERO, 10, 5)
	# yeux : blanc en amande, un peu bridés vers l'intérieur, pupille ; sans contour (lisibles de loin)
	var pupil := _c(cfg, "eye")
	d.style(1.0, 1.0)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		d.ell(Vector3(sx * 0.078, 0.25, -0.266), Vector3(0.046, 0.03, 0.02), EYE_WHITE, Vector3(0, -sx * 0.3, sx * 0.22), 10, 5)
		d.ell(Vector3(sx * 0.07, 0.247, -0.283), Vector3(0.019, 0.023, 0.009), pupil, Vector3(0, -sx * 0.3, 0), 8, 4)


## Buste : veste courte croisée (V clair), fourreau laqué dans le dos, ou bandoulière d'étoiles.
static func _b_chest(a: Builder, cfg: Dictionary, lite: bool, weapon: String) -> void:
	var sides := 10 if lite else 14
	var sd := 8 if lite else 10
	var rg := 4 if lite else 5
	var under := _c(cfg, "under")
	var gold := _c(cfg, "gold")
	a.style(0.8, 1.0)
	a.pleats = 6
	a.pleat = 0.06
	a.lathe(_pv([0.165, -0.19, 0.17, -0.12, 0.178, -0.02, 0.19, 0.08, 0.2, 0.15, 0.185, 0.2, 0.14, 0.235, 0.07, 0.25, 0.0, 0.255]),
		_c(cfg, "cloth"), sides, Transform3D.IDENTITY, 1.0, 0.72)
	# sous-vêtement clair, puis les deux pans du col (le gauche par-dessus le droit)
	a.style(0.85, 1.0)
	a.ell(Vector3(0, 0.12, -0.128), Vector3(0.07, 0.075, 0.028), under, Vector3(0.25, 0, 0), sd, rg)
	for s in [1.0, -1.0]:
		var sx := float(s)
		a.ell(Vector3(sx * 0.042, 0.07, -0.136 - (0.004 if sx < 0.0 else 0.0)), Vector3(0.028, 0.135, 0.02), under,
			Vector3(0.1, 0, -sx * 0.4), sd, rg)
	if weapon == "katana":
		# saya laquée (reflet sur un flanc), embouchure et bout d'or, cordon
		var rot := Basis.from_euler(SAYA_ROT)
		var xf := Transform3D(rot, SAYA_POS)
		a.style(0.7, 1.0)
		a.side_dark = 0.25
		a.lathe(_pv([0.0, -0.43, 0.026, -0.425, 0.03, -0.38, 0.032, 0.36, 0.03, 0.395, 0.0, 0.4]), _c(cfg, "saya"), sd, xf,
			1.0, 0.62)
		a.style(0.8, 1.0)
		a.lathe(_pv([0.034, 0.34, 0.038, 0.355, 0.038, 0.375, 0.034, 0.39]), gold, sd, xf, 1.0, 0.66)
		a.lathe(_pv([0.034, 0.27, 0.038, 0.28, 0.034, 0.29]), _c(cfg, "accent"), sd, xf, 1.0, 0.66)
		a.ell(SAYA_POS + rot * Vector3(0, -0.41, 0), Vector3(0.034, 0.03, 0.024), gold, SAYA_ROT, 8, 4)
	elif weapon == "shuriken":
		# bandoulière en travers du torse, étoiles accrochées
		a.style(0.7, 0.95)
		a.ell(Vector3(0, 0.02, -0.142), Vector3(0.03, 0.26, 0.022), WOOD_D, Vector3(0.1, 0, 0.75), sd, rg)
		var ax := Vector3(-sin(0.75), cos(0.75), 0)
		for i in (2 if lite else 3):
			var t := (float(i) - 1.0) * 0.12
			_star(a, Vector3(0, 0.02, -0.168) + ax * t, 0.05, Vector3.ZERO, _c(cfg, "steel"))


## Bassin : haut du hakama plissé, obi et cordon d'or, nœud et ses pans ; bombes de fumée (kemuri).
static func _b_hips(a: Builder, cfg: Dictionary, lite: bool, weapon: String) -> void:
	var sides := 10 if lite else 14
	var sd := 8 if lite else 10
	var rg := 4 if lite else 5
	var accent := _c(cfg, "accent")
	a.style(0.78, 0.95)
	a.pleats = 7
	a.pleat = 0.12
	a.lathe(_pv([0.15, -0.13, 0.175, -0.08, 0.186, 0.0, 0.18, 0.08, 0.17, 0.13]), _c(cfg, "dark"), sides,
		Transform3D.IDENTITY, 1.0, 0.8)
	a.style(0.82, 1.0)
	a.lathe(_pv([0.183, 0.085, 0.193, 0.11, 0.195, 0.15, 0.186, 0.18]), accent, sides, Transform3D.IDENTITY, 1.0, 0.78)
	a.lathe(_pv([0.194, 0.123, 0.2, 0.13, 0.194, 0.137]), _c(cfg, "gold"), sides, Transform3D.IDENTITY, 1.0, 0.79)
	a.ell(Vector3(-0.07, 0.13, -0.152), Vector3(0.05, 0.036, 0.03), accent.darkened(0.12), Vector3.ZERO, sd, rg)
	a.ell(Vector3(-0.088, 0.07, -0.15), Vector3(0.022, 0.06, 0.012), accent, Vector3(0.1, 0, 0.25), 6, 3)
	a.ell(Vector3(-0.055, 0.065, -0.152), Vector3(0.022, 0.065, 0.012), accent, Vector3(0.1, 0, -0.2), 6, 3)
	if weapon == "smoke":
		for p in [Vector3(0.205, 0.07, -0.05), Vector3(0.2, 0.07, 0.07), Vector3(-0.2, 0.07, 0.07)]:
			var bp: Vector3 = p
			a.ell(bp, Vector3(0.048, 0.048, 0.048), Toon.SUMI, Vector3.ZERO, sd, rg)
			if not lite:
				a.ell(bp + Vector3(0, 0.05, 0), Vector3(0.012, 0.022, 0.012), Toon.VERMILION, Vector3.ZERO, 6, 3)


## Poignée tressée (tsuka) le long de l'axe Y de `xf`, de y0 à y1, kashira d'or au bout.
static func _tsuka(a: Builder, xf: Transform3D, y0: float, y1: float, cfg: Dictionary, lite: bool) -> void:
	var prof := PackedVector2Array()
	var bands := PackedFloat32Array()
	var n := 5 if lite else 9
	prof.append(Vector2(0.0, y0))
	bands.append(0.3)
	for i in n:
		var y := lerpf(y0 + 0.005, y1, float(i) / float(n - 1))
		prof.append(Vector2(0.025 if i % 2 == 0 else 0.022, y))
		bands.append(0.95 if i % 2 == 0 else 0.22)
	prof.append(Vector2(0.0, y1 + 0.004))
	bands.append(0.3)
	a.style(1.0, 1.0)
	a.bands = bands
	a.lathe(prof, _c(cfg, "under"), 8, xf, 1.0, 0.85)
	a.style(0.85, 1.0)
	a.ell(xf * Vector3(0, y1 + 0.01, 0), Vector3(0.028, 0.02, 0.025), _c(cfg, "gold"), xf.basis.get_euler(), 8, 4)


## Arme en main droite (repère de la main : poignet à l'origine, poing en (0, -0.045, 0), devant = -Z).
static func _b_weapon(a: Builder, d: Builder, cfg: Dictionary, lite: bool, weapon: String) -> void:
	var steel := _c(cfg, "steel")
	var gold := _c(cfg, "gold")
	# axe de l'arme : +Y du repère `xf` = devant la main
	var xf := Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, -0.045, 0))
	match weapon:
		"katana":
			_tsuka(a, xf, -0.1, 0.105, cfg, lite)
			a.style(0.85, 1.0)
			a.lathe(_pv([0.0, 0.106, 0.048, 0.109, 0.05, 0.118, 0.0, 0.122]), gold, 10, xf, 1.0, 0.8)
			a.lathe(_pv([0.018, 0.118, 0.02, 0.13, 0.018, 0.148, 0.0, 0.15]), gold, 6, xf, 0.7, 1.0)
			# lame : section en losange, légère courbure (sori), reflet sur un flanc ; sans contour
			d.style(0.8, 1.0)
			d.side_dark = 0.3
			d.bend = 0.045
			d.lathe(_pv([1.0, 0.14, 1.0, 0.72, 0.78, 0.8, 0.0, 0.855]), steel, 4, xf, 0.009, 0.03)
		"shuriken":
			_star(a, Vector3(0, -0.075, -0.035), 0.07, Vector3.ZERO, steel)
		"smoke":
			a.style(0.75, 1.0)
			a.ell(Vector3(0, -0.1, 0), Vector3(0.068, 0.068, 0.068), Toon.SUMI, Vector3.ZERO, 10, 5)
			a.ell(Vector3(0, -0.1, -0.075), Vector3(0.014, 0.014, 0.026), Toon.VERMILION, Vector3.ZERO, 6, 3)
		"kusarigama":
			# kama : manche de bois, virole de fer, lame en faucille
			a.style(0.8, 1.0)
			a.lathe(_pv([0.0, -0.06, 0.019, -0.055, 0.019, 0.34, 0.0, 0.35]), WOOD_D, 6, xf, 1.0, 1.0)
			a.lathe(_pv([0.022, 0.29, 0.024, 0.31, 0.022, 0.33]), IRON, 6, xf, 1.0, 1.0)
			var kb := xf.basis * Basis(Vector3(0, 0, 1), 0.35)
			d.style(0.8, 1.0)
			d.ell(xf * Vector3(0.1, 0.32, 0), Vector3(0.11, 0.026, 0.007), steel, kb.get_euler(), 6, 3)


## Étoile à quatre branches dans le plan XY du repère `rot` (moyeu avec contour, branches en losange).
static func _star(a: Builder, center: Vector3, r: float, rot: Vector3, col: Color) -> void:
	var rb := Basis.from_euler(rot)
	a.style(0.8, 1.0)
	a.ell(center, Vector3(r * 0.3, r * 0.3, r * 0.14), IRON, rot, 8, 4)
	for k in 4:
		var bb := rb * Basis(Vector3(0, 0, 1), TAU * float(k) / 4.0 + PI * 0.25)
		a.ell(center + bb * Vector3(0, r * 0.55, 0), Vector3(r * 0.28, r * 0.6, r * 0.1), col, bb.get_euler(), 4, 2)


# ------------------------------------------------------------------ assembleur

## Formes lisses de révolution (profils, ellipsoïdes) en couleurs de sommets : dégradé de bas en haut
## (`lo` -> `hi`, bande d'ombre douce), plis (`pleats`), reflet latéral, courbure, bandes par anneau.
class Builder:
	extends RefCounted

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var ix := PackedInt32Array()
	var lo := 0.82
	var hi := 1.0
	var pleats := 0
	var pleat := 0.0
	var side_dark := 0.0
	var bend := 0.0
	var bands := PackedFloat32Array()
	# écailles seigaiha : `pleats` écailles par tour, éclaircies vers scale_col (0 : aucune) ; rangées de deux
	# anneaux (base large, sommet étroit) décalées d'une demi-écaille une rangée sur deux
	var scales := 0.0
	var scale_col := Color.WHITE

	## Style des formes suivantes (remet plis, reflet, courbure, bandes et écailles à zéro).
	func style(l: float, h: float) -> void:
		lo = l
		hi = h
		pleats = 0
		pleat = 0.0
		side_dark = 0.0
		bend = 0.0
		bands = PackedFloat32Array()
		scales = 0.0

	## Révolution du profil (rayon, y), de bas en haut, autour de l'axe Y ; `sx`, `sz` : section ovale.
	## Un rayon nul ferme la forme (pôle). Normales lisses tirées de la surface (couture invisible).
	func lathe(prof: PackedVector2Array, col: Color, sides: int, xf: Transform3D, sx: float, sz: float) -> void:
		var rings := prof.size()
		if rings < 2 or sides < 3:
			return
		var base := v.size()
		var y0 := prof[0].y
		var y1 := prof[rings - 1].y
		var span := maxf(absf(y1 - y0), 0.0001)
		var pos := PackedVector3Array()
		pos.resize(rings * sides)
		for i in rings:
			var r := prof[i].x
			var y := prof[i].y
			var k := (y - y0) / span
			var off := bend * k * k
			for s in sides:
				var a := TAU * float(s) / float(sides)
				pos[i * sides + s] = Vector3(r * sx * cos(a), y, r * sz * sin(a) + off)
		var nb := xf.basis.inverse().transposed()
		for i in rings:
			var k := (prof[i].y - y0) / span
			var shade := lerpf(lo, hi, k)
			if bands.size() == rings:
				shade *= bands[i]
			var pole := prof[i].x < 0.0001
			var other := prof[1].y if i == 0 else prof[i - 1].y
			for s in sides:
				var p := pos[i * sides + s]
				var nrm := Vector3.ZERO
				if pole:
					nrm = Vector3(0, 1.0 if prof[i].y > other else -1.0, 0)
				else:
					var pa := pos[i * sides + (s + 1) % sides] - pos[i * sides + (s + sides - 1) % sides]
					var pt := pos[mini(i + 1, rings - 1) * sides + s] - pos[maxi(i - 1, 0) * sides + s]
					nrm = pt.cross(pa)
					if nrm.length_squared() < 0.0000000001:
						nrm = Vector3(p.x, 0, p.z)
				var a := TAU * float(s) / float(sides)
				var sh := shade
				var cc := col
				if pleats > 0 and pleat > 0.0:
					sh *= 1.0 - pleat * (0.5 + 0.5 * cos(a * float(pleats)))
				if scales > 0.0 and pleats > 0:
					# rangée = 3 anneaux : base large de l'arc, sommet étroit, fond uni ; la rangée suivante est
					# décalée d'une demi-écaille (seigaiha)
					var rr := i % 6
					var w := maxf(0.0, cos(a * float(pleats) + (PI if rr >= 3 else 0.0)))
					var k3 := rr % 3
					var wk := 0.0
					if k3 == 0:
						wk = minf(1.0, w * 1.6)
					elif k3 == 1:
						wk = w * w * w * w
					cc = col.lerp(scale_col, scales * wk)
				if side_dark > 0.0:
					sh *= 1.0 - side_dark * (0.5 + 0.5 * sin(a))
				v.append(xf * p)
				n.append((nb * nrm).normalized())
				c.append(Color(cc.r * sh, cc.g * sh, cc.b * sh, 1.0))
		# faces avant dans le sens horaire (convention de Godot)
		for i in rings - 1:
			for s in sides:
				var s1 := (s + 1) % sides
				var a0 := base + i * sides + s
				var b0 := base + i * sides + s1
				var a1 := base + (i + 1) * sides + s
				var b1 := base + (i + 1) * sides + s1
				ix.append(b1)
				ix.append(a1)
				ix.append(a0)
				ix.append(b1)
				ix.append(a0)
				ix.append(b0)

	## Ellipsoïde centré sur `center`, de rayons `radii`, tourné par `rot` (angles d'Euler).
	func ell(center: Vector3, radii: Vector3, col: Color, rot: Vector3, sides: int, rings: int) -> void:
		var prof := PackedVector2Array()
		var rr := maxi(rings, 2)
		for k in rr + 1:
			var t := -PI * 0.5 + PI * float(k) / float(rr)
			var r := 0.0 if k == 0 or k == rr else cos(t)
			prof.append(Vector2(r, sin(t) * radii.y))
		lathe(prof, col, sides, Transform3D(Basis.from_euler(rot), center), radii.x, radii.z)

	## Ajoute la surface au maillage (rien si vide).
	func add_to(m: ArrayMesh) -> void:
		if v.is_empty():
			return
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = ix
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
