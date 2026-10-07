# Procédure — Ajouter un nouveau datamart (cas d'usage)

## 1. C'est quoi un datamart ?
Un **datamart** est un sous-ensemble thématique de l'entrepôt, dédié à une équipe ou un usage précis
(marketing, finance, SAV…). Il expose des tables **agrégées / prêtes à l'emploi** construites **au-dessus**
des faits et dimensions existants — il **ne duplique pas** l'étoile, il la réutilise.

Exemple : un datamart « marketing » avec une table `mart_ventes_mensuelles` (CA par mois, canal, segment)
que les analystes interrogent directement, sans réécrire les jointures à chaque fois.

## 2. Prérequis
- L'entrepôt de base est construit (`dbt build` vert).
- Le besoin est défini : quelles mesures, quelle granularité, pour quelle équipe.

## 3. Étapes (dans le projet dbt)

1. **Créer un sous-dossier dédié** sous `models/` :
   ```
   models/marts/marketing/
   ```
2. **Écrire les modèles du mart**, construits sur les faits/dimensions via `ref()`. Exemple
   `models/marts/marketing/mart_ventes_mensuelles.sql` :
   ```sql
   {{ config(materialized='table') }}
   select
       d.annee, d.mois, c.canal, cl.segment,
       count(*)                as nb_commandes,
       sum(f.montant_total)    as chiffre_affaires
   from {{ ref('fact_commandes') }} f
   join {{ ref('dim_date') }}   d  on f.date_commande_id = d.date_id
   join {{ ref('dim_canal') }}  c  on f.canal_id = c.canal_id
   join {{ ref('dim_client') }} cl on f.client_id = cl.client_id
   group by d.annee, d.mois, c.canal, cl.segment
   ```
3. **(Optionnel) Isoler le mart dans son propre schéma** pour la lisibilité et les droits, via
   `dbt_project.yml` :
   ```yaml
   models:
     datawarehouse_e6:
       marts:
         +schema: marts        # les modèles du mart iront dans le schéma "marts"
         +materialized: table
   ```
4. **Documenter et tester** : un `models/marts/marketing/schema.yml` avec description + tests
   (`not_null`, cohérence des agrégats), et un bloc `{% docs %}` si besoin.
5. **Construire** : `dbt build --select marts.marketing` (ou `dbt run --select mart_ventes_mensuelles+`).
6. **Donner l'accès** à l'équipe concernée (lecture seule) — voir `procedure_ajout_acces.md` :
   ```sql
   GRANT USAGE ON SCHEMA marts TO reporting;
   GRANT SELECT ON ALL TABLES IN SCHEMA marts TO reporting;
   ```
7. **Régénérer le lineage** : `dbt docs generate` — le mart apparaît branché sur les faits/dimensions.

## 4. Bonnes pratiques
- Le mart **consomme** l'étoile (faits + dimensions), il ne recrée pas de dimension.
- Un modèle par usage clair ; nommer `mart_<sujet>`.
- Tester les agrégats (ex. total du mart = total du fait) pour éviter les écarts silencieux.
- Ne pas mettre de logique de nettoyage ici : ça reste en staging.
