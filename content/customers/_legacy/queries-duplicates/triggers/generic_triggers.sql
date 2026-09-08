-- 1. FUNCION GENERICA REUTILIZABLE
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- 2. TRIGGER PARA cs.addresses
CREATE TRIGGER tg_addresses_updated_at
BEFORE UPDATE ON cs.addresses
FOR EACH ROW
EXECUTE FUNCTION trg_set_updated_at();

-- 3. TRIGGER PARA ship.shipment_orders
CREATE TRIGGER tg_shipment_orders_updated_at
BEFORE UPDATE ON ship.shipment_orders
FOR EACH ROW
EXECUTE FUNCTION trg_set_updated_at();