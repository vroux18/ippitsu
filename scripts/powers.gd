extends Node
## Rouleaux (pouvoirs) choisis en montant de niveau, au sanctuaire et après le gardien :
## raretés (commun → légendaire), affinités d'école, synergies, légendaires uniques et visibles.
## Données dans power_data.gd. `main` appelle les hooks : on_hit, on_boss_hit, on_kill, on_dash_end,
## on_stroke_release, update ; et en plus on_hurt, on_shape, on_enso_land, on_dodge, time_mult,
## boss_dmg, on_room_start (facultatif : la salle est aussi détectée dans update).

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")

const LEG_ROOM := 6  # premier légendaire possible à partir de cette salle...
const LEG_LEVEL := 6  # ... ou de ce niveau
const LEG_MAX := 3  # légendaires par partie
const PITY_EPIC := 3  # offres d'affilée sans épique (ou mieux) avant d'en garantir un
const PITY_LEG := 5  # offres sans légendaire (une fois permis) avant d'en garantir un
const DASH_SPEED := 34.0  # même valeur que hero.gd
const Vfx = preload("res://scripts/vfx.gd")
const FOX_COLOR := Color("#B58BFF")  # feu de renard : lilas (école de l'ombre)
const FLAME_COLOR := Color("#FF5A1F")  # = Vfx.FIRE
const WIND_COLOR := Color("#5FD6A8")  # = Vfx.WIND

var main: Node3D
var levels := {}  # id -> niveau (1..max)
var _tiers := {}  # école -> palier d'affinité atteint (0, 1, 2)
var _burn := {}  # instance_id -> [ennemi, temps restant, dégâts/s]
var _burn_fx := {}  # instance_id -> flammes accrochées à l'ennemi (visuel seul)
var _trails: Array = []  # [points, temps restant, tick, dégâts/s]
var _boss_burn: Array = []  # [point, temps restant, dégâts/s]
var _kills := 0
var _hits := 0  # touches, pour l'orage
var _aff_hits := 0  # touches, pour l'affinité foudre
var _kill_depth := 0  # explosions en chaîne : profondeur limitée
var _since_epic := 0
var _since_leg := 0
var _room := -1
var _strokes := 0
var _last_pts := PackedVector3Array()
var _stroke_hits := 0
var _charge := 0.0
var _ippitsu_next := false
var _ippitsu_now := false
var _blade_hit := {}
var _fox_cd := {}
var _fox_ang := 0.0
var _fox_pos: Array = []
var _fox_boss_t := 0.0
var _aura_t := 0.0
var _foam_seen := 0
var _utsu_left := 0
var _hoo_used := false
var _enso_heal_room := -1
var _raiju_t := 2.0
var _stolen_stroke := -1
var _slow_until := 0  # millisecondes (temps réel)
var _slow_cd := 0
var _slow_scale := 1.0
var _was_touching := false
var _drum_pulse := 0.0
# objets vivants (tous sous _root, libérés par reset)
var _zones: Array = []  # roue de feu, tourbillon, cercle d'encre
var _sweeps: Array = []  # grande vague, clone d'ombre
var _fx: Array = []  # éclairs, éclats, mues
var _root: Node3D
var _halo: Node3D
var _flames: Array = []
var _drums: Node3D
var _gale: Node3D
var _foxes: Array = []
var _anim := 0.0
var _cache := {}


func reset() -> void:
	levels.clear()
	_tiers.clear()
	_burn.clear()
	_clear_burn_fx()
	_trails.clear()
	_boss_burn.clear()
	_kills = 0
	_hits = 0
	_aff_hits = 0
	_kill_depth = 0
	_since_epic = 0
	_since_leg = 0
	_room = -1
	_strokes = 0
	_last_pts = PackedVector3Array()
	_stroke_hits = 0
	_charge = 0.0
	_ippitsu_next = false
	_ippitsu_now = false
	_blade_hit.clear()
	_fox_cd.clear()
	_fox_pos.clear()
	_fox_ang = 0.0
	_fox_boss_t = 0.0
	_aura_t = 0.0
	_foam_seen = 0
	_utsu_left = 0
	_hoo_used = false
	_enso_heal_room = -1
	_raiju_t = 2.0
	_stolen_stroke = -1
	_slow_until = 0
	_slow_cd = 0
	_slow_scale = 1.0
	_was_touching = false
	_drum_pulse = 0.0
	_zones.clear()
	_sweeps.clear()
	_fx.clear()
	_flames.clear()
	_foxes.clear()
	_halo = null
	_drums = null
	_gale = null
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null


# ------------------------------------------------------------------ niveaux et valeurs

func lvl(id: String) -> int:
	return int(levels.get(id, 0))


func max_level(id: String) -> int:
	if not Data.POWERS.has(id):
		return 0
	var d: Dictionary = Data.POWERS[id]
	return int(d.get("max", 3))


func val(id: String) -> float:
	return _level_value(id, "v", lvl(id))


func val2(id: String) -> float:
	return _level_value(id, "w", lvl(id))


func _level_value(id: String, key: String, l: int) -> float:
	if l <= 0 or not Data.POWERS.has(id):
		return 0.0
	var d: Dictionary = Data.POWERS[id]
	if not d.has(key):
		return 0.0
	var arr: Array = d[key]
	return float(arr[mini(l, arr.size()) - 1])


func add(id: String) -> void:
	if not Data.POWERS.has(id):
		return
	var foam_before := foam_per_room()
	var before := lvl(id)
	levels[id] = mini(before + 1, max_level(id))
	_refresh_tiers()
	# l'écume gagnée sert tout de suite, sans attendre la salle suivante
	var gain := foam_per_room() - foam_before
	if gain > 0:
		main.foam = int(main.foam) + gain
		_foam_seen = int(main.foam)
	match id:
		"ink_daruma":
			main.hero.max_hp = int(main.hero.max_hp) + 1
			main.heal(int(val(id)))
		"fire_hoo":
			main.hero.max_hp = int(main.hero.max_hp) + 1
			main.heal(1)
		"ink_omamori":
			main.picker.rerolls = int(main.picker.rerolls) + 1
		"shadow_utsusemi":
			_utsu_left = int(val(id))
	_ensure_visuals()


# ------------------------------------------------------------------ affinités

## Nombre de pouvoirs différents de l'école (+1 avec le sceau Rakkan si l'école est commencée).
func affinity(school: String) -> int:
	return _aff_count(school, 0)


func _aff_raw(school: String) -> int:
	if school == "ink" or school == "":
		return 0
	var n := 0
	for id in levels.keys():
		if int(levels[id]) <= 0:
			continue
		var d: Dictionary = Data.POWERS[id]
		if String(d["school"]) == school:
			n += 1
	return n


func _aff_count(school: String, extra: int) -> int:
	var n := _aff_raw(school) + extra
	if n > 0 and lvl("ink_rakkan") > 0:
		n += 1
	return n


func _tier_for(n: int) -> int:
	var t := 0
	for th in Data.AFF_TIERS:
		if n >= int(th):
			t += 1
	return t


func _refresh_tiers() -> void:
	_tiers.clear()
	for s in Data.SCHOOLS.keys():
		_tiers[s] = _tier_for(affinity(String(s)))


func _tier_of(school: String) -> int:
	return int(_tiers.get(school, 0))


func _schools_started() -> int:
	var n := 0
	for s in Data.SCHOOLS.keys():
		if _aff_raw(String(s)) > 0:
			n += 1
	return n


## Résumé des affinités (pour un éventuel affichage) : école -> [nombre, palier].
func affinities() -> Dictionary:
	var out := {}
	for s in Data.AFFINITY.keys():
		var n := affinity(String(s))
		if n > 0:
			out[s] = [n, _tier_of(String(s))]
	return out


func _fire_mult() -> float:
	return 1.0 + 0.25 * float(_tier_of("fire"))


func _bolt_mult() -> float:
	return 1.0 + 0.25 * float(_tier_of("bolt"))


func _wave_mult() -> float:
	return 1.5 if _tier_of("water") >= 2 else 1.0


# ------------------------------------------------------------------ offre (raretés, pitié)

