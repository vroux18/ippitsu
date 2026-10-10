extends Node3D
## Sceau d'un yōkai scellé (enemy.seal_fig, main._spawn_list) : un ofuda (bande de papier) collé au front, qui
## pend devant le visage, tourné vers la caméra ; la figure qui le brise y est peinte en grand à l'encre sumi
## (glyphe UiKit._fsym, rendu une fois en texture), et un hanko vermillon en deux moitiés (même sceau que le
## coffre scellé, puzzle_art.build_seal) est apposé au pied du papier. Pas de texte (UI v2).
## Coup qui ricoche (enemy.take_hit / hurt_dot) : le papier tressaute, la figure rougit, le hanko gonfle.
## Bonne figure (enemy.unseal_kill) : la figure se dore, le hanko se fend et ses moitiés tombent, l'ofuda se
## décolle et s'envole en tournoyant (même geste que l'ofuda du coffre, puzzle_art.unseal).
## Pivot orienté caméra à la main (pas de billboard de matière) : il garde l'échelle de ses parents (préchauffage
## en miniature de main._warmup sans losange noir) et n'est jamais top_level.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PuzzleArt = preload("res://scripts/puzzle_art.gd")

const CARD := Vector2(0.86, 1.16)  # papier (m) : plus large que la tête, lisible de la caméra de jeu sur téléphone
const GLYPH := 0.78  # côté du carré où la figure est peinte (m)
const GLYPH_Y := 0.47  # centre de la figure sous le point de collage (m)
const HANKO_Y := 0.97  # centre du hanko sous le point de collage (m)
const HANKO_K := 0.5  # hanko du coffre (0,34 m) réduit
const TEX_PAPER := Vector2i(160, 232)
const TEX_GLYPH := 192
const PAPER_COL := Color("#F4ECD8")  # papier de l'ofuda du coffre (puzzle_art « ofuda »)
const RICO_T := 0.42
const FLY_T := 1.4

const CACHE := &"seal_mark_cache"  # textures et matière du papier, en méta de la racine (libérées avec l'arbre)

var shape := ""
var lift := 1.5  # hauteur du point de collage (front), en m au-dessus des pieds
var reach := 0.4  # avancée vers la caméra (devant la tête)
var _pivot: Node3D  # orienté caméra, origine au point de collage
var _card: Node3D  # le papier (il flotte un peu autour du pivot)
var _gmat: StandardMaterial3D
var _hanko: Node3D
var _halves: Array = []
var _crack: Node3D
var _glint: Node3D  # éclat du ricochet (étoile d'or pâle sur le papier)
var _glint_mat: StandardMaterial3D
var _rico := 0.0
var _pop := 0.0
var _t := 0.0
var _gone := false


