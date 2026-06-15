# 3. Análisis de Rendimiento y Validación

Este apartado detalla la estrategia metodológica, las herramientas de telemetría y los entornos de prueba utilizados para evaluar el desempeño e integridad del procesador. Se presenta un estudio comparativo entre la arquitectura base y la variante con jerarquía de memoria multinivel.

---

## 3.1 Metodología de Medición

La recolección de métricas de rendimiento se realiza de forma dinámica en tiempo de simulación mediante una **Unidad de Monitoreo de Desempeño (PMU)** embebida en el diseño del procesador. 

### Mecanismo de Telemetría (PMU)
Para extraer las métricas sin alterar el camino crítico ni alterar el comportamiento del hardware, los entornos de verificación (*testbenches*) aplican inyecciones forzadas temporales (`force`) sobre el bus de direccionamiento de lectura de la PMU (`read_addr`). Las métricas clave monitoreadas y sus correspondientes registros internos se estructuran de la siguiente manera:

| Registro (Dirección) | Métrica Asociada | Descripción / Propósito |
| :---: | :--- | :--- |
| `5'd0` | Ciclos Totales | Contador global de ciclos de reloj de ejecución. |
| `5'd11` | Instrucciones Totales | Contador de instrucciones que alcanzan la etapa de *Writeback*. |
| `5'd12` | *Stalls* por Control | Ciclos de parada provocados por riesgos de control (ej. desvíos de saltos). |
| `5'd10` | Accesos a Memoria | Cantidad total de transacciones solicitadas por el CPU. |
| `5'd2` / `5'd5` | *Misses* L1 / L2 | Fallos totales en los niveles de caché L1 y L2 respectivamente. |
| `5'd3` / `5'd6` | *Misses* de Lectura L1 / L2 | Fallos provocados específicamente por operaciones de carga (`Load`). |
| `5'd4` / `5'd7` | *Misses* de Escritura L1 / L2 | Fallos provocados específicamente por operaciones de almacenamiento (`Store`). |
| `5'd8` / `5'd9` | Accesos L1 / L2 | Cantidad de consultas que recibe cada nivel de la jerarquía. |
| `5'd1` | *Misses* Globales | Conteo unificado de fallos que impactaron la memoria principal. |

### Modelado Aritmético de Rendimiento
Para evitar truncamientos enteros que desvirtúen los resultados de eficiencia, el entorno de pruebas procesa los datos crudos en aritmética de punto flotante (`real`), calculando de forma analítica los siguientes indicadores:

* **Instrucciones por Ciclo (IPC):** $$IPC = \frac{\text{Total Instructions}}{\text{Total Cycles}}$$
* **Tasa de Fallos (Miss Rate):** $$\text{Miss Rate}_{Lx} = \frac{\text{Total Lx Misses}}{\text{Total Lx Accesses}}$$
* **Tiempo de Acceso Promedio a Memoria (AMAT):** Refleja penalizaciones recursivas por nivel de caché:
    $$AMAT = \text{Latencia}_{L1} + \text{Miss Rate}_{L1} \times \left( \text{Latencia}_{L2} + \text{Miss Rate}_{L2} \times \text{Latencia}_{MemPrincipal} \right)$$

---

## 3.2 Benchmarks Utilizados

Para estresar la segmentación del pipeline, los mecanismos de anticipación de datos (*forwarding*), la predicción de saltos y la localidad espacial/temporal de las cachés, se compilaron y ejecutaron los siguientes programas de prueba:

1. **[Nombre del Benchmark 1, ej: Multiplicación de Matrices]:** * **Descripción:** Algoritmo intensivo en accesos a memoria secuenciales y repetitivos.
   * **Objetivo:** Evaluar la tasa de aciertos (*Hit Rate*) de la caché L1 y el impacto de los fallos en cascada hacia L2.
2. **[Nombre del Benchmark 2, ej: Ordenamiento BubbleSort / QuickSort]:**
   * **Descripción:** Algoritmo con alta densidad de instrucciones de salto condicional.
   * **Objetivo:** Evaluar la efectividad del predictor y cuantificar los *Stalls* de control detectados por el registro `5'd12`.
