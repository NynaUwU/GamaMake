# Zumbi FPS — protótipo (Godot 4.7.2)

Primeira pessoa, combate corpo a corpo, zumbis com animação procedural,
reação física a golpes e ragdoll (estilo Dying Light), visual de PC dos anos 2000 em 960x540 (16:9).

## Como abrir
1. Godot 4.7.2 → **Importar** → selecione `project.godot`.
2. **F5** para rodar. Abre o **menu**: jogar sozinho, criar servidor na rede local ou entrar num.

## Multiplayer na rede local (até 32 jogadores)
- **Criar:** menu → *Multiplayer (rede local)* → *Criar servidor*. Ou, como no Minecraft, no meio
  de uma partida solo: **Esc → Abrir para LAN** (vira servidor na hora, sem recarregar).
- **Entrar:** menu → *Multiplayer*: as partidas da rede aparecem na lista (clique para entrar).
  Também dá para digitar o IP (`192.168.0.10` ou `192.168.0.10:7779`). Dá para entrar no meio.
- **Firewall:** igual ao Minecraft. Quem **entra não precisa liberar nada**: o cliente *pergunta*
  na rede "tem partida aí?" e o host responde direto para ele (resposta a uma pergunta que o
  próprio PC fez passa pelo firewall). Só o **host** recebe conexões, e o Windows pergunta uma
  vez "Permitir acesso?" para o jogo, como faz com o Java do Minecraft: clique em Permitir.
  Se a porta 7777 estiver ocupada (outro servidor no mesmo PC), usa a próxima livre.
- **Só o host** usa as teclas de admin: **Z** (zumbi), **H** (100 zumbis) e **Backspace**
  (recomeça a partida para todo mundo; também em Esc → Recomeçar). Nos outros, Backspace só
  **renasce** quando morre.
- Online o Esc **não pausa** o jogo (o mundo é de todos) e o "congelamento" dos golpes fica desligado.
- Os outros jogadores aparecem com o nome em cima, o item da mão, a lanterna acesa e uma bolinha
  azul no minimapa/mapa. Em cima, no meio da tela, aparece quem está online.

## Construções do martelo
- **Parede** de tábuas deitadas (tom por fileira, frestas, pregos), **piso** de tábuas com emendas desencontradas, **teto** de telhas em fiadas com degrau. Os detalhes só aparecem nos quadrados inteiros: cortou com a talhadeira, o detalhe sai junto.
- **Pilar** com base de pedra, cantos chanfrados, cintas de ferro e capitel. **R deita o pilar (viga)**: fica no sentido da parede à sua frente, apoiado na altura da grade; mirando o topo de uma parede, cobre o topo dela inteiro.
- **Janela:** as travessas dividem o vidro em vidraças iguais (~0,8 m) medidas pelo formato da própria janela, não pela posição na parede; em janela torta (L, losango) só aparecem onde tem vidro dos dois lados.

## Móveis e casas
- **Móveis** refeitos (pernas torneadas, portas de almofada, puxadores e dobradiças, fogão com a boca de ferro das fornalhas, cama com colcha e tapete, privada de caixa alta...). A malha de cada tipo é montada uma vez e reaproveitada (todas as camas são iguais): mobiliar uma casa não trava mais o jogo.
- **Casas da cidade:** térreo de pedra com juntas e cunhais, andares de tábua com revestimento ou de reboco com postes de canto, rodapé e rachaduras; janelas com moldura, peitoril, travessas e veneziana (as tapadas com tábuas em X); porta de tábuas com batente, degrau e alpendre; telhado com fiadas de telha, cumeeira, testeira e beiral; chaminé com chapéu; ruínas com juntas de pedra. Tudo só no desenho (a colisão é a mesma).
- `tests/bench_baked.gd` compara gerar os modelos por código com carregar modelo salvo (.scn nativo ou .glb).
- **Itens** que ainda eram simples refeitos: carnes com osso, gordura e marmoreio (assada com marca de grelha), charque amarrado com sal, pele com tufos e contorno de bicho, rolo de couro costurado, banha no pote, casaco de pele com gola e botões de osso, correia enrolada com fivela, vara com cabo de cortiça, passadores e molinete.
- **Carros:** todos ganharam buzina de latão com pera de borracha, bocal do tanque com correntinha e galão de combustível preso na lateral.

## Modelos refeitos no padrão do Tier 3
Todos os objetos do martelo anteriores ao Tier 3 foram refeitos com o mesmo nível de detalhe das máquinas a vapor (`scripts/machines/object_models.gd`): tábuas com frestas e tons alternados, fiadas de tijolo, cintas de ferro rebitadas, polias de latão nas portas de energia, fumaça só com fogo aceso e objetos de cena (lenha, ferramentas, baldes, sacos).
- Plantadores (pote com pratinho e pintura, floreira com cantoneiras, **canteiro com leiras de terra, torrões, sulcos e plaquinhas**, cova), bandeira com monte de pedras e cunho.
- Estações: mesa de trabalho (gaveteiro, painel de ferramentas, lampião), fogueira (chaleira, lenha de reserva), fornalha de barro, forno de tijolo com pães, baú, secador com pele estendida, coletor com torneira de latão, lousa (bandeja de tintas, paleta).
- Manivela: amolar, moinho (tina de aduelas), **bomba** (a alavanca agora sobe e desce), roca de pedal, **tear** (os liços sobem e descem, pano listrado), fornalha de pedra (fole que abre e fecha, cadinho, chaminé), filtro (faixas de cascalho, carvão e areia, pingando), defumador, composteira, peneira.
- Energia: eixo com mancais e copo de graxa, roda d'água (a polia de saída agora fica onde o eixo encaixa), moinho de vento (pás de treliça com lona), serraria (carrinho com tora, correia), carneiro hidráulico (câmara de ar rebitada, válvula cuspindo água).
- Armadilha de urso (molas, prato, corrente e estaca) e caixa do airdrop (tábuas com sarrafos, cintas, cantoneiras).

## Tier 3: vapor, aço e canos
Martelo → aba **Vapor**. Ordem natural: torno (ferro) → parafusos/engrenagens → alto-forno → aço → caldeira + motor a vapor.
- **Canos** (`scripts/machines/fluids.gd`, `pipe_tool.gd`): cano de cobre na mão (mesa: 1 barra de cobre = 2 canos; torno: 4). **Segure o clique** numa saída de latão (ou na ponta de um cano), arraste e **solte** onde o cano termina; clicar na ponta de um cano continua a linha. **Shift** deixa reto (no nível e em 45°). Cada 2 m gasta 1 cano, até 6 m por trecho. Bolinha amarela = encaixou numa porta. Desmontar devolve os canos.
  - **Rede de fluido** (1x por segundo no host): água e vapor são redes separadas. Fontes: carneiro hidráulico (1/s, sem fim), coletor de chuva (o que juntou), caixa d'água (o que guardou). A água que sobra vai para as caixas; faltando, elas soltam. Mirando um cano aparece o fluxo ("água 0,6/s", "vapor 1,0/s").
  - **Caixa d'água** (8 tábuas + 2 barras de ferro): guarda 60, 4 portas, [E] enche garrafa (sai suja).
  - **Aspersor** (2 cobre + 1 parafuso): com água no cano, molha as plantações a 8 m (crescem 50% mais rápido, como o carneiro).
  - **Garrafa de água na mão + clique** na caldeira, destilaria ou caixa d'água: despeja (a garrafa volta vazia).
- **Alto-forno multibloco**: a base (16 tijolos, 6 pedras, 2 barras de ferro) + **2 anéis de tijolo empilhados** (mire no topo da base para empilhar; no chão não vai). Só funciona montado inteiro e com o **fole girando** (eixo/correia com força na polia à esquerda). Só queima **carvão**. 2 barras de ferro → 1 **barra de aço** (ou 4 sucatas). Janela igual às fornalhas, com a barra do fole e o que falta montar.
- **Caldeira** (4 aço, 6 tijolos, 2 cobre, 4 parafusos): combustível em baixo, água pelo cano (latão à esquerda) ou despejada. Esquenta (~20 s), ferve e faz **pressão** (manômetro e visor de nível no modelo); a saída de vapor fica no alto do domo. Pressão no máximo: a válvula **chia** soltando vapor. **Seca e quente por 12 s: apita e EXPLODE** (6 m, machuca quem estiver perto, some com o carvão). Janela com água, calor, pressão e aviso.
- **Motor a vapor** (3 aço, 2 engrenagens, 6 parafusos, 1 eixo torneado, 1 óleo): vapor da caldeira (cano no alto do cilindro) vira **força 10** nos eixos (porta à direita). Volante girando, baforadas e "tchuc" no ritmo. Uma caldeira quente toca um motor a 100% gastando 0,15 de água por segundo.
- **Torno** (6 tábuas, 4 ferro, 2 sucatas) e **prensa** (6 tábuas, 3 ferro, 2 parafusos): bancadas que só fabricam com o **eixo girando** (puxam força só nos segundos depois de fabricar).
  - Torno: 1 ferro → 4 parafusos; 2 ferro → engrenagem; 1 aço → eixo torneado; 1 cobre → 4 canos.
  - Prensa: 3 frutas + garrafa → **suco** (+45 sede, +12 fome); 4 sementes de algodão (ou 2 gorduras) + garrafa → **óleo**.
- **Destilaria** (6 cobre, 6 tijolos, 2 canos): fogo + 1 de água por lote + 4 trigo (ou 3 frutas, ou 4 batatas) → **álcool**. 
  - **Combustível dos carros:** os carros agora têm **tanque** (começam com 25–70%, ~18 min de pé no fundo). Álcool na mão + clique no carro = +35%; óleo = +20%. Marcador V/C no painel, ao lado do velocímetro; sem combustível o motor engasga. O tanque vai no save e na rede.
  - **Antisséptico:** bandagem + álcool (mesa) = **bandagem com álcool** (+60 vida e cura a doença).
- **Itens novos:** barra de aço, parafusos, engrenagem, eixo torneado, cano, suco, óleo, álcool, bandagem com álcool (modelos próprios).

## Não cair pelo mundo e saque mais raro (rodada de feedback)
- **Descer do carro tombado ou capotado:** o jogador desce num ponto livre em volta do carro (porta, outro lado, atrás, frente, mais longe, por cima), sempre em cima do chão e só onde o corpo cabe. Antes descia dentro do terreno e caía pelo mundo. `Player._safe_exit`.
- **Barreira no fundo do mundo** (`scripts/world/world_floor.gd`): 4x por segundo, quem passou de y = -60 ou ficou mais de 4 m abaixo do terreno volta **para cima da terra** (ou boiando na água), parado. Vale para o jogador, zumbis de pé, bichos, itens no chão e carros. Item que cai onde o chão ainda não tem colisão (longe de todo mundo) fica congelado até o chão aparecer.
- **Drop de bicho não atravessa mais o chão:** o item nascia dentro da caixa do bicho morto e era empurrado para baixo. Agora o bicho sai da física antes de soltar, o item nasce acima do corpo, nunca abaixo do terreno, e com detecção contínua (não atravessa rápido).
- **Zumbis não soltam mais roupa**, e soltam bem menos: 10% uma sucata ou 8% um pano (antes 30% + 30% + 12% de roupa). Arma de zumbi: 2% (antes 4%).

