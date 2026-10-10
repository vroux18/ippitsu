extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 8 (Yomi) — Gaki-ō, le roi des affamés (22 PV × monde).
##  Trois chaînes le lient à des pieux de fer : tant qu'elles tiennent, l'enfer le protège (bouclier 10)
##  et un coup ne fait qu'effleurer. Mécanique de trait : TRANCHER LES CHAÎNES EN TRAVERS (un trait qui
##  croise une chaîne la rompt). Les trois rompues en moins de 8 s : il s'effondre 5.5 s, vulnérable
##  (dégâts ×2). Sinon les chaînes se ressoudent. Prépare les fils d'Izanami.
##  Attaques : ruée vorace en ligne (bande annoncée 1.0 s, 9 m/s) ; hurlement de faim (disque r2.4,
##  1.2 s) ; os crachés en éventail (lueur 0.8 s).

##  Apparence (direction « Masque d'encre ») : le gaki commun (yokai_ink_w8.gd) en GÉANT, modelé en primitives
##  fusionnées (Yokai.Mesher, couleurs de sommets) : corps d'encre fluet au VENTRE ÉNORME de cendre, côtes d'os,
##  masque gris décharné cerné d'or (orbites creuses à lueur verte, bouche béante aux dents d'os), COURONNE D'OR
##  à pointes, collier d'or où s'accrochent les chaînes, bras maigres aux bracelets d'or, grand os rongé en main
##  droite, gouttes d'encre qui s'étirent sous lui. Pieux et chaînes de fer (mécanique) inchangés.

const Yokai = preload("res://scripts/yokai_parts.gd")
const Loop = preload("res://scripts/boss_loop.gd")
const BONE := Color("#D8D2C4")
const IRON := Color("#3A3C42")
const HUNGER := Color("#9AE070")
const INK_GAKI := Color("#2A2428")
const CLOTH := Color("#5A3A7A")  # violet des haies (étoffe du monde 8)
const WAVE := Color("#B9A8E8")  # lilas des âmes
const BELLY := Color("#8A8290")  # cendre du ventre
const MASK_GAKI := Color("#CFC9C4")
const U := 1.9  # échelle du modelé (H_REF 1,75 m -> ~3,3 m, deux fois le gaki commun)
const REST_R := Vector3(1.1, 0, 0.3)  # bras au repos (comme ink_rig.REST_ARMS["gaki"])
const REST_L := Vector3(1.0, 0, -0.35)
const SHIELD := 10.0
const CHAIN_CHIP := 1.2  # éclat de bouclier par chaîne rompue
const RESOLDER := 8.0  # délai pour rompre les trois chaînes
const LUNGE_TELE := 1.0
const LUNGE_SPEED := 9.0
const LUNGE_W := 0.9
const HOWL_R := 2.4
const HOWL_TELE := 1.2
const SPIT_TELE := 0.8
const STAKES := [Vector3(-3.4, 0, -6.6), Vector3(3.4, 0, -6.6), Vector3(0.0, 0, 1.4)]
const HOME := Vector3(0, 0, -3.6)

static var _ink_mat: StandardMaterial3D = null

var _belly: MeshInstance3D
var _head: Node3D
var _maw: MeshInstance3D  # lueur verte de la faim au fond de la gueule (remplace la lueur du personnage)
var _arms: Array = []  # [droit, gauche] (pivots d'épaule)
var _drips: Array = []
var _glow := 0.0
var _lean := 0.0  # penché en avant (ruée), en arrière (charge, hurlement)
var _chains: Array = []  # {stake (Vector3), node (Node3D, maillons), mesh, cut}
var _cut_t := 0.0  # temps restant avant que les chaînes rompues se ressoudent
var _cycle := 0
var _lunge_end := Vector3.ZERO
var _lunge_dir := Vector3(0, 0, 1)


func _ready() -> void:
	title = "Gaki-ō"
	hp = 22.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	_build()
	_shield_init(SHIELD, Vector3(1.5, 1.9, 1.5), 1.4)
	_state = "spawn"
	_timer = 1.3


