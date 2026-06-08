-- habilitar tipo de datos citext
CREATE EXTENSION IF NOT EXISTS citext;

-- customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email CITEXT NOT NULL,
    phone VARCHAR(13) NOT NULL,
    city VARCHAR(50) NOT NULL,
    segment VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_customers_email
    UNIQUE (email),
    CONSTRAINT chk_customers_email_format
    CHECK (email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]+$' ),
    CONSTRAINT chk_customers_segment
    CHECK (segment IN ('retail', 'wholesale', 'online_only', 'vip')),
    CONSTRAINT uq_customers_phone
    UNIQUE (phone),
    CONSTRAINT chk_customers_phone_format
    CHECK (phone ~ '^\+5959[0-9]{8}$'),
    CONSTRAINT chk_customers_deleted_at
    CHECK (
        (is_active = TRUE AND deleted_at IS NULL)
        OR
        (is_active = FALSE AND deleted_at IS NOT NULL)
    )
);

-- products
CREATE TABLE IF NOT EXISTS products(
    product_id INT PRIMARY KEY,
    sku VARCHAR(14) NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_products_sku
    UNIQUE (sku),
    CONSTRAINT chk_products_sku_format
    CHECK (sku ~'^SKU-[A-Z0-9]{10}$'),
    CONSTRAINT chk_products_brand_format
    CHECK (brand ~ '^[A-Z][a-zA-Z]*$'),
    CONSTRAINT chk_products_category_format
    CHECK (category ~'^[a-z]+$'),
    CONSTRAINT chk_products_name_format
    CHECK (product_name ~ '^[A-Z][a-zA-Z]* [a-z]+ [A-Z0-9]+$'),
    CONSTRAINT chk_products_unit_price_positive
    CHECK (unit_price > 0),
    CONSTRAINT chk_products_unit_cost_positive
    CHECK (unit_cost > 0),
    CONSTRAINT chk_products_deleted_at
    CHECK (
        (deleted_at IS NULL AND is_active = TRUE)
        OR
        (deleted_at IS NOT NULL AND is_active = FALSE)
    )
);

-- orders
CREATE TABLE IF NOT EXISTS orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_datetime TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    channel VARCHAR(50) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    current_status VARCHAR(50) NOT NULL,
    order_total DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_orders_channel
    CHECK (channel IN ('mobile', 'web', 'store', 'phone')),
    CONSTRAINT chk_orders_currency
    CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_orders_current_status
    CHECK (
        current_status IN (
            'created',
            'paid',
            'packed',
            'shipped',
            'delivered',
            'cancelled',
            'refunded'
        )
    ),
    CONSTRAINT chk_orders_order_total_positive
    CHECK (order_total >= 0),
    CONSTRAINT chk_orders_deleted_at
    CHECK (
        (is_active = TRUE AND deleted_at IS NULL)
        OR
        (is_active = FALSE AND deleted_at IS NOT NULL)
    )
);

-- order_items
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL (10,2) NOT NULL,
    discount_rate DECIMAL(4,3) DEFAULT 0 NOT NULL,
    line_total DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_order_items_order_id
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product_id
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT chk_order_items_quantity
    CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price
    CHECK (unit_price > 0),
    CONSTRAINT chk_order_items_discount_rate
    CHECK (
        (discount_rate >= 0)
        AND
        (discount_rate < 1)
    ),
    CONSTRAINT chk_order_items_line_total
    CHECK (
        (line_total = (unit_price * quantity))
        AND
        (line_total > 0)
    )
);

-- payments
CREATE TABLE IF NOT EXISTS payments (
    payment_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    payment_datetime TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    method VARCHAR(50) NOT NULL,
    payment_status VARCHAR(50) NOT NULL,
    amount DECIMAL (10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,

    CONSTRAINT fk_payments_order_id
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_payments_method
    CHECK (method IN ('card', 'transfer', 'cash', 'wallet')),
    CONSTRAINT chk_payments_payment_status
    CHECK (payment_status IN ('rejected', 'pending', 'approved', 'refunded')),
    CONSTRAINT chk_payments_amount
    CHECK (amount > 0),
    CONSTRAINT chk_payments_currency_format
    CHECK (currency ~ '^[A-Z]{3}$')
);

-- order_status_history
CREATE TABLE IF NOT EXISTS order_status_history (
    status_history_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    status VARCHAR(50) NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by VARCHAR(50) NOT NULL,
    reason VARCHAR(50) NULL,

    CONSTRAINT fk_order_status_history_order_id
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_order_status_history_status
    CHECK (status IN ('cancelled', 'delivered', 'paid', 'shipped', 'packed', 'refunded')),
    CONSTRAINT chk_order_status_history_changed_by
    CHECK (changed_by IN ('user', 'payment_gateway', 'ops', 'system', 'warehouse')),
    CONSTRAINT chk_order_status_history_reason
    CHECK(
        (status NOT IN ('cancelled', 'refunded') AND reason IS NULL)
        OR
        (status IN ('cancelled', 'refunded') AND
        reason IN ( 'chargeback', 'customer_request', 'fraud_check',
            'out_of_stock', 'payment_failed', 'return', 'service_issue')
        )
    )
);

-- order_audit
CREATE TABLE IF NOT EXISTS order_audit (
    audit_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    field_name VARCHAR(50) NOT NULL,
    old_value VARCHAR(6) NOT NULL,
    new_value VARCHAR(6) NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by VARCHAR(50) NOT NULL,

    CONSTRAINT fk_order_audit_order_id
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_order_audit_field_name
    CHECK (
        field_name IN (
            'current_status',
            'customer_phone',
            'notes',
            'order_total',
            'shipping_address'
        )
    ),
    CONSTRAINT chk_order_audit_old_value
    CHECK ( old_value ~ '^[A-Z0-9]{4,6}$'),
    CONSTRAINT chk_order_audit_new_value
    CHECK ( new_value ~ '^[A-Z0-9]{5,6}$'),
    CONSTRAINT chk_order_audit_changed_by
    CHECK (changed_by IN ('system', 'support', 'ops'))
);
