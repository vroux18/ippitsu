extends Node3D
## Boucle de jeu : on trace, on lâche = ruée qui tranche. Chaque monde est une expédition en étapes :
## de longues cartes qui avancent vers le fond, des zones de combat qui se ferment (vagues d'ennemis),
## des recoins à fouiller, l'arène du gardien à mi-chemin et le boss au bout.
## `room` compte les combats (15 par monde, dont 8 = gardien et 15 = boss) : XP, rouleaux, records.

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
	"ibaraki": "res://scripts/boss_mini_ibaraki.gd"}
const WORLD_BOSS := {1: "uwabami", 2: "kyubi", 3: "gashadokuro", 4: "daidara", 5: "kuronami"}
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
}
const MINI_BOSS := {1: "okappa", 2: "tsuchigumo", 3: "yukionna", 4: "ibaraki", 5: "bakekujira"}
const Vfx = preload("res://scripts/vfx.gd")
const Options = preload("res://scripts/options.gd")
const Pickups = preload("res://scripts/pickups.gd")
const KIND_XP := {"oni": 1, "kappa": 2, "tate": 2, "funa": 2, "brute": 3,
	"umibozu": 2, "kitsunebi": 2, "kitsunebi_s": 1, "yukionna": 3, "kasha": 3, "kagebo": 3,
	"kappa_yumi": 2, "ika": 2, "umi_nyobo": 3, "kamaitachi": 2, "tanuki": 2, "tanuki_d": 0, "kitsune_tsukai": 3,
	"yuki_warashi": 1, "tsurara": 2, "onryo": 3, "hinotama": 2, "teppo": 2, "tengu": 3, "kanabo": 5,
	"sumidama": 2, "sumidama_s": 1, "kasa": 2, "moryo": 3}
const Tutorial = preload("res://scripts/tutorial.gd")
const Intro = preload("res://scripts/intro.gd")
const Music = preload("res://scripts/music_player.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const Hazards = preload("res://scripts/hazards.gd")
const Arena = preload("res://scripts/arena.gd")
const Worlds = preload("res://scripts/worlds.gd")
const WorldMap = preload("res://scripts/worldmap.gd")
const Meta = preload("res://scripts/meta.gd")
const Refuge = preload("res://scripts/refuge.gd")
const BOT_PATH := "res://scripts/bot.gd"  # robot du CI : chargé seulement avec `-- --bot`
const PowersRecap = preload("res://scripts/powers_recap.gd")
# malédictions du sanctuaire (après les salles de SANCTUARIES) : un malus pour toute la partie, une récompense tout de suite
const CURSES := {
	"dry": {"name": "Encre sèche", "text": "Trait -30 %  ·  2 rouleaux en plus", "icon": "c_dry"},
	"oni_eye": {"name": "Œil d'oni", "text": "Ennemis +50 % de vie  ·  2 rouleaux en plus", "icon": "c_eye"},
	"heavy": {"name": "Pas lourd", "text": "Plus de pas de côté  ·  +2 vies max, soin", "icon": "c_heavy"},
	"haste": {"name": "Hâte des morts", "text": "Ennemis +25 % vitesse  ·  1 rouleau, soin", "icon": "c_haste"},
}
const PASS_GOLD := 15  # « Passer » au sanctuaire : un cœur soigné, ou cet or si la vie est pleine
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
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const SHAPE_KANJI := {"loop": "渦", "zigzag": "雷", "return": "返", "straight": "一", "enso": "円", "hook": "鉤"}
const ROOMS := 15  # combats d'un monde
const MINI_ROOM := 8  # combat du mini-boss (son arène)
const SANCTUARIES := [5, 10]  # malédictions proposées après ces combats (fins des étapes 2 et 5)
# étapes du monde : combats (numéros de `room`) réunis sur une même longue carte ; [8] et [15] : arènes
const STAGE_PLAN := [[1, 2], [3, 4, 5], [6, 7], [8], [9, 10], [11, 12], [13, 14], [15]]
const CAM_LEAD := 2.4  # la caméra regarde un peu devant le héros (vers le fond de l'étape)
const KIND_COST := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 2,
	"umibozu": 2, "kitsunebi": 3, "yukionna": 3, "kasha": 3, "kagebo": 3,
	"kappa_yumi": 2, "ika": 2, "umi_nyobo": 3, "kamaitachi": 2, "tanuki": 2, "kitsune_tsukai": 3,
	"yuki_warashi": 1, "tsurara": 2, "onryo": 3, "hinotama": 2, "teppo": 2, "tengu": 3, "kanabo": 4,
	"sumidama": 3, "kasa": 2, "moryo": 3}
# première salle où chaque ennemi peut venir (ennemis signature : un par monde, vers la salle 3-4)
const KIND_ROOM := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 4,
	"umibozu": 3, "kitsunebi": 3, "yukionna": 4, "kasha": 4, "kagebo": 4,
	# bestiaire étendu : tireurs et coureurs tôt, soutiens et costauds plus tard
	"kappa_yumi": 2, "ika": 3, "umi_nyobo": 5, "kamaitachi": 2, "tanuki": 3, "kitsune_tsukai": 5,
	"yuki_warashi": 2, "tsurara": 6, "onryo": 4, "hinotama": 2, "teppo": 3, "tengu": 4, "kanabo": 6,
	"sumidama": 2, "kasa": 3, "moryo": 5}
const UNLOCK_ALL := false  # vrai : tous les mondes ouverts (prototype) ; sinon un monde vaincu ouvre le suivant
const SAVE_PATH := "user://ippitsu.cfg"

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (x, z)
const IN_PLAY_STATES := ["play", "transit", "dying", "pick", "tuto"]

const ELAN_MAX := 14.0  # longueur de trait maximale
const ELAN_REGEN := 9.0  # par seconde réelle, hors tracé
const ELAN_PER_HIT := 3.5
const DODGE_DIST := 2.4
const ENEMY_HP_MULT := 2.0
const DODGE_COOLDOWN := 0.7  # esquive gratuite (sans encre), mais pas en rafale
const ULT_DAMAGE := 4.0
const HIT_REACH := 0.55

var cam: Camera3D
var hero: Node3D
var sfx: Node
var hud: Control
var world: Node3D

var enemies: Array = []
var bullets: Array = []
var effects: Array = []

var elan := 14.0
var touching := false
var stroke: MeshInstance3D
var dash_stroke: MeshInstance3D
var stroke_layer := 0
var stroke_id := 0
var combo := 0
var origin := Vector3.ZERO
var _prev_hero := Vector3.ZERO

var shake := 0.0
var wave_wait := 1.0
var safety_left := 1  # pas de côté automatiques restants dans la salle
const ATTACK_TOKENS := 2  # ennemis autorisés à préparer une attaque en même temps
var _attackers: Array = []
var game_over := false
var _ticks := 0
var _cam_base := Transform3D()
var _cam_pad := Transform3D()
var _cam_full := Transform3D()

var state := "menu"  # menu | worlds | intro | play | boss_intro | pick | transit | paused | dying | over | tuto
var menu: Control
var record := 0
var _state_t := 0.0
const MENU_BOAT := Vector3(0, 0, 17.5)  # la barque de l'accueil, au large devant le sanctuaire (elle avance vers lui)
const BOAT_DECK := -0.24
var menu_boat: Node3D
var _env: Environment
var _light_mode := false  # rendu allégé (téléphone)
var _fx_cache := {}  # maillages et matières d'effets réutilisés
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
var worldmap: Control
var _ending_victory := false
var music: Node
var tuto: Control
var intro: Control  # planches illustrées : premier JOUER, ou bouton « ? » de l'accueil
var vfx: Node3D
var options: Control
var ctrl_mode := "pad"  # pad | screen
var pad_size := "m"  # s | m | l
var pad_show := "start"  # always | start | never
var _strokes_done := 0
var _options_from := "menu"
var pickups: Node3D
# expérience et or ramassés au sol : la barre pleine fait monter de niveau (un rouleau à choisir)
var xp := 0
var level := 1
var run_gold := 0
var _pending_levels := 0
var _pick_context := "room"  # room | level
var foam := 0  # coups bloqués restants dans la salle (Écume)
var _bot: Node = null  # robot testeur (CI)
var _last_offer: Array = []  # derniers rouleaux proposés (pour le robot)
var recap: Control
var _recap_from := "pause"
var _shrine: Node3D = null  # autel du sanctuaire (facultatif)
var in_hub := false  # sanctuaire de départ (avant la salle 1)
var _pause_pending := false  # l'appli a été quittée pendant une transition : pause au retour en jeu
var _web_hidden_t := 0.0
var ult := 0.0  # jauge d'ultime (0..1), double tap quand elle est pleine
var _dodge_cd := 0.0
var _touch_ms := 0
var _last_tap_ms := 0
var _boss_seen: Node3D = null
var _boss_hp_seen := 0.0
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
var shape_counts := {}  # figures réalisées pendant la partie (forme -> nombre)
var _chain_t := 0.0
var _stroke_hit := false
var _pad_start := Vector2.ZERO
var _shape: Dictionary = {}  # forme reconnue du trait en cours de ruée
var _fig_mods: Dictionary = {}  # effets de la figure sur la ruée en cours (powers.figure_launch)
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
# exploration : course au doigt posé
var _explore := false  # hors combat (calculé à chaque image)
var _running := false
var _run_dir := Vector3.ZERO
var _run_anchor := Vector2.ZERO  # point du pad où le doigt s'est posé (manette)
var _run_sp := Vector2.ZERO
var _hold_t := 0.0
var _hold_sp := Vector2.ZERO
var run_dist := 0.0  # distance courue depuis le dernier départ (robot)
var puzzles_seen := 0
var puzzles_solved := 0
# combat de boss sans dégât
var _scratched := false
var _flawless_pending := false  # rouleau « sans une égratignure » à ouvrir (gardien)
var _flawless_boss := false  # boss du monde vaincu sans dégât
var _pass_bonus := ""
var _boss_scripts := {}  # chemin -> GDScript chargé (gardé : pas recompilé à chaque boss)
var _frame_cache := {}  # cadrages calculés par taille d'écran (_frame), gardés aussi sur le disque
var _frame_disk_key := ""  # version du jeu et réglages du cadrage : un cadrage enregistré n'est repris que s'ils sont les mêmes
const FRAMES_PATH := "user://frames.cfg"
const FRAMES_MAX := 12
# mesures de chargement : lignes « BOT PERF <étape> <ms> » avec le robot, bilan à sa fin (bot.finish)
var perf := {}  # étape -> [nombre, total ms, max ms]
var _perf_on := false


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
	var ref_layer := CanvasLayer.new()
	ref_layer.layer = 4
	add_child(ref_layer)
	refuge = Refuge.new()
	refuge.meta = meta
	ref_layer.add_child(refuge)
	refuge.closed.connect(_on_refuge_closed)
	menu.atelier_pressed.connect(_on_atelier)
	menu.worlds_pressed.connect(_open_worlds)
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
	tuto.finished.connect(_on_tuto_finished)
	tuto.dojo_finished.connect(_on_dojo_finished)
	menu.dojo_pressed.connect(_start_dojo)
	intro = Intro.new()
	opt_layer.add_child(intro)
	intro.finished.connect(_on_intro_finished)
	menu.tuto_pressed.connect(_open_intro.bind(true))
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
	var wpos := wsearch.find("world=")
	hud.show_fps = "fps" in wsearch
	# `?unlockall` (web) et robot du CI : tous les mondes et tous les paliers de rouleaux ouverts
	if "unlockall" in wsearch or "--bot" in OS.get_cmdline_user_args():
		meta.test_unlock_all = true
	apply_world(clampi(int(wsearch.substr(wpos + 6).get_slice("&", 0)), 1, 5) if wpos >= 0 else 1)
	_start()
	# `-- --autoplay` : démarre directement en jeu (vérification automatique du CI)
	var autoplay := "--autoplay" in OS.get_cmdline_user_args()
	if autoplay:
		var fails: Array = StrokeShapes.self_test()
		if not fails.is_empty():
			print("SCRIPT ERROR: formes de trait : ", fails)
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
		_pick_context = "room"
		_set_state("pick")
		_open_upgrades()
	if "atelier" in wsearch:
		_on_atelier()
	if "dojo" in wsearch:
		_start_dojo()
	if "tuto" in wsearch:
		_start_tutorial()
	# `?intro` (web) : ouvre directement les planches de l'intro (captures d'écran)
	if "intro" in wsearch:
		_open_intro(false)
	if "pause" in wsearch:
		_set_state("play")
		_on_pause()
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


