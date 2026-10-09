extends Node3D
## Squelettes KayKit habillés en yōkai (yokai_parts.gd : masques, cornes, chapeaux, queues posés sur les os) ;
## les yōkai d'encre (Yokai.is_ink : yokai_ink_wN.gd) sont des corps d'encre modelés en code (ink_rig.gd) : encre qui coule,
## masque de nō, obi à seigaiha ; même logique de jeu, animations traduites en clips procéduraux.
##  oni   — Minion : fonce sur le héros, frappe une zone annoncée par un disque qui se remplit
##  kappa — Mage : garde ses distances et lance de grosses boules lentes
##  brute — Warrior : grand, lent et costaud (il faut l'enchaîner dans un combo)
##  tate  — Warrior au grand bouclier rond : invulnérable de face (cône 120°), il faut le prendre à revers
##  funa  — Funa-yūrei, Minion noyé bleuté : émerge au bord du ponton, lance une louche d'eau, replonge
## Ennemis signature (un par monde) :
##  umibozu     — (1) moine de mer : plonge sous les planches, ressurgit sous le héros (disque annoncé), touchable seulement émergé
##  kitsunebi   — (2) feu-follet renard : se téléporte sur une zone annoncée ; à sa mort il se scinde en deux kitsunebi_s
##  yukionna    — (3) fantôme des neiges : gèle une bande annoncée ; la glace freine la ruée qui la traverse
##  kasha       — (4) chat-charrette en feu : charge en ligne droite (couloir annoncé), laisse une traînée de feu
##  kagebo      — (5) double d'encre : rejoue plus tard le dernier trait du héros, tourné vers lui (chemin annoncé)
## Bestiaire étendu (archétypes) :
##  kappa_yumi  — (1) kappa archer : tir en ligne fine annoncée            teppo — (4) arquebusier : la ligne suit le héros puis se fige
##  ika         — (1) calmar : obus d'encre en cloche sur un disque         umi_nyobo — (1) femme de la mer : soigne les alliés proches
##  kamaitachi  — (2,3) belette : taille en zigzag annoncée, puis se pose   tanuki — (2) tambour du ventre + leurre (DORON), tanuki_d
##  kitsune_tsukai — (2) montreur de renards : invoque des feux follets     yuki_warashi — (3) enfant des neiges : court et explose
##  tsurara     — (3) stalactite : tourelle fixe, tirs de glace annoncés     onryo — (3) spectre : disparaît, surgit dans le dos du héros
##  hinotama    — (4) boule de feu volante : piqué en ligne                 kanabo — (4) oni à massue : armure frontale, bouclier
##  tengu       — (4) corbeau : lance des chausse-trapes (zones au sol)     sumidama — (5) goutte d'encre : flaque qui freine, se divise
##  kasa        — (5) parapluie : bonds sur un disque, intouchable en l'air moryo — (5) esprit : pose des boucliers sur les alliés
## Mondes 6 à 8 :
##  karasu      — (6) karasu-tengu : corbeau qui plonge en piqué (couloir)   yamabushi — (6) tengu ascète : rafale de son éventail (cône)
##  konoha      — (6) tengu-feuille : feuilles lancées en éventail          kani — (7) crabe heike : carapace de face (comme le porte-bouclier)
##  ningyo      — (7) sirène : jet d'eau en ligne annoncée                   fugu — (7) poisson-globe : gonfle, frappe autour de lui, épines
##  gaki        — (8) affamé : rapide, se soigne à chaque coup porté         gokusotsu — (8) geôlier : chaîne en couloir, armure de départ
##  shiryo      — (8) feu d'âme : cercle de feu froid sous le héros
## Clan des ninjas (忍, mondes 2, 5, 6) — rōdeurs KayKit en cagoule, hachimaki ; maître ninja = élite (MAÎTRE) :
##  shinobi     — 忍 : court au héros, cligne sur son flanc (fumée) et taille aussitôt (disque devant lui)
##  shuriken    — 手裏剣 : garde ses distances, éventail de 3 lignes de visée (5 pour le maître), étoiles lancées
##  kemuri      — 煙 : bombe de fumée, presque invisible, ressurgit dans le dos du héros (contour rouge, disque)
##  kunoichi    — くノ一 : kusarigama, balayage de la chaîne dans un arc au sol annoncé devant elle
## Boucliers (barre bleue) : tant qu'il en reste, un coup n'entame que 25 % des PV ; figures et pouvoirs les usent ×2 ;
## brisé : titube 0.8 s. Élites (main._spawn_list) : ×1.25, ×2.5 PV, bouclier, aura et cornes d'or, 1–2 affixes.

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const NinjaRig = preload("res://scripts/ninja_rig.gd")
const InkRig = preload("res://scripts/ink_rig.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")
const Worlds = preload("res://scripts/worlds.gd")
# textures recolorées des squelettes et du rōdeur (préchargées une fois : plus de load() au montage)
const TEX_RED := preload("res://assets/kaykit/tex/skeleton_red.png")
const TEX_INK := preload("res://assets/kaykit/tex/skeleton_ink.png")
const TEX_GOLD := preload("res://assets/kaykit/tex/skeleton_gold.png")
const TEX_PRUSSIAN := preload("res://assets/kaykit/tex/skeleton_prussian.png")
const TEX_ROGUE_INK := preload("res://assets/kaykit/tex/rogue_ink.png")
const TEX_ROGUE_INDIGO := preload("res://assets/kaykit/tex/rogue_indigo.png")
const TEX_ROGUE_GLYCINE := preload("res://assets/kaykit/tex/rogue_glycine.png")
const TEX_ROGUE_SAKURA := preload("res://assets/kaykit/tex/rogue_sakura.png")
## Vrai : le clan des ninjas (NINJA_KINDS) prend le ninja procédural (ninja_rig.gd) à leur palette ;
## faux : rōdeur KayKit habillé (yokai_parts).
const NINJA_ENEMIES_RIG := true
const ROGUE = preload("res://assets/kaykit/Rogue_Hooded.glb")  # (aussi le héros : chargé au démarrage)
# squelettes : pas préchargés (démarrage plus court), lus en arrière-plan pendant l'accueil (request_models)
const MINION_PATH := "res://assets/kaykit/Skeleton_Minion.glb"
const WARRIOR_PATH := "res://assets/kaykit/Skeleton_Warrior.glb"
const MAGE_PATH := "res://assets/kaykit/Skeleton_Mage.glb"
static var MINION: PackedScene = null
static var WARRIOR: PackedScene = null
static var MAGE: PackedScene = null

const SPAWN_TIME := 1.0
const EDGE_IN := 0.4  # funa : distance au bord du ponton

var _steer := Vector3.ZERO
var _stagger := 0.0  # tate : garde ouverte après un coup bloqué
var _steer_t := 0.0
var kind := "oni"
var hp := 1.0
var speed := 2.0
var radius := 0.45
var hero: Node3D
var main: Node

var dead := false
var dummy := false  # mannequin du tutoriel : ne bouge pas, n'attaque pas
var spar := false  # mannequin du dojo offensif : poursuit et attaque comme en combat (sans butin)
var last_stroke := -1
var body: Node3D
var ch: Node3D
var _flash := 0.0
var flash_c := Color.WHITE  # teinte de l'éclat de touche (élément du pouvoir, elem_flash) ; blanc sinon
# impact d'un coup de sabre : éclat blanc franc, silhouette écrasée, bref temps figé
const FLASH_T := 0.09  # éclat de touche (plein éclat les 0,05 premières secondes)
const FLASH_FULL := 0.05
const SQUASH := Vector3(1.2, 0.8, 1.2)
const HIT_FREEZE := 0.06  # touché sans être tué : figé un instant
var _squash := 0.0  # retour en douceur de l'écrasement (s)
var _hit_freeze := 0.0
# mort : recul franc, petit saut en basculant dans le sens du coup, puis il s'enfonce
const DIE_KNOCK := 9.0
const DIE_HOP := 0.3  # durée du saut (s)
const DIE_HOP_H := 0.6  # hauteur du saut (m)
const DIE_TILT := 1.2  # bascule (rad)
const DIE_SINK := 0.4  # enfoncement (s)
var _die_y := 0.0
var _spawn := SPAWN_TIME
var _knock := Vector3.ZERO
var _t := 0.0
var _walk := "Walking_D_Skeletons"
var _deco: Node3D  # accessoires posés sur le corps (oreilles, roues…), cachés pendant l'apparition
var _glow_a := 0.0  # lueur de base (fantômes, feu)
var _glow_c := Toon.VERMILION

# attaque
var _state := "move"  # move | windup | charge | recover
var _timer := 0.0
var _windup := 1.0
var _attack := "1H_Melee_Attack_Chop"
var _strike_dir := Vector3.FORWARD
var _zone: Node3D
var _tele: Node3D  # visuel partagé de l'annonce (vfx.tele_disc)
var _zone_r := 1.0
var _shadow: MeshInstance3D

# funa : cycle émerge → visible → plonge → caché
const FUNA_TINT := Color("#7FB2C8")
const FUNA_DEPTH := -1.2
const FUNA_EMERGE := 0.6
const FUNA_UP := 2.2
const FUNA_DIVE := 0.5
const FUNA_UNDER := 3.0
var _phase := "emerge"  # emerge | up | dive | under
var _ptimer := 0.0
var _shot := false
var _target := Vector3.ZERO

# umibōzu : sous les planches, il suit le héros puis ressurgit sous lui
const UMI_UP := 2.6
const UMI_UNDER := 1.4
const UMI_WINDUP := 1.0
const UMI_SWIM := 3.2
var _ripple_t := 0.0
var _waits := 0

# kitsune-bi
const FOX_FIRE := Color("#8FE3FF")
const FOX_PALE := Color("#FFF3D6")

# couloirs annoncés (yuki-onna, kasha, kagebō) : polyligne au sol + annonces rectangulaires
var _lane := PackedVector3Array()
var _lane_w := 1.2
var _teles: Array = []
var _li := 1
var _ctime := 0.0
var _cspeed := 10.0
var _hit_cd := 0.0

# yuki-onna : bande de givre
const ICE_C := Color("#BFE8FF")
const YUKI_W := 1.2
const YUKI_LEN := 9.0
const YUKI_WINDUP := 1.3
const ICE_TIME := 3.5
const ICE_SLOW := 0.45
var _ice: Node3D
var _ice_mat: StandardMaterial3D
var _ice_pts := PackedVector3Array()
var _ice_t := 0.0
var _slow_id := -1
var _slowed := false

# kasha : charge et traînée de feu
const KASHA_FIRE := Color("#FF5A1F")
const KASHA_W := 1.3
const KASHA_LEN := 8.5
const KASHA_WINDUP := 1.1
const KASHA_SPEED := 12.0
const FIRE_TIME := 2.0
var _wheels: Array = []
var _fire_a := Vector3.ZERO
var _fire_b := Vector3.ZERO
var _fire_t := 0.0

# kagebō : copie du dernier trait du héros
const KAGE_W := 1.0
const KAGE_MAX := 9.0
const KAGE_WINDUP := 1.3
const KAGE_SPEED := 14.0
var _rec := PackedVector3Array()
var _rec_id := -1

# ------------------------------------------------------------------ bestiaire étendu
const SHIELD_C := Color("#6FB7FF")
const ELITE_C := Color("#FFB23E")
const HEAL_C := Color("#7FE0A8")
const INK_C := Color("#26222C")
const ROGUE_GEAR := ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]
const KIND_H := {"oni": 1.6, "brute": 2.4, "kappa": 1.75, "tate": 1.9, "funa": 1.6, "umibozu": 2.0,
	"kitsunebi": 1.35, "kitsunebi_s": 0.95, "yukionna": 1.85, "kasha": 1.7, "kagebo": 1.75}
const NO_ELITE := ["kitsunebi_s", "tanuki_d", "sumidama_s", "tsurara"]
# lourds : un coup pendant leur annonce ne la casse pas (sauf mise à mort ou bouclier brisé)
const HEAVY_KINDS := ["tate", "kasha", "gokusotsu", "kani", "brute", "kanabo"]
# coups lourds : 2 cœurs dès le monde HEAVY_HIT_WORLD (explosion d'élite comprise)
const HEAVY_HIT_KINDS := ["brute", "kanabo", "gokusotsu"]
const HEAVY_HIT_WORLD := 5
const WINDUP_MIN := 0.65  # plancher des annonces (s), même dans les mondes avancés
const ELITE_NAMES := {"blinde": "BLINDÉ", "rapide": "RAPIDE", "vampire": "VAMPIRE", "explosif": "EXPLOSIF",
	"invocateur": "INVOCATEUR", "enrage": "ENRAGÉ", "maitre": "MAÎTRE NINJA"}
const ELITE_POOL := ["blinde", "rapide", "vampire", "explosif", "invocateur", "enrage"]
const BLAST_R := 1.9
const BLAST_T := 1.1
# tireurs en ligne (kappa archer, arquebusier, stalactite)
const SNIPE_W := 0.6
const SNIPE_LEN := 11.0
const SNIPE_WINDUP := 1.15
const TEPPO_TRACK := 0.75
const TEPPO_HOLD := 0.45
const ICICLE_W := 0.7
const ICICLE_LEN := 8.0
const ICICLE_T := 1.2
# calmar : obus en cloche
const MORTAR_R := 1.3
const MORTAR_T := 1.5
# soutiens (soin, bouclier)
const SUPPORT_R := 4.5
const SUPPORT_CAST := 0.9
# belette, boule de feu
const WEASEL_T := 0.85
const SWOOP_T := 0.95
# tanuki, invocateur, enfant des neiges
const DRUM_R := 2.0
const DRUM_T := 1.0
const SUMMON_CAST := 1.1
const KAMI_R := 1.7
const KAMI_T := 1.0
# spectre
const ONRYO_FADE := 0.35
const ONRYO_GONE := 0.45
const ONRYO_T := 0.8
# tengu : chausse-trapes
const TRAP_R := 0.7
const TRAP_T := 1.0
const TRAP_LIFE := 4.5
# parapluie : bonds
const HOP_R := 0.95
const HOP_T := 0.85
const HOP_GROUND := 0.9
# mondes 6 à 8 : rafale d'éventail, feuilles, poisson-globe, chaîne, feu d'âme
const GUST_T := 1.0
const GUST_LEN := 5.5
const GUST_HALF := 0.55  # demi-angle du cône (rad)
const LEAF_T := 0.8
const PUFF_T := 1.1
const PUFF_R := 1.5
const CHAIN_T := 1.1
const CHAIN_W := 1.0
const WISP_T := 1.2
const WISP_R := 1.1
const YOMI_C := Color("#B9A8E8")
# clan des ninjas (忍) : noms et kanji (手裏剣 shuriken, 煙 fumée, くノ一 kunoichi)
const NINJA_KINDS := ["shinobi", "shuriken", "kemuri", "kunoichi"]
const NINJA_KANJI := {"shinobi": "忍", "shuriken": "手裏剣", "kemuri": "煙", "kunoichi": "くノ一"}
const NINJA_NAMES := {"shinobi": "un shinobi", "shuriken": "un lanceur de shuriken", "kemuri": "un ninja des fumées", "kunoichi": "une kunoichi"}
const SMOKE_C := Color("#8E84A0")
const SHINOBI_RANGE := 5.0
const SHINOBI_R := 1.0
const SHINOBI_GAP := 1.5  # distance au héros après le clignement (sur son flanc, jamais dans son dos)
const SHINOBI_REST := 1.1
const SHURI_W := 0.5
const SHURI_LEN := 9.0
const SHURI_T := 1.1
const SHURI_SPREAD := 0.3  # écart entre deux lignes (rad)
const SHURI_FLY := 0.22  # vol des étoiles : elles touchent pile à la fin de l'annonce
const KEMURI_GONE := 0.9
const KEMURI_T := 0.95
const KEMURI_R := 1.15
const CLOUD_LIFE := 2.4
const KUSARI_T := 1.0
const KUSARI_LEN := 3.8
const KUSARI_HALF := 0.85  # demi-angle de l'arc (rad)

static var _res := {}  # maillages et matériaux partagés par tous les ennemis

var shield := 0.0
var shield_max := 0.0
var elite := false
var affixes: Array = []
var minion := false  # invoqué (pas d'élite)
var _shield_frac := 0.0  # bouclier de départ (fraction des PV max), posé à la première image
var _bubble: MeshInstance3D
var _bubble_base := Vector3.ONE
var _aura: MeshInstance3D
var _aura_r := 1.0
var _tempo := 1.0  # Rapide / Enragé : tout son rythme accéléré
var _enraged := false
var _called := false
var _blast_t := 0.0
var _selfkill := false  # explosion volontaire, leurre dissipé : pas de butin
var _h := 1.7  # hauteur du modèle
var _rogue := false
var _custom := false  # corps modelé (pas de squelette KayKit)
var _rig := false  # ninja procédural (NinjaRig) au lieu du rōdeur KayKit
var _ink := false  # yōkai d'encre (InkRig) : corps d'encre, masque de nō, gouttes (monde 1)
var _scale_in := 0.0  # apparition par mise à l'échelle (durée)
var _base_hp := 1.0
var _summons: Array = []  # invocations (peuvent être libérées : jamais typées)
var _summon_total := 0
var _proj: MeshInstance3D
var _proj_from := Vector3.ZERO
var _belly: MeshInstance3D
var _doron_cd := 0.0
var _life := 0.0
var _air := false
var _hop_from := Vector3.ZERO
var _hop_len := 0.6
var _traps := PackedVector3Array()
var _trap_t := 0.0
var _trap_node: Node3D
var _armour_t := -9.0
var _ice_w := YUKI_W
var _ice_word := "GIVRE"
var _ice_col := ICE_C
var _drift_p := Vector3.ZERO
var _drift_t := 0.0
var _corner_t := 0.0
var _spark_t := -9.0
var _wings: Array = []  # pivots des ailes (karasu) : battement
var _fan: Array = []  # shuriken : lignes de visée (PackedVector3Array [départ, fin])
var _stars: Array = []  # shuriken en vol : [nœud (peut être libéré : jamais typé), départ, fin]
var _cloud: Node3D  # kemuri : nuage de fumée laissé sur place
var _cloud_t := 0.0
var _master := false  # maître ninja (élite d'un ninja)
var _combo := 0  # maître shinobi : deux tailles d'affilée


