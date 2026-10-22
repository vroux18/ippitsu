extends "res://scripts/boss.gd"
## Uwabami, boss du monde 1 : le grand serpent d'eau (corps, bouclier et robot de base hérités de boss.gd,
## qui garde Ō-Kappa inchangé). Il vit sous l'eau et ne se laisse trancher que quand il fait surface.
## Un cycle : crachats de la tête seule (rien à trancher), puis une remontée, puis la fenêtre.
##  - crachat : disque vermillon où jaillit la tête, puis jets d'eau en éventail (couloirs vermillon) ou
##    bombes d'eau en cloche (disques sur le héros et de part et d'autre) ; elle replonge ;
##  - remontée, au choix : traversée (sillage de points, il ondule d'un bout à l'autre de l'arène et s'y
##    pose), ressurgit ailleurs (disque où jaillit la tête, points le long du corps qui remonte), ou dès la
##    phase 2 enroulement (cercle de points autour du héros, le corps s'enroule et l'étreinte écrase le disque
##    intérieur : on en sort d'un trait, la ruée traverse le corps) ;
##  - posé en surface, la fenêtre (un long trait sur tout son corps use SHIELD_FULL de bouclier : il se brise),
##    il attaque aussitôt : balayage de queue (arc vermillon d'un côté du corps) ou jets d'eau ;
##  - brisé, il reste sonné VULN_LEN s, mais l'attaque déjà annoncée tombe quand même ;
##  - phases (paliers de main.boss_gate, 2/3 et 1/3 des PV) : annonces plus courtes (jamais sous 0,75 s), un
##    crachat de plus après chaque palier, deux petits kappa qui sortent de l'eau (à la place des renforts),
##    en phase 3 deux attaques d'affilée et un bouclier plus épais (deux longs traits).
## Toute attaque est annoncée au sol (zones vermillon de vfx) et laisse une sortie : on s'en échappe d'un trait.
## Mesures (robot campagne, graines 101, 202, 303, sauvegarde neuve) : 83-89 s (86 s en moyenne), 0 à 3 cœurs
## perdus (1,7 en moyenne) ; arbre plein : 70-86 s. Avant (boss.gd) : 61 s, 3,7 cœurs (surtout les renforts
## génériques), arbre plein 55 s. Passe d'équilibrage d'ensemble (HP 44 -> 36) : 71-86 s (76 s en moyenne,
## contre 86-99 s), 0 à 4 cœurs ; il reste le plus long des boss des trois premiers mondes.

const WATER := Color("#BFE3F0")  # jets d'eau
const COIL_R := 2.2  # rayon de l'enroulement (le corps couvre ~80 % du cercle)
const CRUSH_R := 1.75  # disque écrasé au centre de l'enroulement
const SWEEP_PIVOT := 6  # segment autour duquel la queue balaie
const SWEEP_HALF := 1.31  # demi-angle de l'arc de queue (75°) : 0° à 150° d'un côté du corps
const SWEEP_R := 5.0
const JET_LEN := 8.5
const JET_HX := 0.32  # demi-largeur d'un couloir de jet
const HIT_M := 0.21  # part du héros prise par un coup (comme main.enemy_strike : RADIUS × 0,6)
const BOT_REACT := 0.55  # robot : temps de réaction à une annonce (il ne la voit pas avant)

# réglages par phase (indice 0 : phase 1)
const TELE_CROSS := [1.3, 1.1, 0.95]
const SPEED := [6.5, 7.5, 8.5]
const TELE_EMERGE := [1.15, 1.0, 0.85]
const TELE_COIL := [1.1, 1.0, 0.85]  # points de l'enroulement avant que le corps ne surgisse
const COIL_SPEED := [8.0, 8.5, 9.5]
const REST := [1.5, 1.3, 1.1]  # posé après ses attaques, avant de replonger
const TELE_SWEEP := [1.05, 0.9, 0.75]
const TELE_JETS := [1.05, 0.9, 0.75]
const JETS_N := [5, 5, 7]
const TELE_BOMBS := [1.15, 1.0, 0.9]
const BOMBS_N := [3, 3, 4]
const BOMB_R := 1.1
const JET_SPREAD := [0.28, 0.28, 0.24]
const ATTACKS := [1, 1, 2]  # attaques posées en surface avant de replonger
const DIVE := [1.3, 1.0, 0.8]
const PEEKS := [2, 2, 3]  # crachats de la tête seule avant chaque remontée

const VULN_LEN := 3.5  # sonné après le bouclier brisé (boss.gd : 6 s)
const HP := 36.0  # 360 affichés, paliers à 240 et 120 (44 avant la passe d'ensemble : 87-99 s au robot ; boss.gd : 40)
const SHIELD_FULL := 12.5  # un trait sur tout le corps (boss.gd : tout le bouclier d'un coup)
const SHIELD_P3 := 20.0  # phase 3 : bouclier plus épais, deux longs traits dans la même remontée

