# Roadmap: máquinas, energia e sobrevivência

Este documento divide o design de máquinas em fases que podem ser jogadas uma de cada vez.
Cada fase só usa o que as anteriores já entregaram.

## O que o jogo já tinha antes deste roadmap
- Fogueira com grelha (cozinha comida crua).
- Mesa de trabalho.
- Fornalha de barro (minério → barra, com combustível).
- Fome, plantação, lagos, pesca.
- Construção em grade e o sistema de objetos colocados (`PlacedManager`).
  Ele já sincroniza na rede, vai no save e é a base de todas as máquinas.

## Sistemas que faltavam (pré-requisitos)

| Sistema | Usado por | Fase |
|---|---|---|
| Sede + garrafas de água | coletor, bomba, filtro, caldeira | 1 |
| Clima (chuva, vento) | coletor de chuva, moinho de vento, painel solar | 1 |
| Doença por água suja | filtro, destilaria (álcool antisséptico) | 1 |
| Argila (pá na beira do lago) → tijolo | fogueira, fornalha de pedra, alto-forno | 1 |
| Comida estragando (frescor no slot, igual à durabilidade) | secador, defumador, geladeira | 2 |
| Animais (carne, pele, fibra) | secador de pele, roca/tear | 3 |
| Rios (água corrente) | roda d'água, carneiro hidráulico | 4 |
| Frio / temperatura (biomas, noite, roupa) | calor da fogueira, roupa com isolamento | 3 |

## Arquitetura das máquinas

### `Machine` (base comum)
- Objeto colocado com:
  - slots de entrada e saída (baú interno, igual ao `ContainerManager`);
  - receitas `{entrada, saída, tempo}`;
  - progresso calculado pelo relógio do host, igual à plantação.
- Funciona sem ninguém por perto e continua certo depois de carregar o save.

### Energia mecânica (Tier 1)
- A máquina manual consome **stamina** enquanto o jogador segura o botão (manivela).
- Exemplos: pedra de amolar, moinho manual, bomba manual, fole, roca.

### Energia rotacional (Tier 2)
- **Grafo de eixos.** Cada eixo ou correia liga duas portas.
- Uma busca no grafo (BFS) acha os componentes conectados.
- Em cada componente:
  - a potência gerada (roda d'água, moinho de vento) é dividida pela demanda das máquinas;
  - sobrando pouca energia, a máquina anda mais devagar (`velocidade = min(1, oferta / demanda)`).
- Recalcula só quando a rede muda e, depois disso, a cada 1 s (o vento varia).

### Canos (água e vapor)
- **Rígidos.**
- Como colocar:
  1. clique numa entrada ou saída;
  2. arraste e solte para criar um segmento reto;
  3. clique no fim do segmento para continuar a seção.
- Cada segmento é um nó da rede de fluido.
- Volume e pressão são simulados por componente: a água sai de um tanque ou bomba e vai para os consumidores.

### Cabos elétricos (Tier 4)
- **Conectores** colocáveis em parede, pilar ou máquina.
- O cabo liga dois conectores e é desenhado como **catenária** (barriga para baixo, proporcional ao comprimento), sem física.
- Malha simples: um tubo fino seguindo a curva `y = a·cosh(x/a)` aproximada por 12 pontos.
- Rede elétrica:
  - mesmo grafo e mesma divisão de oferta/demanda;
  - baterias carregam com o que sobra e descarregam quando falta.

## Fases

1. **Tier 0 completo + sede, clima e doença** *(feito nesta rodada)*
   - Sede, garrafa, água suja e potável.
   - Doença temporária.
   - Chuva e vento.
   - Coletor de água da chuva.
   - Secador (peixe → peixe seco).
   - Argila → tijolo na fogueira.
   - Fogueira acesa afasta zumbis à noite.
2. **Comida estragando + Tier 1 manual**
   - Base `Machine` com manivela, gastando stamina.
   - Pedra de amolar, moinho manual (trigo → farinha → pão no forno).
   - Bomba manual (água suja), filtro de areia/carvão.
   - Fole + fornalha de pedra (de tijolo).
   - Defumador, composteira.
3. **Animais e frio**
   - Carne, pele e fibra.
   - Secador de pele (couro).
   - Roca e tear (fio → tecido → roupa quente).
   - Frio por bioma e noite.
4. **Tier 2**
   - Rios, roda d'água, moinho de vento.
   - Eixos e correias (grafo de energia rotacional).
   - Serraria, carneiro hidráulico (irrigação).
5. **Tier 3**
   - Canos rígidos e rede de fluido.
   - Alto-forno multibloco (aço).
   - Caldeira (explode sem água), motor a vapor.
   - Torno (eixo, parafuso, engrenagem), prensa (óleo, suco).
   - Destilaria (álcool: antisséptico e combustível dos carros).
6. **Tier 4**
   - Cabos com catenária e conectores de parede.
   - Dínamo, bateria, painel solar.
   - Bomba elétrica, cerca elétrica, iluminação.
   - Geladeira (para a comida de estragar).
   - Rádio (eventos e missões).
