# Factorio Todo Manager

Gestionnaire de tâches indépendant pour **Factorio 2.1**, sans dépendance à un
service externe ni à un mod de contenu. La V1 gère les tâches ; le lot 2 ajoute
les objectifs de production et leur décomposition progressive. La Factoriopedia
appartient au lot 3.

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
sans fichier externe. Le schéma 3 conserve `parent_id` et `order` sur les tâches,
les objectifs de production facultatifs et des préférences indexées par joueur.
La migration depuis les schémas 1 et 2 initialise les nouveaux champs sans perdre
les titres ni les positions.
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

## Lot 2 : objectifs de production

Dans l'éditeur, le bouton à côté du titre ouvre un sélecteur commun aux objets,
fluides et recettes, avec recherche par nom localisé et filtre facultatif par type.
Le choix remplit automatiquement un titre vide et actualise un titre précédemment
généré ; un titre personnalisé est conservé. La cible et la recette ne sont
enregistrées qu'avec le reste du formulaire. Le bouton de retrait de la cible
supprime cette association sans supprimer la tâche ni ses sous-tâches.

Pour un objet ou un fluide, choisir explicitement sa recette dans la liste des
alternatives. Aucune recette n'est choisie automatiquement, même si une seule est
proposée. Les recettes verrouillées sont signalées et peuvent servir à planifier
un objectif futur ; les recettes cachées ne figurent pas dans cette liste.
Pour une recette choisie directement, celle-ci est déjà explicite.

La quantité est facultative :

- Vide : une fabrication de la recette choisie.
- Objet : nombre entier d'unités souhaitées.
- Fluide : quantité souhaitée, éventuellement décimale.
- Recette : nombre entier de fabrications.

Les besoins sont calculés par fabrication entière. Le rendement moyen officiel
est utilisé pour les résultats aléatoires et les résultats multiples ; l'estimation
n'est pas une garantie de production. Aucun bonus de productivité ou de qualité,
choix de machine, vitesse de production ou équilibrage des coproduits n'est simulé.
Les ingrédients sont des besoins bruts, y compris lorsqu'un catalyseur revient
parmi les résultats. Les contraintes de température et de qualité des ingrédients
sont affichées dans la décomposition ; le joueur choisit sa chaîne et ses machines.

Une icône de la cible apparaît dans la liste et le panneau compact, dans une
colonne fixe. Elle ouvre **Décomposer les composants**. Cocher uniquement les
composants à transformer en sous-tâches, puis choisir **Ajouter les composants
sélectionnés**. Les autres restent simplement des ingrédients, sans création de
tâche. Chaque nouvelle sous-tâche conserve sa quantité, mais aucune recette ne lui
est attribuée automatiquement. Elle peut ensuite être développée de la même façon.

Un composant déjà ajouté depuis cette recette n'est pas dupliqué. Ses modifications
manuelles sont conservées. Changer la recette ou la quantité du parent ne modifie
ni ne supprime les enfants déjà créés ; ils doivent être ajustés manuellement.

Les associations sont conservées dans la sauvegarde, au schéma 3. Le passage des
schémas 1 et 2 au schéma 3 conserve les anciennes tâches, positions, statuts,
épingles et préférences. Si un mod retiré emporte un prototype ou une recette,
l'association reste enregistrée, la tâche reste éditable et la décomposition
signale que le prototype n'est plus disponible.

Les essais chargent aussi un mod de test fournissant ses propres objets, fluides
et recettes alternatives, probabilistes et avec contraintes de température. Ils
vérifient la sélection, les quantités, les doublons, les conflits, le développement
progressif et le passage d'une véritable sauvegarde V1 au nouveau schéma.
Ces prototypes de test ne sont pas inclus dans l'archive distribuable.

La Factoriopedia reste prévue pour le lot 3.
