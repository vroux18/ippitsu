extends Node3D
## Portes à deux sceaux (fin d'étape, façon Hades) : deux torii côte à côte au bout de l'étape, chacun
## portant un sceau (médaillon de washi suspendu au linteau, sans texte) qui annonce la récompense de
## l'étape suivante. PHASE 1 (maquette) : visuel seul, posé par la capture `?room=N&portes=fire,gold`
## (main.gd) ; aucune mécanique.
##
## Sceaux (`kinds`) : une école ("fire", "water", "bolt", "wind", "shadow", "ink", "fig") -> rouleau de
## cette école ; "gold" -> koban (grosse somme d'or) ; "heart" -> source de soin ; "oni" -> combat d'élite
## et rouleau rare ou épique garanti.
##
## Lecture (gabarit validé avec Victor, Seal.dc.html) : anneau sumi, disque washi, filet de la couleur du
## sceau, glyphe au centre ; dos de laque comme le torii de sortie ; incliné vers la caméra plongeante (54°)
## pour se lire en entier. Le seul vermillon est le petit glyphe du feu, sur washi cerné de sumi, en hauteur :
## rien à voir avec un disque d'annonce au sol.
##
## Approche (`hover`, 0..1 par porte) : quand le héros s'approche d'un torii, son sceau grossit (×1,22), s'éclaire,
## son halo s'ouvre ; les ofuda des piliers s'allument, la corde luit, des rayons coulent sous l'arche.

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

const SCHOOLS := ["fire", "water", "bolt", "wind", "shadow", "ink", "fig"]
const GATE_DX := 2.3  # demi-écart des deux torii (m) : l'arène visible fait ±4.6
const GATE_K := 1.15  # torii des portes : celui de sortie, un peu agrandi (les sceaux se lisent mieux)
const SEAL_R := 0.62  # rayon du sceau (repère du torii de sortie ; × GATE_K en mètres)
const SEAL_Y := 1.55  # centre du sceau, devant le linteau
const PIVOT_Y := 1.9  # point d'attache des cordons, sur la face du kasagi
const SEAL_TILT := 0.62  # inclinaison vers la caméra (rad, ~35°)
const FACE_PX := 256  # côté de la texture d'un sceau
const NEAR := 3.2  # distance (m) où l'approche commence
const NEAR_FULL := 1.3  # distance où le sceau est pleinement éveillé

# luminosité du sceau par monde (non éclairé, il garde sa lecture partout ; juste accordé à la lumière du
# monde, pleine à l'approche)
const WORLD_LUM := {1: 1.0, 2: 0.88, 3: 0.95, 4: 0.9, 5: 0.97, 6: 0.94, 7: 0.9, 8: 0.86}

var world_id := 1
var kinds: Array = ["fire", "gold"]
var hero: Node3D = null  # héros suivi (approche) ; null : aucune approche
var hover_force := -1  # maquette : porte forcée en état « approché » (-1 : selon la distance du héros)
var hover: Array = [0.0, 0.0]  # éveil de chaque porte (0..1), lissé
var _gates: Array = []  # par porte : {root, pivot, seal, halo, halo_mat, face_mat, ofuda, rope, rays, ray_mat, ph}
var _t := 0.0


## Construit les deux portes centrées sur (0, gate_z) ; `arena` : pour le chemin d'encre qui bifurque (points
## posés sur la terre ferme seulement) et les paliers sous les torii hors de la terre ferme.
func build(arena: Node, gate_z: float, from: Vector3) -> void:
	for i in 2:
		var g := _build_gate(i, String(kinds[i]), Vector3((-1.0 if i == 0 else 1.0) * GATE_DX, 0, gate_z), arena)
		_gates.append(g)
	_fork_path(arena, gate_z, from)