## Trois rouleaux tirés selon la rareté et la progression (salle `room_n`, par défaut la salle en cours).
## Un des trois améliore souvent un pouvoir déjà pris ; un épique est garanti après PITY_EPIC offres sans,
## et un légendaire (à partir du milieu de partie) après PITY_LEG offres sans.
func offer(room_n: int = -1) -> Array:
	var r := room_n
	if r < 0:
		r = int(main.room) if main != null else 0
	var lv := int(main.level) if main != null else 1
	var w := _rarity_weights(r, lv)
	var pools := {"common": [], "rare": [], "epic": [], "legendary": []}
	var owned_up: Array = []
	for key in Data.POWERS.keys():
		var id := String(key)
		if not _eligible(id, r, lv):
			continue
		var d: Dictionary = Data.POWERS[id]
		var pl: Array = pools[String(d["rarity"])]
		pl.append(id)
		if lvl(id) > 0:
			owned_up.append(id)
	var out: Array = []
	if not owned_up.is_empty() and randf() < 0.65:
		out.append(owned_up[randi() % owned_up.size()])
	var leg_pool: Array = pools["legendary"]
	var leg_ok := float(w["legendary"]) > 0.0 and not leg_pool.is_empty()
	var force_leg := leg_ok and _since_leg >= PITY_LEG
	var force_epic := _since_epic >= PITY_EPIC
	var guard := 0
	while out.size() < 3 and guard < 20:
		guard += 1
		var rar := _roll(w)
		if force_leg and not _has_rank(out, 3):
			rar = "legendary"
		elif force_epic and out.size() == 2 and not _has_rank(out, 2):
			rar = "legendary" if leg_ok and randf() < 0.25 else "epic"
		var id := _pick(pools, rar, out)
		if id == "":
			break
		out.append(id)
	if _has_rank(out, 2):
		_since_epic = 0
	else:
		_since_epic += 1
	if leg_ok:
		if _has_rank(out, 3):
			_since_leg = 0
		else:
			_since_leg += 1
	out.shuffle()
	return out


func _leg_open(r: int, lv: int) -> bool:
	return r >= LEG_ROOM or lv >= LEG_LEVEL


func _leg_count() -> int:
	var n := 0
	for id in levels.keys():
		var d: Dictionary = Data.POWERS[id]
		if String(d["rarity"]) == "legendary":
			n += 1
	return n


func _rarity_weights(r: int, lv: int) -> Dictionary:
	var p := clampf(float(r) / 15.0, 0.0, 1.0)
	var luck := val("ink_omamori") / 100.0
	var w := {"common": 100.0 - 30.0 * p, "rare": (38.0 + 30.0 * p) * (1.0 + luck * 0.5), "epic": 0.0, "legendary": 0.0}
	if r >= 2 or lv >= 3:
		w["epic"] = (9.0 + 26.0 * p) * (1.0 + luck)
	if _leg_open(r, lv) and _leg_count() < LEG_MAX:
		w["legendary"] = (3.5 + 9.0 * p) * (1.0 + luck) * (1.0 + 0.5 * float(_since_leg))
	return w


func _roll(w: Dictionary) -> String:
	var total := 0.0
	for k in Data.RARITY_ORDER:
		total += float(w.get(k, 0.0))
	var x := randf() * total
	for k in Data.RARITY_ORDER:
		x -= float(w.get(k, 0.0))
		if x <= 0.0:
			return String(k)
	return "common"


func _rank(id: String) -> int:
	var d: Dictionary = Data.POWERS[id]
	var rd: Dictionary = Data.RARITIES[String(d["rarity"])]
	return int(rd["rank"])


func _has_rank(ids: Array, rank: int) -> bool:
	for id in ids:
		if _rank(String(id)) >= rank:
			return true
	return false


func _eligible(id: String, r: int, lv: int) -> bool:
	if lvl(id) >= max_level(id):
		return false
	var d: Dictionary = Data.POWERS[id]
	if d.has("needs"):
		var ok := false
		for n in d["needs"]:
			if lvl(String(n)) > 0:
				ok = true
		if not ok:
			return false
	var rar := String(d["rarity"])
	var school := String(d["school"])
	if rar == "legendary":
		if not _leg_open(r, lv) or _leg_count() >= LEG_MAX:
			return false
		# un légendaire d'école ne vient qu'une fois l'école commencée
		if school != "ink" and _aff_raw(school) == 0:
			return false
	elif rar == "epic" and r < 2 and lv < 3:
		return false
	if id == "ink_rakkan" and _schools_started() < 2:
		return false
	return true


## Un pouvoir de la rareté voulue (sinon la plus proche en dessous, puis au-dessus), pondéré :
## les écoles déjà commencées reviennent plus souvent, pour des builds lisibles.
func _pick(pools: Dictionary, rar: String, exclude: Array) -> String:
	var start: int = Data.RARITY_ORDER.find(rar)
	var order: Array = []
	for k in range(start, -1, -1):
		order.append(Data.RARITY_ORDER[k])
	for k in range(start + 1, Data.RARITY_ORDER.size()):
		order.append(Data.RARITY_ORDER[k])
	for rk in order:
		var cands: Array = []
		var weights: Array = []
		var total := 0.0
		for id in pools[rk]:
			if id in exclude:
				continue
			var wt := _bias(String(id))
			cands.append(id)
			weights.append(wt)
			total += wt
		if cands.is_empty():
			continue
		var x := randf() * total
		for i in cands.size():
			x -= float(weights[i])
			if x <= 0.0:
				return String(cands[i])
		return String(cands[cands.size() - 1])
	return ""


func _bias(id: String) -> float:
	var d: Dictionary = Data.POWERS[id]
	var school := String(d["school"])
	var b := 1.0
	if lvl(id) > 0:
		b *= 1.4
	elif school != "ink" and _aff_raw(school) > 0:
		b *= 1.7
	if String(d["rarity"]) == "legendary" and _aff_raw(school) >= 2:
		b *= 2.0
	return b


# ------------------------------------------------------------------ description (cartes, récapitulatif)

## Carte de rouleau : textes en clair, valeurs « niveau actuel → niveau suivant », affinité et synergie.
func describe(id: String) -> Dictionary:
	var d: Dictionary = Data.POWERS[id]
	var cur := lvl(id)
	var mx := max_level(id)
	var next := mini(cur + 1, mx)
	var school := String(d["school"])
	var sd: Dictionary = Data.SCHOOLS[school]
	var rar := String(d["rarity"])
	var rd: Dictionary = Data.RARITIES[rar]
	# affinité : avant / après ce choix, palier visé (ou atteint) et son bonus, en clair
	var aff := 0
	var aff_next := 0
	var aff_goal := 0
	var aff_hit := false
	var aff_text := ""
	var aff_tail := ""
	var aff_tail_short := ""
	var aff_done := false
	if Data.AFFINITY.has(school):
		aff = affinity(school)
		aff_next = _aff_count(school, 1) if cur == 0 else aff
		var bonus: Array = Data.AFFINITY[school]
		var tiers: Array = Data.AFF_TIERS
		var k_hit := -1
		var k_goal := -1
		for k in tiers.size():
			var th := int(tiers[k])
			if aff < th and aff_next >= th:
				k_hit = k
			if k_goal < 0 and aff_next < th:
				k_goal = k
		if k_hit >= 0:
			aff_hit = true
			aff_goal = int(tiers[k_hit])
			aff_text = String(bonus[k_hit])
			aff_tail = "BONUS ACTIF :"
			aff_tail_short = "BONUS :"
		elif k_goal >= 0:
			aff_goal = int(tiers[k_goal])
			aff_text = String(bonus[k_goal])
			var need := aff_goal - aff_next
			aff_tail = "encore %d pouvoir%s %s :" % [need, "s" if need > 1 else "", String(sd["word"])]
			aff_tail_short = "encore %d :" % need
		else:
			aff_done = true
			aff_goal = int(tiers[tiers.size() - 1])
			aff_text = String(bonus[bonus.size() - 1])
			aff_tail = "école complète :"
			aff_tail_short = "complète :"
	var syn := _synergy(id)
	return {"name": d["name"], "sub": String(d.get("sub", "")),
		"when": _fill(id, String(d.get("when", "")), next, next),
		"text": _fill(id, String(d.get("text", "")), next, next),
		"stat": _fill(id, String(d.get("stat", "")), cur, next),
		"level": next, "kanji": String(d.get("kanji", sd["kanji"])),
		"color": sd["color"], "school": school, "school_name": sd["name"], "school_kanji": sd["kanji"],
		"rarity": rar, "rarity_name": rd["name"], "rarity_color": rd["color"], "rarity_rank": int(rd["rank"]),
		"is_new": cur == 0, "cur_level": cur, "max_level": mx,
		"aff": aff, "aff_next": aff_next, "aff_goal": aff_goal, "aff_hit": aff_hit, "aff_text": aff_text,
		"aff_tail": aff_tail, "aff_tail_short": aff_tail_short, "aff_done": aff_done,
		"synergy": syn[0], "synergy_on": syn[1]}


## Pouvoir possédé (récapitulatif) : textes avec les valeurs du niveau actuel.
func recap_info(id: String) -> Dictionary:
	var d: Dictionary = Data.POWERS[id]
	var cur := maxi(1, lvl(id))
	var school := String(d["school"])
	var sd: Dictionary = Data.SCHOOLS[school]
	var rd: Dictionary = Data.RARITIES[String(d["rarity"])]
	var syn := _synergy(id)
	return {"id": id, "name": d["name"], "sub": String(d.get("sub", "")),
		"when": _fill(id, String(d.get("when", "")), cur, cur),
		"text": _fill(id, String(d.get("text", "")), cur, cur),
		"stat": _fill(id, String(d.get("stat", "")), cur, cur),
		"level": cur, "max_level": max_level(id), "kanji": String(d.get("kanji", sd["kanji"])),
		"color": sd["color"], "school": school, "school_name": sd["name"],
		"rarity_name": rd["name"], "rarity_color": rd["color"], "rarity_rank": int(rd["rank"]),
		"synergy": syn[0] if bool(syn[1]) else ""}


