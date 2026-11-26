-- Escalas de trabalho (JFL): Recepção, Governança e Manutenção montam a escala do mês; o Gerente Geral aprova.
-- Mesmo Supabase do app de governança; prédios em gov_predios; tudo com prefixo esc_.
-- As regras trabalhistas são verificadas no app (index.html, função validar); o banco controla quem pode o quê e o fluxo
-- rascunho → enviada → aprovada (ou devolvida).
-- Segurança: RLS ligado e sem acesso direto; o app só usa as RPCs abaixo, que validam o PIN.

-- ---------- Tabelas ----------
create table if not exists esc_usuarios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  titulo text,
  pin text not null unique check (pin ~ '^\d{4}$'),
  papel text not null check (papel in ('admin', 'aprovador', 'montador', 'visualizacao')),
  departamento text check (departamento in ('recepcao', 'governanca', 'manutencao')), -- obrigatório para montador
  predio_id text references gov_predios(id),                                          -- nulo = todos os prédios
  ativo boolean not null default true,
  check (papel <> 'montador' or departamento is not null),
  check (papel = 'admin' or papel = 'visualizacao' or papel = 'montador' or predio_id is not null)
);

create table if not exists esc_turnos (
  id bigserial primary key,
  predio_id text not null references gov_predios(id),
  sigla text not null check (sigla ~ '^[A-Z0-9]{1,3}$' and sigla not in ('F', 'FE', 'AF')),
  nome text not null,
  inicio time not null, fim time not null,             -- segunda a sexta
  inicio_fds time, fim_fds time,                       -- sábado e domingo (nulo = igual à semana)
  intervalo_min int not null default 60 check (intervalo_min between 0 and 180),
  departamentos text[] not null default '{recepcao,governanca,manutencao}',
  ordem int not null default 0,
  ativo boolean not null default true,
  unique (predio_id, sigla)
);

create table if not exists esc_funcionarios (
  id uuid primary key default gen_random_uuid(),
  predio_id text not null references gov_predios(id),
  departamento text not null check (departamento in ('recepcao', 'governanca', 'manutencao')),
  nome text not null,
  cargo text,
  sexo text check (sexo in ('F', 'M')),                -- F: domingo de folga a cada 15 dias (CLT art. 386)
  turno_padrao text,                                   -- sigla do turno mais comum (ajuda a preencher)
  ordem int not null default 0,
  ativo boolean not null default true,
  gov_usuario_id uuid,                                 -- de onde veio (app de governança), se veio
  criado_em timestamptz not null default now()
);
create index if not exists esc_funcionarios_predio on esc_funcionarios (predio_id, departamento);

create table if not exists esc_escalas (
  id bigserial primary key,
  predio_id text not null references gov_predios(id),
  departamento text not null check (departamento in ('recepcao', 'governanca', 'manutencao')),
  mes date not null check (extract(day from mes) = 1),
  grade jsonb not null default '{}',                   -- { "<funcionario_id>": { "2026-12-01": "M", ... } }
  turnos jsonb not null default '[]',                  -- cópia dos turnos usados quando foi salva
  status text not null default 'rascunho' check (status in ('rascunho', 'enviada', 'aprovada', 'devolvida')),
  resumo jsonb,                                        -- { bloqueios, alertas } calculados ao enviar
  motivo text,                                         -- motivo da devolução
  salvo_por text, salvo_em timestamptz,
  enviada_por text, enviada_em timestamptz,
  aprovada_por text, aprovada_em timestamptz,
  unique (predio_id, departamento, mes)
);

create table if not exists esc_config (
  predio_id text not null references gov_predios(id),
  departamento text not null,
  cobertura jsonb not null default '{}',               -- { "M": 1, "T": 1 } mínimo de pessoas por turno e dia
  primary key (predio_id, departamento)
);

create table if not exists esc_historico (
  id bigserial primary key,
  escala_id bigint not null references esc_escalas(id) on delete cascade,
  acao text not null, por text, motivo text,
  em timestamptz not null default now()
);

alter table esc_usuarios enable row level security;
alter table esc_turnos enable row level security;
alter table esc_funcionarios enable row level security;
alter table esc_escalas enable row level security;
alter table esc_config enable row level security;
alter table esc_historico enable row level security;

