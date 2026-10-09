# Ippitsu — Handoff UI/UX v2 (pour Claude Code)

Source de vérité : le canvas Design « Ippitsu — UI/UX » (version du 9 oct. 2026). Ce zip en est l'export complet. Il remplace les maquettes du handoff v1 partout où les deux divergent. La section 0 « Décisions » du handoff v1 (glossaire figé, règles de compteurs et de texte) reste valable, sauf là où ce document la modifie.

## Contenu du zip

| Dossier | Contenu | Usage |
|---|---|---|
| `screens/` | Rendu PNG de chaque planche, à l'échelle ×1,5 | Référence visuelle pixel |
| `source/` | Planches `.dc.html` + `canvas.json` | Valeurs exactes : positions, tailles, couleurs, paths SVG. En cas de doute, c'est la source qui fait foi. |
| `icons/` | SVG prêts à importer dans Godot (grille 32, sauf mention) | `res://ui/icons/` |
| `tokens/theme.json` | Couleurs, éléments jour/nuit, raretés, polices, multiplicateurs | À traduire en `Theme` Godot + constantes `UIColors.gd` |
| `tools/` | Mini-renderer pour prévisualiser une planche en local | Optionnel (voir le commentaire de `viewer.html`) |

Unité : 1 px maquette = 1 u. La référence est 400 × 860 u en portrait. Côté Godot : base 400 × 860, stretch `canvas_items`, aspect `keep_width`.

## 1. Règles transverses (nouvelles ou modifiées)

1. **Plus de kanji dans l'UI.** Seul le logo 一筆 reste (Accueil, DA). Les sceaux à côté des titres sont supprimés. Les éléments, mondes, rangs, monstres, « nouveau », harmonie et ultime passent en pictos (`icons/elements`, `icons/hud`). Les noms romanisés restent (Nidan-zuki, Ushio, Oni) sans leur kanji.
2. **Élément = couleur + picto**, jamais un caractère. Liste : flamme (feu), goutte (eau), éclair (foudre), volute (vent), lune (ombre), enso ouvert (neutre), boucle (figure). Sur une étiquette, on affiche le picto + le nom en capitales (`FOUDRE`) sur fond couleur d'élément.
3. **Chiffres** : toujours en Zen Kaku Gothic New Black 900, tabular-nums, line-height 1. Ne jamais utiliser Shippori pour un chiffre, car il décale la ligne de base.
4. **Rareté = bordure seule**, sans aucun mot (voir `theme.json`).
5. **Pas de textes d'interaction** (« touche pour… »). L'état visuel porte la consigne.
6. **HUD indépendant du thème** : fond sumi à 92 % et contour papier 1,5. Le thème ne change que l'accent.
7. **Halos** : pas de flou dans `_draw()`. Les remplacer par 2 à 3 cercles ou contours concentriques à alpha décroissant.

## 2. HUD de combat (`Main`, `Nuit`, `Specs`)

Zones réservées (y en u) :

| y | Usage |
|---|---|
| 0–32 | Encoche, rien |
| 36–80 | Barre haute : étape (gauche), multiplicateur + score, pause 44 |
| 88–130 | Bandeau d'événement / coach, en haut. Avec un gardien, la barre de gardien occupe 90–154. |
| 136–430 | Jeu pur, aucun élément fixe |
| 434–682 | Grappes latérales (x 7–55 et 338–394) |
| 690–836 | Zone du pouce, rien de fixe |

Composants mis à jour depuis le v1 (les `Specs` gardent quelques valeurs anciennes ; ce tableau prime) :

- **Jauge de vie** (nouvelle) : `icons/composants/jauge_vie_*.svg`, SVG 32 × 188 placé en x 8, y 434.
  - Fourreau : coup de pinceau sumi, path `SHEATH`.
  - Cœur posé en pommeau, translaté de +5.
  - 5 segments inclinés de 3,5 u (coupe de lame), de y 34 à 178, gap 4.
  - Plein : #D7372B, plus un reflet blanc à 40 %.
  - Vide : washi à 12 %.
  - PV qui vient d'être perdu : washi à 55 % (traînée de dégâts). Anim : shake ±3 u sur 120 ms, puis vidage en 200 ms.
  - Critique (1 PV) : liseré vermillon et halo pulsé à 900 ms.