func _build_gate(i: int, kind: String, pos: Vector3, arena: Node) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	# palier de pierre sous le torii s'il déborde de la terre ferme (la maquette ne change pas la forme)
	if arena != null and arena.has_method("walkable") and not bool(arena.call("walkable", pos + Vector3(0, 0, 0.3), 0.9)):
		var slab := Toon.part(root, Toon.box(Vector3(2.9, 0.5, 1.6)), Toon.mat_shared(Color("#5E5753")), Vector3(0, -0.23, -0.15))
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# corps de la porte : le torii de sortie (échelle 0.55, mêmes repères que arena._build_gate), agrandi de GATE_K
	var body := Node3D.new()
	root.add_child(body)
	body.scale = Vector3.ONE * GATE_K
	var t := Decor.torii(body, Vector3(0, 0, -0.3), 0.55, true)
	t.visible = true
	var g := {"root": root, "ph": float(i) * 1.9, "kind": kind}
	# ofuda des piliers (éteints, ils s'allument à l'approche)
	var ofuda: Array = []
	var seal_mesh := Toon.box(Vector3(0.085, 0.17, 0.012))
	for row in 3:
		for sx: float in [-1.0, 1.0]:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("#E9DEC4")
			m.emission_enabled = true
			m.emission = glow(kind)
			m.emission_energy_multiplier = 0.0
			var mi := Toon.part(body, seal_mesh, m, Vector3(sx * 1.21, 0.42 + 0.33 * row, -0.19))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ofuda.append(m)
	g["ofuda"] = ofuda
	# shimenawa sous le nuki
	var rope_m := StandardMaterial3D.new()
	rope_m.albedo_color = Color("#D9C38C")
	rope_m.emission_enabled = true
	rope_m.emission = Color("#FFD27A")
	rope_m.emission_energy_multiplier = 0.0
	var rope := Toon.part(body, Toon.cyl(0.042, 0.042, 2.3, 8), rope_m, Vector3(0, 1.17, -0.3))
	rope.rotation.z = PI / 2.0
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g["rope"] = rope_m
	# rayons sous l'arche (approche)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.vertex_color_use_as_albedo = true
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.albedo_color = Color(1, 1, 1, 0.0)
	var gc := glow(kind)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_c := Color(gc.lerp(Color(1, 0.95, 0.8), 0.5), 0.4)
	var low_c := Color(gc, 0.0)
	for xc: float in [-0.55, -0.18, 0.18, 0.55]:
		var a := Vector3(xc - 0.12, 1.5, -0.32)
		var b := Vector3(xc + 0.12, 1.5, -0.32)
		var wb := 0.36 + absf(xc) * 0.3
		var c := Vector3(xc * 1.6 + wb, 0.03, 2.6)
		var d := Vector3(xc * 1.6 - wb, 0.03, 2.6)
		for v in [[a, top_c], [b, top_c], [c, low_c], [a, top_c], [c, low_c], [d, low_c]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var rays := MeshInstance3D.new()
	rays.mesh = st.commit()
	rays.material_override = rm
	rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rays.visible = false
	body.add_child(rays)
	g["rays"] = rays
	g["ray_mat"] = rm
	# sceau : pivot au point d'attache (sous le kasagi), il se balance ; disque incliné vers la caméra
	var pivot := Node3D.new()
	body.add_child(pivot)
	pivot.position = Vector3(0, PIVOT_Y, 0.02)
	g["pivot"] = pivot
	var lacquer := Toon.mat_shared(Color("#2A2428"), false)
	var gold := Toon.mat_shared(UIColors.GOLD_DARK, false)
	# cordons d'attache (deux brins d'or) jusqu'au haut du sceau
	var drop := PIVOT_Y - SEAL_Y - SEAL_R * 0.92
	for sx: float in [-0.16, 0.16]:
		var cord := Toon.part(pivot, Toon.cyl(0.014, 0.014, drop + 0.08, 5), gold, Vector3(sx, -drop * 0.5 + 0.02, 0.0))
		cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var seal := Node3D.new()
	pivot.add_child(seal)
	seal.position = Vector3(0, SEAL_Y - PIVOT_Y, 0.06)
	seal.rotation.x = -SEAL_TILT
	g["seal"] = seal
	# halo (derrière, gabarit : disques r58 à 22 % et r52 à 28 % de la couleur d'approche), dos de laque, face
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SEAL_R * 120.0 / 46.0  # le viewBox 120 entier ; l'anneau sumi r46 = SEAL_R
	var halo_m := StandardMaterial3D.new()
	halo_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	halo_m.albedo_texture = _halo_tex()
	halo_m.albedo_color = Color(glow(kind), 0.0)
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	halo.material_override = halo_m
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0, 0, -0.05)
	seal.add_child(halo)
	g["halo_mat"] = halo_m
	var back := Toon.part(seal, Toon.cyl(SEAL_R, SEAL_R, 0.06, 28), lacquer, Vector3(0, 0, -0.025))
	back.rotation.x = PI / 2.0
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var face_m := StandardMaterial3D.new()
	face_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face_m.alpha_scissor_threshold = 0.5
	face_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face_m.albedo_texture = face_tex(kind)
	var lum: float = float(WORLD_LUM.get(world_id, 1.0))
	face_m.albedo_color = Color(lum, lum, lum)
	g["lum"] = lum
	var face := MeshInstance3D.new()
	face.mesh = quad
	face.material_override = face_m
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.position = Vector3(0, 0, 0.012)
	seal.add_child(face)
	g["face_mat"] = face_m
	return g


