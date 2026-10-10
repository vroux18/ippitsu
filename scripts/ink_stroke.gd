extends MeshInstance3D
## Un coup de pinceau d'encre posé au sol : épais au départ, effilé au bout, puis il sèche.
const Perf = preload("res://scripts/perf_probe.gd")  # relevé par image (-- --perf)

const Toon = preload("res://scripts/toon.gd")

const WIDTH := 0.3
const STEP := 0.18
const DRY := Color("#6E6A66")
static var ink := Toon.SUMI  # encre du trait (Atelier), réglée par meta.apply_run_start

var points := PackedVector3Array()
var jitter := PackedFloat32Array()
var length := 0.0
var exhausted := false
var drying := false
var _dry_t := 0.0
var _y := 0.02
var _imesh := ImmediateMesh.new()
var _mat: StandardMaterial3D
var _tip: MeshInstance3D
var _ring: MeshInstance3D
var danger := false
# figure reconnue pendant le tracé : l'encre se teinte légèrement de la couleur de la figure
const FIG_INK := {"loop": Color("#3E9C8C"), "zigzag": Color("#D9A93A"), "return": Color("#3D7EC4"),
	"hook": Color("#8A5BB0"), "straight": Color("#C8463A"), "enso": Color("#C2668F")}
var figure := ""
var probe_len := 0.0  # longueur au dernier test de figure (main)
var raw := PackedVector3Array()  # geste du doigt au sol, sans le rognage des bords (lecture des figures)
var lead_n := -1  # indice du point où le doigt a touché (avant : amorce depuis le héros)
var _col := Color.BLACK
var _goal := Color.BLACK
var _pop := 0.0


func _init(start: Vector3, layer: int) -> void:
	_y = 0.02 + 0.002 * float(layer % 8)
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_col = ink
	_goal = ink
	_mat = Toon.flat(ink)
	_mat.vertex_color_use_as_albedo = true
	material_override = _mat
	_add(Vector3(start.x, 0, start.z))


func _ready() -> void:
	_tip = Toon.disc(self, 0.16, Color(ink, 0.9), _y + 0.002)
	# cercle d'arrivée : là où le héros va s'arrêter (vermillon = zone qui va frapper)
	_ring = Toon.disc(self, 0.55, Color(Toon.SUMI, 0.18), _y + 0.001)
	_rebuild()


func last() -> Vector3:
	return points[points.size() - 1]


func _add(p: Vector3) -> void:
	if points.size() > 0:
		length += p.distance_to(last())
	points.append(p)
	jitter.append(randf_range(0.82, 1.15))


## Étend le trait vers `target`, en dépensant au plus `budget` de longueur.
## Renvoie la longueur réellement ajoutée.
func extend_to(target: Vector3, budget: float) -> float:
	target.y = 0
	var added := 0.0
	var guard := 0
	while guard < 200:
		guard += 1
		var from := last()
		var d := from.distance_to(target)
		if d < STEP:
			break
		var step := minf(STEP, budget - added)
		if step < 0.02:
			exhausted = true
			break
		_add(from + (target - from) / d * step)
		added += step
	if added > 0.0:
		exhausted = false
		_rebuild()
	return added


## Teinte l'encre vers la couleur de `shape` ("" = encre nue). Le changement est fondu en ~0,2 s.
func set_figure(shape: String) -> void:
	if shape == figure:
		return
	figure = shape
	_goal = ink.lerp(FIG_INK[shape], 0.7) if FIG_INK.has(shape) else ink
	if shape != "":
		_pop = 1.0


func start_drying() -> void:
	if drying:
		return
	drying = true
	_rebuild()  # une seule fois : ensuite le séchage ne touche qu'à la matière
	_col = _goal
	_mat.albedo_color = Color(_col.r * _col.r, _col.g * _col.g, _col.b * _col.b, 1.0)
	if _tip:
		_tip.visible = false
		_ring.visible = false


func _process(delta: float) -> void:
	if Perf.on:
		var _pt := Time.get_ticks_usec()
		_process_body(delta)
		Perf.add(&"ink_stroke", _pt)
	else:
		_process_body(delta)


func _process_body(delta: float) -> void:
	if not drying:
		if not _col.is_equal_approx(_goal):
			_col = _col.lerp(_goal, minf(1.0, delta * 10.0))
			if absf(_col.r - _goal.r) + absf(_col.g - _goal.g) + absf(_col.b - _goal.b) < 0.01:
				_col = _goal
			_rebuild()
			if _tip:
				(_tip.material_override as StandardMaterial3D).albedo_color = Color(_col, 0.9)
		_pop = maxf(0.0, _pop - delta * 4.0)
		if _tip:
			_tip.position = last() + Vector3(0, _y + 0.004, 0)
			var pulse := 1.0 + (0.35 * sin(Time.get_ticks_msec() * 0.03) if exhausted else 0.0)
			pulse += 0.9 * _pop  # petit éclat quand la figure est reconnue
			_tip.scale = Vector3(pulse, 1, pulse)
			_ring.position = last() + Vector3(0, _y + 0.002, 0)
			var ring_mat := _ring.material_override as StandardMaterial3D
			ring_mat.albedo_color = Color(Toon.VERMILION, 0.55) if danger else Color(Toon.SUMI, 0.18)
			var rs := 1.0 + (0.15 * sin(Time.get_ticks_msec() * 0.02) if danger else 0.0)
			_ring.scale = Vector3(rs, 1, rs)
		return
	_dry_t += delta
	if _dry_t > 1.6:
		queue_free()
	else:
		# l'encre fraîche est noire, elle pâlit et s'efface en séchant
		var fade := clampf(1.0 - (_dry_t - 0.5) / 1.1, 0.0, 1.0)
		var tint := _col.lerp(DRY, clampf(_dry_t / 0.8, 0.0, 1.0))
		_mat.albedo_color = Color(_col.r * tint.r, _col.g * tint.g, _col.b * tint.b, fade)


func _rebuild() -> void:
	_imesh.clear_surfaces()
	var n := points.size()
	if n < 2:
		return
	# en séchant, la teinte passe par la matière (voir _process) : sommets blancs
	var tint := Color.WHITE if drying else _col
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var s := 0.0
	for i in n:
		var p := points[i]
		if i > 0:
			s += p.distance_to(points[i - 1])
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		var t := b - a
		t.y = 0
		if t.length_squared() < 0.000001:
			t = Vector3.FORWARD
		t = t.normalized()
		var side := Vector3(-t.z, 0, t.x)
		var u := s / maxf(length, 0.001)
		# attaque franche du pinceau, puis s'effile en fin de trait
		var w := WIDTH * jitter[i] * clampf(s / 0.25 + 0.45, 0.0, 1.0) * lerpf(1.0, 0.3, u * u)
		var c := Color(tint, 0.95 - 0.25 * u)
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(Vector3(p.x, _y, p.z) + side * w)
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(Vector3(p.x, _y, p.z) - side * w)
	_imesh.surface_end()