## Script du boss `k` (compilé une seule fois, gardé).
func _boss_script(k: String) -> GDScript:
	var path: String = BOSS_PATHS.get(k, BOSS_BASE)
	if not _boss_scripts.has(path):
		_boss_scripts[path] = load(path)
	var scr: GDScript = _boss_scripts[path]
	return scr


const WARM_KINDS := ["oni", "kappa", "brute", "tate", "funa", "umibozu", "kitsunebi", "kitsunebi_s", "yukionna", "kasha", "kagebo",
	"kappa_yumi", "ika", "umi_nyobo", "kamaitachi", "tanuki", "kitsune_tsukai", "yuki_warashi", "tsurara", "onryo",
	"hinotama", "teppo", "tengu", "kanabo", "sumidama", "kasa", "moryo"]
const WARM_BUDGET_US := 8000  # temps de préchauffage par image (µs), au moins un ennemi


## Préchauffage : on affiche une fois, cachés sous le sol, un exemplaire de chaque ennemi et de chaque
## effet. Godot prépare ainsi leurs shaders pendant l'accueil au lieu de figer l'image en pleine partie.
## Étalé sur plusieurs images (quelques ennemis par image) : l'accueil reste fluide.
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
	var x := -3.0
	for k in WARM_KINDS:
		var e := Enemy.new()
		e.setup(String(k), hero, self)
		e.position = Vector3(x, 0, 0)
		w.add_child(e)
		e.process_mode = Node.PROCESS_MODE_DISABLED
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
	var b := Node3D.new()
	w.add_child(b)
	Toon.part(b, Toon.sphere(0.3), Toon.mat(Toon.VERMILION, true, 0.05), Vector3.ZERO)
	var st := InkStroke.new(Vector3.ZERO, 0)
	w.add_child(st)
	st.extend_to(Vector3(2, 0, 0), 3.0)
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = "0123456789.× 渦雷返一円鉤斬逃波筆炎鳳神嵐狐背雪鬼"
	l.font_size = 120  # mêmes tailles que les textes de combat : glyphes prêts d'avance
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	w.add_child(l)
	var l2 := l.duplicate() as Label3D
	l2.font_size = 110
	w.add_child(l2)
	_splash(fxp, Toon.VERMILION, 8)
	_blot(fxp, Toon.SUMI, 0.3, 0.5)
	_slash_mark(fxp, Vector3.FORWARD)
	vfx.impact(fxp, Vector3.FORWARD, true)
	vfx.kill_burst(fxp, Vector3.FORWARD, true)
	get_tree().create_timer(1.2).timeout.connect(w.queue_free)
	var spent_end := Time.get_ticks_usec() - t0
	t_cpu += spent_end
	t_max = maxi(t_max, spent_end)
	perf_mark("warmup", t_cpu)  # temps de calcul total (réparti sur plusieurs images)
	perf_mark("warmup_step_max", t_max)  # la plus longue image de préchauffage
	perf_mark("warmup_span", Time.get_ticks_usec() - t_all)  # du début à la fin (images comprises)


# ------------------------------------------------------------------ états

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		record = int(cfg.get_value("game", "best", 0))
		menu.muted = bool(cfg.get_value("game", "muted", false))
		ctrl_mode = String(cfg.get_value("settings", "control", "pad"))
		pad_size = String(cfg.get_value("settings", "pad_size", "m"))
		pad_show = String(cfg.get_value("settings", "pad_show", "start"))
		sfx.haptics = String(cfg.get_value("settings", "vibration", "on")) == "on"
	menu.best = stage_of(record)
	menu.sumi = meta.sumi
	AudioServer.set_bus_mute(0, menu.muted)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", record)
	cfg.set_value("game", "muted", menu.muted)
	cfg.set_value("settings", "control", ctrl_mode)
	cfg.set_value("settings", "pad_size", pad_size)
	cfg.set_value("settings", "pad_show", pad_show)
	cfg.set_value("settings", "vibration", "on" if sfx.haptics else "off")
	cfg.save(SAVE_PATH)


func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0
	hud.visible = not s in ["menu", "worlds", "sail"]
	match s:
		"menu":
			menu.show_mode("home")
			music.play_menu()
			_board_boat()
		"intro":
			menu.show_mode("hidden")
			music.play_world(current_world)
			# la caméra quitte la barque et rejoint l'arène où le héros attend
			hero.position = arena.start
			hero.face(Vector3(0, 0, -1))
			hero.snap_facing()
		"play":
			menu.show_mode("hidden")
			if room == 0:
				music.play_world(current_world)
				var wd: Dictionary = Worlds.world(current_world)
				if in_hub:
					hud.banner("SANCTUAIRE", "ENTRAÎNE-TOI  ·  PASSE LE TORII POUR PARTIR", wd.color, 2.6)
				else:
					hud.banner(String(wd.name).to_upper(), "ÉTAPE 1  ·  AVANCE, TRACE POUR FRAPPER", wd.color, 2.4)
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
		# tout premier lancement : les planches d'abord, puis le tutoriel
		_open_intro(false)
	elif not meta.tuto_done:
		# toute première partie : on apprend d'abord à tracer
		_start_tutorial()
	else:
		_set_state("sail")


## Choix du monde sur le rouleau, centré sur `center` (par défaut le monde en cours). `reveal` : monde que
## la victoire vient d'ouvrir (le rouleau se déroule jusqu'à lui et brise son sceau), `reveal_powers` :
## rouleaux débloqués avec lui (aperçu sur sa carte).
func _open_worlds(center := -1, reveal := 0, reveal_powers := []) -> void:
	_set_state("worlds")
	var unlocked: int = 5 if UNLOCK_ALL or bool(meta.test_unlock_all) else int(meta.unlocked)
	# records : meilleur combat atteint -> meilleure étape
	var best := {}
	for k in meta.world_best.keys():
		best[k] = stage_of(int(meta.world_best[k]))
	var c: int = center if center >= 1 else current_world
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
	if id != current_world:
		apply_world(id)
	_start()
	_set_state("intro")


func _on_pause() -> void:
	if state != "play":
		return
	_cancel_stroke()
	var w: Dictionary = Worlds.world(current_world)
	menu.world_kanji = String(w.kanji)
	menu.world_color = w.color
	menu.stat_room = maxi(stage_i + 1, 1)
	menu.stat_combo = chain
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
		if what != NOTIFICATION_WM_GO_BACK_REQUEST and state in ["transit", "boss_intro", "pick", "intro"]:
			_pause_pending = true  # pause dès que la partie reprend la main
		if menu == null or hud == null:
			return
		if what == NOTIFICATION_WM_GO_BACK_REQUEST and recap != null and recap.visible:
			recap.visible = false
			_on_recap_closed()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and intro != null and intro.visible:
			intro.close()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "menu":
			get_tree().quit()  # Retour depuis l'accueil : on quitte, comme toute appli
		else:
			_on_pause()


## Tutoriel guidé : arène calme, mannequins, héros intouchable, élan illimité.
func _start_tutorial() -> void:
	sfx.play("slash", 0.9, -4.0)
	menu.show_mode("hidden")
	_start(false, true)
	_set_state("tuto")
	hero.face(Vector3(0, 0, -1))
	hero.guard_t = 99999.0
	hud.banner("TUTORIEL", "APPRENDS À TRACER", Toon.PRUSSIAN, 1.8)
	tuto.begin()


## Intro illustrée, sur l'accueil (la barque continue de tanguer derrière).
func _open_intro(from_help: bool) -> void:
	sfx.play("whoosh", 1.1, -6.0)
	menu.show_mode("hidden")
	intro.open(from_help)


## "done" : fin des planches au premier lancement -> tutoriel (ou le large) ; "tuto" : depuis le « ? » ;
## "back" : retour à l'accueil.
func _on_intro_finished(action: String) -> void:
	if action == "tuto":
		_start_tutorial()
	elif action == "done":
		meta.intro_done = true
		meta.save_data()
		if not meta.tuto_done:
			_start_tutorial()
		else:
			_set_state("sail")
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
	hud.banner("DOJO", "ENTRAÎNE-TOI LIBREMENT", Toon.PRUSSIAN, 1.6)
	tuto.begin_dojo()


func _on_dojo_finished() -> void:
	_start()
	_set_state("menu")


func _on_tuto_finished() -> void:
	meta.tuto_done = true
	meta.save_data()
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
	_start()
	_set_state("menu")


func _open_options() -> void:
	_options_from = "pause" if state == "paused" else "menu"
	options.values = {"control": ctrl_mode, "pad_size": pad_size, "pad_show": pad_show, "sound": "off" if menu.muted else "on", "vibration": "on" if sfx.haptics else "off"}
	menu.show_mode("hidden")
	options.open()


func _on_option(key: String, value: String) -> void:
	match key:
		"control":
			ctrl_mode = value
		"pad_size":
			pad_size = value
		"pad_show":
			pad_show = value
		"sound":
			menu.muted = value == "off"
			AudioServer.set_bus_mute(0, menu.muted)
		"vibration":
			sfx.haptics = value == "on"
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


## Plan d'accueil : derrière le héros debout sur sa barque, face au paysage du monde.
func _menu_transform() -> Transform3D:
	var bp := menu_boat.position if menu_boat != null else MENU_BOAT
	bp.y = 0.0
	var pos := bp + Vector3(0.95, 1.95, 4.1)
	return Transform3D(Basis(), pos).looking_at(bp + Vector3(-0.15, 1.15, -7.0), Vector3.UP)


