-- FUNCTION: UPDATE TOTAL
CREATE OR REPLACE FUNCTION pay.update_total_orders()
RETURNS TEXT
LANGUAGE plpgsql
AS
$$
    DECLARE
        rows_affected INT;
    BEGIN
        UPDATE pay.orders ord
        SET total = sub.total
        FROM (
            SELECT
                T1.order_id,
                SUM(T2.cop_price * T1.quantity) AS total
            FROM pay.order_items T1
            INNER JOIN ctg.products T2
                ON T1.product_id = T2.id
            GROUP BY 1
        ) sub
        WHERE ord.id = sub.order_id;

        GET DIAGNOSTICS rows_affected = ROW_COUNT;

    RETURN 'Rows affected: '||rows_affected;   
END;
$$;