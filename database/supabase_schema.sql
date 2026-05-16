
-- Al-Eman Fish Supply ERP - Supabase schema + realtime
create extension if not exists "uuid-ossp";
create type user_role as enum ('owner','general_manager','sales_manager','sales_rep','delivery_manager','delivery_rep','accounts_manager','accountant','warehouse_manager','storekeeper','warehouse_staff');
create type order_status as enum ('draft','confirmed','preparing','out_for_delivery','delivered','cancelled');
create type payment_status as enum ('unpaid','partial','paid','overdue');

create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text not null, role user_role not null, phone text, is_active boolean default true, created_at timestamptz default now());
create table public.employees (id uuid primary key default uuid_generate_v4(), profile_id uuid references public.profiles(id), employee_code text unique, job_title text not null, manager_id uuid references public.employees(id), permissions text[] default '{}', created_at timestamptz default now());
create table public.customers (id uuid primary key default uuid_generate_v4(), brand_name text not null, contact_name text, phone text, email text, location text, address text, sales_owner uuid references public.profiles(id), status text default 'lead', notes text, created_at timestamptz default now());
create table public.products (id uuid primary key default uuid_generate_v4(), sku text unique, name text not null, category text, unit text default 'kg', current_price numeric(12,2) default 0, is_active boolean default true, created_at timestamptz default now());
create table public.price_history (id uuid primary key default uuid_generate_v4(), product_id uuid references public.products(id) on delete cascade, price numeric(12,2) not null, effective_from date default current_date, changed_by uuid references public.profiles(id));
create table public.warehouses (id uuid primary key default uuid_generate_v4(), name text not null, location text, manager_id uuid references public.profiles(id));
create table public.inventory (id uuid primary key default uuid_generate_v4(), warehouse_id uuid references public.warehouses(id), product_id uuid references public.products(id), quantity numeric(12,3) default 0, min_quantity numeric(12,3) default 0, updated_at timestamptz default now(), unique(warehouse_id,product_id));
create table public.orders (id uuid primary key default uuid_generate_v4(), order_no text unique not null, customer_id uuid references public.customers(id), sales_id uuid references public.profiles(id), status order_status default 'draft', delivery_date date, notes text, subtotal numeric(12,2) default 0, discount numeric(12,2) default 0, total numeric(12,2) default 0, created_at timestamptz default now());
create table public.order_items (id uuid primary key default uuid_generate_v4(), order_id uuid references public.orders(id) on delete cascade, product_id uuid references public.products(id), quantity numeric(12,3) not null, unit_price numeric(12,2) not null, total numeric(12,2) generated always as (quantity * unit_price) stored);
create table public.deliveries (id uuid primary key default uuid_generate_v4(), order_id uuid references public.orders(id), driver_id uuid references public.profiles(id), scheduled_at timestamptz, delivered_at timestamptz, status text default 'scheduled', proof_url text, notes text);
create table public.invoices (id uuid primary key default uuid_generate_v4(), invoice_no text unique not null, order_id uuid references public.orders(id), customer_id uuid references public.customers(id), issue_date date default current_date, due_date date, total numeric(12,2) not null default 0, paid numeric(12,2) default 0, status payment_status default 'unpaid');
create table public.payments (id uuid primary key default uuid_generate_v4(), invoice_id uuid references public.invoices(id), amount numeric(12,2), method text, paid_at timestamptz default now(), notes text);
create table public.contracts (id uuid primary key default uuid_generate_v4(), contract_no text unique not null, customer_id uuid references public.customers(id), start_date date, end_date date, terms text, file_url text, status text default 'active');
create table public.complaints (id uuid primary key default uuid_generate_v4(), customer_id uuid references public.customers(id), order_id uuid references public.orders(id), title text, details text, owner_id uuid references public.profiles(id), status text default 'open', created_at timestamptz default now());
create table public.audit_logs (id bigserial primary key, table_name text, record_id uuid, action text, changed_by uuid references public.profiles(id), payload jsonb, created_at timestamptz default now());

alter table public.profiles enable row level security; alter table public.employees enable row level security; alter table public.customers enable row level security; alter table public.products enable row level security; alter table public.price_history enable row level security; alter table public.warehouses enable row level security; alter table public.inventory enable row level security; alter table public.orders enable row level security; alter table public.order_items enable row level security; alter table public.deliveries enable row level security; alter table public.invoices enable row level security; alter table public.payments enable row level security; alter table public.contracts enable row level security; alter table public.complaints enable row level security;