func setup(k: String, h: Node3D, m: Node) -> void:
	kind = k
	hero = h
	main = m


## Démarrage (main, après la première image) : les squelettes se chargent sur un fil d'arrière-plan.
static func request_models() -> void:
	Toon.request(MINION_PATH)
	Toon.request(WARRIOR_PATH)
	Toon.request(MAGE_PATH)


## Squelettes prêts avant le premier ennemi (attend la fin du chargement en arrière-plan si besoin).
static func _need_models() -> void:
	if MINION == null:
		MINION = Toon.fetch(MINION_PATH) as PackedScene
	if WARRIOR == null:
		WARRIOR = Toon.fetch(WARRIOR_PATH) as PackedScene
	if MAGE == null:
		MAGE = Toon.fetch(MAGE_PATH) as PackedScene


func _ready() -> void:
	_need_models()
	_t = randf() * 10.0
	body = Node3D.new()
	add_child(body)
	_rig = NINJA_ENEMIES_RIG and kind in NINJA_KINDS
	_ink = Yokai.is_ink(kind)
	if _rig:
		ch = NinjaRig.new()
	elif _ink:
		ch = InkRig.new()  # yōkai d'encre du monde 1 : corps modelé, masque de nō (ink_rig.gd)
	else:
		ch = Character.new()
	body.add_child(ch)
	_deco = Node3D.new()
	body.add_child(_deco)
	_h = float(KIND_H.get(kind, 1.7))
	match kind:
		"oni":
			hp = 1.0
			speed = 2.3
			radius = 0.45
			_windup = 1.0
			ch.setup(kind, _h)  # masque rouge cornu, massue
		"brute":
			hp = 3.5
			speed = 1.4
			radius = 0.75
			_zone_r = 1.5
			_windup = 1.2
			_attack = "2H_Melee_Attack_Chop"
			_walk = "Walking_A"
			ch.setup(kind, _h)  # large, masque de fer à kuwagata d'or, kanabō
		"kappa":
			hp = 1.0
			speed = 1.6
			radius = 0.45
			_walk = "Walking_B"
			ch.setup(kind, _h)  # masque vert à bec, coupelle d'eau, carapace, bâton levé
			_timer = 1.4 + randf() * 1.5
		"tate":
			hp = 2.0
			speed = 1.8
			radius = 0.55
			_zone_r = 1.0
			_windup = 1.0
			_walk = "Walking_A"
			ch.setup(kind, _h)  # masque washi sous l'eboshi, grand bouclier rond fixé devant
		"funa":
			hp = 1.0
			speed = 0.0
			radius = 0.45
			_zone_r = 1.2
			_windup = 1.1
			ch.setup(kind, _h)  # encre bleutée, masque pâle au triangle des morts, louche levée
			_ghostify()
		"umibozu":
			# moine de mer : crâne lisse bleu nuit, yeux d'or, perle lumineuse à la main
			hp = 1.5
			speed = 1.0
			radius = 0.5
			_zone_r = 1.0
			_walk = "Walking_A"
			ch.setup(kind, _h)  # dôme lisse d'encre d'abysse, gros yeux d'or, kesa
			ch.attach("handslot.r", _orb(0.12, Color("#9FE0FF")))
		"kitsunebi", "kitsunebi_s":
			# feu-follet renard : pâle et translucide, oreilles et queue, flamme bleue à la main
			var mini := kind == "kitsunebi_s"
			hp = 0.5 if mini else 1.5
			speed = 2.4 if mini else 1.8
			radius = 0.32 if mini else 0.42
			_zone_r = 0.7 if mini else 0.95
			_windup = 0.75 if mini else 0.9
			_walk = "Idle_Combat"
			var h := 0.95 if mini else 1.35
			ch.setup(MAGE, h, [["", TEX_GOLD]], ["Skeleton_Mage_Hat"], FOX_FIRE)
			_tint(FOX_PALE, 0.85)
			_glow_a = 0.45
			_glow_c = FOX_FIRE
			ch.attach("handslot.r", _orb(0.1 if mini else 0.15, FOX_FIRE))
			_timer = randf_range(1.2, 2.0)
			if mini:
				_spawn = 0.4
		"yukionna":
			# femme des neiges : fantôme blanc bleuté, longue chevelure noire
			hp = 2.0
			speed = 1.5
			radius = 0.45
			_walk = "Walking_B"
			var hy := 1.85
			ch.setup(MAGE, hy, [], ["Skeleton_Mage_Hat"], Color("#7FD8FF"))
			_tint(Color("#E8F4FF"), 0.7)
			_glow_a = 0.3
			_glow_c = ICE_C
			_timer = randf_range(1.5, 2.5)
		"kasha":
			# chat-charrette : squelette rouge, tête de chat noir aux mèches de feu, deux queues, deux roues en feu
			hp = 2.5
			speed = 1.7
			radius = 0.6
			_walk = "Walking_A"
			var hk := 1.7
			ch.setup(WARRIOR, hk, [["Helmet", TEX_GOLD], ["", TEX_RED]])
			_glow_a = 0.2
			_glow_c = KASHA_FIRE
			for s in [-1.0, 1.0]:
				var sx := float(s)
				var spin := Node3D.new()
				spin.position = Vector3(sx * 0.46, 0.36, 0.05)
				_deco.add_child(spin)
				var hub := Node3D.new()
				hub.rotation.z = PI / 2.0
				spin.add_child(hub)
				Toon.part(hub, Toon.cyl(0.34, 0.34, 0.07, 14), Toon.mat(Toon.WOOD, true, 0.02), Vector3.ZERO)
				Toon.part(hub, Toon.cyl(0.09, 0.09, 0.11, 10), Toon.mat(Toon.GOLD, true, 0.02), Vector3.ZERO)
				Toon.part(hub, Toon.box(Vector3(0.6, 0.075, 0.05)), Toon.mat(Toon.SUMI, false), Vector3.ZERO)
				_wheels.append(spin)
				main.vfx.burner(_deco, 0.22, 4, Vector3(sx * 0.46, 0.15, 0.05))
			_timer = randf_range(1.5, 2.5)
		"kagebo":
			# double d'encre : le ronin lui-même, noir et translucide
			hp = 2.0
			speed = 2.0
			radius = 0.45
			_walk = "Walking_A"
			ch.setup(ROGUE, 1.75, [["", TEX_ROGUE_INK]], ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"])
			_tint(Color(0.3, 0.29, 0.34), 0.85)
			ch.attach("handslot.r", _blade(0.85, Toon.SUMI))
			_timer = randf_range(2.0, 3.0)
		_:
			_setup_extra()
	if not _custom and not _rig and not _ink:
		_dress()
	# rythme un peu plus posé : marche -10 %, annonces des coups +15 % ; les mondes avancés raccourcissent
	# les annonces (worlds.gd « tele »), jamais sous WINDUP_MIN
	speed *= 0.9
	_windup = maxf(WINDUP_MIN, _windup * 1.15 * float(Worlds.world(_world()).get("tele", 1.0)))
	_base_hp = hp
	if kind == "kagebo" or _rogue or _custom:
		_scale_in = SPAWN_TIME
	if kind == "kitsunebi_s" or kind == "sumidama_s":
		_scale_in = 0.4
	if _glow_a > 0.0:
		_base_glow()
	ch.idle = "Blocking" if kind == "tate" else ("Idle" if kind == "kagebo" or _rogue else "Idle_Combat")
	_shadow = Toon.blob(self, radius * 1.1, 0.3)  # ombre de contact douce
	# (pas pour les modèles de préchauffage, accrochés en miniature à la caméra)
	if kind != "funa" and kind != "umibozu" and kind != "tanuki_d" and get_parent() == main:
		# il sort d'une flaque d'encre qui s'ouvre puis se résorbe
		main.vfx.spawn_ink(position, radius)
	if kind == "funa":
		# pas d'apparition au sol : il sort de l'eau au bord du ponton
		_spawn = 0.0
		position = _nearest_edge(position)
		_start_emerge()
		return
	if kind == "umibozu":
		# il sort de l'eau sur place
		_spawn = 0.0
		_surface()
		return
	if kind == "tanuki_d":
		_spawn = 0.0  # le leurre prend la place du vrai, sans apparition
		return
	if _scale_in > 0.0:
		if _scale_in < SPAWN_TIME:
			_spawn = _scale_in
		return  # apparition par mise à l'échelle (_process)
	ch.play_once("Spawn_Ground_Skeletons", ch.length("Spawn_Ground_Skeletons") / SPAWN_TIME, 0.0)


## Bestiaire étendu : modèle, teinte, accessoires et réglages de chaque nouveau yōkai.
func _setup_extra() -> void:
	match kind:
		"kappa_yumi":
			# kappa archer : carapace sur le dos, coupelle sur le crâne, arbalète
			hp = 1.0
			speed = 1.7
			radius = 0.42
			_walk = "Walking_B"
			_h = 1.55
			ch.setup(kind, _h)  # kappa au hachimaki, grand arc au flanc
			_timer = randf_range(1.6, 2.4)
		"teppo":
			# arquebusier : long canon de fer, mèche rouge
			hp = 1.5
			speed = 1.5
			radius = 0.5
			_walk = "Walking_A"
			_h = 1.85
			ch.setup(WARRIOR, _h, [["Cloak", TEX_RED], ["Helmet", TEX_INK]])
			_timer = randf_range(1.8, 2.6)
		"ika":
			# calmar : manteau pointu sur la tête, tentacules à la taille
			hp = 1.2
			speed = 1.3
			radius = 0.45
			_h = 1.35
			ch.setup(kind, _h)  # capuche de calmar, grands yeux noirs, tentacules
			_timer = randf_range(1.5, 2.5)
		"umi_nyobo":
			# femme de la mer : pâle et verte, longue chevelure, perle de soin
			hp = 1.4
			speed = 1.6
			radius = 0.45
			_walk = "Walking_B"
			_h = 1.75
			ch.setup(kind, _h)  # ko-omote, chevelure d'algues, coquillage
			_glow_a = 0.25
			_glow_c = HEAL_C
			ch.attach("handslot.r", _orb(0.13, HEAL_C))
			_timer = randf_range(1.5, 2.5)
		"moryo":
			# mōryō : petit démon d'encre aux longues oreilles, talisman au front
			hp = 1.3
			speed = 1.9
			radius = 0.4
			_h = 1.3
			ch.setup(MINION, _h, [["", TEX_INK]], [], SHIELD_C)
			_tint(Color("#7C6F86"), 0.85)
			_glow_a = 0.2
			_glow_c = SHIELD_C
			_timer = randf_range(1.5, 2.5)
		"kamaitachi":
			# belette faucheuse : petite, fauve, deux lames, longue queue
			hp = 0.9
			speed = 2.6
			radius = 0.38
			_walk = "Walking_A"
			_h = 1.25
			_rogue = true
			ch.setup(ROGUE, _h, [], _gear_except(["Knife", "Knife_Offhand"]), Toon.GOLD)
			_tint(Color("#C99A62"), 1.0)
			_timer = randf_range(1.2, 2.0)
		"tanuki", "tanuki_d":
			# tanuki : ventru, chapeau de paille ; le leurre n'a pas de queue (le seul indice)
			var decoy := kind == "tanuki_d"
			hp = 0.05 if decoy else 1.8
			speed = 2.0 if decoy else 1.6
			radius = 0.55
			_walk = "Walking_A"
			_h = 1.45
			ch.setup(WARRIOR, _h, [["", TEX_GOLD]])
			_tint(Color("#A07850"), 1.0)
			_belly = Toon.part(_deco, _sph(0.36), _pm(Color("#E8D2A8")), Vector3(0, 0.45 * _h, -0.12 * _h), Vector3(1, 1, 0.7))
			if decoy:
				_life = 7.0
			_doron_cd = 1.5
		"kitsune_tsukai":
			# montreur de renards : eboshi noir, demi-masque de renard, robe rouge, lanterne de feu bleu
			hp = 1.5
			speed = 1.5
			radius = 0.45
			_walk = "Walking_B"
			_h = 1.75
			ch.setup(MAGE, _h, [["Body", TEX_RED]], ["Skeleton_Mage_Hat"], FOX_FIRE)
			_tint(Color("#F0E2CC"), 0.9)
			_glow_a = 0.2
			_glow_c = FOX_FIRE
			ch.attach("handslot.r", _lantern_glow())
			_timer = randf_range(1.2, 2.0)
		"yuki_warashi":
			# enfant des neiges : petit, blanc, chapeau de paille et écharpe rouge
			hp = 0.8
			speed = 2.9
			radius = 0.38
			_h = 1.1
			ch.setup(MINION, _h, [], [], ICE_C)
			_tint(Color("#EEF6FF"), 0.8)
			_glow_a = 0.25
			_glow_c = ICE_C
		"tsurara":
			# stalactite : tourelle de glace posée sur un tertre de neige
			hp = 1.2
			speed = 0.0
			radius = 0.5
			_h = 1.5
			_custom = true
			Toon.part(body, _ymesh("body"), Yokai.mat(), Vector3.ZERO)
			Toon.part(body, _sph(0.09), main.vfx.glow_mat(ICE_C, 2.5), Vector3(0, 0.55, -0.24))
			_timer = randf_range(1.5, 2.5)
		"hinotama":
			# boule de feu : cœur ardent, yeux noirs, flammes
			hp = 0.8
			speed = 2.0
			radius = 0.42
			_h = 0.9
			_custom = true
			Toon.part(body, _sph(0.32), main.vfx.glow_mat(Color("#FF7A2A"), 2.6), Vector3(0, 0.45, 0))
			Toon.part(body, _sph(0.2), main.vfx.glow_mat(Color("#FFD36A"), 2.4), Vector3(0, 0.47, -0.1))
			for s in [-1.0, 1.0]:
				Toon.part(body, _sph(0.05), _pm(Toon.SUMI, false), Vector3(float(s) * 0.1, 0.52, -0.29))
			main.vfx.burner(body, 0.25, 5, Vector3(0, 0.55, 0))
			body.position.y = 1.3
			_timer = randf_range(1.5, 2.2)
		"kanabo":
			# oni à massue : ao-oni bleu à crinière blanche, plastron de fer, kanabō ; armure de face et bouclier
			hp = 4.0
			speed = 1.25
			radius = 0.8
			_zone_r = 1.6
			_windup = 1.35
			_attack = "2H_Melee_Attack_Chop"
			_walk = "Walking_A"
			_h = 2.5
			ch.setup(WARRIOR, _h, [["Helmet", TEX_INK], ["Cloak", TEX_GOLD]])
			_tint(Color("#7C98C8"), 1.0)
			_shield_frac = 0.35
		"tengu":
			# karasu-tengu : noir, bec d'or, petit bonnet rouge, ailes
			hp = 1.3
			speed = 2.0
			radius = 0.45
			_walk = "Walking_A"
			_h = 1.65
			_rogue = true
			ch.setup(ROGUE, _h, [], ROGUE_GEAR.duplicate(), Toon.GOLD)
			_tint(Color("#4A4A58"), 1.0)
			_timer = randf_range(1.5, 2.5)
		"onryo":
			# onryō : spectre pâle, cheveux noirs sur le visage, bandeau blanc
			hp = 1.4
			speed = 1.6
			radius = 0.45
			_walk = "Walking_B"
			_h = 1.8
			ch.setup(MAGE, _h, [], ["Skeleton_Mage_Hat"], Color("#C9B8FF"))
			_tint(Color("#E4E8F2"), 0.7)
			_glow_a = 0.3
			_glow_c = Color("#B9A8E8")
			_timer = randf_range(1.8, 2.6)
		"sumidama", "sumidama_s":
			# goutte d'encre : boule noire tremblotante à deux yeux
			var small := kind == "sumidama_s"
			var s := 0.6 if small else 1.0
			hp = 0.55 if small else 1.6
			speed = 2.6 if small else 1.4
			radius = 0.35 if small else 0.55
			_h = 0.9 * s
			_custom = true
			Toon.part(body, _ymesh("body"), Yokai.mat(), Vector3.ZERO)
		"kasa":
			# kasa-obake : parapluie rouge à un œil, une jambe, langue pendante
			hp = 1.1
			speed = 0.0
			radius = 0.5
			_h = 1.5
			_custom = true
			Toon.part(body, _ymesh("body"), Yokai.mat(), Vector3.ZERO)
			_timer = 0.8
		"karasu":
			# karasu-tengu : corbeau noir au bec d'or, tokin rouge, grandes ailes ; plonge en piqué
			hp = 0.9
			speed = 2.2
			radius = 0.42
			_h = 1.0
			_custom = true
			Toon.part(body, _ymesh("body"), Yokai.mat(), Vector3.ZERO)
			for s in [-1.0, 1.0]:
				var ksx := float(s)
				var pivot := Node3D.new()
				pivot.position = Vector3(ksx * 0.22, 0.6, 0.0)
				body.add_child(pivot)
				Toon.part(pivot, _ymesh("wing_l" if ksx < 0.0 else "wing_r"), Yokai.mat(), Vector3.ZERO)
				_wings.append(pivot)
			_timer = randf_range(1.5, 2.3)
		"yamabushi":
			# yamabushi-tengu : visage rouge au long nez, tokin noir, pompons d'ascète, éventail de plumes
			hp = 1.6
			speed = 1.6
			radius = 0.48
			_walk = "Walking_B"
			_h = 1.8
			ch.setup(MAGE, _h, [["Body", TEX_RED]], ["Skeleton_Mage_Hat"], Toon.GOLD)
			_tint(Color("#E8DCC8"), 1.0)
			_timer = randf_range(1.6, 2.4)
		"konoha":
			# konoha-tengu : petit tengu-feuille au bec jaune, ailes de feuilles ; feuilles lancées en éventail
			hp = 1.0
			speed = 2.0
			radius = 0.4
			_walk = "Walking_A"
			_h = 1.3
			_rogue = true
			ch.setup(ROGUE, _h, [], ROGUE_GEAR.duplicate(), Toon.GOLD)
			_tint(Color("#7FA65A"), 1.0)
			_timer = randf_range(1.4, 2.2)
		"kani":
			# heikegani : crabe rouge à carapace-masque de samouraï, pinces levées ; carapace de face
			hp = 2.0
			speed = 1.7
			radius = 0.58
			_zone_r = 1.0
			_windup = 1.0
			_h = 0.9
			_custom = true
			Toon.part(body, _ymesh("body"), Yokai.mat(), Vector3.ZERO)
		"ningyo":
			# ningyo : sirène pâle à queue de poisson, longue chevelure ; jet d'eau en ligne
			hp = 1.3
			speed = 1.5
			radius = 0.45
			_walk = "Walking_B"
			_h = 1.7
			ch.setup(MAGE, _h, [], ["Skeleton_Mage_Hat"], Color("#7FE8FF"))
			_tint(Color("#BFE6DF"), 0.8)
			_glow_a = 0.2
			_glow_c = Color("#7FE8FF")
			ch.attach("handslot.r", _orb(0.12, Color("#9FF0E6")))
			_timer = randf_range(1.6, 2.4)
		"fugu":
			# fugu : poisson-globe qui gonfle ; à pleine taille il frappe autour de lui et projette ses épines
			hp = 1.4
			speed = 1.4
			radius = 0.5
			_h = 1.0
			_custom = true
			Toon.part(body, _ymesh("body"), Yokai.mat(), Vector3.ZERO)
			body.position.y = 0.3
			_timer = randf_range(1.0, 1.8)
		"gaki":
			# gaki : affamé décharné au ventre gonflé ; se rue, mord et se soigne de chaque coup porté
			hp = 0.9
			speed = 2.7
			radius = 0.42
			_zone_r = 0.85
			_windup = 0.75
			_h = 1.45
			ch.setup(MINION, _h, [["", TEX_INK]], [], Color("#C9FF8A"))
			_tint(Color("#BFB8A6"), 0.9)
			_glow_a = 0.15
			_glow_c = Color("#9AE070")
		"shinobi":
			# shinobi : garde indigo, cagoule, hachimaki rouge, ninjatō au dos et en main
			hp = 1.2
			speed = 2.9
			radius = 0.42
			_zone_r = SHINOBI_R
			_windup = 0.7
			_walk = "Walking_A"
			_h = 1.7
			_rogue = true
			if _rig:
				ch.setup(NinjaRig.enemy_config(kind), _h)
			else:
				ch.setup(ROGUE, _h, [["", TEX_ROGUE_INDIGO]], ROGUE_GEAR.duplicate(), Toon.GOLD)
				_tint(Color("#9AA2C8"), 1.0)
			_timer = randf_range(0.8, 1.4)
		"shuriken":
			# lanceur de shuriken : garde d'encre grise, bandoulière d'étoiles, une étoile en main
			hp = 1.0
			speed = 1.8
			radius = 0.42
			_walk = "Walking_A"
			_h = 1.6
			_rogue = true
			if _rig:
				ch.setup(NinjaRig.enemy_config(kind), _h)
			else:
				ch.setup(ROGUE, _h, [["", TEX_ROGUE_INK]], ROGUE_GEAR.duplicate(), Toon.GOLD)
				_tint(Color("#A8B0C0"), 1.0)
			_timer = randf_range(1.6, 2.4)
		"kemuri":
			# ninja des fumées : garde glycine sombre, bombes à la ceinture
			hp = 1.3
			speed = 1.9
			radius = 0.42
			_walk = "Walking_B"
			_h = 1.65
			_rogue = true
			if _rig:
				ch.setup(NinjaRig.enemy_config(kind), _h)
			else:
				ch.setup(ROGUE, _h, [["", TEX_ROGUE_GLYCINE]], ROGUE_GEAR.duplicate(), Toon.GOLD)
				_tint(Color("#9A90B0"), 1.0)
			_timer = randf_range(1.8, 2.6)
		"kunoichi":
			# kunoichi : garde sakura sombre, queue de cheval, kusarigama
			hp = 1.5
			speed = 2.2
			radius = 0.44
			_walk = "Walking_B"
			_h = 1.65
			_rogue = true
			if _rig:
				ch.setup(NinjaRig.enemy_config(kind), _h)
			else:
				ch.setup(ROGUE, _h, [["", TEX_ROGUE_SAKURA]], ROGUE_GEAR.duplicate(), Toon.GOLD)
				_tint(Color("#D88A8A"), 1.0)
			_timer = randf_range(1.4, 2.2)
		"gokusotsu":
			# gokusotsu : geôlier des enfers à tête de bœuf (gozu), chaîne de fer ; armure de départ
			hp = 3.0
			speed = 1.4
			radius = 0.7
			_walk = "Walking_A"
			_h = 2.3
			ch.setup(WARRIOR, _h, [["Helmet", TEX_INK], ["Cloak", TEX_INK]])
			_tint(Color("#9A7A64"), 1.0)
			_shield_frac = 0.25
			_timer = randf_range(1.6, 2.4)
		"shiryo":
			# shiryō : feu d'âme violet à longue traîne ; annonce un cercle de feu froid sous le héros
			hp = 1.0
			speed = 1.8
			radius = 0.4
			_h = 1.1
			_custom = true
			Toon.part(body, _sph(0.3), main.vfx.glow_mat(YOMI_C, 2.2), Vector3(0, 0.5, 0))
			Toon.part(body, _sph(0.18), main.vfx.glow_mat(Color("#F0E8FF"), 2.4), Vector3(0, 0.52, -0.08))
			var strail := Toon.part(body, _cyl(0.0, 0.26, 0.6, 7), main.vfx.glow_mat(YOMI_C, 1.6), Vector3(0, 0.55, 0.42))
			strail.rotation.x = PI / 2.0
			for e in [-1.0, 1.0]:
				Toon.part(body, _sph(0.05), _pm(Toon.SUMI, false), Vector3(float(e) * 0.1, 0.56, -0.27))
			body.position.y = 0.9
			_timer = randf_range(1.6, 2.4)


## Rogue KayKit : ne garder que les armes listées.
func _gear_except(keep: Array) -> Array:
	var out: Array = []
	for g in ROGUE_GEAR:
		if not (g in keep):
			out.append(g)
	return out


# maillages et matériaux partagés (créés une fois pour toute la partie)
func _sph(r: float) -> Mesh:
	var key := "s%.3f" % r
	if not _res.has(key):
		_res[key] = Toon.sphere(r)
	return _res[key] as Mesh


func _cyl(top: float, bottom: float, h: float, sides := 12) -> Mesh:
	var key := "c%.3f_%.3f_%.3f_%d" % [top, bottom, h, sides]
	if not _res.has(key):
		_res[key] = Toon.cyl(top, bottom, h, sides)
	return _res[key] as Mesh


func _torus() -> Mesh:
	if not _res.has("torus"):
		var t := TorusMesh.new()
		t.inner_radius = 0.86
		t.outer_radius = 1.0
		t.rings = 28
		t.ring_segments = 4
		_res["torus"] = t
	return _res["torus"] as Mesh


func _pm(c: Color, outline := true) -> Material:
	var key := "m%s%s" % [c.to_html(), "o" if outline else ""]
	if not _res.has(key):
		_res[key] = Toon.mat(c, outline, 0.02)
	return _res[key] as Material


func _fm(c: Color) -> Material:
	var key := "f%s" % c.to_html()
	if not _res.has(key):
		_res[key] = Toon.flat(c)
	return _res[key] as Material


func _shield_mat() -> Material:
	if not _res.has("bubble"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(SHIELD_C, 0.17)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.no_depth_test = false
		_res["bubble"] = m
	return _res["bubble"] as Material


func _blade(blade_len: float, steel: Color) -> Node3D:
	var k := Node3D.new()
	Toon.part(k, Toon.box(Vector3(0.05, 0.2, 0.05)), Toon.mat(Color("#4A3A2C")), Vector3.ZERO)
	Toon.part(k, Toon.box(Vector3(0.035, blade_len, 0.08)), Toon.mat(steel, true, 0.015), Vector3(0, 0.1 + blade_len / 2.0, 0))
	return k


## Tenue de yōkai (Yokai.parts) : un maillage fusionné par os, matériau partagé ; sans ombre en mode léger.
func _dress() -> void:
	ch.hide_meshes(Yokai.hidden(kind))
	var d := Yokai.parts(kind, ch.scale_factor)
	for bone in d:
		ch.attach_mesh(String(bone), d[bone] as Mesh, Yokai.mat(), not Toon.lite)


## Maillage fusionné d'un corps modelé (repère du corps, face -Z).
func _ymesh(part: String) -> Mesh:
	var d := Yokai.parts(kind, 1.0)
	return d.get(part) as Mesh


## Panse lumineuse de la lanterne du montreur de renards (la perche vient de Yokai).
func _lantern_glow() -> Node3D:
	var k := Node3D.new()
	Toon.part(k, _sph(0.12), main.vfx.glow_mat(FOX_FIRE, 2.0), Vector3(0, 1.165, 0), Vector3(1, 1.3, 1))
	return k


## Boule lumineuse tenue à la main (perle du moine, flamme du renard).
func _orb(r: float, c: Color) -> Node3D:
	var k := Node3D.new()
	Toon.part(k, _sph(r), main.vfx.glow_mat(c, 3.0), Vector3(0, 0.15, 0))
	return k


## Rendu fantôme : teinte bleutée et lueur (sans transparence).
func _ghostify() -> void:
	_glow_a = 0.35
	_glow_c = FUNA_TINT
	ch.set_glow(0.35, FUNA_TINT)
	_tint(Color.WHITE, 0.75)


## Teinte (multipliée à la texture) de tous les matériaux du modèle ; `alpha` < 1 éclaircit et allume la lueur.
func _tint(c: Color, alpha: float) -> void:
	if _ink:
		return  # corps d'encre : couleurs de sommets, aplat partagé ; la lueur suffit (set_glow)
	for n in ch.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m == null:
				continue
			# plus de transparence (source de scintillement) : un fantôme se lit par sa teinte claire et sa lueur
			var lift := clampf(1.0 - alpha, 0.0, 1.0)
			m.albedo_color = Color(c.r, c.g, c.b, 1.0).lerp(Color(1, 1, 1), lift * 0.35)
			m.emission_enabled = true
			m.emission = Color(c.r, c.g, c.b)
			m.emission_energy_multiplier = maxf(m.emission_energy_multiplier, lift * 0.6)


func _base_glow() -> void:
	ch.set_glow(_glow_a, _glow_c)


func _make_zone(fixed := false) -> void:
	_zone = Node3D.new()
	# zone fixe : reste à l'endroit visé, en coordonnées globales
	_zone.top_level = fixed
	add_child(_zone)
	_tele = main.vfx.tele_disc(_zone, _zone_r)


func is_harmless() -> bool:
	if (kind == "funa" or kind == "umibozu") and _phase != "up":
		return true
	if kind == "kasa" and _air:
		return true  # en l'air : hors d'atteinte
	if kind == "onryo" and (_state == "fade" or _state == "gone"):
		return true  # évanoui
	if kind == "kemuri" and _state == "gone":
		return true  # dans la fumée
	return _spawn > 0.0 or dead


## Vrai si un coup venant dans la direction `dir` (ruée du héros) frappe le bouclier (cône frontal 120°).
func blocks(dir: Vector3) -> bool:
	if (kind != "tate" and kind != "kani") or dead or _stagger > 0.0:
		return false
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		return false
	var front := Vector3(-sin(body.rotation.y), 0, -cos(body.rotation.y))
	return d.normalized().dot(front) < -0.5


## Bouclier frappé : la garde s'ouvre un instant (le coup suivant passe).
func shield_break() -> void:
	_stagger = 1.4
	if _state == "windup":
		_cancel_attack()
	ch.play_once("Hit_A", 1.2)


func take_hit(dmg: float, dir: Vector3) -> bool:
	dmg = _armour(dmg, dir)
	dmg = _absorb(dmg, _figure_hit())
	hp -= dmg
	_flash = FLASH_T
	_knock = dir.normalized() * _knock_force()
	if kind == "funa" or kind == "tsurara" or _state == "charge" or _air:
		_knock = Vector3.ZERO
	if _state == "windup" and (hp <= 0.0 or _flinches()):
		_cancel_attack()
	if hp <= 0.0:
		_die()
		# mort franche : recul (~1 m), il bascule dans le sens du coup
		_knock = Vector3.ZERO if kind == "funa" or kind == "tsurara" else dir.normalized() * DIE_KNOCK
		var hd := Vector3(dir.x, 0.0, dir.z)
		if hd.length_squared() > 0.0001:
			body.rotation.y = atan2(hd.x, hd.z)  # dos au coup : la bascule (rotation.x) le couche dans son sens
		return true
	ch.play_once("Hit_A", 1.6)
	# le coup écrase la silhouette (retour en douceur, _process) et le fige un instant
	body.scale = SQUASH
	_squash = 0.25
	_hit_freeze = HIT_FREEZE
	if kind == "umibozu" and _phase == "up":
		# touché sans être tranché net : il replonge bientôt (pas aussitôt : sinon, PV élevés des derniers
		# mondes, il plonge à chaque coup et le combat traîne)
		_ptimer = minf(_ptimer, 0.8)
	elif kind == "tanuki" and _doron_cd <= 0.0:
		_doron_cd = 6.0
		call_deferred("_doron")
	_on_wounded()
	return false


## Un coup (non mortel) casse-t-il l'annonce ? Ni élite ni lourd ; dès le monde 3, seulement à partir de
## la 2e touche du trait (combo >= 2). Le bouclier brisé la casse toujours (_shield_broken).
func _flinches() -> bool:
	if elite or kind in HEAVY_KINDS:
		return false
	if _world() >= 3:
		var c = main.get("combo") if main != null else null
		return c != null and int(c) >= 2
	return true


## Monde en cours (1 au dojo, ou sans main.gd) : difficulté des annonces, des coups lourds.
func _world() -> int:
	if main == null or str(main.get("state")) == "tuto":
		return 1
	var w = main.get("current_world")
	return int(w) if w != null else 1


## Cœurs ôtés par un coup de cet ennemi (lourds : 2 dès le monde HEAVY_HIT_WORLD).
func _hit_n() -> int:
	return 2 if kind in HEAVY_HIT_KINDS and _world() >= HEAVY_HIT_WORLD else 1


func _knock_force() -> float:
	var f := 7.0
	match kind:
		"brute":
			f = 3.0
		"kanabo":
			f = 2.0
		"tate", "kasha", "tanuki", "kani":
			f = 4.5
		"gokusotsu":
			f = 3.0
	if shield > 0.0:
		f *= 0.5
	return f


## Kanabō : armure de face (35 % des dégâts), dos exposé (×1.4).
func _armour(dmg: float, dir: Vector3) -> float:
	if kind != "kanabo" or _stagger > 0.0:
		return dmg
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		return dmg
	var front := Vector3(-sin(body.rotation.y), 0, -cos(body.rotation.y))
	var dot := d.normalized().dot(front)
	if dot < -0.5:
		main.vfx.sparks(position + Vector3(0, 1.4, 0) + front * 0.5, front, 6, Toon.GOLD)
		if _t - _armour_t > 1.2:
			_armour_t = _t
			main.float_text(position, "ARMURE", Toon.GOLD)
		return dmg * 0.35
	if dot > 0.5:
		return dmg * 1.4
	return dmg


## Le coup vient-il d'une figure (forme reconnue du trait) ?
func _figure_hit() -> bool:
	var sh = main.get("_shape")
	return sh is Dictionary and not sh.is_empty()


## Bouclier : renvoie les dégâts qui passent jusqu'aux PV (25 % tant qu'il tient, le surplus en entier).
## `strong` (figures, pouvoirs) : le bouclier s'use deux fois plus vite.
func _absorb(dmg: float, strong: bool) -> float:
	if shield <= 0.0 or dmg <= 0.0:
		return dmg
	var mult := 2.0 if strong else 1.0
	var sd := dmg * mult
	if sd < shield:
		shield -= sd
		if _t - _spark_t > 0.25:
			# étincelles bleues (limitées : les brûlures frappent à chaque image)
			_spark_t = _t
			main.vfx.sparks(position + Vector3(0, _h * 0.6, 0), Vector3.UP, 3, SHIELD_C)
		return dmg * 0.25
	var over := (sd - shield) / mult
	shield = 0.0
	_shield_broken()
	return (dmg - over) * 0.25 + over


func _shield_broken() -> void:
	_stagger = maxf(_stagger, 0.8)
	if _state == "windup" and not _air:
		_cancel_attack()
	if _bubble != null:
		_bubble.visible = false
	main.float_text(position, "BRISÉ", SHIELD_C)
	main.vfx.ring(Vector3(position.x, 0.1, position.z), SHIELD_C, 1.3)
	main.vfx.sparks(position + Vector3(0, _h * 0.6, 0), Vector3.UP, 10, SHIELD_C)
	main.sfx.play("strike", 1.6, -5.0)
	ch.play_once("Hit_A", 1.0)


## Points de bouclier (soutien, élite, armure de départ).
func give_shield(v: float) -> void:
	if dead or v <= 0.0:
		return
	shield = maxf(shield, v)
	shield_max = maxf(shield_max, shield)
	_ensure_bubble()


func shield_ratio() -> float:
	if shield <= 0.0 or shield_max <= 0.0:
		return 0.0
	return clampf(shield / shield_max, 0.0, 1.0)


## Hauteur de la barre de vie au-dessus de la tête.
func bar_top() -> float:
	return maxf(2.1, _h + 0.45) * scale.y + maxf(body.position.y, 0.0)


## Soin d'un allié (umi-nyōbō) : faux s'il est déjà indemne.
func heal_pct(f: float) -> bool:
	if dead:
		return false
	var mh := float(get_meta("max_hp", hp))
	if hp >= mh - 0.01:
		return false
	hp = minf(mh, hp + mh * f)
	main.float_text(position, "+", HEAL_C)
	return true


func _ensure_bubble() -> void:
	if _bubble != null:
		_bubble.visible = shield > 0.0
		return
	var r := maxf(radius * 1.5, _h * 0.38)
	_bubble_base = Vector3(r, _h * 0.62, r)
	_bubble = Toon.part(self, _sph(1.0), _shield_mat(), Vector3(0, _h * 0.5, 0), _bubble_base)
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.visible = shield > 0.0


# ------------------------------------------------------------------ élites

static func elite_chance(world: int) -> float:
	return 0.06 + 0.025 * float(world)


static func roll_affixes(world: int) -> Array:
	var pool: Array = ELITE_POOL.duplicate()
	pool.shuffle()
	var n := 2 if randf() < 0.2 + 0.1 * float(world) else 1
	return pool.slice(0, n)


func can_be_elite() -> bool:
	return not minion and not dummy and not elite and not (kind in NO_ELITE)


## Élite : plus gros, ×2.5 PV, bouclier, aura et cornes d'or, affixes. Appelé avant la pose de max_hp.
func promote(list: Array, announce := true) -> void:
	elite = true
	affixes = list.duplicate()
	hp *= 2.5
	scale = Vector3.ONE * 1.25
	radius *= 1.15
	_shield_frac += 0.6 if "blinde" in affixes else 0.3
	if "rapide" in affixes:
		_tempo *= 1.2
		speed *= 1.2
	_aura_r = radius * 1.4
	_aura = Toon.part(self, _torus(), main.vfx.glow_mat(ELITE_C, 2.2), Vector3(0, 0.05, 0), Vector3(_aura_r, 0.06, _aura_r))
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _ink:
		ch.set_elite(true)  # masque cerné d'or, liserés et oreilles d'or (yokai_parts.ink_parts)
	else:
		for s in [-1.0, 1.0]:
			var sx := float(s)
			var horn := Toon.part(_deco, _cyl(0.0, 0.05, 0.22, 6), _pm(ELITE_C), Vector3(sx * 0.1, _h * 1.0, -0.02))
			horn.rotation.z = -sx * 0.35
	if kind in NINJA_KINDS:
		# maître ninja : tailles enchaînées, éventail plus large, fumée plus brève, arc plus ample
		_master = true
		affixes.append("maitre")
	_ensure_bubble()
	if announce:
		var words := PackedStringArray(["ÉLITE"])
		for a in affixes:
			words.append(String(ELITE_NAMES.get(a, "")))
		main.hud.toast(" · ".join(words))


## Seuils de l'élite (Enragé, Invocateur) sous la moitié de sa vie.
func _on_wounded() -> void:
	if not elite or dead:
		return
	var mh := float(get_meta("max_hp", hp))
	if hp > mh * 0.5:
		return
	if "enrage" in affixes and not _enraged:
		_enraged = true
		_tempo *= 1.35
		_glow_a = maxf(_glow_a, 0.4)
		_glow_c = Toon.VERMILION
		_base_glow()
		main.float_text(position, "ENRAGÉ", Toon.VERMILION)
	if "invocateur" in affixes and not _called:
		_called = true
		call_deferred("_summon", _minion_kind(), 2, maxf(mh * 0.1, 0.8))


func _minion_kind() -> String:
	if kind in ["kitsunebi", "kitsune_tsukai", "onryo", "yukionna", "umi_nyobo"]:
		return "kitsunebi_s"
	if kind == "sumidama":
		return "sumidama_s"
	if kind in NINJA_KINDS:
		return "shinobi"  # le maître appelle son clan
	return "oni"


## Coup porté par l'ennemi (Vampire : se soigne s'il touche).
func _strike(center: Vector3, r: float) -> void:
	var before: int = hero.hp
	main.enemy_strike(center, r, _hit_n())
	if elite and not dead and "vampire" in affixes and int(hero.hp) < before:
		var mh := float(get_meta("max_hp", hp))
		hp = minf(mh, hp + mh * 0.25)
		main.float_text(position, "VAMPIRE", Toon.VERMILION)
		main.splash(position + Vector3(0, 1.0, 0), Toon.VERMILION, 8)
	elif kind == "gaki" and not dead and int(hero.hp) < before:
		# l'affamé dévore : il reprend des forces
		var gmh := float(get_meta("max_hp", hp))
		hp = minf(gmh, hp + gmh * 0.35)
		main.float_text(position, "VORACE", Color("#9AE070"))


## Invocation : `n` créatures autour de lui (différée : jamais pendant un parcours de main.enemies).
func _summon(k: String, n: int, hp_each: float) -> void:
	if not is_instance_valid(main) or not is_inside_tree():
		return
	var sc = get_script()
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		var p: Vector3 = main.arena.clamp_walk(Vector3(position.x, 0, position.z) + Vector3(cos(a), 0, sin(a)) * 1.0, 0.35)
		var hole: bool = main.hazards.is_hole(p, 0.1)
		if hole:
			p = Vector3(position.x, 0, position.z)
		var e = sc.new()
		e.setup(k, hero, main)
		e.minion = true
		e.position = p
		main.add_child(e)
		e.hp = hp_each
		e.set_meta("max_hp", e.hp)
		main.enemies.append(e)
		_summons.append(e)
	_puff(position, ELITE_C if elite else FOX_FIRE)


func _alive_summons() -> int:
	var n := 0
	for s in _summons:
		if is_instance_valid(s) and not s.dead:
			n += 1
	return n


## PV d'une invocation : base × multiplicateurs du monde et de la salle portés par l'invocateur.
func _minion_hp(base: float) -> float:
	var mult := float(get_meta("max_hp", hp)) / maxf(_base_hp, 0.01)
	if elite:
		mult /= 2.5
	return base * mult


func _puff(p: Vector3, c: Color) -> void:
	main.splash(p + Vector3(0, 0.6, 0), c, 10)
	main.vfx.ring(Vector3(p.x, 0.08, p.z), c, 0.9)


## Zone d'attaque en préparation : [centre, rayon, temps restant], ou [] s'il n'y en a pas.
func danger_zone() -> Array:
	if _blast_t > 0.0:
		return [_target, _zone_r, _blast_t]
	if _state == "windup" and kind == "tengu" and _traps.size() > 0:
		return [_closest_pt(_traps, _probe()), TRAP_R, _timer]
	if _state == "windup" and kind == "yamabushi" and _zone != null:
		# rafale : point de l'axe du cône le plus proche, demi-largeur du cône à cet endroit
		var gq := _probe()
		var gt := clampf(Vector3(gq.x - _target.x, 0, gq.z - _target.z).dot(_strike_dir), 0.3, GUST_LEN)
		return [_target + _strike_dir * gt, gt * tan(GUST_HALF), _timer]
	if _state == "windup" and not _fan.is_empty():
		# éventail de shuriken : la ligne la plus proche
		return [_fan_closest(_probe()), SHURI_W * 0.5, _timer]
	if _state == "windup" and kind == "kunoichi" and _zone != null:
		# chaîne : point de l'axe de l'arc le plus proche, demi-largeur de l'arc à cet endroit
		var kq := _probe()
		var kt := clampf(Vector3(kq.x - _target.x, 0, kq.z - _target.z).dot(_strike_dir), 0.3, KUSARI_LEN)
		return [_target + _strike_dir * kt, kt * tan(_kusari_half()), _timer]
	if _state == "windup" and _zone != null:
		if _lane.size() >= 2:
			return [_lane_closest(_probe()), _lane_w * 0.5, _timer]
		if _zone.top_level:
			# zone fixe visée (noyé, moine, renard, obus, bond…)
			return [_target, _zone_r, _timer]
		return [position + _strike_dir * (_zone_r * 0.9), _zone_r, _timer]
	if _fire_t > 0.0:
		# traînée de feu encore chaude
		return [_seg_closest(_probe(), _fire_a, _fire_b), 0.3, 0.0]
	if _trap_t > 0.0 and _traps.size() > 0:
		return [_closest_pt(_traps, _probe()), TRAP_R, 0.0]
	return []


func _closest_pt(pts: PackedVector3Array, p: Vector3) -> Vector3:
	var best := pts[0]
	var bd := INF
	for q in pts:
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < bd:
			bd = d
			best = q
	return best


## Point à tester pour l'alerte d'arrivée : la fin du trait en cours, sinon le héros.
func _probe() -> Vector3:
	var s = main.stroke
	if main.touching and is_instance_valid(s):
		var p: Vector3 = s.last()
		return p
	return hero.position


## Éclat de touche à la couleur d'un élément (pouvoirs, powers._dmg) : bref, il remplace l'éclat blanc.
func elem_flash(c: Color) -> void:
	if dead:
		return
	flash_c = c
	_flash = maxf(_flash, 0.1)


## Dégâts « indirects » (brûlure, foudre, feu) : pas de recul ni d'animation de coup.
func hurt_dot(dmg: float) -> bool:
	if dead or is_harmless():
		return false
	dmg = _absorb(dmg, true)
	hp -= dmg
	_flash = maxf(_flash, 0.05)
	if hp <= 0.0:
		_die()
		_knock = Vector3.ZERO
		return true
	_on_wounded()
	return false


func _die() -> void:
	dead = true
	_cancel_attack()
	_timer = 0.0
	_thaw()
	_clear_ice()
	_clear_traps()
	_clear_cloud()
	_fire_t = 0.0
	_air = false
	_die_y = body.position.y
	_hit_freeze = 0.0
	if kind == "kemuri":
		# tombé dans la fumée : on le voit tomber
		body.visible = true
		_shadow.visible = true
	shield = 0.0
	ch.hold()
	ch.play_once("Death_A" if kind == "kagebo" or _rogue else "Death_C_Skeletons", 2.4, 0.05)
	if kind == "kitsunebi":
		call_deferred("_split")
	elif kind == "sumidama":
		call_deferred("_split_blob")
	elif kind == "tanuki_d":
		# leurre : fumée, rien d'autre
		_puff(position, Toon.WASHI)
		body.visible = false
	elif kind == "hinotama":
		main.vfx.fire_burst(Vector3(position.x, 0, position.z), 0.9)
		body.visible = false
	elif kind == "karasu":
		# nuée de plumes noires
		main.splash(position + Vector3(0, body.position.y + 0.5, 0), Toon.SUMI, 12)
		body.visible = false
	elif kind == "shiryo":
		_puff(position + Vector3(0, body.position.y, 0), YOMI_C)
		body.visible = false
	elif kind == "fugu":
		main.vfx.water_burst(Vector3(position.x, 0, position.z), 0.7)
	if body.visible:
		# il s'enfonce dans une flaque d'encre (visuel seulement)
		main.vfx.spawn_ink(position, radius * 0.9, true)
	if elite and not _selfkill and not dummy and not has_meta("elite"):
		# élite de vague : butin en plus (le défi d'un recoin a le sien, dans main)
		main.pickups.drop(position, "coin", 4)
		main.pickups.drop(position, "xp", 5)
	if elite and "explosif" in affixes:
		# Explosif : il éclate après sa mort (disque annoncé)
		_blast_t = BLAST_T
		_target = Vector3(position.x, 0, position.z)
		_zone_r = BLAST_R
		_make_zone(true)
		_zone.global_position = _target
		main.float_text(position, "EXPLOSIF", ELITE_C)


func push(v: Vector3) -> void:
	# un mort n'est plus projeté (fin sobre) ; costauds et tourelle ne bougent pas
	if kind != "brute" and kind != "funa" and kind != "kanabo" and kind != "tsurara" and not dead and _state != "charge" and not _air:
		_knock += v


func _cancel_attack() -> void:
	_state = "recover"
	_timer = 0.6
	_base_glow()
	main.free_token(self)
	if _zone:
		_zone.queue_free()
		_zone = null
	_teles = []
	_lane = PackedVector3Array()
	_proj = null
	_fan = []
	_clear_stars()


func _exit_tree() -> void:
	if _slowed:
		_thaw()


func _process(delta: float) -> void:
	# Rapide / Enragé : tout le rythme (marche, annonces, repos) accéléré
	delta *= _tempo
	_t += delta
	if _shield_frac > 0.0:
		# bouclier de départ : posé une fois les PV du monde appliqués
		give_shield(float(get_meta("max_hp", hp)) * _shield_frac)
		_shield_frac = 0.0
	if _flash > 0.0:
		_flash -= delta
		# éclat blanc franc (plein éclat d'abord), puis qui retombe
		var fa := 0.0
		if _flash > FLASH_T - FLASH_FULL:
			fa = 1.0
		elif _flash > 0.0:
			fa = 0.35 + 0.65 * clampf(_flash / (FLASH_T - FLASH_FULL), 0.0, 1.0)
		if _flash > 0.0 and flash_c != Color.WHITE:
			ch.set_glow(fa * 1.6, flash_c)  # éclat à la couleur de l'élément
		else:
			ch.set_flash(fa)
		if _flash <= 0.0:
			flash_c = Color.WHITE
		if _flash <= 0.0 and _glow_a > 0.0:
			_base_glow()
	if _bubble != null or _aura != null:
		_update_marks()

	if dead:
		if _blast_t > 0.0:
			# Explosif : le disque se remplit, puis éclate
			_blast_t -= delta
			if is_instance_valid(_tele):
				main.vfx.tele_update(_tele, 1.0 - _blast_t / BLAST_T, _blast_t)
			if _blast_t <= 0.0:
				_blast_t = 0.0
				main.enemy_strike(_target, _zone_r, 2 if _world() >= HEAVY_HIT_WORLD else 1)
				main.vfx.fire_burst(_target, _zone_r)
				if _zone:
					_zone.queue_free()
					_zone = null
		# mort (0,7 s) : recul franc, petit saut en basculant dans le sens du coup, puis s'enfonce dans le sol
		position += _knock * delta
		_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
		_timer += delta
		var tk := clampf(_timer / DIE_HOP, 0.0, 1.0)
		body.rotation.x = DIE_TILT * (1.0 - (1.0 - tk) * (1.0 - tk))
		var sink := clampf((_timer - DIE_HOP) / DIE_SINK, 0.0, 1.0)
		if _timer < DIE_HOP:
			body.position.y = _die_y + DIE_HOP_H * sin(PI * tk)
		else:
			body.position.y = _die_y * (1.0 - sink) - 1.3 * sink * sink
		body.scale = Vector3.ONE * (1.0 - 0.2 * sink)
		if _shadow:
			_shadow.visible = sink < 0.5
		if _timer > DIE_HOP + DIE_SINK and _blast_t <= 0.0:
			queue_free()
		return

	if _spawn > 0.0:
		_spawn -= delta
		_deco.visible = _spawn <= 0.0
		var to := hero.position - position
		body.rotation.y = atan2(-to.x, -to.z)
		if _scale_in > 0.0:
			body.scale = Vector3.ONE * (clampf(1.0 - _spawn / _scale_in, 0.05, 1.0) if _spawn > 0.0 else 1.0)
		return

	if _squash > 0.0:
		# écrasement du coup : la silhouette reprend sa forme en douceur
		_squash -= delta
		body.scale = Vector3.ONE if _squash <= 0.0 else body.scale.lerp(Vector3.ONE, minf(1.0, delta * 12.0))

	if kind == "funa":
		_ghost(delta)
		return

	if dummy and not spar:
		return

	if _hit_freeze > 0.0:
		# touché : figé un instant (ni marche, ni attaque, ni recul), puis le recul part
		_hit_freeze -= delta
		return

	if _hit_cd > 0.0:
		_hit_cd -= delta
	if _fire_t > 0.0:
		_update_fire(delta)
	if _ice != null:
		_update_ice(delta)
	if _trap_t > 0.0:
		_update_traps(delta)
	if _cloud_t > 0.0:
		_update_cloud(delta)
	if kind == "kagebo":
		_record()
	if _custom:
		body.scale = body.scale.lerp(Vector3.ONE, minf(1.0, delta * 8.0))
	if not _wings.is_empty():
		_flap()

	var to_hero := hero.position - position
	to_hero.y = 0
	var dist := to_hero.length()
	var dir := to_hero / maxf(dist, 0.001)

	match kind:
		"oni", "brute", "tate", "kanabo", "kani", "gaki":
			_melee(delta, dir, dist)
		"kappa":
			_shooter(delta, dir, dist)
		_:
			if _stagger > 0.0:
				# assommé (pouvoirs, bouclier brisé) : ni marche ni attaque
				_stagger -= delta
				if _state == "charge":
					_end_charge()
			else:
				match kind:
					"umibozu":
						_umibozu(delta, dir, dist)
					"kitsunebi", "kitsunebi_s":
						_kitsune(delta, dir, dist)
					"yukionna":
						_yuki(delta, dir, dist)
					"kasha":
						_kasha(delta, dir, dist)
					"kagebo":
						_kagebo(delta, dir, dist)
					"kappa_yumi", "teppo", "ningyo":
						_sniper(delta, dir, dist)
					"ika":
						_mortar(delta, dir, dist)
					"umi_nyobo", "moryo":
						_support(delta, dir, dist)
					"kamaitachi", "hinotama", "karasu":
						_swooper(delta, dir, dist)
					"tanuki", "tanuki_d":
						_tanuki(delta, dir, dist)
					"kitsune_tsukai":
						_summoner(delta, dir, dist)
					"yuki_warashi", "sumidama", "sumidama_s":
						_bomber(delta, dir, dist)
					"tsurara":
						_turret(delta, dir, dist)
					"onryo":
						_onryo(delta, dir, dist)
					"tengu":
						_trapper(delta, dir, dist)
					"kasa":
						_hopper(delta, dir, dist)
					"yamabushi":
						_gust(delta, dir, dist)
					"konoha":
						_leaves(delta, dir, dist)
					"fugu":
						_puffer(delta, dir, dist)
					"gokusotsu":
						_jailer(delta, dir, dist)
					"shiryo":
						_wisp(delta, dir, dist)
					"shinobi":
						_shinobi(delta, dir, dist)
					"shuriken":
						_shuriken_ai(delta, dir, dist)
					"kemuri":
						_kemuri(delta, dir, dist)
					"kunoichi":
						_kunoichi(delta, dir, dist)

	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 9.0))
	main.clamp_to_arena(self, radius)


