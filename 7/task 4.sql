WITH -- 1. Общие торговые итоги
trade_totals AS (
    SELECT COUNT(DISTINCT c.civilization_type) AS total_trading_partners,
        SUM(tt.value) AS all_time_trade_value,
        SUM(
            CASE
                WHEN tt.balance_direction = 'positive' THEN tt.value
                WHEN tt.balance_direction = 'negative' THEN - tt.value
                ELSE 0
            END
        ) AS all_time_trade_balance
    FROM CARAVANS c
        JOIN TRADE_TRANSACTIONS tt ON tt.caravan_id = c.caravan_id
),
-- 2. Данные по каждой цивилизации
civilization_data AS (
    SELECT c.civilization_type,
        COUNT(DISTINCT c.caravan_id) AS total_caravans,
        SUM(tt.value) AS total_trade_value,
        SUM(
            CASE
                WHEN tt.balance_direction = 'positive' THEN tt.value
                WHEN tt.balance_direction = 'negative' THEN - tt.value
                ELSE 0
            END
        ) AS trade_balance,
        CASE
            WHEN SUM(
                CASE
                    WHEN tt.balance_direction = 'positive' THEN tt.value
                    WHEN tt.balance_direction = 'negative' THEN - tt.value
                    ELSE 0
                END
            ) > 0 THEN 'Favorable'
            WHEN SUM(
                CASE
                    WHEN tt.balance_direction = 'positive' THEN tt.value
                    WHEN tt.balance_direction = 'negative' THEN - tt.value
                    ELSE 0
                END
            ) < 0 THEN 'Unfavorable'
            ELSE 'Neutral'
        END AS trade_relationship,
        CASE
            WHEN STDEV_SAMP(tt.value) = 0
            OR STDEV_SAMP(de.relationship_change) = 0 THEN NULL
            ELSE COVAR_SAMP(tt.value, de.relationship_change) / (
                STDEV_SAMP(tt.value) * STDEV_SAMP(de.relationship_change)
            )
        END AS diplomatic_correlation,
        STRING_AGG(CAST(c.caravan_id AS NVARCHAR(MAX)), ',') AS caravan_ids_csv
    FROM CARAVANS c
        JOIN TRADE_TRANSACTIONS tt ON tt.caravan_id = c.caravan_id
        LEFT JOIN DIPLOMATIC_EVENTS de ON de.caravan_id = c.caravan_id
    GROUP BY c.civilization_type
),
-- 3. Зависимости по импорту
import_deps AS (
    SELECT cg.material_type,
        SUM(cg.quantity) AS total_imported,
        COUNT(DISTINCT c.caravan_id) AS import_diversity,
        SUM(
            CASE
                WHEN cg.material_type = 'Exotic Metals' THEN cg.quantity * 0.5
                WHEN cg.material_type = 'Lumber' THEN cg.quantity * 0.3
                ELSE cg.quantity * 0.1
            END
        ) AS dependency_score,
        STRING_AGG(CAST(cg.material_id AS NVARCHAR(MAX)), ',') AS resource_ids_csv
    FROM CARAVAN_GOODS cg
        JOIN CARAVANS c ON c.caravan_id = cg.caravan_id
    GROUP BY cg.material_type
),
-- 4. Эффективность экспорта продукции мастерских
export_eff AS (
    SELECT w.type AS workshop_type,
        p.type AS product_type,
        COUNT(DISTINCT wp.workshop_id) AS workshop_count,
        SUM(wp.quantity) AS total_exported,
        SUM(wp.quantity * p.value) AS total_export_value,
        COUNT(DISTINCT wp.workshop_id) * 1.0 / NULLIF(COUNT(DISTINCT w.workshop_id), 1) * 100 AS export_ratio,
        AVG(
            CASE
                WHEN p.value = 0 THEN NULL
                ELSE (CAST(tt.value AS FLOAT) / p.value)
            END
        ) AS avg_markup,
        STRING_AGG(CAST(w.workshop_id AS NVARCHAR(MAX)), ',') AS workshop_ids_csv
    FROM WORKSHOP_PRODUCTS wp
        JOIN PRODUCTS p ON p.product_id = wp.product_id
        JOIN WORKSHOPS w ON w.workshop_id = wp.workshop_id
        LEFT JOIN CARAVAN_GOODS cg ON cg.original_product_id = p.product_id
        LEFT JOIN TRADE_TRANSACTIONS tt ON tt.caravan_id = cg.caravan_id
    GROUP BY w.type,
        p.type
),
-- 5. Эволюция торговли по кварталам
trade_timeline AS (
    SELECT DATEPART(YEAR, tt.date) AS [year],
        DATEPART(QUARTER, tt.date) AS [quarter],
        SUM(tt.value) AS quarterly_value,
        SUM(
            CASE
                WHEN tt.balance_direction = 'positive' THEN tt.value
                WHEN tt.balance_direction = 'negative' THEN - tt.value
                ELSE 0
            END
        ) AS quarterly_balance,
        COUNT(DISTINCT c.civilization_type) AS trade_diversity
    FROM TRADE_TRANSACTIONS tt
        JOIN CARAVANS c ON c.caravan_id = tt.caravan_id
    GROUP BY DATEPART(YEAR, tt.date),
        DATEPART(QUARTER, tt.date)
)
SELECT tt.total_trading_partners,
    tt.all_time_trade_value,
    tt.all_time_trade_balance,
    (
        SELECT civilization_type,
            total_caravans,
            total_trade_value,
            trade_balance,
            trade_relationship,
            diplomatic_correlation,
            JSON_QUERY('[' + cd.caravan_ids_csv + ']') AS caravan_ids
        FROM civilization_data cd FOR JSON PATH
    ) AS civilization_trade_data,
    (
        SELECT material_type,
            dependency_score,
            total_imported,
            import_diversity,
            JSON_QUERY('[' + id.resource_ids_csv + ']') AS resource_ids
        FROM import_deps id FOR JSON PATH
    ) AS resource_dependency,
    (
        SELECT workshop_type,
            product_type,
            export_ratio,
            avg_markup,
            JSON_QUERY('[' + ef.workshop_ids_csv + ']') AS workshop_ids
        FROM export_eff ef FOR JSON PATH
    ) AS export_effectiveness,
    (
        SELECT [year],
            [quarter],
            quarterly_value,
            quarterly_balance,
            trade_diversity
        FROM trade_timeline FOR JSON PATH
    ) AS trade_timeline
FROM trade_totals tt FOR JSON PATH,
    WITHOUT_ARRAY_WRAPPER;