extends Node
## Robot testeur, mode ui (`-- --bot --mode=ui`) : parcours scripté des écrans, sans combat du robot.
## Il passe par les mêmes entrées que le doigt : _gui_input des écrans dessinés (clics synthétiques aux
## rectangles qu'ils ont calculés), appui/relâché au centre des boutons, main._touch_down / _touch_up pour
## l'esquive et la course. Chaque étape réussie : « BOT UI <étape> ok » ; état attendu non atteint
## à temps : « BOT ALERTE ui: … », puis retour à l'accueil et étape suivante.

const Meta = preload("res://scripts/meta.gd")
const Worlds = preload("res://scripts/worlds.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Options = preload("res://scripts/options.gd")
const TIMEOUT := 15.0  # secondes réelles

var bot: Node
var main: Node
var _fails := 0


func run() -> void:
	await _frames(5)
	# premier lancement : intro puis monde 1 avec le coach, comme une sauvegarde neuve
	main.meta.intro_done = false
	main.meta.coach_reset()
	if not await _step_menu():
		await _recover()
	if not await _step_first_intro():
		await _recover()
	elif not await _step_coach("premier lancement"):
		await _recover()
	if not await _step_replay_intro():
		await _recover()
	if not await _step_options("accueil"):
		await _recover()
	if not await _step_atelier():
		await _recover()
	if not await _step_wardrobe():
		await _recover()
	if not await _step_dojo():
		await _recover()
	for w in range(1, Worlds.WORLDS.size() + 1):
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


## Bouton de la pause à confirmer (RECOMMENCER, QUITTER) : le premier toucher ne fait que demander
## confirmation (la partie reste en pause), le second agit.
func _press_confirm(b: Control, what: String) -> bool:
	if not await _press(b, what):
		return false
	await _frames(2)
	if not _check(String(main.state) == "paused" and bool(b.get("accent")) and String(main.menu._confirm) != "",
			"pause : %s demande confirmation" % what, "état %s, confirmation « %s »" % [String(main.state), String(main.menu._confirm)]):
		return false
	return await _press(b, what + " (confirmé)")


## Retour à un état connu (accueil) après une étape en échec.
func _recover() -> void:
	print("BOT UI reprise : retour à l'accueil")
	bot.guard_all = true
	main.meta.intro_done = true
	main.meta.tuto_done = true
	for c in [main.intro, main.options, main.recap, main.refuge, main.worldmap, main.picker, main.wardrobe]:
		c.visible = false
	main._wardrobe_on = false
	main.tuto.abort_dojo()
	main.tuto.visible = false
	main.coach.clear()
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
	# pinceau JOUER posé, entrées à icône visibles et assez grandes pour le doigt
	var mn = main.menu
	await _until(func(): return float(mn._t) >= 1.6, "accueil : encre posée", 5.0)
	var small := ""
	for b in [mn._play, mn._atelier, mn._dojo, mn._wardrobe, mn._help, mn._gear, mn._sound]:
		var bc: Control = b
		if not bc.is_visible_in_tree() or bc.size.y < 40.0 or bc.size.x < 40.0:
			small += " " + String(bc.get("text")) + String(bc.get("icon"))
	_check(String(mn._play.style) == "brush" and float(mn._play.reveal) >= 1.0 and small == "",
		"accueil : pinceau JOUER et entrées ATELIER · DOJO · GARDE-ROBE", "JOUER %s (%.2f), trop petits ou cachés :%s" % [String(mn._play.style), float(mn._play.reveal), small])
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
	if not await _until(func(): return String(main.state) in ["intro", "play"] and bool(main.meta.intro_done) and bool(main.in_hub), "fin de l'intro -> monde 1 (sanctuaire)"):
		return false
	_check(int(main.current_world) == 1 and bool(main.gentle) and not bool(main.meta.tuto_done), "intro du premier lancement -> monde 1, tutoriel en jeu", "monde %d, adouci %s" % [int(main.current_world), str(main.gentle)])
	return true


## Tutoriel en jeu (coach) : au sanctuaire du monde 1, la bulle du premier trait arrive en arrêt sur image
## (jeu figé) ; un toucher après l'invite le lève sans tracer, puis temps ralenti ; un trait lève la bulle,
## enregistrée comme vue ; puis « PASSER » termine le tutoriel et l'on rentre.
func _step_coach(label: String) -> bool:
	var coach = main.coach
	if not await _until(func(): return String(main.state) == "play" and String(coach.mark) == "stroke", "coach (%s) : bulle « trace un trait » affichée" % label):
		return false
	_ok("coach (%s) : bulle 1 « trace un trait »" % label)
	await _frames(10)
	var ts := Engine.time_scale
	_check(ts < 0.01 and bool(coach.frozen()), "coach : arrêt sur image à la première bulle (%.2f)" % ts, "jeu non figé (%.2f)" % ts)
	# « TOUCHE POUR CONTINUER » : ce toucher lève l'arrêt sur image, sans lancer de trait
	if bool(coach.frozen()):
		if not await _until(func(): return bool(coach.hint_shown()) or not bool(coach.frozen()), "coach : invite « touche pour continuer »", 5.0):
			return false
		var tap := main.get_viewport().get_visible_rect().size * Vector2(0.5, 0.45)
		main._touch_down(tap)
		main._touch_move(tap + Vector2(40, -30))
		main._touch_up(tap + Vector2(40, -30))
		await _frames(5)
		_check(not bool(coach.frozen()) and not bool(main.touching) and main.stroke == null and not bool(main.hero.dashing) and String(coach.mark) == "stroke",
			"coach : le toucher lève l'arrêt sur image (sans trait)", "figé %s, trait %s, ruée %s" % [str(coach.frozen()), str(main.stroke != null), str(main.hero.dashing)])
	ts = Engine.time_scale
	_check(ts < 0.6, "coach : temps ralenti avant le premier trait (%.2f)" % ts, "temps normal (%.2f)" % ts)
	if not await _until(func(): return _hero_still(), "héros posé (coach)", 10.0):
		return false
	if not bot.stroke_line(main.hero.position + Vector3(0, 0, -3.0)):
		_fail("coach : premier trait impossible")
		return false
	if not await _until(func(): return String(coach.mark) != "stroke" and main.meta.coach_seen.has("stroke"), "coach : le trait lève la bulle 1"):
		return false
	_ok("coach : le premier trait lève la bulle")
	await _frames(5)
	ts = Engine.time_scale
	_check(ts > 0.9 or String(main.state) != "play", "coach : temps rétabli après le trait (%.2f)" % ts, "toujours ralenti (%.2f)" % ts)
	var cf := ConfigFile.new()
	var saved := cf.load(Meta.SAVE_PATH) == OK and bool(cf.get_value("coach", "stroke", false))
	_check(saved and not bool(main.meta.coach_first_run()), "coach : bulle vue enregistrée", "absente de la sauvegarde")
	return await _coach_pass_home()


## « PASSER » du coach (coin bas gauche, au doigt), puis retour à l'accueil.
func _coach_pass_home() -> bool:
	var coach = main.coach
	if not await _until(func(): return String(main.state) == "play" and bool(coach._skip_shown()) and coach._skip_rect.has_area(), "coach : PASSER affiché"):
		return false
	var r: Rect2 = coach._skip_rect
	var sp := r.get_center()
	main._touch_down(sp)
	main._touch_up(sp)
	await _frames(2)
	var all_seen := true
	for id in Meta.COACH_MARKS:
		if not main.meta.coach_seen.has(id):
			all_seen = false
	var cf := ConfigFile.new()
	var saved := cf.load(Meta.SAVE_PATH) == OK and bool(cf.get_value("meta", "tuto_done", false))
	_check(bool(main.meta.tuto_done) and all_seen and String(coach.mark) == "" and saved, "coach : PASSER termine le tutoriel", "tutoriel toujours actif")
	await _until(func(): return _hero_still(), "héros posé (coach)", 10.0)
	main._on_home()
	if not await _until(func(): return String(main.state) == "menu" and String(main.menu.mode) == "home", "coach : retour à l'accueil"):
		return false
	_ok("coach : retour à l'accueil")
	return true


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
	# « ? » jusqu'à la dernière planche : LANCER LE TUTORIEL (monde 1 avec le coach), puis PASSER
	await _press(main.menu._help, "?")
	if not await _until(func(): return bool(intro.visible), "« ? » rouvre l'intro"):
		return false
	if not await _intro_to_last():
		return false
	await _press(intro._tuto, "LANCER LE TUTORIEL")
	if not await _until(func(): return String(main.state) in ["intro", "play"] and bool(main.in_hub) and not bool(main.meta.tuto_done), "LANCER LE TUTORIEL -> monde 1, tutoriel en jeu"):
		return false
	_ok("intro « ? » : LANCER LE TUTORIEL")
	if not await _until(func(): return String(main.state) == "play" and String(main.coach.mark) == "stroke", "tutoriel revu : bulle « trace un trait »"):
		return false
	_ok("tutoriel revu : bulles remises à zéro")
	return await _coach_pass_home()


# ------------------------------------------------------------------ options

func _option_applied(key: String, val: String) -> bool:
	match key:
		"sound":
			return bool(main.menu.muted) == (val == "off")
		"vibration":
			return bool(main.sfx.haptics) == (val == "on")
		"tuto":
			return val == "replay" and not bool(main.meta.tuto_done) and main.meta.coach_seen.is_empty()
		"control":
			# choix enregistré pour le prochain lancement : le mode de la session ne bouge pas,
			# la note « redémarre » n'apparaît que si le choix diffère
			var opt = main.options
			return String(main.ctrl_pref) == val and String(main.ctrl_mode) == "screen" \
				and bool(opt.restart_pending()) == (val != String(main.ctrl_mode))
		"pad_size":
			return String(main.pad_size) == val
		"pad_show":
			return String(main.pad_show) == val
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
	# son, vibrations, contrôles (sur l'écran par défaut), taille et affichage du pad, revoir le tutoriel
	var keys: Array = []
	for row in Options.ROWS:
		keys.append(String(row["key"]))
	_check(keys == ["sound", "vibration", "control", "pad_size", "pad_show", "tuto"] and String(opt.values.get("control", "")) == "screen"
		and String(main.ctrl_mode) == "screen" and not bool(opt.restart_pending()),
		"options (%s) : contrôles sur l'écran par défaut, réglages du pad" % from, "lignes %s, contrôle « %s »" % [str(keys), String(opt.values.get("control", ""))])
	# en mode « sur l'écran », les réglages du pad sont grisés : aucune case touchable
	var dim_ok := true
	for h in opt._hits:
		if String(h[1]) in Options.PAD_KEYS:
			dim_ok = false
	_check(dim_ok, "options (%s) : réglages du pad grisés sur l'écran" % from, "cases du pad touchables")
	# les lignes dans l'ordre : CONTRÔLES finit sur PAD EN BAS, ce qui ouvre la taille et l'affichage du pad
	for row in Options.ROWS:
		if String(row["key"]) == "tuto":
			continue  # à part : elle remet le tutoriel à zéro
		for o in row["opts"]:
			await _option(String(row["key"]), String(o[0]), from == "accueil")
	# valeurs de départ (le contrôle en dernier : les réglages du pad se regrisent ensuite)
	for key in orig.keys():
		if String(key) != "tuto" and String(key) != "control":
			await _option(String(key), String(orig[key]), false)
	await _option("control", String(orig["control"]), true)
	_check(String(main.ctrl_mode) == "screen" and String(main.ctrl_pref) == "screen" and not bool(opt.restart_pending()),
		"options (%s) : PAD EN BAS annulé sans redémarrer" % from, "contrôle %s / choix %s" % [String(main.ctrl_mode), String(main.ctrl_pref)])
	# « revoir le tutoriel » : bulles du coach remises à zéro, puis état d'avant rétabli (suite du parcours)
	var seen0: Dictionary = main.meta.coach_seen.duplicate()
	var done0 := bool(main.meta.tuto_done)
	await _option("tuto", "replay", true)
	main.meta.coach_seen = seen0
	main.meta.tuto_done = done0
	main.meta.save_data()
	main.coach.clear()
	if done0:
		opt.values.erase("tuto")
	_check(bool(main.menu.muted) == (String(orig["sound"]) == "off") and bool(main.sfx.haptics) == (String(orig["vibration"]) == "on"), "options (%s) : valeurs rétablies" % from, "réglages non rétablis")
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


# ------------------------------------------------------------------ garde-robe

## Toucher une cible de la garde-robe (onglet, élément) à son rectangle, sinon par la même suite.
func _wd_tap(key: String) -> void:
	var wd = main.wardrobe
	await _frame()
	var r := Rect2()
	for hr in wd._hits:
		if String(hr[1]) == key:
			r = hr[0]
	if r.has_area() and String(wd._target_at(r.get_center())) == key:
		_tap(wd, r.get_center())
	else:
		wd.tap(key)
	await _frames(2)


## Garde-robe : tenue achetée à l'encre et portée, une apparence par type (écharpe, sillage, encre),
## thème Nuit acheté et appliqué à l'accueil, retour au Washi, puis RETOUR.
func _step_wardrobe() -> bool:
	var meta = main.meta
	var wd = main.wardrobe
	meta.sumi = maxi(int(meta.sumi), 5000)
	main.menu.sumi = meta.sumi
	await _press(main.menu._wardrobe, "GARDE-ROBE")
	if not await _until(func(): return bool(wd.visible) and float(wd._t) >= 0.4 and wd._hits.size() > 0, "GARDE-ROBE ouvre la garde-robe"):
		return false
	_ok("garde-robe ouverte")
	await _wd_tap("tab:0")
	var oid := "kaki"
	if not bool(meta.cosmetic_owned("outfit", oid)):
		await _wd_tap("item:" + oid)
		await _press(wd._buy, "ACHETER")
	else:
		await _wd_tap("item:" + oid)
	_check(String(meta.outfit) == oid and bool(meta.cosmetic_owned("outfit", oid)), "garde-robe : tenue %s achetée et portée" % oid, "tenue %s" % String(meta.outfit))
	for i in range(1, 4):
		var kind := String(wd.CATS[i])
		await _wd_tap("tab:%d" % i)
		var ids: Array = meta.cosmetic_ids(kind)
		var pid := String(ids[ids.size() - 1])
		meta._grant(pid)
		await _wd_tap("item:" + pid)
		_check(bool(meta.cosmetic_worn(kind, pid)), "garde-robe : %s porté (%s)" % [kind, pid], "non porté")
	await _wd_tap("tab:4")
	await _wd_tap("item:nuit")
	if not bool(meta.cosmetic_owned("theme", "nuit")):
		await _press(wd._buy, "ACHETER")
	var nuit: Dictionary = Meta.THEMES["nuit"]
	_check(String(meta.theme) == "nuit" and main.menu.th_paper == nuit["paper"], "garde-robe : thème Nuit appliqué", "thème %s" % String(meta.theme))
	await _wd_tap("item:washi")
	_check(String(meta.theme) == "washi", "garde-robe : retour au thème Washi", "thème %s" % String(meta.theme))
	await _press(wd._back, "RETOUR")
	if not await _until(func(): return not bool(wd.visible) and String(main.state) == "menu" and bool(main.menu.visible), "garde-robe : RETOUR -> accueil"):
		return false
	_ok("garde-robe : RETOUR")
	return true


# ------------------------------------------------------------------ dojo

## Dojo : entrée depuis l'accueil, quelques figures et traits ratés (verdict), un trait à travers trois
## mannequins, une esquive, le mannequin offensif (zone rouge), le carnet, l'ultime au double tap, puis la maison.
func _step_dojo() -> bool:
	var dj = main.tuto.dojo
	await _press(main.menu._dojo, "DOJO")
	if not await _until(func(): return String(main.state) == "tuto" and bool(main.tuto.in_dojo()) and bool(dj.visible), "DOJO ouvre le dojo"):
		return false
	if not await _until(func(): return _dummies().size() >= 3, "dojo : mannequins en place"):
		return false
	_ok("dojo ouvert (%d mannequins)" % _dummies().size())
	# figures : quelques essais jusqu'à une figure reconnue
	var kinds := ["loop", "zigzag", "enso", "straight", "loop", "zigzag"]
	for k in kinds:
		if int(dj.total_figures()) >= 2:
			break
		if not await _until(func(): return _hero_still(), "héros posé (dojo)", 10.0):
			return false
		var dm := _dummies()
		var target := Vector3.ZERO
		if not dm.is_empty():
			target = dm[0].position
		if not bot.figure(String(k), target):
			bot.stroke_line(Vector3(0, 0, 1))
		await _until(func(): return _hero_still(), "fin de la ruée (dojo)", 10.0)
		await _frames(3)
	_check(int(dj.total_figures()) >= 1, "dojo : figures reconnues et comptées (%d)" % int(dj.total_figures()), "aucune figure comptée")
	# trait trop court pour une figure : un verdict s'affiche
	await _until(func(): return _hero_still(), "héros posé (dojo)", 10.0)
	dj.last_verdict = ""
	var hp: Vector3 = main.hero.position
	var side := Vector3(1.3, 0, 0)
	if hp.x > 0.0:
		side = Vector3(-1.3, 0, 0)  # vers le milieu de l'arène
	bot._stroke_points(PackedVector3Array([hp + side]))
	await _until(func(): return _hero_still(), "fin de la ruée (dojo)", 10.0)
	await _frames(3)
	_check(String(dj.last_verdict) != "", "dojo : verdict d'un trait non reconnu (%s)" % String(dj.last_verdict), "aucun verdict")
	# un trait à travers trois mannequins
	if await _until(func(): return _dummies().size() >= 3 and _hero_still(), "dojo : trois mannequins", 10.0):
		var d3 := _dummies()
		bot._stroke_points(PackedVector3Array([d3[0].position, d3[1].position, d3[2].position]))
		await _until(func(): return _hero_still(), "fin de la ruée (dojo)", 10.0)
		await _frames(3)
		_check(dj.done.has("multi3"), "dojo : défi « 3 mannequins d'un trait »", "défi non coché")
	# esquive
	await _until(func(): return _hero_still(), "héros posé (dojo)", 10.0)
	var dg0 := int(dj.dodges)
	var hd: Vector3 = main.hero.position
	bot.dodge(Vector3(-hd.x, 0, -hd.z))
	await _until(func(): return _hero_still(), "fin du bond (dojo)", 10.0)
	await _frames(3)
	_check(int(dj.dodges) > dg0, "dojo : esquive comptée", "esquive non comptée")
	# mannequin offensif : une zone rouge à esquiver
	await _press(dj._off, "OFFENSIF")
	_check(bool(dj.offensive), "dojo : mannequin offensif activé", "toujours inactif")
	var tries := 0
	while int(dj.zones_ok) < 1 and tries < 4:
		tries += 1
		if not await _until(func(): return dj._zone != null, "dojo : zone rouge annoncée", 10.0):
			break
		await _until(func(): return _hero_still(), "héros posé (dojo)", 10.0)
		var hz: Vector3 = main.hero.position
		bot.dodge(Vector3(-hz.x, 0, -hz.z))
		await _until(func(): return dj._zone == null, "dojo : impact de la zone rouge", 10.0)
		await _frames(2)
	_check(int(dj.zones_ok) >= 1 and dj.done.has("zone"), "dojo : zone rouge esquivée", "aucune zone esquivée")
	await _press(dj._off, "OFFENSIF")
	_check(not bool(dj.offensive) and dj._zone == null, "dojo : mannequin offensif désactivé", "toujours actif")
	# carnet : déplié puis replié
	await _press(dj._book, "CARNET")
	if await _until(func(): return bool(dj.open) and float(dj._open_k) > 0.9, "dojo : carnet déplié", 5.0):
		_ok("dojo : carnet déplié")
	await _press(dj._book, "FERMER")
	if await _until(func(): return not bool(dj.open) and float(dj._open_k) < 0.1, "dojo : carnet replié", 5.0):
		_ok("dojo : carnet replié")
	# ultime : jauge pleine, double tap sur le héros
	await _until(func(): return _hero_still() and not bool(main.touching), "héros posé (dojo)", 10.0)
	main.ult = 1.0
	var sp: Vector2 = main.cam.unproject_position(main.hero.position)
	main._touch_down(sp)
	main._touch_up(sp)
	main._touch_down(sp)
	main._touch_up(sp)
	await _frames(3)
	_check(int(dj.ults) >= 1 and dj.done.has("ult"), "dojo : ultime au double tap", "ultime non lancé")
	await _until(func(): return _hero_still(), "fin du bond (dojo)", 10.0)
	# maison : retour à l'accueil
	await _press(dj._home, "maison du dojo")
	if not await _until(func(): return String(main.state) == "menu" and not bool(main.tuto.visible) and not bool(main.tuto.in_dojo()), "dojo quitté -> accueil"):
		return false
	_ok("dojo quitté (bouton maison)")
	return true


# ------------------------------------------------------------------ mondes

func _step_world(w: int) -> bool:
	var wm = main.worldmap
	await _press(main.menu._play, "JOUER")
	if not await _until(func(): return String(main.state) == "worlds" and bool(wm.visible), "JOUER -> barque -> carte des mondes"):
		return false
	_ok("monde %d : barque et carte des mondes" % w)
	_check(not bool(main.arena._room_root.visible), "monde %d : accueil sans plateau (décor seul)" % w, "salle visible sous la carte")
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
	_check(bool(main.arena._room_root.visible), "monde %d : sanctuaire affiché en jeu" % w, "salle cachée en jeu")
	if w == 1:
		await _step_run()  # course au doigt posé, dans le sanctuaire (hors combat)
	if not await _transit_to_room1(w):
		return false
	if w == 1:
		if not await _step_pause_recap():
			return false
		if not await _step_pickers():
			return false
		if not await _step_sanctuary():
			return false
		if not await _step_flawless():
			return false
		if not await _step_puzzles():
			return false
	if not await _boss_intro(w, int(main.MINI_ROOM)):
		return false
	if not await _boss_intro(w, int(main.ROOMS)):
		return false
	if w == 1:
		return await _step_victory()
	if w == 2:
		return await _step_defeat()
	if w == 3:
		return await _step_defeat_atelier()
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
	if not await _until(func(): return String(main.state) == "play" and not bool(main.in_hub) and bool(main.arena.stage), "monde %d : transit -> étape 1" % w):
		return false
	_ok("monde %d : torii, transit, étape 1 (%s)" % [w, String(main.arena.layout)])
	# l'étape avance : on marche jusqu'à la première zone de combat, qui se ferme derrière le héros
	t0 = Time.get_ticks_msec()
	while int(main.room) < 1:
		if Time.get_ticks_msec() - t0 > int(TIMEOUT * 1000.0):
			_fail("monde %d : zone de combat 1 jamais atteinte" % w)
			return false
		if String(main.state) == "play" and _hero_still():
			var g: Vector3 = main.arena.next_goal()
			if g != Vector3.INF:
				bot.stroke_line(g)
		await _frames(4)
	if not await _until(func(): return String(main.state) == "play" and int(main.room) == 1 and int(main._enc) == 0, "monde %d : entrée dans la zone 1" % w):
		return false
	_ok("monde %d : marche dans l'étape, zone de combat 1 fermée" % w)
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
	if not await _press_confirm(main.menu._quit, "QUITTER"):
		return false
	if not await _until(func(): return String(main.state) == "menu", "pause : QUITTER -> accueil"):
		return false
	_ok("monde %d : pause, QUITTER -> accueil" % w)
	return true


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
	# en jeu, le récapitulatif ouvert directement (jeu en pause) se referme sur le jeu
	await _frames(3)
	main._open_recap()
	if not await _until(func(): return bool(rc.visible) and String(main.state) == "paused", "jeu -> récapitulatif"):
		return false
	await _until(func(): return float(rc._t) >= 0.35, "récapitulatif prêt")
	back = rc._back
	_tap(rc, back.get_center())
	if not await _until(func(): return not bool(rc.visible) and String(main.state) == "play", "récapitulatif -> retour au jeu"):
		return false
	_ok("récapitulatif depuis le jeu (appel direct)")
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


## Combat nettoyé par le vrai chemin (ennemis achevés), haie ou torii ouvert, rouleaux de niveau en attente résolus.
func _clear_room() -> bool:
	var t0 := Time.get_ticks_msec()
	while not (bool(main._room_done) and (bool(main.arena.gate_open) or int(main._enc) < 0)):
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
		var g0: int = main.run_gold
		var hp0: int = main.hero.hp
		var idx: int = 0 if take else main.picker._ids.size() - 1  # la dernière carte : « Passer »
		if not await _pick_card(idx, "sanctuaire"):
			return false
		await _settle_play("après le pacte")
		var want: int = nc + (1 if take else 0)
		_check(main.curses.size() == want, "sanctuaire : %s" % ("malédiction acceptée %s" % str(main.curses) if take else "PASSER"), "%d malédiction(s), attendu %d" % [main.curses.size(), want])
		if not take:
			# « Passer » rapporte un cœur (s'il en manque) ou un peu d'or
			_check(int(main.run_gold) >= g0 + int(main.PASS_GOLD) or int(main.hero.hp) > hp0, "sanctuaire : PASSER donne son bonus (or %d -> %d, vie %d -> %d)" % [g0, int(main.run_gold), hp0, int(main.hero.hp)], "aucun bonus")
	return true


## Course au doigt posé (sanctuaire, hors combat) : un trait, le doigt s'immobilise, la ruée part et le héros
## continue de courir ; il s'arrête au relâché.
func _step_run() -> bool:
	if not await _until(func(): return String(main.state) == "play" and _hero_still() and bool(main._explore), "sanctuaire : héros posé, hors combat"):
		return false
	var hp: Vector3 = main.hero.position
	var dir := Vector3(1, 0, 0) if hp.x < 0.0 else Vector3(-1, 0, 0)
	var sp0: Vector2 = main.cam.unproject_position(hp)
	var sp1: Vector2 = main.cam.unproject_position(hp + dir * 1.6)
	if bool(main.hud.is_over_pause(sp0)):
		_ok("course au doigt posé : point de départ sous un bouton du HUD, étape passée")
		return true
	main._touch_down(sp0)
	for i in 6:
		main._touch_move(sp0.lerp(sp1, float(i + 1) / 6.0))
		await _frame()
	if not await _until(func(): return bool(main._running), "course : le doigt immobile lance la course", 5.0):
		main._touch_up(sp1)
		return false
	# le doigt pousse un peu plus loin dans la même direction, devant le héros
	var sp2: Vector2 = main.cam.unproject_position(main.hero.dash_end() + dir * 3.0)
	main._touch_move(sp2)
	await _until(func(): return float(main.run_dist) > 0.6 or not bool(main._running), "course : le héros court", 4.0)
	var ran: float = main.run_dist
	main._touch_up(sp2)
	await _frames(2)
	return _check(ran > 0.6 and not bool(main._running) and not bool(main.touching), "course au doigt posé (%.1f m courus)" % ran, "%.2f m courus, course %s" % [ran, str(main._running)])


## Gardien vaincu sans dégât : le rouleau « sans une égratignure » (épiques ou légendaires), choisi au toucher.
func _step_flawless() -> bool:
	await _settle_play("avant le rouleau sans égratignure")
	var pk = main.picker
	var p = main.powers
	main._flawless_pending = true
	if not await _until(func(): return String(main.state) == "pick" and bool(pk.visible) and String(main._pick_mode) == "flawless", "rouleau sans une égratignure ouvert"):
		main._flawless_pending = false
		return false
	var worst := 9
	for id in pk._ids:
		var d: Dictionary = PowerData.POWERS.get(String(id), {})
		var rd: Dictionary = PowerData.RARITIES.get(String(d.get("rarity", "common")), {})
		worst = mini(worst, int(rd.get("rank", 0)))
	_check(worst >= 2 and String(pk._title_text) == "SANS UNE ÉGRATIGNURE", "rouleau sans une égratignure : %s" % str(pk._ids), "rang le plus bas %d, titre « %s »" % [worst, String(pk._title_text)])
	if pk._ids.is_empty():
		return false
	var chosen := String(pk._ids[0])
	var l0 := int(p.lvl(chosen))
	if not await _pick_card(0, "rouleau sans une égratignure"):
		return false
	await _settle_play("après le rouleau sans égratignure")
	return _check(int(p.lvl(chosen)) > l0, "rouleau sans une égratignure : %s choisi au toucher" % chosen, "niveau inchangé")


## Énigmes des recoins : chacune posée au pied du héros (hors combat), consigne à l'approche, résolue d'un trait.
func _step_puzzles() -> bool:
	var ok := true
	for kind in ["stele", "lanterns", "spirit"]:
		await _settle_play("avant l'énigme %s" % kind)
		if not await _until(func(): return _hero_still() and bool(main._explore) and String(main.state) == "play", "énigme %s : héros posé hors combat" % kind):
			return false
		var pk: Dictionary = main.spawn_puzzle(String(kind), main.hero.position)
		await _frames(3)
		_check(bool(pk["hinted"]), "énigme %s : consigne affichée à l'approche" % String(pk["pz"]), "pas de consigne")
		var tries := 0
		while not bool(pk["used"]) and tries < 4:
			tries += 1
			if not await _until(func(): return _hero_still(), "énigme : héros posé", 10.0):
				break
			main.hero.position = pk["pos"]  # au centre de l'énigme, comme le robot de campagne
			main._prev_hero = main.hero.position
			bot.solve_puzzle(pk)
			await _until(func(): return _hero_still(), "énigme : fin du trait", 10.0)
			await _frames(3)
		ok = _check(bool(pk["used"]), "énigme %s résolue d'un trait (%d essai(s))" % [String(pk["pz"]), tries], "non résolue") and ok
	return ok


func _step_victory() -> bool:
	await _settle_play("avant la victoire")
	# progression remise au début : cette victoire doit ouvrir le monde 2 et le palier 1 des rouleaux
	# (le robot joue avec tout débloqué, meta.test_unlock_all : seule la feuille de résultats en dépend)
	main.meta.unlocked = 1
	main.meta.power_tier = 0
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
	var menu = main.menu
	var n_new: int = main.meta.powers_of_tier(1).size()
	_check(int(menu.unlock_world) == 2 and menu.unlock_powers.size() == n_new and n_new > 0 and int(menu._unlock_rows()) == 2,
		"résultats : DÉBLOQUÉ (monde 2, %d rouleaux « %s »)" % [menu.unlock_powers.size(), String(menu.unlock_family)],
		"monde %d, %d rouleaux (attendu 2 et %d)" % [int(menu.unlock_world), menu.unlock_powers.size(), n_new])
	_check(int(main.meta.unlocked) == 2 and int(main.meta.power_tier) == 1, "victoire : monde 2 et palier 1 enregistrés", "unlocked %d, palier %d" % [int(main.meta.unlocked), int(main.meta.power_tier)])
	await _until(func(): return float(menu._t) >= 0.7, "résultats prêts")
	_check(String(menu.next_label) == "DÉCOUVRIR LE MONDE SUIVANT" and menu._next.is_visible_in_tree() and menu._replay.is_visible_in_tree()
		and menu._over_atelier.is_visible_in_tree() and menu._home.is_visible_in_tree() and String(menu._replay.style) == "text" and String(menu._next.style) == "brush",
		"résultats de victoire : DÉCOUVRIR LE MONDE SUIVANT, puis REJOUER / ATELIER / ACCUEIL", "bouton « %s », REJOUER %s" % [String(menu.next_label), String(menu._replay.style)])
	# vers la carte : centrée sur le monde vaincu, elle se déroule jusqu'au monde 2 et brise son sceau
	var wm = main.worldmap
	await _press(menu._next, "DÉCOUVRIR LE MONDE SUIVANT")
	if not await _until(func(): return String(main.state) == "worlds" and bool(wm.visible), "DÉCOUVRIR LE MONDE SUIVANT -> carte des mondes"):
		return false
	_check(int(wm._reveal_id) == 2 and int(wm._sel()) == 0 and bool(wm._locked(1)) and not wm._go.is_visible_in_tree(),
		"carte : centrée sur le monde 1, monde 2 encore scellé, PARTIR caché", "révélé %d, centré %d" % [int(wm._reveal_id), int(wm._sel())])
	if not await _until(func(): return bool(wm._rv_broken), "carte : le sceau du monde 2 se brise"):
		return false
	_check(int(wm._sel()) == 1 and not bool(wm._locked(1)), "carte : rouleau déroulé jusqu'au monde 2, sceau brisé", "centré %d" % int(wm._sel()))
	if not await _until(func(): return float(wm._rv) >= float(wm.RV_CARD) + 0.5, "carte du monde 2 levée"):
		return false
	_ok("carte : carte du monde 2 (nom, ambiance, nouveaux rouleaux)")
	_tap(wm, wm.size / 2.0)  # un toucher l'efface
	if not await _until(func(): return bool(wm._reveal_done()) and wm._go.is_visible_in_tree(), "carte effacée -> PARTIR"):
		return false
	_ok("carte : révélation finie, PARTIR disponible sur le monde 2")
	await _press(wm._back, "maison de la carte")
	if not await _until(func(): return String(main.state) == "menu" and not bool(wm.visible), "carte : retour à l'accueil"):
		return false
	_ok("résultats de victoire -> carte -> accueil")
	return true


## Défaite au monde 3 : REJOUER reste le bouton principal ; ATELIER des résultats, puis accueil.
func _step_defeat_atelier() -> bool:
	if not await _die():
		return false
	var menu = main.menu
	_check(not bool(menu.victory) and String(menu.next_label) == "" and not menu._next.is_visible_in_tree() and String(menu._replay.style) == "brush",
		"résultats de défaite (monde 3) : REJOUER principal", "bouton suivant « %s »" % String(menu.next_label))
	await _press(menu._over_atelier, "ATELIER des résultats")
	if not await _until(func(): return bool(main.refuge.visible), "résultats : ATELIER"):
		return false
	await _until(func(): return float(main.refuge._t) >= 0.4, "atelier prêt")
	await _ref_tap("back")
	if not await _until(func(): return String(main.state) == "menu", "atelier -> accueil"):
		return false
	_ok("résultats : ATELIER puis accueil")
	return true


## Le héros tombe par le vrai chemin (_hurt_hero) jusqu'aux résultats prêts.
func _die() -> bool:
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
	await _until(func(): return float(main.menu._t) >= 0.7, "résultats prêts")
	return true


func _step_defeat() -> bool:
	if not await _die():
		return false
	_check(not bool(main.menu.victory) and not main.menu._next.is_visible_in_tree(), "résultats de défaite (coup fatal : %s%s)" % [String(main.menu.killer_name), String(main.menu.killer_kind)], "menu.victory vrai ou bouton monde suivant")
	await _press(main.menu._replay, "REJOUER")
	if not await _until(func(): return String(main.state) == "play" and bool(main.in_hub), "REJOUER -> sanctuaire"):
		return false
	_ok("résultats : REJOUER")
	await _press(main.hud._pause, "pause")
	if not await _until(func(): return String(main.state) == "paused", "pause"):
		return false
	if not await _press_confirm(main.menu._restart, "RECOMMENCER"):
		return false
	if not await _until(func(): return String(main.state) == "play" and bool(main.in_hub) and int(main.room) == 0, "RECOMMENCER -> sanctuaire"):
		return false
	_ok("pause : RECOMMENCER")
	return await _quit_to_menu(2)
