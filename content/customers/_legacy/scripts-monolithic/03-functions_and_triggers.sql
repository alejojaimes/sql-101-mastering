-- FUNCTION: UPDATE TOTAL
CREATE OR REPLACE FUNCTION pay.update_total_orders()
RETURNS TEXT
LANGUAGE plpgsql
AS
$$
    DECLARE
        rows_affected INT;
    BEGIN
        UPDATE cs.orders ord
        SET total = sub.total
        FROM (
            SELECT
                T1.order_id,
                SUM(T2.cop_price * T1.quantity) AS total
            FROM cs.order_items T1
            INNER JOIN cs.products T2
                ON T1.product_id = T2.id
            GROUP BY 1
        ) sub
        WHERE ord.id = sub.order_id;

        GET DIAGNOSTICS rows_affected = ROW_COUNT;

    RETURN 'Rows affected: '||rows_affected;   
END;
$$;

-- FUNCTION: USD_TO_COP
CREATE OR REPLACE FUNCTION ctg.convert_usd_to_cop()
RETURNS TEXT
LANGUAGE plpgsql
AS
$$
    DECLARE
        rows_affected INT;
    BEGIN
        UPDATE cs.products
        SET cop_price = (usd_price * 3750);

        GET DIAGNOSTICS rows_affected = ROW_COUNT;

    RETURN 'Rows affected: '||rows_affected;   
END;
$$;

-- FUNCTION: UPDATE THE CATEGORIES IN PRODUCTS
CREATE OR REPLACE FUNCTION ctg.update_category_id(product_id INT,
                                             cat_id INT)
RETURNS TEXT
LANGUAGE plpgsql
AS
$$
    DECLARE
        rows_affected INTEGER;
    BEGIN
        UPDATE cs.products
        SET category_id = cat_id
        WHERE id = product_id;

        GET DIAGNOSTICS rows_affected = ROW_COUNT;

        RETURN 'Rows affected: '|| rows_affected;
    END;
$$;

-- CREATE TRIGGER THAT AFTER INSERT
-- UPDATE AUTO THE COP PRICE
CREATE OR REPLACE FUNCTION ctg.update_price_cop_af_ins()
RETURNS TRIGGER
LANGUAGE plpgsql
AS 
$$
    BEGIN

    UPDATE cs.products
    SET cop_price = (usd_price * 3750)
    WHERE id = NEW.id;

    RETURN NEW;

END;
$$;

CREATE TRIGGER tgg_update_price_cop_af_ins
AFTER INSERT ON cs.products
FOR EACH ROW
EXECUTE FUNCTION cs.update_price_cop_af_ins();