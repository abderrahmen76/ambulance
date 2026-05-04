create table if not exists public.maintenance_rules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  maintenance_type text not null,
  interval_km integer,
  interval_days integer,
  warning_before_km integer,
  warning_before_days integer,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, maintenance_type)
);

alter table public.maintenance_records
  add column if not exists next_due_date timestamptz,
  add column if not exists next_due_km numeric,
  add column if not exists interval_km integer,
  add column if not exists interval_days integer,
  add column if not exists warning_before_km integer,
  add column if not exists warning_before_days integer;

create index if not exists maintenance_rules_tenant_type_idx
  on public.maintenance_rules (tenant_id, maintenance_type);

alter table public.maintenance_rules enable row level security;

drop policy if exists "maintenance_rules_select_by_tenant" on public.maintenance_rules;
create policy "maintenance_rules_select_by_tenant"
  on public.maintenance_rules
  for select
  using (
    exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and (u.tenant_id = maintenance_rules.tenant_id or u.role = 'admin')
    )
  );

drop policy if exists "maintenance_rules_insert_by_tenant_manager" on public.maintenance_rules;
create policy "maintenance_rules_insert_by_tenant_manager"
  on public.maintenance_rules
  for insert
  with check (
    exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  );

drop policy if exists "maintenance_rules_update_by_tenant_manager" on public.maintenance_rules;
create policy "maintenance_rules_update_by_tenant_manager"
  on public.maintenance_rules
  for update
  using (
    exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  )
  with check (
    exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  );

drop policy if exists "maintenance_rules_delete_by_tenant_manager" on public.maintenance_rules;
create policy "maintenance_rules_delete_by_tenant_manager"
  on public.maintenance_rules
  for delete
  using (
    exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  );
