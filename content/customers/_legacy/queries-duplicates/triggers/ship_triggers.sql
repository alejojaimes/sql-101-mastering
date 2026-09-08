-- 1. FUNCION DEL TRIGGER
CREATE OR REPLACE FUNCTION ship.trg_link_shipment_to_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar que la orden existe
    IF NOT EXISTS (
        SELECT 1 FROM pay.orders WHERE id = NEW.order_id
    ) THEN
        RAISE EXCEPTION 'La orden % no existe en pay.orders', NEW.order_id;
    END IF;

    -- Validar que la orden no tenga ya un envio asignado
    IF EXISTS (
        SELECT 1 FROM ship.shipment_orders
        WHERE  order_id = NEW.order_id
        AND    id       != NEW.id
    ) THEN
        RAISE EXCEPTION 'La orden % ya tiene un envio asignado', NEW.order_id;
    END IF;

    RETURN NEW;
END;
$$;

-- 2. TRIGGER
CREATE TRIGGER tg_link_shipment_to_order
BEFORE INSERT ON ship.shipment_orders
FOR EACH ROW
EXECUTE FUNCTION ship.trg_link_shipment_to_order();