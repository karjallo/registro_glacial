CREATE SCHEMA IF NOT EXISTS staging;

-- customers staging
CREATE TABLE IF NOT EXISTS staging.customers (
    customer_id TEXT,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    city TEXT,
    segment TEXT,
    created_at TEXT,
    is_active TEXT,
    deleted_at TEXT
);

-- products staging
CREATE TABLE IF NOT EXISTS staging.products (
    product_id TEXT,
    sku TEXT,
    product_name TEXT,
    category TEXT,
    brand TEXT,
    unit_price TEXT,
    unit_cost TEXT,
    created_at TEXT,
    is_active TEXT,
    deleted_at TEXT
);

-- orders staging
CREATE TABLE IF NOT EXISTS staging.orders (
    order_id TEXT,
    customer_id TEXT,
    order_datetime TEXT,
    channel TEXT,
    currency TEXT,
    current_status TEXT,
    order_total TEXT,
    is_active TEXT,
    deleted_at TEXT
);

-- order_items staging
CREATE TABLE IF NOT EXISTS staging.order_items (
    order_item_id TEXT,
    order_id TEXT,
    product_id TEXT,
    quantity TEXT,
    unit_price TEXT,
    discount_rate TEXT,
    line_total TEXT
);

-- payments staging
CREATE TABLE IF NOT EXISTS staging.payments (
    payment_id TEXT,
    order_id TEXT,
    payment_datetime TEXT,
    method TEXT,
    payment_status TEXT,
    amount TEXT,
    currency TEXT
);

-- order_status_history staging
CREATE TABLE IF NOT EXISTS staging.order_status_history (
    status_history_id TEXT,
    order_id TEXT,
    status TEXT,
    changed_at TEXT,
    changed_by TEXT,
    reason TEXT
);

-- order_audit staging
CREATE TABLE IF NOT EXISTS staging.order_audit (
    audit_id TEXT,
    order_id TEXT,
    field_name TEXT,
    old_value TEXT,
    new_value TEXT,
    changed_at TEXT,
    changed_by TEXT
);
