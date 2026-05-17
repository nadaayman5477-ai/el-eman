-- =========================================================
-- AL-EMAN ERP - SUPABASE FULL SETUP
-- شركة الإيمان لتوريد الأسماك الطازجة والمجمدة
-- Run in: Supabase Dashboard > SQL Editor > New Query > Run
-- =========================================================

-- =========================
-- 0) EXTENSIONS
-- =========================
create extension if not exists "uuid-ossp";

-- =========================
-- 1) CLEAN OLD TABLES
-- استخدم هذا الملف للتأسيس من الصفر
-- =========================
drop table if exists audit_logs cascade;
drop table if exists notifications cascade;
drop table if exists contract_items cascade;
drop table if exists contracts cascade;
drop table if exists treasury_transactions cascade;
drop table if exists expenses cascade;
drop table if exists payments cascade;
drop table if exists invoice_items cascade;
drop table if exists invoices cascade;
drop table if exists deliveries cascade;
drop table if exists order_items cascade;
drop table if exists orders cascade;
drop table if exists stock_movements cascade;
drop table if exists stock cascade;
drop table if exists warehouses cascade;
drop table if exists price_history cascade;
drop table if exists products cascade;
drop table if exists product_categories cascade;
drop table if exists customer_complaints cascade;
drop table if exists customer_contacts cascade;
drop table if exists customer_addresses cascade;
drop table if exists customers cascade;
drop table if exists payroll cascade;
drop table if exists salary_bonuses cascade;
drop table if exists salary_deductions cascade;
drop table if exists attendance cascade;
drop table if exists leaves cascade;
drop table if exists employee_accounts cascade;
drop table if exists employees cascade;
drop table if exists roles cascade;

-- =========================
-- 2) ROLES / EMPLOYEES / AUTH PROFILE
-- =========================
create table roles (
  id uuid primary key default uuid_generate_v4(),
  role_key text unique not null,
  role_name_ar text not null,
  permissions jsonb default '{}',
  created_at timestamptz default now()
);

create table employees (
  id uuid primary key default uuid_generate_v4(),
  auth_user_id uuid unique,
  full_name text not null,
  username text unique not null,
  email text unique,
  phone text,
  national_id text,
  address text,
  role_id uuid references roles(id),
  job_title text,
  department text,
  base_salary numeric(12,2) default 0,
  allowance numeric(12,2) default 0,
  commission_rate numeric(5,2) default 0,
  hire_date date default current_date,
  status text default 'active' check (status in ('active','inactive','suspended','left')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table employee_accounts (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id) on delete cascade,
  login_email text unique,
  demo_password text,
  is_active boolean default true,
  last_login timestamptz,
  created_at timestamptz default now()
);

-- =========================
-- 3) HR
-- =========================
create table attendance (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id) on delete cascade,
  attendance_date date not null default current_date,
  check_in time,
  check_out time,
  status text default 'present' check (status in ('present','absent','late','half_day','vacation','sick_leave')),
  late_minutes int default 0,
  overtime_minutes int default 0,
  notes text,
  created_at timestamptz default now(),
  unique(employee_id, attendance_date)
);

create table leaves (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id) on delete cascade,
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  status text default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid references employees(id),
  reason text,
  created_at timestamptz default now()
);

create table salary_deductions (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id) on delete cascade,
  amount numeric(12,2) not null,
  reason text,
  deduction_date date default current_date,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

create table salary_bonuses (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id) on delete cascade,
  amount numeric(12,2) not null,
  reason text,
  bonus_date date default current_date,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

create table payroll (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id),
  payroll_month int not null check (payroll_month between 1 and 12),
  payroll_year int not null,
  base_salary numeric(12,2) default 0,
  allowance numeric(12,2) default 0,
  bonuses numeric(12,2) default 0,
  deductions numeric(12,2) default 0,
  absences_deduction numeric(12,2) default 0,
  overtime_amount numeric(12,2) default 0,
  net_salary numeric(12,2) default 0,
  status text default 'pending' check (status in ('pending','approved','paid','cancelled')),
  paid_at timestamptz,
  notes text,
  created_at timestamptz default now(),
  unique(employee_id, payroll_month, payroll_year)
);

