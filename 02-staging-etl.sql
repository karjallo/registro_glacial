BEGIN;

-- limpieza de tablas por si se ejecuta dos veces
TRUNCATE TABLE
    staging.order_audit,
    staging.order_status_history,
    staging.payments,
    staging.order_items,
    staging.orders,
    staging.products,
    staging.customers
CASCADE;

-- customers
COPY staging.customers (
    customer_id, full_name, email, phone, city, segment, created_at, is_active, deleted_at
)
FROM '/var/local/db_imports/data/customers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- products
COPY staging.products (
    product_id, sku, product_name, category, brand, unit_price, unit_cost, created_at, is_active, deleted_at
)
FROM '/var/local/db_imports/data/products.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- orders
COPY staging.orders (
    order_id, customer_id, order_datetime, channel, currency, current_status, is_active,deleted_at, order_total
)
FROM '/var/local/db_imports/data/orders.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- oreder_items
COPY staging.order_items (
    order_item_id, order_id, product_id, quantity, unit_price, discount_rate, line_total
)
FROM '/var/local/db_imports/data/order_items.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- payments
COPY staging.payments (
    payment_id, order_id, payment_datetime, method, payment_status, amount, currency
)
FROM '/var/local/db_imports/data/payments.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- order_status_history
COPY staging.order_status_history (
    status_history_id, order_id, status, changed_at, changed_by, reason
)
FROM '/var/local/db_imports/data/order_status_history.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- order_audit
COPY staging.order_audit (
    audit_id, order_id, field_name, old_value, new_value, changed_at, changed_by
)
FROM '/var/local/db_imports/data/order_audit.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COMMIT;

