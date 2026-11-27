-- Portaria (terceirizada): só a lista de plantão dos fins de semana, para divulgar. Sem regras.
-- A Sara importa toda semana (Word .docx ou texto colado); admin e aprovador também. Todos veem.
create table if not exists esc_portaria (
  id bigserial primary key,
  predio_id text not null references gov_predios(id),
  data date not null,
  periodo text not null default 'diurno' check (periodo in ('diurno', 'noturno')),
  nome text, posto text, horario text, obs text,
  ordem int not null default 0,
  criado_por text,
  criado_em timestamptz not null default now()
);
create index if not exists esc_portaria_data on esc_portaria (predio_id, data);
alter table esc_portaria enable row level security;

alter table esc_usuarios add column if not exists portaria boolean not null default false;
update esc_usuarios set portaria = true where nome = 'Sara' and predio_id = 'jml';

-- RPCs: esc_portaria_listar(p_pin, p_predio, p_de, p_ate) → { linhas, datas, atualizado };
-- esc_portaria_salvar(p_pin, p_predio, p_linhas jsonb) substitui as datas importadas.
-- esc_login devolve "portaria" (true para quem importa); esc_usuarios_listar/esc_usuario_salvar levam o campo portaria.
-- (código completo no banco; mesma forma das demais RPCs, validando PIN e prédio)
