# Skills de gamedev úteis para o DinoChris

Triagem feita em 26/10/2026 sobre a coleção em:

```text
H:\Nova pasta (2)\DASHI\SKILLS\gamedev-skills\skills\
```

Critério: o projeto é **Godot 4.7 (Forward+), GDScript, 3D, corredor infinito, sem game over**, com câmera em `SpringArm3D`, animações de GLB, áudio sintetizado, gerador procedural, shader de lava, menu/HUD e testes headless. Só entraram skills que encaixam nesse stack ou nas etapas já previstas em `inicio.md`.

Legenda de encaixe:

- **Perfeito** — usa exatamente o que o projeto já faz; pode consultar sem adaptação.
- **Alto** — a técnica é transversal e se aplica direto às áreas existentes.
- **Futuro** — útil quando a etapa correspondente do roadmap começar.

---

## 1. Núcleo Godot (encaixe perfeito)

| Skill | Encaixe | Onde entra neste projeto |
|---|---|---|
| [godot-3d-essentials][g3d] | Perfeito | `scenes/fase_1.tscn`: `Node3D`, `Camera3D`, `DirectionalLight3D`, `WorldEnvironment`, céu HDRI, tonemap AgX e névoa. Também materiais e `GridMap` se um dia houver bloqueio de fase em grade. |
| [godot-gdscript][ggd] | Perfeito | Todos os `scripts/*.gd`: tipagem estática, `_ready`/`_physics_process`, `@export`, `@onready`, `await` e sinais. O estilo atual dos scripts segue essa linha. |
| [godot-nodes-scenes][gns] | Perfeito | `scenes/jogador.tscn`, `caixa.tscn`, `coletavel.tscn`, `fase_1.tscn`; autoloads `Dados` e `Sons`; instanciação de caixas, comidas e árvores em `scripts/corredor.gd`; cuidados com `queue_free()` e `is_instance_valid()`. |
| [godot-physics][gph] | Perfeito | `CharacterBody3D` do T-Rex, `Area3D` do rugido e da lava, `StaticBody3D` das caixas, camadas 1–4 (`Cenario`, `Jogador`, `Quebravel`, `Gatilho`), `get_slide_collision()` e consultas de sobreposição. Cobre também Jolt Physics. |
| [godot-animation][gan] | Perfeito | `AnimationPlayer` em `Modelo/AnimationPlayer` (`Idle`, `Walk`, `Run`, `Jump`, `Attack`, `Roar`), loops, `speed_scale` e `animation_finished`; `Tween` da onda de choque e do HUD. |
| [godot-audio][gau] | Perfeito | `scripts/sons.gd` (autoload), `AudioStreamPlayer`/`AudioStreamPlayer3D`, volume em dB, pitch aleatório dos passos e futura separação em buses (`Master`, `SFX`, `Music`). |
| [godot-shaders][gsh] | Perfeito | `assets/shaders/lava.gdshader`: shader `spatial` unshaded, ruído animado com `TIME`/`UV`, emissão e uniforms. Serve para novos efeitos de água, lava e materiais do cenário. |
| [godot-signals-groups][gsg] | Perfeito | Grupos `quebravel` e `coletavel`, sinais `comida_coletada` e `subiu_nivel`, chamadas por grupo e desacoplamento entre jogador, HUD e fase. |
| [godot-ui-control][gui] | Perfeito | `scenes/tela_inicial.tscn` e HUD: anchors, containers, `Theme`, foco amarelo navegável por D-pad e botões enormes. |
| [godot-gdscript-headless-testing][ght] | Perfeito | Os `tests/harness*.tscn` e `tests/integracao_menu.tscn` rodam com `godot --headless`; a skill cobre `--import` antes dos testes, contagem de falhas e `quit(1)` para o CI falhar de verdade. |
| [godot-export][gex] | Perfeito | Exportação para Windows `.exe` e Android, `export_presets.cfg`, templates e export headless. É a etapa 5 dos próximos passos. |

## 2. Disciplinas transversais (encaixe alto)

| Skill | Encaixe | Onde entra neste projeto |
|---|---|---|
| [game-feel][gfe] | Alto | É o **pilar do jogo**: tremor de câmera, squash/stretch, pausa curta no impacto, partículas, som em camadas e feedback exagerado ao rugir, quebrar caixa, pular e coletar. |
| [camera-systems][gca] | Alto | `CameraRig` + `SpringArm3D` + `Camera3D`: follow, colisão do braço, enquadramento rígido para criança e gancho de shake usado em `scripts/camera_tremer.gd`. |
| [input-systems][gin] | Alto | `InputMap` com `mover_*`, `pular`, `rugido`, `mordida`; deadzone 0.25; teclado + analógico + D-pad; e as ideias de input buffering/coyote time que ainda podem amaciar o pulo. |
| [procedural-gen][gpr] | Alto | `scripts/corredor.gd`: `RandomNumberGenerator` com semente, sorteio de desafios por peso, espaçamento mínimo, reciclagem de pedaços e reprodutibilidade para testar um caminho fixo. |
| [physics-tuning][gpt] | Alto | Gravidade 24, força de pulo 7.5, velocidade 5–6 m/s, distância de salto ~3,7 m, prevenção de tunneling em quedas e ajuste de camadas/massas se o Jolt mostrar jitter. |
| [level-design][gld] | Alto | Métricas do personagem, largura mínima de 8 m, buracos de no máximo 2,6 m, curvas suaves, obstáculos macios e as regras de anti-softlock de `scripts/fase.gd`. |
| [game-ui-ux][gux] | Alto | Menu inicial, painel de nome, HUD de nível/comida, escalonamento em 1280×720, áreas seguras e navegação por controle. |
| [audio-design][gad] | Alto | Arquitetura de buses, variação de SFX, ducking e, no futuro, trilha em loop e som de "uau" ao subir de nível. |
| [performance-optimization][gpo] | Alto | Corredor infinito com `queue_free()` dos pedaços antigos, reutilização de moldes de árvore, orçamento de draw calls, partículas e alocações por frame. |
| [save-systems][gsv] | Alto | `scripts/dados.gd` com `user://dados.cfg`: escolha do que persistir, escrita segura, versão do arquivo e migração futura de nome/progresso. |
| [shader-programming][gsp] | Alto | Fundamentos de UV, ruído, dissolve, outline e fresnel para evoluir a lava e criar efeitos de impacto sem depender só da sintaxe do Godot. |