## Bonus d'une école (récapitulatif) : nombre de pouvoirs, palier, bonus actif et prochain bonus.
func school_status(school: String) -> Dictionary:
	var n := affinity(school)
	var tiers: Array = Data.AFF_TIERS
	var bonus: Array = Data.AFFINITY.get(school, [])
	var tier := _tier_for(n)
	var out := {"count": n, "tier": tier, "goal": int(tiers[mini(tier, tiers.size() - 1)]),
		"active": "", "next": "", "next_at": 0}
	if bonus.is_empty():
		return out
	if tier > 0:
		out["active"] = String(bonus[tier - 1])
	if tier < tiers.size():
		out["next"] = String(bonus[tier])
		out["next_at"] = int(tiers[tier])
	return out


## Synergie du pouvoir : [texte « Avec <partenaire> : <effet> », active ?] (la première active, sinon une piste).
func _synergy(id: String) -> Array:
	var syn := ""
	for s in Data.SYNERGIES:
		var a := String(s[0])
		var b := String(s[1])
		var partner := ""
		if a == id:
			partner = b
		elif b == id:
			partner = a
		if partner == "" or not Data.POWERS.has(partner):
			continue
		var pd: Dictionary = Data.POWERS[partner]
		var line := "Avec %s : %s" % [String(pd["name"]), String(s[2])]
		if lvl(partner) > 0:
			return [line, true]
		if syn == "":
			syn = line
	return [syn, false]


## Remplace {v} / {w} : une seule valeur, ou « avant → après » si elle change entre les niveaux a et b.
func _fill(id: String, s: String, a: int, b: int) -> String:
	var out := s
	for key in ["v", "w"]:
		var tag := "{%s}" % key
		if not out.contains(tag):
			continue
		var after := _fr(_level_value(id, key, b))
		var txt := after
		if a > 0 and a != b:
			var before := _fr(_level_value(id, key, a))
			if before != after:
				txt = before + " → " + after
		out = out.replace(tag, txt)
	return out


## Nombre à la française (virgule décimale).
func _fr(v) -> String:
	return _num(v).replace(".", ",")


func _num(v) -> String:
	var f := float(v)
	if absf(f - roundf(f)) < 0.001:
		return str(int(roundf(f)))
	return str(snappedf(f, 0.01))


# ------------------------------------------------------------------ statistiques

func elan_bonus() -> float:
	var b := val("wind_long")
	if lvl("wind_fujin") > 0:
		b += 4.0
	var t := _tier_of("wind")
	if t >= 2:
		b += 4.0
	elif t == 1:
		b += 2.0
	return b


func regen_mult() -> float:
	return 1.0 + val("wind_gust") / 100.0 + (0.5 if lvl("wind_fujin") > 0 else 0.0)


func dash_mult() -> float:
	var m := 1.0 + val("bolt_quick") / 100.0
	if _tier_of("bolt") >= 1:
		m += 0.1
	if _tier_of("wind") >= 2:
		m += 0.15
	return m


func dodge_cost(base: float) -> float:
	return 0.0 if lvl("wind_feather") > 0 else base


func dodge_dist(base: float) -> float:
	return val("wind_feather") if lvl("wind_feather") > 0 else base


func foam_per_room() -> int:
	var n := int(val("water_foam"))
	if lvl("water_kanagawa") > 0:
		n += 1
	if _tier_of("water") >= 1:
		n += 1
	return n


## Échelle de temps voulue par les pouvoirs (Souffle suspendu, Instant volé) ; 1.0 sinon.
func time_mult() -> float:
	var now := Time.get_ticks_msec()
	var touching := bool(main.touching)
	if touching and not _was_touching and lvl("wind_stillness") > 0 and now >= _slow_cd:
		_slow(val("wind_stillness"), 0.35)
		_slow_cd = now + 5000
	_was_touching = touching
	if now < _slow_until:
		return _slow_scale
	return 1.0


func _slow(sec: float, scale: float) -> void:
	var now := Time.get_ticks_msec()
	if now >= _slow_until:
		_slow_scale = scale
	else:
		_slow_scale = minf(_slow_scale, scale)
	_slow_until = maxi(_slow_until, now + int(sec * 1000.0))


## Dégâts d'un coup de ruée sur un boss, modifiés par les pouvoirs (renaissance, Ippitsu, critiques).
func boss_dmg(d: float) -> float:
	var out := d * _global_mult()
	if lvl("ink_ippitsu") > 0 and int(main.combo) > 1:
		out *= 1.0 + 0.25 * float(int(main.combo) - 1)
	return out * _crit(main.hero.position)


func _global_mult() -> float:
	var m := 1.0
	if _hoo_used:
		m *= 1.25
	if _ippitsu_now:
		m *= 2.0
	return m


func _crit(pos: Vector3) -> float:
	var t := _tier_of("shadow")
	if t == 0:
		return 1.0
	if randf() < (0.1 if t == 1 else 0.25):
		# critique d'ombre : bouffée violette
		main.vfx.smoke(pos, 0.3, 5)
		main.splash(pos, Vfx.SHADOW, 6)
		return 2.0 if t == 1 else 2.5
	return 1.0


# ------------------------------------------------------------------ hooks de combat

## Modifie les dégâts d'un coup de trait et applique les effets de touche.
func on_hit(e: Node3D, dmg: float, dir: Vector3) -> float:
	var out := dmg
	var eid := e.get_instance_id()
	var combo := int(main.combo)
	_stroke_hits += 1
	out *= _global_mult()
	if lvl("ink_ippitsu") > 0 and combo > 1:
		out *= 1.0 + 0.25 * float(combo - 1)
	if lvl("fire_edge") > 0 and _burn.has(eid):
		out *= 1.0 + val("fire_edge") / 100.0
	if lvl("shadow_back") > 0:
		var ry: float = e.body.rotation.y
		var fwd := Vector3(-sin(ry), 0, -cos(ry))
		if dir.normalized().dot(fwd) > 0.5:
			out *= val("shadow_back")
			main.float_text(e.position, "×" + _num(val("shadow_back")), FOX_COLOR)
	out *= _crit(e.position)
	if lvl("bolt_thunder") > 0 and combo >= 3:
		out += val("bolt_thunder") * _bolt_mult()
		_stun(e)
		main.vfx.sparks(e.position + Vector3(0, 0.9, 0), Vector3.UP, 4, Vfx.BOLT)
	# Kaishaku : sous le seuil, le coup achève
	if lvl("shadow_execute") > 0:
		var th := val("shadow_execute") + (10.0 if lvl("shadow_back") > 0 else 0.0)
		var mx := float(e.get_meta("max_hp", 1.0))
		var left := float(e.hp) - out
		if left > 0.0 and left <= mx * th / 100.0:
			out = float(e.hp) + 0.01
			main.shape_text(e.position, "斬")
	# brûlure
	var burn := val("fire_burn")
	if _tier_of("fire") >= 2:
		burn = maxf(burn, 0.6)
	if burn > 0.0:
		_ignite(e, burn, 3.0)
	if lvl("water_push") > 0:
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		if side.dot(e.position - main.hero.position) < 0.0:
			side = -side
		e.push(side * val("water_push") * 3.0 * _wave_mult())
		main.vfx.wave_arc(e.position, side, 0.7)
	_storm(e.position)
	if lvl("bolt_arc") > 0:
		for o in main.nearest_enemies(e.position, 3.0, int(val("bolt_arc")), e):
			main.zap(e.position, o.position)
			main.damage_enemy(o, 0.5 * _bolt_mult())
	if lvl("bolt_raijin") > 0:
		var n := 2 + (1 if lvl("bolt_arc") > 0 else 0)
		for o in main.nearest_enemies(e.position, 4.0, n, e):
			main.zap(e.position, o.position)
			main.damage_enemy(o, 1.0 * _bolt_mult())
	_common_hit(e.position)
	return out


## Coup de ruée sur un boss : braise, arcs, orage, foudre de Raijin s'appliquent aussi.
## `dmg` facultatif (dégâts du coup, pour un usage futur).
func on_boss_hit(pos: Vector3, _dmg: float = 1.0) -> void:
	_stroke_hits += 1
	var burn := val("fire_burn")
	if _tier_of("fire") >= 2:
		burn = maxf(burn, 0.6)
	if burn > 0.0:
		if _boss_burn.size() >= 6:
			_boss_burn.remove_at(0)
		_boss_burn.append([pos, 3.0, burn])
		main.vfx.flames(pos, 0.35, 5)
	if lvl("bolt_arc") > 0:
		for o in main.nearest_enemies(pos, 3.0, int(val("bolt_arc")), null):
			main.zap(pos, o.position)
			main.damage_enemy(o, 0.5 * _bolt_mult())
	if lvl("bolt_raijin") > 0:
		var hits: Array = main.damage_bosses(pos, 2.5, 0.6 * _bolt_mult(), false)
		if not hits.is_empty():
			_bolt_strike(hits[0], false)
	_storm(pos)
	_common_hit(pos)


