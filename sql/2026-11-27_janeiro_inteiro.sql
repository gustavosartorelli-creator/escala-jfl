-- Pedido do Gustavo (27/11/2026): janeiro numa escala só. Transição: dezembro (01–31/12/2026), janeiro (01–31/01/2027),
-- fevereiro curto (01–15/02/2027); 16 → 15 a partir de 16/02/2027. Antes de dezembro: 16/11 a 30/11/2026. No app: PER_ESPECIAIS.
alter table esc_escalas drop constraint if exists esc_escalas_mes_check;

create or replace function esc__periodo(p date) returns date
language sql immutable as $$
  select case
    when p between '2026-12-01' and '2026-12-31' then '2026-12-01'::date
    when p between '2027-01-01' and '2027-01-31' then '2027-01-01'::date
    when p between '2027-02-01' and '2027-02-15' then '2027-02-01'::date
    else (case when extract(day from p) >= 16 then date_trunc('month', p) else date_trunc('month', p) - interval '1 month' end + interval '15 days')::date
  end
$$;

-- Junta 16–31/01 (escala 16/01) na escala de janeiro, pessoa por pessoa
update esc_escalas j set grade = (
  select coalesce(jsonb_object_agg(k, coalesce(j.grade -> k, '{}') || coalesce(s.grade -> k, '{}')), '{}')
  from (select jsonb_object_keys(j.grade) k union select jsonb_object_keys(s.grade)) ks
)
from esc_escalas s
where j.predio_id = s.predio_id and j.departamento = s.departamento and j.mes = '2027-01-01' and s.mes = '2027-01-16';
update esc_escalas s set mes = '2027-01-01'
where s.mes = '2027-01-16' and not exists (select 1 from esc_escalas j where j.predio_id = s.predio_id and j.departamento = s.departamento and j.mes = '2027-01-01');
delete from esc_escalas where mes = '2027-01-16';

alter table esc_escalas add constraint esc_escalas_mes_check check (extract(day from mes) = 16 or mes in ('2026-12-01', '2027-01-01', '2027-02-01'));
