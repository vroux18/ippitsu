# Ippitsu — bible d'univers

*v1 — 5 octobre 2026. Document de game design destiné à l'implémentation Godot 4.*
*Unités : mètres (m), secondes (s), dégâts en « coups » (1.0 = un coup de base du ronin). PV ennemis dans la même unité.*

---

## État actuel du jeu (8 octobre 2026)

*Ce résumé fait foi pour ce qui est implémenté ; la suite du document est la vision v1 d'origine (salles, héros multiples, boutique… : en partie remplacée).*

- **Commandes** (un doigt) : tracer = ruée qui tranche ; **tap** = bond d'esquive gratuit (recharge 0.7 s ; un petit glissé choisit la direction) ; **double tap** = ultime quand le sceau 筆 est plein ; doigt posé hors combat = course. Pad tactile en bas (ou tracé direct sur l'écran, option).
- **HUD** : vie, niveau / XP et or en haut à gauche, chaîne dessous ; sceau du monde + étape (x / 8) au centre ; pause en haut à droite ; **jauge d'encre verticale sur le bord droit** avec le sceau d'ultime ; colonne de progression de l'étape à gauche. Les pouvoirs ne sont plus affichés en jeu (pause → MES POUVOIRS, et bilan de fin).
- **Structure** : accueil (barque) → sanctuaire de départ (dojo, torii) → **5 mondes × 8 étapes**. Une étape = longue carte vers le fond avec des **zones de combat** (vagues d'ennemis, haies sacrées qui se ferment), des recoins (coffre, source, défi d'élite, énigmes stèle / lanternes / esprit) et un torii au bout. 15 combats par monde (`STAGE_PLAN`) : étape 4 = arène du **mini-boss**, étape 8 = **boss**. Sanctuaire de malédiction après les combats 5 et 10. Battre le boss ouvre le monde suivant (carte emakimono).
- **Mondes et bestiaire** (`worlds.gd`, `enemy.gd`) : base commune oni, kappa, brute, tate (bouclier frontal), funa ; puis
  1 Grande Vague — umibozu, kappa_yumi, ika, umi_nyobo ;
  2 Tanabata — kitsunebi, kamaitachi, tanuki, kitsune_tsukai ;
  3 Cent Contes — yukionna, yuki_warashi, onryo, tsurara ;
  4 Fuji Rouge — kasha, hinotama, teppo, tengu, kanabo, moryo ;
  5 Trente-six Vues — kagebo, sumidama, kasa, moryo, onryo, teppo, tengu.
  PV ×1.0 → ×1.6 du monde 1 au monde 5.
- **Gardiens / boss** : mini-boss Ō-Kappa, Tsuchigumo, Yuki-onna, Ibaraki-dōji, Bakekujira ; boss Uwabami, Kyūbi, Gashadokuro, Daidarabotchi, Kuro-Nami. Chacun a un point faible (geste) affiché sous sa barre.
- **Boucliers et élites** : barre bleue — tant qu'il en reste, un coup n'entame que 25 % ; figures et pouvoirs l'usent ×2. Élites (dès le 4e combat) : ×2.5 PV, bouclier, aura et cornes d'or, 1–2 affixes (blindé, rapide, vampire, explosif, invocateur, enragé).
- **Progression de partie** : XP et or au sol ; chaque niveau = un **rouleau** parmi 3. **59 pouvoirs** (`power_data.gd`) en 4 raretés (21 communs, 16 rares, 13 épiques, 9 légendaires) et 7 écoles (feu, eau, foudre, vent, ombre, encre, figure) ; affinités à 2 et 4 pouvoirs d'une école, synergies ; paliers de déblocage par monde vaincu.
- **Figures** (`stroke_shapes.gd`) : boucle, zigzag, trait droit, aller-retour, ensō, crochet. Tracée sans son rouleau : +1 chaîne et +15 % de dégâts ; son **rouleau de figure** (école « figure », 16 rouleaux) débloque la technique puis l'améliore.
- **Méta (Atelier)** : encre (sumi) → Pierre à encre (6 lignes à rangs) ; sceaux (dons permanents, légendaires) ; collection d'estampes (Vues) qui débloquent des apparences.
- **Tests** : robots du CI `bot.gd` (campaign, powers, stress), `bot_ui.gd` (parcours des écrans), `bot_shapes.gd` (figures).

---

## 0. Rappels et conventions

### 0.1 Valeurs actuelles du prototype (référence d'équilibrage)
| Constante (`main.gd` / `hero.gd`) | Valeur | Rôle |
|---|---|---|
| `ELAN_MAX` | 14 m | longueur de trait max |
| `ELAN_REGEN` | 9 m/s | recharge hors tracé |
| `ELAN_PER_HIT` | 3.5 m | élan rendu par ennemi tranché |
| `DODGE_DIST` / `DODGE_COOLDOWN` | 2.4 m / 0.7 s | bond d'esquive gratuit (tap) |
| `HIT_REACH` | 0.55 m | demi-largeur de la coupe |
| `DASH_SPEED` | 34 m/s | vitesse de ruée |
| Dégâts combo | `1.0 × (1 + 0.5 × (combo−1))` | ×1, ×1.5, ×2… |
| Combo ≥ 3 | élan rempli | |
| Héros | 5 PV, invuln 1.2 s après coup | |
| Arène | 9.2 × 17.2 m (`HALF = 4.6, 8.6`) | portrait |
| Ennemis | `oni` (Minion, 1 PV, zone r1.0, annonce 1.0 s), `kappa` (Mage, 1 PV, tir toutes les 2.6–3.8 s), `brute` (Warrior, 3.5 PV, zone r1.5, annonce 1.2 s, non interruptible) | |

### 0.2 Le tracé SANS ralenti (décision du propriétaire)
Le temps ne ralentit plus quand on pose le doigt. Conséquences de design, à appliquer partout :

1. **Le tracé est un geste rapide** (0.2–0.5 s en moyenne). Pendant le tracé, le héros reste sur place, en garde : il est **touchable**. La ruée reste intouchable.
2. **Règles de lisibilité (obligatoires pour tout ennemi/danger)** :
   - Annonce de zone ≥ **0.9 s** en monde 1, plancher absolu **0.65 s** en monde 5 (et malédictions).
   - Projectiles ≤ **5 m/s** en monde 1 (≤ 7 m/s monde 5), diamètre visuel ≥ 0.45 m, vermillon ou or, avec traînée.
   - **Jeton d'attaque** : au plus N ennemis en phase d'annonce simultanément (N = 2 monde 1, 3 mondes 2–4, 4 monde 5). Un ennemi sans jeton attend (il tourne autour, ~1 m/s). C'est le réglage n°1 de difficulté perçue.
   - Les annonces vermillon se remplissent ; la dernière **0.15 s** elles flashent blanc écume (#E9EEF0) : c'est le « maintenant ».
3. **Marqueur d'arrivée** : pendant le tracé, un petit cercle d'encre au bout du trait. Il devient **vermillon** s'il est dans une zone annoncée qui se déclenchera avant ~0.3 s après l'arrivée prévue (calcul : temps de ruée = longueur / vitesse). C'est le remplaçant direct du ralenti : on ne voit plus venir en ralenti, on voit *où il ne faut pas finir*.
4. **Filet de sécurité** conservé (1 pas de côté auto par salle) ; il s'applique aussi pendant le tracé.
5. **Le ralenti devient un pouvoir** (rare, donc précieux) : amélioration Vent « Souffle suspendu », amélioration Ombre « Instant volé », passif du héros Kohaku, malédiction inverse. Voir §3 et §4.
6. Réglage d'accessibilité (désactivé par défaut, dans les options) : « Ralenti d'aide » 60 % au doigt posé, sans récompense de fin (pas de sceau). À garder si les tests canapé montrent un mur de difficulté.

---

## 1. Prétexte (volontairement minimal)

- **Prétexte** : un vieux peintre d'estampes (clin d'œil à Hokusai, qui signait « le vieux fou de dessin ») voit la **Vague Noire**, *Kuro-Nami*, s'échapper de sa Grande Vague et dévorer ses estampes. Il peint un guerrier d'un seul coup de pinceau — *ippitsu* — et l'envoie dedans. Mort = l'encre coule, il repeint le héros.
- **Refuge** : l'atelier du peintre (maison sur pilotis, Fuji au fond). Hub de méta-progression (§5).
- **« Histoire qui avance à chaque mort »** : uniquement une **estampe** de plus accrochée au mur de l'atelier (collection des « 36 Vues », §5.1). Zéro dialogue, zéro cinématique. Fin : on referme la Vague d'un ensō (boss final).

C'est tout : l'effort va sur les mondes, ennemis, pouvoirs et la progression.

---

## 2. Les cinq mondes

### 2.0 Le fil rouge : Hokusai et le Japon
Chaque monde **est une œuvre de Hokusai** (ou une série) dans laquelle on entre, enrichie d'un lieu, d'une fête, d'objets et d'une nourriture japonaise reconnaissables. Le fond peint de chaque arène reprend la composition de l'estampe de référence (cadrage, Fuji minuscule, vague, nuages en bandes).

