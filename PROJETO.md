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
Bloqueiam o envio: horas por semana acima do limite da data (semana segunda a domingo, vale a regra da segunda-feira que abre a semana;
a semana de transição 14–20/12/2026 ainda é regra antiga, ver Decisões); menos folgas que o mínimo da semana (todo código que não é turno conta como dia sem trabalho);
mais de 6 dias seguidos; menos de 11h entre jornadas; turno no domingo
em departamento fechado no domingo (`esc_config.fecha_domingo`, ligado para Governança e Manutenção); dia sem marcação; pessoa sem sexo
informado; turno com intervalo ou jornada fora da CLT (art. 71 e 59).
Alertas: mulher com 2 domingos seguidos (CLT 386) e homem com 7 (contando a partir de 16/12/2026); semana de transição; jornada acima de 8h; abaixo do mínimo de pessoas por turno (`esc_config.cobertura`).
As regras de semana, 6 dias seguidos, 11h e domingos olham também o mês anterior (`esc_escala` devolve `anterior`).
O servidor só confere o fluxo e as permissões (e que o resumo enviado tem 0 bloqueios); as regras rodam no app.

Códigos (a legenda que as equipes já usavam nas planilhas): siglas dos turnos (`esc_turnos`, por prédio) + **X folga**, FC compensa feriado,
FP preferência de folga, XX folga aniversário, BH banco de horas, FE férias, AT atestado, **F falta**, NA não se aplica (antes da admissão /
após o desligamento). Todos contam como dia sem trabalho. Feriados (nacionais + SP) ficam em `FERIADOS` no index.html (2026–2027; acrescentar os anos seguintes).
Turnos têm **versões por data** (`desde`/`ate`): a mesma sigla muda de horário num dia (ex.: 07 = 07:00–16:00 até 15/12/2026 e 07:00–16:24
a partir de 16/12/2026). O líder cria e edita turnos só do departamento dele; o Gerente Geral, todos.
Antes de 16/12/2026 passar do limite semanal é só alerta (hora extra); depois, bloqueia.
Turnos iniciais: **M** 07:00–15:20 (sáb/dom 08:00–16:20), **I** 11:00–19:20, **T** 13:40–22:00 (Recepção e Governança; ainda os horários
da 6x1, faltam as versões a partir de 16/12, ex.: Recepção 07:00–16:24). Manutenção do JML: 07, 08, 09, 10, 12 (hora de entrada), com as
versões antiga e nova da planilha do Willian. A escala guarda uma cópia dos turnos (`esc_escalas.turnos`) ao salvar.
Manutenção do JML: dez/2026 e jan/2027 importados das planilhas do Willian (OneDrive, Área de Trabalho\Escalas\Manutenção) como rascunho.
Governança do JML: dez/2026 e jan/2027 importados de "ESCALA - GOVERNANÇA - 2026 (1).xlsx" como rascunho (ver `sql/2026-11-26_governanca_jml.sql`).
Turnos por função: C camareira, R rouparia, S supervisora de rouparia, A1/A2/A3 ASG (6h, manhã, tarde), G governanta; M/I/T no JML ficaram só para a
Recepção. A Governança do JML **não** é fechada no domingo (os ASGs trabalham). Nomes trocados para os da planilha: Sol → Solange, Glorinha → Maria da Glória,
Maria → Maria Bezerra, May → Mayari (confirmar); linhas sem nome da planilha → Cooperada 1 e 2.

## Onde está cada coisa
- **App:** `index.html` (HTML, CSS e JS num arquivo só). Sem service worker. Imagem para WhatsApp com html2canvas (cdnjs, carregado só ao usar).
- **Banco:** o mesmo Supabase dos outros apps (`zzppioqshjiltllfpttg`), tabelas `esc_`. Prédios em `gov_predios`.
  RLS ligado sem acesso direto; só RPCs `SECURITY DEFINER` que validam o PIN: esc_login, esc_dados, esc_escala, esc_salvar, esc_acao
  (enviar/aprovar/devolver/reabrir), esc_funcionario_salvar, esc_turno_salvar, esc_config_salvar, esc_usuarios_listar, esc_usuario_salvar.
