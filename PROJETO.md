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
  Com `predio_id` nulo aprova em todos os prédios: Rafaela (Superintendente de Operações), desde 26/11/2026 (a restrição que exigia prédio foi tirada).
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
Governança do JML: dez/2026 e jan/2027 atualizados em 27/11/2026 por "ESCALA - GOVERNANÇA - 2026 (2).xlsx" (Downloads; a aba de janeiro
começa com uma coluna do dia 31/12; "XF" = X; a Norma não está na planilha e foi mantida). Antes, importados de "(1).xlsx" como rascunho (ver `sql/2026-11-26_governanca_jml.sql`).
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

## Premissas da JFL (Premissas_Escalas_5x2_JFL.pdf, nov/2026) — como estão no app
- **Transição: escala de dezembro (01 a 31/12/2026) e escala de janeiro (01 a 15/01/2027), separadas** (pedido do Gustavo, para a equipe
  se acostumar); antes, 16/11 a 30/11/2026.
  Os períodos 16 → 15 começam em 16/01/2027. App: `PER_ESPECIAIS`; banco: `esc__periodo`.
- **Período 16 → 15** (item 07): `esc_escalas.mes` = dia 16 de início; no app `MES` guarda o início, `fimPer`, `perAnterior`, `nomePer`
  ("DEZEMBRO - JANEIRO 2027", como as abas antigas da planilha). A escala anterior entra na conferência (semanas, dias seguidos, 11h, domingos).
- Jornada 42h, 8h24 + 1h de intervalo (item 01): alerta só acima de 8h24/dia (`REGRA.jornadaNormal`).
- 2 folgas regulares por semana (02): contam só X e FP (`FOLGA_REGULAR`); FE/AT/F/NA reduzem o que falta; **FC, BH e XX não substituem** (05).
- Dias seguidos (03): 6 = alerta, 7+ = bloqueio (`diasSeguidosIdeal` / `diasSeguidosMax`).
- Domingos (04): mulher quinzenal, homem 1 a cada 4 semanas — os dois **bloqueiam** (Gustavo confirmou em 26/11/2026, seguindo o "garantir" das premissas).
  Os domingos contam a partir de 16/12/2026.
- Feriado trabalhado (05): alerta pedindo FC no período.
- Equalização (06): referência = domingos + sábados a partir de 16/12/2026 (conta do Gustavo: dezembro = 4 domingos + sábados 19 e 26 = 6).
  O X no dia de feriado é o descanso do feriado: não entra nas folgas regulares e reduz o mínimo daquela semana; quem trabalha no feriado ganha FC.
- Cobertura (08): mínimo por turno na aba Turnos (alerta).

## Decisões do Gustavo (26 e 27/11/2026)
- **A semana vai de DOMINGO a SÁBADO** (como as equipes contam; 27/11/2026). inicioSemana() no app; a regra da semana é a do domingo que a abre.
  Semana de transição: 13 a 19/12/2026 (regra antiga + alerta); 42h e 2 folgas a partir de 20/12/2026. Alerta de 6 dias seguidos só na 5x2.
- **Por enquanto só o JML faz escala no app.** Tudo o que o Gustavo disser sobre equipes e regras vale para o JML; os outros prédios
  ficam como estão (equipe da Governança importada, sem sexo preenchido). No JML: Governança toda feminina, Manutenção toda masculina.
- Semana de transição 14–20/12/2026 (a lei muda na quarta): segue a regra antiga (44h, 1 folga; excesso = alerta de hora extra), com um alerta
  lembrando; 42h e 2 folgas a partir de 21/12/2026. No código: a semana usa a regra do domingo que a abre (`regraEm(ds[0])`).
- Domingo das mulheres (CLT 386) é **alerta**, não bloqueio, e os domingos só contam a partir de 16/12/2026 (`REGRA.domingoDesde`).
- Escala só tem funcionário fixo registrado: as Cooperadas 1 e 2 do JML foram desativadas e tiradas de dez/jan (as linhas sem nome da planilha
  eram vagas, não cooperadas). A opção `esc_funcionarios.sem_regras` ("Cooperada / não CLT" na Equipe) continua no app, sem uso.
- Mês escrito em maiúsculas e negrito acima da escala, com setas ‹ › para o mês anterior e o seguinte.
- **A grade tem de parecer a planilha da equipe** ("a ideia é só facilitar fazer a escala sem erros"): nada de siglas (C, A3…) na tela.
  `tabelaEscala()` monta, para a tela e para a imagem/impressão: seções (`esc_funcionarios.secao`, ordem em `SECOES`), colunas HORÁRIO e
  APÓS dd/mm (quando o horário muda no mês; o horário de cada pessoa é o mais usado nos dias de trabalho), dias com D/SE/T/Q/Q/SEX/S,
  dia de trabalho no horário da pessoa em branco (Governança) ou escrito "09–18" (Manutenção) conforme `esc_config.celula`, verde-claro;
  outro horário escrito; X/BH/FE…; fim de semana cinza-azulado; feriado pêssego; rodapé Manhã/Inter/Tarde/Total no dia (até 9h59, 10h–12h59,
  a partir de 13h) e totais Trab., X, BH… à direita. As siglas ficam só por dentro (banco e aba Turnos).
  Folgas previstas no mês (`folgasPrevistas`, conta do Gustavo): para cada domingo do mês, as folgas da semana (1 na 6x1, 2 na 5x2) + feriados
  fora do domingo. Coluna "Folgas de N" conta X, FC, FP, XX e BH: verde = bate, amarelo = menos, cinza = mais; sem cor para quem teve FE, AT, F ou NA.
  A semana que cruza a virada do mês conta no mês do domingo, então dezembro tende a dar "a mais" (ex.: BH em 31/12 é folga da semana de 28/12 a 03/01).
  A paleta tem "Trabalha" (horário da pessoa), os outros horários escritos e os códigos. Escala nova já vem preenchida com o horário de cada pessoa
  (o líder só marca as folgas), como a planilha em branco.
