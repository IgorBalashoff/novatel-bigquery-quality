# NovaTel — Analyse commerciale et qualité des données

Projet de formation **Data Analyst** réalisé avec **Google BigQuery (SQL)** et **Looker Studio**, à partir d’un jeu de données fictif d’un opérateur télécom.

L’objectif est de contrôler la qualité des données, d’identifier les anomalies, de préparer des vues adaptées au reporting et de présenter les indicateurs commerciaux dans un tableau de bord interactif.

## Informations sur le projet

- **Période analysée :** du 1er janvier 2023 au 31 décembre 2024
- **Outils :** Google BigQuery, SQL, Looker Studio
- **Périmètre :** contrôle qualité, préparation des données, analyse commerciale et visualisation
- **Données :** jeu de données fictif NovaTel

## Tableau de bord interactif 

[**Ouvrir le tableau de bord NovaTel dans Looker Studio**](https://datastudio.google.com/u/0/reporting/eecb7ab3-c9bf-4b54-9909-c119ac0bb4dd/page/sbqAG)

Le rapport est organisé autour de quatre pages :

1. **Vue globale** — KPI principaux et évolution mensuelle du chiffre d’affaires net.
2. **Géographie** — comparaison du chiffre d’affaires net par région.
3. **Produits** — chiffre d’affaires par catégorie, canal et produits les plus performants.
4. **Opérations** — panier moyen, contribution des types d’opération et comparaison par canal.

## Indicateurs présentés dans le tableau de bord

| Indicateur | Valeur affichée |
|---|---:|
| Transactions | 246 823 |
| Chiffre d’affaires encaissé | 12 191 454,21 € |
| Chiffre d’affaires net | 12 230 149,95 € |
| Clients uniques | 9 901 |
| Panier moyen affiché | 49,55 € |

Ces valeurs sont celles du tableau de bord Looker Studio. Elles doivent être interprétées selon le périmètre de la source de données du rapport ; elles ne sont pas présentées ici comme les résultats d’une vue de contrôle qualité distincte.

## Captures du tableau de bord

### 1. Vue globale — KPI et évolution mensuelle

![Vue globale du tableau de bord NovaTel](images/novatel_dashboard_1.png)

### 2. Géographie — chiffre d’affaires net par région

![Chiffre d’affaires net par région](images/novatel_dashboard_2.png)

### 3. Produits — catégories, canaux et produits performants

![Analyse des produits dans Looker Studio](images/novatel_dashboard_3.png)

### 4. Opérations — chiffre d’affaires par type d’opération

![Analyse des opérations dans Looker Studio](images/novatel_dashboard_4.png)

### 5. Vue complémentaire — montant net par canal et type d’opération

![Vue complémentaire du tableau de bord NovaTel](images/novatel_dashboard_5.png)

## Démarche de contrôle qualité

Les tables sources sont conservées. Les contrôles et traitements sont réalisés au moyen de requêtes SQL et de vues, afin de séparer les données d’origine des données préparées pour l’analyse.

### 1. Détection des doublons de transactions

La requête ci-dessous recherche les identifiants de transaction répétés dont les lignes présentent les mêmes valeurs métier. Il s’agit d’un contrôle de doublons exacts ; il ne suffit pas, à lui seul, à démontrer que toutes les répétitions d’identifiants sont des doublons exacts.

```sql
SELECT COUNT(*) AS nb_exact_duplicate_ids
FROM (
  SELECT transaction_id
  FROM `postmantest1-337319.novatel.fact_transactions`
  GROUP BY transaction_id
  HAVING COUNT(*) > 1
    AND COUNT(DISTINCT TO_JSON_STRING(STRUCT(
      date_id, client_id, produit_id, point_vente_id,
      type_operation_id, quantite, montant_brut, remise,
      remboursement, montant_net, montant_encaisse,
      statut_transaction
    ))) = 1
);
```

### 2. Exclusion des dates manquantes du reporting

Les lignes sans date sont conservées dans la table source, mais exclues de la vue destinée au reporting. Cette règle évite de les attribuer artificiellement à une période.

```sql
CREATE OR REPLACE VIEW
  `postmantest1-337319.novatel.vw_transactions_reporting_clean` AS
SELECT *
FROM `postmantest1-337319.novatel.vw_transactions_reporting`
WHERE date_transaction IS NOT NULL;
```

Contrôle effectué sur cette vue : **246 577 lignes**, **246 577 identifiants de transaction distincts** et **0 date manquante**.

### 3. Utilisation de la dimension des types d’opération

La dimension `dim_type_operation` décrit les opérations et leur impact sur le chiffre d’affaires. Elle permet de distinguer, par exemple, les opérations positives des remboursements et avoirs, dont l’impact est négatif, et des résiliations, neutres.

```sql
SELECT
  f.type_operation_id,
  o.type_operation,
  o.categorie,
  o.impact_ca,
  COUNT(*) AS nb_transactions,
  MIN(f.montant_net) AS montant_net_min
FROM `postmantest1-337319.novatel.fact_transactions` AS f
LEFT JOIN `postmantest1-337319.novatel.dim_type_operation` AS o
  ON f.type_operation_id = o.type_operation_id
WHERE f.montant_net < 0
GROUP BY
  f.type_operation_id, o.type_operation, o.categorie, o.impact_ca
ORDER BY nb_transactions DESC;
```

Le type d’opération est indispensable pour interpréter les montants négatifs : un remboursement ou un avoir peut légitimement avoir un montant négatif. Il ne faut donc pas appliquer automatiquement `ABS()` à tous les montants négatifs. Les valeurs négatives sur une opération normalement positive doivent être signalées pour investigation métier.

### 4. Contrôle des montants bruts

Pour les produits disposant d’un prix catalogue, le montant brut d’une vente peut être comparé au prix catalogue multiplié par la quantité. Le type d’opération et le statut doivent être pris en compte : le prix catalogue ne constitue pas une règle universelle pour les facturations récurrentes, remboursements ou avoirs.

```sql
SELECT
  f.type_operation_id,
  o.type_operation,
  COUNT(*) AS nb_transactions,
  COUNTIF(
    p.prix_catalogue > 0
    AND ROUND(f.montant_brut, 2)
        != ROUND(p.prix_catalogue * f.quantite, 2)
  ) AS ecarts_catalogue
FROM `postmantest1-337319.novatel.vw_transactions_reporting_clean` AS f
LEFT JOIN `postmantest1-337319.novatel.dim_produit` AS p
  ON f.produit_id = p.produit_id
LEFT JOIN `postmantest1-337319.novatel.dim_type_operation` AS o
  ON f.type_operation_id = o.type_operation_id
WHERE f.type_operation_id IN ('TOP03', 'TOP04')
  AND f.statut_transaction != 'annulée'
GROUP BY f.type_operation_id, o.type_operation
ORDER BY ecarts_catalogue DESC;
```

Lors du contrôle des ventes de terminaux (**TOP03**) et d’accessoires (**TOP04**), aucun écart au prix catalogue n’a été observé dans la vue contrôlée : **0 écart pour 10 547 ventes de terminaux et 0 écart pour 9 280 ventes d’accessoires**.

### 5. Anomalies détectées et règles d’interprétation

Les contrôles menés pendant le projet ont notamment mis en évidence :

- **Dates manquantes :** 246 lignes exclues de la vue de reporting, sans suppression de la source.
- **Montants nets négatifs :** 3 501 lignes négatives dans une première vue de contrôle ; la dimension des types d’opération permet de distinguer les remboursements et avoirs attendus des valeurs négatives suspectes sur des opérations positives.
- **Montants bruts incohérents :** 142 écarts à la formule `montant_brut - remise - remboursement = montant_net` ont été détectés lors d’un contrôle. Les écarts doivent être analysés avec le type d’opération et, lorsque c’est pertinent, le prix catalogue.
- **Transactions validées sans encaissement :** 50 cas ont été identifiés sur des opérations positives dans un contrôle ; ils doivent être interprétés selon le statut et le type d’opération.
- **Facturations postérieures à une résiliation :** 50 cas ont été repérés en rapprochant les dates de facturation et de résiliation pour un même client et produit.
- **Qualité de la dimension client :** contrôles des emails manquants ou invalides, des régions manquantes, des variantes d’écriture des segments et des valeurs de sexe manquantes ou codées `N`.

Ces nombres proviennent de contrôles distincts effectués pendant l’analyse. Ils ne doivent pas être additionnés : certains contrôles peuvent porter sur des périmètres différents.

### 6. Standardisation des segments clients

Une vue dédiée harmonise la casse et les variantes d’écriture des segments, sans modifier la table source.

```sql
CREATE OR REPLACE VIEW
  `postmantest1-337319.novatel.dim_client_clean` AS
SELECT
  client_id,
  prenom,
  nom,
  email,
  sexe,
  date_naissance,
  tranche_age,
  ville,
  region,
  CASE
    WHEN UPPER(segment_client) = 'FAMILLE' THEN 'Famille'
    WHEN UPPER(segment_client) = 'GRAND PUBLIC' THEN 'Grand public'
    WHEN UPPER(segment_client) = 'PROFESSIONNEL' THEN 'Professionnel'
    WHEN UPPER(segment_client) = 'SENIOR' THEN 'Senior'
    WHEN UPPER(segment_client) = 'ÉTUDIANT' THEN 'Étudiant'
    ELSE segment_client
  END AS segment_client
FROM `postmantest1-337319.novatel.dim_client`;
```

Cette standardisation traite les variantes de casse observées. Elle ne corrige pas automatiquement les emails invalides, les doublons de personnes ou les champs manquants : ces cas nécessitent des règles de rapprochement ou une validation adaptée.

## Principaux enseignements commerciaux

- Suivre mensuellement le chiffre d’affaires net par catégorie de produit, canal et région.
- Analyser séparément les remboursements et les avoirs commerciaux, car ils ont un impact négatif sur le chiffre d’affaires.
- Examiner la catégorie « Autres » avant de tirer des conclusions sur les performances régionales.
- Continuer à documenter les règles de nettoyage et à distinguer les anomalies confirmées des cas nécessitant une validation métier.

## Livrables

- **Tableau de bord interactif :** [NovaTel — Looker Studio](https://datastudio.google.com/u/0/reporting/eecb7ab3-c9bf-4b54-9909-c119ac0bb4dd/page/sbqAG)
- **Synthèse du contrôle qualité BigQuery :** `Synthese_BigQuery_NovaTel.pdf`
- **Requêtes SQL :** `cleaning.sql`
- **Captures du tableau de bord :** dossier `images/`

## Limites d’interprétation

Le tableau de bord présente des résultats descriptifs et ne démontre pas, à lui seul, les causes des tendances observées. Les anomalies financières doivent être interprétées selon le type d’opération, le statut de la transaction et les règles métier. Toute correction automatique doit être justifiée et contrôlée ; les montants négatifs ne sont pas corrigés simplement en prenant leur valeur absolue.
