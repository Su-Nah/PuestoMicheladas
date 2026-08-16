# Vaso por capas (en vez de 65 combinaciones) + hardening del freeze

## Sobre el freeze al darle a "Servir michelada"
Con el `.uid` que mandaste confirmé que no existe un `MicheladaMixer.gd` con
contenido propio en tu proyecto — el `.uid` es solo el "apuntador" que
Godot genera por cada script, pero el archivo `.gd` real ya no está (se
renombró a `Main.gd`, según lo que vimos). Así que el bug está en algún
lugar del flujo `Main.gd` ⇄ `VasoMichelada.gd`.

Revisé todo el camino que se ejecuta al presionar "Servir" línea por línea
y no encontré ningún bucle infinito (ni en `Main.gd`, ni en
`CustomerSpawner.gd`, que además ya tenía un límite de intentos
anti-loop-infinito puesto por ustedes). Lo más probable es que un dato
faltante (por ejemplo, un campo ausente en un diccionario) causara un error
de tipo a medio camino de `_resolver_cliente()`, dejando la bandera interna
`resolviendo` en `true` para siempre — eso hace que el botón "Servir" deje
de reaccionar y la barra de paciencia se quede congelada, dando la
sensación de que "el juego se traba" aunque el motor sigue corriendo.

Hice dos cosas para blindar esto:
1. **`Main.gd`**: cambié todos los accesos `cliente_actual["campo"]` (que
   truenan si el campo no existe) por `cliente_actual.get("campo", valor_por_defecto)`
   en la función que se dispara al servir.
2. **`VasoMichelada.gd`**: le agregué `class_name VasoMichelada` y en
   `Main.gd` ahora la variable `vaso` está tipada como `VasoMichelada` (antes
   como `Panel` genérico). Esto no debería cambiar el comportamiento, pero
   hace que Godot pueda verificar en tiempo de análisis que
   `vaso.tiene_alcohol()`, `vaso.reset()`, etc. existen de verdad, en vez de
   confiar en que se resuelvan en tiempo de ejecución.

**Si el freeze sigue pasando con este paquete**, lo que más me ayudaría es
que abras la pestaña "Debugger" / "Output" de Godot (abajo del editor) justo
después de que se trabe, y me copies el texto en rojo que aparezca ahí —
con eso puedo ir directo a la línea exacta en vez de ir a ciegas.

## El cambio que pediste: capas en vez de 65 combinaciones
Ya no genero un PNG distinto por cada una de las 65 combinaciones válidas.
Ahora el vaso es una **pila de capas** (como en Photoshop): cada ingrediente
tiene su propia imagen transparente del tamaño completo del vaso, y
`VasoMichelada.gd` simplemente la muestra u oculta según si ese ingrediente
está puesto. Al estar unas encima de otras, el motor las combina solo — así
que cualquier combinación de las 65 (y cualquier futura, si agregan más
ingredientes) se ve bien sin que tengas que generar un PNG por cada mezcla.

Capas, de abajo hacia arriba:
1. `vidrio_base` — el vaso vacío (siempre visible)
2. `liquido_salsa_tomate`, `liquido_chile_liquido`, `liquido_cerveza`,
   `liquido_cerveza_azul` — cada una semitransparente a propósito, para que
   si el jugador combina varias (ej. salsa + chile + cerveza) se vean
   "mezcladas" entre sí de forma natural, sin necesitar código de mezcla de
   colores.
3. `hielo`
4. `rim_sal` / `rim_escarchado_cafe` / `rim_escarchado_azul` — el borde del
   vaso. Solo una de las tres es visible a la vez (la lógica de
   `VasoMichelada.gd` ya se encarga de que solo pueda haber una puesta).
5. `limon` — el gajito decorativo en el borde
6. `contorno` — el borde/silueta del vaso, siempre visible y siempre hasta
   arriba para que se vea nítido encima de todo lo demás.

## Qué reemplaza este paquete
- **`VasoMichelada.gd`** → reescrito para el sistema de capas. Las reglas de
  orden de los ingredientes NO cambiaron, solo cambió cómo se dibuja el
  vaso.
- **`Main.tscn`** → dentro de `Mesa/Vaso` ya no hay un solo `VasoSprite`,
  ahora hay un nodo `VasoCapas` con 11 `TextureRect` hijos (uno por capa).
- **`Main.gd`** → mismo comportamiento de antes, con los accesos más
  seguros que mencioné arriba y el tipo `VasoMichelada` en vez de `Panel`.
- **`CharacterDB.gd`** → sin cambios respecto al paquete anterior (lo
  incluyo de nuevo por completitud).
- **`assets/michelada_capas/`** → las 11 imágenes de capas (reemplaza a la
  carpeta `assets/michelada/` de 65 archivos, que ya NO se usa — puedes
  borrarla de tu proyecto si quieres, aunque dejarla no rompe nada).
- **`assets/sprites/ingredients/`** → los mismos 7 iconos de ingredientes
  del paquete anterior, sin cambios, incluidos por completitud.

## Cómo integrarlo
1. Reemplaza `VasoMichelada.gd`, `Main.gd`, `Main.tscn` y `CharacterDB.gd`
   donde ya los tenías.
2. Copia `assets/michelada_capas/` a `res://assets/michelada_capas/`.
3. (Opcional) borra `res://assets/michelada/` — ya no se usa.
4. Abre `Main.tscn` en el editor y confirma que dentro de `Mesa > Vaso`
   aparece el nuevo nodo `VasoCapas` con sus 11 hijos.