- Márcio (JML) em 22→23/01/2027: só 10h36 entre 12–21:24 e 08:00 (bloqueio; o Willian precisa trocar).
- Cadastrar Recepção e Manutenção (nomes, cargo, sexo) e informar o sexo de todos na Governança.
- Acessos que faltam: Recepção dos outros prédios (gerente assistente), Manutenção dos outros prédios, Gerente Geral do JML (hoje o Gustavo, admin).
- Feriados (não tratados ainda) e conferir a convenção do Sindifícios (domingo para homens, banco de horas, ampliação da jornada diária).

## Atualizações de 27/11/2026
- **Recepção do JML** (imagens que o Gustavo mandou): Marlon Ribeiro (Sr., I), Yasmin Cubas, Ingridy Ribeiro (Jr., M), Mayara Gesteira, Lucas Henrique (Jr., T);
  dezembro e janeiro transcritos como rascunho. Turnos da Recepção a partir de 16/12/2026 (8h24 + 1h): **M 07:00–16:24** (sáb/dom 08:00–17:24; fica a mais),
  **I 09:56–19:20** (entra mais cedo), **T 12:36–22:00** (entra mais cedo); até 15/12 os horários antigos.
- Coluna HORÁRIO = horário cadastrado da pessoa (	urno_padrao); célula em branco/verde = esse turno (também no fim de semana).
- **Excel** (botão ao lado de Imagem e PDF): aixarExcel() monta a mesma grade de 	abelaEscala() com cores, via xlsx-js-style@1.2.0 (jsdelivr, carregado só ao usar).
- Acessos: Sara (Analista Administrativa, só consulta JML, PIN do Orçamento); Rafaela (Superintendente de Operações, aprova, todos os prédios, PIN da Governança);
  Rodrigo Pazetto (só consulta JML, PIN da Governança). Eva mantém o PIN da Governança.
## Portaria (27/11/2026)
- Aba **Portaria**: a portaria é terceirizada e a empresa manda só a escala dos **fins de semana** (Word). Mostra sexta a segunda em volta do sábado
  escolhido (setas por fim de semana), por dia e período (diurno/noturno): nome, posto, horário, observação. Imagem (WhatsApp) e impressão. Sem regras.
- Quem importa: esc_usuarios.portaria (Sara) + admin e aprovador. Importar: arquivo .docx (lido com mammoth 1.6.0 do cdnjs) ou texto colado;
  lerPortaria() reconhece "Sábado dia 28 de novembro (diurno)", "Equipe (Noturna)", "Nome: posto 06h/18h", "Nome - posto - 20hrs/ 8 hrs",
  "Estacionamento: não informado" (vira posto + observação). Prévia editável antes de salvar; os dias importados substituem os anteriores.
- Tabela esc_portaria; RPCs esc_portaria_listar e esc_portaria_salvar (sql/2026-11-27_portaria.sql). Fim de semana 28–29/11/2026 já gravado (imagem do Gustavo).
- **Homem: ao menos 1 domingo de folga em cada mês do calendário** (Gustavo, 27/11/2026; substitui o '1 a cada 4 semanas' das premissas). Bloqueia; vale desde dezembro inteiro (não usa `domingoDesde`). O mês só é conferido quando todos os domingos dele estão na escala atual ou na anterior.
- Setas do período também logo acima e abaixo da grade (`navMini`).

- **Janeiro numa escala só** (27/11/2026): transição = dezembro (01–31/12), janeiro (01–31/01), fevereiro curto (01–15/02); 16 → 15 a partir de 16/02/2027 (sql/2026-11-27_janeiro_inteiro.sql; `PER_ESPECIAIS`). Recepção: intermediário a partir de 16/12 = 09:36–19:00; ordem Yasmin, Ingridy, Marlon, Mayara, Lucas.
- Rodapé Manhã/Inter/Tarde: o período do turno vem do **nome** (Manhã / Inter / Tarde) e, se o nome não disser, da hora de entrada (`periodoDe` em `tabelaEscala`). Necessário porque a tarde da Recepção entra 12:36 e o intermediário 09:36.

## Tempo real (27/11/2026)
- Duas pessoas na mesma escala veem as mudanças uma da outra em ~2 s, sem atualizar o navegador (aviso "Atualizado: X mexeu nesta escala").
- Banco: `esc_ping` (Realtime, leitura anon como `gov_ping`) + gatilhos; `esc_salvar_mudancas` aplica só as células mudadas e devolve a grade combinada
  (sql/2026-11-27_tempo_real.sql). `esc_salvar` (grade inteira) não é mais usado pelo app.
- App: `BASE` = última grade do servidor; salva `diferenca(GRADE, BASE)`; `EDIT` guarda o que a pessoa mexeu de verdade (o preenchimento automático
  não conta) para não sobrescrever a mudança de outra pessoa; `ligarTempoReal`/`tratarAvisos`/`atualizarEscalaRemota`. Ao voltar para a aba, busca de novo.- O app confere a versão publicada a cada minuto e ao voltar para a aba (`conferirVersao`) e recarrega sozinho; o canal de tempo real é religado se cair. A RPC antiga `esc_salvar` agora recusa com 'recarregue a página' (a versão antiga salvava a grade inteira e podia apagar mudanças de outra pessoa).
- Os avisos guardam a tela que mudou (`esc_ping.cliente`, `CLIENTE` no app): cada tela ignora só os próprios avisos, então a mesma pessoa em dois aparelhos também vê na hora. O 'a cada minuto' é só a conferência de versão nova do app; os dados vão em tempo real.
