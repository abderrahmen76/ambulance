alter table public.maintenance_rules enable row level security;

drop policy if exists "maintenance_rules_select_by_tenant" on public.maintenance_rules;
create policy "maintenance_rules_select_by_tenant"
  on public.maintenance_rules
  for select
  using (
    maintenance_rules.tenant_id = nullif(
      coalesce(
        auth.jwt() ->> 'tenant_id',
        auth.jwt() -> 'user_metadata' ->> 'tenant_id'
      ),
      ''
    )::uuid
    or exists (
      select 1
      from public.users u
      where (u.auth_user_id = auth.uid() or u.id = auth.uid())
        and (u.tenant_id = maintenance_rules.tenant_id or u.role = 'admin')
    )
  );

drop policy if exists "maintenance_rules_insert_by_tenant_manager" on public.maintenance_rules;
create policy "maintenance_rules_insert_by_tenant_manager"
  on public.maintenance_rules
  for insert
  with check (
    (
      maintenance_rules.tenant_id = nullif(
        coalesce(
          auth.jwt() ->> 'tenant_id',
          auth.jwt() -> 'user_metadata' ->> 'tenant_id'
        ),
        ''
      )::uuid
      and coalesce(
        auth.jwt() ->> 'role',
        auth.jwt() -> 'user_metadata' ->> 'role'
      ) in ('manager', 'admin')
    )
    or exists (
      select 1
      from public.users u
      where (u.auth_user_id = auth.uid() or u.id = auth.uid())
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  );

drop policy if exists "maintenance_rules_update_by_tenant_manager" on public.maintenance_rules;
create policy "maintenance_rules_update_by_tenant_manager"
  on public.maintenance_rules
  for update
  using (
    (
      maintenance_rules.tenant_id = nullif(
        coalesce(
          auth.jwt() ->> 'tenant_id',
          auth.jwt() -> 'user_metadata' ->> 'tenant_id'
        ),
        ''
      )::uuid
      and coalesce(
        auth.jwt() ->> 'role',
        auth.jwt() -> 'user_metadata' ->> 'role'
      ) in ('manager', 'admin')
    )
    or exists (
      select 1
      from public.users u
      where (u.auth_user_id = auth.uid() or u.id = auth.uid())
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  )
  with check (
    (
      maintenance_rules.tenant_id = nullif(
        coalesce(
          auth.jwt() ->> 'tenant_id',
          auth.jwt() -> 'user_metadata' ->> 'tenant_id'
        ),
        ''
      )::uuid
      and coalesce(
        auth.jwt() ->> 'role',
        auth.jwt() -> 'user_metadata' ->> 'role'
      ) in ('manager', 'admin')
    )
    or exists (
      select 1
      from public.users u
      where (u.auth_user_id = auth.uid() or u.id = auth.uid())
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  );

drop policy if exists "maintenance_rules_delete_by_tenant_manager" on public.maintenance_rules;
create policy "maintenance_rules_delete_by_tenant_manager"
  on public.maintenance_rules
  for delete
  using (
    (
      maintenance_rules.tenant_id = nullif(
        coalesce(
          auth.jwt() ->> 'tenant_id',
          auth.jwt() -> 'user_metadata' ->> 'tenant_id'
        ),
        ''
      )::uuid
      and coalesce(
        auth.jwt() ->> 'role',
        auth.jwt() -> 'user_metadata' ->> 'role'
      ) in ('manager', 'admin')
    )
    or exists (
      select 1
      from public.users u
      where (u.auth_user_id = auth.uid() or u.id = auth.uid())
        and u.tenant_id = maintenance_rules.tenant_id
        and u.role in ('manager', 'admin')
    )
  );
