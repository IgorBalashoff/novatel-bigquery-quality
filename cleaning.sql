-- NovaTel - BigQuery
-- Nettoyage et contrôles qualité
-- Projet : postmantest1-337319
-- Dataset : novatel

-- ============================================================
-- 1. Vérification des doublons exacts
-- ============================================================

SELECT
  COUNT(*) AS nb_exact_duplicate_ids
FROM (
  SELECT transaction_id
  FROM `postmantest1-337319.novatel.fact_transactions`
  GROUP BY transaction_id
  HAVING COUNT(*) > 1
    AND COUNT(DISTINCT TO_JSON_STRING(STRUCT(
      date_id,
      client_id,
      produit_id,
      point_vente_id,
      type_operation_id,
      quantite,
      montant_brut,
      remise,
      remboursement,
      montant_net,
      montant_encaisse,
      statut_transaction
    ))) = 1
);


-- ============================================================
-- 2. Création de la vue fact_transactions_clean
--    - suppression des doublons exacts
--    - correction des montant_net négatifs pour validée
--    - correction des montant_brut incohérents
-- ============================================================

CREATE OR REPLACE VIEW `postmantest1-337319.novatel.fact_transactions_clean` AS
SELECT DISTINCT
  f.transaction_id,
  f.date_id,
  f.client_id,
  f.produit_id,
  f.point_vente_id,
  f.type_operation_id,
  f.quantite,

  CASE
    WHEN f.statut_transaction = 'validée'
         AND p.prix_catalogue > 0
         AND f.montant_brut != p.prix_catalogue * f.quantite
      THEN p.prix_catalogue * f.quantite
    ELSE f.montant_brut
  END AS montant_brut,

  f.remise,
  f.remboursement,

  CASE
    WHEN f.statut_transaction = 'validée'
         AND f.montant_net < 0
      THEN ABS(f.montant_net)
    ELSE f.montant_net
  END AS montant_net,

  f.montant_encaisse,
  f.statut_transaction

FROM `postmantest1-337319.novatel.fact_transactions` AS f
LEFT JOIN `postmantest1-337319.novatel.dim_produit` AS p
  ON f.produit_id = p.produit_id;


-- ============================================================
-- 3. Contrôles de la vue fact_transactions_clean
-- ============================================================

-- Nombre de lignes, transactions uniques et doublons
SELECT
  COUNT(*) AS nb_lignes,
  COUNT(DISTINCT transaction_id) AS nb_transaction_ids,
  COUNT(*) - COUNT(DISTINCT transaction_id) AS nb_doublons
FROM `postmantest1-337319.novatel.fact_transactions_clean`;


-- Transactions validées avec montant_net négatif
SELECT
  COUNT(*) AS nb_net_negatif_valides
FROM `postmantest1-337319.novatel.fact_transactions_clean`
WHERE statut_transaction = 'validée'
  AND montant_net < 0;


-- Incohérences de montant_brut
SELECT
  COUNT(*) AS nb_gross_incoherents
FROM `postmantest1-337319.novatel.fact_transactions_clean` AS f
JOIN `postmantest1-337319.novatel.dim_produit` AS p
  ON f.produit_id = p.produit_id
WHERE f.statut_transaction = 'validée'
  AND p.prix_catalogue > 0
  AND f.montant_brut != p.prix_catalogue * f.quantite;


-- Références inconnues
SELECT
  COUNTIF(c.client_id IS NOT NULL AND cl.client_id IS NULL) AS clients_inconnus,
  COUNTIF(c.produit_id IS NOT NULL AND p.produit_id IS NULL) AS produits_inconnus,
  COUNTIF(c.point_vente_id IS NOT NULL AND pv.point_vente_id IS NULL) AS points_vente_inconnus
FROM `postmantest1-337319.novatel.fact_transactions_clean` AS c
LEFT JOIN `postmantest1-337319.novatel.dim_client` AS cl
  ON c.client_id = cl.client_id
LEFT JOIN `postmantest1-337319.novatel.dim_produit` AS p
  ON c.produit_id = p.produit_id
LEFT JOIN `postmantest1-337319.novatel.dim_point_vente` AS pv
  ON c.point_vente_id = pv.point_vente_id;


-- Champs financiers NULL
SELECT
  COUNTIF(montant_brut IS NULL) AS brut_null,
  COUNTIF(remise IS NULL) AS remise_null,
  COUNTIF(remboursement IS NULL) AS remboursement_null,
  COUNTIF(montant_net IS NULL) AS net_null,
  COUNTIF(montant_encaisse IS NULL) AS encaisse_null
FROM `postmantest1-337319.novatel.fact_transactions_clean`;


-- Dates manquantes
SELECT
  COUNT(*) AS nb_date_id_null
FROM `postmantest1-337319.novatel.fact_transactions_clean`
WHERE date_id IS NULL;


-- Comparaison Source / Clean
SELECT
  'Source' AS version,
  COUNT(*) AS nb_lignes,
  COUNT(DISTINCT transaction_id) AS nb_transactions
FROM `postmantest1-337319.novatel.fact_transactions`

UNION ALL

SELECT
  'Clean' AS version,
  COUNT(*) AS nb_lignes,
  COUNT(DISTINCT transaction_id) AS nb_transactions
FROM `postmantest1-337319.novatel.fact_transactions_clean`;


-- ============================================================
-- 4. Création de dim_client_clean
--    Standardisation de segment_client
-- ============================================================

CREATE OR REPLACE VIEW `postmantest1-337319.novatel.dim_client_clean` AS
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


-- Contrôle des segments standardisés
SELECT
  segment_client,
  COUNT(*) AS nb_clients
FROM `postmantest1-337319.novatel.dim_client_clean`
GROUP BY segment_client
ORDER BY nb_clients DESC;


-- Contrôle du nombre de clients
SELECT
  COUNT(*) AS nb_clients,
  COUNT(DISTINCT client_id) AS nb_client_ids
FROM `postmantest1-337319.novatel.dim_client_clean`;


-- ============================================================
-- 5. Anomalie potentielle conservée pour investigation
-- ============================================================

SELECT
  type_operation_id,
  COUNT(*) AS nb_transactions,
  MIN(montant_net) AS min_net,
  MAX(montant_net) AS max_net
FROM `postmantest1-337319.novatel.fact_transactions_clean`
WHERE statut_transaction = 'validée'
  AND montant_net > 0
  AND montant_encaisse = 0
GROUP BY type_operation_id
ORDER BY nb_transactions DESC;