## Bulle du bouclier et aura d'élite : légère pulsation, suivent un corps qui flotte.
func _update_marks() -> void:
	if _bubble != null:
		if dead or shield <= 0.0:
			_bubble.visible = false
		elif _bubble.visible:
			_bubble.position.y = body.position.y + _h * 0.5
			_bubble.scale = _bubble_base * (1.0 + 0.03 * sin(_t * 5.0))
	if _aura != null:
		_aura.visible = not dead
		var s := _aura_r * (1.0 + 0.08 * sin(_t * 4.0))
		_aura.scale = Vector3(s, 0.06, s)


func _face(dir: Vector3, delta: float, rate := 10.0) -> void:
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * rate))


func _melee(delta: float, dir: Vector3, dist: float) -> void:
	if _stagger > 0.0:
		# garde ouverte : il titube, ni marche ni attaque
		_stagger -= delta
		return
	var reach := 0.6 + _zone_r
	match _state:
		"move":
			# le porteur de bouclier pivote lentement : on peut le contourner
			_face(dir, delta, 3.0 if kind == "tate" or kind == "kani" else (2.5 if kind == "kanabo" else 10.0))
			if dist > reach - 0.3:
				# chemin : par la passerelle si le héros est sur une autre plateforme
				# recalculé 5 fois par seconde seulement (parcours des plateformes)
				_steer_t -= delta
				if _steer_t <= 0.0:
					_steer_t = 0.2
					_steer = main.steer_dir(position, hero.position)
				var sd := _steer
				position += sd * speed * delta
				if sd != Vector3.ZERO:
					_face(sd, delta)
				ch.play(_walk, speed / 1.6)
			else:
				# tate : garde le bouclier levé à l'arrêt
				ch.play(ch.idle)
			if dist <= reach - 0.3:
				# jeton d'attaque : au plus N ennemis en préparation en même temps
				if not main.take_token(self):
					var around := Vector3(-dir.z, 0, dir.x) * (1.0 if get_instance_id() % 2 == 0 else -1.0)
					position += around * 1.0 * delta
					ch.play(_walk, 0.6)
					return
				_state = "windup"
				_timer = _windup
				_strike_dir = dir
				_make_zone()
				# le coup de l'animation tombe pile à la fin de l'annonce
				ch.play_once(_attack, ch.length(_attack) * 0.5 / _windup)
		"windup":
			var k := 1.0 - _timer / _windup
			_zone.position = _strike_dir * (_zone_r * 0.9)
			# remplissage, pulsation et flash final (vfx.tele_update)
			main.vfx.tele_update(_tele, k, _timer)
			_timer -= delta
			if _timer <= 0.0:
				var center := position + _strike_dir * (_zone_r * 0.9)
				_strike(center, _zone_r)
				if kind == "kanabo":
					# la massue fend le sol
					main.vfx.ring(Vector3(center.x, 0.08, center.z), Toon.GOLD, _zone_r * 1.1)
					main.vfx.scorch(center, _zone_r * 0.8, 1.0)
					main.shake = maxf(float(main.shake), 0.21)
				_cancel_attack()
				_timer = 1.3
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"


