# Développement et distribution

## Commandes

```sh
./build.sh check
FACTORIO_BIN=/chemin/factorio-autonome/bin/x64/factorio ./build.sh test
./build.sh package
./build.sh clean
```

`check` compile les fichiers Lua avec `liblua5.2.so.0` et vérifie les traductions
françaises et anglaises. Aucun paquet Python externe n'est nécessaire.
`test` exécute les tests Python de construction et les scénarios dans un moteur
Factorio 2.1 autonome. Les moteurs Steam sont refusés.

`package` produit `dist/todo-manager_<version>.zip` d'après `info.json`.
L'archive contient uniquement le mod, sa documentation, sa licence et son historique ;
les tests et leurs prototypes ne sont pas distribués. `clean` supprime les archives
de ce mod dans `dist/`. Le dossier reste ignoré par Git.

## Lien de développement

```sh
./build.sh devlink --mods-dir ~/.factorio/mods
./build.sh unlink --mods-dir ~/.factorio/mods
```

Le lien pointe vers les sources. Les archives existantes du même mod sont déplacées
dans `.todo-manager-backups` sous le dossier de mods. Aucun dossier réel ni lien vers
un autre projet n'est écrasé. `unlink` retire uniquement le lien de ce projet.
Redémarrer le jeu après un changement de prototypes ; recharger les scripts ne suffit pas.

## Vérifications graphiques

```sh
FACTORIO_GUI_BIN=/chemin/factorio-autonome/bin/x64/factorio python3 tests/visual.py
FACTORIO_GUI_BIN=/chemin/factorio-autonome/bin/x64/factorio python3 tests/factopedia_native.py
```

Le scénario visuel utilise le rendu hors écran ; celui des gestes natifs utilise
Xvfb et `xdotool`. Tous deux utilisent un profil temporaire et le moteur autonome,
sans ouvrir Steam ni les sauvegardes du joueur. `XVFB_BIN` permet de choisir
l'exécutable Xvfb pour le test des gestes natifs.
Les captures et journaux sont écrits dans `tests/visual-output/`, ignoré par Git.

Les tests moteur couvrent sauvegarde/rechargement, migrations des schémas 1 et 2,
arbres profonds, statuts, épingles par joueur, conflits d'édition, surfaces supprimées,
recettes alternatives et prototypes de test. Le scénario natif exerce le survol et
Ctrl + Maj + clic dans l'inventaire et les deux panneaux de la Factopédia, ainsi que
le geste natif Maj seul. Aucun pré-commit ni mesure de couverture n'est configuré.
Le multijoueur avec plusieurs clients simultanés n'est pas couvert par ces scénarios.

## Architecture et persistance

`control.lua` enregistre les événements ; `scripts/runtime.lua` les distribue.
Les modules `scripts/` gèrent les tâches, la production, les recettes, les positions
et les traductions asynchrones des titres. `gui/` construit les fenêtres natives.
`integrations/factopedia.lua` reste indépendant du modèle de tâches.

Les données résident dans `storage.todo_manager`, au schéma 3. Les tâches conservent
leur `parent_id` et leur `order` ; les relations sont reconstruites sans récursion Lua.
Les épingles et préférences sont indexées par joueur. Les migrations ne modifient pas
`storage` pendant `on_load`. Une révision GUI distincte reconstruit les anciennes fenêtres.

L'intégration Factopédia utilise le prototype survolé transmis à un `custom-input`.
Elle ne lit pas la page active et n'injecte aucun bouton dans l'interface du jeu.
La recette n'est directement connue que si le prototype survolé est une recette.

## Préparer une publication

1. Mettre à jour `info.json` et `changelog.txt`.
2. Exécuter les vérifications et relire les captures.
3. Construire l'archive avec `./build.sh package` et vérifier son contenu.
4. Utiliser `docs/mod-portal.md` comme description du portail ; téléverser les captures choisies séparément.

Le dépôt peut rester privé : ne pas utiliser de liens GitHub privés pour les images
publiques du portail. La construction et une fusion Git ne publient rien sur le portail.
