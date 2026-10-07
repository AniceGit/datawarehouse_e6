# RGPD — Stratégie d'accès, registre des traitements & procédure de purge

_Entrepôt VenteRapide. Responsable de traitement : **VenteRapide**. Sous-traitant technique :
**ShopFlow** (ESN). Ce document couvre le volet conformité de la tâche 3.5._

## 1. Données personnelles présentes dans l'entrepôt

| Où | Colonnes personnelles |
|---|---|
| `raw_clients` / `stg_clients` / `dim_client` / `scd_client` | `nom`, `prenom`, `email`, `date_naissance`, `ville`, `code_postal` |
| `fact_commandes`, `fact_visites`, `fact_retours` | `client_id` (donnée personnelle par rattachement) |

## 2. Stratégie de gestion des accès (moindre privilège)

- Chaque accès est **nominatif** et limité au besoin réel (voir `procedure_ajout_acces.md`).
- L'utilisateur applicatif `dbt_user` (lecture/écriture) sert **uniquement** au pipeline dbt.
- L'équipe analytique passe par le rôle **`reporting` en lecture seule** — jamais d'écriture possible.
- **Minimisation des colonnes** : pour un besoin purement statistique, exposer une **vue** sans les
  colonnes identifiantes plutôt que la table brute. Exemple :
  ```sql
  CREATE VIEW v_clients_anonyme AS
  SELECT client_id, ville, segment, actif FROM dim_client;  -- sans nom/email
  GRANT SELECT ON v_clients_anonyme TO reporting;
  ```
- Les accès sont **tracés** (journalisation `log_connections` — voir tâche 3.2) et **révoqués** en fin
  de mission.

## 3. Registre des traitements (art. 30 RGPD)

| Traitement | Finalité | Données concernées | Base légale | Durée de conservation | Destinataires |
|---|---|---|---|---|---|
| Gestion des commandes | Exécuter et suivre les commandes | client_id, nom, email, ville, code_postal, montants | Exécution du contrat | 5 ans (obligations comptables/commerciales) | Logistique, comptabilité |
| Gestion des retours | Traiter les remboursements | client_id, produit, montant remboursé, motif | Exécution du contrat | 5 ans | SAV, comptabilité |
| Analyse des visites | Statistiques d'audience du site | client_id, device, pages vues, durée | Intérêt légitime / consentement (cookies) | 13 mois (recommandation CNIL cookies) | Équipe analytique |
| Reporting analytique | Pilotage de l'activité | agrégats + client_id | Intérêt légitime | Durée d'activité du compte | Équipe reporting (rôle `reporting`) |
| Historisation client (SCD) | Analyser l'état du client au moment des faits (ville/segment) | nom, ville, code_postal, segment + bornes de validité | Intérêt légitime | Idem clients (5 ans) | Équipe analytique |

## 4. Procédure de tri / purge des données personnelles

**Principe RGPD** : limitation de la durée de conservation + minimisation. On **anonymise** les clients
devenus inactifs, ce qui les rend non identifiables **tout en gardant** la valeur analytique agrégée.

- **Critère d'inactivité** : aucune commande depuis **36 mois**.
- **Action** : anonymisation des champs identifiants (`nom`, `prenom`, `email`, `ville`, `code_postal`),
  en conservant `client_id` pour ne pas casser les analyses. **Irréversible** (≠ pseudonymisation).
- **Fréquence** : **mensuelle**.
- **Automatisation** : **automatisée** via `cron`, avec un **dry-run** journalisé avant la purge.

Script fourni : `scripts/anonymize_inactifs.sql` (paramètre `seuil_mois`, défaut 36).
```bash
# dry-run (liste les candidats, ne modifie rien) — décommenter la requête 1 du script, ou :
psql -h localhost -p 5433 -U dbt_user -d datawarehouse_e6 -c "
  select count(*) from raw_clients where client_id not in (
    select distinct client_id from raw_commandes
    where date_commande::date >= (now() - interval '36 months')::date);"
# purge réelle (à planifier en cron mensuel)
psql -h localhost -p 5433 -U postgres -d datawarehouse_e6 -f scripts/anonymize_inactifs.sql
```
Exemple de planification mensuelle (1er du mois à 3 h) :
```cron
0 3 1 * * psql -p 5433 -d datawarehouse_e6 -f /chemin/scripts/anonymize_inactifs.sql >> /chemin/logs/purge.log 2>&1
```

**Point important (spécifique à notre architecture)** : la donnée personnelle « source de vérité » est
**en amont** (système opérationnel / seed `raw_clients`). L'entrepôt étant reconstruit depuis la source
à chaque `dbt build`, la purge doit s'appliquer à la **source** — sinon un simple `dbt seed` restaurerait
les données. En production, l'anonymisation est déclenchée sur le **système opérationnel**, puis
propagée à l'entrepôt par le pipeline.

**Vocabulaire à distinguer** :
- **Anonymisation** : irréversible, la donnée sort du champ du RGPD (choix retenu ici).
- **Pseudonymisation** : réversible (ex. remplacement par un jeton), reste une donnée personnelle.
- **Suppression** : effacement pur (perd aussi la valeur analytique agrégée).

_Validation (2026-09-10) : dry-run exécuté → 17 clients candidats identifiés (inactifs > 36 mois)._
