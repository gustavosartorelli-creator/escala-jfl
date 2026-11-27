-- Tempo real (27/11/2026): avisos em esc_ping (Supabase Realtime) e salvamento por célula (esc_salvar_mudancas),
-- para o Gustavo e o líder editarem a mesma escala ao mesmo tempo sem atualizar o navegador e sem um apagar o outro.
create table if not exists esc_ping (
  id bigserial primary key,
  predio_id text not null,
  departamento text,
  mes date,
  tipo text not null,          -- escala | acao | dados | portaria
  por uuid,
  por_nome text,
  em timestamptz not null default now()
);
alter table esc_ping enable row level security;
drop policy if exists esc_ping_leitura on esc_ping;
create policy esc_ping_leitura on esc_ping for select to anon, authenticated using (true);
grant select on esc_ping to anon, authenticated;
alter publication supabase_realtime add table esc_ping;

-- esc__ping(p_predio, p_dep, p_mes, p_tipo, u): grava o aviso (e apaga avisos com mais de 2 dias)
-- esc_salvar_mudancas(p_pin, p_predio, p_dep, p_mes, p_mud, p_turnos): aplica só as células mudadas
--   ({ "<funcionario>": { "2027-01-05": "X", "2027-01-06": null } }) e devolve a grade combinada; avisa com tipo 'escala'.
-- Gatilhos esc__trg_ping em esc_escalas (mudança de situação), esc_funcionarios, esc_turnos, esc_config e esc_portaria.
-- (código completo no banco)