# ------------------------------------------------------------------ construction

## Toon à contour épais (géant) aux couleurs de sommets : un seul matériau pour l'encre, la cendre, l'os et l'or.
static func ink_mat() -> StandardMaterial3D:
	if _ink_mat == null:
		_ink_mat = Toon.mat(Color.WHITE, true, 0.04)
		_ink_mat.vertex_color_use_as_albedo = true
		_ink_mat.vertex_color_is_srgb = true
	return _ink_mat


## Pièce fusionnée posée sur `parent` : surface toon, et aplat lumineux si `f` n'est pas vide.
static func piece(parent: Node3D, a: Yokai.Mesher, f: Yokai.Mesher = null) -> MeshInstance3D:
	var m: ArrayMesh = a.mesh() if f == null else Yokai.two(a, f)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.set_surface_override_material(0, Yokai.ink_flat_mat() if a.arrays().is_empty() else ink_mat())
	if m.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	parent.add_child(mi)
	return mi


func _build() -> void:
	var lite := Toon.lite
	Toon.disc(self, 1.1, Color(0, 0, 0, 0.18))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # il surgit déjà tourné vers le héros (le modèle regarde vers -Z)
	# corps : encre fluette (w 0,9), obi violet à seigaiha lilas liseré d'or, côtes d'os saillantes
	var w := 0.9
	var b := Yokai.Mesher.new(U)
	Yokai.ink_body(b, w, INK_GAKI, CLOTH, WAVE, Toon.GOLD, lite, true)
	var n := 2 if lite else 4
	for i in n:
		var y := 1.02 - 0.065 * float(i)
		for s in [-1.0, 1.0]:
			var x := float(s)
			b.box(Vector3(x * 0.15, y, -0.34 + 0.02 * float(i)), Vector3(0.22, 0.024, 0.02), BONE, Vector3(0, -x * 0.5, x * 0.3))
	# collier d'or (kubiwa) où les chaînes s'accrochent (y = 2,0 m : ancre des chaînes), bord sumi
	b.cyl(Vector3(0, 2.0 / U, 0), Vector3(0.5, 0.05, 0.47), Toon.GOLD, Vector3.ZERO, 1.0, 14)
	b.cyl(Vector3(0, 2.0 / U, 0), Vector3(0.52, 0.02, 0.49), Toon.SUMI, Vector3.ZERO, 1.0, 14)
	for k in 3:
		var ang := PI * 0.5 + TAU * float(k) / 3.0
		b.ball(Vector3(cos(ang) * 0.48, 2.0 / U, sin(ang) * 0.45), Vector3.ONE * 0.05, IRON, Vector3.ZERO, 6)
	piece(body, b)
	# ventre : énorme boule de cendre qui déborde sous l'obi (pièce à part : il gonfle avant le hurlement),
	# nombril sumi, cerne d'or
	var bm := Yokai.Mesher.new(U)
	bm.ball(Vector3.ZERO, Vector3(0.5, 0.42, 0.46), BELLY, Vector3.ZERO, 12)
	bm.ball(Vector3(0, -0.04, -0.45), Vector3(0.04, 0.05, 0.02), Toon.SUMI, Vector3.ZERO, 6)
	bm.cyl(Vector3(0, -0.08, 0), Vector3(0.505, 0.035, 0.465), Toon.GOLD, Vector3.ZERO, 1.0, 14)
	_belly = piece(body, bm)
	_belly.position = Vector3(0, 0.5, -0.08) * U
	# tête : dôme d'encre, masque gris décharné cerné d'or, couronne d'or à pointes, mèches rares
	_head = Node3D.new()
	body.add_child(_head)
	_head.position = Vector3(0, 1.22, 0) * U
	var a := Yokai.Mesher.new(U)
	var f := Yokai.Mesher.new(U)
	Yokai.mask_plate(a, MASK_GAKI, 0.95, 1.05, true)
	for s in [-1.0, 1.0]:
		var x := float(s)
		# joues creuses, orbites creuses à lueur verte, sourcils de douleur (relevés vers l'intérieur)
		a.ball(Vector3(x * 0.12, 0.07, Yokai.FACE_Z + 0.005), Vector3(0.085, 0.1, 0.025), Toon.SUMI, Vector3.ZERO, 8)
		f.ball(Vector3(x * 0.12, 0.06, Yokai.FACE_Z - 0.018), Vector3(0.035, 0.035, 0.01), HUNGER, Vector3.ZERO, 6)
		a.box(Vector3(x * 0.1, 0.2, Yokai.FACE_Z), Vector3(0.14, 0.03, 0.02), Toon.SUMI, Vector3(0, 0, -x * 0.35))
		a.box(Vector3(x * 0.19, -0.1, Yokai.FACE_Z + 0.012), Vector3(0.07, 0.14, 0.02), Color("#9A9290"), Vector3(0, 0, x * 0.2))
	# bouche béante pleine de dents d'os, lueur de la faim au fond (pièce à part, mise à l'échelle)
	a.ball(Vector3(0, -0.18, Yokai.FACE_Z), Vector3(0.13, 0.11, 0.03), Toon.SUMI, Vector3.ZERO, 8)
	var teeth := 3 if lite else 6
	for i in teeth:
		var x := -0.095 + 0.19 * float(i) / float(teeth - 1)
		a.spike(Vector3(x, -0.1, Yokai.FACE_Z - 0.015), 0.016, 0.06, BONE, Vector3(PI, 0, 0), 0.0, 4)
		a.spike(Vector3(x + 0.016, -0.27, Yokai.FACE_Z - 0.015), 0.013, 0.045, BONE, Vector3.ZERO, 0.0, 4)
	# couronne d'or : bandeau sur le crâne, cinq pointes, perle verte au front
	a.cyl(Vector3(0, 0.3, Yokai.MASK_Z + 0.1), Vector3(0.26, 0.05, 0.25), Toon.GOLD, Vector3(0.2, 0, 0), 0.92, 12)
	var pts := 3 if lite else 5
	for i in pts:
		var ang := -0.9 + 1.8 * float(i) / float(pts - 1)
		var base := Vector3(sin(ang) * 0.24, 0.32 - 0.04 * absf(ang), Yokai.MASK_Z + 0.1 - cos(ang) * 0.22)
		a.spike(base, 0.035, 0.16 + 0.08 * (1.0 - absf(ang)), Toon.GOLD, Vector3(0.1 - 0.15 * absf(ang), 0, -ang * 0.35), 0.0, 4, 0.5)
	f.ball(Vector3(0, 0.3, Yokai.MASK_Z - 0.16), Vector3(0.035, 0.04, 0.02), HUNGER, Vector3.ZERO, 6)
	# mèches rares : quelques brins raides derrière la couronne
	var m := 3 if lite else 5
	for i in m:
		var k := float(i) - float(m - 1) * 0.5
		a.stick(Vector3(k * 0.1, 0.3, Yokai.MASK_Z + 0.2 + 0.03 * absf(k)), Vector3(0.025, 0.26, 0.02), Yokai.HAIR, Vector3(-0.4 - 0.2 * absf(k), 0, -k * 0.5))
	piece(_head, a, f)
	_maw = Toon.part(_head, Toon.sphere(0.1 * U), main.vfx.glow_mat(HUNGER, 2.0), Vector3(0, -0.16, Yokai.FACE_Z + 0.02) * U)
	_maw.scale = Vector3.ONE * 0.01
	# bras maigres (pivot à l'épaule, pendent vers -Y), bracelets d'or ; grand os rongé en main droite
	for sx: float in [1.0, -1.0]:
		var piv := Node3D.new()
		body.add_child(piv)
		piv.position = Vector3(sx * 0.4 * w, 1.0, 0) * U
		var am := Yokai.Mesher.new(U)
		am.cyl(Vector3(0, -0.22, 0), Vector3(0.07, 0.44, 0.07), INK_GAKI, Vector3(PI, 0, 0), 0.7, 7)
		am.cyl(Vector3(0, -0.36, 0), Vector3(0.07, 0.035, 0.07), Toon.GOLD, Vector3.ZERO, 1.0, 8)
		am.ball(Vector3(0, -0.46, 0), Vector3(0.085, 0.075, 0.085), INK_GAKI)
		if sx > 0.0:
			# os (fémur) tenu en travers de la main : fût et deux têtes
			am.cyl(Vector3(0, -0.46, 0), Vector3(0.03, 0.62, 0.03), BONE, Vector3(PI / 2.0 + 0.3, 0, 0), 1.0, 6)
			for e in [-1.0, 1.0]:
				var ez := float(e) * 0.31
				am.ball(Vector3(0.03, -0.46 + ez * sin(0.3), ez * cos(0.3)), Vector3.ONE * 0.05, BONE, Vector3.ZERO, 6)
				am.ball(Vector3(-0.03, -0.46 + ez * sin(0.3), ez * cos(0.3)), Vector3.ONE * 0.05, BONE, Vector3.ZERO, 6)
		piece(piv, am)
		_arms.append(piv)
	# gouttes d'encre sous le corps (étirées en code)
	var dpts := [Vector3(0.16, 0.36, -0.14), Vector3(-0.19, 0.35, 0.06), Vector3(0.05, 0.34, 0.18)]
	if lite:
		dpts = [Vector3(0.16, 0.36, -0.14), Vector3(-0.17, 0.35, 0.1)]
	for p: Vector3 in dpts:
		var piv := Node3D.new()
		body.add_child(piv)
		piv.position = p * U
		var dm := Yokai.Mesher.new(U)
		dm.ball(Vector3.ZERO, Vector3(0.06, 0.08, 0.06), INK_GAKI, Vector3.ZERO, 6)
		dm.spike(Vector3.ZERO, 0.055, 0.2, INK_GAKI, Vector3(PI, 0, 0), 0.3, 5)
		dm.ball(Vector3(0, -0.21, 0), Vector3(0.04, 0.045, 0.04), INK_GAKI, Vector3.ZERO, 6)
		piece(piv, dm)
		_drips.append(piv)
	# pieux de fer et leurs chaînes (mécanique : inchangés)
	var iron := Toon.mat_shared(IRON, true, 0.03)
	for k in STAKES.size():
		var sp: Vector3 = STAKES[k]
		var stake := Node3D.new()
		stake.top_level = true
		add_child(stake)
		stake.global_position = sp
		Toon.part(stake, Toon.cyl(0.12, 0.16, 1.6, 6), iron, Vector3(0, 0.8, 0))
		Toon.part(stake, Toon.cyl(0.2, 0.2, 0.1, 6), iron, Vector3(0, 1.6, 0))
		Toon.disc(stake, 0.45, Color(Toon.SUMI, 0.25), 0.02)
		var link := Toon.part(self, Toon.cyl(0.05, 0.05, 1.0, 5), Toon.mat_shared(IRON, true, 0.02), Vector3.ZERO)
		link.top_level = true
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chains.append({"stake": Vector3(sp.x, 0, sp.z), "stake_node": stake, "mesh": link, "cut": false})
	_make_stars(body, 3.2)
	body.scale = Vector3.ONE * 0.01


