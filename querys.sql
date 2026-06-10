---- 5.4 Consultas estructurales ----
-- las ordenes con line_total mayor a 1000
SELECT c.order_id, c.line_total
FROM core.order_items c
WHERE c.line_total > 1000;

-- todas las ordenes con estado paid que se realizaron mediante el channel
-- mobile
SELECT order_id, channel, curret_status
FROM core.orders
WHERE current_status = 'paid'
    AND channel = 'mobile';

-- ordenes con pagos aprobados que han sido delivered
SELECT s.status_history_id, s.order_id, s.status, p.payment_status
FROM core.order_status_history s
JOIN core.payments p ON p.order_id = s.order_id
WHERE p.payment_status = 'approved'
    AND s.status = 'delivered';

-- todos los productos de la marca Nova
SELECT product_id, product_name, brand
FROM core.products
WHERE brand = 'Nova';

-- clientes que usan copaco
SELECT full_name, phone
FROM core.customers
WHERE phone ~ '^\+59596[0-9]{7}$';

-- las ordenes de los clientes de Ciudad del Este
SELECT o.order_id, o.customer_id, c.city
FROM core.orders o
JOIN core.customers c ON o.customer_id = c.customer_id
WHERE c.city = 'Ciudad del Este';

-- los clientes con fecha de creacion anterior anterior al 2024
SELECT full_name, created_at
FROM core.customers
WHERE created_at < '2026-01-01 00:00';

-- tras verificar la columna order_items, vemos que la columna
-- unit_price y discount_rate, parecen no aplicarse en line_total
--pero tras analizar, el precio correcto se encuentra en products
-- y el unit_price de order_items corresponde al valor ya descontado
-- comprobar, viendo los order_item donde no se cumpla esto, no sale ningun valor
-- se realiza ABS, para poder hacer una aproximacion verdadera porque por
-- diferencias minimas de precision no toma comp verdadera la afirmacion
SELECT o.order_item_id, o.product_id, p.unit_price,
    o.discount_rate, o.unit_price
FROM core.order_items o
JOIN core.products p ON p.product_id = o.product_id
WHERE ABS(o.unit_price - (p.unit_price * (1 - o.discount_rate))) > 0.01;

-- todos los pagos menores a 50 de los clientes de Luque
--aprovados
SELECT p.payment_id, c.customer_id, p.amount
FROM core.payments p
    JOIN core.orders o ON o.order_id = p.order_id
    JOIN core.customers c ON c.customer_id = o.customer_id
WHERE p.amount < 50
    AND p.payment_status = 'approved'
    AND c.city = 'Luque';

-- Casos que no se cargaron
-- los clientes que no ingresaron por tener duplicado phone
SELECT s.customer_id, s.phone
FROM staging.customers s
WHERE customer_id::INT NOT IN
    (SELECT c.customer_id
    FROM core.customers c)

-- ordenes que no se cargaron porque no se pudieron cargar sus usuarios
SELECT s.order_id, s.customer_id
FROM staging.orders s
LEFT JOIN core.customers c
    ON s.customer_id::INT = c.customer_id
WHERE c.customer_id IS NULL;

-- order audits que no se cargaron porque su old o new_value
-- no corresponde al formato utilizado 6 valores alfanumericos = 0
SELECT s.audit_id, s.old_value, s.new_value
FROM staging.order_audit s
LEFT JOIN core.order_audit c ON c.audit_id = s.audit_id::INT
WHERE c.audit_id IS NULL;

-- pagos que no se cargaron porque tienen valor <= 0
SELECT s.payment_id, s.amount
FROM staging.payments s
WHERE s.amount::DECIMAL(10,2) = 0;

------ 5.5 validacion de integridad ------

-- Ordenes que tienen estado de pago aprobado, pero su current status en orders
-- sigue no esta actualizado a paid, shipped, o delivered => muchos
SELECT DISTINCT o.order_id, o.current_status
FROM core.orders o
JOIN core.payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'approved'
  AND o.current_status = 'created';

-- la mayoria de casos que deberian ser filtrados han sido filtrados por
-- el schema diseñado y los que no deberia de haber ingresado ya fueron
-- visualizados en ejemplos anteriores, si nos ponemos mas estrictos
-- tenemos varias incongruencias en algunas columnas, por ejemplo, en
-- order_audit tenemos que son realizadas modificaciones en los campos
-- customer_phone, notes, shipping_address, etc, ninguno de esos campos
-- existe y old_value y new_value son valores alfanumericos de 6 caracteres
-- no concuerda con lo que deberia ser, a menos que haya una tabla mas que no
-- se nos brindo

-- luego, podemos verificar, a pesar de que ya lo realizamos con regex en el
-- schema, hay telefonos que no corresponden a ninguna linea en el pais => muchos
SELECT customer_id, full_name, phone
FROM core.customers
WHERE phone !~ '^\+5959[6-9][0-9]{7}$';

-- para verificar los casos en donde esta activo y deleted_at is not null => 0
SELECT order_id, is_active, deleted_at
FROM core.orders
WHERE is_active = TRUE AND deleted_at IS NOT NULL
   OR is_active = FALSE AND deleted_at IS NULL;

-- pata clientes activos con derleted_at o
-- sin deleted_at pero is_active = false => 0
SELECT customer_id, is_active, deleted_at
FROM core.customers
WHERE is_active = TRUE AND deleted_at IS NOT NULL
    OR is active = FALSE AND deleted_at IS NULL;

-- order_status_history con status 'cancelled' o 'refunded' sin reason => 0
SELECT status_history_id, order_id, status, reason
FROM core.order_status_history
WHERE status IN ('cancelled', 'refunded')
  AND reason IS NULL;