-- =========================
-- 4) CUSTOMERS
-- =========================
create table customers (
  id uuid primary key default uuid_generate_v4(),
  customer_code text unique,
  customer_name text not null,
  company_name text,
  customer_type text default 'company' check (customer_type in ('company','restaurant','hotel','market','individual','other')),
  phone text,
  email text,
  address text,
  tax_number text,
  credit_limit numeric(12,2) default 0,
  balance numeric(12,2) default 0,
  assigned_sales_id uuid references employees(id),
  status text default 'active',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table customer_addresses (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid references customers(id) on delete cascade,
  address_title text,
  address text not null,
  city text,
  area text,
  is_default boolean default false,
  created_at timestamptz default now()
);

create table customer_contacts (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid references customers(id) on delete cascade,
  contact_name text,
  job_title text,
  phone text,
  email text,
  created_at timestamptz default now()
);

create table customer_complaints (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid references customers(id) on delete cascade,
  complaint_title text not null,
  complaint_details text,
  status text default 'open' check (status in ('open','in_progress','resolved','closed')),
  priority text default 'medium' check (priority in ('low','medium','high','urgent')),
  assigned_to uuid references employees(id),
  solution text,
  created_at timestamptz default now(),
  closed_at timestamptz
);

-- =========================
-- 5) PRODUCTS / PRICES
-- =========================
create table product_categories (
  id uuid primary key default uuid_generate_v4(),
  category_name text not null unique,
  description text,
  created_at timestamptz default now()
);

