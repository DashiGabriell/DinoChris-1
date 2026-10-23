# O Super T-Rex Corajoso — documento de projeto (Godot 4)

Game de corredor 3D estilo Crash Bandicoot para uma criança de 4 anos que ama T-Rex.
Foco: **sensação de poder** (correr, rugir, quebrar) sem dificuldade, sem game over e sem punição.

---

## 1. Pilares de design (o que vale e o que não vale)

**Vale:**
- Corredor linear 3D. Nada de mundo aberto — criança de 4 anos se perde e desiste.
- Poucos botões: analógico (direção) + pular + rugir.
- Feedback exagerado: som alto, partículas, tremor de tela, caixas voando.
- Erro nunca custa nada: cair ou bater = cambalhota engraçada e volta na hora.

**Não vale:**
- Game over, vidas, cronômetro, contador de mortes.
- Pulos com timing preciso, plataformas estreitas, câmera que gira sozinha.
- Texto na tela. Ícone e áudio bastam.

---

## 2. Controles

### Ações no Input Map (Projeto → Configurações do Projeto → Mapa de Entrada)

| Ação | Teclado | Controle (PlayStation) | Botão Godot |
|---|---|---|---|
| `mover_frente` | W / ↑ | Analógico esquerdo para cima (eixo 1) / D-pad ↑ | `JOY_AXIS_LEFT_Y` negativo |
| `mover_tras` | S / ↓ | Analógico esquerdo para baixo (eixo 1) / D-pad ↓ | `JOY_AXIS_LEFT_Y` positivo |
| `mover_esquerda` | A / ← | Analógico esquerdo (eixo 0) / D-pad ← | `JOY_AXIS_LEFT_X` negativo |
| `mover_direita` | D / → | Analógico esquerdo (eixo 0) / D-pad → | `JOY_AXIS_LEFT_X` positivo |
| `pular` | Espaço | X (Cruz) ou B (Bola) | `JOY_BUTTON_A` (0) / `JOY_BUTTON_B` (1) |
| `rugido` | E | Quadrado ou Triângulo | `JOY_BUTTON_X` (2) / `JOY_BUTTON_Y` (3) |

Observações importantes:
- O Godot usa **nomenclatura de layout Xbox**: o "X/Cruz" do PlayStation é `JOY_BUTTON_A` (0) e o "Quadrado" é `JOY_BUTTON_X` (2). O controle é detectado automaticamente (SDL), não precisa plugin.
- Configure **deadzone 0.25** nas ações de eixo (clique no eixo dentro do Input Map). Isso evita o dino andar sozinho com o analógico solto.
- Deixe `rugido` e `pular` mapeados também no teclado: só você vai testar no PC.
- **O avanço é manual**: o dino fica parado até o jogador empurrar o analógico para cima (ou W / ↑). Empurrar para baixo faz recuar devagar. O D-pad funciona como alternativa ao analógico em controles simples.

---

## 3. Estrutura de nós do T-Rex

```
TRex (CharacterBody3D)            # grupo "jogador", camada 2
├── Corpo (CollisionShape3D)      # cápsula, não esfera
├── Modelo (Node3D)               # modelo/animações do dino
├── RugidoArea (Area3D)           # monitorando sempre, mask = camada 3
│   └── CollisionShape3D          # esfera de ~3,5 m
└── CameraRig (Node3D)            # posição (0, 2.5, 0)
    └── SpringArm3D               # inclinação ~-15°, spring_length ≈ 5,5
        └── Camera3D              # FOV 70
```

Por que `SpringArm3D`: a câmera filha direta funciona, mas atravessa paredes e deixa a criança sem referência. O SpringArm afasta a câmera para trás automaticamente quando há geometria no caminho. Para um corredor reto **não** use lerp/suavização no começo: câmera rígida é mais fácil de ler para uma criança.

Camadas de colisão sugeridas:

| Camada | Uso |
|---|---|
| 1 | Cenário / chão |
| 2 | Jogador |
| 3 | Quebráveis (caixas, barreiras) |
| 4 | Coletáveis e gatilhos |

