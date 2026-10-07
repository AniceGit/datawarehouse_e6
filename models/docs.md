{% docs dim_client %}
Dimension client issue du système e-commerce.
Contient les informations de chaque client avec son segment (Premium/Standard),
sa localisation et sa date d'inscription.
Utilisée en jointure avec fact_commandes et fact_visites via client_id.
{% enddocs %}

{% docs dim_produit %}
Dimension produit du catalogue e-commerce.
Contient les caractéristiques de chaque produit : catégorie, marque, prix,
coût d'achat et marges calculées.
{% enddocs %}

{% docs dim_date %}
Dimension calendrier couvrant la période 2023-2024.
Permet l'analyse temporelle par jour, semaine, mois, trimestre et année.
Inclut l'indicateur weekend.
{% enddocs %}

{% docs dim_canal %}
Dimension des canaux d'acquisition (SEO, Email, Pub, Direct).
Indique si le canal est payant ou organique.
{% enddocs %}

{% docs dim_statut_commande %}
Dimension des statuts possibles d'une commande :
Livré, Annulé, Retourné, En cours.
{% enddocs %}

{% docs fact_commandes %}
Table de faits centrale des commandes.
Granularité : une ligne par commande.
Contient les montants, les délais d'expédition et de livraison,
et les clés étrangères vers toutes les dimensions.
{% enddocs %}

{% docs fact_visites %}
Table de faits des visites sur le site e-commerce.
Granularité : une ligne par visite.
Contient le nombre de pages vues, la durée, le device
et l'indicateur de conversion.
{% enddocs %}

{% docs fact_retours %}
Table de faits des retours produits.
Granularité : une ligne par retour.
Contient le montant remboursé et le motif du retour,
avec les clés étrangères vers dim_client, dim_produit et dim_date,
et la référence de commande (dimension dégénérée commande_id).
{% enddocs %}