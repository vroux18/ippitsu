extends Node
## Améliorations (« rouleaux ») choisies entre les salles : données + effets.
## Ids et valeurs issus de design/UNIVERS.md §4 (premier lot du monde 1).
## `main` appelle les hooks : on_hit, on_kill, on_dash_end, on_stroke_release, update.

const Toon = preload("res://scripts/toon.gd")

const SCHOOLS := {
	"fire": {"kanji": "火", "color": Color("#D7372B")},
	"water": {"kanji": "水", "color": Color("#1F3A5F")},
	"bolt": {"kanji": "雷", "color": Color("#C49A45")},
	"wind": {"kanji": "風", "color": Color("#7FA39C")},
	"shadow": {"kanji": "影", "color": Color("#3A3846")},
}

# rouleaux qui n'ont de sens qu'avec un autre déjà pris
const NEEDS := {"fire_edge": "fire_burn"}
# texte : « {v} » remplacé par la valeur du niveau suivant
const DATA := {
	"fire_trail": {"school": "fire", "name": "Sillage", "text": "Le trait laisse du feu ({v} dégâts/s)", "v": [0.6, 0.9, 1.2]},
	"fire_burn": {"school": "fire", "name": "Braise", "text": "Les ennemis tranchés brûlent ({v}/s)", "v": [0.5, 0.8, 1.1]},
	"fire_hearth": {"school": "fire", "name": "Foyer", "text": "Cercle de feu à l'arrivée ({v} dégâts)", "v": [1.0, 1.5, 2.0]},
	"fire_edge": {"school": "fire", "name": "Lame rouge", "text": "+{v} % dégâts sur les ennemis en feu", "v": [30, 45, 60]},
	"water_push": {"school": "water", "name": "Ressac", "text": "Repousse les ennemis tranchés ({v} m)", "v": [2.5, 3.2, 4.0]},
	"water_foam": {"school": "water", "name": "Écume", "text": "Bouclier d'écume : {v} coup(s) bloqué(s) par salle", "v": [1, 1, 2]},
	"water_dew": {"school": "water", "name": "Rosée", "text": "+1 vie tous les {v} ennemis tués", "v": [12, 10, 8]},
	"bolt_arc": {"school": "bolt", "name": "Arc", "text": "Chaque coup foudroie {v} ennemi(s) proche(s)", "v": [1, 2, 3]},
	"bolt_storm": {"school": "bolt", "name": "Orage", "text": "Toutes les {v} touches, la foudre frappe 3 ennemis", "v": [8, 6, 4]},
	"bolt_quick": {"school": "bolt", "name": "Vif", "text": "Ruée {v} % plus rapide", "v": [20, 30, 40]},
	"wind_long": {"school": "wind", "name": "Souffle long", "text": "+{v} m de trait", "v": [3, 5, 7]},
	"wind_gust": {"school": "wind", "name": "Bourrasque", "text": "Élan {v} % plus rapide", "v": [30, 45, 60]},
	"wind_feather": {"school": "wind", "name": "Plume", "text": "Bond d'esquive gratuit et plus long ({v} m)", "v": [3.2, 3.6, 4.0]},
	"shadow_back": {"school": "shadow", "name": "Ushiro", "text": "Dans le dos : dégâts ×{v}", "v": [2.0, 2.5, 3.0]},
	"shadow_step": {"school": "shadow", "name": "Pas d'ombre", "text": "Après une esquive : intouchable {v} s", "v": [0.5, 0.8, 1.1]},
	"shadow_veil": {"school": "shadow", "name": "Voile", "text": "2 ennemis d'un trait : intouchable {v} s", "v": [0.6, 0.9, 1.2]},
}

var main: Node3D
var levels := {}  # id -> niveau (1..3)
var _burn := {}  # instance_id -> [ennemi, temps restant]
var _trails: Array = []  # [points, temps restant, tick]
var _kills := 0
var _hits := 0  # touches, pour l'orage
var _boss_burn: Array = []  # [point, temps restant] : braise sur un boss


func reset() -> void:
	levels.clear()
	_burn.clear()
	_trails.clear()
	_boss_burn.clear()
	_kills = 0
	_hits = 0


func lvl(id: String) -> int:
	return int(levels.get(id, 0))


func val(id: String) -> float:
	var l := lvl(id)
	if l == 0:
		return 0.0
	return float(DATA[id].v[l - 1])


func add(id: String) -> void:
	levels[id] = mini(lvl(id) + 1, 3)


## Trois rouleaux au hasard parmi ceux qui ne sont pas au niveau max (une seule fois chacun).
## Si on en possède déjà, l'un des trois en améliore un : les builds montent vraiment de niveau.
func offer() -> Array:
	var owned: Array = []
	var pool: Array = []
	for id in DATA.keys():
		if lvl(id) >= 3 or (NEEDS.has(id) and lvl(String(NEEDS[id])) == 0):
			continue
		if lvl(id) > 0:
			owned.append(id)
		else:
			pool.append(id)
	owned.shuffle()
	pool.shuffle()
	var out: Array = []
	if not owned.is_empty():
		out.append(owned.pop_front())
	var rest: Array = pool + owned
	rest.shuffle()
	for id in rest:
		if out.size() >= 3:
			break
		out.append(id)
	out.shuffle()
	return out