## Barque de l'accueil (au large, derrière l'arène) : coque, pont, lanterne, sillage d'écume.
func _build_menu_boat() -> void:
	menu_boat = Node3D.new()
	world.add_child(menu_boat)
	menu_boat.position = MENU_BOAT
	var hull := Toon.mat(Color("#5E4130"), true, 0.03)
	var deck := Toon.mat(Color("#B88A5A"), true, 0.02)
	var dark := Toon.mat(Color("#2E221B"), false)
	Toon.part(menu_boat, Toon.box(Vector3(1.15, 0.32, 3.2)), hull, Vector3(0, -0.43, 0))
	var bow := Toon.part(menu_boat, Toon.box(Vector3(0.95, 0.28, 1.0)), hull, Vector3(0, -0.33, -1.85))
	bow.rotation.x = 0.38
	var stern := Toon.part(menu_boat, Toon.box(Vector3(1.0, 0.26, 0.6)), hull, Vector3(0, -0.36, 1.75))
	stern.rotation.x = -0.25
	Toon.part(menu_boat, Toon.box(Vector3(0.98, 0.04, 2.9)), deck, Vector3(0, -0.26, 0.05))
	for sx in [-1.0, 1.0]:
		Toon.part(menu_boat, Toon.box(Vector3(0.07, 0.1, 3.3)), dark, Vector3(0.57 * sx, -0.24, 0))
	# perche et lanterne à la proue (hors du champ entre la caméra et le héros)
	Toon.part(menu_boat, Toon.cyl(0.025, 0.03, 1.5), dark, Vector3(-0.4, 0.5, -1.55))
	var lan := Toon.mat(Color("#F4C97A"), true, 0.02)
	lan.emission_enabled = true
	lan.emission = Color("#FFB35A")
	lan.emission_energy_multiplier = 1.6
	Toon.part(menu_boat, Toon.sphere(0.13), lan, Vector3(-0.4, 1.18, -1.55), Vector3(1, 1.35, 1))
	# sillage d'écume autour de la coque
	var wake := _disc(menu_boat, 1.0, Toon.flat(Color(Toon.FOAM, 0.55)), -0.53)
	wake.scale = Vector3(0.95, 1, 2.1)
	menu_boat.visible = false


## Tangage de la barque ; le héros reste debout dessus.
func _rock_boat() -> void:
	var bob := sin(_state_t * 1.3) * 0.045
	menu_boat.position.y = MENU_BOAT.y + bob
	menu_boat.rotation = Vector3(sin(_state_t * 0.9) * 0.025, 0, sin(_state_t * 1.1) * 0.035)
	hero.position = Vector3(menu_boat.position.x, BOAT_DECK + bob, menu_boat.position.z - 0.2)


## Pose le héros sur la barque, de dos (face au paysage).
func _board_boat() -> void:
	menu_boat.visible = true
	menu_boat.position = MENU_BOAT
	hero.position = MENU_BOAT + Vector3(0, BOAT_DECK, -0.2)
	hero.face(Vector3(0, 0, -1))
	hero.snap_facing()


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
	e.adjustment_saturation = 1.2
	e.adjustment_contrast = 1.12
	e.adjustment_brightness = 0.92
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
	sun.shadow_opacity = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	var light := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
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
	_env.ambient_light_energy = float(w.ambient_energy) * (1.35 if _light_mode else 1.0)
	_sun.light_color = w.sun_color
	_sun.light_energy = float(w.sun_energy) * 0.86
	arena.set_world(id)
	if fresh:
		perf_mark("world_build", Time.get_ticks_usec() - t0)  # lointain du monde (ou monde gardé en mémoire)


## Deux cadrages : avec le pad (arène en haut, pad dessous) et sans (arène qui occupe l'écran).
## Le jeu glisse de l'un à l'autre selon la visibilité du pad.
func _fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0 or vs.y <= 0:
		return
	_cam_pad = _frame(vs, 0.68)
	_cam_full = _frame(vs, 0.9)
	var k: float = hud.pad_alpha if hud != null and ctrl_mode == "pad" else 0.0
	_cam_base = _cam_full.interpolate_with(_cam_pad, k)
	cam.global_transform = _cam_base


## Caméra la plus proche qui montre toute l'arène entre le haut de l'écran et `bottom_k` (fraction de hauteur).
func _frame(vs: Vector2, bottom_k: float) -> Transform3D:
	# même écran, même cadrage : la recherche (des milliers de projections) n'est faite qu'une fois
	var key := "%.2fx%.2f_%.3f" % [vs.x, vs.y, bottom_k]
	if _frame_cache.has(key):
		var cached: Transform3D = _frame_cache[key]
		return cached
	var tilt := deg_to_rad(54.0)
	# marges serrées : caméra un peu plus proche (le haut du torii peut toucher le bandeau)
	var corners := [Vector3(-HALF.x - 0.15, 0, -HALF.y - 0.2), Vector3(HALF.x + 0.15, 0, -HALF.y - 0.2),
		Vector3(-HALF.x - 0.15, 0, HALF.y + 0.2), Vector3(HALF.x + 0.15, 0, HALF.y + 0.2),
		Vector3(0, 2.2, -HALF.y - 0.4)]
	var top := vs.y * 0.085
	var bottom := vs.y * bottom_k  # sous l'arène : le pad tactile (s'il est affiché)
	var best := Transform3D()
	var found := false
	var dist := 12.0
	while dist < 70.0 and not found:
		# à cette distance, garde le cadrage qui centre l'arène verticalement
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


## Cadrages des lancements précédents (même version du jeu, même écran) : la recherche est évitée.
func _load_frames() -> void:
	_frame_disk_key = "%s|%s|%.2f|1" % [str(ProjectSettings.get_setting("application/config/version", "dev")), str(HALF), cam.fov]
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
	_dodge_cd = 0.0
	_dmg_labels.clear()
	_ricochets = {}
	wave_wait = 0.8
	room = 0
	_waves_left = []
	_room_done = false
	powers.reset()
	hazards.clear()
	curses.clear()
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
	pickups.clear()
	chain = 0
	max_chain = 0
	shape_counts = {}
	_chain_t = 0.0
	_scratched = false
	_flawless_pending = false
	_flawless_boss = false
	_pass_bonus = ""
	puzzles_seen = 0
	puzzles_solved = 0
	run_dist = 0.0
	hud.dying = 0.0
	hero.max_hp = 5 + meta.hp_bonus()
	hero.hp = hero.max_hp
	meta.apply_run_start(self)  # apparence de l'Atelier, rouleau de départ, bénédiction
	game_over = false
	touching = false
	shake = 0.0
	Engine.time_scale = 1.0
	_fit_camera()
	perf_mark("start", Time.get_ticks_usec() - t0)  # nouvelle partie entière (salle, héros, remise à zéro)


func elan_max() -> float:
	return (ELAN_MAX + powers.elan_bonus() + meta.elan_bonus()) * (0.7 if "dry" in curses else 1.0)


## Combat suivant (zone d'une étape, ou arène d'un gardien) : 3 vagues d'ennemis à tuer, tirées selon
## le monde, budget croissant.
func _begin_room() -> void:
	room += 1
	_room_done = false
	_alive_prev = 0
	foam = powers.foam_per_room()
	powers.on_room_start(room)
	safety_left = 0 if "heavy" in curses else meta.safety_per_room()
	if arena.stage:
		hazards.begin_room(room, hero.position, false, arena.bounds, true)
	else:
		hazards.begin_room(room, hero.position, room == MINI_ROOM or room == ROOMS)
	var w: Dictionary = Worlds.world(current_world)
	var weights: Dictionary = w.enemies
	var budget := 5 + 2 * room
	var list: Array = []
	if room >= 3:
		list.append("brute")
		budget -= 3
	var guard := 0
	while budget > 0 and guard < 100:
		guard += 1
		var k := _weighted_kind(weights)
		var cost := int(KIND_COST.get(k, 1))
		if room < int(KIND_ROOM.get(k, 1)) or cost > budget:
			k = "oni"
			cost = 1
		list.append(k)
		budget -= cost
	list.shuffle()
	if room == MINI_ROOM:
		list = ["oni", "oni", "oni"]
		_spawn_boss(String(MINI_BOSS.get(current_world, "okappa")))
	elif room == ROOMS:
		list = []
		_spawn_boss(String(WORLD_BOSS.get(current_world, "uwabami")))
	# découpe en vagues : 40 % / 35 % / 25 %
	_waves_left = []
	var n := list.size()
	var a := int(ceil(n * 0.4))
	var b := int(ceil(n * 0.75))
	var first: Array = list.slice(0, a)
	if b > a:
		_waves_left.append(list.slice(a, b))
	if n > b:
		_waves_left.append(list.slice(b))
	waves_total = 1 + _waves_left.size()
	wave_index = 1
	var boss_room := (room == MINI_ROOM or room == ROOMS) and is_instance_valid(_intro_boss)
	if boss_room:
		# salle de boss : carton titre et première vague à la fin de son entrée (_start_boss_intro)
		_intro_wave = first
	elif arena.stage:
		hud.toast("COMBAT %d / %d" % [_enc + 1, arena.zones.size()])
	if not boss_room:
		_spawn_list(first)
	sfx.play("strike", 0.7, -2.0)


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

func _spawn_boss(k: String) -> Node3D:
	var t0 := Time.get_ticks_usec()
	var b: Node3D = _boss_script(k).new()
	b.setup(k, self)
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
	shake = 0.4
	perf_mark("boss_spawn", Time.get_ticks_usec() - t0)
	return b


# ------------------------------------------------------------------ entrée des boss

