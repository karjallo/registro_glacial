BEGIN;

-- Apuntar al esquema correcto para esta sesión de carga
SET search_path TO core, public;

-- Limpieza previa usando nombres reales de tablas
TRUNCATE TABLE
    order_audit,
    order_status_history,
    payments,
    order_items,
    orders,
    products,
    customers
CASCADE;

-- tablas maestras
-- customers
INSERT INTO customers (
    customer_id, full_name, email, phone, city, segment, created_at, is_active, deleted_at
)
SELECT
    customer_id::INT,
    TRIM(full_name),
    LOWER(TRIM(email))::CITEXT,
    TRIM(phone),
    TRIM(city),
    LOWER(TRIM(segment)),
    created_at::TIMESTAMP,
    is_active::INT::BOOLEAN,
    NULLIF(TRIM(deleted_at), '')::TIMESTAMP
FROM staging.customers
ON CONFLICT (phone) DO NOTHING;

-- products
INSERT INTO products (
    product_id, sku, product_name, category, brand, unit_price, unit_cost, created_at, is_active, deleted_at
)
SELECT
    product_id::INT,
    TRIM(sku),
    TRIM(product_name),
    LOWER(TRIM(category)),
    TRIM(brand),
    unit_price::DECIMAL(10,2),
    unit_cost::DECIMAL(10,2),
    created_at::TIMESTAMP,
    is_active::BOOLEAN,
    NULLIF(TRIM(deleted_at), '')::TIMESTAMP
FROM staging.products;

-- depende de customer, otras tablas tambien dependen de orders
-- orders
INSERT INTO orders (
    order_id, customer_id, order_datetime, channel, currency, current_status, order_total, is_active, deleted_at
)
SELECT
    order_id::INT,
    customer_id::INT,
    order_datetime::TIMESTAMP,
    LOWER(TRIM(channel)),
    UPPER(TRIM(currency)),
    LOWER(TRIM(current_status)),
    order_total::DECIMAL(10,2),
    is_active::BOOLEAN,
    NULLIF(TRIM(deleted_at), '')::TIMESTAMP
FROM staging.orders
WHERE customer_id::INT IN (SELECT customer_id FROM core.customers);

-- tablas dependintes
-- order_items
INSERT INTO order_items (
    order_item_id, order_id, product_id, quantity, unit_price, discount_rate, line_total
)
SELECT
    order_item_id::INT,
    order_id::INT,
    product_id::INT,
    quantity::INT,
    unit_price::DECIMAL(10,2),
    discount_rate::DECIMAL(4,3),
    line_total::DECIMAL(10,2)
FROM staging.order_items
WHERE order_id::INT IN (SELECT order_id FROM core.orders);

-- payments
INSERT INTO payments (
    payment_id, order_id, payment_datetime, method, payment_status, amount, currency
)
SELECT
    payment_id::INT,
    order_id::INT,
    payment_datetime::TIMESTAMP,
    LOWER(TRIM(method)),
    LOWER(TRIM(payment_status)),
    amount::DECIMAL(10,2),
    UPPER(TRIM(currency))
FROM staging.payments
WHERE order_id::INT IN (SELECT order_id FROM core.orders)
    AND amount::DECIMAL(10,2) > 0;

-- order_status_history
INSERT INTO order_status_history (
    status_history_id, order_id, status, changed_at, changed_by, reason
)
SELECT
    status_history_id::INT,
    order_id::INT,
    LOWER(TRIM(status)),
    changed_at::TIMESTAMP,
    LOWER(TRIM(changed_by)),
    NULLIF(TRIM(reason), '')
FROM staging.order_status_history
WHERE order_id::INT IN (SELECT order_id FROM core.orders);


INSERT INTO order_audit (
    audit_id, order_id, field_name, old_value, new_value, changed_at, changed_by
)
SELECT
    audit_id::INT,
    order_id::INT,
    LOWER(TRIM(field_name)),
    UPPER(TRIM(old_value)),
    UPPER(TRIM(new_value)),
    changed_at::TIMESTAMP,
    LOWER(TRIM(changed_by))
FROM staging.order_audit
WHERE order_id::INT IN (SELECT order_id FROM core.orders);

COMMIT;
