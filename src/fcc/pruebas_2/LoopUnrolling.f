int resultado_loop_unrolling;

func int procesar_bloques(int[] bloques){
    int dobles[6];
    int total = 0;
    int i = 0;

    i = 0;
    while (i < 6) {
        dobles[i] = bloques[i] * 2;
        i += 1;
    }

    total = dobles[0] + dobles[1] + dobles[2];
    total += dobles[3];
    total += dobles[4];
    total += dobles[5];

    ret total;
}

func int main(){
    int bloques[6];

    bloques[0] = 10;
    bloques[1] = 20;
    bloques[2] = 30;
    bloques[3] = 5;
    bloques[4] = 15;
    bloques[5] = 25;

    resultado_loop_unrolling = procesar_bloques(bloques);
    ret resultado_loop_unrolling;
}
