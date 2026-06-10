-- eliminamos el esquema y todas las tablas
DROP SCHEMA IF EXISTS core CASCADE;

-- creamos el esquema
CREATE SCHEMA core;
-- colocamos el path a core, para no escribir core cada vez
SET search_path TO core, public;

CREATE EXTENSION citext;

-- customers
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email CITEXT NOT NULL UNIQUE
        CHECK (email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]+$' ),
    phone VARCHAR(13) NOT NULL UNIQUE
        CHECK (phone ~ '^\+5959[0-9]{8}$'),
    city VARCHAR(50) NOT NULL,
    segment VARCHAR(50) NOT NULL
        CHECK (segment IN ('retail', 'wholesale', 'online_only', 'vip')),
    created_at TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL,
    deleted_at TIMESTAMP NULL
        CHECK (
            (is_active = TRUE AND deleted_at IS NULL)
            OR
            (is_active = FALSE AND deleted_at IS NOT NULL)
        )
);

-- products
CREATE TABLE products(
    product_id INT PRIMARY KEY,
    sku VARCHAR(14) NOT NULL UNIQUE
        CHECK (sku ~'^SKU-[A-Z0-9]{10}$'),
    product_name VARCHAR(100) NOT NULL
        CHECK (product_name ~ '^[A-Z][a-zA-Z]* [a-z]+ [A-Z0-9]+$'),
    category VARCHAR(50) NOT NULL
        CHECK (category ~'^[a-z]+$'),
    brand VARCHAR(50) NOT NULL
        CHECK (brand ~ '^[A-Z][a-zA-Z]*$'),
    unit_price DECIMAL(10,2) NOT NULL
        CHECK (unit_price > 0),
    unit_cost DECIMAL(10,2) NOT NULL
        CHECK (unit_cost > 0),
    created_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    deleted_at TIMESTAMP NULL
    CHECK (
        (deleted_at IS NULL AND is_active = TRUE)
        OR
        (deleted_at IS NOT NULL AND is_active = FALSE)
    )
);

-- orders
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_datetime TIMESTAMP NOT NULL,
    channel VARCHAR(50) NOT NULL
        CHECK (channel IN ('mobile', 'web', 'store', 'phone')),
    currency VARCHAR(3) NOT NULL
        CHECK (currency ~ '^[A-Z]{3}$'),
    current_status VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    deleted_at TIMESTAMP NULL
        CHECK (
            (is_active = TRUE AND deleted_at IS NULL) OR
            (is_active = FALSE AND deleted_at IS NOT NULL)),
    order_total DECIMAL(10,2) NOT NULL
        CHECK (order_total >= 0),

    CONSTRAINT orders_customer_id_fkey
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- order_items
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL
        CHECK (quantity > 0),
    unit_price DECIMAL (10,2) NOT NULL
        CHECK (unit_price > 0),
    discount_rate DECIMAL(4,3) DEFAULT 0 NOT NULL
        CHECK (
            (discount_rate >= 0)
            AND
            (discount_rate < 1)
        ),
    line_total DECIMAL(10,2) NOT NULL
        CHECK (
            (line_total > 0) AND
            (line_total = (unit_price * quantity))),

    CONSTRAINT order_items_order_id_fkey
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT order_items_product_id_fkey
        FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- payments
CREATE TABLE payments (
    payment_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    payment_datetime TIMESTAMP NOT NULL,
    method VARCHAR(50) NOT NULL
        CHECK (method IN ('card', 'transfer', 'cash', 'wallet')),
    payment_status VARCHAR(50) NOT NULL
        CHECK (payment_status IN ('rejected', 'pending', 'approved', 'refunded')),
    amount DECIMAL (10,2) NOT NULL
        CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL
        CHECK (currency ~ '^[A-Z]{3}$'),

    CONSTRAINT payments_order_id_fkey
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- order_status_history
CREATE TABLE order_status_history (
    status_history_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    status VARCHAR(50) NOT NULL
        CHECK (status IN ('cancelled', 'created', 'delivered',
                'paid', 'shipped', 'packed', 'refunded')),
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by VARCHAR(50) NOT NULL
        CHECK (changed_by IN ('user', 'payment_gateway', 'ops', 'system', 'warehouse')),
    reason VARCHAR(50) NULL
    CHECK(
        (status NOT IN ('cancelled', 'refunded') AND reason IS NULL) OR
        (status IN ('cancelled', 'refunded') AND
        reason IN ( 'chargeback', 'customer_request', 'fraud_check',
            'out_of_stock', 'payment_failed', 'return', 'service_issue'))
    ),

    CONSTRAINT order_status_history_order_id_fkey
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- order_audit
CREATE TABLE order_audit (
    audit_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    field_name VARCHAR(50) NOT NULL,
    CHECK (
        field_name IN ('current_status', 'customer_phone',
            'notes', 'order_total', 'shipping_address')
    ),
    old_value VARCHAR(6) NOT NULL
        CHECK ( old_value ~ '^[A-Z0-9]{6}$'),
    new_value VARCHAR(6) NOT NULL
        CHECK ( new_value ~ '^[A-Z0-9]{6}$'),
    changed_at TIMESTAMP NOT NULL,
    changed_by VARCHAR(50) NOT NULL
        CHECK (changed_by IN ('system', 'support', 'ops')),

    CONSTRAINT order_audit_order_id_fkey
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- ordenes-fk
CREATE INDEX orders_customer_id_idx ON core.orders(customer_id);
-- order_items-fk
CREATE INDEX order_items_order_id_idx ON core.order_items(order_id);
CREATE INDEX order_items_product_id_idx ON core.order_items(product_id);
-- payments-fk
CREATE INDEX payments_order_id_idx ON core.payments(order_id);
-- order_status-fk
CREATE INDEX order_status_history_order_id_idx ON core.order_status_history(order_id);
-- audit-fk
CREATE INDEX order_audit_order_id_idx ON core.order_audit(order_id);

-- indices para consultas
CREATE INDEX orders_datetime_idx ON core.orders(order_datetime);
CREATE INDEX order_status_history_changed_at_idx ON core.order_status_history(changed_at);
CREATE INDEX orders_status_idx ON core.orders(current_status);
CREATE INDEX payments_status_idx ON core.payments(payment_status);