## Effets communs à toute touche de ruée (ennemi ou boss).
func _common_hit(pos: Vector3) -> void:
	var combo := int(main.combo)
	if _tier_of("bolt") >= 2:
		_aff_hits += 1
		if _aff_hits % 5 == 0:
			for o in main.nearest_enemies(pos, 5.0, 2, null):
				_bolt_strike(o.position, false)
				main.damage_enemy(o, 1.0 * _bolt_mult())
	if _tier_of("wind") >= 2:
		main.elan = minf(float(main.elan_max()), float(main.elan) + 1.0)
	if lvl("shadow_stolen") > 0 and combo >= 4 and _stolen_stroke != int(main.stroke_id):
		_stolen_stroke = int(main.stroke_id)
		_slow(val("shadow_stolen"), 0.3)
		main.vfx.ring(Vector3(pos.x, 0.06, pos.z), Vfx.SHADOW, 2.0)
		main.vfx.smoke(pos, 0.6, 7)
		main.vfx.school_kanji(pos, "shadow")


## Orage : toutes les N touches, la foudre tombe sur les 3 ennemis les plus proches.
func _storm(pos: Vector3) -> void:
	if lvl("bolt_storm") == 0:
		return
	_hits += 1
	if _hits % int(val("bolt_storm")) != 0:
		return
	var struck := false
	for o in main.nearest_enemies(pos, 7.0, 3, null):
		# orage : la foudre tombe du ciel sur chaque cible
		main.vfx.sky_bolt(o.position, false)
		main.damage_enemy(o, 1.0 * _bolt_mult())
		struck = true
	if struck:
		main.vfx.school_kanji(pos, "bolt")
	main.damage_bosses(pos, 3.0, 1.0 * _bolt_mult())


func on_kill(e: Node3D) -> void:
	_kills += 1
	if lvl("water_dew") > 0 and _kills % int(val("water_dew")) == 0:
		main.heal(1)
	if not is_instance_valid(e):
		return
	var eid := e.get_instance_id()
	var burning := _burn.has(eid)
	_burn.erase(eid)
	_drop_burn_fx(eid)
	_fox_cd.erase(eid)
	if _kill_depth >= 2:
		return
	_kill_depth += 1
	if burning and lvl("fire_spark") > 0:
		# Hibana : l'ennemi en feu explose et passe le feu à ses voisins
		var p: Vector3 = e.position
		var dmg := val("fire_spark") * _fire_mult()
		main.fire_ring(p, 1.6)
		main.vfx.school_kanji(p, "fire")
		for o in main.nearest_enemies(p, 1.6, 99, e):
			_ignite(o, maxf(val("fire_burn"), 0.5), 3.0)
			main.damage_enemy(o, dmg)
		main.damage_bosses(p, 1.6, dmg)
	_kill_depth -= 1


func on_dash_end(pos: Vector3, kills: int) -> void:
	var combo := int(main.combo)
	if lvl("fire_hearth") > 0:
		var hd := val("fire_hearth") * _fire_mult()
		main.fire_ring(pos, 1.8)
		for o in main.nearest_enemies(pos, 1.8, 99, null):
			main.damage_enemy(o, hd)
		main.damage_bosses(pos, 1.8, hd)
	if lvl("shadow_veil") > 0 and kills >= 2:
		main.hero.invuln = maxf(float(main.hero.invuln), val("shadow_veil"))
		main.vfx.smoke(pos, 0.5, 6)
	if lvl("water_tide") > 0:
		var td := val("water_tide") * _wave_mult()
		main.vfx.water_burst(pos, 1.75)
		_burst(pos, 2.6, td, 9.0)
	if lvl("water_uzushio") > 0 and combo >= 3:
		_add_whirl(pos)
	if _charge > 0.05:
		var cd := _charge * _bolt_mult()
		_charge = 0.0
		main.vfx.ring(Vector3(pos.x, 0.07, pos.z), Vfx.BOLT, 1.5)
		for o in main.nearest_enemies(pos, 2.2, 99, null):
			main.zap(pos, o.position)
			main.damage_enemy(o, cd)
		main.damage_bosses(pos, 2.2, cd)
	if lvl("wind_fujin") > 0:
		# l'arrivée souffle : repousse et blesse un peu
		main.vfx.ring(Vector3(pos.x, 0.07, pos.z), WIND_COLOR, 1.6)
		main.vfx.swirl(pos, 1.8)
		_burst(pos, 2.4, 0.8, 12.0)
	if lvl("water_kanagawa") > 0 and _strokes % 3 == 0 and _last_pts.size() > 1:
		_add_wave(_last_pts)
	if lvl("bolt_raijin") > 0 and _strokes % 4 == 0:
		_drum()
	if lvl("ink_ippitsu") > 0 and _stroke_hits >= 4:
		_ippitsu_next = true
		main.vfx.ink_wave(pos, 1.6)
		main.shape_text(pos, "筆")
	_ippitsu_now = false


func on_stroke_release(points: PackedVector3Array) -> void:
	_strokes += 1
	_last_pts = points
	_stroke_hits = 0
	_blade_hit.clear()
	_ippitsu_now = _ippitsu_next
	_ippitsu_next = false
	if points.size() < 2:
		return
	var length := _length(points)
	if lvl("fire_trail") > 0:
		_add_trail(points, 3.0, val("fire_trail"))
	if lvl("bolt_charge") > 0:
		_charge += length * val("bolt_charge")
	if lvl("wind_fujin") > 0 and length >= 4.0:
		_fujin_pull(points)
	if lvl("shadow_bunshin") > 0:
		_add_clone(points)


## Forme reconnue (渦 loop, 雷 zigzag, 返 return, 一 straight, 円 enso, 鉤 hook), à l'arrivée de la ruée.
## main : `powers.on_shape(String(sh.shape), sh)` au début de _apply_shape.
func on_shape(shape: String, info: Dictionary) -> void:
	var hp: Vector3 = main.hero.position
	if lvl("ink_enso") > 0 and shape != "enso":
		_ink_wave(hp, 2.2, 1.5)
	match shape:
		"loop":
			if lvl("fire_kasha") > 0:
				var c: Vector3 = info.get("center", hp)
				_add_wheel(Vector3(c.x, 0, c.z))
		"zigzag":
			if lvl("bolt_inazuma") > 0:
				# l'éclair de base frappe les 4 plus proches ; Inazuma continue la chaîne
				var list: Array = main.nearest_enemies(hp, 8.0, 4 + int(val("bolt_inazuma")), null)
				if list.size() > 4:
					main.vfx.school_kanji(hp, "bolt")
				var from := hp
				for i in list.size():
					var o = list[i]
					_stun(o)
					if i >= 4:
						main.zap(from, o.position)
						main.damage_enemy(o, 1.2 * _bolt_mult())
					from = o.position
				main.sfx.play("strike", 1.8, -6.0)


## Atterrissage du bond d'ensō. main : `powers.on_enso_land(hero.position, _enso_r)` à la fin de _on_hero_landed.
func on_enso_land(pos: Vector3, r: float) -> void:
	if lvl("ink_enso") == 0:
		return
	var rr := r * 1.4 + 0.4
	main.vfx.ink_wave(pos, rr / 1.5)
	main.vfx.school_kanji(pos, "ink")
	main.shake = maxf(float(main.shake), 0.6)
	_burst(pos, rr, 2.0, 8.0)
	if _enso_heal_room != _room:
		_enso_heal_room = _room
		main.heal(1)
	_add_inkring(pos, minf(rr, 4.0))


## Bond d'esquive. main : `powers.on_dodge(origin, end)` juste après `_launch(s)` dans la branche d'esquive.
func on_dodge(from: Vector3, to: Vector3) -> void:
	if lvl("wind_tsumuji") == 0:
		return
	var d := val("wind_tsumuji") * (1.5 if lvl("wind_feather") > 0 else 1.0)
	_whirl_burst(from, 1.5, d)
	_whirl_burst(to, 1.5, d)


