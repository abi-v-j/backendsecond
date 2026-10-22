-- ==============================================================================
-- DATABASE SCHEMA & STORED PROCEDURES FOR 'postgres_curser'
-- Pure SQL & PostgreSQL Stored Procedures (No ORM)
-- ==============================================================================

-- 1. CUSTOMER MASTER TABLE
CREATE TABLE IF NOT EXISTS customer_master (
    customer_id BIGSERIAL PRIMARY KEY,
    customer_code VARCHAR(20) UNIQUE NOT NULL,
    customer_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. ITEM MASTER TABLE
CREATE TABLE IF NOT EXISTS item_master (
    item_id BIGSERIAL PRIMARY KEY,
    item_code VARCHAR(20) UNIQUE NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    uom VARCHAR(10) DEFAULT 'NOS',
    unit_price NUMERIC(12, 2) DEFAULT 0 CHECK (unit_price >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. SALES HEADER TABLE
CREATE TABLE IF NOT EXISTS sales_header (
    sales_id BIGSERIAL PRIMARY KEY,
    sales_no VARCHAR(20) UNIQUE NOT NULL,
    sales_date DATE NOT NULL,
    customer_id BIGINT NOT NULL REFERENCES customer_master(customer_id),
    total_amount NUMERIC(14, 2) DEFAULT 0 CHECK (total_amount >= 0),
    status VARCHAR(15) DEFAULT 'DRAFT',
    remarks VARCHAR(250),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. SALES DETAILS TABLE
CREATE TABLE IF NOT EXISTS sales_details (
    sales_detail_id BIGSERIAL PRIMARY KEY,
    sales_id BIGINT NOT NULL REFERENCES sales_header(sales_id) ON DELETE CASCADE,
    line_no INT NOT NULL,
    item_id BIGINT NOT NULL REFERENCES item_master(item_id),
    quantity NUMERIC(12, 3) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    line_amount NUMERIC(14, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    CONSTRAINT uq_sales_details_line UNIQUE (sales_id, line_no)
);

-- 5. INVOICE TABLE
CREATE TABLE IF NOT EXISTS invoice (
    invoice_id BIGSERIAL PRIMARY KEY,
    invoice_no VARCHAR(20) UNIQUE NOT NULL,
    invoice_date DATE NOT NULL,
    sales_id BIGINT UNIQUE NOT NULL REFERENCES sales_header(sales_id),
    sub_total NUMERIC(14, 2) DEFAULT 0 CHECK (sub_total >= 0),
    tax_amount NUMERIC(14, 2) DEFAULT 0 CHECK (tax_amount >= 0),
    net_amount NUMERIC(14, 2) GENERATED ALWAYS AS (sub_total + tax_amount) STORED,
    payment_status VARCHAR(10) DEFAULT 'UNPAID',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- STORED PROCEDURES: ITEM MASTER
-- ==============================================================================

-- Insert Item Procedure
CREATE OR REPLACE PROCEDURE sp_insert_item(
    p_item_code VARCHAR,
    p_item_name VARCHAR,
    p_uom VARCHAR,
    p_unit_price NUMERIC,
    INOUT p_item_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO item_master (item_code, item_name, uom, unit_price)
    VALUES (p_item_code, p_item_name, COALESCE(p_uom, 'NOS'), COALESCE(p_unit_price, 0))
    RETURNING item_id INTO p_item_id;
END;
$$;

-- Get All Items Procedure (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_all_items(INOUT p_cursor REFCURSOR)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT item_id, item_code, item_name, uom, unit_price, is_active, created_at
        FROM item_master
        ORDER BY item_id;
END;
$$;

-- Get Item By ID Procedure (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_item_by_id(
    p_item_id BIGINT,
    INOUT p_cursor REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT item_id, item_code, item_name, uom, unit_price, is_active, created_at
        FROM item_master
        WHERE item_id = p_item_id;
END;
$$;

-- Update Item Procedure
CREATE OR REPLACE PROCEDURE sp_update_item(
    p_item_id BIGINT,
    p_item_code VARCHAR,
    p_item_name VARCHAR,
    p_uom VARCHAR,
    p_unit_price NUMERIC,
    p_is_active BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE item_master
    SET item_code = p_item_code,
        item_name = p_item_name,
        uom = COALESCE(p_uom, 'NOS'),
        unit_price = COALESCE(p_unit_price, 0),
        is_active = COALESCE(p_is_active, TRUE)
    WHERE item_id = p_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item with id % does not exist.', p_item_id;
    END IF;
END;
$$;

-- Delete Item Procedure
CREATE OR REPLACE PROCEDURE sp_delete_item(
    p_item_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM item_master
    WHERE item_id = p_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item with id % does not exist.', p_item_id;
    END IF;
END;
$$;

-- ==============================================================================
-- STORED PROCEDURES: CUSTOMER MASTER
-- ==============================================================================

-- Insert Customer Procedure
CREATE OR REPLACE PROCEDURE sp_insert_customer(
    p_customer_code VARCHAR,
    p_customer_name VARCHAR,
    p_phone VARCHAR,
    p_email VARCHAR,
    p_address TEXT,
    INOUT p_customer_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO customer_master (customer_code, customer_name, phone, email, address)
    VALUES (p_customer_code, p_customer_name, p_phone, p_email, p_address)
    RETURNING customer_id INTO p_customer_id;
END;
$$;

-- Get All Customers Procedure (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_all_customers(INOUT p_cursor REFCURSOR)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT customer_id, customer_code, customer_name, phone, email, address, is_active, created_at
        FROM customer_master
        ORDER BY customer_id;
END;
$$;

-- Get Customer By ID Procedure (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_customer_by_id(
    p_customer_id BIGINT,
    INOUT p_cursor REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT customer_id, customer_code, customer_name, phone, email, address, is_active, created_at
        FROM customer_master
        WHERE customer_id = p_customer_id;
END;
$$;

-- Update Customer Procedure
CREATE OR REPLACE PROCEDURE sp_update_customer(
    p_customer_id BIGINT,
    p_customer_code VARCHAR,
    p_customer_name VARCHAR,
    p_phone VARCHAR,
    p_email VARCHAR,
    p_address TEXT,
    p_is_active BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE customer_master
    SET customer_code = p_customer_code,
        customer_name = p_customer_name,
        phone = p_phone,
        email = p_email,
        address = p_address,
        is_active = COALESCE(p_is_active, TRUE)
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer with id % does not exist.', p_customer_id;
    END IF;
END;
$$;

-- Delete Customer Procedure
CREATE OR REPLACE PROCEDURE sp_delete_customer(
    p_customer_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM customer_master
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer with id % does not exist.', p_customer_id;
    END IF;
END;
$$;

-- ==============================================================================
-- STORED PROCEDURES: SALES ORDER & DETAILS
-- ==============================================================================

-- Create Sales Order and Lines Procedure (Atomic Transaction)
CREATE OR REPLACE PROCEDURE sp_create_sales_order(
    p_sales_no VARCHAR,
    p_sales_date DATE,
    p_customer_id BIGINT,
    p_status VARCHAR,
    p_remarks VARCHAR,
    p_lines JSONB,
    INOUT p_sales_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_line RECORD;
    v_line_no INT := 1;
    v_unit_price NUMERIC;
    v_item_price NUMERIC;
    v_total_amount NUMERIC := 0;
BEGIN
    -- Check if customer exists
    IF NOT EXISTS (SELECT 1 FROM customer_master WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer with id % does not exist.', p_customer_id;
    END IF;

    -- Check if sales_no exists
    IF EXISTS (SELECT 1 FROM sales_header WHERE sales_no = p_sales_no) THEN
        RAISE EXCEPTION 'Sales order with sales_no ''%'' already exists.', p_sales_no;
    END IF;

    -- Insert sales header
    INSERT INTO sales_header (sales_no, sales_date, customer_id, status, remarks, total_amount)
    VALUES (p_sales_no, p_sales_date, p_customer_id, COALESCE(p_status, 'DRAFT'), p_remarks, 0)
    RETURNING sales_id INTO p_sales_id;

    -- Insert line items
    FOR v_line IN SELECT * FROM jsonb_to_recordset(p_lines) AS x(item_id BIGINT, quantity NUMERIC, unit_price NUMERIC)
    LOOP
        -- Validate item exists and get price
        SELECT unit_price INTO v_item_price FROM item_master WHERE item_id = v_line.item_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Line %: Item with id % does not exist.', v_line_no, v_line.item_id;
        END IF;

        IF v_line.quantity IS NULL OR v_line.quantity <= 0 THEN
            RAISE EXCEPTION 'Line %: Quantity must be greater than 0.', v_line_no;
        END IF;

        v_unit_price := COALESCE(v_line.unit_price, v_item_price);

        INSERT INTO sales_details (sales_id, line_no, item_id, quantity, unit_price)
        VALUES (p_sales_id, v_line_no, v_line.item_id, v_line.quantity, v_unit_price);

        v_line_no := v_line_no + 1;
    END LOOP;

    -- Compute and update total amount
    SELECT COALESCE(SUM(line_amount), 0) INTO v_total_amount
    FROM sales_details
    WHERE sales_id = p_sales_id;

    UPDATE sales_header
    SET total_amount = v_total_amount
    WHERE sales_id = p_sales_id;
END;
$$;

-- Get All Sales Orders with nested customer and lines (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_all_sales_orders(INOUT p_cursor REFCURSOR)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT 
            sh.sales_id,
            sh.sales_no,
            sh.sales_date,
            sh.total_amount,
            sh.status,
            sh.remarks,
            sh.created_at,
            json_build_object(
                'customer_id', cm.customer_id,
                'customer_code', cm.customer_code,
                'customer_name', cm.customer_name,
                'phone', cm.phone,
                'email', cm.email,
                'address', cm.address
            ) AS customer_details,
            COALESCE(
                (
                    SELECT json_agg(
                        json_build_object(
                            'sales_detail_id', sd.sales_detail_id,
                            'line_no', sd.line_no,
                            'item_id', sd.item_id,
                            'quantity', sd.quantity,
                            'unit_price', sd.unit_price,
                            'line_amount', sd.line_amount,
                            'item_details', json_build_object(
                                'item_id', im.item_id,
                                'item_code', im.item_code,
                                'item_name', im.item_name,
                                'uom', im.uom,
                                'unit_price', im.unit_price
                            )
                        ) ORDER BY sd.line_no
                    )
                    FROM sales_details sd
                    JOIN item_master im ON im.item_id = sd.item_id
                    WHERE sd.sales_id = sh.sales_id
                ),
                '[]'::json
            ) AS lines
        FROM sales_header sh
        JOIN customer_master cm ON cm.customer_id = sh.customer_id
        ORDER BY sh.sales_id DESC;
END;
$$;

-- Get Sales Order By ID with nested customer and lines (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_sales_order_by_id(
    p_sales_id BIGINT,
    INOUT p_cursor REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT 
            sh.sales_id,
            sh.sales_no,
            sh.sales_date,
            sh.total_amount,
            sh.status,
            sh.remarks,
            sh.created_at,
            json_build_object(
                'customer_id', cm.customer_id,
                'customer_code', cm.customer_code,
                'customer_name', cm.customer_name,
                'phone', cm.phone,
                'email', cm.email,
                'address', cm.address
            ) AS customer_details,
            COALESCE(
                (
                    SELECT json_agg(
                        json_build_object(
                            'sales_detail_id', sd.sales_detail_id,
                            'line_no', sd.line_no,
                            'item_id', sd.item_id,
                            'quantity', sd.quantity,
                            'unit_price', sd.unit_price,
                            'line_amount', sd.line_amount,
                            'item_details', json_build_object(
                                'item_id', im.item_id,
                                'item_code', im.item_code,
                                'item_name', im.item_name,
                                'uom', im.uom,
                                'unit_price', im.unit_price
                            )
                        ) ORDER BY sd.line_no
                    )
                    FROM sales_details sd
                    JOIN item_master im ON im.item_id = sd.item_id
                    WHERE sd.sales_id = sh.sales_id
                ),
                '[]'::json
            ) AS lines
        FROM sales_header sh
        JOIN customer_master cm ON cm.customer_id = sh.customer_id
        WHERE sh.sales_id = p_sales_id;
END;
$$;

-- ==============================================================================
-- STORED PROCEDURES: INVOICE
-- ==============================================================================

-- Create Invoice from Sales Order Procedure
CREATE OR REPLACE PROCEDURE sp_create_invoice(
    p_sales_id BIGINT,
    p_invoice_no VARCHAR,
    p_invoice_date DATE,
    p_tax_rate NUMERIC DEFAULT 0.05,
    p_payment_status VARCHAR DEFAULT 'UNPAID',
    INOUT p_invoice_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sub_total NUMERIC;
    v_tax_amount NUMERIC;
BEGIN
    SELECT total_amount INTO v_sub_total FROM sales_header WHERE sales_id = p_sales_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sales order with id % does not exist.', p_sales_id;
    END IF;

    IF EXISTS (SELECT 1 FROM invoice WHERE sales_id = p_sales_id) THEN
        RAISE EXCEPTION 'Invoice for sales order id % already exists.', p_sales_id;
    END IF;

    v_tax_amount := ROUND(v_sub_total * COALESCE(p_tax_rate, 0.05), 2);

    INSERT INTO invoice (invoice_no, invoice_date, sales_id, sub_total, tax_amount, payment_status)
    VALUES (p_invoice_no, p_invoice_date, p_sales_id, v_sub_total, v_tax_amount, COALESCE(p_payment_status, 'UNPAID'))
    RETURNING invoice_id INTO p_invoice_id;

    UPDATE sales_header SET status = 'INVOICED' WHERE sales_id = p_sales_id;
END;
$$;

-- Get All Invoices Procedure (using REFCURSOR)
CREATE OR REPLACE PROCEDURE sp_get_all_invoices(INOUT p_cursor REFCURSOR)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_cursor FOR
        SELECT 
            i.invoice_id,
            i.invoice_no,
            i.invoice_date,
            i.sales_id,
            i.sub_total,
            i.tax_amount,
            i.net_amount,
            i.payment_status,
            i.created_at,
            sh.sales_no,
            cm.customer_name
        FROM invoice i
        JOIN sales_header sh ON sh.sales_id = i.sales_id
        JOIN customer_master cm ON cm.customer_id = sh.customer_id
        ORDER BY i.invoice_id DESC;
END;
$$;