-- ---------- Auxiliares ----------
create or replace function esc__usuario(p_pin text) returns esc_usuarios
language plpgsql stable security definer set search_path = public as $$
declare u esc_usuarios;
begin
  select * into u from esc_usuarios where pin = p_pin and ativo;
  if u.id is null then raise exception 'PIN inválido' using errcode = 'P0001'; end if;
  return u;
end $$;

create or replace function esc__predio(u esc_usuarios, p_predio text) returns void
language plpgsql stable as $$
begin
  if p_predio is null or not (u.predio_id is null or u.predio_id = p_predio) then
    raise exception 'Sem acesso a este prédio' using errcode = 'P0001';
  end if;
end $$;

-- Pode montar/editar a escala (e a equipe) deste departamento?
create or replace function esc__pode_montar(u esc_usuarios, p_dep text) returns boolean
language sql stable as $$
  select u.papel in ('admin', 'aprovador') or (u.papel = 'montador' and u.departamento = p_dep)
$$;

create or replace function esc__exige(cond boolean) returns void
language plpgsql immutable as $$
begin
  if not cond then raise exception 'Sem permissão' using errcode = 'P0001'; end if;
end $$;

-- ---------- RPCs ----------
create or replace function esc_login(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
declare u esc_usuarios;
begin
  perform pg_sleep(0.3);
  u := esc__usuario(p_pin);
  return json_build_object('id', u.id, 'nome', u.nome, 'titulo', u.titulo, 'papel', u.papel, 'departamento', u.departamento,
    'predio', u.predio_id,
    'predios', coalesce((select json_agg(json_build_object('id', id, 'nome', nome) order by ordem) from gov_predios
                         where ativo and (u.predio_id is null or id = u.predio_id)), '[]'::json));
end $$;

-- Turnos, equipe e configuração do prédio + situação das escalas do mês
create or replace function esc_dados(p_pin text, p_predio text, p_mes date) returns json
language plpgsql stable security definer set search_path = public as $$
declare u esc_usuarios;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  return json_build_object(
    'turnos', coalesce((select json_agg(t order by t.ordem, t.sigla) from esc_turnos t where t.predio_id = p_predio and t.ativo), '[]'),
    'funcionarios', coalesce((select json_agg(f order by f.departamento, f.ordem, f.nome) from esc_funcionarios f
                              where f.predio_id = p_predio and f.ativo), '[]'),
    'config', coalesce((select json_object_agg(c.departamento, c.cobertura) from esc_config c where c.predio_id = p_predio), '{}'),
    'escalas', coalesce((select json_agg(json_build_object('id', e.id, 'departamento', e.departamento, 'status', e.status,
                           'resumo', e.resumo, 'motivo', e.motivo, 'salvo_por', e.salvo_por, 'salvo_em', e.salvo_em,
                           'enviada_por', e.enviada_por, 'enviada_em', e.enviada_em, 'aprovada_por', e.aprovada_por, 'aprovada_em', e.aprovada_em))
                         from esc_escalas e where e.predio_id = p_predio and e.mes = date_trunc('month', p_mes)::date), '[]'));
end $$;

-- Uma escala (mês) + o mês anterior (para checar semana, 11h e domingos na virada do mês)
create or replace function esc_escala(p_pin text, p_predio text, p_dep text, p_mes date) returns json
language plpgsql stable security definer set search_path = public as $$
declare u esc_usuarios; m date := date_trunc('month', p_mes)::date;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  return json_build_object(
    'escala', (select row_to_json(e) from esc_escalas e where e.predio_id = p_predio and e.departamento = p_dep and e.mes = m),
    'anterior', (select json_build_object('grade', e.grade, 'turnos', e.turnos, 'status', e.status) from esc_escalas e
                 where e.predio_id = p_predio and e.departamento = p_dep and e.mes = (m - interval '1 month')::date),
    'historico', coalesce((select json_agg(h order by h.em desc) from esc_historico h join esc_escalas e on e.id = h.escala_id
                           where e.predio_id = p_predio and e.departamento = p_dep and e.mes = m), '[]'));
end $$;

create or replace function esc_salvar(p_pin text, p_predio text, p_dep text, p_mes date, p_grade jsonb, p_turnos jsonb) returns json
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios; m date := date_trunc('month', p_mes)::date; e esc_escalas;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(esc__pode_montar(u, p_dep));
  select * into e from esc_escalas where predio_id = p_predio and departamento = p_dep and mes = m for update;
  if e.id is not null and e.status in ('enviada', 'aprovada') then
    raise exception 'A escala está %; reabra para editar', e.status using errcode = 'P0001';
  end if;
  insert into esc_escalas (predio_id, departamento, mes, grade, turnos, salvo_por, salvo_em)
  values (p_predio, p_dep, m, coalesce(p_grade, '{}'), coalesce(p_turnos, '[]'), u.nome, now())
  on conflict (predio_id, departamento, mes) do update
    set grade = excluded.grade, turnos = excluded.turnos, salvo_por = excluded.salvo_por, salvo_em = excluded.salvo_em
  returning * into e;
  return json_build_object('id', e.id, 'status', e.status, 'salvo_em', e.salvo_em);
end $$;

-- enviar (montador, só sem bloqueios), aprovar / devolver (Gerente Geral), reabrir (aprovada ou enviada volta a rascunho)
create or replace function esc_acao(p_pin text, p_escala bigint, p_acao text, p_motivo text default null, p_resumo jsonb default null) returns json
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios; e esc_escalas;
begin
  u := esc__usuario(p_pin);
  select * into e from esc_escalas where id = p_escala for update;
  if e.id is null then raise exception 'Escala não encontrada' using errcode = 'P0001'; end if;
  perform esc__predio(u, e.predio_id);
  if p_acao = 'enviar' then
    perform esc__exige(esc__pode_montar(u, e.departamento));
    if e.status not in ('rascunho', 'devolvida') then raise exception 'A escala já está %', e.status using errcode = 'P0001'; end if;
    if coalesce((p_resumo->>'bloqueios')::int, 1) > 0 then raise exception 'Corrija os bloqueios antes de enviar' using errcode = 'P0001'; end if;
    update esc_escalas set status = 'enviada', resumo = p_resumo, motivo = null, enviada_por = u.nome, enviada_em = now(),
      aprovada_por = null, aprovada_em = null where id = e.id;
  elsif p_acao in ('aprovar', 'devolver') then
    perform esc__exige(u.papel in ('admin', 'aprovador'));
    if e.status <> 'enviada' then raise exception 'Só dá para % uma escala enviada', p_acao using errcode = 'P0001'; end if;
    if p_acao = 'devolver' and coalesce(trim(p_motivo), '') = '' then raise exception 'Informe o motivo da devolução' using errcode = 'P0001'; end if;
    if p_acao = 'aprovar' then
      update esc_escalas set status = 'aprovada', aprovada_por = u.nome, aprovada_em = now(), motivo = null where id = e.id;
    else
      update esc_escalas set status = 'devolvida', motivo = trim(p_motivo) where id = e.id;
    end if;
  elsif p_acao = 'reabrir' then
    perform esc__exige(esc__pode_montar(u, e.departamento));
    if e.status not in ('enviada', 'aprovada') then raise exception 'A escala já está aberta' using errcode = 'P0001'; end if;
    update esc_escalas set status = 'rascunho', aprovada_por = null, aprovada_em = null where id = e.id;
  else
    raise exception 'Ação inválida' using errcode = 'P0001';
  end if;
  insert into esc_historico (escala_id, acao, por, motivo) values (e.id, p_acao, u.nome, nullif(trim(coalesce(p_motivo, '')), ''));
  return (select row_to_json(x) from esc_escalas x where x.id = e.id);
end $$;

-- Funcionário: cria (sem id) ou altera; ativo = false tira da lista
create or replace function esc_funcionario_salvar(p_pin text, p_predio text, p jsonb) returns json
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios; f esc_funcionarios; dep text := p->>'departamento';
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(esc__pode_montar(u, dep));
  if coalesce(trim(p->>'nome'), '') = '' then raise exception 'Informe o nome' using errcode = 'P0001'; end if;
  if p->>'id' is null then
    insert into esc_funcionarios (predio_id, departamento, nome, cargo, sexo, turno_padrao, ativo)
    values (p_predio, dep, trim(p->>'nome'), nullif(trim(p->>'cargo'), ''), nullif(p->>'sexo', ''), nullif(p->>'turno_padrao', ''),
            coalesce((p->>'ativo')::boolean, true))
    returning * into f;
  else
    select * into f from esc_funcionarios where id = (p->>'id')::uuid and predio_id = p_predio;
    if f.id is null then raise exception 'Funcionário não encontrado' using errcode = 'P0001'; end if;
    perform esc__exige(esc__pode_montar(u, f.departamento));
    update esc_funcionarios set departamento = dep, nome = trim(p->>'nome'), cargo = nullif(trim(p->>'cargo'), ''),
      sexo = nullif(p->>'sexo', ''), turno_padrao = nullif(p->>'turno_padrao', ''), ativo = coalesce((p->>'ativo')::boolean, true)
    where id = f.id returning * into f;
  end if;
  return row_to_json(f);
end $$;

-- Turno: só Gerente Geral / admin
create or replace function esc_turno_salvar(p_pin text, p_predio text, p jsonb) returns json
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios; t esc_turnos;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(u.papel in ('admin', 'aprovador'));
  if p->>'id' is null then
    insert into esc_turnos (predio_id, sigla, nome, inicio, fim, inicio_fds, fim_fds, intervalo_min, departamentos, ordem)
    values (p_predio, upper(trim(p->>'sigla')), trim(p->>'nome'), (p->>'inicio')::time, (p->>'fim')::time,
            nullif(p->>'inicio_fds', '')::time, nullif(p->>'fim_fds', '')::time, (p->>'intervalo_min')::int,
            array(select jsonb_array_elements_text(p->'departamentos')),
            coalesce((select max(ordem) + 1 from esc_turnos where predio_id = p_predio), 0))
    returning * into t;
  else
    update esc_turnos set sigla = upper(trim(p->>'sigla')), nome = trim(p->>'nome'), inicio = (p->>'inicio')::time, fim = (p->>'fim')::time,
      inicio_fds = nullif(p->>'inicio_fds', '')::time, fim_fds = nullif(p->>'fim_fds', '')::time, intervalo_min = (p->>'intervalo_min')::int,
      departamentos = array(select jsonb_array_elements_text(p->'departamentos')), ativo = coalesce((p->>'ativo')::boolean, true)
    where id = (p->>'id')::bigint and predio_id = p_predio returning * into t;
  end if;
  return row_to_json(t);
end $$;

create or replace function esc_config_salvar(p_pin text, p_predio text, p_dep text, p_cobertura jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(esc__pode_montar(u, p_dep));
  insert into esc_config (predio_id, departamento, cobertura) values (p_predio, p_dep, coalesce(p_cobertura, '{}'))
  on conflict (predio_id, departamento) do update set cobertura = excluded.cobertura;
end $$;

-- Acessos (líderes): admin vê todos; Gerente Geral vê e cadastra os do prédio dele (menos admin)
create or replace function esc_usuarios_listar(p_pin text, p_predio text) returns json
language plpgsql stable security definer set search_path = public as $$
declare u esc_usuarios;
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(u.papel in ('admin', 'aprovador'));
  return coalesce((select json_agg(json_build_object('id', x.id, 'nome', x.nome, 'titulo', x.titulo, 'papel', x.papel,
      'departamento', x.departamento, 'predio', x.predio_id, 'ativo', x.ativo) order by x.ativo desc, x.papel, x.nome)
    from esc_usuarios x where x.predio_id = p_predio or (x.predio_id is null and u.papel = 'admin')), '[]');
end $$;

create or replace function esc_usuario_salvar(p_pin text, p_predio text, p jsonb) returns json
language plpgsql security definer set search_path = public as $$
declare u esc_usuarios; x esc_usuarios; v_pin text := nullif(trim(coalesce(p->>'pin', '')), '');
begin
  u := esc__usuario(p_pin);
  perform esc__predio(u, p_predio);
  perform esc__exige(u.papel in ('admin', 'aprovador'));
  if u.papel <> 'admin' and p->>'papel' = 'admin' then raise exception 'Sem permissão' using errcode = 'P0001'; end if;
  if v_pin is not null and exists (select 1 from esc_usuarios where pin = v_pin and id is distinct from nullif(p->>'id', '')::uuid) then
    raise exception 'Este PIN já está em uso; escolha outro' using errcode = 'P0001';
  end if;
  if nullif(p->>'id', '') is null then
    if v_pin is null then raise exception 'Informe o PIN' using errcode = 'P0001'; end if;
    insert into esc_usuarios (nome, titulo, pin, papel, departamento, predio_id)
    values (trim(p->>'nome'), nullif(trim(p->>'titulo'), ''), v_pin, p->>'papel', nullif(p->>'departamento', ''), p_predio)
    returning * into x;
  else
    select * into x from esc_usuarios where id = (p->>'id')::uuid;
    if x.id is null or (u.papel <> 'admin' and (x.predio_id is distinct from p_predio or x.papel = 'admin')) then
      raise exception 'Sem permissão' using errcode = 'P0001';
    end if;
    update esc_usuarios set nome = trim(p->>'nome'), titulo = nullif(trim(p->>'titulo'), ''), pin = coalesce(v_pin, pin),
      papel = p->>'papel', departamento = nullif(p->>'departamento', ''), ativo = coalesce((p->>'ativo')::boolean, true)
    where id = x.id returning * into x;
  end if;
  return json_build_object('id', x.id);
end $$;

revoke all on function esc__usuario(text), esc__predio(esc_usuarios, text), esc__pode_montar(esc_usuarios, text), esc__exige(boolean) from public, anon, authenticated;
grant execute on function esc_login(text), esc_dados(text, text, date), esc_escala(text, text, text, date),
  esc_salvar(text, text, text, date, jsonb, jsonb), esc_acao(text, bigint, text, text, jsonb),
  esc_funcionario_salvar(text, text, jsonb), esc_turno_salvar(text, text, jsonb), esc_config_salvar(text, text, text, jsonb),
  esc_usuarios_listar(text, text), esc_usuario_salvar(text, text, jsonb) to anon, authenticated;

-- ---------- Carga inicial ----------
-- Turnos da JFL em todos os prédios: Manhã 07:00–15:20 (sáb/dom 08:00–16:20), Intermediário 11:00–19:20, Tarde 13:40–22:00; 1h de intervalo.
insert into esc_turnos (predio_id, sigla, nome, inicio, fim, inicio_fds, fim_fds, intervalo_min, ordem)
select p.id, t.sigla, t.nome, t.ini::time, t.fim::time, t.ini_fds::time, t.fim_fds::time, 60, t.ordem
from gov_predios p cross join (values
  ('M', 'Manhã', '07:00', '15:20', '08:00', '16:20', 0),
  ('I', 'Intermediário', '11:00', '19:20', null, null, 1),
  ('T', 'Tarde', '13:40', '22:00', null, null, 2)) t(sigla, nome, ini, fim, ini_fds, fim_fds, ordem)
on conflict (predio_id, sigla) do nothing;

-- Equipe da governança vinda do app de governança (camareiras, ASGs e governantas; sem o Gerente Geral). Sexo fica em branco:
-- o líder confirma no app (a regra do domingo a cada 15 dias depende disso).
insert into esc_funcionarios (predio_id, departamento, nome, cargo, turno_padrao, gov_usuario_id)
select g.predio_id, 'governanca', g.nome,
       coalesce((select c.nome from gov_cargos c where c.id = g.cargo_id), case g.papel when 'camareira' then 'Camareira' when 'asg' then 'ASG' else 'Governanta' end),
       null, g.id
from gov_usuarios g
where g.ativo and g.predio_id is not null and g.papel in ('camareira', 'asg', 'governanta') and not coalesce(g.gerente, false)
  and g.nome !~* 'cooperativa'
  and not exists (select 1 from esc_funcionarios f where f.gov_usuario_id = g.id);
