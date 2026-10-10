extends Node
## Robot testeur (CI) : `-- --bot [--mode=campaign|powers|ui|stress] [--seed=N]`.
##  campaign (défaut) : les 8 mondes d'affilée, sanctuaire compris, puis une partie où il doit mourir.
##    Les boss (gardiens compris) disent eux-mêmes quel trait les blesse (bot_stroke) : boucles,
##    perles et bulles dans l'ordre, chaînes et fils tranchés en travers, tornade traversée.
##    Le héros prend de vrais coups (soigné à chaque salle, protégé seulement au dernier coup encaissable :
##    1 cœur, 2 dès que les coups lourds en ôtent 2). Bilan par monde (BOT STATS, BOT BILAN).
##  powers : chaque pouvoir, à chaque niveau, actif pendant une salle de combat entière (gardien et boss
##    compris) ; les six figures, des traits de fuite, malédictions et sanctuaires au hasard ; écume, utsusemi, hōō.
##  ui : parcours scripté des écrans (bot_ui.gd), sans combat du robot.
##  stress : vagues doublées, 16 pouvoirs dont 6 légendaires, nœuds comptés salle après salle.
## Il signale les salles où il reste bloqué (« BOT ALERTE »). Fin : « BOT DONE » puis il quitte.

const InkStroke = preload("res://scripts/ink_stroke.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Meta = preload("res://scripts/meta.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const BotShapes = preload("res://scripts/bot_shapes.gd")
const BotUi = preload("res://scripts/bot_ui.gd")
const Worlds = preload("res://scripts/worlds.gd")
const MODES := ["campaign", "powers", "ui", "stress"]
const ROOM_TIMEOUT := {"campaign": 150.0, "powers": 180.0, "stress": 260.0}  # secondes de jeu avant de déclarer un combat bloqué (marche de l'étape comprise)
const GAME_LIMIT := {"campaign": 12000.0, "powers": 16000.0, "stress": 5200.0, "ui": 1.0e9}  # secondes de jeu
const WALL_LIMIT := 1440.0  # secondes réelles (le CI coupe à 25 min)
const STROKE_KINDS := ["plain", "loop", "zigzag", "straight", "return", "enso", "hook"]
const POWER_GROUP := 8  # pouvoirs suivis par partie (mode powers) : 71 rouleaux en 9 parties, dans le budget de temps
const MAX_POWER_RUNS := 14
const STRESS_POWERS := ["fire_burn", "fire_trail", "fire_hearth", "water_tide", "water_foam", "bolt_arc", "bolt_storm",
	"wind_blades", "shadow_back", "shadow_veil", "fire_fudo", "shadow_kitsunebi", "bolt_raijin", "water_kanagawa",
	"shadow_bunshin", "ink_enso"]

var main: Node
var mode := "campaign"
var seed_arg := ""
var world := 1
var alerts: Array = []
var cinematics := false  # lu par main : en mode ui, les entrées des boss se jouent en entier
var guard_all := false  # mode ui : héros intouchable (sauf pour l'écran de défaite)
var _t := 0.0
var _room_t := 0.0
var _last_room := -2
var _n := 0
var _total := 0.0
var _wall0 := 0
var _picks := 0
var _death_test := false
var _hits_taken := 0
var _last_hp := -1
var _still := {}  # id ennemi -> [dernière position, temps immobile]
var _stuck_seen := {}
var _done := false
var _ui: Node
# bilan par monde (campagne) : monde -> {rooms, time, hits, guards, heals, max_on}
var _stats := {}
var _world_t0 := 0.0  # temps de jeu au départ du monde en cours (durée du BOT BILAN)
var _guarded := false  # dernier cœur déjà gardé dans cette salle
# mode powers
var _runs := 0
var _order: Array = []  # tous les pouvoirs, dans l'ordre (mélangé) où on les couvre
var _group: Array = []
var _cov := {}  # id -> {niveau: true}
var _cov_boss := {}  # id -> true (actif pendant une salle de gardien ou de boss)
var _cov_done := {}
var _snap := {}  # niveaux au début de la salle
var _kills0 := 0
var _room_ended := true
var _take_shrine := true
var _shape_stats := {}  # forme -> [essais, orientation trouvée, reconnue par le jeu]
var _flees := 0  # traits de fuite réussis (mode powers)
var _trig := {"water_foam": 0, "shadow_utsusemi": 0, "fire_hoo": 0}
var _prev_foam := 0
var _prev_utsu := 0
var _hoo_seen := false
var _force_pending := false
# mode stress
var _nodes := {}  # salle -> [nœuds de l'arbre, orphelins, objets]
var _measure_room := -1
var _measure_t := 0.0
# énigmes des recoins (toutes parties confondues)
var _pz_seen := 0
var _pz_solved := 0
var _seal_seen := 0  # coffres scellés posés / ouverts sur toute la campagne
var _seal_open := 0


func begin(m: Node) -> void:
	main = m
	_wall0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--mode="):
			mode = s.substr(7)
		elif s.begins_with("--seed="):
			seed_arg = s.substr(7)
	if not mode in MODES:
		alert("mode inconnu « %s » : campagne" % mode)
		mode = "campaign"
	print("BOT mode %s, graine %s" % [mode, seed_arg if seed_arg != "" else "aléatoire"])
	# progression : le robot joue avec tous les mondes et tous les paliers de rouleaux ouverts (main._ready)
	if not bool(main.meta.test_unlock_all):
		main.meta.test_unlock_all = true
		alert("progression : test_unlock_all n'était pas posé par main, forcé")
	# hors mode ui : pas de tutoriel en jeu (ni ralenti du premier trait, ni combats adoucis)
	if mode != "ui":
		main.meta.tuto_done = true
		main.coach.clear()
	match mode:
		"ui":
			cinematics = true
			guard_all = true
			_ui = BotUi.new()
			_ui.set("bot", self)
			_ui.set("main", main)
			add_child(_ui)
			_ui.call("run")
		"powers":
			_powers_setup()
			world = 1
			_new_run()
		"stress":
			world = 1 + randi() % Worlds.WORLDS.size()
			_new_run()
		_:
			_new_run()


func alert(msg: String) -> void:
	alerts.append(msg)
	print("BOT ALERTE ", msg)


## Bilan et sortie : toutes les alertes répétées, « BOT DONE », puis on quitte.
func finish() -> void:
	if _done:
		return
	_done = true
	print("BOT alertes : %d, coups reçus : %d" % [alerts.size(), _hits_taken])
	_perf_summary()
	for a in alerts:
		print("BOT ALERTE ", a)
	print("BOT DONE")
	main.get_tree().quit()


## Bilan des temps de chargement (main.perf_mark) : nombre, moyenne et pire cas de chaque étape.
func _perf_summary() -> void:
	var perf: Dictionary = main.perf
	var labels: Array = perf.keys()
	labels.sort()
	print("BOT PERF bilan : %d étapes mesurées (ms : nombre, moyenne, max)" % labels.size())
	for l in labels:
		var e: Array = perf[l]
		var n := int(e[0])
		print("BOT PERF bilan %s : n=%d moy=%.1f max=%.1f" % [String(l), n, float(e[1]) / maxf(1.0, float(n)), float(e[2])])


func _new_run() -> void:
	main.apply_world(world)
	main._start(true)
	main._set_state("play")
	_last_room = -2
	_room_ended = true
	_hoo_seen = false
	_prev_foam = 0
	_prev_utsu = 0
	_last_hp = -1  # la nouvelle partie rend tous les cœurs : ce n'est pas un soin
	_world_t0 = _total
	if mode == "powers":
		_runs += 1
		_group = _next_group()
		print("BOT POUVOIRS partie %d (monde %d) : %s" % [_runs, world, str(_group)])
	print("BOT monde %d : départ au sanctuaire" % world)


## Appelé par main à chaque image, avec un pas de temps fixe.
func step(dt: float) -> void:
	if _done:
		return
	_total += dt
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	if _total > float(GAME_LIMIT.get(mode, 4000.0)) or wall > WALL_LIMIT:
		print("SCRIPT ERROR: bot %s : temps total dépassé (monde %d, salle %d, état %s)" % [mode, world, main.room, String(main.state)])
		_done = true
		main.get_tree().quit()
		return
	if mode == "ui":
		if guard_all and is_instance_valid(main.hero):
			main.hero.guard_t = 99999.0
		return
	if not is_instance_valid(main.hero):
		return
	var h = main.hero
	if _last_hp >= 0 and h.hp < _last_hp:
		_hits_taken += _last_hp - h.hp
		_stat("hits", _last_hp - h.hp)
	elif _last_hp >= 0 and h.hp > _last_hp:
		_stat("heals", h.hp - _last_hp)
	_last_hp = h.hp
	if int(main.room) != _last_room:
		_on_room_change()
		_last_hp = h.hp  # soin du robot à chaque salle : pas compté
	if String(main.state) == "play":
		var alive := 0
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead:
				alive += 1
		_stat_max("max_on", alive)
	# protégé seulement au dernier coup encaissable (sauf dans la partie où il doit mourir, et tant que Hōō
	# attend son coup mortel) : 1 cœur, 2 quand les coups lourds en ôtent 2 (enemy.HEAVY_HIT_WORLD)
	if not _death_test and h.hp <= _last_stand() and _guard_allowed():
		if not _guarded:
			_guarded = true
			_stat("guards", 1)
		h.guard_t = 99999.0
	if mode == "powers":
		_watch_triggers()
	if not _room_ended and bool(main._room_done) and int(main.room) >= 1:
		_room_ended = true
		_on_room_end()
	match String(main.state):
		"pick":
			_pick()
		"over":
			_over()
		"play":
			_play(dt)


## Cœurs à partir desquels le robot se protège : un coup lourd peut en ôter 2 dès le monde 5.
func _last_stand() -> int:
	return 2 if int(main.current_world) >= 5 else 1


func _guard_allowed() -> bool:
	if mode == "powers" and main.powers.lvl("fire_hoo") > 0 and not bool(main.powers._hoo_used):
		return false
	return true


func _on_room_change() -> void:
	# stress : on compte au début de la salle suivante (salle précédente nettoyée, effets retombés)
	if mode == "stress" and _last_room >= 1 and int(main.room) > _last_room:
		_measure_room = _last_room
		_measure()
	if _last_room >= 1 and _room_t > 0.0:
		_stat("rooms", 1)
		_stat("time", _room_t)
	_last_room = int(main.room)
	_room_t = 0.0
	_guarded = false
	_force_pending = false
	_measure_t = 0.0
	main.hero.guard_t = 0.0
	if not _death_test:
		main.hero.hp = main.hero.max_hp  # soigné à chaque salle
	else:
		main.hero.hp = 1
	print("BOT monde %d salle %d (%s)" % [world, main.room, String(main.arena.layout)])
	if main.room < 1:
		return
	_room_ended = false
	_kills0 = _kill_count()
	if mode == "powers":
		_powers_room_start()
	elif mode == "stress":
		_stress_room_start()


func _on_room_end() -> void:
	if mode == "powers":
		_powers_room_end()


func _kill_count() -> int:
	return int(main.kills) + int(main.boss_kills) + int(main.mini_kills)


## Statistiques par monde (campagne seulement, hors partie de la mort).
func _stat(key: String, v) -> void:
	if mode != "campaign" or _death_test:
		return
	var d := _world_stats()
	d[key] = d[key] + v


## Maximum par monde (campagne seulement, hors partie de la mort).
func _stat_max(key: String, v: int) -> void:
	if mode != "campaign" or _death_test:
		return
	var d := _world_stats()
	d[key] = maxi(int(d[key]), v)


func _world_stats() -> Dictionary:
	if not _stats.has(world):
		_stats[world] = {"rooms": 0, "time": 0.0, "hits": 0, "guards": 0, "heals": 0, "max_on": 0}
	return _stats[world]


func _pick() -> void:
	if main._last_offer.is_empty():
		return
	var offer: Array = main._last_offer
	main._last_offer = []
	if String(main._pick_mode) == "flawless":
		# gardien vaincu sans dégât : rouleau d'exception, épiques ou légendaires seulement
		var best := 0
		for oid in offer:
			var pd: Dictionary = PowerData.POWERS.get(String(oid), {})
			var rd: Dictionary = PowerData.RARITIES.get(String(pd.get("rarity", "common")), {})
			best = maxi(best, int(rd.get("rank", 0)))
		print("BOT SANS UNE ÉGRATIGNURE monde %d : %s" % [world, str(offer)])
		if best < 2:
			alert("rouleau sans égratignure sans épique ni légendaire : %s" % str(offer))
	main.picker.visible = false  # le robot choisit sans toucher l'écran : on referme la carte
	main._on_picked(_choose(offer))


func _choose(offer: Array) -> String:
	if mode != "powers":
		# alterne : premier, deuxième, troisième rouleau (et la malédiction proposée)
		var id := String(offer[_picks % offer.size()])
		_picks += 1
		return id
	if "refuse" in offer:
		# sanctuaire : une malédiction au hasard, deux fois sur trois
		if offer.size() > 1 and randf() < 0.67:
			return String(offer[randi() % (offer.size() - 1)])
		return "refuse"
	# les pouvoirs suivis montent selon le programme : on prend autre chose
	for id in offer:
		if not String(id) in _group:
			return String(id)
	var keys: Array = PowerData.POWERS.keys()
	keys.shuffle()
	for k in keys:
		var kid := String(k)
		if not kid in _group and main.powers.lvl(kid) < main.powers.max_level(kid):
			return kid
	return String(offer[0])


func _over() -> void:
	print("BOT monde %d fini : salle %d/%d, %d ennemis, %d boss, niveau %d, pouvoirs %s" % [world, main.room, main.ROOMS, main.kills, main.boss_kills, main.level, str(main.powers.levels.keys())])
	print("BOT ÉNIGMES monde %d : %d résolues sur %d posées" % [world, int(main.puzzles_solved), int(main.puzzles_seen)])
	_pz_seen += int(main.puzzles_seen)
	_pz_solved += int(main.puzzles_solved)
	print("BOT COFFRES SCELLÉS monde %d : %d ouverts sur %d posés" % [world, int(main.chests_unsealed), int(main.chests_sealed)])
	_seal_seen += int(main.chests_sealed)
	_seal_open += int(main.chests_unsealed)
	if mode == "campaign" and _death_test and _seal_seen >= 3 and _seal_open == 0:
		alert("coffres scellés : aucun ouvert sur %d posés pendant la campagne" % _seal_seen)
	if mode == "campaign" and _death_test and _pz_seen >= 4 and _pz_solved == 0:
		alert("énigmes : aucune résolue sur %d posées pendant la campagne" % _pz_seen)
	if _last_room >= 1 and _room_t > 0.0:
		_stat("rooms", 1)
		_stat("time", _room_t)
		_room_t = 0.0
	if mode == "powers":
		if main.room < main.ROOMS:
			alert("partie pouvoirs %d (monde %d) terminée avant la salle %d" % [_runs, world, main.ROOMS])
		_powers_run_end()
		return
	if mode == "stress":
		if main.room < main.ROOMS:
			alert("stress : monde %d terminé avant la salle %d" % [world, main.ROOMS])
		_stress_end()
		finish()
		return
	if main.room < main.ROOMS and not _death_test:
		print("SCRIPT ERROR: bot : monde %d terminé avant la salle %d" % [world, main.ROOMS])
	if _death_test:
		print("BOT mort testée : écran de fin atteint (salle %d)" % main.room)
		_print_stats()
		finish()
		return
	if mode == "campaign":
		var bd := _world_stats()
		print("BOT BILAN monde %d : cœurs perdus %d, soins %d, durée %.0f s, ennemis max à l'écran %d" % [world, int(bd["hits"]), int(bd["heals"]), _total - _world_t0, int(bd["max_on"])])
	world += 1
	if world > Worlds.WORLDS.size():
		# dernière partie : le héros doit mourir (mort, ralenti, résultats)
		_death_test = true
		world = 1
	_new_run()


func _print_stats() -> void:
	for w in range(1, Worlds.WORLDS.size() + 1):
		if not _stats.has(w):
			continue
		var d: Dictionary = _stats[w]
		var rooms := int(d["rooms"])
		var avg := float(d["time"]) / float(maxi(rooms, 1))
		print("BOT STATS monde %d : %d salles, %.1f s de jeu par salle en moyenne, %d coups reçus, dernier cœur gardé %d fois (morts évitées)" % [w, rooms, avg, int(d["hits"]), int(d["guards"])])


func _play(dt: float) -> void:
	_room_t += dt
	_check_stuck(dt)
	if _room_t > float(ROOM_TIMEOUT.get(mode, 70.0)):
		var who: Array = []
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead:
				who.append("%s@%s" % [e.kind, str(e.position.snapped(Vector3(0.1, 0.1, 0.1)))])
		for bo in main.bosses:
			if is_instance_valid(bo) and not bo.dead:
				who.append("boss %s hp %.0f" % [bo.kind, bo.hp])
		alert("monde %d salle %d (%s) bloquée : %s, vagues restantes %d, porte %s" % [world, main.room, String(main.arena.layout), str(who), main._waves_left.size(), str(main.arena.gate_open)])
		# on débloque pour continuer le test
		for e in main.enemies:
			if is_instance_valid(e):
				e.queue_free()
		main.enemies.clear()
		for bo in main.bosses:
			if is_instance_valid(bo):
				bo.queue_free()
		main.bosses.clear()
		main._waves_left.clear()
		_room_t = 0.0
		if main.arena.gate_open:
			main.hero.position = main.arena.gate_goal(main.bot_gate())
		elif bool(main.arena.stage) and int(main._enc) < 0:
			# étape : on pose le héros à l'entrée de la zone suivante
			var g: Vector3 = main.arena.next_goal()
			if g != Vector3.INF:
				main.hero.position = g
	if _death_test and not main.in_hub and (int(main._enc) >= 0 or not bool(main.arena.stage) or not main.enemies.is_empty()):
		return  # il se laisse frapper (hors combat dans une étape : il marche jusqu'à la zone suivante)
	if _measure_t > 0.0:
		# stress : salle nettoyée, on laisse retomber les effets avant de compter
		_measure_t -= dt
		if _measure_t <= 0.0:
			_measure()
		return
	if _force_pending:
		# mode powers, salle nettoyée : coups reçus exprès dès que le héros est posé
		if not main.hero.dashing and _force_hurts():
			_force_pending = false
		return
	if mode == "powers" and not main.in_hub and main.bosses.is_empty() and not bool(main._room_done) and fmod(_room_t, 9.0) < 2.0:
		return  # mode powers : il se laisse approcher (coups reçus : écume, utsusemi, hōō)
	_t -= dt
	if _t > 0.0 or main.hero.dashing or main.touching:
		return
	_t = 0.3
	# boss : il dit lui-même quel trait le blesse maintenant (vide = attendre)
	for bo in main.bosses:
		if is_instance_valid(bo) and not bo.dead and bo.has_method("bot_stroke"):
			var bp: PackedVector3Array = bo.bot_stroke(main.hero.position)
			if bp.size() >= 2:
				_stroke_points(bp)
			return
	var target := Vector3.INF
	if not main.in_hub:
		var best := 1e9
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead and not e.is_harmless():
				var d: float = e.position.distance_to(main.hero.position)
				if d < best:
					best = d
					target = e.position
		for bo in main.bosses:
			if is_instance_valid(bo) and not bo.dead:
				var db: float = bo.position.distance_to(main.hero.position)
				if db < best:
					best = db
					target = bo.position
	var fight := target != Vector3.INF
	if mode == "powers" and fight:
		# fuite : sous une attaque annoncée, ou de temps en temps, un trait court à l'opposé de la cible
		if main.is_danger(main.hero.position, 0.35) or _n % 6 == 5:
			_n += 1
			var away: Vector3 = main.hero.position - target
			if flee(away):
				return
	if not fight:
		# hors combat, au pied d'une énigme : il la résout comme un joueur (un seul trait)
		var pk: Dictionary = main.bot_puzzle()
		if not pk.is_empty():
			solve_puzzle(pk)
			return
	if target == Vector3.INF and is_instance_valid(main._shrine) and (mode != "powers" or _take_shrine):
		target = main._shrine.position  # le robot prend les pactes (pour les tester)
	if target == Vector3.INF:
		# hors combat : recoin à fouiller, entrée de la zone suivante de l'étape, ou torii ouvert
		target = main.bot_goal()
		if target == Vector3.INF:
			return
	target = Vector3(target.x, 0, target.z)
	if mode == "powers" and fight:
		var kind := String(STROKE_KINDS[_n % STROKE_KINDS.size()])
		_n += 1
		if kind == "plain" or not figure(kind, target):
			stroke_line(target)
		return
	_stroke(target)


## Ennemi immobile 8 s loin du héros (hors attaque) : coincé quelque part -> alerte.
func _check_stuck(dt: float) -> void:
	for e in main.enemies:
		# kappa, funa : tireurs à distance ; tsurara : tourelle fixe (immobile par nature)
		if not is_instance_valid(e) or e.dead or e.dummy or e.kind == "kappa" or e.kind == "funa" or e.kind == "tsurara":
			continue
		var id: int = e.get_instance_id()
		var p: Vector3 = e.position
		if not _still.has(id):
			_still[id] = [p, 0.0]
			continue
		var st: Array = _still[id]
		var lp: Vector3 = st[0]
		if lp.distance_to(p) > 0.25 or p.distance_to(main.hero.position) < 3.0:
			_still[id] = [p, 0.0]
			continue
		st[1] = float(st[1]) + dt
		if float(st[1]) > 8.0 and not _stuck_seen.has(id):
			_stuck_seen[id] = true
			alert("monde %d salle %d (%s) : %s coincé en %s (héros en %s)" % [world, main.room, String(main.arena.layout), e.kind, str(p.snapped(Vector3(0.1, 0.1, 0.1))), str(main.hero.position.snapped(Vector3(0.1, 0.1, 0.1)))])


# ------------------------------------------------------------------ traits, figures, fuites (aussi pour bot_ui)

## Trait qui part du héros et passe par les points donnés (ramenés dans l'arène). null si trop court.
func make_stroke(pts: PackedVector3Array) -> Node3D:
	var s := InkStroke.new(main.hero.position, main.stroke_layer)
	main.stroke_layer += 1
	main.add_child(s)
	for p in pts:
		s.extend_to(main._clamp_point(p), 40.0)
	if s.length < 0.7:
		s.queue_free()
		return null
	return s


func _stroke_points(pts: PackedVector3Array) -> void:
	var s := make_stroke(pts)
	if s != null:
		main._launch(s)


## Trait droit vers la cible (un peu au-delà, pour la traverser).
func stroke_line(target: Vector3) -> bool:
	var o: Vector3 = main.hero.position
	var d := Vector3(target.x - o.x, 0, target.z - o.z)
	var dir := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var s := make_stroke(PackedVector3Array([Vector3(target.x, 0, target.z) + dir * 0.8]))
	if s == null:
		return false
	main._launch(s)
	return true


## Figure reconnue (loop, zigzag, straight, return, enso, hook) lancée vers la cible.
## Faux si aucune orientation ne tient dans l'arène.
func figure(kind: String, target: Vector3) -> bool:
	var st: Array = _shape_stats.get(kind, [0, 0, 0])
	_shape_stats[kind] = st
	st[0] = int(st[0]) + 1
	var wps := BotShapes.plan(kind, main.hero.position, target, Callable(main, "_clamp_point"))
	if wps.is_empty():
		return false
	st[1] = int(st[1]) + 1
	var s := make_stroke(wps)
	if s == null:
		return false
	main._launch(s)
	if String(main._shape.get("shape", "")) == kind:
		st[2] = int(st[2]) + 1
	return true


## Fuite comme au doigt : un trait court (2,5 m) dans la direction donnée, loin du danger (il n'y a plus
## d'esquive au tap : la ruée protège son départ). Cherche une direction voisine qui atterrit en sécurité.
func flee(dir: Vector3) -> bool:
	if main.touching or main.game_over or main.hero.dashing:
		return false
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	var hp: Vector3 = main.hero.position
	var best: Vector3 = main._clamp_point(hp + d * 2.5)
	for k in [0.0, 0.7, -0.7, 1.4, -1.4, PI]:
		var dv: Vector3 = d.rotated(Vector3.UP, float(k))
		var p: Vector3 = main._clamp_point(hp + dv * 2.5)
		if not main.hazards.is_hole(p, 0.2) and not main.is_danger(p, 0.2):
			best = p
			break
	var s := make_stroke(PackedVector3Array([best]))
	if s == null:
		return false
	main._launch(s)
	if bool(main.hero.dashing):
		_flees += 1
		return true
	return false


func flees() -> int:
	return _flees


## Énigme d'un recoin (main.spawn_puzzle) résolue d'un trait depuis le héros : la figure de la stèle (ou de la
## plaque d'un coffre scellé),
## les lanternes dans l'ordre, ou une boucle complète autour de l'esprit errant.
func solve_puzzle(pk: Dictionary) -> void:
	var o: Vector3 = main.hero.position
	var c: Vector3 = pk["pos"]
	var pts := PackedVector3Array()
	match String(pk["pz"]):
		"stele", "seal":
			# (coffre scellé : la figure de sa plaque, tracée de même depuis le pied du coffre)
			# vers le sud (déjà parcouru) : la figure n'entre pas dans la zone de combat suivante
			pts = BotShapes.plan(String(pk["shape"]), o, c + Vector3(0, 0, 2.0), Callable(main, "_clamp_point"))
		"lanterns":
			for q in pk["lanterns"]:
				var lq: Vector3 = q
				pts.append(lq)
			if pts.size() >= 2:
				var last := pts[pts.size() - 1]
				var prev := pts[pts.size() - 2]
				pts.append(last + (last - prev).normalized() * 0.4)
		"spirit":
			var sp: Vector3 = main.spirit_pos(pk)
			var a0 := atan2(o.z - sp.z, o.x - sp.x)
			for i in 27:
				var a := a0 + TAU * 1.15 * float(i) / 26.0
				pts.append(sp + Vector3(cos(a), 0, sin(a)) * 1.5)
	if pts.is_empty():
		pts.append(c + Vector3(0, 0, 1.0))
	_stroke_points(pts)


## Trait de la campagne : vers l'ennemi le plus proche (traits droits, zigzags, boucles, ensō).
func _stroke(target: Vector3) -> void:
	var o: Vector3 = main.hero.position
	var d := target - o
	d.y = 0
	var dist := d.length()
	var dir := d / dist if dist > 0.01 else Vector3.FORWARD
	var side := Vector3(-dir.z, 0, dir.x)
	var pts := PackedVector3Array()
	match _n % 5:
		2:
			# zigzag
			for k in [0.25, 0.5, 0.75]:
				pts.append(o + d * k + side * (0.9 if k != 0.5 else -0.9))
		3:
			# boucle autour de la cible
			for i in 11:
				var a := TAU * float(i) / 10.0
				pts.append(target + Vector3(cos(a), 0, sin(a)) * 1.3)
		4:
			# ensō : grand cercle qui revient au départ
			for i in 13:
				var b := TAU * float(i) / 12.0
				pts.append(o + dir * 1.8 + Vector3(cos(b), 0, sin(b)) * 1.8)
	pts.append(target + dir * 0.8)
	_n += 1
	_stroke_points(pts)


# ------------------------------------------------------------------ mode powers

func _powers_setup() -> void:
	var fails: Array = StrokeShapes.self_test()
	if fails.is_empty():
		print("BOT FIGURES auto-test de reconnaissance ok")
	else:
		alert("formes de trait : auto-test en échec %s" % str(fails))
	var sc: Dictionary = BotShapes.self_check(Callable(main, "_clamp_point"))
	for k in sc.keys():
		var r: Array = sc[k]
		print("BOT FIGURES plan %s : reconnue depuis %d/%d positions de départ" % [String(k), int(r[0]), int(r[1])])
		if int(r[0]) == 0:
			alert("figure %s : aucune orientation reconnue par StrokeShapes.detect" % String(k))
	# légendaires scellés : on les libère à l'Atelier, comme un joueur (sceaux offerts)
	var locked: Array = main.meta.locked_powers()
	main.meta.seals = int(main.meta.seals) + 30
	for sid in Meta.SEAL_ORDER:
		var it: Dictionary = Meta.SEAL_ITEMS[sid]
		var pid := String(it.get("power", ""))
		if pid == "":
			continue
		if not main.meta.owns_seal(String(sid)):
			main.meta.buy_seal(String(sid))
		if main.meta.power_unlocked(pid):
			print("BOT POUVOIR %s déverrouillé (%s)" % [pid, "était scellé" if pid in locked else "déjà libre"])
		else:
			alert("pouvoir %s : toujours scellé après l'achat du sceau %s" % [pid, String(sid)])
	_order = PowerData.POWERS.keys()
	_order.shuffle()


func _covered(id: String) -> bool:
	if not _cov_boss.has(id):
		return false
	var c: Dictionary = _cov.get(id, {})
	for l in range(1, int(main.powers.max_level(id)) + 1):
		if not c.has(l):
			return false
	return true


func _uncovered() -> Array:
	var out: Array = []
	for id in _order:
		if not _covered(String(id)):
			out.append(String(id))
	return out


func _next_group() -> Array:
	var g: Array = _uncovered().slice(0, POWER_GROUP)
	# un pouvoir qui en demande un autre (needs : Lame rouge et Braise, améliorations de figure et leur
	# technique, Kasha et la toupie…) vient avec le premier de sa liste
	for id in g.duplicate():
		var d: Dictionary = PowerData.POWERS.get(String(id), {})
		var needs: Array = d.get("needs", [])
		if needs.is_empty():
			continue
		var ok := false
		for n in needs:
			if String(n) in g:
				ok = true
		if not ok:
			g.append(String(needs[0]))
	return g


## Début de salle : les pouvoirs suivis montent d'un niveau par salle (1, 2, puis 3 : un niveau par salle entière).
func _powers_room_start() -> void:
	var r := int(main.room)
	var p = main.powers
	for id in _group:
		var target := mini(r, int(p.max_level(String(id))))
		var guard := 0
		while int(p.lvl(String(id))) < target and guard < 5:
			guard += 1
			p.add(String(id))
	main.elan = main.elan_max()
	# Hōō : à 1 cœur, sans garde, le prochain coup doit le faire renaître
	if p.lvl("fire_hoo") > 0 and not bool(p._hoo_used):
		main.hero.hp = 1
	_snap = p.levels.duplicate()
	_take_shrine = randf() < 0.6


## Fin de salle : chaque pouvoir resté au même niveau toute la salle (avec des ennemis tués) est couvert.
func _powers_room_end() -> void:
	var r := int(main.room)
	var boss_room := r == int(main.MINI_ROOM) or r == int(main.ROOMS)
	if _kill_count() - _kills0 > 0:
		var lv: Dictionary = main.powers.levels
		for k in lv.keys():
			var id := String(k)
			var l := int(lv[k])
			if l <= 0 or int(_snap.get(k, 0)) != l:
				continue
			if not _cov.has(id):
				_cov[id] = {}
			var c: Dictionary = _cov[id]
			c[l] = true
			if boss_room:
				_cov_boss[id] = true
			if not _cov_done.has(id) and _covered(id):
				_cov_done[id] = true
				print("BOT POUVOIR %s ok (niveaux 1 à %d en combat, gardien ou boss compris)" % [id, int(main.powers.max_level(id))])
	if r < int(main.ROOMS):
		_force_pending = true


## Écume, utsusemi et hōō : coups reçus comptés au vol.
func _watch_triggers() -> void:
	var p = main.powers
	var f := int(main.foam)
	if f < _prev_foam:
		_trig["water_foam"] = int(_trig["water_foam"]) + _prev_foam - f
	_prev_foam = f
	var u := int(p._utsu_left)
	if u < _prev_utsu and p.lvl("shadow_utsusemi") > 0:
		_trig["shadow_utsusemi"] = int(_trig["shadow_utsusemi"]) + _prev_utsu - u
	_prev_utsu = u
	if bool(p._hoo_used) and not _hoo_seen:
		_hoo_seen = true
		_trig["fire_hoo"] = int(_trig["fire_hoo"]) + 1
		print("BOT POUVOIR fire_hoo renaissance ok (%d cœurs, salle %d)" % [int(main.hero.hp), int(main.room)])


## Salle nettoyée : si l'écume, le leurre ou le phénix n'ont pas servi, un coup reçu exprès (vrai chemin _hurt_hero).
## Faux tant que le héros n'est pas posé (ruée, bond).
func _force_hurts() -> bool:
	var h = main.hero
	if bool(main.game_over):
		return true
	if String(main.state) != "play" or bool(h.dashing) or float(h._leap_t) >= 0.0:
		return false
	var p = main.powers
	var n := 0
	while n < 6 and (int(main.foam) > 0 or (p.lvl("shadow_utsusemi") > 0 and int(p._utsu_left) > 0)):
		n += 1
		var hp0 := int(h.hp)
		_unguard(h)
		main._hurt_hero()
		if int(h.hp) < hp0:
			alert("coup forcé : ni l'écume ni utsusemi n'ont bu le coup (salle %d)" % int(main.room))
			break
	if p.lvl("fire_hoo") > 0 and not bool(p._hoo_used):
		h.hp = 1
		_unguard(h)
		main._hurt_hero()
		if not bool(p._hoo_used) or bool(main.game_over):
			alert("fire_hoo : pas de renaissance sur un coup mortel (salle %d)" % int(main.room))
	return true


func _unguard(h) -> void:
	h.guard_t = 0.0
	h.invuln = 0.0
	h.spinning = 0.0


func _powers_run_end() -> void:
	var left := _uncovered()
	print("BOT POUVOIRS partie %d finie : %d/%d pouvoirs couverts" % [_runs, _order.size() - left.size(), _order.size()])
	if not left.is_empty() and _runs < MAX_POWER_RUNS:
		world = 1 + (_runs % 5)  # (mondes 1 à 5 : budget de temps du mode inchangé)
		_new_run()
		return
	for id in left:
		var c: Dictionary = _cov.get(id, {})
		alert("pouvoir %s non couvert : niveaux vus %s / %d, gardien ou boss %s" % [id, str(c.keys()), int(main.powers.max_level(String(id))), str(_cov_boss.has(id))])
	for k in BotShapes.SHAPES:
		var st: Array = _shape_stats.get(k, [0, 0, 0])
		print("BOT FIGURES %s : %d reconnues sur %d lancées (%d essais)" % [String(k), int(st[2]), int(st[1]), int(st[0])])
		if int(st[2]) == 0:
			alert("figure %s jamais reconnue en jeu" % String(k))
	print("BOT FUITES : %d" % _flees)
	if _flees == 0:
		alert("aucun trait de fuite réussi")
	for k in _trig.keys():
		print("BOT DÉCLENCHEMENTS %s : %d" % [String(k), int(_trig[k])])
		if int(_trig[k]) == 0:
			alert("pouvoir %s jamais déclenché par un coup reçu" % String(k))
	finish()


# ------------------------------------------------------------------ mode stress

func _stress_room_start() -> void:
	var r := int(main.room)
	if r == 1:
		var p = main.powers
		for id in STRESS_POWERS:
			var guard := 0
			while int(p.lvl(String(id))) < int(p.max_level(String(id))) and guard < 5:
				guard += 1
				p.add(String(id))
		main.elan = main.elan_max()
		print("BOT STRESS %d pouvoirs : %s" % [p.levels.size(), str(p.levels)])
	# vagues doublées : chaque vague restante deux fois, et la première aussi
	var extra: Array = []
	for w in main._waves_left:
		var wa: Array = w
		extra.append(wa.duplicate())
	main._waves_left.append_array(extra)
	if not main._intro_wave.is_empty():
		var iw: Array = main._intro_wave
		main._intro_wave.append_array(iw.duplicate())
	else:
		var kinds: Array = []
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead and not e.dummy:
				kinds.append(String(e.kind))
		if not kinds.is_empty():
			main.spawn_minions(kinds)
	main.waves_total = 1 + main._waves_left.size()


func _measure() -> void:
	var n: int = main.get_tree().get_node_count()
	var orph := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_nodes[_measure_room] = [n, orph, objs]
	print("BOT STRESS salle %d : %d nœuds dans l'arbre, %d orphelins, %d objets, %d pouvoirs" % [_measure_room, n, orph, objs, main.powers.levels.size()])


func _stress_end() -> void:
	var rooms: Array = _nodes.keys()
	rooms.sort()
	var counts: Array = []
	for r in rooms:
		counts.append(int(_nodes[r][0]))
	print("BOT STRESS nœuds par salle : %s" % str(counts))
	if not (_nodes.has(3) and _nodes.has(14)):
		alert("stress : mesures incomplètes (salles mesurées %s)" % str(rooms))
		return
	var a: Array = _nodes[3]
	var b: Array = _nodes[14]
	print("BOT STRESS bilan : salle 3 = %d nœuds, salle 14 = %d (×%.2f) ; orphelins %d -> %d" % [int(a[0]), int(b[0]), float(b[0]) / maxf(1.0, float(a[0])), int(a[1]), int(b[1])])
	if float(b[0]) > 1.5 * float(a[0]):
		alert("fuite probable : %d nœuds en salle 14 contre %d en salle 3" % [int(b[0]), int(a[0])])
	if int(b[1]) - int(a[1]) > 100:
		alert("fuite probable : orphelins %d -> %d entre la salle 3 et la salle 14" % [int(a[1]), int(b[1])])
