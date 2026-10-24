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

## Éclat des yeux des monstres (aplats lumineux) : > 1 dans les mondes sombres, les yeux passent le seuil du
## glow et luisent dans la pénombre (main.apply_world -> set_eye_glow).
static var eye_glow := 1.0
static var _eye_mats: Array[WeakRef] = []
static var _hit_glow: StandardMaterial3D = null


## Matière d'yeux lumineux (aplat) inscrite pour suivre l'éclat du monde : `base` est sa couleur d'origine.
## `amp` : part de l'éclat reçue (aplats partagés avec autre chose que des yeux : moins).
static func eye_mat_register(m: BaseMaterial3D, base: Color, amp := 1.0) -> void:
	m.set_meta(&"eye_base", base)
	m.set_meta(&"eye_amp", amp)
	var k := 1.0 + (eye_glow - 1.0) * amp
	m.albedo_color = Color(base.r * k, base.g * k, base.b * k, base.a)
	if _eye_mats.size() >= 256:
		set_eye_glow(eye_glow)  # oublie les matières des monstres disparus
	_eye_mats.append(weakref(m))


static func set_eye_glow(k: float) -> void:
	eye_glow = k
	var keep: Array[WeakRef] = []
	for w in _eye_mats:
		var m := w.get_ref() as BaseMaterial3D
		if m == null:
			continue
		var base: Color = m.get_meta(&"eye_base", Color.WHITE)
		var ka := 1.0 + (k - 1.0) * float(m.get_meta(&"eye_amp", 1.0))
		m.albedo_color = Color(base.r * ka, base.g * ka, base.b * ka, base.a)
		keep.append(w)
	_eye_mats = keep


## Lueur de touche : dégradé radial additif au sol sous un monstre frappé (partagée, jamais modifiée).
static func hit_glow_mat() -> StandardMaterial3D:
	if _hit_glow == null:
		blob_mesh()
		_hit_glow = StandardMaterial3D.new()
		_hit_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hit_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_hit_glow.albedo_texture = _blob_tex
		_hit_glow.albedo_color = Color(1.0, 0.92, 0.78, 0.55)
		_hit_glow.disable_fog = true
		_hit_glow.render_priority = -1
	return _hit_glow


## Largeur de la rampe toon (voir mat) : partagée par les personnages (character.gd) et les rigs.
const TOON_ROUGH := 0.55

## Sens de la lumière du soleil (main : rotation -40°, -38°) : hachures d'ombre des passes d'encre, biseaux du sol.
const SUN_DIR := Vector3(0.47, -0.64, -0.6)
const INK_SHADER = preload("res://shaders/ink_outline.gdshader")
const NOISE_PX := 256  # côté du bruit partagé des matières
const GRAIN_PX := 128  # côté du grain washi
const DECAL_PX := 1024  # côté de l'atlas des marques au sol (16 cases de 256)

# textures partagées des matières, faites par le code : bruit (4 bruits sans couture, un par canal), grain washi,
# atlas des marques peintes au sol. Créées vides et neutres au premier appel ; decor_warm les remplit en place
# (fil d'arrière-plan pour les bruits, SubViewport pour l'atlas) : toutes les matières partagent les mêmes objets.
static var _noise_tex: ImageTexture = null
static var _grain_tex: ImageTexture = null
static var _decal_tex: ImageTexture = null
static var textures_ready := false  # bruit et grain calculés (decor_warm)


## Bruit partagé des shaders (RGBA, NOISE_PX, sans couture, mipmaps) : r = perlin doux, g = perlin plus fin,
## b = cellules (veines, craquelures : distance au bord, sombre sur les lignes), a = grain fin. Une lecture de
## texture remplace quatre hachages par canal dans les shaders (bien moins cher sur téléphone).
static func noise_tex() -> ImageTexture:
	if _noise_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5, 0.5))
		_noise_tex = ImageTexture.create_from_image(img)
	return _noise_tex


## Grain du washi (gris clair, moyenne ~0,93) multiplié sur l'albédo des matières toon (triplanaire monde).
static func grain_tex() -> ImageTexture:
	if _grain_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color(0.95, 0.95, 0.95))
		_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex


## Atlas des marques au sol (kanji au pinceau, seigaiha, asanoha, auréoles, éclaboussures) : rouge = encre.
## Noir tant que decor_warm ne l'a pas peint (jamais sans écran : --headless), le sol reste alors sans marque.
static func decal_tex() -> ImageTexture:
	if _decal_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_L8)
		img.fill(Color.BLACK)
		_decal_tex = ImageTexture.create_from_image(img)
	return _decal_tex


