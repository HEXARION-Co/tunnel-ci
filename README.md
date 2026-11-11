# tunnel-ci

Le **juge** du Tunnel HEXARION : il lance les tests du code écrit par l'IA dans un conteneur verrouillé et produit le « vert » que la porte de fusion de [tunnel-core](https://github.com/HEXARION-Co/tunnel-core) exige (architecture §5.4, §11.1). L'IA ne doit jamais pouvoir le modifier : c'est un composant **Tier-0**.

## Ce que fait le harnais

`actions/run-tests` est une action composite GitHub. Elle exécute la commande de test du repo dans un conteneur :

- **sans réseau** (`--network none`), **sans secret** (environnement vide), **sans socket Docker** ;
- racine en **lecture seule**, repo monté en **lecture seule**, `/tmp` en mémoire et non exécutable ;
- utilisateur non privilégié (10001), aucune capacité, `no-new-privileges`, limites de processus, mémoire, CPU ;
- **délai dur** (1 à 3600 s, 600 par défaut) ;
- image de test **épinglée par digest** (`actions/run-tests/image.lock`) : toute image non épinglée est refusée.

## Utilisation

Dans un repo de code, par SHA complet (jamais par branche ni par tag) :

```yaml
jobs:
  linux-tests:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>
        with: { persist-credentials: false }
      - uses: HEXARION-Co/tunnel-ci/actions/run-tests@<sha de tunnel-ci>
        with:
          test-command: python -m unittest discover -s tests -v
```

Le SHA de `tunnel-ci` utilisé est le **harnais** enregistré dans l'enveloppe de chaque tâche (`ci_harness_sha`) ; la porte de fusion le compare à la valeur attendue de la politique du repo.

## Auto-test

`.github/workflows/selftest.yml` prouve à chaque PR que le harnais tient : un projet sain passe, un projet en échec échoue, une commande qui s'emballe est arrêtée par le délai, une image non épinglée est refusée, et dans le conteneur l'utilisateur, le réseau, le système de fichiers, l'environnement et le socket Docker sont bien isolés.

## Gouvernance

- **Public**, pour que les règles de protection GitHub s'appliquent sans plan payant et que `tunnel-sandbox` (public) puisse l'utiliser. Rien de secret ici ; les futurs tests de confiance cachés iront dans un dépôt privé séparé.
- Branche `main` : PR obligatoire, check `selftest` vert sur le SHA exact, historique linéaire, pas de force push ni de suppression. Tags figés.
- Aucune GitHub App du Tunnel n'y est installée, aucune branche `ai/*`. **Jamais d'auto-merge** : l'opérateur fusionne.

## Limites connues

- Un repo de code appelle le harnais depuis son propre workflow ; une PR qui modifierait `.github/workflows/` pourrait contourner le harnais. Le contrôle de chemins du validateur (§7) doit interdire `.github/**` à l'IA ; la règle de protection correspondante côté repo reste à brancher.
- Le conteneur est celui de GitHub Actions (sans gVisor) : isolement de niveau conteneur durci, voir §14 pour la suite.