## Lueur verte de la faim au fond de la gueule (0 : éteinte).
func _set_glow(a: float) -> void:
	_glow = clampf(a, 0.0, 1.0)


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and _bound():
		_cut_chains(a, b)
	if _state == "spawn" or _state == "dying":
		return false
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


func end_stroke(_stroke_id: int) -> void:
	if dead or not _bound():
		return
	# la dernière image de la ruée n'est pas forcément passée par check_dash
	var pa: Vector3 = main._prev_hero
	_cut_chains(pa, hero.position)


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "lunge":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.35


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "lunge":
		return false
	return _seg_dist(p, position, _lunge_end) < LUNGE_W + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.4, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "lunge":
		_state = "lunge"
	elif tag == "howl":
		var c: Vector3 = z["c"]
		main.enemy_strike(c, HOWL_R)
		main.vfx.ring(Vector3(c.x, 0.08, c.z), HUNGER, HOWL_R)
		main.shake = maxf(float(main.shake), 0.42)
		_state = "idle"
		_timer = 1.6 if hp > max_hp * 0.5 else 1.2


func _on_die() -> void:
	for c in _chains:
		var cd: Dictionary = c
		var m = cd["mesh"]
		m.visible = false
	_set_glow(0.0)


## Chaînes rompues : il s'effondre, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_state = "fallen"
	_cut_t = 0.0
	_set_glow(0.0)