## Chemin d'encre qui bifurque : un tronc depuis le héros, puis une branche vers chaque torii.
func _fork_path(arena: Node, gate_z: float, from: Vector3) -> void:
	var fork := Vector3(0, 0, gate_z + 3.6)
	var m := Toon.flat(Color(Toon.SUMI, 0.62))
	var disc := Toon.cyl(1.0, 1.0, 0.004, 10)
	var legs: Array = [[Vector3(from.x, 0, maxf(from.z, fork.z + 0.8)), fork]]
	for i in 2:
		legs.append([fork, Vector3((-1.0 if i == 0 else 1.0) * GATE_DX, 0, gate_z + 0.7)])
	for leg in legs:
		var a: Vector3 = leg[0]
		var b: Vector3 = leg[1]
		var d := b - a
		var n := int(d.length() / 0.5)
		if n < 1:
			continue
		var side := Vector3(-d.z, 0, d.x).normalized()
		for k in range(0, n + 1):
			var p := a + d * (float(k) / float(n)) + side * (0.1 if k % 2 == 0 else -0.1)
			if arena != null and arena.has_method("walkable") and not bool(arena.call("walkable", p, 0.05)):
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = disc
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.position = Vector3(p.x, 0.022, p.z)
			mi.rotation.y = randf() * PI
			var s := randf_range(0.1, 0.13)
			mi.scale = Vector3(s, 1, s * 1.25)


func _process(delta: float) -> void:
	_t += delta
	for i in _gates.size():
		var g: Dictionary = _gates[i]
		var root: Node3D = g["root"]
		var want := 0.0
		if hover_force >= 0:
			want = 1.0 if hover_force == i else 0.0
		elif hero != null and is_instance_valid(hero):
			var dd := Vector2(hero.global_position.x - root.global_position.x, hero.global_position.z - root.global_position.z - 0.6).length()
			want = clampf((NEAR - dd) / (NEAR - NEAR_FULL), 0.0, 1.0)
		var h: float = move_toward(float(hover[i]), want, delta * 3.0)
		hover[i] = h
		var e := h * h * (3.0 - 2.0 * h)
		var ph: float = g["ph"]
		# balancement : léger au repos, plus vif quand le héros approche (le sceau « appelle »)
		var pivot: Node3D = g["pivot"]
		pivot.rotation.z = sin(_t * 1.25 + ph) * (0.045 + 0.03 * e)
		pivot.rotation.x = sin(_t * 0.9 + ph * 1.3) * 0.03
		var seal: Node3D = g["seal"]
		seal.scale = Vector3.ONE * (1.0 + 0.22 * e + 0.02 * sin(_t * 2.2 + ph))  # approché : ×1,22
		# le sceau s'avance un peu vers la caméra (il sort du linteau)
		seal.position = Vector3(0, SEAL_Y - PIVOT_Y - 0.08 * e, 0.06 + 0.25 * e)
		var hm: StandardMaterial3D = g["halo_mat"]
		# lueur douce au repos (un tiers, qui respire), pleine à l'approche
		hm.albedo_color.a = (0.3 + 0.1 * sin(_t * 1.7 + ph)) * (1.0 - e) + e
		var fm: StandardMaterial3D = g["face_mat"]
		var lum: float = g["lum"]
		var l := minf(1.0, lum + (1.0 - lum) * e)
		fm.albedo_color = Color(l, l, l)
		var k := 0
		for om: StandardMaterial3D in g["ofuda"]:
			om.emission_energy_multiplier = 2.2 * clampf(e * 1.6 - 0.1 * k, 0.0, 1.0)
			k += 1
		var rp: StandardMaterial3D = g["rope"]
		rp.emission_energy_multiplier = 1.1 * e
		var rays: MeshInstance3D = g["rays"]
		rays.visible = e > 0.02
		var rmat: StandardMaterial3D = g["ray_mat"]
		rmat.albedo_color = Color(1, 1, 1, e * (0.8 + 0.2 * sin(_t * 1.6 + ph)))


