# Organisation de la maintenance de l'entrepôt (tâche 3.1, C16)

_Entrepôt VenteRapide, maintenu par ShopFlow (ESN). Ce document définit comment les tâches de
maintenance sont priorisées, réparties, et suivies via des indicateurs de service._

## 1. Méthodologie retenue

On combine trois cadres complémentaires :

- **ITIL** (gestion des services) — on distingue :
  - la **gestion des incidents** : rétablir le service au plus vite (ex. l'entrepôt ne répond plus) ;
  - la **gestion des problèmes** : traiter la **cause racine** pour éviter la récurrence (ex. corriger
    le modèle dbt fautif, pas seulement relancer le build).
- **Ticketing** (Jira / GLPI) — toute demande ou incident = **un ticket** : titre, priorité, assigné,
  statut, historique. Rien ne se traite « à l'oral ».
- **Kanban** — un tableau visuel `À faire → En cours → En revue → Terminé`, avec une **limite de
  tâches en cours (WIP)** pour éviter la dispersion.

**Justification** : ITIL donne le vocabulaire incident/problème et les priorités ; le ticketing assure
la traçabilité (utile pour les indicateurs) ; Kanban rend le flux visible pour une petite équipe.

## 2. Priorisation des tâches

Matrice **impact × urgence** → 4 niveaux de priorité :

| Priorité | Définition | Exemple sur l'entrepôt | Délai de prise en charge (SLA) |
|---|---|---|---|
| **P1 — critique** | Service indisponible ou données corrompues | L'entrepôt ne répond plus ; un backup a échoué | < 1 h |
| **P2 — majeur** | Fonction dégradée, contournement possible | Le `dbt build` nocturne a échoué ; un test dbt rouge | < 4 h |
| **P3 — mineur** | Gêne, sans blocage | Lenteur d'une requête ; doc à mettre à jour | < 1 jour ouvré |
| **P4 — cosmétique** | Amélioration, dette | Renommer un modèle, refactor | < 1 semaine |

## 3. Répartition / assignation (rôles de l'équipe)

Les tâches sont assignées par **domaine de responsabilité** :

| Rôle | Responsabilités de maintenance |
|---|---|
| **Data Engineer** (référent pipeline) | Modèles dbt, tests, intégration de sources, échecs de build |
| **Administrateur PostgreSQL / DBA** | Sauvegardes & restauration, accès/rôles, stockage, journalisation |
| **Référent RGPD (DPO)** | Registre des traitements, procédure de purge/anonymisation, revue des accès |
| **Analyste (consommateur)** | Remonte les anomalies de données via un ticket, valide les correctifs |

Chaque ticket est **assigné nominativement** au rôle concerné ; un incident P1 déclenche l'astreinte
du Data Engineer + DBA.

## 4. Indicateurs de service (basés sur des SLA)

Un SLA = un **indicateur** + une **cible** + une **conséquence** si non atteinte.

| Indicateur | Définition | Cible (SLA) |
|---|---|---|
| **Disponibilité** | % du temps où l'entrepôt est interrogeable | ≥ 99,5 % / mois |
| **MTTR** (P1) | Temps moyen de résolution d'un incident critique | < 4 h |
| **Temps de prise en charge** | Délai avant qu'un ticket soit pris en main | selon priorité (§2) |
| **Fraîcheur des données** | Délai entre la donnée source et l'entrepôt | < 24 h (build quotidien) |
| **Taux de réussite `dbt build`** | % de builds sans échec | ≥ 99 % |
| **Taux de réussite des backups** | % de sauvegardes planifiées réussies | 100 % |
| **Couverture de tests** | Nb de tests dbt verts / total | 100 % (actuellement 87/87) |

Source des mesures : logs PostgreSQL, `target/run_results.json` (dbt), `backups/backup.log`,
historique des tickets. Non-atteinte d'un SLA → **revue d'incident** documentée.

## 5. Tableau de bord de suivi (maquette)

Le tableau de bord rend compte de **l'ensemble** des indicateurs, en un coup d'œil :

| Indicateur | Cible | Valeur (exemple) | Statut |
|---|---|---|---|
| Disponibilité (mois) | ≥ 99,5 % | 99,8 % | 🟢 |
| MTTR incidents P1 | < 4 h | 1 h 20 | 🟢 |
| Fraîcheur des données | < 24 h | 6 h | 🟢 |
| Réussite `dbt build` | ≥ 99 % | 100 % | 🟢 |
| Réussite backups (7 j) | 100 % | 100 % | 🟢 |
| Tests dbt verts | 100 % | 87 / 87 | 🟢 |
| Tickets P1/P2 ouverts | 0 | 0 | 🟢 |
| Dernier backup complet | < 24 h | il y a 3 h | 🟢 |

Vue complémentaire — **tickets par priorité** : P1 (0) · P2 (0) · P3 (2) · P4 (5).

**Outil cible** : en local, ce tableau est un document ; en production il serait alimenté
automatiquement (Metabase / Grafana) à partir des logs, de `run_results.json` et de l'outil de
ticketing.

## 6. En entreprise (industrialisation)

Mêmes principes, outillés : ticketing Jira relié au monitoring, alertes routées vers l'astreinte
(PagerDuty), tableau de bord temps réel (Grafana), revue d'incidents (post-mortems) et rapports SLA
mensuels au client. Voir aussi le guide « Les yeux de l'entrepôt » (journalisation & alertes, 3.2).