## Carton titre de chaque boss : kanji, nom, épithète.
const BOSS_CARDS := {
	"okappa": ["大河童", "Ō-KAPPA", "le seigneur des eaux dormantes"],
	"tsuchigumo": ["土蜘蛛", "TSUCHIGUMO", "l'araignée des terres"],
	"yukionna": ["雪女", "YUKI-ONNA", "la dame des neiges"],
	"ibaraki": ["茨木童子", "IBARAKI-DŌJI", "l'oni au bras tranché"],
	"bakekujira": ["化鯨", "BAKEKUJIRA", "la baleine fantôme"],
	"uwabami": ["蟒蛇", "UWABAMI", "le serpent qui avale les barques"],
	"kyubi": ["九尾", "KYŪBI", "le renard aux neuf queues"],
	"gashadokuro": ["餓者髑髏", "GASHADOKURO", "le squelette des affamés"],
	"daidara": ["大太法師", "DAIDARABOTCHI", "le géant qui façonne les monts"],
	"kuronami": ["黒波", "KURO-NAMI", "la vague noire"],
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
	var sub := ("GARDIEN DE L'ÉTAPE %d" % stage_of(MINI_ROOM)) if _intro_mini else "GARDIEN DU MONDE"
	if _bot != null and not bool(_bot.get("cinematics")):
		hud.banner(String(b.title).to_upper(), sub, Toon.VERMILION, 2.2)
		_end_boss_intro()
		return
	var card: Array = BOSS_CARDS.get(String(b.kind), ["", String(b.title).to_upper(), ""])
	_cancel_stroke()
	_reset_stroke_state(true)
	hero.stop_dash()
	hud.pad_trail = PackedVector2Array()
	_intro_len = 1.6 if _intro_mini else 2.0
	_intro_w = 0.0
	_intro_roar = false
	_intro_pose = str(b.get("_state"))
	# il joue sa propre apparition (jamais d'attaque : voir _update_boss_intro)
	b.process_mode = Node.PROCESS_MODE_INHERIT
	hud.boss_card(String(card[0]), String(card[1]), String(card[2]), sub, _intro_mini, _intro_len - 0.3)
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
		shake = 0.5 if _intro_mini else 0.65
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
	pickups.drop(b.position, "xp", 8)
	pickups.drop(b.position, "coin", 10)
	var clean := not _scratched
	if is_mini_boss(String(b.kind)):
		mini_kills += 1
		_pending_levels += 1  # le gardien vaincu offre un rouleau
		music.end_boss(true)
		if clean and room < ROOMS:
			# aucun coup reçu : un rouleau d'exception (épique ou légendaire) à la fin du combat
			_flawless_pending = true
			hud.toast("SANS UNE ÉGRATIGNURE  ·  ROULEAU D'EXCEPTION")
			float_text(b.position, "SANS UNE ÉGRATIGNURE", Toon.GOLD)
	else:
		boss_kills += 1
		music.end_boss(false)  # le jingle de victoire suit
		if clean:
			_flawless_boss = true
			float_text(b.position, "SANS UNE ÉGRATIGNURE", Toon.GOLD)
	shake = 0.7
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
func feel(kind: String) -> void:
	sfx.haptic(kind)


func small_hit(pos: Vector3) -> void:
	_splash(pos, Toon.VERMILION, 4)
	sfx.play("slash", randf_range(1.2, 1.5), -8.0)


func big_hit(pos: Vector3) -> void:
	shake = maxf(shake, 0.35)
	sfx.play("kill", 0.9)
	feel("heavy")
	_splash(pos, Toon.VERMILION, 24)
	_blot(pos, Toon.VERMILION, 0.9, 2.5)


func clang(pos: Vector3) -> void:
	shake = maxf(shake, 0.15)
	sfx.play("empty", 0.5)
	feel("clang")
	_splash(pos, Toon.FOAM, 10)


func splash(pos: Vector3, color: Color, amount: int) -> void:
	_splash(pos, color, amount)


func _spawn_list(list: Array) -> void:
	# élite : dès le 4e combat (hors gardiens), au plus un par vague, plus fréquent dans les mondes avancés
	var elite_at := -1
	if room >= 4 and room != MINI_ROOM and room != ROOMS and not in_hub and not list.is_empty():
		if randf() < Enemy.elite_chance(current_world):
			elite_at = randi() % list.size()
	var idx := -1
	for k in list:
		idx += 1
		var e := Enemy.new()
		e.setup(String(k), hero, self)
		var p := Vector3.ZERO
		for attempt in 30:
			p = arena.random_point(hero.position, 4.5)
			if not hazards.is_hole(p, -0.8):
				break
		e.position = p
		add_child(e)
		if "oni_eye" in curses:
			e.hp *= 1.5
		if "haste" in curses:
			e.speed *= 1.25
		# plus robustes : ×2, et +4 % par combat dans le monde
		e.hp *= float(Worlds.world(current_world).hp_mult) * ENEMY_HP_MULT * (1.0 + 0.04 * float(maxi(room - 1, 0)))
		if elite_at >= 0 and idx >= elite_at:
			if e.can_be_elite():
				e.promote(Enemy.roll_affixes(current_world))
				elite_at = -1
		e.set_meta("max_hp", e.hp)
		enemies.append(e)


func xp_need() -> int:
	# courbe plus raide : ~1 niveau par salle au début, puis de plus en plus espacé
	return 8 + 5 * level + level * level


## Butin ramassé (appelé par pickups.gd).
func collect(kind: String, value: int) -> void:
	if kind == "xp":
		xp += value
		sfx.play("xp", 1.0 + randf() * 0.15, -10.0)
		while xp >= xp_need():
			xp -= xp_need()
			level += 1
			_pending_levels += 1
			hud.toast("NIVEAU %d  ·  ROULEAU À LA FIN DU COMBAT" % level)
			sfx.play("levelup", 1.0, -3.0)
			feel("level")
	else:
		run_gold += value
		sfx.play("coin", 1.0, -8.0)


## Un ennemi tombe : il lâche de l'expérience et parfois de l'or.
func _on_enemy_killed(e: Node3D) -> void:
	if e.dummy:
		return  # mannequin : pas de butin
	var k := String(e.kind)
	_last_kill_pos = e.position
	pickups.drop(e.position, "xp", int(KIND_XP.get(k, 1)))
	if randf() < (0.8 if k == "brute" else 0.4):
		pickups.drop(e.position, "coin", 2 if k == "brute" else 1)
	if e.has_meta("elite"):
		# défi d'un recoin relevé : belle récompense
		pickups.drop(e.position, "coin", 8)
		pickups.drop(e.position, "xp", 6)
		hud.toast("DÉFI RELEVÉ  ·  BUTIN")
		sfx.play("levelup", 1.2, -4.0)


func _room_cleared() -> void:
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
	hud.banner("ZONE NETTOYÉE", "LA HAIE S'OUVRE  ·  AVANCE  ·  COMBAT %d / %d" % [arena.zones_done() + 1, arena.zones.size()], Toon.GOLD, 1.6)
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
		hud.banner("ÉTAPE NETTOYÉE", "LE TORII S'ÉVEILLE  ·  SUIS LE CHEMIN D'ENCRE", Toon.GOLD, 1.8)
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


## Sanctuaire facultatif (après certains combats) : un petit autel près du torii (s'il est ouvert),
## sinon près du héros. Le toucher propose un pacte ; passer le torii l'ignore.
func _spawn_shrine() -> void:
	var gp: Vector3 = arena.gate_pos if arena.gate_open else hero.position + Vector3(0, 0, -1.5)
	var side := 1.0 if randf() < 0.5 else -1.0
	var p: Vector3 = arena.clamp_walk(gp + Vector3(2.3 * side, 0, 2.2), 0.6)
	if p.distance_to(gp) < 1.8 or p.distance_to(hero.position) < 1.6:
		p = arena.clamp_walk(gp + Vector3(-2.3 * side, 0, 2.2), 0.6)
	_shrine = Node3D.new()
	add_child(_shrine)
	_shrine.position = Vector3(p.x, 0, p.z)
	var stone := Toon.mat(Color("#8C8A86"))
	var red := Toon.mat(Color("#7A1F1A"))
	var roof := Toon.mat(Toon.SUMI)
	Toon.part(_shrine, Toon.box(Vector3(0.8, 0.18, 0.7)), stone, Vector3(0, 0.09, 0))
	Toon.part(_shrine, Toon.box(Vector3(0.56, 0.5, 0.46)), red, Vector3(0, 0.43, 0))
	Toon.part(_shrine, Toon.box(Vector3(0.82, 0.08, 0.7)), roof, Vector3(0, 0.72, 0))
	var top := Toon.part(_shrine, Toon.box(Vector3(0.5, 0.08, 0.5)), roof, Vector3(0, 0.8, 0))
	top.rotation.y = PI / 4.0
	_disc(_shrine, 1.1, Toon.flat(Color(Toon.GOLD, 0.35)), 0.02)
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = "鬼"
	l.font_size = 110
	l.pixel_size = 0.005
	l.modulate = Toon.VERMILION
	l.outline_modulate = Toon.SUMI
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 1.45, 0)
	_shrine.add_child(l)
	hud.banner("UN SANCTUAIRE", "TOUCHE-LE POUR UN PACTE  ·  OU PASSE LE TORII", Color("#7A1F1A"), 2.6)
	sfx.play("shrine", 1.0, -4.0)


func _open_upgrades() -> void:
	_pick_mode = "upgrade"
	var ids: Array = powers.offer(room)
	_last_offer = ids
	var infos: Array = []
	for id in ids:
		infos.append(powers.describe(id))
	picker.open(ids, infos)
	sfx.play("shot", 0.6)


func _open_sanctuary() -> void:
	_pick_mode = "curse"
	var pool: Array = []
	for id in CURSES.keys():
		if not id in curses:
			pool.append(id)
	pool.shuffle()
	var ids: Array = pool.slice(0, 2)
	var infos: Array = []
	for id in ids:
		var cd: Dictionary = CURSES[id]
		infos.append({"name": String(cd["name"]), "text": String(cd["text"]), "level": -1, "kanji": "鬼", "color": Color("#7A1F1A"), "icon": String(cd.get("icon", "oni"))})
	ids.append("refuse")
	_last_offer = ids
	# refuser rapporte un peu : un cœur s'il en manque, sinon de l'or
	_pass_bonus = "heal" if hero.hp < hero.max_hp else "gold"
	var bonus := "1 cœur soigné" if _pass_bonus == "heal" else ("%d pièces d'or" % PASS_GOLD)
	infos.append({"name": "Passer", "text": "Sans pacte  ·  " + bonus, "level": -1, "kanji": "道", "color": Color("#8C8FA8")})
	picker.open(ids, infos)
	sfx.play("hurt", 0.6, -6.0)
	sfx.play("pact", 1.0, -4.0)


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


## « Passer » au sanctuaire : le petit bonus annoncé sur la carte.
func _pass_reward() -> void:
	if _pass_bonus == "heal" and hero.hp < hero.max_hp:
		heal(1)
		sfx.play("shrine", 1.3, -5.0)
	else:
		run_gold += PASS_GOLD
		float_text(hero.position, "+%d OR" % PASS_GOLD, Toon.GOLD)
		sfx.play("coin", 0.9, -4.0)
	_pass_bonus = ""


func _on_reroll() -> void:
	sfx.play("whoosh", 1.2, -4.0)
	if _pick_mode == "curse":
		_open_sanctuary()
	elif _pick_mode == "flawless":
		_open_flawless()
	else:
		_open_upgrades()


func _on_picked(id: String) -> void:
	if _pick_mode == "curse":
		if id != "refuse":
			_take_curse(id)
		else:
			_pass_reward()
		if _extra_picks > 0:
			_extra_picks -= 1
			_open_upgrades()
		else:
			_after_room_pick()
		return
	powers.add(id)
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
			hero.ch.play(hero.ch.idle)
	else:
		hud.wash_out = true
		hud.wash = clampf(1.0 - (t - 0.8) / 0.35, 0.0, 1.0)
	if t >= 1.15 and _rebuilt:
		hud.wash = 0.0
		hud.wash_out = false
		_set_state("play")


func _rebuild_room() -> void:
	_rebuilt = true
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
	if boss_seg:
		arena.build_room(next, ROOMS, randi(), MINI_ROOM)
	else:
		# (tests : `?room=N` au milieu d'une étape -> on reprend à son premier combat)
		room = int(plan[0]) - 1
		arena.build_stage(plan.size(), randi(), int(plan[0]) == 1)
		_build_pockets()
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


