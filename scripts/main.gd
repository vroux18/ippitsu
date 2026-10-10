extends Node3D
## Boucle de jeu : on trace, on lâche = ruée qui tranche. Chaque monde est une expédition en étapes :
## de longues cartes qui avancent vers le fond, des zones de combat qui se ferment (vagues d'ennemis),
## des recoins à fouiller, l'arène du gardien à mi-chemin et le boss au bout.
## `room` compte les combats (15 par monde, dont 8 = gardien et 15 = boss) : XP, rouleaux, records.
const Perf = preload("res://scripts/perf_probe.gd")  # relevé par image (-- --perf)

const Toon = preload("res://scripts/toon.gd")
const Hero = preload("res://scripts/hero.gd")
const Enemy = preload("res://scripts/enemy.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")
const Powers = preload("res://scripts/powers.gd")
const Picker = preload("res://scripts/picker.gd")
# scripts des boss : pas préchargés (démarrage plus court), compilés un par image après l'accueil (_boot_async)
const BOSS_BASE := "res://scripts/boss.gd"  # okappa, uwabami
const BOSS_PATHS := {"kyubi": "res://scripts/boss_kyubi.gd", "gashadokuro": "res://scripts/boss_gasha.gd",
	"daidara": "res://scripts/boss_daidara.gd", "kuronami": "res://scripts/boss_kuronami.gd",
	"bakekujira": "res://scripts/boss_mini_kujira.gd",
	# (ceux-ci préchargent un squelette : après les autres, le temps qu'il arrive en arrière-plan)
	"tsuchigumo": "res://scripts/boss_mini_tsuchigumo.gd", "yukionna": "res://scripts/boss_mini_yukionna.gd",
	"ibaraki": "res://scripts/boss_mini_ibaraki.gd",
	# mondes 6 à 8 (Kurama, Ryūgū-jō, Yomi)
	"karasu_o": "res://scripts/boss_mini_karasu.gd", "sojobo": "res://scripts/boss_sojobo.gd",
	"umibozu_o": "res://scripts/boss_mini_umibozu.gd", "ryujin": "res://scripts/boss_ryujin.gd",
	"gaki_o": "res://scripts/boss_mini_gaki.gd", "izanami": "res://scripts/boss_izanami.gd"}
const WORLD_BOSS := {1: "uwabami", 2: "kyubi", 3: "gashadokuro", 4: "daidara", 5: "kuronami", 6: "sojobo", 7: "ryujin", 8: "izanami"}
# gardien de la salle MINI_ROOM : chacun enseigne le geste utile contre le boss de son monde
# point faible de chaque boss, montré en astuce quand la lame ricoche
const BOSS_HINTS := {
	"okappa": "Frappe-le quand il sort de l'eau",
	"uwabami": "Quand il fait surface : un long trait sur tout son corps",
	"kyubi": "Entoure-le d'une boucle ou d'un ensō",
	"gashadokuro": "Frappe la main posée au sol, puis la colonne de la queue au crâne",
	"daidara": "Tranche ses cœurs lumineux dans l'ordre",
	"kuronami": "Coupe ses griffes en longueur, renvoie les vagues d'un aller-retour",
	"tsuchigumo": "Trace une boucle autour du cocon pour le déchirer",
	"yukionna": "après son souffle, tranche les cristaux du plus petit au plus grand",
	"ibaraki": "Touche ses sceaux de braise dans l'ordre, d'un seul trait",
	"bakekujira": "quand elle charge, trace un aller-retour juste devant sa tête",
	"karasu_o": "Quand il se pose, trace une boucle autour de lui",
	"sojobo": "Tranche sa tornade de plumes, puis entoure-le d'une boucle",
	"umibozu_o": "Crève ses bulles d'écume dans l'ordre, d'un seul trait",
	"ryujin": "Tranche ses cinq perles dans l'ordre, d'un seul trait",
	"gaki_o": "Tranche ses trois chaînes en travers",
	"izanami": "Coupe les fils des huit dieux du tonnerre, puis entoure-la d'un ensō",
}
const MINI_BOSS := {1: "okappa", 2: "tsuchigumo", 3: "yukionna", 4: "ibaraki", 5: "bakekujira", 6: "karasu_o", 7: "umibozu_o", 8: "gaki_o"}
const Vfx = preload("res://scripts/vfx.gd")
const Options = preload("res://scripts/options.gd")
const Pickups = preload("res://scripts/pickups.gd")
const KIND_XP := {"oni": 1, "kappa": 2, "tate": 2, "funa": 2, "brute": 3,
	"umibozu": 2, "kitsunebi": 2, "kitsunebi_s": 1, "yukionna": 3, "kasha": 3, "kagebo": 3,
	"kappa_yumi": 2, "ika": 2, "umi_nyobo": 3, "kamaitachi": 2, "tanuki": 2, "tanuki_d": 0, "kitsune_tsukai": 3,
	"yuki_warashi": 1, "tsurara": 2, "onryo": 3, "hinotama": 2, "teppo": 2, "tengu": 3, "kanabo": 5,
	"sumidama": 2, "sumidama_s": 1, "kasa": 2, "moryo": 3,
	"karasu": 2, "yamabushi": 3, "konoha": 2, "kani": 3, "ningyo": 2, "fugu": 2, "gaki": 1, "gokusotsu": 4, "shiryo": 2,
	"shinobi": 2, "shuriken": 2, "kemuri": 3, "kunoichi": 3}
const Tutorial = preload("res://scripts/tutorial.gd")  # hôte du dojo
const Coach = preload("res://scripts/coach.gd")  # tutoriel en jeu : bulles du premier monde
const Intro = preload("res://scripts/intro.gd")
const Opening = preload("res://scripts/opening.gd")
const Music = preload("res://scripts/music_player.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const BotShapes = preload("res://scripts/bot_shapes.gd")  # captures `?fig=` : la figure tracée par le héros
const PowerData = preload("res://scripts/power_data.gd")
const Hazards = preload("res://scripts/hazards.gd")
const Arena = preload("res://scripts/arena.gd")
const Worlds = preload("res://scripts/worlds.gd")
const WorldMap = preload("res://scripts/worldmap.gd")
const Meta = preload("res://scripts/meta.gd")
const Refuge = preload("res://scripts/refuge.gd")
const Bestiary = preload("res://scripts/bestiary.gd")  # base_kind : clé de comptage des ennemis (écran bestiaire retiré)
const BOT_PATH := "res://scripts/bot.gd"  # robot du CI : chargé seulement avec `-- --bot`
const PowersRecap = preload("res://scripts/powers_recap.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")  # jetons UI v2 (encres des figures, hex des pictos)
const Score = preload("res://scripts/score.gd")
# malédictions du sanctuaire (après les salles de SANCTUARIES) : un malus pour toute la partie, une récompense tout de suite
## Dix pactes (planche Sanctuaire, UNIVERS §4.9). Chacun : "school" (couleur d'élément de la carte), "leg"
## (pacte légendaire : filet d'or, au plus un par offre), "malus" et "gain" (lignes de la carte :
## [pictogramme, valeur, libellé] ; "gain2" facultatif), "line" (phrase de la bulle : déclencheur explicite).
## Le glyphe du médaillon est UiKit.POWER_GLYPH["pact_<id>"]. Application : _take_curse (gains immédiats) et
## les lectures de `curses` (elan_max, _spawn_list, _spawn_elite, _wave_ready, heal, curse_dmg_mult, _hurt_hero…).
const CURSES := {
	"dry": {"name": "Encre sèche", "school": "ink", "leg": false,
		"malus": ["effets/portee", "−30 %", "encre max"], "gain": ["hud/rouleau", "+2", "rouleaux"],
		"line": "Toute la partie, ta réserve d'encre (la longueur de tes traits) baisse de 30 %. En échange : deux rouleaux, tout de suite."},
	"oni_eye": {"name": "Œil de l'oni", "school": "shadow", "leg": true,
		"malus": ["hud/oni", "+50 %", "vie yōkai"], "gain": ["hud/rouleau", "+1", "rouleau épique"],
		"line": "Toute la partie, chaque yōkai qui paraît a 50 % de vie en plus. En échange : un rouleau épique garanti, tout de suite."},
	"heavy": {"name": "Pas lourd", "school": "ink", "leg": false,
		"malus": ["effets/vitesse", "−20 %", "ruée"], "gain": ["effets/cur", "+1", "cœur max"], "gain2": ["hud/rouleau", "+1", "rouleau"],
		"line": "Toute la partie, tes ruées sont 20 % plus lentes. En échange : un cœur de plus à ta jauge, et un rouleau tout de suite."},
	"haste": {"name": "Hâte des morts", "school": "bolt", "leg": false,
		"malus": ["effets/vitesse", "+25 %", "yōkai"], "gain": ["hud/rouleau", "+1", "rouleau"], "gain2": ["effets/cur", "", "soin complet"],
		"line": "Toute la partie, les yōkai marchent 25 % plus vite. En échange : un rouleau tout de suite, et tous tes cœurs rendus."},
	# mode difficile choisi : la déferlante ne vient plus que par ce pacte
	"tide": {"name": "Déferlante", "school": "water", "leg": true,
		"malus": ["hud/vague", "", "vagues en combat"], "gain": ["hud/rouleau", "+2", "rouleaux"],
		"line": "Dès le prochain combat et jusqu'au bout, des vagues balaient l'arène et te bousculent. En échange : deux rouleaux, tout de suite."},
	"lantern": {"name": "Lanterne éteinte", "school": "fire", "leg": false,
		"malus": ["effets/duree", "−25 %", "annonces"], "gain": ["hud/rouleau", "+1", "rouleau rare"],
		"line": "Toute la partie, les yōkai annoncent leurs coups 25 % moins longtemps. En échange : un rouleau rare garanti, tout de suite."},
	"cursed_ink": {"name": "Encre maudite", "school": "shadow", "leg": false,
		"malus": ["effets/duree", "4 s", "encre figée"], "gain": ["effets/cur", "+2", "cœurs max"], "gain2": ["effets/cur", "", "soin complet"],
		"line": "Toute la partie, chaque coup reçu fige ta recharge d'encre pendant 4 s. En échange : deux cœurs de plus à ta jauge, et tous tes cœurs rendus."},
	"ronin": {"name": "Serment du rōnin", "school": "fig", "leg": true,
		"malus": ["effets/cur", "", "plus aucun soin"], "gain": ["effets/degats", "+30 %", "dégâts"],
		"line": "Jusqu'à la fin de la partie, aucune source (fontaine, rouleau, ensō) ne te soigne plus. En échange : tous tes dégâts montent de 30 %."},
	"drum": {"name": "Tambour des morts", "school": "bolt", "leg": false,
		"malus": ["effets/vitesse", "×2", "vagues"], "gain": ["hud/etoile", "+40 %", "score"],
		"line": "Toute la partie, la vague suivante entre deux fois plus tôt, sans attendre la précédente. En échange : chaque point marqué vaut 40 % de plus."},
	"mask": {"name": "Masque fendu", "school": "fire", "leg": false,
		"malus": ["hud/oni", "×2", "élites"], "gain": ["hud/piece", "×2", "or"],
		"line": "Toute la partie, les élites (bouclier, aura, affixes) sont deux fois plus fréquents. En échange : chaque pièce ramassée en vaut deux."},
}
const PACT_OFFER := 3  # pactes proposés au sanctuaire, dont au plus un légendaire
const REFUSE_COST := 40  # « Refuser » au sanctuaire coûte de l'or (monde 1), +REFUSE_COST_STEP par monde : sans l'or, un pacte est obligatoire
const REFUSE_COST_STEP := 10
const INK_LOCK_T := 4.0  # Encre maudite : recharge d'encre figée après un coup reçu (s)
# hors combat : encre illimitée, trait plus long, et course en gardant le doigt posé
const EXPLORE_REACH := 2.0
const RUN_SPEED := 7.0
const HOLD_RUN_T := 0.4  # doigt immobile (s) après un trait avant de courir
# énigmes des recoins
const PUZZLE_KINDS := ["stele", "lanterns", "spirit"]
const PUZZLE_FIGS := ["loop", "zigzag", "return", "enso"]
const PUZZLE_REWARDS := ["gold", "heal", "reroll"]
const LANTERN_R := 1.6
const LANTERN_TOUCH := 0.6
const STELE_NEAR := 2.5
# coffres scellés des recoins (dès l'étape 2) : figure peinte sur la plaque (puzzle_art.build_seal)
const SEAL_FIGS := ["loop", "zigzag", "straight", "return", "enso", "hook"]
const SEAL_FIGS_EASY := ["loop", "zigzag", "straight", "return"]  # deux premières étapes du monde 1
const SEAL_CHANCE := 0.5  # part des coffres de recoin scellés
const SEAL_NEAR := 3.0  # le trait passe à moins de 3 m du coffre
const SEAL_SCROLL := 0.35  # part des coffres scellés qui offrent un rouleau (l'expérience du niveau suivant)
const PuzzleArt = preload("res://scripts/puzzle_art.gd")  # décor des énigmes (stèle, tōrō, hitodama)
# yōkai scellés (_spawn_list, dès l'étape 2, jamais aux combats de gardien ni de boss) : un ofuda au front porte
# une figure ; tracée en le touchant, elle brise le sceau et le tue d'un coup (_seal_break) ; tout le reste ricoche
# (enemy.SEAL_RESIST). Figures tirées parmi celles que le joueur connaît (seal_figs).
const SEALED_FIGS := ["loop", "zigzag", "return", "hook", "straight", "enso", "wave", "point", "triangle"]
const SEALED_BASE := ["loop", "zigzag", "return", "hook", "straight", "enso"]  # connues d'emblée
const SEALED_ROOM := 0.7  # part des combats qui ont au moins un scellé
const SEALED_TWO := 0.35  # ... et un deuxième (jamais plus de deux)
const SEALED_PICK := 0.45  # chance qu'un ennemi éligible soit le scellé (pas toujours le deuxième venu)
const SEALED_GOLD := 3  # pièces lâchées par un sceau brisé
const SEALED_INK := 0.25  # part de la jauge d'encre rendue par un sceau brisé
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const ROOMS := 15  # combats d'un monde
const MINI_ROOM := 8  # combat du mini-boss (son arène)
# courbe du budget d'ennemis dans un monde (index = salle) : montée, gardien (8), respiration (9), épreuve
const ROOM_CURVE := [0.0, 0.75, 0.85, 1.0, 1.0, 1.05, 1.1, 1.2, 1.0, 0.9, 1.05, 1.15, 1.2, 1.3, 1.4, 1.0]  # index = salle (8 gardien, 9 respiration, 14 épreuve, 15 boss)
const TRIAL_ROOM := 14  # épreuve : un élite garanti
const MOB_SCALE := 1.12  # un peu plus d'ennemis par combat, tous mondes
const WAVE_OVERLAP_T := 9.0  # vagues qui se chevauchent : la suivante arrive au plus tard après ce délai
const REINF_DIST := 5.0  # renforts du boss : apparition à cette distance du héros au moins
const SANCTUARIES := [5, 10]  # malédictions proposées après ces combats (fins des étapes 2 et 5)
# étapes du monde : combats (numéros de `room`) réunis sur une même longue carte ; [8] et [15] : arènes
const STAGE_PLAN := [[1, 2], [3, 4, 5], [6, 7], [8], [9, 10], [11, 12], [13, 14], [15]]
const CAM_FOCUS_Y := 0.9  # hauteur visée au centre de l'écran (mi-corps du héros)
const CAM_LEAD := 0.6  # la caméra regarde à peine devant le héros (il reste au centre de l'écran)
const CAM_LEAD_PAD := 2.4  # mode pad : l'arène est cadrée au-dessus du pad, on voit plus loin devant
const SETTINGS_V := 1  # version des réglages : 1 = contrôle « sur l'écran » par défaut (anciens « pad » remis à zéro)
const PAD_STROKES := 12  # pad « au début » : il s'efface après ces premiers traits de la session
const KIND_COST := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 2,
	"umibozu": 2, "kitsunebi": 3, "yukionna": 3, "kasha": 3, "kagebo": 3,
	"kappa_yumi": 2, "ika": 2, "umi_nyobo": 3, "kamaitachi": 2, "tanuki": 2, "kitsune_tsukai": 3,
	"yuki_warashi": 1, "tsurara": 2, "onryo": 3, "hinotama": 2, "teppo": 2, "tengu": 3, "kanabo": 4,
	"sumidama": 3, "kasa": 2, "moryo": 3,
	"karasu": 2, "yamabushi": 3, "konoha": 2, "kani": 3, "ningyo": 2, "fugu": 2, "gaki": 1, "gokusotsu": 4, "shiryo": 2,
	"shinobi": 2, "shuriken": 2, "kemuri": 3, "kunoichi": 3}
# première salle où chaque ennemi peut venir (ennemis signature : un par monde, vers la salle 3-4)
const KIND_ROOM := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 4,
	"umibozu": 3, "kitsunebi": 3, "yukionna": 4, "kasha": 4, "kagebo": 4,
	# bestiaire étendu : tireurs et coureurs tôt, soutiens et costauds plus tard
	"kappa_yumi": 2, "ika": 3, "umi_nyobo": 5, "kamaitachi": 2, "tanuki": 3, "kitsune_tsukai": 5,
	"yuki_warashi": 2, "tsurara": 6, "onryo": 4, "hinotama": 2, "teppo": 3, "tengu": 4, "kanabo": 6,
	"sumidama": 2, "kasa": 3, "moryo": 5,
	"karasu": 2, "yamabushi": 4, "konoha": 3, "kani": 3, "ningyo": 2, "fugu": 3, "gaki": 2, "gokusotsu": 5, "shiryo": 3,
	"shinobi": 2, "shuriken": 3, "kemuri": 4, "kunoichi": 4}
# rythme des rencontres : dans chaque monde, ses ennemis propres arrivent par étapes (STAGE_PLAN) :
# quelques-uns dès l'étape 1, d'autres à l'étape 3, le reste à l'étape 5 (après le gardien).
# Remplace KIND_ROOM dans ce monde ; ailleurs (ennemi qui revient), KIND_ROOM s'applique.
# Monde 1 en douceur : rien de neuf avant la salle 2, puis un ou deux par étape.
const KIND_STAGE := {
	1: {"kappa_yumi": 2, "umibozu": 3, "ika": 5, "umi_nyobo": 5},
	2: {"kitsunebi": 1, "kamaitachi": 1, "tanuki": 3, "shinobi": 3, "kitsune_tsukai": 5, "shuriken": 5},
	3: {"yukionna": 1, "yuki_warashi": 1, "onryo": 3, "tsurara": 5},
	4: {"kasha": 1, "hinotama": 1, "teppo": 3, "tengu": 3, "kanabo": 5, "moryo": 5},
	5: {"kagebo": 1, "sumidama": 1, "kasa": 3, "kemuri": 3, "kunoichi": 5},
	6: {"karasu": 1, "konoha": 3, "yamabushi": 5},
	7: {"kani": 1, "ningyo": 3, "fugu": 5},
	8: {"gaki": 1, "shiryo": 3, "gokusotsu": 5},
}
const UNLOCK_ALL := false  # vrai : tous les mondes ouverts (prototype) ; sinon un monde vaincu ouvre le suivant
const SAVE_PATH := "user://ippitsu.cfg"

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (x, z)
const IN_PLAY_STATES := ["play", "transit", "dying", "pick", "tuto"]

const ELAN_MAX := 18.0  # longueur de trait maximale (de quoi tracer large dès le départ)
const ELAN_REGEN := 10.0  # par seconde réelle, hors tracé
const ELAN_PER_HIT := 3.5
const ENEMY_HP_MULT := 2.05  # 2.0 avant les portes à sceaux : +2,5 % pour leurs rouleaux en plus (robots campagne)
const ULT_DAMAGE := 4.0
const FIG_SLOW_LEN := 0.55  # figure reconnue : durée du léger ralenti (s réelles)
const FIG_SLOW_SCALE := 0.7  # vitesse du jeu au creux du ralenti
var _fig_slow := 0.0
const SHOW_DMG := false  # chiffres de dégâts au-dessus des ennemis
const HIT_REACH := 0.55

var cam: Camera3D
var hero: Node3D
var sfx: Node
var hud: Control
var world: Node3D

var enemies: Array = []
var bullets: Array = []
var effects: Array = []

var elan := 18.0
var touching := false
var stroke: MeshInstance3D
var dash_stroke: MeshInstance3D
var stroke_layer := 0
var stroke_id := 0
var combo := 0
var origin := Vector3.ZERO
var _prev_hero := Vector3.ZERO

var shake := 0.0  # secousse : amplitude linéaire (shake × 0,35 m)
# impact d'un coup : arrêt sur image bref (temps réel), croissant avec la série, plafonné par trait
const HITSTOP_HIT := 0.035
const HITSTOP_KILL := 0.065
const HITSTOP_BOSS := 0.05
## Dégâts du héros sur les gardiens et les boss, multipliés par ce facteur (ruée, pouvoirs, ultime) : à 1,0 ils
## tombaient trop vite ; il faut maintenant tenir deux ou trois fenêtres de vulnérabilité.
const BOSS_TOUGH := 0.55
const HITSTOP_STEP := 0.01
const HITSTOP_MAX := 0.12
const HITSTOP_STROKE := 0.3  # arrêt cumulé maximal sur un trait
const HITSTOP_SCALE := 0.03  # échelle de temps pendant l'arrêt
var _hitstop := 0.0  # secondes réelles d'arrêt restantes
var _stroke_stop := 0.0  # arrêt déjà donné sur le trait en cours
var _kick := Vector3.ZERO  # poussée de caméra dans le sens du coup (retombe vite)
var _zoom_k := 0.0  # rapproché bref de la caméra sur une belle série (1 -> 0 en 0,3 s)
const ZOOM_PUNCH := 0.6
const COMBO_PITCH := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]  # son de coup : gamme pentatonique
var wave_wait := 1.0
var safety_left := 1  # pas de côté automatiques restants dans la salle
const ATTACK_TOKENS := 2  # attaquants simultanés par défaut (le monde en cours en donne plus : attack_tokens)
var _attackers: Array = []
# vagues : taille de la dernière vague lâchée, temps depuis, reste d'une vague retenue par le plafond à l'écran
var _wave_size := 0
var _wave_t := 0.0
var _wave_cont := false  # la tête de _waves_left est la suite d'une vague déjà annoncée
var _elite_due := 0  # élites garantis restant à poser dans la salle (épreuve)
var _reinf_step := 0  # renforts du boss de fin déjà appelés (66 %, puis 33 % de ses PV)
var game_over := false
var _ticks := 0
var _bot_step := 1.0 / 30.0  # pas fixe du robot : celui du moteur (--fixed-fps), retrouvé depuis delta
var _cam_base := Transform3D()
var _cam_full := Transform3D()
var _cam_pad := Transform3D()  # mode pad : arène cadrée au-dessus du pad

var state := "menu"  # menu | worlds | intro | play | boss_intro | pick | transit | paused | dying | over | tuto
# groupes d'états testés à chaque image : constantes (un `state in [...]` littéral allouerait le tableau à chaque appel)
const ST_FIGHT := ["play", "tuto"]  # en jeu, trait actif
const ST_HOLD := ["transit", "boss_intro", "pick", "intro"]  # séquences où le retour système est ignoré
const ST_SCENE := ["play", "pick", "transit", "boss_intro", "tuto"]  # la scène 3D vit (caméra, décor)
const ST_RING_OFF := ["menu", "worlds", "sail"]  # anneau du héros caché
const ST_HUD := ["play", "transit", "pick", "tuto", "paused", "boss_intro"]  # HUD de jeu affiché
var menu: Control
var record := 0
var _state_t := 0.0
const MENU_BOAT := Vector3(0, 0, 17.5)  # la barque de l'accueil, au large devant le sanctuaire (elle avance vers lui)
const BOAT_DECK := -0.24
const BOAT_LEN := 3.8  # sampan : longueur, demi-largeur, place du héros (proue vers -z)
const BOAT_BEAM := 0.62
const BOAT_HERO_Z := -1.0
const RING_LIFE := 3.0  # durée d'une ride sur l'eau
const WARDROBE_DIR := Vector3(0.958, 0.0, -0.287)  # garde-robe : la caméra sur le flanc de la proue
const Decor = preload("res://scripts/decor.gd")
var menu_boat: Node3D
var _boat_lantern: Node3D
var _boat_lan_mat: StandardMaterial3D
var _boat_light: OmniLight3D = null
var _boat_rings: Array = []  # [MeshInstance3D, matériau, âge]
var _boat_ring_t := 0.0
var _boat_fx: Node3D = null  # particules de l'accueil (selon le monde)
var _boat_fx_world := 0
var _boat_birds: Node3D
var _boat_bird_t := 5.0
var _drift_t := 0.0  # dérive lente de la caméra d'accueil
var wardrobe: Control  # garde-robe (wardrobe.gd)
var bestiary: Control  # bestiaire (bestiary.gd)
var _new_kinds: Array = []  # ennemis rencontrés pour la première fois : bandeau « NOUVEAU YOKAI » à venir
var _new_kind_t := 0.0
var _bestiary_dirty := false  # victoires comptées depuis la dernière sauvegarde
var _wardrobe_on := false
var _wardrobe_k := 0.0
var _env: Environment
# ambiance de boss : ciel assombri vers l'encre du monde, brume plus dense, soleil bas et chaud, contraste,
# éclairs lointains (boss du monde seulement) ; fondue à l'entrée en scène, retirée à la mort du boss
var _mood_k := 0.0
var _mood_to := 0.0
var _mood_base: Dictionary = {}
var _mood_flash := 0.0
var _mood_next_flash := 6.0
const MOOD_FADE := 2.5
const MOOD_INK := Color("#14111A")
var _light_mode := false  # rendu allégé (téléphone)
var _fx_cache := {}  # maillages et matières d'effets réutilisés
const SPLASH_POOL_MAX := 10  # gerbes de gouttes gardées par couleur (au lieu d'un émetteur neuf par coup)
var _splash_pool := {}  # "drop" + couleur -> Array de CPUParticles3D éteints et cachés
var _sun: DirectionalLight3D
var arena: Node3D
var current_world := 1

var powers: Node
var picker: Control
var room := 0
var _stroke_kills := 0
var bosses: Array = []
var hazards: Node3D
var meta: RefCounted
var refuge: Control
var mini_kills := 0
var curses: Array = []
var _pick_mode := "upgrade"
var _extra_picks := 0
var _safe_point := Vector3.ZERO
var kills := 0
var boss_kills := 0
var _waves_left: Array = []
var waves_total := 1
var wave_index := 1
var _room_done := false
var _rebuilt := false
var _dash_prev := Vector3.ZERO  # garde-fou des ruées bloquées
var _dash_stall := 0.0
var _intro_world := 0  # monde choisi sur la carte, construit sous le rideau de l'intro
var _intro_swapped := false
var worldmap: Control
var _ending_victory := false
var music: Node
var tuto: Control  # dojo (état « tuto »)
var coach: Control  # tutoriel en jeu (coach.gd)
var gentle := false  # première partie du tutoriel : les deux premiers combats du monde 1 adoucis
# contrôles : ctrl_mode est lu une fois au lancement (cadrage, entrée) ; ctrl_pref est le choix des options,
# appliqué au prochain lancement
var ctrl_mode := "screen"  # screen | pad
var ctrl_pref := "screen"
var pad_size := "m"  # s | m | l
var pad_show := "start"  # always | start | never
var _strokes_done := 0
var _run_anchor := Vector2.ZERO  # mode pad : point où le doigt s'est posé pendant la course (manette)
var intro: Control  # planches illustrées : premier JOUER, ou bouton « ? » de l'accueil
var opening: Control  # ouverture à l'encre du tout premier démarrage (mini-histoire, opening.gd), au-dessus de tout
var vfx: Node3D
var options: Control
var _options_from := "menu"
var pickups: Node3D
# expérience et or ramassés au sol : la barre pleine fait monter de niveau (un rouleau à choisir)
var xp := 0
var level := 1
var run_gold := 0
var _pending_levels := 0
var _lv_cele := -1.0  # fête de montée de niveau en cours (s), < 0 : aucune
const LV_CELE := 0.9  # durée de la fête avant les rouleaux
var _pick_context := "room"  # room | level
var foam := 0  # coups bloqués restants dans la salle (Écume)
var _bot: Node = null  # robot testeur (CI)
var _force_fig := ""  # captures `?fig=wave` : figure tracée en boucle par le héros (_force_fig_step)
var _force_fig_t := 1.5
var _fig_shot := ""  # captures `&figshot=` : préfixe des images
var _fig_shot_n := 0
var _last_offer: Array = []  # derniers rouleaux proposés (pour le robot)
var recap: Control
var _recap_from := "pause"
var _shrine: Node3D = null  # autel du sanctuaire (facultatif)
var in_hub := false  # sanctuaire de départ (avant la salle 1)
var _pause_pending := false  # l'appli a été quittée pendant une transition : pause au retour en jeu
var _web_hidden_t := 0.0
var ult := 0.0  # jauge d'ultime (0..1), double tap quand elle est pleine
var _ult_sent := -1.0  # dernière valeur passée au HUD (évite un set() par image)
var _touch_ms := 0
var _last_tap_ms := 0
var _boss_seen: Node3D = null
var _boss_hp_seen := 0.0
var _boss_sh_seen := 0.0  # bouclier du boss vu à l'image précédente (astuce du point faible)
var _boss_dry_t := 0.0  # temps sans dégât sur le boss (affiche son point faible)
var _dmg_labels := {}  # id ennemi -> chiffre en cours (cumul des touches rapprochées)
var _ricochets := {}  # ricochets sur les boss de la partie (astuces)
var _auto_step := false  # pas de côté automatique en cours (ne compte pas comme un trait)
var run_time := 0.0
# chaîne : ruées réussies d'affilée sans prendre de coup (bonus de dégâts)
const CHAIN_TIMEOUT := 6.0
const CHAIN_TIERS := {5: "FLUIDE", 10: "TRANCHANT", 20: "MAÎTRE"}
var chain := 0
var max_chain := 0
var score: RefCounted = Score.new()  # points de la partie (score.gd), multipliés par la chaîne
var shape_counts := {}  # figures réalisées pendant la partie (forme -> nombre)
var _chain_t := 0.0
var _stroke_hit := false
var _touch_sp := Vector2.ZERO  # point où le doigt s'est posé
var _shape: Dictionary = {}  # forme reconnue du trait en cours de ruée
var _fig_mods: Dictionary = {}  # effets de la figure sur la ruée en cours (powers.figure_launch)
# Arbre du pinceau (meta.gd) : effets de combat
var _net_ready := false  # Coup net : la prochaine touche du combat est critique
var _last_breath_used := false  # Dernier souffle : déjà servi dans cette partie
var _bleed := {}  # Lame d'encre : instance_id -> [ennemi, temps restant, temps jusqu'à la prochaine goutte]
# expédition
var stage_i := 0  # étape en cours (index dans STAGE_PLAN)
var _enc := -1  # zone de combat en cours dans l'étape (-1 : on marche)
var _cam_dz := 0.0  # la caméra suit le héros le long de l'étape
var _pockets: Array = []  # recoins : {kind, node, pos, used, fx}
# ralenti sur le dernier ennemi d'un combat
var _slowmo_t := -1.0  # temps réel écoulé (-1 : pas de ralenti)
var _slowmo_pos := Vector3.ZERO
var _last_kill_pos := Vector3.ZERO
var _alive_prev := 0
# rituel du torii (passage vers la suite, joueur seulement)
var _ritual := false
var _ritual_from := Vector3.ZERO
var _ritual_flash := false
var _walk_from := Vector3.ZERO  # rituel du torii : d'où le héros entre à pied dans la suite
# exploration : course au doigt posé
var _explore := false  # hors combat (calculé à chaque image)
var _running := false
var _run_dir := Vector3.ZERO
var _run_sp := Vector2.ZERO
var _hold_t := 0.0
var _hold_sp := Vector2.ZERO
var run_dist := 0.0  # distance courue depuis le dernier départ (robot)
var puzzles_seen := 0
var puzzles_solved := 0
var chests_sealed := 0  # coffres scellés posés / ouverts (robot de campagne)
var chests_unsealed := 0
var sealed_set := 0  # yōkai scellés posés / brisés à la figure (robot de campagne)
var sealed_broken := 0
var _seal_quota := 0  # scellés encore possibles dans ce combat
var _room_spawned := 0  # ennemis posés depuis le début du combat (le premier n'est jamais scellé)
var _cap_fige := -1.0  # captures (`fige=`) : délai entre le coup sur le sceau et l'image figée (< 0 : rien)
var _cap_frozen := false
# combat de boss sans dégât
var _scratched := false
var _flawless_pending := false  # rouleau « sans une égratignure » à ouvrir (gardien)
# portes à deux sceaux (fin d'étape, SealGate) : le sceau de la porte franchie vaut pour l'étape qui suit
const SealGate = preload("res://scripts/seal_gate.gd")
const SEAL_GOLD := 60  # sceau koban : or versé à la fin de l'étape (monde 1)…
const SEAL_GOLD_STEP := 15  # … et en plus par monde
const SEAL_HEAL := 2  # sceau du cœur : la source garantie rend deux cœurs
const SEAL_ONI_HP := 1.35  # sceau de l'oni : PV du défi d'élite en plus
const XP_SEAL_K := 1.3  # expérience par niveau ×1,3 depuis les portes à sceaux (~3 rouleaux de sceau de plus par monde)
var seal_reward := ""  # sceau de l'étape en cours : école ("fire"…), "gold", "heart", "oni" ; "" : aucun
var _seal_picks: Array = []  # rouleaux de sceau à ouvrir hors combat : {"school": s} ou {"rank": 1}
var _seal_cur: Dictionary = {}  # rouleau de sceau ouvert (relance)
var _gate_force: Array = []  # captures (`?portes=a,b`) : sceaux imposés aux portes de l'étape
var _flawless_boss := false  # boss du monde vaincu sans dégât

# --- pinceaux et omamori (gear_data.gd), choisis sur l'écran de départ (departure.gd), lus par _start ---
const Gear = preload("res://scripts/gear_data.gd")
const Departure = preload("res://scripts/departure.gd")
var brush := "fude"  # pinceau de la partie
var aspect := 0  # son aspect (0..2)
var charm := ""  # omamori porté ("" : aucun)
var departure: Control  # écran AVANT LE DÉPART
var _dep_world := 0  # monde à ouvrir après PARTIR
var _dep_from_map := false  # écran ouvert depuis la carte (retour : la carte)
var _rain: Array = []  # Fude · Pluie : gouttes au sol [MeshInstance3D, position, vie]
var _rain_mat: StandardMaterial3D
var _wall_pts := PackedVector3Array()  # Hake · Mur : trait posé qui bloque les projectiles
var _wall_t := 0.0
var _dash_s := 0.0  # mètres parcourus depuis le début de la ruée (écart du pinceau fendu)
var _tresse_next := 0.0  # Warefude · Tresse : prochain croisement (m)
var _split_hits := {}  # Warefude : ennemi -> lignes qui l'ont déjà touché pendant ce trait (bits 1, 2)
var _blood := 0.0  # Calame de sang : dette de vie (cœurs) des mètres au-delà de CHI_FREE
var _half := 0  # Calame · Pacte : demi-cœurs gagnés (deux = un cœur)
var _pact_key := -1  # Calame · Pacte : trait de figure déjà payé
var _aiguille_key := -1  # Menso · Aiguille : trait dont le critique a déjà relancé la technique
var _garde_stage := -1  # omamori de la garde : étape où le coup a déjà été annulé
var _portes_used := false  # omamori des portes : la troisième porte a paru dans ce monde
var _refuse_free_used := false  # omamori du pacte : refus gratuit pris dans ce monde
var _fig_double_room := -1  # omamori de la figure : combat dont la première figure a déjà doublé

var _ink_lock := 0.0  # Encre maudite : secondes restantes sans recharge d'encre (après un coup reçu)
var _boss_scripts := {}  # chemin -> GDScript chargé (gardé : pas recompilé à chaque boss)
var _frame_cache := {}  # cadrages calculés par taille d'écran (_frame), gardés aussi sur le disque
var _frame_disk_key := ""  # version du jeu et réglages du cadrage : un cadrage enregistré n'est repris que s'ils sont les mêmes
const FRAMES_PATH := "user://frames.cfg"
const FRAMES_MAX := 12
# mesures de chargement : lignes « BOT PERF <étape> <ms> » avec le robot, bilan à sa fin (bot.finish)
var perf := {}  # étape -> [nombre, total ms, max ms]
var _perf_on := false
var warmed := false  # préchauffage fini (shaders des ennemis et des effets compilés : relevé --perf --shadercheck)


func _ready() -> void:
	var t_ready := Time.get_ticks_usec()
	_perf_on = "--bot" in OS.get_cmdline_user_args()
	# du lancement du moteur jusqu'ici : scripts compilés et ressources préchargées
	perf_mark("boot_load", t_ready)
	randomize()
	# `-- --seed=N` (robot du CI) : tirages fixés par la graine (salles, ennemis, rouleaux)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--seed="):
			seed(int(String(a).substr(7)))
	_build_world()
	_load_frames()
	sfx = Sfx.new()
	add_child(sfx)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	var top := CanvasLayer.new()
	top.layer = 2
	add_child(top)
	menu = Menu.new()
	top.add_child(menu)
	menu.play_pressed.connect(_on_play)
	menu.home_pressed.connect(_on_home)
	menu.sound_toggled.connect(_on_sound)
	meta = Meta.new()
	meta.load_data()
	score.hud = hud
	var ref_layer := CanvasLayer.new()
	ref_layer.layer = 4
	add_child(ref_layer)
	refuge = Refuge.new()
	refuge.meta = meta
	ref_layer.add_child(refuge)
	refuge.closed.connect(_on_refuge_closed)
	_setup_wardrobe()
	var dep_layer := CanvasLayer.new()
	dep_layer.layer = 4
	add_child(dep_layer)
	departure = Departure.new()
	departure.set("meta", meta)
	dep_layer.add_child(departure)
	departure.connect("go", _on_departure_go)
	departure.connect("closed", _on_departure_back)
	menu.atelier_pressed.connect(_on_atelier)
	menu.worlds_pressed.connect(_on_home_worlds)
	menu.world_step.connect(_on_home_world_step)
	menu.resume_pressed.connect(_on_resume)
	menu.restart_pressed.connect(_on_restart)
	menu.next_pressed.connect(_on_next_world)
	hud.pause_pressed.connect(_on_pause)
	pickups = Pickups.new()
	pickups.main = self
	add_child(pickups)
	vfx = Vfx.new()
	vfx.main = self
	add_child(vfx)
	music = Music.new()
	add_child(music)
	hazards = Hazards.new()
	hazards.main = self
	add_child(hazards)
	powers = Powers.new()
	powers.main = self
	add_child(powers)
	var pick_layer := CanvasLayer.new()
	pick_layer.layer = 3
	add_child(pick_layer)
	picker = Picker.new()
	pick_layer.add_child(picker)
	picker.picked.connect(_on_picked)
	picker.reroll.connect(_on_reroll)
	var opt_layer := CanvasLayer.new()
	opt_layer.layer = 5
	add_child(opt_layer)
	options = Options.new()
	opt_layer.add_child(options)
	options.changed.connect(_on_option)
	options.closed.connect(_on_options_closed)
	recap = PowersRecap.new()
	opt_layer.add_child(recap)
	recap.closed.connect(_on_recap_closed)
	menu.powers_pressed.connect(_open_recap)
	menu.options_pressed.connect(_open_options)
	tuto = Tutorial.new()
	tuto.main = self
	pick_layer.add_child(tuto)
	tuto.dojo_finished.connect(_on_dojo_finished)
	coach = Coach.new()
	coach.main = self
	pick_layer.add_child(coach)
	menu.dojo_pressed.connect(_start_dojo)
	intro = Intro.new()
	opt_layer.add_child(intro)
	intro.finished.connect(_on_intro_finished)
	menu.tuto_pressed.connect(_open_intro.bind(true))
	var open_layer := CanvasLayer.new()
	open_layer.layer = 6
	add_child(open_layer)
	opening = Opening.new()
	opening.set("sfx", sfx)
	open_layer.add_child(opening)
	opening.connect("reveal", _on_opening_reveal)
	opening.connect("finished", _on_opening_finished)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 4
	add_child(map_layer)
	worldmap = WorldMap.new()
	map_layer.add_child(worldmap)
	worldmap.world_chosen.connect(_on_world_chosen)
	worldmap.closed.connect(_on_worldmap_closed)
	worldmap.seal_broken.connect(_on_seal_broken)
	_load()
	get_viewport().size_changed.connect(_fit_camera)
	# `?world=N` (web) : ouvre directement le monde N
	var wsearch := str(JavaScriptBridge.eval("location.search", true)) if OS.has_feature("web") else ""
	# `-- --q=pick&world=3` (bureau) : mêmes réglages que `?…` sur le web ; `-- --shot=f.png[:s]` : capture puis sortie
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--q="):
			wsearch = "?" + s.substr(4)
		elif s.begins_with("--shot="):
			_shot(s.substr(7))
	var wpos := wsearch.find("world=")
	hud.show_fps = "fps" in wsearch
	# `?unlockall` (web) et robot du CI : tous les mondes et tous les paliers de rouleaux ouverts
	if "unlockall" in wsearch or "--bot" in OS.get_cmdline_user_args():
		meta.test_unlock_all = true
	apply_world(clampi(int(wsearch.substr(wpos + 6).get_slice("&", 0)), 1, Worlds.WORLDS.size()) if wpos >= 0 else 1)
	# `&pinceau=hake&aspect=1&charme=garde` (captures) : équipement imposé, même verrouillé ; `&won=N` : progression
	# de démonstration (mondes 1..N vaincus, leurs omamori gagnés) pour l'écran de départ ; rien n'est sauvegardé
	_gear_query(wsearch)
	_start()
	# `-- --autoplay` : démarre directement en jeu (vérification automatique du CI)
	var autoplay := "--autoplay" in OS.get_cmdline_user_args()
	if autoplay:
		var fails: Array = StrokeShapes.self_test()
		if not fails.is_empty():
			print("SCRIPT ERROR: formes de trait : ", fails)
	# `-- --figtest` : corpus de gestes (tools/fig_corpus.gd) -> matrice de confusion, puis sortie
	if "--figtest" in OS.get_cmdline_user_args():
		_figtest()
		return
	autoplay = autoplay or "autoplay" in wsearch
	if autoplay or "room=" in wsearch:
		_start(false)  # tests : directement dans les salles, sans le sanctuaire
	# `?room=N` (web) : commence directement à l'étape du combat N (tests des boss : 8 et 15)
	var rm := wsearch.find("room=")
	if rm >= 0:
		room = clampi(int(wsearch.substr(rm + 5).get_slice("&", 0)), 1, ROOMS) - 1
		_build_segment()
		_set_state("play")
		music.play_world(current_world)
	else:
		# `?hub` : directement en jeu dans le sanctuaire de départ
		_set_state("play" if autoplay or "hub" in wsearch else "menu")
	# `?pick` (web) : ouvre directement le choix de rouleau, pour vérifier l'écran
	if "pick" in wsearch:
		# hors salle (accueil) : on ouvre d'abord une vraie salle, le rouleau s'affiche au-dessus du combat
		if rm < 0:
			_start(false)
			room = 2
			_build_segment()
			_set_state("play")
			music.play_world(current_world)
		_pick_context = "room"
		_set_state("pick")
		# `?pickstyle=N` : style des cartes à comparer (0 kakemono, 1 ofuda, 2 estampe), ex. `?pick&pickstyle=1`
		var ps := wsearch.find("pickstyle=")
		if ps >= 0:
			picker.style = clampi(int(wsearch.substr(ps + 10).get_slice("&", 0)), 0, 2)
		_open_upgrades()
		# `?pick&sel=N` : la carte N déjà levée (capture de la bulle de description)
		var sl := wsearch.find("sel=")
		if sl >= 0:
			picker.set("_sel", clampi(int(wsearch.substr(sl + 4).get_slice("&", 0)), 0, 2))
	# `?sanctuaire` (captures) : l'écran des pactes au-dessus d'une vraie salle ; `&sel=N` : la carte N levée
	if "sanctuaire" in wsearch:
		if rm < 0:
			_start(false)
			room = 5
			_build_segment()
			_set_state("play")
			music.play_world(current_world)
		_pick_context = "room"
		_set_state("pick")
		# `&or=N` (captures) : or de la partie, pour voir REFUSER payable ou éteint
		var gq := wsearch.find("or=")
		if gq >= 0:
			run_gold = int(wsearch.substr(gq + 3).get_slice("&", 0))
		_open_sanctuary()
		var sl2 := wsearch.find("sel=")
		if sl2 >= 0:
			picker.set("_sel", clampi(int(wsearch.substr(sl2 + 4).get_slice("&", 0)), 0, PACT_OFFER - 1))
	# `?autel` (captures) : l'autel du sanctuaire posé dans la salle en cours (avec `room=N`)
	# `?enigme=stele` (captures) : cette énigme de recoin (stele, lanterns, spirit) posée devant le héros
	# `?coffre` ou `?enigme=chest` (captures) : un coffre scellé devant le héros ; `fig=hook` sa figure,
	# `ouvre=2.5` le déverrouille au bout de 2,5 s, `rate=1.5` y rate un trait (secousse vermillon)
	var pq := wsearch.find("enigme=")
	var pqk := wsearch.substr(pq + 7).get_slice("&", 0) if pq >= 0 else ""
	if (pqk == "chest" or "coffre" in wsearch) and state == "play":
		meta.tuto_done = true  # (capture : pas de coach qui fige le jeu en attendant le premier trait)
		var fq := wsearch.find("fig=")
		var cpk := _spawn_sealed_chest(hero.position + Vector3(0, 0, -3.2), wsearch.substr(fq + 4).get_slice("&", 0) if fq >= 0 else "")
		var oq := wsearch.find("ouvre=")
		if oq >= 0:
			get_tree().create_timer(float(wsearch.substr(oq + 6).get_slice("&", 0)), true, false, true).timeout.connect(_unseal_chest.bind(cpk))
		var rq := wsearch.find("rate=")
		if rq >= 0:
			get_tree().create_timer(float(wsearch.substr(rq + 5).get_slice("&", 0)), true, false, true).timeout.connect(_puzzle_fail.bind(cpk, ""))
	elif pq >= 0 and state == "play":
		spawn_puzzle(pqk, hero.position + Vector3(0, 0, -3.4))
	# `?scelle=loop` (captures) : un yōkai scellé (figure loop ; `kind=kappa`) et deux autres, figés devant le héros ;
	# `ricoche=1.5` : un trait droit le traverse à 1,5 s (le coup ricoche) ; `brise=2` : à 2 s, le héros trace sa
	# figure à travers lui (le sceau se brise) ; `loin=1` : posés plus loin (distance de jeu ordinaire)
	var scq := wsearch.find("scelle=")
	if scq >= 0 and state == "play":
		meta.tuto_done = true
		if not "coach=seal" in wsearch:
			meta.coach_seen["seal"] = true  # (pas de leçon qui fige l'image, sauf demandée)
		var kq := wsearch.find("kind=")
		var sfig := wsearch.substr(scq + 7).get_slice("&", 0)
		_capture_sealed(sfig, wsearch.substr(kq + 5).get_slice("&", 0) if kq >= 0 else "", "loin=1" in wsearch)
		var rq2 := wsearch.find("ricoche=")
		if rq2 >= 0:
			get_tree().create_timer(float(wsearch.substr(rq2 + 8).get_slice("&", 0)), true, false, true).timeout.connect(_capture_seal_stroke.bind(false))
		var fq2 := wsearch.find("fige=")
		if fq2 >= 0:
			_cap_fige = float(wsearch.substr(fq2 + 5).get_slice("&", 0))
		var bq := wsearch.find("brise=")
		if bq >= 0:
			get_tree().create_timer(float(wsearch.substr(bq + 6).get_slice("&", 0)), true, false, true).timeout.connect(_capture_seal_stroke.bind(true))
	if "autel" in wsearch and state == "play":
		# comme après le dernier combat de l'étape : zones nettoyées, torii ouvert, puis l'autel
		for zi in arena.zones.size():
			arena.clear_zone(zi)
		arena.open_gate()
		_spawn_shrine()
		# le héros est posé devant l'autel (sinon il est au départ de l'étape, l'autel hors champ)
		hero.position = arena.clamp_walk(_shrine.position + Vector3(0, 0, 3.2), 0.5)
		_prev_hero = hero.position
		_cam_dz = _cam_target()
		arena.follow_camera(_cam_dz)
	# `?room=N&portes=fire,gold[&proche]` (maquette) : la sortie de l'étape remplacée par deux torii à sceaux
	if "portes" in wsearch and state == "play":
		load("res://scripts/seal_gate.gd").mock(self, wsearch)
	if "atelier" in wsearch:
		# `?atelier&tab=1` (captures) : l'onglet N ouvert (0 arbre, 1 estampes) ; `&fresh` : encre et arbre remis
		# à zéro (prix visibles) ; `&arbre` : arbre de démonstration (640 encre, quelques nœuds appris, `&voie` : la
		# branche VOIE entière) ;
		# `&noeud=v2` : ce nœud choisi (panneau du bas)
		if "fresh" in wsearch:
			meta.sumi = 60
			meta.tree = {}
		if "arbre" in wsearch:
			meta.sumi = 640
			meta.tree = {}
			for nid in ["l1", "l2", "l3", "e1", "e2", "p1", "v1"]:
				meta.tree[nid] = true
			if "voie" in wsearch:
				# `&arbre&voie` : toute la branche VOIE apprise (choix du rouleau de départ, sommet)
				for nid in ["v2", "v3", "v4", "v5", "v6", "vc"]:
					meta.tree[nid] = true
		var tb := wsearch.find("tab=")
		if tb >= 0:
			refuge.set("_tab", clampi(int(wsearch.substr(tb + 4).get_slice("&", 0)), 0, 1))
		_on_atelier()
		var nq := wsearch.find("noeud=")
		if nq >= 0:
			refuge.call("select_node", wsearch.substr(nq + 6).get_slice("&", 0))
	if "dojo" in wsearch:
		_start_dojo()
	if "tuto" in wsearch:
		# `?tuto` (web) : première partie du tutoriel en jeu
		meta.coach_reset()
		_start_first_run()
	# `?tuto&coach=figures` (captures) : cette bulle du coach dès que le jeu tourne (figures, ult…)
	var cf := wsearch.find("coach=")
	if cf >= 0:
		coach.force(wsearch.substr(cf + 6).get_slice("&", 0))
	# `?intro` (web) : ouvre directement les planches de l'intro (captures d'écran)
	if "intro" in wsearch:
		_open_intro(false)
		# `?intro&page=N` (captures) : la planche N (0..5) directement
		var ip := wsearch.find("page=")
		if ip >= 0:
			intro._go(clampi(int(wsearch.substr(ip + 5).get_slice("&", 0)), 0, 5))
	# `?mondes` (captures) : la carte des mondes ; `?mondes&reveal=N` : le monde N se révèle (rouleaux compris)
	if "mondes" in wsearch:
		var rv := wsearch.find("reveal=")
		if rv >= 0:
			var rid := clampi(int(wsearch.substr(rv + 7).get_slice("&", 0)), 1, Worlds.WORLDS.size())
			_open_worlds(rid - 1, rid, ["fire_burn", "water_tide", "fire_spark", "fire_kasha"])  # rouleaux de démonstration
		else:
			_open_worlds()
	if "pause" in wsearch:
		_set_state("play")
		_on_pause()
	# `?room=3&fig=wave` (captures) : le héros trace cette figure (bot_shapes) vers les ennemis toutes les 2,6 s,
	# sa technique débloquée (`&figlv=2` : niveau 2, et ses améliorations rares au niveau 1)
	var fq := wsearch.find("fig=")
	if fq >= 0:
		_force_fig = wsearch.substr(fq + 4).get_slice("&", 0)
		var fl := wsearch.find("figlv=")
		var flv := clampi(int(wsearch.substr(fl + 6).get_slice("&", 0)), 1, 3) if fl >= 0 else 1
		# `&figshot=<chemin>` : captures pendant les deux premières techniques (<chemin>_0.png…), puis sortie
		var fs := wsearch.find("figshot=")
		if fs >= 0:
			_fig_shot = wsearch.substr(fs + 8).get_slice("&", 0)
		var fid := String(PowerData.FIG_UNLOCK.get(_force_fig, ""))
		if fid != "":
			powers.levels[fid] = flv
			if flv >= 2:
				for pid in PowerData.POWERS.keys():
					if String(pid).begins_with(fid + "_"):
						powers.levels[String(pid)] = 1
	# `?carnet` (captures) : le dojo, carnet des figures ouvert
	if "carnet" in wsearch:
		_start_dojo()
		tuto.dojo.call("_toggle_book")
	# `?garderobe`, `?options` (captures) : ces écrans depuis l'accueil
	if "garderobe" in wsearch:
		_open_wardrobe()
	# `?depart[&voir=warefude][&sel=portes]` (captures) : l'écran AVANT LE DÉPART, ce pinceau affiché, ce charme touché
	if "depart" in wsearch:
		_ask_departure(current_world, false)
		var vq := wsearch.find("voir=")
		if vq >= 0:
			departure.call("show_brush", wsearch.substr(vq + 5).get_slice("&", 0))
		var cq := wsearch.find("sel=")
		if cq >= 0:
			departure.call("tap", "charm:" + wsearch.substr(cq + 4).get_slice("&", 0))
	if "options" in wsearch:
		_open_options()
	# `?victoire`, `?defaite` (captures) : la feuille de résultats d'une partie simulée (étape 5, chiffres de démo)
	if "victoire" in wsearch or "defaite" in wsearch:
		_start(false)
		room = 5
		stage_i = 2
		kills = 23
		max_chain = 14
		run_time = 312.0
		score.points = 61280 if "victoire" in wsearch else 18420
		shape_counts = {"loop": 12, "zigzag": 7, "straight": 31, "return": 4, "enso": 2}
		powers.levels = {"fire_burn": 2, "fire_spark": 1, "water_tide": 1, "fig_loop": 1}  # build de démo (médaillons, étiquettes)
		_ending_victory = "victoire" in wsearch
		_finish_run()
		menu.new_prints = ["w1_room"]  # estampe de démo (vignette des gains)
		if not _ending_victory:
			menu.killer_kind = "oni"  # coup fatal de démo (aucun ennemi en vie à cet instant)
	# ouverture à l'encre du tout premier démarrage (rejouable avec `?opening` ; `?opening&t=N` : depuis la
	# seconde N, pour les captures) ; jamais pour le robot ni les tests
	var auto_run := autoplay or "--bot" in OS.get_cmdline_user_args()
	# (désactivée au premier lancement, décision de Victor : on arrive directement sur l'accueil ; `?opening` la rejoue)
	if state == "menu" and not auto_run and "opening" in wsearch:
		var ot := wsearch.find("&t=")
		_open_opening(float(wsearch.substr(ot + 3).get_slice("&", 0)) if ot >= 0 else 0.0)
	# `-- --perf` : relevé par image (temps, nœuds, dessin, mémoire ; postes de script), jamais par défaut
	if "--perf" in OS.get_cmdline_user_args():
		var probe: Node = Perf.new()
		probe.set("main", self)
		add_child(probe)
	# `-- --bot [--mode=campaign|powers|ui|stress]` : le robot teste le jeu et signale les blocages (CI)
	if "--bot" in OS.get_cmdline_user_args():
		var bot_script: GDScript = load(BOT_PATH)
		_bot = bot_script.new()
		add_child(_bot)
		_bot.begin(self)
	_ticks = Time.get_ticks_usec()
	perf_mark("boot_ready", _ticks - t_ready)
	# la suite (squelettes, boss, préchauffage) vient après l'affichage de l'accueil
	_boot_async(t_ready)


## Captures `?fig=<figure>` : toutes les 2,6 s, le héros (intouchable) trace la figure vers l'ennemi le plus proche,
## comme le robot (BotShapes.plan : une orientation qui tient dans l'arène et reste reconnue).
func _force_fig_step(dt: float) -> void:
	if state != "play" or game_over or not is_instance_valid(hero):
		return
	hero.invuln = maxf(float(hero.invuln), 1.0)
	_force_fig_t -= dt
	if _force_fig_t > 0.0 or hero.dashing or touching:
		return
	_force_fig_t = 4.2 if _force_fig == "triangle" else 2.6
	var target: Vector3 = hero.position + Vector3(0, 0, -6)
	var near: Array = nearest_enemies(hero.position, 40.0, 1, null)
	if near.is_empty():
		# pas encore de combat : le héros avance vers la zone suivante (vers le haut de l'écran)
		hero.position = arena.clamp_walk(hero.position + Vector3(0, 0, -6), 0.5)
		_prev_hero = hero.position
		_force_fig_t = 0.4
		return
	else:
		target = near[0].position
		# le héros est posé à portée de la figure (sceau du triangle sur l'ennemi, kunai et vague devant lui)
		var reach := float({"triangle": 1.6, "point": 4.5, "wave": 2.2}.get(_force_fig, 4.0))
		var away := hero.position - target
		away.y = 0.0
		if away.length() > reach + 0.5:
			hero.position = arena.clamp_walk(target + away.normalized() * reach, 0.5)
			_prev_hero = hero.position
	var wps := BotShapes.plan(_force_fig, hero.position, target, Callable(self, "_clamp_point"))
	if wps.is_empty():
		return
	var s := InkStroke.new(hero.position, stroke_layer)
	stroke_layer += 1
	add_child(s)
	for p in wps:
		s.extend_to(_clamp_point(p), 40.0)
	if s.length < 0.7:
		s.queue_free()
		return
	_launch(s)


## Captures `&figshot=` : la technique en action (instants propres à chaque figure), deux fois, puis sortie.
func _fig_snap() -> void:
	var times: Array = [0.4, 1.6, 3.05] if _force_fig == "triangle" else [0.12, 0.35]
	var t0 := 0.0
	for t in times:
		await get_tree().create_timer(float(t) - t0, true, false, true).timeout
		t0 = float(t)
		await RenderingServer.frame_post_draw
		var path := "%s_%d.png" % [_fig_shot, _fig_shot_n]
		get_viewport().get_texture().get_image().save_png(path)
		print("FIGSHOT ", path)
		_fig_shot_n += 1
	if _fig_shot_n >= 2 * times.size():
		get_tree().quit()


## Capture d'écran (bureau, `-- --shot=fichier.png[:secondes]`) : attend, enregistre l'image, quitte.
func _shot(arg: String) -> void:
	var path := arg.get_slice(":", 0)
	var wait := float(arg.get_slice(":", 1)) if arg.contains(":") else 4.0
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit()


## Mesure de chargement : gardée pour le bilan du robot, et affichée (« BOT PERF <étape> <ms> ») avec lui.
func perf_mark(label: String, usec: int) -> void:
	var ms := float(usec) / 1000.0
	var e: Array = perf.get(label, [0, 0.0, 0.0])
	e[0] = int(e[0]) + 1
	e[1] = float(e[1]) + ms
	e[2] = maxf(float(e[2]), ms)
	perf[label] = e
	if _perf_on:
		print("BOT PERF %s %.1f" % [label, ms])


func _on_arena_perf(label: String, usec: int) -> void:
	perf_mark(label, usec)


## Démarrage progressif : l'accueil s'affiche d'abord. Ensuite, une chose par image : les squelettes
## partent se charger en arrière-plan, les scripts des boss se compilent, puis le préchauffage.
func _boot_async(t_ready: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # (la première image vient d'être dessinée)
	var now := Time.get_ticks_usec()
	perf_mark("boot_first_frame", now)  # depuis le lancement du moteur
	perf_mark("boot_ready_to_frame", now - t_ready)
	Enemy.request_models()
	var t_boss := 0
	for k in BOSS_PATHS.keys():
		var t0 := Time.get_ticks_usec()
		_boss_script(String(k))
		t_boss += Time.get_ticks_usec() - t0
		await get_tree().process_frame
	var t1 := Time.get_ticks_usec()
	_boss_script("uwabami")
	t_boss += Time.get_ticks_usec() - t1
	perf_mark("boss_scripts", t_boss)
	await get_tree().process_frame
	await _warmup()


## Les pièces accrochées aux os (cornes, masques, armes) ne suivent pas l'échelle miniature du préchauffage :
## on les cache et on en pose une copie libre, minuscule, à côté (même maillage, même matière : shader prêt).
func _warm_bones(e: Node3D, w: Node3D, at: Vector3) -> void:
	for ba in e.find_children("*", "BoneAttachment3D", true, false):
		var bn := ba as Node3D
		bn.visible = false
		for n in bn.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var c := MeshInstance3D.new()
			c.mesh = mi.mesh
			c.material_override = mi.material_override
			c.position = at
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.add_child(c)


## Script du boss `k` (compilé une seule fois, gardé).
func _boss_script(k: String) -> GDScript:
	var path: String = BOSS_PATHS.get(k, BOSS_BASE)
	if not _boss_scripts.has(path):
		_boss_scripts[path] = load(path)
	var scr: GDScript = _boss_scripts[path]
	return scr


const WARM_KINDS := ["oni", "kappa", "brute", "tate", "funa", "umibozu", "kitsunebi", "kitsunebi_s", "yukionna", "kasha", "kagebo",
	"kappa_yumi", "ika", "umi_nyobo", "kamaitachi", "tanuki", "kitsune_tsukai", "yuki_warashi", "tsurara", "onryo",
	"hinotama", "teppo", "tengu", "kanabo", "sumidama", "kasa", "moryo",
	"karasu", "yamabushi", "konoha", "kani", "ningyo", "fugu", "gaki", "gokusotsu", "shiryo",
	"shinobi", "shuriken", "kemuri", "kunoichi"]
var _warm_hide := Vector3(0, -6.0, 0)  # cachette sous le sol des pièces face caméra du préchauffage
const WARM_BUDGET_US := 8000  # temps de préchauffage par image (µs), au moins un ennemi


## Préchauffage : on affiche une fois, cachés sous le sol, un exemplaire de chaque ennemi et de chaque
## effet. Godot prépare ainsi leurs shaders pendant l'accueil au lieu de figer l'image en pleine partie.
## Étalé sur plusieurs images (quelques ennemis par image) : l'accueil reste fluide.
## Préchauffage : les particules en repère monde ignorent l'échelle 0,002 de la miniature et se dessinaient en
## grand devant la caméra (losange noir du brûleur du kasha) : on les passe en repère local, tout rétrécit.
## Même chose pour les nœuds « top_level » (zones d'attaque, bulles, nuages, étoiles) : hors de la hiérarchie,
## ils ignoraient l'échelle et se posaient à l'origine du monde, plein cadre (goutte noire au centre de l'arène
## quand un combat commençait avant la fin du préchauffage).
## Maillage d'une miniature de préchauffage dessinée en billboard : un quad de 1 mm portant la matière de surface.
func _warm_tiny(m: Mesh) -> Mesh:
	if m == null:
		return null
	var q := QuadMesh.new()
	q.size = Vector2(0.001, 0.001)
	if m.get_surface_count() > 0:
		q.material = m.surface_get_material(0)
	return q


## Une matière de ce maillage est en billboard sans garder l'échelle du nœud.
func _warm_unscaled(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	for si in mi.mesh.get_surface_count():
		var mm := mi.get_active_material(si) as BaseMaterial3D
		if mm != null and mm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED and not mm.billboard_keep_scale:
			return true
	return false


## Les pièces face caméra (billboard sans « keep scale » : particules de fumée et de braises, étoiles du butin,
## papiers des énigmes) perdent toute échelle dans le shader : dessinées en taille réelle à 2 m devant l'objectif
## (losange noir plein cadre pendant l'entrée d'un boss quand le préchauffage n'était pas fini). Elles sortent
## de la miniature et vont dans la cachette sous le sol (_warm_hide), avec les effets de vfx.warm.
func _warm_shrink(n: Node) -> void:
	if n is GPUParticles3D or n is CPUParticles3D:
		n.set("local_coords", true)
	# billboard sans « keep_scale » (particules, halos en quad) : le shader jette l'échelle du nœud, la miniature
	# se dessinait en grand (losanges noirs cernés d'or du kasha et du hinotama devant la barque de l'accueil, des
	# secondes durant) : maillage minuscule, même matière (le shader se compile toujours)
	if n is CPUParticles3D:
		var cp := n as CPUParticles3D
		cp.mesh = _warm_tiny(cp.mesh)
	elif n is GPUParticles3D:
		var gpp := n as GPUParticles3D
		gpp.draw_pass_1 = _warm_tiny(gpp.draw_pass_1)
	elif n is MeshInstance3D and _warm_unscaled(n as MeshInstance3D):
		var mi := n as MeshInstance3D
		mi.mesh = _warm_tiny(mi.mesh)
	if n is Node3D and n.top_level:
		n.top_level = false
		n.position = Vector3.ZERO
	if n is GeometryInstance3D and _bill_unscaled(n as GeometryInstance3D):
		var g := n as Node3D
		g.top_level = true
		g.global_position = _warm_hide
	for c in n.get_children():
		_warm_shrink(c)


## Vrai si une matière de `g` est tournée face caméra sans garder l'échelle du nœud.
func _bill_unscaled(g: GeometryInstance3D) -> bool:
	var mats: Array = [g.material_override]
	var mesh: Mesh = null
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		mesh = mi.mesh
		for i in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(i))
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	elif g is GPUParticles3D:
		mesh = (g as GPUParticles3D).draw_pass_1
	if mesh != null:
		for i in mesh.get_surface_count():
			mats.append(mesh.surface_get_material(i))
	for m in mats:
		var bm := m as BaseMaterial3D
		if bm != null and bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED and not bm.billboard_keep_scale:
			return true
	return false


func _warmup() -> void:
	var t_all := Time.get_ticks_usec()
	var t_cpu := 0
	var t_max := 0
	var t0 := Time.get_ticks_usec()
	var w := Node3D.new()
	# accroché à la caméra, en miniature : dessinés (donc shaders compilés) mais invisibles à l'œil,
	# où que soit le héros (la barque de l'accueil est en pleine mer)
	cam.add_child(w)
	w.position = Vector3(0, 0, -2.0)
	w.scale = Vector3.ONE * 0.002
	var fxp: Vector3 = hero.position + Vector3(0, -3.0, 0)  # effets sous l'eau opaque
	_warm_hide = fxp + Vector3(0, -3.0, 0)
	var x := -3.0
	for k in WARM_KINDS:
		var e := Enemy.new()
		e.setup(String(k), hero, self)
		e.position = Vector3(x, 0, 0)
		w.add_child(e)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		_warm_shrink(e)
		_warm_bones(e, w, Vector3(x, 0.4, 0))
		x += 0.35
		var spent := Time.get_ticks_usec() - t0
		if spent >= WARM_BUDGET_US:
			t_cpu += spent
			t_max = maxi(t_max, spent)
			await get_tree().process_frame
			if not is_instance_valid(w):
				return
			t0 = Time.get_ticks_usec()
	# une élite blindée : bulle de bouclier et aura d'or compilées d'avance
	var el := Enemy.new()
	el.setup("oni", hero, self)
	el.position = Vector3(0, 0, 0.6)
	w.add_child(el)
	el.process_mode = Node.PROCESS_MODE_DISABLED
	el.promote(["blinde"], false)
	el.give_shield(1.0)
	# un scellé : papier de l'ofuda, figure, hanko (pivot orienté caméra sans billboard de matière : il rétrécit
	# avec la miniature) ; éclats d'or du sceau brisé
	var se := Enemy.new()
	se.setup("oni", hero, self)
	se.position = Vector3(0.6, 0, 0.6)
	w.add_child(se)
	se.process_mode = Node.PROCESS_MODE_DISABLED
	se.set_seal("loop")
	se._seal.visible = true
	PuzzleArt._motes(w, Vector3(0.6, 1.0, 0.6), Toon.GOLD, 1, 0.5, 1.0, 0.2)
	var b := Node3D.new()
	w.add_child(b)
	Toon.part(b, Toon.sphere(0.3), Toon.mat_shared(Toon.VERMILION, true, 0.05), Vector3.ZERO)
	var st := InkStroke.new(Vector3.ZERO, 0)
	w.add_child(st)
	st.extend_to(Vector3(2, 0, 0), 3.0)
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = "0123456789.×"  # chiffres de dégâts et compteurs (plus de kanji en combat : UI v2)
	l.font_size = 120  # mêmes tailles que les textes de combat : glyphes prêts d'avance
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	w.add_child(l)
	var l2 := l.duplicate() as Label3D
	l2.font_size = 110
	w.add_child(l2)
	# énigmes des recoins (encre au pinceau shaders/puzzle_ink.gdshader, pierres, papiers, esprit),
	# coffre, source et stèle de défi, butin au sol : leurs matières ne servent nulle part ailleurs
	var pz_at := [Vector3(-3.0, 0, 2.0), Vector3(0.0, 0, 2.0), Vector3(3.0, 0, 2.0)]
	var pz_nodes: Array = []
	for at in pz_at:
		var pzn := Node3D.new()
		w.add_child(pzn)
		pzn.position = at
		pz_nodes.append(pzn)
	PuzzleArt.build_stele(pz_nodes[0], {}, _glyph_pts("loop", PuzzleArt.GLYPH_O, PuzzleArt.GLYPH_K), "loop")
	PuzzleArt.build_lanterns(pz_nodes[1], {}, [Vector3(1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(-1.5, 0, 0)], Vector3.ZERO)
	PuzzleArt.build_spirit(pz_nodes[2], {})
	var px := -3.0
	for pkind in ["chest", "spring", "elite", "sealed"]:
		var pn := _pocket_node("chest" if pkind == "sealed" else String(pkind), Vector3.ZERO)
		remove_child(pn)
		w.add_child(pn)
		pn.position = Vector3(px, 0, 4.0)
		px += 2.0
		if pkind == "sealed":
			# coffre scellé : chaîne, ofuda, sceau, plaque et son encre, gouttes du déverrouillage
			PuzzleArt.build_seal(pn, {}, "loop", 1.0)
			PuzzleArt.warm_seal(pn)
	pickups.warm(w, Vector3(-3.0, 0, 5.5))
	hazards.warm(w, Vector3(-3.0, 0, 7.0))  # matières des trous du sol
	# portes à deux sceaux : faces des dix sceaux rastérisées d'avance (cache de svg_tex), matières du sceau
	# (face, halo, rayons, ofuda) compilées sur une paire éveillée, porte gauche approchée
	for sk in SealGate.SCHOOLS + ["gold", "heart", "oni"]:
		SealGate.face_tex(String(sk))
	var sgw: Node3D = SealGate.new()
	sgw.set("kinds", ["fire", "oni"])
	w.add_child(sgw)
	sgw.position = Vector3(0, 0, 7.0)
	sgw.call("build")
	sgw.call("open")
	sgw.set("hover_force", 0)
	SealGate.marker(sgw, "heart")  # petit sceau au-dessus d'une source ou d'un défi de sceau
	_splash(fxp, Toon.VERMILION, 8)
	_blot(fxp, Toon.SUMI, 0.3, 0.5)
	_slash_mark(fxp, Vector3.FORWARD)
	vfx.impact(fxp, Vector3.FORWARD, true)
	vfx.kill_burst(fxp, Vector3.FORWARD, true)
	vfx.warm(fxp)  # effets riches des pouvoirs (pinceau, additifs, crête de vague)
	preload("res://scripts/boss_shrine.gd").warm(w)  # arènes de gardien et de boss : motif du sol, lots, halos, tōrō
	_warm_shrink(w)
	# libéré quoi qu'il arrive (même arbre en pause ou temps ralenti : sinon la miniature restait des secondes)
	get_tree().create_timer(1.2, true, false, true).timeout.connect(w.queue_free)
	var spent_end := Time.get_ticks_usec() - t0
	t_cpu += spent_end
	t_max = maxi(t_max, spent_end)
	perf_mark("warmup", t_cpu)  # temps de calcul total (réparti sur plusieurs images)
	perf_mark("warmup_step_max", t_max)  # la plus longue image de préchauffage
	perf_mark("warmup_span", Time.get_ticks_usec() - t_all)  # du début à la fin (images comprises)
	warmed = true
	if Perf.on:
		print("PERF préchauffage fini t=%.1f" % Time.get_unix_time_from_system())


# ------------------------------------------------------------------ états

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		record = int(cfg.get_value("game", "best", 0))
		menu.muted = bool(cfg.get_value("game", "muted", false))
		sfx.haptics = String(cfg.get_value("settings", "vibration", "on")) == "on"
		# avant la version 1, le pad était le contrôle par défaut : on repasse une fois « sur l'écran »
		if int(cfg.get_value("settings", "version", 0)) >= SETTINGS_V:
			ctrl_pref = String(cfg.get_value("settings", "control", "screen"))
		pad_size = String(cfg.get_value("settings", "pad_size", "m"))
		pad_show = String(cfg.get_value("settings", "pad_show", "start"))
	if not ctrl_pref in ["screen", "pad"]:
		ctrl_pref = "screen"
	if not pad_size in ["s", "m", "l"]:
		pad_size = "m"
	if not pad_show in ["always", "start", "never"]:
		pad_show = "start"
	ctrl_mode = ctrl_pref  # le seul moment où le mode change : au lancement
	if "--bot" in OS.get_cmdline_user_args():
		ctrl_mode = "screen"  # le robot du CI joue toujours au doigt sur l'écran (sans toucher au choix enregistré)
	hud.pad_alpha = 0.0 if pad_show == "never" else 1.0
	menu.best = stage_of(record)
	menu.sumi = meta.sumi
	AudioServer.set_bus_mute(0, menu.muted)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", record)
	cfg.set_value("game", "muted", menu.muted)
	cfg.set_value("settings", "vibration", "on" if sfx.haptics else "off")
	cfg.set_value("settings", "version", SETTINGS_V)
	cfg.set_value("settings", "control", ctrl_pref)
	cfg.set_value("settings", "pad_size", pad_size)
	cfg.set_value("settings", "pad_show", pad_show)
	cfg.save(SAVE_PATH)


func _set_state(s: String) -> void:
	if s != "menu" and state == "menu":
		_home_scene_end()
	state = s
	_state_t = 0.0
	hud.visible = not s in ["menu", "worlds", "sail"]
	_show_stage(not s in ["menu", "worlds", "sail"])
	match s:
		"menu":
			_home_select(current_world)  # le sélecteur repart du monde du joueur
			menu.show_mode("home")
			music.play_menu()
			_board_boat()
		"intro":
			# rideau d'encre : la barque disparaît, le héros apparaît directement dans le monde (_intro_swap)
			menu.show_mode("hidden")
			_intro_swapped = false
		"play":
			menu.show_mode("hidden")
			if room == 0:
				music.play_world(current_world)
				var wd: Dictionary = Worlds.world(current_world)
				if in_hub:
					hud.banner("SANCTUAIRE", "", wd.color, 2.6)
				else:
					hud.banner(String(wd.name).to_upper(), "ÉTAPE 1", wd.color, 2.4)
		"over":
			menu.show_mode("over")
		"worlds", "sail":
			menu.show_mode("hidden")


func _on_play() -> void:
	sfx.play("slash", 0.8, -4.0)
	if state == "over":
		_start()
		_set_state("play")
	elif not meta.intro_done:
		# tout premier lancement : les planches d'abord, puis le monde 1
		_open_intro(false)
	elif meta.coach_first_run():
		# toute première partie (ou tutoriel à revoir) : droit au monde 1, le coach explique en jouant
		_start_first_run()
	else:
		_home_play()  # droit dans le monde choisi sur l'accueil (scellé : la carte)


## Choix du monde sur le rouleau, centré sur `center` (par défaut le monde en cours). `reveal` : monde que
## la victoire vient d'ouvrir (le rouleau se déroule jusqu'à lui et brise son sceau), `reveal_powers` :
## rouleaux débloqués avec lui (aperçu sur sa carte).
func _open_worlds(center := -1, reveal := 0, reveal_powers := []) -> void:
	_set_state("worlds")
	var unlocked := _unlocked_count()
	# records : meilleur combat atteint -> meilleure étape
	var best := {}
	for k in meta.world_best.keys():
		best[k] = stage_of(int(meta.world_best[k]))
	var c: int = center if center >= 1 else current_world
	worldmap.scores = meta.world_score.duplicate()
	worldmap.won_top = int(meta.won_top)
	worldmap.open(Worlds.WORLDS, unlocked, best, c, STAGE_PLAN.size(), meta.owned_prints, reveal, reveal_powers)


## Résultats d'une victoire : « DÉCOUVRIR LE MONDE SUIVANT » (le rouleau part du monde vaincu et révèle le
## nouveau) ou « MONDE SUIVANT » (déjà ouvert : la carte s'ouvre sur lui).
func _on_next_world() -> void:
	sfx.play("whoosh", 1.0, -4.0)
	var prev := current_world
	var reveal := int(menu.unlock_world)
	var ups: Array = menu.unlock_powers
	var reveal_powers: Array = ups.duplicate()
	var nxt := mini(prev + 1, Worlds.WORLDS.size())
	_start()
	_board_boat()
	music.play_menu()
	if reveal > 0:
		_open_worlds(prev, reveal, reveal_powers)
	else:
		_open_worlds(nxt)


## Sceau du monde révélé brisé sur la carte.
func _on_seal_broken(_id: int) -> void:
	sfx.play("strike", 1.1, -3.0)
	sfx.play("levelup", 1.0, -4.0)
	feel("hit")


func _on_world_chosen(id: int) -> void:
	sfx.play("slash", 0.9, -4.0)
	_ask_departure(id, true)


## Sous le rideau d'encre : monde choisi construit, barque cachée, héros posé au départ.
func _intro_swap() -> void:
	_intro_swapped = true
	arena.hide_shore(false)
	if _intro_world > 0:
		if _intro_world != current_world:
			apply_world(_intro_world)
		_start()
		_intro_world = 0
	if menu_boat != null:
		menu_boat.visible = false
	music.play_world(current_world)
	hero.position = arena.start
	hero.face(Vector3(0, 0, -1))
	hero.snap_facing()
	_splash(hero.position + Vector3(0, 0.3, 0), Toon.SUMI, 10)
	sfx.play("whoosh", 1.2, -6.0)


func _on_pause() -> void:
	if state != "play":
		return
	_cancel_stroke()
	var w: Dictionary = Worlds.world(current_world)
	menu.world_kanji = String(w.kanji)
	menu.world_color = w.color
	menu.stat_room = maxi(stage_i + 1, 1)
	menu.stat_combo = chain
	menu.stat_score = int(score.points)
	menu.stat_time = run_time
	menu.pause_powers = powers.levels.keys()
	hud.pause_enabled = false
	state = "paused"
	menu.show_mode("pause")


## Téléphone : bouton Retour ou appli mise en arrière-plan -> pause (au lieu de quitter en pleine partie).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _bot != null:
			return
		if what != NOTIFICATION_WM_GO_BACK_REQUEST and state in ST_HOLD:
			_pause_pending = true  # pause dès que la partie reprend la main
		if menu == null or hud == null:
			return
		if what == NOTIFICATION_WM_GO_BACK_REQUEST and recap != null and recap.visible:
			recap.visible = false
			_on_recap_closed()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and opening != null and opening.visible:
			opening.call("skip")
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and intro != null and intro.visible:
			intro.close()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and wardrobe != null and wardrobe.visible:
			wardrobe.call("close")
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and departure != null and departure.visible:
			departure.call("close")
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and bestiary != null and bestiary.visible:
			bestiary.call("back")
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "menu":
			get_tree().quit()  # Retour depuis l'accueil : on quitte, comme toute appli
		else:
			_on_pause()


## Tutoriel guidé : arène calme, mannequins, héros intouchable, élan illimité.
## Première partie du tutoriel : droit au monde 1 (sanctuaire puis étape 1), le coach explique en jouant ;
## les deux premiers combats sont adoucis (gentle).
func _start_first_run() -> void:
	sfx.play("slash", 0.9, -4.0)
	if current_world != 1:
		apply_world(1)
	_start()
	gentle = true
	_set_state("intro")


## Ouverture à l'encre (opening.gd) par-dessus l'accueil caché : la mer et la barque attendent dessous.
func _open_opening(start := 0.0) -> void:
	menu.show_mode("hidden")
	opening.call("play", start)


## Le papier de l'ouverture s'efface : l'accueil se peint dessous (titre, JOUER), comme à chaque retour.
func _on_opening_reveal() -> void:
	if state == "menu":
		menu.show_mode("home")


func _on_opening_finished() -> void:
	meta.opening_done = true
	meta.save_data()
	if state == "menu" and String(menu.mode) != "home":
		menu.show_mode("home")


## Intro illustrée, sur l'accueil (la barque continue de tanguer derrière).
func _open_intro(from_help: bool) -> void:
	sfx.play("whoosh", 1.1, -6.0)
	menu.show_mode("hidden")
	intro.open(from_help)


## "done" : fin des planches au premier lancement -> monde 1 avec le coach (ou le large) ;
## "tuto" : depuis le « ? », le tutoriel en jeu recommence ; "back" : retour à l'accueil.
func _on_intro_finished(action: String) -> void:
	if action == "tuto":
		meta.coach_reset()
		meta.save_data()
		_start_first_run()
	elif action == "done":
		meta.intro_done = true
		meta.save_data()
		if meta.coach_first_run():
			_start_first_run()
		else:
			_open_worlds()
	else:
		menu.show_mode("home")


## Dojo : entraînement libre aux figures (mêmes réglages que le tutoriel : héros intouchable, encre infinie,
## techniques prêtées), mené par le tutoriel en mode libre.
func _start_dojo() -> void:
	sfx.play("slash", 0.9, -4.0)
	menu.show_mode("hidden")
	_start(false, true)
	# dojo : arène entièrement plate (disposition des boss), tout l'espace pour s'entraîner
	arena.build_room(ROOMS, ROOMS, randi(), MINI_ROOM)
	hero.position = arena.start
	_prev_hero = hero.position
	_fit_camera()
	_set_state("tuto")
	hero.face(Vector3(0, 0, -1))
	hero.guard_t = 99999.0
	hud.banner("DOJO", "", Toon.PRUSSIAN, 1.6)
	tuto.begin_dojo()


func _on_dojo_finished() -> void:
	_start()
	_set_state("menu")


## Mannequin d'entraînement (tutoriel) : ne bouge pas, n'attaque pas.
func spawn_dummy(pos: Vector3) -> void:
	var e := Enemy.new()
	e.setup("oni", hero, self)
	e.dummy = true
	e.position = arena.clamp_walk(pos, 0.8)
	add_child(e)
	e.set_meta("max_hp", e.hp)
	enemies.append(e)


func _on_restart() -> void:
	sfx.play("slash", 0.8, -4.0)
	_start()
	_set_state("play")


func _on_resume() -> void:
	menu.show_mode("hidden")
	state = "play"


func _on_worldmap_closed() -> void:
	_set_state("menu")


func _on_atelier() -> void:
	sfx.play("whoosh", 0.8)
	menu.show_mode("hidden")
	refuge.open()


func _on_refuge_closed() -> void:
	menu.sumi = meta.sumi
	_start()
	_set_state("menu")


func _on_home() -> void:
	_save_bestiary()
	_start()
	_set_state("menu")


func _open_options() -> void:
	_options_from = "pause" if state == "paused" else "menu"
	options.values = {"sound": "off" if menu.muted else "on", "vibration": "on" if sfx.haptics else "off",
		"control": ctrl_pref, "pad_size": pad_size, "pad_show": pad_show}
	options.active_control = ctrl_mode
	if not meta.tuto_done:
		options.values["tuto"] = "replay"  # tutoriel en cours ou à revoir : la case reste cochée
	menu.show_mode("hidden")
	options.open()


func _on_option(key: String, value: String) -> void:
	match key:
		"sound":
			menu.muted = value == "off"
			AudioServer.set_bus_mute(0, menu.muted)
		"vibration":
			sfx.haptics = value == "on"
		"control":
			ctrl_pref = value  # au prochain lancement (la carte d'options le rappelle)
		"pad_size":
			pad_size = value
			if ctrl_mode == "pad":
				_fit_camera()  # le pad change de hauteur : l'arène se recadre au-dessus
		"pad_show":
			pad_show = value
		"tuto":
			# « Revoir le tutoriel » : les bulles du coach reviendront (JOUER mène droit au monde 1)
			meta.coach_reset()
			meta.save_data()
			coach.clear()
	sfx.play("empty", 1.4, -6.0)
	feel("kill")
	_save()


## Récapitulatif des pouvoirs : depuis la pause, ou en touchant les sceaux du HUD (met le jeu en pause).
func _open_recap() -> void:
	if state == "play":
		_cancel_stroke()
		hud.pause_enabled = false
		state = "paused"
		_recap_from = "play"
	elif state == "paused":
		_recap_from = "pause"
	else:
		return
	menu.show_mode("hidden")
	sfx.play("whoosh", 1.1, -6.0)
	recap.open(powers)


func _on_recap_closed() -> void:
	if _recap_from == "play":
		state = "play"
	else:
		menu.show_mode("pause")


func _on_options_closed() -> void:
	menu.show_mode("pause" if _options_from == "pause" else "home")


func _on_sound(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)
	_save()


## Plan d'accueil : derrière le héros debout à la proue de sa barque, face au paysage du monde.
## Lente dérive latérale (le lointain glisse moins vite que la barque : parallaxe).
func _menu_transform() -> Transform3D:
	var bp := menu_boat.position if menu_boat != null else MENU_BOAT
	bp.y = 0.0
	var dx := sin(_drift_t * 0.11) * 0.55
	var dy := sin(_drift_t * 0.07 + 1.3) * 0.12
	# en retrait et en hauteur : toute la barque tient entre le titre et JOUER, le décor respire
	# barque au centre de l'écran (demandé) : caméra dans l'axe, un peu plus en retrait
	var pos := bp + Vector3(0.35 + dx, 3.1 + dy, 8.2)
	return Transform3D(Basis(), pos).looking_at(bp + Vector3(0.05 + dx * 0.25, 0.3, -6.0), Vector3.UP)


## Garde-robe : la caméra passe sur le flanc de la proue, le héros se tourne vers elle (haut de l'écran).
func _wardrobe_transform() -> Transform3D:
	var hp := hero.position if is_instance_valid(hero) else MENU_BOAT
	var pos := hp + WARDROBE_DIR * 3.3 + Vector3(0, 1.05, 0)
	return Transform3D(Basis(), pos).looking_at(hp + Vector3(0, 0.1, 0), Vector3.UP)


## Barque de l'accueil (sampan) : coque courbe, pont de planches, toit de natte (tomaya) sur quatre
## poteaux, rame posée, rouleau de corde, perche et lanterne de papier à la proue. Tout le bois est un
## seul maillage (couleurs de sommets) ; la lanterne se balance à part, avec la seule lumière.
func _build_menu_boat() -> void:
	menu_boat = Node3D.new()
	world.add_child(menu_boat)
	menu_boat.position = MENU_BOAT
	var wood := Toon.mat(Color.WHITE, true, 0.022)
	wood.vertex_color_use_as_albedo = true
	wood.vertex_color_is_srgb = true
	var body := MeshInstance3D.new()
	body.mesh = _boat_mesh()
	body.material_override = wood
	menu_boat.add_child(body)
	# lanterne : pivot au bout de la perche, elle pend et se balance
	_boat_lantern = Node3D.new()
	menu_boat.add_child(_boat_lantern)
	_boat_lantern.position = Vector3(-0.42, 1.36, -1.93)
	var dark := Toon.mat_shared(Color("#2E221B"), false)
	Toon.part(_boat_lantern, Toon.box(Vector3(0.012, 0.16, 0.012)), dark, Vector3(0, -0.08, 0))
	_boat_lan_mat = Toon.mat(Color("#F4C27A"), true, 0.015)
	_boat_lan_mat.emission_enabled = true
	_boat_lan_mat.emission = Color("#FF9E45")
	_boat_lan_mat.emission_energy_multiplier = 1.4
	var lb := Toon.part(_boat_lantern, Toon.sphere(0.12), _boat_lan_mat, Vector3(0, -0.33, 0), Vector3(1, 1.32, 1))
	lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sy in [-1.0, 1.0]:
		var cap := Toon.part(_boat_lantern, Toon.cyl(0.07, 0.07, 0.035, 10), dark, Vector3(0, -0.33 + 0.165 * float(sy), 0))
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _light_mode:
		# une seule lumière, courte portée, sans ombre (téléphone : l'émission et la lueur suffisent)
		_boat_light = OmniLight3D.new()
		_boat_light.position = Vector3(0, -0.33, 0)
		_boat_light.light_color = Color(1.0, 0.72, 0.42)
		_boat_light.light_energy = 0.7
		_boat_light.omni_range = 2.4
		_boat_light.shadow_enabled = false
		_boat_lantern.add_child(_boat_light)
	# sillage d'écume autour de la coque
	var wake := _disc(menu_boat, 1.0, Toon.flat(Color(Toon.FOAM, 0.5)), -0.53)
	wake.scale = Vector3(0.85, 1, 2.2)
	# rides : anneaux plats qui s'élargissent et s'effacent (posés sur l'eau, pas sur la barque)
	var ring := _boat_ring_mesh()
	for i in 5:
		var rm := Toon.flat(Color(Toon.FOAM, 0.0))
		var mi := Toon.part(world, ring, rm, MENU_BOAT, Vector3.ONE)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_boat_rings.append([mi, rm, RING_LIFE])
	# oiseaux de passage, de temps en temps
	_boat_birds = Node3D.new()
	world.add_child(_boat_birds)
	var gull: Mesh = Worlds._gull_mesh()
	for i in 3:
		var g := MeshInstance3D.new()
		g.mesh = gull
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.position = Vector3(-0.9 * i, 0.35 * float(i % 2) - 0.1 * i, 0.6 * i)
		g.scale = Vector3.ONE * (1.3 - 0.15 * i)
		_boat_birds.add_child(g)
	_boat_birds.visible = false
	menu_boat.visible = false


## Bois de la barque, en un seul maillage.
func _boat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hull := Color("#5E4130")
	var wale := Color("#3A2A20")
	var inner := Color("#8A6A48")
	var rim := Color("#2E221B")
	var nz := 26
	var nphi := 10
	var half := BOAT_LEN * 0.5
	# coque : ellipses (largeur, haut du plat-bord, quille) le long de z, proue relevée vers -z
	var outer_p: Array = []
	var outer_n: Array = []
	var outer_c: Array = []
	var inner_p: Array = []
	var inner_n: Array = []
	var inner_c: Array = []
	for i in nphi + 1:
		var phi := -PI / 2.0 + PI * float(i) / float(nphi)
		var rp := PackedVector3Array()
		var rn := PackedVector3Array()
		var rc := PackedColorArray()
		var ip := PackedVector3Array()
		var inn := PackedVector3Array()
		var ic := PackedColorArray()
		for j in nz + 1:
			var z := -half + BOAT_LEN * float(j) / float(nz)
			var hs := _boat_section(z / half)
			var w: float = hs.x
			var top: float = hs.y
			var hh: float = hs.y - hs.z
			rp.append(Vector3(w * sin(phi), top - hh * cos(phi), z))
			rn.append(Vector3(hh * sin(phi), -w * cos(phi), 0).normalized())
			rc.append(wale if absf(phi) > 1.2 else hull)
			var wi := maxf(w - 0.05, 0.01)
			var hi := hh - 0.05
			ip.append(Vector3(wi * sin(phi), top - hi * cos(phi), z))
			inn.append(-Vector3(hi * sin(phi), -wi * cos(phi), 0).normalized())
			ic.append(inner)
		outer_p.append(rp)
		outer_n.append(rn)
		outer_c.append(rc)
		inner_p.append(ip)
		inner_n.append(inn)
		inner_c.append(ic)
	_st_grid(st, outer_p, outer_n, outer_c, false)
	_st_grid(st, inner_p, inner_n, inner_c, true)
	# plat-bord : bande du dessus entre la coque et sa face intérieure (gauche : i = 0, droite : i = nphi)
	for side in [0, nphi]:
		var si: int = side
		var po: PackedVector3Array = outer_p[si]
		var pin: PackedVector3Array = inner_p[si]
		var ups := PackedVector3Array()
		var cc := PackedColorArray()
		for j in nz + 1:
			ups.append(Vector3.UP)
			cc.append(rim)
		_st_grid(st, [po, pin], [ups, ups], [cc, cc], si == 0)
	# pont : planches en travers, à la largeur intérieure de la coque
	var deck_y := -0.27
	var z0 := -1.5
	var k := 0
	while z0 < 1.62:
		var hs2 := _boat_section((z0 + 0.09) / half)
		var top2: float = hs2.y
		var hi2: float = hs2.y - hs2.z - 0.05
		var wi2: float = maxf(hs2.x - 0.05, 0.01)
		var q := clampf((top2 - deck_y) / maxf(hi2, 0.01), 0.0, 1.0)
		var dw := wi2 * sqrt(1.0 - q * q) - 0.01
		if dw > 0.08:
			var pc := Color("#B88A5A") if k % 2 == 0 else Color("#A97E50")
			_st_obox(st, Vector3(0, deck_y, z0 + 0.09), Basis(), Vector3(dw, 0.02, 0.09), pc)
		z0 += 0.2
		k += 1
	# toit de natte (tomaya) : voûte sur quatre poteaux, à la poupe (sous la ligne de vue de la caméra)
	var post := Color("#3B2C22")
	for px in [-0.46, 0.46]:
		for pz in [0.52, 1.38]:
			_st_obox(st, Vector3(float(px), 0.235, float(pz)), Basis(), Vector3(0.025, 0.49, 0.025), post)
	var ra := 0.52
	var rh := 0.3
	var base := 0.72
	var na := 10
	var nzr := 7
	var roof_p: Array = []
	var roof_n: Array = []
	var roof_c: Array = []
	var roof_ip: Array = []
	var roof_in: Array = []
	for i in na + 1:
		var al := -PI / 2.0 + PI * float(i) / float(na)
		var rp2 := PackedVector3Array()
		var rn2 := PackedVector3Array()
		var rc2 := PackedColorArray()
		var ip2 := PackedVector3Array()
		var in2 := PackedVector3Array()
		var nrm := Vector3(rh * sin(al), ra * cos(al), 0).normalized()
		for j in nzr + 1:
			var z := 0.4 + 1.1 * float(j) / float(nzr)
			rp2.append(Vector3(ra * sin(al), base + rh * cos(al), z))
			rn2.append(nrm)
			rc2.append(Color("#C2A56A") if j % 2 == 0 else Color("#A68C55"))
			ip2.append(Vector3((ra - 0.03) * sin(al), base + (rh - 0.03) * cos(al), z))
			in2.append(-nrm)
		roof_p.append(rp2)
		roof_n.append(rn2)
		roof_c.append(rc2)
		roof_ip.append(ip2)
		roof_in.append(in2)
	_st_grid(st, roof_p, roof_n, roof_c, true)
	_st_grid(st, roof_ip, roof_in, roof_c, false)
	# rame posée en travers de la poupe, pelle au-dessus de l'eau
	var oar := Color("#9C7448")
	var oa := Vector3(0.12, -0.2, 0.95)
	var ob := Vector3(0.55, -0.12, 2.35)
	var od := (ob - oa).normalized()
	_st_beam(st, oa, ob, Vector2(0.025, 0.025), oar)
	_st_beam(st, ob - od * 0.42, ob + od * 0.08, Vector2(0.075, 0.012), oar.darkened(0.15))
	# rouleau de corde sur le pont
	_st_torus(st, Vector3(-0.3, -0.225, 1.2), 0.13, 0.028, Color("#C9B48A"))
	_st_torus(st, Vector3(-0.3, -0.175, 1.2), 0.1, 0.026, Color("#B8A276"))
	# perche de la lanterne (à la proue, à gauche du héros) et son bras
	_st_beam(st, Vector3(-0.42, -0.25, -1.5), Vector3(-0.42, 1.38, -1.5), Vector2(0.022, 0.022), rim)
	_st_beam(st, Vector3(-0.42, 1.34, -1.48), Vector3(-0.42, 1.39, -1.97), Vector2(0.016, 0.016), rim)
	return st.commit()


## Coupe de la coque en s (-1 proue … 1 poupe) : (demi-largeur, haut du plat-bord, quille).
func _boat_section(s: float) -> Vector3:
	var a := clampf(absf(s), 0.0, 1.0)
	var w := maxf(BOAT_BEAM * sqrt(maxf(0.0, 1.0 - pow(a, 2.2))), 0.035)
	var top := -0.13 + (0.5 if s < 0.0 else 0.3) * pow(a, 3.0)
	var bot := -0.6 + 0.3 * a * a
	return Vector3(w, top, bot)


## Quadrillage de sommets (rangées i, colonnes j) en triangles : face extérieure selon i × j,
## `flip` pour l'autre sens (faces intérieures).
func _st_grid(st: SurfaceTool, pts: Array, nrm: Array, cols: Array, flip: bool) -> void:
	var order: Array = [0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]
	for i in pts.size() - 1:
		var r0: PackedVector3Array = pts[i]
		var r1: PackedVector3Array = pts[i + 1]
		var n0: PackedVector3Array = nrm[i]
		var n1: PackedVector3Array = nrm[i + 1]
		var c0: PackedColorArray = cols[i]
		var c1: PackedColorArray = cols[i + 1]
		for j in r0.size() - 1:
			var vp: Array = [r0[j], r0[j + 1], r1[j + 1], r1[j]]
			var vn: Array = [n0[j], n0[j + 1], n1[j + 1], n1[j]]
			var vc: Array = [c0[j], c0[j + 1], c1[j + 1], c1[j]]
			for o in order:
				var oi: int = o
				var cv: Color = vc[oi]
				var nv: Vector3 = vn[oi]
				var pv: Vector3 = vp[oi]
				st.set_color(cv)
				st.set_normal(nv)
				st.add_vertex(pv)


## Pavé orienté (base `b`, demi-tailles `h`) à couleur de sommet (faces dans le sens horaire vu de dehors).
func _st_obox(st: SurfaceTool, c: Vector3, b: Basis, h: Vector3, col: Color) -> void:
	var fs: Array = [[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]
	for f in fs:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := n * absf(n.dot(h))
		var du := u * absf(u.dot(h))
		var dv := v * absf(v.dot(h))
		var nn := b * n
		for pv in [o - du - dv, o - du + dv, o + du + dv, o - du - dv, o + du + dv, o + du - dv]:
			var p: Vector3 = pv
			st.set_color(col)
			st.set_normal(nn)
			st.add_vertex(c + b * p)


## Poutre de a à b (section : demi-tailles sec.x, sec.y).
func _st_beam(st: SurfaceTool, a: Vector3, b: Vector3, sec: Vector2, col: Color) -> void:
	var ax := b - a
	var ln := ax.length()
	if ln < 0.001:
		return
	var fz := ax / ln
	var side := Vector3.UP.cross(fz)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := fz.cross(side)
	_st_obox(st, (a + b) * 0.5, Basis(side, up, fz), Vector3(sec.x, sec.y, ln * 0.5), col)


## Tore posé à plat (corde enroulée).
func _st_torus(st: SurfaceTool, c: Vector3, big: float, r: float, col: Color) -> void:
	var npsi := 6
	var nth := 16
	var pts: Array = []
	var nrm: Array = []
	var cols: Array = []
	for i in npsi + 1:
		var psi := TAU * float(i) / float(npsi)
		var rp := PackedVector3Array()
		var rn := PackedVector3Array()
		var rc := PackedColorArray()
		for j in nth + 1:
			var th := TAU * float(j) / float(nth)
			var d := Vector3(cos(th), 0, sin(th))
			rp.append(c + d * (big + r * cos(psi)) + Vector3(0, r * sin(psi), 0))
			rn.append((d * cos(psi) + Vector3(0, sin(psi), 0)).normalized())
			rc.append(col if j % 2 == 0 else col.darkened(0.12))
		pts.append(rp)
		nrm.append(rn)
		cols.append(rc)
	_st_grid(st, pts, nrm, cols, false)


## Anneau plat (ride sur l'eau), rayon 1.
func _boat_ring_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 28
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		for p in [o0, o1, o1 * 0.88, o0, o1 * 0.88, o0 * 0.88]:
			var pv: Vector3 = p
			st.set_normal(Vector3.UP)
			st.add_vertex(pv)
	return st.commit()


## Particules de l'accueil autour de la barque, selon le monde : pétales, lucioles, neige, braises, papier.
func _build_boat_fx(id: int) -> void:
	if is_instance_valid(_boat_fx):
		_boat_fx.queue_free()
	_boat_fx = Node3D.new()
	_boat_fx.name = "BoatFx"
	world.add_child(_boat_fx)
	_boat_fx_world = id
	var k := 0.6 if _light_mode else 1.0
	var c := MENU_BOAT + Vector3(0, 1.4, -3.0)
	var ext := Vector3(4.0, 1.6, 4.5)
	if Worlds.boat_fx(id, _boat_fx, c, ext, k):
		return  # mondes 6 à 8 : aiguilles de cèdre, bulles, âmes
	match clampi(id, 1, 5):
		1:
			Decor.petals(_boat_fx, AABB(MENU_BOAT + Vector3(-4.0, -0.4, -7.5), Vector3(8.0, 3.6, 9.0)))
		2:
			var p := Worlds._emitter(_boat_fx, "Fireflies", c + Vector3(0, -0.4, 0), ext, int(16 * k), 5.0, Worlds._sphere_mesh("fire", 0.06, true))
			p.direction = Vector3.UP
			p.spread = 180.0
			p.gravity = Vector3(0, 0.04, 0)
			p.initial_velocity_min = 0.06
			p.initial_velocity_max = 0.2
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.4
			p.color_ramp = Worlds._fade(0.25, 0.7)
			p.color_initial_ramp = Worlds._ramp([Color(0.85, 1.0, 0.55), Color(1.0, 0.92, 0.6), Color(0.7, 1.0, 0.7)], false)
			p.emitting = true
		3:
			var p := Worlds._emitter(_boat_fx, "Snow", c + Vector3(-1.0, 1.6, 0), Vector3(ext.x + 1.0, 0.05, ext.z), int(46 * k), 4.6, Worlds._sphere_mesh("snow", 0.035, false))
			p.direction = Vector3(0.35, -1.0, 0.1)
			p.spread = 8.0
			p.gravity = Vector3(0.04, -0.12, 0)
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.1
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.5
			p.color_ramp = Worlds._fade(0.08, 0.9)
			p.emitting = true
		4:
			var p := Worlds._emitter(_boat_fx, "Embers", c + Vector3(0, -1.6, 0), Vector3(ext.x, 0.1, ext.z), int(22 * k), 4.0, Worlds._quad_mesh("ember", Vector2(0.07, 0.07), true))
			p.direction = Vector3.UP
			p.spread = 25.0
			p.gravity = Vector3(0.08, 0.25, 0.02)
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 0.9
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.4
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
			g.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.8, 0.45, 1.0), Color(1.0, 0.45, 0.15, 0.85), Color(0.5, 0.1, 0.05, 0.0)])
			p.color_ramp = g
			p.emitting = true
		_:
			var p := Worlds._emitter(_boat_fx, "Paper", c + Vector3(-2.0, 0.4, 0), ext, int(20 * k), 7.0, Worlds._quad_mesh("paper", Vector2(0.13, 0.1), false))
			p.direction = Vector3(1.0, 0.12, 0.2)
			p.spread = 25.0
			p.gravity = Vector3(0.1, -0.03, 0.02)
			p.initial_velocity_min = 0.25
			p.initial_velocity_max = 0.5
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -150.0
			p.angular_velocity_max = 150.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.5
			p.color_ramp = Worlds._fade(0.1, 0.85)
			p.color_initial_ramp = Worlds._ramp([Toon.WASHI, Color("#F6F0E2"), Toon.SUMI], true)
			p.emitting = true


## Accueil, carte des mondes, départ en barque : seul le décor du monde (fond, mer) se voit ; la salle
## (plateformes du sanctuaire, torii) n'apparaît qu'au vol de la caméra vers elle (intro) et en jeu.
func _show_stage(on: bool) -> void:
	if arena != null:
		var rr = arena.get("_room_root")
		if rr is Node3D:
			rr.visible = on
	if is_instance_valid(_shrine):
		_shrine.visible = on
	if is_instance_valid(_boat_fx):
		_boat_fx.visible = not on
		_boat_fx.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if not on:
		return
	# en jeu la barque n'a plus rien à faire là (l'intro la garde jusqu'à l'arrivée de la caméra)
	if menu_boat != null and state != "intro":
		menu_boat.visible = false
		arena.hide_shore(false)
	if is_instance_valid(_boat_birds):
		_boat_birds.visible = false
	for r in _boat_rings:
		var rmi: MeshInstance3D = r[0]
		rmi.visible = false
		r[2] = RING_LIFE


## Tangage de la barque (le héros reste debout à la proue), lanterne qui se balance et luit,
## rides sur l'eau, oiseaux de passage, dérive de la caméra.
func _rock_boat(real := 0.0) -> void:
	_drift_t += real
	# houle : la barque monte et descend, tangue et roule doucement (deux rythmes mêlés, jamais mécanique)
	var bob := sin(_state_t * 1.3) * 0.075 + sin(_state_t * 0.55 + 1.0) * 0.03
	menu_boat.position.y = MENU_BOAT.y + bob
	menu_boat.rotation = Vector3(sin(_state_t * 0.9) * 0.04 + sin(_state_t * 0.37) * 0.012, sin(_state_t * 0.21) * 0.03, sin(_state_t * 1.1) * 0.06)
	hero.position = Vector3(menu_boat.position.x, BOAT_DECK + bob - BOAT_HERO_Z * sin(menu_boat.rotation.x), menu_boat.position.z + BOAT_HERO_Z)
	if real <= 0.0:
		return
	if _boat_lantern != null:
		_boat_lantern.rotation = Vector3(sin(_drift_t * 1.3 + 1.0) * 0.07, 0, sin(_drift_t * 1.7) * 0.11 - menu_boat.rotation.z)
		var fl := 0.5 + 0.5 * sin(_drift_t * 5.3) * sin(_drift_t * 2.1)
		_boat_lan_mat.emission_energy_multiplier = 1.25 + 0.3 * fl
		if _boat_light != null:
			_boat_light.light_energy = 0.6 + 0.15 * fl
	# rides : un anneau naît près de la coque (plus souvent quand la barque file)
	var moving := state == "sail" or state == "worlds"
	_boat_ring_t -= real
	if _boat_ring_t <= 0.0:
		_boat_ring_t = 0.55 if moving else 1.1
		for r in _boat_rings:
			if float(r[2]) >= RING_LIFE:
				r[2] = 0.0
				var rn: MeshInstance3D = r[0]
				rn.position = Vector3(menu_boat.position.x + randf_range(-0.15, 0.15), -0.535, menu_boat.position.z + (1.4 if moving else 0.3))
				rn.scale = Vector3(0.7, 1.0, 1.1)
				rn.visible = true
				break
	for r in _boat_rings:
		var age: float = r[2]
		if age >= RING_LIFE:
			continue
		age += real
		r[2] = age
		var ri: MeshInstance3D = r[0]
		var rmat: StandardMaterial3D = r[1]
		var kk := clampf(age / RING_LIFE, 0.0, 1.0)
		var sc := 0.7 + 2.2 * (1.0 - (1.0 - kk) * (1.0 - kk))
		ri.scale = Vector3(sc, 1.0, sc * 1.6)
		rmat.albedo_color = Color(Toon.FOAM, 0.45 * (1.0 - kk) * clampf(age * 4.0, 0.0, 1.0))
		if age >= RING_LIFE:
			ri.visible = false
	# oiseaux : un petit vol traverse le ciel de temps en temps
	if _boat_birds.visible:
		_boat_birds.position += Vector3(1.9, 0.04, -0.15) * real
		var gi := 0
		for g in _boat_birds.get_children():
			var gn: Node3D = g
			gn.scale.y = gn.scale.x * (0.35 + 0.65 * absf(sin(_drift_t * 6.5 + gi * 1.7)))
			gi += 1
		if _boat_birds.position.x > 15.0:
			_boat_birds.visible = false
			_boat_bird_t = randf_range(7.0, 15.0)
	else:
		_boat_bird_t -= real
		if _boat_bird_t <= 0.0:
			_boat_birds.position = Vector3(-15.0, randf_range(3.6, 5.4), menu_boat.position.z - randf_range(9.0, 15.0))
			_boat_birds.visible = true


## Accueil : le paysage derrière la barque est celui du monde choisi (sélecteur au-dessus de JOUER,
## chevrons ou glissé). Changer de monde le remplace sous un court fondu de papier. Le monde du joueur
## (current_world) ne bouge pas tant que JOUER n'a pas lancé le monde choisi : on le remet en partant.
const SCENE_IN := 0.25  # fondu vers le papier (s)
const SCENE_OUT := 0.35  # retour du paysage (s)
var _home_sel := 1  # monde choisi sur l'accueil
var _scene_f := -1.0  # temps du fondu en cours (-1 : aucun)
var _scene_swapped := false
var _scene_veil: ColorRect


## Nombre de mondes ouverts (tous en prototype, au CI ou avec `?unlockall`).
func _unlocked_count() -> int:
	if UNLOCK_ALL or bool(meta.test_unlock_all):
		return Worlds.WORLDS.size()
	return int(meta.unlocked)


## Sélecteur de l'accueil : monde `id` choisi (aperçu permis même scellé), affiché par le menu.
func _home_select(id: int) -> void:
	var n := Worlds.WORLDS.size()
	_home_sel = wrapi(id, 1, n + 1)
	var w: Dictionary = Worlds.world(_home_sel)
	menu.sel_world = _home_sel
	menu.sel_name = UiKit.plain(String(w.name))
	menu.sel_kanji = String(w.kanji)
	menu.sel_color = w.color
	menu.sel_locked = _home_sel > _unlocked_count()


## Chevrons et glissé de l'accueil : monde précédent (-1) ou suivant (+1).
func _on_home_world_step(dir: int) -> void:
	if state != "menu":
		return
	sfx.play("whoosh", 1.25, -9.0)
	_home_select(_home_sel + dir)


## Nom du monde (accueil) : la carte des mondes, centrée sur le monde choisi.
func _on_home_worlds() -> void:
	if state != "menu":
		return
	sfx.play("whoosh", 1.0, -6.0)
	_open_worlds(_home_sel)


## JOUER sur l'accueil (hors premier lancement) : droit dans le monde choisi, sous le rideau d'encre,
## comme PARTIR sur la carte ; monde scellé : la carte s'ouvre sur lui (la condition pour l'ouvrir).
func _home_play() -> void:
	var id := _home_sel
	if id > _unlocked_count():
		_open_worlds(id)
		return
	_ask_departure(id, false)


## Écran AVANT LE DÉPART (JOUER de l'accueil, PARTIR de la carte) : pinceau, aspect et omamori de la partie ;
## PARTIR (un seul toucher garde le dernier choix) entre dans le monde `id`.
func _ask_departure(id: int, from_map: bool) -> void:
	_dep_world = id
	_dep_from_map = from_map
	departure.call("open")


func _on_departure_go() -> void:
	var id := _dep_world
	if id <= 0:
		return
	_dep_world = 0
	sfx.play("slash", 0.9, -4.0)
	if not _dep_from_map:
		if arena.world_id != id:
			_home_scene(id)  # fondu pas encore basculé : le paysage du monde choisi tout de suite
		apply_world(id)  # le monde du joueur devient le monde choisi (_home_scene_end ne le remet pas)
	# le monde est construit sous le rideau d'encre (_intro_swap), pas sous les yeux
	_intro_world = id
	_set_state("intro")


## Retour depuis l'écran de départ : l'accueil, ou la carte des mondes d'où l'on venait.
func _on_departure_back() -> void:
	var id := _dep_world
	_dep_world = 0
	if _dep_from_map and id > 0:
		_open_worlds(id)


## Paramètres de capture de l'équipement (voir _ready).
func _gear_query(q: String) -> void:
	var wq := q.find("won=")
	if wq >= 0:
		var n := clampi(int(q.substr(wq + 4).get_slice("&", 0)), 0, Meta.WORLD_COUNT)
		meta.won_top = n
		meta.charms_won = {}
		for cid in Gear.CHARM_ORDER:
			if int(Gear.CHARMS[cid]["world"]) <= n:
				meta.charms_won[cid] = true
	var bq := q.find("pinceau=")
	var cq := q.find("charme=")
	if bq >= 0 or cq >= 0:
		if bq >= 0:
			meta.brush_sel = q.substr(bq + 8).get_slice("&", 0)
		var aq := q.find("aspect=")
		meta.aspect_sel[meta.brush_sel] = clampi(int(q.substr(aq + 7).get_slice("&", 0)), 0, 2) if aq >= 0 else 0
		if cq >= 0:
			meta.charm_sel = q.substr(cq + 7).get_slice("&", 0)
		meta.gear_force = true


func _home_scene_tick(real: float) -> void:
	if _scene_veil == null:
		var vl := CanvasLayer.new()
		vl.layer = -1  # au-dessus de la 3D, sous l'interface de l'accueil
		add_child(vl)
		_scene_veil = ColorRect.new()
		_scene_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scene_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_veil.color = Color(Toon.WASHI, 0.0)
		vl.add_child(_scene_veil)
	if _scene_f < 0.0:
		if arena.world_id == _home_sel:
			_scene_veil.color = Color(Toon.WASHI, 0.0)
			return
		_scene_f = 0.0
		_scene_swapped = false
	_scene_f += real
	var k := 0.0
	if _scene_f < SCENE_IN:
		k = clampf(_scene_f / SCENE_IN, 0.0, 1.0)
	else:
		k = clampf(1.0 - (_scene_f - SCENE_IN) / SCENE_OUT, 0.0, 1.0)
		if arena.world_id != _home_sel:
			if _scene_swapped:
				# nouveau choix pendant le retour : le voile remonte depuis où il en est
				_scene_f = k * SCENE_IN
				_scene_swapped = false
			else:
				_home_scene(_home_sel)  # sous le papier : le monde se construit sans se voir
				_scene_swapped = true
		elif _scene_f >= SCENE_IN + SCENE_OUT:
			_scene_f = -1.0
			_scene_swapped = false
			k = 0.0
	_scene_veil.color = Color(Toon.WASHI, k)


## Ciel, brume, lumière et lointain du monde `id`, sans toucher au monde du joueur.
func _home_scene(id: int) -> void:
	var w: Dictionary = Worlds.world(id)
	_env.background_color = w.sky
	_env.fog_light_color = w.fog
	_env.fog_density = float(w.fog_density) * 0.7
	_env.ambient_light_color = w.ambient_color
	_env.ambient_light_energy = float(w.ambient_energy) * (1.6 if _light_mode else 1.25)
	_sun.light_color = w.sun_color
	_sun.light_energy = float(w.sun_energy) * 0.98
	arena.set_world(id)
	arena.hide_shore(true)


## En quittant l'accueil : plus de fondu ; le paysage redevient le monde du joueur (déjà le monde
## choisi si JOUER l'a lancé : _home_play).
func _home_scene_end() -> void:
	_scene_f = -1.0
	_scene_swapped = false
	if _scene_veil != null:
		_scene_veil.color = Color(Toon.WASHI, 0.0)
	if arena.world_id != current_world:
		apply_world(current_world)


## Pose le héros sur la barque, à la proue, de dos (face au paysage).
func _board_boat() -> void:
	arena.hide_shore(true)  # accueil : un paysage, pas le cadre de la salle
	menu_boat.visible = true
	menu_boat.position = MENU_BOAT
	if _boat_fx_world != current_world:
		_build_boat_fx(current_world)
	hero.position = MENU_BOAT + Vector3(0, BOAT_DECK, BOAT_HERO_Z)
	hero.face(WARDROBE_DIR if _wardrobe_on else Vector3(0, 0, -1))
	hero.snap_facing()


## Garde-robe (bouton de l'accueil) : panneau par-dessus la barque, aperçu immédiat sur le héros.
func _setup_wardrobe() -> void:
	var wl := CanvasLayer.new()
	wl.layer = 4
	add_child(wl)
	var ws: GDScript = load("res://scripts/wardrobe.gd")
	wardrobe = ws.new()
	wardrobe.set("meta", meta)
	wl.add_child(wardrobe)
	wardrobe.connect("changed", _on_wardrobe_changed)
	wardrobe.connect("closed", _on_wardrobe_closed)
	menu.wardrobe_pressed.connect(_open_wardrobe)
	menu.apply_theme(meta.theme_colors())
	Toon.set_ui_theme(meta.theme_colors())


func _open_wardrobe() -> void:
	if state != "menu":
		return
	sfx.play("whoosh", 0.9, -4.0)
	menu.show_mode("hidden")
	_wardrobe_on = true
	hero.face(WARDROBE_DIR)
	wardrobe.call("open")


func _on_wardrobe_changed(cat: String) -> void:
	meta.apply_look(hero)
	if cat == "theme":
		menu.apply_theme(meta.theme_colors())
		Toon.set_ui_theme(meta.theme_colors())
	sfx.play("empty", 1.3, -6.0)
	feel("kill")


func _on_wardrobe_closed() -> void:
	_wardrobe_on = false
	menu.sumi = meta.sumi
	if is_instance_valid(hero):
		hero.face(Vector3(0, 0, -1))
	if state == "menu":
		menu.show_mode("home")


## Salle d'arrivée d'un ennemi dans un monde (KIND_STAGE du monde, sinon KIND_ROOM).
func kind_room(k: String, w: int) -> int:
	var sched: Dictionary = KIND_STAGE.get(w, {})
	if sched.has(k):
		var st := clampi(int(sched[k]), 1, STAGE_PLAN.size())
		var rooms: Array = STAGE_PLAN[st - 1]
		return int(rooms[0])
	return int(KIND_ROOM.get(k, 1))


## Un ennemi entre en jeu : première rencontre -> fiche du bestiaire, et bandeau (sauf boss et tutoriel).
func _discover(k: String, boss := false) -> void:
	if meta == null or state == "tuto":
		return
	var key: String = ("boss_" + k) if boss else Bestiary.base_kind(k)
	if key == "":
		return
	if not bool(meta.see_kind(key, current_world)):
		return
	meta.save_data()
	if boss or _gentle_room():
		return  # le carton du boss le présente déjà ; premiers combats du tutoriel : pas de surcharge
	if not key in _new_kinds:
		_new_kinds.append(key)
		_new_kind_t = maxf(_new_kind_t, 0.6)  # le temps qu'il sorte de sa flaque d'encre


func _count_kill(k: String, boss := false) -> void:
	if meta == null:
		return
	var key: String = ("boss_" + k) if boss else Bestiary.base_kind(k)
	if key == "":
		return
	meta.kill_kind(key)
	_bestiary_dirty = true


func _save_bestiary() -> void:
	if _bestiary_dirty and meta != null:
		meta.save_data()
	_bestiary_dirty = false


## Bandeau bref (1,5 s, sans pause) pour chaque ennemi nouveau, un à la fois, quand le bandeau est libre.
func _tick_discovery(real: float) -> void:
	if _new_kinds.is_empty():
		return
	_new_kind_t -= real
	if _new_kind_t > 0.0 or state != "play" or _intro_boss != null:
		return
	if float(hud.get("_banner_t")) >= 0.0 or float(hud.get("_card_t")) >= 0.0:
		return
	var k := String(_new_kinds.pop_front())
	var kj := Bestiary.kanji_of(k)
	var sub := "NOUVEAU NINJA" if Bestiary.is_ninja(k) else "NOUVEAU YOKAI"
	if kj != "" and _font_has(kj):
		sub += "  ·  " + kj
	hud.banner(UiKit.plain(Bestiary.name_of(k)), sub, Toon.VERMILION, 1.5)
	sfx.play("levelup", 1.5, -14.0)
	_new_kind_t = 1.7


func _font_has(chars: String) -> bool:
	for i in chars.length():
		if not UiKit.UI_FONT.has_char(chars.unicode_at(i)):
			return false
	return true


# ------------------------------------------------------------------ décor

func _build_world() -> void:
	world = Node3D.new()
	add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Toon.WASHI
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.9, 1.0)
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# couleurs plus franches : un peu plus de saturation et de contraste
	e.adjustment_enabled = true
	# étalonnage : couleurs franches mais pas brûlées (les sols clairs saturaient)
	# palette plus sobre et moderne : saturation presque neutre, le contraste fait ressortir les personnages
	e.adjustment_saturation = 1.04
	e.adjustment_contrast = 1.14
	e.adjustment_brightness = 1.0  # lumineux sans brûler les sols clairs
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_strength = 1.1
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# brume d'estampe : le lointain (Fuji, îlots) se fond dans le papier
	e.fog_enabled = true
	e.fog_light_color = Toon.WASHI
	e.fog_density = 0.0028
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)

	# soleil chaud et rasant qui projette de vraies ombres
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-38), 0)
	sun.light_energy = 0.72
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	var light := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	light = light or "--lite" in OS.get_cmdline_user_args()  # mesures et captures du rendu téléphone sur le bureau
	if light:
		# téléphone : chaque lumière refait un passage sur chaque objet -> une seule, ombres plus proches,
		# 3D rendue un peu en dessous de la résolution native (l'interface reste nette)
		sun.directional_shadow_max_distance = 26.0
		_light_mode = true
		get_viewport().scaling_3d_scale = 0.8
	else:
		# contre-jour froid, sans ombre, pour détacher les silhouettes
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(150), 0)
		fill.light_energy = 0.22
		fill.light_color = Color(0.7, 0.8, 1.0)
		add_child(fill)
	Toon.lite = _light_mode
	# voile d'estampe sous toute l'interface : vignette d'encre douce (+ grain du papier hors mode léger)
	var veil_layer := CanvasLayer.new()
	veil_layer.layer = -1
	add_child(veil_layer)
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	var veil_mat := ShaderMaterial.new()
	veil_mat.shader = load("res://shaders/print_veil.gdshader")
	veil_mat.set_shader_parameter("fine", not _light_mode)
	veil.material = veil_mat
	veil_layer.add_child(veil)

	cam = Camera3D.new()
	cam.fov = 38.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	cam.current = true

	_env = e
	_sun = sun
	# la salle (sol, décor, torii de sortie) et le monde (vide, lointain, particules)
	arena = Arena.new()
	world.add_child(arena)
	arena.perf.connect(_on_arena_perf)
	_build_menu_boat()


## Applique l'ambiance d'un monde : ciel, brume, lumière, puis le décor lointain.
func apply_world(id: int) -> void:
	var t0 := Time.get_ticks_usec()
	var fresh: bool = id != arena.world_id
	current_world = id
	var w: Dictionary = Worlds.world(id)
	_env.background_color = w.sky
	_env.fog_light_color = w.fog
	_env.fog_density = float(w.fog_density) * 0.7  # brume plus légère : couleurs moins délavées
	_env.ambient_light_color = w.ambient_color
	# sans contre-jour (téléphone), un peu plus de lumière ambiante compense
	_env.ambient_light_energy = float(w.ambient_energy) * (1.6 if _light_mode else 1.25)
	_sun.light_color = w.sun_color
	_sun.light_energy = float(w.sun_energy) * 0.98
	_mood_capture(w)
	arena.set_world(id)
	if fresh:
		perf_mark("world_build", Time.get_ticks_usec() - t0)  # lointain du monde (ou monde gardé en mémoire)


## Valeurs de lumière du monde (base de l'ambiance de boss) ; l'ambiance repart de zéro.
func _mood_capture(w: Dictionary) -> void:
	_mood_base = {"sky": _env.background_color, "fog": _env.fog_light_color, "fog_d": _env.fog_density,
		"amb_e": _env.ambient_light_energy, "sun_c": _sun.light_color, "sun_e": _sun.light_energy,
		"contrast": _env.adjustment_contrast, "bright": _env.adjustment_brightness,
		"sat": _env.adjustment_saturation, "tint": w.get("color", MOOD_INK)}
	_mood_k = 0.0
	_mood_to = 0.0
	_mood_flash = 0.0


## Ambiance de boss : se fond vers _mood_to ; éclairs lointains quand le boss du monde est là.
func _update_mood(real: float) -> void:
	if _mood_base.is_empty() or in_hub or state == "menu":
		return
	if _mood_to > 0.0 and bosses.is_empty() and state != "boss_intro":
		_mood_to = 0.0  # plus de boss (salle suivante, mort, abandon) : le ciel se rouvre
	if is_equal_approx(_mood_k, _mood_to) and _mood_k <= 0.0 and _mood_flash <= 0.0:
		return
	_mood_k = move_toward(_mood_k, _mood_to, real / MOOD_FADE)
	var k := _mood_k * _mood_k * (3.0 - 2.0 * _mood_k)
	# éclairs lointains : boss du monde seulement, une lueur brève tous les 7 à 13 s
	if _mood_to >= 1.0 and k > 0.9:
		_mood_next_flash -= real
		if _mood_next_flash <= 0.0:
			_mood_next_flash = randf_range(7.0, 13.0)
			_mood_flash = 1.0
			sfx.play("thunder", randf_range(0.45, 0.6), -16.0)
	_mood_flash = maxf(0.0, _mood_flash - real / 0.35)
	var fl := _mood_flash * _mood_flash
	var tint: Color = _mood_base["tint"]
	var dark: Color = MOOD_INK.lerp(tint.darkened(0.55), 0.35)
	var sky: Color = _mood_base["sky"]
	_env.background_color = sky.lerp(dark, 0.6 * k).lerp(Color(0.92, 0.9, 1.0), 0.35 * fl)
	var fog: Color = _mood_base["fog"]
	_env.fog_light_color = fog.lerp(dark.lightened(0.12), 0.55 * k)
	_env.fog_density = float(_mood_base["fog_d"]) * (1.0 + 0.9 * k)
	_env.ambient_light_energy = float(_mood_base["amb_e"]) * (1.0 - 0.35 * k + 0.6 * fl)
	var sun_c: Color = _mood_base["sun_c"]
	_sun.light_color = sun_c.lerp(Color(1.0, 0.7, 0.52), 0.45 * k)
	_sun.light_energy = float(_mood_base["sun_e"]) * (1.0 - 0.42 * k)
	_env.adjustment_contrast = float(_mood_base["contrast"]) + 0.12 * k
	_env.adjustment_brightness = float(_mood_base["bright"]) * (1.0 - 0.1 * k + 0.12 * fl)
	_env.adjustment_saturation = float(_mood_base["sat"]) * (1.0 - 0.1 * k)
	hud.mood = k
	hud.mood_tint = dark


## Cadrage de l'arène : son centre (là où se tient le héros) au centre de l'écran.
## Mode pad : un second cadrage, l'arène au-dessus du pad ; le jeu glisse de l'un à l'autre selon la
## visibilité du pad (_cam_mix).
func _fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0 or vs.y <= 0:
		return
	_cam_full = _frame(vs)
	_cam_base = _cam_full
	if ctrl_mode == "pad":
		_cam_pad = _frame_pad(vs, pad_rect().position.y / vs.y)
		_cam_base = _cam_mix()
	cam.global_transform = _cam_base


## Cadrage de jeu : en mode pad, mélange des deux cadrages selon la visibilité du pad (l'arène descend
## quand il s'efface).
func _cam_mix() -> Transform3D:
	if ctrl_mode != "pad" or hud == null:
		return _cam_full
	var kp: float = clampf(float(hud.pad_alpha), 0.0, 1.0)
	return _cam_full.interpolate_with(_cam_pad, kp * kp * (3.0 - 2.0 * kp))


## Mode pad : caméra la plus proche qui montre toute l'arène entre le bandeau du haut et `bottom_k`
## (haut du pad, en fraction de hauteur), arène centrée dans cette bande (cadrage d'avant le tracé sur l'écran).
func _frame_pad(vs: Vector2, bottom_k: float) -> Transform3D:
	var key := "%.2fx%.2f_p%.3f" % [vs.x, vs.y, bottom_k]
	if _frame_cache.has(key):
		var cached: Transform3D = _frame_cache[key]
		return cached
	var tilt := deg_to_rad(54.0)
	var corners := [Vector3(-HALF.x - 0.15, 0, -HALF.y - 0.2), Vector3(HALF.x + 0.15, 0, -HALF.y - 0.2),
		Vector3(-HALF.x - 0.15, 0, HALF.y + 0.2), Vector3(HALF.x + 0.15, 0, HALF.y + 0.2),
		Vector3(0, 2.2, -HALF.y - 0.4)]
	var top := vs.y * 0.085
	var bottom := vs.y * bottom_k
	var best := Transform3D()
	var found := false
	var dist := 12.0
	while dist < 70.0 and not found:
		# à cette distance, garde le cadrage qui centre l'arène verticalement dans la bande
		var best_gap := INF
		for zi in 41:
			var zc := -4.0 + zi * 0.2
			var focus := Vector3(0, 0, zc)
			var pos := focus + Vector3(0, sin(tilt), cos(tilt)) * dist
			var tr := Transform3D(Basis(), pos).looking_at(focus, Vector3.UP)
			cam.global_transform = tr
			var ok := true
			var min_y := INF
			var max_y := -INF
			for c in corners:
				var p := cam.unproject_position(c)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
				if p.x < -vs.x * 0.01 or p.x > vs.x * 1.01 or p.y < top or p.y > bottom:
					ok = false
					break
			if ok:
				var gap := absf((min_y - top) - (bottom - max_y))
				if gap < best_gap:
					best_gap = gap
					best = tr
				found = true
		dist += 0.25
	if not found:
		best = Transform3D(Basis(), Vector3(0, 30, 18)).looking_at(Vector3.ZERO, Vector3.UP)
	if _frame_cache.size() >= FRAMES_MAX:
		_frame_cache.clear()
	_frame_cache[key] = best
	_save_frames()
	return best


## Caméra la plus proche qui vise le centre de l'arène (à hauteur du héros) au centre de l'écran et montre
## toute l'arène entre le bandeau du haut et le bas de l'écran.
func _frame(vs: Vector2) -> Transform3D:
	# même écran, même cadrage : la recherche n'est faite qu'une fois
	var key := "%.2fx%.2f_c" % [vs.x, vs.y]
	if _frame_cache.has(key):
		var cached: Transform3D = _frame_cache[key]
		return cached
	var tilt := deg_to_rad(54.0)
	# marges serrées : caméra un peu plus proche (le haut du torii peut toucher le bandeau)
	var corners := [Vector3(-HALF.x - 0.15, 0, -HALF.y - 0.2), Vector3(HALF.x + 0.15, 0, -HALF.y - 0.2),
		Vector3(-HALF.x - 0.15, 0, HALF.y + 0.2), Vector3(HALF.x + 0.15, 0, HALF.y + 0.2),
		Vector3(0, 2.2, -HALF.y - 0.4)]
	var top := vs.y * 0.085
	var bottom := vs.y * 0.97
	var focus := Vector3(0, CAM_FOCUS_Y, 0)
	var best := Transform3D()
	var found := false
	var dist := 12.0
	while dist < 70.0 and not found:
		var pos := focus + Vector3(0, sin(tilt), cos(tilt)) * dist
		var tr := Transform3D(Basis(), pos).looking_at(focus, Vector3.UP)
		cam.global_transform = tr
		var ok := true
		for c in corners:
			var p := cam.unproject_position(c)
			if p.x < -vs.x * 0.01 or p.x > vs.x * 1.01 or p.y < top or p.y > bottom:
				ok = false
				break
		if ok:
			best = tr
			found = true
		dist += 0.25
	if not found:
		best = Transform3D(Basis(), focus + Vector3(0, 30, 18)).looking_at(focus, Vector3.UP)
	if _frame_cache.size() >= FRAMES_MAX:
		_frame_cache.clear()
	_frame_cache[key] = best
	_save_frames()
	return best


## Cadrages des lancements précédents (même version du jeu, même écran) : la recherche est évitée.
func _load_frames() -> void:
	_frame_disk_key = "%s|%s|%.2f|2" % [str(ProjectSettings.get_setting("application/config/version", "dev")), str(HALF), cam.fov]
	var cfg := ConfigFile.new()
	if cfg.load(FRAMES_PATH) != OK:
		return
	if str(cfg.get_value("meta", "key", "")) != _frame_disk_key or not cfg.has_section("frames"):
		return
	for k in cfg.get_section_keys("frames"):
		var v: Variant = cfg.get_value("frames", k)
		if v is Transform3D:
			_frame_cache[String(k)] = v


func _save_frames() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "key", _frame_disk_key)
	for k in _frame_cache.keys():
		cfg.set_value("frames", String(k), _frame_cache[k])
	cfg.save(FRAMES_PATH)


# ------------------------------------------------------------------ partie

## Nouvelle partie. `hub` : on démarre dans le sanctuaire (zone d'entraînement, torii vers l'étape 1) ;
## sinon directement dans l'étape 1 (tests), ou dans une salle simple pour le tutoriel (`tutorial`).
func _start(hub := true, tutorial := false) -> void:
	var t0 := Time.get_ticks_usec()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_attackers.clear()
	for bo in bosses:
		if is_instance_valid(bo):
			bo.queue_free()
	bosses.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	if hero:
		hero.queue_free()
	_clear_pockets()
	hazards.clear()
	if is_instance_valid(_shrine):
		_shrine.queue_free()
	_shrine = null
	in_hub = hub
	gentle = false  # (posé ensuite par _start_first_run)
	_new_kinds.clear()
	if coach != null:
		coach.clear()
	stage_i = 0
	_enc = -1
	_slowmo_t = -1.0
	_alive_prev = 0
	var t_arena := Time.get_ticks_usec()
	if hub:
		arena.build_hub(randi())
		arena.open_gate()
	elif tutorial:
		arena.build_room(1, ROOMS, randi(), MINI_ROOM)
	else:
		arena.build_stage(STAGE_PLAN[0].size(), randi(), true)
	perf_mark("hub_build" if hub else ("room_build" if tutorial else "stage_build"), Time.get_ticks_usec() - t_arena)
	hero = Hero.new()
	add_child(hero)
	hero.position = arena.start
	hero.dash_finished.connect(_on_dash_finished)
	hero.landed.connect(_on_hero_landed)
	_prev_hero = hero.position
	if arena.stage:
		_build_pockets()
	_cam_dz = _cam_target()
	_cancel_stroke()
	if is_instance_valid(dash_stroke):
		dash_stroke.queue_free()
	dash_stroke = null
	_reset_stroke_state(true)
	_pick_context = "room"
	foam = 0
	ult = 0.0
	_dmg_labels.clear()
	_ricochets = {}
	wave_wait = 0.8
	room = 0
	_waves_left = []
	_room_done = false
	powers.reset()
	hazards.clear()
	curses.clear()
	_ink_lock = 0.0
	score.bonus_mult = 1.0
	elan = elan_max()  # après la remise à zéro des pouvoirs et malédictions
	_extra_picks = 0
	picker.rerolls = meta.rerolls()
	kills = 0
	boss_kills = 0
	mini_kills = 0
	run_time = 0.0
	xp = 0
	level = 1
	run_gold = 0
	_pending_levels = 0
	seal_reward = ""
	_seal_picks.clear()
	pickups.clear()
	chain = 0
	max_chain = 0
	score.reset()
	# Arbre du pinceau : Fil du sabre (×1,5 dès 2), Maître des figures (+25 % de points de figure)
	score.chain_early = meta.learned("l3")
	score.fig_mult = Meta.MASTER_FIG_PTS if meta.learned("vc") else 1.0
	# pinceau et omamori de la partie (écran de départ ; robot et captures : gear_force)
	var gear: Dictionary = meta.gear_now()
	brush = String(gear["brush"])
	aspect = int(gear["aspect"])
	charm = String(gear["charm"])
	InkStroke.brush = brush
	InkStroke.aspect = aspect
	if charm == "ascete":
		score.bonus_mult = Gear.ASCETE_PTS  # points +25 % (le Tambour des morts le multiplie)
	_clear_rain()
	_wall_t = 0.0
	_blood = 0.0
	_half = 0
	_pact_key = -1
	_aiguille_key = -1
	_garde_stage = -1
	_portes_used = false
	_refuse_free_used = false
	_fig_double_room = -1
	_last_breath_used = false
	_net_ready = false
	_bleed.clear()
	shape_counts = {}
	_chain_t = 0.0
	_scratched = false
	_flawless_pending = false
	_flawless_boss = false
	puzzles_seen = 0
	puzzles_solved = 0
	chests_sealed = 0
	chests_unsealed = 0
	sealed_set = 0
	sealed_broken = 0
	_seal_quota = 0
	run_dist = 0.0
	hud.dying = 0.0
	hero.max_hp = 5 + meta.hp_bonus()
	hero.hp = hero.max_hp
	meta.apply_run_start(self)  # apparence de l'Atelier, rouleau de départ, bénédiction
	hero.set_charm(charm, Gear.charm(charm).get("col", Color.WHITE) if charm != "" else Color.WHITE)
	game_over = false
	touching = false
	shake = 0.0
	_kick = Vector3.ZERO
	_zoom_k = 0.0
	_hitstop = 0.0
	Engine.time_scale = 1.0
	_fit_camera()
	perf_mark("start", Time.get_ticks_usec() - t0)  # nouvelle partie entière (salle, héros, remise à zéro)


func elan_max() -> float:
	var add := 0.0
	var mul := 1.0
	match brush:
		"fude":
			add = Gear.VENT_ELAN if aspect == 2 else 0.0  # Vent
		"hake":
			mul = Gear.HAKE_ELAN
		"menso":
			mul = Gear.MENSO_ELAN
	return (ELAN_MAX + powers.elan_bonus() + meta.elan_bonus() + add) * mul * (0.7 if "dry" in curses else 1.0)


## Dégâts du trait selon le pinceau : Vent −10 %, Calame +40 % (Démon ×1,5 à 2 cœurs ou moins).
func brush_dmg() -> float:
	match brush:
		"fude":
			return Gear.VENT_DMG if aspect == 2 else 1.0
		"chi":
			var m := Gear.CHI_DMG
			if aspect == 2 and is_instance_valid(hero) and int(hero.hp) <= Gear.CHI_DEMON_HP:
				m *= Gear.CHI_DEMON
			return m
	return 1.0


## Portée latérale du coup de trait (HIT_REACH ; Hake : tout ce qu'il frôle ; Menso : fin).
func brush_reach() -> float:
	match brush:
		"hake":
			return Gear.HAKE_REACH
		"menso":
			return Gear.MENSO_REACH
	return HIT_REACH


## L'omamori porté vient d'agir : il brille à la ceinture.
func charm_fx() -> void:
	if is_instance_valid(hero):
		hero.charm_flash()


## Plafond de la recharge d'élan : l'élan max, ou un peu plus avec la Réserve (Arbre du pinceau).
func elan_cap() -> float:
	return elan_max() * meta.reserve_mult()


## Coup net (Arbre du pinceau) : la première touche de chaque combat est critique (×2).
func _net_crit(pos: Vector3) -> float:
	if not _net_ready:
		return 1.0
	_net_ready = false
	float_text(pos, "NET !", Toon.GOLD)
	vfx.dusk_crit(pos)
	return Meta.NET_CRIT


## Lame d'encre (Arbre du pinceau) : l'ennemi saigne BLEED_TIME secondes (relancé s'il saigne déjà).
func _bleed_start(e: Node3D) -> void:
	var eid := e.get_instance_id()
	if _bleed.has(eid):
		var b: Array = _bleed[eid]
		b[1] = Meta.BLEED_TIME
	else:
		_bleed[eid] = [e, Meta.BLEED_TIME, 0.0]


func _update_bleeds(dt: float) -> void:
	for k in _bleed.keys():
		if not _bleed.has(k):
			continue  # une mort en chaîne a pu vider la table pendant la boucle
		var b: Array = _bleed[k]
		var e = b[0]
		b[1] = float(b[1]) - dt
		if not is_instance_valid(e) or e.dead or float(b[1]) <= 0.0:
			_bleed.erase(k)
			continue
		b[2] = float(b[2]) - dt
		if float(b[2]) <= 0.0:
			b[2] = 0.3
			_splash(e.position, Toon.VERMILION, 2)  # gouttes vermillon
		damage_enemy(e, Meta.BLEED_DPS * dt, false)


## Combat suivant (zone d'une étape, ou arène d'un gardien) : 3 vagues d'ennemis à tuer, tirées selon
## le monde, budget croissant.
func _begin_room() -> void:
	room += 1
	_room_done = false
	score.on_room_start()
	_room_spawned = 0
	_seal_quota = _seal_roll()
	_alive_prev = 0
	foam = powers.foam_per_room()
	powers.on_room_start(room)
	safety_left = meta.safety_per_room()
	if charm == "encre" and state != "tuto" and not in_hub:
		# omamori de l'encre : la jauge démarre pleine, et déborde (réserve d'or)
		elan = maxf(elan, elan_max() * Gear.ENCRE_FILL)
		charm_fx()
	# Arbre du pinceau : Coup net (1re touche critique), Garde au départ (intouchable 2 s), saignements oubliés
	_net_ready = meta.learned("l4")
	_bleed.clear()
	if meta.learned("p2") and hero.invuln < 500.0:
		hero.invuln = maxf(hero.invuln, Meta.START_GUARD)
	if arena.stage:
		hazards.begin_room(room, hero.position, false, arena.bounds, true)
	else:
		hazards.begin_room(room, hero.position, room == MINI_ROOM or room == ROOMS)
	# difficulté du monde (worlds.gd : b0, per) et courbe dans le monde (ROOM_CURVE : respiration, épreuve)
	var b0 := world_diff("b0", 4.0)
	var per := world_diff("per", 1.0)
	var curve := float(ROOM_CURVE[clampi(room, 0, ROOM_CURVE.size() - 1)])
	var budget := int((b0 + per * float(room)) * curve * MOB_SCALE)
	if _gentle_room():
		budget = maxi(3, int(budget * 0.55))  # premier tutoriel : moins d'ennemis
	if hero.hp <= 1:
		budget = maxi(2, int(budget * 0.85))  # combat commencé au dernier cœur : un peu moins d'ennemis
	var list: Array = []
	if room >= (4 if current_world == 1 else 3):
		list.append("brute")
		budget -= int(KIND_COST.get("brute", 3))
	if room >= 10:
		# seconde moitié du monde : un deuxième lourd (kanabō s'il est déjà arrivé dans ce monde, sinon une brute)
		var heavy := "brute"
		var wk: Dictionary = Worlds.world(current_world).get("enemies", {})
		if wk.has("kanabo") and room >= kind_room("kanabo", current_world):
			heavy = "kanabo"
		list.append(heavy)
		budget -= int(KIND_COST.get(heavy, 3))
	list.append_array(_draw_kinds(_room_pool(), budget))
	list.shuffle()
	_elite_due = 1 if room == TRIAL_ROOM else 0
	_reinf_step = 0
	if room == MINI_ROOM:
		# escorte du gardien : tirée dans le pool du monde, plus fournie dans les mondes avancés
		list = _draw_kinds(_room_pool(), 4 + 2 * current_world)
		list.shuffle()
		_spawn_boss(String(MINI_BOSS.get(current_world, "okappa")))
	elif room == ROOMS:
		list = []
		_spawn_boss(String(WORLD_BOSS.get(current_world, "uwabami")))
	# découpe en vagues : 40 % / 35 % / 25 %, puis 4 vagues dès la salle 10 (30 / 25 / 25 / 20 %)
	_waves_left = []
	_wave_cont = false
	_wave_t = 0.0
	var cuts: Array = [0.3, 0.55, 0.8] if room >= 10 else [0.4, 0.75]
	var n := list.size()
	var prev := int(ceil(n * float(cuts[0])))
	var first: Array = list.slice(0, prev)
	for ci in range(1, cuts.size()):
		var c := int(ceil(n * float(cuts[ci])))
		if c > prev:
			_waves_left.append(list.slice(prev, c))
			prev = c
	if n > prev:
		_waves_left.append(list.slice(prev))
	waves_total = 1 + _waves_left.size()
	wave_index = 1
	_wave_size = first.size()
	first = _cap_wave(first, 0)
	var boss_room := (room == MINI_ROOM or room == ROOMS) and is_instance_valid(_intro_boss)
	if boss_room:
		# salle de boss : carton titre et première vague à la fin de son entrée (_start_boss_intro)
		_intro_wave = first
	elif arena.stage:
		hud.toast("COMBAT %d / %d" % [_enc + 1, arena.zones.size()])
	if not boss_room:
		_spawn_list(first)
	sfx.play("strike", 0.7, -2.0)


## Deux premiers combats du monde 1 pendant la première partie du tutoriel.
func _gentle_room() -> bool:
	return gentle and current_world == 1 and room >= 1 and room <= 2 and not in_hub


func _weighted_kind(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	var r := randf() * total
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return "oni"


## Ennemis que le combat peut tirer : mondes 2 et suivants, ceux déjà arrivés (sinon trop d'oni en début
## de monde) ; monde 1, tous (un ennemi pas encore arrivé devient un oni au tirage : combats plus doux).
func _room_pool() -> Dictionary:
	var weights: Dictionary = Worlds.world(current_world).get("enemies", {"oni": 1})
	if current_world <= 1:
		return weights
	var pool := {}
	for wk in weights.keys():
		if room >= kind_room(String(wk), current_world):
			pool[wk] = weights[wk]
	if pool.is_empty():
		pool = {"oni": 1}
	return pool


## Tire des ennemis dans `pool` jusqu'à épuiser `budget` (coût KIND_COST) ; un ennemi pas encore arrivé
## ou trop cher devient un oni.
func _draw_kinds(pool: Dictionary, budget: int) -> Array:
	var list: Array = []
	var guard := 0
	while budget > 0 and guard < 100:
		guard += 1
		var k := _weighted_kind(pool)
		var cost := int(KIND_COST.get(k, 1))
		if room < kind_room(k, current_world) or cost > budget:
			k = "oni"
			cost = 1
		list.append(k)
		budget -= cost
	return list


## Vitesse de la ruée selon le monde : plus lente au début (on voit venir les dangers et on apprend à
## s'en écarter d'un trait), pleine vitesse dès le monde 4. Dojo et tutoriel : vitesse du monde 1.
const WORLD_DASH := {1: 0.78, 2: 0.86, 3: 0.94}


func _world_dash_mult() -> float:
	return float(WORLD_DASH.get(current_world, 1.0))


## Réglage de difficulté du monde en cours (worlds.gd : tokens, tele, b0, per, elite, bullet).
func world_diff(key: String, fallback: float) -> float:
	return float(Worlds.world(current_world).get(key, fallback))


## Ennemis autorisés à préparer une attaque en même temps : selon le monde, +1 en fin de monde (max 5).
func attack_tokens() -> int:
	if state == "tuto":
		return ATTACK_TOKENS
	var t := int(world_diff("tokens", float(ATTACK_TOKENS)))
	if room >= 11:
		t += 1
	return mini(t, 5)


## Plafond d'ennemis vivants à l'écran (4 + monde / 2).
func screen_cap() -> int:
	return 4 + int(float(current_world) / 2.0)


## Vagues qui se chevauchent (dès la salle 5 du monde 2) : la suivante n'attend plus le dernier ennemi.
func _waves_overlap() -> bool:
	return current_world >= 3 or (current_world == 2 and room >= 5)


## Plafond à l'écran : garde de `wave` ce qui tient avec `alive` ennemis déjà là ; le reste repasse en tête
## de _waves_left (suite de la même vague, sans nouvelle annonce).
func _cap_wave(wave: Array, alive: int) -> Array:
	var space := maxi(1, screen_cap() - alive)
	if wave.size() <= space:
		return wave
	_waves_left.push_front(wave.slice(space))
	_wave_cont = true
	return wave.slice(0, space)


## Vague suivante (ou suite de la vague retenue par le plafond) prête à entrer ?
func _wave_ready(alive: int) -> bool:
	if alive >= screen_cap():
		return false
	if _wave_cont or alive <= 1:
		return true
	if "drum" in curses:
		# Tambour des morts : la suite entre deux fois plus tôt, quel que soit le monde
		return alive <= maxi(1, ceili(float(_wave_size) * 0.6)) or _wave_t >= WAVE_OVERLAP_T * 0.5
	if not _waves_overlap():
		return false
	return alive <= maxi(1, ceili(float(_wave_size) * 0.35)) or _wave_t >= WAVE_OVERLAP_T


## Boss de fin : renforts (ennemis du monde, budget 3 + monde) à 66 % puis 33 % de ses PV.
func _boss_reinforce() -> void:
	if room != ROOMS or _reinf_step >= 2 or in_hub:
		return
	for bo in bosses:
		if not is_instance_valid(bo) or bool(bo.dead) or is_mini_boss(String(bo.kind)):
			continue
		var mh := float(bo.max_hp)
		if mh <= 0.0:
			continue
		var ratio := float(bo.hp) / mh
		var at: float = 0.66 if _reinf_step == 0 else 0.33
		if ratio <= at:
			_reinf_step += 1
			_spawn_list(_draw_kinds(_room_pool(), 3 + current_world), REINF_DIST)
			hud.toast("RENFORTS")
			sfx.play("strike", 0.8, -4.0)
		return


func _spawn_boss(k: String) -> Node3D:
	var t0 := Time.get_ticks_usec()
	var b: Node3D = _boss_script(k).new()
	b.setup(k, self)
	_discover(k, true)
	if is_mini_boss(k):
		b.position = Vector3(0, 0, -HALF.y + 3.0)
	b.max_hp_mult = float(Worlds.world(current_world).hp_mult)
	# figé jusqu'à son entrée en scène, une fois le torii passé (_start_boss_intro)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	_intro_boss = b
	_scratched = false  # combat sans dégât : suivi jusqu'à sa chute (boss_killed)
	add_child(b)
	bosses.append(b)
	music.play_boss(current_world, is_mini_boss(k))
	sfx.play("strike", 0.5)
	shake = 0.55
	perf_mark("boss_spawn", Time.get_ticks_usec() - t0)
	return b


# ------------------------------------------------------------------ entrée des boss

## Carton titre de chaque boss : nom romanisé, épithète (UI v2 : plus de kanji, le sceau du carton est un picto).
const BOSS_CARDS := {
	"okappa": ["Ō-KAPPA", "le seigneur des eaux dormantes"],
	"tsuchigumo": ["TSUCHIGUMO", "l'araignée des terres"],
	"yukionna": ["YUKI-ONNA", "la dame des neiges"],
	"ibaraki": ["IBARAKI-DŌJI", "l'oni au bras tranché"],
	"bakekujira": ["BAKEKUJIRA", "la baleine fantôme"],
	"uwabami": ["UWABAMI", "le serpent qui avale les barques"],
	"kyubi": ["KYŪBI", "le renard aux neuf queues"],
	"gashadokuro": ["GASHADOKURO", "le squelette des affamés"],
	"daidara": ["DAIDARABOTCHI", "le géant qui façonne les monts"],
	"kuronami": ["KURO-NAMI", "la vague noire"],
	"karasu_o": ["KARASU-TENGU", "le chef des corbeaux du Kurama"],
	"sojobo": ["SŌJŌBŌ", "le roi des tengu du mont Kurama"],
	"umibozu_o": ["UMIBŌZU", "le moine géant des abysses"],
	"ryujin": ["RYŪJIN", "le roi dragon de la mer"],
	"gaki_o": ["GAKI-Ō", "le roi des affamés"],
	"izanami": ["IZANAMI", "la reine du pays des morts"],
}
var _intro_boss: Node3D = null  # boss qui attend son entrée en scène (figé)
var _intro_wave: Array = []  # première vague, lâchée à la fin de l'entrée
var _intro_len := 2.0
var _intro_w := 0.0  # poids du plan rapproché (0 = cadrage de l'arène)
var _intro_roar := false
var _intro_pose := ""  # état d'apparition du boss : il se fige dès qu'il en sort
var _intro_mini := false


## Le boss entre : caméra sur lui, bandes noires, carton titre. Le robot (CI) passe tout.
func _start_boss_intro() -> void:
	var b := _intro_boss
	if not is_instance_valid(b):
		_intro_boss = null
		_intro_wave = []
		return
	_intro_mini = is_mini_boss(String(b.kind))
	_mood_to = 0.5 if _intro_mini else 1.0  # ambiance de boss (moitié pour un gardien)
	var sub := ("GARDIEN DE L'ÉTAPE %d" % stage_of(MINI_ROOM)) if _intro_mini else "GARDIEN DU MONDE"
	if _bot != null and not bool(_bot.get("cinematics")):
		hud.banner(String(b.title).to_upper(), sub, Toon.VERMILION, 2.2)
		_end_boss_intro()
		return
	var known := BOSS_CARDS.has(String(b.kind))
	var card: Array = BOSS_CARDS.get(String(b.kind), [String(b.title).to_upper(), ""])
	_cancel_stroke()
	_reset_stroke_state(true)
	hero.stop_dash()
	_intro_len = 1.6 if _intro_mini else 2.0
	_intro_w = 0.0
	_intro_roar = false
	_intro_pose = str(b.get("_state"))
	# il joue sa propre apparition (jamais d'attaque : voir _update_boss_intro)
	b.process_mode = Node.PROCESS_MODE_INHERIT
	hud.boss_card("picto" if known else "", String(card[0]), String(card[1]), sub, _intro_mini, _intro_len - 0.3)
	_set_state("boss_intro")


func _update_boss_intro(real: float) -> void:
	var b := _intro_boss
	if not is_instance_valid(b):
		_end_boss_intro()
		return
	# sorti de son apparition, il attendrait d'attaquer : on le fige jusqu'au combat
	if b.process_mode != Node.PROCESS_MODE_DISABLED and str(b.get("_state")) != _intro_pose:
		b.process_mode = Node.PROCESS_MODE_DISABLED
	if not _intro_roar and _state_t >= 0.3:
		# rugissement : grondement grave, coup sourd, secousse
		_intro_roar = true
		shake = 0.86 if _intro_mini else 1.45
		sfx.play("hurt", 0.4, 1.0)
		sfx.play("strike", 0.42, 2.0)
		sfx.play("whoosh", 0.5, -2.0)
	var target := 1.0 if _state_t < _intro_len - 0.45 else 0.0
	_intro_w = move_toward(_intro_w, target, real / (0.5 if target > 0.5 else 0.4))
	hud.cine = _intro_w * _intro_w * (3.0 - 2.0 * _intro_w)
	if _state_t >= _intro_len:
		_end_boss_intro()


func _end_boss_intro() -> void:
	var b := _intro_boss
	_intro_boss = null
	_intro_w = 0.0
	hud.cine = 0.0
	hud.end_boss_card(0.2)
	if is_instance_valid(b):
		b.process_mode = Node.PROCESS_MODE_INHERIT
	if not _intro_wave.is_empty():
		_spawn_list(_intro_wave)
	_intro_wave = []
	_set_state("play")


## Un toucher passe l'entrée (après 0,5 s) : la caméra revient en douceur.
func _boss_intro_tap(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		pressed = event.pressed
	if pressed and _state_t >= 0.5 and _intro_len > _state_t + 0.4:
		_intro_len = _state_t + 0.4
		hud.end_boss_card(0.25)


## Plan rapproché sur le boss, mêlé au cadrage de l'arène selon _intro_w.
func _boss_intro_cam() -> Transform3D:
	var base := _cam_base.translated(Vector3(0, 0, _cam_dz))
	if not is_instance_valid(_intro_boss):
		return base
	var p := _intro_boss.global_position
	var f := Vector3(clampf(p.x, -HALF.x, HALF.x), 0.0, clampf(p.z, -HALF.y + 1.5, HALF.y - 1.5))
	var look := f + Vector3(0, 1.3 if _intro_mini else 2.6, 0)
	var eye := f + (Vector3(0, 6.0, 7.5) if _intro_mini else Vector3(0, 9.0, 12.0))
	var close := Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
	var w := _intro_w * _intro_w * (3.0 - 2.0 * _intro_w)
	return base.interpolate_with(close, w * (0.7 if _intro_mini else 0.55))


func spawn_minions(list: Array) -> void:
	_spawn_list(list)


## Vrai pour un gardien de salle (Ō-Kappa et les mini-boss des autres mondes).
func is_mini_boss(k: String) -> bool:
	return MINI_BOSS.values().has(k)


func boss_killed(b: Node3D) -> void:
	_count_kill(String(b.kind), true)
	_mood_to = 0.0  # le ciel se rouvre
	pickups.drop(b.position, "xp", 8)
	pickups.drop(b.position, "coin", 10)
	var clean := not _scratched
	if is_mini_boss(String(b.kind)):
		mini_kills += 1
		if meta.learned("p4"):
			heal(1)  # Kintsugi (Arbre du pinceau) : chaque gardien vaincu rend un cœur
		_pending_levels += 1  # le gardien vaincu offre un rouleau
		music.end_boss(true)
		if clean and room < ROOMS:
			# aucun coup reçu : un rouleau d'exception (épique ou légendaire) à la fin du combat
			_flawless_pending = true
			hud.toast("SANS UNE ÉGRATIGNURE")
			float_text(b.position, "SANS UNE ÉGRATIGNURE", Toon.GOLD)
	else:
		boss_kills += 1
		music.end_boss(false)  # le jingle de victoire suit
		if clean:
			_flawless_boss = true
			float_text(b.position, "SANS UNE ÉGRATIGNURE", Toon.GOLD)
	score.on_boss(is_mini_boss(String(b.kind)), clean, chain)
	shake = 1.68
	sfx.play("kill", 0.6)
	feel("boss_death")
	_splash(b.position, Toon.VERMILION, 30)
	_splash(b.position, Toon.GOLD, 20)
	# gardien vaincu (le boss du monde a sa propre fin au ralenti) : même ralenti que le dernier ennemi
	if is_mini_boss(String(b.kind)) and room < ROOMS:
		var others := false
		for bo in bosses:
			if is_instance_valid(bo) and bo != b and not bo.dead:
				others = true
		for e in enemies:
			if is_instance_valid(e) and not e.dead and not e.dummy:
				others = true
		if not others:
			_start_slowmo(b.position)


## Retour haptique nommé (motifs dans sfx.gd) : sans effet hors mobile ou si l'option est coupée.
func feel(kind: String, boost := 0.0) -> void:
	sfx.haptic(kind, boost)


## Arrêt sur image après un coup : `base` + un cran par touche de la série (plafonds par coup et par trait).
## Jamais pour le robot, ni hors du jeu (pause, rouleaux, mort), ni pendant le pas de côté automatique.
func _add_hitstop(base: float) -> void:
	if _bot != null or _auto_step or game_over or not (state in ST_FIGHT):
		return
	var want := minf(HITSTOP_MAX, base + HITSTOP_STEP * float(clampi(combo - 1, 0, 5)))
	want = minf(want, _hitstop + maxf(0.0, HITSTOP_STROKE - _stroke_stop))
	if want <= _hitstop:
		return
	_stroke_stop += want - _hitstop
	_hitstop = want


## Poussée de caméra dans le sens du coup (`amount` m), qui retombe vite (_process).
func _cam_kick(dir: Vector3, amount: float) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.0001:
		return
	_kick = d.normalized() * amount


## Hauteur du son de coup : gamme pentatonique qui monte avec la série.
func _combo_pitch() -> float:
	return float(COMBO_PITCH[clampi(combo - 1, 0, COMBO_PITCH.size() - 1)])


func small_hit(pos: Vector3) -> void:
	_splash(pos, Toon.VERMILION, 4)
	sfx.play("slash", randf_range(1.2, 1.5), -8.0)


func big_hit(pos: Vector3) -> void:
	shake = maxf(shake, 0.42)
	sfx.play("kill", 0.9)
	feel("heavy")
	_splash(pos, Toon.VERMILION, 24)
	_blot(pos, Toon.VERMILION, 0.9, 2.5)


func clang(pos: Vector3) -> void:
	shake = maxf(shake, 0.08)
	sfx.play("empty", 0.5)
	feel("clang")
	_splash(pos, Toon.FOAM, 10)


func splash(pos: Vector3, color: Color, amount: int) -> void:
	_splash(pos, color, amount)


## Pose les ennemis de `list` à `min_d` m au moins du héros (renforts : REINF_DIST).
func _spawn_list(list: Array, min_d := 4.5) -> void:
	# élite : dès le 4e combat (hors gardiens), chance du monde (worlds.gd « elite ») ; au plus un par vague,
	# deux dès la salle 10 ; l'épreuve (TRIAL_ROOM) en garantit un
	var elite_at := -1
	var elite_n := 0
	if room >= 4 and room != MINI_ROOM and room != ROOMS and not in_hub and not list.is_empty():
		var chance := world_diff("elite", Enemy.elite_chance(current_world)) * (2.0 if "mask" in curses else 1.0)  # Masque fendu
		var rolls := 2 if room >= 10 else 1
		for roll in rolls:
			if randf() < chance:
				elite_n += 1
		if _elite_due > 0:
			elite_n = maxi(elite_n, 1)
		if elite_n > 0:
			elite_at = randi() % list.size()
	var idx := -1
	for k in list:
		idx += 1
		var e := Enemy.new()
		e.setup(String(k), hero, self)
		_discover(String(k))
		var p := Vector3.ZERO
		for attempt in 30:
			p = arena.random_point(hero.position, min_d)
			if not hazards.is_hole(p, -0.8):
				break
		e.position = p
		add_child(e)
		_apply_curses(e)
		if _gentle_room():
			e._tempo *= 0.75  # premier tutoriel : plus lents (marche, annonces)
		# plus robustes : ×2, et +4 % par combat dans le monde
		e.hp *= float(Worlds.world(current_world).hp_mult) * ENEMY_HP_MULT * (1.0 + 0.04 * float(maxi(room - 1, 0)))
		if elite_n > 0 and idx >= elite_at:
			if e.can_be_elite():
				e.promote(Enemy.roll_affixes(current_world))
				elite_n -= 1
				_elite_due = maxi(0, _elite_due - 1)
		# scellé : jamais le premier ennemi du combat (donc jamais seul au début), au plus _seal_quota
		if _seal_quota > 0 and _room_spawned > 0 and e.can_be_sealed() and randf() < SEALED_PICK:
			var figs := seal_figs()
			if not figs.is_empty():
				e.set_seal(String(figs[randi() % figs.size()]))
				_seal_quota -= 1
				sealed_set += 1
		_room_spawned += 1
		e.set_meta("max_hp", e.hp)
		enemies.append(e)


## Capture : un yōkai scellé (figure `fig`, sorte `k` ou la première du monde) devant le héros, deux autres à
## ses côtés ; tous figés (mannequins), pour juger la lisibilité de l'ofuda à la distance de jeu.
func _capture_sealed(fig: String, k: String, far: bool) -> void:
	var kinds: Array = Worlds.world(current_world).get("enemies", {"oni": 1}).keys()
	var kk := k if k != "" else String(kinds[0])
	var hp := hero.position
	var dz := 5.2 if far else 3.6
	for pk in _pockets:
		# recoins (coffres, stèles) retirés : rien d'autre que les yōkai dans l'image
		if is_instance_valid(pk["node"]):
			(pk["node"] as Node).queue_free()
	_pockets.clear()
	# les deux autres : des yōkai propres au monde (après les communs oni, kappa, brute, tate, funa)
	var spots := [[kk, Vector3(0.4, 0, -dz), true], [String(kinds[mini(5, kinds.size() - 1)]), Vector3(-2.6, 0, -dz - 1.4), false],
		[String(kinds[mini(7, kinds.size() - 1)]), Vector3(2.8, 0, -dz - 0.6), false]]
	for sp in spots:
		var e := Enemy.new()
		e.setup(String(sp[0]), hero, self)
		e.position = arena.clamp_walk(hp + Vector3(sp[1]), 0.8)
		add_child(e)
		e.hp *= float(Worlds.world(current_world).hp_mult) * ENEMY_HP_MULT
		if bool(sp[2]):
			e.set_seal(fig if fig != "" else "loop")
			sealed_set += 1
		e.dummy = true
		e.set_meta("max_hp", e.hp)
		enemies.append(e)


## Capture : le héros trace un trait à travers le scellé : sa figure (`right`, le sceau se brise) ou un trait droit
## (le coup ricoche).
func _capture_seal_stroke(right: bool) -> void:
	var tgt: Node3D = null
	for e in enemies:
		if is_instance_valid(e) and not e.dead and String(e.seal_fig) != "":
			tgt = e
	if tgt == null or hero == null:
		return
	var o := hero.position
	var t := Vector3(tgt.position.x, 0, tgt.position.z)
	var wps := PackedVector3Array()
	if right:
		wps = BotShapes.through(String(tgt.seal_fig), o, t, float(tgt.radius) + HIT_REACH * 0.6, Callable(self, "_clamp_point"))
	if wps.is_empty():
		wps.append(t + (t - o).normalized() * 2.6)
	var s := InkStroke.new(o, stroke_layer)
	stroke_layer += 1
	add_child(s)
	for p in wps:
		s.extend_to(_clamp_point(p), 40.0)
	_launch(s)


## Scellés possibles dans le combat qui commence : aucun avant l'étape 2, ni au tutoriel, ni aux combats de
## gardien et de boss ; sinon un (SEALED_ROOM), parfois deux (SEALED_TWO).
func _seal_roll() -> int:
	if stage_i < 1 or in_hub or state == "tuto" or room == MINI_ROOM or room >= ROOMS or _gentle_room():
		return 0
	if seal_figs().is_empty() or randf() >= SEALED_ROOM:
		return 0
	return 2 if randf() < SEALED_TWO else 1


## Figures qu'un sceau peut porter : celles que le joueur connaît (les six de base, et celles qu'un rouleau
## apprend : meta.fig_learned) dont l'interface a le glyphe (UiKit.FIGURES) ; ni ensō ni crochet aux deux
## premières étapes du monde 1 (comme les coffres scellés).
func seal_figs() -> Array:
	var out: Array = []
	var learn: bool = meta != null and meta.has_method("fig_learned")
	for k in SEALED_FIGS:
		var key := String(k)
		if not UiKit.FIGURES.has(key):
			continue
		if not (SEALED_BASE.has(key) or (learn and bool(meta.call("fig_learned", key)))):
			continue
		if current_world == 1 and stage_i < 2 and (key == "enso" or key == "hook"):
			continue
		out.append(key)
	return out


## Sceau brisé par la bonne figure (_check_slashes) : il meurt d'un coup, l'ofuda s'envole (seal_mark.gd) ;
## points du sceau (score.on_seal), un peu d'or et d'encre.
func _seal_break(e: Node3D, dir: Vector3) -> void:
	var p: Vector3 = e.position
	_stroke_hit = true
	_chain_t = 0.0
	sealed_broken += 1
	e.unseal_kill(dir)
	vfx.impact(p, dir, true)
	_add_hitstop(HITSTOP_KILL)
	_cam_kick(dir, 0.25)
	_on_enemy_killed(e)
	vfx.kill_burst(p, dir, true, _ink_tint(e))
	vfx.ring(Vector3(p.x, 0.06, p.z), Toon.GOLD, 1.7)
	hud.screen_flash = maxf(hud.screen_flash, 0.3)
	kills += 1
	_stroke_kills += 1
	powers.on_kill(e)
	if state != "tuto":
		score.on_seal(chain)
	pickups.drop(p, "coin", SEALED_GOLD)
	elan = minf(elan_max(), elan + ELAN_PER_HIT + elan_max() * SEALED_INK)
	shake = maxf(shake, 0.4)
	sfx.play("kill", _combo_pitch())
	sfx.play("strike", 1.7, -6.0)
	sfx.play("shrine", 1.3, -5.0)
	feel("kill")
	hero.slash_pop()
	_slash_mark(p, dir)
	if combo >= 3:
		_combo_label(p, combo)
	coach.on_event("seal")
	seal_event()


## Coup sur un sceau (ricochet ou sceau brisé) : en capture (`fige=X`), l'image se fige X s plus tard.
func seal_event() -> void:
	if _cap_fige < 0.0:
		return
	get_tree().create_timer(_cap_fige, true, false, true).timeout.connect(func() -> void: _cap_frozen = true)
	_cap_fige = -1.0


func xp_need() -> int:
	# courbe plus raide : ~1 niveau par salle au début, puis de plus en plus espacé ; ×XP_SEAL_K depuis les
	# portes à sceaux (leurs rouleaux d'école et de l'oni remplacent une partie des rouleaux de niveau)
	return int(round(float(8 + 5 * level + level * level) * XP_SEAL_K))


## Butin ramassé (appelé par pickups.gd).
func collect(kind: String, value: int) -> void:
	if kind == "xp":
		xp += value
		sfx.play("xp", 1.0 + randf() * 0.15, -10.0)
		while xp >= xp_need():
			xp -= xp_need()
			level += 1
			_pending_levels += 1
			hud.toast("NIVEAU %d" % level)
			sfx.play("levelup", 1.0, -3.0)
			feel("level")
	else:
		run_gold += value * (2 if "mask" in curses else 1)  # Masque fendu : chaque pièce en vaut deux
		sfx.play("coin", 1.0, -8.0)


## Un ennemi tombe : il lâche de l'expérience et parfois de l'or.
func _on_enemy_killed(e: Node3D) -> void:
	if e.dummy:
		return  # mannequin : pas de butin
	var k := String(e.kind)
	if state != "tuto":
		_count_kill(k)  # bestiaire : victoires
		score.on_kill(int(KIND_XP.get(k, 1)), e.has_meta("elite"), not _fig_mods.is_empty() or float(score.fig_t) > 0.0 or e.has_meta("unsealed"), chain)
	_last_kill_pos = e.position
	if brush == "chi" and aspect == 1 and state == "play" and _pact_key != stroke_id \
			and (not _fig_mods.is_empty() or float(score.fig_t) > 0.0 or e.has_meta("unsealed")):
		# Calame · Pacte : une figure qui tue rend un demi-cœur (deux demis : un cœur)
		_pact_key = stroke_id
		_half += 1
		if _half >= 2:
			_half = 0
			heal(1)
		else:
			float_text(e.position + Vector3(0, 0.6, 0), "+½", Toon.VERMILION)
	pickups.drop(e.position, "xp", int(KIND_XP.get(k, 1)))
	if randf() < (0.8 if k == "brute" else 0.4):
		pickups.drop(e.position, "coin", 2 if k == "brute" else 1)
	if e.has_meta("elite"):
		# défi d'un recoin relevé : belle récompense
		pickups.drop(e.position, "coin", 8)
		pickups.drop(e.position, "xp", 6)
		hud.toast("DÉFI RELEVÉ")
		sfx.play("levelup", 1.2, -4.0)
		if e.has_meta("seal_oni"):
			_seal_picks.append({"rank": 1})  # sceau de l'oni : rouleau rare ou épique


func _room_cleared() -> void:
	score.on_room_clear(room)
	_cancel_stroke()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	hazards.calm()  # plus de vague une fois la salle nettoyée
	pickups.gather()
	if room >= ROOMS:
		_victory()
		return
	if arena.stage and _enc >= 0:
		arena.clear_zone(_enc)
		var j: int = _enc
		_enc = -1
		# sceau d'élément : un rouleau de cette école à la fin du premier combat de l'étape
		if seal_reward in SealGate.SCHOOLS and arena.zones_done() == 1:
			_seal_picks.append({"school": seal_reward})
		# sceau koban : la grosse somme d'or à la fin de l'étape
		if seal_reward == "gold" and arena.zones_left() == 0:
			_seal_gold()
		if arena.zones_left() > 0:
			_open_passage(j + 1)
			if room in SANCTUARIES:
				_spawn_shrine()
			return
	_open_gate()
	if room in SANCTUARIES:
		_spawn_shrine()


## Zone nettoyée au milieu d'une étape : la haie d'encre du nord se renfonce, la route continue.
func _open_passage(j: int) -> void:
	elan = elan_max()
	_set_state("play")
	var jc: Vector3 = arena.join_center(j)
	hud.banner("ZONE NETTOYÉE", "COMBAT %d / %d" % [arena.zones_done() + 1, arena.zones.size()], Toon.GOLD, 1.6)
	_splash(jc + Vector3(0, 0.4, 0), Toon.SUMI, 14)
	shake = maxf(shake, 0.1)
	sfx.play("torii", 1.15, -5.0)
	sfx.play("whoosh", 0.6, -6.0)
	feel("clear")


func _open_gate() -> void:
	elan = elan_max()
	_set_state("play")
	var was_open: bool = arena.gate_open
	arena.open_gate()
	# fin d'étape bien visible : le torii s'éveille (arena), chemin d'encre du héros jusqu'à lui
	if room > 0 and not in_hub and not was_open:
		hud.banner("ÉTAPE NETTOYÉE", "", Toon.GOLD, 1.8)
		arena.gate_path(hero.position)
		shake = maxf(shake, 0.12)
		sfx.play("torii", 1.0, -3.0)
		feel("clear")
	sfx.play("shot", 1.4, -4.0)
	sfx.play("whoosh", 0.7, -6.0)


## Après un rouleau ou un pacte choisi hors fin de niveau : on rend la main (le torii s'il est ouvert).
func _after_room_pick() -> void:
	if arena.gate_open:
		_open_gate()
	else:
		elan = elan_max()
		_set_state("play")


## Sanctuaire facultatif (après les combats de SANCTUARIES) : un autel de pierre (PuzzleArt.build_altar) posé au
## milieu du tronçon qui suit le combat, à SHRINE_BEFORE_GATE m au moins avant le torii de sortie, loin du héros
## et des recoins. Le toucher (anneau d'approche au sol) propose un pacte ; passer le torii l'ignore.
func _spawn_shrine() -> void:
	var p := _shrine_spot()
	_shrine = Node3D.new()
	add_child(_shrine)
	_shrine.position = Vector3(p.x, 0, p.z)
	PuzzleArt.build_altar(_shrine, current_world)
	hud.banner("SANCTUAIRE", "UN PACTE ?", Color("#7A1F1A"), 2.6)
	sfx.play("shrine", 1.0, -4.0)


const SHRINE_BEFORE_GATE := 6.5  # autel : au moins cette distance (m) avant le torii de sortie
const SHRINE_CLEAR := 2.6  # … et loin du héros et des recoins


## Place de l'autel : milieu du dernier tronçon de l'étape (entre la fin du combat et le torii), décalé vers
## un côté libre ; à défaut (salle unique) près du torii ou du héros.
func _shrine_spot() -> Vector3:
	var gp: Vector3 = arena.gate_pos
	var cands: Array = []
	if arena.stage and not arena.zones.is_empty():
		var z: Rect2 = arena.zones[arena.zones.size() - 1]
		# le tronçon est traversé du sud (z grand) au nord (torii) : milieu du tronçon, jamais plus près du torii
		var zc := maxf(z.get_center().y, gp.z + SHRINE_BEFORE_GATE)
		for dx in [0.0, 1.8, -1.8, 3.0, -3.0]:
			for dz in [0.0, 1.5, -1.5, 3.0]:
				cands.append(Vector3(gp.x + float(dx), 0, zc + float(dz)))
	else:
		var base: Vector3 = gp if arena.gate_open else hero.position + Vector3(0, 0, -1.5)
		for dx in [2.3, -2.3, 3.2, -3.2]:
			cands.append(base + Vector3(float(dx), 0, 2.2))
	var best := Vector3.INF
	var best_score := -1.0e9
	for c in cands:
		var q: Vector3 = arena.clamp_walk(c, 0.9)
		var dh := Vector2(q.x - hero.position.x, q.z - hero.position.z).length()
		var dg := Vector2(q.x - gp.x, q.z - gp.z).length()
		var dp := 1.0e9
		for pk in _pockets:
			var pp: Vector3 = pk["pos"]
			dp = minf(dp, Vector2(q.x - pp.x, q.z - pp.z).length())
		var sc := minf(dh, 6.0) + minf(dp, 4.0) + minf(dg, SHRINE_BEFORE_GATE + 2.0)
		if dh < SHRINE_CLEAR or dp < SHRINE_CLEAR:
			sc -= 50.0
		if dg < SHRINE_BEFORE_GATE and arena.stage:
			sc -= 20.0
		sc -= 0.3 * Vector2(q.x - c.x, q.z - c.z).length()  # un candidat déplacé par clamp_walk vaut moins
		if sc > best_score:
			best_score = sc
			best = q
	if best == Vector3.INF:
		best = arena.clamp_walk(hero.position + Vector3(0, 0, -3.0), 0.9)
	return best


func _open_upgrades() -> void:
	_pick_mode = "upgrade"
	var ids: Array = powers.offer(room)
	_last_offer = ids
	var infos: Array = []
	for id in ids:
		infos.append(powers.describe(id))
	picker.open(ids, infos)
	sfx.play("shot", 0.6)


## Rouleau de sceau : trois rouleaux de l'école du sceau ({"school": s}) ou rares / épiques ({"rank": 1}, oni).
func _open_seal_pick(d: Dictionary) -> void:
	_pick_mode = "seal"
	_seal_cur = d
	var ids: Array = powers.offer_seal(String(d.get("school", "")), int(d.get("rank", 0)))
	if _bot != null:
		print("BOT SCEAU rouleau %s : %s" % [str(d), str(ids)])
	if ids.is_empty():
		_set_state("play")
		return
	_last_offer = ids
	var infos: Array = []
	for id in ids:
		infos.append(powers.describe(id))
	picker.open(ids, infos)
	vfx.ring(Vector3(hero.position.x, 0.05, hero.position.z), SealGate.glow(String(d.get("school", "oni"))), 2.6)
	sfx.play("levelup", 1.1, -4.0)
	sfx.play("shot", 0.6)


## Vrai si l'étape `si` (index) finit sur deux portes : pas avant le gardien ni avant le boss, jamais au
## sanctuaire ni au dojo.
func gate_choice(si: int) -> bool:
	if in_hub or state == "tuto" or si + 1 >= STAGE_PLAN.size() - 1:
		return false
	return si + 1 != stage_of(MINI_ROOM) - 1


## Tirage des deux sceaux : deux différents parmi les écoles (pondérées vers celles du build, une école neuve
## de temps en temps), l'or, le cœur (plus souvent quand la vie est basse) et l'oni.
func _draw_seals(count := 2) -> Array:
	var cands: Array = []
	var counts: Dictionary = powers.school_counts()
	var ew: Array = []
	var etot := 0.0
	for sc in SealGate.SCHOOLS:
		if not powers.school_open(String(sc)):
			continue
		var w := 0.3 + float(counts.get(sc, 0))
		ew.append([sc, w])
		etot += w
	for e in ew:
		cands.append([e[0], 1.3 * float(e[1]) / maxf(etot, 0.01)])  # les écoles pèsent 1,3 en tout
	cands.append(["gold", 0.45])
	cands.append(["heart", 0.3 + (0.5 if hero.hp * 2 <= hero.max_hp else 0.0)])
	cands.append(["oni", 0.45])
	var out: Array = []
	for _n in count:
		var tot := 0.0
		for c in cands:
			tot += float(c[1])
		var x := randf() * tot
		for i in cands.size():
			x -= float(cands[i][1])
			if x <= 0.0 or i == cands.size() - 1:
				out.append(String(cands[i][0]))
				cands.remove_at(i)
				break
	return out


## Sceau du cœur ou de l'oni : la source (ou le défi) de l'étape est garantie ; elle prend un recoin libre,
## sinon celui d'un coffre ou d'une source (le coffre du départ en dernier recours).
func _seal_pocket(kinds: Array, spots: Array) -> void:
	var want := "spring" if seal_reward == "heart" else ("elite" if seal_reward == "oni" else "")
	if want == "" or want in kinds:
		return
	var best := -1
	for pref in ["", "chest", "spring", "elite"]:
		for i in range(1, spots.size()):
			if spots[i] != Vector3.INF and String(kinds[i]) == pref:
				best = i
				break
		if best >= 0:
			break
	if best < 0 and not spots.is_empty() and spots[0] != Vector3.INF:
		best = 0
	if best >= 0:
		kinds[best] = want


## Sceau koban : l'or de l'étape tombe en pluie de pièces (SEAL_GOLD, +SEAL_GOLD_STEP par monde).
func _seal_gold() -> void:
	var total := SEAL_GOLD + SEAL_GOLD_STEP * maxi(0, current_world - 1)
	if charm == "or":
		total *= 2  # omamori de l'or
		charm_fx()
	var n := 12
	pickups.drop(_last_kill_pos, "coin", n, int(ceil(float(total) / float(n))))
	vfx.ring(Vector3(_last_kill_pos.x, 0.05, _last_kill_pos.z), Toon.GOLD, 3.0)
	sfx.play("coin", 0.7, -2.0)


## Robot : porte choisie (0 gauche, 1 droite). Mode pouvoirs : l'école la plus prise, sinon l'oni ; sinon
## en alternance.
func bot_gate() -> int:
	var ks: Array = arena.gate_seals()
	if ks.size() < 2:
		return 0
	if _bot != null and String(_bot.get("mode")) == "powers":
		var counts: Dictionary = powers.school_counts()
		var best := 0
		var bv := -2
		for i in ks.size():
			var k := String(ks[i])
			var v: int = (int(counts.get(k, 0)) + 1) if k in SealGate.SCHOOLS else (0 if k == "oni" else -1)
			if v > bv:
				bv = v
				best = i
		return best
	return (stage_i + current_world) % ks.size()


## Sanctuaire : PACT_OFFER pactes (au plus un légendaire) en cartes v2, et « refuser » (un cœur, sinon de l'or).
## La carte reçoit : name, school, leg, fx (lignes [picto, valeur, libellé, malus ?]), line, pact = true.
func _open_sanctuary() -> void:
	_pick_mode = "curse"
	var pool: Array = []
	for id in CURSES.keys():
		if id in curses:
			continue
		if ("ronin" in curses or charm == "ascete") and (id == "haste" or id == "cursed_ink"):
			continue  # le serment interdit tout soin : les pactes qui en promettent un ne sont plus proposés
		pool.append(id)
	pool.shuffle()
	var ids: Array = []
	var leg_done := false
	for id in pool:
		if ids.size() >= PACT_OFFER:
			break
		var is_leg := bool(CURSES[id].get("leg", false))
		if is_leg and leg_done:
			continue
		leg_done = leg_done or is_leg
		ids.append(id)
	var infos: Array = []
	for id in ids:
		infos.append(pact_info(String(id)))
	ids.append("refuse")
	_last_offer = ids
	# refuser se paie en or ; sans assez d'or, le bouton est éteint : il faut sceller un pacte
	var cost := refuse_cost()
	infos.append({"name": "Refuser", "pact": false, "refuse": true, "cost": cost, "can": run_gold >= cost, "level": -1, "free": refuse_free()})
	picker.open(ids, infos)
	sfx.play("hurt", 0.6, -6.0)
	sfx.play("pact", 1.0, -4.0)


## Fiche d'un pacte pour la carte v2 du sanctuaire (picker._pact_face) : lignes MALUS puis GAIN(S).
func pact_info(id: String) -> Dictionary:
	var cd: Dictionary = CURSES[id]
	var fx: Array = []
	var m: Array = cd["malus"]
	fx.append([String(m[0]), String(m[1]), String(m[2]), true])
	var g: Array = cd["gain"]
	fx.append([String(g[0]), String(g[1]), String(g[2]), false])
	if cd.has("gain2"):
		var g2: Array = cd["gain2"]
		fx.append([String(g2[0]), String(g2[1]), String(g2[2]), false])
	return {"name": String(cd["name"]), "pact": true, "school": String(cd.get("school", "ink")), "leg": bool(cd.get("leg", false)),
		"fx": fx, "line": String(cd.get("line", "")), "glyph": "pact_" + id, "level": -1}


## Gardien vaincu sans un coup reçu : trois rouleaux épiques ou légendaires (verrous et plafond respectés).
func _open_flawless() -> void:
	_pick_mode = "flawless"
	var ids: Array = powers.offer_flawless()
	if ids.is_empty():
		_open_upgrades()
		return
	_last_offer = ids
	var infos: Array = []
	for id in ids:
		infos.append(powers.describe(id))
	picker.open(ids, infos, "SANS UNE ÉGRATIGNURE", "Gardien vaincu sans un coup : un rouleau d'exception")
	sfx.play("levelup", 0.9, -2.0)
	sfx.play("shot", 0.6)


## Prix du refus au sanctuaire dans le monde en cours.
func refuse_cost() -> int:
	if refuse_free():
		return 0
	return REFUSE_COST + REFUSE_COST_STEP * maxi(0, current_world - 1)


## Omamori du pacte : le premier refus du monde est gratuit, même sans or.
func refuse_free() -> bool:
	return charm == "pacte" and not _refuse_free_used


## « Refuser » au sanctuaire : on paie le prix (l'or de la partie, converti en encre à la fin).
func _pay_refuse() -> void:
	if refuse_free():
		_refuse_free_used = true
		float_text(hero.position, "REFUS OFFERT", Gear.CHARMS["pacte"]["col"])
		charm_fx()
		sfx.play("shrine", 1.2, -4.0)
		return
	run_gold = maxi(0, run_gold - refuse_cost())
	sfx.play("coin", 0.6, -4.0)


func _on_reroll() -> void:
	sfx.play("whoosh", 1.2, -4.0)
	if _pick_mode == "seal":
		_open_seal_pick(_seal_cur)
	elif _pick_mode == "curse":
		_open_sanctuary()
	elif _pick_mode == "flawless":
		_open_flawless()
	else:
		_open_upgrades()


func _on_picked(id: String) -> void:
	if _pick_mode == "curse":
		if id == "refuse" and run_gold < refuse_cost():
			# pas assez d'or pour refuser (le bouton est éteint ; garde-fou pour les robots) : premier pacte proposé
			for oid in _last_offer:
				if String(oid) != "refuse":
					id = String(oid)
					break
		if id != "refuse":
			_take_curse(id)
		else:
			_pay_refuse()
		if _extra_picks > 0:
			_extra_picks -= 1
			_open_upgrades()
		else:
			_after_room_pick()
		return
	powers.add(id)
	coach.on_pick(id)  # rouleau de figure : le coach montre la figure à tracer
	sfx.play("slash", 1.2, -4.0)
	if _extra_picks > 0:
		_extra_picks -= 1
		_open_upgrades()
		return
	if _pick_context == "level":
		_set_state("play")
	else:
		_after_room_pick()


## Passage du torii. Joueur : petit rituel (le héros passe sous l'arche, éclat de lumière, lavis d'encre
## qui part du torii et couvre l'écran) ; robot : simple coup de pinceau. La suite apparaît derrière.
func _transit() -> void:
	_set_state("transit")
	_rebuilt = false
	_cancel_stroke()
	_reset_stroke_state(true)  # pas de technique (ensō, iai…) qui déborde sur la suite
	hero.stop_dash()
	_ritual = _bot == null
	_ritual_from = hero.position
	_ritual_flash = false
	if _ritual:
		hero.face(Vector3(0, 0, -1))
		hero.ch.play("Walking_A", 1.3)
		arena.gate_flash()
		sfx.play("whoosh", 0.5, -4.0)
	else:
		sfx.play("whoosh", 0.6)


## Rituel du torii (temps réel) : 0-0,45 s le héros passe l'arche ; éclat ; 0,35-0,75 s le lavis d'encre
## s'étend depuis le torii ; la suite se construit sous l'encre ; 0,8-1,15 s l'encre se retire.
func _update_ritual() -> void:
	var t := _state_t
	if not _rebuilt:
		var k := clampf(t / 0.45, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var gp: Vector3 = arena.gate_pos
		hero.position = _ritual_from.lerp(Vector3(gp.x, 0, gp.z - 0.8), e)
		_prev_hero = hero.position
		hud.wash_c = cam.unproject_position(gp + Vector3(0, 1.0, 0))
		if t >= 0.36 and not _ritual_flash:
			_ritual_flash = true
			arena.gate_flash()
			hud.screen_flash = maxf(hud.screen_flash, 0.55)
			hero.ch.play_once("Interact", 1.6)
			sfx.play("torii", 1.25, -4.0)
			sfx.play("whoosh", 0.8, -3.0)
			feel("clear")
		hud.wash_out = false
		hud.wash = clampf((t - 0.35) / 0.4, 0.0, 1.0)
		if t >= 0.8:
			hud.wash = 1.0
			_rebuild_room()
			# la suite : le héros arrive à pied depuis le sud pendant que l'encre se retire, la caméra le rattrape
			_walk_from = arena.start + Vector3(0, 0, 2.2)
			hero.position = _walk_from
			_prev_hero = hero.position
			hero.ch.play("Walking_A", 1.2)
			_cam_dz = _cam_target() + 1.6
	else:
		var k2 := clampf((t - 0.8) / 0.6, 0.0, 1.0)
		hud.wash_out = true
		hud.wash = 1.0 - k2 * k2 * (3.0 - 2.0 * k2)
		var kw := clampf((t - 0.8) / 0.7, 0.0, 1.0)
		hero.position = _walk_from.lerp(arena.start, kw * (2.0 - kw))
		_prev_hero = hero.position
		if t >= 1.5:
			hero.position = arena.start
			hero.ch.play(hero.ch.idle)
	if t >= 1.5 and _rebuilt:
		hud.wash = 0.0
		hud.wash_out = false
		_set_state("play")


func _rebuild_room() -> void:
	_rebuilt = true
	# porte franchie : son sceau vaut pour l'étape qui suit (aucun : torii unique, sanctuaire, gardien)
	var seals: Array = arena.gate_seals()
	var gp: int = arena.gate_pick
	seal_reward = String(seals[gp]) if gp >= 0 and gp < seals.size() else ""
	if _bot != null and not seals.is_empty():
		print("BOT SCEAU monde %d étape %d : %s parmi %s" % [current_world, stage_i + 2, seal_reward, str(seals)])
	if is_instance_valid(_shrine):
		_shrine.queue_free()
	_shrine = null
	in_hub = false
	# on quitte le sanctuaire (mannequins) ou l'étape (défi laissé derrière) : personne ne suit
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_attackers.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	for e in effects:
		if is_instance_valid(e.node):
			e.node.queue_free()
	effects.clear()
	_build_segment()


## Construit la suite pour le combat `room + 1` : l'étape qui le contient (on arrive au sud, les zones
## de combat se déclenchent en marchant) ou l'arène d'un gardien (le combat commence tout de suite).
func _build_segment() -> void:
	var t0 := Time.get_ticks_usec()
	var next := room + 1
	stage_i = clampi(stage_of(next) - 1, 0, STAGE_PLAN.size() - 1)
	var plan: Array = STAGE_PLAN[stage_i]
	_enc = -1
	_slowmo_t = -1.0
	_clear_pockets()
	hazards.clear()
	var boss_seg := next == MINI_ROOM or next >= ROOMS
	# deux portes à sceaux au bout de l'étape, sauf avant le gardien et avant le boss ; omamori des portes : une
	# fois par monde, la première fois qu'il y a un choix, trois portes
	var nk := 3 if charm == "portes" and not _portes_used and _gate_force.is_empty() else 2
	arena.gate_kinds = _gate_force.duplicate() if not _gate_force.is_empty() else (_draw_seals(nk) if gate_choice(stage_i) else [])
	if boss_seg:
		arena.build_room(next, ROOMS, randi(), MINI_ROOM)
	else:
		# (tests : `?room=N` au milieu d'une étape -> on reprend à son premier combat)
		room = int(plan[0]) - 1
		arena.build_stage(plan.size(), randi(), int(plan[0]) == 1)
		_build_pockets()
	if arena.gate_spots.size() == 3:
		_portes_used = true
		if _bot != null:
			print("BOT OMAMORI portes : trois portes %s (monde %d, étape %d)" % [str(arena.gate_seals()), current_world, stage_i + 1])
	hero.cancel_moves()
	hero.position = arena.start
	_prev_hero = hero.position
	hero.face(Vector3(0, 0, -1))
	hero.snap_facing()
	_cam_dz = _cam_target()
	arena.follow_camera(_cam_dz)
	# (arène de boss : la mesure s'arrête avant le combat, l'apparition du boss a la sienne)
	perf_mark("arena_build" if boss_seg else "stage_build", Time.get_ticks_usec() - t0)
	if boss_seg:
		_begin_room()
	elif room > 0:
		var wd: Dictionary = Worlds.world(current_world)
		hud.banner("ÉTAPE %d / %d" % [stage_i + 1, STAGE_PLAN.size()], "%d COMBATS" % plan.size(), wd.color, 2.2)


## Numéro d'étape (1..8) du combat `r` (0 : pas encore parti).
static func stage_of(r: int) -> int:
	if r <= 0:
		return 0
	for i in STAGE_PLAN.size():
		var p: Array = STAGE_PLAN[i]
		if r <= int(p[p.size() - 1]):
			return i + 1
	return STAGE_PLAN.size()


## Le héros entre dans la zone `i` de l'étape : les haies se dressent, le combat commence.
func _enter_zone(i: int) -> void:
	_enc = i
	arena.begin_zone(i)
	hero.position = _clamp_point(hero.position)
	if hero.dashing:
		# le reste du trait (tracé avant la haie) est ramené dans la zone
		var pth: PackedVector3Array = hero.path
		for k in range(pth.size()):
			pth[k] = _clamp_point(pth[k])
		hero.path = pth
	_prev_hero = hero.position
	shake = maxf(shake, 0.2)
	sfx.play("strike", 0.55, -2.0)
	sfx.play("whoosh", 0.5, -5.0)
	_splash(arena.join_center(i) + Vector3(0, 0.3, 0), Toon.SUMI, 16)
	_begin_room()


## Marche dans l'étape, hors combat : autel, torii, entrée de la zone suivante.
func _stage_roam() -> void:
	if is_instance_valid(_shrine) and not hero.dashing and Vector2(hero.position.x - _shrine.position.x, hero.position.z - _shrine.position.z).length() < 1.3:
		_shrine.queue_free()
		_shrine = null
		_pick_context = "room"
		_set_state("pick")
		_open_sanctuary()
		return
	if arena.gate_open and arena.gate_reached(hero.position):
		_transit()
		return
	var zi: int = arena.zone_entered(hero.position)
	if zi >= 0:
		_enter_zone(zi)


## Cadrage le long de l'étape : la zone de combat entière pendant un combat, sinon le héros au centre de
## l'écran (à peine en retrait), sans dépasser les bouts de l'étape. 0 pour une salle unique.
func _cam_target() -> float:
	if not arena.stage or hero == null:
		return 0.0
	var lo: float = arena.stage_rect.position.y + HALF.y
	var hi: float = arena.stage_rect.end.y - HALF.y
	var lead := CAM_LEAD
	if ctrl_mode == "pad" and hud != null:
		lead = lerpf(CAM_LEAD, CAM_LEAD_PAD, clampf(float(hud.pad_alpha), 0.0, 1.0))  # arène au-dessus du pad
	var t: float = hero.position.z - lead
	if _enc >= 0 and _enc < arena.zones.size():
		var z: Rect2 = arena.zones[_enc]
		t = z.get_center().y
	return clampf(t, lo, hi)


# ------------------------------------------------------------------ recoins de l'étape

## Recoins : un coffre au départ, puis selon le tirage une énigme de trait, une source de soin et un défi
## d'élite (dès l'étape 2).
func _build_pockets() -> void:
	_clear_pockets()
	var spots: Array = arena.pocket_spots
	var kinds: Array = []
	for i in spots.size():
		kinds.append("")
	if spots.size() > 0:
		kinds[0] = "chest"
	var slots: Array = []
	for i in range(1, spots.size()):
		if spots[i] != Vector3.INF:
			slots.append(i)
	slots.shuffle()
	# une petite énigme de trait par étape, presque toujours (à l'écart du chemin)
	if not slots.is_empty() and randf() < 0.9:
		kinds[int(slots.pop_back())] = "puzzle"
	if not slots.is_empty() and randf() < 0.4:
		kinds[int(slots.pop_back())] = "spring"
	if not slots.is_empty() and stage_i >= 1 and randf() < 0.65:
		kinds[int(slots.pop_back())] = "elite"
	if not slots.is_empty() and randf() < 0.35:
		kinds[int(slots.pop_back())] = "chest"
	_seal_pocket(kinds, spots)  # sceau du cœur ou de l'oni : sa source ou son défi, garantis
	for i in spots.size():
		var p: Vector3 = spots[i]
		var k := String(kinds[i])
		if k == "" or p == Vector3.INF:
			continue
		if k == "puzzle":
			spawn_puzzle("", p)
			continue
		if k == "chest" and stage_i >= 1 and randf() < SEAL_CHANCE:
			_spawn_sealed_chest(p)
			continue
		var sealed := (k == "spring" and seal_reward == "heart") or (k == "elite" and seal_reward == "oni")
		var pn := _pocket_node(k, p)
		if sealed:
			SealGate.marker(pn, seal_reward)  # le sceau choisi au torii flotte au-dessus
		_pockets.append({"kind": k, "pos": p, "used": false, "node": pn, "seal": sealed})


func _clear_pockets() -> void:
	for pk in _pockets:
		var n = pk["node"]  # peut déjà être libéré : pas de type (sinon erreur à l'affectation)
		if is_instance_valid(n):
			n.queue_free()
	_pockets.clear()


## Coffre laqué, source entourée de pierres, ou stèle de défi (鬼) : petits décors posés dans le recoin.
func _pocket_node(kind: String, p: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.position = Vector3(p.x, 0, p.z)
	match kind:
		"chest":
			# karabitsu laqué : coffre à pieds, ferrures d'or aux angles, couvercle à gradin, mon d'or en façade
			var lac := Toon.mat_shared(Color("#7A1F17"))
			var dark := Toon.mat_shared(Color("#2A0E0B"))
			var gold := Toon.mat(Color("#E0B04E"))
			gold.emission_enabled = true
			gold.emission = Color("#8A5A10")
			var W := 1.15
			var D := 0.78
			var H := 0.62
			var B := 0.16  # hauteur des pieds
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					Toon.part(n, Toon.box(Vector3(0.16, B, 0.16)), dark, Vector3(float(sx) * (W / 2.0 - 0.1), B / 2.0, float(sz) * (D / 2.0 - 0.1)))
			Toon.part(n, Toon.box(Vector3(W, H, D)), lac, Vector3(0, B + H / 2.0, 0))
			# ferrures : montants d'or aux quatre angles et bande basse
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					Toon.part(n, Toon.box(Vector3(0.09, H + 0.02, 0.09)), gold, Vector3(float(sx) * (W / 2.0 - 0.03), B + H / 2.0, float(sz) * (D / 2.0 - 0.03)))
			Toon.part(n, Toon.box(Vector3(W + 0.03, 0.06, D + 0.03)), gold, Vector3(0, B + 0.05, 0))
			# mon (blason rond) et moraillon en façade
			var mon := Toon.part(n, Toon.cyl(0.13, 0.13, 0.03, 20), gold, Vector3(0, B + H * 0.55, D / 2.0 + 0.01))
			mon.rotation.x = PI / 2.0
			Toon.part(n, Toon.box(Vector3(0.1, 0.18, 0.04)), gold, Vector3(0, B + H - 0.06, D / 2.0 + 0.02))
			var lid := Node3D.new()
			lid.name = "Lid"
			n.add_child(lid)
			lid.position = Vector3(0, B + H, -D / 2.0)  # charnière à l'arrière
			Toon.part(lid, Toon.box(Vector3(W + 0.06, 0.14, D + 0.06)), lac, Vector3(0, 0.07, D / 2.0))
			Toon.part(lid, Toon.box(Vector3(W - 0.14, 0.12, D - 0.2)), lac, Vector3(0, 0.2, D / 2.0))
			Toon.part(lid, Toon.box(Vector3(W + 0.08, 0.05, 0.12)), gold, Vector3(0, 0.1, D / 2.0))
			Toon.part(lid, Toon.box(Vector3(0.12, 0.05, D + 0.08)), gold, Vector3(0, 0.1, D / 2.0))
			Toon.part(lid, Toon.box(Vector3(0.18, 0.06, 0.18)), gold, Vector3(0, 0.28, D / 2.0))
			_disc(n, 1.0, Toon.flat(Color(Toon.SUMI, 0.22)), 0.015)
			# lueur d'or au sol qui respire tant qu'il est fermé (main._update_pockets)
			var glow := Toon.flat(Color(Toon.GOLD, 0.25))
			var gd := _disc(n, 1.35, glow, 0.02)
			gd.name = "Glow"
		"spring":
			# chōzubachi : bassin de pierre taillée, filet d'eau d'un tuyau de bambou, louche de bois
			var stone := Toon.mat_shared(Color("#8E8A84"))
			var dark_st := Toon.mat_shared(Color("#6E6A64"))
			Toon.part(n, Toon.box(Vector3(0.95, 0.12, 0.7)), dark_st, Vector3(0, 0.06, 0))
			Toon.part(n, Toon.box(Vector3(0.85, 0.42, 0.6)), stone, Vector3(0, 0.33, 0))
			var water := Toon.flat(Color("#6FD0DA", 0.95))
			var w := Toon.part(n, Toon.box(Vector3(0.66, 0.02, 0.42)), water, Vector3(0, 0.55, 0))
			w.name = "Water"
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var bam := Toon.mat_shared(Color("#7FA65A"))
			var pipe := Toon.part(n, Toon.cyl(0.04, 0.04, 0.7, 8), bam, Vector3(0.18, 0.78, -0.22))
			pipe.rotation = Vector3(deg_to_rad(65), 0, 0)
			Toon.part(n, Toon.cyl(0.05, 0.05, 0.75, 8), bam, Vector3(0.18, 0.42, -0.52))
			var ladle := Toon.mat_shared(Color("#B08A5A"))
			var stick := Toon.part(n, Toon.cyl(0.015, 0.015, 0.6, 6), ladle, Vector3(-0.15, 0.6, 0.0))
			stick.rotation = Vector3(0, 0, deg_to_rad(80))
			Toon.part(n, Toon.cyl(0.07, 0.06, 0.08, 10), ladle, Vector3(0.14, 0.62, 0.0))
			# lueur de soin au sol (jade) : on comprend que c'est bénéfique
			var glint := _disc(n, 0.85, Toon.flat(Color("#9FE8C8", 0.22)), 0.02)
			glint.name = "Glint"
		"elite":
			var stone2 := Toon.mat_shared(Color("#55525A"))
			Toon.part(n, Toon.box(Vector3(0.5, 0.12, 0.4)), stone2, Vector3(0, 0.06, 0))
			Toon.part(n, Toon.box(Vector3(0.34, 0.9, 0.16)), stone2, Vector3(0, 0.55, 0))
			Toon.part(n, Toon.box(Vector3(0.2, 0.3, 0.02)), Toon.mat_shared(Toon.VERMILION, false), Vector3(0, 0.65, 0.09))
			_disc(n, 1.2, Toon.flat(Color(Toon.VERMILION, 0.18)), 0.02)
			# deux cornes d'oni en papier au sommet de la pierre (plus de kanji : UI v2), l'ofuda vermillon dessous
			var horn := Toon.mat_shared(Toon.WASHI, true, 0.025)
			for sx in [-1.0, 1.0]:
				var h := Toon.part(n, Toon.cyl(0.0, 0.05, 0.22, 8), horn, Vector3(float(sx) * 0.1, 1.08, 0))
				h.rotation = Vector3(0, 0, float(-sx) * 0.3)
	return n


## Le héros touche un recoin : coffre (or, expérience), source (1 cœur), défi (un ennemi d'élite apparaît).
func _update_pockets() -> void:
	for pk in _pockets:
		if bool(pk["used"]):
			continue
		var p: Vector3 = pk["pos"]
		var d := Vector2(hero.position.x - p.x, hero.position.z - p.z).length()
		var kind := String(pk["kind"])
		if not is_instance_valid(pk["node"]):
			continue
		var n: Node3D = pk["node"]
		match kind:
			"chest":
				# lueur retrouvée une fois (plus de recherche par nom à chaque image), null si absente
				if not pk.has("glow"):
					pk["glow"] = n.get_node_or_null("Glow") as MeshInstance3D
				var gl: MeshInstance3D = pk["glow"]
				if gl != null:
					var gk := 0.5 + 0.5 * sin(run_time * 3.0)
					(gl.material_override as StandardMaterial3D).albedo_color = Color(Toon.GOLD, 0.12 + 0.2 * gk)
					gl.scale = Vector3(1.35, 1.0, 1.35) * (0.9 + 0.12 * gk)
				if bool(pk.get("sealed", false)):
					# scellé : il ne s'ouvre qu'au trait de la figure de sa plaque (_puzzle_stroke)
					if not bool(pk["hinted"]) and d < 4.2 and _explore:
						pk["hinted"] = true
						sfx.play("shrine", 1.6, -8.0)
					PuzzleArt.update(pk, n, run_time, 0, Vector3.ZERO)
				elif d < 1.35:
					pk["used"] = true
					_open_chest(pk, false)
			"spring":
				if d < 1.1 and hero.hp < hero.max_hp:
					pk["used"] = true
					heal(SEAL_HEAL if bool(pk.get("seal", false)) else 1, bool(pk.get("seal", false)))
					var w := n.get_node_or_null("Water") as MeshInstance3D
					if w != null:
						w.material_override = Toon.flat(Color("#4E6E78", 0.6))
					var gl2 := n.get_node_or_null("Glint") as Node3D
					if gl2 != null:
						gl2.visible = false
					_splash(p + Vector3(0, 0.2, 0), Color("#BFF2F5"), 14)
					sfx.play("shrine", 1.4, -4.0)
					hud.toast("SOIN +1")
			"elite":
				if d < 3.0 and _enc < 0:
					pk["used"] = true
					_spawn_elite(p, bool(pk.get("seal", false)))
					if is_instance_valid(n):
						n.queue_free()
			"puzzle":
				_update_puzzle(pk, n, d)


## Coffre ouvert : le couvercle saute, colonne de lumière, butin. `rich` (coffre scellé) : plus d'or et
## d'expérience, ou un rouleau (juste l'expérience du niveau suivant, SEAL_SCROLL des fois).
func _open_chest(pk: Dictionary, rich: bool) -> void:
	var nv = pk["node"]  # sans type : le nœud peut avoir été libéré (étape quittée pendant l'animation)
	if not is_instance_valid(nv) or hero == null:
		return
	var n: Node3D = nv
	var p: Vector3 = pk["pos"]
	var lid := n.get_node_or_null("Lid") as Node3D
	if lid != null:
		# le couvercle bascule d'un coup sec, avec un petit rebond
		var tw := create_tween()
		tw.tween_property(lid, "rotation:x", -1.9, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gl = pk.get("glow")
	if gl == null:
		gl = n.get_node_or_null("Glow")
	if is_instance_valid(gl):
		gl.queue_free()
	# colonne de lumière dorée qui jaillit et s'efface
	var beam_m := Toon.flat(Color(Toon.GOLD.lightened(0.35), 0.55))
	var beam := Toon.part(n, Toon.cyl(0.42, 0.3, 3.2, 16), beam_m, Vector3(0, 2.2, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tb := create_tween()
	tb.tween_property(beam_m, "albedo_color:a", 0.0, 0.9).set_delay(0.15)
	tb.tween_callback(beam.queue_free)
	shake = maxf(shake, 0.25)
	if not rich:
		pickups.drop(p, "coin", randi_range(6, 9))
		pickups.drop(p, "xp", randi_range(3, 5))
	elif randf() < SEAL_SCROLL:
		pickups.drop(p, "coin", randi_range(5, 7), 2 if charm == "or" else 1)
		pickups.drop(p, "xp", 6, ceili(float(maxi(1, xp_need() - xp)) / 6.0))
	else:
		pickups.drop(p, "coin", randi_range(11, 15), 2 if charm == "or" else 1)
		pickups.drop(p, "xp", randi_range(6, 8))
	if rich and charm == "or":
		charm_fx()  # omamori de l'or : pièces doublées du coffre scellé
	if rich:
		vfx.ring(Vector3(p.x, 0.05, p.z), Toon.GOLD, 2.2)
	vfx.chest_burst(p)
	sfx.play("coin", 0.8, -2.0)
	sfx.play("shot", 1.6, -6.0)
	hud.toast("COFFRE")


## Coffre scellé posé en `p` (recoin, ou devant le héros pour les captures) : chaîne, ofuda et sceau, plaque où
## se peint la figure `fig` (au hasard parmi SEAL_FIGS, sans ensō ni crochet aux deux premières étapes du monde 1).
func _spawn_sealed_chest(p: Vector3, fig := "") -> Dictionary:
	var c := Vector3(p.x, 0, p.z)
	var figs: Array = SEAL_FIGS_EASY if current_world == 1 and stage_i < 2 else SEAL_FIGS
	var shape := fig if fig in SEAL_FIGS else String(figs[randi() % figs.size()])
	var n := _pocket_node("chest", c)
	# la plaque se dresse côté milieu de l'étape (jamais contre le bord ni dans l'eau)
	var mid: float = arena.stage_rect.get_center().x if arena.stage else 0.0
	var side := 1.0 if c.x <= mid else -1.0
	var pk := {"kind": "chest", "pos": c, "used": false, "node": n, "sealed": true, "pz": "seal", "shape": shape,
		"hinted": false, "fail_t": -9.0, "t": randf() * TAU}
	PuzzleArt.build_seal(n, pk, shape, side)
	_pockets.append(pk)
	chests_sealed += 1
	return pk


## Bonne figure tracée près d'un coffre scellé : le sceau se brise (puzzle_art.unseal), puis le coffre s'ouvre.
func _unseal_chest(pk: Dictionary) -> void:
	if bool(pk["used"]):
		return
	pk["used"] = true
	chests_unsealed += 1
	var nv = pk["node"]
	if not is_instance_valid(nv):
		return
	PuzzleArt.unseal(pk, nv)
	sfx.play("strike", 1.7, -7.0)
	sfx.play("shrine", 1.3, -5.0)
	shake = maxf(shake, 0.12)
	feel("clear")
	get_tree().create_timer(PuzzleArt.UNSEAL_T, false).timeout.connect(_open_chest.bind(pk, true))


## Défi d'un recoin : un costaud d'élite, plus gros et plus solide, qui garde un butin.
func _spawn_elite(p: Vector3, seal := false) -> void:
	var e := Enemy.new()
	e.setup("brute", hero, self)
	_discover("brute")
	e.position = arena.clamp_walk(p, 0.8)
	add_child(e)
	e.hp *= float(Worlds.world(current_world).hp_mult)
	_apply_curses(e)
	# système d'élite commun : ×2.5 PV, ×1.25, bouclier, aura, affixes
	var aff: Array = Enemy.roll_affixes(current_world)
	if seal:
		# défi du sceau de l'oni : plus dur (deux affixes, PV ×SEAL_ONI_HP), un rouleau rare ou épique à la clé
		for a2 in Enemy.roll_affixes(current_world + 9):
			if not a2 in aff and aff.size() < 2:
				aff.append(a2)
		e.hp *= SEAL_ONI_HP
		e.set_meta("seal_oni", true)
	e.promote(aff)
	e.set_meta("max_hp", e.hp)
	e.set_meta("elite", true)
	enemies.append(e)
	shake = maxf(shake, 0.3)
	sfx.play("strike", 0.45)
	_splash(p + Vector3(0, 0.4, 0), Toon.VERMILION, 20)
	hud.banner("DÉFI", "GARDIEN D'ÉLITE", Toon.VERMILION, 1.6)


# ------------------------------------------------------------------ énigmes des recoins

## Pose une énigme de trait dans un recoin (`kind` vide : au hasard) : stèle à figure, lanternes à relier
## dans l'ordre d'un seul trait, esprit errant à entourer. Résolue hors combat, elle offre une récompense ;
## ratée, elle attend simplement le trait suivant.
func spawn_puzzle(kind: String, p: Vector3) -> Dictionary:
	var pz := kind if kind != "" else String(PUZZLE_KINDS[randi() % PUZZLE_KINDS.size()])
	var c := Vector3(p.x, 0, p.z)
	var pk := {"kind": "puzzle", "pz": pz, "pos": c, "used": false, "hinted": false,
		"reward": String(PUZZLE_REWARDS[randi() % PUZZLE_REWARDS.size()]), "t": randf() * TAU, "fail_t": -9.0}
	if pz == "lanterns":
		var spots := _lantern_spots(c, 3 if stage_i < 2 else 3 + randi() % 2)
		if spots.is_empty():
			pz = "stele"  # pas la place pour un cercle de lanternes : une stèle à la place
			pk["pz"] = pz
		else:
			pk["lanterns"] = spots
	if pz == "stele":
		pk["shape"] = String(PUZZLE_FIGS[randi() % PUZZLE_FIGS.size()])
	pk["node"] = _puzzle_node(pk)
	_pockets.append(pk)
	puzzles_seen += 1
	return pk


## Lanternes en cercle autour de `c`, numérotées dans le désordre, toutes sur la terre ferme ; vide sinon.
func _lantern_spots(c: Vector3, n: int) -> Array:
	for attempt in 10:
		var r := LANTERN_R if attempt < 6 else LANTERN_R * 0.8
		var rot := randf() * TAU
		var pts: Array = []
		for i in n:
			var a := rot + TAU * float(i) / float(n)
			var q := c + Vector3(cos(a), 0, sin(a)) * r
			if not Arena._walk_r(arena.rects, Vector2(q.x, q.z), 0.3) or arena.is_bridge(q, 0.2):
				break
			pts.append(q)
		if pts.size() == n:
			pts.shuffle()
			return pts
	return []


## Décor de l'énigme (puzzle_art.gd) : stèle gravée et sa figure qui se trace au sol, tōrō numérotés
## reliés de pointillés, esprit errant cerné d'un cercle fléché.
func _puzzle_node(pk: Dictionary) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var c: Vector3 = pk["pos"]
	n.position = c
	match String(pk["pz"]):
		"stele":
			var shape := String(pk["shape"])
			PuzzleArt.build_stele(n, pk, _glyph_pts(shape, PuzzleArt.GLYPH_O, PuzzleArt.GLYPH_K), shape)
		"lanterns":
			PuzzleArt.build_lanterns(n, pk, pk["lanterns"], c)
		"spirit":
			PuzzleArt.build_spirit(n, pk)
	return n


func _puzzle_label(parent: Node3D, txt: String, pos: Vector3, col: Color) -> Label3D:
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = txt
	l.font_size = 110
	l.pixel_size = 0.0045
	l.modulate = col
	l.outline_modulate = Toon.WASHI
	l.outline_size = 22
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	parent.add_child(l)
	return l


## Ruban posé au sol le long de `pts` (coordonnées locales du parent).
func _ribbon(parent: Node3D, pts: PackedVector3Array, w: float, m: Material) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	if pts.size() >= 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var a := pts[maxi(i - 1, 0)]
			var b := pts[mini(i + 1, pts.size() - 1)]
			var t := b - a
			t.y = 0
			t = t.normalized() if t.length_squared() > 0.000001 else Vector3.FORWARD
			var side := Vector3(-t.z, 0, t.x) * w
			var p := Vector3(pts[i].x, 0.03, pts[i].z)
			im.surface_add_vertex(p + side)
			im.surface_add_vertex(p - side)
		im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## La figure de la stèle vue de dessus (le haut de l'écran vers -z), large d'environ 2 × `k` m.
static func _glyph_pts(shape: String, o: Vector3, k: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	match shape:
		"loop":
			for i in 33:
				var t := -PI + TAU * float(i) / 32.0
				out.append(o + Vector3(0.45 * t - 0.6 * sin(t), 0, 0.6 * cos(t)) * k)
		"zigzag":
			for v in [Vector2(-0.9, 0.5), Vector2(-0.3, -0.5), Vector2(0.3, 0.5), Vector2(0.9, -0.5)]:
				var c2: Vector2 = v
				out.append(o + Vector3(c2.x, 0, c2.y) * k)
		"return":
			for i in 9:
				out.append(o + Vector3(-0.9 + 1.6 * float(i) / 8.0, 0, 0.22) * k)
			for i in range(1, 12):
				var a := PI * 0.5 - PI * float(i) / 11.0
				out.append(o + Vector3(0.7 + 0.22 * cos(a), 0, 0.22 * sin(a)) * k)
			for i in range(1, 8):
				out.append(o + Vector3(0.7 - 1.4 * float(i) / 7.0, 0, -0.22) * k)
		_:
			# ensō : cercle ouvert
			for i in 33:
				var a2 := 0.5 + (TAU - 0.9) * float(i) / 32.0
				out.append(o + Vector3(cos(a2), 0, sin(a2)) * 0.8 * k)
	return out


## Énigme : consigne à la première approche (hors combat), aperçu des lanternes allumées pendant le tracé,
## esprit qui erre.
func _update_puzzle(pk: Dictionary, n: Node3D, d: float) -> void:
	if not bool(pk["hinted"]) and d < 4.2 and _explore:
		pk["hinted"] = true
		# (UI v2 : plus de consigne écrite ; la figure de la stèle se trace d'elle-même, les lanternes portent leurs
		# numéros et leur chemin en pointillé, l'esprit son icône de boucle fléchée)
		sfx.play("shrine", 1.6, -8.0)
	# la figure se trace d'elle-même, les lanternes s'allument au fil du trait, l'esprit erre (puzzle_art.gd)
	var lit := 0
	var q := Vector3.ZERO
	match String(pk["pz"]):
		"spirit":
			q = spirit_pos(pk)
		"lanterns":
			var fail := run_time - float(pk["fail_t"]) < 0.6
			if not fail and touching and stroke != null and _explore and d < 7.0:
				lit = maxi(0, _lantern_progress(pk["lanterns"], stroke.points))
	PuzzleArt.update(pk, n, run_time, lit, q)


func _puzzle_hint(pk: Dictionary) -> String:
	match String(pk["pz"]):
		"stele":
			return "STÈLE  ·  TRACE SON SYMBOLE : %s" % String(StrokeShapes.FIG_NAMES.get(String(pk["shape"]), "")).to_upper()
		"lanterns":
			return "LANTERNES  ·  RELIE-LES DANS L'ORDRE, D'UN SEUL TRAIT"
	return "ESPRIT ERRANT  ·  ENTOURE-LE D'UNE BOUCLE"


## Position de l'esprit errant (il flâne autour du centre du recoin, sans quitter l'étape).
func spirit_pos(pk: Dictionary) -> Vector3:
	var c: Vector3 = pk["pos"]
	var t := run_time * 0.55 + float(pk["t"])
	var q := c + Vector3(cos(t) * 0.7 + 0.2 * sin(t * 2.3), 0, sin(t * 0.8) * 0.55)
	var b: Rect2 = arena.stage_rect
	q.x = clampf(q.x, b.position.x + 1.0, b.end.x - 1.0)
	return q


## Lanternes touchées dans l'ordre par le trait (0..n) ; -1 si l'une est touchée avant son tour
## (sauf celle d'où part le trait).
func _lantern_progress(order: Array, pts: PackedVector3Array) -> int:
	if pts.is_empty():
		return 0
	var start := pts[0]
	var nxt := 0
	for p in pts:
		for i in range(nxt, order.size()):
			var q: Vector3 = order[i]
			if Vector2(p.x - q.x, p.z - q.z).length() >= LANTERN_TOUCH:
				continue
			if i == nxt:
				nxt += 1
			elif Vector2(start.x - q.x, start.z - q.z).length() >= LANTERN_TOUCH:
				return -1
		if nxt >= order.size():
			break
	return nxt


## Angle total (radians, signé) balayé par le trait autour de `c`.
static func _winding(pts: PackedVector3Array, c: Vector3) -> float:
	if pts.size() < 2:
		return 0.0
	var total := 0.0
	var prev := atan2(pts[0].z - c.z, pts[0].x - c.x)
	for i in range(1, pts.size()):
		var a := atan2(pts[i].z - c.z, pts[i].x - c.x)
		total += wrapf(a - prev, -PI, PI)
		prev = a
	return total


## Trait lancé hors combat : il résout (ou rate, sans punition) les énigmes proches.
func _puzzle_stroke(pts: PackedVector3Array) -> void:
	if pts.size() < 2:
		return
	var o := pts[0]
	for pk in _pockets:
		var sealed: bool = String(pk["kind"]) == "chest" and bool(pk.get("sealed", false))
		if bool(pk["used"]) or (String(pk["kind"]) != "puzzle" and not sealed) or not is_instance_valid(pk["node"]):
			continue
		var c: Vector3 = pk["pos"]
		if Vector2(o.x - c.x, o.z - c.z).length() > 9.0:
			continue
		match String(pk["pz"]):
			"seal":
				# coffre scellé : la figure de sa plaque, tracée près de lui
				var near_s := 1.0e9
				for p in pts:
					near_s = minf(near_s, Vector2(p.x - c.x, p.z - c.z).length())
				var got_s := String(_shape.get("shape", ""))
				if near_s <= SEAL_NEAR and got_s == String(pk["shape"]):
					_unseal_chest(pk)
				elif near_s <= SEAL_NEAR and got_s != "":
					_puzzle_fail(pk, "")
			"stele":
				var near := 1.0e9
				for p in pts:
					near = minf(near, Vector2(p.x - c.x, p.z - c.z).length())
				var want := String(pk["shape"])
				var got := String(_shape.get("shape", ""))
				if near <= STELE_NEAR and got == want:
					_solve_puzzle(pk)
				elif near <= STELE_NEAR and got != "":
					_puzzle_fail(pk, "LA STÈLE ATTEND %s" % String(StrokeShapes.FIG_NAMES.get(want, "")).to_upper())
			"lanterns":
				var order: Array = pk["lanterns"]
				var k := _lantern_progress(order, pts)
				if k >= order.size():
					_solve_puzzle(pk)
				elif k != 0:
					_puzzle_fail(pk, "DANS L'ORDRE, D'UN SEUL TRAIT : 1 → %d" % order.size())
			"spirit":
				var sp := spirit_pos(pk)
				var wind := absf(_winding(pts, sp))
				# boucle ou ensō reconnu autour de lui ; et au bord du quai (trait rogné par l'eau), un tour partiel suffit
				var fig_c: Vector3 = _shape.get("center", Vector3.INF)
				var ringed: bool = String(_shape.get("shape", "")) in ["loop", "enso"] and fig_c != Vector3.INF 					and Vector2(fig_c.x - sp.x, fig_c.z - sp.z).length() < 1.8
				var edge: bool = not arena.walkable(sp, 1.4)
				if wind >= PI * 1.6 or ringed or (edge and wind >= PI * 1.05):
					_solve_puzzle(pk)
				else:
					var close := 1.0e9
					for p in pts:
						close = minf(close, Vector2(p.x - sp.x, p.z - sp.z).length())
					if close < 1.6 and StrokeShapes.length(pts) > 3.0:
						_puzzle_fail(pk, "ENTOURE L'ESPRIT D'UNE BOUCLE COMPLÈTE")


func _puzzle_fail(pk: Dictionary, msg: String) -> void:
	pk["fail_t"] = run_time
	PuzzleArt.fail(pk, run_time)  # secousse vermillon de l'objet (puzzle_art.update) : seul retour, sans texte (UI v2)
	sfx.play("empty", 0.9, -4.0)


## Énigme résolue : la consigne se dore, la récompense tombe (coffre d'or et d'expérience, soin ou relance).
func _solve_puzzle(pk: Dictionary) -> void:
	pk["used"] = true
	puzzles_solved += 1
	var c: Vector3 = pk["pos"]
	var n = pk["node"]  # sans type : le nœud peut avoir été libéré
	# gravure et figure dorées, colonne de lumière ; lanternes allumées ; l'esprit s'envole (puzzle_art.gd)
	PuzzleArt.solve(pk, n)
	var reward := String(pk["reward"])
	if reward == "heal" and (hero.hp >= hero.max_hp or charm == "ascete"):
		reward = "gold"
	var txt := ""
	match reward:
		"heal":
			heal(1)
			txt = "SOIN +1"
		"reroll":
			picker.rerolls += 1
			txt = "+1 RELANCE DE ROULEAU"
			float_text(c, "+1 RELANCE", Toon.GOLD)
		_:
			var chest := _pocket_node("chest", c + Vector3(0, 0, 0.7))
			var lid := chest.get_node_or_null("Lid") as Node3D
			if lid != null:
				lid.rotation.x = -1.05
			if is_instance_valid(n):
				chest.reparent(n)
			pickups.drop(c, "coin", randi_range(8, 12))
			pickups.drop(c, "xp", randi_range(4, 6))
			txt = "COFFRE : OR ET EXPÉRIENCE"
	hud.toast("ÉNIGME RÉSOLUE  ·  " + txt)
	_splash(c + Vector3(0, 0.5, 0), Toon.GOLD, 18)
	vfx.ring(Vector3(c.x, 0.05, c.z), Toon.GOLD, 2.0)
	sfx.play("shrine", 1.2, -3.0)
	sfx.play("levelup", 1.3, -6.0)
	feel("clear")


## Énigme (ou coffre scellé) proche du robot (CI), hors combat : il la résout lui-même (bot.gd). Vide sinon.
func bot_puzzle() -> Dictionary:
	if not _explore or hero == null:
		return {}
	for pk in _pockets:
		var sealed: bool = String(pk["kind"]) == "chest" and bool(pk.get("sealed", false))
		if bool(pk["used"]) or (String(pk["kind"]) != "puzzle" and not sealed) or int(pk.get("bot_try", 0)) >= 4:
			continue
		var p: Vector3 = pk["pos"]
		if Vector2(hero.position.x - p.x, hero.position.z - p.z).length() < 2.0:
			pk["bot_try"] = int(pk.get("bot_try", 0)) + 1
			return pk
	return {}


## But du robot hors combat : recoin à fouiller (dans le cadre courant), torii ouvert, entrée de la zone suivante.
func bot_goal() -> Vector3:
	if not arena.stage or _enc >= 0:
		return arena.gate_goal(bot_gate()) if arena.gate_open else Vector3.INF
	var best := Vector3.INF
	var bd := 1.0e9
	var chosen: Dictionary = {}
	for pk in _pockets:
		if bool(pk["used"]):
			continue
		if String(pk["kind"]) == "spring" and hero.hp >= hero.max_hp:
			continue
		if int(pk.get("bot_try", 0)) >= 4:
			continue  # énigme (ou coffre scellé) ratée plusieurs fois : le robot la laisse
		var p: Vector3 = pk["pos"]
		if not arena.bounds.has_point(Vector2(p.x, p.z)) or int(pk.get("bot", 0)) > 12:
			continue
		var d := p.distance_to(hero.position)
		if d < bd:
			bd = d
			best = p
			chosen = pk
	if best != Vector3.INF:
		# au plus une douzaine d'essais par recoin (jamais bloqué sur un coffre mal placé)
		chosen["bot"] = int(chosen.get("bot", 0)) + 1
		return best
	if arena.gate_open:
		return arena.gate_goal(bot_gate())
	return arena.next_goal()


## Ralenti cinématographique sur le dernier ennemi d'un combat (jamais pour le robot).
func _start_slowmo(pos: Vector3) -> void:
	if _bot != null or in_hub:
		return
	_slowmo_t = 0.0
	_slowmo_pos = pos
	sfx.play("kill", 0.55, 0.0)
	feel("heavy")


## Échelle de temps du ralenti : ~0,25 pendant 0,55 s (réelles), puis retour à 1 en 0,25 s.
func _slowmo_scale() -> float:
	if _slowmo_t < 0.0:
		return 1.0
	if _slowmo_t < 0.55:
		return 0.25
	return lerpf(0.25, 1.0, clampf((_slowmo_t - 0.55) / 0.25, 0.0, 1.0))


## Poids du rapproché de caméra pendant le ralenti (0..1).
func _slowmo_w() -> float:
	if _slowmo_t < 0.0:
		return 0.0
	var a := clampf(_slowmo_t / 0.15, 0.0, 1.0)
	var b := clampf((0.85 - _slowmo_t) / 0.3, 0.0, 1.0)
	var w := minf(a, b)
	return w * w * (3.0 - 2.0 * w)


func _award(victory: bool) -> void:
	var cleared := room if victory or _room_done else room - 1
	var g: Dictionary = meta.award_run(cleared, kills, boss_kills, curses.size(), victory, mini_kills, current_world)
	var open_before: Dictionary = meta.brushes_open()
	var un: Dictionary = meta.record_world(current_world, room, victory)
	# pinceaux : le boss vaincu avec ce pinceau donne son aspect suivant ; le monde ouvre peut-être un pinceau
	menu.unlock_gear = meta.on_world_won(brush, open_before) if victory else []
	if _bot != null and not menu.unlock_gear.is_empty():
		print("BOT ÉQUIPEMENT gagné : %s" % str(menu.unlock_gear))
	# ce que la victoire débloque : le monde suivant et une famille de rouleaux (rangée DÉBLOQUÉ des résultats)
	menu.unlock_world = int(un.get("world", 0))
	var ups: Array = un.get("powers", [])
	menu.unlock_powers = ups.duplicate()
	menu.unlock_family = String(un.get("family", ""))
	if menu.unlock_world > 0:
		var nw: Dictionary = Worlds.world(menu.unlock_world)
		menu.unlock_world_name = String(nw.get("name", ""))
		menu.unlock_world_kanji = String(nw.get("kanji", "道"))
		menu.unlock_world_color = nw.get("color", Toon.PRUSSIAN)
	# l'or ramassé devient de l'encre (2 pièces = 1 encre)
	var bonus := int(run_gold / 2.0)
	meta.sumi += bonus
	meta.save_data()
	menu.gain_sumi = int(g.get("sumi", 0)) + bonus
	if victory and _flawless_boss:
		# boss du monde vaincu sans un coup : encre en plus (40, et les 2 anciens sceaux payés en encre)
		var fl := 40 + 2 * Meta.SEAL_SUMI
		meta.sumi += fl
		meta.save_data()
		menu.gain_sumi += fl
	menu.sumi = meta.sumi
	# nouvelles Vues (ids de meta.PRINTS) pour la feuille de résultats
	var np: Array = g.get("prints", [])
	menu.new_prints = np.duplicate()


func _take_curse(id: String) -> void:
	curses.append(id)
	if _bot != null:
		print("BOT PACTE scellé : %s (salle %d)" % [id, room])
	shake = 0.55
	sfx.play("strike", 0.5)
	sfx.play("pact", 0.8, -2.0)
	feel("heavy")
	# gains immédiats (les malus sont lus sur `curses` là où ils agissent)
	match id:
		"dry", "tide":
			_extra_picks += 2
		"oni_eye":
			powers.force_rank = 2  # un rouleau épique garanti dans la prochaine offre
			_extra_picks += 1
		"heavy":
			hero.max_hp += 1
			if charm != "ascete":
				hero.hp += 1  # (l'ascète gagne la place du cœur, pas le soin)
			_extra_picks += 1
		"haste":
			_extra_picks += 1
			hero.hp = hero.max_hp
		"lantern":
			powers.force_rank = 1  # un rouleau rare garanti
			_extra_picks += 1
		"cursed_ink":
			hero.max_hp += 2
			hero.hp = hero.max_hp
		"drum":
			score.bonus_mult *= 1.4
		"ronin", "mask":
			pass  # gains permanents : curse_dmg_mult, or ×2
	if hero.hp > hero.max_hp:
		hero.hp = hero.max_hp


## Pas de choix de rouleau pendant l'entrée d'un boss (caméra de présentation).
func bosses_intro_done() -> bool:
	return state != "boss_intro"


## Arrivée au-dessus du vide ou d'un trou : le héros s'arrête au bord (dernier point solide du trajet).
func _land_safe() -> void:
	var path: PackedVector3Array = hero.path
	var safe := _safe_point
	for i in range(path.size() - 1, -1, -1):
		if not hazards.is_hole(path[i], 0.35):
			safe = path[i]
			break
	if hazards.is_hole(safe, 0.2):
		safe = arena.clamp_walk(hero.position, 0.5)
	var on_piece: bool = arena.on_set_piece(hero.position, 0.3)  # buté contre un décor : pas d'éclaboussure
	if not on_piece:
		_splash(hero.position, Toon.FOAM, 8)
	hero.position = Vector3(safe.x, 0, safe.z)
	_prev_hero = hero.position
	if not on_piece:
		sfx.play("empty", 0.7)


func drown(e: Node3D) -> void:
	_splash(e.position, Toon.PRUSSIAN, 14)
	damage_enemy(e, 99.0, false)


func wave_hit(push: Vector3) -> void:
	_hurt_hero()
	hero.position = _clamp_point(hero.position + push)
	_prev_hero = hero.position


func _victory() -> void:
	game_over = true
	_ending_victory = true
	hero.invuln = 999.0
	if _flawless_boss:
		hud.banner("VICTOIRE", "SANS UNE ÉGRATIGNURE", Toon.GOLD, 2.6)
	else:
		hud.banner("VICTOIRE", String(Worlds.world(current_world).name), Toon.GOLD, 2.2)
	music.play_victory()
	_set_state("dying")


## Après la séquence de fin : gains, record, et la feuille de résultats.
func _finish_run() -> void:
	var won := _ending_victory
	menu.victory = won
	_award(won)
	_award_score()
	# victoire : le bouton principal mène au monde suivant (REJOUER sur le dernier monde, et en cas de défaite)
	menu.next_label = ""
	if won and current_world < Worlds.WORLDS.size():
		menu.next_label = "MONDE SUIVANT"
	menu.new_record = room > record
	if room > record:
		record = room
		_save()
	menu.best = stage_of(record)
	var w: Dictionary = Worlds.world(current_world)
	menu.stat_room = maxi(stage_i + 1, 1)
	menu.stat_kills = kills
	menu.stat_combo = max_chain
	menu.stat_time = run_time
	menu.world_name = String(w.name)
	menu.world_kanji = String(w.kanji)
	menu.world_color = w.color
	# le build et les figures, figés avant la remise à zéro de la partie suivante
	menu.stat_shapes = shape_counts.duplicate()
	menu.build = powers.levels.duplicate()
	menu.affinities = powers.affinities()
	# coup fatal : le boss ou l'ennemi le plus proche du héros à sa chute
	menu.killer_kind = ""
	menu.killer_name = ""
	if not won:
		var best_d := 1.0e9
		for bo in bosses:
			if not is_instance_valid(bo) or bo.dead:
				continue
			var bd: float = Vector2(bo.position.x - hero.position.x, bo.position.z - hero.position.z).length() - 3.0
			if bd < best_d:
				best_d = bd
				var tl = bo.get("title")
				menu.killer_name = String(tl) if tl is String and String(tl) != "" else "le gardien"
				menu.killer_kind = ""
		for e in enemies:
			if not is_instance_valid(e) or e.dead or e.dummy or e.is_harmless():
				continue
			var ed: float = Vector2(e.position.x - hero.position.x, e.position.z - hero.position.z).length()
			if ed < best_d:
				best_d = ed
				menu.killer_name = ""
				menu.killer_kind = String(e.kind)
	_set_state("over")


## Score de la partie : record du monde, rang, prime d'encre (ajoutée aux gains de la feuille de résultats).
func _award_score() -> void:
	var r: Dictionary = score.finish(meta, current_world, max_chain, _ending_victory)
	menu.stat_score = int(r.get("score", 0))
	menu.best_score = int(r.get("best", 0))
	menu.score_record = bool(r.get("record", false))
	menu.score_rank = int(r.get("rank", 0))
	menu.score_next = Score.next_rank_pts(int(r.get("score", 0)), current_world, _ending_victory)
	# omamori : rang Maître de ce monde atteint (il exige le boss)
	var cid: String = meta.check_charm(current_world)
	if cid != "":
		menu.unlock_gear.append({"kind": "charm", "id": cid, "k": 0})
		if _bot != null:
			print("BOT OMAMORI gagné : %s (monde %d)" % [cid, current_world])
	menu.gain_sumi += int(r.get("sumi", 0))
	menu.sumi = meta.sumi


# ------------------------------------------------------------------ aides pour les pouvoirs

func damage_enemy(e: Node3D, dmg_in: float, fx := true) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var dmg := dmg_in * curse_dmg_mult()
	var killed: bool = e.hurt_dot(dmg)
	if fx and not killed:
		_splash(e.position, Toon.SUMI, 3)
	if killed:
		var kp: Vector3 = e.position
		var kd: Vector3 = kp - hero.position if is_instance_valid(hero) else Vector3.FORWARD
		vfx.kill_burst(kp, kd, false, _ink_tint(e))
		kills += 1
		powers.on_kill(e)
		_on_enemy_killed(e)
		sfx.play("kill", randf_range(1.1, 1.3), -6.0)
		feel("hit")


func nearest_enemies(pos: Vector3, r: float, n: int, exclude: Node3D) -> Array:
	var found: Array = []
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e == exclude or e.is_harmless():
			continue
		var d := Vector2(e.position.x - pos.x, e.position.z - pos.z).length()
		if d <= r:
			found.append([d, e])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for i in mini(n, found.size()):
		out.append(found[i][1])
	return out


## Dégâts de zone sur les boss (techniques, pouvoirs). Renvoie les points touchés.
func damage_bosses(center: Vector3, r: float, dmg_in: float, fx := true) -> Array:
	var hits: Array = []
	var dmg := dmg_in * curse_dmg_mult()
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		var p: Vector3 = bo.aoe_hit(center, r, dmg * BOSS_TOUGH, fx)
		if p == Vector3.INF:
			continue
		hits.append(p)
		if fx:
			_dmg_text(p, dmg, false)
			_splash(p, Toon.SUMI, 4)
	return hits


## Dégâts le long d'un trait sur les boss : chacun n'est touché qu'une fois.
func damage_bosses_line(pts: PackedVector3Array, r: float, dmg_in: float, fx := true) -> void:
	var dmg := dmg_in * curse_dmg_mult()
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		for i in range(0, pts.size(), 3):
			var p: Vector3 = bo.aoe_hit(pts[i], r, dmg * BOSS_TOUGH, fx)
			if p != Vector3.INF:
				if fx:
					_dmg_text(p, dmg, false)
					_splash(p, Toon.SUMI, 4)
				break


## `sealed` : soin du sceau du cœur des portes (sa source garantie), permis même à l'ascète.
func heal(n: int, sealed := false) -> void:
	if "ronin" in curses:
		# Serment du rōnin : plus aucun soin de la partie
		float_text(hero.position, "SERMENT", Toon.VERMILION)
		return
	if charm == "ascete" and not sealed:
		# omamori de l'ascète : aucun soin (sauf la source du sceau du cœur ; Hōō et Dernier souffle ne sont pas des soins)
		float_text(hero.position, "ASCÈTE", Gear.CHARMS["ascete"]["col"])
		charm_fx()
		return
	hero.hp = mini(hero.max_hp, hero.hp + n)
	float_text(hero.position, "+%d" % n, Toon.VERMILION)


## Dégâts du héros multipliés par les pactes (Serment du rōnin : +30 %).
func curse_dmg_mult() -> float:
	return (1.3 if "ronin" in curses else 1.0) * (Gear.ASCETE_DMG if charm == "ascete" else 1.0)


## Malus permanents d'un yōkai qui paraît (pactes) : vie, vitesse, annonces plus courtes.
func _apply_curses(e: Node3D) -> void:
	if "oni_eye" in curses:
		e.hp *= 1.5
	if "haste" in curses:
		e.speed *= 1.25
	if "lantern" in curses:
		e._windup *= 0.75  # Lanterne éteinte (plancher Enemy.WINDUP_MIN respecté par l'ennemi)


## Éclair (雷) : zigzag jaune cerné d'encre, de a à b (à hauteur de torse).
func zap(a: Vector3, b: Vector3) -> void:
	vfx.bolt(Vector3(a.x, 0.9, a.z), Vector3(b.x, 0.9, b.z), 3, true)


## Cercle de feu (火) : couronne de flammes, anneau orange, braises, roussi.
func fire_ring(pos: Vector3, r: float) -> void:
	vfx.fire_burst(pos, r, true)


## Sillage de feu : vraies flammes le long du trait et traînée de suie (durée en temps du jeu).
func fire_trail_fx(points: PackedVector3Array, dur: float) -> void:
	vfx.fire_trail(points, dur)


## Estoc d'ombre (影) de a vers b (crochet, riposte d'Utsusemi).
func shadow_stab(a: Vector3, b: Vector3) -> void:
	vfx.shadow_stab(a, b, true)


## Tourbillon de vent (風) : toupie de la boucle, tourbillons.
func wind_spin(pos: Vector3, r: float) -> void:
	vfx.toupie(pos, r)


## Onde d'encre (墨) : choc de l'ensō.
func ink_wave(pos: Vector3, r: float) -> void:
	vfx.ink_wave(pos, r, true)


# figures de l'arbre : sons existants réutilisés (son, hauteur) ; les autres jouent « tech_<figure> »
const TECH_SFX := {"wave": ["tech_return", 0.8], "point": ["tech_hook", 1.2], "triangle": ["tech_enso", 1.25]}


## Figure reconnue, à l'arrivée de la ruée : sa technique vient des rouleaux de figure (powers.figure_end).
func _apply_shape() -> void:
	if _shape.is_empty():
		return
	var sh: Dictionary = _shape
	_shape = {}
	score.figure_used()
	shape_counts[String(sh.shape)] = int(shape_counts.get(String(sh.shape), 0)) + 1
	var label: String = powers.figure_end(String(sh.shape), sh)
	if charm == "figure" and _fig_double_room != room and not _explore and state == "play" and room > 0:
		# omamori de la figure : la première figure du combat déclenche sa technique une seconde fois
		_fig_double_room = room
		get_tree().create_timer(0.35, false).timeout.connect(_fig_again.bind(String(sh.shape), sh))
	if _fig_shot != "" and String(sh.shape) == _force_fig:
		_fig_snap()
	hud.shape_pop(String(sh.shape), label)
	var ts: Array = TECH_SFX.get(String(sh.shape), ["tech_" + String(sh.shape), 1.0])
	sfx.play(String(ts[0]), float(ts[1]), -3.0)
	feel("figure")


func _fig_again(shape: String, info: Dictionary) -> void:
	if state != "play" or game_over or not is_instance_valid(hero):
		return
	powers.figure_end(shape, info)
	float_text(hero.position + Vector3(0, 0.4, 0), "×2", Gear.CHARMS["figure"]["col"])
	charm_fx()


## Fin d'un bond (figure) : les pouvoirs de figure frappent à l'atterrissage.
func _on_hero_landed() -> void:
	shake = maxf(shake, 0.86)
	sfx.play("strike", 0.7)
	feel("heavy")
	powers.figure_landed(hero.position)


## Techniques qui durent (toupie, coupe différée…) : gérées par les pouvoirs de figure.
func _update_moves(dt: float) -> void:
	powers.figure_update(dt)


## Sceau flottant (UI v2, à la place des kanji de combat) : disque à la couleur `col` cerné de washi, picto v2 `key`
## (clé de ui_icons.gd : « figures/zigzag », « elements/feu », « hud/slash »…) en washi dessus ; même vie que float_text
## (rebond, montée, fondu : effet « icon »). Clé inconnue : rien.
func float_icon(pos: Vector3, key: String, col: Color) -> void:
	var ic := UiKit.icon(key, 96.0, {"*": UIColors.hex(Toon.WASHI)})
	if ic == null:
		return
	var disc := Sprite3D.new()
	disc.texture = _seal_disc_tex()
	disc.modulate = col
	disc.pixel_size = 0.0085
	disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.no_depth_test = true
	disc.shaded = false
	disc.render_priority = 2
	disc.position = pos + Vector3(0, 2.8, 0)
	var pic := Sprite3D.new()
	pic.texture = ic
	pic.pixel_size = 0.0056
	pic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pic.no_depth_test = true
	pic.shaded = false
	pic.render_priority = 3
	disc.add_child(pic)
	add_child(disc)
	effects.append({"node": disc, "t": 0.0, "life": 0.75, "kind": "icon"})


## Disque du sceau flottant (texture partagée) : plein blanc modulé par la couleur, fin liseré clair.
func _seal_disc_tex() -> Texture2D:
	return UiKit.svg_tex('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="29" fill="#FFFFFF" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="4"/></svg>', 128.0, {}, "seal_disc")


## Chiffre de dégâts au-dessus de l'ennemi : blanc cerclé d'encre, vermillon s'il tue ou en combo.
## Chiffre de dégâts : encre épaisse, rebond à l'apparition, petite courbe en montant ; les touches
## rapprochées sur un même ennemi s'additionnent. Blanc normal, or gros coup, vermillon coup fatal.
func _dmg_text(pos: Vector3, dmg: float, killed: bool, key: Object = null) -> void:
	if not SHOW_DMG:
		return  # demandé : pas de chiffre à chaque coup (l'impact, la jauge et le score suffisent)
	var now := Time.get_ticks_msec()
	var kid := key.get_instance_id() if key != null else -1
	if kid != -1 and _dmg_labels.has(kid):
		var prev: Dictionary = _dmg_labels[kid]
		var pl = prev["fx"]["node"]
		if is_instance_valid(pl) and now - int(prev["ms"]) < 380:
			prev["sum"] = float(prev["sum"]) + dmg
			prev["ms"] = now
			_style_dmg(pl as Label3D, float(prev["sum"]), killed)
			prev["fx"]["t"] = 0.0
			return
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.font_size = 120
	l.outline_size = 30
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(randf_range(-0.35, 0.35), 2.7, 0)
	_style_dmg(l, dmg, killed)
	add_child(l)
	var fx := {"node": l, "t": 0.0, "life": 0.8, "kind": "dmg", "vx": randf_range(-0.9, 0.9), "y0": l.position.y}
	effects.append(fx)
	if kid != -1:
		_dmg_labels[kid] = {"fx": fx, "sum": dmg, "ms": now}


func _style_dmg(l: Label3D, v: float, killed: bool) -> void:
	l.text = str(int(round(v))) if absf(v - round(v)) < 0.05 else "%.1f" % v
	var big := v >= 3.0
	l.pixel_size = 0.006 * (100.0 + 16.0 * minf(v, 8.0)) / 120.0
	if killed:
		l.modulate = Toon.VERMILION
	elif big:
		l.modulate = Toon.GOLD.lightened(0.15)
	else:
		l.modulate = Color(1, 1, 1)
	l.outline_modulate = Toon.SUMI
	l.set_meta("big", big or killed)


## Lame qui ricoche sur un boss : au 2e ricochet, une astuce explique son point faible (une fois par boss),
## et un mini-boss perd quand même un peu de vie pour ne jamais bloquer la partie.
func _boss_ricochet() -> void:
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		var k := String(bo.kind)
		_ricochets[k] = int(_ricochets.get(k, 0)) + 1
		if is_mini_boss(k) and bo.has_method("_damage"):
			bo.call("_damage", 0.5)
		return


func float_text(pos: Vector3, text: String, color: Color) -> void:
	if text == "×0":
		_boss_ricochet()
	var l := Label3D.new()
	# police du jeu (le web n'a pas de police de secours) : symboles et macrons ramenés à ce qu'elle contient
	l.font = KANJI_FONT
	l.text = Hud.plain(text.replace("✕", "×").replace("○", "O"))
	l.font_size = 110
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = Toon.SUMI
	l.outline_size = 20
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 3.3, 0)  # au-dessus des têtes, pas sur les corps
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.75, "kind": "label"})

## Direction de marche d'un ennemi vers `to`, en passant par les passerelles si besoin.
func steer_dir(from: Vector3, to: Vector3) -> Vector3:
	var t: Vector3 = arena.steer(from, to)
	var d := t - from
	d.y = 0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO


func clamp_to_arena(n: Node3D, r: float) -> void:
	var cp: Vector3 = arena.clamp_walk(n.position, r)
	n.position = Vector3(cp.x, n.position.y, cp.z)


## Point ramené dans le cadre courant (l'arène, ou la partie ouverte de l'étape / la zone de combat).
func _clamp_point(p: Vector3) -> Vector3:
	var b: Rect2 = arena.bounds
	return Vector3(clampf(p.x, b.position.x + 0.3, b.end.x - 0.3), 0, clampf(p.z, b.position.y + 0.3, b.end.y - 0.3))


# ------------------------------------------------------------------ entrée

func _input(event: InputEvent) -> void:
	# tactile (téléphone) et souris (ordinateur) ; la souris émulée depuis le tactile sert aux boutons du menu
	if state == "boss_intro":
		_boss_intro_tap(event)
		return
	if state != "play" and state != "tuto":
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_touch_down(event.position)
		else:
			_touch_up(event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0:
			_touch_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_down(event.position)
		else:
			_touch_up(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_touch_move(event.position)


func _ground(sp: Vector2) -> Vector3:
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	if absf(n.y) < 0.0001:
		return Vector3.ZERO
	var p := o + n * (-o.y / n.y)
	p.y = 0
	return p


func _touch_down(sp: Vector2) -> void:
	if hud.is_over_pause(sp) or tuto.is_over_ui(sp):
		return
	if coach.is_over_ui(sp):
		coach.skip()  # « PASSER » du tutoriel
		return
	if coach.freeze_tap(sp):
		return  # arrêt sur image du tutoriel : ce toucher le lève (jamais un trait ; relâché et glissé sans effet)
	if game_over:
		return
	# on trace n'importe où sur l'écran (hors boutons du HUD) : le trait part du héros et suit le doigt au sol
	# mode pad : le geste du doigt est reproduit depuis le héros, en plus grand ; le doigt peut se poser
	# n'importe où (le cadre du pad n'est qu'un repère visuel)
	_strokes_done += 1
	touching = true
	_running = false
	_hold_t = 0.0
	_hold_sp = sp
	_touch_sp = sp
	_touch_ms = Time.get_ticks_msec()
	if ctrl_mode == "pad":
		hud.pad_trail = PackedVector2Array([sp])
	origin = hero.dash_end()
	stroke_layer += 1
	stroke = InkStroke.new(origin, stroke_layer)
	add_child(stroke)


## Zone du pad tactile, en bas de l'écran (coordonnées de la vue). Vide hors mode pad.
func pad_rect() -> Rect2:
	if ctrl_mode != "pad":
		return Rect2()
	var vs := get_viewport().get_visible_rect().size
	var hk := 0.2 if pad_size == "s" else (0.27 if pad_size == "m" else 0.34)
	var wk := 0.8 if pad_size == "s" else (0.92 if pad_size == "m" else 0.96)
	return Rect2(Vector2(vs.x * (1.0 - wk) / 2.0, vs.y * (0.955 - hk)), Vector2(vs.x * wk, vs.y * hk))


## Geste dans le pad -> déplacement au sol : la largeur du pad couvre ~15 m (haut de l'écran = vers le fond).
func _pad_to_world(d: Vector2) -> Vector3:
	var k := 15.0 / maxf(pad_rect().size.x, 1.0)
	return Vector3(d.x, 0, d.y) * k


func _touch_move(sp: Vector2) -> void:
	if touching and _running:
		_steer_run(sp)
		return
	if not touching or stroke == null:
		return
	if sp.distance_to(_hold_sp) > 6.0:
		# le doigt bouge encore : pas de course
		_hold_sp = sp
		_hold_t = 0.0
	var free_pt := _ground(sp)
	if ctrl_mode == "pad":
		free_pt = origin + _pad_to_world(sp - _touch_sp)
	var target := _clamp_point(free_pt)
	# geste brut (non rogné par les bords de la zone, ni coupé net par l'encre) : en combat, une figure
	# tracée près d'un bord ou au bout de l'encre se lit quand même
	var rw: PackedVector3Array = stroke.raw
	if rw.is_empty() or Vector2(rw[rw.size() - 1].x - free_pt.x, rw[rw.size() - 1].z - free_pt.z).length() >= 0.15:
		if StrokeShapes.length(rw) < float(stroke.length) + 2.5:
			rw.append(Vector3(free_pt.x, 0, free_pt.z))
			stroke.raw = rw
		var tr: PackedVector2Array = hud.pad_trail
		if tr.size() == 0 or tr[tr.size() - 1].distance_to(sp) > 4.0:
			tr.append(sp)
			hud.pad_trail = tr
	var was_empty: bool = stroke.exhausted
	# hors combat : encre illimitée, trait deux fois plus long ; en combat, l'encre plus les mètres offerts (Plume)
	var budget: float = maxf(0.0, elan_max() * EXPLORE_REACH - float(stroke.length)) if _explore else elan + powers.free_ink(float(stroke.length))
	var used: float = stroke.extend_to(target, budget)
	if stroke.lead_n < 0 and used > 0.0 and ctrl_mode != "pad":
		# (mode pad : pas d'amorce, le geste part du héros ; lead_n reste à -1, tout le trait est lu)
		stroke.lead_n = stroke.points.size() - 1  # fin de l'amorce héros -> doigt
	if not _explore:
		elan -= powers.ink_cost(float(stroke.length) - used, used)
	# figure reconnue en direct : l'encre se teinte (testé tous les 30 cm de trait)
	if used > 0.0 and float(stroke.length) - float(stroke.probe_len) >= 0.3:
		stroke.probe_len = stroke.length
		var live: Dictionary = _detect_fig(stroke) if float(stroke.length) >= 2.0 else {}
		stroke.set_figure(String(live.get("shape", "")))
	if stroke.exhausted and not was_empty:
		sfx.play("empty", 0.8)


## Figure d'un trait : le geste brut du doigt (raw) fait foi ; sans geste brut (robot, trait enchaîné), le trait
## posé est lu, amorce depuis le héros écartée. En combat, le trait posé est rogné par les bords de la zone et
## coupé par l'encre : une boucle contre un mur devient un zigzag ou un crochet ; le geste brut, non.
## En mode tactile, le doigt dessine sur l'écran mais ses points sont posés au sol en perspective : un cercle
## à l'écran est un ovale au sol (1,7 fois plus long que large en haut de l'arène), un zigzag y perd ses angles.
## Le geste est donc relu dans le plan de l'écran (_detect_screen), remis à la longueur de son tracé au sol pour
## que les seuils en mètres (trait droit de 7 m, aller de 3 m) restent ceux du chemin que court le héros, et les
## points de la figure (centre, coins, pointe) sont reprojetés au sol pour les techniques (powers).
const FIG_CLOSED := ["loop", "enso", "return"]  # formes fermées (gardé pour les lecteurs du dict de figure)


func _detect_fig(s: Node) -> Dictionary:
	_sync_fig_lock()
	var rw: PackedVector3Array = s.get("raw")
	if rw.size() >= 3:
		var r: Dictionary = {}
		if ctrl_mode == "pad":
			# pad : le geste du doigt est reproduit au sol à l'échelle (15 m pour la largeur du pad) : rien à redresser
			var vs := get_viewport().get_visible_rect().size
			r = StrokeShapes.detect(rw, 15.0 / (7.0 * maxf(pad_rect().size.x / maxf(vs.x, 1.0), 0.1)))
		else:
			r = _detect_screen(rw)
		if not r.is_empty():
			return r
	var pts: PackedVector3Array = s.get("points")
	return StrokeShapes.detect_lead(pts, int(s.get("lead_n")))


## Figures de l'arbre (vague, pointe, triangle) pas encore apprises (meta.fig_learned) : StrokeShapes ne les lit
## pas (ni reconnues, ni proposées par le diagnostic du dojo), le trait garde la lecture des six autres.
func _sync_fig_lock() -> void:
	var lk: Array = []
	for k in StrokeShapes.LEARNED:
		if meta == null or not bool(meta.fig_learned(String(k))):
			lk.append(String(k))
	StrokeShapes.locked = lk


## Lecture du geste brut dans le plan de l'écran : chaque point au sol est reprojeté à l'écran, le dessin est
## mis à l'échelle pour garder la longueur du tracé au sol, et lu par StrokeShapes avec l'échelle du geste
## (mètres par centimètre d'écran, pour le rayon qui sépare boucle et ensō). Les points de la figure reviennent au sol.
func _detect_screen(rw: PackedVector3Array) -> Dictionary:
	var vs := get_viewport().get_visible_rect().size
	var g := Vector3.ZERO
	for p in rw:
		g += p
	g /= float(rw.size())
	var sc := cam.unproject_position(g)
	var scr := PackedVector2Array()
	var l_scr := 0.0
	for p in rw:
		var u := cam.unproject_position(p) - sc
		if not scr.is_empty():
			l_scr += u.distance_to(scr[scr.size() - 1])
		scr.append(u)
	var l_ground := StrokeShapes.length(rw)
	if l_scr < 1.0 or l_ground <= 0.0 or not is_finite(l_scr):
		return StrokeShapes.detect(rw)
	var k := l_ground / l_scr  # « mètres » par pixel le long de ce geste
	var sp := PackedVector3Array()
	for u in scr:
		sp.append(Vector3(u.x * k, 0.0, u.y * k))
	var r: Dictionary = StrokeShapes.detect(sp, k * vs.x / 7.0)
	if r.is_empty():
		return r
	# direction au sol (trait droit, crochet) : entre la pointe et un point un mètre en arrière, tous deux reprojetés
	if r.has("dir"):
		var tip: Vector3 = r.get("tip", sp[sp.size() - 1])
		var back: Vector3 = tip - Vector3(r["dir"]) * 1.0
		var d := _unrect(tip, sc, k) - _unrect(back, sc, k)
		d.y = 0
		r["dir"] = d.normalized() if d.length() > 0.001 else Vector3(r["dir"])
	for key in ["center", "far", "tip"]:
		if r.has(key):
			r[key] = _unrect(r[key], sc, k)
	if r.has("corners"):
		var cs: Array = []
		for c in r["corners"]:
			cs.append(_unrect(c, sc, k))
		r["corners"] = cs
	if r.has("radius"):
		# rayon au sol : distance du centre à un point du cercle, reprojetés tous deux (moyenne de deux directions)
		var c3: Vector3 = r["center"]
		var cr: Vector3 = _unrect_inv(c3, sc, k)
		var rr := float(r["radius"])
		var ra := _unrect(cr + Vector3(rr, 0, 0), sc, k).distance_to(c3)
		var rb := _unrect(cr + Vector3(0, 0, rr), sc, k).distance_to(c3)
		r["radius"] = (ra + rb) * 0.5
	return r


## Point du dessin redressé (« mètres » autour du centre d'écran sc, facteur k) -> point au sol.
func _unrect(v: Vector3, sc: Vector2, k: float) -> Vector3:
	return _ground(sc + Vector2(v.x, v.z) / k)


## Point au sol -> dessin redressé (inverse de _unrect, pour le rayon).
func _unrect_inv(p: Vector3, sc: Vector2, k: float) -> Vector3:
	var u := cam.unproject_position(p) - sc
	return Vector3(u.x * k, 0.0, u.y * k)


## `-- --figtest` : échelle du geste (mètres au sol par centimètre d'écran, caméra de jeu), le corpus de gestes
## réalistes de tools/fig_corpus.gd (matrice de confusion, ratés), puis le même corpus dessiné sur l'écran et posé
## au sol par la caméra : lecture redressée (_detect_screen, celle du jeu) contre lecture au sol brute. Le jeu se ferme.
func _figtest() -> void:
	_set_state("play")
	_fit_camera()
	var vs := get_viewport().get_visible_rect().size
	var cm := vs.x / 7.0  # un téléphone fait ~7 cm de large : pixels par centimètre d'écran
	print("FIGTEST vue %s ; coins de l'arène à l'écran : %s %s %s %s" % [str(vs), str(cam.unproject_position(Vector3(-HALF.x, 0, -HALF.y))),
		str(cam.unproject_position(Vector3(HALF.x, 0, -HALF.y))), str(cam.unproject_position(Vector3(-HALF.x, 0, HALF.y))), str(cam.unproject_position(Vector3(HALF.x, 0, HALF.y)))])
	for ky: float in [0.3, 0.5, 0.7, 0.85]:
		var a := _ground(Vector2(vs.x * 0.5, vs.y * ky))
		var bx := _ground(Vector2(vs.x * 0.5 + cm, vs.y * ky))
		var by := _ground(Vector2(vs.x * 0.5, vs.y * ky - cm))
		print("FIGTEST échelle y=%.2f : 1 cm d'écran = %.2f m (horizontal), %.2f m (vertical)" % [ky, a.distance_to(bx), a.distance_to(by)])
	var FigCorpus = load("res://tools/fig_corpus.gd")
	FigCorpus.run(true)
	# gestes du corpus posés à l'écran (geste du doigt seul, à sa taille au sol pour la profondeur choisie, entre
	# 30 et 90 % de la hauteur de la vue), puis au sol par la caméra comme en jeu
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 0
	var ok_scr := 0
	var ok_gnd := 0
	var fails: Array = []
	for s: Dictionary in FigCorpus.build(rng):
		var pts: PackedVector3Array = s["pts"]
		var lead := int(s.get("lead", -1))
		if lead >= 0:
			pts = pts.slice(lead)
		var g := Vector3.ZERO
		for p in pts:
			g += p
		g /= float(pts.size())
		var anchor := Vector2(vs.x * rng.randf_range(0.3, 0.7), vs.y * rng.randf_range(0.3, 0.9))
		var mpc := _ground(anchor).distance_to(_ground(anchor + Vector2(cm, 0)))  # mètres par centimètre, ici
		var px_per_m := cm / maxf(mpc, 0.01)
		var raw := PackedVector3Array()
		for p in pts:
			var u := anchor + Vector2(p.x - g.x, p.z - g.z) * px_per_m
			raw.append(_ground(u))
		var want := String(s["want"])
		var got_scr := String(_detect_screen(raw).get("shape", ""))
		var got_gnd := String(StrokeShapes.detect(raw).get("shape", ""))
		n += 1
		if got_scr == want:
			ok_scr += 1
		else:
			fails.append("%s à y=%.2f : attendu '%s', redressé '%s' (au sol '%s')" % [String(s["name"]), anchor.y / vs.y, want, got_scr, got_gnd])
		if got_gnd == want:
			ok_gnd += 1
	print("FIGTEST écran : %d gestes posés au sol par la caméra : %d justes redressés (%.1f %%), %d justes lus au sol tels quels (%.1f %%)" % [n, ok_scr, 100.0 * float(ok_scr) / float(maxi(n, 1)), ok_gnd, 100.0 * float(ok_gnd) / float(maxi(n, 1))])
	for f in fails:
		print("FIGTEST   écran raté : ", f)
	get_tree().quit()


func _touch_up(sp: Vector2) -> void:
	if not touching:
		return
	touching = false
	hud.pad_trail = PackedVector2Array()
	if _running:
		_stop_run()
		return
	if stroke == null:
		return
	if stroke.length >= 0.7:
		_launch(stroke)
	else:
		# trait trop court pour une ruée : un simple tap (ou un petit coup de doigt) ne fait rien, l'encre
		# est rendue ; la seule façon d'échapper à un coup est de tracer un trait (la ruée protège son départ)
		var now := Time.get_ticks_msec()
		var flick := _pad_to_world(sp - _touch_sp) if ctrl_mode == "pad" else _ground(sp) - _ground(_touch_sp)
		flick.y = 0
		var is_tap := flick.length() <= 0.12 and now - _touch_ms < 260
		# double tap : l'ultime, si la jauge est pleine
		if is_tap and now - _last_tap_ms < 320 and ult >= 1.0 and (state == "play" or (state == "tuto" and tuto.in_dojo())):
			_last_tap_ms = 0
			stroke.queue_free()
			stroke = null
			_ultimate()
			return
		if is_tap:
			_last_tap_ms = now
		elan = minf(elan_max(), elan + stroke.length)
		stroke.queue_free()
	stroke = null


## Hors combat : sanctuaire, marche entre deux zones d'une étape, salle nettoyée (aucun ennemi ni boss vivant).
func exploring() -> bool:
	if state != "play" or game_over or hero == null:
		return false
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			return false
	for e in enemies:
		if is_instance_valid(e) and not e.dead and not e.dummy:
			return false
	if in_hub or (arena.stage and _enc < 0):
		return true
	return _room_done


## Course au doigt posé (hors combat) : après un trait, le doigt immobile lance la ruée puis le héros
## continue au trot tant que le doigt reste posé (écran : il suit le doigt ; pad : on l'oriente en glissant
## autour du point d'appui, comme une manette). Il s'arrête aux bords et aux trous.
func _update_run(real: float, dt: float) -> void:
	if _running:
		if not touching or not _explore or state != "play":
			_stop_run()
			return
		if hero.dashing or float(hero._leap_t) >= 0.0:
			return  # la ruée du trait d'abord
		var dir := _run_dir
		if ctrl_mode != "pad":
			var g := _ground(_run_sp) - hero.position
			g.y = 0
			if g.length() < 0.35:
				hero.ch.play(hero.ch.idle)
				return
			dir = g.normalized()
			_run_dir = dir
		var step := RUN_SPEED * dt
		var nxt := Vector3.INF
		# tout droit, sinon on glisse le long du bord
		for v in [dir, Vector3(dir.x, 0, 0), Vector3(0, 0, dir.z)]:
			var dv: Vector3 = v
			if dv.length() < 0.25:
				continue
			var q: Vector3 = hero.position + dv * step
			if arena.walkable(q, 0.25) and not hazards.is_hole(q, 0.3):
				nxt = q
				break
		if nxt == Vector3.INF:
			hero.ch.play(hero.ch.idle)
			return
		run_dist += hero.position.distance_to(nxt)
		hero.position = nxt
		_prev_hero = nxt  # courir ne tranche pas (_check_slashes)
		hero.face(dir)
		hero.run_anim(1.15)
		return
	if not touching or stroke == null or not _explore or state != "play":
		return
	_hold_t += real
	if _hold_t < HOLD_RUN_T or float(stroke.length) < 0.7:
		return
	var pts: PackedVector3Array = stroke.points
	var d := pts[pts.size() - 1] - pts[maxi(0, pts.size() - 5)]
	d.y = 0
	if d.length() < 0.05:
		return
	_run_dir = d.normalized()
	_run_sp = _hold_sp
	_run_anchor = _hold_sp
	_running = true
	run_dist = 0.0
	coach.on_event("run")
	var s: MeshInstance3D = stroke
	stroke = null
	_launch(s)
	hud.pad_trail = PackedVector2Array([_run_anchor]) if ctrl_mode == "pad" else PackedVector2Array()


## Doigt qui bouge pendant la course : écran, la direction suit le doigt à chaque image (_update_run) ;
## pad, nouvelle direction autour du point d'appui.
func _steer_run(sp: Vector2) -> void:
	_run_sp = sp
	if ctrl_mode != "pad":
		return
	var off := sp - _run_anchor
	if off.length() > 14.0:
		_run_dir = Vector3(off.x, 0, off.y).normalized()
	hud.pad_trail = PackedVector2Array([_run_anchor, sp])


func _stop_run() -> void:
	_running = false
	touching = false
	hud.pad_trail = PackedVector2Array()
	if hero != null and not hero.dashing and not hero.dead:
		hero.ch.play(hero.ch.idle)


## Ultime (double tap, jauge pleine) : un immense coup de pinceau traverse l'arène et frappe tout.
func _ultimate() -> void:
	ult = 0.0
	var hp := hero.position
	var a := Vector3(-HALF.x - 1.0, 0, hp.z + 1.6)
	var b := Vector3(HALF.x + 1.0, 0, hp.z - 1.6)
	vfx.slash_line(a, b)
	vfx.slash_line(Vector3(-HALF.x - 1.0, 0, hp.z - 2.4), Vector3(HALF.x + 1.0, 0, hp.z + 0.8))
	vfx.ink_wave(hp, 5.5)
	float_icon(hp + Vector3(0, 1.2, 0), "hud/pinceau", Toon.SUMI)
	hud.screen_flash = maxf(hud.screen_flash, 0.5)
	shake = maxf(shake, 1.68)
	sfx.play("iai", 0.8)
	sfx.play("kill", 0.7)
	feel("heavy")
	hud.toast("IPPITSU  ·  ULTIME")
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead and (not e.dummy or state == "tuto"):
			damage_enemy(e, ULT_DAMAGE * chain_mult())
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			bo.aoe_hit(bo.position, 6.0, ULT_DAMAGE * 2.0 * chain_mult() * BOSS_TOUGH, true)
	if state == "tuto":
		tuto.on_ultimate()
	coach.on_event("ult")


## Jauge d'ultime : se remplit en tranchant.
const ULT_PER_FIGURE := 0.2  # part de la jauge d'ultime par figure tracée en combat (5 figures = un ultime)


func gain_ult(v: float) -> void:
	if state == "play" and not in_hub:
		ult = minf(1.0, ult + v)


func _launch(s: MeshInstance3D) -> void:
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = s
	# la figure se lit sur le trait tel que tracé : l'allongement d'Oikaze (rogné aux murs) coudait le trait et
	# lui faisait perdre sa figure (trait droit, crochet) au relâchement
	var fig: Dictionary = _detect_fig(s) if s.length >= 2.0 else {}
	# Oikaze (vent arrière) : un trait dans le sens du précédent est poussé plus loin, gratuitement
	var ext: float = powers.stroke_extend(s.points)
	if ext > 0.0:
		var pts: PackedVector3Array = s.points
		var n := pts.size()
		var edir: Vector3 = pts[n - 1] - pts[maxi(0, n - 4)]
		edir.y = 0
		if edir.length() > 0.01:
			s.extend_to(_clamp_point(pts[n - 1] + edir.normalized() * ext), ext)
	hero.dash_guard = _dash_guard()
	if hero.dashing:
		# on enchaîne : la ruée en cours se termine et la nouvelle prend le relais
		var rest := PackedVector3Array()
		for i in range(hero.path_i - 1, hero.path.size()):
			rest.append(hero.path[i] if i >= hero.path_i else hero.position)
		for p in s.points:
			rest.append(p)
		hero.start_dash(rest)
	else:
		hero.start_dash(s.points)
	stroke_id += 1
	combo = 0
	_stroke_kills = 0
	_stroke_stop = 0.0
	_stroke_hit = false
	_prev_hero = hero.position
	_dash_s = 0.0
	_split_hits.clear()
	_tresse_next = Gear.TRESSE_WAVE * 0.5
	if not _explore and state == "play":
		_brush_launch(s)
	hero.speed_mult = powers.dash_mult() * _world_dash_mult() * (0.8 if "heavy" in curses else 1.0)  # Pas lourd
	_auto_step = false  # un vrai trait reprend la main sur le pas de côté automatique
	_safe_point = s.points[0]
	powers.on_stroke_release(s.points)
	_shape = fig
	if not _shape.is_empty():
		# le geste seul (trait posé, sans l'amorce depuis le héros) : la vague de Ressac le suit
		var ln := int(s.get("lead_n"))
		var sp: PackedVector3Array = s.points
		_shape["path"] = sp.slice(ln) if ln > 0 and ln < sp.size() - 2 else sp
	s.set_figure(String(_shape.get("shape", "")))
	_fig_mods = {}
	if not _shape.is_empty():
		_fig_slow = FIG_SLOW_LEN
		# l'ultime ne se charge QUE par les figures, et seulement en combat (pas entre deux vagues)
		if not _explore:
			gain_ult(meta.ult_per_figure(ULT_PER_FIGURE))  # Maître des figures : 4 figures au lieu de 5
		# (plus de sceau coloré flottant au bout du trait : le sceau papier du HUD, au-dessus du héros, dit déjà la figure)
		sfx.play("whoosh", 0.7)
		_fig_mods = powers.figure_launch(String(_shape.shape), _shape, s.points)
		hero.speed_mult *= float(_fig_mods.get("speed", 1.0))
	if _explore:
		_puzzle_stroke(s.points)  # énigmes des recoins (jamais en combat)
	coach.on_launch(String(_shape.get("shape", "")))
	sfx.play("whoosh", randf_range(0.9, 1.1))
	feel("dash")


## Règles du pinceau au lâcher d'un trait de combat : Calame de sang (les mètres au-delà de CHI_FREE se paient
## en vie, jamais le dernier cœur), Hake · Mur (le trait posé bloque les projectiles).
func _brush_launch(s: MeshInstance3D) -> void:
	if brush == "chi":
		var over := float(s.length) - Gear.CHI_FREE
		if over > 0.0:
			_blood += over * Gear.CHI_COST
			while _blood >= 1.0:
				if int(hero.hp) <= 1:
					_blood = 0.99  # plancher : la dette attend un cœur de plus, elle ne tue jamais
					break
				_blood -= 1.0
				hero.hp -= 1
				hud.hurt_flash = maxf(float(hud.hurt_flash), 0.45)
				float_text(hero.position, "−1 SANG", Toon.VERMILION)
				_splash(hero.position, Toon.VERMILION, 6)
	elif brush == "hake" and aspect == 1:
		_wall_pts = s.points.duplicate()
		_wall_t = Gear.HAKE_WALL_T


## Hake · Mur : vrai si `p` touche le trait posé (largeur du pinceau large).
func _on_wall(p: Vector3) -> bool:
	if _wall_t <= 0.0:
		return false
	for i in range(0, _wall_pts.size(), 2):
		var q: Vector3 = _wall_pts[i]
		if Vector2(p.x - q.x, p.z - q.z).length() < 0.95:
			return true
	return false


## Fude · Pluie : le trait de combat sèche en gouttes qui ralentissent les ennemis qui marchent dessus.
func _rain_drop(pts: PackedVector3Array) -> void:
	if _rain_mat == null:
		_rain_mat = Toon.flat(Color(Toon.SUMI, 0.5))
	var acc := Gear.PLUIE_STEP * 0.5
	for i in range(1, pts.size()):
		acc += pts[i].distance_to(pts[i - 1])
		if acc < Gear.PLUIE_STEP:
			continue
		acc = 0.0
		var p := Vector3(pts[i].x, 0, pts[i].z)
		var d := _disc(self, 0.36, _rain_mat, 0.016)
		d.position = Vector3(p.x, 0.016, p.z)
		_rain.append([d, p, Gear.PLUIE_LIFE])
	while _rain.size() > 40:
		var old: Array = _rain.pop_front()
		if is_instance_valid(old[0]):
			old[0].queue_free()


func _update_rain(dt: float) -> void:
	_wall_t = maxf(0.0, _wall_t - dt)
	for i in range(_rain.size() - 1, -1, -1):
		var r: Array = _rain[i]
		r[2] = float(r[2]) - dt
		var mi = r[0]
		if float(r[2]) <= 0.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_rain.remove_at(i)
			continue
		var k := clampf(float(r[2]) / 0.5, 0.0, 1.0)
		(mi as Node3D).scale = Vector3(0.36 * k, 1, 0.36 * k)
		var p: Vector3 = r[1]
		for e in enemies:
			if is_instance_valid(e) and not e.dead and Vector2(e.position.x - p.x, e.position.z - p.z).length() < Gear.PLUIE_R + float(e.radius) * 0.5:
				e.ink_slow(Gear.PLUIE_SLOW)


func _clear_rain() -> void:
	for r in _rain:
		if is_instance_valid(r[0]):
			r[0].queue_free()
	_rain.clear()


func _on_dash_finished() -> void:
	if _auto_step:
		_auto_step = false
		return
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
		if brush == "fude" and aspect == 1 and not _explore and state == "play":
			_rain_drop(dash_stroke.points)
	dash_stroke = null
	if state == "tuto":
		tuto.on_dash_end(hero.position, _stroke_kills, String(_shape.get("shape", "")))
	if _stroke_hit:
		_add_chain(2 if not _shape.is_empty() else 1)
		coach.on_event("hit")
	_apply_shape()
	if hazards.is_hole(hero.position):
		_land_safe()
	for bo in bosses:
		if is_instance_valid(bo):
			bo.end_stroke(stroke_id)
	powers.on_dash_end(hero.position, _stroke_kills)
	if state != "tuto":
		score.on_stroke(_stroke_kills, chain)
	if combo >= 3:
		elan = elan_max()
	_reset_stroke_state()


# ------------------------------------------------------------------ combat

func spawn_bullet(pos: Vector3, dir: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	if not _fx_cache.has("bullet"):
		_fx_cache["bullet"] = [Toon.sphere(0.3), Toon.mat_shared(Toon.VERMILION, true, 0.05), Toon.sphere(0.13), Toon.mat_shared(Toon.WASHI, false), Toon.flat(Color(0, 0, 0, 0.2))]
	var bc: Array = _fx_cache["bullet"]
	Toon.part(n, bc[0], bc[1], Vector3.ZERO)
	Toon.part(n, bc[2], bc[3], Vector3(0, 0.12, -0.12))
	var shadow := _disc(n, 0.26, bc[4])
	shadow.position.y = -pos.y + 0.012
	bullets.append({"node": n, "vel": dir * world_diff("bullet", 3.4), "life": 7.0})
	sfx.play("shot", randf_range(0.9, 1.1), -6.0)


func take_token(e: Node) -> bool:
	for i in range(_attackers.size() - 1, -1, -1):
		if not is_instance_valid(_attackers[i]) or _attackers[i].dead:
			_attackers.remove_at(i)
	if e in _attackers:
		return true
	if _attackers.size() >= attack_tokens():
		return false
	_attackers.append(e)
	return true


func free_token(e: Node) -> void:
	_attackers.erase(e)


## Annule le trait en train d'être tracé (pause, fin de salle, mort…).
func _cancel_stroke() -> void:
	if is_instance_valid(stroke):
		stroke.queue_free()
	stroke = null
	touching = false
	_running = false
	hud.pad_trail = PackedVector2Array()


## Oublie la ruée finie : touches et forme reconnue. `all` annule aussi la coupe iai en attente.
func _reset_stroke_state(all := false) -> void:
	combo = 0
	_stroke_kills = 0
	_stroke_hit = false
	_shape = {}
	_fig_mods = {}
	if all:
		powers.figure_cancel()


## Vrai si finir en `p` dans `eta` secondes tombe dans une attaque (zone qui frappe ou boule qui passe).
func is_danger(p: Vector3, eta: float) -> bool:
	if hazards.danger(p, eta):
		return true
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var z: Array = e.danger_zone()
		if z.size() == 3:
			var c: Vector3 = z[0]
			if Vector2(p.x - c.x, p.z - c.z).length() < float(z[1]) + 0.35 and float(z[2]) < eta + 0.35:
				return true
	for bo in bosses:
		# chaque boss teste toutes ses zones annoncées, avec leur vraie forme
		if is_instance_valid(bo) and bo.danger_at(p, eta):
			return true
	for b in bullets:
		var n: Node3D = b.node
		for k in 4:
			var q: Vector3 = n.position + b.vel * (eta + 0.15 * k)
			if Vector2(p.x - q.x, p.z - q.z).length() < 0.75:
				return true
	return false


## `n` : cœurs perdus si le héros est touché (coups lourds : 2 dès le monde 5, voir enemy._hit_n).
func enemy_strike(center: Vector3, r: float, n := 1) -> void:
	shake = maxf(shake, 0.08)
	sfx.play("strike", randf_range(0.9, 1.1), -3.0)
	_blot(center, Color(Toon.VERMILION, 0.35), r * 0.9, 0.6)
	# le coup tombe : bref anneau d'encre sur le bord de la zone
	vfx.ring(Vector3(center.x, 0.08, center.z), Toon.SUMI, r)
	var d := Vector2(hero.position.x - center.x, hero.position.z - center.z).length()
	if d < r + Hero.RADIUS * 0.6:
		_hurt_hero(n)


func chain_mult() -> float:
	return 1.0 + minf(chain * 0.03, 0.5)  # plafond +50 % (le combat restait trop facile)


func _add_chain(n: int) -> void:
	var before := chain
	chain += n
	max_chain = maxi(max_chain, chain)
	_chain_t = 0.0
	for tier in CHAIN_TIERS.keys():
		if before < int(tier) and chain >= int(tier):
			# petite annonce plutôt qu'un bandeau : on ne cache pas l'action en plein combat
			hud.toast("%s  ·  DÉGÂTS +%d %%" % [String(CHAIN_TIERS[tier]), int(round((chain_mult() - 1.0) * 100.0))])
			sfx.play("shot", 1.5, -2.0)
			feel("multi")


func _break_chain() -> void:
	if chain >= 3:
		hud.chain_break = 1.0
		hud.chain_lost = chain
	chain = 0
	_chain_t = 0.0


## Coup reçu par le héros (`n` cœurs). Ruée : intouchable en entier aux mondes 1-2, puis seulement au
## début de chaque ruée (hero.dash_safe) ; temps d'invincibilité après un coup raccourci dans les mondes avancés.
func _hurt_hero(n := 1) -> void:
	if hero.dash_safe() or hero.invuln > 0.0 or hero.protected() or game_over:
		return
	# temps figé (choix de rouleau, pause, arrêt sur image) ou hors combat : les coups de contact, testés par
	# position à chaque image, ne doivent pas passer (on mourait en choisissant un rouleau)
	if not (state in ST_FIGHT) or Engine.time_scale <= 0.0:
		return
	if charm == "garde" and _garde_stage != stage_i and state == "play":
		# omamori de la garde : le premier coup de chaque étape est annulé
		_garde_stage = stage_i
		hero.invuln = 0.8
		clang(hero.position)
		float_text(hero.position, "GARDE", Gear.CHARMS["garde"]["col"])
		charm_fx()
		return
	if foam > 0:
		# bouclier d'écume : le coup est bu par l'écume
		foam -= 1
		hero.invuln = 0.6
		clang(hero.position)
		float_text(hero.position, "ÉCUME", Toon.FOAM)
		return
	if powers.on_hurt(n):
		return
	if hero.hp <= n and not _last_breath_used and meta.learned("p6"):
		# Dernier souffle (Arbre du pinceau) : une fois par partie, le coup mortel laisse 1 cœur
		_last_breath_used = true
		hero.hp = 1
		hero.invuln = 1.5
		_break_chain()
		score.on_hurt()
		hud.hurt_flash = 1.0
		shake = 0.69
		sfx.play("hurt", 0.8)
		feel("hurt")
		float_text(hero.position, "DERNIER SOUFFLE", Toon.GOLD)
		return
	hero.hurt(n, _hurt_iframes())
	if "cursed_ink" in curses:
		_ink_lock = INK_LOCK_T  # Encre maudite : la recharge d'encre se fige
	_scratched = true
	_break_chain()
	score.on_hurt()
	hud.hurt_flash = 1.0
	shake = 0.69
	sfx.play("hurt")
	feel("hurt")
	_splash(hero.position, Toon.SUMI, 14)
	if hero.hp <= 0:
		game_over = true
		_ending_victory = false
		_set_state("dying")
		music.play_defeat()
		sfx.play("kill", 0.5)
		feel("death")
		_cancel_stroke()


## Invincibilité après un coup reçu : 1,2 s, puis 1 s dès le monde 3 et 0,85 s dès le monde 6.
func _hurt_iframes() -> float:
	if state == "tuto" or current_world < 3:
		return 1.2
	return 0.85 if current_world >= 6 else 1.0


## Part intouchable de chaque ruée : toute la ruée aux mondes 1-2 (et au dojo), puis ses 0,35 premières
## secondes. C'est la seule esquive du jeu : tracer un trait.
func _dash_guard() -> float:
	if state == "tuto" or current_world < 3:
		return Hero.DASH_GUARD_ALL
	return 0.35


func _check_slashes() -> void:
	if _auto_step:
		# pas de côté automatique : ce n'est pas un coup
		_prev_hero = hero.position
		return
	var a := _prev_hero
	var b := hero.position
	_prev_hero = b
	if not hero.dashing and a.distance_to(b) < 0.001:
		return
	var seg := b - a
	if hero.dashing:
		_dash_s += seg.length()
	if brush == "warefude":
		# pinceau fendu : deux lignes de part et d'autre du chemin (écart gear_data.split_off), 60 % chacune ;
		# le chemin du héros lui-même ne frappe plus
		var sd := Vector3(-seg.z, 0, seg.x)
		if sd.length_squared() > 0.000001:
			sd = sd.normalized()
			var s0 := maxf(0.0, _dash_s - seg.length())
			for li in 2:
				var sk := 1.0 if li == 0 else -1.0
				var oa := a + sd * Gear.split_off(aspect, s0) * sk
				var ob := b + sd * Gear.split_off(aspect, _dash_s) * sk
				_slash_line(oa, ob, seg, Gear.SPLIT_REACH, Gear.SPLIT_DMG, li + 1)
		if aspect == 2 and hero.dashing:
			# Tresse : chaque croisement des lignes éclate en petite onde
			while _dash_s >= _tresse_next:
				_tresse_next += Gear.TRESSE_WAVE * 0.5
				_tresse_burst(b)
	else:
		_slash_line(a, b, seg, brush_reach(), 1.0, 0)
	for bo in bosses:
		if not is_instance_valid(bo):
			continue
		if bo.check_dash(a, b, stroke_id):
			combo += 1
			var bd := 1.0 * (1.0 + 0.3 * (combo - 1)) * chain_mult() * float(_fig_mods.get("dmg", 1.0)) * curse_dmg_mult()
			bd *= meta.dmg_mult(chain) * _net_crit(bo.position)
			# pinceau : ses dégâts ; les boss gardent le chemin du héros (leurs mécaniques le lisent), le pinceau
			# fendu y porte ses deux lignes (2 × 60 %)
			bd *= brush_dmg() * (2.0 * Gear.SPLIT_DMG if brush == "warefude" else 1.0)
			_stroke_hit = true
			_chain_t = 0.0
			var bdir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
			bo.take_hit(powers.boss_dmg(bd) * BOSS_TOUGH, bdir)
			powers.on_boss_hit(bo.position, bd)
			elan = maxf(elan, minf(elan_cap(), elan + ELAN_PER_HIT))
			_add_hitstop(HITSTOP_BOSS)
			_cam_kick(bdir, 0.12)
			shake = maxf(shake, 0.17)
			sfx.play("slash", 0.85 * _combo_pitch())
			feel("boss_hit")
			hero.slash_pop()
			_splash(bo.position + Vector3(0, 0.6, 0), Toon.SUMI, 5)
			_slash_mark(bo.position, bdir)
			vfx.impact(bo.position, bdir, false)


## Une ligne de coupe a..b (le chemin du héros, ou une ligne du pinceau fendu `line` 1 ou 2) : chaque ennemi
## n'est touché qu'une fois par ligne et par trait ; `reach` : portée latérale, `k` : part des dégâts.
func _slash_line(a: Vector3, b: Vector3, seg: Vector3, reach: float, k: float, line: int) -> void:
	var ls := b - a
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.is_harmless():
			continue
		var key := 0
		var mask := 0
		if line == 0:
			if e.last_stroke == stroke_id:
				continue
		else:
			key = e.get_instance_id()
			mask = int(_split_hits.get(key, 0))
			if mask & line:
				continue
		var p: Vector3 = e.position
		var t := 0.0
		if ls.length_squared() > 0.0001:
			t = clampf((p - a).dot(ls) / ls.length_squared(), 0.0, 1.0)
		var q := a + ls * t
		var dist := Vector2(p.x - q.x, p.z - q.z).length()
		if dist < e.radius + reach:
			if line != 0:
				_split_hits[key] = mask | line
			_slash_hit(e, seg, k, dist)


## Touche d'un ennemi par le trait (sceau, garde, dégâts, effets du pinceau).
func _slash_hit(e: Node3D, seg: Vector3, k: float, dist: float) -> void:
	var p: Vector3 = e.position
	e.last_stroke = stroke_id
	combo += 1
	var fig := String(_shape.get("shape", ""))
	if String(e.seal_fig) != "" and fig != "" and (fig == String(e.seal_fig) or charm == "sceaux"):
		# la figure de son ofuda, tracée à travers lui : le sceau se brise, il tombe d'un coup
		# (omamori des sceaux : n'importe quelle figure)
		if fig != String(e.seal_fig):
			charm_fx()
		_seal_break(e, seg if seg.length_squared() > 0.0001 else hero.facing)
		return
	var dmg := 1.0 * (1.0 + 0.3 * (combo - 1))
	var dir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
	var piercing: bool = bool(_fig_mods.get("pierce", false))
	if not piercing and e.blocks(dir):
		combo -= 1
		clang(p)
		float_text(p, "GARDE !", Toon.FOAM)
		e.shield_break()
		hero.stop_dash()
		# le héros rebondit sur le bouclier au lieu de rester collé
		hero.position = arena.clamp_walk(hero.position - dir.normalized() * 0.8, 0.4)
		_prev_hero = hero.position
		return
	dmg *= float(_fig_mods.get("dmg", 1.0))
	dmg *= chain_mult() * curse_dmg_mult() * meta.dmg_mult(chain)
	dmg *= _net_crit(p)
	dmg *= k * brush_dmg()
	if brush == "menso" and dist < float(e.radius) * Gear.MENSO_CENTER:
		# Menso : le trait passe au centre de l'ennemi, critique garanti
		dmg *= Gear.MENSO_CRIT
		float_text(p + Vector3(0, 0.5, 0), "CRITIQUE", Toon.GOLD)
		vfx.dusk_crit(p)
		if aspect == 1 and fig != "" and _aiguille_key != stroke_id:
			# Aiguille : le critique déclenche aussi la technique de la figure en cours de tracé
			_aiguille_key = stroke_id
			powers.figure_end(fig, _shape)
	dmg = powers.on_hit(e, dmg, dir)
	_stroke_hit = true
	_chain_t = 0.0
	var killed: bool = e.take_hit(dmg, dir)
	if not killed and not _shape.is_empty() and meta.learned("l5"):
		_bleed_start(e)  # Lame d'encre : tranché pendant une figure, il saigne
	if brush == "hake" and aspect == 2 and not killed and is_instance_valid(e):
		e.push(dir.normalized() * Gear.HAKE_PUSH)  # Balai : repoussé dans le sens du trait
	if brush == "menso" and aspect == 2:
		_add_chain(1)  # Fil : chaque ennemi transpercé
	_dmg_text(p, dmg, killed, e)
	vfx.impact(p, dir, killed)
	_add_hitstop(HITSTOP_KILL if killed else HITSTOP_HIT)
	_cam_kick(dir, 0.25 if killed else 0.12)
	if killed:
		_on_enemy_killed(e)
		# le grand 斬 dès la deuxième touche du trait ; quelques gouttes à la couleur du yōkai
		vfx.kill_burst(p, dir, combo >= 2, _ink_tint(e))
		hud.screen_flash = maxf(hud.screen_flash, 0.25)
		kills += 1
		_stroke_kills += 1
		powers.on_kill(e)
		if _stroke_kills == 3:
			_zoom_k = 1.0  # trois d'un trait : la caméra s'approche un instant
	elan = maxf(elan, minf(elan_cap(), elan + ELAN_PER_HIT))
	shake = maxf(shake, 0.3 if killed else 0.15)
	sfx.play("kill" if killed else "slash", _combo_pitch())
	if killed:
		sfx.play("strike", 0.7, -6.0)  # coup sourd sous la mise à mort
	var boost := 0.05 * float(mini(combo, 5))
	feel("multi" if killed and _stroke_kills >= 2 else ("kill" if killed else "hit"), boost)
	hero.slash_pop()
	# touche : quelques gouttes d'encre (la mise à mort a sa giclée et sa tache, vfx.kill_burst)
	if not killed:
		_splash(p, Toon.SUMI, 3)
	_slash_mark(p, dir)
	if combo >= 3:
		_combo_label(p, combo)


## Warefude · Tresse : croisement des deux lignes, petite onde qui frappe autour.
func _tresse_burst(p: Vector3) -> void:
	var c := Vector3(p.x, 0.06, p.z)
	vfx.ring(c, Gear.BRUSHES["warefude"]["col"], Gear.TRESSE_R)
	var d: float = Gear.TRESSE_DMG * chain_mult() * meta.dmg_mult(chain)
	for o in nearest_enemies(p, Gear.TRESSE_R, 99, null):
		damage_enemy(o, d)
	damage_bosses(p, Gear.TRESSE_R, d, false)


func _update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		var n: Node3D = b.node
		n.position += b.vel * dt
		b.life -= dt
		var hp := n.position
		hp.y = 0
		var d := hp.distance_to(hero.position)
		# filet de sécurité : un pas de côté automatique, une fois par vague
		if safety_left > 0 and not b.get("friendly", false) and d < 1.0 and not hero.dashing and hero.invuln <= 0.0 and not game_over:
			var v: Vector3 = b.vel
			var side := Vector3(-v.z, 0, v.x).normalized()
			if side.dot(hero.position - hp) < 0:
				side = -side
			safety_left -= 1
			var step := PackedVector3Array([hero.position, _clamp_point(hero.position + side * 1.3)])
			_auto_step = true
			hero.start_dash(step)
		if b.get("friendly", false):
			for o in nearest_enemies(hp, 0.8, 1, null):
				damage_enemy(o, 1.5)
				b.life = 0.0
		elif _wall_t > 0.0 and b.life > 0.0 and _on_wall(hp):
			# Hake · Mur : le trait posé arrête le projectile
			b.life = 0.0
			clang(hp)
		elif d < 0.3 + Hero.RADIUS and not hero.dash_safe() and hero.invuln <= 0.0:
			_hurt_hero()
			b.life = 0.0
		if b.life <= 0.0 or not arena.bounds.grow(1.0).has_point(Vector2(n.position.x, n.position.z)):
			if b.life <= 0.0:
				_splash(n.position, Toon.VERMILION, 6)
			n.queue_free()
			bullets.remove_at(i)


# ------------------------------------------------------------------ effets

func _splash(pos: Vector3, color: Color, amount: int) -> void:
	# gouttes : un maillage par couleur, partagé (pas de nouvelle ressource à chaque coup)
	var key := "drop" + color.to_html()
	# émetteur d'une gerbe finie de la même couleur, repris de la réserve (réglages tous reposés ci-dessous)
	var p: CPUParticles3D = null
	var pool: Array = _splash_pool.get(key, [])
	while p == null and not pool.is_empty():
		var pv = pool.pop_back()
		if is_instance_valid(pv):
			p = pv
	var fresh := p == null
	if fresh:
		p = CPUParticles3D.new()
		p.set_meta("pool", key)
	if not _fx_cache.has(key):
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		mt.albedo_color = color
		var m := _drop_mesh()
		m.surface_set_material(0, mt)
		_fx_cache[key] = m
	p.mesh = _fx_cache[key]
	p.amount = amount
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -20, 0)
	p.particle_flag_align_y = true  # goutte étirée dans le sens de sa course (pas de bille ni de carré)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.position = pos + Vector3(0, 0.6, 0)
	if fresh:
		add_child(p)
		p.emitting = true
	else:
		p.visible = true
		p.restart()
	effects.append({"node": p, "t": 0.0, "life": 1.0, "kind": "none"})


## Goutte (deux plans croisés le long de +y : tête ronde, queue effilée) ; une par couleur (cache de _splash).
func _drop_mesh() -> ArrayMesh:
	var prof: Array = [Vector2(0.0, 0.11), Vector2(0.055, 0.085), Vector2(0.07, 0.05), Vector2(0.04, -0.01), Vector2(0.0, -0.12)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in 2:
		for i in prof.size() - 1:
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[i + 1]
			var ar := Vector3(a.x, a.y, 0.0) if plane == 0 else Vector3(0.0, a.y, a.x)
			var al := Vector3(-a.x, a.y, 0.0) if plane == 0 else Vector3(0.0, a.y, -a.x)
			var br := Vector3(b.x, b.y, 0.0) if plane == 0 else Vector3(0.0, b.y, b.x)
			var bl := Vector3(-b.x, b.y, 0.0) if plane == 0 else Vector3(0.0, b.y, -b.x)
			st.add_vertex(al)
			st.add_vertex(ar)
			st.add_vertex(br)
			st.add_vertex(al)
			st.add_vertex(br)
			st.add_vertex(bl)
	return st.commit()


## Teinte des quelques gouttes de couleur d'une mise à mort : la lueur du yōkai (vermillon par défaut).
func _ink_tint(e) -> Color:
	var c := Toon.VERMILION
	if is_instance_valid(e):
		var gc = e.get("_glow_c")
		if gc is Color:
			c = gc
	return c


## Gerbe finie : cachée et rangée par couleur (au plus SPLASH_POOL_MAX), sinon libérée.
func _recycle_splash(node: Node3D) -> bool:
	if not node.has_meta("pool") or not (node is CPUParticles3D):
		return false
	var key := String(node.get_meta("pool"))
	if not _splash_pool.has(key):
		_splash_pool[key] = []
	var pool: Array = _splash_pool[key]
	if pool.size() >= SPLASH_POOL_MAX:
		return false
	var p := node as CPUParticles3D
	p.emitting = false
	p.visible = false
	pool.append(p)
	return true


func _blot(pos: Vector3, color: Color, r: float, life: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = Vector3(pos.x, 0, pos.z)
	# disque unité partagé, mis à l'échelle ; une seule matière par tache (elle s'efface d'un bloc)
	var mt := Toon.flat(color)
	var main_disc := _disc(n, r, mt, 0.015)
	main_disc.scale = Vector3(r, 1, r * randf_range(0.7, 1.0))
	main_disc.rotation.y = randf() * TAU
	for i in 4:
		var a := randf() * TAU
		var dd := _disc(n, r * randf_range(0.12, 0.25), mt, 0.016)
		dd.position += Vector3(cos(a), 0, sin(a)) * r * randf_range(1.1, 1.8)
	effects.append({"node": n, "t": 0.0, "life": life, "kind": "fade", "mats": [mt], "alpha": color.a})


## Disque plat au sol de rayon `r`, sur un maillage unité partagé.
func _disc(parent: Node3D, r: float, material: Material, y := 0.01) -> MeshInstance3D:
	if not _fx_cache.has("disc"):
		_fx_cache["disc"] = Toon.cyl(1.0, 1.0, 0.004, 24)
	var d := Toon.part(parent, _fx_cache["disc"], material, Vector3(0, y, 0), Vector3(r, 1, r))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d


func _slash_mark(pos: Vector3, dir: Vector3) -> void:
	# éclair blanc en travers de l'ennemi : le « tranchant »
	var n := Node3D.new()
	add_child(n)
	n.position = pos + Vector3(0, 0.7, 0)
	var d := dir.normalized()
	n.rotation.y = atan2(-d.x, -d.z) + randf_range(-0.5, 0.5)
	if not _fx_cache.has("slash"):
		_fx_cache["slash"] = Toon.box(Vector3(0.06, 0.02, 1.5))
	var bar := Toon.part(n, _fx_cache["slash"], Toon.flat(Color(1, 1, 1, 0.95)), Vector3.ZERO)
	bar.rotation.x = randf_range(-0.25, 0.25)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.append({"node": n, "t": 0.0, "life": 0.14, "kind": "slash", "mats": [bar.material_override], "alpha": 0.95})


func _combo_label(pos: Vector3, n: int) -> void:
	var l := Label3D.new()
	l.text = "×%d" % n
	l.font = KANJI_FONT
	l.font_size = 110
	l.pixel_size = 0.006 * (70.0 + 6.0 * mini(n, 6)) / 110.0
	l.modulate = Toon.VERMILION
	l.outline_modulate = Toon.SUMI
	l.outline_size = 22
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 1.8, 0)
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.75, "kind": "label"})


func _update_effects(dt: float, real: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var fx = effects[i]
		var node: Node3D = fx.node
		fx.t += real if fx.kind == "label" or fx.kind == "dmg" or fx.kind == "icon" else dt
		var k: float = fx.t / fx.life
		match fx.kind:
			"fade":
				var a: float = fx.alpha * clampf((1.0 - k) * 2.0, 0.0, 1.0)
				for m in fx.mats:
					m.albedo_color.a = a
			"slash":
				node.scale = Vector3(1, 1, 1.0 + k)
				for m in fx.mats:
					m.albedo_color.a = fx.alpha * (1.0 - k)
			"dmg":
				# rebond (1.7 → 1), courbe latérale, montée qui ralentit, fondu final
				var pop := 1.0 + 0.7 * maxf(0.0, 1.0 - k * 7.0) - 0.1 * maxf(0.0, sin(minf(k * 7.0, 1.0) * PI))
				var big: bool = node.get_meta("big", false)
				node.scale = Vector3.ONE * pop * (1.25 if big else 1.0)
				node.position.x += float(fx.vx) * real * (1.0 - k)
				node.position.y = float(fx.y0) + 1.1 * (1.0 - pow(1.0 - k, 2.0))
				node.modulate.a = clampf((1.0 - k) * 3.5, 0.0, 1.0)
				node.outline_modulate.a = node.modulate.a
			"label":
				node.position.y += real * 1.5
				var s := 1.0 + 0.4 * maxf(0.0, 1.0 - k * 6.0)
				node.scale = Vector3.ONE * s
				node.modulate.a = clampf((1.0 - k) * 3.0, 0.0, 1.0)
				node.outline_modulate.a = node.modulate.a
			"icon":
				# sceau flottant (float_icon) : même vie que le label, le picto suit le disque
				node.position.y += real * 1.5
				node.scale = Vector3.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - k * 6.0))
				var ia := clampf((1.0 - k) * 3.0, 0.0, 1.0)
				node.modulate.a = ia
				if node.get_child_count() > 0:
					node.get_child(0).modulate.a = ia
		if k >= 1.0:
			if fx.kind != "none" or not _recycle_splash(node):
				node.queue_free()
			effects.remove_at(i)


# ------------------------------------------------------------------ boucle

func _process(_delta: float) -> void:
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	var now := Time.get_ticks_usec()
	var real := minf((now - _ticks) / 1000000.0, 0.05)
	_ticks = now
	_update_mood(real)
	if _bot != null:
		# pas fixe (--fixed-fps) : le robot joue aussi vite que la machine le permet. Le pas est celui que
		# reçoivent les nœuds (delta rendu à l'échelle 1) : figé à 1/30, à 120 Hz main avançait 4 fois plus
		# vite que les ennemis et le héros (combats 2,5 fois plus longs, ennemis « coincés »).
		var ts := Engine.time_scale
		if ts > 0.0001 and _delta > 0.0:
			_bot_step = clampf(_delta / ts, 1.0 / 480.0, 0.05)
		real = _bot_step
		var _bt := Time.get_ticks_usec() if Perf.on else 0
		_bot.step(real)
		if _bt != 0:
			Perf.add(&"bot", _bt)
	if _force_fig != "":
		_force_fig_step(real)
	elif Perf.sim_dt > 0.0:
		real = Perf.sim_dt  # relevé --perf au pas fixe : partie rejouable à l'identique (mesures et captures avant/après)

	# pause : tout est figé, seul l'écran de pause vit
	if state == "paused" or (state == "pick" and _pick_context == "level"):
		Engine.time_scale = 0.0
		_hitstop = 0.0
		if _pt != 0:
			Perf.add(&"main", _pt)
		return
	if _cap_frozen:
		Engine.time_scale = 0.0  # capture d'un scellé (`fige=`) : l'image se fige après le coup
		return
	# tutoriel : arrêt sur image le temps de lire une bulle du coach (figé comme la pause ; le coach compte
	# en temps réel, se lève au toucher ou seul au bout de quelques secondes)
	if state == "play" and not game_over and coach.frozen():
		Engine.time_scale = 0.0
		_hitstop = 0.0
		if _pt != 0:
			Perf.add(&"main", _pt)
		return

	# temps : fin de partie au ralenti, sinon normal
	var target := 1.0
	if state == "dying":
		target = 0.25 if not _ending_victory else 0.6
	elif game_over:
		target = 0.35
	elif state == "play":
		target = powers.time_mult()  # ralentis des pouvoirs (souffle suspendu, instant volé)
		if coach.slows():
			target = minf(target, Coach.SLOW)
		if _fig_slow > 0.0:
			# figure réussie : léger ralenti qui se relâche en douceur (temps réel)
			_fig_slow = maxf(0.0, _fig_slow - real)
			target = minf(target, lerpf(1.0, FIG_SLOW_SCALE, minf(1.0, _fig_slow / (FIG_SLOW_LEN * 0.6))))  # tutoriel : le jeu attend le premier trait (ralenti, pas figé)
		if _slowmo_t >= 0.0:
			# dernier ennemi du combat : ralenti cinématographique (temps réel)
			target = minf(target, _slowmo_scale())
			_slowmo_t += real
			if _slowmo_t > 0.85:
				_slowmo_t = -1.0
	elif _slowmo_t >= 0.0 and state != "pick":
		_slowmo_t = -1.0
	# arrêt sur image d'un coup (temps réel) : le temps se fige net, sans fondu, puis reprend son cours
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - real)
	if _hitstop > 0.0 and _bot == null and not game_over and state in ST_FIGHT:
		Engine.time_scale = HITSTOP_SCALE
	elif target < Engine.time_scale:
		Engine.time_scale = lerpf(Engine.time_scale, target, minf(1.0, real * 18.0))
	else:
		Engine.time_scale = target
	var dt := real * Engine.time_scale

	if ult != _ult_sent:  # jauge d'ultime (dessinée par le HUD si elle existe) : reposée seulement si elle a bougé
		_ult_sent = ult
		hud.set(&"ult", ult)
	_ink_lock = maxf(0.0, _ink_lock - real)
	if not touching and not hero.dashing and _ink_lock <= 0.0:
		elan = maxf(elan, minf(elan_cap(), elan + ELAN_REGEN * powers.regen_mult() * meta.regen_mult() * real))
	# hors combat : l'encre se recharge aussitôt, et le doigt posé fait courir
	_explore = exploring()
	if _explore:
		elan = elan_max()
	_update_run(real, dt)

	_check_slashes()
	_update_bullets(dt)
	_update_rain(dt)
	_update_effects(dt, real)

	# nettoyage et vagues
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)
	for i in range(bosses.size() - 1, -1, -1):
		if not is_instance_valid(bosses[i]):
			bosses.remove_at(i)
	_state_t += real
	_tick_discovery(real)
	if state == "dying":
		# la caméra s'approche du héros, l'image se délave
		if not _ending_victory:
			hud.dying = clampf(_state_t / 1.3, 0.0, 1.0)
			var close := Transform3D(Basis(), hero.position + Vector3(0, 7.5, 6.0)).looking_at(hero.position + Vector3(0, 0.8, 0), Vector3.UP)
			# (la caméra finale est _cam_base décalée de _cam_dz le long de l'étape)
			_cam_base = _cam_base.interpolate_with(close.translated(Vector3(0, 0, -_cam_dz)), minf(1.0, real * 2.0))
		if _state_t > 1.6:
			_finish_run()
	if state == "tuto":
		elan = elan_max()
		_update_moves(dt)
	# un boss vient d'apparaître : son entrée en scène avant le combat
	if state == "play" and _intro_boss != null:
		_start_boss_intro()
	if state == "play" and _bot == null:
		if _pause_pending:
			_pause_pending = false
			_on_pause()
		elif OS.has_feature("web"):
			# navigateur mobile : onglet ou appli quittés -> pause
			_web_hidden_t -= real
			if _web_hidden_t <= 0.0:
				_web_hidden_t = 0.5
				if str(JavaScriptBridge.eval("document.hidden", true)) == "true":
					_on_pause()
	# gardien vaincu sans dégât : le rouleau d'exception, salle nettoyée
	if state == "play" and _flawless_pending and _room_done and not hero.dashing and not touching:
		_flawless_pending = false
		_pick_context = "level"
		vfx.ring(Vector3(hero.position.x, 0.05, hero.position.z), Toon.GOLD, 2.6)
		_set_state("pick")
		_open_flawless()
	# rouleaux de sceau (élément, oni) : hors combat, après les rouleaux de niveau
	if state == "play" and not _seal_picks.is_empty() and _pending_levels == 0 and _lv_cele < 0.0 and _enc < 0 \
			and not game_over and not hero.dashing and not touching and bosses.is_empty():
		_pick_context = "level"
		_set_state("pick")
		_open_seal_pick(_seal_picks.pop_front())
	# rouleaux de niveau : tout de suite, même en plein combat (le jeu se fige pendant le choix),
	# dès que le héros a fini sa ruée et que le doigt est levé
	if state == "play" and _pending_levels > 0 and not game_over and not hero.dashing and not touching and bosses_intro_done():
		if _lv_cele < 0.0:
			# montée de niveau : d'abord la fête (bandeau or, anneaux, éclat du héros), les rouleaux viennent après
			_lv_cele = 0.0
			hero.invuln = maxf(hero.invuln, LV_CELE + 0.4)  # intouchable le temps de la fête (les ennemis bougent encore)
			hud.banner("NIVEAU %d" % level, "", Toon.GOLD, LV_CELE + 0.3)
			var hp := Vector3(hero.position.x, 0.05, hero.position.z)
			vfx.ring(hp, Toon.GOLD, 2.4)
			vfx.ring(hp, Toon.WASHI, 1.4)
			hero.ch.set_glow(1.0, Toon.GOLD)
		else:
			_lv_cele += real
			if _lv_cele > LV_CELE * 0.45 and _lv_cele - real <= LV_CELE * 0.45:
				vfx.ring(Vector3(hero.position.x, 0.05, hero.position.z), Toon.GOLD, 3.2)
			if _lv_cele >= LV_CELE:
				_lv_cele = -1.0
				hero.ch.set_glow(0.0)
				_pending_levels -= 1
				_pick_context = "level"
				_set_state("pick")
				_open_upgrades()
	if state == "play":
		run_time += real
		if chain > 0:
			_chain_t += real
			if _chain_t > CHAIN_TIMEOUT:
				chain = 0
		score.update(dt)
		_update_moves(dt)
		powers.update(dt)
		_update_bleeds(dt)
		hazards.update(dt)
		for bo in bosses:
			# contact d'un boss : la ruée reste intouchable en entier (on le tranche en le traversant)
			if is_instance_valid(bo) and not hero.dashing and bo.touching_hero(hero.position):
				_hurt_hero()
		var alive := 0
		for e in enemies:
			if is_instance_valid(e) and not e.dead:
				alive += 1
		# dernier ennemi du combat tombé : ralenti (le bandeau et l'ouverture suivent, wave_wait)
		if alive == 0 and _alive_prev > 0 and _waves_left.is_empty() and not _room_done and bosses.is_empty() and not in_hub and room > 0:
			_start_slowmo(_last_kill_pos)
		_alive_prev = alive
		# combat d'une étape : le héros reste dans la zone (haies)
		if arena.stage and _enc >= 0:
			var hb: Rect2 = arena.bounds
			if hero.position.z < hb.position.y + 0.3 or hero.position.z > hb.end.y - 0.3:
				hero.position.z = clampf(hero.position.z, hb.position.y + 0.3, hb.end.y - 0.3)
		# garde-fou : une ruée qui n'avance plus (cible hors de la zone, bord, haie) s'arrête,
		# sinon le héros resterait figé en « ruée » sans encre ni nouveau trait possible
		if hero.dashing and hero.position.distance_squared_to(_dash_prev) < 0.0004:
			_dash_stall += dt  # temps de jeu : un arrêt sur image ne compte pas
			if _dash_stall > 0.3:
				hero.stop_dash()
				_dash_stall = 0.0
		else:
			_dash_stall = 0.0
		_dash_prev = hero.position
		_update_pockets()
		_wave_t += dt
		_boss_reinforce()
		if not _waves_left.is_empty() and _wave_ready(alive):
			# vague suivante (ou suite de la vague retenue par le plafond à l'écran)
			var cont := _wave_cont
			_wave_cont = false
			var nxt: Array = _waves_left.pop_front()
			if not cont:
				_wave_size = nxt.size()
				_wave_t = 0.0
				wave_index += 1
				sfx.play("strike", 0.8, -4.0)
				hud.toast("VAGUE %d / %d" % [wave_index, waves_total])
			_spawn_list(_cap_wave(nxt, alive))
		elif in_hub:
			# sanctuaire : le torii mène à la première étape
			if arena.gate_reached(hero.position):
				_transit()
		elif arena.stage and _enc < 0:
			# étape : on marche (recoins, autel, zone suivante, torii)
			_stage_roam()
		elif room == 0:
			wave_wait -= real
			if wave_wait <= 0.0:
				_begin_room()
		elif not _room_done and enemies.is_empty() and _waves_left.is_empty() and bosses.is_empty():
			wave_wait -= real
			if wave_wait <= 0.0:
				wave_wait = 0.8
				_room_done = true
				_room_cleared()
		elif is_instance_valid(_shrine) and not hero.dashing and Vector2(hero.position.x - _shrine.position.x, hero.position.z - _shrine.position.z).length() < 1.3:
			# le héros touche l'autel : le pacte est proposé
			_shrine.queue_free()
			_shrine = null
			_pick_context = "room"
			_set_state("pick")
			_open_sanctuary()
		elif arena.gate_open and arena.gate_reached(hero.position):
			_transit()
		# un noyé hors de la terre ferme est ramené au bord le plus proche
		for e in enemies:
			if is_instance_valid(e) and e.kind == "funa" and not e.dead:
				var cp: Vector3 = arena.clamp_walk(e.position, 0.45)
				e.position = Vector3(cp.x, e.position.y, cp.z)
	elif state == "boss_intro":
		_update_boss_intro(real)
	elif state == "transit":
		if _ritual:
			_update_ritual()
		else:
			hud.wipe = clampf(_state_t / 0.35, 0.0, 1.0) if _state_t < 0.45 else clampf(1.0 - (_state_t - 0.45) / 0.35, 0.0, 1.0)
			if _state_t >= 0.4 and not _rebuilt:
				_rebuild_room()
			if _state_t >= 0.8:
				hud.wipe = 0.0
				_set_state("play")

	# caméra le long de l'étape (et le lointain avec elle)
	if state in ST_SCENE:
		_cam_dz = lerpf(_cam_dz, _cam_target(), minf(1.0, real * 2.6))
	arena.follow_camera(_cam_dz)
	var cb := _cam_base.translated(Vector3(0, 0, _cam_dz))
	if _slowmo_t >= 0.0:
		# léger rapproché vers le dernier coup
		cb.origin = cb.origin.lerp(_slowmo_pos + Vector3(0, 0.8, 0), 0.14 * _slowmo_w())
	# belle série : la caméra s'avance d'un coup puis revient en 0,3 s (temps réel)
	if _zoom_k > 0.0:
		_zoom_k = maxf(0.0, _zoom_k - real / 0.3)
		var zk := _zoom_k * _zoom_k * (3.0 - 2.0 * _zoom_k)
		cb.origin -= cb.basis.z.normalized() * ZOOM_PUNCH * zk
	# poussée dans le sens du coup : retombe très vite
	_kick = _kick.lerp(Vector3.ZERO, minf(1.0, real * 22.0))

	# barque (accueil, carte, départ) : pas d'anneau au sol sous le héros
	if is_instance_valid(hero):
		hero.ring_off = state in ST_RING_OFF or (state == "intro" and not _intro_swapped)
	# caméra : plan d'accueil, transition vers l'arène, secousse en jeu
	if state == "menu":
		# la barque tangue doucement, le héros avec elle ; garde-robe : la caméra glisse vers la proue
		_rock_boat(real)
		var sway := Vector3(sin(_state_t * 0.35) * 0.18, sin(_state_t * 0.5) * 0.06, 0)
		var mt := _menu_transform().translated(sway)
		var w_on := _wardrobe_on and wardrobe != null and wardrobe.visible
		_home_scene_tick(real)
		_wardrobe_k = move_toward(_wardrobe_k, 1.0 if w_on else 0.0, real * 1.4)
		if _wardrobe_k > 0.0:
			var wk := _wardrobe_k * _wardrobe_k * (3.0 - 2.0 * _wardrobe_k)
			mt = mt.interpolate_with(_wardrobe_transform(), wk)
		cam.global_transform = mt
	elif state == "intro":
		# rideau d'encre (0,4 s), bascule dessous, puis le monde se dévoile (0,45 s) : aucun survol
		hud.wipe = clampf(_state_t / 0.4, 0.0, 1.0) if _state_t < 0.5 else clampf(1.0 - (_state_t - 0.5) / 0.45, 0.0, 1.0)
		if _state_t < 0.42 and not _intro_swapped:
			_rock_boat(real)
			cam.global_transform = _menu_transform()
		else:
			if not _intro_swapped:
				_intro_swap()
			cam.global_transform = _cam_base.translated(Vector3(0, 0, _cam_dz))
		if _state_t >= 0.95:
			hud.wipe = 0.0
			_set_state("play")
	elif state == "sail":
		# Jouer : la barque prend le large (elle accélère), puis on choisit le monde
		menu_boat.position.z = maxf(menu_boat.position.z - real * minf(_state_t * 3.2, 2.6), 12.2)
		_rock_boat(real)
		cam.global_transform = _menu_transform()
		if _state_t > 1.3:
			_open_worlds()
	elif state == "worlds":
		_rock_boat(real)
		cam.global_transform = _menu_transform()
	elif state == "boss_intro":
		# secousse linéaire, qui retombe d'autant plus vite qu'elle est forte (durées proches de l'ancienne)
		shake = maxf(0.0, shake - real * (1.6 + 3.0 * shake))
		var si := shake * 0.35
		cam.global_transform = _boss_intro_cam().translated(Vector3(randf_range(-si, si), randf_range(-si, si) * 0.5, randf_range(-si, si)))
	elif shake > 0.0 or _kick.length_squared() > 0.000001:
		shake = maxf(0.0, shake - real * (1.6 + 3.0 * shake))
		var s := shake * 0.35
		cam.global_transform = cb.translated(Vector3(randf_range(-s, s), randf_range(-s, s) * 0.5, randf_range(-s, s)) + _kick)
	else:
		cam.global_transform = cb

	if ctrl_mode == "pad":
		hud.pad = pad_rect()
		hud.pad_active = touching
		var show_pad := pad_show == "always" or (pad_show == "start" and (state == "tuto" or _strokes_done < PAD_STROKES))
		hud.pad_alpha = move_toward(float(hud.pad_alpha), 1.0 if show_pad else 0.0, real * 1.5)
	if state in ST_HUD:
		# cadrage de jeu (efface le rapproché de la mort) ; mode pad : l'arène descend quand le pad s'efface
		_cam_base = _cam_mix()
	hud.in_play = state in IN_PLAY_STATES
	hud.dojo = state == "tuto"  # dojo : HUD réduit (posé à l'entrée, levé à la sortie de l'état)
	if is_instance_valid(hero) and not cam.is_position_behind(hero.position):
		hud.hero_screen = cam.unproject_position(hero.position + Vector3(0, 3.6, 0))
	hud.pause_enabled = state == "play"  # le bouton pause n'apparaît que là où il agit
	var wd: Dictionary = Worlds.world(current_world)
	hud.world_kanji = String(wd.kanji)
	hud.world_color = wd.color
	hud.rooms_total = STAGE_PLAN.size()
	menu.rooms_total = STAGE_PLAN.size()
	hud.elan_m = elan_max() * (EXPLORE_REACH if _explore else 1.0)
	hud.combo = combo if hero.dashing else 0
	hud.chain = chain if state != "tuto" else 0
	hud.level = level
	hud.xp_ratio = float(xp) / float(xp_need())
	hud.gold = run_gold
	hud.score = int(score.points) if state != "tuto" else -1
	hud.score_mult = Score.mult(chain, score.chain_early) if state != "tuto" else 1.0
	var bars: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.has_meta("max_hp"):
			var mh: float = e.get_meta("max_hp")
			var sr: float = e.shield_ratio()
			var el: bool = e.elite
			# blessé, protégé par un bouclier, ou élite : barre affichée (bouclier en bleu par-dessus)
			if (e.hp < mh - 0.01 or sr > 0.0 or el) and not cam.is_position_behind(e.position):
				var top: float = e.bar_top()
				bars.append([cam.unproject_position(e.position + Vector3(0, top, 0)), e.hp / mh, sr, el])
	hud.enemy_bars = bars
	hud.hp = hero.hp
	hud.max_hp = hero.max_hp
	if _explore:
		# jauge : ce qui reste du trait (deux fois plus long) en cours de tracé
		var cap := elan_max() * EXPLORE_REACH
		hud.elan = clampf(1.0 - (float(stroke.length) / cap if touching and stroke != null else 0.0), 0.0, 1.0)
	else:
		hud.elan = elan / elan_max()
	if touching and stroke != null:
		stroke.danger = is_danger(stroke.last(), stroke.length / (Hero.DASH_SPEED * _world_dash_mult()))
	hud.elan_empty = touching and stroke != null and stroke.exhausted
	hud.wave = stage_i + 1
	# flèche : vers le torii ouvert, ou vers la suite de l'étape entre deux combats
	hud.gate_hint = state == "play" and (arena.gate_open or (arena.stage and _enc < 0 and arena.zones_left() > 0))
	# compte des combats de l'étape (crans de la pilule d'étape)
	if arena.stage and not in_hub:
		hud.enc_done = arena.zones_done()
		hud.enc_total = arena.zones.size()
	else:
		hud.enc_done = 0
		hud.enc_total = 0
	hud.boss_name = ""
	hud.boss_hint = ""
	hud.boss_has_shield = false
	hud.boss_vuln = 0.0
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			hud.boss_name = bo.title
			# bouclier → vulnérable (propriétés absentes : boss sans bouclier)
			var sv = bo.get("shield")
			var smv = bo.get("shield_max")
			var vtv = bo.get("vulnerable_t")
			var vlv = bo.get("vulnerable_len")
			var bs: float = float(sv) if sv != null else 0.0
			var bsm: float = float(smv) if smv != null else 0.0
			var bvt: float = float(vtv) if vtv != null else 0.0
			hud.boss_has_shield = bsm > 0.0
			hud.boss_shield = clampf(bs / bsm, 0.0, 1.0) if bsm > 0.0 else 0.0
			hud.boss_vuln = bvt
			hud.boss_vuln_len = float(vlv) if vlv != null else 6.0
			# point faible : seulement après 12 s sans entamer son bouclier (ou sa vie, vulnérable ou sans bouclier)
			var bh: float = float(bo.hp)
			var dent: bool = (bh < _boss_hp_seen - 0.001) if (bvt > 0.0 or bsm <= 0.0) else (bs < _boss_sh_seen - 0.001)
			if dent or bo != _boss_seen:
				_boss_dry_t = 0.0
			_boss_seen = bo
			_boss_hp_seen = bh
			_boss_sh_seen = bs
			_boss_dry_t += real
			if _boss_dry_t > 12.0:
				hud.boss_hint = String(BOSS_HINTS.get(String(bo.kind), ""))
			hud.boss_ratio = clampf(bo.hp / bo.max_hp, 0.0, 1.0)
	if _pt != 0:
		Perf.add(&"main", _pt)
