# Arquitectura de jerarquía de memoria 

----

## 1. Diagrama de jerarquía de memoria

En el siguiente diagrama se muestra como se ve la jerarquía de memoria acoplada entre los pipes de MEM y WB del procesador.

## 2. Especificaciones de la caché y memoria

A continuación se describen las características de la memoria caché y memoria de datos, que incluye sus políticas de escritura y reemplazo seleccionadas, implementadas en SystemVerilog.

### Caché L1-D

+ TAMAÑO: *(modificable)* 4 KB
+ ASOCIATIVIDAD: *(modificable)* 2 vías
+ TAMAÑO DE LÍNEA: *(modificable)* 32 bytes
+ LATENCIA: *(modificable)* 1 ciclo
+ ESCRITURA: write-through con buffer de escritura
+ REEMPLAZO: FIFO

### Caché L2

+ TAMAÑO: *(modificable)* 16 KB
+ ASOCIATIVIDAD: *(modificable)* 4 vías
+ TAMAÑO DE LÍNEA: *(modificable)* 32 bytes
+ LATENCIA: *(modificable)* 8 ciclos
+ ESCRITURA: write-through con buffer de escritura
+ REEMPLAZO: FIFO

### Memoria Principal

+ TAMAÑO: *(modificable)* 64 KB
+ TAMAÑO DE LÍNEA: *(modificable)* 32 bytes
+ LATENCIA: *(modificable)* 25 ciclos

NOTAS:

+ La latencia de las memorias es un aspecto de simulación alcanzado por medio de contadores de ciclos.
+ El tamaño de línea especifica la cantidad de bytes por bloque en cada vía de un set, por lo que es necesario que este valor sea el mismo en todos los niveles de memoria.
+ Al empaquetar las memorias caché con la memoria de datos en un mismo modulo, es necesario controlar los accesos a estos por medio de una máquina de estados finitos (FSM) por lo que evidemente existe un coste de latencia adicional sobre las operaciones de memoria.

## 3. Decisiones de diseño relavantes

### Selección de políticas de escritura

Se escoge una política de escritura write-through para ambas caché, ya que permite simplificar el control sobre las escrituras ya que solo es necesario mantener las señales de escritura hasta que se escriba al menos en el primer buffer.

### Selección de políticas de reemplazo

Para ambas caché se escoge una política de reemplazo FIFO para reemplzar siempre la primer vía del set al que se mapea los datos faltantes por un miss (llenar la línea).
