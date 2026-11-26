-- Pessoas fora das regras CLT (cooperadas): só precisam ter todos os dias marcados
alter table esc_funcionarios add column if not exists sem_regras boolean not null default false;
update esc_funcionarios set sem_regras = true where predio_id = 'jml' and nome in ('Cooperada 1', 'Cooperada 2');
-- esc_funcionario_salvar passou a gravar sem_regras (ver a função no banco; mesma de 2026-11-26_escalas.sql + a coluna)

-- Norma: nova camareira do JML a partir de 16/12/2026 (1–15/12 = NA; de 16/12 em diante C, com X nos domingos e no Natal).
-- Janeiro dela ficou em branco para a governanta preencher.
insert into esc_funcionarios (predio_id, departamento, nome, cargo, sexo, turno_padrao)
select 'jml', 'governanca', 'Norma', 'Camareira', 'F', 'C'
where not exists (select 1 from esc_funcionarios where predio_id = 'jml' and nome = 'Norma');