## Cadrage le long de l'étape : la zone de combat entière pendant un combat, sinon le héros (un peu en
## retrait pour voir devant), sans dépasser les bouts de l'étape. 0 pour une salle unique.
func _cam_target() -> float:
	if not arena.stage or hero == null:
		return 0.0
	var lo: float = arena.stage_rect.position.y + HALF.y
	var hi: float = arena.stage_rect.end.y - HALF.y
	var t: float = hero.position.z - CAM_LEAD
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
	if not slots.is_empty() and randf() < 0.6:
		kinds[int(slots.pop_back())] = "spring"
	if not slots.is_empty() and stage_i >= 1 and randf() < 0.65:
		kinds[int(slots.pop_back())] = "elite"
	if not slots.is_empty() and randf() < 0.35:
		kinds[int(slots.pop_back())] = "chest"
	for i in spots.size():
		var p: Vector3 = spots[i]
		var k := String(kinds[i])
		if k == "" or p == Vector3.INF:
			continue
		if k == "puzzle":
			spawn_puzzle("", p)
			continue
		_pockets.append({"kind": k, "pos": p, "used": false, "node": _pocket_node(k, p)})


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
			var lac := Toon.mat(Color("#5A1E18"))
			var gold := Toon.mat(Toon.GOLD)
			Toon.part(n, Toon.box(Vector3(0.72, 0.4, 0.48)), lac, Vector3(0, 0.2, 0))
			var lid := Node3D.new()
			lid.name = "Lid"
			n.add_child(lid)
			lid.position = Vector3(0, 0.4, -0.24)
			Toon.part(lid, Toon.box(Vector3(0.76, 0.14, 0.52)), lac, Vector3(0, 0.07, 0.24))
			Toon.part(lid, Toon.box(Vector3(0.78, 0.05, 0.08)), gold, Vector3(0, 0.07, 0.24))
			Toon.part(n, Toon.box(Vector3(0.1, 0.16, 0.02)), gold, Vector3(0, 0.33, 0.25))
			_disc(n, 0.75, Toon.flat(Color(Toon.SUMI, 0.18)), 0.015)
		"spring":
			var stone := Toon.mat(Color("#8C8A86"))
			for k in 7:
				var a := TAU * float(k) / 7.0
				var s := Toon.part(n, Toon.sphere(0.16), stone, Vector3(cos(a) * 0.62, 0.05, sin(a) * 0.5), Vector3(1.2, 0.6, 1.0))
				s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var water := Toon.flat(Color("#7FD3E0", 0.85))
			var w := _disc(n, 0.55, water, 0.03)
			w.name = "Water"
			w.scale = Vector3(0.55, 1, 0.45)
			var glint := _disc(n, 0.6, Toon.flat(Color("#BFF2F5", 0.35)), 0.035)
			glint.scale = Vector3(0.36, 1, 0.28)
		"elite":
			var stone2 := Toon.mat(Color("#55525A"))
			Toon.part(n, Toon.box(Vector3(0.5, 0.12, 0.4)), stone2, Vector3(0, 0.06, 0))
			Toon.part(n, Toon.box(Vector3(0.34, 0.9, 0.16)), stone2, Vector3(0, 0.55, 0))
			Toon.part(n, Toon.box(Vector3(0.2, 0.3, 0.02)), Toon.mat(Toon.VERMILION, false), Vector3(0, 0.65, 0.09))
			_disc(n, 1.2, Toon.flat(Color(Toon.VERMILION, 0.18)), 0.02)
			var l := Label3D.new()
			l.font = KANJI_FONT
			l.text = "鬼"
			l.font_size = 110
			l.pixel_size = 0.004
			l.modulate = Toon.VERMILION
			l.outline_modulate = Toon.SUMI
			l.outline_size = 18
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3(0, 1.35, 0)
			n.add_child(l)
	return n


## Le héros touche un recoin : coffre (or, expérience), source (2 cœurs), défi (un ennemi d'élite apparaît).
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
				if d < 1.1:
					pk["used"] = true
					var lid := n.get_node_or_null("Lid") as Node3D
					if lid != null:
						lid.rotation.x = -1.05
					pickups.drop(p, "coin", randi_range(6, 9))
					pickups.drop(p, "xp", randi_range(3, 5))
					_splash(p + Vector3(0, 0.3, 0), Toon.GOLD, 16)
					sfx.play("coin", 0.8, -2.0)
					sfx.play("shot", 1.6, -6.0)
					hud.toast("COFFRE  ·  OR ET EXPÉRIENCE")
			"spring":
				if d < 1.1 and hero.hp < hero.max_hp:
					pk["used"] = true
					heal(2)
					var w := n.get_node_or_null("Water") as MeshInstance3D
					if w != null:
						w.material_override = Toon.flat(Color("#4E6E78", 0.6))
					_splash(p + Vector3(0, 0.2, 0), Color("#BFF2F5"), 14)
					sfx.play("shrine", 1.4, -4.0)
					hud.toast("SOURCE  ·  SOIN +2")
			"elite":
				if d < 3.0 and _enc < 0:
					pk["used"] = true
					_spawn_elite(p)
					if is_instance_valid(n):
						n.queue_free()
			"puzzle":
				_update_puzzle(pk, n, d)


## Défi d'un recoin : un costaud d'élite, plus gros et plus solide, qui garde un butin.
func _spawn_elite(p: Vector3) -> void:
	var e := Enemy.new()
	e.setup("brute", hero, self)
	e.position = arena.clamp_walk(p, 0.8)
	add_child(e)
	e.hp *= float(Worlds.world(current_world).hp_mult)
	if "oni_eye" in curses:
		e.hp *= 1.5
	if "haste" in curses:
		e.speed *= 1.25
	# système d'élite commun : ×2.5 PV, ×1.25, bouclier, aura, affixes
	e.promote(Enemy.roll_affixes(current_world))
	e.set_meta("max_hp", e.hp)
	e.set_meta("elite", true)
	enemies.append(e)
	shake = maxf(shake, 0.3)
	sfx.play("strike", 0.45)
	_splash(p + Vector3(0, 0.4, 0), Toon.VERMILION, 20)
	hud.banner("DÉFI", "UN GARDIEN D'ÉLITE  ·  BUTIN À LA CLÉ", Toon.VERMILION, 1.6)


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


## Décor de l'énigme et sa consigne au-dessus : kanji de la figure (et la figure peinte au sol),
## numéros des lanternes, ensō au-dessus de l'esprit (et son aire en pointillés).
func _puzzle_node(pk: Dictionary) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var c: Vector3 = pk["pos"]
	n.position = c
	match String(pk["pz"]):
		"stele":
			var stone := Toon.mat(Color("#7E7A74"))
			Toon.part(n, Toon.box(Vector3(0.8, 0.14, 0.5)), stone, Vector3(0, 0.07, 0))
			Toon.part(n, Toon.box(Vector3(0.56, 1.15, 0.2)), stone, Vector3(0, 0.71, 0))
			Toon.part(n, Toon.box(Vector3(0.66, 0.1, 0.28)), stone, Vector3(0, 1.33, 0))
			Toon.part(n, Toon.box(Vector3(0.36, 0.6, 0.02)), Toon.mat(Toon.PAPER, false), Vector3(0, 0.78, 0.11))
			var shape := String(pk["shape"])
			var gm := Toon.flat(Color(Toon.SUMI, 0.6))
			_ribbon(n, _glyph_pts(shape, Vector3(0, 0, 1.15), 0.75), 0.09, gm)
			pk["gmat"] = gm
			pk["label"] = _puzzle_label(n, String(SHAPE_KANJI.get(shape, "円")), Vector3(0, 1.95, 0), Toon.SUMI)
		"lanterns":
			var mats: Array = []
			var spots: Array = pk["lanterns"]
			var stone2 := Toon.mat(Color("#8C8A86"))
			var roof := Toon.mat(Toon.SUMI)
			for i in spots.size():
				var q: Vector3 = spots[i]
				var ln := Node3D.new()
				n.add_child(ln)
				ln.position = q - c
				Toon.part(ln, Toon.cyl(0.2, 0.24, 0.12), stone2, Vector3(0, 0.06, 0))
				Toon.part(ln, Toon.box(Vector3(0.12, 0.42, 0.12)), stone2, Vector3(0, 0.33, 0))
				var lamp := Toon.mat(Color("#6B6258"))
				lamp.emission_enabled = true
				lamp.emission = Color.BLACK
				Toon.part(ln, Toon.box(Vector3(0.3, 0.26, 0.3)), lamp, Vector3(0, 0.67, 0))
				Toon.part(ln, Toon.cyl(0.04, 0.3, 0.14, 4), roof, Vector3(0, 0.87, 0))
				_disc(ln, 0.42, Toon.flat(Color(Toon.GOLD, 0.22)), 0.015)
				_puzzle_label(ln, str(i + 1), Vector3(0, 1.3, 0), Toon.VERMILION)
				mats.append(lamp)
			pk["mats"] = mats
		"spirit":
			var rm := Toon.flat(Color("#7FD3E0", 0.5))
			for k in 10:
				var a0 := TAU * float(k) / 10.0
				var arc := PackedVector3Array()
				for j in 5:
					var a := a0 + 0.42 * float(j) / 4.0
					arc.append(Vector3(cos(a), 0, sin(a)) * 1.7)
				_ribbon(n, arc, 0.06, rm)
			var sp := Node3D.new()
			sp.name = "Spirit"
			n.add_child(sp)
			sp.position = Vector3(0, 0.95, 0)
			Toon.part(sp, Toon.sphere(0.22), Toon.flat(Color("#CFF6FF", 0.85)), Vector3.ZERO)
			Toon.part(sp, Toon.sphere(0.11), Toon.flat(Color(1, 1, 1, 0.95)), Vector3(0, 0.02, 0.06))
			Toon.part(sp, Toon.sphere(0.12), Toon.flat(Color("#9FE6F2", 0.6)), Vector3(0, 0.2, 0), Vector3(0.8, 1.6, 0.8))
			_puzzle_label(sp, "円", Vector3(0, 0.75, 0), Color("#2E8FA3"))
			var sh := _disc(n, 0.25, Toon.flat(Color(Toon.SUMI, 0.15)), 0.012)
			sh.name = "Shadow"
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
		hud.toast(_puzzle_hint(pk))
		sfx.play("shrine", 1.6, -8.0)
	match String(pk["pz"]):
		"spirit":
			var sp := n.get_node_or_null("Spirit") as Node3D
			if sp != null:
				var q := spirit_pos(pk)
				sp.position = Vector3(q.x - n.position.x, 0.95 + 0.12 * sin(run_time * 3.0 + float(pk["t"])), q.z - n.position.z)
				var sh := n.get_node_or_null("Shadow") as Node3D
				if sh != null:
					sh.position = Vector3(sp.position.x, 0.012, sp.position.z)
		"lanterns":
			var mats: Array = pk["mats"]
			var lit := 0
			var fail := run_time - float(pk["fail_t"]) < 0.6
			if not fail and touching and stroke != null and _explore and d < 7.0:
				lit = maxi(0, _lantern_progress(pk["lanterns"], stroke.points))
			for i in mats.size():
				var m: StandardMaterial3D = mats[i]
				if fail:
					m.albedo_color = Toon.VERMILION
					m.emission = Color.BLACK
				elif i < lit:
					m.albedo_color = Color("#FFD27A")
					m.emission = Color("#FFB648")
				else:
					m.albedo_color = Color("#6B6258")
					m.emission = Color.BLACK


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
		if bool(pk["used"]) or String(pk["kind"]) != "puzzle" or not is_instance_valid(pk["node"]):
			continue
		var c: Vector3 = pk["pos"]
		if Vector2(o.x - c.x, o.z - c.z).length() > 9.0:
			continue
		match String(pk["pz"]):
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
				if absf(_winding(pts, sp)) >= PI * 1.6:
					_solve_puzzle(pk)
				else:
					var close := 1.0e9
					for p in pts:
						close = minf(close, Vector2(p.x - sp.x, p.z - sp.z).length())
					if close < 1.6 and StrokeShapes.length(pts) > 3.0:
						_puzzle_fail(pk, "ENTOURE L'ESPRIT D'UNE BOUCLE COMPLÈTE")


