# Tutorial estilo Ren'py con Nancy + personajes detrás de la mesa

## 1) Tutorial al estilo Ren'py
Agregué un nuevo overlay (`TutorialOverlay.gd`, nodo `TutorialLayer` en
`Main.tscn`) que se muestra automáticamente al arrancar la partida, ANTES
del día 1: fondo oscurecido, el retrato de **Nancy** (la hermana del
jugador) a la izquierda, y un cuadro de diálogo a la derecha con su nombre,
el texto del paso, un indicador "Paso X de 7" y un botón "Siguiente ▶"
(que en el último paso cambia a "¡Empezar!"). También hay un botón
"Saltar tutorial" para no repetirlo si están probando el juego una y otra
vez.

Los 7 pasos de Nancy están alineados con las reglas de orden que ya tiene
`VasoMichelada.gd`: escarchado (limón → sal/escarchado café/escarchado
azul) → hielo → salsa de tomate/chile líquido → cerveza, y cierra con la
regla de "nunca le sirvas alcohol a un menor de edad" (que conecta
directo con el dilema ético que ya tienen implementado).

**Mientras el tutorial está en pantalla, el día NO arranca**: `Main.gd` ya
no llama a `_iniciar_dia()` directo en `_ready()`, sino que espera la señal
`tutorial_terminado` de `TutorialOverlay.gd`. Así la barra de paciencia del
primer cliente no se gasta mientras el jugador está leyendo.

Nancy es un personaje "guía", no aparece en la rotación normal de clientes
(no toqué `CharacterDB.gd` ni `CustomerSpawner.gd` para esto). Su retrato
(`nancy_la_hermana.png`) es arte placeholder generado por código, con el
mismo criterio que los demás assets de este proyecto: para que el tutorial
funcione visualmente desde ya, y lo reemplacen con arte final más adelante
si quieren (mismo nombre de archivo, mismo lugar).

## 2) Personajes detrás de la mesa, sin recortarse
Reordené los nodos de `Main.tscn` y agrandé el área del cliente:
- `CustomerPortrait` ahora es más grande (500×740 en vez de 400×370) y se
  extiende hacia abajo hasta pasar el borde superior de la mesa (`Mesa`
  empieza en Y=850, el retrato ahora llega hasta Y=900). Como `Mesa` sigue
  dibujándose después en el árbol de nodos, la mesa queda **enfrente** y
  tapa naturalmente la parte de abajo del personaje — como si estuviera
  parado detrás del mostrador — en vez de que la imagen se vea cortada por
  un rectángulo arbitrario.
- Moví `CustomerPortrait` ANTES de `EmojiIcon` y `PatienceBar` en el árbol
  de nodos, para que la carita y la barra de paciencia se sigan viendo
  ENCIMA del personaje (no tapadas por él).
- `CustomerName` y `DialogueLabel` ya no se superponían con el retrato
  agrandado: los moví al margen izquierdo de la pantalla (antes vacío),
  como una especie de tarjeta de diálogo fija, en vez de flotar debajo del
  personaje.

Esto no depende de qué tan alto o ancho sea el arte real de cada
personaje: como `stretch_mode` sigue en "keep aspect centered", cualquier
imagen que suban se va a acomodar completa dentro de esa caja más grande,
y si el arte incluye cuerpo completo, las piernas quedarán naturalmente
detrás del mostrador.

## Qué reemplaza este paquete
- **`Main.tscn`** → layout reordenado + nodo `TutorialLayer` nuevo.
- **`Main.gd`** → ahora espera el tutorial antes de iniciar el día 1.
- **`TutorialOverlay.gd`** (archivo nuevo) → colócalo en
  `res://scripts/TutorialOverlay.gd` (mismo lugar que `VasoMichelada.gd`).
- **`assets/sprites/nancy_la_hermana.png`** (archivo nuevo).
- `VasoMichelada.gd`, `CharacterDB.gd`, `assets/michelada_capas/`,
  `assets/sprites/ingredients/` → sin cambios respecto al paquete anterior,
  incluidos de nuevo por completitud.

## Cómo integrarlo
1. Reemplaza `Main.tscn` y `Main.gd`.
2. Copia `TutorialOverlay.gd` a `res://scripts/`.
3. Copia `assets/sprites/nancy_la_hermana.png` a `res://assets/sprites/`.
4. Abre `Main.tscn` y confirma que aparece el nodo `TutorialLayer` al final
   del árbol (hijo directo de `Main`, después de `Mesa`).
5. Corre el juego: debería aparecer el tutorial de Nancy antes que llegue
   el primer cliente.
