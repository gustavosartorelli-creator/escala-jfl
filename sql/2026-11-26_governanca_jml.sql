-- Governança do JML pela planilha "ESCALA - GOVERNANÇA - 2026 (1).xlsx" (OneDrive, Área de Trabalho\Escalas), abas DEZEMBRO e JANEIRO 27.
-- Na planilha, célula vazia = trabalha no horário da pessoa; X folga; BH banco de horas; FÉRIAS (células mescladas) = FE.
-- As células mescladas sem texto de Nilza e Mayari em 1–7/12 foram lidas como férias (continuação das férias de novembro).

update esc_turnos set departamentos = '{recepcao}' where predio_id = 'jml' and sigla in ('M', 'I', 'T');
insert into esc_turnos (predio_id, sigla, nome, inicio, fim, intervalo_min, departamentos, ordem, desde, ate) values
  ('jml', 'C',  'Camareira',               '09:00', '17:20', 60, '{governanca}', 20, null, '2026-12-15'),
  ('jml', 'C',  'Camareira',               '09:00', '18:24', 60, '{governanca}', 20, '2026-12-16', null),
  ('jml', 'R',  'Rouparia',                '08:00', '17:24', 60, '{governanca}', 21, null, null),
  ('jml', 'S',  'Supervisora de rouparia', '09:40', '18:00', 60, '{governanca}', 22, null, '2026-12-15'),
  ('jml', 'S',  'Supervisora de rouparia', '09:00', '18:24', 60, '{governanca}', 22, '2026-12-16', null),
  ('jml', 'A1', 'ASG 6h',                  '06:00', '14:20', 60, '{governanca}', 23, null, '2026-12-15'),
  ('jml', 'A1', 'ASG 6h',                  '06:00', '15:24', 60, '{governanca}', 23, '2026-12-16', null),
  ('jml', 'A2', 'ASG manhã',               '08:00', '16:20', 60, '{governanca}', 24, null, '2026-12-15'),
  ('jml', 'A2', 'ASG manhã',               '07:00', '16:24', 60, '{governanca}', 24, '2026-12-16', null),
  ('jml', 'A3', 'ASG tarde',               '13:00', '21:20', 60, '{governanca}', 25, null, '2026-12-15'),
  ('jml', 'A3', 'ASG tarde',               '12:00', '21:24', 60, '{governanca}', 25, '2026-12-16', null),
  ('jml', 'G',  'Governanta',              '08:00', '18:00', 60, '{governanca}', 26, null, '2026-12-15'),
  ('jml', 'G',  'Governanta',              '08:00', '17:24', 60, '{governanca}', 26, '2026-12-16', null);

-- Os ASGs trabalham aos domingos
update esc_config set fecha_domingo = false where predio_id = 'jml' and departamento = 'governanca';

-- Nomes da planilha (apelido no app de governança → nome na escala) e Maria Gilda (rouparia, não estava no app de governança)
update esc_funcionarios set nome = 'Solange' where predio_id = 'jml' and departamento = 'governanca' and nome = 'Sol';
update esc_funcionarios set nome = 'Maria da Glória' where predio_id = 'jml' and departamento = 'governanca' and nome = 'Glorinha';
update esc_funcionarios set nome = 'Maria Bezerra' where predio_id = 'jml' and departamento = 'governanca' and nome = 'Maria';
update esc_funcionarios set nome = 'Mayari', cargo = 'Supervisora de rouparia' where predio_id = 'jml' and departamento = 'governanca' and nome = 'May';
insert into esc_funcionarios (predio_id, departamento, nome, cargo, turno_padrao)
select 'jml', 'governanca', 'Maria Gilda', 'Rouparia', 'R'
where not exists (select 1 from esc_funcionarios where predio_id = 'jml' and departamento = 'governanca' and nome = 'Maria Gilda');
update esc_funcionarios f set turno_padrao = case f.nome when 'Mayari' then 'S' when 'Kelly' then 'A3' when 'Julia' then 'A1' when 'Miriam' then 'A2' when 'Eva' then 'G' when 'Maria Gilda' then 'R' else 'C' end
where predio_id = 'jml' and departamento = 'governanca';

-- Grades de dez/2026 e jan/2027 gravadas como rascunho (salvo_por = 'Importado da planilha da Governança').
-- As linhas 14 e 15 da planilha (sem nome) foram para Cooperada 1 e 2. Maria Gilda em janeiro só tinha 1–3 marcados: 4–31 ficaram vazios.