create or replace function public.current_role() returns user_role language sql stable as $$ select role from public.profiles where id = auth.uid() $$;
create policy "read authenticated" on public.products for select to authenticated using (true);
create policy "owner full profiles" on public.profiles for all to authenticated using (public.current_role() in ('owner','general_manager')) with check (public.current_role() in ('owner','general_manager'));
create policy "sales customers" on public.customers for all to authenticated using (public.current_role() in ('owner','general_manager','sales_manager','sales_rep')) with check (public.current_role() in ('owner','general_manager','sales_manager','sales_rep'));
create policy "orders team" on public.orders for all to authenticated using (public.current_role() in ('owner','general_manager','sales_manager','sales_rep','delivery_manager','accounts_manager','accountant','warehouse_manager','storekeeper')) with check (public.current_role() in ('owner','general_manager','sales_manager','sales_rep'));
create policy "finance" on public.invoices for all to authenticated using (public.current_role() in ('owner','general_manager','accounts_manager','accountant')) with check (public.current_role() in ('owner','general_manager','accounts_manager','accountant'));
create policy "warehouse" on public.inventory for all to authenticated using (public.current_role() in ('owner','general_manager','warehouse_manager','storekeeper','warehouse_staff')) with check (public.current_role() in ('owner','general_manager','warehouse_manager','storekeeper'));
create policy "delivery" on public.deliveries for all to authenticated using (public.current_role() in ('owner','general_manager','delivery_manager','delivery_rep')) with check (public.current_role() in ('owner','general_manager','delivery_manager'));

alter publication supabase_realtime add table public.profiles, public.employees, public.customers, public.products, public.price_history, public.warehouses, public.inventory, public.orders, public.order_items, public.deliveries, public.invoices, public.payments, public.contracts, public.complaints, public.audit_logs;

insert into public.products (sku,name,category,current_price) values
('PRD-001','جمبرى لحم 20-16','مأكولات بحرية',1100),
('PRD-002','جمبرى لحم 25-21','مأكولات بحرية',1050),
('PRD-003','جمبرى لحم 30-26','مأكولات بحرية',950),
('PRD-004','جمبرى لحم 40-30','مأكولات بحرية',800),
('PRD-005','جمبرى لحم 50-40','مأكولات بحرية',770),
('PRD-006','جمبرى لحم 60-50','مأكولات بحرية',700),
('PRD-007','جمبرى لحم 70-60','مأكولات بحرية',650),
('PRD-008','جمبرى لحم 90-70','مأكولات بحرية',600),
('PRD-009','جمبرى لحم 110-90','مأكولات بحرية',580),
('PRD-010','جمبرى لحم 200-100','مأكولات بحرية',550),
('PRD-011','جمبرى بالذيل 20-16','مأكولات بحرية',1100),
('PRD-012','جمبرى بالذيل 25-21','مأكولات بحرية',1050),
('PRD-013','جمبرى بالذيل 30-26','مأكولات بحرية',1000),
('PRD-014','جمبرى قشر 12-8','مأكولات بحرية',1450),
('PRD-015','جمبرى قشر يو 10','مأكولات بحرية',1350),
('PRD-016','جمبرى قشر 15-13','مأكولات بحرية',1100),
('PRD-017','جمبرى قشر 20-16','مأكولات بحرية',950),
('PRD-018','جمبرى قشر 30-20','مأكولات بحرية',700),
('PRD-019','جمبرى قشر 40-30','مأكولات بحرية',600),
('PRD-020','كاليماري بيضاء','مأكولات بحرية',500),
('PRD-021','كاليماري صيني','مأكولات بحرية',160),
('PRD-022','كراب استيكس صيني','مأكولات بحرية',150),
('PRD-023','كراب استيكس هندي','مأكولات بحرية',280),
('PRD-024','سوفت شيل','مأكولات بحرية',16000),
('PRD-025','بلاك كود','مأكولات بحرية',4500),
('PRD-026','هامتشي','مأكولات بحرية',2500),
('PRD-027','شيليان سيباس','مأكولات بحرية',4500),
('PRD-028','سالمون هول مجمد','مأكولات بحرية',580),
('PRD-029','سالمون فيليه','مأكولات بحرية',900),
('PRD-030','سالمون مدخن بالجلد','مأكولات بحرية',1000),
('PRD-031','سالمون مدخن منزوعة الجلد','مأكولات بحرية',1200),
('PRD-032','تونة ساكو','مأكولات بحرية',800),
('PRD-033','باسا 1 ك','مأكولات بحرية',160),
('PRD-034','باسا 5 ك','مأكولات بحرية',170),
('PRD-035','سي سكالوب','مأكولات بحرية',1900),
('PRD-036','بلح مفتوح','مأكولات بحرية',370),
('PRD-037','بلح مقفول','مأكولات بحرية',300),
('PRD-038','بلح لحم','مأكولات بحرية',0),
('PRD-039','اخطبوط كبير','مأكولات بحرية',480),
('PRD-040','اخطبوط صغير','مأكولات بحرية',400),
('PRD-041','ذيول استاكوزا اماراتي','مأكولات بحرية',3300),
('PRD-042','استاكوزا هول','مأكولات بحرية',1300),
('PRD-043','فيليه قشر بياض','مأكولات بحرية',600),
('PRD-045','سالمون هول فرش نرويجي','مأكولات بحرية',1250),
('PRD-046','سبيط كامل بالراس','مأكولات بحرية',450),
('PRD-047','سبيط ضهور فقط','مأكولات بحرية',800),
('PRD-048','كينج كراب','مأكولات بحرية',7500),
('PRD-049','ذيول استاكوزا كندي','مأكولات بحرية',6000),
('PRD-050','سالمون بورشن','مأكولات بحرية',1000);
