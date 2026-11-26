-- Layout igual às planilhas das equipes (pedido do Gustavo em 26/11/2026):
-- seções (CAMAREIRA, ROUPARIA, EQUIPE ASG, GOVERNANTA; LÍDER, MANUTENCISTA) e como aparece o dia de trabalho no horário da pessoa
-- (esc_config.celula: 'vazio' = em branco, como a planilha da Governança; 'horario' = "09–18", como a da Manutenção).
alter table esc_funcionarios add column if not exists secao text;
alter table esc_config add column if not exists celula text not null default 'vazio' check (celula in ('vazio', 'horario'));
insert into esc_config (predio_id, departamento, celula) select id, 'manutencao', 'horario' from gov_predios
on conflict (predio_id, departamento) do update set celula = 'horario';

update esc_funcionarios f set secao = x.secao, ordem = x.ordem from (values
  ('Solange', 'CAMAREIRA', 10), ('Maria da Glória', 'CAMAREIRA', 11), ('Kezia', 'CAMAREIRA', 12), ('Gislene', 'CAMAREIRA', 13),
  ('Cooperada 1', 'CAMAREIRA', 14), ('Cooperada 2', 'CAMAREIRA', 15), ('Nilza', 'CAMAREIRA', 16), ('Lussamia', 'CAMAREIRA', 17),
  ('Zile', 'CAMAREIRA', 18), ('Edinalva', 'CAMAREIRA', 19), ('Zenilde', 'CAMAREIRA', 20), ('Maria Bezerra', 'CAMAREIRA', 21),
  ('Zilma', 'CAMAREIRA', 22), ('Norma', 'CAMAREIRA', 23), ('Maria Gilda', 'ROUPARIA', 24), ('Mayari', 'ROUPARIA / SUPERVISORA', 26),
  ('Kelly', 'EQUIPE ASG', 31), ('Julia', 'EQUIPE ASG', 32), ('Miriam', 'EQUIPE ASG', 33), ('Eva', 'GOVERNANTA', 37)
) x(nome, secao, ordem) where f.predio_id = 'jml' and f.departamento = 'governanca' and f.nome = x.nome;
update esc_funcionarios set secao = case when nome = 'Willian' then 'LÍDER' else 'MANUTENCISTA' end where predio_id = 'jml' and departamento = 'manutencao';
update esc_funcionarios set secao = case
    when cargo ilike 'camareira%' then 'CAMAREIRA' when cargo ilike 'asg%' then 'EQUIPE ASG'
    when cargo ilike '%rouparia%' then 'ROUPARIA' else upper(coalesce(cargo, 'EQUIPE')) end
where secao is null;

-- esc_dados devolve config.celula; esc_config_celula(p_pin, p_predio, p_dep, p_celula) muda o estilo;
-- esc_funcionario_salvar grava secao (e põe a pessoa nova no fim da ordem). Ver as funções no banco.
