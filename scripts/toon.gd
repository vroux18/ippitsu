extends RefCounted
## Palette, matériaux cartoon à contour d'encre et petites briques de modélisation.

const WASHI := Color("#EFE6D2")
const SUMI := Color("#1B1A1E")
const VERMILION := Color("#D7372B")
const PRUSSIAN := Color("#1F3A5F")
const FOAM := Color("#E9EEF0")
const GOLD := Color("#C49A45")
const SKIN := Color("#F2D7B6")
const WOOD := Color("#CDB78E")
const PAPER := Color("#F5EEDD")  # cartes et feuilles de l'interface
const VEIL := Color("#110E11")  # voile d'encre derrière les fenêtres

# thème de l'interface (garde-robe) : papier des cartes, lavis des fonds, encre du texte
static var ui_paper := PAPER
static var ui_wash := WASHI
static var ui_ink := SUMI
static var ui_dark := false  # papier sombre, encre claire (Nuit) : les accents foncés passent au clair
static var ui_rev := 0  # change à chaque thème : les écrans qui ne se redessinent pas seuls le guettent

# rendu allégé (téléphone) : posé par main avant de bâtir le monde ; coupe grain, détails des shaders, poussières
static var lite := false

static var _blob_mesh: PlaneMesh = null
static var _blob_tex: GradientTexture2D = null
static var _blob_mats := {}  # alpha ("%.2f") -> matériau
static var _brush: ShaderMaterial = null


## Thème choisi (meta.theme_colors()) : {paper, wash, ink}.
static func set_ui_theme(d: Dictionary) -> void:
	ui_paper = d.get("paper", PAPER)
	ui_wash = d.get("wash", WASHI)
	ui_ink = d.get("ink", SUMI)
	ui_dark = ui_ink.get_luminance() > ui_paper.get_luminance()
	ui_rev += 1


# caches partagés (voir mat_shared, outline_mat, sphere…) : bornés, vidés quand ils débordent
# (les objets en service restent vivants par leurs utilisateurs, seules les clés sont oubliées)
static var _mesh_cache := {}  # dimensions (float : sphère, Vector2 : capsule, Vector3 : boîte, Vector4 : cylindre) -> maillage
static var _outlines := {}  # épaisseur -> passe de contour d'encre (jamais modifiée par les appelants)
static var _mat_cache := {}  # couleur + contour -> matériau toon figé
const CACHE_MAX := 4096


## Passe de contour d'encre (coque inversée gonflée de `size`), partagée par épaisseur : aucun appelant
## ne modifie cette passe, seul le matériau de base est propre à chacun.
static func outline_mat(size: float) -> StandardMaterial3D:
	var key := "%.4f" % size
	if _outlines.has(key):
		var cached: StandardMaterial3D = _outlines[key]
		return cached
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = SUMI
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = size
	_outlines[key] = o
	return o


## Matériau toon neuf (l'appelant peut le modifier : flash, lueur, couleurs de sommets…) ; sa passe de
## contour est partagée. Pour une pièce qui ne bouge jamais de couleur, préférer mat_shared.
static func mat(color: Color, outline := true, outline_size := 0.035) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if outline:
		m.next_pass = outline_mat(outline_size)
	return m


## Même matériau que mat(), mais partagé par couleur et contour : à réserver aux pièces dont le
## matériau n'est jamais retouché après coup (une modification toucherait toutes les pièces de même clé).
static func mat_shared(color: Color, outline := true, outline_size := 0.035) -> StandardMaterial3D:
	var key := "%s%d%.4f" % [color.to_html(true), 1 if outline else 0, outline_size]
	if _mat_cache.has(key):
		var cached: StandardMaterial3D = _mat_cache[key]
		return cached
	if _mat_cache.size() >= CACHE_MAX:
		_mat_cache.clear()
	var m := mat(color, outline, outline_size)
	_mat_cache[key] = m
	return m


## Aplat sans lumière, neuf (souvent fondu ou recoloré par l'appelant).
static func flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Les primitives sont partagées par dimensions (aucun appelant ne les modifie après coup) : même
## géométrie, un seul maillage envoyé au GPU par taille. Cache borné : des dimensions tirées au sort
## (débris, éclats) ne le font pas grossir sans fin.
static func _mesh_room() -> void:
	if _mesh_cache.size() >= CACHE_MAX:
		_mesh_cache.clear()


