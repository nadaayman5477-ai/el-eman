-- AL-EMAN ERP LOGIC UPGRADE V3
-- Purpose: Adds strict ERP logic for orders, stock deduction, invoices, payments, contracts, and audit trail.
-- Run after the base setup. Safe to re-run where possible.

create extension if not exists "uuid-ossp";

-- =========================
-- CORE ENUM-LIKE CHECKS
-- =========================

alter table orders drop constraint if exists orders_status_check;
alter table orders add constraint orders_status_check
check (status in ('draft','pending','approved','prepared','out_for_delivery','delivered','cancelled','returned'));

alter table invoices drop constraint if exists invoices_status_check;
alter table invoices add constraint invoices_status_check
check (status in ('draft','issued','partially_paid','paid','overdue','cancelled'));

-- =========================
-- CUSTOMERS: better accounting fields
-- =========================

alter table customers add column if not exists contact_person text;
alter table customers add column if not exists commercial_register text;
alter table customers add column if not exists payment_terms_days int default 0;
alter table customers add column if not exists customer_type text default 'restaurant';
alter table customers add column if not exists notes text;

-- =========================
-- PRODUCTS: strict pricing/stock fields
-- =========================

alter table products add column if not exists sku text;
alter table products add column if not exists default_warehouse_id uuid references warehouses(id);
alter table products add column if not exists min_sale_qty numeric(12,3) default 0;
alter table products add column if not exists tax_rate numeric(5,2) default 0;
alter table products add column if not exists description text;
alter table products add column if not exists image_url text;

-- =========================
-- WAREHOUSE BATCHES / LOTS
-- Frozen/fresh fish often needs batch, expiry, supplier, cost.
-- =========================

create table if not exists suppliers (
  id uuid primary key default uuid_generate_v4(),
  supplier_name text not null,
  phone text,
  email text,
  address text,
  balance numeric(12,2) default 0,
  status text default 'active',
  created_at timestamptz default now()
);