- **XP** : filet de 11 × 150 en x 42, y 470. Jade, or au-delà de 80 %.
- **Niveau** : hexagone 48 en x 7, y 626. Chiffre seul.
- **Encre** : goutte 24 en y 436, puis jauge claire de 28 × 150 en x 362, y 470. Papier, remplissage encre.
- **Ultime** : sceau 56 en x 338, y 624. Arc de charge or de 4 u, picto **pinceau** au centre (plus de 筆). Plein : picto double tap (2 points + arcs) accroché.
- **Étape** : pilule h44. Picto monde (vague pour le monde 1) dans un carré de 30 aux couleurs du monde, « 5/8 » en 20/13, crans de combat 9 × 4.
- **Barre de gardien** (`Nuit`) : makimono 380 × 44.
  - Rouleaux bois et or aux deux bouts.
  - Remplissage rouge à bord pinceau.
  - Traînée de dégâts washi.
  - Encoches de phase (losanges or).
  - Sceau monstre : picto oni sur carré vermillon.
  - Sous la barre : « GARDIEN » + losanges de phase, et à droite une puce or « bouclier brisé ×2 » quand le gardien est vulnérable.
- **Multiplicateur** : puce h32, collée à gauche du score. Couleurs dans `theme.json`. Changement de palier : scale 1 → 1,25 → 1 en 180 ms (back-out).
- **Zones d'attaque** : rouge à 42–45 %, contour 3,5 et liseré blanc pointillé 1,2.

## 3. Carte de rouleau (`RouleauCard`, `CarteRouleau`, `EffetsCartes`)

Carte de 116 × 250, rayon 12. Le seul texte est le nom.

1. Scène peinte de l'élément, avec un médaillon et le glyphe du pouvoir.
2. Haut gauche : pastille « nouveau ». C'est un rond sumi de 22, liseré or, étoile or à 4 branches. Pour une montée de niveau : pastille or ↑.
3. Haut droit : picto de déclencheur sur rond sumi.
4. Cartouche du nom en Shippori 800.
5. **Lignes d'effet, variante C validée** :
   - picto 12 dans la couleur d'élément, sans disque ;
   - libellé en capitales 8,5 #5A5148 ;
   - points de conduite ;
   - valeur en Zen Kaku 900 12, unité en 8 ;
   - hauteur de ligne 24, gap 3 ;
   - panneau en `top: 128`, `left/right: 8`.
6. Crans de niveau 13 × 6. Le cran gagné brille (or + halo). Pas de crans sur un pacte.
7. **Anneau d'harmonie** (état *après* le choix) :
   - 4 arcs fins (r 16, épaisseur 2,6 / 2) ;
   - pleins = pouvoirs de l'élément déjà possédés ; or pointillé = celui qu'apporte la carte ;
   - picto d'élément au centre ;
   - losange or en bas = palier 2 ;
   - pas d'anneau pour Neutre.
8. Bordure = rareté.

Survol / sélection : `translateY(-14)` et ombre portée.

## 4. Composants

- **Boutons** (`Boutons`) :
  - Héros 140 × 52, Principal 128 × 46 (path pinceau dans `icons/composants`), Secondaire 120 × 36 (étiquette papier + puce picto), Prix 96 × 34 (pinceau), Rond Ø44.
  - Onglets : coup de pinceau sumi derrière l'onglet actif, un mot centré en 11 px, interlettrage 2, pas de soulignement.
  - Bouton armé (SCELLER, achat) : contour vermillon, sans coche.
- **Tickets d'effet** (`Icones`) : 124 × 42, talon picto de 34, chiffre 16, unité 9, libellé 7.
  - Variante amélioration : « 3 → 4 », avec la valeur avant grisée.
  - Variante malus : fond sumi, chiffre #FF8A7A.
  - Les 6 variantes de pastilles alternatives sont sur la page « Explorations · pastilles d'effet ». **Aucune n'a encore été validée.**
- **Médaillons de pouvoir** (`icons/pouvoirs`, 60 viewBox) :
  - disque couleur d'élément cerné sumi ;
  - croissant d'ombre en bas à droite, reflet en haut à gauche ;
  - glyphe en silhouette washi cernée de sumi.
  - Une version plus riche (cerclage or, fond ombre) est réservée aux pouvoirs rares (exemple : Estoc assassin).
- **Pastille harmonie** : pilule or « ◆ HARMONIE » en Zen Kaku 900 9 px.

## 5. Écrans (fichier → points clés)