| Monde | Estampe(s) Hokusai de référence | Lieu évoqué | Fête / saison | Objets signature (props, récompenses) | Cuisine (soins / boutique) |
|---|---|---|---|---|---|
| 1 **Grande Vague** | *Sous la vague au large de Kanagawa* ; *Fuji vu de la mer à Kanagawa* | baie de Kanagawa, port de pêche d'Enoshima | **Hatsu-hinode** (1er lever de soleil de l'an) : soleil vermillon à l'horizon | barques *oshiokuri*, filets, lanternes de port, bouées de verre, daruma pêcheur | **onigiri** (+1 PV), poulpe grillé *takoyaki* (boutique) |
| 2 **Tanabata** | *Feux de renards la nuit du Nouvel An à Ōji* ; *Kirifuri no taki* (cascades) | bambouseraie d'Arashiyama, torii en rangées de Fushimi Inari | **Tanabata** (fête des étoiles) : bandes de papier *tanzaku* colorées sur les bambous | tanzaku, masques de renard *kitsune-men*, lanternes de sanctuaire, statues de renard, cascade de fond | **inari-zushi** (+1 PV), **dango** 3 couleurs (boutique) |
| 3 **Cent Contes** | série *Hyaku monogatari* (le fantôme d'Oiwa dans la lanterne, Okiku et les assiettes de Sarayashiki) ; *Neige sur la rivière Sumida* | temple de montagne enneigé, cimetière, Nikkō | **Obon** (fête des morts) : lanternes flottantes *tōrō nagashi* ; neige de l'hiver | lanternes en papier, assiettes de porcelaine, ombrelles *wagasa*, cloche *bonshō*, statues *jizō* | **soupe miso fumante** (+1 PV), **amazake** (boutique) |
| 4 **Fuji Rouge** | *Fuji rouge* (*Gaifū kaisei*) ; *Orage sous le sommet* (éclairs sous le Fuji) | intérieur du Fuji, forges de sabres de Seki, onsen volcaniques | **Yamabiraki** (ouverture de la saison d'ascension) ; feu de **Yoshida Hi-Matsuri** (torches géantes) | enclumes, katanas en forge, torches de Yoshida, masques d'oni, *kanabō* | **onsen tamago** (œuf cuit à la source, +1 PV), **yakitori** (boutique) |
| 5 **Trente-six Vues** | toute la série *Trente-six vues du mont Fuji* + *Manga* de Hokusai (croquis) | chaque salle = une Vue différente (Ejiri, Kajikawa, Mishima, pont de Mannen, tonnelier de Fujimigahara, Shichiri-ga-hama…) | **Shōgatsu** (Nouvel An) : *kadomatsu*, *kagami-mochi* | papiers qui s'envolent (Ejiri), barrique géante (tonnelier), pont de Mannen, sceaux de peintre, pinceaux | **mochi** (+1 PV), **soba** de fin d'année (boutique) |

Règles transverses :
- Les **rouleaux d'amélioration** sont présentés comme de petites estampes (cadre washi, cartouche vertical façon titre d'estampe avec le nom).
- Les **morts d'ennemis** se dessèchent en encre et s'envolent en papier.
- Chaque boss vaincu = une **estampe dorée** dans l'atelier, composée comme une vraie planche de Hokusai (ex. Uwabami dans la Grande Vague).
- La **boutique** est un stand de *matsuri* (fête de quartier) tenu par un tanuki : lanternes, *yatai*, poissons rouges.

### 2.1 Palette et ordre

Palette commune : washi `#EFE6D2` · sumi `#1B1A1E` · vermillon `#D7372B` (coups, danger) · bleu de Prusse `#1F3A5F` · écume `#E9EEF0` · or `#C49A45` (récompenses).
Règle : **le vermillon reste réservé au danger et aux coups du joueur** dans tous les mondes ; les couleurs propres au monde ne doivent jamais ressembler à une annonce.

Ordre de déblocage : 1 → 2 → 3 → 4 → 5. Une partie = **un monde** (v1 : 9 salles ; aujourd'hui 8 étapes, voir « État actuel »). Battre le boss d'un monde ouvre le suivant au départ de l'atelier (§6).

---

### Monde 1 — GRANDE VAGUE (Kanagawa)
*Le monde du prototype. Estampe : « Sous la vague au large de Kanagawa ».*

- **Ambiance** : ponton de bois au-dessus de la baie de Kanagawa, vent salé, **la Grande Vague figée à l'horizon, griffes d'écume dressées, Fuji minuscule dans son creux** (le cadrage exact de l'estampe en fond). Torii vermillon dans l'eau (Itsukushima). Premier lever de soleil de l'an (*hatsu-hinode*) : disque vermillon pâle.
- **Clin d'œil** : à chaque nouvelle salle, la Vague du fond a un peu plus avancé ; au boss, elle surplombe l'arène.
- **Palette propre** : vert d'eau `#4F7F7A` (mer proche), sable mouillé `#B9A57E` (planches).
- **Décor / props low-poly** : planches (box 1×0.1×0.3, variation ±5°), pilotis (cyl), torii (2 cyl + 2 box), lanternes de port (cyl + cube papier émissif), filets de pêche (plan alpha), barques *oshiokuri* (coque 6 faces), cordages, tonneaux de saké, mouettes (billboard 2 frames).
- **Dangers d'arène** :
  - **Déferlante** : une bande transversale (largeur 2.5 m, toute la largeur) annoncée 1.3 s en bleu de Prusse hachuré écume → balaie : 1 dégât et pousse de 3 m. Toutes les 9–12 s dès la salle 4. *La ruée passe au travers ; finir le trait hors de la bande.*
  - **Planches pourries** : trous (r 0.8–1.2 m) dans le ponton. **On peut tracer au-dessus du vide, pas finir dedans** (arrivée dans un trou = chute, 1 dégât, réapparition au dernier point sûr). Les ennemis poussés dedans meurent (sauf brute). Le marqueur d'arrivée devient vermillon au-dessus d'un trou.
- **Ennemis** :
  | id | Nom | Modèle | PV | Comportement | Ce que ça impose au tracé |
  |---|---|---|---|---|---|
  | `oni` | **Hone** (os-soldat) | Skeleton_Minion | 1 | fonce (2.3 m/s), frappe une zone r1.0 annoncée 1.0 s | finir hors des disques ; base des combos |
  | `kappa` | **Kappa** | Skeleton_Mage | 1 | garde 4.5–7 m, boule lente 4.5 m/s toutes les 2.6–3.8 s ; annonce = lueur 0.7 s | tracer *entre* ses boules ; le rejoindre vite |
  | `brute` | **Gashi** (costaud) | Skeleton_Warrior ×1.4 | 3.5 | lent (1.4 m/s), zone r1.5 annoncée 1.2 s, non interruptible | l'enchaîner dans un combo (×2 au 3e) ou repasser 2 fois |
  | `tate` | **Tate** (bouclier) | Skeleton_Warrior + bouclier | 2 | avance bouclier levé (cône frontal 120° : les coups de face font 0 et rebondissent : la ruée s'arrête net) ; frappe r1.0 annonce 1.0 s | **le prendre par-derrière** : trait en U ou en crochet |
  | `funa` | **Funa-yūrei** (noyé) | Skeleton_Minion translucide bleu | 1 | émerge de l'eau au bord du ponton (2 s visible), lance une louche d'eau (zone r1.2 annoncée 1.1 s à l'endroit du héros), replonge 3 s (intouchable) | timing : le trancher pendant sa fenêtre visible ; tracer le long du bord |
- **Mini-boss — Ō-Kappa** (le chef kappa, 18 PV, r1.0, Skeleton_Mage ×2 + coupelle d'eau sur la tête)
  1. *Salve* : 5 boules en éventail 60° (4 m/s), puis pause 1.5 s.
  2. *Plongeon* : disparaît dans un trou du ponton, réapparaît sous le héros (zone r1.6 annoncée 1.2 s).
  3. *Coupelle* : **mécanique de trait** — sa coupelle (point or sur la tête) est visible de dos ; un trait qui le traverse **par-derrière** renverse l'eau : étourdi 3 s, dégâts ×3. De face : ×1.
  - Invoque 2 Hone à 50 % PV.
- **Boss — Uwabami** (le serpent de mer, 60 PV)
  - Corps : 12 segments (sphères r0.6 en chaîne, tête oni-dragon), il s'enroule autour du ponton, entre et sort de l'eau.
  - **Mécanique de trait : le trancher dans sa longueur.** Dégâts seulement si le trait longe ≥ 4 segments consécutifs (angle trait/corps < 30°). Couper en travers = 0 dégât, la ruée rebondit. Longer 4 seg = 4 dmg, 8 seg = 10 dmg, 12 seg (de la queue à la tête) = 20 dmg + étourdi 2 s.
  - Patterns (cycle 14 s) :
    1. *Ondulation* : traverse l'arène en S (annonce : sillage d'écume 1.2 s), corps posé 3 s → **fenêtre pour le longer**.
    2. *Crachat* : 3 jets de 6 boules en ligne droite (5 m/s), tête fixe.
    3. *Anneau* : s'enroule autour du héros (cercle r3.5 qui se resserre en 2.5 s) → sortir en traçant **par-dessus** le corps à l'endroit d'une ouverture (le seul segment immergé, bleu foncé).
    4. *Déferlante* (≤50 % PV) : 2 bandes de vague successives.
- **Musique / sons** : koto + shakuhachi, tempo 92 BPM, ressac en boucle, taiko léger pendant les vagues d'ennemis. Mouettes, bois qui craque sous l'arrivée, « ploc » des trous.

---

### Monde 2 — TANABATA (la Bambouseraie aux renards)
*Estampes : « Feux de renards la nuit à Ōji » ; cascade de Kirifuri en fond.*
- **Ambiance** : bambouseraie d'Arashiyama la nuit de **Tanabata**, bandes de papier *tanzaku* (5 couleurs pâles) accrochées aux tiges, brume basse, Voie lactée en bande sur le ciel, allées de torii serrés façon Fushimi Inari, feux de renards (*kitsune-bi*) comme dans l'estampe d'Ōji. Cascade de Kirifuri au loin.
- **Clin d'œil** : couper un bambou décoré fait tomber ses tanzaku en pluie de papier (pur feedback) ; la procession des **noces du renard** (*kitsune no yomeiri*) traverse le fond pendant le boss.
- **Palette propre** : vert bambou `#5E7F4A`, jade pâle `#A3B07A`. Nuit = washi assombri `#C9BFA8` au sol.
- **Décor / props** : tiges de bambou (cyl 0.12 × 4 m, nœuds tous les 0.6 m), touffes de 3–7 tiges, statues de renard (kitsune assis, 30 tris de style), petits torii rouges en rangée, lanternes de pierre *tōrō*, sentier de dalles, feuilles qui tombent (particules).
- **Dangers d'arène** :
  - **Bosquets** : touffes de bambous = murs. **Le trait ne peut pas les traverser** (le tracé s'arrête au contact, l'élan n'est pas dépensé). Mais un trait qui *frôle* une touffe (≤ 0.4 m) la **coupe** : les tiges tombent dans la direction du trait (ligne de 3 m, 1.5 dmg aux ennemis) et la touffe disparaît.
  - **Brume** : nappes (r 3 m) où les ennemis ne montrent que leurs yeux (2 points or). Les annonces restent visibles par-dessus la brume (règle de lisibilité).
- **Ennemis** :
  | id | Nom | PV | Comportement | Tracé imposé |
  |---|---|---|---|---|
  | `kitsunebi` | **Kitsune-bi** (feux follets, duo lié) | 1 + 1 | 2 flammes reliées par un fil or ; tournent l'une autour de l'autre (r 1.5 m), glissent vers le héros 1.2 m/s ; contact = 1 dmg. Si une seule meurt, l'autre la ranime en 2 s | **les deux dans le même trait** |
  | `tanuki` | **Tanuki** (explosif) | 1.5 | déguisé en statue/lanterne (immobile, prop identique à 95 %, queue qui dépasse) ; se réveille à ≤ 2.5 m, tape son ventre : onde r2.2 annoncée 1.0 s. Tranché : **roule** 4 m dans la direction du trait puis explose r2, 2 dmg aux ennemis | le lancer comme une boule de bowling dans le groupe |
  | `kamaitachi` | **Kamaitachi** (belettes faucheuses) | 0.5 ×3 | trio en file indienne ; marque une ligne au sol (annonce 0.9 s), fonce dessus à 12 m/s puis se pose 2 s | **tracer en travers** de leur ligne au moment où elles se posent (3 en un trait facile si perpendiculaire) |
  | `kodama` | **Kodama** (esprit d'arbre) | 1 | soigneur : immobile près d'un bosquet, rend 0.5 PV/s aux ennemis à ≤ 3 m (lien vert visible) ; se cache derrière les bambous | couper le bosquet pour l'atteindre ; priorité |
  | `tsuchinoko` | **Tsuchinoko** | 2 | serpent trapu qui saute en arc (zone d'atterrissage r1.2 annoncée 1.0 s), 3 sauts puis repos 2.5 s (ventre exposé) | dégâts ×2 pendant le repos |
- **Mini-boss — Tsuchigumo** (araignée géante, 30 PV, r1.2)
  - Tisse des **toiles** (lignes de 4–6 m entre bambous). Une toile **arrête le trait** (comme un bosquet) et colle le héros 1 s s'il finit dessus.
  - *Mécanique de trait* : chaque toile coupée **en son milieu** (±0.8 m) la fait claquer : 3 dmg à Tsuchigumo si elle y est reliée (fil visible). Couper les 3 toiles reliées = elle tombe au sol, étourdie 3 s.
  - Patterns : jet de toile vers le héros (ligne annoncée 0.9 s, colle 1.2 s) ; saut écrasant r1.8 (annonce 1.1 s) ; ponte de 3 petites araignées (0.5 PV, 2.8 m/s) toutes les 10 s.
- **Boss — Kyūbi** (le renard à neuf queues, 70 PV)
  - **Phase 1 — Illusions** : 3 renards identiques. Le vrai est le seul **dont l'ombre bouge**, et la Brume révèle ses yeux or. Frapper un faux = il éclate en 6 feux follets (lents, 3 m/s). Frapper le vrai = 4 dmg et les faux disparaissent 6 s.
  - **Phase 2 (≤ 60 %) — Les neuf queues** : 9 points de feu (queues) plantés au sol en cercle r4 ; chacun tire une flamme toutes les 4 s, décalées.
    - **Mécanique de trait : l'Ensō.** Tracer une **boucle fermée qui entoure Kyūbi** (forme Ensō, §4.6) éteint toutes les queues incluses dans la boucle et inflige 2 dmg par queue. 9 queues dans une boucle = étourdi 3 s + 18 dmg.
  - **Phase 3 (≤ 25 %)** : fuite rapide (6 m/s) en zigzag entre les bosquets ; ne tient que si on lui coupe la route (couper les bosquets où il veut passer).
- **Musique / sons** : shakuhachi solo, flûte *ryūteki*, clochettes de sanctuaire (*suzu*), tambour *kotsuzumi* sec à chaque frappe. Bambous qui craquent, bruissement de queues.

---

### Monde 3 — CENT CONTES (le Temple sous la neige)
*Estampes : série « Hyaku monogatari » (Oiwa dans la lanterne, Okiku et les assiettes) ; « Neige sur la Sumida ».*
- **Ambiance** : temple de montagne sous la neige pendant **Obon** : lanternes de papier flottant sur un étang gelé à moitié (*tōrō nagashi*), cimetière de stèles, escaliers, lanternes de pierre allumées une à une. Neige qui tombe en diagonale. Silence ouaté. Le jeu des **cent contes** (*hyakumonogatari kaidankai*) : 100 bougies, une s'éteint à chaque salle (compteur visuel au fond, aucun texte).
- **Clin d'œil Hokusai** : le Chōchin-obake reprend le **visage d'Oiwa dans la lanterne déchirée** ; ajouter en variante l'**Okiku** (fantôme du puits de Sarayashiki, cou de serpent fait d'assiettes) comme tireuse d'assiettes (voir tableau).
- **Palette propre** : bleu glace `#BFD6E3`, gris lavande `#8C8FA8` (ombres sur la neige).
- **Décor / props** : stèles (*haka*, box empilées), lanternes *tōrō* (5 pièces), cloche de temple suspendue, toits de pagode à 3 niveaux (fond), pins tordus (cônes + tronc courbe), bols d'offrande, statues *jizō* à bonnet rouge (attention : bonnet **sombre**, pas vermillon), congères (demi-sphères).
- **Dangers d'arène** :
  - **Glace** : plaques bleu glace. **Une arrivée sur la glace glisse** de 1.5 m dans la direction de la fin du trait (prévisualisé par le marqueur d'arrivée qui s'allonge en flèche). Les ennemis y glissent aussi (+knockback ×2).
  - **Cloche** : frapper la cloche (la traverser) → onde r6 qui **révèle** les fantômes 4 s et étourdit les ennemis 0.6 s. Recharge 15 s.
- **Ennemis** :
  | id | Nom | PV | Comportement | Tracé imposé |
  |---|---|---|---|---|
  | `onryo` | **Onryō** (fantôme) | 1.5 | **invisible** sauf : à ≤ 2 m du héros, sur de l'encre fraîche (traits < 2 s), ou révélé par la cloche. Attaque : apparition + griffe r1.0 annonce 0.9 s (l'annonce est toujours visible) | **tracer d'abord pour encrer le sol** (le trait révèle) ; puis le trancher |
  | `chochin` | **Chōchin-obake** (lanterne) | 1 | tireuse : éventail de 3 flammes (4.5 m/s) toutes les 3 s. Tranchée : **explose** r1.8, 1.5 dmg à tous (héros compris si à l'arrivée dans le rayon !) | la trancher en *milieu* de trait, pas en fin |
  | `kasa` | **Kasa-obake** (parapluie) | 1 | saute (1 bond / 1.4 s, 2.5 m), atterrissage = zone r0.9 annoncée 0.8 s ; en l'air il est intouchable | le trancher entre deux bonds (fenêtre 0.6 s au sol) |
  | `gaki` | **Gaki** (affamés) | 0.4 | essaim de 6–10, 2.6 m/s, contact = 1 dmg ; se jettent sur les flaques d'encre (trait < 2 s) et y restent 1.5 s | **appât** : tracer un leurre, puis repasser sur le groupe (combo ×5+) |
  | `okiku` | **Okiku** (fantôme du puits, Hokusai) | 2 | sort d'un puits (fixe), lance des **assiettes** qui tournent : 1, 2, 3… jusqu'à 9 en éventail (une de plus à chaque salve, 4 m/s), puis se recache 2 s et recommence à 1 | la tuer avant la salve 5 ; tracer entre les assiettes |
  | `oni` W3 | **Hone gelé** | 1.5 | variante Hone dont la zone laisse une plaque de glace 4 s | |
- **Mini-boss — Yuki-onna** (femme des neiges, 35 PV, flotte à 0.5 m)
  - *Souffle* : cône 70° sur 6 m annoncé 1.1 s, gèle 1.5 s (bloque le tracé).
  - *Miroirs de glace* : 3 piliers qui **réfléchissent le trait** : un trait qui touche un pilier repart en miroir (angle d'incidence). Elle ne prend de dégâts que d'un trait **réfléchi** au moins une fois (×2 si deux réflexions).
  - *Blizzard* (≤ 50 %) : la neige pousse tout à 1 m/s vers un bord.
- **Boss — Gashadokuro** (squelette géant, 90 PV ; modèle KayKit squelette ×5, buste seulement, sort du sol en fond d'arène)
  - **Mains** (2 × 15 PV) : *Écrasement* : une main tombe sur la position du héros (zone rectangulaire 2×3 m, annonce 1.2 s), reste au sol **2 s** → tranchable (dégâts aux mains). *Balayage* : une main balaie un tiers de l'arène (bande annoncée 1.0 s).
  - **Mécanique de trait** : quand les 2 mains sont détruites, le buste s'effondre vers l'avant : la **colonne vertébrale** forme un chemin de 9 vertèbres (points lumineux) jusqu'au crâne. Un trait qui passe sur ≥ 6 vertèbres dans l'ordre (queue → crâne) = 25 dmg. Sinon 1 dmg par vertèbre. Les mains repoussent après 8 s (à 60 % PV).
  - **Phase 2 (≤ 40 %)** : pluie de stèles (5 zones r1.0 annoncées 1.0 s, décalées de 0.3 s) + Gaki qui sortent des côtes.
- **Musique / sons** : shamisen grave, cloche de temple (*bonshō*) en basse, chœur bouddhique murmuré, neige qui crisse. Crâne qui claque des dents.

---

### Monde 4 — FUJI ROUGE (la Forge des oni)
*Estampes : « Fuji rouge » (Gaifū kaisei) ; « Orage sous le sommet ».*
- **Ambiance** : flancs puis intérieur du **Fuji rouge** de l'estampe (pente rouge-brun, nuages en écailles, ciel bleu de Prusse), qui mène à la forge géante des oni : forges de sabres (Seki), coulées de lave noire veinée d'or, chaînes, cendres qui montent. Pendant le boss, **éclairs sous le sommet** comme dans « Orage sous le sommet ».
- **Fête** : torches géantes du **Yoshida Hi-Matsuri** (fête du feu au pied du Fuji) plantées en bord d'arène = braseros/geysers allumés.
- **Palette propre** : rouge braise `#8E2A1E` (sombre, jamais vif), cendre `#5A5550`. La lave est **sumi + veines or** (pour ne pas concurrencer le vermillon des annonces).
- **Décor / props** : enclumes, soufflets, fûts de *tatara* (four), chaînes, piques de roche (cônes), ponts de pierre, statues de Fudō Myōō (fond), braseros, lingots, masques d'oni accrochés.
- **Dangers d'arène** :
  - **Geysers** : 3–5 bouches ; éruption r1.2 annoncée 1.0 s (cycle 6 s, décalé). Un ennemi tranché *vers* un geyser actif est projeté en l'air : il retombe 2 s plus tard (r1.5, 1.5 dmg aux ennemis).
  - **Coulée** : une bande de lave avance de 0.5 m/s d'un bord à l'autre puis se retire (cycle 20 s). Tracer au-dessus est permis, finir dedans = 1 dmg/0.5 s.
  - **Ponts** : certaines salles sont des îlots reliés ; tracer d'îlot en îlot (comme les trous du monde 1).
- **Ennemis** :
  | id | Nom | PV | Comportement | Tracé imposé |
  |---|---|---|---|---|
  | `aka_ao` | **Aka & Ao** (oni rouge et bleu, duo lié par chaîne) | 3 + 3 | Aka charge (ligne annoncée 1.0 s, 9 m/s) ; Ao frappe au massue r1.4 (1.2 s). Chaîne de 4 m entre eux : **la chaîne fait 1 dmg au contact**. Si un seul meurt, l'autre le relève en 3 s avec 50 % PV | les **deux dans le même trait** ; ou couper la chaîne (traverser la chaîne au milieu = 2 dmg aux deux + chaîne coupée) |
  | `wanyudo` | **Wanyūdō** (roue enflammée) | 2 | roue qui roule en ligne droite (7 m/s), rebondit sur les bords, laisse une traînée de feu 2 s ; invulnérable de face/derrière (jante) | la trancher **par le côté** (axe de la roue) |
  | `teppo` | **Teppō-oni** (arquebusier) | 1.5 | tir instantané en ligne : annonce **ligne fine 1.1 s** qui suit le héros 0.7 s puis se fige 0.4 s | après le figeage, tracer perpendiculaire hors de la ligne |
  | `hinotama` | **Hi-no-tama** (boule de feu, explosif) | 0.5 | dérive vers le héros 1.5 m/s ; tranchée : explose r2 (2 dmg aux ennemis, et au héros s'il finit dedans) ; meurt seule en 6 s en explosant | la trancher au milieu des autres, **sans finir dans le rayon** |
  | `brute` W4 | **Kanabō-oni** | 5 | Gashi en plus gros ; son coup laisse un cratère (trou 6 s) | |
- **Mini-boss — Ibaraki** (oni au bras tranché, 45 PV)
  - Son bras droit **vole séparément** (10 PV) et attaque seul : poing qui plonge (r1.3, annonce 1.0 s).
  - *Mécanique de trait* : tant que le bras vit, Ibaraki prend 50 % de dégâts. Un trait qui touche **bras puis corps** (dans cet ordre) = « recoller la blessure » : 12 dmg et le bras tombe 5 s.
  - Patterns : charge en ligne (1.0 s), cercle de flammes autour de lui r2.5 (1.2 s), rugissement qui repousse le héros de 3 m (0.8 s, sans dégâts).
- **Boss — Daidarabotchi** (le colosse de lave, 110 PV, 6 m de haut, occupe le fond de l'arène)
  - **Mécanique de trait : relier les points lumineux dans l'ordre.** Le colosse montre 3 à 7 **noyaux or numérotés par des traits sumi (1 à 7 encoches, pas de chiffres)** sur son corps et au sol devant lui. Un seul trait qui passe sur tous dans l'ordre = noyau brisé : 30 dmg + phase suivante. Hors ordre : 1 dmg par noyau et les noyaux se réarrangent.
  - Phase 1 (3 noyaux, en ligne presque droite) → Phase 2 (5 noyaux, en zigzag : **forme zigzag** utile) → Phase 3 (7 noyaux en spirale : **trait long ≥ 14 m**, nécessite des améliorations d'élan ou un combo pour recharger en route).
  - Patterns : *Poing* (zone 3×3 annoncée 1.3 s, laisse un trou), *Pluie de cendres* (8 zones r0.8), *Coulée* (bande de lave qui avance), *Souffle* (≤ 30 %, cône 45° 8 m, 1.0 s).
- **Musique / sons** : taiko massif (*ōdaiko*), 120 BPM, marteaux sur enclume calés sur le temps, chœur grave, sifflement de vapeur. Basse qui pulse avec les geysers.

---

### Monde 5 — TRENTE-SIX VUES (la Mer d'encre)
*Estampes : toute la série « Trente-six vues du mont Fuji » + croquis du « Hokusai Manga ».*
- **Ambiance** : les estampes envahies par la Vague Noire. **Chaque salle reprend une Vue** reconnaissable, à moitié noyée d'encre :
  | Salle | Vue de référence | Particularité d'arène |
  |---|---|---|
  | 1 | *Ejiri* (papiers emportés par le vent) | rafales : des feuilles de papier traversent l'arène et **masquent** brièvement ; vent latéral 0.8 m/s |
  | 2 | *Kajikazawa* (pêcheur sur un rocher) | rocher central + vagues de côté |
  | 3 | *Fujimigahara* (le tonnelier dans la barrique) | **barrique géante** au centre : anneau = mur circulaire, on trace autour ou à travers l'ouverture |
  | 4 | *Pont de Mannen à Fukagawa* | pont arqué : deux niveaux, tracer dessous ou dessus |
  | 5 | *Mishima* (bûcherons et grand cèdre) | arbre central à contourner (Ensō autour) |
  | 6–8 | *Shichiri-ga-hama*, *Ushibori*, *Tama* | variations de rivage |
  | 9 | retour à la **Grande Vague**, en noir | boss final |
  La mer est d'encre, le ciel est du papier brut, des bords déchirés flottent, des croquis du *Manga* (petits personnages en trait) courent en fond. Nouvel An (*Shōgatsu*) : *kadomatsu* en bambou aux portes.
- **Palette propre** : indigo nuit `#0E1A2E` (mer d'encre), rose aube `#E4B7B0` (ciel, rare).
- **Décor / props** : barques *oshiokuri* (sol de l'arène = 3–4 barques reliées), griffes d'écume (crêtes en forme de doigts, extrudées), morceaux de papier déchiré flottants (plans), sceaux de peintre géants (cylindres gravés), pinceaux plantés comme des mâts, tache d'encre animée (shader).
- **Dangers d'arène** :
  - **Zones effacées** : taches de papier blanc nu = vide (comme les trous, r 1–2 m), qui **apparaissent** (annonce : le papier pâlit 1.5 s) et disparaissent.
  - **La Vague** : toutes les 12 s, une vague géante balaie *toute* l'arène d'un bord (annonce : 2.0 s, ombre qui monte + grondement). Seuls abris : derrière les barques (zone d'ombre visible). 2 dmg. *Ou* : être en ruée au moment de l'impact (intouchable).
- **Ennemis** :
  | id | Nom | PV | Comportement | Tracé imposé |
  |---|---|---|---|---|
  | `kurokage` | **Kuro-kage** (ombre du héros) | 2 | copie **ton trait précédent** 1.5 s plus tard, depuis sa position (même forme, même longueur), fait 1 dmg au contact | ne pas finir là où tu as commencé ; varier les traits |
  | `ningyo` | **Ningyo** (sirène) | 1.5 | chante (ondes concentriques, 3 s) : **attire** le héros à 1.2 m/s vers elle ; plonge si on s'approche à < 2 m (1.0 s d'annonce : éclaboussure) | trait long qui part *de* l'attraction ; la frapper depuis loin |
  | `umizato` | **Umi-zatō** (moine aveugle de la mer) | 4 | marche à 1 m/s, **réagit au son** : chaque arrivée du héros à ≤ 5 m le fait frapper au point d'arrivée (zone r1.5 annoncée 0.8 s) | finir loin de lui ; le frapper en passant |
  | `sumidama` | **Sumi-dama** (goutte d'encre) | 1 | se divise en 2 (0.5 PV) puis 4 (0.25 PV) quand tranchée ; les petites foncent 3.5 m/s | combos : les retrancher dans le même trait (retour) |
  | `tate` W5 | **Tate d'encre** | 3 | Tate dont le bouclier renvoie le trait (rebond de la ruée à 90°) | |
- **Mini-boss — Bakekujira** (baleine squelette, 60 PV)
  - Nage *sous* l'arène ; seule sa colonne d'écume la signale. Surgit (zone 4×2 annoncée 1.3 s) et reste en surface 3 s.
  - *Mécanique de trait* : en surface, son corps est un long couloir : **forme Retour** (aller-retour sur son dos) = 2 passages comptés en un trait, ×2 au retour. Ses fanons projettent des sumi-dama.
- **Boss final — Kuro-Nami** (la Vague Noire, 3 phases, 150 PV au total)
  - **Phase 1 — Les griffes** (50 PV) : la vague géante au fond tend 5 « doigts » d'écume (5 × 10 PV) qui griffent l'arène (bandes annoncées 1.0 s). Chaque doigt tranché **dans sa longueur** (comme Uwabami) = 10 dmg.
  - **Phase 2 — Le Fuji** (50 PV) : la vague menace le Fuji au centre de l'arène (petit mont, 10 PV de « vie du Fuji » qui baisse de 1 / vague qui le touche). Ses vagues arrivent par 3 couloirs (annonces 1.2 s). **Mécanique : le trait retour** devant une vague la renvoie (« Kaeshi ») et lui inflige 8 dmg. Fuji détruit = défaite.
  - **Phase 3 — L'Ensō** (50 PV) : la vague s'enroule en spirale autour de l'arène qui rétrécit (r 8 → 3 en 40 s). Au centre, un œil sumi. **Seul dégât possible : tracer un Ensō (boucle presque fermée, écart 0.5–1.5 m, rayon ≥ 2.5 m) autour de l'œil**. Un ensō parfait (écart dans la plage, rondeur > 0.85) = 25 dmg. Deux ensō = victoire → Vue finale.
- **Musique / sons** : toutes les mélodies des mondes 1–4 reprises au koto, puis effacées une à une ; phase 3 : silence + respiration + un seul coup de taiko à chaque ensō. Vagues d'encre (son « liquide visqueux »), papier qui se déchire.

---

## 3. Héros jouables

Stats de base relatives au ronin (prototype). Chaque héros a : un **passif**, une **forme spéciale signature** (débloquée dès le départ pour lui), une arme et une silhouette distinctes.

| Héros | Modèle proto | PV | Élan max | Regen | Ruée | Dégâts | Portée coupe | Prix |
|---|---|---|---|---|---|---|---|---|
| **Jin** (ronin) | Rogue_Hooded, cape vermillon, katana | 5 | 14 m | 9 m/s | 34 m/s | 1.0 | 0.55 m | départ |
| **Tsubame** (kunoichi) | Rogue (sans capuche), foulard sumi, 2 kunai | 3 | 10 m | 13 m/s | 44 m/s | 0.8 | 0.45 m | 400 sumi |
| **Benkei** (moine-guerrier) | Barbarian, robe sumi, capuche blanche, naginata | 8 | 12 m | 7 m/s | 26 m/s | 1.6 | 0.85 m | 600 sumi + 1 sceau |
| **Kohaku** (kitsune, mi-renarde) | Mage (KayKit) + oreilles/queue, éventail or | 4 | 16 m | 9 m/s | 34 m/s | 0.9 | 0.55 m | 900 sumi + 3 sceaux |

### Jin — le ronin
- **Passif « Iai »** : le **premier** ennemi de chaque trait subit ×2 dégâts (s'ajoute au multiplicateur combo).
- **Forme signature : Boucle → Tourbillon** (Uzu) : r1.6, 1.0 dmg par tour, 2 tours.
- Style : polyvalent, apprentissage.

### Tsubame — la kunoichi
- **Passif « Hirondelle »** : peut **tracer pendant sa ruée** : le nouveau trait part du point d'arrivée prévu et s'enchaîne sans arrêt (file de 1 trait). Les traits < 4 m qui touchent au moins 1 ennemi ne coûtent pas d'élan.
- **Forme signature : Zigzag → Kunai en chaîne** : 3 kunai rebondissent entre ennemis (≤ 4 m), 0.7 dmg chacun.
- Style : rapide, fragile, beaucoup de petits traits.

### Benkei — le moine
- **Passif « Montagne »** : **pendant le tracé** (héros immobile), les projectiles venant de face (cône 140°) sont bloqués par sa naginata. Son arrivée crée une onde r1.5, 0.5 dmg, repousse 1.5 m. Il n'a **pas** de bond d'esquive (le petit coup de doigt fait une frappe sur place r1.4, 1.0 dmg).
- **Forme signature : Retour → Renvoi** (Kaeshi) renforcé : renvoie tous les projectiles à ≤ 2 m du trait, ×2 dégâts.
- Style : lent, tank, compense l'absence de ralenti par la garde.

### Kohaku — la kitsune
- **Passif « Œil du renard » (le ralenti, ici comme identité)** : poser le doigt ralentit le temps à **40 % pendant 0.5 s réelle** ; recharge 5 s (icône : petite flamme or près de la jauge d'élan).
- **Second passif « Feu follet »** : au départ de chaque ruée, un **leurre** renard reste au point de départ 2 s ; les ennemis le ciblent (aggro) et les tireurs visent le leurre.
- **Forme signature : Ensō → Sceau** : une boucle fermée pose un sceau de feu-renard (r = rayon de la boucle) qui immobilise 2 s et fait 0.5 dmg/s.
- Style : contrôle, lecture du terrain, pour joueurs avancés.

**Bonus de progression héros** : chaque héros a 3 niveaux de **maîtrise** (gagnés en battant un boss avec lui) : M1 +1 PV, M2 une 2e forme signature au choix, M3 skin estampe (contour or).

---

## 4. Pouvoirs

### 4.1 Règles générales
- Après chaque salle de combat : **1 amélioration parmi 3** (« Rouleaux »). Les 3 proviennent de 1–3 écoles ; la salle annonce l'école sur la porte (§6).
- Raretés : **Commun** (60 %), **Rare** (30 %), **Légendaire** (10 %, nécessite 2 améliorations de l'école). Les niveaux I → II → III : reprendre la même amélioration la monte (offerte en priorité 25 %).
- **Duos** : apparaissent si on a ≥ 2 améliorations dans chacune des 2 écoles.
- Une partie typique : 7–8 améliorations. Viser un build lisible : 1 école principale + 1 secondaire.
- Statuts : **Brûlure** (Feu, DoT), **Trempé** (Eau, ralenti), **Choc** (Foudre, étourdi), **Marque** (Ombre, ×dégâts).

### 4.2 École du FEU — *Hi* (vermillon / or) — dégâts sur la durée, zones
| id | Nom | Rareté | Effet (I / II / III) | Synergies |
|---|---|---|---|---|
| `fire_trail` | **Sillage** | C | le trait laisse une bande de feu 2.5 / 3.5 / 4.5 s, 0.4 / 0.6 / 0.8 dmg/s | Vent `wind_long`, Ombre `shadow_clone` (le clone allume aussi) |
| `fire_burn` | **Braise** | C | ennemis tranchés : Brûlure 3 s, 0.3 / 0.45 / 0.6 dmg/s, cumul ×3 | `fire_spark` |
| `fire_spark` | **Hibana** | R | ennemi tué en brûlant : explose r1.6, 0.8 / 1.2 / 1.6 dmg (propage la Brûlure) | Tanuki, Hi-no-tama |
| `fire_edge` | **Lame rouge** | C | +30 / 45 / 60 % dégâts contre ennemis brûlants | |
| `fire_hearth` | **Foyer** | R | à l'arrivée : cercle de feu r1.8, 1.0 / 1.5 / 2.0 dmg une fois (protège l'arrivée) | Benkei |
| `fire_ink` | **Encre ardente** | R | tous les 10 ennemis brûlés : +1 élan max (plafond +6 / +8 / +10) | |
| `fire_phoenix` | **Hōō** | L | 1×/partie : à 0 PV, renaît 2 PV + explosion r3, 3 dmg + intouchable 2 s | |

### 4.3 École de l'EAU — *Mizu* (bleu de Prusse / écume) — contrôle, survie, renvoi
| id | Nom | Rareté | Effet | Synergies |
|---|---|---|---|---|
| `water_push` | **Ressac** | C | ennemis tranchés repoussés 2.5 / 3.2 / 4 m perpendiculairement au trait (vers les trous = mort) | trous, geysers, lave |
| `water_dew` | **Rosée** | C | soigne 1 PV tous les 12 / 10 / 8 ennemis tués | |
| `water_mirror` | **Miroir** | R | les projectiles que le trait traverse sont **renvoyés** (50 / 75 / 100 %), 1.5 dmg | Kappa, Chōchin, Teppō |
| `water_tide` | **Marée** | C | à l'arrivée : vague en cône 90° sur 3 m, 0.7 / 1.0 / 1.3 dmg, repousse 2 m | |
| `water_bubble` | **Bulle** | R | bouclier qui absorbe 1 coup ; se recharge après 10 / 8 / 6 ennemis tués | |
| `water_soak` | **Courant** | C | ennemis tranchés Trempés : −40 % vitesse et cadence d'attaque, 2.5 / 3.5 / 4.5 s | Foudre (duo) |
| `water_tsunami` | **Tsunami** | L | combo ≥ 5 : une vague traverse l'arène dans la direction du trait (largeur 3 m), 2 dmg, repousse 4 m | |

### 4.4 École de la FOUDRE — *Rai* (or / écume) — chaînes, interruptions
| id | Nom | Rareté | Effet | Synergies |
|---|---|---|---|---|
| `bolt_arc` | **Arc** | C | chaque ennemi tranché lance un arc vers 1 / 2 / 3 ennemis à ≤ 3 m, 0.5 dmg | Kitsune-bi (duo lié), Sumi-dama |
| `bolt_thunder` | **Tonnerre** | C | combo ≥ 3 : Choc (étourdi) 1.0 / 1.4 / 1.8 s sur tous les ennemis tranchés | |
| `bolt_chain` | **Inazuma** | R | **forme zigzag** : éclair en chaîne 4 / 6 / 8 cibles, 1.0 dmg chacune | Tsubame |
| `bolt_charge` | **Charge** | C | chaque mètre tracé charge 0.08 / 0.11 / 0.14 dmg, déchargés à l'arrivée en r2 (14 m ≈ 1.1 / 1.5 / 2.0) | Vent `wind_long` |
| `bolt_raiju` | **Raijū** | R | un loup-tonnerre frappe l'ennemi le plus proche de ton arrivée toutes les 6 / 5 / 4 s, 1.5 dmg | |
| `bolt_quick` | **Vif** | C | +20 / 30 / 40 % vitesse de ruée ; ennemis touchés après 6 m de ruée : ×1.2 dégâts | |
| `bolt_raijin` | **Raijin** | L | tous les 4 traits : un éclair frappe **chaque ennemi en annonce** (1.5 dmg, annule l'attaque) | sans ralenti, c'est l'anti-danger ultime |

### 4.5 École du VENT — *Kaze* (écume / washi) — élan, mobilité, **ralenti**
| id | Nom | Rareté | Effet | Synergies |
|---|---|---|---|---|
| `wind_long` | **Souffle long** | C | +3 / +5 / +7 m d'élan max | Charge, Sillage |
| `wind_gust` | **Bourrasque** | C | +30 / 45 / 60 % de recharge d'élan ; +0.5 / 1.0 / 1.5 m d'élan par ennemi tranché | |
| `wind_stillness` | **Souffle suspendu** | R | **le ralenti** : poser le doigt ralentit le temps à 35 % pendant 0.6 / 0.8 / 1.0 s réelle ; recharge 6 / 5 / 4 s. Icône prête = plume blanche sur la jauge | toutes les écoles |
| `wind_feather` | **Plume** | C | bond d'esquive : coût 0, distance 3.2 m ; II : laisse une lame de vent 0.5 dmg ; III : +1 bond gratuit enchaînable | |
| `wind_rebound` | **Rebond** | R | tuer un ennemi dans les **1.5 derniers mètres** du trait prolonge la ruée de 2.5 / 3.5 / 4.5 m dans la même direction (gratuit, enchaînable) | combos longs, boss Daidarabotchi |
| `wind_blades` | **Kamaitachi** | C | 2 lames latérales suivent le trait à 1.0 m de part et d'autre, 0.4 / 0.6 / 0.8 dmg (élargit la coupe) | |
| `wind_fujin` | **Fūjin** | L | les traits ≥ 9 m **aspirent** les ennemis à ≤ 4 m de la ligne de 1.5 m vers elle (0.25 s avant la ruée) | combos géants |

### 4.6 École de l'OMBRE — *Kage* (sumi / or) — critiques, arrivée sûre, clones
| id | Nom | Rareté | Effet | Synergies |
|---|---|---|---|---|
| `shadow_back` | **Ushiro** | C | ×2 / ×2.5 / ×3 dégâts sur un ennemi touché dans le dos (cône 120°) | Tate, Ō-Kappa |
| `shadow_veil` | **Voile** | C | si la ruée tue ≥ 2 ennemis : intouchable 0.6 / 0.9 / 1.2 s à l'arrivée | **corrige le moment dangereux** |
| `shadow_clone` | **Bunshin** | R | un clone d'ombre retrace ton trait précédent 0.6 s après, à 40 / 60 / 80 % des dégâts | Sillage, Arc |
| `shadow_execute` | **Kaishaku** | R | ennemis sous 20 / 25 / 30 % PV meurent au contact (pas les boss : +50 % dégâts à la place) | |
| `shadow_stolen` | **Instant volé** | R | combo ≥ 4 : le temps ralentit à 30 % pendant 0.8 / 1.0 / 1.2 s réelle (lecture + traçage du trait suivant) | Tsubame |
| `shadow_pool` | **Flaque noire** | C | ennemi tué : flaque d'ombre 4 s ; finir un trait dessus = intouchable 0.5 s et +3 / 4 / 5 m d'élan | |
| `shadow_nue` | **Nue** | L | 1×/salle : le premier coup reçu est annulé, le héros est téléporté au **départ** de son dernier trait | |

### 4.7 Duos (2 écoles, 1 seul par partie en principe)
| id | Écoles | Nom | Effet |
|---|---|---|---|
| `duo_steam` | Feu + Eau | **Vapeur** | Ressac/Marée sur un ennemi brûlant → nuage r2 : ennemis dedans ne tirent plus pendant 2.5 s |
| `duo_plasma` | Feu + Foudre | **Plasma** | les arcs appliquent la Brûlure ; Brûlure +50 % sur ennemis choqués |
| `duo_storm` | Eau + Foudre | **Orage** | ennemis Trempés : arcs ×2 dégâts et +1 rebond |
| `duo_firewhirl` | Feu + Vent | **Tornade de feu** | la Boucle crée un tourbillon de feu 3 s qui se déplace vers l'ennemi le plus proche (1.2 dmg/s) |
| `duo_typhoon` | Eau + Vent | **Typhon** | Fūjin/aspiration et Ressac en même trait : les ennemis s'entrechoquent, 1 dmg chacun |
| `duo_blackbolt` | Ombre + Foudre | **Éclair noir** | une exécution (Kaishaku) déclenche un arc vers 3 ennemis à 1.5 dmg |
| `duo_moon` | Ombre + Vent | **Lune noire** | Souffle suspendu et Instant volé durent +0.4 s ; pendant le ralenti, dégâts +25 % |
| `duo_inkfire` | Ombre + Feu | **Encre brûlée** | les flaques noires brûlent (0.5 dmg/s) et le clone laisse un Sillage |

### 4.8 Formes spéciales (reconnaissance du geste)
Débloquées au refuge (sauf la forme signature du héros). Une forme détectée = **effet en plus** de la ruée normale. Détection sur la polyligne du trait (points tous les ~0.15 m) au relâchement.

| id | Forme | Détection (proposition) | Effet de base | Coût refuge |
|---|---|---|---|---|
| `form_loop` | **Uzu** (boucle) | angle cumulé ≥ 300° sur un sous-segment ET auto-intersection ; rayon 0.6–2.5 m | tourbillon au centre de la boucle r1.6, 2 × 1.0 dmg | départ (Jin) / 150 |
| `form_zigzag` | **Inazuma** (zigzag) | ≥ 3 changements de direction > 100°, segments 0.8–3 m | éclair en chaîne 4 cibles × 1.0 | 200 |
| `form_return` | **Kaeshi** (retour) | fin à ≤ 1.2 m du départ, distance max au départ ≥ 3 m, aller ≈ retour (écart moyen < 0.8 m) | renvoie les projectiles à ≤ 1.5 m du trait ; 2e passage sur un ennemi ×1.5 | 200 |
| `form_straight` | **Ittō** (trait droit) | longueur ≥ 7 m, écart max à la droite < 0.4 m | perce les boucliers (Tate), ×1.5 dégâts, ruée +30 % | 250 |
| `form_enso` | **Ensō** (cercle ouvert) | courbe fermée à 0.5–1.5 m près, rayon ≥ 2 m, rondeur (écart-type du rayon / rayon moyen) < 0.2 | tous les ennemis **à l'intérieur** : immobilisés 1.5 s + 1.5 dmg | 350 + 1 sceau (obligatoire pour le boss final : débloqué gratuitement à la 1re visite du monde 5) |
| `form_hook` | **Kagi** (crochet) | dernier segment ≥ 1.5 m formant un angle 120–170° avec le précédent | l'ennemi touché par le crochet est frappé dans le dos (déclenche Ushiro) | 150 |

Améliorations de forme (dans le pool une fois la forme débloquée, rareté R) : `form_loop_plus` (Uzu r +0.6, +1 tour), `form_zigzag_plus` (+2 cibles, choc 0.5 s), `form_return_plus` (projectiles renvoyés ×2 dégâts), `form_enso_plus` (immobilisation +1 s, +1 dmg).

Feedback : forme reconnue = idéogramme pinceau qui flotte 0.6 s (渦 雷 返 一 円 鉤), son de pinceau spécifique. **Aucun texte.**

### 4.9 Malédictions — *Noroi* (toutes les 3 salles, au sanctuaire, optionnel)
Le sanctuaire propose **2 malédictions au choix ou refus**. Une malédiction dure **jusqu'à la fin de la partie** (sauf mention). Récompense immédiate. Une malédiction acceptée = +1 **sceau** si on bat le boss.

| id | Nom | Malus | Récompense |
|---|---|---|---|
| `curse_dry` | **Encre sèche** | élan max −30 % | 1 amélioration **rare garantie** + 40 mon |
| `curse_dull` | **Lame émoussée** | multiplicateur combo divisé par 2 (+0.25 par ennemi au lieu de +0.5) | 2 améliorations (choix 1/3 deux fois) |
| `curse_oni_eye` | **Œil d'oni** | ennemis +50 % PV | sumi ×2 pour la partie |
| `curse_arrows` | **Pluie de flèches** | tous les tireurs : +1 projectile par salve | 1 **légendaire** au choix parmi 2 |
| `curse_heavy` | **Pas lourd** | filet de sécurité désactivé ; arrivée : 0.2 s d'immobilité | +2 PV max et soin complet |
| `curse_moonless` | **Nuit sans lune** | annonces 25 % plus courtes (plancher 0.65 s) | 1 duo garanti si éligible, sinon 1 légendaire |
| `curse_haste` | **Hâte des morts** | ennemis +25 % vitesse de déplacement | 80 mon + soin complet |
| `curse_tremor` | **Main tremblante** | le trait ondule (bruit latéral ±0.3 m, période 1.2 m) : moins précis | sumi +50 %, et Ittō compte quand même si l'intention est droite |
| `curse_seal` | **Sceau rouge** | chaque salle de combat doit être finie en < 45 s, sinon −1 PV | 2 améliorations |
| `curse_haunted` | **Hanté** | un Onryō invincible suit le héros à 0.8 m/s toute la partie (contact 1 dmg) | +1 sceau immédiat (sans attendre le boss) |
| `curse_noslow` | **Temps pressé** | toutes les sources de ralenti désactivées (Souffle suspendu, Instant volé, Œil du renard) | +1 amélioration et toutes les améliorations Vent/Ombre restantes passent un niveau |

---

## 5. Méta-progression : l'Atelier

### 5.1 Monnaies
| Monnaie | Icône | Portée | Gain | Usage |
|---|---|---|---|---|
| **Mon** (pièce trouée) | cuivre/or | **une partie** (perdue à la mort) | 2–4 / salle de combat, 8 / élite, 15–25 / boss, coffres | boutique du tanuki, événements |
| **Sumi** (bâton d'encre) | sumi + liseré or | **permanente** | 1 / 5 ennemis, +10 / mini-boss, +30 / boss, +15 % par malédiction active. Moyenne : 40 (mort tôt) à 140 (boss battu) | Pierre à encre, formes, héros |
| **Sceau** (hanko) | vermillon carré | permanente, rare | 1 / boss battu (1re fois par monde : +2), +1 / malédiction tenue jusqu'au boss | héros, Marées, Ensō, légendaires dans le pool |
| **Vue** (estampe) | rectangle washi | collection | 1 / mort (jusqu'à 24), 1 dorée / premier kill de chaque boss et mini-boss (10), 2 secrètes | histoire (paravent) |

### 5.2 Stations de l'Atelier (chaque station = un prop cliquable)
1. **Pierre à encre** (*suzuri*) — améliorations permanentes. 6 lignes × 5 rangs.
   | Ligne | Effet par rang | Coûts (sumi) |
   |---|---|---|
   | Pinceau long | +1 m élan max | 40 / 80 / 140 / 220 / 320 |
   | Encre vive | +6 % recharge élan | 40 / 80 / 140 / 220 / 320 |
   | Peau de papier | +1 PV max (3 rangs) | 100 / 200 / 350 |
   | Second souffle | +1 filet de sécurité par salle (2 rangs) | 250 / 500 |
   | Bourse | +10 mon au départ | 30 / 60 / 100 / 150 / 210 |
   | Choix | +1 relance de rouleaux par partie | 120 / 240 / 400 |
2. **Râtelier** — héros (voir §3 pour les prix).
3. **Rouleaux pendus** — formes spéciales (§4.8) ; chaque forme débloquée ajoute aussi son « + » au pool.
4. **Autel des écoles** — au départ seules Feu et Vent sont dans le pool. Débloquer : Eau 120, Foudre 200, Ombre 300 sumi. Ajouter les légendaires d'une école au pool : 1 sceau chacune.
5. **Paravent** — les 36 Vues (consultation).
6. **Lanterne des Marées** — difficulté (§5.4), débloquée après le boss du monde 5… ou dès le premier boss pour le monde en cours.
7. **Tanuki marchand** (dans la cour) — cosmétiques (couleur d'encre du trait : sumi, or, indigo, vermillon — 150 sumi chacun), coût symbolique, aucun avantage.
8. **Chat** — on peut le caresser. C'est tout.

### 5.3 Courbe visée
- Partie 1–3 : mort salle 3–6 → 1 Vue + 40–70 sumi → 1 rang Pierre à encre / partie.
- Boss monde 1 vers la partie 5–8. Tous les mondes : ~35–50 parties (≈ 5 h).

### 5.4 Marées (difficulté, type « Heat »)
Lanterne : 10 niveaux, chacun activable séparément (1 sceau pour déverrouiller chaque niveau) : ennemis +20 % PV ; +1 jeton d'attaque ; annonces −10 % ; boss phase supplémentaire ; une malédiction imposée ; pas de Source chaude ; etc. Récompense : +10 % sumi par niveau, Vue dorée à Marée 5 et 10.

---

## 6. Structure d'une partie

### 6.1 Déroulé (v1 : 9 salles, 6–8 min — remplacé par les 8 étapes, voir « État actuel »)
```
[1 Combat] → [2 Combat|Élite] → [3 Combat] → [Sanctuaire : malédiction ?]
→ [4 Choix : Boutique | Source | Événement] → [5 MINI-BOSS]
→ [6 Combat|Élite] → [7 Combat] → [Sanctuaire : malédiction ?]
→ [8 Choix : Boutique | Source | Événement] → [9 BOSS]
```
- Le sanctuaire n'est pas une salle : un petit autel apparaît à la sortie des salles 3 et 7 (on peut l'ignorer).
- Durées visées : combat 30–45 s, élite 50 s, mini-boss 60–90 s, boss 2–3 min.

### 6.2 Choix de chemin
À la fin d'une salle, **2 portes** (torii) au bord nord de l'arène ; on y entre en **traçant** jusqu'à elles. Au-dessus de chaque torii, une icône de récompense :
| Icône | Récompense |
|---|---|
| idéogramme d'école (火 水 雷 風 影) | rouleaux 1/3 orientés sur cette école |
| ×2 rouleaux | élite : 2 rouleaux, dont 1 rare garanti |
| pièce | 20–30 mon |
| bâton d'encre | 15 sumi |
| cœur pinceau | soin 2 PV |
| ? | événement |

### 6.3 Composition des combats (budget)
- Budget de points par salle : `budget = 6 + 2 × index_salle` (monde 1) ; ×1.2 par monde au-delà (monde 5 ≈ ×2.1).
- Coûts (voir JSON §7.2) : Hone 1, Kappa 2, Gashi 3, Tate 3, Funa 2…
- 2 vagues par salle (60 % / 40 % du budget), la 2e arrive quand il reste ≤ 2 ennemis. 3 vagues en élite.
- Max 2 types nouveaux par salle ; un ennemi nouveau du monde apparaît d'abord **seul ou avec des Hone** (apprentissage sans texte).

### 6.4 Boutique — Tanuki marchand
- 4 articles : 2 améliorations (prix 60 C / 100 R / 160 L mon), 1 soin (2 PV, 40 mon), 1 relique.
- **Reliques** (objets passifs, 1 par boutique, 80–120 mon) : *Gourde de saké* (+1 PV max), *Netsuke chat* (+15 % mon), *Pierre à aiguiser* (+0.1 portée de coupe), *Clochette* (fantômes visibles à 3.5 m au lieu de 2), *Éventail* (premier trait de chaque salle gratuit), *Omamori* (1 fois : survit à un coup mortel avec 1 PV).
- Relance : 15 mon, +10 à chaque relance.

### 6.5 Source chaude (*onsen*)
Choix : soigner 3 PV **ou** +1 PV max **ou** monter une amélioration d'un niveau.

**Nourriture** (soins, selon le monde, §2.0) : une salle de combat finie sans dégât laisse tomber le plat du monde (onigiri, inari-zushi, soupe miso, onsen tamago, mochi) : +1 PV. La boutique vend le plat « de fête » du monde (takoyaki, dango, amazake, yakitori, soba) : +2 PV pour 35 mon.

### 6.6 Événements (salle « ? », 1 écran, 2 boutons-icônes, zéro ou une ligne de texte)
| id | Nom | Choix |
|---|---|---|
| `ev_jizo` | **Jizō** | donner 30 mon → soin complet / passer |
| `ev_fox_wedding` | **Noces du renard** (pluie sous le soleil) | suivre la procession : combat surprise d'élite (récompense légendaire) / passer |
| `ev_painter` | **L'élève du peintre** | échanger une amélioration contre une autre de même école, rareté +1 |
| `ev_kappa_sumo` | **Sumo du kappa** | mini-défi : pousser un kappa dans l'eau en < 10 s (Ressac aide) → 50 mon / rien |
| `ev_lantern` | **Cent lanternes** (*hyakumonogatari*) | éteindre les lanternes en un seul trait (toutes = 1 Vue secrète ou 1 sceau la première fois) |
| `ev_cursed_blade` | **Lame maudite** | prendre une malédiction aléatoire + 1 légendaire |
| `ev_tea` | **Cérémonie du thé** | attendre 5 s sans toucher l'écran → +1 relance et +2 élan max |

### 6.7 Défaite et retour
Mort : le héros se dissout en encre qui coule sur le papier (1.5 s), fondu vers l'Atelier ; le peintre accroche l'estampe suivante (animation 3 s, passable par un tap) ; écran de gains (sumi, Vue, sceau) en icônes et chiffres.

---

## 7. Tables de données proposées

À placer dans `res://data/` (JSON chargé au démarrage). Clés en anglais pour le code, noms affichés en français/japonais.

### 7.1 `upgrades.json`
Champs : `id`, `school` (fire|water|bolt|wind|shadow|duo|form), `name`, `rarity` (C|R|L), `max_level`, `params` (tableaux indexés par niveau), `trigger` (hook moteur), `requires`.
Hooks proposés (signaux à émettre depuis `main.gd`) : `on_stroke_start`, `on_stroke_release(path)`, `on_enemy_hit(enemy, dmg, index_in_stroke)`, `on_enemy_kill(enemy)`, `on_dash_end(pos, kills)`, `on_hurt`, `on_room_start`, `on_touch_down`, `passive` (modif de stats).

```json
[
  {"id":"fire_trail","school":"fire","name":"Sillage","rarity":"C","max_level":3,"trigger":"on_stroke_release","params":{"duration":[2.5,3.5,4.5],"dps":[0.4,0.6,0.8],"width":0.9}},
  {"id":"fire_burn","school":"fire","name":"Braise","rarity":"C","max_level":3,"trigger":"on_enemy_hit","params":{"duration":3.0,"dps":[0.3,0.45,0.6],"max_stacks":3}},
  {"id":"fire_spark","school":"fire","name":"Hibana","rarity":"R","max_level":3,"trigger":"on_enemy_kill","requires":{"status":"burn"},"params":{"radius":1.6,"dmg":[0.8,1.2,1.6]}},
  {"id":"fire_edge","school":"fire","name":"Lame rouge","rarity":"C","max_level":3,"trigger":"on_enemy_hit","params":{"bonus_vs_burn":[0.3,0.45,0.6]}},
  {"id":"fire_hearth","school":"fire","name":"Foyer","rarity":"R","max_level":3,"trigger":"on_dash_end","params":{"radius":1.8,"dmg":[1.0,1.5,2.0]}},
  {"id":"fire_ink","school":"fire","name":"Encre ardente","rarity":"R","max_level":3,"trigger":"on_enemy_kill","params":{"burned_kills_per_elan":10,"elan_cap":[6,8,10]}},
  {"id":"fire_phoenix","school":"fire","name":"Hōō","rarity":"L","max_level":1,"trigger":"on_hurt","requires":{"school_count":2},"params":{"revive_hp":2,"radius":3.0,"dmg":3.0,"invuln":2.0,"uses":1}},

  {"id":"water_push","school":"water","name":"Ressac","rarity":"C","max_level":3,"trigger":"on_enemy_hit","params":{"knock":[2.5,3.2,4.0]}},
  {"id":"water_dew","school":"water","name":"Rosée","rarity":"C","max_level":3,"trigger":"on_enemy_kill","params":{"kills_per_heal":[12,10,8]}},
  {"id":"water_mirror","school":"water","name":"Miroir","rarity":"R","max_level":3,"trigger":"on_stroke_release","params":{"reflect_chance":[0.5,0.75,1.0],"dmg":1.5,"radius":0.6}},
  {"id":"water_tide","school":"water","name":"Marée","rarity":"C","max_level":3,"trigger":"on_dash_end","params":{"cone_deg":90,"range":3.0,"dmg":[0.7,1.0,1.3],"knock":2.0}},
  {"id":"water_bubble","school":"water","name":"Bulle","rarity":"R","max_level":3,"trigger":"on_hurt","params":{"recharge_kills":[10,8,6]}},
  {"id":"water_soak","school":"water","name":"Courant","rarity":"C","max_level":3,"trigger":"on_enemy_hit","params":{"slow":0.4,"duration":[2.5,3.5,4.5]}},
  {"id":"water_tsunami","school":"water","name":"Tsunami","rarity":"L","max_level":1,"trigger":"on_dash_end","requires":{"school_count":2},"params":{"min_combo":5,"width":3.0,"dmg":2.0,"knock":4.0}},

  {"id":"bolt_arc","school":"bolt","name":"Arc","rarity":"C","max_level":3,"trigger":"on_enemy_hit","params":{"targets":[1,2,3],"range":3.0,"dmg":0.5}},
  {"id":"bolt_thunder","school":"bolt","name":"Tonnerre","rarity":"C","max_level":3,"trigger":"on_dash_end","params":{"min_combo":3,"stun":[1.0,1.4,1.8]}},
  {"id":"bolt_chain","school":"bolt","name":"Inazuma","rarity":"R","max_level":3,"trigger":"form_zigzag","params":{"targets":[4,6,8],"dmg":1.0}},
  {"id":"bolt_charge","school":"bolt","name":"Charge","rarity":"C","max_level":3,"trigger":"on_dash_end","params":{"dmg_per_m":[0.08,0.11,0.14],"radius":2.0}},
  {"id":"bolt_raiju","school":"bolt","name":"Raijū","rarity":"R","max_level":3,"trigger":"on_dash_end","params":{"cooldown":[6,5,4],"dmg":1.5}},
  {"id":"bolt_quick","school":"bolt","name":"Vif","rarity":"C","max_level":3,"trigger":"passive","params":{"dash_speed_mult":[1.2,1.3,1.4],"late_hit_mult":1.2,"late_after_m":6.0}},
  {"id":"bolt_raijin","school":"bolt","name":"Raijin","rarity":"L","max_level":1,"trigger":"on_stroke_release","requires":{"school_count":2},"params":{"every_n_strokes":4,"dmg":1.5,"cancel_windup":true}},

  {"id":"wind_long","school":"wind","name":"Souffle long","rarity":"C","max_level":3,"trigger":"passive","params":{"elan_max_add":[3,5,7]}},
  {"id":"wind_gust","school":"wind","name":"Bourrasque","rarity":"C","max_level":3,"trigger":"passive","params":{"regen_mult":[1.3,1.45,1.6],"elan_per_hit_add":[0.5,1.0,1.5]}},
  {"id":"wind_stillness","school":"wind","name":"Souffle suspendu","rarity":"R","max_level":3,"trigger":"on_touch_down","params":{"time_scale":0.35,"duration_real":[0.6,0.8,1.0],"cooldown":[6,5,4]}},
  {"id":"wind_feather","school":"wind","name":"Plume","rarity":"C","max_level":3,"trigger":"passive","params":{"dodge_cost":0.0,"dodge_dist":3.2,"blade_dmg":[0,0.5,0.5],"extra_dodges":[0,0,1]}},
  {"id":"wind_rebound","school":"wind","name":"Rebond","rarity":"R","max_level":3,"trigger":"on_enemy_kill","params":{"tail_window":1.5,"extend":[2.5,3.5,4.5]}},
  {"id":"wind_blades","school":"wind","name":"Kamaitachi","rarity":"C","max_level":3,"trigger":"on_stroke_release","params":{"offset":1.0,"dmg":[0.4,0.6,0.8]}},
  {"id":"wind_fujin","school":"wind","name":"Fūjin","rarity":"L","max_level":1,"trigger":"on_stroke_release","requires":{"school_count":2},"params":{"min_len":9.0,"radius":4.0,"pull":1.5,"delay":0.25}},

  {"id":"shadow_back","school":"shadow","name":"Ushiro","rarity":"C","max_level":3,"trigger":"on_enemy_hit","params":{"back_cone_deg":120,"mult":[2.0,2.5,3.0]}},
  {"id":"shadow_veil","school":"shadow","name":"Voile","rarity":"C","max_level":3,"trigger":"on_dash_end","params":{"min_kills":2,"invuln":[0.6,0.9,1.2]}},
  {"id":"shadow_clone","school":"shadow","name":"Bunshin","rarity":"R","max_level":3,"trigger":"on_stroke_release","params":{"delay":0.6,"dmg_mult":[0.4,0.6,0.8]}},
  {"id":"shadow_execute","school":"shadow","name":"Kaishaku","rarity":"R","max_level":3,"trigger":"on_enemy_hit","params":{"threshold":[0.2,0.25,0.3],"boss_bonus":0.5}},
  {"id":"shadow_stolen","school":"shadow","name":"Instant volé","rarity":"R","max_level":3,"trigger":"on_dash_end","params":{"min_combo":4,"time_scale":0.3,"duration_real":[0.8,1.0,1.2]}},
  {"id":"shadow_pool","school":"shadow","name":"Flaque noire","rarity":"C","max_level":3,"trigger":"on_enemy_kill","params":{"duration":4.0,"radius":0.9,"invuln":0.5,"elan":[3,4,5]}},
  {"id":"shadow_nue","school":"shadow","name":"Nue","rarity":"L","max_level":1,"trigger":"on_hurt","requires":{"school_count":2},"params":{"per_room":1}},

  {"id":"duo_steam","school":"duo","name":"Vapeur","rarity":"L","requires":{"schools":["fire","water"]},"params":{"radius":2.0,"silence":2.5}},
  {"id":"duo_plasma","school":"duo","name":"Plasma","rarity":"L","requires":{"schools":["fire","bolt"]},"params":{"burn_vs_stun_mult":1.5}},
  {"id":"duo_storm","school":"duo","name":"Orage","rarity":"L","requires":{"schools":["water","bolt"]},"params":{"arc_mult_vs_soaked":2.0,"extra_bounce":1}},
  {"id":"duo_firewhirl","school":"duo","name":"Tornade de feu","rarity":"L","requires":{"schools":["fire","wind"],"form":"form_loop"},"params":{"duration":3.0,"dps":1.2,"speed":2.0}},
  {"id":"duo_typhoon","school":"duo","name":"Typhon","rarity":"L","requires":{"schools":["water","wind"]},"params":{"collide_dmg":1.0}},
  {"id":"duo_blackbolt","school":"duo","name":"Éclair noir","rarity":"L","requires":{"schools":["shadow","bolt"]},"params":{"targets":3,"dmg":1.5}},
  {"id":"duo_moon","school":"duo","name":"Lune noire","rarity":"L","requires":{"schools":["shadow","wind"]},"params":{"slow_add_real":0.4,"dmg_mult_in_slow":1.25}},
  {"id":"duo_inkfire","school":"duo","name":"Encre brûlée","rarity":"L","requires":{"schools":["shadow","fire"]},"params":{"pool_dps":0.5}}
]
```

### 7.2 `enemies.json`
Champs : `id`, `world`, `name`, `model` (glb KayKit/Quaternius proposé), `scale`, `hp`, `speed`, `radius`, `ai` (melee|shooter|leaper|charger|ghost|linked|swarm|healer|mimic|roller|mirror|lure), `attack` (`shape`, `r`/`len`, `windup`, `cooldown`, `dmg`), `cost` (budget), `rule` (tag de règle de tracé), `flags`.

```json
[
  {"id":"oni","world":1,"name":"Hone","model":"Skeleton_Minion","scale":1.6,"hp":1.0,"speed":2.3,"radius":0.45,"ai":"melee","attack":{"shape":"disc","r":1.0,"windup":1.0,"cooldown":1.3,"dmg":1},"cost":1,"rule":"none","flags":["interruptible"]},
  {"id":"kappa","world":1,"name":"Kappa","model":"Skeleton_Mage","scale":1.75,"hp":1.0,"speed":1.6,"radius":0.45,"ai":"shooter","attack":{"shape":"bullet","speed":4.5,"count":1,"windup":0.7,"cooldown":[2.6,3.8],"dmg":1},"cost":2,"rule":"weave_bullets","flags":["keep_range_4.5_7"]},
  {"id":"brute","world":1,"name":"Gashi","model":"Skeleton_Warrior","scale":2.4,"hp":3.5,"speed":1.4,"radius":0.75,"ai":"melee","attack":{"shape":"disc","r":1.5,"windup":1.2,"cooldown":1.3,"dmg":1},"cost":3,"rule":"combo","flags":["uninterruptible","low_knock"]},
  {"id":"tate","world":1,"name":"Tate","model":"Skeleton_Warrior+shield","scale":1.9,"hp":2.0,"speed":1.8,"radius":0.55,"ai":"melee","attack":{"shape":"disc","r":1.0,"windup":1.0,"cooldown":1.5,"dmg":1},"cost":3,"rule":"hit_from_back","flags":["front_shield_120","stops_dash"]},
  {"id":"funa","world":1,"name":"Funa-yūrei","model":"Skeleton_Minion_ghost","scale":1.6,"hp":1.0,"speed":0.0,"radius":0.45,"ai":"ghost_water","attack":{"shape":"disc_at_hero","r":1.2,"windup":1.1,"cooldown":5.0,"dmg":1},"cost":2,"rule":"timing_window","flags":["edge_spawn","visible_2s_hidden_3s"]},

  {"id":"kitsunebi","world":2,"name":"Kitsune-bi","model":"wisp_pair","scale":1.0,"hp":1.0,"speed":1.2,"radius":0.4,"ai":"linked","attack":{"shape":"contact","dmg":1},"cost":3,"rule":"both_in_one_stroke","flags":["revive_partner_2s","orbit_r1.5"]},
  {"id":"tanuki","world":2,"name":"Tanuki","model":"tanuki_lowpoly","scale":1.2,"hp":1.5,"speed":1.5,"radius":0.5,"ai":"mimic","attack":{"shape":"disc","r":2.2,"windup":1.0,"cooldown":3.0,"dmg":1},"cost":2,"rule":"launch_into_group","flags":["disguised","wake_2.5","roll_4m_explode_r2_dmg2"]},
  {"id":"kamaitachi","world":2,"name":"Kamaitachi","model":"weasel_x3","scale":0.8,"hp":0.5,"speed":12.0,"radius":0.35,"ai":"charger","attack":{"shape":"line","len":8.0,"width":0.8,"windup":0.9,"cooldown":2.0,"dmg":1},"cost":3,"rule":"cross_their_line","flags":["group_3"]},
  {"id":"kodama","world":2,"name":"Kodama","model":"kodama","scale":0.9,"hp":1.0,"speed":0.0,"radius":0.4,"ai":"healer","attack":{"shape":"heal_aura","r":3.0,"hps":0.5},"cost":2,"rule":"priority_target","flags":["hides_behind_bamboo"]},
  {"id":"tsuchinoko","world":2,"name":"Tsuchinoko","model":"snake_fat","scale":1.0,"hp":2.0,"speed":0.0,"radius":0.5,"ai":"leaper","attack":{"shape":"disc_landing","r":1.2,"windup":1.0,"jumps":3,"rest":2.5,"dmg":1},"cost":2,"rule":"hit_while_resting_x2","flags":[]},

  {"id":"onryo","world":3,"name":"Onryō","model":"ghost_lady","scale":1.6,"hp":1.5,"speed":1.8,"radius":0.45,"ai":"ghost","attack":{"shape":"disc","r":1.0,"windup":0.9,"cooldown":2.0,"dmg":1},"cost":3,"rule":"reveal_with_ink","flags":["invisible","visible_within_2m","visible_on_fresh_ink_2s"]},
  {"id":"chochin","world":3,"name":"Chōchin-obake","model":"lantern","scale":1.2,"hp":1.0,"speed":1.0,"radius":0.45,"ai":"shooter","attack":{"shape":"bullet_fan","speed":4.5,"count":3,"spread_deg":40,"windup":0.8,"cooldown":3.0,"dmg":1},"cost":2,"rule":"cut_mid_stroke","flags":["explode_on_death_r1.8_dmg1.5_hits_hero"]},
  {"id":"kasa","world":3,"name":"Kasa-obake","model":"umbrella","scale":1.3,"hp":1.0,"speed":0.0,"radius":0.4,"ai":"leaper","attack":{"shape":"disc_landing","r":0.9,"windup":0.8,"hop":2.5,"period":1.4,"dmg":1},"cost":1,"rule":"hit_between_hops","flags":["airborne_untouchable"]},
  {"id":"gaki","world":3,"name":"Gaki","model":"Skeleton_Minion_small","scale":1.0,"hp":0.4,"speed":2.6,"radius":0.3,"ai":"swarm","attack":{"shape":"contact","dmg":1},"cost":0.5,"rule":"bait_with_ink","flags":["group_6_10","eat_ink_1.5s"]},
  {"id":"okiku","world":3,"name":"Okiku","model":"ghost_plates","scale":1.5,"hp":2.0,"speed":0.0,"radius":0.5,"ai":"shooter","attack":{"shape":"bullet_fan","speed":4.0,"count":"salvo_index_1_to_9","spread_deg":80,"windup":0.8,"cooldown":2.2,"dmg":1},"cost":3,"rule":"kill_early","flags":["well_fixed","hide_2s_after_9"]},
  {"id":"oni_frost","world":3,"name":"Hone gelé","model":"Skeleton_Minion","scale":1.6,"hp":1.5,"speed":2.1,"radius":0.45,"ai":"melee","attack":{"shape":"disc","r":1.0,"windup":1.0,"cooldown":1.3,"dmg":1,"leaves":"ice_4s"},"cost":1.5,"rule":"none","flags":["interruptible"]},

  {"id":"aka_ao","world":4,"name":"Aka & Ao","model":"oni_pair","scale":2.0,"hp":3.0,"speed":2.0,"radius":0.6,"ai":"linked","attack":{"aka":{"shape":"line","len":7.0,"windup":1.0,"speed":9.0},"ao":{"shape":"disc","r":1.4,"windup":1.2},"chain_contact_dmg":1,"dmg":1},"cost":6,"rule":"both_in_one_stroke_or_cut_chain","flags":["revive_partner_3s_50pct","chain_len_4"]},
  {"id":"wanyudo","world":4,"name":"Wanyūdō","model":"fire_wheel","scale":1.5,"hp":2.0,"speed":7.0,"radius":0.6,"ai":"roller","attack":{"shape":"contact","dmg":1,"trail_fire":2.0},"cost":3,"rule":"hit_from_side","flags":["bounce_walls","front_back_immune"]},
  {"id":"teppo","world":4,"name":"Teppō-oni","model":"oni_gunner","scale":1.8,"hp":1.5,"speed":1.2,"radius":0.5,"ai":"sniper","attack":{"shape":"laser","track":0.7,"lock":0.4,"cooldown":3.5,"dmg":1},"cost":3,"rule":"leave_locked_line","flags":[]},
  {"id":"hinotama","world":4,"name":"Hi-no-tama","model":"fireball","scale":0.8,"hp":0.5,"speed":1.5,"radius":0.35,"ai":"drifter","attack":{"shape":"explode","r":2.0,"dmg":2,"fuse":6.0},"cost":1,"rule":"cut_mid_stroke","flags":["explode_on_death_hits_hero"]},
  {"id":"kanabo","world":4,"name":"Kanabō-oni","model":"Skeleton_Warrior","scale":2.8,"hp":5.0,"speed":1.3,"radius":0.85,"ai":"melee","attack":{"shape":"disc","r":1.6,"windup":1.2,"cooldown":1.5,"dmg":1,"leaves":"hole_6s"},"cost":4,"rule":"combo","flags":["uninterruptible"]},

  {"id":"kurokage","world":5,"name":"Kuro-kage","model":"Rogue_Hooded_black","scale":1.75,"hp":2.0,"speed":0.0,"radius":0.4,"ai":"mirror","attack":{"shape":"replay_last_stroke","delay":1.5,"dmg":1},"cost":3,"rule":"vary_strokes","flags":[]},
  {"id":"ningyo","world":5,"name":"Ningyo","model":"mermaid","scale":1.4,"hp":1.5,"speed":1.0,"radius":0.5,"ai":"lure","attack":{"shape":"pull","speed":1.2,"duration":3.0,"cooldown":5.0},"cost":2,"rule":"long_stroke_from_range","flags":["dive_if_close_2m"]},
  {"id":"umizato","world":5,"name":"Umi-zatō","model":"blind_monk","scale":2.0,"hp":4.0,"speed":1.0,"radius":0.6,"ai":"listener","attack":{"shape":"disc_at_arrival","r":1.5,"windup":0.8,"trigger_range":5.0,"dmg":1},"cost":4,"rule":"land_far","flags":[]},
  {"id":"sumidama","world":5,"name":"Sumi-dama","model":"ink_blob","scale":1.0,"hp":1.0,"speed":1.5,"radius":0.5,"ai":"splitter","attack":{"shape":"contact","dmg":1},"cost":2,"rule":"recut_return","flags":["split_2_then_4","children_speed_3.5"]},
  {"id":"tate_ink","world":5,"name":"Tate d'encre","model":"Skeleton_Warrior+shield","scale":1.9,"hp":3.0,"speed":1.8,"radius":0.55,"ai":"melee","attack":{"shape":"disc","r":1.0,"windup":0.9,"cooldown":1.4,"dmg":1},"cost":4,"rule":"hit_from_back","flags":["front_shield_120","deflect_dash_90"]}
]
```

### 7.3 `bosses.json` (squelette)
```json
[
  {"id":"okappa","world":1,"tier":"mini","hp":18,"phases":[{"until":0.5,"patterns":["fan5","dive"]},{"until":0.0,"patterns":["fan5","dive","summon_oni_2"]}],"weak":"back_bowl_x3_stun3"},
  {"id":"uwabami","world":1,"tier":"boss","hp":60,"segments":12,"cycle":14,"patterns":["undulate","spit_3x6","coil","wave_x2@0.5"],"rule":"slice_along_min4_segments"},
  {"id":"tsuchigumo","world":2,"tier":"mini","hp":30,"patterns":["web_shot","leap_r1.8","spawn_spiders_3"],"rule":"cut_web_middle"},
  {"id":"kyubi","world":2,"tier":"boss","hp":70,"phases":[{"until":0.6,"rule":"find_real_shadow"},{"until":0.25,"rule":"enso_tails"},{"until":0.0,"rule":"cut_escape_route"}]},
  {"id":"yukionna","world":3,"tier":"mini","hp":35,"patterns":["breath_cone70","ice_mirrors_3","blizzard@0.5"],"rule":"reflected_stroke_only"},
  {"id":"gashadokuro","world":3,"tier":"boss","hp":90,"hands_hp":15,"patterns":["slam_2x3","sweep_third","stele_rain@0.4"],"rule":"spine_in_order_min6"},
  {"id":"ibaraki","world":4,"tier":"mini","hp":45,"arm_hp":10,"patterns":["charge","fire_ring_r2.5","roar_push3"],"rule":"arm_then_body"},
  {"id":"daidarabotchi","world":4,"tier":"boss","hp":110,"phases":[{"cores":3,"layout":"line"},{"cores":5,"layout":"zigzag"},{"cores":7,"layout":"spiral"}],"rule":"connect_cores_in_order"},
  {"id":"bakekujira","world":5,"tier":"mini","hp":60,"patterns":["breach_4x2","spawn_sumidama"],"rule":"return_on_back_x2"},
  {"id":"kuronami","world":5,"tier":"boss","hp":150,"phases":[{"hp":50,"rule":"slice_fingers_along"},{"hp":50,"rule":"return_reflects_wave","protect":"fuji_10"},{"hp":50,"rule":"enso_around_eye_x2"}]}
]
```

### 7.4 `heroes.json`
```json
[
  {"id":"jin","hp":5,"elan_max":14,"elan_regen":9,"dash_speed":34,"dmg":1.0,"reach":0.55,"passive":"iai_first_hit_x2","form":"form_loop","cost":{"sumi":0}},
  {"id":"tsubame","hp":3,"elan_max":10,"elan_regen":13,"dash_speed":44,"dmg":0.8,"reach":0.45,"passive":"queue_stroke_during_dash;short_hit_free_4m","form":"form_zigzag","cost":{"sumi":400}},
  {"id":"benkei","hp":8,"elan_max":12,"elan_regen":7,"dash_speed":26,"dmg":1.6,"reach":0.85,"passive":"guard_while_tracing_140;arrival_shock_r1.5;tap_slam_r1.4","form":"form_return","cost":{"sumi":600,"seal":1}},
  {"id":"kohaku","hp":4,"elan_max":16,"elan_regen":9,"dash_speed":34,"dmg":0.9,"reach":0.55,"passive":"slow_on_touch_0.4_0.5s_cd5;decoy_2s","form":"form_enso","cost":{"sumi":900,"seal":3}}
]
```

---

## 8. Feuille de route d'implémentation (priorisée)

### P0 — Le cœur sans ralenti (à faire tout de suite, 2–4 jours)
1. **Lisibilité** : marqueur d'arrivée (cercle encre → vermillon si arrivée dans une zone qui tombe), flash écume des 0.15 dernières secondes d'annonce, **jetons d'attaque** (max 2 annonces simultanées), vitesse balles 4.5 m/s. Mesurer : morts par « je n'ai pas vu » en test canapé.
2. Vérifier que le filet de sécurité couvre aussi la phase de tracé.
3. Passer les stats héros/ennemis dans `res://data/*.json` (§7) + un `DataDB` autoload ; `enemy.gd` lit `kind` dans la table (garder `oni`/`kappa`/`brute`).
4. Système de **hooks** (`signal` dans `main.gd` : `stroke_released`, `enemy_hit`, `enemy_killed`, `dash_ended`, `hero_hurt`, `room_started`, `touch_down`) pour brancher les améliorations sans toucher au cœur.

### P1 — Une partie complète du monde 1 (1–2 semaines)
5. Boucle de 9 salles + écran « 1 parmi 3 » (cartes icône + nom court) + 2 portes torii.
6. **12 premières améliorations** (pool de départ Feu + Vent + Ombre) : `fire_trail`, `fire_burn`, `fire_spark`, `fire_hearth`, `wind_long`, `wind_gust`, `wind_stillness`, `wind_feather`, `wind_rebound`, `shadow_back`, `shadow_veil`, `shadow_clone`.
7. Ennemis manquants du monde 1 : `tate` (bouclier, dos) puis `funa`. Dangers : trous de planches (le plus simple et le plus fort), puis déferlante.
8. Forme **Uzu** (boucle) — détecteur de formes générique (`stroke_shapes.gd`, fonctions pures testables sur PackedVector3Array).
9. Mini-boss **Ō-Kappa**, boss **Uwabami** (la mécanique « longer le corps » réutilise le test segment/trait).
10. Sanctuaire + 4 malédictions (`curse_dry`, `curse_oni_eye`, `curse_heavy`, `curse_noslow`).

### P2 — Le refuge et l'histoire (1 semaine)
11. Sauvegarde méta (`user://ippitsu.cfg` existe déjà) : sumi, sceaux, Vues, déblocages.
12. Atelier minimal : Pierre à encre (3 lignes), Autel des écoles, Paravent (8 premières Vues en images fixes).
13. Écran de mort → Vue suivante.
14. Boutique tanuki + Source chaude + 3 événements (`ev_jizo`, `ev_tea`, `ev_cursed_blade`).

### P3 — Deuxième héros et écoles complètes
15. **Tsubame** (file de traits pendant la ruée — teste la solidité du système).
16. Écoles Eau et Foudre complètes, formes Inazuma, Kaeshi, Kagi, Ittō ; 4 duos.
17. Malédictions restantes.

### P4 — Mondes 2 et 3
18. Tanabata : bosquets coupables (obstacle de trait = nouvelle règle moteur : `stroke.extend_to` s'arrête sur collision), Kitsune-bi (duo lié), Tanuki, Kamaitachi, Kodama, Tsuchinoko ; Tsuchigumo ; Kyūbi + forme **Ensō**.
19. Cent Contes : glace (glissade d'arrivée), révélation des fantômes par l'encre fraîche (le trait doit persister au sol 2 s : déjà le cas visuellement), Gashadokuro.
20. Benkei.

### P5 — Mondes 4 et 5, fin
21. Fuji Rouge (geysers, coulée, Daidarabotchi « relier les points »).
22. Trente-six Vues (une Vue par salle, Kuro-kage : enregistrer le dernier trait, Vague globale + abris, Kuro-Nami 3 phases).
23. Kohaku, estampes de collection, fin, Marées.

### Repères d'équilibrage à surveiller
- Temps moyen de salle 30–45 s ; dégâts reçus par salle ≈ 0.5–1 PV en monde 1 sans amélioration.
- Taux de traits finissant dans une zone annoncée < 15 % après 3 parties (sinon allonger les annonces de 0.1 s).
- Combo moyen ≥ 2.2 dès la salle 3 (sinon augmenter `HIT_REACH` à 0.65 ou la densité d'ennemis).
- Pick-rate « Souffle suspendu » : s'il dépasse 60 %, le baisser (0.5 s) — c'est le signe que le jeu sans ralenti est trop dur.