3. **[Nombre del Benchmark 3, ej: Operaciones Criptográficas / Acceso Seguro]:**
   * **Descripción:** Rutina orientada al manejo de datos restringidos interconectando módulos periféricos como la bóveda (`vault`) y memoria segura (`secmem`).
   * **Objetivo:** Validar el aislamiento y la consistencia de datos en escenarios de alta seguridad.

---


## 3.3 Análisis de Resultados y Comparación entre Configuraciones

A continuación, se contrastan los reportes de rendimiento obtenidos entre la configuración base (**Pipeline Monolítico sin Caché**) y la avanzada (**Pipeline con Jerarquía de Cachés L1 y L2**).

### Comparativa Cuantitativa de Desempeño

#### Benchmark #1
```f



```

| Parámetro / Métrica | Configuración Base (Sin Caché) | Configuración Avanzada (Con Caché L1/L2) | Impacto / Variación (%) |
| :--- | :---: | :---: | :---: |
| **Ciclos Totales** | | | |
| **Instrucciones Ejecutadas** | | | |
| **IPC Resultante** | | | |
| **Stalls por Control** | | | |
| **Accesos Totales a Memoria** | | | |
| **Hit Rate L1** | N/A | | N/A |
| **Hit Rate L2** | N/A | | N/A |
| **AMAT Calculado** | | | |


#### Benchmark #2
```f



```


| Parámetro / Métrica | Configuración Base (Sin Caché) | Configuración Avanzada (Con Caché L1/L2) | Impacto / Variación (%) |
| :--- | :---: | :---: | :---: |
| **Ciclos Totales** | | | |
| **Instrucciones Ejecutadas** | | | |
| **IPC Resultante** | | | |
| **Stalls por Control** | | | |
| **Accesos Totales a Memoria** | | | |
| **Hit Rate L1** | N/A | | N/A |
| **Hit Rate L2** | N/A | | N/A |
| **AMAT Calculado** | | | |

#### Benchmark #3
```f



```

| Parámetro / Métrica | Configuración Base (Sin Caché) | Configuración Avanzada (Con Caché L1/L2) | Impacto / Variación (%) |
| :--- | :---: | :---: | :---: |
| **Ciclos Totales** | | | |
| **Instrucciones Ejecutadas** | | | |
| **IPC Resultante** | | | |
| **Stalls por Control** | | | |
| **Accesos Totales a Memoria** | | | |
| **Hit Rate L1** | N/A | | N/A |
| **Hit Rate L2** | N/A | | N/A |
| **AMAT Calculado** | | | |

### Discusión del Comportamiento Arquitectónico
* **Eficiencia del Pipeline (IPC vs. Ciclos):** [Analizar aquí cómo la incorporación de la caché modificó el IPC. Discutir si la reducción de los ciclos totales compensa o no la complejidad del hardware].
* **Comportamiento de la Memoria (AMAT e Impacto de Caché):** [Explicar la efectividad de las cachés L1 y L2. Justificar los resultados de AMAT basándose en si el benchmark exhibió una buena localidad espacial o temporal].

---

## 3.4 Validación Experimental

La exactitud funcional y la consistencia del estado del procesador se verificaron mediante auditorías exhaustivas del mapa de memoria al término de cada programa.

### Criterios de Aceptación Funcional
1. **Detección de Parada Estricta:** El flujo de control valida que la simulación finalice de forma correcta mediante el opcode de detención de arquitectura (`32'h1E000080`) en la etapa de Writeback, descartando interrupciones por desbordamiento de ciclos (*timeout*).
2. **Ventana de Estabilización:** Tras la instrucción de parada, se incorporó una ventana crítica de 100 ciclos de reloj adicionales. Esto garantiza que cualquier escritura remanente en el buffer de memoria o actualización de tags de caché se asiente por completo antes de los volcados físicos.

### Verificación de Consistencia de Datos (Volcado de Archivos Hexadecimales)
Para asegurar que el procesamiento matemático y las transformaciones de datos fueron correctas, se realiza una comparación bit a bit (*diff*) de las estructuras de almacenamiento interno contra modelos de referencia dorados (*Golden Models*):