## Coup reçu (après l'écume) : renvoie true pour l'annuler (Utsusemi, renaissance de Hōō).
## main : `if powers.on_hurt(): return` juste avant `hero.hurt()` dans _hurt_hero.
func on_hurt() -> bool:
	var h = main.hero
	if _utsu_left > 0 and lvl("shadow_utsusemi") > 0:
		_utsu_left -= 1
		h.invuln = maxf(float(h.invuln), 1.0)
		var p: Vector3 = h.position
		_shell(p)
		main.shape_text(p, "逃")
		main.shake = maxf(float(main.shake), 0.3)
		main.sfx.play("whoosh", 0.7)
		var d := val2("shadow_utsusemi")
		for o in main.nearest_enemies(p, 2.4, 99, null):
			main.vfx.shadow_stab(p, o.position)
			main.damage_enemy(o, d)
		main.damage_bosses(p, 2.4, d)
		return true
	if lvl("fire_hoo") > 0 and not _hoo_used and int(h.hp) <= 1:
		_hoo_used = true
		h.hp = mini(3, int(h.max_hp))
		h.invuln = 2.5
		var p2: Vector3 = h.position
		main.shape_text(p2, "鳳")
		# renaissance : grande couronne de flammes et braises
		main.vfx.fire_burst(p2, 2.4)
		main.vfx.ring(Vector3(p2.x, 0.1, p2.z), Vfx.FIRE_HOT, 1.5)
		main.vfx.embers(p2, 0.8, 10)
		main.splash(p2, Vfx.FIRE_HOT, 14)
		main.splash(p2, Vfx.FIRE, 14)
		main.shake = 0.7
		main.sfx.play("strike", 0.6)
		main.float_text(p2, "+%d" % int(h.hp), Toon.VERMILION)
		for o in main.nearest_enemies(p2, 3.5, 99, null):
			_ignite(o, 1.0, 4.0)
			main.damage_enemy(o, 3.0)
		main.damage_bosses(p2, 3.5, 3.0)
		return true
	return false


## Début de salle (facultatif : update le détecte tout seul). main : `powers.on_room_start(room)` dans _begin_room.
func on_room_start(r: int) -> void:
	if r == _room:
		return
	_room = r
	_utsu_left = int(val("shadow_utsusemi"))
	_foam_seen = int(main.foam)
	_charge = 0.0
	_burn.clear()
	_clear_burn_fx()
	_boss_burn.clear()
	_trails.clear()
	_fox_cd.clear()
	_raiju_t = minf(_raiju_t, 2.0)
	for z in _zones:
		if is_instance_valid(z["node"]):
			z["node"].queue_free()
	_zones.clear()
	for s in _sweeps:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	_sweeps.clear()
	if _tier_of("water") >= 2 and r > 1:
		main.heal(1)


# ------------------------------------------------------------------ boucle de jeu

func update(dt: float) -> void:
	if main == null or not is_instance_valid(main.hero):
		return
	var r := int(main.room)
	if r != _room:
		on_room_start(r)
	_update_burns(dt)
	_update_trails(dt)
	_watch_foam()
	var hero = main.hero
	if bool(hero.dashing):
		if lvl("wind_blades") > 0:
			_blades(hero.position)
		if lvl("water_mirror") > 0:
			_mirror(hero.position)
	if lvl("fire_fudo") > 0:
		_aura(dt, hero.position)
	if lvl("shadow_kitsunebi") > 0:
		_fox_hits(dt, hero)
	if lvl("bolt_raiju") > 0:
		_raiju(dt, hero.position)
	_update_zones(dt)
	_update_sweeps(dt)


func _update_burns(dt: float) -> void:
	var fm := _fire_mult()
	for k in _burn.keys():
		var b: Array = _burn[k]
		var e = b[0]
		b[1] = float(b[1]) - dt
		if not is_instance_valid(e) or e.dead or float(b[1]) <= 0.0:
			_burn.erase(k)
			_drop_burn_fx(k)
			continue
		main.damage_enemy(e, float(b[2]) * fm * dt, false)
	for i in range(_boss_burn.size() - 1, -1, -1):
		var bb: Array = _boss_burn[i]
		bb[1] = float(bb[1]) - dt
		if float(bb[1]) <= 0.0:
			_boss_burn.remove_at(i)
		else:
			main.damage_bosses(bb[0], 1.5, float(bb[2]) * fm * dt, false)


## Sillages de feu : 4 ticks par seconde.
func _update_trails(dt: float) -> void:
	var fm := _fire_mult()
	for i in range(_trails.size() - 1, -1, -1):
		var t: Array = _trails[i]
		t[1] = float(t[1]) - dt
		t[2] = float(t[2]) + dt
		if float(t[1]) <= 0.0:
			_trails.remove_at(i)
			continue
		if float(t[2]) >= 0.25:
			t[2] = 0.0
			var pts: PackedVector3Array = t[0]
			var d := float(t[3]) * fm * 0.25
			for e in main.enemies:
				if _alive(e) and _near_line(e.position, pts, 0.6 + float(e.radius)):
					main.damage_enemy(e, d, false)
			main.damage_bosses_line(pts, 0.6, d, false)


func _add_trail(points: PackedVector3Array, dur: float, dps: float) -> void:
	if _trails.size() >= 8:
		_trails.remove_at(0)
	_trails.append([points, dur, 0.0, dps])
	main.fire_trail_fx(points, dur)


## Écume : quand un coup est bu, elle éclate autour du héros.
func _watch_foam() -> void:
	var f := int(main.foam)
	if f < _foam_seen and lvl("water_foam") > 0:
		var p: Vector3 = main.hero.position
		main.vfx.water_burst(p, 1.5)
		_burst(p, 2.2, val2("water_foam") * _wave_mult(), 10.0)
	_foam_seen = f


## Kamaitachi : pendant la ruée, les lames de vent tranchent ce qui passe à côté.
func _blades(p: Vector3) -> void:
	var d := val("wind_blades")
	for e in main.enemies:
		if not _alive(e):
			continue
		var eid: int = e.get_instance_id()
		if _blade_hit.has(eid):
			continue
		if Vector2(e.position.x - p.x, e.position.z - p.z).length() < 1.75 + float(e.radius):
			_blade_hit[eid] = true
			main.damage_enemy(e, d)
			# lame de vent : croissant jade
			main.vfx.wind_slash(e.position, e.position - p)


## Kagami : la ruée renvoie les boules qu'elle frôle vers l'ennemi le plus proche.
func _mirror(p: Vector3) -> void:
	var r := val("water_mirror")
	for b in main.bullets:
		if bool(b.get("friendly", false)):
			continue
		var n: Node3D = b["node"]
		if Vector2(n.position.x - p.x, n.position.z - p.z).length() >= r:
			continue
		var v: Vector3 = b["vel"]
		var speed := maxf(v.length(), 3.0) * 1.4
		var near: Array = main.nearest_enemies(n.position, 9.0, 1, null)
		if near.is_empty():
			b["vel"] = -v.normalized() * speed
		else:
			var o = near[0]
			var to: Vector3 = o.position - n.position
			to.y = 0
			b["vel"] = to.normalized() * speed
		b["friendly"] = true
		main.splash(n.position, Vfx.WATER, 5)
		main.vfx.ring(Vector3(n.position.x, 0.07, n.position.z), Vfx.WATER, 0.6)


## Fudō Myōō : halo de flammes, 4 ticks par seconde.
func _aura(dt: float, p: Vector3) -> void:
	_aura_t -= dt
	if _aura_t > 0.0:
		return
	_aura_t = 0.25
	var dmg := val("fire_fudo") * 0.25 * _fire_mult()
	var dps := maxf(1.0 if lvl("fire_edge") > 0 else 0.6, val("fire_burn"))
	for o in main.nearest_enemies(p, 2.0, 99, null):
		_ignite(o, dps, 2.0)
		main.damage_enemy(o, dmg, false)
	main.damage_bosses(p, 1.9, dmg, false)


## Kitsunebi : trois feux follets en orbite ; chaque ennemi touché attend 0.5 s avant le suivant.
func _fox_hits(dt: float, hero) -> void:
	_fox_ang += dt * (5.5 if bool(hero.dashing) else 2.6)
	for k in _fox_cd.keys():
		_fox_cd[k] = float(_fox_cd[k]) - dt
		if float(_fox_cd[k]) <= 0.0:
			_fox_cd.erase(k)
	var c: Vector3 = hero.position
	_fox_pos.clear()
	for i in 3:
		var a := _fox_ang + TAU * float(i) / 3.0
		_fox_pos.append(c + Vector3(cos(a), 0, sin(a)) * 1.45)
	var ignite := lvl("fire_burn") > 0
	for e in main.enemies:
		if not _alive(e):
			continue
		var eid: int = e.get_instance_id()
		if _fox_cd.has(eid):
			continue
		for fp in _fox_pos:
			if Vector2(e.position.x - fp.x, e.position.z - fp.z).length() < 0.45 + float(e.radius):
				_fox_cd[eid] = 0.5
				main.damage_enemy(e, 1.0)
				if ignite:
					_ignite(e, val("fire_burn"), 3.0)
				break
	_fox_boss_t -= dt
	if _fox_boss_t <= 0.0:
		_fox_boss_t = 0.5
		for fp in _fox_pos:
			main.damage_bosses(fp, 0.6, 0.8)