func _shooter(delta: float, dir: Vector3, dist: float) -> void:
	_face(dir, delta, 6.0)
	if _state == "move":
		# reste à distance moyenne, glisse sur le côté
		var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.8)
		var want := 0.0
		if dist < 4.5:
			want = -1.0
		elif dist > 7.0:
			want = 1.0
		var v := (dir * want + side * 0.6) * speed
		position += v * delta
		if v.length() > 0.3:
			ch.play(_walk, 0.8)
		else:
			ch.play("Idle_Combat")
		_timer -= delta
		if _timer <= 0.0:
			if not main.take_token(self):
				_timer = 0.4
				return
			_state = "windup"
			_timer = 0.7
			ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / 0.7)
	elif _state == "windup":
		var k := 1.0 - _timer / 0.7
		ch.set_glow(0.55 * k)
		_timer -= delta
		if _timer <= 0.0:
			ch.set_glow(0.0)
			main.spawn_bullet(position + Vector3(0, 1.1, 0) + dir * 0.5, dir)
			main.free_token(self)
			_state = "move"
			_timer = 2.6 + randf() * 1.2
	elif _state == "recover":
		# sort ici quand le tir a été interrompu par un coup
		_timer -= delta
		if _timer <= 0.0:
			_state = "move"
			_timer = 1.5