## Fin de la fenêtre : les chaînes se ressoudent, il se relève.
func _on_shield_back() -> void:
	if _state != "fallen":
		return
	_resolder()
	_state = "idle"
	_timer = 1.2


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	if _cut_t > 0.0 and _state != "fallen":
		_cut_t -= delta
		if _cut_t <= 0.0:
			_resolder()
			main.float_icon(position + Vector3(0, 2.6, 0), "hud/chaine", SHIELD_C)
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.3, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.4
		"idle":
			_face(dir, delta, 4.0)
			# il rôde autour de sa place, tenu par ses chaînes
			var want := HOME + Vector3(sin(_t * 0.5) * 1.2, 0, cos(_t * 0.4) * 0.8)
			var mv := Vector3(want.x - position.x, 0, want.z - position.z)
			if mv.length() > 0.1:
				position += mv.normalized() * minf(1.0 * delta, mv.length())
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				match _cycle % 3:
					1:
						_start_lunge(dir)
					2:
						_zone_disc(position, HOWL_R, HOWL_TELE, "howl")
						_state = "howl"
					_:
						_state = "spit"
						_timer = SPIT_TELE
		"charge":
			_face(_lunge_dir, delta, 8.0)
		"howl":
			# le ventre gonfle avant le hurlement
			pass
		"spit":
			_face(dir, delta, 5.0)
			_timer -= delta
			if _flash <= 0.0:
				_set_glow(0.6 * clampf(1.0 - _timer / SPIT_TELE, 0.0, 1.0))
			if _timer <= 0.0:
				_set_glow(0.0)
				var n := 5 if hp > max_hp * 0.5 else 7
				var spread := deg_to_rad(56.0 if n == 5 else 80.0)
				for i in n:
					var ang := -spread * 0.5 + spread * float(i) / float(n - 1)
					var d := dir.rotated(Vector3.UP, ang)
					main.spawn_bullet(position + Vector3(0, 1.6, 0) + d * 1.0, d)
				_state = "idle"
				_timer = 2.0 if hp > max_hp * 0.5 else 1.6
		"lunge":
			var left := Vector2(_lunge_end.x - position.x, _lunge_end.z - position.z).length()
			var step := LUNGE_SPEED * delta
			if left <= step:
				position = Vector3(_lunge_end.x, 0, _lunge_end.z)
				main.clamp_to_arena(self, radius)
				_state = "idle"
				_timer = 1.6 if hp > max_hp * 0.5 else 1.2
				main.splash(position + Vector3(0, 0.3, 0), BONE, 10)
			else:
				position += _lunge_dir * step
		"fallen":
			# effondré : la fin de la fenêtre (vulnerable_t) le relève (_on_shield_back)
			pass
		"dying":
			_timer += delta
			if _timer > 1.4:
				body.position.y -= delta * 1.5
			if _timer > 2.2:
				queue_free()
	_animate(delta)