## Raijū : le loup-tonnerre frappe l'ennemi le plus proche à intervalle régulier.
func _raiju(dt: float, p: Vector3) -> void:
	_raiju_t -= dt
	if _raiju_t > 0.0:
		return
	_raiju_t = val("bolt_raiju")
	var dmg := 2.0 * _bolt_mult()
	var near: Array = main.nearest_enemies(p, 9.0, 1, null)
	if not near.is_empty():
		var o = near[0]
		_bolt_strike(o.position, true)
		_stun(o)
		main.damage_enemy(o, dmg)
		return
	var hits: Array = main.damage_bosses(p, 8.0, dmg)
	if not hits.is_empty():
		_bolt_strike(hits[0], true)
	else:
		_raiju_t = 0.6  # personne à portée : on réessaie bientôt


## Raijin : le tambour frappe chaque ennemi qui prépare une attaque (étourdi), sinon les deux plus proches.
func _drum() -> void:
	var p: Vector3 = main.hero.position
	var dmg := 2.0 * _bolt_mult()
	var targets: Array = []
	for e in main.enemies:
		if not _alive(e):
			continue
		var z: Array = e.danger_zone()
		if not z.is_empty():
			targets.append(e)
	if targets.is_empty():
		targets = main.nearest_enemies(p, 7.0, 2, null)
	for o in targets:
		_bolt_strike(o.position, false)
		_stun(o)
		main.damage_enemy(o, dmg)
	var hits: Array = main.damage_bosses(p, 7.0, dmg)
	for i in mini(2, hits.size()):
		_bolt_strike(hits[i], false)
	_drum_pulse = 1.0
	main.vfx.school_kanji(p, "bolt")
	main.shake = maxf(float(main.shake), 0.3)
	main.sfx.play("strike", 1.3, -2.0)


## Fūjin : avant la ruée, les ennemis proches du trait sont aspirés vers sa ligne.
func _fujin_pull(points: PackedVector3Array) -> void:
	var hurt := lvl("wind_blades") > 0
	for e in main.enemies:
		if not _alive(e):
			continue
		var q := _closest_on_line(e.position, points)
		var d := Vector3(q.x - e.position.x, 0, q.z - e.position.z)
		var dist := d.length()
		if dist < 4.0 and dist > 0.25:
			e.position += d / dist * minf(1.8, dist - 0.2)
			if hurt:
				main.damage_enemy(e, 0.5, false)
	var step := maxi(1, points.size() / 4)
	for i in range(0, points.size(), step):
		main.vfx.swirl(points[i], 0.7)
	main.vfx.school_kanji(points[points.size() - 1], "wind")


## Dégâts et recul en cercle autour de `p` (ennemis et boss).
func _burst(p: Vector3, r: float, dmg: float, push: float) -> void:
	for o in main.nearest_enemies(p, r, 99, null):
		var away: Vector3 = o.position - p
		away.y = 0
		if away.length_squared() > 0.0001:
			o.push(away.normalized() * push)
		main.damage_enemy(o, dmg)
	main.damage_bosses(p, r, dmg)


## Ensō parfait : onde d'encre (chaque forme), qui brûle avec Foyer.
func _ink_wave(p: Vector3, r: float, dmg: float) -> void:
	main.vfx.ink_wave(p, r / 1.5)
	if lvl("fire_hearth") > 0:
		for o in main.nearest_enemies(p, r, 99, null):
			_ignite(o, maxf(val("fire_burn"), 0.6), 3.0)
	_burst(p, r, dmg, 6.0)


func _whirl_burst(p: Vector3, r: float, dmg: float) -> void:
	# tourbillon tranchant : spirale jade et lames de vent
	main.vfx.swirl(p, r)
	main.vfx.wind_slash(p, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 1.1)
	_burst(p, r, dmg, 7.0)


func _ignite(e, dps: float, dur: float) -> void:
	if not _alive(e):
		return
	var eid: int = e.get_instance_id()
	if _burn.has(eid):
		var b: Array = _burn[eid]
		b[1] = maxf(float(b[1]), dur)
		b[2] = maxf(float(b[2]), dps)
	else:
		_burn[eid] = [e, dur, dps]
	if not _burn_fx.has(eid) or not is_instance_valid(_burn_fx[eid]):
		# l'ennemi en feu porte de petites flammes (un seul émetteur par ennemi)
		_burn_fx[eid] = main.vfx.burner(e, 0.25, 4, Vector3(0, 0.3, 0))


## Visuel de brûlure : retiré quand la brûlure s'arrête.
func _drop_burn_fx(eid) -> void:
	if not _burn_fx.has(eid):
		return
	var n = _burn_fx[eid]
	if is_instance_valid(n):
		n.queue_free()
	_burn_fx.erase(eid)


func _clear_burn_fx() -> void:
	for k in _burn_fx.keys():
		var n = _burn_fx[k]
		if is_instance_valid(n):
			n.queue_free()
	_burn_fx.clear()


## Étourdit (garde ouverte, attaque annulée) ; la brute reste inarrêtable.
func _stun(e) -> void:
	if _alive(e) and String(e.kind) != "brute":
		e.shield_break()


func _alive(e) -> bool:
	return is_instance_valid(e) and not e.dead and not e.is_harmless()


# ------------------------------------------------------------------ zones (roue, tourbillon, encre)

func _add_wheel(p: Vector3) -> void:
	_trim_zones("wheel", 3)
	var node := Node3D.new()
	_holder().add_child(node)
	node.position = Vector3(p.x, 0.55, p.z)
	var spin := Node3D.new()
	node.add_child(spin)
	var ring := _part(spin, _torus(), main.vfx.glow_mat(FLAME_COLOR, 2.8))
	ring.rotation.z = PI / 2.0
	ring.scale = Vector3(0.55, 0.9, 0.55)
	_part(spin, _sphere(), main.vfx.glow_mat(Vfx.FIRE_HOT, 2.0)).scale = Vector3.ONE * 1.4
	# la roue crache des flammes en roulant
	main.vfx.burner(node, 0.4, 7, Vector3(0, -0.45, 0))
	var dur := 3.5 + (0.5 if lvl("fire_trail") > 0 else 0.0)
	_zones.append({"kind": "wheel", "pos": Vector3(p.x, 0, p.z), "t": dur, "tick": 0.0, "r": 1.3,
		"dps": val("fire_kasha") * _fire_mult(), "node": node, "spin": spin, "drop": 0.0, "last": Vector3(p.x, 0, p.z)})
	main.sfx.play("whoosh", 0.6)


func _add_whirl(p: Vector3) -> void:
	_trim_zones("whirl", 2)
	var node := Node3D.new()
	_holder().add_child(node)
	node.position = Vector3(p.x, 0.0, p.z)
	# tourbillon d'eau : fond bleu, bord cyan, spirales d'écume
	var pool := _part(node, _disc_mesh(), _flat("whirl", Color(Vfx.WATER, 0.28)))
	pool.scale = Vector3(2.2, 1, 2.2)
	pool.position.y = 0.05
	var spin := Node3D.new()
	node.add_child(spin)
	var edge := _part(spin, _torus(), main.vfx.glow_mat(Vfx.WATER, 1.8))
	edge.scale = Vector3(2.2, 0.05, 2.2)
	edge.position.y = 0.07
	var sw := _part(spin, main.vfx.swirl_mesh(), main.vfx.glow_mat(Vfx.WATER_FOAM, 1.6))
	sw.scale = Vector3(1.9, 1, 1.9)
	sw.position.y = 0.09
	main.vfx.school_kanji(p, "water")
	var dur := 3.0 + (1.0 if lvl("water_tide") > 0 else 0.0)
	_zones.append({"kind": "whirl", "pos": Vector3(p.x, 0, p.z), "t": dur, "tick": 0.0, "r": 2.2,
		"dps": val("water_uzushio") * _wave_mult(), "node": node, "spin": spin})
	main.vfx.water_burst(p, 1.6)


func _add_inkring(p: Vector3, r: float) -> void:
	_trim_zones("ink", 1)
	var node := Node3D.new()
	_holder().add_child(node)
	node.position = Vector3(p.x, 0.0, p.z)
	var pool := _part(node, _disc_mesh(), _flat("inkpool", Color(Toon.SUMI, 0.22)))
	pool.scale = Vector3(r, 1, r)
	pool.position.y = 0.05
	var spin := Node3D.new()
	node.add_child(spin)
	var ring := _part(spin, _torus(), _ink_mat())
	ring.scale = Vector3(r, 0.06, r)
	ring.position.y = 0.05
	_zones.append({"kind": "ink", "pos": Vector3(p.x, 0, p.z), "t": 4.0, "tick": 0.0, "r": r,
		"dps": 1.2, "node": node, "spin": spin})


func _trim_zones(kind: String, keep: int) -> void:
	var n := 0
	for i in range(_zones.size() - 1, -1, -1):
		if String(_zones[i]["kind"]) != kind:
			continue
		n += 1
		if n >= keep:
			var node: Node3D = _zones[i]["node"]
			if is_instance_valid(node):
				node.queue_free()
			_zones.remove_at(i)