var own_reinforce := true  # lu par main._boss_reinforce : ses kappa remplacent les renforts génériques
# zones annoncées : {node, fill, shape (disc | rect | fan), c, dir, r, hx, hz, half, t, total, age, tag}
var _zones: Array = []
var _beams: Array = []  # jets d'eau qui retombent : {node, t, l}
var _phase_n := 1
var _move := ""
var _moves := 0
var _atk_left := 0
var _atk_i := 0
var _tele_len := 1.0
var _tele_age := 0.0  # depuis l'apparition de l'annonce de mouvement en cours (robot)
var _speed := 6.5
var _line: Array = []  # ressurgit ailleurs : points du corps qui va remonter
var _aim := Vector3.FORWARD  # jets : direction du centre de l'éventail
var _coil_c := Vector3.ZERO
var _sweep_t := -1.0  # balayage en cours (s depuis le coup), -1 sinon
var _sweep_rs := 1.0  # sens de rotation de la queue
var _force_move := ""  # captures : `--q=room=15&uwa=coil` impose ce mouvement (cross, emerge, coil), cette
# attaque posée (sweep, jets) ou les crachats de bombes (bombs)
var _force_atk := ""
var _beam_mat: StandardMaterial3D
var _peek := false  # la tête seule hors de l'eau (crachat entre deux remontées) : rien à trancher
var _peeks_left := 0
var _peek_i := 0
var _balls: Array = []  # bombes d'eau en vol : {node, a, b, t, total}
var _peek_y := -1.6
var _head_yaw := 0.0  # jets : la tête vise le centre de l'éventail


func _ready() -> void:
	super._ready()
	vulnerable_len = VULN_LEN
	hp = HP * max_hp_mult
	max_hp = hp
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		var at := s.find("uwa=")
		if s.begins_with("--q=") and at >= 0:
			var f := s.substr(at + 4).get_slice("&", 0)
			if f in ["cross", "emerge", "coil"]:
				_force_move = f
			elif f == "bombs":
				_force_move = "peek"  # crachats en boucle, bombes d'eau
			elif f in ["sweep", "jets"]:
				_force_atk = f
				_force_move = "emerge"  # (la remontée la plus courte)


