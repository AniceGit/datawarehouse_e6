{{ config(materialized="table") }}

with retours as (
    select * from {{ ref('stg_retours') }}
)

select
    retour_id,
    commande_id,
    client_id,
    produit_id,
    to_char(date_retour, 'YYYYMMDD')::integer as date_retour_id,
    motif,
    montant_rembourse
from retours
