-- Pedido do Gustavo (26/11/2026): a primeira escala vai de 01/12/2026 a 15/01/2027 (dezembro inteiro + janeiro até 15),
-- para a equipe se acostumar; os períodos 16 → 15 começam em 16/01/2027. O período anterior a ela fica 16/11 a 30/11/2026.
-- No app: PER_ESPECIAIS (index.html). Para outro período especial, mude os dois lugares.
alter table esc_escalas drop constraint if exists esc_escalas_mes_check;

create or replace function esc__periodo(p date) returns date
language sql immutable as $$
  select case
    when p between '2026-12-01' and '2027-01-15' then '2026-12-01'::date
    else (case when extract(day from p) >= 16 then date_trunc('month', p) else date_trunc('month', p) - interval '1 month' end + interval '15 days')::date
  end
$$;

-- Junta as escalas 16/11 (dias 1–15/12) e 16/12 (16/12–15/01) no período 01/12
with dias as (
  select e.predio_id, e.departamento, p.key fid, d.key dia, d.value cod, e.turnos
  from esc_escalas e cross join lateral jsonb_each(e.grade) p cross join lateral jsonb_each(p.value) d
  where e.mes in ('2026-11-16', '2026-12-16')
), g as (
  select predio_id, departamento, jsonb_object_agg(fid, x) grade, (array_agg(turnos))[1] turnos
  from (select predio_id, departamento, fid, jsonb_object_agg(dia, cod) x, (array_agg(turnos))[1] turnos from dias group by 1, 2, 3) y
  group by 1, 2
), del as (delete from esc_escalas where mes in ('2026-11-16', '2026-12-16') returning id)
insert into esc_escalas (predio_id, departamento, mes, grade, turnos, salvo_por, salvo_em)
select predio_id, departamento, '2026-12-01', grade, turnos,
       case departamento when 'governanca' then 'Importado da planilha da Governança' else 'Importado da planilha do Willian' end, now()
from g;

alter table esc_escalas add constraint esc_escalas_mes_check check (extract(day from mes) = 16 or mes = '2026-12-01');

-- esc_escala: a escala anterior passou a ser esc__periodo(início - 1 dia) (ver a função no banco)