# ------------------------------------------------------------------ textures (peintes une fois, en cache)

static var _halo: Texture2D = null


## Halo du gabarit : disques blancs r58 (22 %) et r52 (28 %), teintés par le matériau.
static func _halo_tex() -> Texture2D:
	if _halo == null:
		_halo = UiKit.svg_tex('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">'
			+ '<circle cx="60" cy="60" r="58" fill="#FFFFFF" opacity="0.22"/><circle cx="60" cy="60" r="52" fill="#FFFFFF" opacity="0.28"/></svg>',
			128.0, {}, "seal_halo")
	return _halo


## Clé du gabarit de sceau (maquette validée, Seal.dc.html) pour un type de sceau du jeu.
static func seal_key(kind: String) -> String:
	if kind in SCHOOLS:
		var e := UIColors.element_of(kind)
		return "encre" if e == "neutre" else e
	match kind:
		"gold":
			return "or"
		"heart":
			return "coeur"
	return kind


## Couleur du sceau (filet et glyphe), gabarit validé.
const SEAL_COL := {"feu": "#D7372B", "eau": "#1F3A5F", "foudre": "#C49A45", "vent": "#5F8F86", "ombre": "#3A3846",
	"encre": "#6E5A44", "figure": "#A8436B", "or": "#C49A45", "coeur": "#C8463A", "oni": "#3A3846"}

## Glyphes du gabarit 120 (chemins SVG exacts de la maquette ; %s = couleur du sceau).
const SEAL_GLYPH := {
	"feu": '<path d="M60 34 C70 48 76 54 76 66 A16 16 0 0 1 44 66 C44 56 52 52 52 44 C56 50 58 50 60 34 Z" fill="%s"/><path d="M60 56 C64 62 67 64 67 69 A7 7 0 0 1 53 69 C53 64 57 62 60 56 Z" fill="#F2A33A"/>',
	"eau": '<path d="M36 70 C38 54 50 45 62 47 C73 49 78 59 72 64 C66 68 59 62 64 57" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><path d="M34 80 C44 74 52 84 62 78 C70 74 76 78 84 78" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round"/>',
	"foudre": '<path d="M65 32 L47 63 L59 63 L53 88 L75 55 L63 55 L70 32 Z" fill="%s" stroke="#1B1A1E" stroke-width="1.5" stroke-linejoin="round"/>',
	"vent": '<path d="M38 58 C36 44 54 38 62 46 C67 52 61 60 54 56" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round"/><path d="M36 68 L82 68" stroke="%s" stroke-width="5" stroke-linecap="round"/><path d="M44 79 L74 79" stroke="%s" stroke-width="5" stroke-linecap="round"/>',
	"ombre": '<path d="M68 34 A27 27 0 1 0 85 74 A21 21 0 1 1 68 34 Z" fill="%s"/>',
	"encre": '<path d="M60 32 C67 45 75 53 75 64 A15 15 0 0 1 45 64 C45 53 53 45 60 32 Z" fill="%s"/><path d="M54 64 A6 6 0 0 0 60 70" fill="none" stroke="#F5EEDD" stroke-width="3" stroke-linecap="round"/>',
	"figure": '<path d="M60 60 m-4 0 a4 4 0 1 1 8 0 a10 10 0 1 1 -19 -3 a18 18 0 1 1 33 11" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round"/>',
	"or": '<ellipse cx="60" cy="60" rx="18" ry="25" fill="#1B1A1E"/><ellipse cx="60" cy="60" rx="16" ry="23" fill="#E2A93B"/><ellipse cx="60" cy="60" rx="12" ry="19" fill="none" stroke="#1B1A1E" stroke-opacity="0.45" stroke-width="1.6"/><rect x="55" y="45" width="10" height="9" fill="#1B1A1E" fill-opacity="0.7"/><rect x="54.5" y="61" width="11" height="2.6" fill="#1B1A1E" fill-opacity="0.7"/><rect x="54.5" y="67" width="11" height="2.6" fill="#1B1A1E" fill-opacity="0.7"/>',
	"coeur": '<path d="M60 84 C45 72 37 63 37 52 A11.5 11.5 0 0 1 60 47 A11.5 11.5 0 0 1 83 52 C83 63 75 72 60 84 Z" fill="%s"/><path d="M50 54 A6 6 0 0 1 55 49" fill="none" stroke="#F5EEDD" stroke-width="3" stroke-linecap="round"/>',
	"oni": '<path d="M44 48 L40 30 L53 43 Z" fill="#C49A45" stroke="#1B1A1E" stroke-width="1.5" stroke-linejoin="round"/><path d="M76 48 L80 30 L67 43 Z" fill="#C49A45" stroke="#1B1A1E" stroke-width="1.5" stroke-linejoin="round"/><path d="M40 52 C40 40 80 40 80 52 C80 72 70 84 60 84 C50 84 40 72 40 52 Z" fill="%s"/><path d="M46 56 L56 60 L46 62 Z" fill="#E2A93B"/><path d="M74 56 L64 60 L74 62 Z" fill="#E2A93B"/><path d="M50 72 L54 69 L58 72 L62 69 L66 72 L70 69" fill="none" stroke="#F5EEDD" stroke-width="2.4" stroke-linejoin="round"/>',
}


