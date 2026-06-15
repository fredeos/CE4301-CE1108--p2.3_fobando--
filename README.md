# CE4301--p2_fobando_isa--

Este repositorio contiene el desarrollo del primer proyecto grupal del curso CE4301 – Arquitectura de Computadores I. El objetivo del proyecto es diseñar e implementar una arquitectura de set de instrucciones (ISA) tipo RISC orientada a aplicaciones de seguridad informática, utilizando SystemVerilog.

La propuesta incorpora soporte a nivel de hardware para operaciones criptográficas eficientes, mediante la implementación del algoritmo TEA, así como un mecanismo seguro de almacenamiento de llaves criptográficas basado en una bóveda protegida. Todo el sistema es validado mediante simulación, permitiendo analizar su funcionalidad de manera correcta.

## Estructura del repositorio

```

├── images/              # Imagenes utilizadas en la documentacion
├── input/               # Archivos de entrada (texto, imágenes, etc.)
├── output/              # Resultados generados por la simulación
├── res/                 # Recursos adicionales
├── src/                 # Código fuente
│   ├── alu/                    # Implementación de las ALUs
│   ├── control/                # Unidad de control
│   ├── datamem/                # Memoria de datos
│   ├── datapath/               # Datapath del procesador
│   ├── hazard/                 # Unidad de Hazard
│   ├── instrmem/               # Memoria de instrucciones
│   ├── regfile/                # Banco de registros
│   ├── secmem/                 # Memoria segura
│   ├── vault/                  # Bóveda de llaves criptográficas
│   ├── extract_data.py         # Genera archivo con datos extraídos
│   ├── gen_file.py             # Generador de archivos
│   └── load_file.py            # Carga de archivos a memoria
├── docs/
|    ├── EspecificacionISA-P1.pdf   # Descripcion del ISA desarrollado
|    ├── isa.md                     # Green sheet del ISA desarrollado
|    ├── microarchitecture.md       # Descripción de la microarquitectura
|    └── simulation.md              # Detalles sobre la simulación
├── tea/
|    ├── proof/                   # Para guardar resultados del algoritmo
|    ├── asm_parser.py            # Parser de codigo ensamblador FCC
|    ├── asm_to_bin.py            # Codifica instrucciones a binario
|    ├── gen_tea_compact.py       # Genera los programas TEA (encrypt/decrypt) en .HEX
|    ├── gen_tea_unrolled.py      # Genera y ensambla los programas TEA en .HEX según el archivo de entrada
|    ├── tea_decrypt.asm          # Algoritmo de desencriptado TEA en ensamblador FCC
|    ├── tea_decrypt.f            # Algoritmo de desencriptado TEA en alto nivel
|    ├── tea_decrypt.hex          # Algoritmo de desencriptado TEA codificado
|    ├── tea_encrypt.asm          # Algoritmo de encriptado TEA en ensamblador FCC
|    ├── tea_encrypt.f            # Algoritmo de encriptado TEA en alto nivel
|    └── tea encrypt.hex          # Algoritmo de encriptado TEA codificado
├── .gitignore
├── commands.txt           # Comandos útiles y scripts de ejecución
├── LICENSE
├── Makefile               # Automatización de compilación/simulación
└── README.md

```
Nota: Cada carpeta funcional dentro de `src/` contiene un subdirectorio `test/` donde se encuentran los testbenches asociados a ese módulo (por ejemplo: `alu/test/`, `vault/test/`, etc.).

---

## Requisitos previos

Antes de ejecutar el proyecto, asegúrese de tener instalado lo siguiente:

