# Escalas de trabalho (JFL): notas do projeto

## O que é
PWA para os líderes montarem a **escala mensal** de **Recepção**, **Governança** e **Manutenção**, prédio a prédio, com as regras
trabalhistas conferidas na hora. Criado em 26/11/2026 para a mudança da **EC 141/2026** (a partir de 16/12/2026: 42h por semana
e 2 folgas, a 5x2; a partir de 16/12/2027: 40h). Só os líderes entram; os funcionários recebem a escala por imagem (WhatsApp) ou impressa.

Fluxo: o líder monta (governanta na Governança, líder de manutenção na Manutenção, gerente assistente na Recepção) → **envia**
(só sem bloqueios) → o **Gerente Geral aprova ou devolve** com motivo. Aprovada só muda se for **reaberta** (volta a rascunho e
precisa de nova aprovação). Histórico em `esc_historico`.

Perfis por PIN de 4 dígitos (`esc_usuarios`, independente dos outros apps; os PINs iniciais foram copiados dos apps de Governança
e Orçamento, então cada pessoa usa o mesmo PIN que já conhece):
- **admin**: tudo, todos os prédios (Gustavo).
- **aprovador**: Gerente Geral do prédio; monta, aprova, edita turnos e cadastra acessos do prédio.
- **montador**: líder de um departamento (`departamento`); `predio_id` nulo = todos os prédios (Graciele, Manutenção).
- **visualizacao**: só vê.

## Regras (index.html: `LEI`, `REGRA`, `validar`, `checarTurno`)
Bloqueiam o envio: horas por semana acima do limite da data (semana segunda a domingo, vale a regra do domingo que fecha a semana,
então a semana de 14 a 20/12/2026 já é 42h); menos folgas que o mínimo da semana (F, FE, AF e X contam como dia sem trabalho);
mais de 6 dias seguidos; menos de 11h entre jornadas; mulher com 2 domingos seguidos trabalhados (CLT 386); turno no domingo
em departamento fechado no domingo (`esc_config.fecha_domingo`, ligado para Governança e Manutenção); dia sem marcação; pessoa sem sexo
informado; turno com intervalo ou jornada fora da CLT (art. 71 e 59).
Alertas: homem com 7 domingos seguidos; jornada acima de 8h; abaixo do mínimo de pessoas por turno (`esc_config.cobertura`).
As regras de semana, 6 dias seguidos, 11h e domingos olham também o mês anterior (`esc_escala` devolve `anterior`).
O servidor só confere o fluxo e as permissões (e que o resumo enviado tem 0 bloqueios); as regras rodam no app.

Códigos: siglas dos turnos (`esc_turnos`, por prédio) + F folga, FE férias, AF atestado/afastamento, X não se aplica (antes da admissão / após o desligamento).
Turnos iniciais em todos os prédios: **M** Manhã 07:00–15:20 (sáb/dom 08:00–16:20), **I** Intermediário 11:00–19:20, **T** Tarde 13:40–22:00,
todos com 1h de intervalo (7h20 de trabalho por dia; 5 dias = 36h40). A escala guarda uma cópia dos turnos (`esc_escalas.turnos`) ao salvar.

## Onde está cada coisa
- **App:** `index.html` (HTML, CSS e JS num arquivo só). Sem service worker. Imagem para WhatsApp com html2canvas (cdnjs, carregado só ao usar).
- **Banco:** o mesmo Supabase dos outros apps (`zzppioqshjiltllfpttg`), tabelas `esc_`. Prédios em `gov_predios`.
  RLS ligado sem acesso direto; só RPCs `SECURITY DEFINER` que validam o PIN: esc_login, esc_dados, esc_escala, esc_salvar, esc_acao
  (enviar/aprovar/devolver/reabrir), esc_funcionario_salvar, esc_turno_salvar, esc_config_salvar, esc_usuarios_listar, esc_usuario_salvar.
- **Mudanças de banco:** `sql/` (uma por data).
- **Equipe:** `esc_funcionarios`. A Governança foi importada do app de governança em 26/11/2026 (camareiras, ASGs e governantas, sem o
  Gerente Geral e sem a "Cooperativa"; `gov_usuario_id` guarda a origem). Recepção e Manutenção começam vazias. Sexo começa em branco.
- **Testar localmente:** `powershell -File .claude/serve.ps1 -Port 8791` e abrir http://localhost:8791.
- **Site:** ainda não publicado.

## Pendências
- Publicar (GitHub Pages, como o Orçamento, ou Vercel).
- Cadastrar Recepção e Manutenção (nomes, cargo, sexo) e informar o sexo de todos na Governança.
- Acessos que faltam: Recepção dos outros prédios (gerente assistente), Manutenção dos outros prédios, Gerente Geral do JML (hoje o Gustavo, admin).
- Feriados (não tratados ainda) e conferir a convenção do Sindifícios (domingo para homens, banco de horas, ampliação da jornada diária).