## Face d'un sceau (gabarit 120 : anneau sumi r46, disque washi r42, filet r36.5 de 3, glyphe), rastérisée
## par UiKit.svg_tex (cache partagé) ; la face 3D couvre le viewBox entier (le disque fait 46/60 du quad).
static func face_tex(kind: String, px := FACE_PX) -> Texture2D:
	var k := seal_key(kind)
	var col := String(SEAL_COL.get(k, "#1B1A1E"))
	var g := String(SEAL_GLYPH.get(k, ""))
	g = g.replace("%s", col)
	var src := '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">' \
		+ '<circle cx="60" cy="60" r="46" fill="#1B1A1E"/><circle cx="60" cy="60" r="42" fill="#F5EEDD"/>' \
		+ '<circle cx="60" cy="60" r="36.5" fill="none" stroke="%s" stroke-width="3"/>' % col + g + '</svg>'
	return UiKit.svg_tex(src, px, {}, "seal_" + k)


## Couleur du halo d'approche : or pour l'or, la foudre et l'oni, sinon la couleur du sceau.
static func glow(kind: String) -> Color:
	var k := seal_key(kind)
	if k in ["or", "foudre", "oni"]:
		return Color("#E2A93B")
	return Color(String(SEAL_COL.get(k, "#1B1A1E")))


## Maquette (captures) : `?room=N&portes=fire,gold[&proche]` remplace la sortie de l'étape en cours par
## les deux torii à sceaux ; `&proche` pose le héros devant la porte gauche (état « approché »).
static func mock(main: Node, q: String) -> void:
	var arena: Node = main.get("arena")
	var zones: Array = arena.get("zones")
	for zi in zones.size():
		arena.call("clear_zone", zi)
	var old: Node3D = arena.get("_gate")
	if old != null and is_instance_valid(old):
		old.visible = false
	var ks: Array = ["fire", "gold"]
	var at := q.find("portes=")
	if at >= 0:
		var arg := q.substr(at + 7).get_slice("&", 0)
		var parts := arg.split(",", false)
		if parts.size() >= 2:
			ks = [parts[0], parts[1]]
	var sg: Node3D = load("res://scripts/seal_gate.gd").new()
	sg.set("world_id", int(arena.get("world_id")))
	sg.set("kinds", ks)
	var holder: Node3D = arena.get("_room_root")
	holder.add_child(sg)
	var gp: Vector3 = arena.get("gate_pos")
	var hero: Node3D = main.get("hero")
	var hp := Vector3(-GATE_DX, 0, gp.z + 1.9) if "proche" in q else Vector3(0, 0, gp.z + 6.5)
	hero.position = arena.call("clamp_walk", hp, 0.5)
	sg.call("build", arena, gp.z, hero.position)
	sg.set("hero", hero)
	main.set("_prev_hero", hero.position)
	var dz: float = main.call("_cam_target")
	main.set("_cam_dz", dz)
	arena.call("follow_camera", dz)