# ------------------------------------------------------------------ déplacements communs

## Marche vers le héros (par les passerelles si besoin).
func _walk_to_hero(delta: float, spd: float) -> void:
	_steer_t -= delta
	if _steer_t <= 0.0:
		_steer_t = 0.2
		_steer = main.steer_dir(position, hero.position)
	position += _steer * spd * delta
	if _steer != Vector3.ZERO:
		_face(_steer, delta)
	ch.play(_walk, maxf(spd / 1.6, 0.6))


## Garde une distance entre `near` et `far` en glissant sur le côté.
func _drift(delta: float, dir: Vector3, dist: float, near: float, far: float) -> void:
	var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.8)
	var fwd := dir
	var want := 0.0
	if _corner_t > 0.0:
		_corner_t -= delta
	if dist < near and _corner_t <= 0.0:
		want = -1.0
	elif dist > far or _corner_t > 0.0:
		want = 1.0
		_steer_t -= delta
		if _steer_t <= 0.0:
			_steer_t = 0.2
			_steer = main.steer_dir(position, hero.position)
		fwd = _steer
	var v := (fwd * want + side * 0.6) * speed
	position += v * delta
	if v.length() > 0.3:
		ch.play(_walk, 0.8)
	else:
		ch.play(ch.idle)
	# coincé contre un bord ou dans un coin : il revient un moment vers le héros
	_drift_t += delta
	if _drift_t > 2.0:
		if position.distance_to(_drift_p) < 0.5 and dist > 3.0:
			_corner_t = 1.6
		_drift_p = position
		_drift_t = 0.0


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


func _seg_closest(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	ab.y = 0.0
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf(Vector3(p.x - a.x, 0, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector3(a.x + ab.x * t, 0, a.z + ab.z * t)


func _path_closest(pts: PackedVector3Array, p: Vector3) -> Vector3:
	if pts.size() == 0:
		return position
	var best := pts[0]
	var bd := INF
	for i in range(1, pts.size()):
		var q := _seg_closest(p, pts[i - 1], pts[i])
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < bd:
			bd = d
			best = q
	return best


func _lane_closest(p: Vector3) -> Vector3:
	return _path_closest(_lane, p)


func _path_len(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


## Avance de `a` vers `b` tant que le sol est ferme ; renvoie le dernier point sûr.
func _cut_walkable(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	d.y = 0.0
	var n := int(ceil(d.length() / 0.25))
	var last := Vector3(a.x, 0, a.z)
	for i in range(1, n + 1):
		var p := a + d * (float(i) / float(n))
		p.y = 0.0
		var ok: bool = main.arena.walkable(p, radius * 0.8) and not main.hazards.is_hole(p, 0.1)
		if not ok:
			break
		last = p
	return last


## Couloir annoncé le long d'une polyligne : une annonce rectangulaire par segment.
func _make_lane(pts: PackedVector3Array, w: float) -> void:
	_lane = pts
	_lane_w = w
	_zone = Node3D.new()
	_zone.top_level = true
	add_child(_zone)
	_tele = null
	_teles = []
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var d := pts[i] - a
		d.y = 0.0
		var l := maxf(d.length(), 0.1)
		var seg := Node3D.new()
		_zone.add_child(seg)
		seg.position = Vector3(a.x, 0, a.z)
		seg.rotation.y = atan2(-d.x, -d.z)
		# part de a (z = 0) et se remplit vers -z
		var tl: Node3D = main.vfx.tele_rect(seg, w * 0.5, l * 0.5, Vector2(0, 1))
		tl.position.z = -l * 0.5
		_teles.append(tl)


func _update_lane(k: float) -> void:
	for tl in _teles:
		main.vfx.tele_update(tl, k, _timer)


## Fin de l'annonce : la course commence (le couloir s'efface, le jeton reste pris).
func _start_charge(spd: float) -> void:
	if _zone:
		_zone.queue_free()
		_zone = null
	_teles = []
	_state = "charge"
	_li = 1
	_cspeed = spd
	_ctime = _path_len(_lane) / spd + 0.4
	_hit_cd = 0.0
	_knock = Vector3.ZERO


func _charge(delta: float) -> void:
	_ctime -= delta
	var move := _cspeed * delta
	while move > 0.0 and _li < _lane.size():
		var tgt := _lane[_li]
		var to := tgt - position
		to.y = 0.0
		var d := to.length()
		if d > 0.001:
			body.rotation.y = atan2(-to.x, -to.z)
		if d <= move:
			position = Vector3(tgt.x, position.y, tgt.z)
			move -= d
			_li += 1
		else:
			position += to / d * move
			move = 0.0
	_knock = Vector3.ZERO
	# contact : un seul coup tous les 0.6 s
	if _hit_cd <= 0.0 and _flat_dist(hero.position) < radius + 0.4:
		_hit_cd = 0.6
		_strike(Vector3(position.x, 0, position.z), radius + 0.25)
	if _li >= _lane.size() or _ctime <= 0.0:
		_end_charge()


func _end_charge() -> void:
	main.free_token(self)
	_base_glow()
	if kind == "kasha" and _lane.size() >= 2:
		var from := _lane[0]
		var to := Vector3(position.x, 0, position.z)
		if from.distance_to(to) > 0.8:
			_fire_a = from
			_fire_b = to
			_fire_t = FIRE_TIME
			# points tous les 0.4 m : les flammes couvrent toute la traînée
			var pts := PackedVector3Array()
			var n := int(ceil(from.distance_to(to) / 0.4))
			for i in n + 1:
				pts.append(from.lerp(to, float(i) / float(n)))
			main.vfx.fire_trail(pts, FIRE_TIME)
		ch.play_once("Hit_A", 0.8)
	elif kind == "kagebo":
		for i in range(1, _lane.size()):
			main.vfx.slash_line(_lane[i - 1], _lane[i])
	elif kind == "kamaitachi":
		main.vfx.wind_slash(position, _strike_dir)
	elif kind == "hinotama":
		main.vfx.embers(Vector3(position.x, 0, position.z), 0.6, 5)
	elif kind == "karasu":
		main.vfx.wind_slash(position, _strike_dir, 0.8)
	_state = "recover"
	_timer = 1.6 if kind == "kasha" else (1.8 if kind == "kamaitachi" else 1.5)
	_lane = PackedVector3Array()


# ------------------------------------------------------------------ umibōzu

func _surface() -> void:
	_phase = "rise"
	_ptimer = FUNA_EMERGE
	body.visible = true
	body.position.y = FUNA_DEPTH
	_shadow.visible = true
	_face_hero_now()
	ch.play("Idle_Combat")


func _umibozu(delta: float, dir: Vector3, dist: float) -> void:
	_ptimer -= delta
	match _phase:
		"rise":
			# sort de l'eau, encore intouchable
			body.position.y = lerpf(FUNA_DEPTH, 0.0, clampf(1.0 - _ptimer / FUNA_EMERGE, 0.0, 1.0))
			_face(dir, delta, 8.0)
			if _ptimer <= 0.0:
				body.position.y = 0.0
				_phase = "up"
				_ptimer = UMI_UP
		"up":
			# émergé : lent et vulnérable
			if dist > 1.2:
				_walk_to_hero(delta, speed)
			else:
				_face(dir, delta, 6.0)
				ch.play("Idle_Combat")
			if _ptimer <= 0.0:
				_phase = "dive"
				_ptimer = FUNA_DIVE
		"dive":
			_knock = Vector3.ZERO
			body.position.y = lerpf(0.0, FUNA_DEPTH, clampf(1.0 - _ptimer / FUNA_DIVE, 0.0, 1.0))
			if _ptimer <= 0.0:
				_phase = "under"
				_ptimer = UMI_UNDER
				_waits = 0
				body.visible = false
				_shadow.visible = false
		"under":
			_knock = Vector3.ZERO
			if _state == "windup":
				main.vfx.tele_update(_tele, 1.0 - _timer / UMI_WINDUP, _timer)
				_timer -= delta
				if _timer <= 0.0:
					_strike(_target, _zone_r)
					main.vfx.water_burst(_target, _zone_r)
					_end_ghost_attack()
					_surface()
				return
			# sous les planches : il file vers le héros, trahi par des rides
			_walk_to_hero(delta, UMI_SWIM)
			_ripple_t -= delta
			if _ripple_t <= 0.0:
				_ripple_t = 0.3
				main.vfx.ring(Vector3(position.x, 0.06, position.z), Toon.FOAM, 0.55)
			if _ptimer > 0.0:
				return
			_ptimer = 0.3
			_waits += 1
			if _waits > 8:
				# pas de jeton ni d'ouverture : il remonte sans frapper
				_surface()
				return
			var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), radius)
			var hole: bool = main.hazards.is_hole(t, 0.1)
			if hole or dist > 7.5 or not main.take_token(self):
				return
			_target = t
			position = t
			_state = "windup"
			_timer = UMI_WINDUP
			_make_zone(true)
			_zone.global_position = _target


# ------------------------------------------------------------------ kitsune-bi

func _blink_fx(p: Vector3) -> void:
	main.vfx.ring(Vector3(p.x, 0.08, p.z), FOX_FIRE, 0.6)
	main.splash(p + Vector3(0, 0.6, 0), FOX_FIRE, 6)


func _kitsune(delta: float, dir: Vector3, dist: float) -> void:
	var mini := kind == "kitsunebi_s"
	# flotte au-dessus du sol
	body.position.y = lerpf(body.position.y, 0.3 + 0.12 * sin(_t * 3.0), minf(1.0, delta * 4.0))
	_face(dir, delta, 8.0)
	match _state:
		"move":
			_drift(delta, dir, dist, 2.8, 5.0)
			_timer -= delta
			if _timer <= 0.0:
				var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), radius)
				var hole: bool = main.hazards.is_hole(t, 0.1)
				if hole or not main.take_token(self):
					_timer = 0.4
					return
				# il annonce où il va apparaître… et y frappe
				_target = t
				_state = "windup"
				_timer = _windup
				_make_zone(true)
				_zone.global_position = _target
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / _windup)
		"windup":
			var k := 1.0 - _timer / _windup
			main.vfx.tele_update(_tele, k, _timer)
			ch.set_glow(_glow_a + 1.2 * k, _glow_c)
			_timer -= delta
			if _timer <= 0.0:
				_blink_fx(position)
				position = _target
				_blink_fx(_target)
				_strike(_target, _zone_r)
				_cancel_attack()
				# reste un instant sur place : la fenêtre pour le trancher
				_timer = 1.1 if mini else 1.5
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(1.6, 2.4) * (0.7 if mini else 1.0)
				if randf() < 0.5:
					# clignement d'esquive : petit saut de côté, sans dégâts
					var side := Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
					var p: Vector3 = main.arena.clamp_walk(position + side * 2.0, radius)
					var hole: bool = main.hazards.is_hole(p, 0.1)
					if not hole:
						_blink_fx(position)
						position = p
						_blink_fx(p)


## Mort du grand feu-follet : deux petits feux s'en échappent.
func _split() -> void:
	if not is_instance_valid(main) or not is_inside_tree():
		return
	var mult := float(get_meta("max_hp", 1.5)) / 1.5
	var a0 := randf() * TAU
	var sc = get_script()
	for i in 2:
		var a := a0 + PI * float(i)
		var e = sc.new()
		e.setup("kitsunebi_s", hero, main)
		var p: Vector3 = main.arena.clamp_walk(position + Vector3(cos(a), 0, sin(a)) * 0.9, 0.35)
		e.position = p
		main.add_child(e)
		e.hp *= mult
		e.set_meta("max_hp", e.hp)
		main.enemies.append(e)
	_blink_fx(position)


# ------------------------------------------------------------------ yuki-onna

func _yuki(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.0, 6.5)
			_timer -= delta
			if _timer <= 0.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				var a := Vector3(position.x, 0, position.z) + dir * 0.6
				var b := _cut_walkable(a, a + dir * YUKI_LEN)
				if a.distance_to(b) < 2.0:
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_lane(PackedVector3Array([a, b]), YUKI_W)
				_state = "windup"
				_timer = YUKI_WINDUP
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / YUKI_WINDUP)
		"windup":
			_face(_strike_dir, delta, 8.0)
			var k := 1.0 - _timer / YUKI_WINDUP
			_update_lane(k)
			ch.set_glow(_glow_a + 0.8 * k, _glow_c)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_lane_closest(hero.position), _lane_w * 0.5)
				_freeze(_lane)
				_cancel_attack()
				_lane = PackedVector3Array()
				_timer = 0.9
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.6, 3.6)


