-- Pedido do Gustavo (26/11/2026): escalas separadas na transição — dezembro (01 a 31/12/2026) e janeiro (01 a 15/01/2027);
-- depois 16 → 15 a partir de 16/01/2027. Antes de dezembro: 16/11 a 30/11/2026. No app: PER_ESPECIAIS.
-- Substitui 2026-11-26_periodo_inicial_dez_jan.sql (que juntava 01/12 a 15/01 numa escala só).
alter table esc_escalas drop constraint if exists esc_escalas_mes_check;

create or replace function esc__periodo(p date) returns date
language sql immutable as $$
  select case
    when p between '2026-12-01' and '2026-12-31' then '2026-12-01'::date
    when p between '2027-01-01' and '2027-01-15' then '2027-01-01'::date
    else (case when extract(day from p) >= 16 then date_trunc('month', p) else date_trunc('month', p) - interval '1 month' end + interval '15 days')::date
  end
$$;

-- Separa a escala 01/12 (01/12 a 15/01) em dezembro e janeiro
with dias as (
  select e.predio_id, e.departamento, e.salvo_por, e.turnos, p.key fid, d.key dia, d.value cod
  from esc_escalas e cross join lateral jsonb_each(e.grade) p cross join lateral jsonb_each(p.value) d
  where e.mes = '2026-12-01' and d.key >= '2027-01-01'
), g as (
  select predio_id, departamento, max(salvo_por) salvo_por, (array_agg(turnos))[1] turnos, jsonb_object_agg(fid, x) grade
  from (select predio_id, departamento, salvo_por, turnos, fid, jsonb_object_agg(dia, cod) x from dias group by 1, 2, 3, 4, 5) y
  group by 1, 2
)
insert into esc_escalas (predio_id, departamento, mes, grade, turnos, salvo_por, salvo_em)
select predio_id, departamento, '2027-01-01', grade, turnos, salvo_por, now() from g;

update esc_escalas e set grade = (
  select coalesce(jsonb_object_agg(p.key, (select coalesce(jsonb_object_agg(d.key, d.value), '{}') from jsonb_each(p.value) d where d.key < '2027-01-01')), '{}')
  from jsonb_each(e.grade) p)
where e.mes = '2026-12-01';

alter table esc_escalas add constraint esc_escalas_mes_check check (extract(day from mes) = 16 or mes in ('2026-12-01', '2027-01-01'));

-- Acessos: aprovador pode ter predio_id nulo (aprova em todos os prédios) — Rafaela, Superintendente de Operações
alter table esc_usuarios drop constraint if exists esc_usuarios_check1;
