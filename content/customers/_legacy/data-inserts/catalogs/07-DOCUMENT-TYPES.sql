INSERT INTO ctg.document_types (code, description, abbreviation)
VALUES
('1', 	'Cédula de ciudadanía', 'CC') , 
('2', 	'Cédula de extranjería', 'CE'), 
('3', 	'Número de identificación tributaria',  'NIT'),
('4', 	'Tarjeta de identidad', 'TI'), 
('7', 	'Sociedad extranjera sin NIT en Colombia', 'SESNE'),
('9', 	'Número único de identificación personal', 'NUIP'),
('10', 	'Permiso por protección temporal',  'PPT'),
('11', 	'Permiso especial de permanencia',  'PEP'),
('12', 	'Registro Civil', 'RC'),
('13',   'Documento de Identidad Policial',  'DIP');

INSERT INTO ctg.document_types (code, description)
VALUES
('14', 	'Visa') , 
('5', 	'Pasaporte'), 
('6', 	'Carné diplomático');