create table products (
  id uuid primary key default uuid_generate_v4(),
  product_code text unique,
  product_name text not null,
  category_id uuid references product_categories(id),
  unit text default 'kg',
  price numeric(12,2) default 0,
  cost numeric(12,2) default 0,
  is_fresh boolean default false,
  image_url text,
  min_order_qty numeric(12,3) default 1,
  status text default 'active' check (status in ('active','inactive')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table price_history (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid references products(id) on delete cascade,
  old_price numeric(12,2),
  new_price numeric(12,2),
  changed_by uuid references employees(id),
  reason text,
  created_at timestamptz default now()
);

-- =========================
-- 6) WAREHOUSES / STOCK
-- =========================
create table warehouses (
  id uuid primary key default uuid_generate_v4(),
  warehouse_name text not null,
  warehouse_type text default 'freezer' check (warehouse_type in ('freezer','fresh','dry','main','branch')),
  location text,
  manager_id uuid references employees(id),
  created_at timestamptz default now()
);

create table stock (
  id uuid primary key default uuid_generate_v4(),
  warehouse_id uuid references warehouses(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  quantity numeric(12,3) default 0,
  reserved_quantity numeric(12,3) default 0,
  min_quantity numeric(12,3) default 0,
  expiry_date date,
  batch_number text,
  updated_at timestamptz default now(),
  unique(warehouse_id, product_id, batch_number)
);

create table stock_movements (
  id uuid primary key default uuid_generate_v4(),
  warehouse_id uuid references warehouses(id),
  product_id uuid references products(id),
  movement_type text not null check (movement_type in ('in','out','transfer','adjustment','return')),
  quantity numeric(12,3) not null,
  unit_cost numeric(12,2) default 0,
  reference_type text,
  reference_id uuid,
  notes text,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

-- =========================
-- 7) ORDERS / DELIVERY
-- =========================
create table orders (
  id uuid primary key default uuid_generate_v4(),
  order_number text unique not null,
  customer_id uuid references customers(id),
  sales_employee_id uuid references employees(id),
  delivery_employee_id uuid references employees(id),
  order_date date default current_date,
  delivery_date date,
  delivery_time time,
  status text default 'pending' check (status in ('pending','confirmed','preparing','out_for_delivery','delivered','cancelled','returned')),
  subtotal numeric(12,2) default 0,
  discount numeric(12,2) default 0,
  tax numeric(12,2) default 0,
  total numeric(12,2) default 0,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id),
  quantity numeric(12,3) not null,
  unit_price numeric(12,2) not null,
  discount numeric(12,2) default 0,
  total numeric(12,2) not null
);

create table deliveries (
  id uuid primary key default uuid_generate_v4(),
  delivery_number text unique,
  order_id uuid references orders(id) on delete cascade,
  delivery_employee_id uuid references employees(id),
  delivery_address text,
  scheduled_date date,
  scheduled_time time,
  actual_delivery_time timestamptz,
  status text default 'scheduled' check (status in ('scheduled','picked_up','on_way','delivered','failed','returned')),
  proof_image_url text,
  customer_signature_url text,
  notes text,
  created_at timestamptz default now()
);

-- =========================
-- 8) ACCOUNTING
-- =========================
create table invoices (
  id uuid primary key default uuid_generate_v4(),
  invoice_number text unique not null,
  order_id uuid references orders(id),
  customer_id uuid references customers(id),
  invoice_date date default current_date,
  due_date date,
  subtotal numeric(12,2) default 0,
  discount numeric(12,2) default 0,
  tax numeric(12,2) default 0,
  total numeric(12,2) default 0,
  paid_amount numeric(12,2) default 0,
  remaining_amount numeric(12,2) default 0,
  status text default 'unpaid' check (status in ('unpaid','partial','paid','cancelled','overdue')),
  notes text,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

create table invoice_items (
  id uuid primary key default uuid_generate_v4(),
  invoice_id uuid references invoices(id) on delete cascade,
  product_id uuid references products(id),
  item_name text,
  quantity numeric(12,3) not null,
  unit_price numeric(12,2) not null,
  total numeric(12,2) not null
);

create table payments (
  id uuid primary key default uuid_generate_v4(),
  payment_number text unique,
  customer_id uuid references customers(id),
  invoice_id uuid references invoices(id),
  amount numeric(12,2) not null,
  payment_method text check (payment_method in ('cash','bank_transfer','instapay','vodafone_cash','cheque','other')),
  payment_date date default current_date,
  notes text,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

create table expenses (
  id uuid primary key default uuid_generate_v4(),
  expense_number text unique,
  expense_title text not null,
  category text,
  amount numeric(12,2) not null,
  expense_date date default current_date,
  paid_by uuid references employees(id),
  payment_method text,
  notes text,
  created_at timestamptz default now()
);

create table treasury_transactions (
  id uuid primary key default uuid_generate_v4(),
  transaction_number text unique,
  transaction_type text not null check (transaction_type in ('income','expense','transfer','opening_balance','adjustment')),
  amount numeric(12,2) not null,
  source text,
  reference_id uuid,
  notes text,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

-- =========================
-- 9) CONTRACTS
-- =========================
create table contracts (
  id uuid primary key default uuid_generate_v4(),
  contract_number text unique not null,
  customer_id uuid references customers(id),
  contract_title text,
  start_date date,
  end_date date,
  contract_value numeric(12,2) default 0,
  payment_terms text,
  delivery_terms text,
  status text default 'active' check (status in ('draft','active','expired','cancelled','renewed')),
  file_url text,
  notes text,
  created_by uuid references employees(id),
  created_at timestamptz default now()
);

create table contract_items (
  id uuid primary key default uuid_generate_v4(),
  contract_id uuid references contracts(id) on delete cascade,
  product_id uuid references products(id),
  agreed_price numeric(12,2),
  min_quantity numeric(12,3),
  notes text
);

-- =========================
-- 10) NOTIFICATIONS / AUDIT
-- =========================
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id) on delete cascade,
  title text not null,
  message text,
  notification_type text default 'info',
  is_read boolean default false,
  reference_type text,
  reference_id uuid,
  created_at timestamptz default now()
);

create table audit_logs (
  id uuid primary key default uuid_generate_v4(),
  employee_id uuid references employees(id),
  action text not null,
  table_name text,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz default now()
);

-- =========================
-- 11) SEED ROLES
-- =========================
insert into roles (role_key, role_name_ar, permissions)
values
('owner', 'صاحب الشركة', '{"all": true}'),
('general_manager', 'مدير الشركة', '{"dashboard": true, "reports": true, "employees": true, "hr": true, "sales": true, "accounts": true, "warehouse": true, "contracts": true}'),
('sales_manager', 'مدير المبيعات', '{"sales": true, "customers": true, "orders": true, "prices": true, "reports": true}'),
('sales_employee', 'موظف مبيعات', '{"customers": true, "orders": true, "prices": true}'),
('delivery_manager', 'مدير المناديب', '{"deliveries": true, "orders": true, "drivers": true, "reports": true}'),
('delivery_employee', 'مندوب توصيل', '{"deliveries": true, "my_orders": true}'),
('accounts_manager', 'مدير الحسابات', '{"accounts": true, "invoices": true, "payments": true, "expenses": true, "payroll": true, "reports": true}'),
('accounts_employee', 'موظف حسابات', '{"invoices": true, "payments": true, "expenses": true, "customers_balance": true}'),
('warehouse_manager', 'مدير المخازن', '{"warehouse": true, "stock": true, "stock_movements": true, "reports": true}'),
('warehouse_keeper', 'أمين مخزن', '{"stock": true, "stock_movements": true, "orders_preparation": true}'),
('warehouse_employee', 'موظف مخازن', '{"stock": true, "stock_movements": true}')
on conflict (role_key) do nothing;