func _start_lunge(dir: Vector3) -> void:
	_lunge_dir = dir
	var me := Vector3(position.x, 0, position.z)
	var room := _bot_room(me, dir) - 0.8
	var l := clampf(room, 2.0, 7.0)
	_lunge_end = me + dir * l
	_zone_rect(me + dir * (l * 0.5), dir, LUNGE_W, l * 0.5, LUNGE_TELE, "lunge", Vector2(0, -1))
	_state = "charge"


func _bound() -> bool:
	return _state != "spawn" and _state != "fallen" and _state != "dying"


## Point d'attache des chaînes (son collier), au sol.
func _collar_ground() -> Vector3:
	return Vector3(position.x, 0, position.z)


## Ruée a..b : chaque chaîne croisée se rompt ; les trois rompues brisent le bouclier.
func _cut_chains(a: Vector3, b: Vector3) -> void:
	var me := _collar_ground()
	var n_cut := 0
	for c in _chains:
		var cd: Dictionary = c
		if bool(cd["cut"]):
			n_cut += 1
			continue
		var sp: Vector3 = cd["stake"]
		# la chaîne va du pieu à 0.9 m de lui (on ne la tranche pas dans son corps)
		var tip := me + (sp - me).normalized() * 0.9
		if Loop.cuts(a, b, sp, tip):
			cd["cut"] = true
			n_cut += 1
			var mid := sp.lerp(tip, 0.5)
			main.small_hit(mid + Vector3(0, 1.0, 0))
			main.vfx.sparks(mid + Vector3(0, 1.0, 0), Vector3.UP, 8, Toon.GOLD)
			main.sfx.play("strike", 1.4, -5.0)
			if _cut_t <= 0.0:
				_cut_t = RESOLDER
			if n_cut < _chains.size():
				_shield_dmg(CHAIN_CHIP)
	if n_cut >= _chains.size() and vulnerable_t <= 0.0 and not dead:
		main.float_icon(position + Vector3(0, 2.4, 0), "hud/slash", Toon.GOLD)
		main.big_hit(position + Vector3(0, 1.4, 0))
		main.shake = maxf(float(main.shake), 0.69)
		_shield_dmg(shield_max)


