-- CREATE TRIGGER THAT AFTER INSERT
-- SCHEMA AFFECTED: CTG
CREATE TRIGGER tgg_update_price_cop_af_ins
AFTER INSERT ON ctg.products
FOR EACH ROW
EXECUTE FUNCTION ctg.update_price_cop_af_ins();