-- =========================
-- 12) SEED DEFAULT EMPLOYEES + DEMO ACCOUNTS
-- كلمة المرور التجريبية: 123456
-- =========================
insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'صاحب الشركة', 'owner', 'owner@aleman.local', '01000000000', id, 'صاحب الشركة', 'الإدارة العليا', 0 from roles where role_key='owner'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'مدير الشركة', 'general.manager', 'manager@aleman.local', '01000000001', id, 'مدير الشركة', 'الإدارة العليا', 25000 from roles where role_key='general_manager'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'مدير المبيعات', 'sales.manager', 'sales.manager@aleman.local', '01000000002', id, 'مدير المبيعات', 'المبيعات', 18000 from roles where role_key='sales_manager'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'موظف مبيعات 1', 'sales.01', 'sales01@aleman.local', '01000000006', id, 'موظف مبيعات', 'المبيعات', 9000 from roles where role_key='sales_employee'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'مدير الحسابات', 'accounts.manager', 'accounts.manager@aleman.local', '01000000003', id, 'مدير الحسابات', 'الحسابات', 18000 from roles where role_key='accounts_manager'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'موظف حسابات 1', 'accounts.01', 'accounts01@aleman.local', '01000000007', id, 'موظف حسابات', 'الحسابات', 8500 from roles where role_key='accounts_employee'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'مدير المخازن', 'warehouse.manager', 'warehouse.manager@aleman.local', '01000000004', id, 'مدير المخازن', 'المخازن', 16000 from roles where role_key='warehouse_manager'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'أمين مخزن', 'keeper.01', 'keeper01@aleman.local', '01000000008', id, 'أمين مخزن', 'المخازن', 9000 from roles where role_key='warehouse_keeper'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'مدير المناديب', 'delivery.manager', 'delivery.manager@aleman.local', '01000000005', id, 'مدير المناديب', 'التوصيل', 15000 from roles where role_key='delivery_manager'
on conflict (username) do nothing;

insert into employees (full_name, username, email, phone, role_id, job_title, department, base_salary)
select 'مندوب توصيل 1', 'driver.01', 'driver01@aleman.local', '01000000009', id, 'مندوب توصيل', 'التوصيل', 8000 from roles where role_key='delivery_employee'
on conflict (username) do nothing;

insert into employee_accounts (employee_id, login_email, demo_password, is_active)
select id, email, '123456', true from employees
on conflict (login_email) do nothing;

-- =========================
-- 13) SEED PRODUCT CATEGORIES
-- =========================
insert into product_categories (category_name, description)
values
('جمبري', 'منتجات الجمبري بجميع المقاسات'),
('كاليماري وسبيط', 'كاليماري وسبيط طازج ومجمد'),
('سالمون', 'منتجات السالمون'),
('كراب واستاكوزا', 'كراب واستاكوزا وسوفت شيل'),
('أسماك فيليه', 'فيليه وأسماك مجهزة'),
('أصناف بحرية أخرى', 'أصناف بحرية متنوعة')
on conflict (category_name) do nothing;