func describe(id: String) -> Dictionary:
	var d: Dictionary = DATA[id]
	var next := mini(lvl(id) + 1, 3)
	var v = d.v[next - 1]
	var shown := str(v) if typeof(v) == TYPE_INT or float(v) != floorf(float(v)) else str(int(v))
	var school: Dictionary = SCHOOLS[d.school]
	return {"name": d.name, "text": String(d.text).replace("{v}", shown), "level": next,
		"kanji": school.kanji, "color": school.color}


# ------------------------------------------------------------------ statistiques

func elan_bonus() -> float:
	return val("wind_long")


func regen_mult() -> float:
	return 1.0 + val("wind_gust") / 100.0


func dash_mult() -> float:
	return 1.0 + val("bolt_quick") / 100.0


func dodge_cost(base: float) -> float:
	return 0.0 if lvl("wind_feather") > 0 else base


func foam_per_room() -> int:
	return int(val("water_foam"))


func dodge_dist(base: float) -> float:
	return val("wind_feather") if lvl("wind_feather") > 0 else base


# ------------------------------------------------------------------ hooks

## Modifie les dégâts d'un coup de trait et applique les effets de touche.
func on_hit(e: Node3D, dmg: float, dir: Vector3) -> float:
	var out := dmg
	if lvl("fire_edge") > 0 and _burn.has(e.get_instance_id()):
		out *= 1.0 + val("fire_edge") / 100.0
	if lvl("shadow_back") > 0:
		var ry: float = e.body.rotation.y
		var fwd := Vector3(-sin(ry), 0, -cos(ry))
		if dir.normalized().dot(fwd) > 0.5:
			out *= val("shadow_back")
			main.float_text(e.position, "×" + str(val("shadow_back")), Toon.GOLD)
	if lvl("fire_burn") > 0:
		_burn[e.get_instance_id()] = [e, 3.0]
	if lvl("water_push") > 0:
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		if side.dot(e.position - main.hero.position) < 0.0:
			side = -side
		e.push(side * val("water_push") * 3.0)
	_storm(e.position)
	if lvl("bolt_arc") > 0:
		var n := int(val("bolt_arc"))
		for o in main.nearest_enemies(e.position, 3.0, n, e):
			main.zap(e.position, o.position)
			main.damage_enemy(o, 0.5)
	return out


## Coup de ruée sur un boss : braise, arc et orage s'appliquent aussi.
func on_boss_hit(pos: Vector3) -> void:
	if lvl("fire_burn") > 0:
		_boss_burn.append([pos, 3.0])
	if lvl("bolt_arc") > 0:
		for o in main.nearest_enemies(pos, 3.0, int(val("bolt_arc")), null):
			main.zap(pos, o.position)
			main.damage_enemy(o, 0.5)
	_storm(pos)


## Orage : toutes les N touches, la foudre tombe sur les 3 ennemis les plus proches.
func _storm(pos: Vector3) -> void:
	if lvl("bolt_storm") == 0:
		return
	_hits += 1
	if _hits % int(val("bolt_storm")) != 0:
		return
	for o in main.nearest_enemies(pos, 7.0, 3, null):
		main.zap(pos, o.position)
		main.damage_enemy(o, 1.0)
	main.damage_bosses(pos, 3.0, 1.0)


func on_kill(_e: Node3D) -> void:
	_kills += 1
	if lvl("water_dew") > 0 and _kills % int(val("water_dew")) == 0:
		main.heal(1)


func on_dash_end(pos: Vector3, kills: int) -> void:
	if lvl("fire_hearth") > 0:
		main.fire_ring(pos, 1.8)
		for o in main.nearest_enemies(pos, 1.8, 99, null):
			main.damage_enemy(o, val("fire_hearth"))
		main.damage_bosses(pos, 1.8, val("fire_hearth"))
	if lvl("shadow_veil") > 0 and kills >= 2:
		main.hero.invuln = maxf(main.hero.invuln, val("shadow_veil"))


func on_stroke_release(points: PackedVector3Array) -> void:
	if lvl("fire_trail") > 0 and points.size() > 1:
		_trails.append([points, 3.0, 0.0])
		main.fire_trail_fx(points, 3.0)


func update(dt: float) -> void:
	# brûlures
	for k in _burn.keys():
		var b: Array = _burn[k]
		var e = b[0]
		b[1] = float(b[1]) - dt
		if not is_instance_valid(e) or e.dead or float(b[1]) <= 0.0:
			_burn.erase(k)
			continue
		main.damage_enemy(e, val("fire_burn") * dt, false)
	for i in range(_boss_burn.size() - 1, -1, -1):
		var bb: Array = _boss_burn[i]
		bb[1] = float(bb[1]) - dt
		if float(bb[1]) <= 0.0:
			_boss_burn.remove_at(i)
		else:
			main.damage_bosses(bb[0], 1.5, val("fire_burn") * dt, false)
	# sillages de feu : 4 ticks par seconde
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
			for e in main.enemies:
				if is_instance_valid(e) and not e.dead and _near_line(e.position, pts, 0.6 + float(e.radius)):
					main.damage_enemy(e, val("fire_trail") * 0.25, false)
			main.damage_bosses_line(pts, 0.6, val("fire_trail") * 0.25, false)


func _near_line(p: Vector3, pts: PackedVector3Array, r: float) -> bool:
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := b - a
		var t := 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var q := a + seg * t
		if Vector2(p.x - q.x, p.z - q.z).length() < r:
			return true
	return false