## La bande annoncée gèle : plaque de givre qui freine la ruée.
func _freeze(pts: PackedVector3Array) -> void:
	_clear_ice()
	_ice_pts = pts.duplicate()
	_ice_w = YUKI_W
	_ice_word = "GIVRE"
	_ice_col = ICE_C
	_ice_t = ICE_TIME
	_ice = Node3D.new()
	_ice.top_level = true
	add_child(_ice)
	_ice_mat = Toon.flat(Color(ICE_C, 0.55))
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var d := pts[i] - a
		d.y = 0.0
		var mi := Toon.part(_ice, Toon.box(Vector3(YUKI_W, 0.02, maxf(d.length(), 0.1))), _ice_mat, Vector3(a.x + d.x * 0.5, 0.06, a.z + d.z * 0.5))
		mi.rotation.y = atan2(-d.x, -d.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.vfx.sparks(Vector3(a.x + d.x * 0.5, 0.2, a.z + d.z * 0.5), Vector3.UP, 6, ICE_C)


func _update_ice(delta: float) -> void:
	_ice_t -= delta
	_ice_mat.albedo_color.a = 0.55 * clampf(_ice_t / 0.6, 0.0, 1.0)
	var on: bool = hero.dashing
	var sid: int = main.stroke_id
	if _slowed and (not on or sid != _slow_id):
		_thaw()
	if on and sid != _slow_id and _ice_t > 0.0:
		var q := _path_closest(_ice_pts, hero.position)
		if Vector2(q.x - hero.position.x, q.z - hero.position.z).length() < _ice_w * 0.5:
			# la ruée patine sur le givre (ou s'englue dans l'encre) : ralentie jusqu'à la fin de ce trait
			_slow_id = sid
			_slowed = true
			hero.speed_mult *= ICE_SLOW
			main.float_text(hero.position, _ice_word, _ice_col)
			main.splash(hero.position, _ice_col, 8)
	if _ice_t <= 0.0:
		_clear_ice()


## Rend sa vitesse à la ruée freinée (si c'est toujours le même trait).
func _thaw() -> void:
	if not _slowed:
		return
	_slowed = false
	if is_instance_valid(main) and is_instance_valid(hero) and int(main.stroke_id) == _slow_id:
		hero.speed_mult /= ICE_SLOW


func _clear_ice() -> void:
	if _ice != null:
		_ice.queue_free()
		_ice = null
	_ice_t = 0.0


# ------------------------------------------------------------------ kasha

func _kasha(delta: float, dir: Vector3, dist: float) -> void:
	var roll := 4.0
	match _state:
		"move":
			_face(dir, delta, 8.0)
			_drift(delta, dir, dist, 2.5, 6.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 9.5:
				if not main.take_token(self):
					_timer = 0.4
					return
				var a := Vector3(position.x, 0, position.z)
				var b := _cut_walkable(a, a + dir * clampf(dist + 2.5, 4.0, KASHA_LEN))
				if a.distance_to(b) < 2.0:
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_lane(PackedVector3Array([a, b]), KASHA_W)
				_state = "windup"
				_timer = KASHA_WINDUP
		"windup":
			# il gratte le sol, les roues s'embrasent
			_face(_strike_dir, delta, 12.0)
			var k := 1.0 - _timer / KASHA_WINDUP
			_update_lane(k)
			ch.play(_walk, 2.6)
			ch.set_glow(_glow_a + 1.0 * k, _glow_c)
			roll = 14.0
			_timer -= delta
			if _timer <= 0.0:
				_start_charge(KASHA_SPEED)
		"charge":
			ch.play(_walk, 3.5)
			roll = 30.0
			_charge(delta)
		"recover":
			# étourdi après la charge : la fenêtre pour le frapper
			roll = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.2, 3.2)
	for w in _wheels:
		var wn: Node3D = w
		wn.rotation.x -= roll * delta


func _update_fire(delta: float) -> void:
	_fire_t -= delta
	var on: bool = hero.dashing
	if on or _hit_cd > 0.0:
		return
	var q := _seg_closest(hero.position, _fire_a, _fire_b)
	if Vector2(q.x - hero.position.x, q.z - hero.position.z).length() < 0.45:
		_hit_cd = 0.8
		_strike(q, 0.3)


# ------------------------------------------------------------------ kagebō

## Mémorise le trait du héros dès qu'il part en ruée.
func _record() -> void:
	var on: bool = hero.dashing
	var sid: int = main.stroke_id
	if on and sid != _rec_id:
		_rec_id = sid
		var p: PackedVector3Array = hero.path
		_rec = p.duplicate()


func _simplify(src: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if src.size() == 0:
		return out
	out.append(src[0])
	for i in range(1, src.size()):
		if src[i].distance_to(out[out.size() - 1]) >= 0.9:
			out.append(src[i])
			if out.size() >= 9:
				break
	var last := src[src.size() - 1]
	if out.size() < 9 and last.distance_to(out[out.size() - 1]) >= 0.3:
		out.append(last)
	return out


## Le dernier trait du héros, reparti d'ici et tourné vers lui (coupé au bord de l'arène).
func _mirror_path(dir: Vector3, dist: float) -> PackedVector3Array:
	var a := Vector3(position.x, 0, position.z)
	var out := PackedVector3Array()
	out.append(a)
	var src := _simplify(_rec)
	if src.size() < 2 or _path_len(src) < 1.5:
		out.append(_cut_walkable(a, a + dir * clampf(dist + 1.5, 3.0, 8.0)))
		return out
	var v := src[src.size() - 1] - src[0]
	v.y = 0.0
	if v.length() < 0.5:
		# trait qui revient sur lui-même (boucle, retour) : on oriente son premier segment
		v = src[1] - src[0]
		v.y = 0.0
	var rot := atan2(dir.x, dir.z) - atan2(v.x, v.z)
	var total := 0.0
	var prev := a
	for i in range(1, src.size()):
		var off := (src[i] - src[0]).rotated(Vector3.UP, rot)
		var p := a + Vector3(off.x, 0, off.z)
		var seg := p - prev
		var sl := seg.length()
		if total + sl > KAGE_MAX:
			p = prev + seg * ((KAGE_MAX - total) / maxf(sl, 0.001))
			out.append(_cut_walkable(prev, p))
			break
		var q := _cut_walkable(prev, p)
		out.append(q)
		total += prev.distance_to(q)
		if q.distance_to(p) > 0.05:
			break  # bord atteint
		prev = q
	return out


func _kagebo(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 8.0)
			_drift(delta, dir, dist, 3.0, 6.0)
			_timer -= delta
			if _timer <= 0.0 and dist < 9.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				var pts := _mirror_path(dir, dist)
				if pts.size() < 2 or _path_len(pts) < 1.5:
					main.free_token(self)
					_timer = 0.6
					return
				_make_lane(pts, KAGE_W)
				_state = "windup"
				_timer = KAGE_WINDUP
				ch.play(ch.idle)
		"windup":
			if _lane.size() >= 2:
				_face(_lane[1] - _lane[0], delta, 10.0)
			var k := 1.0 - _timer / KAGE_WINDUP
			_update_lane(k)
			ch.set_glow(0.9 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				_start_charge(KAGE_SPEED)
				ch.play_once("1H_Melee_Attack_Slice_Horizontal", 2.0)
		"charge":
			_charge(delta)
		"recover":
			# encre qui sèche : immobile, à découvert
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.4, 3.4)


# ------------------------------------------------------------------ tireurs en ligne (kappa archer, arquebusier)

## Ligne de tir droite depuis lui vers `dir` (coupée au bord du sol).
func _beam(dir: Vector3, w: float, length: float) -> void:
	var a := Vector3(position.x, 0, position.z) + dir * 0.5
	var b := _cut_walkable(a, a + dir * length)
	_make_lane(PackedVector3Array([a, b]), w)


## Arquebusier : la ligne pivote vers le héros (longueur gardée).
func _beam_aim(dir: Vector3, delta: float) -> void:
	if _zone == null or _zone.get_child_count() == 0 or _lane.size() < 2:
		return
	var a := _lane[0]
	var cur := _lane[1] - a
	cur.y = 0.0
	var l := cur.length()
	var ang := lerp_angle(atan2(-cur.x, -cur.z), atan2(-dir.x, -dir.z), minf(1.0, delta * 5.0))
	var seg := _zone.get_child(0) as Node3D
	if seg != null:
		seg.rotation.y = ang
	var d := Vector3(-sin(ang), 0, -cos(ang))
	_lane[1] = a + d * l
	_strike_dir = d


func _sniper(delta: float, dir: Vector3, dist: float) -> void:
	var track := kind == "teppo"
	var total := TEPPO_TRACK + TEPPO_HOLD if track else SNIPE_WINDUP
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.5, 7.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 11.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				_beam(dir, SNIPE_W, SNIPE_LEN)
				if _lane.size() < 2 or _path_len(_lane) < 2.5:
					_cancel_attack()
					return
				_strike_dir = dir
				_state = "windup"
				_timer = total
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / total)
		"windup":
			if track and _timer > TEPPO_HOLD:
				_beam_aim(dir, delta)
			_face(_strike_dir, delta, 12.0)
			var k := 1.0 - _timer / total
			_update_lane(k)
			ch.set_glow(_glow_a + 0.9 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				var a := _lane[0]
				var b := _lane[_lane.size() - 1]
				_strike(_lane_closest(hero.position), SNIPE_W * 0.5)
				main.vfx.slash_line(a, b)
				if kind == "ningyo":
					main.vfx.water_burst(b, 0.7)
				_cancel_attack()
				_timer = 1.0  # rechargement : la fenêtre pour le rejoindre
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.4, 3.4)


# ------------------------------------------------------------------ calmar : obus d'encre en cloche

func _mortar(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.0, 7.0)
			_timer -= delta
			if _timer <= 0.0 and dist < 10.0:
				var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), 0.3)
				var hole: bool = main.hazards.is_hole(t, 0.1)
				if hole or not main.take_token(self):
					_timer = 0.4
					return
				_target = t
				_zone_r = MORTAR_R
				_make_zone(true)
				_zone.global_position = _target
				# l'obus vole pendant toute l'annonce (il tombe pile à la fin)
				_proj = Toon.part(_zone, _sph(0.22), _pm(INK_C), Vector3.ZERO)
				_proj.top_level = true
				_proj_from = position + Vector3(0, 1.2, 0)
				_proj.global_position = _proj_from
				_state = "windup"
				_timer = MORTAR_T
				ch.play_once("Throw", ch.length("Throw") / 0.6)
		"windup":
			var k := 1.0 - _timer / MORTAR_T
			main.vfx.tele_update(_tele, k, _timer)
			if is_instance_valid(_proj):
				var p := _proj_from.lerp(_target + Vector3(0, 0.2, 0), k)
				p.y += 3.2 * 4.0 * k * (1.0 - k)
				_proj.global_position = p
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				main.vfx.ink_wave(_target, _zone_r)
				_cancel_attack()
				_timer = 0.6
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.6, 3.6)


# ------------------------------------------------------------------ soutiens : umi-nyōbō (soin), mōryō (bouclier)

func _support(delta: float, dir: Vector3, dist: float) -> void:
	var heal := kind == "umi_nyobo"
	match _state:
		"move":
			_face(dir, delta, 5.0)
			_drift(delta, dir, dist, 4.5, 8.0)
			_timer -= delta
			if _timer <= 0.0:
				if _support_targets(heal) == 0:
					_timer = 0.7
					return
				_state = "windup"
				_timer = SUPPORT_CAST
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / SUPPORT_CAST)
		"windup":
			var k := 1.0 - _timer / SUPPORT_CAST
			ch.set_glow(_glow_a + 1.4 * k, HEAL_C if heal else SHIELD_C)
			_timer -= delta
			if _timer <= 0.0:
				_support_cast(heal)
				_base_glow()
				_state = "recover"
				_timer = 0.8
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(3.0, 3.8)


func _ally_ok(e, heal: bool) -> bool:
	if not is_instance_valid(e) or e == self or e.dead or e.dummy:
		return false
	var p: Vector3 = e.position
	if Vector2(p.x - position.x, p.z - position.z).length() > SUPPORT_R:
		return false
	if heal:
		return float(e.hp) < float(e.get_meta("max_hp", 1.0)) - 0.01
	return float(e.shield) <= 0.0 and String(e.kind) != "moryo" and String(e.kind) != "tanuki_d"


func _support_targets(heal: bool) -> int:
	var n := 0
	for e in main.enemies:
		if _ally_ok(e, heal):
			n += 1
	return n


func _support_cast(heal: bool) -> void:
	var col := HEAL_C if heal else SHIELD_C
	main.vfx.ring(Vector3(position.x, 0.08, position.z), col, SUPPORT_R)
	main.sfx.play("shrine", 1.5, -8.0)
	for e in main.enemies:
		if not _ally_ok(e, heal):
			continue
		if heal:
			e.heal_pct(0.3)
		else:
			e.give_shield(float(e.get_meta("max_hp", 1.0)) * 0.4)
		var p: Vector3 = e.position
		main.vfx.sparks(p + Vector3(0, 1.0, 0), Vector3.UP, 5, col)


# ------------------------------------------------------------------ belette (zigzag au sol), boule de feu (piqué)

func _swoop_path(dir: Vector3, dist: float, fly: bool) -> PackedVector3Array:
	var a := Vector3(position.x, 0, position.z)
	var out := PackedVector3Array([a])
	var b := _cut_walkable(a, a + dir * clampf(dist + 1.5, 3.0, 8.0))
	out.append(b)
	if not fly:
		# zigzag : la deuxième taille repart en biais
		var side := 1.0 if randf() < 0.5 else -1.0
		var d2 := dir.rotated(Vector3.UP, 0.9 * side)
		var c := _cut_walkable(b, b + d2 * 3.0)
		if c.distance_to(b) > 1.0:
			out.append(c)
	return out


func _swooper(delta: float, dir: Vector3, dist: float) -> void:
	var fly := kind == "hinotama" or kind == "karasu"
	var total := SWOOP_T if fly else WEASEL_T
	if fly:
		# vole haut, pique en rase-mottes, se pose un instant après
		var want := 1.4
		if _state == "charge":
			want = 0.5
		elif _state == "recover":
			want = 0.35
		body.position.y = lerpf(body.position.y, want + 0.1 * sin(_t * 3.0), minf(1.0, delta * 4.0))
	match _state:
		"move":
			_face(dir, delta, 8.0)
			_drift(delta, dir, dist, 3.0 if fly else 2.5, 5.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 9.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				var pts := _swoop_path(dir, dist, fly)
				if pts.size() < 2 or _path_len(pts) < 2.0:
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_lane(pts, 1.0 if fly else 0.9)
				_state = "windup"
				_timer = total
		"windup":
			if _lane.size() >= 2:
				_face(_lane[1] - _lane[0], delta, 12.0)
			var k := 1.0 - _timer / total
			_update_lane(k)
			ch.play(_walk, 2.4)
			ch.set_glow(1.0 * k, Toon.GOLD)
			_timer -= delta
			if _timer <= 0.0:
				_start_charge(11.0 if fly else 13.0)
				ch.play_once("1H_Melee_Attack_Slice_Horizontal", 2.0)
		"charge":
			_charge(delta)
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(1.8, 2.6)


# ------------------------------------------------------------------ tanuki : tambour du ventre, leurre

func _tanuki(delta: float, dir: Vector3, dist: float) -> void:
	var decoy := kind == "tanuki_d"
	if decoy:
		_life -= delta
		if _life <= 0.0:
			# le leurre se dissipe tout seul
			_selfkill = true
			_die()
			return
	else:
		_doron_cd -= delta
	match _state:
		"move":
			if dist > 1.6:
				_walk_to_hero(delta, speed)
			else:
				_face(dir, delta, 8.0)
				ch.play(ch.idle)
			if not decoy and dist < 2.2:
				if not main.take_token(self):
					return
				_target = Vector3(position.x, 0, position.z)
				_zone_r = DRUM_R
				_make_zone(true)
				_zone.global_position = _target
				_state = "windup"
				_timer = DRUM_T
		"windup":
			_face(dir, delta, 6.0)
			var k := 1.0 - _timer / DRUM_T
			main.vfx.tele_update(_tele, k, _timer)
			if _belly != null:
				# il se tape le ventre, de plus en plus vite
				var b := 1.0 + 0.12 * absf(sin(_t * (8.0 + 14.0 * k)))
				_belly.scale = Vector3(b, b, 0.7 * b)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				main.vfx.ring(Vector3(_target.x, 0.08, _target.z), Toon.GOLD, _zone_r)
				if _belly != null:
					_belly.scale = Vector3(1, 1, 0.7)
				_cancel_attack()
				_timer = 1.3
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"


## « Doron » : un leurre prend sa place, le vrai tanuki file un peu plus loin.
func _doron() -> void:
	if dead or not is_instance_valid(main) or not is_inside_tree():
		return
	if _state == "windup":
		_cancel_attack()
	var here := Vector3(position.x, 0, position.z)
	_puff(here, Toon.WASHI)
	var sc = get_script()
	var e = sc.new()
	e.setup("tanuki_d", hero, main)
	e.minion = true
	e.position = here
	main.add_child(e)
	e.set_meta("max_hp", e.hp)
	main.enemies.append(e)
	for attempt in 10:
		var a := randf() * TAU
		var p: Vector3 = main.arena.clamp_walk(here + Vector3(cos(a), 0, sin(a)) * 3.5, radius)
		var hole: bool = main.hazards.is_hole(p, 0.1)
		if not hole and p.distance_to(hero.position) > 2.5:
			position = Vector3(p.x, position.y, p.z)
			break
	_puff(position, Toon.WASHI)
	main.float_text(position, "DORON", Toon.GOLD)


# ------------------------------------------------------------------ montreur de renards : invocations

func _summoner(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.5, 7.5)
			_timer -= delta
			if _timer <= 0.0:
				if _alive_summons() >= 2 or _summon_total >= 6:
					_timer = 1.0
					return
				_state = "windup"
				_timer = SUMMON_CAST
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / SUMMON_CAST)
		"windup":
			var k := 1.0 - _timer / SUMMON_CAST
			ch.set_glow(_glow_a + 1.4 * k, FOX_FIRE)
			_timer -= delta
			if _timer <= 0.0:
				_summon_total += 2
				call_deferred("_summon", "kitsunebi_s", 2, _minion_hp(0.5))
				main.vfx.ring(Vector3(position.x, 0.08, position.z), FOX_FIRE, 1.4)
				_base_glow()
				_state = "recover"
				_timer = 0.8
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(4.0, 5.0)


# ------------------------------------------------------------------ enfant des neiges (explose), goutte d'encre (flaque)

func _bomber(delta: float, dir: Vector3, dist: float) -> void:
	var kami := kind == "yuki_warashi"
	var total := KAMI_T if kami else 0.9
	match _state:
		"move":
			var reach := 1.5 if kami else 1.4
			if dist > reach:
				var spd := speed
				if not kami:
					# la goutte avance par petits bonds mous
					spd *= 0.6 + 0.8 * absf(sin(_t * 4.0))
					var w := 0.1 * sin(_t * 8.0)
					body.scale = Vector3(1.0 - w * 0.5, 1.0 + w, 1.0 - w * 0.5)
				_walk_to_hero(delta, spd)
			else:
				_face(dir, delta, 8.0)
				ch.play(ch.idle)
			if dist <= reach + 0.3:
				if not main.take_token(self):
					var around := Vector3(-dir.z, 0, dir.x) * (1.0 if get_instance_id() % 2 == 0 else -1.0)
					position += around * 1.0 * delta
					return
				_target = Vector3(position.x, 0, position.z)
				_zone_r = KAMI_R if kami else (1.25 if kind == "sumidama" else 0.95)
				_make_zone(true)
				_zone.global_position = _target
				_state = "windup"
				_timer = total
		"windup":
			var k := 1.0 - _timer / total
			main.vfx.tele_update(_tele, k, _timer)
			if kami:
				# il gonfle et blanchit avant d'éclater
				body.scale = Vector3.ONE * (1.0 + 0.35 * k)
				ch.set_glow(_glow_a + 1.6 * k, ICE_C)
			else:
				body.scale = Vector3(1.0 + 0.3 * k, 1.0 - 0.25 * k, 1.0 + 0.3 * k)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				if kami:
					main.vfx.ring(Vector3(_target.x, 0.08, _target.z), ICE_C, _zone_r)
					main.vfx.sparks(_target + Vector3(0, 0.6, 0), Vector3.UP, 12, ICE_C)
					main.splash(_target + Vector3(0, 0.5, 0), Color.WHITE, 14)
					_cancel_attack()
					_selfkill = true
					_die()
					return
				main.vfx.ink_wave(_target, _zone_r)
				_puddle(_target, 2.2 if kind == "sumidama" else 1.4)
				_cancel_attack()
				_timer = 1.1
		"recover":
			if not _custom:
				body.scale = body.scale.lerp(Vector3.ONE, minf(1.0, delta * 8.0))
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"


