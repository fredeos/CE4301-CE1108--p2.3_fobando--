func int maximo_lista(){
    int i = 0;
    int maximo = lista[0];

    while (i < lista_largo) {
        if (lista[i] > maximo) {
            maximo = lista[i];
        }

        i += 1;
    }

    ret maximo;
}