## Bichos, pássaros e fazenda de animais (rodada de feedback)
- **15 espécies, todas caçáveis** (`scripts/animals/`, em blocos; `AnimalModels` monta cada uma com poucas malhas guardadas por espécie):
  - **Selvagens:** cervo, coelho, raposa e cabra (fogem); javali (revida quando apanha); **lobo** (ataca quem chega a 12 m, de noite de ~19 m, e a matilha vem junto; uiva à noite); **urso** (220 de vida, ataca quem chega a 7 m ou bate).
  - **Pássaros:** pombo, corvo, pato e gaivota andam bicando; chegou perto, **levantam voo** (batendo as asas), voam 30–55 m a ~9 m de altura e pousam. **Pato** pousa e **nada no lago**; **gaivota** plana em círculos sobre a costa. Hitbox maior: dá para acertar com tiro e lança. Soltam carne e **penas**.
  - **De criação** (selvagens na planície, em bandos): **galinha, ovelha, vaca, porco**.
  - Nascem por bioma, em grupos (rebanho de cabras na montanha, matilha na neve, patos no lago, gaivotas na costa). Cada bicho tem voz (cocoricó, béé, muu, ronco, cró, quá, uivo).
- **Fazenda:**
  - **Domesticar:** segure a comida dele na mão (galinha: qualquer semente; ovelha e vaca: trigo; porco: trigo ou legumes) e o bicho **vem atrás** (leve até o cercado). **[E]** com a comida = fica **manso**.
  - Manso fica em volta de casa (ou segue quem segura a comida, para mudar de lugar), **come no cocho** e **bebe no bebedouro** sozinho.
  - **Cria:** dois iguais **alimentados e com água**, perto um do outro, têm **filhote** (porco: 2) a cada ~15 min do relógio da fazenda. Filhote é menor e cresce em ~15 min. Sem água não cria. Até 24 mansos por fazenda.
  - **Produtos:** galinha **bota ovo** no chão (mais rápido com água); vaca: **[E] com garrafa vazia = leite**; ovelha: **[E] tosquia** (2–3 de lã; a lã cresce de novo em ~10 min se ela comer).
  - Mansos **vão no save**; os selvagens não.
- **Aba "Fazenda" do martelo:** **Cocho** (4 tábuas, 2 gravetos; baú: [E] abre), **Bebedouro** (4 tábuas, 1 barra de ferro; enche com garrafa de água, com a chuva ou por cano — tem porta de latão), **Cerca** (2,4 m: com Shift encaixa ponta com ponta na grade) e **Porteira** ([E] abre/fecha). Zumbis tratam a cerca como construção (contornam, ou quebram com 6 golpes se você está dentro).
- **Itens novos:** ovo (frite na fogueira → **ovo frito**), **leite**, **lã** (na roca: 1 lã = 1 fio), **pena**; na mesa: **gorro de lã** (3 lãs, isolamento 0,45), **casaco de lã** (6 lãs + couro, 0,8), **casaco de penas** (12 penas + 2 tecidos, 0,75).
- Teste: `tests/test_farm.gd`. Fotos: `STUDIO=animais` no `tests/studio.gd`.

## Zumbis especiais, IA nova e plantio (rodada de feedback)
- **Zumbis desviam da sua base:** se você **não está dentro** dela, o zumbi contorna paredes, portas, janelas e cercas (leque de raios, sempre pelo mesmo lado até ficar livre) em vez de quebrar. Se você **está dentro** (teto em cima, piso construído no alto, ou paredes em 6 de 8 direções), eles batem na parede como antes. Rodou 14 s sem chegar mais perto: desiste e quebra por um tempo. `Zombie.target_sheltered`, `Zombie._avoid_builds`.
- **Zumbis nadam:** em água funda boiam com a cabeça para fora (sem afundar), braços abertos, na metade da velocidade, com som de água; saem andando na margem. Também nas cópias do multiplayer.
- **Zumbis especiais** (raros: ~5% no mapa, 7% nas hordas, 5% → 16% nas ondas conforme os dias; slider **Zumbis especiais** no Criar mundo; `/especial <tipo>` cria um na sua frente). Corpos **deformados de verdade** (blocos esticados, inchados e tortos no próprio esqueleto) + pústulas, ossos saindo, papo de ácido. `scripts/enemies/zombie_special.gd`.
  - **Inchado:** barril de pústulas, lento, 50 de vida. Perto de você **vomita bile**; morto, **estoura**. Bile na cara = tela verde por 7 s, todo zumbi a 40 m vem atrás de você e chegam mais 5.
  - **Saltador:** magro, braços até o chão, quase de quatro. De 4,5 a 14 m **agacha e dá um bote** em arco: 22 de dano e empurrão. Bloqueio defende.
  - **Brutamontes:** braço direito gigante, cabeça enterrada nos ombros, 520 de vida, não cambaleia com golpe fraco. **Urra e dispara** em linha reta (9 m/s): 30 de dano e arremesso; **arrebenta parede** de construção de uma vez; batendo em árvore/pedra fica tonto.
  - **Cuspidor:** pescoço esticado, mandíbula pendurada. Fica a 7–13 m rodeando e **cospe ácido**: poça verde de 2,2 m que queima (9/s) por 7 s. Morto, deixa uma poça pequena.
- **Ondas da noite com direção:** cada noite sorteia um lado; **3 de cada 4 zumbis** vêm dele (leque de ~50°) e o resto de qualquer lado. Um **urro e gemidos ao longe** avisam de onde a onda vem (sem texto).
- **Árvore derrubada:** troncos, mudas e gravetos vão **direto para a mochila** (o que não couber cai no chão).
- **Plantar/colher sem mirar na vaga:** em pote, floreira, canteiro ou cova, colhe a pronta mais perto da mira; senão planta na vaga vazia mais perto. Mirando o chão do lado (até 1 m), também vale.
- **Bug do scroll:** a roda do mouse não prende mais o mouse na câmera com um menu aberto (só os botões esquerdo/direito/meio recapturam, e só sem menu).

## Criar mundo, desmontar e ladeiras (rodada de feedback)
- **Menu "Criar mundo"** (menu inicial → Novo mundo, ou Multiplayer → Criar servidor): sliders de tudo do mapa, com **prévia do mapa** que se atualiza sozinha (cidades, lagos, rios, pista e tamanho embaixo).
  - **Mapa:** tamanho (1,5–4,5 km), tamanho da ilha, recorte da costa.
  - **Relevo:** altura e quantidade de montanhas, morros nas planícies, clima (mais frio ↔ mais quente: muda onde fica neve e deserto).
  - **Lugares:** cidades, lagos, rios (0–12), pista de corrida (sim/não).
  - **Recursos:** árvores e plantas, rochas e minérios, saque nos baús.
  - **Perigo:** zumbis, hordas, zumbis especiais, animais. **Tempo:** duração do dia (5–60 min), chuva.
  - Semente (ou aleatória) e "Tudo no padrão". As configurações vão no save e o host manda para quem entra (todo mundo gera o mesmo mapa). `scripts/world/world_settings.gd`.
- **Desmontar:** segurando **Shift**, o que está mirado fica vermelho e o **clique direito desmonta**; o esquerdo só constrói (e com Shift alinha na grade).
- **Ladeiras:** o câmbio só sobe a marcha se a próxima ainda tiver força para a subida, e não troca de novo logo em seguida (nada de ficar caçando marcha). A 1ª tem corte de giro: **sobe 45° saindo parado a ~20 km/h**, devagar e sem parar; 30° sobe em 2ª.

