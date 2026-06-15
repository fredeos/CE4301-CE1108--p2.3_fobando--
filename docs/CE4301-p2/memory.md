# Arquitectura de jerarquía de memoria 

----

## 1. Diagrama de jerarquía de memoria

En el siguiente diagrama se muestra como se ve la jerarquía de memoria acoplada entre los pipes de MEM y WB del procesador.

## 2. Especificaciones de la caché y memoria

A continuación se describen las características de la memoria caché y memoria de datos, que incluye sus políticas de escritura y reemplazo seleccionadas, implementadas en SystemVerilog.

### Caché L1-D

+ **TAMAÑO**: *(modificable)* 4 KB
+ **ASOCIATIVIDAD**: *(modificable)* 2 vías
+ **TAMAÑO DE LÍNEA**: *(modificable)* 32 bytes
+ **LATENCIA**: *(modificable)* 1 ciclo
+ **ESCRITURA**: write-through con buffer de escritura
+ **REEMPLAZO**: FIFO o Random

### Caché L2

+ **TAMAÑO**: *(modificable)* 16 KB
+ **ASOCIATIVIDAD**: *(modificable)* 4 vías
+ **TAMAÑO DE LÍNEA**: *(modificable)* 32 bytes
+ **LATENCIA**: *(modificable)* 8 ciclos
+ **ESCRITURA**: write-through con buffer de escritura
+ **REEMPLAZO**: FIFO o Random

### Memoria Principal

+ **TAMAÑO**: *(modificable)* 64 KB
+ **TAMAÑO DE LÍNEA**: *(modificable)* 32 bytes
+ **LATENCIA**: *(modificable)* 25 ciclos

NOTAS:

+ La latencia de las memorias es un aspecto de simulación alcanzado por medio de contadores de ciclos.
+ El tamaño de línea especifíca la cantidad de bytes por bloque en cada vía de un set, por lo que es necesario que este valor sea el mismo en todos los niveles de memoria.
+ Al empaquetar las memorias caché con la memoria de datos en un mismo módulo, es necesario controlar los accesos a estos por medio de una máquina de estados finitos (FSM) por lo que evidemente existe un coste de latencia adicional sobre las operaciones de memoria.

## 3. Decisiones de diseño relavantes

### Tipo de memoria caché

Por cuestión de facilidad y tiempo, se implementan memorias caché bloqueantes ya que en un procesador con pipeline puede inducir en bugs o problemas de coherencia de datos.

### Selección de políticas de escritura

Se escoge una política de escritura write-through para ambas caché, ya que permite simplificar el control sobre las escrituras ya que solo es necesario mantener las señales de escritura hasta que se escriba al menos en el primer buffer. Un aspecto importante sobre el comportamiento de las escrituras es que ante misses en un nivel estos se omiten y simplemente se deja pasar el dato hasta que llegue al siguiente nivel. Esto último, permite reducir la latencia efectiva de las escrituras. Algunas otras consideraciones necesarias incluyen la necesidad de adelantar bytes desde los buffers y verificar si una escritura es posible verificando si los buffers están llenos.

Para el adelantamiento, en vista de que los buffers son de tamaños pequeños para almacenar entre 2 y 8 datos, se utiliza lógica combinacional para verificar cuáles bytes de un dato que se quiera leer están en un buffer dado. Usando este resultado se puede saber si el siguiente nivel de memoria posterior al buffer produce una lectura desactualizada. Para este fin se diseña mapeos de bytes para datos en buffers para saber si existen traslapes de bytes entre la lectura y una futura escritura. Cuando estos casos suceden en niveles como L2 o memoria principal se penalizan estos adelantamientos ignorando las líneas faltantes en niveles inferiores; es decir si en L1 y L2 hubieron misses y memoria principal obtiene el dato, pero con bytes adelantados de su buffer de escritura, entonces se omiten las etapas de rellenado de líneas faltantes en L1 y L2. Esta política se hace para simplificar la lógica combinacional para la transferencia de ráfagas de datos.

Por otro lado, el control sobre las escrituras depende de si alguno de los buffers están llenos, ya que debido a la latencia existente en cada memoria se debe verificar que exista espacio para que la escritura se puede propagar correctamente por lo que antes de escribir al primer buffer se hace una verificación del estado de los buffers. Hasta que el dato finalmente se escribe en el primer buffer se deja fluir el pipeline.

### Selección de políticas de reemplazo

En vista de que las caché L1 y L2 son descritas por un mismo módulo de caché génerico que permite alternar entre políticas de reemplazo FIFO y random, se implementan ambas políticas para ambas. Sin embargo, usando FIFO en ambos niveles se obtiene un mejor desempeño ya que, al L2 tener mayor tamaño y más vías, cuando se desalojan líneas en L1 es más probable volver a encontrarlas en L2 debido a que las escrituras se propagan en los buffers de escritura; esto funciona casi como una caché víctima, pero un coste de latencia mayor debido a las restricciones de L2. Caso contrario, si L2 utiliza una política random, al desalojar líneas en L1 es menos probable volver a encontrarlas en L2. Por está razón es recomendable utilizar combinaciones de políticas como FIFO-FIFO o Random-FIFO, ya que son más óptimas.

### Diseño de dispositivos controladores de memoria (FSM)

A continuación se describen las etapas de las máquinas de estados (FSM) para el control de lectura y escritura, respectivamente.

- **FSM de lectura**
  + **IDLE**: esperando datos para iniciar lectura
  + **REQUEST L1**: buscar en caché L1
  + **ASSERT L1**: capturar resultado de caché L1
  + **REQUEST L2**: buscar en caché L1
  + **ASSERT L2**: capturar resultado de caché L2
  + **REQUEST MEM**: buscar en memoria principal
  + **ASSERT MEM**: capturar resultado de memoria principal
  + **FILL L1**: llenado de líneas de L1
  + **FILL L2**: llenado de líneas de L2
  + **DONE**: resultado está listo

- **FSM de escritura**
  + **IDLE**: esperando datos para iniciar escritura
  + **WAIT**: verifica si los buffers permiten más escrituras
  + **WRITE**: escribre el dato al primer buffer
  + **DONE**: resultado ya fue escrito