-- =========================
-- 14) SEED PRODUCTS FROM PRICE LIST
-- =========================
insert into products (product_code, product_name, price, unit, is_fresh)
values
('P001','جمبرى لحم 20-16',1100,'kg',false),
('P002','جمبرى لحم 25-21',1050,'kg',false),
('P003','جمبرى لحم 30-26',950,'kg',false),
('P004','جمبرى لحم 40-30',800,'kg',false),
('P005','جمبرى لحم 50-40',770,'kg',false),
('P006','جمبرى لحم 60-50',700,'kg',false),
('P007','جمبرى لحم 70-60',650,'kg',false),
('P008','جمبرى لحم 90-70',600,'kg',false),
('P009','جمبرى لحم 110-90',580,'kg',false),
('P010','جمبرى لحم 200-100',550,'kg',false),
('P011','جمبرى بالذيل 20-16',1100,'kg',false),
('P012','جمبرى بالذيل 25-21',1050,'kg',false),
('P013','جمبرى بالذيل 30-26',1000,'kg',false),
('P014','جمبرى قشر 12-8',1450,'kg',false),
('P015','جمبرى قشر يو 10',1350,'kg',false),
('P016','جمبرى قشر 15-13',1100,'kg',false),
('P017','جمبرى قشر 20-16',950,'kg',false),
('P018','جمبرى قشر 30-20',700,'kg',false),
('P019','جمبرى قشر 40-30',600,'kg',false),
('P020','كاليماري بيضاء',500,'kg',false),
('P021','كاليماري صيني',160,'kg',false),
('P022','كراب استيكس صيني',150,'kg',false),
('P023','كراب استيكس هندي',280,'kg',false),
('P024','سوفت شيل',16000,'kg',false),
('P025','بالك كود',4500,'kg',false),
('P026','هامتشي',2500,'kg',false),
('P027','شيليان سيباس',4500,'kg',false),
('P028','سالمون هول مجمد',580,'kg',false),
('P029','سالمون فيليه',900,'kg',false),
('P030','سالمون مدخن بالجلد',1000,'kg',false),
('P031','سالمون مدخن منزوعة الجلد',1200,'kg',false),
('P032','تونة ساكو',800,'kg',false),
('P033','باسا 1 ك',160,'kg',false),
('P034','باسا 5 ك',170,'kg',false),
('P035','سي سكالوب',1900,'kg',false),
('P036','بلح مفتوح',370,'kg',false),
('P037','بلح مقفول',300,'kg',false),
('P038','بلح لحم',0,'kg',false),
('P039','اخطبوط كبير',480,'kg',false),
('P040','اخطبوط صغير',400,'kg',false),
('P041','ذيول استاكوزا اماراتي',3300,'kg',false),
('P042','استاكوزا هول',1300,'kg',false),
('P043','فيليه قشر بياض',600,'kg',false),
('P045','سالمون هول فرش نرويجي',1250,'kg',true),
('P046','سبيط كامل بالرأس',450,'kg',false),
('P047','سبيط ضهور فقط',800,'kg',false),
('P048','كينج كراب',7500,'kg',false),
('P049','ذيول استاكوزا كندي',6000,'kg',false),
('P050','سالمون بورشن',1000,'kg',false)
on conflict (product_code) do update
set product_name = excluded.product_name,
    price = excluded.price,
    unit = excluded.unit,
    is_fresh = excluded.is_fresh;

-- =========================
-- 15) SAMPLE WAREHOUSES
-- =========================
insert into warehouses (warehouse_name, warehouse_type, location)
values
('المخزن الرئيسي - مجمدات', 'freezer', 'القاهرة'),
('مخزن الطازج', 'fresh', 'القاهرة')
on conflict do nothing;

-- =========================
-- 16) ENABLE REALTIME
-- قد يظهر خطأ duplicate إذا كانت الجداول مضافة مسبقًا، يمكن تجاهله أو تشغيل الملف من مشروع جديد
-- =========================
do $$
begin
  begin alter publication supabase_realtime add table roles; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table employees; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table employee_accounts; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table attendance; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table leaves; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table salary_deductions; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table salary_bonuses; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table payroll; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table customers; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table customer_addresses; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table customer_contacts; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table customer_complaints; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table product_categories; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table products; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table price_history; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table warehouses; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table stock; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table stock_movements; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table orders; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table order_items; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table deliveries; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table invoices; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table invoice_items; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table payments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table expenses; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table treasury_transactions; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table contracts; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table contract_items; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table notifications; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table audit_logs; exception when duplicate_object then null; end;
end $$;