func _puzzle_fail(pk: Dictionary, msg: String) -> void:
	pk["fail_t"] = run_time
	hud.toast(msg)
	sfx.play("empty", 0.9, -4.0)


## Énigme résolue : la consigne se dore, la récompense tombe (coffre d'or et d'expérience, soin ou relance).
func _solve_puzzle(pk: Dictionary) -> void:
	pk["used"] = true
	puzzles_solved += 1
	var c: Vector3 = pk["pos"]
	var n = pk["node"]  # sans type : le nœud peut avoir été libéré
	var lb = pk.get("label", null)
	if is_instance_valid(lb):
		lb.modulate = Toon.GOLD
	if pk.has("gmat"):
		var gm: StandardMaterial3D = pk["gmat"]
		gm.albedo_color = Color(Toon.GOLD, 0.85)
	if pk.has("mats"):
		for m in pk["mats"]:
			var lm: StandardMaterial3D = m
			lm.albedo_color = Color("#FFD27A")
			lm.emission = Color("#FFB648")
	if String(pk["pz"]) == "spirit" and is_instance_valid(n):
		var sp = n.get_node_or_null("Spirit")
		if is_instance_valid(sp):
			_splash(sp.global_position, Color("#CFF6FF"), 18)
			sp.queue_free()
	var reward := String(pk["reward"])
	if reward == "heal" and hero.hp >= hero.max_hp:
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


## Énigme proche du robot (CI), hors combat : il la résout lui-même (bot.gd). Vide sinon.
func bot_puzzle() -> Dictionary:
	if not _explore or hero == null:
		return {}
	for pk in _pockets:
		if bool(pk["used"]) or String(pk["kind"]) != "puzzle" or int(pk.get("bot_try", 0)) >= 4:
			continue
		var p: Vector3 = pk["pos"]
		if Vector2(hero.position.x - p.x, hero.position.z - p.z).length() < 2.0:
			pk["bot_try"] = int(pk.get("bot_try", 0)) + 1
			return pk
	return {}


## But du robot hors combat : recoin à fouiller (dans le cadre courant), torii ouvert, entrée de la zone suivante.
func bot_goal() -> Vector3:
	if not arena.stage or _enc >= 0:
		return arena.gate_pos if arena.gate_open else Vector3.INF
	var best := Vector3.INF
	var bd := 1.0e9
	var chosen: Dictionary = {}
	for pk in _pockets:
		if bool(pk["used"]):
			continue
		if String(pk["kind"]) == "spring" and hero.hp >= hero.max_hp:
			continue
		if String(pk["kind"]) == "puzzle" and int(pk.get("bot_try", 0)) >= 4:
			continue  # énigme ratée plusieurs fois : le robot la laisse
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
		return arena.gate_pos
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
	var un: Dictionary = meta.record_world(current_world, room, victory)
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
	menu.gain_seals = int(g.get("seals", 0))
	if victory and _flawless_boss:
		# boss du monde vaincu sans un coup : sceaux et encre en plus
		meta.seals += 2
		meta.sumi += 40
		meta.save_data()
		menu.gain_seals += 2
		menu.gain_sumi += 40
	menu.sumi = meta.sumi
	# nouvelles Vues (ids de meta.PRINTS) pour la feuille de résultats
	var np: Array = g.get("prints", [])
	menu.new_prints = np.duplicate()


func _take_curse(id: String) -> void:
	curses.append(id)
	shake = 0.4
	sfx.play("strike", 0.5)
	sfx.play("pact", 0.8, -2.0)
	feel("heavy")
	match id:
		"dry", "oni_eye":
			_extra_picks += 2
		"heavy":
			hero.max_hp += 2
			hero.hp = hero.max_hp
		"haste":
			_extra_picks += 1
			hero.hp = hero.max_hp


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
	_splash(hero.position, Toon.FOAM, 8)
	hero.position = Vector3(safe.x, 0, safe.z)
	_prev_hero = hero.position
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
		hud.banner("VICTOIRE", "SANS UNE ÉGRATIGNURE  ·  +2 SCEAUX, +40 ENCRE", Toon.GOLD, 2.6)
	else:
		hud.banner("VICTOIRE", String(Worlds.world(current_world).name), Toon.GOLD, 2.2)
	music.play_victory()
	_set_state("dying")


## Après la séquence de fin : gains, record, et la feuille de résultats.
func _finish_run() -> void:
	var won := _ending_victory
	menu.victory = won
	_award(won)
	# victoire : le bouton principal mène au monde suivant (REJOUER sur le dernier monde, et en cas de défaite)
	menu.next_label = ""
	if won and current_world < Worlds.WORLDS.size():
		menu.next_label = "DÉCOUVRIR LE MONDE SUIVANT" if int(menu.unlock_world) > 0 else "MONDE SUIVANT"
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


# ------------------------------------------------------------------ aides pour les pouvoirs

func damage_enemy(e: Node3D, dmg: float, fx := true) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var killed: bool = e.hurt_dot(dmg)
	if fx:
		_splash(e.position, Toon.GOLD, 5)
	if killed:
		kills += 1
		powers.on_kill(e)
		_on_enemy_killed(e)
		sfx.play("kill", randf_range(1.1, 1.3), -6.0)
		feel("hit")
		_splash(e.position, Toon.VERMILION, 14)
		_blot(e.position, Toon.VERMILION, 0.45, 2.5)


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
func damage_bosses(center: Vector3, r: float, dmg: float, fx := true) -> Array:
	var hits: Array = []
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		var p: Vector3 = bo.aoe_hit(center, r, dmg, fx)
		if p == Vector3.INF:
			continue
		hits.append(p)
		if fx:
			_dmg_text(p, dmg, false)
			_splash(p, Toon.GOLD, 6)
	return hits


## Dégâts le long d'un trait sur les boss : chacun n'est touché qu'une fois.
func damage_bosses_line(pts: PackedVector3Array, r: float, dmg: float, fx := true) -> void:
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		for i in range(0, pts.size(), 3):
			var p: Vector3 = bo.aoe_hit(pts[i], r, dmg, fx)
			if p != Vector3.INF:
				if fx:
					_dmg_text(p, dmg, false)
					_splash(p, Toon.GOLD, 6)
				break


func heal(n: int) -> void:
	hero.hp = mini(hero.max_hp, hero.hp + n)
	float_text(hero.position, "+%d" % n, Toon.VERMILION)


## Éclair (雷) : zigzag jaune cerné d'encre, de a à b (à hauteur de torse).
func zap(a: Vector3, b: Vector3) -> void:
	vfx.bolt(Vector3(a.x, 0.9, a.z), Vector3(b.x, 0.9, b.z))


## Cercle de feu (火) : couronne de flammes, anneau orange, braises, roussi.
func fire_ring(pos: Vector3, r: float) -> void:
	vfx.fire_burst(pos, r)


## Sillage de feu : vraies flammes le long du trait et traînée de suie (durée en temps du jeu).
func fire_trail_fx(points: PackedVector3Array, dur: float) -> void:
	vfx.fire_trail(points, dur)


## Estoc d'ombre (影) de a vers b (crochet, riposte d'Utsusemi).
func shadow_stab(a: Vector3, b: Vector3) -> void:
	vfx.shadow_stab(a, b)


## Tourbillon de vent (風) : toupie de la boucle, tourbillons.
func wind_spin(pos: Vector3, r: float) -> void:
	vfx.swirl(pos, r)


## Onde d'encre (墨) : choc de l'ensō.
func ink_wave(pos: Vector3, r: float) -> void:
	vfx.ink_wave(pos, r)


## Figure reconnue, à l'arrivée de la ruée : sa technique vient des rouleaux de figure (powers.figure_end).
func _apply_shape() -> void:
	if _shape.is_empty():
		return
	var sh: Dictionary = _shape
	_shape = {}
	shape_counts[String(sh.shape)] = int(shape_counts.get(String(sh.shape), 0)) + 1
	var label: String = powers.figure_end(String(sh.shape), sh)
	hud.shape_pop(String(sh.shape), label)
	sfx.play("tech_" + String(sh.shape), 1.0, -3.0)
	feel("figure")


## Fin d'un bond (figure) : les pouvoirs de figure frappent à l'atterrissage.
func _on_hero_landed() -> void:
	shake = maxf(shake, 0.5)
	sfx.play("strike", 0.7)
	feel("heavy")
	powers.figure_landed(hero.position)


## Techniques qui durent (toupie, coupe différée…) : gérées par les pouvoirs de figure.
func _update_moves(dt: float) -> void:
	powers.figure_update(dt)


func shape_text(pos: Vector3, kanji: String) -> void:
	if kanji == "":
		return
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = kanji
	l.font_size = 160
	l.pixel_size = 0.006
	l.modulate = Toon.SUMI
	l.outline_modulate = Toon.WASHI
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 2.8, 0)
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.75, "kind": "label"})


## Chiffre de dégâts au-dessus de l'ennemi : blanc cerclé d'encre, vermillon s'il tue ou en combo.
## Chiffre de dégâts : encre épaisse, rebond à l'apparition, petite courbe en montant ; les touches
## rapprochées sur un même ennemi s'additionnent. Blanc normal, or gros coup, vermillon coup fatal.
func _dmg_text(pos: Vector3, dmg: float, killed: bool, key: Object = null) -> void:
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
	if game_over:
		return
	# on trace dans le pad du bas : le trait part du héros et reproduit le geste du doigt, en plus grand
	# en mode pad, on peut poser le doigt n'importe où : le geste est reproduit depuis le héros
	# (le cadre du pad n'est qu'un repère visuel)
	_strokes_done += 1
	touching = true
	_running = false
	_hold_t = 0.0
	_hold_sp = sp
	_pad_start = sp
	_touch_ms = Time.get_ticks_msec()
	hud.pad_trail = PackedVector2Array([sp])
	origin = hero.dash_end()
	stroke_layer += 1
	stroke = InkStroke.new(origin, stroke_layer)
	add_child(stroke)


