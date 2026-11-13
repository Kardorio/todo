# Todo Manager

Organisez vos objectifs industriels dans **Factorio 2.1** : tâches, sous-tâches,
positions et décomposition progressive des recettes. Interfaces en français et en anglais.

## Prise en main

- `/todo Augmenter les fondeurs` crée une tâche à votre position actuelle, avec sa surface, et l'épingle pour vous. La vue distante est prise en compte.
- `/todo` ou l'icône de liste dans la barre des mods ouvre la gestion des tâches.
- Le **+** du titre crée une tâche principale ; celui d'une ligne crée une sous-tâche.
- Cliquez sur un titre pour ouvrir son éditeur. **Enregistrer** applique les modifications ; fermer ou **Recharger** abandonne le brouillon.
- Épinglez les objectifs que vous souhaitez suivre dans le rappel. La roue crantée permet de régler sa largeur et sa visibilité.

## Objectifs de production

Le sélecteur à côté du titre permet de choisir un objet, un fluide ou une recette
avec la recherche native. Le titre se remplit automatiquement ; un titre personnalisé
reste conservé. Un clic droit retire l'association sans supprimer la tâche.

Une recette unique est sélectionnée directement. Pour plusieurs alternatives, vous
choisissez la recette. Le bouton à toque affiche ou masque les recettes non recherchées,
présentées en rouge. Le livre ouvre la recette choisie dans la Factopédia.

Dans les ingrédients, **+** prépare l'ajout du composant en sous-tâche et **✓** annule
cet ajout avant enregistrement. Les composants déjà ajoutés sont signalés. Chaque
sous-tâche peut ensuite être décomposée de la même façon, à votre rythme.
Changer de recette ne réécrit pas les enfants existants.

Survolez une icône dans la Factopédia, l'inventaire ou une interface et faites
**Ctrl + Maj + clic gauche** pour préparer une tâche associée au prototype.
Ce raccourci est configurable dans les contrôles Factorio. L'entrée **Nouvelle tâche**
de la barre de raccourcis ouvre aussi un formulaire vide.

## Rappel et carte

Le rappel présente uniquement les tâches explicitement épinglées, sous forme de cartes,
avec leur hiérarchie et leur progression. Épingler un parent n'épingle pas ses enfants.
Cliquer sur le titre ou l'icône ouvre la fiche de la tâche, même sans objectif de production.
L'icône de carte ouvre sa position ; la Factopédia reste accessible depuis l'éditeur. Il disparaît
s'il n'y a aucune tâche épinglée. Les épingles et réglages sont propres à chaque joueur.

L'éditeur propose un aperçu de la zone enregistrée : **Utiliser ma position**,
**Retirer la position** et **Voir sur la carte**. Les modifications de position sont
appliquées en enregistrant. La navigation ne téléporte pas le personnage et conserve
le brouillon. Une surface supprimée ne supprime jamais la tâche.

## Données et règles

Toutes les tâches sont partagées entre les joueurs de la partie, y compris entre forces.
Le créateur est informatif : chacun peut modifier les tâches. Les données et préférences
suivent la sauvegarde, sans fichier externe. Les données des versions de développement
sont migrées au chargement.

Les statuts sont **À faire**, **En cours**, **Terminé** et **Ignoré**. La progression
compte les enfants directs, hors ignorés, sans terminer automatiquement le parent.
La suppression demande confirmation et conserve les enfants en les remontant d'un niveau.
L'ordre est stable, sans tri manuel. La profondeur du modèle n'est pas limitée.

Les recettes sont lues dans les prototypes du jeu et des mods. Les quantités affichées
sont théoriques ; le mod ne simule ni machines, ni productivité, ni équilibrage des coproduits.
Il n'ajoute jamais automatiquement toute une chaîne de production.

## Installation depuis les sources

Exécutez `./build.sh package`, puis placez `dist/todo-manager_1.0.2.zip` dans votre
dossier de mods et activez **Todo Manager**. Redémarrez Factorio après installation
pour charger les prototypes de raccourci.

Les archives sont générées localement et ne sont pas versionnées.
Voir le [guide de développement](docs/developpement.md) pour les tests et le lien de développement,
et la [présentation du portail](docs/mod-portal.md) pour le texte de publication.

Licence [MIT](LICENSE) — Kardorio.