---

## 4. Script do jogador (corrigido)

```gdscript
extends CharacterBody3D

@export var velocidade_frente: float = 6.0
@export var velocidade_tras: float = 3.5
@export var velocidade_lateral: float = 7.0
@export var forca_pulo: float = 6.0

@onready var rugido_area: Area3D = $RugidoArea

var gravidade: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var checkpoint: Vector3
var _rugindo: bool = false
var _quebrando: bool = false

func _ready() -> void:
	checkpoint = global_position
	rugido_area.monitoring = true   # fica ligada o tempo todo (ver seção 5)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravidade * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("pular") and is_on_floor():
		velocity.y = forca_pulo
		$AudioPulo.play()

	var direcao := Input.get_axis("mover_esquerda", "mover_direita")
	var frente := Input.get_axis("mover_tras", "mover_frente")
	var velocidade_z := velocidade_frente if frente >= 0.0 else velocidade_tras

	velocity.x = direcao * velocidade_lateral
	velocity.z = -frente * velocidade_z

	move_and_slide()

	_quebrar_no_impacto()

	if Input.is_action_just_pressed("rugido") and not _rugindo:
		executar_rugido()

func _quebrar_no_impacto() -> void:
	for i in get_slide_collision_count():
		var alvo := get_slide_collision(i).get_collider()
		if alvo and alvo.is_in_group("quebravel") and alvo.has_method("quebrar"):
			alvo.quebrar()

func executar_rugido() -> void:
	_rugindo = true
	$AudioRugido.play()

	# Não use area_entered: caixas já sobrepostas não disparam o sinal.
	# Perguntamos à área quem está dentro agora.
	for corpo in rugido_area.get_overlapping_bodies():
		if corpo.is_in_group("quebravel") and corpo.has_method("quebrar"):
			corpo.quebrar()

	await get_tree().create_timer(0.4).timeout
	_rugindo = false

func voltar_ao_checkpoint() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	# Aqui entra a animação de cambalhota engraçada
```

Correções aplicadas em relação ao rascunho original:
- `ProjectSettings.get_setting(...)` retorna Variant → cast com `float()`.
- `disabled = false` dentro de `_physics_process` dava erro; a área agora fica sempre monitorando.
- `await` em `executar_rugido` não trava o `_physics_process` (a chamada retorna na hora), e a flag `_rugindo` evita rugidos empilhados.
- Trombada resolvida via `get_slide_collision`, sem precisar de `Area3D` em cada caixa.
- Avanço **manual** (só com o direcional para cima) — as regras anti-softlock da seção 8 continuam valendo para quando o jogador insiste em andar e fica preso.

---

## 5. Caixa quebrável

Caixa **não** é `Area3D`: precisa bloquear o dino fisicamente. Use `StaticBody3D` no grupo `quebravel`, camada 3.

```
Caixa (StaticBody3D)              # grupo "quebravel"
├── Malha (MeshInstance3D)
├── Colisao (CollisionShape3D)
└── Destroco (GPUParticles3D, one_shot = true, emitting = false)
```

```gdscript
extends StaticBody3D

var _quebrada: bool = false

func quebrar() -> void:
	if _quebrada:
		return
	_quebrada = true
	$Destroco.restart()
	$Destroco.emitting = true
	$AudioQuebra.play()
	# Tira a colisão na hora e remove o visual depois do som/partícula
	set_deferred("collision_layer", 0)
	await get_tree().create_timer(0.6).timeout
	queue_free()
```

Dica: para pedaços voando de verdade, instancie um `RigidBody3D` pequeno (3–5 fragmentos) no lugar da caixa. Isso é o efeito que mais impressiona criança nessa idade.

---

## 6. Queda e respawn (o "sem game over")

Nada de morte. Uma `Area3D` grande embaixo da fase detecta a queda e devolve o dino ao último checkpoint.