## Flaque d'encre ronde : freine la ruée qui la traverse (même mécanique que le givre).
func _puddle(c: Vector3, w: float) -> void:
	_clear_ice()
	_ice_pts = PackedVector3Array([c, c])
	_ice_w = w
	_ice_word = "ENCRE"
	_ice_col = Color("#8E7FA8")
	_ice_t = ICE_TIME
	_ice = Node3D.new()
	_ice.top_level = true
	add_child(_ice)
	_ice_mat = Toon.flat(Color(INK_C, 0.55))
	var mi := Toon.part(_ice, _cyl(1.0, 1.0, 0.01, 20), _ice_mat, Vector3(c.x, 0.05, c.z), Vector3(w * 0.5, 1, w * 0.5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mort de la grosse goutte : deux petites s'en échappent.
func _split_blob() -> void:
	if not is_instance_valid(main) or not is_inside_tree():
		return
	_summon("sumidama_s", 2, _minion_hp(0.55))
	main.vfx.ink_wave(Vector3(position.x, 0, position.z), 1.0)


# ------------------------------------------------------------------ stalactite : tourelle fixe

func _turret(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_timer -= delta
			if _timer <= 0.0 and dist < 11.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				if dist < 2.6:
					# héros collé : couronne de pics autour d'elle
					_lane = PackedVector3Array()
					_target = Vector3(position.x, 0, position.z)
					_zone_r = 1.8
					_make_zone(true)
					_zone.global_position = _target
				else:
					_beam(dir, ICICLE_W, ICICLE_LEN)
					if _lane.size() < 2 or _path_len(_lane) < 2.0:
						_cancel_attack()
						return
				_state = "windup"
				_timer = ICICLE_T
		"windup":
			var k := 1.0 - _timer / ICICLE_T
			if _lane.size() >= 2:
				_update_lane(k)
			else:
				main.vfx.tele_update(_tele, k, _timer)
			# la glace frémit avant de tirer
			body.scale = Vector3.ONE * (1.0 + 0.05 * sin(_t * 40.0) * k)
			_timer -= delta
			if _timer <= 0.0:
				if _lane.size() >= 2:
					var a := _lane[0]
					var b := _lane[_lane.size() - 1]
					_strike(_lane_closest(hero.position), ICICLE_W * 0.5)
					for i in 4:
						main.vfx.sparks(a.lerp(b, (float(i) + 0.5) / 4.0) + Vector3(0, 0.3, 0), Vector3.UP, 4, ICE_C)
				else:
					_strike(_target, _zone_r)
					main.vfx.ring(Vector3(_target.x, 0.08, _target.z), ICE_C, _zone_r)
					main.vfx.sparks(_target + Vector3(0, 0.4, 0), Vector3.UP, 10, ICE_C)
				_cancel_attack()
				_timer = 0.8
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.6, 3.4)


# ------------------------------------------------------------------ onryō : surgit dans le dos

func _onryo(delta: float, dir: Vector3, dist: float) -> void:
	body.position.y = lerpf(body.position.y, 0.2 + 0.08 * sin(_t * 2.5), minf(1.0, delta * 4.0))
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 2.5, 5.0)
			_timer -= delta
			if _timer <= 0.0 and dist < 10.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				_state = "fade"
				_timer = ONRYO_FADE
				_puff(position, Color("#B9A8E8"))
		"fade":
			_knock = Vector3.ZERO
			_timer -= delta
			body.scale = Vector3(1.0, maxf(_timer / ONRYO_FADE, 0.05), 1.0)
			if _timer <= 0.0:
				body.visible = false
				_shadow.visible = false
				_state = "gone"
				_timer = ONRYO_GONE
		"gone":
			_knock = Vector3.ZERO
			_timer -= delta
			if _timer <= 0.0:
				# dans le dos du héros (ou sur son flanc si le dos est un trou)
				var f: Vector3 = hero.facing
				f.y = 0.0
				if f.length_squared() < 0.01:
					f = Vector3(0, 0, -1)
				f = f.normalized()
				var hp0 := Vector3(hero.position.x, 0, hero.position.z)
				var p: Vector3 = main.arena.clamp_walk(hp0 - f * 1.4, radius)
				var hole: bool = main.hazards.is_hole(p, 0.1)
				if hole:
					p = main.arena.clamp_walk(hp0 + Vector3(f.z, 0, -f.x) * 1.4, radius)
				position = Vector3(p.x, position.y, p.z)
				body.visible = true
				_shadow.visible = true
				body.scale = Vector3.ONE
				_face_hero_now()
				_puff(position, Color("#B9A8E8"))
				_target = hp0.lerp(Vector3(p.x, 0, p.z), 0.35)
				_zone_r = 1.15
				_make_zone(true)
				_zone.global_position = _target
				_state = "windup"
				_timer = ONRYO_T
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / ONRYO_T)
		"windup":
			var k := 1.0 - _timer / ONRYO_T
			main.vfx.tele_update(_tele, k, _timer)
			ch.set_glow(_glow_a + 1.2 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				_cancel_attack()
				_timer = 1.4
		"recover":
			body.visible = true
			_shadow.visible = true
			body.scale = body.scale.lerp(Vector3.ONE, minf(1.0, delta * 10.0))
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.2, 3.2)


# ------------------------------------------------------------------ tengu : chausse-trapes

func _trapper(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 3.5, 6.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 9.5 and _trap_t <= 0.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				# trois poignées de makibishi autour du héros, chacune annoncée
				_traps = PackedVector3Array()
				_zone = Node3D.new()
				_zone.top_level = true
				add_child(_zone)
				_tele = null
				_teles = []
				var c := Vector3(hero.position.x, 0, hero.position.z)
				var a0 := randf() * TAU
				for i in 3:
					var off := Vector3.ZERO
					if i > 0:
						var a := a0 + PI * float(i)
						off = Vector3(cos(a), 0, sin(a)) * 1.5
					var p: Vector3 = main.arena.clamp_walk(c + off, 0.3)
					var hole: bool = main.hazards.is_hole(p, 0.1)
					if hole:
						continue
					_traps.append(p)
					var holder := Node3D.new()
					_zone.add_child(holder)
					holder.position = p
					_teles.append(main.vfx.tele_disc(holder, TRAP_R))
				if _traps.is_empty():
					_cancel_attack()
					return
				_state = "windup"
				_timer = TRAP_T
				ch.play_once("Throw", ch.length("Throw") * 0.5 / TRAP_T)
		"windup":
			_face(dir, delta, 8.0)
			var k := 1.0 - _timer / TRAP_T
			for tl in _teles:
				main.vfx.tele_update(tl, k, _timer)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_closest_pt(_traps, hero.position), TRAP_R)
				for p in _traps:
					main.vfx.ring(Vector3(p.x, 0.08, p.z), Toon.SUMI, TRAP_R)
				_lay_traps()
				_cancel_attack()
				_timer = 0.7
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(3.2, 4.2)


## Les pointes restent au sol : finir son trait dessus fait mal (la ruée passe sans danger).
func _lay_traps() -> void:
	if _trap_node != null:
		_trap_node.queue_free()
	_trap_t = TRAP_LIFE
	_trap_node = Node3D.new()
	_trap_node.top_level = true
	add_child(_trap_node)
	var spike := _cyl(0.0, 0.07, 0.16, 4)
	var iron := _pm(Color("#2A2830"))
	for p in _traps:
		var d := Toon.part(_trap_node, _cyl(TRAP_R, TRAP_R, 0.004, 20), _fm(Color(Toon.SUMI, 0.22)), Vector3(p.x, 0.02, p.z))
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for j in 5:
			var a := TAU * float(j) / 5.0 + randf() * 0.5
			var r := randf_range(0.12, TRAP_R * 0.75)
			var s := Toon.part(_trap_node, spike, iron, Vector3(p.x + cos(a) * r, 0.08, p.z + sin(a) * r))
			s.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_traps(delta: float) -> void:
	_trap_t -= delta
	if _trap_t <= 0.0:
		_clear_traps()
		return
	var on: bool = hero.dashing
	if on or _hit_cd > 0.0:
		return
	for p in _traps:
		if Vector2(p.x - hero.position.x, p.z - hero.position.z).length() < TRAP_R * 0.85:
			_hit_cd = 0.8
			main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.3)
			break


func _clear_traps() -> void:
	_trap_t = 0.0
	_traps = PackedVector3Array()
	if _trap_node != null:
		_trap_node.queue_free()
		_trap_node = null


# ------------------------------------------------------------------ kasa-obake : bonds

func _hopper(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			# au sol : il sautille sur place
			body.position.y = absf(sin(_t * 6.0)) * 0.08
			_face(dir, delta, 6.0)
			_timer -= delta
			if _timer <= 0.0:
				var big: bool = dist < 7.0 and main.take_token(self)
				var t := Vector3(hero.position.x, 0, hero.position.z)
				if not big:
					# petit bond sans attaque, vers le héros ou de biais
					t = Vector3(position.x, 0, position.z) + dir.rotated(Vector3.UP, randf_range(-0.8, 0.8)) * 2.0
				t = main.arena.clamp_walk(t, radius)
				var hole: bool = main.hazards.is_hole(t, 0.1)
				if hole:
					if big:
						main.free_token(self)
					_timer = 0.3
					return
				_hop_from = Vector3(position.x, 0, position.z)
				_target = t
				_air = true
				if big:
					_zone_r = HOP_R
					_make_zone(true)
					_zone.global_position = _target
					_state = "windup"
					_hop_len = HOP_T
				else:
					_state = "hop"
					_hop_len = 0.5
				_timer = _hop_len
		"windup", "hop":
			var k := clampf(1.0 - _timer / _hop_len, 0.0, 1.0)
			if _state == "windup":
				main.vfx.tele_update(_tele, k, _timer)
			var p := _hop_from.lerp(_target, k)
			position = Vector3(p.x, position.y, p.z)
			body.position.y = (2.2 if _state == "windup" else 0.9) * 4.0 * k * (1.0 - k)
			body.rotation.y += delta * 9.0
			_knock = Vector3.ZERO
			_timer -= delta
			if _timer <= 0.0:
				_air = false
				body.position.y = 0.0
				position = Vector3(_target.x, position.y, _target.z)
				if _state == "windup":
					_strike(_target, _zone_r)
					main.vfx.ring(Vector3(_target.x, 0.08, _target.z), Toon.SUMI, _zone_r)
					main.splash(_target + Vector3(0, 0.3, 0), Toon.WASHI, 8)
					_cancel_attack()
					_timer = HOP_GROUND
				else:
					_state = "move"
					_timer = randf_range(0.6, 0.9)
		"recover":
			# posé : la fenêtre pour le trancher
			_air = false
			body.position.y = lerpf(body.position.y, 0.0, minf(1.0, delta * 10.0))
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(0.5, 0.8)


# ------------------------------------------------------------------ mondes 6 à 8

## Karasu : battement des ailes (plus serré pendant le piqué).
func _flap() -> void:
	var rate := 16.0 if _state == "charge" else 9.0
	var amp := 0.25 if _state == "charge" else 0.55
	for i in _wings.size():
		var w: Node3D = _wings[i]
		var sx := -1.0 if i % 2 == 0 else 1.0
		w.rotation.z = sx * sin(_t * rate) * amp


## Yamabushi-tengu : rafale de l'éventail dans un cône annoncé devant lui.
func _gust(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 3.0, 5.5)
			_timer -= delta
			if _timer <= 0.0 and dist < GUST_LEN + 0.5:
				if not main.take_token(self):
					_timer = 0.4
					return
				_strike_dir = dir
				_target = Vector3(position.x, 0, position.z)
				_zone = Node3D.new()
				_zone.top_level = true
				add_child(_zone)
				_zone.global_position = _target
				_zone.rotation.y = atan2(dir.x, dir.z)
				_tele = main.vfx.tele_fan(_zone, GUST_HALF, GUST_LEN)
				_state = "windup"
				_timer = GUST_T
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / GUST_T)
			elif _timer <= 0.0:
				_timer = 0.5
		"windup":
			_face(_strike_dir, delta, 8.0)
			var k := 1.0 - _timer / GUST_T
			main.vfx.tele_update(_tele, k, _timer)
			ch.set_glow(_glow_a + 0.9 * k, Toon.GOLD)
			_timer -= delta
			if _timer <= 0.0:
				if _in_gust(hero.position):
					_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
				main.vfx.wind_slash(_target + _strike_dir * 1.5, _strike_dir, 1.4)
				main.vfx.wind_slash(_target + _strike_dir * 3.5, _strike_dir, 1.1)
				_cancel_attack()
				_timer = 1.2
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.4, 3.2)


## Vrai si p est dans le cône de la rafale (sommet _target, axe _strike_dir).
func _in_gust(p: Vector3) -> bool:
	var v := Vector3(p.x - _target.x, 0, p.z - _target.z)
	var l := v.length()
	if l < 0.3:
		return true
	if l > GUST_LEN:
		return false
	return v.dot(_strike_dir) / l > cos(GUST_HALF)


## Konoha-tengu : trois feuilles lancées en éventail après une courte lueur.
func _leaves(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.0, 6.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 10.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				_strike_dir = dir
				_state = "windup"
				_timer = LEAF_T
				ch.play_once("Throw", ch.length("Throw") * 0.5 / LEAF_T)
		"windup":
			_face(dir, delta, 8.0)
			var k := 1.0 - _timer / LEAF_T
			ch.set_glow(_glow_a + 0.8 * k, Color("#9FD86A"))
			_timer -= delta
			if _timer <= 0.0:
				for i in 3:
					var d := dir.rotated(Vector3.UP, deg_to_rad(-20.0 + 20.0 * float(i)))
					main.spawn_bullet(position + Vector3(0, 1.0, 0) + d * 0.5, d)
				main.free_token(self)
				_base_glow()
				_state = "recover"
				_timer = 0.6
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.6, 3.4)


## Fugu : il approche, gonfle (disque annoncé autour de lui), frappe et projette six épines.
func _puffer(delta: float, dir: Vector3, dist: float) -> void:
	body.position.y = lerpf(body.position.y, 0.3 + 0.1 * sin(_t * 2.6), minf(1.0, delta * 4.0))
	match _state:
		"move":
			if dist > 2.0:
				_walk_to_hero(delta, speed)
			else:
				_face(dir, delta, 6.0)
			_timer -= delta
			if _timer <= 0.0 and dist < 2.8:
				if not main.take_token(self):
					_timer = 0.4
					return
				_target = Vector3(position.x, 0, position.z)
				_zone_r = PUFF_R
				_make_zone(true)
				_zone.global_position = _target
				_state = "windup"
				_timer = PUFF_T
		"windup":
			var k := 1.0 - _timer / PUFF_T
			main.vfx.tele_update(_tele, k, _timer)
			body.scale = Vector3.ONE * (1.0 + 0.55 * k)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				for i in 6:
					var a := TAU * float(i) / 6.0 + _t
					var d := Vector3(cos(a), 0, sin(a))
					main.spawn_bullet(position + Vector3(0, 0.6, 0) + d * 0.7, d)
				main.vfx.water_burst(_target, _zone_r)
				_cancel_attack()
				_timer = 1.6
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(1.6, 2.4)


## Gokusotsu : il marche sur le héros puis fouette sa chaîne dans un couloir annoncé.
func _jailer(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			if dist > 3.0:
				_walk_to_hero(delta, speed)
			else:
				_face(dir, delta, 4.0)
				ch.play(ch.idle)
			_timer -= delta
			if _timer <= 0.0 and dist < 6.5:
				if not main.take_token(self):
					_timer = 0.4
					return
				var a := Vector3(position.x, 0, position.z) + dir * 0.5
				var b := _cut_walkable(a, a + dir * clampf(dist + 1.5, 3.0, 6.5))
				if a.distance_to(b) < 1.5:
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_lane(PackedVector3Array([a, b]), CHAIN_W)
				_state = "windup"
				_timer = CHAIN_T
				ch.play_once("2H_Melee_Attack_Chop", ch.length("2H_Melee_Attack_Chop") * 0.5 / CHAIN_T)
		"windup":
			_face(_strike_dir, delta, 8.0)
			var k := 1.0 - _timer / CHAIN_T
			_update_lane(k)
			ch.set_glow(_glow_a + 0.8 * k, Color("#9AB8FF"))
			_timer -= delta
			if _timer <= 0.0:
				var la := _lane[0]
				var lb := _lane[_lane.size() - 1]
				_strike(_lane_closest(hero.position), CHAIN_W * 0.5)
				main.vfx.slash_line(la, lb)
				for i in 4:
					main.vfx.sparks(la.lerp(lb, (float(i) + 0.5) / 4.0) + Vector3(0, 0.3, 0), Vector3.UP, 3, Color("#9AB8FF"))
				_cancel_attack()
				_timer = 1.3
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.0, 2.8)


## Shiryō : il flotte à distance et annonce un cercle de feu froid sous le héros.
func _wisp(delta: float, dir: Vector3, dist: float) -> void:
	body.position.y = lerpf(body.position.y, 0.9 + 0.15 * sin(_t * 2.2), minf(1.0, delta * 4.0))
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 3.5, 6.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 10.0:
				var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), 0.3)
				var hole: bool = main.hazards.is_hole(t, 0.1)
				if hole or not main.take_token(self):
					_timer = 0.4
					return
				_target = t
				_zone_r = WISP_R
				_make_zone(true)
				_zone.global_position = _target
				_state = "windup"
				_timer = WISP_T
		"windup":
			var k := 1.0 - _timer / WISP_T
			main.vfx.tele_update(_tele, k, _timer)
			body.scale = Vector3.ONE * (1.0 + 0.3 * k)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				main.vfx.ring(Vector3(_target.x, 0.08, _target.z), YOMI_C, _zone_r)
				main.vfx.sparks(_target + Vector3(0, 0.4, 0), Vector3.UP, 10, YOMI_C)
				_cancel_attack()
				_timer = 0.9
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.4, 3.2)


