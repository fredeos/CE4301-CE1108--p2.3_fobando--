# Organización del CPU

## Microarquitectura

En esta sección se detalla la organización interna del procesador diseñado para la arquitectura RISC planteada en el ISA. El procesador se basa en una **arquitectura Harvard** con una separación física de las memorias de instrucciones y datos.

---------

- ### Diagrama de bloques

<p align="center">
    <img src="../images/datapath.svg" width=1500>
</p>

Notese que del diagrama anterior se resaltan las entradas y salidas del Hazard Unit con colores azules y verdes, respectivamente, mientras que para señales de control del Control Unit se utilizan múltiples colores y para conexiones de cada etapa se utiliza el color negro. Otro aspecto importante de notar es que todos los circuitos secuenciales y flip-flops tiene un señal RST, distinta a los CLR visibles, que permiten limpiar los registros de manera asíncrona para poder inicialiar el estado inicial del procesador (pipeline vacío).

- ### Módulos de desarrollados

  - **Memoria de instrucciones (*Instruction Memory*)**:
    Circuito combinacional para lectura de instrucciones con alineamiento por byte. Este circuito se comporta como una ROM, ya que solo permite lecturas de datos.
  - **Unidad de selección segura (*SSU*)**:
    Circuito combinacional para identificar instrucciones que requieren hardware seguro o tienen ejecución condicional antes de que estas entren al pipeline. Este modulo produce 2 salidas, un bit para ignorar o omitir el ingreso de la instruccion al pipeline (sustituye por un `nop`) y un bit para refrescar sesiones seguras el cual se propaga en el pipeline hasta su ingreso al Admin Unit en MEM.
  - **Unidad de control (*Control Unit*)**:
    Unidad encargada de decodificar las instrucciones y producir las señales de control necesarias para configurar las ALU, multiplexores, memorias y bancos de registros. Esta unidad está compuesta por tres submodulos: decodificador principal (*Main Decoder*), decodificador de ALU (*ALU Decoder*) y decodificador de ramas (*Branch Decoder*).
    <p align="center">
        <img src="../images/control_unit.svg" width=600>
    </p>
  - **Banco de registros (*Register File*)**:
    Circuito secuencial para escritura y lectura de 32 registros definidos por el ISA. Permite escritura en flancos positivos de reloj y lectura combinacional. Para la lectura de registros permite seleccionar un dato que se está escribiendo (*bypass*).
  - **Memoria segura (*Secure memory*):**
    Circuito secuencial para escritura y lectura de 8 registros seguros definidos por el ISA. Permite escritura en flancos positivos de reloj y lectura combinacional. Para la lectura de registros permite seleccionar un dato que se está escribiendo (*bypass*).
  - **ALU primaria (*pALU*)**:
    Circuito combinacional para ejecución de operaciones de suma, resta, multiplicación, división, módulo, and, or, xor, set equal y corrimientos lógicos con dos operandos. Produce bandares de salida para negativo (N), cero(Z), acarreo(C) y desbordamiento(V).
  - **ALU secundaria (*sALU*)**:
    Circuito combinacional para ejecución de operaciones de suma y xor con dos operandos.
  - **Unidad de administrador (*Admin Unit*)**:
    Unidad secuencial encargada de llevar un control de los sesiones en el hardware seguro, esta permite llevar un conteo de ciclos para mantener una sesión abierta si no se han usado más instrucciones que requieren el hardware (este conteo es refrescable si ingresan más instrucciones de este tipo al pipeline) y conteo de ciclos para inhabilitar el uso de hardware seguro en caso de exceder la cantidad máxima de intentos de inicios de sesión.
    <p align="center">
        <img src="../images/admin_unit.svg" width=600>
    </p>
    Este módulo hace uso de dos submódulos comparadores de ciclos (que son los que permiten llevar los conteos mencionados anteriormente)
    <p align="center">
        <img src="../images/cycle_comparer.svg" width=600>
    </p>
  - **Unidad de condiciones (*Cond Unit*)**:
    Unidad combinacional utilizada para detectar las condiciones de los saltos utilizando las banderas de salidad de ALU. También, permite detectar si hay instrucciones que modifican el registro `PC` para poder alterar el flujo de las instrucciones.
  - **Bóveda (*Vault*)**:
    Circuito secuencial para lectura y escritura 16 palabras/llaves necesarias para aplicaciones de criptografía. El procesador siempre inicia con un conjunto de llaves por defecto. La memoria está alineada por palabra, pero es direccionable por byte por medio de detección cruce del límite de palabra lo que permite acceder a bytes de palabras contiguas. Permite escritura en flanco positivos de reloj y lectura combinacional.
  - **Memoria de datos (*Data Memory*)**:
    Circuito secuencial para lectura y escritura de datos. La memoria está alineada por palabra, pero es direccionable por byte por medio de detección cruce del límite de palabra lo que permite acceder a bytes de palabras contiguas. Permite escritura en flanco positivos de reloj y lectura combinacional.
  - **Unidad de riesgos (*Hazard Unit*)**:
    Unidad combinacional encargada de detectar riesgos de datos y de control y controlar el flujo del pipeline por medio de adelantamientos, stalls y flushes. Este circuito implementa adelantamiento de MEM hacia EX y WB hacia ALU. Además, requiere de que el pipeline propague las instrucciones en cada etapa para determinar los tipos de adelantamiento y activación de los stall y flush necesarias para solucionar los riesgos.
  