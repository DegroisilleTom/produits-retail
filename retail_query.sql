#Préparation des données
CREATE DATABASE retail_project;
USE retail_project;

#Vérification des tables
SELECT * FROM retails_order;
SELECT * FROM calendar;

#Nettoyage et normalisation des noms de colonnes
ALTER TABLE retails_order RENAME COLUMN `Product Name` TO product_name;
ALTER TABLE retails_order RENAME COLUMN `Ship Mode` TO ship_mode;
ALTER TABLE retails_order RENAME COLUMN `Ship Date` TO ship_date;
ALTER TABLE retails_order RENAME COLUMN `Customer Name` TO customer_name;
ALTER TABLE retails_order RENAME COLUMN `Order ID` TO order_id;
ALTER TABLE retails_order RENAME COLUMN order_name TO order_date;

ALTER TABLE calendar RENAME COLUMN `Month Name` TO month_name;

#Analyses exploratrices
#Nombre total de lignes
SELECT COUNT(*) AS total_lignes FROM retails_order;

#Période couverte
SELECT MIN(order_date) AS premiere_commande, MAX(order_date) AS derniere_commande
FROM retails_order;

#Segments clients distincts
SELECT DISTINCT segment FROM retails_order;

#Vente, profits et quantités globales
SELECT 
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(profit),2) AS total_profit,
    SUM(quantity) AS total_quantite
FROM retails_order;


#Analyses Business
#TOP 10 des produits les plus vendues
SELECT product_name, SUM(sales) AS ventes_totales
FROM retails_order
GROUP BY product_name
ORDER BY ventes_totales DESC
LIMIT 10;

#Répartition par catégorie
SELECT category, SUM(sales) AS ventes, SUM(profit) AS profit
FROM retails_order
GROUP BY category
ORDER BY ventes DESC;

#TOP clients
SELECT customer_name, SUM(sales) AS ventes
FROM retails_order
GROUP BY customer_name
ORDER BY ventes DESC
LIMIT 10;

#Répartition par segment 
SELECT segment, SUM(sales) AS ventes, SUM(profit) AS profit
FROM retails_order
GROUP BY segment
ORDER BY ventes DESC;

#Analyses temporelles
#Ventes annuelles
SELECT c.year, SUM(r.sales) AS ventes, SUM(r.profit) AS profit
FROM retails_order r
JOIN calendar c ON r.order_date = c.date
GROUP BY c.year
ORDER BY c.year;

#Ventes mensuelles
SELECT c.year, c.month, c.month_name, SUM(r.sales) AS ventes
FROM retails_order r
JOIN calendar c ON r.order_date = c.date
GROUP BY c.year, c.month, c.month_name
ORDER BY c.year, c.month;


#Croissance annuelle
WITH ventes_annuelles AS (
    SELECT cal.year, SUM(r.sales) AS ventes
    FROM retails_order r
    JOIN calendar cal ON r.order_date = cal.date
    GROUP BY cal.year
)
SELECT year,
       ventes,
       ROUND((ventes - LAG(ventes) OVER (ORDER BY year)) / LAG(ventes) OVER (ORDER BY year) * 100,2) AS croissance_pct
FROM ventes_annuelles;


#Analyses avancées

#Classement produits par année
SELECT c.year, r.product_name, SUM(r.sales) AS ventes,
       RANK() OVER (PARTITION BY c.year ORDER BY SUM(r.sales) DESC) AS rang
FROM retails_order r
JOIN calendar c ON r.order_date = c.date
GROUP BY c.year, r.product_name
ORDER BY c.year, rang
LIMIT 20;

#Moyenne mobile 3 mois
WITH ventes_mensuelles AS (
    SELECT c.year, c.month, SUM(r.sales) AS ventes
    FROM retails_order r
    JOIN calendar c ON r.order_date = c.date
    GROUP BY c.year, c.month
)
SELECT year, month, ventes,
       ROUND(AVG(ventes) OVER (ORDER BY year, month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS moyenne_mobile_3m
FROM ventes_mensuelles;

#Produits non rentables
SELECT product_name, SUM(sales) AS ventes, SUM(profit) AS profit
FROM retails_order
GROUP BY product_name
HAVING SUM(profit) < 0
ORDER BY profit ASC
LIMIT 10;

#Analyse Pareto (80% ventes = 20 ventes)
WITH ventes AS (
    SELECT product_name, SUM(sales) AS ventes
    FROM retails_order
    GROUP BY product_name
),
classement AS (
    SELECT product_name, ventes,
           SUM(ventes) OVER (ORDER BY ventes DESC) AS ventes_cumul,
           SUM(ventes) OVER () AS ventes_totales
    FROM ventes
)
SELECT product_name, ventes,
       ROUND(ventes_cumul / ventes_totales * 100,2) AS pct_cumul
FROM classement
WHERE ROUND(ventes_cumul / ventes_totales * 100,2) <= 80;

#TOP 3 des produits avec le plus de retours
SELECT product_name,
       COUNT(*) AS nb_ventes,
       SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) AS nb_retours,
       ROUND(SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*) * 100,2) AS taux_retour_pct
FROM retails_order
GROUP BY product_name
HAVING nb_ventes > 20
ORDER BY taux_retour_pct DESC
LIMIT 3;


#Vues pour Reporting

#Ventes par catégories
CREATE VIEW ventes_par_categorie AS
SELECT category, SUM(sales) AS ventes, SUM(profit) AS profit
FROM retails_order
GROUP BY category;

SELECT * FROM ventes_par_categorie;

#Ventes annuelles par catégories
CREATE VIEW ventes_annuelles_par_categorie AS
SELECT c.year, r.category,
       SUM(r.sales) AS ventes_totales,
       SUM(r.profit) AS profit_total,
       AVG(r.discount) AS remise_moyenne
FROM retails_order r
LEFT JOIN calendar c ON r.order_date = c.date
GROUP BY c.year, r.category;

SELECT * FROM ventes_annuelles_par_categorie;

#Classification et insights

#Classification produits par rentabilité
SELECT product_name, SUM(sales) AS ventes, SUM(profit) AS profit,
       CASE 
           WHEN SUM(profit) < 0 THEN 'Non rentable'
           WHEN SUM(profit) BETWEEN 0 AND 1000 THEN 'Faiblement rentable'
           ELSE 'Très rentable'
       END AS classification_profit
FROM retails_order
GROUP BY product_name
ORDER BY profit DESC;


#Niveau de performance mensuel
SELECT c.year, c.month, c.month_name,
       COALESCE(SUM(r.sales),0) AS ventes,
       CASE 
           WHEN COALESCE(SUM(r.sales),0) > 50000 THEN 'Bonne performance'
           WHEN COALESCE(SUM(r.sales),0) BETWEEN 20000 AND 50000 THEN 'Performance moyenne'
           ELSE 'Faible performance'
       END AS niveau_performance
FROM calendar c
LEFT JOIN retails_order r ON r.order_date = c.date
GROUP BY c.year, c.month, c.month_name
ORDER BY c.year, c.month;