## Zone du pad tactile, en bas de l'écran (coordonnées de la vue).
func pad_rect() -> Rect2:
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
	var target := _clamp_point(_ground(sp)) if ctrl_mode == "screen" else _clamp_point(origin + _pad_to_world(sp - _pad_start))
	if hud.pad_trail.size() == 0 or hud.pad_trail[hud.pad_trail.size() - 1].distance_to(sp) > 4.0:
		hud.pad_trail.append(sp)
	var was_empty: bool = stroke.exhausted
	# hors combat : encre illimitée, trait deux fois plus long
	var budget: float = maxf(0.0, elan_max() * EXPLORE_REACH - float(stroke.length)) if _explore else elan
	var used: float = stroke.extend_to(target, budget)
	if not _explore:
		elan -= used
	if stroke.exhausted and not was_empty:
		sfx.play("empty", 0.8)


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
		# petit coup de doigt (direction choisie) ou simple tap (loin du danger) : bond d'esquive gratuit
		var now := Time.get_ticks_msec()
		var flick := (_ground(sp) - _ground(_pad_start)) if ctrl_mode == "screen" else _pad_to_world(sp - _pad_start)
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
		var dir := Vector3.ZERO
		if flick.length() > 0.12:
			dir = flick.normalized()
		elif is_tap:
			dir = _dodge_dir(sp)
		if dir != Vector3.ZERO and _dodge_cd <= 0.0:
			var s: MeshInstance3D = stroke
			var dd: float = powers.dodge_dist(DODGE_DIST)
			var end := _clamp_point(origin + dir * dd)
			s.extend_to(end, dd)
			_dodge_cd = DODGE_COOLDOWN
			hero.invuln = maxf(hero.invuln, powers.val("shadow_step"))
			_launch(s)
			powers.on_dodge(origin, end)
			if state == "tuto":
				tuto.on_dodge()
		else:
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
## continue au trot dans la direction finale tant que le doigt reste posé (manette : on l'oriente en
## glissant autour du point d'appui ; écran : il suit le doigt). Il s'arrête aux bords et aux trous.
func _update_run(real: float, dt: float) -> void:
	if _running:
		if not touching or not _explore or state != "play":
			_stop_run()
			return
		if hero.dashing or float(hero._leap_t) >= 0.0:
			return  # la ruée du trait d'abord
		var dir := _run_dir
		if ctrl_mode == "screen":
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
		hero.ch.play("Running_A", 1.15)
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
	_run_anchor = _hold_sp
	_run_sp = _hold_sp
	_running = true
	run_dist = 0.0
	var s: MeshInstance3D = stroke
	stroke = null
	_launch(s)
	hud.pad_trail = PackedVector2Array() if ctrl_mode == "screen" else PackedVector2Array([_run_anchor])


## Doigt qui bouge pendant la course : nouvelle direction (manette : autour du point d'appui).
func _steer_run(sp: Vector2) -> void:
	_run_sp = sp
	if ctrl_mode == "screen":
		return  # la direction suit le doigt à chaque image (_update_run)
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


## Direction d'un bond d'esquive au tap : vers le doigt (mode écran), sinon loin du danger le plus proche
## (zone annoncée, boule, ennemi), en restant sur la terre ferme et hors des zones.
func _dodge_dir(sp: Vector2) -> Vector3:
	var o: Vector3 = hero.dash_end()
	var want := Vector3.ZERO
	if ctrl_mode == "screen":
		var g := _ground(sp) - o
		g.y = 0
		if g.length() > 0.3:
			want = g.normalized()
	if want == Vector3.ZERO:
		var threat := Vector3.INF
		var best := 4.5
		for e in enemies:
			if not is_instance_valid(e) or e.dead or e.dummy:
				continue
			var z: Array = e.danger_zone()
			var tp: Vector3 = z[0] if z.size() == 3 else e.position
			var d := Vector2(tp.x - o.x, tp.z - o.z).length()
			if d < best:
				best = d
				threat = tp
		for b in bullets:
			var n: Node3D = b.node
			var db := Vector2(n.position.x - o.x, n.position.z - o.z).length()
			if db < best:
				best = db
				threat = n.position
		for bo in bosses:
			if is_instance_valid(bo) and not bo.dead:
				var dbo := Vector2(bo.position.x - o.x, bo.position.z - o.z).length()
				if dbo < best:
					best = dbo
					threat = bo.position
		if threat != Vector3.INF:
			want = Vector3(o.x - threat.x, 0, o.z - threat.z)
			want = want.normalized() if want.length() > 0.01 else Vector3(0, 0, 1)
		else:
			want = Vector3(0, 0, 1)  # rien à fuir : petit bond en arrière
	# on garde la direction la plus proche de l'idéale qui atterrit sur un sol sûr
	var dd: float = powers.dodge_dist(DODGE_DIST)
	for k in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, PI]:
		var dv := want.rotated(Vector3.UP, float(k))
		var p := _clamp_point(o + dv * dd)
		if not hazards.is_hole(p, 0.2) and not is_danger(p, 0.2):
			return dv
	return want


## Ultime (double tap, jauge pleine) : un immense coup de pinceau traverse l'arène et frappe tout.
func _ultimate() -> void:
	ult = 0.0
	var hp := hero.position
	var a := Vector3(-HALF.x - 1.0, 0, hp.z + 1.6)
	var b := Vector3(HALF.x + 1.0, 0, hp.z - 1.6)
	vfx.slash_line(a, b)
	vfx.slash_line(Vector3(-HALF.x - 1.0, 0, hp.z - 2.4), Vector3(HALF.x + 1.0, 0, hp.z + 0.8))
	vfx.ink_wave(hp, 5.5)
	shape_text(hp + Vector3(0, 1.2, 0), "筆")
	hud.screen_flash = maxf(hud.screen_flash, 0.5)
	shake = maxf(shake, 0.7)
	sfx.play("iai", 0.8)
	sfx.play("kill", 0.7)
	feel("heavy")
	hud.toast("IPPITSU  ·  ULTIME")
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead and (not e.dummy or state == "tuto"):
			damage_enemy(e, ULT_DAMAGE * chain_mult())
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			bo.aoe_hit(bo.position, 6.0, ULT_DAMAGE * 2.0 * chain_mult(), true)
	if state == "tuto":
		tuto.on_ultimate()


## Jauge d'ultime : se remplit en tranchant.
func gain_ult(v: float) -> void:
	if state == "play" and not in_hub:
		ult = minf(1.0, ult + v)


func _launch(s: MeshInstance3D) -> void:
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = s
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
	_stroke_hit = false
	_prev_hero = hero.position
	hero.speed_mult = powers.dash_mult()
	_auto_step = false  # un vrai trait reprend la main sur le pas de côté automatique
	_safe_point = s.points[0]
	powers.on_stroke_release(s.points)
	_shape = StrokeShapes.detect(s.points) if s.length >= 2.0 else {}
	_fig_mods = {}
	if not _shape.is_empty():
		shape_text(s.last(), String(SHAPE_KANJI.get(_shape.shape, "")))
		sfx.play("whoosh", 0.7)
		_fig_mods = powers.figure_launch(String(_shape.shape), _shape, s.points)
		hero.speed_mult *= float(_fig_mods.get("speed", 1.0))
	if _explore:
		_puzzle_stroke(s.points)  # énigmes des recoins (jamais en combat)
	sfx.play("whoosh", randf_range(0.9, 1.1))
	feel("dash")


func _on_dash_finished() -> void:
	if _auto_step:
		_auto_step = false
		return
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = null
	if state == "tuto":
		tuto.on_dash_end(hero.position, _stroke_kills, String(_shape.get("shape", "")))
	if _stroke_hit:
		_add_chain(2 if not _shape.is_empty() else 1)
	_apply_shape()
	if hazards.is_hole(hero.position):
		_land_safe()
	for bo in bosses:
		if is_instance_valid(bo):
			bo.end_stroke(stroke_id)
	powers.on_dash_end(hero.position, _stroke_kills)
	if combo >= 3:
		elan = elan_max()
	_reset_stroke_state()


# ------------------------------------------------------------------ combat

