# O Super T-Rex Corajoso — documento de projeto (Godot 4)

Game de corredor 3D estilo Crash Bandicoot para uma criança de 4 anos que ama T-Rex.
Foco: **sensação de poder** (correr, rugir, quebrar) com vidas generosas e um game over fofo, sem punição severa.

---

## 1. Pilares de design (o que vale e o que não vale)

**Vale:**
- Corredor linear 3D. Nada de mundo aberto — criança de 4 anos se perde e desiste.
- Poucos botões: analógico (direção) + pular + rugir.
- Feedback exagerado: som alto, partículas, tremor de tela, caixas voando.
- Erro custa no máximo **1 coração**: cambalhota engraçada, invulnerabilidade curta e volta logo.
- Vidas generosas: 5 iniciais, até 7, com corações saindo das caixas.

**Não vale:**
- Game over punitivo, vidas escassas, cronômetro ou contador de mortes.
- Pulos com timing preciso, plataformas estreitas, câmera que gira sozinha.
- Texto longo. Ícone, áudio e frases curtas bastam.

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

## 6. Queda, dano e respawn

O dino começa com **5 corações**, pode chegar a **7** e só perde 1 por obstáculo. Não existe checkpoint fixo: como o corredor é infinito, o próprio gerador guarda onde o dino pisou em chão firme.

- **Ponto seguro**: a cada quadro em que o dino está no chão (e não em cima de uma caixa) e a mais de 2,4 m de qualquer fissura/lava, `scripts/corredor.gd` grava a posição em `TRex.checkpoint`. Ele continua sendo usado pelo anti-softlock.
- **Fissura**: se o dino cair abaixo de `ALTURA_QUEDA` (−7 m), perde **1 coração** e reaparece **depois** da fissura, em chão firme, ~3 m após a borda final e virado para frente.
- **Lava**: encostar na `Area3D` de perigo tira **1 coração** e faz o mesmo reposicionamento após o rio, com anel laranja e som grave.
- **Tronco**: a trombada tira **1 coração** e mantém o empurrão para trás; não teleporta.
- **Invulnerabilidade**: após qualquer dano, o dino pisca por **1,5 s** e não perde outro coração nesse intervalo.
- **Anti-softlock**: se o jogador segurar o avanço e o dino ficar 3 s sem mudar de `z`, `scripts/fase.gd` chama `voltar_ao_checkpoint()` **sem tirar vida**.
- **Game over**: ao chegar a **0 vidas**, a fase pausa e mostra **QUASE!** com **TENTAR NOVAMENTE** (reinicia a fase com 5) e **SAIR** (volta para a tela inicial). O game over só aparece nesse caso; não há cronômetro nem contador de mortes.

### Corações nas caixas

- Ao quebrar uma caixa, pode sair um coração que pula para fora e brilha.
- Chance de **40%** quando o dino tem menos de 7 vidas; com **1 ou 2 vidas**, a chance é **100%**.
- Com **7 vidas**, nenhuma caixa solta coração.
- O coração cura 1 vida, não conta como comida e some sozinho após ~12 s se não for pego.
- As vidas são só da sessão: nova tentativa, retorno ao menu ou novo app recomeça com 5. Elas **não** são salvas em `user://dados.cfg`.

---

## 7. Comida saudável (coletáveis)

- Quatro comidas se alternam pelo corredor: **carne** (coxão com osso), **fruta** (maçã), **vegetal** (cenoura) e **água** (gota). São `Area3D` com o grupo `coletavel` e o tipo escolhido na propriedade `tipo` da cena.
- O desenho é montado por código em `coletavel.gd` (esferas, cilindros e caixas), então não precisa de modelo importado.
- Ao entrar: som curto, some (`queue_free()`) e conta para a missão.
- Coloque em **trilha** (5–8 seguidos), não isolados — a trilha ensina o caminho sem texto.
- Nunca coloque comida exigindo pulo preciso; a recompensa que flutua sobre uma fissura ou lava é opcional.

### Missão e níveis