| Planche | Points clés |
|---|---|
| `Accueil` | Logo 一筆 + IPPITSU. Sélecteur de monde (picto monde + rang bambou). JOUER en pinceau 320 × 84. Entrées basses légères (44, translucides) : Atelier, Dojo (torii), Garde-robe, Bestiaire (oni). |
| `Mondes` | Carte de monde. Frise de 8 étapes : boss = oni, gardien = couronne. Score et rang suivant en texte (« Pin à 60 000 »). |
| `Main` / `Nuit` | HUD jour et nuit (§2). Le bandeau d'événement est en haut. |
| `Coach` | Bandeau en haut (picto entaille + « TRACE UN TRAIT ») et main fantôme sur l'ellipse. |
| `Rouleaux` | Choix de 3 cartes. Bulle de description (nom romanisé, texte, anneau → HARMONIE). CHOISIR + relance (compteur). |
| `Sanctuaire` | Pacte : SCELLER (pinceau) / REFUSER. Pas de légende. |
| `Pause` | Feuille papier, en-tête sumi avec trait vermillon (le soleil a été retiré). Stats, bande Pouvoirs, REPRENDRE, OPTIONS / QUITTER en étiquettes. |
| `MesPouvoirs` | Grille de pouvoirs avec une étiquette élément picto + nom. Bulle Nidan-zuki. Tuiles Harmonies : actif = sumi + bord or + losange. |
| `Victoire` / `Defaite` | Score, rang (picto pin), lignes à pictos : rouleaux, traces, chaîne, butin, déblocages. Défaite : monstre fatal + conseil d'esquive en pictos. |
| `Atelier` | Onglets pinceau. Cartes d'amélioration. Prix : « MAX » au lieu de 完. Les boutons prix utilisent encore l'ancienne pilule rouge (voir §7). |
| `GardeRobe`, `Dojo`, `Carnet` | Carnet : clic sur une figure → overlay avec trait animé et emplacement « capture vidéo 4 s ». |
| `Bestiaire`, `FicheMonstre`, `Rencontre` | Encyclopédie. Fiche Oni : attaque/parade, traces, estampe. La première rencontre est **non bloquante** : bandeau en haut, pas de voile. |
| `Options`, `Tuto` | Tuto en 6 planches. |
| `DA`, `Icones`, `Specs` | Références : thèmes, éléments jour/nuit, raretés, typo, iconographie complète, specs HUD. |

## 6. Mapping figure → technique (tiré de la capture Carnet du zip v1)

Boucle → Toupie · Zigzag → Éclair · Trait droit → Iaï · Aller-retour → Garde · Enso → Onde de choc · Crochet → Estoc.

## 7. À valider ou à compléter (ne pas coder comme définitif)

- **Contenus inventés pour la maquette** :
  - texte de la bulle Ushio ;
  - second pacte ;
  - seuils de rang et scores (30 000 / 60 000 / 90 000) ;
  - certains noms de déclencheurs ;
  - mécaniques de `FicheMonstre` (traces par figure, estampe sur 100).
- **Liste des pouvoirs** : 10 sont connus. La liste complète est à fournir.
- **Pastilles d'effet** : choix de variante en attente. Les tickets compacts actuels servent de défaut.
- **Captures vidéo du Carnet** : placeholder, aucune vidéo réelle.
- **Prix de l'Atelier** : à aligner sur le style Prix pinceau de `Boutons`.
- **`Specs`** : ses valeurs de jauge de vie (« cœur 30 + 28 × 150 ») et de sceau d'ultime sont antérieures à la refonte. Utiliser le §2.
- **Picto oni** : version simple, à affiner si besoin.

## 8. Ordre de push conseillé

1. `theme.json` → `Theme` + `UIColors.gd`, polices embarquées.
2. Import de `icons/` (SVG, scale 2 à l'import).
3. HUD combat : jauge de vie, encre, XP, niveau, ultime, barre haute, bandeau en haut, barre de gardien.
4. `RouleauCard` + écran `Rouleaux` + anneau d'harmonie.
5. Pause / Mes pouvoirs.
6. Accueil / Mondes / Victoire / Défaite.
7. Méta : Atelier, Garde-robe, Dojo, Carnet, Bestiaire, Options, Tuto.

Tout est faisable en `_draw()` ou en SVG importé : aplats, polygones, arcs, paths pinceau. Aucun dégradé ni flou n'est requis.