## 3. Para as próximas etapas do roadmap (encaixe futuro)

| Skill | Encaixe | Quando usar |
|---|---|---|
| [game-ai][gai] | Futuro | Quando rigar e animar o `spinoBob.glb` como inimigo: FSM, behavior tree, steering, patrulha/perseguição e `NavigationAgent3D`. |
| [create-game-assets][gca2] | Futuro | Ao produzir novos modelos, texturas, ícones e UI: direção de arte, brief de asset 3D, normalização, importação e folha de contato. Dialoga com o pipeline em `tools/rig/`. |
| [godot-resources][gre] | Futuro | Se comidas, níveis ou configurações saírem das constantes e virarem dados editáveis no Inspector (`.tres`), em vez de `Dictionary`/`@export` espalhados. |

## 4. Ordem de leitura sugerida

1. `godot-gdscript` + `godot-nodes-scenes` — base para qualquer mudança.
2. `godot-3d-essentials` + `godot-physics` + `godot-animation` — cena, colisão e animação do dino.
3. `game-feel` + `camera-systems` + `input-systems` — a sensação de poder que é o foco do jogo.
4. `procedural-gen` + `level-design` — corredor, ritmo e anti-softlock.
5. `godot-gdscript-headless-testing` + `godot-export` — validar e entregar.
6. As demais conforme a área que for mexer.

## 5. Como usar estas skills

- Abra o `SKILL.md` da skill **antes** de alterar a área correspondente; cada uma traz workflows, padrões e armadilhas específicas do Godot 4.7.
- Para o agente carregar uma skill automaticamente, copie a pasta dela para `.agents/skills/<nome>/` neste projeto (o nome da pasta deve ser igual ao campo `name` do frontmatter). Exemplo: `.agents/skills/game-feel/SKILL.md`.
- As skills estão fora do catálogo padrão do opencode; sem copiar, elas funcionam como documentação de referência lida sob demanda.

## 6. O que ficou de fora (e por quê)

Não entram neste projeto: skills de **Unity, Unreal, Roblox, Ebitengine, Bevy, Defold, LÖVE, pygame, Phaser, PixiJS e three.js** (outra engine/stack); **godot-csharp** (o projeto é GDScript); **godot-multiplayer** (single-player local); **godot-tilemap** e **godot-2d-movement** (o jogo é 3D); **platformer** (é 2D — as ideias de coyote time e jump buffer já estão cobertas por `input-systems`); gêneros sem relação (**card-game, fps-shooter, puzzle, roguelike, rpg, survival-crafting, tower-defense, visual-novel**); e fluxos que não são o caso agora (**game-jam, prototype-fast, itch-publish, steam-publish** — a distribuição prevista é `.exe`/Android, coberta por `godot-export`).

---

## Links diretos

[g3d]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-3d-essentials/SKILL.md
[ggd]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-gdscript/SKILL.md
[gns]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-nodes-scenes/SKILL.md
[gph]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-physics/SKILL.md
[gan]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-animation/SKILL.md
[gau]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-audio/SKILL.md
[gsh]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-shaders/SKILL.md
[gsg]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-signals-groups/SKILL.md
[gui]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-ui-control/SKILL.md
[ght]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-gdscript-headless-testing/SKILL.md
[gex]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-export/SKILL.md
[gfe]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/game-feel/SKILL.md
[gca]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/camera-systems/SKILL.md
[gin]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/input-systems/SKILL.md
[gpr]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/procedural-gen/SKILL.md
[gpt]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/physics-tuning/SKILL.md
[gld]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/level-design/SKILL.md
[gux]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/game-ui-ux/SKILL.md
[gad]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/audio-design/SKILL.md
[gpo]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/performance-optimization/SKILL.md
[gsv]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/save-systems/SKILL.md
[gsp]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/shader-programming/SKILL.md
[gai]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/game-ai/SKILL.md
[gca2]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/disciplines/create-game-assets/SKILL.md
[gre]: file:///H:/Nova%20pasta%20%282%29/DASHI/SKILLS/gamedev-skills/skills/godot/godot-resources/SKILL.md