- Meta do nível 1: **8 comidas**; cada nível seguinte pede 1 a mais (até 15).
- Ao completar a meta: toca o som `nivel`, o HUD mostra **NÍVEL 2!**, a barra zera e o corredor continua gerando comidas à frente — não existe mais reposição de comida.
- O HUD (canto superior direito) mostra `NÍVEL`, `COMIDA: X / meta`, a barra do nível e o `TOTAL` acumulado.
- As comidas vêm em trilhas de 3 a 5 unidades; cada fissura ou rio de lava ainda ganha uma comida-recompensa flutuando no meio do salto.

---

## 8. Anti-softlock (corredor com avanço manual)

O dino agora fica parado até o jogador mandar. O risco de softlock é quando a criança segura o direcional para frente e o dino trava em algo. Regras obrigatórias:

1. **Corredor largo**: mínimo 8 m livres.
2. **Curvas suaves**: no máximo ~10° por segmento, ou nenhuma curva (preferível).
3. **Nada de canto morto**: toda parede lateral deve desviar o dino para frente, nunca segurá-lo.
4. **Obstáculos macios**: troncos baixos (pula fácil) e caixas (quebra no impacto). Nada que exija desvio milimétrico.
5. **Velocidade 5–6 m/s**, pulo ~1,2 m de altura. Ajuste esses dois números com o seu filho jogando — é a única métrica que importa.
6. Se o jogador segurar o avanço e o dino ficar mais de 3 s sem sair do lugar (`global_position.z` parado), reposicione no ponto seguro. Ficar parado sem apertar nada **não** conta.

---

## 9. Construção da fase

- **Gerador procedural** (`scripts/corredor.gd`): pedaços de 36 m com chão, paredes, decoração e desafios. O corredor reto é de propósito — curva quebra o mapeamento lateral do controle.
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
- [ ] Zona de queda + ponto seguro + respawn
- [ ] Coletável com som
- [ ] 3 sons essenciais: rugido, caixa, passo
- [ ] Teste com a criança e ajuste velocidade/pulo **antes** de qualquer arte

Depois disso: arte do dino, corredor procedural da fase 1, perseguição invertida (o T-Rex correndo atrás de uma fruta gigante) e tela de seleção com miniaturas grandes.

---

## 12. Exportação

- Exportar para Windows em `.exe` (rodar direto com o controle plugado) ou para Android/tablet se ele joga no sofá.
- Antes de entregar: teste com `Input.get_connected_joypads()` para confirmar que o controle foi reconhecido e coloque um fallback de teclado.
- Nome do executável e ícone do T-Rex importam: ele precisa reconhecer o jogo pelo ícone.

---

## 13. Estado atual do projeto (implementado)

Já existe uma fatia vertical jogável e **infinita**: tela inicial com nome do jogador e um corredor procedural sem fim (pedaços de 36 m gerados à frente e reciclados atrás). Cada pedaço traz árvores do GLB, samambaias, caixas, comidas e, a partir do segundo, fissuras e rios de lava que o dino precisa pular. O dino começa com **5 corações** (máximo 7); cair, encostar na lava ou trombar num tronco tira 1 coração e devolve o dino logo depois do obstáculo, com invulnerabilidade curta. Caixas podem soltar corações de cura. Ao chegar a 0, aparece um game over fofo com **TENTAR NOVAMENTE** e **SAIR**. A missão é comer bem: cada comida conta para o nível e o HUD mostra o contador e a barra. O dino **só anda quando o jogador manda** e aceita teclado, analógico e D-pad.

### Como rodar (Windows)

