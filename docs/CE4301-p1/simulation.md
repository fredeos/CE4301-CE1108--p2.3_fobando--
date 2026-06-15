# Modelado de la simulación

- **Entorno de simulación**: testbench. Todos lo módulos implementados vienen con su respectivo testbench para simulación. No todos los testbench hacen uso del visualizador de ondas.
- **Estímulos**: casos de prueba. Ya sea qué el módulo describa un circuito combinacional o secuencial, las pruebas se realizan estimulando las señales de entrada de los módulos y verificando las salidas por medio de `$display()` para diferentes casos.
- **Temporización**: para módulos secuenciales se realiza la temporización por medio de pulsaciones controladas de las señales de reloj por medio de `always #5 clk = ~clk`, entre otros. La lógica de los circuitos secuenciales se diseña para flancos positivos.
- **Otras herramientas**: para los módulos con memorias modificables se hacen volcados de memoria para guardar el estado final en archivos hexadecimales en el directorio `/output`.