```
ZonaDeQueda (Area3D)              # y abaixo do chão, mask = camada 2
└── CollisionShape3D (BoxShape3D gigante)

Checkpoint (Area3D)               # mask = camada 2, espalhados pela fase
└── CollisionShape3D
```

```gdscript
# ZonaDeQueda
extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("voltar_ao_checkpoint"):
		body.voltar_ao_checkpoint()
```

```gdscript
# Checkpoint
extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("voltar_ao_checkpoint"):
		body.checkpoint = global_position + Vector3(0, 0.2, 0)
		$AudioCheckpoint.play()
```

Regra: coloque checkpoint antes de cada trecho com buraco ou obstáculo. A criança nunca deve repetir mais de ~15 segundos de jogo.

---

## 7. Comida saudável (coletáveis)

- Quatro comidas se alternam pelo corredor: **carne** (coxão com osso), **fruta** (maçã), **vegetal** (cenoura) e **água** (gota). São `Area3D` com o grupo `coletavel` e o tipo escolhido na propriedade `tipo` da cena.
- O desenho é montado por código em `coletavel.gd` (esferas, cilindros e caixas), então não precisa de modelo importado.
- Ao entrar: som curto, some (`queue_free()`) e conta para a missão.
- Coloque em **trilha** (5–8 seguidos), não isolados — a trilha ensina o caminho sem texto.
- Nunca coloque comida exigindo pulo preciso.

### Missão e níveis

- Meta do nível 1: **8 comidas**; cada nível seguinte pede 1 a mais (até 15).
- Ao completar a meta: toca o som `nivel`, o HUD mostra **NÍVEL 2!**, a barra zera e o corredor **repõe as comidas** (as que o dino está pisando só voltam na próxima reposição, para não ganhar de graça).
- O HUD (canto superior direito) mostra `NÍVEL`, `COMIDA: X / meta`, a barra do nível e o `TOTAL` acumulado.
- Ao dar a volta no corredor, as comidas também são repostas e o nível continua de onde parou.

---

## 8. Anti-softlock (corredor com avanço manual)

O dino agora fica parado até o jogador mandar. O risco de softlock é quando a criança segura o direcional para frente e o dino trava em algo. Regras obrigatórias:

1. **Corredor largo**: mínimo 8 m livres.
2. **Curvas suaves**: no máximo ~10° por segmento, ou nenhuma curva (preferível).
3. **Nada de canto morto**: toda parede lateral deve desviar o dino para frente, nunca segurá-lo.
4. **Obstáculos macios**: troncos baixos (pula fácil) e caixas (quebra no impacto). Nada que exija desvio milimétrico.
5. **Velocidade 5–6 m/s**, pulo ~1,2 m de altura. Ajuste esses dois números com o seu filho jogando — é a única métrica que importa.
6. Se o jogador segurar o avanço e o dino ficar mais de 2,5 s sem sair do lugar (`global_position.z` parado), reposicione no checkpoint. Ficar parado sem apertar nada **não** conta.

---

## 9. Construção da fase

- **GridMap** para chão, paredes e decoração modular (grama, pedra, osso). Desenhar o corredor é rápido e o alinhamento é automático.
- Blocos de 2 m ou 4 m; corredor de 3–4 blocos de largura.
- Cenário sugerido para a primeira fase: floresta tropical com vulcão ao fundo (fundo em parallax/`WorldEnvironment` com fog leve).
- Iluminação simples: `DirectionalLight3D` + `WorldEnvironment` com céu claro. Sem sombras pesadas no começo (performance e leitura visual).

---

## 10. Feedback (prioridade acima de gráfico)

| Evento | Som | Visual |
|---|---|---|
| Passo | "ploft" grave por passo | poeirinha no chão |
| Pulo | whoosh curto | escala do dino esticando |
| Rugido | rugido longo + grave | onda de choque (anel expandindo) + tremor de câmera |
| Caixa quebrando | madeira estalando | fragmentos voando + partículas coloridas |
| Coletável | sino agudo | brilho rápido |
| Queda | "boing" cômico | cambalhota |

