# Reinos da Área — Protótipo Godot 4
## Jogo de estratégia territorial baseado em cálculo de área

---

## Estrutura do Projeto

```
reinos_da_area/
├── project.godot              ← configuração do projeto Godot 4
├── icon.svg                   ← ícone do projeto
├── scenes/
│   └── Main.tscn              ← única cena raiz (tudo criado programaticamente)
└── scripts/
	├── Main.gd                ← orquestrador: liga todos os sistemas
	├── GameManager.gd         ← estado, pontuação, progressão, timer
	├── TerritoryGenerator.gd  ← geração procedural de territórios (BFS orgânico)
	└── TerritoryRenderer.gd   ← renderização via _draw() (Node2D)
```

---

## Como abrir no Godot 4

1. Abra o **Godot 4** (versão 4.2 ou superior)
2. Clique em **Import** → navegue até a pasta `reinos_da_area/`
3. Selecione `project.godot` e clique em **Import & Edit**
4. Pressione **F5** (Play) para rodar

> **Atenção**: não é necessário configurar nenhum nó manualmente.
> Toda a cena é construída programaticamente no `Main.gd`.

---

## Arquitetura

### Main.gd (Node2D — raiz)
Ponto de entrada. Instancia e conecta todos os outros sistemas.
Responsabilidades:
- Criar GameManager, TerritoryGenerator e TerritoryRenderer
- Construir toda a UI programaticamente (sem depender de .tscn externo)
- Conectar os sinais do GameManager à UI e ao Renderer
- Orquestrar o fluxo de rodada (start → decision → result → restart)

### GameManager.gd (Node — filho de Main)
Pura lógica de jogo, zero visual.
Responsabilidades:
- Estado do jogo (fase atual, rodada, pontuação, streak)
- Timer de decisão com escalada de dificuldade
- Cálculo de resultado (ATACAR / DEFENDER / RECUAR)
- Progressão de dificuldade a cada 3 rodadas
- Emissão de sinais para comunicação

### TerritoryGenerator.gd (RefCounted — sem nó)
Algoritmo de geração procedural.
Responsabilidades:
- Gerar territórios orgânicos alinhados ao grid via BFS com peso aleatório
- Respeitar regiões separadas (esquerda = jogador, direita = inimigo)
- Controlar o tamanho exato em células (para balanceamento de dificuldade)

### TerritoryRenderer.gd (Node2D — filho de Main)
Desenho puro via `_draw()`.
Responsabilidades:
- Fundo e grid seletivo (grid visível sobre jogador, OCULTO sobre inimigo)
- Fill e borda de contorno para cada território
- Névoa sobre o inimigo (impede contagem visual)
- Animação de entrada (fade-in das células)
- Flash de resultado (verde = vitória, vermelho = derrota)
- Revelação do grid inimigo após o combate

---

## Mecânicas Implementadas

### Balanceamento de área
- Diferença entre territórios: 2% a 8% no nível 1
- Diferença diminui conforme a dificuldade sobe (mínimo 2%)
- Tamanho base: 40 a 80 células por território

### Sistema de decisão
| Ação | Vence quando |
|------|--------------|
| ATACAR | Sua área > área inimiga |
| DEFENDER | Área inimiga > sua área |
| RECUAR | Sempre empate (sem perda) |

### Progressão de dificuldade
- A cada 3 rodadas: `difficulty_level += 0.15` (máximo 5.0)
- Efeitos: timer mais curto, diferença de área menor
- Níveis: Aprendiz → Estrategista → Arquiteto → Mestre → Lendário

### Pontuação
- Vitória base: 100 pts
- Bônus de velocidade: até 200 pts (proporcional ao tempo sobrado)
- Bônus de sequência: +50 pts por vitória consecutiva além da primeira
- Derrota: -50 pts (mínimo 0)
- Empate: sem alteração

---

## Controles

| Tecla | Ação |
|-------|------|
| **A** | Atacar |
| **D** | Defender |
| **R** | Recuar |
| Clique no botão | Mesma ação |

---

## Extensões Futuras (planejadas para v0.2)

- [ ] Sistema de habilidades por arquétipo (Estrategista/Engenheiro/Guerreiro)
- [ ] Painel HUD detalhado com painel esquerdo/direito
- [ ] Múltiplos territórios por fase
- [ ] Modos de visão (névoa de guerra progressiva)
- [ ] Sons e música ambiente
- [ ] Save de pontuação entre sessões

---

## Dependências
- Godot 4.2+
- Nenhuma plugin ou asset externo necessário