# ------------------------------------------------------------------ clan des ninjas (忍)

## Bouffée de fumée d'un clignement de ninja.
func _ninja_puff(p: Vector3) -> void:
	main.vfx.smoke(Vector3(p.x, 0, p.z), 0.35, 5)
	main.vfx.ring(Vector3(p.x, 0.08, p.z), SMOKE_C, 0.6)


## Zone d'attaque portée par l'ennemi : compense l'échelle de l'élite (annonce = vraie zone de frappe).
func _fit_zone() -> void:
	if _zone == null:
		return
	var s := maxf(scale.x, 0.01)
	_zone.scale = Vector3.ONE / s
	_zone.position = _strike_dir * (_zone_r * 0.9) / s


## Shinobi : il fonce sur le héros, puis cligne sur son flanc (fumée aux deux bouts) et taille aussitôt.
func _shinobi(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			if dist > 1.6:
				_walk_to_hero(delta, speed)
				ch.play(_walk, 1.5)
			else:
				_face(dir, delta, 10.0)
				ch.play(ch.idle)
			_timer -= delta
			if _timer <= 0.0 and dist < SHINOBI_RANGE:
				if not main.take_token(self):
					_timer = 0.4
					return
				if not _blink_strike(dir):
					main.free_token(self)
					_timer = 0.6
		"windup":
			var k := 1.0 - _timer / _windup
			_face(_strike_dir, delta, 14.0)
			_fit_zone()
			main.vfx.tele_update(_tele, k, _timer)
			ch.set_glow(0.9 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				var center := position + _strike_dir * (_zone_r * 0.9)
				center.y = 0.0
				_strike(center, _zone_r)
				main.vfx.wind_slash(center, _strike_dir, 0.9)
				_cancel_attack()
				_combo += 1
				# la fenêtre pour le trancher (le maître enchaîne une seconde taille)
				_timer = 0.45 if _master and _combo < 2 else SHINOBI_REST
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				if _master and _combo < 2 and dist < SHINOBI_RANGE and main.take_token(self):
					if _blink_strike(dir):
						return
					main.free_token(self)
				_combo = 0
				_state = "move"
				_timer = randf_range(1.4, 2.2)


## Clignement sur le flanc du héros (ou en biais devant lui), puis annonce de la taille. Faux si aucun point sûr.
func _blink_strike(dir: Vector3) -> bool:
	var hp0 := Vector3(hero.position.x, 0, hero.position.z)
	var side := Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
	var picks := [side, -side, (side - dir).normalized(), (-side - dir).normalized()]
	var dest := Vector3.INF
	for v in picks:
		var vv: Vector3 = v
		var p: Vector3 = main.arena.clamp_walk(hp0 + vv * SHINOBI_GAP, radius)
		var hole: bool = main.hazards.is_hole(p, 0.1)
		if hole or Vector2(p.x - hp0.x, p.z - hp0.z).length() < 1.0:
			continue
		dest = p
		break
	if dest == Vector3.INF:
		return false
	_ninja_puff(position)
	position = Vector3(dest.x, position.y, dest.z)
	_ninja_puff(position)
	var to := hp0 - Vector3(position.x, 0, position.z)
	_strike_dir = to.normalized() if to.length_squared() > 0.0001 else dir
	body.rotation.y = atan2(-_strike_dir.x, -_strike_dir.z)
	_knock = Vector3.ZERO
	_zone_r = SHINOBI_R
	_make_zone()
	_fit_zone()
	_state = "windup"
	_timer = _windup
	ch.play_once("1H_Melee_Attack_Slice_Horizontal", ch.length("1H_Melee_Attack_Slice_Horizontal") * 0.5 / _windup)
	return true


## Lanceur de shuriken : à distance, il annonce un éventail de lignes de visée ; les étoiles volent à la fin.
func _shuriken_ai(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.5, 7.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 10.5:
				if not main.take_token(self):
					_timer = 0.4
					return
				var n := 5 if _master else 3
				var lanes: Array = []
				var a0 := Vector3(position.x, 0, position.z)
				for i in n:
					var d := dir.rotated(Vector3.UP, SHURI_SPREAD * (float(i) - float(n - 1) * 0.5))
					var s := a0 + d * 0.5
					var e := _cut_walkable(s, s + d * SHURI_LEN)
					if s.distance_to(e) >= 1.5:
						lanes.append(PackedVector3Array([s, e]))
				if lanes.is_empty():
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_fan(lanes, SHURI_W)
				_state = "windup"
				_timer = SHURI_T
				ch.play_once("Throw", ch.length("Throw") * 0.5 / SHURI_T)
		"windup":
			_face(_strike_dir, delta, 10.0)
			var k := 1.0 - _timer / SHURI_T
			_update_lane(k)
			ch.set_glow(0.8 * k, Toon.VERMILION)
			if _stars.is_empty() and _timer <= SHURI_FLY:
				_throw_stars()
			_update_stars(delta)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_fan_closest(hero.position), SHURI_W * 0.5)
				for l in _fan:
					var pts: PackedVector3Array = l
					main.vfx.sparks(pts[1] + Vector3(0, 0.4, 0), Vector3.UP, 3, Toon.WASHI)
				_cancel_attack()
				_timer = 1.0  # il recharge : la fenêtre pour le rejoindre
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.4, 3.2)


## Annonce en éventail : une ligne fine par shuriken (même rendu que les couloirs).
func _make_fan(lanes: Array, w: float) -> void:
	_fan = lanes
	_lane_w = w
	_zone = Node3D.new()
	_zone.top_level = true
	add_child(_zone)
	_tele = null
	_teles = []
	for l in lanes:
		var pts: PackedVector3Array = l
		var a := pts[0]
		var d := pts[1] - a
		d.y = 0.0
		var ln := maxf(d.length(), 0.1)
		var seg := Node3D.new()
		_zone.add_child(seg)
		seg.position = Vector3(a.x, 0, a.z)
		seg.rotation.y = atan2(-d.x, -d.z)
		var tl: Node3D = main.vfx.tele_rect(seg, w * 0.5, ln * 0.5, Vector2(0, 1))
		tl.position.z = -ln * 0.5
		_teles.append(tl)


func _fan_closest(p: Vector3) -> Vector3:
	var best := Vector3(position.x, 0, position.z)
	var bd := INF
	for l in _fan:
		var pts: PackedVector3Array = l
		var q := _seg_closest(p, pts[0], pts[1])
		var dd := Vector2(q.x - p.x, q.z - p.z).length()
		if dd < bd:
			bd = dd
			best = q
	return best


## Les étoiles partent : elles filent le long des lignes et arrivent pile à la fin de l'annonce.
func _throw_stars() -> void:
	_clear_stars()
	for l in _fan:
		var pts: PackedVector3Array = l
		var mi := MeshInstance3D.new()
		mi.mesh = Yokai.shuriken_mesh()
		mi.material_override = Yokai.mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		mi.global_position = pts[0] + Vector3(0, 0.9, 0)
		_stars.append([mi, pts[0], pts[1]])
	main.sfx.play("shot", 1.5, -8.0)


func _update_stars(delta: float) -> void:
	var k := clampf(1.0 - _timer / SHURI_FLY, 0.0, 1.0)
	for st in _stars:
		var it: Array = st
		if not is_instance_valid(it[0]):
			continue
		var n: Node3D = it[0]
		var a: Vector3 = it[1]
		var b: Vector3 = it[2]
		n.global_position = a.lerp(b, k) + Vector3(0, 0.9, 0)
		n.rotation.y += delta * 30.0


func _clear_stars() -> void:
	for st in _stars:
		var it: Array = st
		if is_instance_valid(it[0]):
			it[0].queue_free()
	_stars = []


## Kemuri : bombe de fumée, il s'y fond (presque invisible), puis ressurgit dans le dos du héros, contour rouge.
func _kemuri(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 3.0, 6.0)
			_timer -= delta
			if _timer <= 0.0 and dist < 10.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				_state = "bomb"
				_timer = 0.35
				ch.play_once("Throw", ch.length("Throw") * 0.5 / 0.35)
				ch.set_glow(0.6, SMOKE_C)
		"bomb":
			_timer -= delta
			if _timer <= 0.0:
				_base_glow()
				_smoke_cloud(Vector3(position.x, 0, position.z))
				body.visible = false
				_shadow.visible = false
				_state = "gone"
				_timer = KEMURI_GONE * (0.7 if _master else 1.0)
		"gone":
			_knock = Vector3.ZERO
			_timer -= delta
			# presque invisible : on l'entrevoit par éclats
			body.visible = fmod(_t, 0.3) < 0.04
			if _timer <= 0.0:
				var f: Vector3 = hero.facing
				f.y = 0.0
				if f.length_squared() < 0.01:
					f = Vector3(0, 0, -1)
				f = f.normalized()
				var hp0 := Vector3(hero.position.x, 0, hero.position.z)
				var p: Vector3 = main.arena.clamp_walk(hp0 - f * 1.5, radius)
				var hole: bool = main.hazards.is_hole(p, 0.1)
				if hole:
					p = main.arena.clamp_walk(hp0 + Vector3(f.z, 0, -f.x) * 1.5, radius)
				position = Vector3(p.x, position.y, p.z)
				body.visible = true
				_shadow.visible = true
				_face_hero_now()
				_ninja_puff(position)
				_target = hp0.lerp(Vector3(p.x, 0, p.z), 0.35)
				_zone_r = KEMURI_R
				_make_zone(true)
				_zone.global_position = _target
				_state = "windup"
				_timer = KEMURI_T
				ch.play_once("1H_Melee_Attack_Stab", ch.length("1H_Melee_Attack_Stab") * 0.5 / KEMURI_T)
		"windup":
			var k := 1.0 - _timer / KEMURI_T
			main.vfx.tele_update(_tele, k, _timer)
			# contour rouge : il s'allume de plus en plus
			ch.set_glow(0.5 + 1.3 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				_strike(_target, _zone_r)
				main.vfx.smoke(_target, 0.4, 4)
				_cancel_attack()
				_timer = 1.4
		"recover":
			body.visible = true
			_shadow.visible = true
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.6, 3.4)


## Nuage de fumée laissé au sol (visuel) : il gonfle puis se dissipe.
func _smoke_cloud(c: Vector3) -> void:
	_clear_cloud()
	_cloud = Node3D.new()
	_cloud.top_level = true
	add_child(_cloud)
	_cloud.global_position = c
	var m := _fm(Color(SMOKE_C, 0.55))
	var n := 3 if Toon.lite else 5
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 0.0 if i == 0 else 0.55
		var mi := Toon.part(_cloud, _sph(0.5), m, Vector3(cos(a) * r, 0.45 + 0.15 * float(i % 2), sin(a) * r), Vector3.ONE * (1.2 if i == 0 else 0.85))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud_t = CLOUD_LIFE
	main.vfx.smoke(c, 0.8, 10)
	main.vfx.ring(Vector3(c.x, 0.08, c.z), SMOKE_C, 1.2)
	main.sfx.play("shot", 0.6, -6.0)


func _update_cloud(delta: float) -> void:
	_cloud_t -= delta
	if _cloud == null or _cloud_t <= 0.0:
		_clear_cloud()
		return
	var k := clampf(_cloud_t / CLOUD_LIFE, 0.0, 1.0)
	_cloud.scale = Vector3.ONE * (1.0 + 0.35 * (1.0 - k)) * clampf(_cloud_t / 0.5, 0.05, 1.0)


func _clear_cloud() -> void:
	_cloud_t = 0.0
	if _cloud != null:
		_cloud.queue_free()
		_cloud = null


func _kusari_half() -> float:
	return KUSARI_HALF * (1.5 if _master else 1.0)


## Kunoichi : elle approche, annonce un arc au sol devant elle, puis la chaîne de la kusarigama le balaie.
func _kunoichi(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			if dist > 2.6:
				_walk_to_hero(delta, speed)
			else:
				_face(dir, delta, 6.0)
				ch.play(ch.idle)
			_timer -= delta
			if _timer <= 0.0 and dist < KUSARI_LEN + 0.3:
				if not main.take_token(self):
					_timer = 0.4
					return
				_strike_dir = dir
				_target = Vector3(position.x, 0, position.z)
				_zone = Node3D.new()
				_zone.top_level = true
				add_child(_zone)
				_zone.global_position = _target
				_zone.rotation.y = atan2(dir.x, dir.z)
				_tele = main.vfx.tele_fan(_zone, _kusari_half(), KUSARI_LEN)
				_state = "windup"
				_timer = KUSARI_T
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / KUSARI_T)
			elif _timer <= 0.0:
				_timer = 0.5
		"windup":
			_face(_strike_dir, delta, 8.0)
			var k := 1.0 - _timer / KUSARI_T
			main.vfx.tele_update(_tele, k, _timer)
			ch.set_glow(0.9 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				if _in_cone(hero.position, _kusari_half(), KUSARI_LEN):
					_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
				var sweep := _strike_dir.rotated(Vector3.UP, 1.2)
				main.vfx.wind_slash(_target + _strike_dir * 1.6, sweep, 1.2)
				main.vfx.wind_slash(_target + _strike_dir * 3.0, sweep, 1.0)
				ch.play_once("2H_Melee_Attack_Spinning", 2.2)
				_cancel_attack()
				_timer = 1.3
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.0, 2.8)


## Vrai si p est dans l'arc (sommet _target, axe _strike_dir, demi-angle `half`, portée `ln`).
func _in_cone(p: Vector3, half: float, ln: float) -> bool:
	var v := Vector3(p.x - _target.x, 0, p.z - _target.z)
	var l := v.length()
	if l < 0.3:
		return true
	if l > ln:
		return false
	return v.dot(_strike_dir) / l > cos(half)


# ------------------------------------------------------------------ funa

## Point du bord le plus proche de `p` (les noyés sortent de l'eau, jamais du milieu du ponton).
func _nearest_edge(p: Vector3) -> Vector3:
	# bords du cadre courant (la zone de combat d'une étape, sinon l'arène)
	var b: Rect2 = main.arena.bounds
	var c := b.get_center()
	var hx := b.size.x * 0.5
	var hz := b.size.y * 0.5
	var ex := hx - EDGE_IN
	var ez := hz - EDGE_IN
	var lx := p.x - c.x
	var lz := p.z - c.y
	var dx := hx - absf(lx)
	var dz := hz - absf(lz)
	var q := Vector3(ex * (1.0 if lx >= 0.0 else -1.0), 0, clampf(lz, -ez, ez)) if dx <= dz else Vector3(clampf(lx, -ex, ex), 0, ez * (1.0 if lz >= 0.0 else -1.0))
	q += Vector3(c.x, 0, c.y)
	# salles en plateformes : toujours sur la terre ferme
	return main.arena.clamp_walk(q, radius)


## Autre point du bord, loin de l'ancien et pas collé au héros.
func _random_edge() -> Vector3:
	var b: Rect2 = main.arena.bounds
	var c := b.get_center()
	var hx := b.size.x * 0.5
	var hz := b.size.y * 0.5
	var ex := hx - EDGE_IN
	var ez := hz - EDGE_IN
	var best := position
	for attempt in 20:
		var q := Vector3.ZERO
		# les grands côtés sont plus souvent choisis (proportion des longueurs)
		if randf() < hz / (hx + hz):
			q = Vector3(ex * (1.0 if randf() < 0.5 else -1.0), 0, randf_range(-ez + 0.4, ez - 0.4))
		else:
			q = Vector3(randf_range(-ex + 0.4, ex - 0.4), 0, ez * (1.0 if randf() < 0.5 else -1.0))
		q = main.arena.clamp_walk(q + Vector3(c.x, 0, c.y), radius)
		best = q
		if q.distance_to(position) > 3.0 and q.distance_to(hero.position) > 2.0:
			break
	return best


func _start_emerge() -> void:
	_phase = "emerge"
	_ptimer = FUNA_EMERGE
	_shot = false
	body.visible = true
	body.position.y = FUNA_DEPTH
	_shadow.visible = true
	_face_hero_now()
	ch.play("Idle_Combat")


func _face_hero_now() -> void:
	var to := hero.position - position
	if Vector2(to.x, to.z).length() > 0.01:
		body.rotation.y = atan2(-to.x, -to.z)


func _ghost(delta: float) -> void:
	_ptimer -= delta
	match _phase:
		"emerge":
			# monte depuis l'eau, intouchable
			_face_hero_now()
			body.position.y = lerpf(FUNA_DEPTH, 0.0, clampf(1.0 - _ptimer / FUNA_EMERGE, 0.0, 1.0))
			if _ptimer <= 0.0:
				body.position.y = 0.0
				_phase = "up"
				_ptimer = FUNA_UP
		"up":
			if _state != "windup":
				var to := hero.position - position
				to.y = 0
				_face(to, delta, 6.0)
			# une seule louche par sortie, lancée assez tôt pour finir avant de replonger
			if not _shot and _ptimer < FUNA_UP - 0.25 and _ptimer > _windup + 0.05:
				if main.take_token(self):
					_shot = true
					_state = "windup"
					_timer = _windup
					_target = Vector3(hero.position.x, 0, hero.position.z)
					_strike_dir = _target - position
					_make_zone(true)
					_zone.global_position = _target
					ch.play_once("Throw", ch.length("Throw") * 0.5 / _windup)
			if _state == "windup":
				var k := 1.0 - _timer / _windup
				main.vfx.tele_update(_tele, k, _timer)
				_timer -= delta
				if _timer <= 0.0:
					_strike(_target, _zone_r)
					_end_ghost_attack()
			if _ptimer <= 0.0:
				_end_ghost_attack()
				_phase = "dive"
				_ptimer = FUNA_DIVE
		"dive":
			body.position.y = lerpf(0.0, FUNA_DEPTH, clampf(1.0 - _ptimer / FUNA_DIVE, 0.0, 1.0))
			if _ptimer <= 0.0:
				_phase = "under"
				_ptimer = FUNA_UNDER
				body.visible = false
				_shadow.visible = false
		"under":
			if _ptimer <= 0.0:
				position = _random_edge()
				_start_emerge()


## Fin (ou abandon) de la louche : libère le jeton et efface la zone.
func _end_ghost_attack() -> void:
	if _state == "windup" or _zone != null:
		main.free_token(self)
	_state = "move"
	if _zone:
		_zone.queue_free()
		_zone = null