Tremor de câmera: `Camera3D` com script curto usando `randf_range` por 0.2 s. É o efeito com melhor custo/benefício do projeto.

---

## 11. Ordem de implementação (fatia vertical primeiro)

Não comece por fases nem por arte. Construa **uma** cena jogável de ponta a ponta:

- [ ] Projeto Godot 4.4+ com renderer Forward+
- [ ] Input Map com as 4 ações e deadzone
- [ ] `TRex.tscn` com cápsula, SpringArm + câmera e movimento lateral/pulo
- [ ] Chão de teste (uma `BoxShape3D` grande) e paredes laterais
- [ ] Rugido quebrando caixas por `get_overlapping_bodies()`
- [ ] Trombada quebrando caixas por `get_slide_collision`
- [ ] Zona de queda + checkpoint + respawn
- [ ] Coletável com som
- [ ] 3 sons essenciais: rugido, caixa, passo
- [ ] Teste com a criança e ajuste velocidade/pulo **antes** de qualquer arte

Depois disso: arte do dino, GridMap da fase 1, perseguição invertida (o T-Rex correndo atrás de uma fruta gigante) e tela de seleção com miniaturas grandes.

---

## 12. Exportação

- Exportar para Windows em `.exe` (rodar direto com o controle plugado) ou para Android/tablet se ele joga no sofá.
- Antes de entregar: teste com `Input.get_connected_joypads()` para confirmar que o controle foi reconhecido e coloque um fallback de teclado.
- Nome do executável e ícone do T-Rex importam: ele precisa reconhecer o jogo pelo ícone.

---

## 13. Estado atual do projeto (implementado)

Já existe uma fatia vertical jogável: tela inicial com nome do jogador, corredor de 150 m com 15 caixas, 24 comidas saudáveis (carne, fruta, vegetal e água), 3 checkpoints, respawn, rugido com onda de choque, som e tremor de câmera. A missão é comer bem: cada comida conta para o nível e o HUD mostra o contador e a barra. O dino **só anda quando o jogador manda** e aceita teclado, analógico e D-pad.

### Como rodar (Windows)

