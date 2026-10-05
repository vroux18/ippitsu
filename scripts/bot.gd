extends Node
## Robot testeur (CI, `-- --bot`) : joue les 5 mondes d'affilée, sanctuaire compris. Le héros prend de vrais coups
## (soigné à chaque salle, protégé seulement à 1 cœur), puis une dernière partie où il doit mourir.
## Il trace vers l'ennemi le plus proche (traits droits, zigzags, boucles, ensō), prend les rouleaux et
## les malédictions, et signale les salles où il reste bloqué. Fin : « BOT DONE » puis il quitte.

const InkStroke = preload("res://scripts/ink_stroke.gd")
const ROOM_TIMEOUT := 70.0  # secondes de jeu avant de déclarer une salle bloquée
const TOTAL_LIMIT := 4000.0

var main: Node
var world := 1
var alerts: Array = []
var _t := 0.0
var _room_t := 0.0
var _last_room := -2
var _n := 0
var _total := 0.0
var _picks := 0
var _death_test := false
var _hits_taken := 0
var _last_hp := -1


func begin(m: Node) -> void:
	main = m
	_new_run()


func _new_run() -> void:
	main.apply_world(world)
	main._start(true)
	main._set_state("play")
	_last_room = -2
	print("BOT monde %d : départ au sanctuaire" % world)


## Appelé par main à chaque image, avec un pas de temps fixe.
func step(dt: float) -> void:
	_total += dt
	if _total > TOTAL_LIMIT:
		print("SCRIPT ERROR: bot : temps total dépassé (monde %d, salle %d)" % [world, main.room])
		main.get_tree().quit()
		return
	if is_instance_valid(main.hero):
		var h = main.hero
		if _last_hp >= 0 and h.hp < _last_hp:
			_hits_taken += _last_hp - h.hp
		_last_hp = h.hp
		# protégé seulement au dernier cœur (sauf dans la partie où il doit mourir)
		if not _death_test and h.hp <= 1:
			h.guard_t = 99999.0
	match String(main.state):
		"pick":
			if not main._last_offer.is_empty():
				var offer: Array = main._last_offer
				main._last_offer = []
				# alterne : premier, deuxième, troisième rouleau (et la malédiction proposée)
				var id := String(offer[_picks % offer.size()])
				_picks += 1
				main._on_picked(id)
		"over":
			print("BOT monde %d fini : salle %d/%d, %d ennemis, %d boss, niveau %d, pouvoirs %s" % [world, main.room, main.ROOMS, main.kills, main.boss_kills, main.level, str(main.powers.levels.keys())])
			if main.room < main.ROOMS and not _death_test:
				print("SCRIPT ERROR: bot : monde %d terminé avant la salle %d" % [world, main.ROOMS])
			if _death_test:
				print("BOT mort testée : écran de fin atteint (salle %d)" % main.room)
				print("BOT alertes : %d, coups reçus : %d" % [alerts.size(), _hits_taken])
				for a in alerts:
					print("BOT ALERTE ", a)
				print("BOT DONE")
				main.get_tree().quit()
				return
			world += 1
			if world > 5:
				# dernière partie : le héros doit mourir (mort, ralenti, résultats)
				_death_test = true
				world = 1
				_new_run()
				return
			_new_run()
		"play":
			_play(dt)


func _play(dt: float) -> void:
	if main.room != _last_room:
		_last_room = main.room
		_room_t = 0.0
		main.hero.guard_t = 0.0
		if not _death_test:
			main.hero.hp = main.hero.max_hp  # soigné à chaque salle
		else:
			main.hero.hp = 1
		print("BOT monde %d salle %d (%s)" % [world, main.room, String(main.arena.layout)])
	_room_t += dt
	if _room_t > ROOM_TIMEOUT:
		var who: Array = []
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead:
				who.append("%s@%s" % [e.kind, str(e.position.snapped(Vector3(0.1, 0.1, 0.1)))])
		for bo in main.bosses:
			if is_instance_valid(bo) and not bo.dead:
				who.append("boss %s hp %.0f" % [bo.kind, bo.hp])
		var msg := "monde %d salle %d (%s) bloquée : %s, vagues restantes %d, porte %s" % [world, main.room, String(main.arena.layout), str(who), main._waves_left.size(), str(main.arena.gate_open)]
		alerts.append(msg)
		print("BOT ALERTE ", msg)
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
			main.hero.position = main.arena.gate_pos
	if _death_test and not main.in_hub:
		return  # il se laisse frapper
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
	if target == Vector3.INF:
		if main.arena.gate_open:
			target = main.arena.gate_pos
		else:
			return
	_stroke(Vector3(target.x, 0, target.z))


func _stroke_points(pts: PackedVector3Array) -> void:
	var s := InkStroke.new(main.hero.position, main.stroke_layer)
	main.stroke_layer += 1
	main.add_child(s)
	for p in pts:
		s.extend_to(main._clamp_point(p), 40.0)
	if s.length < 0.7:
		s.queue_free()
		return
	main._launch(s)


func _stroke(target: Vector3) -> void:
	var o: Vector3 = main.hero.position
	var d := target - o
	d.y = 0
	var dist := d.length()
	var dir := d / dist if dist > 0.01 else Vector3.FORWARD
	var side := Vector3(-dir.z, 0, dir.x)
	var s := InkStroke.new(o, main.stroke_layer)
	main.stroke_layer += 1
	main.add_child(s)
	var pts: Array = []
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
				pts.append(o + dir * 1.8 + (Vector3(cos(b), 0, sin(b)) - Vector3.ZERO) * 1.8 - dir * 0.0)
	pts.append(target + dir * 0.8)
	for p in pts:
		s.extend_to(main._clamp_point(p), 40.0)
	_n += 1
	if s.length < 0.7:
		s.queue_free()
		return
	main._launch(s)