## Ilha, mar, construção e carros (rodada de feedback)
- **O mapa é uma grande ilha:** perto das bordas o chão desce em praia de areia até o **mar** (costa recortada, fundo descendo até ~22 m). Dá para nadar; o mar vai até o horizonte e ninguém sai do mapa. Cidades, lagos e a pista ficam sempre em terra; zumbis e hordas não nascem na água. `TerrainWorld.coast_distance`, `WaterManager._build_sea`.
- **Rios até o mar:** nascem em lagos (ou em nascentes nos morros) e descem até desaguar no mar, desviando de cidades, avenidas e da pista (rio sem saída é descartado). A ligação com o lago não tem mais barranco de terra (a várzea só rebaixa o chão).
- **Erro ao agachar no rio** corrigido (o efeito debaixo d'água pedia a profundidade de um lago).
- **Construção:** o fantasma do martelo agora é o **modelo de verdade** translúcido (verde = cabe, vermelho = não cabe). **Segure Shift** para alinhar com a grade do piso construído (0,4 m e 90°); **desmontar é segurar Shift + clique direito** (o que vai sair fica vermelho), o botão esquerdo só constrói. Nova **escada** (Estrutura: 6 tábuas + 2 gravetos): sobe um andar (2,8 m) andando, com corrimão.
- **Carros com marchas:** 5 marchas automáticas que dão para sentir (tranco e corte do motor na troca, giro do motor cai); a 1ª tem força para subir rampa de 20° saindo parado. Em curva fechada rápida os pneus perdem aderência e o carro **derrapa** em vez de tombar (barra anti-rolagem).
- **Airdrop some às 8h** da manhã seguinte, com ou sem coisas dentro.
- **Armas dos zumbis** só caem raramente (2%).
- **Receitas:** martelo na mão (1 tronco + 2 tábuas); talhadeira na mesa (2 tábuas + 2 sucatas).
- **Painel da plantação** do tamanho dos itens que tem (não cresce mais para fora da tela).

## Animais e frio
- **Animais** (`scripts/animals/`, em blocos como todo ser vivo): **cervo** (foge de longe, rápido), **coelho** (foge em zigue-zague) e **javali** (apanhou, avança em quem bateu e morde por 15 s) — e mais 12 espécies depois (ver "Bichos, pássaros e fazenda"). Aparecem a 60–110 m dos jogadores conforme o bioma (nunca nas cidades), até 16 selvagens por vez, e somem longe. Sobem degraus como o jogador. Host simula, os outros veem cópias; golpe/tiro/lança funcionam igual aos zumbis.
- **Caça:** carne crua (faz mal crua, estraga em 8 min), pele, gordura (javali). Carne na fogueira → **carne assada**; no secador ou defumador → **carne seca** (nunca estraga). **Pele no secador → couro.** Couro: 2 correias, botas; **casaco de pele** (3 peles + 2 couros): o mais quente. Gordura queima na fogueira (3 min).
- **Frio:** temperatura do lugar = bioma (neve gela, deserto esquenta de dia e gela à noite), altitude, noite, chuva e estar molhado; **fogueira acesa** a até 7 m esquenta muito e **teto em cima** protege. Roupas isolam (casaco de pele 0,9, casaco 0,6, capuz 0,2, calça e botas 0,15). Abaixo de ~10° o calor do corpo cai; zerado, a vida vai embora (hipotermia) e a stamina enche menos.
- **HUD:** **termômetro** no centro do quarto de círculo (azul no frio, verde agradável, vermelho no calor; o bulbo pisca quando o corpo está gelando) e **geada nas bordas da tela** quando esfria.
- **Rios:** a margem ficou mais plana (~8 m quase no nível da água, depois sobe suave).

## Máquinas — Tier 2 (energia natural: a automação começa)
- **Rios** (`scripts/world/rivers.gd`): 5 rios sorteados pela semente, nascendo em lagos e descendo o relevo até o mar. O terreno é cavado num leito, a água é uma faixa com o mesmo shader dos lagos, aparecem no mapa/minimapa, dá para nadar e encher garrafa (água suja).
- **Rede de energia** (`scripts/machines/power.gd`): geradores → eixos/correias → máquinas. O host recalcula 1x por segundo: oferta (geradores) dividida pela demanda (máquinas com material); pouca energia = tudo mais devagar. As peças giram no ritmo da rede.
  - **Portas de latão:** as peças se ligam quando as portas se encostam. O **eixo** (martelo → Máquinas) encaixa sozinho na porta mais perto ao colocar (até 1,2 m), alinhado com ela.
  - **Correia** (mesa: 2 tecidos + 2 fios): com ela na mão, clique numa peça de energia e depois em outra (até 8 m): ficam ligadas, sem precisar alinhar.
- **Roda d'água:** só na beira de um rio, de frente para a água; gira sempre (força 4). A porta fica na margem.
- **Moinho de vento:** força = 6 × vento × altitude (mais alto, mais forte). Para quando o vento cai.
- **Serraria:** com energia (força 3), 1 tronco → 12 tábuas a cada 4 s. O moinho manual, a roca e o tear também trabalham sozinhos se ligados à rede (e continuam na manivela).
- **Carneiro hidráulico:** na beira de um rio, sem energia: o que for plantado a até 10 m cresce 50% mais rápido (irrigação), e [E] enche uma garrafa vazia de água suja.

## Fogo só em uso, itens na mão, revólver (rodada de feedback)
- **A fogueira gasta lenha:** nasce apagada; [E] acende com lenha de qualquer lugar da mochila (tronco 15 min, carvão 10, tábua 4, graveto 1); com lenha na mão, [E] põe mais (até 4 h). Só assa acesa, e só afasta zumbis à noite se estiver acesa.
- **Luz só em uso:** fornalhas acendem enquanto o combustível queima; o forno acende por 45 s depois de assar; o defumador, enquanto tem peixe defumando.
- **Qualquer item aparece na mão** em primeira pessoa (comida, materiais, sementes, garrafas, roupas...), na mão (um cubo perfeito; braço um pouco mais fino): itens longos (garrafa, tábua, graveto, cenoura) ficam em pé atravessando o punho, os outros em cima dela; acompanham o soco.
- **Garrafas:** potável azul-clara, suja marrom-esverdeada (com sujeira no fundo), vazia em vidro claro. Barra de ferro/cobre refeita com todas as faces certas; rolo de fita fechado.
- **Revólver** no lugar da pistola: cano octogonal, tambor canelado, vareta de ejeção, cão com espora, coronha curva com argola.
- **Carros:** saíram o Chevy 55 e o Mormon Meteor.

## Modelos mais elaborados (rodada de feedback)
- **Itens** (`scripts/items/item_detail.gd`, usado pelo `ItemModels` na mão, no chão, nos ícones e nos zumbis): espada com sulco, guarda curva e pomo; maça com flanges e rebites; martelo, talhadeira, pá com punho em D e lâmina com degrau; machado barbado; picareta com pontas afinando; lança em folha; ferramentas de pedra lascada amarradas; lanterna com alça e botão; bumerangue torneado; tocha enrolada; comidas com forma de verdade (maçã, lata com frisos, pão com cortes, cenoura com rama, batata com olhos, abóbora em gomos, peixe seco); materiais (tábua com veios e nó, tronco com casca e anéis, pedras e minérios irregulares com veios, lingotes, vidro com borda, sucata com parafuso, pilha de pano, carretel, rolo de tecido, garrafa com rótulo); roupas (capuz, capacete com crista e rebites, coletes de chapas, calça com remendos, botas com cadarço, casaco com gola de lã).
- **Objetos e máquinas:** fogueira (pedras variadas, lenha em pirâmide, brasas, panelinha), mesa de trabalho (tampo de tábuas, travessas em X, painel de ferramentas), baú com ripas e cantoneiras, fornalha de barro com lenha, secador com cordas e balde de sal, vasos e floreiras, cova, bandeira, armadilhas (estacas queimadas, arame farpado em espiral, mina com nervuras) e mais peças nas máquinas do Tier 1.
- **Móveis** das casas e baús de saque refeitos (pernas torneadas, almofadas, livros variados, louça, banheira com pés de garra...).
- **Carros:** kit comum (placas com parafusos, lanternas, escapamento com abafador, para-barros, ganchos de reboque) e detalhes próprios (números de corrida, cintas no capô, tanque extra, galões).
- **Estúdio de fotos:** `tests/studio.gd` (STUDIO=items|placed|furniture|cars) gera folhas de contato de todos os modelos.

## Ajustes do Tier 1 (feedback)
- **Mais lugares:** grelha 6, filtro 6 (20 s por garrafa), defumador 6, composteira 9, secador 6.
- **Defumador gasta carvão:** 1 carvão defuma 4 peças (3 carvões = 2 rodadas de 6), puxado sozinho da mochila; sem carvão não aceita. Frente aberta: dá para ver os peixes pendurados dentro.
- **Puxam da mochila inteira** (não precisa estar na mão): coletor de chuva ([E] enche uma garrafa vazia de onde estiver), bomba, filtro, secador, defumador, composteira, moinho, roca, tear e peneira (põem tudo o que tiver de uma vez). A grelha continua pelo item da mão.
- **Fornalhas estilo Minecraft** (barro e pedra): janela com material, combustível e resultado; fundem sozinhas pelo host, mesmo sem ninguém olhando (carvão 40 s, tronco 30 s, tábua 12 s, graveto 4 s). Shift+clique manda o combustível e o material para o lugar certo; o resultado não aceita nada. Na de pedra, a barra vermelha é o calor do fole (ferro só com ela acima de 50%).
- **O que sai das máquinas voa até você** e vai direto para a mochila (grelha, secador, filtro, moinho, coletor...): não cai mais no chão.
- **Mudas** também crescem nas covas da pá.
- **Modelos novos:** filtro em funil com garrafas embaixo, defumador de tijolo com armário de madeira aberto, composteira de ripas com tampa, coletor com barril redondo e funil cônico (a água é redonda e fica dentro).
- **Aba Máquinas:** mesa de trabalho, fogueira e fornalha saíram de "Outros". O menu de construção tem 5 colunas.
- **Zumbis naturais voltaram a soltar itens** em qualquer tipo de morte (explosão, empalado, atropelado...) — raramente.
- **Itens pequenos** (graveto, cenoura, sementes) têm uma área de mira maior para pegar.
- **Comida estragada** junta numa pilha só.
- **Botão Organizar** na mochila: armas, ferramentas, recursos brutos, refinados, outros, sementes e comida (alfabético; comida pelo que vence antes). A hotbar não mexe.
- **Aviso de coleta** discreto no canto de cima à esquerda ("+3 Graveto", também quando algo estraga).
- **Tocha** (mão: graveto + pano; mesa: 2 gravetos + pano + carvão → 3): na mão ilumina em volta, queima por meio dia (10 min) e acaba.
- **Peneira** (aba Máquinas): argila → 50% de chance de pedra, segurando E. **Areia:** 10 pedras → 1 areia (mão ou mesa).
- **Pá:** 1 s entre uma cavada e outra.

## Máquinas — Tier 1 (manual: o jogador é a energia)
- **Comida estraga:** peixe cru ~8 min, assados ~15 min, legumes 25–40 min, pão caseiro 20 min (enlatado, pão velho, peixe seco/defumado e farinha não estragam). O frescor é a barrinha embaixo do ícone (verde → marrom); ao zerar vira **comida estragada** (quase não enche, 80% de doença). Pilhas juntam pela média do frescor. Estraga na mochila e nos baús (no chão fica parado). Comer algo com menos de 25% de frescor pode deixar doente.
- **Martelo → aba Máquinas** (o coletor e o secador foram para lá).
- **Manivela:** toque em [E] = pôr material / tirar o pronto / abrir; **segure [E] = girar**, gastando stamina (30/s, sem encher enquanto gira). O modelo gira e range.
  - **Pedra de amolar:** segure E com a ferramenta/arma na mão: ~14 s de 0 a 100% de durabilidade.
  - **Moinho manual:** trigo → farinha (2,5 s de manivela cada).
  - **Bomba d'água:** só na beira do lago; segure E com garrafa vazia → água suja sem fim (1,5 s cada).
  - **Roca:** 2 fibra → 1 fio. **Tear:** 3 fio → 1 tecido. Tecido → **casaco** (isolamento térmico para o frio, 8% de proteção) ou 3 panos na mesa.
  - **Fornalha de pedra + fole** (12 tijolos): a **única que funde minério de ferro** (a de barro não funde mais; continua com cobre, vidro, carvão e sucata). Segure E no fole: ~3 s esquenta acima de 50%, esfria em 90 s. Rende mais: 2 sucata → 1 barra, 2 minério de cobre → 2 barras, argila → tijolo.
- **Forno de tijolo** (estação): 2 farinha + 1 água → 2 pães caseiros (devolve a garrafa); torrada; batata assada em lote.
- **Esperam sozinhos** (como a grelha): **filtro** de areia/carvão (água suja → potável, 30 s), **defumador** (peixe cru → defumado, nunca estraga, 60 s), **composteira** (estragada/legumes → adubo, 120 s).
- **Adubo:** clique num plantador → as próximas 3 colheitas dele rendem o dobro.
- **Plantas novas:** trigo (sementes nas casas) e algodão (dá fibra).

## Máquinas — Tier 0 (primitivo). Plano completo em `docs/ROADMAP_MAQUINAS.md`
- **Sede** (arco azul "A" no HUD, por dentro da fome): esvazia em ~15 min (correndo, mais rápido). Zerada, a vida cai. Com sede baixa a vida não regenera; aviso só por som.
- **Garrafa** (fornalha: 1 vidro → 2 garrafas; casas e caixote inicial): clique com ela na **água do lago** → **água suja**; num **coletor de chuva** → **água potável**. Beber devolve a garrafa vazia.
- **Doença** (água suja: 60% de chance): por 3 min a vida cai devagar (até 15), a stamina enche pela metade e fome/sede gastam 60% mais rápido. Arco da vida fica verde. Some sozinha.
- **Clima** (`scripts/world/weather.gd`): o host sorteia o tempo a cada 2–5 min (~35% de chuva) e o vento (mais forte com chuva; vai mover moinhos no Tier 2). Chuva: gotas em volta da câmera, céu cinza, sol fraco, som de chuva. Vai no save e na rede.
- **Coletor de água da chuva** (martelo → Outros: 4 tábuas + 1 pano): barril com funil; chovendo enche (chuva forte ≈ 1 garrafa a cada 25 s, até 10). A água aparece subindo dentro.
- **Secador** (martelo → Outros: 6 gravetos + 1 pano): varal com 4 ganchos; peixe/frutos do lago viram **peixe seco** em 90 s (+40 fome, não queima). Pele → couro entra quando houver animais.
- **Argila → tijolo:** a pá na **beira dos lagos** (até ~1 m acima da água) tira argila em vez de abrir cova; na grelha da fogueira vira tijolo e **não queima** (pode esquecer lá). O tijolo é a base da fornalha de pedra (Tier 1).
- **A fogueira afasta zumbis à noite:** eles não entram a menos de ~6 m dela, nem indo atrás de quem está ao lado do fogo; ficam rondando a borda da luz. De dia não adianta.

## Airdrop, desgaste por uso, bandeira e menos fita (rodada de feedback)
- **Zumbis da onda noturna não soltam nada.** Ao vencer a onda (cota da noite abatida), **cai um airdrop** a 10–25 m de cada jogador: caixa militar descendo de paraquedas, com uma **luz vermelha piscando** em cima e um quadrado vermelho pulsando no mapa/minimapa. Dentro: suprimentos bons (bandagem, comida, sucata, pano, barras, vidro, fita, carvão, às vezes colete/capacete/pistola). O sinal apaga quando a caixa fica vazia. `scripts/farming/airdrop_fx.gd`, `HordeManager._drop_airdrops`.
- **Desgaste conforme o uso:** atacar gasta 100% (qualquer arma ou ferramenta); ferramenta no serviço certo gasta 75% (machado em árvore/tronco/móvel, picareta em pedra/minério, pá cavando, martelo/talhadeira construindo); no serviço errado gasta **200%** (espada na árvore, machado na pedra). A **maça** gasta sempre 100%. `Player._wear_cost`.
- **Bandeira** (mesa: 2 gravetos + 2 panos): clique no chão para fincar; vira um **waypoint no mapa e no minimapa** para todo mundo (no minimapa, a que está longe fica presa na borda apontando a direção). [E] nela recolhe de volta.
- **Fita só em coisa complexa:** saiu do machado, picareta, lança, bumerangue, chinelo e colete (trocada por sucata/pano/tábua). Continua só na lanterna.

## Carros nas cidades e mapa mais nítido (rodada de feedback)
- **Carros abandonados nas cidades** (`scripts/world/city_cars.gd`): 1 nas vilas, 2 nas médias e 4 nas grandes (23 no mapa padrão), modelo e lugar sorteados pela semente da cidade, largados meio tortos na rua. Ficam **congelados** (sem física, sem rede) até alguém chegar a 150 m e o chão embaixo existir; voltam a congelar quando todos se afastam. Vão no save como os outros.
- **Ícone do carro no mapa só depois de entrar nele uma vez** (vale para todos os carros, inclusive os da garagem; saves antigos já contam como conhecidos).
- **Desvirar mais robusto:** conta como tombado também o carro inclinado/encalhado (apoiado em algo, com menos de 2 rodas no chão e parado); ao desvirar ele acorda a física e pousa 1 m acima do chão que estiver embaixo.
- **Mapa 4x mais nítido** (2 m por pixel): o relevo continua amostrado a 8 m e suavizado, mas ruas, avenidas, a pista e as casas (giradas, com contorno; ruínas mais escuras) são desenhadas por cima em alta resolução. Minimapa mostra 260 m (antes 320). Gera em ~4 s.

## Durabilidade, mudas, degraus e vidro (rodada de feedback)
- **Durabilidade** em roupas/armaduras, ferramentas e armas corpo a corpo: só uma barra embaixo do ícone (verde → amarelo → vermelho), sem texto. Cada golpe que acerta gasta 1 uso (uma vez por golpe, mesmo acertando vários); cada dano recebido gasta a roupa vestida. Ao zerar, quebra com um som de estalo. Ferramentas simples (de pedra) duram ~35% das de metal. `ItemDB.max_durability`, `Inventory.wear`.
- **Golpe acerta 2 a 5 zumbis** (sorteado a cada golpe): hordas voltaram a ser perigosas.
- **Zumbis soltam recursos** ao morrer: 10% uma sucata ou 8% um pano (roupa não cai mais).
- **Mudas de árvore:** árvores do mapa às vezes soltam uma muda. Plante no solo ou num **canteiro** (ocupa o canteiro inteiro). No **vaso ou floreira** ela não cresce: fica de decoração (um golpe arranca e devolve a muda). Cresce em ~8 min (muda → arvoreta → árvore); só dá para derrubar depois de crescida (machado corta bem, o resto mal arranha). Árvore plantada pelo jogador sempre solta **1 muda (10% de chance de 2)**, troncos e gravetos.
- **Subir degraus** de até 0,42 m (altura da canela, um passo da grade) andando, sem pular: jogador e zumbis (os animais vão usar o mesmo `scripts/physics/step_climb.gd`). A câmera sobe suave, sem tranco. Resolve o degrau do piso na entrada das casas construídas.
- **Menus sem botão "Fechar":** clicar fora do painel fecha qualquer menu (mochila, baú, porta-malas, baú do mapa, mesa/fornalha, lousa, construção e pausa). `LegacyGUI.close_on_outside`.
- **Janela** agora custa 2 gravetos + 1 vidro (era tábua + sucata).
- **Deserto:** a pá não abre cova (o solo é ruim: só dá para plantar em plantadores construídos), mas cava **areia** (1–2). O vidro sai só da fornalha: 2 areia → 1 vidro.

## Inventário, crafting, carros e casas (rodada de feedback)

- **Hotbar de 9** (teclas 1-9). **Mochila 9x5** (hotbar + 9x4). Em cima: o **personagem** girando com 4 slots de **roupa/armadura** (cabeça, corpo, pernas, pés) presas no boneco, e o **crafting de mão**.
- **Pilhas de até 100** (armas, ferramentas e roupas: 1 por slot).
- **Shift + clique** transfere rápido: na mochila (hotbar <-> mochila; roupa veste/tira) e no baú construído/porta-malas (baú <-> mochila).
- **Roupas e armaduras** reduzem o dano (somam até 80%): capuz 5%, capacete de ferro 15%, colete de sucata 18%, peitoral de ferro 30%, calça 10%, botas 5%.
- **Crafting de mão** (só o básico e versões que rendem menos): gravetos (2 por tábua), tábuas (3 por tronco), machado e picareta **simples** (pedra + graveto, rendem ~60%), bandagem, capuz.
- **Gravetos:** caem em volta de algumas árvores; golpe de machado numa tábua no chão = 2 gravetos; na mesa, 1 tábua = 4 gravetos. Ferramentas da mesa usam gravetos.
- **Mesa e fornalha em grade:** ícone com o nome embaixo (estilo do menu de construção); passando o mouse mostra o que precisa. Clique fabrica 1; **Shift + clique fabrica o máximo** (até uma pilha de 100: dá para fundir uma pilha inteira de minério).
- **Menos avisos na tela:** pesca, construção, plantio e grelha agora avisam por **som** (boia afundando, "clique" seco quando falta material ou não dá, martelada no conserto...). Sem frases de instrução nos menus.
- **Pesca:** o peixe do minijogo ficou bem mais calmo; a linha sai da ponta da vara.
- **Peixes repovoam a cada 5 dias:** cada lago tem uma quantidade padrão de cada bicho (sorteada na criação do mundo); o que você pega só volta no repovoamento.
- **Carros:** mais pesados (gravidade 1,5x no carro, mola compensada, aceleração igual); **desvirar** com [E] no carro tombado (só de fora do carro); **porta-malas** com [E] atrás do carro (21 slots, arrastar e soltar).
- **Baús de saque** pintados em cores fortes (baú vermelho, armário turquesa, caixote amarelo).
- **Casas com interior:** ~30% das casas grandes (9x9 m ou mais) têm o térreo oco, com porta aberta, **janelas de verdade** (vãos com moldura: dá para olhar e atirar através), piso de tábua e lampião aceso na sala.
- **8 plantas prontas** (`scripts/world/house_plans.gd`) com **4 a 7 cômodos** (sala, cozinha, quartos, banheiro, corredor, escritório, oficina, despensa), paredes internas com vãos de passagem e móveis encostados nas paredes certas de cada cômodo.
- **Móveis:** mesa (com cadeiras), cama, armário, estante, fogão a lenha, sofá, banheira, privada, pia, balcão de cozinha e cômoda. **Qualquer golpe desmonta** (arma, ferramenta ou soco) e eles soltam tábuas, gravetos, pano, sucata, pedra...
- Slots de roupa vazios mostram só a **silhueta** da peça; nas grades de receitas e no menu de construção o **nome curto fica dentro do quadrado** e a quantidade no canto de cima (o resto aparece passando o mouse).
- **Threads:** terreno, casas e sons usam tarefas de alta prioridade no WorkerThreadPool (as comuns dividem só ~30% das threads e a imagem do mapa, que leva ~20 s, ocupava tudo).

## Ajustes (feedback)

- **HUD** de arcos menor (letrinhas S/V/F na ponta).
- **Onda noturna:** só uma barra vermelha abaixo do relógio que esvazia conforme os zumbis da noite morrem. Cada noite tem uma **cota** maior (12 na 1ª, +6 por noite); matou a cota, a onda acaba e não nascem mais noturnos até amanhecer.
- **Mesa de trabalho** é a única bancada de fabricação (6 tábuas + 3 sucatas, sem ferro); a "bancada" antiga saiu do martelo (as já construídas abrem a mesa). Uma já vem na área inicial.
- **Fornalha** de barro: cúpula redonda sobre pedras, boca em arco e chaminé de barro.
- **Pedras soltas** no chão em volta de rochas e veios ([E] pega): dá para fazer a primeira picareta sem ferramenta.
- **Baús, armários e caixotes do mundo:** [E] abre a lista do saque; **só dá para retirar** (clique num item pega; "Pegar tudo"). O saque é sorteado na primeira abertura, sincronizado no multiplayer e salvo.
- **Baú construível** (martelo → Outros, 6 tábuas + 1 sucata): 21 slots (7x3), com **arrastar e soltar igual ao inventário** entre o baú e a mochila (move, troca e junta pilhas; soltar do baú num slot da mochila vai para aquele slot). O conteúdo é do mundo (todos veem, vai no save); desmontar o baú derruba o que tinha dentro. `scripts/ui/storage_ui.gd`.
- **Modelo 3D girando** ao lado do nome do item (janela de detalhes da mochila e no baú). `scripts/ui/item_spinner.gd`.
- **Som:** soco com som próprio (grave e curto); motor sem "pop" (loop periódico sem emenda e liga/desliga com fade, mais baixo).
- **Água** mais transparente, fundo do lago verde de alga; debaixo d'água bem menos escuro.
- **Peixes** nadam devagar e só fogem se você chega muito perto ou ataca por perto.
- **Peixe-baixo** agora é um peixe (cabeça, boca, guelras, barbatanas, rabo bifurcado) com acabamento de contrabaixo (madeira sunburst, captadores, 4 cordas no flanco, tarraxas na barbatana).

## Lagos, pesca e vida aquática (`scripts/water/`, `shaders/`)

- **Lagos e lagoas:** 9 lagos (raio 22-48 m, até 9 m de fundo) e 16 lagoas (9-18 m, 2,5-4 m), sorteados pela semente e longe de cidades, pista, avenidas e da área inicial. O terreno afunda numa bacia com fundo de areia/lodo. Aparecem em azul no mapa. Lagos na neve **congelam** (dá para andar no gelo).
- **Água:** superfície translúcida com ondinhas, mais clara na margem e refletindo de lado.
- **Nadar:** com água acima de ~1,2 m você nada: Espaço sobe, C desce, olhar para baixo andando mergulha; parado, boia. Com água na cintura anda mais devagar.
- **Debaixo d'água:** tela ondulando, verde-azulada e mais escura no fundo, neblina curta, som abafado, bolhas saindo e sujeirinha flutuando.
- **Plantas:** algas compridas que balançam no fundo, juncos e taboas na margem, vitórias-régias boiando (algumas com flor) e pedras com musgo.
- **Bichos (em blocos):** camarão, lagosta, caranguejo, caranguejo-aranha (pernas enormes), atum (só nos lagos grandes) e o **peixe-baixo**: corpo de contrabaixo sunburst, braço com tarraxas fazendo de rabo, 4 cordas e captadores. Nadam/andam pelo lago, caranguejos andam de lado e alguns ficam na margem; fogem de quem chega perto. Pegos voltam depois de 1 min.
- **Lança** (mesa de trabalho: 2 tábuas + 1 sucata + 1 fita): estocada longa que pega qualquer bicho (funciona debaixo d'água) e machuca zumbi.
- **Com a mão:** [E] pega camarão, lagosta e caranguejos (os do fundo e da margem).
- **Vara de pesca** (mesa de trabalho: 2 tábuas + 1 pano + 1 sucata): clique lança a boia onde você mira na água (até 22 m). Espere a boia **afundar** e clique em até 1,2 s. No minijogo, segure o clique para empurrar a faixa verde e manter o peixe dentro dela até a barra amarela encher. O atum briga muito; o camarão é fácil. Botão direito recolhe a linha. À noite eles mordem mais rápido.
- **Na grelha:** todos viram versões assadas que enchem muito mais a fome (atum assado +80, lagosta +55, peixe-baixo +48...).
- Teste: `tests/test_water.gd`.

## HUD, lousa, carros e desempenho

- **HUD em quarto de círculo** (canto de baixo à esquerda): stamina por fora (amarelo), vida no meio (vermelho, pisca quando baixa) e fome por dentro (laranja). `scripts/ui/status_arcs.gd`.
- **Painel do canteiro:** mirando um pote/floreira/canteiro/cova (ou a grelha da fogueira) aparece ao lado da mira a foto de cada planta, a barra de crescimento e a porcentagem. `scripts/ui/plant_panel.gd`.
- **Contador da onda noturna** abaixo do relógio: de dia "Próxima noite em 6:20"; de noite "Onda noturna 2 · 5 vivos · 11 abatidos · amanhece em 3:10".
- **Lousa** (martelo → Outros, 4 tábuas + 1 pano): cavalete com tela. [E] abre a tela grande: 12 cores, 4 espessuras, borracha e Limpar. Todos desenham juntos e veem ao vivo; o desenho vai no save. `scripts/crafting/draw_board.gd`, `scripts/ui/draw_ui.gd`.
- **Carros:** todos dirigem como o primeiro (mesma aderência, esterço, freio e estabilidade); cada um mantém só o próprio torque e a velocidade máxima.
- **Multithread:** o terreno já era gerado em threads e o Jolt já usa vários núcleos na física. Agora também: casas das cidades montadas em threads (WorkerThreadPool), sons sintetizados em paralelo na abertura (o primeiro gemido não trava mais) e a navegação calculada em outra thread. O render em thread separada do Godot foi testado, mas quebra a leitura de malhas dos zumbis (é experimental), então ficou desligado.

## Recursos, estações, conserto e armadilhas

### Árvores, rochas e minérios (`scripts/world/resource_node.gd`)
- **Machado** derruba árvore em 3 golpes (ela tomba de verdade) e solta **troncos** (2-3). Outras armas quase não fazem efeito.
- Tronco: carregue até a **bancada** (1 tronco = **8 tábuas**) ou golpeie com o machado ali mesmo (**2 tábuas**). Na fornalha vira carvão.
- **Picareta** quebra rochas (pedra) e **veios de minério**: ferro (pedaços laranja), cobre (verdes) e carvão (pretos), mais comuns na montanha.
- Árvores e rochas usadas não voltam (vão no save e valem para todos no multiplayer).

### Estações (martelo → aba Outros)
- **Fogueira com grelha** (5 pedras + 3 tábuas): segure comida crua e aperte [E] para pôr na grelha (3 lugares). Em 20 s fica pronta; esquecida 1 min depois vira carvão. Assada enche muito mais: batata 22→45, cenoura 15→30, abóbora 40→75, enlatado 45→65, pão 25→40. Também ilumina à noite.
- **Fornalha** (10 pedras + 2 tábuas): minério → barra de ferro/cobre, 3 sucatas → barra de ferro, pedra → vidro, tronco → 2 carvões. Cada fundição gasta combustível (carvão, tronco ou 2 tábuas).
- **Mesa de trabalho** (6 tábuas + 2 barras de ferro + 2 sucatas): tudo da bancada + receitas de metal (espada, pistola, lanterna, carregador, gancho, colherona, cajado).
- **Bancada:** tábuas do tronco, machado, picareta, pá, martelo, talhadeira, bandagem, bumerangue, chinelo, maça.

### Conserto com o martelo
- Mirando uma peça quebrada por zumbi, o dano aparece em verde e o **clique conserta** (1 tábua a cada 2 quadradinhos). Cortes feitos com a talhadeira não contam como dano.

### Armadilhas (martelo → aba Armadilhas)
- **Estacas** (4 tábuas): machucam a perna de quem passa (30 usos).
- **Armadilha de urso** (2 barras de ferro): prende o zumbi (atordoa 5 s e quebra a perna). Depois fica fechada: [E] arma de novo.
- **Cerca de espinhos** (4 tábuas + 1 barra de ferro): bloqueia; zumbi que bate nela se machuca (aguenta 12 golpes).
- **Mina** (2 sucatas + 3 carvões): explode quando um zumbi chega perto.

### Outros ajustes
- Stamina 4x maior (enche no mesmo tempo de antes).
- **Som:** volume geral bem mais baixo, cada som com o mesmo pico (sem clipping), limitador no canal Master, menos agudos e tom máximo limitado.
- Itens do baú nascem na frente dele (antes podiam ficar presos dentro do armário).
- Testes: `tests/test_resources.gd`, `tests/test_stations.gd`.

## Chat e marcador (`scripts/ui/chat.gd`, `scripts/ui/ping_markers.gd`)

- **Enter** abre o chat (Enter envia, Esc cancela). As mensagens aparecem no canto de baixo à esquerda e somem depois de uns segundos; entradas/saídas de jogadores também aparecem ali.
- **Comandos do host:** `/noite`, `/dia`, `/hora 14`, `/horda` (uma horda a ~90 m vindo até você), `/especial <inchado|saltador|brutamontes|cuspidor>`. `/ajuda` lista.
- **B ou botão do meio do mouse:** marca onde você mira (até 300 m). Todos veem um losango por cima de tudo (atravessa paredes) com o nome, o que é (**Zumbi!**, Item, Carro ou Aqui) e a distância; também aparece no mapa e no minimapa (preso na borda se estiver longe). Some em 12 s.
- O nome no chat vem da lista do host (ninguém consegue falar como outro jogador).
- Teste: `tests/test_chat.gd` (e `net_host.gd`/`net_client.gd` na rede).

## Dia e noite, hordas e zumbis quebrando construções

### Dia e noite (`scripts/world/day_night.gd`)
- Um dia dura **20 minutos**: dia das 6h às 20h, noite das 20h às 6h. Relógio no canto de cima ("Dia 2  21:30").
- O sol gira (nasce, põe), o céu e a neblina escurecem; à noite entra uma lua azulada fraca. Lanterna (L) e faróis fazem diferença.
- Os **postes das cidades só acendem à noite** (os quebrados continuam piscando).
- O host manda a hora para todos; ela vai no save.

### Hordas noturnas (`scripts/enemies/horde_manager.gd`)
- De noite nascem zumbis a 45-65 m de cada jogador, fora da vista, **já vindo atrás dele**.
- Limite por jogador: 13 na 1ª noite, +3 a cada dia (até 30). Ao amanhecer os que estão longe vão embora.
- Cada noite tem uma **direção**: 75% dos zumbis vêm dela, o resto de qualquer lado (urro ao longe avisa).

### Hordas no mapa
- 5 hordas (7 de noite) de 12-30 zumbis andando **de cidade em cidade** (mais rápido de noite). Aparecem no mapa/minimapa como manchas vermelhas pulsando, com a contagem.
- Longe de todo mundo são só um ponto no mapa; a **120 m** de um jogador surgem de verdade e **marcham juntas**; se todos se afastam (200 m), os vivos voltam a ser um ponto.
- Matou todos: a horda some; outra nasce longe depois de um tempo. As hordas vão no save.

### Zumbis quebram construções
- Zumbi perseguindo alguém **que está dentro da construção** com uma parede/porta/janela na frente **para e bate nela** (se a pessoa está fora, ele dá a volta).
- **Parede:** cava um buraco de ~1,2 m de largura do chão para cima (cada pedaço aguenta 2 golpes). Um zumbi sozinho demora; uma horda passa rápido.
- **Janela** aguenta 3 golpes e **porta** 6; depois caem.
- Teste: `tests/test_night.gd`.

## Saque, fome, fabricação e plantação

### Saque (`scripts/loot/`)
- **Baús, armários e caixotes** na frente de ~65% das casas das cidades (escombros têm caixote de ruína). **[E] revista**: os itens pulam para fora.
- Cada um só pode ser revistado **uma vez por mundo** (todo mundo vê aberto; o save lembra).
- Tabelas em `loot.gd`: casa (comida, pano, sementes), caixote (tábua, pedra, sucata, ferramentas raras), ruína (pedra, sucata, raros).
- **Caixote inicial** ao lado da mesa de armas: 20 tábuas, 10 pedras, sementes, 2 enlatados e uma pá.

### Construção custa material
- Parede/piso/teto: 4 tábuas · pilar: 1 tábua + 1 pedra · janela: 2 gravetos + 1 vidro · porta: 3 tábuas + 1 sucata.
- O menu do martelo mostra o custo (tem/precisa) e deixa o slot avermelhado quando falta. Desmontar (Shift + botão direito) **devolve metade**.

### Fome
- Barra laranja embaixo da stamina. Cai em ~22 min (mais rápido correndo).
- Acima de 80: recupera vida devagar. Zerada: perde vida aos poucos.
- Comidas: enlatado (+45), pão velho (+25), abóbora (+40), batata (+22), cenoura (+15), fruta (+10 e vida). Bandagem só cura.

### Bancada de fabricação (`scripts/ui/crafting_ui.gd`)
- Uma ao lado da mesa de armas; dá para construir outras pelo martelo (aba Outros: 6 tábuas + 2 sucatas).
- [E] abre as receitas: pá, martelo, talhadeira, bandagem, bumerangue, chinelo, lanterna, maça, pistola.

### Plantação (`scripts/farming/`)
- **Martelo → aba Outros:** pote (1 planta, 2 pedras), floreira (3 plantas), **canteiro** (piso de terra na grade da construção, 9 plantas), bancada.
- **Pá:** clique = golpe. **Botão direito** no chão de terra cava uma **cova** (às vezes acha pedra); numa cova/pote/canteiro vazio planta a primeira semente da mochila; numa planta pronta, colhe.
- **Semente na mão:** clique planta onde mirar. **[E]** colhe tudo que estiver pronto.
- Culturas: cenoura (~4 min), batata (~5 min), abóbora (~7 min, não cabe no pote pequeno). A colheita dá comida + sementes.
- As plantas crescem pelo relógio do mundo (salvo junto) e sincronizam no multiplayer.
- Testes: `tests/test_farming.gd`.

## Salvar e carregar (`scripts/save/save_game.gd`)

- **Menu inicial:** "Continuar (Mundo N)" abre o último save; "Carregar mundo..." lista todos (com data) e deixa apagar (clique duas vezes em Apagar). "Novo mundo" começa do zero.
- **Pausa (ESC):** botão "Salvar". "Sair para o menu" salva antes de sair. **Autosave a cada 2 minutos.**
- **O que é salvo:** semente do mapa, itens já pegos, itens soltos no chão, construções (peças, recortes, portas/janelas abertas), carros (posição e faróis), jogador (posição, direção, vida, inventário).
- **Multiplayer:** só o host salva (o mundo fica no computador dele). Ao salvar, o host pede o estado de cada cliente e guarda pelo **nome**: quem entrar de novo com o mesmo nome volta com posição, vida e inventário.
- Arquivos em `user://saves/<nome>.save` (no Linux: `~/.local/share/godot/app_userdata/<projeto>/saves`).
- Sistemas novos se salvam sozinhos: basta entrar no grupo `persist` e ter `persist_key()`, `save_data()` e `load_data()`.
- Teste: `tests/test_save.gd`.

## Som (`scripts/audio/sfx.gd`)

Todos os sons são **sintetizados no código** ao abrir o jogo (sem arquivos de áudio): ruído filtrado, tons e "vozes" com formantes para os zumbis. Ficam em cache depois da primeira vez.

- **Combate:** golpe no ar, pancada, corte de membro, corpo caindo, tiro, explosão, tapa do chinelo, zumbido do bumerangue.
- **Zumbis:** gemem de vez em quando (só os próximos), rosnam ao atacar, último gemido ao morrer. Funciona também nas cópias do multiplayer.
- **Mundo:** passos (terra fofa x construção/rua dura), motor dos carros (o tom sobe com a velocidade), porta rangendo, marteladas e talhadeira na construção, pegar item, comer, vento de fundo.
- Sons 3D usam um conjunto de 40 tocadores reaproveitados (`Sfx.play_at`); loops (motor, vento, bumerangue) com `Sfx.loop_player`.
- Teste: `tests/test_sfx.gd` gera todos e mostra duração/pico.

## Construção (`scripts/building/`)
- Ferramentas na área inicial (no chão, ao lado da bancada): **martelo** e **talhadeira**.
  No inventário (Tab), **segure Shift** com o mouse em cima de um item para ver os controles dele.
- **Grade invisível** de **0,4 m** no mundo inteiro. Paredes, pisos e tetos têm **2,8 m**
  (7 x 7 quadrados de 0,4 m); o pilar ocupa 1 quadrado e tem 2,8 m de altura.
- **Martelo:** mostra a peça "fantasma" (verde = cabe, vermelho = já tem peça ali); objetos aparecem com o modelo de verdade translúcido.
  - Clique constrói · **segure o botão direito** para abrir o menu de construção (abas +
    slots com foto de cada peça, como o inventário; solte em cima do slot) · **R** gira a parede ·
    **segurando Shift**, o que está mirado fica vermelho e o **clique direito desmonta** (peça,
    janela/porta ou objeto); o botão esquerdo só constrói · **segure Shift** para
    alinhar objetos com a grade do piso (passos de 0,4 m e giro de 90°). Ao soltar o botão direito
    o menu escolhe o slot que estiver embaixo do mouse.
  - Encaixes: parede mirando um piso vai para a borda dele; mirando o topo de uma parede empilha;
    piso mirando a borda de outro piso vai para o lado; teto mirando o topo de uma parede cobre o
    cômodo do lado onde você está. Piso fica com o topo na grade (pisa-se nele); teto apoia em cima.
- **Talhadeira:** cada quadrado é cortado pelas **duas diagonais** (4 triângulos de quarto), então
  dá para tirar meio quadrado em **"/" ou "\\"** (**R** troca a diagonal). Clique tira o triângulo
  mirado; **clique e arraste** seleciona uma área retangular e tira tudo ao soltar. O buraco tira a
  colisão também e as bordas mostram a espessura da peça.
- **Janela** e **porta** (aba *Aberturas* do menu): mire um buraco feito pela talhadeira e ela
  preenche o buraco **inteiro, em qualquer formato**. A janela tem vidro, batente, guarnição
  saliente, peitoril e **frisos a cada 2 quadrados**; a **porta** precisa de um buraco que encoste na
  base da parede, tem maçaneta, uma **vidraça na altura dos olhos** (porta com 3+ quadrados de largura)
  e abre/fecha com **E**.
- Online o host confere tudo (lugar livre, partes existem, buraco válido) e manda para todos; quem
  entra depois recebe as construções com buracos, janelas e portas.
- Testes: `tests/test_building.gd`, `tests/test_openings.gd`.

## Desempenho dos zumbis
- Corpo do zumbi numa **malha só** deformada pelo esqueleto (antes ~25 peças por zumbi): com 100
  zumbis as chamadas de desenho caíram de ~11.700 para ~2.600 (incluindo o mapa).
- Ossos do ragdoll ficam **fora da física** enquanto o zumbi está de pé.
- Longe (> 30 m): sem sombra, animação a cada 2 quadros e hitboxes desligadas (o tiro acerta a
  cápsula); > 70 m: animação a cada 4 quadros e IA a cada 2.
- Zumbis não colidem fisicamente entre si (se afastam com uma grade de vizinhança).
- A horda (H) nasce em lotes de 10 por quadro: o travão ao criar 100 caiu de ~275 ms para ~24 ms.

## Animações dos outros jogadores
- Quem joga online vê os golpes dos outros no corpo deles: os três arcos da espada/taco/colher,
  soco (alternando os braços), chute, tiro (com recuo), cajado, martelo/talhadeira e dínamo;
  e as poses contínuas: arma de mira apontada para onde a pessoa olha e bloqueio.

## Menus (`scripts/ui/legacy_gui.gd`)
- Estilo dos menus padrão das versões antigas da Unity (GUI.Box/GUI.Button): caixa preta
  translúcida com o título, botões cinza em degradê com borda escura, campos de texto escuros.
- O menu inicial fica na frente de uma cena 3D (carro e zumbi, câmera balançando). O menu de
  pausa usa o mesmo visual.

### Como funciona (`scripts/net/net.gd`, autoload `Network`, acesso por `Net.i`)
- **Mundo:** todo mundo gera o mesmo mapa pela mesma semente (terreno, cidades, pista, frutas).
  Só passa pela rede o que muda.
- **Zumbis:** a IA roda **só no host**. Nos clientes eles são marionetes que seguem a posição e o
  estado (~15x/s, só os que estão a até 170 m) e repetem os eventos visuais (ragdoll, membro
  arrancado, braço quebrado, levantar, arma). O host gera zumbis, terreno e cidades em volta de
  **todos** os jogadores, e cada zumbi persegue o jogador mais perto.
- **Golpes:** quem bate calcula o acerto na hora (sem atraso) e manda o golpe para o host aplicar
  (espada, taco, colher, tiro, chute, explosão, atropelar, deslizar, empalar). O dano dos zumbis
  nos jogadores vai para o dono do boneco, que decide se bloqueou.
- **Itens:** o host decide quem pegou primeiro; o item some para todos. Itens soltos e armas que
  zumbis largam aparecem para todos.
- **Carros:** quem dirige simula a física e manda a posição (~20x/s); nos outros o carro só segue.
  Só uma pessoa dirige cada carro. Se o dono sair do jogo, o host assume o carro.
- Teste com dois processos: rode `tests/net_host.gd` e, logo depois, `tests/net_client.gd`
  (atalho por linha de comando: `godot -- --host --name=Fulano` ou `-- --join=IP`).

## Controles
| Tecla | Ação |
|---|---|
| WASD / Shift | mover / correr |
| Espaço | pular — de frente para obstáculo: **vault** (correndo, até o quadril e curto), **subir** (comprido ou até um pouco acima da cabeça) ou **pular cerca** |
| C | agachar — **correndo: deslizar** (passa por baixo dos zumbis e derruba quem estiver em cima) |
| Clique esquerdo | atacar com a arma do slot (sem arma: **soco**) |
| Botão direito | **bloquear** (espada/taco). Bloquear logo antes do golpe = parry (zumbi cambaleia) |
| Shift + segurar clique (espada) | **empalar** até 3 zumbis (só de frente ou de costas); parou → chuta todos |
| F | chute em área |
| 1–5 / Q / roda | escolher slot da hotbar |
| Tab | mochila (arraste os itens entre os slots) |
| E / G | pegar / soltar item |
| M | mapa do mundo (o minimapa fica no canto de baixo à direita) |
| L | lanterna (precisa estar no inventário e ter bateria) |
| R | recarregar a pistola |
| Enter | chat (comandos do host: `/noite`, `/dia`, `/hora N`, `/horda`) |
| B / botão do meio | marcar (ping) onde mira |
| Botão direito (pá) | cavar cova / plantar / colher |
| E (no carro) | entrar/sair. Dirigindo: W/S acelera/ré, A/D vira, Espaço freio de mão |
| Z / H | novo zumbi / **100 zumbis** em volta (teste, só o host online) · Backspace recomeça · **Esc pausa** (Continuar / Recomeçar / Sair) |

## Área inicial e carro
- Ao lado de onde você nasce: uma bancada coberta (com lâmpada) com **um exemplar de cada arma**
  — espada, taco, cajado e pistola — e a lanterna.
- Estacionado ao lado, virado para a saída sul da cidade: o **carro** (`scenes/vehicles/vintage_car.tscn`,
  `scripts/vehicles/vintage_car.gd`), inspirado no **Alfa Romeo 8C 2300 Monza (1932)**: capô
  comprido com venezianas, grade cromada em "coração", faróis torneados, para-lamas de moto curvos,
  rodas raiadas (pneu, aro, 16 raios cruzados, cubo knock-off), "rabo de barco" com estepe,
  escapamento lateral, feixes de mola, número 8 e volante à direita. Suspensão alta e com curso
  longo para fora de estrada; tração traseira, ~100 km/h.
- **Dirigir é em primeira pessoa**: você senta no banco, olha em volta com o mouse e as mãos
  ficam no volante (que gira com a direção). Sem para-brisa: o **velocímetro** (0–140 km/h,
  ponteiro funcionando) fica embutido no centro do painel.
- No ar (saltos, rampas) o carro segura o giro e se endireita devagar para cair de rodas.
- Pneus escorregam um pouco antes de tombar. Em alta velocidade a roda vira bem menos
  (100% parado, ~45% a 50 km/h, ~15% a 100 km/h). Dirigindo, volante e braços ficam semitransparentes
  e o mouse gira só a cabeça (o corpo fica sentado). **Faróis** acendem ao entrar; **L** liga/desliga.
- Atropelar derruba o zumbi (dano ~7 por m/s; rápido mata e pode arrancar membros).

### Garagem: mais 4 carros (`scripts/vehicles/cars/`)
Estacionados em duas fileiras ao lado do Monza. Cada um herda de `VintageCar` e só muda a
**ficha** em `_configure()` (medidas, peso, curva de torque, aderência, banco/volante) e a
carroceria em `_build_body()`.

| Carro | Inspiração | 0–100 | Máx. | Como anda |
|---|---|---|---|---|
| Aero V12 | especial feito à mão com V12 de avião | ~6 s | ~180 km/h | pesado, puxa forte em alta, vira devagar (entre-eixos enorme) |
| Brutus | BMW Brutus (V12 de avião num chassi de 1907) | ~3,5 s | ~170 km/h | **torque demais**: acelerando na curva a traseira sai de lado (~30°); volante reto ou contra-esterço trazem de volta |
| Darracq V8 | Darracq V8 de recorde (1905) | ~5 s | ~180 km/h | levíssimo, fraco embaixo e bravo no giro, direção nervosa, freio fraco |
| Hall-Scott Four | especial de 1917 com motor Hall-Scott | ~9 s | ~125 km/h | muita força no arranque que acaba cedo |

- Curva de torque: `torque_low` / `torque_peak` / `torque_high` (fração da força no arranque,
  onde fica o pico e quanto sobra na máxima). `wheelspin` tira aderência da traseira com o pé
  no fundo; `drift_max` limita o quanto o carro fica de lado.
- Teste: `tests/test_cars.gd` (arrancada e curva de cada carro; `CAR=brutus` testa só um).

## Estilo visual
- **Seres vivos** (player, zumbis, animais no futuro) são em **blocos**.
- **Todo o resto** é **poligonal estilo PS2**: poucos lados, sombreamento suave mas silhueta
  facetada — nunca completamente liso. Peças complexas (painel, rodas) podem ter mais polígonos.
- **Mãos** (`scripts/util/blocky_hand.gd`): em blocos, com 4 dedos e polegar. O player segura
  as armas e o volante com a mão fechada; zumbis têm dedos tortos de garra.
- **Temas:**
  - **Carros:** pré-guerra — de corrida (como o Alfa 8C Monza) e, no futuro, civis.
  - **Armas:** **medieval steampunk** — aço, ferro, latão, cobre, couro e madeira, com
    formas simples, poucas peças — tudo gasto e fosco (pós-apocalíptico).
  - **Arquitetura:** **medieval com um toque de steampunk, em ruínas** (pedra, madeira,
    telhados quebrados, canos e caldeiras abandonadas).
- `scripts/util/mesh_builder.gd` gera essas malhas por código: seções interpoladas (`loft`),
  peças torneadas (`lathe`), toros, tubos ao longo de um caminho, chapas curvas e extrusões.

## Armas (`scripts/items/item_models.gd`)
Modelos medieval steampunk **simples** (poucas peças retas, no máximo uma cinta de latão), feitos
com o `MeshBuilder`. A mesma função alimenta a arma na mão, o item no chão, a arma dos zumbis e
os ícones.
- **Espada:** lâmina de aço em losango, guarda reta de latão, cabo liso de couro, pomo de ferro.
- **Maça:** cabo de madeira com empunhadura de couro, cabeça de ferro octogonal com 4 flanges e
  uma cinta de latão.
- **Cajado:** cabo de madeira, ponteira de ferro, uma cinta de latão e o orbe preso por 3 garras.
- **Pistola:** cano de latão, tambor e armação de ferro, cão, guarda-mato, coronha de madeira.
- **Carregador** (inspirado no do Metro Exodus): dínamo de mão horizontal: motor de ferro deitado
  com bobina de cobre embaixo, alavanca vermelha, medidor com ponteiro da bateria e vários fios. Equipe na hotbar e
  **clique rápido** para carregar; o volante na ponta esquerda gira.
  A carga só aparece no ponteiro do carregador. A lanterna gasta a bateria (~2,5 min cheia) e a
  luz vai ficando mais fraca bem aos poucos (é preciso prestar atenção para notar) até apagar.
- **Colherona:** colher de sopa ridiculamente grande (1,5 m). Lenta, pouco dano, e **arremessa
  o zumbi ~10 m** girando (`spoon_launch`).
- **Gancho:** clique e **segure** para prender e balançar (pêndulo com um impulso para cima ao
  prender, WASD controla no ar); a corda **se recolhe sozinha** quando você chega perto; soltar o clique solta a corda e mantém o impulso no ar. Alcance 45 m.
  **5 cargas**; acabou, espere ~6 s sem usar para recarregar todas (usar de novo reinicia a contagem).
- **Lanterna** de latão, **sucata**, **pano** e **fita**.

## Chinelo e bumerangue (`scripts/weapons/`)
- **Chinelo** (no chão, ao lado da bancada): clique joga no zumbi mais perto do centro da mira e
  **sempre acerta a cabeça** (headshot): o zumbi cai **duro para trás**, braços e pernas juntos, como
  uma tábua, e só no chão vira ragdoll. Depois o chinelo **volta para a mão**; dá para ter **2 no ar**
  (o HUD mostra quantos sobraram) e aí é preciso esperar um voltar.
- **Bumerangue:** vai até o zumbi mirado e **ricocheteia** de zumbi em zumbi (até **5**, os mais perto
  num raio de 14 m). A cada acerto ele **sobe** e cai em arco no próximo; cada acerto tem **40% de
  chance de atordoar** (o zumbi fica parado cambaleando ~2 s). Voa devagar, grande e com rastro para
  dar para acompanhar; **só um por vez**: espere ele voltar para a mão (HUD: "voltando...").
- Online os outros veem o arremesso no seu boneco e o chinelo/bumerangue voando.
- Teste: `tests/test_throwables.gd`.

## Inventário
- `scripts/items/item_db.gd`: catálogo (nome, tipo, pilha, modelo 3D). Item novo = uma entrada lá.
- `scripts/items/inventory.gd`: 5 slots de hotbar + 15 de mochila. Armas/ferramentas vão para a
  hotbar; materiais para a mochila (empilham até 10).
- As armas ficam **no mapa** (espada, taco e lanterna perto do início; cajado na plataforma;
  pistola em cima do contêiner). O player começa sem nada.
- A arma na mão é a do slot selecionado; slot sem arma = punhos.

### Ícones e janela de informação
- `scripts/items/item_icons.gd` (autoload `ItemIcons`) fotografa o modelo 3D de cada item
  (64x64, fundo transparente) — **ninguém precisa desenhar ícone**.
- Os PNGs ficam **na pasta do jogo**: `assets/icons/` (vão no repositório e no jogo exportado).
- Rodando pelo editor, o jogo confere a assinatura em `assets/icons/manifest.txt`
  (`application/config/version` + `RENDER_VERSION` + conteúdo do `ItemDB`). Mudou item ou versão →
  fotografa de novo e regrava os PNGs. A GPU só desenha a foto uma vez; nada fica guardado nela.
- No jogo exportado os PNGs são só carregados. Faltou algum? É gerado em `user://icon_cache/`.
- Os slots mostram só o ícone (e a quantidade). Passando o mouse na mochila aparece uma
  janelinha que segue o mouse com nome, tipo de dano, dano, empurrão e descrição
  (campos `damage_type`, `damage`, `knockback`, `desc` no `ItemDB`).

## Mapa aberto (`scripts/world/`)
- `terrain_world.gd`: mapa de **3 km x 3 km** gerado pela semente (`seed`; `randomize_seed`
  para sortear). Norte = **inverno** (morros com neve, floresta densa de pinheiros), meio =
  **planícies** onduladas (morros + elevações menores) e **montanhas** (~30% do mapa, formas
  **arredondadas** de até ~110 m, com pé baixo e picos só no meio das cordilheiras — sem paredões: grama embaixo, rocha no alto e nas encostas íngremes — boas
  para andar e para estradas no futuro), sul = **deserto** com dunas fortes (até ~16 m) e cactos.
  Bordas sobem em montanhas; o centro é a cidade.
- O terreno vem em pedaços de 64 m que aparecem perto do player e somem longe (até 220 m).
  O cálculo roda em threads; a thread principal só monta os nós (~2.5 ms por pedaço).
- `terrain_props.gd`: árvores normais, **tortas**, **gigantes** e **frutíferas** (frutas no chão:
  pegue e clique para comer, +25 de vida), arbustos, pinheiros, rochas, **3 tipos de cacto grandes
  e tortos** e muita **grama/arbustos de folhas cruzadas** (estilo Minecraft), via MultiMesh, com
  colisão no tronco/rocha. Planejado em thread. Sempre os mesmos para a mesma semente.
- `race_track.gd`: **autódromo** no deserto inspirado na The Motor Raceway (FlatOut 2), com
  traçado 3D (cada ponto tem altura; o terreno é moldado pela pista). Tudo aberto, sem trechos fechados:
  - **oval** com as **curvas inclinadas** (~10°) e uma **lombada na reta oposta** que faz o carro voar a partir de ~85 km/h;
  - **misto**: desce numa valeta, sobe o **morro do infield**, **grampo** lá em cima e desce em S;
  - **cruzamento** de ponta a ponta num **rebaixo** de barrancos suaves; o misto passa por cima numa **ponte**;
  - **atalhos de terra**: um corta a curva 1 por dentro (**rampa** sobre uma valeta), outro sai do grampo e
    **pula por cima do rebaixo**;
  - muretas vermelho/branco seguindo a inclinação, pneus, placas, largada quadriculada, pórtico e arquibancada.
  - Traçado em constantes no topo do arquivo (`INFIELD`, `CROSS`, `SHORTCUT_*`, `RAMPS`); teste em `tests/test_track.gd`.
- `biome_atmosphere.gd`: neblina por distância conforme o bioma, com transição suave:
  planície ~130 m, deserto ~150 m, montanha ~115 m, **neve ~50 m** (com neve caindo e sol mais
  fraco). Valores na tabela `FOG`.
- `zombie_spawner.gd`: mantém ~14 zumbis entre 45 e 110 m do player (mais no inverno) e apaga os
  que ficam a mais de 200 m. Fora da cidade eles andam em linha reta (sem NavigationMesh).

## Movimento (`scripts/player/parkour.gd`)
- **Peso:** aceleração e frenagem graduais, queda mais pesada que a subida, balanço de cabeça; a animação das pernas tem velocidade máxima (não acelera no gancho/no ar).
- Sonda à frente: altura do topo e profundidade do obstáculo decidem o movimento.
  - até `vault_max_height` (1.3 m) e até `vault_max_depth` (1.6 m), correndo → passa por cima;
  - mais comprido (ex.: carro no sentido do comprimento) → sobe em cima;
  - até `climb_max_height` (2.3 m): fino (cerca) → passa para o outro lado; grosso → sobe.
- Deslizar desliga a colisão com zumbis e chama `Zombie.trip()` em quem passar por cima.
- **Deslize:** o **mouse** curva de leve; ladeira abaixo ele acelera e não para até o chão ficar plano.
- **Vault** em objetos de até 4 m de comprimento (capô de carro no sentido do comprimento, mesas).
- **Sem perder o ritmo:** deslizar termina na velocidade de corrida (ou de andar), vault e subir
  saem na mesma velocidade em que entraram (a duração depende dela). Só escalar a cerca para.
- **Animação:** mãos apoiando no obstáculo (as duas ao subir/escalar, a esquerda no vault e
  arrastando no chão no deslize), câmera inclinando e mergulhando, pernas encolhidas no corpo e
  "afundada" da cabeça ao aterrissar.

## Estrutura
```
scenes/
  main.tscn            fase em CSG (blockout, editável no editor)
  player.tscn          CharacterBody3D + câmera + arma
  zombie.tscn          CharacterBody3D + Skeleton3D com os módulos abaixo
  ui/hud.tscn          vida, stamina, mira, avisos (CanvasLayer 2)
  ui/retro_screen.tscn pós-processamento (CanvasLayer 1, não afeta o HUD)
scripts/enemies/
  zombie.gd            IA, vida, dano por osso, equilíbrio, estados (andar, atacar, tranco, cambalear, cair, levantar, morrer)
  humanoid_rig.gd      monta o boneco de teste (ossos, visual, hitboxes, ossos físicos)
  zombie_locomotion.gd animação procedural (andar, ataque, inclinação, agachar, cambaleio, joelho cedendo)
  hit_reaction.gd      SkeletonModifier3D: tronco tomba e volta como mola (pernas de fora)
  limp_limbs.gd        SkeletonModifier3D: membros quebrados pendurados (pêndulos)
  ragdoll.gd           PhysicalBoneSimulator3D: liga/desliga física, impulsos, blend para levantar
scripts/player/player.gd   player, espada, cajado, chute, interação
scripts/weapons/           míssil mágico e explosão
scripts/effects/impact_fx.gd  sangue, faíscas, rastro de bala
scripts/combat/hit_info.gd    dados de um golpe (dano, osso, força, tipo CUT/BLUNT/PIERCE, bias)
scripts/net/net.gd            multiplayer LAN (autoload Network; use Net.i)
scripts/ui/main_menu.gd       menu inicial (solo / multiplayer: lista, IP, criar)
scripts/ui/legacy_gui.gd      visual dos menus (Unity antiga)
scripts/building/             construção (peça com 98 triângulos, grade, martelo/talhadeira)
shaders/retro_screen.gdshader
tests/                 testes headless (ragdoll, juntas, jogo)
```

## Camadas de colisão
| # | Nome | Quem usa |
|---|---|---|
| 1 | mundo | chão, paredes, caixas |
| 2 | player | player |
| 3 | inimigo | cápsula do zumbi (de pé) |
| 4 | ragdoll | ossos físicos (só quando caído/morto) |
| 5 | hitbox | Area3D por osso (só de pé) |
| 6 | interagivel | itens que dá para pegar |

## Como funciona o combate
1. Cada golpe é um **arco**: a lâmina gira em volta de um eixo (tabela `SWINGS` em `player.gd`)
   em três fases — preparação, corte e volta para a guarda — com rastro do corte na tela.
2. Durante o corte, raios seguem a lâmina pelo trecho do arco percorrido a cada frame.
   Acertou a **hitbox** de um osso → `Zombie.take_hit(HitInfo)`;
   a direção é para onde a lâmina se move, então o zumbi é empurrado para o lado do corte.
   Um corte atravessa até 2 inimigos (`max_targets`).
3. Atacar **não gasta stamina** (stamina é só para correr).
4. Dependendo do golpe:
   - **Tronco**: a reação física (`HitReaction`) atua só da cintura para cima — o tronco é
     jogado na direção do golpe e volta para cima como mola, braços chicoteiam.
     **Pernas ficam firmes**: o corpo agacha dobrando os joelhos com os pés no lugar.
   - **Equilíbrio** (`balance` em `zombie.gd`): cada golpe tira equilíbrio, golpe na perna tira
     mais e faz o joelho ceder. O equilíbrio volta sozinho com o tempo.
     - abaixo de `stumble_at` → tranco curto, já volta a atacar;
     - acima de `stumble_at` → **cambaleia como bêbado**: passos em ziguezague para trás,
       tronco inclinado, braços abertos, quase cai;
     - acima de `fall_at` (ou apanhou cambaleando) → cai em ragdoll e depois levanta.
   - **Tranco**: um ou dois passos para trás (dois com golpe forte, como o taco).
   - **Membros com vida própria** (cabeça 70, braço 35, perna 50 — grupo "Membros" no
     inspetor do Zombie). Quando a vida do membro acaba:
     - **corte** (espada) → o membro **sai voando** (corpo físico, toco sangrando);
     - **impacto** (taco, chute) ou **tiro** → o osso **quebra**: o membro fica mole,
       balançando como ragdoll (`limp_limbs.gd`);
     - cabeça destruída mata; braço inutilizado = ataque mais fraco;
     - **perna arrancada ou quebrada** → o zumbi cai e passa a **rastejar** (mais lento,
       cápsula deitada, ataca mais fraco).
   - **Golpes da espada favorecem membros diferentes** (`bias` em `SWINGS`, `player.gd`):
     horizontais decepam cabeça (2x) e pernas (1.8x) conforme a altura em que pegam;
     o golpe de cima arranca braços (2.4x).
   - **Impacto derruba mais**: taco e chute tiram 1.45x mais equilíbrio
     (`blunt_balance_multiplier`); tiro tira metade.
   - **Explosão que mata despedaça o corpo inteiro**: cabeça, braços e pernas voam.
   - **Levantar em etapas** (poses procedurais em `zombie_locomotion.gd`): de bruços →
     apoio nas mãos e joelhos → ajoelhado → de pé; de costas → senta → agacha → de pé.
     Dá para derrubar de novo no meio. Quem rasteja volta direto a rastejar.
   - **Membro quebrado** recebe só 15% do dano (`broken_limb_damage`).
   - **Encontrão**: zumbi cambaleando (ou voando em ragdoll) empurra os outros um pouco.
   - **Morte** → ragdoll permanente; continua dando para bater/chutar o corpo.
5. O *hitstop* (jogo quase para por 50–70 ms) e o tremor de câmera dão peso ao impacto.

## Cidades (`scripts/world/city_gen.gd`, `city_manager.gd`)
- Geradas pela semente: **2 grandes**, **4 médias** e **7 vilas**, em terreno plano (fora das
  montanhas), com o chão achatado, formato **quase quadrado** (grade de quarteirões com bordas
  comidas) e ruas: **avenida** no eixo central, **ruas comuns** na grade e **terra** na borda e
  nas vilas. **Avenidas** tortas (curvas largas + desvios a cada ~35 m) ligam as cidades grandes e médias pelo mapa.
- Torres altas ganham **ramificações tortas** como os cactos: um braço (ponte fechada) que sai
  do meio do prédio e vira uma mini-torre inclinada com telhado.
- Casas medievais com toque steampunk, em ruínas, no estilo **Hello Neighbor**: andares
  empilhados de tamanhos diferentes, tortos e deslocados, puxadinhos, telhados íngremes (alguns
  desabados, com os caibros à mostra), chaminés, canos de cobre, caldeiras, janelas tapadas.
- **Grande:** torres-casa de até 15 andares (~50 m) no centro, baixando para fora; caldeira gigante
  com chaminé na praça. **Média:** 2–6 andares. **Vila:** casinhas de 1–2 andares espalhadas,
  cercas e um poço.
- São construídas aos poucos quando você chega perto (2 casas por frame) e apagadas longe; cada
  uma ganha zumbis nas ruas. Aparecem no mapa e no minimapa.

## Mapa (`scripts/ui/world_map.gd`)
- Gerado uma vez, em thread, a partir do próprio terreno (cor do bioma + sombreado do relevo,
  8 m por pixel) com os prédios da cidade por cima. Leva ~1 s no início.
- **Minimapa** (320 m, norte para cima): seta do player, carro e zumbis próximos.
- **M**: mapa do mundo inteiro com o player, o carro e a legenda dos biomas.

## Zumbis: navegação, escalada, armas e lanterna
- **Contornam obstáculos** com NavigationMesh gerado da fase ao iniciar (`main.gd`).
- **Escalam** só quando o caminho em volta é mais que o dobro da distância reta (ou não existe)
  e o obstáculo tem até 2.3 m (`climb_detour_ratio`, `climb_max_height`). Atrás da cerca longa
  do norte tem um zumbi para testar.
- **30% nascem armados** (taco ou espada, `weapon_chance`): batem 1.6x mais forte e soltam a arma
  quando morrem ou perdem o braço direito — dá para pegar.
- **Lanterna** apontada para um zumbi **de frente** para você (até 45 m, com linha de visão)
  faz ele vir de qualquer distância.

## Modelo do player
- `scenes/player.tscn` → `Body/Skeleton3D`: o mesmo boneco em blocos dos zumbis (`HumanoidRig`,
  sem hitboxes), animado por `scripts/player/player_body.gd` (pernas andam/correm na direção do
  movimento, pulo dobra os joelhos).
- Olhando para baixo você vê as pernas; cabeça, tronco e braços do corpo só projetam **sombra**
  (`shadow_only_bones`) para não tapar a câmera.
- Braço em primeira pessoa (`_update_fp_arm` em `player.gd`): a mão segue a empunhadura da arma
  atual e o antebraço liga o ombro (fora da tela) até ela.

## Cajado e míssil mágico
- `scripts/weapons/magic_missile.gd`: voa a 24 m/s, curva de leve atrás do zumbi mais próximo
  à frente (`homing_turn`, `homing_cone`) e explode ao tocar em qualquer coisa.
- `scripts/weapons/explosion.gd`: **morte instantânea** até 1.3 m do impacto (medido até o
  ponto mais próximo do corpo — explosão no pé conta); até 3.5 m, dano com queda pela distância, joga os zumbis em
  ragdoll (força espalhada por todos os ossos), empurra caixas e treme a tela do player.
- Cadência em `cast_cooldown` (player). Sem mana por enquanto.

## Trocar o boneco por um modelo real (Mixamo, Blender…)
1. Importe o `.glb`/`.fbx` com esqueleto e animações.
2. Em `zombie.tscn`, troque o `Skeleton3D` (e remova `humanoid_rig.gd` e `Locomotion`).
3. Selecione o Skeleton3D do modelo → menu **Skeleton3D → Create Physical Skeleton**.
4. Coloque `ragdoll.gd` no `PhysicalBoneSimulator3D` gerado e ajuste os limites das juntas.
5. Adicione um `HitReaction` (filho do Skeleton3D, **antes** do simulador).
6. Para as hitboxes: `BoneAttachment3D` + `Area3D` (camada 5) com metadados `enemy` e `bone`.
7. Troque `locomotion.speed/attack/swing` em `zombie.gd` por parâmetros de um `AnimationTree`.
8. Atualize `BONE_DAMAGE` / `LEG_BONES` com os nomes de ossos do modelo.

## Visual 960x540 (16:9)
- `display/window/stretch/mode = viewport` → tudo (3D e UI) é renderizado em 960x540 e ampliado
  (escala exata 2x em 1080p e 4x em 4K).
- Para a versão 4:3 antiga, use 800x600.
- Texturas com filtro *Nearest + mipmaps*; o shader reduz para 32 níveis por canal com dithering.
- Ajuste as cores/intensidade no material de `ui/retro_screen.tscn`.

## Inventário / crafting (próximo passo)
- O player já emite `item_picked_up(item_id, amount)` e reserva a ação `inventory` (Tab).
- Sugestão: um autoload `Inventory` com `Dictionary` de itens + `Resource` para receitas;
  a UI entra como outra `CanvasLayer` (layer 3), já em 960x540, legível.

## Testes headless
```bash
godot --headless -s res://tests/test_game.gd
```