1. Baixe o Godot 4.7 ou mais recente, versão padrão (sem C#). O projeto foi validado na 4.7.2.
2. Abra o Godot → **Importar** → selecione `C:\Users\Gabriell\Documents\DinoChris\project.godot`.
3. Aperte **F5**. Abre a tela inicial: **COMEÇAR** entra na fase e **SEU NOME** salva o nome do jogador.

Com o controle plugado, o Godot já reconhece o PlayStation automaticamente: analógico esquerdo (ou D-pad) para andar para os lados, frente e trás; X/B para pular; Quadrado/Triângulo para rugir. No teclado: W/A/S/D (ou setas) para andar, Espaço para pular, E para rugir. O dino não sai do lugar sozinho.

### Tela inicial

- Título grande, botões enormes e foco amarelo — navegável com o controle (D-pad + X) ou mouse.
- **COMEÇAR**: carrega `scenes/fase_1.tscn`.
- **SEU NOME**: abre um painel com `LineEdit` (máx. 16 letras), **SALVAR** (ou Enter) e **CANCELAR** (ou Esc).
- O nome fica salvo em `user://dados.cfg` (autoload `Dados`), aparece como "JOGADOR: …" no menu e no canto da fase. Nome vazio vira `AMIGO`.


### Estrutura de arquivos

| Caminho | O que é |
|---|---|
| `project.godot` | Configuração, Input Map, camadas de física, autoloads `Dados` e `Sons` |
| `scenes/tela_inicial.tscn` | Menu: fundo, título, botões COMEÇAR / SEU NOME e painel de digitação |
| `scenes/fase_1.tscn` | Corredor, luz, céu, caixas, comidas, checkpoints e HUD (nome + missão) |
| `scenes/jogador.tscn` | T-Rex (CharacterBody3D) + câmera com SpringArm3D |
| `scenes/caixa.tscn` | Caixa quebrável (StaticBody3D, grupo `quebravel`) |
| `scenes/coletavel.tscn` | Comida saudável (Area3D, grupo `coletavel`, tipo `tipo`) |
| `scenes/checkpoint.tscn` | Portão que salva a posição de respawn |
| `scripts/tela_inicial.gd` | Ações dos botões, painel de nome e troca de cena |
| `scripts/dados.gd` | Autoload que guarda e persiste o nome em `user://dados.cfg` |
| `scripts/hud.gd` | Nome, nível, contador de comida e barra do nível |
| `scripts/jogador.gd` | Movimento, pulo, rugido, trombada, respawn e missão (nível) |
| `scripts/coletavel.gd` | Desenha carne/fruta/vegetal/água e entrega a comida ao jogador |
| `scripts/caixa.gd` | Destruição + destroços com física |
| `scripts/fase.gd` | Decoração, anti-softlock e reposição das comidas |
| `scripts/sons.gd` | Autoload que toca os efeitos (2D e 3D) |
| `audio/*.wav` | Sons gerados por síntese (sem direitos autorais) |
| `tests/harness.tscn` | Teste automático de fumaça da fase |
| `tests/harness_missao.tscn` | Teste da missão: comidas, barra, nível e reposição |
| `tests/harness_menu.tscn` | Teste da tela inicial (botões, painel e nome) |
| `tests/integracao_menu.tscn` | Teste COMEÇAR → fase carregada + HUD com o nome |

### Testes automáticos

```powershell
godot --headless --path . res://tests/harness.tscn
godot --headless --path . res://tests/harness_missao.tscn
godot --headless --path . res://tests/harness_menu.tscn
godot --headless --path . res://tests/integracao_menu.tscn
```

O primeiro valida 26 pontos da fase: câmera, dino parado sem input, avanço/recuo manuais, mapeamento de joystick (analógico X/Y, D-pad e botões), pulo, lateral, rugido quebrando caixa, coleta, checkpoints, respawn e limites do corredor. O segundo valida a missão: comidas alternando em 4 tipos, HUD (nível, contador, barra, total), subida de nível e reposição das comidas. O terceiro valida o menu e a persistência do nome. O quarto confirma que **COMEÇAR** troca de cena e que o nome aparece no HUD. Todos saem com código 0 quando passam.

### Ajustes rápidos (no inspetor, sem código)

- `TRex` → `Velocidade Frente` (6.0), `Velocidade Tras` (3.5) e `Velocidade Lateral` (7.0): sensação de velocidade.
- `TRex` → `Forca Pulo` (7.5): altura do pulo (gravidade do projeto = 24).
- `TRex/CameraRig` → `Position.y` (3.1) e `SpringArm3D` → `Spring Length` (6.0) / `Rotation X` (-17): enquadramento.
- `Fase1/Objetos`: mova, duplique ou apague caixas/itens/checkpoints direto no editor.

### Observações técnicas (descobertas nos testes)

- `Area3D` com `monitorable = false` deixa de reportar `get_overlapping_bodies()` no Godot 4.7 — por isso a RugidoArea não usa essa opção.
- O rugido consulta `get_overlapping_bodies()` em vez de depender de `area_entered`, então funciona com caixas que já estavam dentro do raio.
- Ao encerrar o jogo no meio de um efeito sonoro, o Godot pode imprimir um aviso de áudio "ainda em uso". É do desligamento do AudioServer, não afeta o jogo.

### Próximos passos sugeridos

1. Trocar o dino de primitivas por um modelo 3D / GLB com animações (andar, rugir, pular).
2. Animação de "comer" ao pegar a comida e um marcador por tipo (carne/fruta/vegetal/água) no HUD.
3. Fase 2 com a perseguição invertida (T-Rex atrás de uma fruta gigante).
4. Trilha sonora em loop e um "uau" ao pegar checkpoint.
5. Exportar `.exe` com ícone do T-Rex.

