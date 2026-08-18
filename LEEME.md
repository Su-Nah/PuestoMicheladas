# 4 cambios grandes: Nancy detrás de la mesa, paciencia gradual, hasta 3 clientes a la vez, sin salsa/chile

## 1) Nancy también detrás de la mesa
Igual que hicimos con los clientes: moví el retrato de Nancy
(`NancyPortrait`) para que ya NO viva dentro de `TutorialLayer`, sino como
hermano directo de `Mesa` en el árbol de `Main.tscn`, colocado ANTES que
`Mesa`. Así la mesa se dibuja encima de ella y le tapa la parte de abajo
—como si estuviera parada detrás del mostrador— en vez de cortarse contra
un rectángulo. `TutorialOverlay.gd` ahora solo la muestra/oculta
(`nancy_portrait.visible = true/false`) según si el tutorial está activo;
el cuadro de diálogo de Nancy se quedó flotando arriba, sin taparla del
todo, para que se le siga viendo la cara mientras habla.

## 2) La paciencia dura más, y baja gradualmente día a día
Antes la paciencia de cada cliente era un valor fijo (definido en
`CharacterDB.gd`, ej. 14 segundos). Ahora ese valor se multiplica según en
qué día vas:
- **Día 1**: toda la paciencia se multiplica por **2.2** (más del doble de
  tiempo — mucho más manejable para aprender).
- **Último día**: se multiplica por **1.1** (ligeramente más generoso que
  el valor "de diseño" original, pero ya casi al ritmo pensado).
- Entre esos dos puntos baja de forma lineal, día a día, así que la
  dificultad sube gradualmente en vez de sentirse igual de difícil todo el
  juego o dar un salto brusco.

Esto está en `Main.gd` → `_paciencia_para_cliente()` / `_progreso_dificultad()`.
Los números (2.2 y 1.1) son constantes al principio del archivo
(`PACIENCIA_MULTIPLICADOR_DIA1` / `PACIENCIA_MULTIPLICADOR_MINIMO`) por si
quieres ajustarlos sin tocar el resto de la lógica.

## 3) Hasta 3 clientes al mismo tiempo, nunca repetidos
Esto fue el cambio más grande. Antes había un solo cliente a la vez
(`cliente_actual`); ahora hay **3 "puestos" fijos** en pantalla
(`ClienteSlot0/1/2`, uno a la izquierda, uno al centro, uno a la derecha,
sin encimarse) y cada uno puede estar vacío u ocupado por un cliente con su
propia barra de paciencia independiente.

- **Selección**: tocas/clickeas el retrato de un cliente para
  "seleccionarlo" (se ve resaltado — el resto se atenúa un poco). El botón
  "Servir michelada" siempre sirve al que esté seleccionado en ese momento.
- **Cuántos aparecen a la vez**: los primeros días, casi siempre aparece
  UN cliente y el próximo entra hasta que el anterior se va. Con el paso de
  los días, sube gradualmente la probabilidad de que se llenen 2 o incluso
  los 3 puestos de golpe (`_probabilidad_simultaneos`, del 5% el día 1 al
  80% en el último día). Un tercer cliente simultáneo solo empieza a ser
  posible más adelante en la semana.
- **Nunca se repite el mismo personaje en dos puestos a la vez**: al
  llenar un puesto, el juego busca en la fila del día el primer cliente
  cuyo `id` NO esté ya ocupando otro puesto (`_tomar_siguiente_no_repetido`).
  Si el único que queda en la fila ya está activo en otro puesto, ese
  puesto se queda vacío hasta que se libere.
- **Vaso compartido**: sigue habiendo un solo vaso/una sola michelada a la
  vez (igual que antes) — el jugador prepara y sirve de a uno, eligiendo a
  quién. Si el cliente seleccionado se resuelve (se le sirve o se le acaba
  la paciencia), el vaso se vacía para el siguiente; pero si a un cliente
  NO seleccionado se le acaba la paciencia mientras preparas la bebida de
  otro, el vaso no se toca.
- Agregué **3 personajes nuevos** a `CharacterDB.gd` (Doña Carmen, Greg el
  turista y Fer la estudiante) para tener más variedad de recetas y caras
  cuando hay varios clientes en pantalla a la vez.

## 4) Se eliminó la salsa de tomate y el chile líquido
Saqué `salsa_tomate` y `chile_liquido` de todos lados:
- `VasoMichelada.gd`: ya no existen esos ingredientes ni esa capa del vaso.
  El orden quedó más corto: escarchado (opcional) → hielo → cerveza.
- `Main.tscn`: se quitaron esos 2 íconos de la mesa (ahora son 7
  ingredientes en vez de 9: limón, sal, escarchado café, escarchado azul,
  hielo, cerveza, cerveza azul) y esas 2 capas visuales del vaso.
- `Main.gd` / `TutorialOverlay.gd`: se quitaron las referencias, textos y
  el paso del tutorial que hablaba de ellos (el tutorial ahora tiene 7
  pasos en vez de 8).
- `CharacterDB.gd`: se actualizaron las recetas y los pedidos de texto de
  los personajes que los mencionaban (Don Ramiro, Chavo de prepa, Señora
  Lupe y Tony).
- Borré los PNG que ya no se usan (`salsa_tomate.png`, `chile_liquido.png`,
  `liquido_salsa_tomate.png`, `liquido_chile_liquido.png`) del paquete.
  Si tu proyecto los sigue teniendo, puedes borrarlos también; no pasa
  nada si se quedan, simplemente ya nadie los usa.

## Qué reemplaza este paquete (todo, completo)
`Main.gd`, `Main.tscn`, `VasoMichelada.gd`, `CharacterDB.gd`,
`TutorialOverlay.gd`, y las carpetas `assets/michelada_capas/` y
`assets/sprites/` (ya sin los archivos de salsa/chile). Reemplaza los 5
scripts/escena y copia las carpetas de assets tal cual, sobrescribiendo.

## Un pendiente para ti
Los 3 personajes nuevos (`dona_carmen`, `turista_greg`, `estudiante_fer`)
usan retratos en rutas que todavía no existen como archivos
(`res://assets/sprites/dona_carmen.png`, etc. — igual que los personajes
que ya tenías, como `don_ramiro.png`). Si no subes esas imágenes, el juego
no truena: cae automáticamente al placeholder
(`res://assets/sprites/placeholder.png`), pero se van a ver todos iguales
hasta que agregues su arte.