## Préchauffage (main._warmup) : la matière des jets d'eau, seule nouveauté (annonces, gerbes et étincelles
## sont celles de vfx et de main).
static func warm(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _beam_mesh()
	mi.material_override = _water_mat()
	parent.add_child(mi)


static func _beam_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	return m


static func _water_mat() -> StandardMaterial3D:
	var m := Toon.flat(Color(WATER, 0.78))
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _ph() -> int:
	return _phase_n - 1


## Durée d'annonce de la phase en cours (captures `uwa=` : trois fois plus longue, le temps de la photographier).
func _tele(table: Array) -> float:
	return float(table[_ph()]) * (3.0 if _force_move != "" else 1.0)


# ------------------------------------------------------------------ boucle

func _uwabami(delta: float) -> void:
	_tick_zones(delta)
	_tick_beams(delta)
	_tick_balls(delta)
	_tele_age += delta
	if not dead:
		_check_phase()
	match _state:
		"dive":
			_depth = move_toward(_depth, -1.6, delta * 2.5)
			_timer -= delta
			# (pendant son entrée en scène, rien ne s'annonce : main le fige dès qu'il quitte cet état)
			if _timer <= 0.0 and _depth <= -1.55 and String(main.state) != "boss_intro":
				_start_move()
		"telegraph":
			# traversée : le sillage d'écume se dessine sur le chemin qu'il va prendre
			_timer -= delta
			_show_marks(1.0 - _timer / _tele_len)
			if _timer <= 0.0:
				_state = "undulate"
				_marks_flash(false)
				_path_i = 0
				_segs_at_path_start()
		"undulate":
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			_advance_head(_speed * delta)
			if _path_i >= _path.size():
				_clear_marks()
				_surface()
		"e_tele":
			# ressurgit ailleurs : la tête jaillit du disque, le corps remonte sous les points
			_timer -= delta
			_show_marks(1.0 - _timer / _tele_len)
			if _timer <= 0.0:
				_clear_marks()
				_depth = -0.9
				_state = "e_rise"
				_timer = 0.45
		"e_rise":
			_depth = move_toward(_depth, 0.0, delta * 3.5)
			_timer -= delta
			if _timer <= 0.0:
				_surface()
		"p_tele":
			# crachat : la tête seule jaillit du disque, puis crache son éventail
			_timer -= delta
			if _timer <= 0.0:
				_peek = true
				if (_peek_i % 2 == 0 or _force_atk == "jets") and _force_move != "peek":
					_plan_jets()
				else:
					_plan_bombs()
				_peek_i += 1
				_atk_left = -2  # (crachat : ni attaque posée ni repos ensuite)
		"c_tele":
			_timer -= delta
			_show_marks(1.0 - _timer / _tele_len)
			if _timer <= 0.0:
				_state = "coil"
				_marks_flash(false)
				_path_i = 0
				_segs_at_path_start()
		"coil":
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			_advance_head(_speed * delta)
			if _path_i >= _path.size():
				_clear_marks()
				_surface()
		"rest":
			# posé en surface : la fenêtre pour le trancher dans sa longueur
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			_timer -= delta
			if _timer <= 0.0:
				_next_attack()
		"sweep_tele", "jets_tele":
			_timer -= delta
			if _state == "jets_tele":
				_aim_head(delta)
			if _timer <= 0.0:
				_state = "sweep" if _state == "sweep_tele" else "jets"
				_timer = 0.55 if _state == "sweep" else 0.4
		"sweep", "jets":
			_timer -= delta
			if _timer <= 0.0:
				_next_attack()
		"stun":
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			var hd: Node3D = _segs[0]
			hd.rotation.z = sin(_t * 10.0) * 0.25
		"dying":
			_clear_zones()
			for bl in _balls:
				if is_instance_valid(bl["node"]):
					(bl["node"] as Node3D).queue_free()
			_balls.clear()
			_timer += delta
			_depth = move_toward(_depth, -2.0, delta * 0.9)
			for s in _segs:
				s.rotation.z = sin(_t * 10.0 + s.position.x) * 0.2
			if _timer > 2.6:
				queue_free()
	if _sweep_t >= 0.0:
		_sweep_t += delta
		if _sweep_t > 0.6:
			_sweep_t = -1.0
	_peek_y = move_toward(_peek_y, 0.0 if _peek else -1.6, delta * 5.0)
	_update_body()


## Crachat : un disque vermillon loin du héros, où la tête va jaillir.
func _start_peek() -> void:
	var h := Vector3(hero.position.x, 0, hero.position.z)
	var best_s := -1e9
	var c := Vector3.ZERO
	for i in 12:
		var q := Vector3(randf_range(-HALF.x + 1.2, HALF.x - 1.2), 0, randf_range(-HALF.y + 1.5, HALF.y - 1.5))
		var d := q.distance_to(h)
		var sc := -absf(d - 4.5) + randf()
		if sc > best_s:
			best_s = sc
			c = q
	# le corps reste sous l'eau, derrière la tête
	var away := (c - h).normalized() if c.distance_to(h) > 0.1 else Vector3(0, 0, 1)
	_trail.clear()
	for i in SEGMENTS * 12 + 2:
		_trail.append(c + away * (float(i) * SPACING / 12.0))
	_move = "peek"
	_tele_age = 0.0
	_tele_len = float(TELE_EMERGE[_ph()])
	_timer = _tele_len
	_state = "p_tele"
	_zone_disc(c, 1.2, _tele_len, "head")


## Palier franchi (main.boss_gate) : phase suivante, deux petits kappa sortent de l'eau.
func _check_phase() -> void:
	var r := hp / maxf(max_hp, 0.001)
	var want := 1 if r > 2.0 / 3.0 + 0.002 else (2 if r > 1.0 / 3.0 + 0.002 else 3)
	if want <= _phase_n:
		return
	_phase_n = want
	if want == 3:
		shield_max = SHIELD_P3  # (il se reforme plein après le palier : boss.gd _shield_refill)
	_peeks_left = int(PEEKS[_ph()]) + 1  # furieux : un crachat de plus avant de remonter
	var hd: Node3D = _segs[0]
	main.splash(Vector3(hd.position.x, 0.3, hd.position.z), BOWL_WATER, 18)
	main.spawn_minions(["kappa", "kappa"])


## Prochain mouvement sous l'eau : traversée et résurgence alternent ; l'enroulement s'y ajoute en phase 2.
func _start_move() -> void:
	var ph := _ph()
	if (_peeks_left > 0 and _force_move == "") or _force_move == "peek":
		_peeks_left -= 1
		_start_peek()
		return
	var order: Array = ["cross", "emerge"] if _phase_n == 1 else ["coil", "cross", "emerge"] if _phase_n == 2 else ["emerge", "coil", "cross"]
	_move = String(order[_moves % order.size()]) if _force_move == "" else _force_move
	_moves += 1
	_tele_age = 0.0
	match _move:
		"cross":
			_plan_crossing()
			_speed = float(SPEED[ph])
			_tele_len = float(TELE_CROSS[ph])
			_state = "telegraph"
		"emerge":
			_plan_emerge()
			_tele_len = float(TELE_EMERGE[ph])
			_state = "e_tele"
			_zone_disc(_line[0], 1.5, _tele_len, "head")
		_:
			_plan_coil()
			_speed = float(COIL_SPEED[ph])
			_tele_len = float(TELE_COIL[ph])
			_state = "c_tele"
			# l'étreinte tombe quand la tête a bouclé le cercle
			var travel := 0.0
			for i in range(1, _path.size()):
				travel += (_path[i] as Vector3).distance_to(_path[i - 1])
			_zone_disc(_coil_c, CRUSH_R, _tele_len + travel / _speed, "crush")
	_timer = _tele_len


## Il fait surface : posé (la fenêtre s'ouvre), il attaque aussitôt, puis reste un instant avant de replonger.
func _surface() -> void:
	_state = "rest"
	_timer = 0.35
	_atk_left = int(ATTACKS[_ph()])


func _next_attack() -> void:
	if _atk_left == 0:
		_atk_left = -1
		_state = "rest"
		_timer = float(REST[_ph()])
		return
	if _peek:
		# crachat fini : la tête replonge, la vraie remontée suit
		_peek = false
		_state = "dive"
		_timer = 0.5
		return
	if _atk_left < 0:
		_state = "dive"
		_timer = float(DIVE[_ph()])
		_peeks_left = int(PEEKS[_ph()])
		return
	_atk_left -= 1
	var a := "sweep" if _atk_i % 2 == 0 else "jets"
	if _force_atk != "":
		a = _force_atk
	_atk_i += 1
	if a == "sweep":
		_plan_sweep()
	else:
		_plan_jets()


func _show_marks(k: float) -> void:
	var n := _marks.get_child_count()
	for i in n:
		var m: Node3D = _marks.get_child(i)
		m.visible = float(i) / float(maxi(n, 1)) <= k * 1.4
		main.vfx.tele_dot_flash(m as MeshInstance3D, _timer < 0.15)


## Points du chemin rendus à leur vermillion (le flash blanc annonçait le départ).
func _marks_flash(on: bool) -> void:
	for m in _marks.get_children():
		main.vfx.tele_dot_flash(m as MeshInstance3D, on)


func _add_mark(p: Vector3) -> void:
	var m: MeshInstance3D = main.vfx.tele_dot(_marks, 0.22)
	m.position = Vector3(p.x, m.position.y, p.z)
	m.visible = false


# ------------------------------------------------------------------ mouvements

## Ressurgit ailleurs : tête loin du héros, près d'un bout de l'arène, corps ondulant vers l'autre bout.
func _plan_emerge() -> void:
	var h := Vector3(hero.position.x, 0, hero.position.z)
	var best_s := -1e9
	var head := Vector3.ZERO
	var sg := 1.0
	for i in 14:
		var s := 1.0 if randf() < 0.5 else -1.0
		var c := Vector3(randf_range(-2.8, 2.8), 0, s * randf_range(HALF.y - 5.0, HALF.y - 1.4))
		var d := c.distance_to(h)
		var sc := minf(d, 6.0) + randf() * 1.5 - (8.0 if d < 3.2 else 0.0)
		if sc > best_s:
			best_s = sc
			head = c
			sg = s
	var amp := randf_range(0.5, 1.3)
	var phs := randf() * TAU
	var step := SPACING / 12.0
	_trail.clear()
	for i in SEGMENTS * 12 + 2:
		var s := float(i) * step
		var x := clampf(head.x + amp * sin(phs + s / (SPACING * SEGMENTS) * PI * 1.3) - amp * sin(phs), -HALF.x + 0.8, HALF.x - 0.8)
		_trail.append(Vector3(x, 0, head.z - sg * s))
	_line.clear()
	_clear_marks()
	for i in range(0, SEGMENTS * 12, 6):
		_line.append(_trail[i])
		if i >= 12:
			_add_mark(_trail[i])


## Enroulement : cercle autour du héros (dans l'arène), un tour complet et un peu plus.
func _plan_coil() -> void:
	var h := hero.position
	_coil_c = Vector3(clampf(h.x, -HALF.x + COIL_R + 0.5, HALF.x - COIL_R - 0.5), 0,
		clampf(h.z, -HALF.y + COIL_R + 0.6, HALF.y - COIL_R - 0.6))
	var a0 := randf() * TAU
	var sd := 1.0 if randf() < 0.5 else -1.0
	_path.clear()
	var steps := 52
	for i in steps + 1:
		var a := a0 + sd * TAU * 1.08 * float(i) / float(steps)
		_path.append(_coil_c + Vector3(cos(a), 0, sin(a)) * COIL_R)
	_clear_marks()
	for i in range(0, steps, 2):
		_add_mark(_path[i])


## Balayage de queue : arc vermillon du côté du héros, autour du segment SWEEP_PIVOT.
func _plan_sweep() -> void:
	var pv: Vector3 = (_segs[SWEEP_PIVOT] as Node3D).position
	var tl: Vector3 = (_segs[SEGMENTS - 1] as Node3D).position
	var back := Vector3(tl.x - pv.x, 0, tl.z - pv.z)
	if back.length_squared() < 0.01:
		back = Vector3(0, 0, 1)
	back = back.normalized()
	var side := Vector3(-back.z, 0, back.x)
	var to_h := Vector3(hero.position.x - pv.x, 0, hero.position.z - pv.z)
	var s := 1.0 if side.dot(to_h) >= 0.0 else -1.0
	_sweep_rs = 1.0 if back.rotated(Vector3.UP, 0.1).dot(side * s) > 0.0 else -1.0
	var dir := back.rotated(Vector3.UP, _sweep_rs * SWEEP_HALF)
	_zone_fan(Vector3(pv.x, 0, pv.z), dir, SWEEP_HALF, SWEEP_R, _tele(TELE_SWEEP), "sweep")
	_state = "sweep_tele"
	_timer = _tele(TELE_SWEEP)


## Jets d'eau : couloirs en éventail depuis la gueule, centrés sur le héros.
func _plan_jets() -> void:
	var hd: Node3D = _segs[0]
	var o := Vector3(hd.position.x, 0, hd.position.z)
	var to := Vector3(hero.position.x - o.x, 0, hero.position.z - o.z)
	_aim = to.normalized() if to.length_squared() > 0.01 else Vector3(0, 0, 1)
	_head_yaw = hd.rotation.y
	var n := int(JETS_N[_ph()])
	var t := _tele(TELE_JETS)
	for i in n:
		var d := _aim.rotated(Vector3.UP, (float(i) - 0.5 * float(n - 1)) * float(JET_SPREAD[_ph()]))
		_zone_rect(o + d * (0.6 + JET_LEN * 0.5), d, JET_HX, JET_LEN * 0.5, t, "jet")
	_state = "jets_tele"
	_timer = t
	main.sfx.play("ink", 0.6, -6.0)


## Bombes d'eau : la tête crache en cloche des boules d'eau qui tombent sur des disques vermillon (le héros,
## et de part et d'autre de lui).
func _plan_bombs() -> void:
	var hd: Node3D = _segs[0]
	var o := Vector3(hd.position.x, 0, hd.position.z)
	var h := Vector3(hero.position.x, 0, hero.position.z)
	var to := h - o
	_aim = to.normalized() if to.length_squared() > 0.01 else Vector3(0, 0, 1)
	_head_yaw = hd.rotation.y
	var side := Vector3(-_aim.z, 0, _aim.x)
	var t := _tele(TELE_BOMBS)
	var spots: Array = [h, h + side * 2.3, h - side * 2.3, h + _aim * 2.3]
	for i in int(BOMBS_N[_ph()]):
		var c: Vector3 = spots[i]
		c = Vector3(clampf(c.x, -HALF.x + 0.6, HALF.x - 0.6), 0, clampf(c.z, -HALF.y + 0.6, HALF.y - 0.6))
		_zone_disc(c, BOMB_R, t + 0.12 * float(i), "bomb")
		_ball(o + Vector3(0, 1.0, 0), c, t + 0.12 * float(i))
	_state = "jets_tele"
	_timer = t + 0.12 * float(int(BOMBS_N[_ph()]) - 1)
	main.sfx.play("ink", 0.5, -6.0)


func _ball(a: Vector3, b: Vector3, total: float) -> void:
	if _beam_mat == null:
		_beam_mat = _water_mat()
	var mi := MeshInstance3D.new()
	mi.mesh = Toon.sphere(0.32)
	mi.material_override = _beam_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	mi.global_position = a
	_balls.append({"node": mi, "a": a, "b": b, "t": 0.0, "total": total})


func _tick_balls(delta: float) -> void:
	for i in range(_balls.size() - 1, -1, -1):
		var bl: Dictionary = _balls[i]
		bl["t"] = float(bl["t"]) + delta
		var mi: MeshInstance3D = bl["node"]
		var k := float(bl["t"]) / float(bl["total"])
		if k >= 1.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_balls.remove_at(i)
			continue
		var a: Vector3 = bl["a"]
		var b: Vector3 = bl["b"]
		mi.global_position = a.lerp(b, k) + Vector3(0, 4.5 * k * (1.0 - k) - k * 0.9, 0)


func _aim_head(delta: float) -> void:
	_head_yaw = lerp_angle(_head_yaw, atan2(-_aim.x, -_aim.z), minf(1.0, delta * 8.0))


# ------------------------------------------------------------------ zones annoncées

func _zone_node(c: Vector3, dir: Vector3) -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = Vector3(c.x, 0, c.z)
	if dir.length_squared() > 0.0001:
		n.rotation.y = atan2(dir.x, dir.z)
	return n


func _new_zone(n: Node3D, fill: Node3D, shape: String, c: Vector3, dir: Vector3, t: float, tag: String) -> Dictionary:
	var z := {"node": n, "fill": fill, "shape": shape, "c": Vector3(c.x, 0, c.z), "dir": dir, "r": 0.0,
		"hx": 0.0, "hz": 0.0, "half": 0.0, "t": t, "total": maxf(t, 0.01), "age": 0.0, "tag": tag}
	_zones.append(z)
	return z


func _zone_disc(c: Vector3, r: float, t: float, tag: String) -> void:
	var n := _zone_node(c, Vector3.ZERO)
	var z := _new_zone(n, main.vfx.tele_disc(n, r), "disc", c, Vector3(0, 0, 1), t, tag)
	z["r"] = r


func _zone_rect(c: Vector3, dir: Vector3, hx: float, hz: float, t: float, tag: String) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var n := _zone_node(c, d)
	var z := _new_zone(n, main.vfx.tele_rect(n, hx, hz, Vector2(0, -1)), "rect", c, d, t, tag)
	z["hx"] = hx
	z["hz"] = hz


func _zone_fan(o: Vector3, dir: Vector3, half: float, length: float, t: float, tag: String) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var n := _zone_node(o, d)
	var z := _new_zone(n, main.vfx.tele_fan(n, half, length), "fan", o, d, t, tag)
	z["r"] = length
	z["half"] = half


func _in_zone(z: Dictionary, p: Vector3, m: float) -> bool:
	var c: Vector3 = z["c"]
	var v := Vector3(p.x - c.x, 0, p.z - c.z)
	var shape := String(z["shape"])
	if shape == "disc":
		return v.length() < float(z["r"]) + m
	var d: Vector3 = z["dir"]
	if shape == "rect":
		var side := Vector3(-d.z, 0, d.x)
		return absf(v.dot(d)) < float(z["hz"]) + m and absf(v.dot(side)) < float(z["hx"]) + m
	var l := v.length()
	if l > float(z["r"]) + m:
		return false
	if l < m + 0.4:
		return true
	return acos(clampf(v.dot(d) / l, -1.0, 1.0)) < float(z["half"]) + m / l


func _tick_zones(delta: float) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		var z: Dictionary = _zones[i]
		z["t"] = float(z["t"]) - delta
		z["age"] = float(z["age"]) + delta
		main.vfx.tele_update(z["fill"], 1.0 - float(z["t"]) / float(z["total"]), float(z["t"]))
		if float(z["t"]) <= 0.0:
			_zones.remove_at(i)
			_zone_fire(z)
			if is_instance_valid(z["node"]):
				(z["node"] as Node3D).queue_free()


func _clear_zones() -> void:
	for z in _zones:
		if is_instance_valid(z["node"]):
			(z["node"] as Node3D).queue_free()
	_zones.clear()


## Le coup tombe : le héros dans la zone perd un cœur (la ruée reste intouchable, main._hurt_hero).
func _zone_fire(z: Dictionary) -> void:
	var c: Vector3 = z["c"]
	var hit := _in_zone(z, hero.position, HIT_M)
	match String(z["tag"]):
		"head":
			main.enemy_strike(c, float(z["r"]))
			main.splash(c + Vector3(0, 0.4, 0), BOWL_WATER, 22)
			main.vfx.sparks(c + Vector3(0, 0.3, 0), Vector3.UP, 12, SHIELD_C, 6.0, 11.0, 30.0)
		"crush":
			# l'étreinte : le corps se resserre sur le disque
			main.enemy_strike(c, float(z["r"]))
			main.splash(c + Vector3(0, 0.4, 0), BOWL_WATER, 20)
			main.shake = maxf(float(main.shake), 0.35)
		"sweep":
			_sweep_t = 0.0
			var d: Vector3 = z["dir"]
			for k in 5:
				var a := (float(k) / 4.0 - 0.5) * 2.0 * float(z["half"])
				var p := c + d.rotated(Vector3.UP, a) * (SWEEP_R - 1.0)
				main.splash(p + Vector3(0, 0.3, 0), BOWL_WATER, 6)
			main.sfx.play("strike", 0.75, -3.0)
			main.shake = maxf(float(main.shake), 0.25)
			if hit:
				main._hurt_hero()
		"bomb":
			main.enemy_strike(c, float(z["r"]))
			main.splash(c + Vector3(0, 0.3, 0), BOWL_WATER, 14)
			main.vfx.sparks(c + Vector3(0, 0.2, 0), Vector3.UP, 6, SHIELD_C, 4.0, 8.0, 50.0)
		"jet":
			_beam(c, z["dir"], float(z["hz"]) * 2.0)
			if hit:
				main._hurt_hero()


## Jet d'eau visible un instant le long d'un couloir (centre c, direction d, longueur l).
func _beam(c: Vector3, d: Vector3, l: float) -> void:
	if _beam_mat == null:
		_beam_mat = _water_mat()
	var mi := MeshInstance3D.new()
	mi.mesh = _beam_mesh()
	mi.material_override = _beam_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	mi.global_position = Vector3(c.x, 0.55, c.z)
	mi.rotation.y = atan2(d.x, d.z)
	mi.scale = Vector3(0.42, 0.3, l)
	_beams.append({"node": mi, "t": 0.0, "l": l})
	var o := c - d * (l * 0.5)
	main.vfx.sparks(o + Vector3(0, 0.7, 0), d, 8, SHIELD_C, 12.0, 20.0, 6.0)
	main.splash(c + d * (l * 0.5) + Vector3(0, 0.3, 0), BOWL_WATER, 5)
	if _beams.size() == 1:
		main.sfx.play("shot", 0.7, -3.0)


func _tick_beams(delta: float) -> void:
	for i in range(_beams.size() - 1, -1, -1):
		var b: Dictionary = _beams[i]
		b["t"] = float(b["t"]) + delta
		var mi: MeshInstance3D = b["node"]
		var k := float(b["t"]) / 0.35
		if k >= 1.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_beams.remove_at(i)
			continue
		mi.scale = Vector3(0.42 * (1.0 - k), 0.3 * (1.0 - k * 0.5), float(b["l"]))


# ------------------------------------------------------------------ corps

func _update_body() -> void:
	super._update_body()
	if _sweep_t >= 0.0:
		# la queue fouette l'arc annoncé, puis revient
		var peak := 2.0 * SWEEP_HALF * _sweep_rs
		var k := minf(_sweep_t / 0.16, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		k *= 1.0 - smoothstep(0.25, 0.6, _sweep_t)
		var pv: Vector3 = (_segs[SWEEP_PIVOT] as Node3D).position
		for i in range(SWEEP_PIVOT + 1, SEGMENTS):
			var s: Node3D = _segs[i]
			var off := s.position - pv
			var w := minf(1.0, float(i - SWEEP_PIVOT) / 2.0)
			s.position = pv + off.rotated(Vector3.UP, peak * k * w)
			s.rotation.y += peak * k * w
	if _peek_y > -1.5 and _depth < -1.0:
		var hp0: Node3D = _segs[0]
		hp0.visible = true
		hp0.position.y = _peek_y - 0.25
	if _state == "jets_tele" or _state == "jets":
		var hd: Node3D = _segs[0]
		hd.position.y += 0.35
		hd.rotation.y = _head_yaw
	elif _state == "sweep_tele":
		# la queue se dresse avant de fouetter
		var k2 := 1.0 - _timer / maxf(_tele(TELE_SWEEP), 0.01)
		for i in range(SWEEP_PIVOT + 2, SEGMENTS):
			var s2: Node3D = _segs[i]
			s2.position.y += 0.35 * k2 * float(i - SWEEP_PIVOT - 1) / float(SEGMENTS - SWEEP_PIVOT - 1)


## Fin du trait : comme boss.gd, mais tout le corps d'un trait n'ôte que SHIELD_FULL (en phase 3 il en faut deux).
func end_stroke(_stroke_id: int) -> void:
	if not dead and vulnerable_t <= 0.0:
		_mark_segs(main._prev_hero, hero.position)  # (dernière image de la ruée)
	var hit_set: Dictionary = _hits
	_hits = {}
	if dead or hit_set.is_empty() or vulnerable_t > 0.0:
		return
	var best := 0
	var run := 0
	for i in SEGMENTS:
		if hit_set.has(i):
			run += 1
			best = maxi(best, run)
		else:
			run = 0
	if best == 0:
		return
	var at: Vector3 = (_segs[0] as Node3D).position
	if best < 4:
		main.clang(at)
		_damage(float(best) * CHIP_HP)
		_shield_dmg(float(best) * CHIP_SH)
		return
	var sd: float = SHIELD_FULL if best >= SEGMENTS else float(best) * (1.25 if best >= 8 else 1.0)
	main.float_text(at + Vector3(0, 0.6, 0), "%d / %d" % [best, SEGMENTS], SHIELD_C)
	main.big_hit(at)
	_damage(float(best) * CHIP_HP)
	_shield_dmg(sd)


## En plongée, il se dérobe : rien n'entame plus son bouclier.
func _shield_dmg(v: float) -> void:
	if _state == "dive":
		return
	super._shield_dmg(v)


## Brisé : il reste sonné en surface ; l'attaque déjà annoncée tombe quand même (on l'a vue venir).
func _shield_break() -> void:
	_peek = false
	_peeks_left = int(PEEKS[_ph()])  # au réveil, un crachat avant de remonter
	super._shield_break()


# ------------------------------------------------------------------ interface avec main

func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	for z in _zones:
		if float(z["t"]) < lim and _in_zone(z, p, DANGER_MARGIN):
			return true
	var reach := SEG_R + 0.35 + DANGER_MARGIN
	if _state == "e_tele" or _state == "e_rise":
		if _state == "e_rise" or _timer < lim:
			for q in _line:
				var lq: Vector3 = q
				if Vector2(p.x - lq.x, p.z - lq.z).length() < reach:
					return true
		return false
	if not _state in ["telegraph", "undulate", "c_tele", "coil"]:
		return false
	# traversée ou enroulement : la tête suit _path, le corps passe ensuite pendant body_t
	var body_t := float(SEGMENTS) * SPACING / _speed
	var acc := 0.0
	var i0 := 0
	var prev := Vector3.ZERO
	if _state == "telegraph" or _state == "c_tele":
		if _path.is_empty():
			return false
		acc = maxf(_timer, 0.0)
		prev = _path[0]
	else:
		if eta < body_t + DANGER_MARGIN:
			for s in _segs:
				var sp: Vector3 = s.position
				if Vector2(p.x - sp.x, p.z - sp.z).length() < reach:
					return true
		i0 = _path_i
		prev = _trail[0]
	for i in range(i0, _path.size()):
		var q: Vector3 = _path[i]
		acc += prev.distance_to(q) / _speed
		prev = q
		if acc > lim:
			break
		if acc + body_t > eta - DANGER_MARGIN and Vector2(p.x - q.x, p.z - q.z).length() < reach:
			return true
	return false


func touching_hero(p: Vector3) -> bool:
	if dead or _depth < -0.3:
		return false
	if not _state in ["undulate", "coil", "e_rise"]:
		return false
	for s in _segs:
		var q: Vector3 = s.position
		if Vector2(p.x - q.x, p.z - q.z).length() < SEG_R + 0.35:
			return true
	return false


# ------------------------------------------------------------------ robot testeur

## Comme un joueur : il voit les annonces (après BOT_REACT s) et s'en sort d'un trait ; posé en surface, il
## trace un long trait sur tout le corps ; sonné, des iaï à travers le corps.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if _bot_threat(h):
		var safe := _bot_safe(h)
		if safe != Vector3.INF:
			return _bot_dense([h, safe])
		return none
	if vulnerable_t > 0.0:
		return super.bot_stroke(hero_pos)
	if _depth < -0.3 or not _state in ["rest", "sweep_tele", "jets_tele", "sweep", "jets"]:
		return _bot_minion(h)
	var pts: Array = []
	for s in _segs:
		var sn: Node3D = s
		pts.append(Vector3(sn.position.x, 0, sn.position.z))
	var head: Vector3 = pts[0]
	var tail: Vector3 = pts[SEGMENTS - 1]
	if h.distance_to(tail) < h.distance_to(head):
		pts.reverse()
	var first: Vector3 = pts[0]
	var second: Vector3 = pts[1]
	if h.distance_to(first) > 3.0:
		var lead := _bot_clamp(first + (first - second).normalized() * 1.0)
		if danger_at(lead, 0.6):
			return none
		return _bot_route([h, lead], pts, SEG_R + 0.75)
	var last: Vector3 = pts[SEGMENTS - 1]
	var prev: Vector3 = pts[SEGMENTS - 2]
	var end := _bot_clamp(last + (last - prev).normalized() * 1.2)
	if danger_at(end, 0.6):
		return none  # il atterrirait dans l'attaque annoncée : il attend qu'elle tombe
	var way: Array = [h]
	way.append_array(pts)
	way.append(end)
	return _bot_dense(way)


## Rien à trancher sur le serpent (sous l'eau, annonce en cours) : un trait à travers le kappa le plus proche,
## s'il atterrit hors de toute attaque annoncée.
func _bot_minion(h: Vector3) -> PackedVector3Array:
	var best: Node3D = null
	var bd := 3.5
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and not e.is_harmless():
			var d := Vector2(e.position.x - h.x, e.position.z - h.z).length()
			if d < bd:
				bd = d
				best = e
	if best == null:
		return PackedVector3Array()
	var line := _bot_line(h, Vector3(best.position.x, 0, best.position.z), 4.0)
	if line.size() < 2 or danger_at(line[line.size() - 1], 0.5):
		return PackedVector3Array()
	return line


## Le héros est-il dans une annonce visible depuis assez longtemps pour qu'un joueur l'ait vue ?
func _bot_threat(h: Vector3) -> bool:
	for z in _zones:
		if float(z["age"]) >= BOT_REACT and float(z["t"]) < 1.8 and _in_zone(z, h, 0.3):
			return true
	if _tele_age >= BOT_REACT and _state in ["telegraph", "undulate", "c_tele", "coil", "e_tele", "e_rise"]:
		if danger_at(h, 0.45):
			return true
	return false


## Point sûr à portée d'un trait, le plus près possible du corps (pour la fenêtre qui suit).
func _bot_safe(h: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_s := 1e9
	var mid: Vector3 = (_segs[SWEEP_PIVOT] as Node3D).position
	for r in [2.6, 4.0, 5.5]:
		for k in 16:
			var a := TAU * float(k) / 16.0
			var p := _bot_clamp(h + Vector3(cos(a), 0, sin(a)) * float(r))
			if p.distance_to(h) < 1.5:
				continue
			var eta := p.distance_to(h) / 28.0 + 0.1
			if danger_at(p, eta + 1.0) or main.is_danger(p, eta) or main.hazards.is_hole(p, 0.2):
				continue
			var sc := float(r) * 0.4 + Vector2(p.x - mid.x, p.z - mid.z).length() * 0.25
			if sc < best_s:
				best_s = sc
				best = p
	return best

