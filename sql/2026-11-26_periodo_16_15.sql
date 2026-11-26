-- Premissas JFL (Premissas_Escalas_5x2_JFL.pdf, nov/2026), item 07: a escala vai do dia 16 ao dia 15 do mês seguinte.
-- esc_escalas.mes passa a ser o INÍCIO do período (dia 16). As escalas por mês (dia 1) foram convertidas juntando os dias.
alter table esc_escalas drop constraint if exists esc_escalas_mes_check;

with dias as (
  select e.predio_id, e.departamento, p.key fid, d.key::date dia, d.value cod, e.turnos, e.salvo_por
  from esc_escalas e cross join lateral jsonb_each(e.grade) p cross join lateral jsonb_each(p.value) d
  where extract(day from e.mes) = 1
), per as (
  select *, (case when extract(day from dia) >= 16 then date_trunc('month', dia) else date_trunc('month', dia) - interval '1 month' end + interval '15 days')::date inicio
  from dias
), g as (
  select predio_id, departamento, inicio, jsonb_object_agg(fid, x) grade, max(salvo_por) salvo_por, (array_agg(turnos))[1] turnos
  from (select predio_id, departamento, inicio, fid, jsonb_object_agg(dia::text, cod) x, max(salvo_por) salvo_por, (array_agg(turnos))[1] turnos
        from per group by 1, 2, 3, 4) y
  group by 1, 2, 3
), del as (
  delete from esc_escalas where extract(day from mes) = 1 returning id
)
insert into esc_escalas (predio_id, departamento, mes, grade, turnos, salvo_por, salvo_em)
select predio_id, departamento, inicio, grade, turnos, salvo_por, now() from g;

alter table esc_escalas add constraint esc_escalas_mes_check check (extract(day from mes) = 16);

-- Início do período que contém uma data
create or replace function esc__periodo(p date) returns date
language sql immutable as $$
  select (case when extract(day from p) >= 16 then date_trunc('month', p) else date_trunc('month', p) - interval '1 month' end + interval '15 days')::date
$$;

-- esc_dados, esc_escala e esc_salvar passaram a usar esc__periodo(p_mes) no lugar de date_trunc('month', p_mes)
-- (ver as funções no banco). A escala anterior é o período que começa um mês antes.
