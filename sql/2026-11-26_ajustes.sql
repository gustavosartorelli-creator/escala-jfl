-- Ajustes aplicados depois de 2026-11-26_escalas.sql (mesmo dia)

-- 1) Sigla X reservada ("não se aplica"); esc_dados devolve também os inativos (para mostrar quem saiu e ainda está na grade)
alter table esc_turnos drop constraint if exists esc_turnos_sigla_check;
alter table esc_turnos add constraint esc_turnos_sigla_check check (sigla ~ '^[A-Z0-9]{1,3}$' and sigla not in ('F', 'FE', 'AF', 'X'));

-- 2) Departamento fechado no domingo (Governança e Manutenção não funcionam aos domingos)
alter table esc_config add column if not exists fecha_domingo boolean;
insert into esc_config (predio_id, departamento, fecha_domingo)
select p.id, d.dep, true from gov_predios p cross join (values ('governanca'), ('manutencao')) d(dep)
on conflict (predio_id, departamento) do update set fecha_domingo = excluded.fecha_domingo;
insert into esc_config (predio_id, departamento, fecha_domingo)
select p.id, 'recepcao', false from gov_predios p on conflict do nothing;

create or replace function esc_dados(p_pin text, p_predio text, p_mes date) returns json
language plpgsql stable security definer set search_path = public as $$
declare u esc_usuarios;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  return json_build_object(
    'turnos', coalesce((select json_agg(t order by t.ordem, t.sigla) from esc_turnos t where t.predio_id = p_predio and t.ativo), '[]'),
    'funcionarios', coalesce((select json_agg(f order by f.departamento, f.ordem, f.nome) from esc_funcionarios f
                              where f.predio_id = p_predio), '[]'),
    'config', coalesce((select json_object_agg(c.departamento, json_build_object('cobertura', c.cobertura, 'fecha_domingo', coalesce(c.fecha_domingo, false)))
                        from esc_config c where c.predio_id = p_predio), '{}'),
    'escalas', coalesce((select json_agg(json_build_object('id', e.id, 'departamento', e.departamento, 'status', e.status,
                           'resumo', e.resumo, 'motivo', e.motivo, 'salvo_por', e.salvo_por, 'salvo_em', e.salvo_em,
                           'enviada_por', e.enviada_por, 'enviada_em', e.enviada_em, 'aprovada_por', e.aprovada_por, 'aprovada_em', e.aprovada_em))
                         from esc_escalas e where e.predio_id = p_predio and e.mes = date_trunc('month', p_mes)::date), '[]'));
end $$;

drop function if exists esc_config_salvar(text, text, text, jsonb);
create or replace function esc_config_salvar(p_pin text, p_predio text, p_dep text, p_cobertura jsonb, p_fecha_domingo boolean default null) returns void
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(esc__pode_montar(u, p_dep));
  insert into esc_config (predio_id, departamento, cobertura, fecha_domingo) values (p_predio, p_dep, coalesce(p_cobertura, '{}'), coalesce(p_fecha_domingo, false))
  on conflict (predio_id, departamento) do update
    set cobertura = coalesce(p_cobertura, esc_config.cobertura), fecha_domingo = coalesce(p_fecha_domingo, esc_config.fecha_domingo);
end $$;
grant execute on function esc_config_salvar(text, text, text, jsonb, boolean) to anon, authenticated;

alter function esc__exige(boolean) set search_path = public;
alter function esc__pode_montar(esc_usuarios, text) set search_path = public;
alter function esc__predio(esc_usuarios, text) set search_path = public;

-- 3) Acessos iniciais (feito por SQL, sem PIN no repositório): cada pessoa usa o MESMO PIN que já tem no app de Governança
--    (Gerentes Gerais e governantas; Henrique, Gerente Assistente da Recepção do AVNU) ou no de Orçamento (Gustavo, admin;
--    Willian e Graciele, Manutenção). Os PINs foram copiados entre tabelas, sem aparecer em lugar nenhum.