func _update_zones(dt: float) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		var z: Dictionary = _zones[i]
		var node: Node3D = z["node"]
		z["t"] = float(z["t"]) - dt
		if float(z["t"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_zones.remove_at(i)
			continue
		var kind := String(z["kind"])
		var pos: Vector3 = z["pos"]
		var r: float = z["r"]
		if kind == "wheel":
			# la roue file vers l'ennemi le plus proche
			var near: Array = main.nearest_enemies(pos, 8.0, 1, null)
			if not near.is_empty():
				var o = near[0]
				var dv: Vector3 = o.position - pos
				dv.y = 0
				var dl := dv.length()
				if dl > 0.1:
					pos += dv / dl * minf(4.0 * dt, dl)
					node.rotation.y = atan2(-dv.x, -dv.z)
			z["pos"] = pos
			if lvl("fire_trail") > 0:
				z["drop"] = float(z["drop"]) + dt
				if float(z["drop"]) >= 0.5:
					z["drop"] = 0.0
					var last: Vector3 = z["last"]
					if last.distance_to(pos) > 0.3:
						_add_trail(PackedVector3Array([last, pos]), 2.0, val("fire_trail"))
					z["last"] = pos
		elif kind == "whirl":
			for e in main.enemies:
				if not _alive(e) or String(e.kind) == "funa":
					continue
				var dv2 := Vector3(pos.x - e.position.x, 0, pos.z - e.position.z)
				var dl2 := dv2.length()
				if dl2 < r + 1.0 and dl2 > 0.35:
					e.position += dv2 / dl2 * minf(2.2 * dt, dl2 - 0.3)
		z["tick"] = float(z["tick"]) - dt
		if float(z["tick"]) <= 0.0:
			z["tick"] = 0.25
			var dmg := float(z["dps"]) * 0.25
			for o2 in main.nearest_enemies(pos, r, 99, null):
				if kind == "wheel":
					_ignite(o2, maxf(val("fire_burn"), 0.5), 2.0)
				elif kind == "ink" and lvl("fire_hearth") > 0:
					_ignite(o2, 0.6, 2.0)
				main.damage_enemy(o2, dmg, false)
			main.damage_bosses(pos, r, dmg, false)
		node.position = Vector3(pos.x, node.position.y, pos.z)


# ------------------------------------------------------------------ balayages (vague, clone)

func _add_wave(points: PackedVector3Array) -> void:
	var node := Node3D.new()
	_holder().add_child(node)
	var wall := _part(node, _box(), _flat("wave", Color("#1668B0", 0.88)))
	wall.scale = Vector3(2.6, 0.75, 0.45)
	wall.position = Vector3(0, 0.38, 0)
	var crest := _part(node, _box(), main.vfx.glow_mat(Vfx.WATER_FOAM, 1.4))
	crest.scale = Vector3(2.9, 0.2, 0.6)
	crest.position = Vector3(0, 0.8, -0.1)
	var dmg := (3.0 + (1.0 if lvl("water_push") > 0 else 0.0)) * _wave_mult()
	_sweeps.append(_sweep(points, "wave", node, 22.0, 0.0, 1.3, dmg))
	main.shape_text(points[0], "波")
	main.sfx.play("whoosh", 0.5)
	main.shake = maxf(float(main.shake), 0.35)


func _add_clone(points: PackedVector3Array) -> void:
	var node := Node3D.new()
	_holder().add_child(node)
	var m := _flat("clone", Color(0.07, 0.06, 0.11, 0.72))
	var body := _part(node, _capsule(), m)
	body.position = Vector3(0, 0.72, 0)
	var head := _part(node, _sphere(), m)
	head.scale = Vector3.ONE * 2.0
	head.position = Vector3(0, 1.42, 0)
	var blade := _part(node, _box(), main.vfx.glow_mat(FOX_COLOR, 2.2))
	blade.scale = Vector3(0.05, 0.05, 1.0)
	blade.position = Vector3(0.35, 0.9, -0.35)
	blade.rotation.y = 0.5
	node.visible = false
	var dmg := 1.2 * float(main.chain_mult())
	_sweeps.append(_sweep(points, "clone", node, DASH_SPEED * dash_mult(), 0.35, 0.6, dmg))


func _sweep(points: PackedVector3Array, kind: String, node: Node3D, speed: float, delay: float, r: float, dmg: float) -> Dictionary:
	var cum := PackedFloat32Array()
	cum.append(0.0)
	for i in range(1, points.size()):
		cum.append(cum[i - 1] + points[i].distance_to(points[i - 1]))
	node.position = points[0]
	return {"pts": points, "cum": cum, "i": 0, "d": 0.0, "total": cum[cum.size() - 1], "speed": speed,
		"delay": delay, "r": r, "dmg": dmg, "hit": {}, "boss_done": false, "node": node, "kind": kind,
		"prev": points[0], "fx": 0.0}


func _update_sweeps(dt: float) -> void:
	for i in range(_sweeps.size() - 1, -1, -1):
		var s: Dictionary = _sweeps[i]
		var node: Node3D = s["node"]
		if not is_instance_valid(node):
			_sweeps.remove_at(i)
			continue
		var kind := String(s["kind"])
		if float(s["delay"]) > 0.0:
			s["delay"] = float(s["delay"]) - dt
			if float(s["delay"]) <= 0.0:
				node.visible = true
				if kind == "clone":
					main.vfx.smoke(node.position, 0.35, 5)
				if kind == "clone" and lvl("fire_trail") > 0:
					_add_trail(s["pts"], 2.5, val("fire_trail"))
			continue
		var a: Vector3 = s["prev"]
		s["d"] = float(s["d"]) + float(s["speed"]) * dt
		var b := _advance(s)
		s["prev"] = b
		var dir := b - a
		dir.y = 0
		var hit: Dictionary = s["hit"]
		var r: float = s["r"]
		var dmg: float = s["dmg"]
		for e in main.enemies:
			if not _alive(e):
				continue
			var eid: int = e.get_instance_id()
			if hit.has(eid):
				continue
			if _seg_dist(e.position, a, b) < r + float(e.radius):
				hit[eid] = true
				if kind == "wave":
					var side := Vector3(-dir.z, 0, dir.x).normalized()
					if side.dot(e.position - b) < 0.0:
						side = -side
					e.push(side * 10.0 + dir.normalized() * 4.0)
					main.damage_enemy(e, dmg)
				else:
					main.damage_enemy(e, dmg * _global_mult())
					main.vfx.smoke(e.position, 0.25, 4)
		if not bool(s["boss_done"]):
			var bh: Array = main.damage_bosses(b, r + 0.3, dmg)
			if not bh.is_empty():
				s["boss_done"] = true
		if kind == "wave":
			s["fx"] = float(s["fx"]) + dt
			if float(s["fx"]) >= 0.12:
				s["fx"] = 0.0
				main.splash(b, Vfx.WATER_FOAM, 4)
				main.splash(b, Vfx.WATER, 3)
		node.position = Vector3(b.x, 0, b.z)
		if dir.length_squared() > 0.0001:
			node.rotation.y = atan2(-dir.x, -dir.z)
		if float(s["d"]) >= float(s["total"]):
			node.queue_free()
			_sweeps.remove_at(i)


## Avance le long de la polyligne d'un balayage ; renvoie le point atteint.
func _advance(s: Dictionary) -> Vector3:
	var pts: PackedVector3Array = s["pts"]
	var cum: PackedFloat32Array = s["cum"]
	var d: float = s["d"]
	var i: int = s["i"]
	while i < pts.size() - 1 and cum[i + 1] < d:
		i += 1
	s["i"] = i
	if i >= pts.size() - 1:
		return pts[pts.size() - 1]
	var seg := cum[i + 1] - cum[i]
	var k := 0.0
	if seg > 0.0001:
		k = clampf((d - cum[i]) / seg, 0.0, 1.0)
	return pts[i].lerp(pts[i + 1], k)


# ------------------------------------------------------------------ visuels

func _holder() -> Node3D:
	if not is_instance_valid(_root):
		_root = Node3D.new()
		_root.name = "PowerFx"
		add_child(_root)
	return _root


## Crée les visuels permanents des légendaires possédés (halo, tambours, vent, feux follets).
func _ensure_visuals() -> void:
	if main == null:
		return
	if lvl("fire_fudo") > 0 and not is_instance_valid(_halo):
		_halo = Node3D.new()
		_holder().add_child(_halo)
		var glow := _part(_halo, _disc_mesh(), _flat("halo", Color(Vfx.FIRE, 0.1)))
		glow.scale = Vector3(1.9, 1, 1.9)
		glow.position.y = 0.05
		var ring := _part(_halo, _torus(), main.vfx.glow_mat(FLAME_COLOR, 2.4))
		ring.scale = Vector3(1.9, 0.06, 1.9)
		ring.position.y = 0.07
		_flames.clear()
		# langues de flamme face caméra qui vacillent sur le cercle
		var tongue: Mesh = main.vfx.flame_mesh()
		for k in 8:
			var a := TAU * float(k) / 8.0
			var col := Vfx.FIRE_HOT if k % 2 == 0 else FLAME_COLOR
			var f := _part(_halo, tongue, main.vfx.flame_mat(col))
			f.position = Vector3(cos(a) * 1.9, 0.1, sin(a) * 1.9)
			_flames.append(f)
	if lvl("bolt_raijin") > 0 and not is_instance_valid(_drums):
		_drums = Node3D.new()
		_holder().add_child(_drums)
		var spin := Node3D.new()
		spin.name = "Spin"
		_drums.add_child(spin)
		var band := _part(spin, _torus(), main.vfx.glow_mat(Vfx.BOLT, 1.8))
		band.scale = Vector3(0.85, 0.04, 0.85)
		for k in 8:
			var a2 := TAU * float(k) / 8.0
			var dr := _part(spin, _drum_mesh(), main.vfx.glow_mat(Vfx.BOLT if k % 2 == 0 else Toon.GOLD, 2.2))
			dr.position = Vector3(cos(a2) * 0.85, 0, sin(a2) * 0.85)
			dr.rotation.y = -a2
			dr.rotation.z = PI / 2.0
	if lvl("wind_fujin") > 0 and not is_instance_valid(_gale):
		_gale = Node3D.new()
		_holder().add_child(_gale)
		for k in 2:
			var ring2 := _part(_gale, _torus(), main.vfx.glow_mat(WIND_COLOR, 1.6))
			ring2.scale = Vector3(1.0 + 0.3 * k, 0.04, 1.0 + 0.3 * k)
			ring2.rotation = Vector3(0.45 - 0.9 * k, 0, 0.3)
	if lvl("shadow_kitsunebi") > 0 and _foxes.is_empty():
		for k in 3:
			var fox := Node3D.new()
			_holder().add_child(fox)
			_part(fox, _sphere(), main.vfx.glow_mat(FOX_COLOR, 3.0)).scale = Vector3(1.6, 2.0, 1.6)
			_part(fox, _sphere(), main.vfx.glow_mat(Color(1, 1, 1), 3.0)).scale = Vector3.ONE * 0.8
			_foxes.append(fox)


func _process(delta: float) -> void:
	if main == null or _root == null:
		return
	var dt := UiKit.unscaled(delta, 0.05)
	if dt <= 0.0:
		return
	_anim += dt
	var h = main.hero
	if not is_instance_valid(h):
		return
	# hors partie (accueil, résultats) : les visuels des pouvoirs se cachent
	_root.visible = String(main.state) in ["play", "transit", "pick", "dying", "tuto", "paused"]
	var hp: Vector3 = h.position
	if is_instance_valid(_halo):
		_halo.position = Vector3(hp.x, 0, hp.z)
		_halo.rotation.y += dt * 1.1
		for k in _flames.size():
			var f: Node3D = _flames[k]
			var flick := 0.8 + 0.35 * sin(_anim * 9.0 + float(k) * 1.7)
			f.scale = Vector3(0.9, 0.9 * flick, 0.9)
	if is_instance_valid(_drums):
		_drum_pulse = maxf(0.0, _drum_pulse - dt * 3.0)
		_drums.position = hp + Vector3(0, 1.75, 0.25)
		_drums.rotation.x = 0.5
		_drums.scale = Vector3.ONE * (1.0 + 0.35 * _drum_pulse)
		var spin: Node3D = _drums.get_node("Spin")
		spin.rotation.y += dt * (0.8 + 6.0 * _drum_pulse)
	if is_instance_valid(_gale):
		_gale.position = hp + Vector3(0, 0.9, 0)
		_gale.rotation.y += dt * 7.0
	if not _foxes.is_empty():
		for k in _foxes.size():
			var fox: Node3D = _foxes[k]
			if not is_instance_valid(fox):
				continue
			var fp: Vector3 = hp
			if k < _fox_pos.size():
				fp = _fox_pos[k]
			else:
				var a := _fox_ang + TAU * float(k) / 3.0
				fp = hp + Vector3(cos(a), 0, sin(a)) * 1.45
			fox.position = fp + Vector3(0, 0.95 + 0.12 * sin(_anim * 4.0 + float(k) * 2.1), 0)
			fox.scale = Vector3.ONE * (0.9 + 0.15 * sin(_anim * 13.0 + float(k)))
	for z in _zones:
		var sp: Node3D = z.get("spin")
		if is_instance_valid(sp):
			match String(z["kind"]):
				"wheel":
					sp.rotation.x -= dt * 10.0
				"whirl":
					sp.rotation.y += dt * 5.0
				_:
					sp.rotation.y += dt * 0.8
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Dictionary = _fx[i]
		var node: Node3D = fx["node"]
		fx["t"] = float(fx["t"]) + dt
		var k2: float = float(fx["t"]) / float(fx["life"])
		if not is_instance_valid(node) or k2 >= 1.0:
			if is_instance_valid(node):
				node.queue_free()
			_fx.remove_at(i)
			continue
		match String(fx["kind"]):
			"bolt":
				var thin := 1.0 - k2
				node.scale = Vector3(thin, 1.0, thin)
			"spin":
				node.rotation.y += dt * 14.0
				node.scale = Vector3.ONE * (0.6 + 0.8 * k2)
			"shell":
				node.scale = Vector3.ONE * (1.0 - 0.6 * k2)
				node.position.y = -0.8 * k2


## Éclair vertical qui tombe du ciel sur `p`.
func _bolt_strike(p: Vector3, big: bool) -> void:
	# éclair brisé qui tombe du ciel, flash, anneau jaune, petite brûlure au sol
	main.vfx.sky_bolt(p, big)
	if big:
		main.sfx.play("strike", 1.7, -4.0)


## Utsusemi : la mue d'ombre laissée à la place du héros.
func _shell(p: Vector3) -> void:
	var node := Node3D.new()
	_holder().add_child(node)
	node.position = Vector3(p.x, 0, p.z)
	var m := _flat("clone", Color(0.07, 0.06, 0.11, 0.72))
	_part(node, _capsule(), m).position = Vector3(0, 0.72, 0)
	var head := _part(node, _sphere(), m)
	head.scale = Vector3.ONE * 2.0
	head.position = Vector3(0, 1.42, 0)
	_fx.append({"node": node, "t": 0.0, "life": 0.7, "kind": "shell"})
	main.vfx.smoke(p, 0.5, 8)


func _part(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# maillages partagés (unitaires, mis à l'échelle sur les nœuds)
func _torus() -> Mesh:
	if not _cache.has("torus"):
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 32
		t.ring_segments = 4
		_cache["torus"] = t
	return _cache["torus"]


func _sphere() -> Mesh:
	if not _cache.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 0.1
		s.height = 0.2
		s.radial_segments = 10
		s.rings = 5
		_cache["sphere"] = s
	return _cache["sphere"]


func _box() -> Mesh:
	if not _cache.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_cache["box"] = b
	return _cache["box"]


func _capsule() -> Mesh:
	if not _cache.has("capsule"):
		var c := CapsuleMesh.new()
		c.radius = 0.28
		c.height = 1.1
		c.radial_segments = 10
		c.rings = 3
		_cache["capsule"] = c
	return _cache["capsule"]


func _disc_mesh() -> Mesh:
	if not _cache.has("disc"):
		_cache["disc"] = Toon.cyl(1.0, 1.0, 0.004, 24)
	return _cache["disc"]


func _drum_mesh() -> Mesh:
	if not _cache.has("drum"):
		var c := CylinderMesh.new()
		c.top_radius = 0.13
		c.bottom_radius = 0.13
		c.height = 0.1
		c.radial_segments = 12
		c.rings = 1
		_cache["drum"] = c
	return _cache["drum"]


func _flat(key: String, c: Color) -> StandardMaterial3D:
	var k := "mat_" + key
	if not _cache.has(k):
		_cache[k] = Toon.flat(c)
	return _cache[k]


func _ink_mat() -> StandardMaterial3D:
	return _flat("ink", Color(Toon.SUMI, 0.85))


# ------------------------------------------------------------------ géométrie

func _length(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var seg := b - a
	var t := 0.0
	if seg.length_squared() > 0.0001:
		t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var q := a + seg * t
	return Vector2(p.x - q.x, p.z - q.z).length()


func _closest_on_line(p: Vector3, pts: PackedVector3Array) -> Vector3:
	var best := pts[0]
	var bd := INF
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := b - a
		var t := 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var q := a + seg * t
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < bd:
			bd = d
			best = q
	return best


func _near_line(p: Vector3, pts: PackedVector3Array, r: float) -> bool:
	for i in range(1, pts.size()):
		if _seg_dist(p, pts[i - 1], pts[i]) < r:
			return true
	return false