static func sphere(r: float) -> SphereMesh:
	var key := r  # clés sans texte (float, Vector2/3/4) : la recherche coûte moins que la création
	if _mesh_cache.has(key):
		var cached: SphereMesh = _mesh_cache[key]
		return cached
	_mesh_room()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	_mesh_cache[key] = m
	return m


static func capsule(r: float, h: float) -> CapsuleMesh:
	var key := Vector2(r, h)
	if _mesh_cache.has(key):
		var cached: CapsuleMesh = _mesh_cache[key]
		return cached
	_mesh_room()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	_mesh_cache[key] = m
	return m


static func box(size: Vector3) -> BoxMesh:
	var key := size
	if _mesh_cache.has(key):
		var cached: BoxMesh = _mesh_cache[key]
		return cached
	_mesh_room()
	var m := BoxMesh.new()
	m.size = size
	_mesh_cache[key] = m
	return m


static func cyl(top: float, bottom: float, h: float, sides := 16) -> CylinderMesh:
	var key := Vector4(top, bottom, h, float(sides))
	if _mesh_cache.has(key):
		var cached: CylinderMesh = _mesh_cache[key]
		return cached
	_mesh_room()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	_mesh_cache[key] = m
	return m


## Disque plat posé au sol (ombre, tache d'encre, zone d'attaque).
static func disc(parent: Node3D, r: float, color: Color, y := 0.01) -> MeshInstance3D:
	var d := part(parent, cyl(r, r, 0.004, 24), flat(color), Vector3(0, y, 0))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d


## Plan unité (2 × 2) pour les ombres douces.
static func blob_mesh() -> PlaneMesh:
	if _blob_mesh == null:
		_blob_mesh = PlaneMesh.new()
		_blob_mesh.size = Vector2(2.0, 2.0)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 64
		_blob_tex.height = 64
	return _blob_mesh


## Ombre douce (dégradé radial d'encre), partagée par opacité.
static func blob_mat(alpha: float) -> StandardMaterial3D:
	blob_mesh()
	var key := "%.2f" % alpha
	if _blob_mats.has(key):
		var cached: StandardMaterial3D = _blob_mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.04, 0.035, 0.05, alpha)
	m.albedo_texture = _blob_tex
	m.render_priority = -1
	_blob_mats[key] = m
	return m


## Ombre de contact douce posée au sol (personnages) : plus dense au centre, sans bord dur.
static func blob(parent: Node3D, r: float, alpha: float, y := 0.012) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = blob_mesh()
	mi.material_override = blob_mat(alpha)
	mi.position = Vector3(0, y, 0)
	mi.scale = Vector3(r, 1.0, r)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Matériau des traînées au pinceau (couleurs de sommets, poils qui s'effilochent), partagé.
static func brush_mat() -> ShaderMaterial:
	if _brush == null:
		_brush = ShaderMaterial.new()
		_brush.shader = load("res://shaders/brush.gdshader")
		_brush.set_shader_parameter("dry", 0.45 if lite else 0.8)
	return _brush


## Distance au sol (plan XZ, y ignoré) du point `p` au segment [a, b] (boss, pouvoirs).
static func seg_dist_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var seg := b - a
	var t := 0.0
	if seg.length_squared() > 0.0001:
		t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var q := a + seg * t
	return Vector2(p.x - q.x, p.z - q.z).length()


# ------------------------------------------------------------------ chargement en arrière-plan

static var _asked := {}  # chemin -> true : chargement en arrière-plan demandé, pas encore récupéré


## Lance le chargement de `path` sur un fil d'arrière-plan (sans effet s'il est déjà en mémoire ou demandé).
static func request(path: String) -> void:
	if _asked.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_asked[path] = true


## La ressource `path`, prête : attend la fin de son chargement en arrière-plan s'il a été demandé,
## sinon la charge tout de suite.
static func fetch(path: String) -> Resource:
	if _asked.has(path):
		_asked.erase(path)
		var r := ResourceLoader.load_threaded_get(path)
		if r != null:
			return r
	return load(path)