## Pose le papier, la figure et le hanko. `fig` : clé de figure (UiKit._fsym).
func build(fig: String) -> void:
	shape = fig
	_t = randf() * 10.0
	_pivot = Node3D.new()
	add_child(_pivot)
	_card = Node3D.new()
	_pivot.add_child(_card)
	var paper := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = CARD
	paper.mesh = pq
	paper.material_override = _paper()
	paper.position = Vector3(0, -CARD.y * 0.5, 0)
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_card.add_child(paper)
	var glyph := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(GLYPH, GLYPH)
	glyph.mesh = gq
	_gmat = StandardMaterial3D.new()
	_gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gmat.albedo_texture = glyph_tex(fig)
	_gmat.albedo_color = Toon.SUMI
	_gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_gmat.render_priority = 1
	glyph.material_override = _gmat
	glyph.position = Vector3(0, -GLYPH_Y, 0.004)
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_card.add_child(glyph)
	# hanko du coffre scellé (deux moitiés vermillon à barres de papier, fente blanche), réduit
	_hanko = Node3D.new()
	_card.add_child(_hanko)
	_hanko.position = Vector3(0, -HANKO_Y, 0.03)
	_hanko.scale = Vector3.ONE * HANKO_K
	for sx in [-1.0, 1.0]:
		var h := Node3D.new()
		_hanko.add_child(h)
		h.position = Vector3(float(sx) * PuzzleArt.SEAL_HALF, 0, 0)
		var blk := Toon.part(h, PuzzleArt._mesh("seal_half"), PuzzleArt._mat("seal_block"), Vector3.ZERO)
		blk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mk := PuzzleArt._mat("seal_mark")
		PuzzleArt._part_flat(h, PuzzleArt._mesh("seal_bar_h"), mk, Vector3(float(sx) * -0.005, 0.14, 0.032))
		PuzzleArt._part_flat(h, PuzzleArt._mesh("seal_bar_h"), mk, Vector3(float(sx) * -0.005, -0.14, 0.032))
		PuzzleArt._part_flat(h, PuzzleArt._mesh("seal_bar_v"), mk, Vector3(float(sx) * 0.055, 0, 0.032))
		_halves.append(h)
	_crack = PuzzleArt._part_flat(_hanko, PuzzleArt._mesh("seal_crack"), PuzzleArt._mat("seal_mark"), Vector3(0, 0, 0.034))
	_crack.visible = false
	# éclat du ricochet : trois traits croisés d'or pâle qui s'ouvrent et s'éteignent (visible d'ici le premier
	# update : le préchauffage, figé, le dessine et compile sa matière)
	_glint = Node3D.new()
	_card.add_child(_glint)
	_glint.position = Vector3(CARD.x * 0.36, -GLYPH_Y * 0.45, 0.08)
	_glint_mat = StandardMaterial3D.new()
	_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glint_mat.albedo_color = Color("#FFF1C4")
	_glint_mat.render_priority = 2
	var gl := QuadMesh.new()
	gl.size = Vector2(0.7, 0.07)
	for a in [PI / 4.0, -PI / 4.0, 0.0, PI / 2.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = gl
		mi.material_override = _glint_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.z = float(a)
		mi.scale = Vector3.ONE if absf(float(a)) > 0.1 else Vector3(0.6, 1, 1)
		_glint.add_child(mi)
	_pop = 1.0


## Chaque image (enemy._process) : le pivot suit le front du yōkai, face à la caméra, devant la tête ; le papier
## flotte à peine ; ricochet et apparition. `shown` : le corps est visible (apparition finie, pas dans la fumée).
func update(delta: float, shown: bool) -> void:
	if _gone or _pivot == null:
		return
	visible = shown
	if not shown:
		return
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var par := get_parent_node_3d()
	if cam == null or par == null:
		return
	var cb := cam.global_basis.orthonormalized()
	var k := par.global_basis.get_scale().x
	_pivot.global_basis = cb.scaled(Vector3.ONE * k)
	_pivot.global_position = par.global_position + Vector3(0, lift * k, 0) + cb.z * reach * k
	# le papier flotte (comme un ofuda au vent) ; ricochet : il tressaute, le hanko gonfle, la figure rougit
	_rico = maxf(0.0, _rico - delta / RICO_T)
	_pop = maxf(0.0, _pop - delta / 0.5)
	var jit := sin(_t * 70.0) * 0.05 * _rico
	_card.rotation = Vector3(0, 0, sin(_t * 2.3) * 0.05 + jit * 2.0)
	_card.position = Vector3(jit, 0, 0)
	_card.scale = Vector3.ONE * (1.0 + 0.35 * _pop * _pop + 0.06 * _rico)
	_hanko.scale = Vector3.ONE * HANKO_K * (1.0 + 0.45 * _rico)
	_gmat.albedo_color = Toon.SUMI.lerp(Toon.VERMILION, clampf(_rico * 1.6, 0.0, 1.0))
	_glint.visible = _rico > 0.02
	if _glint.visible:
		var g := 1.0 - _rico
		_glint.scale = Vector3.ONE * (0.5 + 1.3 * (1.0 - (1.0 - g) * (1.0 - g)))
		_glint.rotation.z = g * 0.6
		_glint_mat.albedo_color.a = clampf(_rico * 1.8, 0.0, 1.0)


## Coup qui ne brise pas le sceau : il ricoche (main._check_slashes, pouvoirs). Sans texte.
func ricochet() -> void:
	if _gone:
		return
	_rico = 1.0


## Position monde du centre du papier (étincelles du ricochet).
func card_pos() -> Vector3:
	if _pivot == null or not _pivot.is_inside_tree():
		return global_position
	return _pivot.global_position - _pivot.global_basis.y.normalized() * GLYPH_Y


## Le sceau se brise. `world` : nœud qui garde l'ofuda en vol (le yōkai meurt et s'enfonce) ; `gold` : brisé par
## la bonne figure (figure dorée, hanko qui se fend, éclats d'or), sinon le papier se décolle seul (mort à l'usure).
func unseal(world: Node3D, gold: bool) -> void:
	if _gone or _pivot == null or not is_inside_tree():
		return
	_gone = true
	visible = true
	var basis0 := _pivot.global_basis
	var p0 := _pivot.global_position
	_pivot.reparent(world)
	_pivot.global_basis = basis0
	_pivot.global_position = p0
	_card.rotation = Vector3.ZERO
	_card.position = Vector3.ZERO
	_card.scale = Vector3.ONE
	_glint.visible = false
	_gmat.albedo_color = Color(Toon.GOLD.darkened(0.12), 1.0) if gold else Toon.SUMI
	var pv := _pivot
	if gold:
		# halo d'or derrière le papier : il s'allume d'un coup et s'éteint (le sceau cède)
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.albedo_color = Color(Toon.GOLD.lightened(0.55), 1.0)
		var hq := QuadMesh.new()
		hq.size = CARD * 1.45
		var halo := MeshInstance3D.new()
		halo.mesh = hq
		halo.material_override = hm
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = Vector3(0, -CARD.y * 0.5, -0.03)
		_card.add_child(halo)
		var tg := halo.create_tween()
		tg.set_parallel(true)
		tg.tween_property(halo, "scale", Vector3(1.8, 1.6, 1.0), 0.5).set_ease(Tween.EASE_OUT)
		tg.tween_property(hm, "albedo_color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		# le hanko gonfle, la fente blanche paraît, les deux moitiés tombent en tournoyant puis fondent
		var ts := pv.create_tween()
		ts.tween_property(_hanko, "scale", Vector3.ONE * HANKO_K * 1.5, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ts.tween_callback(_crack.show)
		ts.tween_interval(0.07)
		for i in _halves.size():
			var h: Node3D = _halves[i]
			var sg := -1.0 if i == 0 else 1.0
			var drop := func() -> void:
				if not is_instance_valid(h):
					return
				var th := h.create_tween()
				th.set_parallel(true)
				th.tween_property(h, "position", h.position + Vector3(sg * 0.35, -1.6, 0.2), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				th.tween_property(h, "rotation", Vector3(sg * 0.8, sg * 1.2, sg * 2.4), 0.5)
				th.chain().tween_property(h, "scale", Vector3.ZERO, 0.25)
			ts.tween_callback(drop)
		ts.tween_callback(_crack.hide).set_delay(0.12)
		PuzzleArt._motes(world, world.to_local(card_pos()), Toon.GOLD.lightened(0.3), 6 if Toon.lite else 16, 1.0, 1.4, 0.35)
	# l'ofuda se décolle et s'envole en tournoyant, rapetisse (comme les morceaux de l'ofuda du coffre)
	var side := 1.0 if randf() < 0.5 else -1.0
	var right := basis0.x.normalized()
	var dest := p0 + Vector3(0, 2.8, 0) + right * 1.1 * side
	var spin := Vector3(1.1, 2.2 * side, 1.7 * side)
	var fly := func(k: float) -> void:
		if not is_instance_valid(pv):
			return
		var q := p0.lerp(dest, k)
		q += right * sin(k * 9.0) * 0.14 * k
		pv.global_position = q
		pv.global_basis = basis0 * Basis.from_euler(spin * k)
		pv.scale = Vector3.ONE * clampf(1.7 - 1.7 * k, 0.0, 1.0) * basis0.get_scale().x
	var to := pv.create_tween()
	to.tween_interval(0.22 if gold else 0.05)
	to.tween_method(fly, 0.0, 1.0, FLY_T).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	to.tween_callback(pv.queue_free)


# ------------------------------------------------------------------ textures (rendues une fois)

## Cache partagé (clé -> ImageTexture, « paper_mat ») : en méta de la fenêtre racine plutôt qu'en variable
## statique, pour être libéré avec l'arbre avant l'arrêt du rendu (sinon textures « leaked » à la sortie).
static func _cache() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	if not tree.root.has_meta(CACHE):
		tree.root.set_meta(CACHE, {})
	var d: Dictionary = tree.root.get_meta(CACHE)
	return d


static func _paper() -> StandardMaterial3D:
	var cache := _cache()
	if not cache.has("paper_mat"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.albedo_texture = _render("paper", TEX_PAPER, func(ci: CanvasItem, sz: Vector2) -> void: _draw_paper(ci, sz))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		cache["paper_mat"] = m
	return cache["paper_mat"]


## Figure `fig` (UiKit._fsym, trait blanc sur fond transparent, teintée par la matière).
static func glyph_tex(fig: String) -> Texture2D:
	return _render("fig_" + fig, Vector2i(TEX_GLYPH, TEX_GLYPH), func(ci: CanvasItem, sz: Vector2) -> void: _draw_glyph(ci, sz, fig))


static func _draw_glyph(ci: CanvasItem, sz: Vector2, fig: String) -> void:
	var s := sz.x * 0.4
	# trait épais : la figure se lit de la caméra de jeu, sur un téléphone
	UiKit._fsym(ci, fig, sz * 0.5, s, Color.WHITE, s * 0.27)


## Papier de l'ofuda : bande washi aux bords déchirés, cernée d'encre (lisible sur sable clair comme sur
## pierre sombre), double filet vermillon intérieur, petit coup de pinceau sumi en tête.
static func _draw_paper(ci: CanvasItem, sz: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var m := 7.0
	var pts := PackedVector2Array()
	var n := 9
	for i in n + 1:
		pts.append(Vector2(m + (sz.x - 2.0 * m) * float(i) / float(n), m + rng.randf_range(-3.5, 3.5)))
	pts.append(Vector2(sz.x - m, sz.y * 0.5))
	for i in n + 1:
		pts.append(Vector2(sz.x - m - (sz.x - 2.0 * m) * float(i) / float(n), sz.y - m + rng.randf_range(-4.0, 4.0)))
	pts.append(Vector2(m, sz.y * 0.5))
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_colored_polygon(pts, Toon.SUMI)
	ci.draw_polyline(ring, Toon.SUMI, 12.0, true)
	ci.draw_colored_polygon(pts, PAPER_COL)
	ci.draw_polyline(ring, Toon.SUMI, 5.0, true)
	var r := Rect2(Vector2(17, 20), sz - Vector2(34, 40))
	ci.draw_rect(r, Color(Toon.VERMILION, 0.85), false, 3.0)
	ci.draw_rect(r.grow(-5.0), Color(Toon.VERMILION, 0.55), false, 1.5)


## Texture rendue une fois par une SubViewport 2D (le dessin appelle `draw(ci, taille)`), recopiée avec ses
## mipmaps dans une ImageTexture (pas de scintillement de loin). Sans écran (robot, --headless) : reste vide.
static func _render(key: String, size: Vector2i, draw: Callable) -> Texture2D:
	var cache := _cache()
	if cache.has(key):
		return cache[key]
	var blank := Image.create(size.x, size.y, true, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(blank)
	cache[key] = tex
	if DisplayServer.get_name() == "headless":
		return tex
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return tex
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # (UPDATE_ONCE : rendue parfois avant le premier _draw, vide)
	var canvas := Node2D.new()
	vp.add_child(canvas)
	canvas.draw.connect(func() -> void: draw.call(canvas, Vector2(size)))
	tree.root.add_child.call_deferred(vp)
	var left := [3]  # images à attendre après l'entrée de la SubViewport dans l'arbre
	var hold: Array = []  # (le lambda se déconnecte lui-même)
	var grab := func() -> void:
		if not is_instance_valid(vp):
			RenderingServer.frame_post_draw.disconnect(hold[0])
			hold.clear()  # (le lambda se tenait lui-même : cycle à rompre, sinon fuite à la sortie)
			return
		if not vp.is_inside_tree():
			return
		left[0] -= 1
		if left[0] > 0:
			return
		RenderingServer.frame_post_draw.disconnect(hold[0])
		hold.clear()
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() == size:
				img.generate_mipmaps()
				tex.update(img)
		vp.queue_free()
	hold.append(grab)
	RenderingServer.frame_post_draw.connect(grab)
	return tex