| Herramienta | Descripción |
|---|---|
| [Icarus Verilog](https://bleyer.org/icarus/) | Compilador y simulador de Verilog/SystemVerilog |
| [GTKWave](https://bleyer.org/icarus/) | Visualizador de waveforms (incluido en el instalador de Icarus) |
| Git Bash | Terminal para ejecutar los comandos `make` en Windows |
| Python 3.x | Requerido para los scripts de preprocesamiento |

>  **Sistema Operativo soportado:** Windows  
> Los comandos de compilación y simulación utilizan `make` a través de Git Bash. No se garantiza compatibilidad con CMD o PowerShell.

## Instrucciones de ejecución

Todos los comandos deben ejecutarse desde la **raíz del repositorio** usando **Git Bash**.

Las memorias del procesador se inicializan a partir de archivos `.HEX` ubicados en las siguientes carpetas:

| Carpeta | Descripción |
|---|---|
| `src/instrmem/` | Memoria de instrucciones |
| `src/datamem/` | Memoria de datos de entrada/salida |
| `src/vault/` | Bóveda de llaves criptográficas |

---

### Compilación de un módulo

Para compilar un módulo junto con sus dependencias y su testbench, ejecute el comando correspondiente:

```bash
$ make ControlUnit        # Unidad de Control
$ make CondUnit           # Unidad de Condiciones
$ make AdminUnit          # Unidad de Administrador
$ make SSU                # Unidad de Selección Segura
$ make SecureMemory       # Memoria Segura
$ make RegFile            # Banco de Registros
$ make Hazard             # Unidad de Riesgos
$ make InstructionMemory  # Memoria de Instrucciones
$ make DataMemory         # Memoria de Datos
$ make Vault              # Bóveda
$ make pALU               # ALU primaria
$ make sALU               # ALU secundaria
$ make ImmExt             # Unidad de Extensión de Inmediatos
$ make Datapath           # Datapath completo del procesador
```

---

### Simulación

Una vez compilado el módulo deseado, puede ejecutar la simulación con los siguientes comandos.

Sin configuración de waveform:

```bash
$ make run
```

Con una configuración predeterminada de señales para GTKWave:

```bash
$ make run-config TARGET=wave
```

En todos los casos, los archivos generados en el directorio `/output` son:

- `sim.out` — archivo de salida de la simulación
- `wave.vcd` — archivo de waveform para GTKWave

Para módulos con memorias, se generan además:

| Archivo | Descripción | Módulos |
|---|---|---|
| `data_mem_exit.hex` | Estado de salida de memoria de datos | Datapath, DataMemory |
| `vault_exit.hex` | Estado de salida de la bóveda | Datapath, Vault |
| `regfile_exit.hex` | Estado de salida del banco de registros | Datapath |
| `secmem_exit.hex` | Estado de salida de la memoria segura | Datapath |

> El TARGET especificado en el comando especifica un archivo .gtkw con una configuración de señales establecida, pero se puede especificar otro archivo de este tipo que se tenga guardado en el directorio `/output`.

---

### Carga de datos a las memorias

Para cargar un archivo en una memoria (de instrucciones o de datos), ejecute:

```bash
$ make pyload-mem INPUT=<archivo> OUTPUT=<memoria> ADDRESS=<direccion>
```

Donde:

- `<archivo>` — nombre del archivo en el directorio `/input` que se desea escribir en la memoria
- `<memoria>` — archivo `.HEX` de la memoria destino:
  - Memoria de datos: `datamem/data_mem.hex`
  - Memoria de instrucciones: `instrmem/instr_mem.hex`
- `<direccion>` — posición en bytes desde la cual se escribe el contenido (ej. `0x4`)

---

### Extracción de datos de las memorias

Para extraer datos de una memoria de salida y guardarlos en un archivo, ejecute:

```bash
$ make pyextract-data INPUT=<memoria> ADDRESS=<direccion> SIZE=<tamaño> OUTPUT=<archivo>
```

Donde:

- `<memoria>` — archivo de estado de salida de una memoria en el directorio `/output`
- `<direccion>` — dirección en bytes desde la cual se comienza a leer (ej. `0x4`)
- `<tamaño>` — tamaño en bytes del archivo de salida (ej. `245`)
- `<archivo>` — nombre con extensión del archivo de salida, guardado en `/output` (ej. `imagen.png`)

---

## Ejecución del Algoritmo TEA

Esta sección describe el flujo completo para encriptar y desencriptar un archivo usando el algoritmo TEA sobre el procesador simulado.

>  En los comandos de Python, `python3` puede sustituirse por `python` o `py` dependiendo de su instalación.

---

### Encriptado

**1. Generar las instrucciones TEA y preparar la memoria de datos**

Se carga el archivo de entrada en la memoria de datos. El archivo de entrada puede ser cualquier tipo de archivo (`.png`, `.jpeg`, `.txt`, etc.)

```bash
python3 tea/gen_tea_unrolled.py --input input/<archivo_entrada> --address 0x0 --mode both
make pyload-mem INPUT=<archivo_de_entrada> OUTPUT=datamem/data_mem.hex ADDRESS=0x0
```

**2. Cargar el programa de encriptado en la memoria de instrucciones**

```bash
cp tea/tea_encrypt.hex src/instrmem/instr_mem.hex
```

**3. Compilar y ejecutar la simulación**

```bash
make Datapath
make run
```

O bien, para ejecutar con un waveform predeterminado que muestra las señales de cada etapa del pipeline y el ciclo correspondiente:

```bash
make run-config TARGET=wave
```

**4. Guardar el resultado encriptado**

```bash
cp output/data_mem_exit.hex tea/proof/<nombre>_encrypted.hex
```

---

### Desencriptado

**1. Cargar el archivo encriptado y el programa de desencriptado**

```bash
make pyload-mem INPUT=../tea/proof/<nombre>_encrypted.hex OUTPUT=datamem/data_mem.hex ADDRESS=0x0
cp tea/tea_decrypt.hex src/instrmem/instr_mem.hex
```

**2. Ejecutar la simulación**

```bash
make run
```

O con waveform:

```bash
make run-config TARGET=wave
```

**3. Guardar el resultado y extraer el archivo original**

Primero se copia la memoria de salida:

```bash
cp output/data_mem_exit.hex tea/proof/<nombre>_decrypted_mem.hex
```

Luego se extrae el archivo recuperado. El parámetro `SIZE` corresponde al tamaño del archivo original en bytes, y `OUTPUT` define el nombre y extensión del archivo reconstruido:

```bash
make pyextract-data \
  INPUT=../tea/proof/<nombre>_decrypted_mem.hex \
  ADDRESS=0x0 \
  SIZE=<tamano_archivo_orig> \
  OUTPUT=../tea/proof/<nombre>_decrypted.<extension_archivo_original>
```

---

## Ejemplos de uso

### Carga de diferentes tipos de archivo

```bash
# Cargar una imagen PNG
make pyload-mem INPUT=foto.png OUTPUT=datamem/data_mem.hex ADDRESS=0x0

# Cargar un archivo PDF
make pyload-mem INPUT=archivo.pdf OUTPUT=datamem/data_mem.hex ADDRESS=0x0

# Cargar un documento de texto
make pyload-mem INPUT=documento.txt OUTPUT=datamem/data_mem.hex ADDRESS=0x0

# Cargar un programa de prueba en la memoria de instrucciones
make pyload-mem INPUT=prueba.hex OUTPUT=instrmem/instr_mem.hex ADDRESS=0x0
```

> Recuerde que para cargar un archivo, este debe encontrarse en la carpeta `input/` del proyecto

### Uso del algoritmo

#### Ejemplo 1: Imagen .png

Se utilizará la siguiente imagen:

![bedrock](input/bedrock.png)

**Cifrado**

```bash
# 1. Generar instrucciones TEA y cargar el archivo
python3 tea/gen_tea_unrolled.py --input input/bedrock.png --address 0x0 --mode both
make pyload-mem INPUT=bedrock.png OUTPUT=datamem/data_mem.hex ADDRESS=0x0

# 2. Cargar el programa de encriptado y compilar
cp tea/tea_encrypt.hex src/instrmem/instr_mem.hex
make Datapath
make run

# 3. Guardar resultado
cp output/data_mem_exit.hex tea/proof/bedrock_encrypted.hex
```

El resultado se encuentra en [bedrock_encrypted.hex](tea/proof/bedrock_encrypted.hex)

**Descifrado**

Para recuperar la imagen original:

```bash
# 1. Cargar el archivo cifrado y el programa de descifrado
make pyload-mem INPUT=../tea/proof/bedrock_encrypted.hex OUTPUT=datamem/data_mem.hex ADDRESS=0x0
cp tea/tea_decrypt.hex src/instrmem/instr_mem.hex

# 2. Ejecutar la simulación
make run

# 3. Extraer el archivo recuperado
cp output/data_mem_exit.hex tea/proof/bedrock_decrypted_mem.hex
make pyextract-data \
  INPUT=../tea/proof/bedrock_decrypted_mem.hex \
  ADDRESS=0x0 \
  SIZE=247 \
  OUTPUT=../tea/proof/bedrock_decrypted.png
```

El resultado del descifrado lo puede ver en: [bedrock_decrypted_mem.hex](tea/proof/bedrock_decrypted_mem.hex)

Y la imagen ya generada: [bedrock_decrypted.png](tea/proof/bedrock_decrypted.png)

#### Ejemplo 2: Archivo .txt 

Se utilizará el siguiente archivo:

[mensaje_tea2.txt](input/mensaje_tea2.txt)

**Cifrado**

```bash
# 1. Generar instrucciones TEA y cargar el archivo
python3 tea/gen_tea_unrolled.py --input input/mensaje_tea2.txt --address 0x0 --mode both
make pyload-mem INPUT=mensaje_tea2.txt OUTPUT=datamem/data_mem.hex ADDRESS=0x0

# 2. Cargar el programa de encriptado y compilar
cp tea/tea_encrypt.hex src/instrmem/instr_mem.hex
make Datapath
make run

# 3. Guardar resultado
cp output/data_mem_exit.hex tea/proof/mensaje_tea2_encrypted.hex
```

El resultado se encuentra en [mensaje_tea2_encrypted.hex](tea/proof/mensaje_tea2_encrypted.hex)

**Descifrado**

Para recuperar la imagen original:

```bash
# 1. Cargar el archivo cifrado y el programa de descifrado
make pyload-mem INPUT=../tea/proof/mensaje_tea2_encrypted.hex OUTPUT=datamem/data_mem.hex ADDRESS=0x0
cp tea/tea_decrypt.hex src/instrmem/instr_mem.hex

# 2. Ejecutar la simulación
make run

# 3. Extraer el archivo recuperado
cp output/data_mem_exit.hex tea/proof/mensaje_tea2_decrypted_mem.hex
make pyextract-data \
  INPUT=../tea/proof/mensaje_tea2_decrypted_mem.hex \
  ADDRESS=0x0 \
  SIZE=301 \
  OUTPUT=../tea/proof/mensaje_tea2_decrypted.txt
```

El resultado del descifrado lo puede ver en: [mensaje_tea2_decrypted_mem.hex](tea/proof/mensaje_tea2_decrypted_mem.hex)

Y el archivo txt recuperado: [mensaje_tea2_decrypted.txt](tea/proof/mensaje_tea2_decrypted.txt)


---
## Integrantes
- [@fredeos](https://github.com/fredeos) Frederick Obando
- [@diegosalaov](https://github.com/diegosalasov) Diego Salas
- [@SpaceBa13](https://github.com/SpaceBa13) Brayan Alpizar
- [@maarigonzalezz](https://github.com/maarigonzalezz) Mariana González

