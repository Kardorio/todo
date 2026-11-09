# Factorio Todo Manager

Gestionnaire de tâches indépendant pour **Factorio 2.1**, sans dépendance à un
service externe ni à un mod de contenu. La V1 gère les tâches ; l'association aux
recettes et la Factoriopedia appartiennent aux versions suivantes.

## Utilisation

- `/todo Augmenter les fondeurs` crée une tâche à la position actuelle du
  contrôleur, y compris sur la surface consultée en vue distante. Elle est
  automatiquement épinglée pour son créateur.
- `/todo` ou le bouton **Tâches** ouvre la fenêtre complète.
- Le bouton **+** de la fenêtre crée une tâche principale. Celui d'une ligne
  prépare une sous-tâche. Les tâches créées dans la fenêtre n'ont pas de position
  par défaut.
- La fenêtre principale contient uniquement le listing. Cliquer sur un titre
  ou sur **+** ouvre une fenêtre distincte d'édition ou d'ajout : titre,
  description, statut, priorité et parent. **Enregistrer** applique les
  modifications puis revient au listing ; **Recharger** les abandonne.
  Fermer l'éditeur revient également au listing sans enregistrer.
  La création et l'édition sont accessibles à tous les joueurs.
- Les flèches **↑ / ↓** réordonnent une tâche parmi ses sœurs. Le choix du parent
  dans les détails déplace une tâche avec tous ses descendants. Les cycles sont
  refusés ; aucune profondeur maximale n'est imposée au modèle.
- La case d'une ligne marque la tâche comme terminée ; la décocher la remet à
  faire. Le formulaire donne accès aux quatre statuts : à faire, en cours,
  terminé et ignoré. Le compteur porte sur les enfants directs, hors ignorés.
  Il ne change jamais automatiquement le statut du parent.
- Le bouton de géolocalisation capture la position actuelle ; la corbeille de
  position la retire. Ces deux changements s'appliquent à l'enregistrement.
  Le bouton carte ouvre la position affichée en vue distante, sans téléporter
  le personnage. Une surface supprimée est signalée et la tâche est conservée.
  Une icône de carte apparaît aussi dans le listing et le panneau compact pour
  les tâches géolocalisées : son infobulle donne la surface et les coordonnées,
  et un clic ouvre la position. Elle est désactivée si la surface a été supprimée.
  La navigation conserve la fenêtre ouverte et le brouillon de l'éditeur.
- La corbeille de tâche demande confirmation. Les enfants sont conservés et
  remontent au parent de la tâche supprimée, à sa place dans l'ordre des tâches.

Le panneau compact affiche les tâches épinglées et leurs descendants. Il disparaît
automatiquement lorsqu'aucune tâche existante n'est épinglée, puis réapparaît dès
qu'une tâche est épinglée si sa visibilité est activée. Les épingles
et branches repliées sont propres à chaque joueur. Le bouton d'épingle d'une ligne
ajoute ou retire cette tâche du panneau. Épingler un enfant déjà visible sous un
ancêtre épinglé ne le duplique pas. La barre de titre permet de déplacer le
panneau ; sa croix le masque. Le bouton d'épingle en haut de l'écran le réaffiche.
La position et la visibilité du panneau sont conservées par joueur.

Toutes les tâches sont partagées dans la partie, y compris entre forces. Le
créateur est conservé à titre informatif ; ce n'est pas une restriction d'édition.
Si une tâche a changé depuis l'ouverture du formulaire, l'enregistrement est
refusé pour éviter d'écraser une modification concurrente. Le texte saisi reste
accessible pour être copié avant de recharger les détails.

## Installation et construction

```sh
./build.sh package
./build.sh devlink
```

L'archive est produite dans `dist/`. `devlink` installe un lien vers les sources
dans `~/.factorio/mods` ; les anciennes archives du même mod sont déplacées dans
un sous-dossier de sauvegarde pour éviter qu'elles masquent ce lien. Un dossier
existant ou un lien appartenant à un autre emplacement n'est pas remplacé.
Redémarrer Factorio, puis activer **Todo Manager** dans le menu des mods.

`./build.sh unlink` retire uniquement le lien appartenant à ce projet.
`./build.sh clean` retire les archives de ce mod dans `dist/`.
Le paramètre `--mods-dir /chemin` permet de choisir un autre dossier de mods.

## Données et mises à jour

Les données sont dans `storage.todo_manager`, à l'intérieur de la sauvegarde,
sans fichier externe. Le schéma 2 utilise `parent_id` et `order` sur les tâches,
et des préférences indexées par joueur. La migration depuis le premier prototype
(schéma 1) initialise les nouveaux champs sans perdre les titres ni les positions.
Elle est appliquée à l'initialisation, au changement de configuration ou avant la
première utilisation après chargement d'un ancien schéma, y compris lors du
remplacement du prototype à version identique. Aucune écriture n'est effectuée
pendant `on_load`.

Une révision distincte de l'interface permet de reconstruire les anciennes
fenêtres au premier tick après une mise à jour, même à version de mod identique.
Les tâches, épingles et préférences d'affichage sont conservées.

Les arbres sont parcourus avec une pile explicite. L'indentation visuelle est
plafonnée pour laisser le titre accessible ; la profondeur réelle apparaît dans
l'infobulle. Les grandes listes disposent d'un défilement horizontal et vertical.

## Vérification

```sh
./build.sh check
FACTORIO_BIN=/chemin/vers/factorio-autonome/bin/x64/factorio ./build.sh test
```

`check` vérifie la syntaxe avec `liblua5.2.so.0` et la cohérence des traductions
françaises et anglaises. Aucun paquet Python externe n'est nécessaire.

Les tests moteur créent une vraie sauvegarde avec des tâches et préférences,
puis la rechargent dans Factorio 2.1 autonome. Ils exercent le modèle, une chaîne
profonde, la migration, les événements de l'interface, les brouillons et conflits,
les déplacements, les épingles et les positions, dont les surfaces supprimées.
Les données de test et de jeu sont isolées dans un répertoire temporaire. Aucun
moteur Steam n'est lancé. `FACTORIO_BIN` est obligatoire pour ce test.

Le rendu visuel et le confort d'utilisation restent à vérifier avec un client
graphique autonome. Une session avec plusieurs clients et le transfert d'une
sauvegarde sur un autre ordinateur ne sont pas couverts par le test moteur.
Aucun contrôle de couverture ni pré-commit n'est configuré.
