INSERT INTO ctg.products (name, usd_price, category_id)
VALUES
    -- Electrónica (1)
    ('Adaptador de Corriente Universal',        25.99, 1),
    ('Regleta de 6 Tomas con Protección',       18.50, 1),
    ('Cable HDMI 2.1 2m',                       12.99, 1),
    ('Convertidor USB-C a HDMI',                22.00, 1),

    -- Computadores y Laptops (2)
    ('Laptop Lenovo IdeaPad 15',               749.99, 2),
    ('Laptop HP Pavilion 14',                  659.00, 2),
    ('MacBook Air M2',                        1199.00, 2),
    ('Mini PC Intel NUC i5',                   420.00, 2),
    ('Laptop Asus VivoBook 16',                579.99, 2),

    -- Periféricos (3)
    ('Mouse Logitech MX Master 3',              89.99, 3),
    ('Teclado Mecánico Keychron K2',           129.00, 3),
    ('Teclado Inalámbrico Logitech K380',       49.99, 3),
    ('Mouse Ergonómico Vertical Anker',         35.00, 3),
    ('Pad Mouse XL Antideslizante',             15.99, 3),

    -- Almacenamiento (4)
    ('SSD Samsung 970 EVO 1TB',                 79.99, 4),
    ('Disco Duro Externo Seagate 2TB',          65.00, 4),
    ('SSD Externo WD 500GB',                    55.99, 4),
    ('Memoria USB Kingston 128GB',              14.99, 4),
    ('Tarjeta MicroSD SanDisk 256GB',           22.50, 4),

    -- Audio y Sonido (5)
    ('Auriculares Sony WH-1000XM5',            279.99, 5),
    ('Audífonos JBL Tune 510BT',                49.99, 5),
    ('Bocina Portátil JBL Flip 6',              99.99, 5),
    ('Micrófono de Condensador Blue Yeti',     109.99, 5),
    ('Soundbar Samsung HW-B450',               179.00, 5),

    -- Telefonía Móvil (6)
    ('Samsung Galaxy A54 128GB',               349.99, 6),
    ('iPhone 14 128GB',                        799.00, 6),
    ('Xiaomi Redmi Note 12 Pro',               269.99, 6),
    ('Cargador Inalámbrico 15W Belkin',         35.99, 6),
    ('Funda Silicona iPhone 14',                12.99, 6),

    -- Cámaras y Fotografía (7)
    ('Cámara Sony ZV-E10 con Lente Kit',       598.00, 7),
    ('Webcam Logitech C920 HD',                 69.99, 7),
    ('Trípode Flexible Joby GorillaPod',        34.99, 7),
    ('Tarjeta de Captura Elgato HD60 S',       149.99, 7),

    -- Impresoras y Escáneres (8)
    ('Impresora HP DeskJet 2775',               89.00, 8),
    ('Impresora Epson EcoTank L3250',           179.99, 8),
    ('Escáner Portátil IRIScan Anywhere 5',     99.00, 8),

    -- Redes y Conectividad (9)
    ('Router TP-Link AX1800 WiFi 6',            79.99, 9),
    ('Switch TP-Link 8 Puertos Gigabit',        29.99, 9),
    ('Adaptador WiFi USB TP-Link AC600',        14.99, 9),
    ('Repetidor de Señal WiFi Tenda',           22.00, 9),

    -- Monitores y Pantallas (10)
    ('Monitor LG 27" 4K UHD',                 399.00, 10),
    ('Monitor Samsung 24" FHD 75Hz',           159.99, 10),
    ('Monitor Curvo AOC 27" 165Hz',            229.00, 10),

    -- Accesorios de Oficina (11)
    ('Hub USB-C Anker 7 en 1',                  45.00, 11),
    ('Soporte Ergonómico para Laptop',          29.99, 11),
    ('Lámpara LED de Escritorio',               24.50, 11),
    ('Organizador de Cables Velcro x10',         8.99, 11),

    -- Gaming y Videojuegos (12)
    ('Control Xbox Series Inalámbrico',         59.99, 12),
    ('Silla Gamer Secretlab TITAN',            399.00, 12),
    ('Audífonos Gamer HyperX Cloud II',         79.99, 12),
    ('Mousepad Gamer RGB Corsair',              45.00, 12),

    -- Wearables y Smartwatches (13)
    ('Smartwatch Samsung Galaxy Watch 6',      249.99, 13),
    ('Banda Fitness Xiaomi Mi Band 8',          39.99, 13),
    ('Apple Watch SE 2da Gen',                 249.00, 13),

    -- Televisores (14)
    ('Televisor Samsung 55" 4K QLED',          699.00, 14),
    ('Televisor LG 50" NanoCell 4K',           549.99, 14),

    -- Energía y Baterías (18)
    ('Power Bank Anker 20000mAh',               45.99, 18),
    ('Batería Portátil Baseus 10000mAh',        29.99, 18),

    -- Seguridad y Vigilancia (17)
    ('Cámara IP WiFi Tapo C200',                29.99, 17),
    ('Cerradura Inteligente WiFi Eufy',        109.99, 17),

    -- Iluminación Inteligente (16)
    ('Bombilla LED Inteligente Philips Hue',     19.99, 16),
    ('Tira LED RGB WiFi 5m Govee',               34.99, 16),
    ('Foco Inteligente TP-Link Tapo L530',       15.99, 16),

    -- Realidad Virtual y Aumentada (20)
    ('Meta Quest 3 128GB',                      499.99, 20),
    ('Lentes VR PlayStation VR2',               549.00, 20),
    ('Gafas AR Xreal Air 2',                    379.00, 20),

    -- Software y Licencias (19)
    ('Licencia Microsoft Office 365 Personal',   69.99, 19),
    ('Antivirus Kaspersky Premium 1 año',        29.99, 19),
    ('Licencia Adobe Creative Cloud 1 año',     599.99, 19),

    -- Electrodomésticos (15)
    ('Aire Purificador Xiaomi Mi Air 3H',        89.99, 15),
    ('Aspiradora Robot Roomba i3',              299.99, 15),
    ('Cafetera Nespresso Essenza Mini',         119.00, 15),

    -- Cámaras y Fotografía (7)
    ('Drone DJI Mini 3',                        759.00, 7),

    -- Telefonía Móvil (6)
    ('Soporte Magnético para Auto Belkin',       24.99, 6),

    -- Redes y Conectividad (9)
    ('Powerline Adapter TP-Link AV1000',         39.99, 9);