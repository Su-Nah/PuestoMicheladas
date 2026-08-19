# Rediseño grande: vaso arrastrable, arrastrar al cliente, Michelada/Azulito, y 3 bugs corregidos

## ⚠️ Un supuesto que hice (revísalo primero)
Me diste 10 nombres de archivo: `cerveza, gatorlite, chamoy_azul, chamoy_cafe,
escarchado_azul, escarchado_cafe, gomitas, limon, mesa, vodka`. Las recetas
que diste empiezan las dos con "vaso", pero "vaso" no aparece en esa lista
de 10 archivos — así que asumí que **`mesa.png` es el archivo del vaso/vidrio
vacío** (es el único de los 10 que no es un ingrediente de sabor). Si me
equivoqué y `mesa.png` es otra cosa, dime qué es y ajusto el mapeo — está
centralizado en un solo lugar (`Main.tscn`, el `ext_resource` con id `43`
apuntando a `res://assets/sprites/ingredients/vaso.png`, más el ícono que
generé yo mismo bajo ese nombre como marcador de posición).

## Los 3 bugs que reportaste

**1) Nancy no se veía en su tutorial.**
Encontré la causa: `TutorialOverlay.gd` solo hacía `nancy_portrait.visible = true`
dentro de la función `mostrar()`, pero `Main.gd` nunca llamaba a `mostrar()`
— solo conectaba la señal de "tutorial terminado". Como el tutorial arranca
visible por defecto (sin que nadie llame a `mostrar()`), Nancy se quedaba
invisible para siempre. Lo arreglé poniendo `nancy_portrait.visible = true`
también dentro de `_ready()`, que sí se ejecuta siempre al cargar la escena.

**2) El oficial Erick no dejaba servirle nada — y no debía.**
Este personaje nunca compra (`quiere_michelada: false`), así que estaba
bien que no se le pudiera "servir". El problema real era que antes SOLO
había una forma de que se fuera: esperar a que se le acabara toda la
paciencia. Ahora, con el nuevo sistema de slots, basta con **tocar/hacer
clic en su puesto** para atenderlo de inmediato (se despide con su diálogo
y se va) — ya no hay que esperarlo. Cualquier cliente que no quiere
michelada funciona igual.

**3) Se trababa si ponías el hielo (ahora: cualquier ingrediente) fuera de
orden.**
Con el sistema de ingredientes viejo, si te adelantabas con un paso podías
quedar en un estado del que ya no se podía recuperar ningún otro
ingrediente. Con el rediseño completo de abajo, cada intento fuera de
orden simplemente SE RECHAZA (no se agrega nada, no se corrompe el vaso) y
puedes seguir intentando con el ingrediente correcto — nunca se "traba" el
vaso completo por un solo error. Y si de plano quieres empezar de cero,
"Vaciar vaso" siempre está ahí.

## Los cambios grandes que pediste

### El vaso ahora es un ingrediente que se arrastra
Por defecto **no existe ningún vaso** en el centro de la mesa. Hay un
nuevo ícono "Vaso" en la bandeja de ingredientes: al arrastrarlo al
centro, ahí se crea una bebida nueva. Antes de eso, no se puede poner
nada más (se rechaza con el mensaje "Primero arrastra un vaso al
centro"). Cuando sirves esa bebida (ver siguiente punto) o le das
"Vaciar vaso", el vaso desaparece del centro otra vez hasta que arrastres
uno nuevo.

### Servir = arrastrar el vaso al cliente
Ya no hay botón "Servir michelada". Ahora **arrastras el vaso ya
preparado directo hacia el cliente** al que se lo quieres dar (a su
retrato/puesto). Así, con dos o tres clientes en pantalla, nunca hay
ambigüedad de a quién le tocaba cuál bebida — literalmente se la llevas
tú mismo/a con el mouse.

### Las dos recetas: Michelada y Azulito
Reescribí todo el orden de `VasoMichelada.gd` según diste:
- **Michelada**: vaso → chamoy (rojo o azul) → chile en polvo/escarchado
  (rojo o azul) → limón → cerveza → gomitas
- **Azulito**: vaso → chamoy (rojo o azul) → chile en polvo/escarchado
  (rojo o azul) → vodka → gatorlite → gomitas

Los primeros dos pasos (chamoy, chile en polvo) son iguales para las dos;
el camino se decide solo cuando pones limón (Michelada) o vodka (Azulito)
— después de eso ya no puedes cambiar de camino (si intentas mezclar,
se rechaza con un mensaje claro, ej. "ya le pusiste vodka: este va a ser
un Azulito").

**Nota importante sobre el dilema de menores de edad**: con las dos
recetas que diste, AMBAS bebidas llevan alcohol (cerveza o vodka) — ya no
existe una versión "sin alcohol" dentro de las reglas que especificaste.
Así que `vaso.tiene_alcohol()` ahora es prácticamente siempre `true` para
cualquier bebida completa, y actualicé el diálogo de Nancy para reflejar
esto ("ninguna de las dos es apta para menores"). Si más adelante quieres
una tercera opción sin alcohol, dime y la agrego.

### Slots de clientes aleatorios
Ya lo tenían implementado desde el paquete anterior (izquierda/centro/
derecha, sin encimarse); ahora además **el orden en que se llenan los
huecos es aleatorio** (`vacios.shuffle()` antes de repartir), así los
clientes no siempre aparecen del mismo lado.

### Texto amarillo del tutorial ya no se encima
El cuadro de diálogo de Nancy tenía el texto normal (`TextoLabel`) y la
pista amarilla (`PistaLabel`) ocupando el mismo rectángulo — cuando las
dos estaban visibles a la vez, se veían encimadas. Les di cada una su
propia fila (una arriba de la otra) dentro del cuadro.

## Ingredientes eliminados / cambiados desde la entrega anterior
`sal`, `hielo` y `cerveza_azul` ya NO existen (no estaban en tu lista de
10 archivos). Todas las recetas de `CharacterDB.gd` se reescribieron con
los ingredientes nuevos.

## Qué reemplaza este paquete (todo, completo)
`Main.gd`, `Main.tscn`, `VasoMichelada.gd`, `CharacterDB.gd`,
`TutorialOverlay.gd`, **`ClienteSlotDrop.gd` (archivo nuevo — cópialo a
`res://scripts/`)**, y las carpetas `assets/michelada_capas/` y
`assets/sprites/` completas (sobrescribe).

## Pendientes de tu lado
- Confirma si `mesa.png` = vaso (ver el aviso arriba).
- Los íconos y capas de chamoy/gatorlite/gomitas/vaso que generé son
  marcadores de posición (arte simple hecho por código) — reemplázalos
  con tus PNG reales usando los MISMOS nombres de archivo
  (`chamoy_cafe.png`, `chamoy_azul.png`, `gatorlite.png`, `gomitas.png`,
  `vodka.png`, `vaso.png` en `assets/sprites/ingredients/`, y las
  versiones de capa dentro de `assets/michelada_capas/`) y todo debería
  seguir funcionando sin tocar código.
