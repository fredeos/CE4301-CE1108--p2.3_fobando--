
func int analizar_sensor_reordenado(int[] datos, int tamano){
    int i = 0;
    int total = 0;

    while (i < tamano){
        int lectura = datos[i];
        int log = i * 100;

        int promedio = lectura * 2;
        int ajuste = promedio + 10;
        int resultado = ajuste * 3;

        if (lectura > 50){
            total += resultado;
        }

        i += 1;
    }

    ret total;
}


func int main(){
    int lista[5];
    lista[0] = 10;
    lista[1] = 20;
    lista[2] = 30;
    lista[3] = 40;
    lista[4] = 50;

    int resultado = analizar_sensor_reordenado(lista, 5);

    ret resultado;
}
