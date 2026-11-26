-- Códigos das planilhas das equipes (X folga, FC, FP, AT, XX, BH, FE, F falta, NA) e turnos com versões por data.
-- Carga da Manutenção do JML a partir das planilhas do Willian ("Nova escala DEZEMBRO .xlsx" e "Escala atualizada JANEIRO.xlsx").

alter table esc_turnos drop constraint if exists esc_turnos_sigla_check;
alter table esc_turnos add constraint esc_turnos_sigla_check
  check (sigla ~ '^[A-Z0-9]{1,3}$' and sigla not in ('X', 'FC', 'FP', 'AT', 'XX', 'BH', 'FE', 'F', 'NA', 'AF'));
alter table esc_turnos add column if not exists desde date, add column if not exists ate date;
alter table esc_turnos drop constraint if exists esc_turnos_predio_id_sigla_key;
create unique index if not exists esc_turnos_versao on esc_turnos (predio_id, sigla, coalesce(desde, '0001-01-01'::date));

-- esc_turno_salvar: grava desde/ate; o líder (montador) cria e edita turnos só do departamento dele
create or replace function esc_turno_salvar(p_pin text, p_predio text, p jsonb) returns json
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios; t esc_turnos;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(u.papel in ('admin', 'aprovador') or (u.papel = 'montador' and exists (
    select 1 from jsonb_array_elements_text(p->'departamentos') d where d = u.departamento) and jsonb_array_length(p->'departamentos') = 1));
  if nullif(p->>'id', '') is null then
    insert into esc_turnos (predio_id, sigla, nome, inicio, fim, inicio_fds, fim_fds, intervalo_min, departamentos, ordem, desde, ate)
    values (p_predio, upper(trim(p->>'sigla')), trim(p->>'nome'), (p->>'inicio')::time, (p->>'fim')::time,
            nullif(p->>'inicio_fds', '')::time, nullif(p->>'fim_fds', '')::time, (p->>'intervalo_min')::int,
            array(select jsonb_array_elements_text(p->'departamentos')),
            coalesce((select max(ordem) + 1 from esc_turnos where predio_id = p_predio), 0),
            nullif(p->>'desde', '')::date, nullif(p->>'ate', '')::date)
    returning * into t;
  else
    select * into t from esc_turnos where id = (p->>'id')::bigint and predio_id = p_predio;
    if t.id is null then raise exception 'Turno não encontrado' using errcode = 'P0001'; end if;
    if u.papel = 'montador' and not (t.departamentos = array[u.departamento]) then raise exception 'Sem permissão' using errcode = 'P0001'; end if;
    update esc_turnos set sigla = upper(trim(p->>'sigla')), nome = trim(p->>'nome'), inicio = (p->>'inicio')::time, fim = (p->>'fim')::time,
      inicio_fds = nullif(p->>'inicio_fds', '')::time, fim_fds = nullif(p->>'fim_fds', '')::time, intervalo_min = (p->>'intervalo_min')::int,
      departamentos = array(select jsonb_array_elements_text(p->'departamentos')), ativo = coalesce((p->>'ativo')::boolean, true),
      desde = nullif(p->>'desde', '')::date, ate = nullif(p->>'ate', '')::date
    where id = t.id returning * into t;
  end if;
  return row_to_json(t);
end $$;

-- JML: M/I/T ficam para Recepção e Governança; Manutenção com os horários da planilha (versão antiga até 15/12, nova a partir de 16/12)
update esc_turnos set departamentos = '{recepcao,governanca}' where predio_id = 'jml' and sigla in ('M', 'I', 'T');
insert into esc_turnos (predio_id, sigla, nome, inicio, fim, intervalo_min, departamentos, ordem, desde, ate) values
  ('jml', '07', 'Manhã 7h',  '07:00', '16:00', 60, '{manutencao}', 10, null, '2026-12-15'),
  ('jml', '07', 'Manhã 7h',  '07:00', '16:24', 60, '{manutencao}', 10, '2026-12-16', null),
  ('jml', '08', 'Manhã 8h',  '08:00', '17:24', 60, '{manutencao}', 11, '2026-12-16', null),
  ('jml', '09', 'Manhã 9h',  '09:00', '18:00', 60, '{manutencao}', 12, null, '2026-12-15'),
  ('jml', '10', 'Inter 10h', '10:00', '19:00', 60, '{manutencao}', 13, null, '2026-12-15'),
  ('jml', '10', 'Inter 10h', '10:00', '19:24', 60, '{manutencao}', 13, '2026-12-16', null),
  ('jml', '12', 'Inter 12h', '12:00', '21:00', 60, '{manutencao}', 14, null, '2026-12-15'),
  ('jml', '12', 'Inter 12h', '12:00', '21:24', 60, '{manutencao}', 14, '2026-12-16', null);

insert into esc_funcionarios (predio_id, departamento, nome, cargo, turno_padrao, ordem) values
  ('jml', 'manutencao', 'Willian', 'Líder de Manutenção', '08', 0),
  ('jml', 'manutencao', 'Claudemir', 'Manutencista', '07', 1),
  ('jml', 'manutencao', 'Jose Carlos', 'Manutencista', '10', 2),
  ('jml', 'manutencao', 'Márcio', 'Manutencista', '12', 3);

-- As grades de dez/2026 e jan/2027 foram gravadas como rascunho em esc_escalas (salvo_por = 'Importado da planilha do Willian'),
-- convertendo cada horário da planilha na sigla pela hora de entrada (ex.: "07–16" e "07-16:24" → 07).