create table if not exists stock_batches (
  id uuid primary key default uuid_generate_v4(),
  warehouse_id uuid references warehouses(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  supplier_id uuid references suppliers(id),
  batch_code text,
  production_date date,
  expiry_date date,
  quantity numeric(12,3) not null default 0,
  cost_price numeric(12,2) default 0,
  notes text,
  created_at timestamptz default now()
);

alter table stock_movements add column if not exists batch_id uuid references stock_batches(id);
alter table stock_movements add column if not exists unit_cost numeric(12,2) default 0;
alter table stock_movements add column if not exists before_qty numeric(12,3);
alter table stock_movements add column if not exists after_qty numeric(12,3);

-- =========================
-- ORDERS: stronger fields
-- =========================

alter table orders add column if not exists warehouse_id uuid references warehouses(id);
alter table orders add column if not exists approved_by uuid references employees(id);
alter table orders add column if not exists approved_at timestamptz;
alter table orders add column if not exists cancelled_reason text;
alter table orders add column if not exists delivery_fee numeric(12,2) default 0;
alter table orders add column if not exists paid_status text default 'unpaid';
alter table orders add column if not exists payment_method text;
alter table orders add column if not exists created_by uuid references employees(id);

alter table order_items add column if not exists warehouse_id uuid references warehouses(id);
alter table order_items add column if not exists batch_id uuid references stock_batches(id);
alter table order_items add column if not exists discount numeric(12,2) default 0;
alter table order_items add column if not exists tax numeric(12,2) default 0;
alter table order_items add column if not exists net_total numeric(12,2) default 0;
alter table order_items add column if not exists notes text;

-- Prevent impossible quantities/prices
alter table order_items drop constraint if exists order_items_quantity_positive;
alter table order_items add constraint order_items_quantity_positive check (quantity > 0);
alter table order_items drop constraint if exists order_items_price_nonnegative;
alter table order_items add constraint order_items_price_nonnegative check (unit_price >= 0);

-- =========================
-- INVOICE: formal printing fields
-- =========================

alter table invoices add column if not exists invoice_type text default 'tax_invoice';
alter table invoices add column if not exists serial_prefix text default 'INV';
alter table invoices add column if not exists seller_name text default 'شركة الإيمان لتوريد الأسماك الطازجة والمجمدة';
alter table invoices add column if not exists seller_phone text default '01005630229';
alter table invoices add column if not exists seller_email text default 'dinasalem531@gmail.com';
alter table invoices add column if not exists seller_address text;
alter table invoices add column if not exists terms text default 'البضاعة المباعة لا ترد ولا تستبدل إلا في حالة وجود عيب مثبت عند الاستلام.';
alter table invoices add column if not exists printed_at timestamptz;
alter table invoices add column if not exists issued_by uuid references employees(id);

create table if not exists invoice_items (
  id uuid primary key default uuid_generate_v4(),
  invoice_id uuid references invoices(id) on delete cascade,
  order_item_id uuid references order_items(id),
  product_id uuid references products(id),
  product_name text not null,
  quantity numeric(12,3) not null,
  unit text default 'kg',
  unit_price numeric(12,2) not null,
  discount numeric(12,2) default 0,
  tax numeric(12,2) default 0,
  total numeric(12,2) not null,
  created_at timestamptz default now()
);

-- =========================
-- CONTRACT: formal clauses/items
-- =========================

alter table contracts add column if not exists contract_party_name text;
alter table contracts add column if not exists contract_party_representative text;
alter table contracts add column if not exists payment_terms text;
alter table contracts add column if not exists delivery_terms text;
alter table contracts add column if not exists quality_terms text;
alter table contracts add column if not exists cancellation_terms text;
alter table contracts add column if not exists signed_by_company uuid references employees(id);
alter table contracts add column if not exists signed_at timestamptz;

create table if not exists contract_items (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references contracts(id) on delete cascade,
  product_id uuid references products(id),
  product_name text,
  agreed_price numeric(12,2),
  min_quantity numeric(12,3),
  notes text,
  created_at timestamptz default now()
);

-- =========================
-- AUDIT LOG
-- =========================

create table if not exists audit_logs (
  id uuid primary key default uuid_generate_v4(),
  table_name text not null,
  row_id uuid,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

-- =========================
-- SERIAL NUMBER GENERATOR
-- =========================

create table if not exists serial_counters (
  counter_key text primary key,
  current_value int not null default 0,
  updated_at timestamptz default now()
);

create or replace function next_serial(p_key text, p_prefix text)
returns text as $$
declare
  v_next int;
begin
  insert into serial_counters(counter_key, current_value)
  values (p_key, 0)
  on conflict (counter_key) do nothing;

  update serial_counters
  set current_value = current_value + 1,
      updated_at = now()
  where counter_key = p_key
  returning current_value into v_next;

  return p_prefix || '-' || to_char(current_date, 'YYYYMM') || '-' || lpad(v_next::text, 5, '0');
end;
$$ language plpgsql;

-- =========================
-- STOCK HELPERS
-- =========================

create or replace function get_stock_qty(p_warehouse_id uuid, p_product_id uuid)
returns numeric as $$
declare
  v_qty numeric(12,3);
begin
  select coalesce(quantity,0) into v_qty
  from stock
  where warehouse_id = p_warehouse_id and product_id = p_product_id;
  return coalesce(v_qty, 0);
end;
$$ language plpgsql;

create or replace function adjust_stock(
  p_warehouse_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_movement_type text,
  p_reference_type text,
  p_reference_id uuid,
  p_created_by uuid default null,
  p_notes text default null,
  p_batch_id uuid default null
)
returns void as $$
declare
  v_before numeric(12,3);
  v_after numeric(12,3);
begin
  if p_quantity = 0 then
    raise exception 'Stock quantity cannot be zero';
  end if;

  insert into stock(warehouse_id, product_id, quantity, min_quantity)
  values (p_warehouse_id, p_product_id, 0, 0)
  on conflict (warehouse_id, product_id) do nothing;

  select quantity into v_before
  from stock
  where warehouse_id = p_warehouse_id and product_id = p_product_id
  for update;

  v_after := v_before + p_quantity;

  if v_after < 0 then
    raise exception 'Insufficient stock. Product %, warehouse %, available %, requested %', p_product_id, p_warehouse_id, v_before, abs(p_quantity);
  end if;

  update stock
  set quantity = v_after,
      updated_at = now()
  where warehouse_id = p_warehouse_id and product_id = p_product_id;

  insert into stock_movements(
    warehouse_id, product_id, batch_id, movement_type, quantity,
    reference_type, reference_id, notes, created_by, before_qty, after_qty
  ) values (
    p_warehouse_id, p_product_id, p_batch_id, p_movement_type, p_quantity,
    p_reference_type, p_reference_id, p_notes, p_created_by, v_before, v_after
  );
end;
$$ language plpgsql;

-- =========================
-- ORDER TOTALS TRIGGER
-- =========================

create or replace function recalc_order_totals(p_order_id uuid)
returns void as $$
declare
  v_subtotal numeric(12,2);
  v_discount numeric(12,2);
  v_tax numeric(12,2);
  v_delivery_fee numeric(12,2);
begin
  select
    coalesce(sum(quantity * unit_price),0),
    coalesce(sum(discount),0),
    coalesce(sum(tax),0)
  into v_subtotal, v_discount, v_tax
  from order_items
  where order_id = p_order_id;

  select coalesce(delivery_fee,0) into v_delivery_fee from orders where id = p_order_id;

  update orders
  set subtotal = v_subtotal,
      discount = v_discount,
      tax = v_tax,
      total = v_subtotal - v_discount + v_tax + coalesce(v_delivery_fee,0)
  where id = p_order_id;
end;
$$ language plpgsql;

create or replace function order_items_before_save()
returns trigger as $$
begin
  new.total := round((new.quantity * new.unit_price)::numeric, 2);
  new.net_total := round((new.total - coalesce(new.discount,0) + coalesce(new.tax,0))::numeric, 2);
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_order_items_before_save on order_items;
create trigger trg_order_items_before_save
before insert or update on order_items
for each row execute function order_items_before_save();

create or replace function order_items_after_change()
returns trigger as $$
begin
  if tg_op = 'DELETE' then
    perform recalc_order_totals(old.order_id);
    return old;
  else
    perform recalc_order_totals(new.order_id);
    return new;
  end if;
end;
$$ language plpgsql;

drop trigger if exists trg_order_items_after_change on order_items;
create trigger trg_order_items_after_change
after insert or update or delete on order_items
for each row execute function order_items_after_change();

-- =========================
-- ORDER APPROVAL: deduct stock strictly
-- =========================

create or replace function approve_order(p_order_id uuid, p_approved_by uuid default null)
returns void as $$
declare
  v_order record;
  item record;
  v_warehouse uuid;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;

  if v_order.status not in ('draft','pending') then
    raise exception 'Only draft/pending orders can be approved. Current status: %', v_order.status;
  end if;

  if not exists (select 1 from order_items where order_id = p_order_id) then
    raise exception 'Order has no items';
  end if;

  for item in select * from order_items where order_id = p_order_id loop
    v_warehouse := coalesce(item.warehouse_id, v_order.warehouse_id);
    if v_warehouse is null then
      raise exception 'Warehouse is required for product %', item.product_id;
    end if;

    perform adjust_stock(
      v_warehouse,
      item.product_id,
      -item.quantity,
      'sale_out',
      'order',
      p_order_id,
      p_approved_by,
      'خصم تلقائي بعد اعتماد الطلب',
      item.batch_id
    );
  end loop;

  update orders
  set status = 'approved',
      approved_by = p_approved_by,
      approved_at = now()
  where id = p_order_id;
end;
$$ language plpgsql;

-- =========================
-- CANCEL APPROVED ORDER: return stock
-- =========================

create or replace function cancel_order(p_order_id uuid, p_reason text default null, p_cancelled_by uuid default null)
returns void as $$
declare
  v_order record;
  item record;
  v_warehouse uuid;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;

  if v_order.status in ('cancelled','returned') then
    raise exception 'Order already cancelled/returned';
  end if;

  if v_order.status in ('approved','prepared','out_for_delivery') then
    for item in select * from order_items where order_id = p_order_id loop
      v_warehouse := coalesce(item.warehouse_id, v_order.warehouse_id);
      perform adjust_stock(
        v_warehouse,
        item.product_id,
        item.quantity,
        'sale_cancel_return',
        'order',
        p_order_id,
        p_cancelled_by,
        'رد مخزون بعد إلغاء الطلب: ' || coalesce(p_reason,''),
        item.batch_id
      );
    end loop;
  end if;

  update orders
  set status = 'cancelled',
      cancelled_reason = p_reason
  where id = p_order_id;
end;
$$ language plpgsql;

-- =========================
-- GENERATE INVOICE FROM ORDER
-- =========================

create or replace function generate_invoice_from_order(p_order_id uuid, p_issued_by uuid default null)
returns uuid as $$
declare
  v_order record;
  v_invoice_id uuid;
  item record;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;

  if v_order.status not in ('approved','prepared','out_for_delivery','delivered') then
    raise exception 'Invoice can only be issued for approved/prepared/out_for_delivery/delivered orders';
  end if;

  if exists (select 1 from invoices where order_id = p_order_id and status <> 'cancelled') then
    select id into v_invoice_id from invoices where order_id = p_order_id and status <> 'cancelled' limit 1;
    return v_invoice_id;
  end if;

  insert into invoices(
    invoice_number, order_id, customer_id, invoice_date, due_date,
    subtotal, discount, tax, total, paid_amount, remaining_amount, status, issued_by
  ) values (
    next_serial('invoice', 'INV'), p_order_id, v_order.customer_id, current_date,
    current_date + interval '7 days',
    v_order.subtotal, v_order.discount, v_order.tax, v_order.total, 0, v_order.total, 'issued', p_issued_by
  ) returning id into v_invoice_id;

  for item in
    select oi.*, p.product_name, p.unit
    from order_items oi
    join products p on p.id = oi.product_id
    where oi.order_id = p_order_id
  loop
    insert into invoice_items(
      invoice_id, order_item_id, product_id, product_name, quantity, unit,
      unit_price, discount, tax, total
    ) values (
      v_invoice_id, item.id, item.product_id, item.product_name, item.quantity, item.unit,
      item.unit_price, item.discount, item.tax, item.net_total
    );
  end loop;

  update customers
  set balance = coalesce(balance,0) + v_order.total
  where id = v_order.customer_id;

  return v_invoice_id;
end;
$$ language plpgsql;

-- =========================
-- REGISTER PAYMENT: updates invoice/customer balance
-- =========================

create or replace function register_invoice_payment(
  p_invoice_id uuid,
  p_amount numeric,
  p_payment_method text default 'cash',
  p_created_by uuid default null,
  p_notes text default null
)
returns void as $$
declare
  v_invoice record;
  v_remaining numeric(12,2);
begin
  if p_amount <= 0 then
    raise exception 'Payment amount must be positive';
  end if;

  select * into v_invoice from invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.status in ('cancelled','paid') then
    raise exception 'Cannot pay invoice with status %', v_invoice.status;
  end if;

  if p_amount > v_invoice.remaining_amount then
    raise exception 'Payment amount exceeds remaining amount';
  end if;

  insert into payments(customer_id, invoice_id, amount, payment_method, payment_date, notes, created_by)
  values (v_invoice.customer_id, p_invoice_id, p_amount, p_payment_method, current_date, p_notes, p_created_by);

  v_remaining := v_invoice.remaining_amount - p_amount;

  update invoices
  set paid_amount = paid_amount + p_amount,
      remaining_amount = v_remaining,
      status = case when v_remaining = 0 then 'paid' else 'partially_paid' end
  where id = p_invoice_id;

  update customers
  set balance = coalesce(balance,0) - p_amount
  where id = v_invoice.customer_id;

  insert into treasury_transactions(transaction_type, amount, source, reference_id, notes, created_by)
  values ('income', p_amount, 'invoice_payment', p_invoice_id, p_notes, p_created_by);
end;
$$ language plpgsql;

-- =========================
-- STOCK PURCHASE RECEIPT
-- =========================

create table if not exists purchase_orders (
  id uuid primary key default uuid_generate_v4(),
  purchase_number text unique not null default next_serial('purchase','PO'),
  supplier_id uuid references suppliers(id),
  warehouse_id uuid references warehouses(id),
  purchase_date date default current_date,
  status text default 'draft',
  subtotal numeric(12,2) default 0,
  total numeric(12,2) default 0,
  notes text,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

create table if not exists purchase_items (
  id uuid primary key default uuid_generate_v4(),
  purchase_order_id uuid references purchase_orders(id) on delete cascade,
  product_id uuid references products(id),
  quantity numeric(12,3) not null,
  unit_cost numeric(12,2) not null,
  total numeric(12,2) generated always as (quantity * unit_cost) stored,
  batch_code text,
  expiry_date date,
  created_at timestamptz default now()
);

create or replace function approve_purchase_order(p_purchase_order_id uuid, p_approved_by uuid default null)
returns void as $$
declare
  v_po record;
  item record;
  v_batch_id uuid;
begin
  select * into v_po from purchase_orders where id = p_purchase_order_id for update;
  if not found then raise exception 'Purchase order not found'; end if;
  if v_po.status <> 'draft' then raise exception 'Only draft purchase orders can be approved'; end if;

  for item in select * from purchase_items where purchase_order_id = p_purchase_order_id loop
    insert into stock_batches(warehouse_id, product_id, supplier_id, batch_code, expiry_date, quantity, cost_price)
    values(v_po.warehouse_id, item.product_id, v_po.supplier_id, item.batch_code, item.expiry_date, item.quantity, item.unit_cost)
    returning id into v_batch_id;

    perform adjust_stock(v_po.warehouse_id, item.product_id, item.quantity, 'purchase_in', 'purchase_order', p_purchase_order_id, p_approved_by, 'إضافة مخزون من أمر شراء', v_batch_id);
  end loop;

  update purchase_orders
  set status = 'approved',
      subtotal = (select coalesce(sum(total),0) from purchase_items where purchase_order_id = p_purchase_order_id),
      total = (select coalesce(sum(total),0) from purchase_items where purchase_order_id = p_purchase_order_id)
  where id = p_purchase_order_id;
end;
$$ language plpgsql;

-- =========================
-- PRINT VIEWS
-- Frontend can use these for strict invoice/contract printing.
-- =========================

create or replace view v_invoice_print as
select
  i.id as invoice_id,
  i.invoice_number,
  i.invoice_date,
  i.due_date,
  i.status,
  i.seller_name,
  i.seller_phone,
  i.seller_email,
  i.seller_address,
  i.terms,
  c.customer_name,
  c.company_name,
  c.phone as customer_phone,
  c.address as customer_address,
  c.tax_number,
  o.order_number,
  o.delivery_date,
  i.subtotal,
  i.discount,
  i.tax,
  i.total,
  i.paid_amount,
  i.remaining_amount
from invoices i
left join customers c on c.id = i.customer_id
left join orders o on o.id = i.order_id;

create or replace view v_invoice_items_print as
select
  ii.invoice_id,
  ii.product_name,
  ii.quantity,
  ii.unit,
  ii.unit_price,
  ii.discount,
  ii.tax,
  ii.total
from invoice_items ii;

create or replace view v_stock_alerts as
select
  s.id,
  w.warehouse_name,
  p.product_name,
  s.quantity,
  s.min_quantity,
  case when s.quantity <= s.min_quantity then true else false end as is_low_stock
from stock s
join warehouses w on w.id = s.warehouse_id
join products p on p.id = s.product_id;

-- =========================
-- REALTIME ADDITIONS
-- ignore duplicate publication errors by wrapping in DO blocks
-- =========================

do $$ begin alter publication supabase_realtime add table suppliers; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table stock_batches; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table invoice_items; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table contract_items; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table audit_logs; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table purchase_orders; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table purchase_items; exception when duplicate_object then null; end $$;

-- =========================
-- DEMO POLICIES FOR NEW TABLES
-- For production, replace with role-based auth policies.
-- =========================

alter table suppliers enable row level security;
alter table stock_batches enable row level security;
alter table invoice_items enable row level security;
alter table contract_items enable row level security;
alter table audit_logs enable row level security;
alter table purchase_orders enable row level security;
alter table purchase_items enable row level security;

drop policy if exists demo_all_suppliers on suppliers;
create policy demo_all_suppliers on suppliers for all using (true) with check (true);
drop policy if exists demo_all_stock_batches on stock_batches;
create policy demo_all_stock_batches on stock_batches for all using (true) with check (true);
drop policy if exists demo_all_invoice_items on invoice_items;
create policy demo_all_invoice_items on invoice_items for all using (true) with check (true);
drop policy if exists demo_all_contract_items on contract_items;
create policy demo_all_contract_items on contract_items for all using (true) with check (true);
drop policy if exists demo_all_audit_logs on audit_logs;
create policy demo_all_audit_logs on audit_logs for all using (true) with check (true);
drop policy if exists demo_all_purchase_orders on purchase_orders;
create policy demo_all_purchase_orders on purchase_orders for all using (true) with check (true);
drop policy if exists demo_all_purchase_items on purchase_items;
create policy demo_all_purchase_items on purchase_items for all using (true) with check (true);

-- =========================
-- Recommended frontend flow:
-- 1. Create order as draft.
-- 2. Add order_items with product_id, quantity, unit_price, warehouse_id.
-- 3. Call: select approve_order('<order_id>', '<employee_id>');
-- 4. Call: select generate_invoice_from_order('<order_id>', '<employee_id>');
-- 5. Print invoice using v_invoice_print + v_invoice_items_print.
-- 6. Register payment: select register_invoice_payment('<invoice_id>', amount, 'cash', '<employee_id>', 'notes');
-- =========================