-- =========================
-- 17) ROW LEVEL SECURITY + DEMO POLICIES
-- ملاحظة: policies مفتوحة للتجربة فقط. للإنتاج لازم تتقفل حسب Supabase Auth والصلاحيات.
-- =========================
alter table roles enable row level security;
alter table employees enable row level security;
alter table employee_accounts enable row level security;
alter table attendance enable row level security;
alter table leaves enable row level security;
alter table salary_deductions enable row level security;
alter table salary_bonuses enable row level security;
alter table payroll enable row level security;
alter table customers enable row level security;
alter table customer_addresses enable row level security;
alter table customer_contacts enable row level security;
alter table customer_complaints enable row level security;
alter table product_categories enable row level security;
alter table products enable row level security;
alter table price_history enable row level security;
alter table warehouses enable row level security;
alter table stock enable row level security;
alter table stock_movements enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table deliveries enable row level security;
alter table invoices enable row level security;
alter table invoice_items enable row level security;
alter table payments enable row level security;
alter table expenses enable row level security;
alter table treasury_transactions enable row level security;
alter table contracts enable row level security;
alter table contract_items enable row level security;
alter table notifications enable row level security;
alter table audit_logs enable row level security;

-- Drop old demo policies if exist
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND policyname LIKE 'demo_%'
  LOOP
    EXECUTE format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

create policy demo_all_roles on roles for all using (true) with check (true);
create policy demo_all_employees on employees for all using (true) with check (true);
create policy demo_all_employee_accounts on employee_accounts for all using (true) with check (true);
create policy demo_all_attendance on attendance for all using (true) with check (true);
create policy demo_all_leaves on leaves for all using (true) with check (true);
create policy demo_all_salary_deductions on salary_deductions for all using (true) with check (true);
create policy demo_all_salary_bonuses on salary_bonuses for all using (true) with check (true);
create policy demo_all_payroll on payroll for all using (true) with check (true);
create policy demo_all_customers on customers for all using (true) with check (true);
create policy demo_all_customer_addresses on customer_addresses for all using (true) with check (true);
create policy demo_all_customer_contacts on customer_contacts for all using (true) with check (true);
create policy demo_all_customer_complaints on customer_complaints for all using (true) with check (true);
create policy demo_all_product_categories on product_categories for all using (true) with check (true);
create policy demo_all_products on products for all using (true) with check (true);
create policy demo_all_price_history on price_history for all using (true) with check (true);
create policy demo_all_warehouses on warehouses for all using (true) with check (true);
create policy demo_all_stock on stock for all using (true) with check (true);
create policy demo_all_stock_movements on stock_movements for all using (true) with check (true);
create policy demo_all_orders on orders for all using (true) with check (true);
create policy demo_all_order_items on order_items for all using (true) with check (true);
create policy demo_all_deliveries on deliveries for all using (true) with check (true);
create policy demo_all_invoices on invoices for all using (true) with check (true);
create policy demo_all_invoice_items on invoice_items for all using (true) with check (true);
create policy demo_all_payments on payments for all using (true) with check (true);
create policy demo_all_expenses on expenses for all using (true) with check (true);
create policy demo_all_treasury_transactions on treasury_transactions for all using (true) with check (true);
create policy demo_all_contracts on contracts for all using (true) with check (true);
create policy demo_all_contract_items on contract_items for all using (true) with check (true);
create policy demo_all_notifications on notifications for all using (true) with check (true);
create policy demo_all_audit_logs on audit_logs for all using (true) with check (true);

-- =========================
-- 18) USEFUL VIEWS
-- =========================
create or replace view v_employee_profiles as
select
  e.id,
  e.full_name,
  e.username,
  e.email,
  e.phone,
  e.job_title,
  e.department,
  e.base_salary,
  e.allowance,
  e.status,
  r.role_key,
  r.role_name_ar,
  r.permissions
from employees e
left join roles r on r.id = e.role_id;

create or replace view v_customer_balances as
select
  c.id,
  c.customer_name,
  c.company_name,
  coalesce(sum(i.total), 0) as total_invoices,
  coalesce(sum(i.paid_amount), 0) as total_paid,
  coalesce(sum(i.remaining_amount), 0) as total_remaining
from customers c
left join invoices i on i.customer_id = c.id
group by c.id, c.customer_name, c.company_name;

create or replace view v_stock_summary as
select
  w.warehouse_name,
  p.product_code,
  p.product_name,
  p.unit,
  s.quantity,
  s.reserved_quantity,
  (s.quantity - s.reserved_quantity) as available_quantity,
  s.min_quantity,
  case when s.quantity <= s.min_quantity then true else false end as is_low_stock
from stock s
join warehouses w on w.id = s.warehouse_id
join products p on p.id = s.product_id;

-- =========================
-- 19) FINISH
-- =========================
select 'AL-EMAN ERP Supabase setup completed successfully' as result;