func _resolder() -> void:
	_cut_t = 0.0
	for c in _chains:
		var cd: Dictionary = c
		if bool(cd["cut"]):
			cd["cut"] = false
			var sp: Vector3 = cd["stake"]
			main.vfx.sparks(sp + Vector3(0, 1.4, 0), Vector3.UP, 5, SHIELD_C)


## Chaînes tendues (pieu -> collier), ventre qui gonfle, corps effondré ; pose procédurale : penché en arrière
## pour la charge et le hurlement, jeté en avant pour la ruée, bras levés pour cracher, écroulé renversé ;
## gouttes qui s'étirent, lueur de la faim au fond de la gueule.
func _animate(delta: float) -> void:
	var neck := position + Vector3(0, 2.0 + body.position.y, 0)
	for c in _chains:
		var cd: Dictionary = c
		var m = cd["mesh"]
		var sp: Vector3 = cd["stake"]
		var on := not bool(cd["cut"]) and not dead
		m.visible = on
		if on:
			var a := sp + Vector3(0, 1.5, 0)
			var d := neck - a
			var l := maxf(d.length(), 0.01)
			var q := Quaternion.IDENTITY
			if absf(d.normalized().dot(Vector3.UP)) < 0.999:
				q = Quaternion(Vector3.UP, d.normalized())
			m.global_transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1, l, 1)), (a + neck) * 0.5)
	var swell := 1.0
	var howl := 0.0
	if _state == "howl":
		for z in _zones:
			var zd: Dictionary = z
			howl = clampf(1.0 - float(zd["t"]) / float(zd["total"]), 0.0, 1.0)
		swell = 1.0 + 0.35 * howl
	_belly.scale = Vector3.ONE * swell
	# penché : charge et hurlement en arrière, ruée en avant, sinon respiration
	var want_lean := 0.0
	var want_r := REST_R
	var want_l := REST_L
	var nod := 0.06 * sin(_t * 1.7)
	match _state:
		"charge":
			want_lean = -0.3
			want_r = Vector3(-0.6, 0, 0.6)
			want_l = Vector3(-0.6, 0, -0.6)
			nod = -0.2
		"lunge":
			want_lean = 0.45
			want_r = Vector3(1.9, 0, 0.3)
			want_l = Vector3(1.9, 0, -0.3)
			nod = 0.25
		"howl":
			want_lean = -0.25 * howl
			want_r = Vector3(0.4, 0, 0.9 + 0.3 * howl)
			want_l = Vector3(0.4, 0, -0.9 - 0.3 * howl)
			nod = -0.35 * howl
		"spit":
			var k := clampf(1.0 - _timer / SPIT_TELE, 0.0, 1.0)
			want_r = Vector3(2.6 * k + REST_R.x * (1.0 - k), 0, 0.4)
			want_l = Vector3(2.6 * k + REST_L.x * (1.0 - k), 0, -0.4)
			nod = -0.2 * k
		"fallen":
			want_r = Vector3(0.3, 0, 1.2 + 0.08 * sin(_t * 9.0))
			want_l = Vector3(0.3, 0, -1.2 - 0.08 * sin(_t * 9.0))
			nod = 0.3
		"dying":
			want_lean = 0.9
			want_r = Vector3(0.2, 0, 0.3)
			want_l = Vector3(0.2, 0, -0.3)
			nod = 0.5
		_:
			want_r += Vector3(0.1 * sin(_t * 1.7), 0, 0)
			want_l += Vector3(0.1 * sin(_t * 1.7 + 1.2), 0, 0)
	var k2 := minf(1.0, delta * 7.0)
	_lean = lerpf(_lean, want_lean, k2)
	var ar: Node3D = _arms[0]
	var al: Node3D = _arms[1]
	ar.rotation = ar.rotation.lerp(want_r, k2)
	al.rotation = al.rotation.lerp(want_l, k2)
	_head.rotation.x = lerpf(_head.rotation.x, nod, k2)
	var stretch := 1.6 if _state == "lunge" else 1.0
	for i in _drips.size():
		var n: Node3D = _drips[i]
		var ph := _t * 2.4 + float(i) * 1.7
		n.scale = Vector3(1, stretch * (1.0 + 0.3 * sin(ph)), 1)
		n.rotation = Vector3(0.1 * sin(ph * 0.7) + 0.4 * _lean, 0, 0.1 * cos(ph * 0.9 + 0.5))
	# le modèle regarde vers -Z : penché en avant = rotation.x négative
	if _state == "fallen":
		body.rotation.x = lerpf(body.rotation.x, 0.5, minf(1.0, delta * 6.0))
		body.position.y = -0.3
	elif _state != "dying":
		body.rotation.x = lerpf(body.rotation.x, -_lean, minf(1.0, delta * 12.0))
		body.position.y = 0.04 * sin(_t * 1.7)
	else:
		body.rotation.x = lerpf(body.rotation.x, -_lean, minf(1.0, delta * 6.0))
	_maw.scale = Vector3.ONE * maxf(0.01, _glow * (1.0 + 0.15 * sin(_t * 14.0)))
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * (1.06 if _flash > 0.0 else 1.0)


# ------------------------------------------------------------------ robot testeur

## Chaînes : un trait droit en travers de la première chaîne intacte (et des autres au passage) ;
## effondré (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := _collar_ground()
	if _state == "fallen":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, me, 7.3)
	if not _bound() or _state == "spawn":
		return none
	for c in _chains:
		var cd: Dictionary = c
		if bool(cd["cut"]):
			continue
		var sp: Vector3 = cd["stake"]
		var tip := me + (sp - me).normalized() * 0.9
		var mid := sp.lerp(tip, 0.5)
		var along := (tip - sp)
		along.y = 0
		if along.length_squared() < 0.01:
			continue
		var n := Vector3(-along.z, 0, along.x).normalized()
		var p0 := mid - n * 1.4
		var p1 := mid + n * 1.4
		if h.distance_to(p1) < h.distance_to(p0):
			var tmp := p0
			p0 = p1
			p1 = tmp
		return _bot_dense([h, p0, p1])
	return none
