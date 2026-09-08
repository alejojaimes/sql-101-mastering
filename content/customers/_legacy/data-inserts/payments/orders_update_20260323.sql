-- Customer Id To Update: 75099091, 30360752, 43715108

-- Min Orders
-- Customer_id: 30360752 | order_date: 2025-12-16 08:14:53.427655
-- Customer_id: 43715108 | order_date: 2025-12-15 13:52:19.801675
-- Customer_id: 75099091 | order_date: 2025-12-06 00:35:29.241368

UPDATE pay.orders
SET order_date = '2025-12-16 08:14:53.427655'
WHERE id IN ('ORD20260323-725E6C4', 'ORD20260323-5165625')
AND customer_id_number = '30360752';

UPDATE pay.orders
SET order_date = '2025-12-15 13:52:19.801675'
WHERE id IN ('ORD20260323-EF67E08', 'ORD20260323-B4017B8')
AND customer_id_number = '43715108';

UPDATE pay.orders
SET order_date = '2025-12-06 00:35:29.241368'
WHERE id IN ('ORD20260323-48261B2', 'ORD20260323-FBBFE2D')
AND customer_id_number = '75099091';