func spawn_bullet(pos: Vector3, dir: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	if not _fx_cache.has("bullet"):
		_fx_cache["bullet"] = [Toon.sphere(0.3), Toon.mat(Toon.VERMILION, true, 0.05), Toon.sphere(0.13), Toon.mat(Toon.WASHI, false), Toon.flat(Color(0, 0, 0, 0.2))]
	var bc: Array = _fx_cache["bullet"]
	Toon.part(n, bc[0], bc[1], Vector3.ZERO)
	Toon.part(n, bc[2], bc[3], Vector3(0, 0.12, -0.12))
	var shadow := _disc(n, 0.26, bc[4])
	shadow.position.y = -pos.y + 0.012
	bullets.append({"node": n, "vel": dir * 3.4, "life": 7.0})
	sfx.play("shot", randf_range(0.9, 1.1), -6.0)


func take_token(e: Node) -> bool:
	for i in range(_attackers.size() - 1, -1, -1):
		if not is_instance_valid(_attackers[i]) or _attackers[i].dead:
			_attackers.remove_at(i)
	if e in _attackers:
		return true
	if _attackers.size() >= ATTACK_TOKENS:
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


func enemy_strike(center: Vector3, r: float) -> void:
	shake = maxf(shake, 0.12)
	sfx.play("strike", randf_range(0.9, 1.1), -3.0)
	_blot(center, Color(Toon.VERMILION, 0.35), r * 0.9, 0.6)
	# le coup tombe : bref anneau d'encre sur le bord de la zone
	vfx.ring(Vector3(center.x, 0.08, center.z), Toon.SUMI, r)
	var d := Vector2(hero.position.x - center.x, hero.position.z - center.z).length()
	if d < r + Hero.RADIUS * 0.6:
		_hurt_hero()


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


func _hurt_hero() -> void:
	if hero.dashing or hero.invuln > 0.0 or hero.protected() or game_over:
		return
	if foam > 0:
		# bouclier d'écume : le coup est bu par l'écume
		foam -= 1
		hero.invuln = 0.6
		clang(hero.position)
		float_text(hero.position, "ÉCUME", Toon.FOAM)
		return
	if powers.on_hurt():
		return
	hero.hurt()
	_scratched = true
	_break_chain()
	hud.hurt_flash = 1.0
	shake = 0.45
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
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.is_harmless() or e.last_stroke == stroke_id:
			continue
		var p: Vector3 = e.position
		var t := 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var q := a + seg * t
		if Vector2(p.x - q.x, p.z - q.z).length() < e.radius + HIT_REACH:
			e.last_stroke = stroke_id
			combo += 1
			var dmg := 1.0 * (1.0 + 0.3 * (combo - 1))
			var dir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
			var piercing: bool = bool(_fig_mods.get("pierce", false))
			if not piercing and e.blocks(dir):
				e.last_stroke = stroke_id
				combo -= 1
				clang(p)
				float_text(p, "GARDE !", Toon.FOAM)
				e.shield_break()
				hero.stop_dash()
				# le héros rebondit sur le bouclier au lieu de rester collé
				hero.position = arena.clamp_walk(hero.position - dir.normalized() * 0.8, 0.4)
				_prev_hero = hero.position
				continue
			dmg *= float(_fig_mods.get("dmg", 1.0))
			dmg *= chain_mult()
			dmg = powers.on_hit(e, dmg, dir)
			_stroke_hit = true
			_chain_t = 0.0
			var killed: bool = e.take_hit(dmg, dir)
			gain_ult(0.06 if killed else 0.03)
			_dmg_text(p, dmg, killed, e)
			vfx.impact(p, dir, killed)
			if killed:
				_on_enemy_killed(e)
				# le grand 斬 ne vient que sur une belle série
				vfx.kill_burst(p, dir, combo >= 3)
				hud.screen_flash = maxf(hud.screen_flash, 0.12)
			if killed:
				kills += 1
				_stroke_kills += 1
				powers.on_kill(e)
			elan = minf(elan_max(), elan + ELAN_PER_HIT)
			shake = maxf(shake, 0.11 if killed else 0.05)
			sfx.play("kill" if killed else "slash", 1.0 + 0.08 * (combo - 1) + randf_range(-0.04, 0.04))
			feel("multi" if killed and _stroke_kills == 3 else ("kill" if killed else "hit"))
			_splash(p, Toon.VERMILION, 8 if killed else 4)
			# tache d'encre au sol seulement à la mise à mort
			if killed:
				_blot(p, Color(Toon.SUMI, 0.6), randf_range(0.25, 0.38) * (1.4 if e.kind == "brute" else 1.0), 1.8)
			_slash_mark(p, dir)
			if combo >= 3:
				_combo_label(p, combo)
	for bo in bosses:
		if not is_instance_valid(bo):
			continue
		if bo.check_dash(a, b, stroke_id):
			combo += 1
			var bd := 1.0 * (1.0 + 0.3 * (combo - 1)) * chain_mult() * float(_fig_mods.get("dmg", 1.0))
			_stroke_hit = true
			_chain_t = 0.0
			var bdir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
			bo.take_hit(powers.boss_dmg(bd), bdir)
			gain_ult(0.025)
			powers.on_boss_hit(bo.position, bd)
			elan = minf(elan_max(), elan + ELAN_PER_HIT)
			shake = maxf(shake, 0.22)
			sfx.play("slash", 0.85 + 0.08 * (combo - 1))
			feel("boss_hit")
			_splash(bo.position + Vector3(0, 0.6, 0), Toon.VERMILION, 6)
			_slash_mark(bo.position, bdir)
			vfx.impact(bo.position, bdir, false)


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
		elif d < 0.3 + Hero.RADIUS and not hero.dashing and hero.invuln <= 0.0:
			_hurt_hero()
			b.life = 0.0
		if b.life <= 0.0 or not arena.bounds.grow(1.0).has_point(Vector2(n.position.x, n.position.z)):
			if b.life <= 0.0:
				_splash(n.position, Toon.VERMILION, 6)
			n.queue_free()
			bullets.remove_at(i)


# ------------------------------------------------------------------ effets

func _splash(pos: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	# gouttes : un maillage par couleur, partagé (pas de nouvelle ressource à chaque coup)
	var key := "drop" + color.to_html()
	if not _fx_cache.has(key):
		var m := Toon.sphere(0.07)
		m.radial_segments = 8
		m.rings = 4
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = color
		m.material = mt
		_fx_cache[key] = m
	p.mesh = _fx_cache[key]
	p.amount = amount
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.position = pos + Vector3(0, 0.6, 0)
	add_child(p)
	p.emitting = true
	effects.append({"node": p, "t": 0.0, "life": 1.0, "kind": "none"})


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
		fx.t += real if fx.kind == "label" or fx.kind == "dmg" else dt
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
		if k >= 1.0:
			node.queue_free()
			effects.remove_at(i)


# ------------------------------------------------------------------ boucle

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _ticks) / 1000000.0, 0.05)
	_ticks = now
	if _bot != null:
		real = 1.0 / 30.0  # pas fixe : le robot joue aussi vite que la machine le permet
		_bot.step(real)

	# pause : tout est figé, seul l'écran de pause vit
	if state == "paused" or (state == "pick" and _pick_context == "level"):
		Engine.time_scale = 0.0
		return

	# temps : fin de partie au ralenti, sinon normal
	var target := 1.0
	if state == "dying":
		target = 0.25 if not _ending_victory else 0.6
	elif game_over:
		target = 0.35
	elif state == "play":
		target = powers.time_mult()  # ralentis des pouvoirs (souffle suspendu, instant volé)
		if _slowmo_t >= 0.0:
			# dernier ennemi du combat : ralenti cinématographique (temps réel)
			target = minf(target, _slowmo_scale())
			_slowmo_t += real
			if _slowmo_t > 0.85:
				_slowmo_t = -1.0
	elif _slowmo_t >= 0.0 and state != "pick":
		_slowmo_t = -1.0
	if target < Engine.time_scale:
		Engine.time_scale = lerpf(Engine.time_scale, target, minf(1.0, real * 18.0))
	else:
		Engine.time_scale = target
	var dt := real * Engine.time_scale

	_dodge_cd = maxf(0.0, _dodge_cd - real)
	hud.set("ult", ult)  # jauge d'ultime (dessinée par le HUD si elle existe)
	if not touching and not hero.dashing:
		elan = minf(elan_max(), elan + ELAN_REGEN * powers.regen_mult() * meta.regen_mult() * real)
	# hors combat : l'encre se recharge aussitôt, et le doigt posé fait courir
	_explore = exploring()
	if _explore:
		elan = elan_max()
	_update_run(real, dt)

	_check_slashes()
	_update_bullets(dt)
	_update_effects(dt, real)

	# nettoyage et vagues
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)
	for i in range(bosses.size() - 1, -1, -1):
		if not is_instance_valid(bosses[i]):
			bosses.remove_at(i)
	_state_t += real
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
	# rouleaux de niveau : seulement une fois la salle nettoyée (jamais en plein combat)
	if state == "play" and _pending_levels > 0 and _room_done and not hero.dashing and not touching:
		_pending_levels -= 1
		_pick_context = "level"
		hud.toast("NIVEAU %d  ·  CHOISIS TON ROULEAU" % level)
		vfx.ring(Vector3(hero.position.x, 0.05, hero.position.z), Toon.GOLD, 2.2)
		_set_state("pick")
		_open_upgrades()
	if state == "play":
		run_time += real
		if chain > 0:
			_chain_t += real
			if _chain_t > CHAIN_TIMEOUT:
				chain = 0
		_update_moves(dt)
		powers.update(dt)
		hazards.update(dt)
		for bo in bosses:
			if is_instance_valid(bo) and bo.touching_hero(hero.position):
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
		_update_pockets()
		if not _waves_left.is_empty() and alive <= 1:
			# vague suivante
			_spawn_list(_waves_left.pop_front())
			wave_index += 1
			sfx.play("strike", 0.8, -4.0)
			hud.toast("VAGUE %d / %d" % [wave_index, waves_total])
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
	if state in ["play", "pick", "transit", "boss_intro", "tuto"]:
		_cam_dz = lerpf(_cam_dz, _cam_target(), minf(1.0, real * 2.6))
	arena.follow_camera(_cam_dz)
	var cb := _cam_base.translated(Vector3(0, 0, _cam_dz))
	if _slowmo_t >= 0.0:
		# léger rapproché vers le dernier coup
		cb.origin = cb.origin.lerp(_slowmo_pos + Vector3(0, 0.8, 0), 0.14 * _slowmo_w())

	# caméra : plan d'accueil, transition vers l'arène, secousse en jeu
	if state == "menu":
		# la barque tangue doucement, le héros avec elle
		_rock_boat()
		var sway := Vector3(sin(_state_t * 0.35) * 0.18, sin(_state_t * 0.5) * 0.06, 0)
		cam.global_transform = _menu_transform().translated(sway)
	elif state == "intro":
		var k := clampf(_state_t / 1.6, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		cam.global_transform = _menu_transform().interpolate_with(cb, k)
		if k >= 1.0:
			menu_boat.visible = false
			_set_state("play")
	elif state == "sail":
		# Jouer : la barque prend le large (elle accélère), puis on choisit le monde
		menu_boat.position.z = maxf(menu_boat.position.z - real * minf(_state_t * 3.2, 2.6), 12.2)
		_rock_boat()
		cam.global_transform = _menu_transform()
		if _state_t > 1.3:
			_open_worlds()
	elif state == "worlds":
		menu_boat.position.z = maxf(menu_boat.position.z - real * 0.6, 11.4)  # elle glisse encore vers le ponton derrière la carte
		_rock_boat()
		cam.global_transform = _menu_transform()
	elif state == "boss_intro":
		shake = maxf(0.0, shake - real * 1.6)
		var si := shake * shake * 1.2
		cam.global_transform = _boss_intro_cam().translated(Vector3(randf_range(-si, si), randf_range(-si, si) * 0.5, randf_range(-si, si)))
	elif shake > 0.0:
		shake = maxf(0.0, shake - real * 1.6)
		var s := shake * shake * 1.2
		cam.global_transform = cb.translated(Vector3(randf_range(-s, s), randf_range(-s, s) * 0.5, randf_range(-s, s)))
	else:
		cam.global_transform = cb

	hud.pad = pad_rect() if ctrl_mode == "pad" else Rect2()
	hud.pad_active = touching
	var show_pad := pad_show == "always" or (pad_show == "start" and (state == "tuto" or _strokes_done < 12))
	hud.pad_alpha = move_toward(hud.pad_alpha, 1.0 if show_pad else 0.0, real * 1.5)
	if state in ["play", "transit", "pick", "tuto", "paused", "boss_intro"]:
		# l'arène descend quand le pad s'efface (plus de grande bande d'eau vide en bas)
		var kp: float = hud.pad_alpha if ctrl_mode == "pad" else 0.0
		_cam_base = _cam_full.interpolate_with(_cam_pad, kp * kp * (3.0 - 2.0 * kp))
	hud.in_play = state in IN_PLAY_STATES
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
	hud.chain_left = 1.0 - _chain_t / CHAIN_TIMEOUT
	hud.chain_mult = chain_mult()
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
		stroke.danger = is_danger(stroke.last(), stroke.length / Hero.DASH_SPEED)
	hud.elan_empty = touching and stroke != null and stroke.exhausted
	hud.wave = stage_i + 1
	# flèche : vers le torii ouvert, ou vers la suite de l'étape entre deux combats
	hud.gate_hint = state == "play" and (arena.gate_open or (arena.stage and _enc < 0 and arena.zones_left() > 0))
	# barre d'avancée de l'étape (héros, zones de combat) et compte des combats
	if arena.stage and not in_hub:
		hud.stage_k = arena.progress_of(hero.position)
		var marks: Array = []
		for i in arena.zones.size():
			var sp: Vector2 = arena.zone_span(i)
			marks.append([sp.x, sp.y, int(arena.zone_state[i])])
		hud.stage_marks = marks
		hud.enc_done = arena.zones_done()
		hud.enc_total = arena.zones.size()
	else:
		hud.stage_k = -1.0
		hud.stage_marks = []
		hud.enc_done = 0
		hud.enc_total = 0
	hud.boss_name = ""
	hud.boss_hint = ""
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			hud.boss_name = bo.title
			# point faible : seulement après 12 s sans le moindre dégât sur ce boss
			var bh: float = float(bo.hp)
			if bh < _boss_hp_seen - 0.001 or bo != _boss_seen:
				_boss_dry_t = 0.0
			_boss_seen = bo
			_boss_hp_seen = bh
			_boss_dry_t += real
			if _boss_dry_t > 12.0:
				hud.boss_hint = String(BOSS_HINTS.get(String(bo.kind), ""))
			hud.boss_ratio = clampf(bo.hp / bo.max_hp, 0.0, 1.0)
