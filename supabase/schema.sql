-- Execute no SQL Editor do Supabase do Cliente 2.
-- Nota: este app e cliente-side puro. Em producao, idealmente mova escrita para
-- uma Edge Function com validacao de identidade/autorizacao.

create table if not exists public.restobar_state (
  id text primary key,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.restobar_state enable row level security;

do $$
begin
  -- Remove policy antiga extremamente permissiva, se existir.
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'restobar_state' and policyname = 'allow_anon_all_restobar_state'
  ) then
    drop policy allow_anon_all_restobar_state on public.restobar_state;
  end if;

  -- Garante que so exista a linha singleton "main".
  if not exists (
    select 1 from pg_constraint
    where conname = 'restobar_state_singleton_main'
      and conrelid = 'public.restobar_state'::regclass
  ) then
    alter table public.restobar_state
      add constraint restobar_state_singleton_main check (id = 'main');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'restobar_state' and policyname = 'allow_anon_select_main_restobar_state'
  ) then
    create policy allow_anon_select_main_restobar_state
      on public.restobar_state
      for select
      to anon
      using (id = 'main');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'restobar_state' and policyname = 'allow_anon_insert_main_restobar_state'
  ) then
    create policy allow_anon_insert_main_restobar_state
      on public.restobar_state
      for insert
      to anon
      with check (id = 'main');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'restobar_state' and policyname = 'allow_anon_update_main_restobar_state'
  ) then
    create policy allow_anon_update_main_restobar_state
      on public.restobar_state
      for update
      to anon
      using (id = 'main')
      with check (id = 'main');
  end if;
end $$;

-- Migracao do catalogo armazenado no JSONB. Mantem todos os produtos existentes:
-- Cozinha, Espetinhos e a antiga categoria Adicionais passam a Lanche.
-- Produtos que eram Adicionais passam para Lanche / Adicionais; os demais, Lanche / Lanches.
update public.restobar_state as state
set
  payload = jsonb_set(
    state.payload,
    '{products}',
    coalesce(
      (
        select jsonb_agg(
          jsonb_set(
            jsonb_set(
              jsonb_set(product, '{category}', to_jsonb(mapped.category), true),
              '{subcategory}', to_jsonb(mapped.subcategory), true
            ),
            '{requiresKitchen}',
            to_jsonb(case when mapped.category in ('Lanche', 'Entradas') then true else coalesce((product->>'requiresKitchen')::boolean, false) end),
            true
          )
        )
        from jsonb_array_elements(coalesce(state.payload->'products', '[]'::jsonb)) as product
        cross join lateral (
          select case lower(btrim(coalesce(product->>'category', '')))
            when 'bar' then 'Bebidas'
            when 'bebida' then 'Bebidas'
            when 'bebidas' then 'Bebidas'
            when 'dose' then 'Bebidas'
            when 'doses' then 'Bebidas'
            when 'dose/copo' then 'Bebidas'
            when 'doses/copo' then 'Bebidas'
            when 'copo' then 'Bebidas'
            when 'espetinho' then 'Lanche'
            when 'espetinhos' then 'Lanche'
            when 'avulso' then 'Lanche'
            when 'avulsos' then 'Lanche'
            when 'variedades' then 'Lanche'
            when 'variados' then 'Lanche'
            when 'adicional' then 'Lanche'
            when 'adicionais' then 'Lanche'
            when 'entrada' then 'Entradas'
            when 'entradas' then 'Entradas'
            when 'cozinha' then 'Lanche'
            when 'lanche' then 'Lanche'
            when 'lanches' then 'Lanche'
            when 'oferta' then 'Ofertas'
            when 'ofertas' then 'Ofertas'
            else 'Lanche'
          end as category,
          case
            when lower(btrim(coalesce(product->>'category', ''))) in ('adicional', 'adicionais', 'avulso', 'avulsos', 'variedades', 'variados')
              or product->>'subcategory' = 'Adicionais' then 'Adicionais'
            when lower(btrim(coalesce(product->>'category', ''))) in ('cozinha', 'lanche', 'lanches', 'espetinho', 'espetinhos') then 'Lanches'
            when lower(btrim(coalesce(product->>'category', ''))) in ('bar', 'bebida', 'bebidas', 'dose', 'doses', 'dose/copo', 'doses/copo', 'copo') then 'Geral'
            else ''
          end as subcategory
        ) as mapped
      ),
      '[]'::jsonb
    ),
    true
  ),
  updated_at = now()
where state.id = 'main' and jsonb_typeof(state.payload->'products') = 'array';