## Calcul des bruits et du grain (fil d'arrière-plan de decor_warm) : [bruit RGBA, grain RGB], avec mipmaps.
static func bake_noise_images() -> Array:
	var n := NOISE_PX
	var chans: Array = []
	# r : perlin fbm doux (plages, usure) ; g : perlin plus fin (fil, grain) ; b : cellules (veines, fissures) ;
	# a : bruit fin presque blanc (mouchetis, étincelles)
	for k in 4:
		var f := FastNoiseLite.new()
		f.seed = 101 + k * 37
		match k:
			0:
				f.noise_type = FastNoiseLite.TYPE_PERLIN
				f.frequency = 0.012
				f.fractal_octaves = 3
			1:
				f.noise_type = FastNoiseLite.TYPE_PERLIN
				f.frequency = 0.045
				f.fractal_octaves = 3
				f.domain_warp_enabled = true
				f.domain_warp_amplitude = 18.0
				f.domain_warp_frequency = 0.02
			2:
				f.noise_type = FastNoiseLite.TYPE_CELLULAR
				f.frequency = 0.03
				f.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
				f.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
				f.fractal_type = FastNoiseLite.FRACTAL_NONE
			_:
				f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
				f.frequency = 0.16
				f.fractal_octaves = 2
		var im := f.get_seamless_image(n, n, false, false, 0.1, true)
		if im.get_format() != Image.FORMAT_L8:
			im.convert(Image.FORMAT_L8)
		chans.append(im.get_data())
	var r: PackedByteArray = chans[0]
	var g: PackedByteArray = chans[1]
	var b: PackedByteArray = chans[2]
	var a: PackedByteArray = chans[3]
	var out := PackedByteArray()
	out.resize(n * n * 4)
	for i in n * n:
		var j := i * 4
		out[j] = r[i]
		out[j + 1] = g[i]
		out[j + 2] = b[i]
		out[j + 3] = a[i]
	var noise := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, out)
	noise.generate_mipmaps()
	# grain : fibres (perlin tordu) et poussière fine, remontés vers le blanc (jamais plus clair que la couleur)
	var gp := GRAIN_PX
	var step := n / gp
	var gd := PackedByteArray()
	gd.resize(gp * gp * 3)
	for y in gp:
		for x in gp:
			var src := (y * step) * n + x * step
			var fib := float(g[src]) / 255.0
			var dust := float(a[src]) / 255.0
			var v := 0.84 + 0.12 * clampf((fib - 0.2) / 0.6, 0.0, 1.0) + 0.05 * dust
			var byte := int(clampf(v, 0.0, 1.0) * 255.0)
			var o := (y * gp + x) * 3
			gd[o] = byte
			gd[o + 1] = byte
			gd[o + 2] = byte
	var grain := Image.create_from_data(gp, gp, false, Image.FORMAT_RGB8, gd)
	grain.generate_mipmaps()
	return [noise, grain]


## Pose les images calculées par bake_noise_images (fil principal).
static func set_noise_images(imgs: Array) -> void:
	noise_tex().set_image(imgs[0])
	grain_tex().set_image(imgs[1])
	textures_ready = true

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
static var _outlines := {}  # épaisseur + hachures -> passe d'encre (jamais modifiée par les appelants)
static var _mat_cache := {}  # couleur + contour -> matériau toon figé
const CACHE_MAX := 4096


## Passe d'encre (shaders/ink_outline.gdshader : coque gonflée de `size`, trait de contour irrégulier sur les
## faces arrière, hachures de gravure sur les faces à l'ombre), partagée par épaisseur et force des hachures :
## aucun appelant ne modifie cette passe, seul le matériau de base est propre à chacun.
static func outline_mat(size: float, hatch := 1.0) -> ShaderMaterial:
	var key := "%.4f_%.2f" % [size, hatch]
	if _outlines.has(key):
		var cached: ShaderMaterial = _outlines[key]
		return cached
	var o := ShaderMaterial.new()
	o.shader = INK_SHADER
	o.set_shader_parameter("size", size)
	o.set_shader_parameter("ink", SUMI)
	o.set_shader_parameter("hatch_k", hatch)
	o.set_shader_parameter("sun_dir", SUN_DIR)
	o.set_shader_parameter("noise", noise_tex())
	_outlines[key] = o
	return o


## Matériau toon neuf (l'appelant peut le modifier : flash, lueur, couleurs de sommets…) ; sa passe de
## contour est partagée. Pour une pièce qui ne bouge jamais de couleur, préférer mat_shared.
static func mat(color: Color, outline := true, outline_size := 0.035) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	# rugosité = largeur de la transition ombre / lumière du toon (smoothstep de -r à r sur N·L) : 0,85 fondait
	# l'ombre propre dans un dégradé mou (volumes plats) ; 0,55 donne une rampe courte mais douce, un vrai côté
	# ombre (teinté par la lumière ambiante du monde : « shade » de worlds.gd), et un reflet toon discret
	m.roughness = TOON_ROUGH
	m.metallic_specular = 0.35
	m.rim_enabled = true
	m.rim = 0.4  # liseré de lumière sur les silhouettes (côté soleil), plus franc
	m.rim_tint = 0.4
	# grain du washi : texture grise partagée, projetée dans le repère du monde (triplanaire, trois lectures) ;
	# elle multiplie la couleur, qui reste la même en moyenne
	m.albedo_texture = grain_tex()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(2.6, 2.6, 2.6)
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
