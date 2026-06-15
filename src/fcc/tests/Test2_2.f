int lista_largo = 7;
int lista[7];
int max = 0;

func int maximo_lista(int[] valores, int largo){
    int i = 0;
    int maximo = valores[0];

    while (i < largo) {
        if (valores[i] > maximo) {
            maximo = valores[i];
        }

        i += 1;
    }

    ret maximo;
}

func int main() {
    lista[0] = 3;
    lista[1] = 4;
    lista[2] = 5;
    lista[3] = 24;
    lista[4] = 5;
    lista[5] = 65;
    lista[6] = 46;

    max = maximo_lista(lista, lista_largo);
    ret max;
}
