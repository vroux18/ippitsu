extends Node
## Robot testeur, mode ui (`-- --bot --mode=ui`) : parcours scripté des écrans, sans combat du robot.
## Il passe par les mêmes entrées que le doigt : _gui_input des écrans dessinés (clics synthétiques aux
## rectangles qu'ils ont calculés), appui/relâché au centre des boutons, main._touch_down / _touch_up pour
## l'esquive et les sceaux du HUD. Chaque étape réussie : « BOT UI <étape> ok » ; état attendu non atteint
## à temps : « BOT ALERTE ui: … », puis retour à l'accueil et étape suivante.

const Meta = preload("res://scripts/meta.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Options = preload("res://scripts/options.gd")
const TIMEOUT := 15.0  # secondes réelles

var bot: Node
var main: Node
var _fails := 0


func run() -> void:
	await _frames(5)
	# premier lancement : intro puis tutoriel, même avec une ancienne sauvegarde
	main.meta.intro_done = false
	main.meta.tuto_done = false
	if not await _step_menu():
		await _recover()
	if not await _step_first_intro():
		await _recover()
	elif not await _step_tutorial("premier lancement"):
		await _recover()
	if not await _step_replay_intro():
		await _recover()
	if not await _step_options("accueil"):
		await _recover()
	if not await _step_atelier():
		await _recover()
	for w in range(1, 6):
		if not await _step_world(w):
			await _recover()
	print("BOT UI bilan : %d étape(s) en échec" % _fails)
	bot.finish()


# ------------------------------------------------------------------ outils

func _frame() -> void:
	await main.get_tree().process_frame


func _frames(n: int) -> void:
	for _i in n:
		await main.get_tree().process_frame


## Attend que `cond` soit vrai (en secondes réelles : les écrans dessinés comptent en temps réel).
func _until(cond: Callable, what: String, timeout := TIMEOUT) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(timeout * 1000.0):
			_fail("%s (délai dépassé ; état %s, salle %d)" % [what, String(main.state), int(main.room)])
			return false
		await main.get_tree().process_frame
	return true


func _ok(what: String) -> void:
	print("BOT UI %s ok" % what)


func _fail(msg: String) -> void:
	_fails += 1
	bot.alert("ui: " + msg)


func _check(cond: bool, what: String, why: String) -> bool:
	if cond:
		_ok(what)
	else:
		_fail("%s : %s" % [what, why])
	return cond


## Clic synthétique envoyé au _gui_input d'un écran (coordonnées locales).
func _click(ctrl: Control, p: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	if pressed and button == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ctrl.call("_gui_input", ev)


## Toucher : appui puis relâché au même point.
func _tap(ctrl: Control, p: Vector2) -> void:
	_click(ctrl, p, true)
	_click(ctrl, p, false)


func _wheel(ctrl: Control, down: bool) -> void:
	var b: MouseButton = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	_click(ctrl, ctrl.size / 2.0, true, b)
	_click(ctrl, ctrl.size / 2.0, false, b)


## Glissé du doigt de a vers b (appui, mouvements, relâché).
func _drag(ctrl: Control, a: Vector2, b: Vector2, steps := 8) -> void:
	_click(ctrl, a, true)
	var prev := a
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		var mm := InputEventMouseMotion.new()
		mm.position = p
		mm.global_position = p
		mm.relative = p - prev
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		ctrl.call("_gui_input", mm)
		prev = p
		await _frame()
	_click(ctrl, b, false)
	await _frame()


## Bouton dessiné (InkButton) : on attend qu'il soit affiché, puis appui et relâché en son centre.
func _press(b: Control, what := "") -> bool:
	var label := what if what != "" else String(b.get("text"))
	if not await _until(func(): return b.is_visible_in_tree() and b.size.x > 1.0, "bouton « %s » affiché" % label, 8.0):
		return false
	_tap(b, b.size / 2.0)
	await _frame()
	return true


## Retour à un état connu (accueil) après une étape en échec.
func _recover() -> void:
	print("BOT UI reprise : retour à l'accueil")
	bot.guard_all = true
	main.meta.intro_done = true
	main.meta.tuto_done = true
	for c in [main.intro, main.options, main.recap, main.refuge, main.worldmap, main.picker]:
		c.visible = false
	if bool(main.tuto.visible):
		main.tuto.visible = false
		main.tuto.step = -1
	Engine.time_scale = 1.0
	main._start()
	main._set_state("menu")
	await _frames(5)


## Rouleaux en attente (niveau, malédiction, bénédiction) : on touche la première carte jusqu'au retour en jeu
## (un toucher la lève, le suivant la choisit).
func _settle_play(what := "") -> int:
	var n := 0
	var pk = main.picker
	var t0 := Time.get_ticks_msec()
	while String(main.state) != "play":
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			_fail("retour en jeu impossible (état %s) %s" % [String(main.state), what])
			return n
		if String(main.state) == "pick" and bool(pk.visible) and int(pk._chosen) < 0 and float(pk._t) >= float(pk._ready_time()) + 0.05 and pk._rects.size() > 0:
			var r: Rect2 = pk._rects[0]
			_tap(pk, r.get_center())
			n += 1
		await _frame()
	return n


## Choisit la carte `idx` du rouleau ouvert, par un toucher sur son rectangle.
func _pick_card(idx: int, what: String) -> bool:
	var pk = main.picker
	if not await _until(func(): return bool(pk.visible) and int(pk._chosen) < 0 and float(pk._t) >= float(pk._ready_time()) + 0.05 and pk._rects.size() > idx, "%s : cartes prêtes" % what):
		return false
	# premier toucher : la carte se lève (détail) ; puis le bouton CHOISIR la prend
	var r: Rect2 = pk._rects[idx]
	_tap(pk, r.get_center())
	if int(pk._sel) != idx or int(pk._chosen) >= 0:
		_fail("%s : le toucher n'a pas levé la carte %d" % [what, idx])
		return false
	await _frames(2)
	var cr: Rect2 = pk._confirm_rect
	_tap(pk, cr.get_center())
	if int(pk._chosen) != idx:
		_fail("%s : CHOISIR n'a pas pris la carte %d" % [what, idx])
		return false
	return await _until(func(): return int(pk._chosen) < 0 or not bool(pk.visible), "%s : rouleau refermé" % what)


func _dummies() -> Array:
	var out: Array = []
	for e in main.enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and not e.dead and e.dummy and not e.is_harmless():
			out.append(e)
	var hp: Vector3 = main.hero.position
	out.sort_custom(func(a, b): return a.position.distance_to(hp) < b.position.distance_to(hp))
	return out


func _hero_still() -> bool:
	var h = main.hero
	return not bool(h.dashing) and float(h._leap_t) < 0.0


# ------------------------------------------------------------------ accueil, intro, tutoriel

func _step_menu() -> bool:
	if not await _until(func(): return String(main.state) == "menu" and bool(main.menu.visible), "accueil affiché"):
		return false
	if not await _until(func(): return main.menu._play.is_visible_in_tree(), "bouton JOUER affiché"):
		return false
	_ok("accueil")
	# son : coupé puis rétabli (bouton rond de l'accueil)
	var m0 := bool(main.menu.muted)
	await _press(main.menu._sound, "son")
	_check(bool(main.menu.muted) != m0 and AudioServer.is_bus_mute(0) == bool(main.menu.muted), "accueil : son coupé", "le bouton son n'agit pas")
	await _press(main.menu._sound, "son")
	_check(bool(main.menu.muted) == m0, "accueil : son rétabli", "état du son non rétabli")
	return true


func _intro_ready() -> bool:
	return await _until(func(): return float(main.intro._pt) >= 0.35, "intro prête", 5.0)


## Planches de l'intro jusqu'à la dernière, par le bouton SUIVANT.
func _intro_to_last() -> bool:
	var intro = main.intro
	var last: int = intro.PAGES.size() - 1
	while int(intro.page) < last:
		var pg := int(intro.page)
		await _intro_ready()
		await _press(intro._next, "SUIVANT")
		if not await _until(func(): return int(intro.page) == pg + 1, "SUIVANT -> planche %d" % (pg + 2), 3.0):
			return false
		_ok("intro planche %d" % (pg + 2))
	await _intro_ready()
	await _frames(2)
	return true


func _step_first_intro() -> bool:
	var intro = main.intro
	await _press(main.menu._play, "JOUER")
	if not await _until(func(): return bool(intro.visible), "JOUER (premier lancement) ouvre l'intro"):
		return false
	_check(not bool(intro.replay), "intro du premier lancement ouverte", "ouverte comme depuis le « ? »")
	await _intro_ready()
	# glissé à gauche : planche suivante ; à droite : retour ; simple toucher : suivante
	var c: Vector2 = intro.size / 2.0
	var u: float = intro._unit()
	_click(intro, c, true)
	_click(intro, c + Vector2(-160.0 * u, 0.0), false)
	_check(int(intro.page) == 1, "intro : glissé vers la planche suivante", "planche %d" % int(intro.page))
	await _intro_ready()
	_click(intro, c, true)
	_click(intro, c + Vector2(160.0 * u, 0.0), false)
	_check(int(intro.page) == 0, "intro : glissé vers la planche précédente", "planche %d" % int(intro.page))
	await _intro_ready()
	_tap(intro, c)
	_check(int(intro.page) == 1, "intro : toucher pour avancer", "planche %d" % int(intro.page))
	if not await _intro_to_last():
		return false
	_check(String(intro._next.text) == "C'EST PARTI" and not bool(intro._tuto.visible), "intro : dernière planche du premier lancement (C'EST PARTI)", "bouton « %s »" % String(intro._next.text))
	await _press(intro._next, "C'EST PARTI")
	if not await _until(func(): return String(main.state) == "tuto" and bool(main.meta.intro_done), "fin de l'intro -> tutoriel"):
		return false
	_ok("intro du premier lancement -> tutoriel")
	return true


func _step_tutorial(label: String) -> bool:
	var tuto = main.tuto
	if not await _until(func(): return String(main.state) == "tuto" and bool(tuto.visible) and int(tuto.step) == 0, "tutoriel lancé"):
		return false
	var n: int = tuto.STEPS.size()
	for i in n:
		var st: Dictionary = tuto.STEPS[i]
		var title := String(st["title"])
		if not await _until(func(): return int(tuto.step) == i and float(tuto._done_t) < 0.0, "tutoriel : étape %d (%s) affichée" % [i + 1, title]):
			return false
		var ok: bool = await _tuto_step(i, String(st["goal"]))
		if not ok:
			_fail("tutoriel : étape %d (%s) jamais réussie" % [i + 1, title])
			return false
		_ok("tutoriel (%s) étape %d %s" % [label, i + 1, title])
	if not await _until(func(): return String(main.state) == "menu" and bool(main.meta.tuto_done), "fin du tutoriel -> accueil"):
		return false
	_ok("tutoriel (%s) terminé" % label)
	return true


## Une étape du tutoriel : le geste attendu, refait jusqu'à la réussite (12 essais au plus).
func _tuto_step(i: int, goal: String) -> bool:
	var tuto = main.tuto
	var tries := 0
	while int(tuto.step) == i and float(tuto._done_t) < 0.0:
		if tries >= 12:
			return false
		if not await _until(func(): return _hero_still(), "héros posé (tutoriel)", 10.0):
			return false
		if int(tuto.step) != i or float(tuto._done_t) >= 0.0:
			break
		tries += 1
		var hp: Vector3 = main.hero.position
		var center := Vector3(-hp.x, 0.0, -hp.z)  # vers le milieu de l'arène
		if center.length() < 0.5:
			center = Vector3(0, 0, -1)
		if goal == "kill1" or goal == "kill2":
			var need := 1 if goal == "kill1" else 2
			if not await _until(func(): return _dummies().size() >= need or int(tuto.step) != i, "mannequins prêts", 6.0):
				return false
			var dm := _dummies()
			if dm.size() < need:
				pass  # étape déjà passée
			elif goal == "kill1":
				bot.stroke_line(dm[0].position)
			else:
				var a: Vector3 = dm[0].position
				var b: Vector3 = dm[1].position
				var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
				bot._stroke_points(PackedVector3Array([a, b + d * 0.8]))
		elif goal == "dodge":
			bot.dodge(center)
		elif goal == "zone":
			if not await _until(func(): return tuto._zone != null or int(tuto.step) != i, "zone rouge annoncée", 10.0):
				return false
			if int(tuto.step) == i:
				bot.dodge(center)
				await _until(func(): return tuto._zone == null or int(tuto.step) != i or float(tuto._done_t) >= 0.0, "impact de la zone rouge", 10.0)
		else:
			var dm2 := _dummies()
			var target := Vector3.ZERO
			if not dm2.is_empty():
				target = dm2[0].position
			if not bot.figure(goal, target):
				bot.stroke_line(Vector3(0, 0, 1))  # trop près d'un bord : on se replace au milieu
		await _until(func(): return _hero_still(), "fin de la ruée (tutoriel)", 10.0)
		await _frames(3)
	return int(tuto.step) != i or float(tuto._done_t) >= 0.0


func _step_replay_intro() -> bool:
	var intro = main.intro
	# « ? » puis PASSER : retour à l'accueil
	await _press(main.menu._help, "?")
	if not await _until(func(): return bool(intro.visible) and bool(intro.replay), "« ? » ouvre l'intro"):
		return false
	await _intro_ready()
	await _press(intro._skip, "PASSER")
	if not await _until(func(): return not bool(intro.visible) and String(main.menu.mode) == "home", "intro « ? » : PASSER -> accueil"):
		return false
	_ok("intro « ? » : PASSER")
	# « ? » jusqu'à la dernière planche : RETOUR
	await _press(main.menu._help, "?")
	if not await _until(func(): return bool(intro.visible), "« ? » rouvre l'intro"):
		return false
	if not await _intro_to_last():
		return false
	_check(bool(intro._tuto.visible) and bool(intro._back.visible) and not bool(intro._next.visible), "intro « ? » : dernière planche (LANCER LE TUTORIEL, RETOUR)", "boutons attendus absents")
	await _press(intro._back, "RETOUR")
	if not await _until(func(): return not bool(intro.visible) and String(main.menu.mode) == "home", "intro « ? » : RETOUR -> accueil"):
		return false
	_ok("intro « ? » : RETOUR")
	# « ? » jusqu'à la dernière planche : LANCER LE TUTORIEL, puis on le quitte par sa maison
	await _press(main.menu._help, "?")
	if not await _until(func(): return bool(intro.visible), "« ? » rouvre l'intro"):
		return false
	if not await _intro_to_last():
		return false
	await _press(intro._tuto, "LANCER LE TUTORIEL")
	if not await _until(func(): return String(main.state) == "tuto" and bool(main.tuto.visible), "LANCER LE TUTORIEL"):
		return false
	_ok("intro « ? » : LANCER LE TUTORIEL")
	await _press(main.tuto._quit, "maison du tutoriel")
	if not await _until(func(): return String(main.state) == "menu" and not bool(main.tuto.visible), "tutoriel quitté -> accueil"):
		return false
	_ok("tutoriel quitté (bouton maison)")
	return true


# ------------------------------------------------------------------ options

func _option_applied(key: String, val: String) -> bool:
	match key:
		"control":
			return String(main.ctrl_mode) == val
		"pad_size":
			return String(main.pad_size) == val
		"pad_show":
			return String(main.pad_show) == val
		"sound":
			return bool(main.menu.muted) == (val == "off")
		"vibration":
			return bool(main.sfx.haptics) == (val == "on")
	return false


func _option(key: String, val: String, log_it: bool) -> bool:
	var opt = main.options
	await _frame()
	var found := false
	var r := Rect2()
	for h in opt._hits:
		if String(h[1]) == key and String(h[2]) == val:
			r = h[0]
			found = true
	if not found:
		_fail("option %s = %s : case introuvable" % [key, val])
		return false
	_tap(opt, r.get_center())
	var ok := String(opt.values.get(key, "")) == val and _option_applied(key, val)
	if log_it or not ok:
		_check(ok, "option %s = %s" % [key, val], "non appliquée")
	return ok


func _step_options(from: String) -> bool:
	var opt = main.options
	await _press(main.menu._gear, "options")
	if not await _until(func(): return bool(opt.visible), "options ouvertes (%s)" % from):
		return false
	if not await _until(func(): return float(opt._t) >= 0.35 and opt._hits.size() > 0, "options prêtes"):
		return false
	var orig: Dictionary = opt.values.duplicate()
	for row in Options.ROWS:
		# les réglages du pad sont grisés en mode « sur l'écran » : on repasse en pad avant de les tester
		if String(row["key"]) in ["pad_size", "pad_show"] and String(opt.values.get("control", "pad")) != "pad":
			await _option("control", "pad", false)
		for o in row["opts"]:
			await _option(String(row["key"]), String(o[0]), from == "accueil")
	# valeurs de départ
	for key in orig.keys():
		await _option(String(key), String(orig[key]), false)
	_check(String(main.ctrl_mode) == String(orig["control"]) and String(main.pad_show) == String(orig["pad_show"]), "options (%s) : valeurs rétablies" % from, "réglages non rétablis")
	var back: Rect2 = opt._back
	_tap(opt, back.get_center())
	if not await _until(func(): return not bool(opt.visible), "options : RETOUR"):
		return false
	_ok("options (%s) : RETOUR" % from)
	return true


# ------------------------------------------------------------------ atelier

## Rectangle d'une cible de l'Atelier (onglet, ligne, sceau, estampe…), s'il est touchable à l'écran.
func _ref_rect(key: String) -> Rect2:
	var ref = main.refuge
	var r := Rect2()
	if key == "back":
		r = ref._back_rect
	else:
		for hr in ref._hits:
			if String(hr[1]) == key:
				r = hr[0]
		if not r.has_area() and int(ref._tab) > 0:
			var view: Rect2 = ref._view
			for hr in ref._list_hits:
				var lr: Rect2 = hr[0]
				if String(hr[1]) == key and view.has_point(lr.get_center()):
					r = lr
	if r.has_area() and String(ref._target_at(r.get_center())) == key:
		return r
	return Rect2()


## Toucher une cible de l'Atelier : à son rectangle si elle est à l'écran, sinon même suite que le toucher.
func _ref_tap(key: String) -> void:
	var ref = main.refuge
	await _frame()
	var r := _ref_rect(key)
	if r.has_area():
		_tap(ref, r.get_center())
	else:
		ref._tap(key)
	await _frame()


func _ref_tab(i: int) -> void:
	await _ref_tap("tab:%d" % i)
	await _frames(3)
	_check(int(main.refuge._tab) == i, "atelier : onglet %d" % i, "onglet %d affiché" % int(main.refuge._tab))


func _ref_scroll() -> void:
	var ref = main.refuge
	await _frames(3)
	if float(ref._max_scroll()) <= 1.0:
		_ok("atelier : onglet %d sans défilement (liste courte)" % int(ref._tab))
		return
	var s0: float = ref._scroll
	_wheel(ref, true)
	_wheel(ref, true)
	await _frames(2)
	var s1: float = ref._scroll
	var view: Rect2 = ref._view
	await _drag(ref, view.get_center(), view.get_center() + Vector2(0.0, -view.size.y * 0.3))
	var s2: float = ref._scroll
	_check(s1 > s0 and absf(s2 - s1) > 0.5, "atelier : défilement de l'onglet %d (molette, glissé)" % int(ref._tab), "%.0f -> %.0f -> %.0f" % [s0, s1, s2])


func _step_atelier() -> bool:
	var meta = main.meta
	var ref = main.refuge
	# monnaie offerte et toutes les estampes, pour tout acheter et tout porter
	meta.sumi = 20000
	meta.seals = 80
	for pid in Meta.PRINT_ORDER:
		meta._grant(String(pid))
	meta.save_data()
	main.menu.sumi = meta.sumi
	await _press(main.menu._atelier, "ATELIER")
	if not await _until(func(): return bool(ref.visible), "ATELIER ouvre l'atelier"):
		return false
	if not await _until(func(): return float(ref._t) >= 0.7 and ref._hits.size() > 0, "atelier prêt"):
		return false
	_ok("atelier ouvert")
	# onglet 0 : Pierre à encre, chaque ligne jusqu'au rang max (choisir, puis confirmer)
	for i in Meta.ORDER.size():
		var lid := String(Meta.ORDER[i])
		var guard := 0
		while int(meta.cost(lid)) >= 0 and guard < 8:
			guard += 1
			var r0 := int(meta.rank(lid))
			await _ref_tap("line:%d" % i)
			await _ref_tap("line:%d" % i)
			if int(meta.rank(lid)) != r0 + 1:
				break
		_check(int(meta.cost(lid)) < 0, "atelier : ligne %s achetée jusqu'au rang %d" % [lid, int(meta.rank(lid))], "rang max non atteint")
	# onglet 1 : sceaux (dons et légendaires)
	await _ref_tab(1)
	for sid in Meta.SEAL_ORDER:
		await _ref_tap("seal:%s" % sid)
		await _ref_tap("seal:%s" % sid)
		_check(bool(meta.owns_seal(String(sid))), "atelier : sceau %s" % sid, "non scellé")
	var sp0 := String(meta.start_power())
	await _ref_tap("next")
	var sp1 := String(meta.start_power())
	await _ref_tap("prev")
	_check(sp1 != sp0 and String(meta.start_power()) == sp0, "atelier : rouleau de départ (flèches)", "%s -> %s -> %s" % [sp0, sp1, String(meta.start_power())])
	await _ref_scroll()
	# onglet 2 : estampes, une apparence portée par type (écharpe, sillage, encre)
	await _ref_tab(2)
	for kind in Meta.LOOK_KINDS:
		var pid := ""
		for k in Meta.PRINT_ORDER:
			var p: Dictionary = Meta.PRINTS[k]
			if pid == "" and String(p["kind"]) == String(kind):
				pid = String(k)
		await _ref_tap("print:%s" % pid)
		await _ref_tap("print:%s" % pid)
		_check(bool(meta.is_worn(pid)), "atelier : apparence %s portée (%s)" % [String(kind), pid], "non portée")
	await _ref_scroll()
	await _ref_tab(0)
	await _ref_tap("back")
	if not await _until(func(): return not bool(ref.visible) and String(main.state) == "menu", "atelier : RETOUR -> accueil"):
		return false
	_check(bool(meta.look_on("cape")) and bool(meta.look_on("trail")) and bool(meta.look_on("ink")), "atelier : RETOUR, apparences portées", "apparence perdue")
	return true


# ------------------------------------------------------------------ mondes

func _step_world(w: int) -> bool:
	var wm = main.worldmap
	await _press(main.menu._play, "JOUER")
	if not await _until(func(): return String(main.state) == "worlds" and bool(wm.visible), "JOUER -> barque -> carte des mondes"):
		return false
	_ok("monde %d : barque et carte des mondes" % w)
	if w == 1:
		# la maison ramène à l'accueil, puis on rouvre la carte
		await _until(func(): return float(wm._t) >= 0.4, "carte prête")
		await _press(wm._back, "maison de la carte")
		if not await _until(func(): return String(main.state) == "menu" and not bool(wm.visible), "carte : retour à l'accueil"):
			return false
		_ok("carte des mondes : retour à l'accueil")
		await _press(main.menu._play, "JOUER")
		if not await _until(func(): return String(main.state) == "worlds" and bool(wm.visible), "carte rouverte"):
			return false
	await _until(func(): return float(wm._t) >= 0.4, "carte prête")
	if w == 2:
		# glissé du rouleau : la carte suit le doigt
		var s0: float = wm._scroll
		var c: Vector2 = wm.size / 2.0
		await _drag(wm, c, c + Vector2(-60.0, 0.0))
		_check(absf(float(wm._scroll) - s0) > 0.01 or float(wm._target) != s0, "carte : glissé du rouleau", "le rouleau n'a pas bougé")
	# molette : une étape par cran, jusqu'au monde voulu
	var guard := 0
	while int(round(float(wm._target))) != w - 1 and guard < 12:
		guard += 1
		_wheel(wm, int(round(float(wm._target))) < w - 1)
		await _frame()
	if not await _until(func(): return int(wm._sel()) == w - 1, "carte centrée sur le monde %d" % w):
		return false
	await _press(wm._go, "PARTIR")
	if not await _until(func(): return String(main.state) == "intro" and int(main.current_world) == w, "PARTIR -> entrée du monde %d" % w):
		return false
	_ok("monde %d choisi (PARTIR)" % w)
	if not await _until(func(): return String(main.state) == "play" and bool(main.in_hub), "entrée du monde %d -> sanctuaire de départ" % w):
		return false
	_ok("monde %d : plan d'entrée puis sanctuaire" % w)
	if not await _transit_to_room1(w):
		return false
	if w == 1:
		if not await _step_pause_recap():
			return false
		if not await _step_pickers():
			return false
		if not await _step_sanctuary():
			return false
	if not await _boss_intro(w, int(main.MINI_ROOM)):
		return false
	if not await _boss_intro(w, int(main.ROOMS)):
		return false
	if w == 1:
		return await _step_victory()
	if w == 2:
		return await _step_defeat()
	return await _quit_to_menu(w)


func _transit_to_room1(w: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while bool(main.in_hub):
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			_fail("monde %d : torii du sanctuaire jamais atteint" % w)
			return false
		if String(main.state) == "play" and _hero_still():
			bot.stroke_line(main.arena.gate_pos)
		await _frames(4)
	if not await _until(func(): return String(main.state) == "play" and int(main.room) == 1, "monde %d : transit -> salle 1" % w):
		return false
	_ok("monde %d : torii, transit, salle 1" % w)
	return true


## Saute à la salle `target` (son boss y entre) par le vrai passage du torii.
func _jump(target: int) -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	for bo in main.bosses:
		if is_instance_valid(bo):
			bo.queue_free()
	main.bosses.clear()
	main._waves_left.clear()
	main._intro_boss = null
	main._intro_wave = []
	main.room = target - 1
	main._transit()


## Entrée d'un boss jouée en entier (plan rapproché, carton titre), sans la passer.
func _boss_intro(w: int, target: int) -> bool:
	await _settle_play("avant la salle %d" % target)
	_jump(target)
	if not await _until(func(): return String(main.state) == "boss_intro", "monde %d salle %d : entrée du boss" % [w, target]):
		return false
	var kind := ""
	if is_instance_valid(main._intro_boss):
		kind = String(main._intro_boss.kind)
	var cine := 0.0
	var t0 := Time.get_ticks_msec()
	while String(main.state) == "boss_intro":
		cine = maxf(cine, float(main.hud.cine))
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			_fail("monde %d : entrée de %s sans fin" % [w, kind])
			return false
		await _frame()
	return _check(cine > 0.5 and String(main.state) == "play" and int(main.room) == target and not main.bosses.is_empty(),
		"monde %d : entrée de %s jouée en entier (salle %d)" % [w, kind, target], "plan rapproché %.2f, état %s" % [cine, String(main.state)])


func _quit_to_menu(w: int) -> bool:
	await _settle_play("avant la pause")
	await _press(main.hud._pause, "pause")
	if not await _until(func(): return String(main.state) == "paused", "pause"):
		return false
	await _press(main.menu._quit, "QUITTER")
	if not await _until(func(): return String(main.state) == "menu", "pause : QUITTER -> accueil"):
		return false
	_ok("monde %d : pause, QUITTER -> accueil" % w)
	return true


## Point de l'écran sur un sceau de pouvoir du HUD (Vector2(-1, -1) s'il n'y en a pas).
func _seal_point() -> Vector2:
	var hud = main.hud
	var sz: Vector2 = hud.size
	var y := 0.0
	while y < sz.y:
		var x := 0.0
		while x < sz.x:
			var p := Vector2(x, y)
			if bool(hud.is_over_seals(p)) and not bool(hud.is_over_pause(p)):
				return p
			x += 6.0
		y += 6.0
	return Vector2(-1, -1)


func _recap_scroll(rc) -> void:
	await _frames(3)
	if float(rc._max_scroll()) <= 1.0:
		_ok("récapitulatif sans défilement (liste courte)")
		return
	var s0: float = rc._scroll
	_wheel(rc, true)
	_wheel(rc, true)
	await _frames(2)
	var s1: float = rc._scroll
	var view: Rect2 = rc._view
	await _drag(rc, view.get_center(), view.get_center() + Vector2(0.0, -view.size.y * 0.3))
	var s2: float = rc._scroll
	_check(s1 > s0 and absf(s2 - s1) > 0.5, "récapitulatif : défilement (molette, glissé)", "%.0f -> %.0f -> %.0f" % [s0, s1, s2])


func _step_pause_recap() -> bool:
	var p = main.powers
	for id in ["fire_burn", "water_foam", "bolt_arc", "wind_long", "shadow_back", "ink_daruma", "fire_fudo", "water_kanagawa", "ink_enso"]:
		p.add(String(id))
	main._sync_power_seals()
	await _settle_play("avant la pause")
	await _press(main.hud._pause, "pause")
	if not await _until(func(): return String(main.state) == "paused" and String(main.menu.mode) == "pause", "bouton pause"):
		return false
	_ok("pause")
	var rc = main.recap
	await _press(main.menu._powers_btn, "MES POUVOIRS")
	if not await _until(func(): return bool(rc.visible), "MES POUVOIRS ouvre le récapitulatif"):
		return false
	_check(int(rc._count) == p.levels.size() and p.levels.size() >= 9, "MES POUVOIRS : %d pouvoirs listés" % int(rc._count), "attendu %d" % p.levels.size())
	await _until(func(): return float(rc._t) >= 0.35, "récapitulatif prêt")
	await _recap_scroll(rc)
	var back: Rect2 = rc._back
	_tap(rc, back.get_center())
	if not await _until(func(): return not bool(rc.visible) and String(main.menu.mode) == "pause", "récapitulatif : RETOUR -> pause"):
		return false
	_ok("récapitulatif refermé sur la pause")
	if not await _step_options("pause"):
		return false
	_check(String(main.menu.mode) == "pause" and String(main.state) == "paused", "options refermées sur la pause", "mode %s" % String(main.menu.mode))
	await _press(main.menu._resume, "REPRENDRE")
	if not await _until(func(): return String(main.state) == "play", "REPRENDRE"):
		return false
	_ok("pause : REPRENDRE")
	# en jeu, toucher les sceaux du HUD ouvre le récapitulatif (jeu en pause), qui se referme sur le jeu
	await _frames(3)
	var sp := _seal_point()
	if sp.x >= 0.0:
		main._touch_down(sp)
	else:
		main._open_recap()
	if not await _until(func(): return bool(rc.visible) and String(main.state) == "paused", "sceaux du HUD -> récapitulatif"):
		return false
	await _until(func(): return float(rc._t) >= 0.35, "récapitulatif prêt")
	back = rc._back
	_tap(rc, back.get_center())
	if not await _until(func(): return not bool(rc.visible) and String(main.state) == "play", "récapitulatif -> retour au jeu"):
		return false
	_ok("récapitulatif depuis les sceaux du HUD (%s)" % ("toucher" if sp.x >= 0.0 else "appel direct"))
	return true


## Rouleaux de niveau de chaque rareté (le légendaire se retourne), et une relance.
func _step_pickers() -> bool:
	await _settle_play("avant les rouleaux")
	var p = main.powers
	var pk = main.picker
	for rar in PowerData.RARITY_ORDER:
		var ids: Array = []
		var keys: Array = PowerData.POWERS.keys()
		keys.shuffle()
		for k in keys:
			var d: Dictionary = PowerData.POWERS[k]
			if ids.size() < 3 and String(d["rarity"]) == String(rar) and int(p.lvl(String(k))) < int(p.max_level(String(k))):
				ids.append(String(k))
		if ids.is_empty():
			_fail("rouleau %s : plus aucun pouvoir à proposer" % String(rar))
			continue
		var infos: Array = []
		for id in ids:
			infos.append(p.describe(String(id)))
		# même ouverture que main._open_upgrades, avec un tirage choisi
		main._pick_context = "level"
		main._pick_mode = "upgrade"
		main._set_state("pick")
		pk.rerolls = 1 if String(rar) == "common" else 0
		pk.open(ids, infos)
		if String(rar) == "legendary":
			_check(int(pk._leg_index) >= 0, "rouleau légendaire : carte à retourner", "pas de légendaire détecté")
		if String(rar) == "common":
			if not await _until(func(): return float(pk._t) >= float(pk._ready_time()) + 0.05 and pk._reroll_rect.has_area(), "bouton RELANCER affiché"):
				return false
			var rr: Rect2 = pk._reroll_rect
			_tap(pk, rr.get_center())
			if not await _until(func(): return bool(pk.visible) and int(pk.rerolls) == 0 and String(main.state) == "pick", "RELANCER -> nouveau tirage"):
				return false
			_ok("rouleau : RELANCER (nouveau tirage %s)" % str(pk._ids))
		if not await _until(func(): return float(pk._t) >= float(pk._ready_time()) + 0.05 and pk._rects.size() == pk._ids.size(), "rouleau %s prêt" % String(rar)):
			return false
		var idx: int = randi() % int(pk._ids.size())
		var chosen := String(pk._ids[idx])
		var l0 := int(p.lvl(chosen))
		if not await _pick_card(idx, "rouleau %s" % String(rar)):
			return false
		await _settle_play("après le rouleau %s" % String(rar))
		_check(int(p.lvl(chosen)) > l0, "rouleau %s : %s choisi au toucher (niveau %d)" % [String(rar), chosen, int(p.lvl(chosen))], "niveau inchangé")
	return true


## Salle nettoyée par le vrai chemin (ennemis achevés), torii ouvert, rouleaux de niveau en attente résolus.
func _clear_room() -> bool:
	var t0 := Time.get_ticks_msec()
	while not (bool(main.arena.gate_open) and bool(main._room_done)):
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			_fail("salle %d jamais nettoyée" % int(main.room))
			return false
		main._waves_left.clear()
		for e in main.enemies:
			if is_instance_valid(e) and not e.dead:
				main.damage_enemy(e, 999.0, false)
		await _frames(2)
	var n: int = await _settle_play("après la salle nettoyée")
	if n > 0:
		_ok("rouleau de niveau de fin de salle (vrai tirage) choisi au toucher")
	return true


func _step_sanctuary() -> bool:
	await _settle_play("avant le sanctuaire")
	if not await _clear_room():
		return false
	for take in [true, false]:
		main._spawn_shrine()
		var shp: Vector3 = main._shrine.position
		var t0 := Time.get_ticks_msec()
		while String(main.state) == "play":
			if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
				_fail("sanctuaire jamais atteint")
				return false
			if _hero_still():
				bot._stroke_points(PackedVector3Array([shp]))
			await _frames(3)
		if not await _until(func(): return String(main.state) == "pick" and bool(main.picker._curse_mode), "autel touché -> pacte proposé"):
			return false
		var nc: int = main.curses.size()
		var idx: int = 0 if take else main.picker._ids.size() - 1  # la dernière carte : « Passer »
		if not await _pick_card(idx, "sanctuaire"):
			return false
		await _settle_play("après le pacte")
		var want: int = nc + (1 if take else 0)
		_check(main.curses.size() == want, "sanctuaire : %s" % ("malédiction acceptée %s" % str(main.curses) if take else "PASSER"), "%d malédiction(s), attendu %d" % [main.curses.size(), want])
	return true


func _step_victory() -> bool:
	await _settle_play("avant la victoire")
	# le boss tombe : salle 15 nettoyée, vrai chemin de fin (_room_cleared -> _victory -> _finish_run)
	var t0 := Time.get_ticks_msec()
	while String(main.state) == "play":
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			_fail("salle 15 nettoyée -> victoire (délai dépassé)")
			return false
		for bo in main.bosses:
			if is_instance_valid(bo):
				bo.queue_free()
		main.bosses.clear()
		for e in main.enemies:
			if is_instance_valid(e):
				e.queue_free()
		main.enemies.clear()
		main._waves_left.clear()
		await _frame()
	if not await _until(func(): return String(main.state) == "dying" or String(main.state) == "over", "salle 15 nettoyée -> victoire"):
		return false
	_ok("victoire : fin au ralenti")
	if not await _until(func(): return String(main.state) == "over" and String(main.menu.mode) == "over", "victoire -> résultats"):
		return false
	_check(bool(main.menu.victory), "résultats de victoire", "menu.victory faux")
	await _until(func(): return float(main.menu._t) >= 0.7, "résultats prêts")
	await _press(main.menu._over_atelier, "ATELIER des résultats")
	if not await _until(func(): return bool(main.refuge.visible), "résultats : ATELIER"):
		return false
	await _until(func(): return float(main.refuge._t) >= 0.4, "atelier prêt")
	await _ref_tap("back")
	if not await _until(func(): return String(main.state) == "menu", "atelier -> accueil"):
		return false
	_ok("résultats : ATELIER puis accueil")
	return true


func _step_defeat() -> bool:
	await _settle_play("avant la défaite")
	bot.guard_all = false
	var h = main.hero
	main.foam = 0
	var t0 := Time.get_ticks_msec()
	while String(main.state) == "play":
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			bot.guard_all = true
			_fail("le héros ne meurt pas")
			return false
		if not bool(h.dashing):
			h.guard_t = 0.0
			h.invuln = 0.0
			h.spinning = 0.0
			h.hp = 1
			main._hurt_hero()
		await _frame()
	bot.guard_all = true
	if not await _until(func(): return String(main.state) == "over" and String(main.menu.mode) == "over", "défaite -> résultats"):
		return false
	_check(not bool(main.menu.victory), "résultats de défaite (coup fatal : %s%s)" % [String(main.menu.killer_name), String(main.menu.killer_kind)], "menu.victory vrai")
	await _until(func(): return float(main.menu._t) >= 0.7, "résultats prêts")
	await _press(main.menu._replay, "REJOUER")
	if not await _until(func(): return String(main.state) == "play" and bool(main.in_hub), "REJOUER -> sanctuaire"):
		return false
	_ok("résultats : REJOUER")
	await _press(main.hud._pause, "pause")
	if not await _until(func(): return String(main.state) == "paused", "pause"):
		return false
	await _press(main.menu._restart, "RECOMMENCER")
	if not await _until(func(): return String(main.state) == "play" and bool(main.in_hub) and int(main.room) == 0, "RECOMMENCER -> sanctuaire"):
		return false
	_ok("pause : RECOMMENCER")
	return await _quit_to_menu(2)