1. Baixe o Godot 4.7 ou mais recente, versão padrão (sem C#). O projeto foi validado na 4.7.2.
2. Abra o Godot → **Importar** → selecione `C:\Users\Gabriell\Documents\DinoChris\project.godot`.
3. Aperte **F5**. Abre a tela inicial: **COMEÇAR** entra na fase e **SEU NOME** salva o nome do jogador.

Com o controle plugado, o Godot já reconhece o PlayStation automaticamente: analógico esquerdo (ou D-pad) para andar para os lados, frente e trás; X/B para pular; Quadrado/Triângulo para rugir; **L1 ou R1 para morder**. No teclado: W/A/S/D (ou setas) para andar, Espaço para pular, **E para rugir**, **F para morder**. O dino não sai do lugar sozinho.

### Tela inicial

- Título grande, botões enormes e foco amarelo — navegável com o controle (D-pad + X) ou mouse.
- **COMEÇAR**: carrega `scenes/fase_1.tscn`.
- **SEU NOME**: abre um painel com `LineEdit` (máx. 16 letras), **SALVAR** (ou Enter) e **CANCELAR** (ou Esc).
- O nome fica salvo em `user://dados.cfg` (autoload `Dados`), aparece como "JOGADOR: …" no menu e no canto da fase. Nome vazio vira `AMIGO`.


### Estrutura de arquivos

| Caminho | O que é |
|---|---|
| `project.godot` | Configuração, Input Map, camadas de física, tema global de fontes, autoloads `Dados` e `Sons` |
| `scenes/tela_inicial.tscn` | Menu: fundo, título, botões COMEÇAR / SEU NOME e painel de digitação |
| `scenes/fase_1.tscn` | Céu, luz, `TRex`, `Corredor`, HUD (nome + corações + missão) e game over |
| `scenes/jogador.tscn` | T-Rex (CharacterBody3D) + modelo rigado + câmera com SpringArm3D |
| `assets/modelos/jogador/trexChrisAnim.glb` | Dino rigado (23 ossos) com as 6 animações — é o que o jogo usa |
| `assets/modelos/jogador/trexChris.glb` | Modelo original sem rig (fonte, não é usado em cena) |
| `assets/modelos/props/arvores.glb` | Três modelos de árvore low-poly usados na decoração da fase |
| `assets/shaders/lava.gdshader` | Shader animado do rio de lava (ruído correndo no sentido do rio) |
| `assets/fontes/tema_jogo.tres` | Tema global: Nunito SemiBold no HUD/texto e Lilita One nos títulos e botões |
| `assets/fontes/*.ttf` + `OFL-*.txt` | Fontes OFL: Lilita One (títulos) e Nunito SemiBold (texto) |
| `tools/rig/*.py` | Pipeline Blender que gera o rig, as animações e o GLB |
| `scenes/caixa.tscn` | Caixa quebrável (StaticBody3D, grupo `quebravel`) |
| `scenes/coracao.tscn` | Coração de cura (Area3D, grupo `coracao`) |
| `scenes/coletavel.tscn` | Comida saudável (Area3D, grupo `coletavel`, tipo `tipo`) |
| `scripts/tela_inicial.gd` | Ações dos botões, painel de nome e troca de cena |
| `scripts/dados.gd` | Autoload que guarda e persiste o nome em `user://dados.cfg` |
| `scripts/hud.gd` | Nome, 7 corações, nível, contador de comida e barra do nível |
| `scripts/jogador.gd` | Movimento, pulo, rugido, trombada, vidas, dano, respawn e missão (nível) |
| `scripts/coletavel.gd` | Desenha carne/fruta/vegetal/água e entrega a comida ao jogador |
| `scripts/caixa.gd` | Destruição + destroços com física + chance de soltar coração |
| `scripts/coracao.gd` | Coleta do coração, cura e tempo de vida |
| `scripts/game_over.gd` | Overlay de fim de vidas, pausa e sinais dos botões |
| `scripts/fase.gd` | Anti-softlock, game over e troca de cena |
| `scripts/corredor.gd` | Gerador procedural infinito: chão, paredes, fissuras, lava, árvores, caixas e comidas |
| `scripts/sons.gd` | Autoload que toca os efeitos (2D e 3D) |
| `assets/ui/icone_coracao*.svg` | Coração cheio e vazio do HUD |
| `audio/*.wav` | Sons gerados por síntese (sem direitos autorais) |
| `tests/harness.tscn` | Teste de fumaça do corredor: geração, fissura, lava, respawn, controles e limites |
| `tests/harness_mordida.tscn` | Teste dos ataques: comando de mordida, rugido, mordida no ar e troca de animações |
| `tests/harness_ceu.tscn` | Teste do céu HDRI: panorama, névoa fora do céu, tonemap e sombra |
| `tests/captura.tscn` | Roda a fase e salva prints do dino em `tools/rig/out/` (QA visual) |
| `tests/harness_missao.tscn` | Teste da missão: comidas, barra e nível |
| `tests/harness_tronco.tscn` | Teste do tronco e do empurrão |
| `tests/harness_vidas.tscn` | Teste de vidas, corações, dano, respawn e game over |
| `tests/harness_menu.tscn` | Teste da tela inicial (botões, painel e nome) |
| `tests/integracao_menu.tscn` | Teste COMEÇAR → fase carregada + HUD com o nome |

### Rig e animações do dino

O T-Rex do jogador é um modelo rigado e animado por código, gerado no Blender 5.2 com Python (`bpy`). Tudo o que está em `trexChrisAnim.glb` sai do pipeline em `tools/rig/`.

**Como foi feito**

1. O GLB do Sketchfab (`trexChris.glb`, 44 mil vértices, 10 malhas separadas e nenhum osso) foi medido, redesenhado em metros e alinhado: frente em **-Z** (padrão Godot), pés em **y = 0**, quadril na origem, altura final de **1,9 m**.
2. A perna direita veio 0,26 m fora do centro no modelo original; foi deslocada para a simetria antes do skinning.
3. Armature de **23 ossos**: `root`, `hips`, `spine_01`, `spine_02`, `neck`, `head`, `jaw`, `tail_01..04`, `thigh/shin/foot/toe_L|R` e `upperarm/forearm_L|R`.
4. Skinning por **cadeia de ossos**: cada vértice é projetado ao longo da cadeia daquela malha e o peso é distribuído por arc length com transição suave nas juntas. A raiz da coxa é ancorada ao `hips` para a casca do quadril não abrir quando a perna gira.
5. As animações são geradas por um solver próprio (`tools/rig/trex_esqueleto.py`): FK em espaço de armature + **IK de 2 ossos** nas pernas, com alvos de pé no chão. Isso mantém os pés plantados e permite autorar passada, pulo e investida em termos de posição de pé, não de ângulo de osso.

**Clipes exportados** (30 fps, nomes iguais no Godot)

| Clipe | Duração | Loop | Uso no jogo |
|---|---|---|---|
| `Idle` | 3,0 s | sim | parado |
| `Walk` | 1,0 s | sim | velocidade até 4,5 m/s |
| `Run` | 0,67 s | sim | velocidade acima de 4,5 m/s |
| `Jump` | 0,9 s | não | botão de pulo (toca a 1,35x para casar com o pulo físico) |
| `Attack` | 0,8 s | não | mordida em caixa próxima |
| `Roar` | 1,4 s | não | rugido com onda de choque |

**Contrato com o Godot**

- `scenes/jogador.tscn` instancia o GLB como nó `Modelo`; o `AnimationPlayer` fica em `Modelo/AnimationPlayer`.
- `scripts/jogador.gd` configura os loops em `_ready()`, escolhe Idle/Walk/Run pela velocidade, ajusta `speed_scale` e dispara Jump/Attack/Roar como ações únicas (bloqueiam a locomoção até terminar).
- **Dois comandos de ataque, separados:**
  - `rugido` (**E** ou Quadrado/Triângulo) toca `Roar` e quebra tudo que estiver dentro do raio da `RugidoArea`.
  - `mordida` (**F** ou **L1/R1**) toca `Attack` e quebra a caixa mais à frente, até 3,6 m e dentro de um cone de 70°. No ar o comando é ignorado, para não roubar a animação de pulo; sem alvo, o dino morde o vento mesmo assim.
- O personagem não tem root motion: quem move é o `CharacterBody3D`, então as animações nunca mudam a posição do nó.

**Regerar depois de mexer no rig ou nas animações**

```powershell
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $b --background --python tools/rig/05_rig.py     # armature + skin -> out/trex_rig.blend
& $b --background --python tools/rig/11_anim.py    # animações + export -> assets/.../trexChrisAnim.glb
godot --headless --path . --import                 # o Godot reimporta o GLB
godot --headless --path . res://tests/harness.tscn
```

Os outros scripts em `tools/rig/` são de inspeção: `01`/`02`/`03` medem o modelo, `04` identifica as partes por cor, `08`/`10`/`15` renderizam poses de teste, `13`/`14` montam a folha de contato de QA e `tests/captura.tscn` tira prints do jogo rodando.

### Céu HDRI

A fase usa o panorama `assets/ceu/ceu-01.exr` (equiretangular 1024×512, pôr do sol sobre a água) como céu e como fonte de luz ambiente.

**Como está montado** (`scenes/fase_1.tscn`)

```
WorldEnvironment
└── Environment
    ├── background_mode = Sky
    ├── sky → Sky → PanoramaSkyMaterial → panorama = ceu-01.exr
    ├── sky_rotation = (0, 180°, 0)      # põe o sol/nuvens à frente do corredor
    ├── background_energy_multiplier = 0.55
    ├── ambient_light_source = Sky, energia 1.3, sky_contribution 0.85
    ├── tonemap AgX, exposição 1.1
    └── fog ligada, densidade 0.0045, sky_affect = 0.0
```

O `Sol` (DirectionalLight3D) fica com cor quente `(1, 0.9, 0.78)` e energia 1.8, mantendo a sombra do dino.

**A armadilha que quebrou a primeira tentativa:** o padrão de `fog_sky_affect` é **1.0**, e isso faz a névoa **substituir o céu inteiro** por uma cor chapada. O céu aparece como um degradê lavado e nenhum ajuste de tonemap, exposição ou energia resolve — porque o céu nem está sendo desenhado. Com `fog_sky_affect = 0.0` o panorama aparece de verdade. Foi exatamente isso que travou a implementação anterior.

**Para reajustar o visual** (tudo no inspetor do `WorldEnvironment`):

| Quero… | Mexa em |
|---|---|
| Céu mais claro/escuro sem mexer na luz | `Background → Energy` |
| Girar o céu (outra parte do panorama à frente) | `Sky → Sky Rotation Y` |
| Cena mais quente/fria | cor e energia do nó `Sol` |
| Menos névoa no fundo | `Fog → Density` (nunca volte o `Sky Affect` acima de 0.1) |
| Contraste geral | `Tonemap → Mode/Exposure` |

O import do EXR está como textura comprimida com mipmaps ligados (`assets/ceu/ceu-01.exr.import`), que é o que evita cintilação do céu com a câmera em movimento.

### Corredor infinito

O caminho é gerado em **pedaços de 36 m** por `scripts/corredor.gd`. Enquanto o dino avança, novos pedaços são criados à frente e os que ficaram 58 m para trás são liberados com `queue_free()` — o nível pode rodar para sempre sem crescer em memória.

```
Corredor (Node3D, scripts/corredor.gd)
└── Pedaco_000…  (Node3D, um por trecho de 36 m)
    ├── Solido (StaticBody3D)        # um corpo só, com as colisões de chão e paredes
    ├── base de rocha + grama + trilha
    ├── Paredes (2)
    ├── Fissura / Lava (Node3D, grupo "buraco")
    ├── árvores (grupo "arvore") e samambaias
    └── caixas e comidas
```

**Desafios**

| Tipo | Como funciona | Largura |
|---|---|---|
| `Fissura` | vão no chão; cair abaixo de `ALTURA_QUEDA` (−7 m) volta ao ponto seguro | 1,8–2,6 m |
| `Lava` | vala com shader de lava 28 cm abaixo do chão, `Area3D` de perigo e luz laranja | 2,0–2,6 m |
| `Caixas` | 2–4 caixas seguidas para rugir, morder ou trombar | — |

Com o pulo atual (força 7,5, gravidade 24, frente 6 m/s) o dino cobre ~3,7 m no ar; por isso nenhum buraco passa de 2,6 m — sobra cerca de 1,1 m de margem para quem pula no tempo certo.

**Roteiro do começo** (para ensinar sem texto): pedaço 0 = caixas, 1 = primeira fissura, 2 = primeira lava, 3 = caixas; do 4 em diante o sorteio escolhe entre fissura (26%), lava (24%), caixas (26%) e trecho livre (24%), com no mínimo 20 m entre dois desafios. A dificuldade cresce com a distância percorrida até o teto de largura.

**Para mexer no ritmo** (tudo em `scripts/corredor.gd`):

| Quero… | Constante |
|---|---|
| Corrida mais longa/curta | `COMPRIMENTO` |
| Mais/menos caminho pronto à frente | `PEDACOS_ADIANTE` |
| Desafios mais espaçados | `ESPACO_ENTRE_OBSTACULOS` |
| Repetir um caminho para testar | `Semente` no nó `Corredor` (0 = sorteia) |

**Rio de lava**: `assets/shaders/lava.gdshader` desenha o rio sem sombreamento (`unshaded`), com dois ruídos baratos correndo no eixo do rio e veios claros. Duas faixas emissivas marcam as margens no chão, e uma `OmniLight3D` acende a vala e as paredes próximas.

### Árvores do cenário

A decoração lateral da fase usa os três modelos low-poly de `assets/modelos/props/arvores.glb` (`Tree1`, `Tree2` e `Tree3`, 742 triângulos no total). `scripts/corredor.gd` instancia o GLB uma vez, mede cada árvore e duplica o molde em cada pedaço do corredor, alternando modelo, giro e altura.

- O GLB vem do Sketchfab com o eixo **Z para cima**, o pivô fora do pé do tronco e alturas diferentes (~16 m e ~20 m). O script leva o pé do tronco para a origem e normaliza todas para `ALTURA_ARVORE` (9 m), com ±12% de variação.
- As árvores ficam **atrás das paredes**, em `x = ±6,5…9 m`, a cada 7–11 m. A copa passa por cima da parede e forma o teto de floresta do corredor.
- Para mudar o porte da floresta, mexa em `ALTURA_ARVORE` e `VARIACAO_ALTURA` no topo de `scripts/corredor.gd`; a distância das paredes e o espaçamento ficam em `_decorar()`.
- Não há colisão: as árvores ficam fora do corredor, então não atrapalham o dino. As samambaias do chão continuam sendo esferas geradas por código.

### Testes automáticos

```powershell
godot --headless --path . res://tests/harness.tscn
godot --headless --path . res://tests/harness_missao.tscn
godot --headless --path . res://tests/harness_menu.tscn
godot --headless --path . res://tests/integracao_menu.tscn
godot --headless --path . res://tests/harness_mordida.tscn
godot --headless --path . res://tests/harness_ceu.tscn
godot --headless --path . res://tests/harness_tronco.tscn
godot --headless --path . res://tests/harness_vidas.tscn
```

O primeiro valida o corredor inteiro: câmera, dino parado sem input, avanço/recuo manuais, mapeamento de joystick (analógico X/Y, D-pad e botões), pulo, lateral, árvores do GLB, fissura e lava geradas, rugido quebrando caixa, coleta, queda na fissura e na lava com volta ao ponto seguro, geração 600 m à frente com pedaços antigos apagados e limites laterais. O segundo valida a missão: comidas no corredor nos 4 tipos, HUD (nível, contador, barra, total) e subida de nível. O terceiro valida o menu e a persistência do nome. O quarto confirma que **COMEÇAR** troca de cena e que o nome aparece no HUD. O quinto valida os ataques e as animações: os 6 clipes importados, loops corretos, mordida mapeada em teclado e controle, mordida quebrando a caixa da frente, rugido sem virar mordida, mordida no ar não interrompendo o pulo, e a troca Idle ↔ Run pela velocidade. O sexto valida o céu: fundo em Sky, material PanoramaSkyMaterial apontando para `ceu-01.exr`, névoa fora do céu (`fog_sky_affect`), tonemap AgX e sol com sombra. O sétimo valida o tronco: dano, empurrão e ausência de dano duplicado durante a invulnerabilidade. O oitavo valida as vidas: HUD com 7 espaços, 5 iniciais, coração de caixa, teto 7, dano de tronco/buraco/lava, respawn depois do obstáculo e game over com os botões. Todos saem com código 0 quando passam.

### Ajustes rápidos (no inspetor, sem código)

- `TRex` → `Velocidade Frente` (6.0), `Velocidade Tras` (3.5) e `Velocidade Lateral` (7.0): sensação de velocidade.
- `TRex` → `Forca Pulo` (7.5): altura do pulo (gravidade do projeto = 24).
- `TRex/CameraRig` → `Position.y` (3.1) e `SpringArm3D` → `Spring Length` (6.0) / `Rotation X` (-17): enquadramento.
- `Fase1/Corredor` → `Semente`: 0 sorteia um caminho novo a cada partida; um número fixo repete o mesmo caminho.
- `scripts/corredor.gd` → `COMPRIMENTO`, `PEDACOS_ADIANTE` e `ESPACO_ENTRE_OBSTACULOS`: tamanho dos pedaços, quanto caminho fica pronto à frente e respiro entre desafios.

### Observações técnicas (descobertas nos testes)

- `Area3D` com `monitorable = false` deixa de reportar `get_overlapping_bodies()` no Godot 4.7 — por isso a RugidoArea não usa essa opção.
- O rugido consulta `get_overlapping_bodies()` em vez de depender de `area_entered`, então funciona com caixas que já estavam dentro do raio.
- A lava fica só 28 cm abaixo do chão de propósito: mais funda, a borda de perto esconde o rio na câmera de trás. A `Area3D` de perigo fica abaixo dessa superfície para não acusar o dino parado na beira.
- Cada pedaço tem **um** `StaticBody3D` com vários `CollisionShape3D` (chão + paredes). Os pedaços que ficam 58 m para trás são liberados inteiros, junto com suas caixas, comidas e árvores.
- Não dá para mudar `Area3D.monitoring` dentro de `body_entered`; o coração usa `set_deferred("monitoring", false)` para evitar o erro "Function blocked during in/out signal".
- O game over fica em `process_mode = ALWAYS` e pausa a árvore; os botões continuam funcionando. Antes de trocar de cena, `fase.gd` faz `get_tree().paused = false`.
- Ao encerrar o jogo no meio de um efeito sonoro, o Godot pode imprimir um aviso de áudio "ainda em uso". É do desligamento do AudioServer, não afeta o jogo.

### Próximos passos sugeridos

1. Animação de "comer" ao pegar a comida (hoje a comida some sem reação do dino).
2. Rigar e animar o `spinoBob.glb` (inimigo) reaproveitando o mesmo pipeline de `tools/rig/`.
3. Fase 2 com a perseguição invertida (T-Rex atrás de uma fruta gigante).
4. Trilha sonora em loop e um "uau" ao passar de nível.
5. Exportar `.exe` com ícone do T-Rex.

### Pendências conhecidas do rig

- O pescoço abre uma fresta fina quando a cabeça gira muito de lado (as malhas de cabeça e corpo são separadas no modelo original). Só aparece de perto; de câmera de jogo não dá para ver.
- Em passada larga o ombro da coxa mostra uma dobra interna. Resolver de vez pediria corrective shape keys ou um modelo com edge loops no quadril.
- Os pés deslizam um pouco em velocidade máxima: o passo do clipe não cobre os 6 m/s de corrida. A `speed_scale` acima de 1,3 disfarça, mas o ajuste definitivo é aumentar o passo do clipe ou reduzir a velocidade do jogo.

