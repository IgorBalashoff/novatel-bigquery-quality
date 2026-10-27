# NovaTel — Analyse commerciale & qualité des données

Projet de **Data Analysis** réalisé avec **BigQuery SQL** et **Looker Studio** à partir d’un jeu de données fictif de télécommunications. L’objectif est de contrôler la qualité des données, de préparer une vue exploitable pour le reporting, puis de construire un tableau de bord commercial interactif.

> **Période analysée :** du 1er janvier 2023 au 31 décembre 2024  
> **Outils :** Google BigQuery (SQL) · Looker Studio  
> **Type de projet :** contrôle qualité des données, préparation des données, analyse commerciale et visualisation

## Tableau de bord interactif

[**Ouvrir le tableau de bord NovaTel dans Looker Studio**](https://datastudio.google.com/u/0/reporting/eecb7ab3-c9bf-4b54-9909-c119ac0bb4dd/page/sbqAG)

Le rapport est organisé autour de quatre pages :
1. **Vue globale** — indicateurs clés et évolution mensuelle du chiffre d’affaires net.
2. **Géographie** — comparaison du chiffre d’affaires net par région.
3. **Produits** — chiffre d’affaires par catégorie et canal, et produits les plus performants.
4. **Opérations** — panier moyen, contributions par type d’opération et comparaison par canal.

## Indicateurs clés

| Indicateur | Valeur observée |
|---|---:|
| Transactions dans le tableau de bord | 246 823 |
| Chiffre d’affaires encaissé | 12 191 454,21 € |
| Chiffre d’affaires net | 12 230 149,95 € |
| Clients uniques | 9 901 |
| Panier moyen affiché | 49,55 € |

Ces valeurs correspondent au tableau de bord Looker Studio décrit dans le rapport de synthèse. Les résultats du contrôle qualité BigQuery sont présentés séparément, car la vue de reporting nettoyée n’a pas exactement le même périmètre que la vue utilisée pour le tableau de bord initial.

## Principaux enseignements commerciaux

- Le chiffre d’affaires net mensuel suit une tendance globale à la hausse sur la période, avec des fluctuations.
- Les catégories **Terminal** et **Mobile** sont les principales contributrices au chiffre d’affaires net parmi les catégories affichées.
- Les canaux **Boutique propre** et **Franchise** dominent les contributions au chiffre d’affaires.
- **Facturation** et **Vente terminal** sont les principales contributions positives par type d’opération.
- Les **remboursements** et **avoirs commerciaux** ont des montants négatifs et réduisent le chiffre d’affaires net.
- La catégorie régionale **« Autres »** regroupe plusieurs territoires : elle doit être interprétée avec prudence.

## Démarche de contrôle qualité dans BigQuery

Les contrôles réalisés ont notamment porté sur :

- les transactions sans date et leur exclusion de la vue de reporting, sans modification des tables brutes ;
- les doublons de `transaction_id` ;
- les incohérences entre `montant_brut`, `remise`, `remboursement` et `montant_net` ;
- les montants nets négatifs, interprétés à l’aide du type d’opération et de `impact_ca` plutôt que corrigés automatiquement avec `ABS()` ;
- les transactions validées sans encaissement ;
- les facturations postérieures à une résiliation ;
- les valeurs manquantes et les variations d’écriture dans `dim_client` ;
- l’import et l’utilisation de `dim_type_operation`.

### Résultats de contrôle documentés

| Contrôle | Nombre relevé |
|---|---:|
| Transactions sans date dans la table source | 246 |
| Lignes excédentaires liées aux doublons de `transaction_id` | 30 |
| Incohérences de montant brut détectées par la formule | 142 |
| Montants nets négatifs hors opérations TOP05 et TOP06 | 75 |
| Transactions validées avec `montant_encaisse = 0` | 50 |
| Facturations postérieures à une résiliation | 50 |
| Emails manquants dans `dim_client` | 323 |
| Régions manquantes dans `dim_client` | 206 |

Les anomalies métier pour lesquelles aucune règle de correction certaine n’était établie ont été conservées et signalées, plutôt que corrigées arbitrairement. Les comptages des emails invalides et des emails répétés nécessitent une interprétation prudente : les critères de détection utilisés ne permettent pas, à eux seuls, de confirmer qu’il s’agit tous d’anomalies du même type.

## Captures du tableau de bord

### 1. Vue globale — KPI et évolution mensuelle

![Vue globale du tableau de bord NovaTel](images/novatel_dashboard_1.png)

### 2. Géographie — chiffre d’affaires net par région

![Chiffre d’affaires net par région](images/novatel_dashboard_2.png)

### 3. Produits — catégories, canaux et produits performants

![Analyse des produits dans Looker Studio](images/novatel_dashboard_3.png)

### 4. Opérations — chiffre d’affaires par type d’opération

![Analyse des opérations dans Looker Studio](images/novatel_dashboard_4.png)

### 5. Vue complémentaire du tableau de bord

![Vue complémentaire du tableau de bord NovaTel](images/novatel_dashboard_5.png)

## Recommandations

- Suivre chaque mois le chiffre d’affaires net par catégorie de produit, canal et région.
- Suivre les remboursements et les avoirs commerciaux par période et par canal afin de repérer les variations inhabituelles.
- Examiner la catégorie « Autres » avant de tirer des conclusions sur la performance régionale.
- Continuer à documenter les règles de nettoyage et à distinguer les anomalies confirmées des cas nécessitant une validation métier.

## Livrables

- **Tableau de bord interactif :** [Looker Studio — NovaTel](https://datastudio.google.com/u/0/reporting/eecb7ab3-c9bf-4b54-9909-c119ac0bb4dd/page/sbqAG)
- **Synthèse du contrôle qualité BigQuery :** `Synthese_BigQuery_NovaTel.pdf`
- **Synthèse du tableau de bord commercial :** rapport PDF de synthèse Looker Studio
- **Captures d’écran :** dossier [`images/`](images/)

## Limites d’interprétation

Les graphiques présentent des constats descriptifs et ne démontrent pas, à eux seuls, les causes des tendances observées. Les montants par type d’opération visibles dans le graphique sont arrondis ; pour une analyse financière détaillée, il convient de vérifier les valeurs exactes dans BigQuery.

---
*Projet réalisé dans le cadre de l’apprentissage de la Data Analysis.*
