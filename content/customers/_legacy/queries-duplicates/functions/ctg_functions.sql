-- FUNCTION: USD_TO_COP
CREATE OR REPLACE FUNCTION ctg.convert_usd_to_cop()
RETURNS TEXT
LANGUAGE plpgsql
AS
$$
    DECLARE
        rows_affected INT;
    BEGIN
        UPDATE ctg.products
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
        UPDATE ctg.products
        SET category_id = cat_id
        WHERE id = product_id;

        GET DIAGNOSTICS rows_affected = ROW_COUNT;

        RETURN 'Rows affected: '|| rows_affected;
    END;
$$;

-- UPDATE AUTO THE COP PRICE
CREATE OR REPLACE FUNCTION ctg.update_price_cop_af_ins()
RETURNS TRIGGER
LANGUAGE plpgsql
AS 
$$
    BEGIN

    UPDATE ctg.products
    SET cop_price = (usd_price * 3750)
    WHERE id = NEW.id;

    RETURN NEW;

END;
$$;