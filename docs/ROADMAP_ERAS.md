# Roadmap: eras, minigames e progressão

Plano em fases do pacote "eras + minigames". Cada fase fecha uma rodada jogável
(com teste e fotos) antes da próxima.

## Base comum (Fase 1 — feita)

- **Minigames como cenas separadas** (`scenes/minigames/*.tscn`): a estação chama
  `Minigame.play(jogador, "forge", contexto, callback)` e recebe a **qualidade 0–1**
  (`-1` = desistiu, nada é gasto). Qualidade vai no item (`q` no slot): dano
  ×0,85…1,2 e desgaste ×1,3…0,7. Aparece na dica do item.
- **Interface de itens nas estações com minigame**: os lugares da estação são um
  "baú" do mundo (host guarda; todos veem o mesmo). Arrasta da mochila, escolhe a
  receita e clica no botão do minigame.
- **Eras com aviso estilo conquista**: cada era tem objetivos; completar os
  objetivos-chave abre a próxima era (aviso grande + som). Não trava conteúdo:
  quem trava são os manuais.
- **Diário do jogador** (tecla **J**): era atual e objetivos (guia de quest),
  receitas descobertas por estação (árvore de receitas), manuais lidos e o que
  liberam, pistas (rádio, manuais).
- **Manuais** (achados em casas, ruínas e airdrops): clique com o manual na mão
  para ler. Liberam receitas/estações (igual aos livros de pesquisa do SevTech).
  O livro continua na mochila (dá para emprestar a outro jogador).
- **Forja a carvão com bigorna** (Era 1): metal + carvão nos lugares, escolhe a
  peça, minigame de **temperatura por cor** (shader que interpola a cor do metal
  pela temperatura). Bate só na faixa certa; fora dela racha (3 rachaduras = peça
  perdida, sobra sucata).
- **Trefiladora** (sem minigame): barra de cobre vira fio de cobre com eixo/motor.
  Fio de cobre rende mais cabo e bobina.

## Fase 2 — Mecânica e metal (Era 2)

- Bronze (cobre + estanho; estanho novo nos minérios) e ligas na fornalha.
- **Moldagem/fundição 3D**: cadinho na máquina, inclinar com o mouse; rápido
  transborda, devagar solidifica antes de encher. Moldes (lingote, engrenagem,
  cabeça de machado).
- **Bancada de solda** (manual de soldagem): só armaduras. Cursor seguindo a
  junta com velocidade constante; rápido demais = solda fraca.
- Tornos e serras manuais com qualidade.

## Fase 3 — Elétrica 2 (Era 3)

- **Voltagem**: redes 12 V (baterias) e 110 V (banco); aparelho na tensão errada
  queima ou não liga.
- **Carregador de baterias** e **banco de baterias** com desgaste (ciclos) e risco
  de sobrecarga (estufa, vaza, pega fogo).
- Bancada de eletrônicos (futuro): módulo de controle e módulo de temperatura
  (máquinas mantêm a temperatura sozinhas).

## Fase 4 — Química e refino (Era 4)

- **Estação química** com válvulas e indicadores: cada receita pede um ajuste
  (vazão, temperatura, pressão) dentro de uma faixa; a qualidade vem de quão
  perto do alvo ficou.
- Destilar combustível, pólvora (munição), plásticos simples, ácido para baterias.
- **Contaminação por zona**: ruínas contaminadas pedem **máscara de gás** (filtro
  dura alguns minutos reais); portões naturais de exploração.

## Fase 5 — Reconstrução (Era 5)

- **Rádio 2**: sintonizar no ruído, decodificar Morse, triangular o sinal com duas
  leituras em lugares diferentes e marcar a origem no mapa.
- **Cofres e portas de ruínas**: combinação por som, chave improvisada ou cortar a
  dobradiça com maçarico (escolher o método é parte do puzzle).
- **Veículos restauráveis**: projeto em partes (motor, rodas, bateria,
  combustível); alguns vêm com peças inteiras; peças retiráveis (motor vira
  gerador).
- Contato com outras comunidades (pedidos maiores, troca).

## Eras

| Era | Nome | Objetivos-chave (abrem a próxima) |
|---|---|---|
| 0 | Sobrevivente | sucata, ferramenta improvisada, fogueira |
| 1 | Ferreiro de sucata | forja a carvão, barra de ferro, primeira peça forjada |
| 2 | Mecânica | roda d'água ou moinho de vento, serraria ou torno |
| 3 | Eletrificação | dínamo ou painel solar, bateria |
| 4 | Química/refino | destilaria, álcool |
| 5 | Reconstrução | rádio, pedido entregue (veículos na Fase 5) |