- **Mudanças de banco:** `sql/` (uma por data).
- **Equipe:** `esc_funcionarios`. A Governança foi importada do app de governança em 26/11/2026 (camareiras, ASGs e governantas, sem o
  Gerente Geral e sem a "Cooperativa"; `gov_usuario_id` guarda a origem). Recepção e Manutenção começam vazias. Sexo começa em branco.
- **Testar localmente:** `powershell -File .claude/serve.ps1 -Port 8791` e abrir http://localhost:8791.
- **Site:** https://gustavosartorelli-creator.github.io/escala-jfl/ (GitHub Pages, branch `main`, pasta raiz; publica sozinho ~1 min após o commit).
- **Repositório:** https://github.com/gustavosartorelli-creator/escala-jfl (**público**, exigência do Pages gratuito; dados protegidos pelo PIN nas RPCs;
  nunca coloque PINs nos arquivos). Sem Git neste PC: envie pelo GitHub no Chrome (*Add file → Upload files*; pasta `sql/` pela URL `.../upload/main/sql`).
  O upload do Chrome só aceita arquivos de pastas da sessão: copie para uma pasta temporária dentro da pasta de trabalho, envie e apague. Não envie `.claude/`.
- Ao mudar o app, suba `VERSAO` no index.html (aparece no rodapé).

## Pendências
- Norma (nova camareira, desde 16/12) está sem janeiro: a governanta preenche.
- Maria Gilda (JML) em janeiro: a planilha só tinha 1–3; o Gustavo pediu "como dezembro" e foi preenchido R de segunda a sexta, X sábado e domingo (5x2, 42h).

## Decisões do Gustavo (26/11/2026)
- Semana de transição 14–20/12/2026 (a lei muda na quarta): segue a regra antiga (44h, 1 folga; excesso = alerta de hora extra), com um alerta
  lembrando; 42h e 2 folgas a partir de 21/12/2026. No código: a semana usa a regra da segunda-feira que a abre (`regraEm(ds[0])`).
- Domingo das mulheres (CLT 386) é **alerta**, não bloqueio, e os domingos só contam a partir de 16/12/2026 (`REGRA.domingoDesde`).
- Cooperadas ficam como estão: `esc_funcionarios.sem_regras` (opção "Cooperada / não CLT" na Equipe) tira a pessoa das regras de horas, folgas e domingos.
- Mês escrito em maiúsculas e negrito acima da escala, com setas ‹ › para o mês anterior e o seguinte.
- **A grade tem de parecer a planilha da equipe** ("a ideia é só facilitar fazer a escala sem erros"): nada de siglas (C, A3…) na tela.
  `tabelaEscala()` monta, para a tela e para a imagem/impressão: seções (`esc_funcionarios.secao`, ordem em `SECOES`), colunas HORÁRIO e
  APÓS dd/mm (quando o horário muda no mês; o horário de cada pessoa é o mais usado nos dias de trabalho), dias com D/SE/T/Q/Q/SEX/S,
  dia de trabalho no horário da pessoa em branco (Governança) ou escrito "09–18" (Manutenção) conforme `esc_config.celula`, verde-claro;
  outro horário escrito; X/BH/FE…; fim de semana cinza-azulado; feriado pêssego; rodapé Manhã/Inter/Tarde/Total no dia (até 9h59, 10h–12h59,
  a partir de 13h) e totais Trab., X, BH… à direita. As siglas ficam só por dentro (banco e aba Turnos).
  A paleta tem "Trabalha" (horário da pessoa), os outros horários escritos e os códigos. Escala nova já vem preenchida com o horário de cada pessoa
  (o líder só marca as folgas), como a planilha em branco.
- Márcio (JML) em 22→23/01/2027: só 10h36 entre 12–21:24 e 08:00 (bloqueio; o Willian precisa trocar).
- Cadastrar Recepção e Manutenção (nomes, cargo, sexo) e informar o sexo de todos na Governança.
- Acessos que faltam: Recepção dos outros prédios (gerente assistente), Manutenção dos outros prédios, Gerente Geral do JML (hoje o Gustavo, admin).
- Feriados (não tratados ainda) e conferir a convenção do Sindifícios (domingo para homens, banco de horas, ampliação da jornada diária).
