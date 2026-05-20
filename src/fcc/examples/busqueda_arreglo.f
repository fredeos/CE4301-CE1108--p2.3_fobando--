int found_index;

func int buscar(int objetivo){
    int datos[5];
    int i = 0;
    int posicion = -1;
    bool encontrado = false;

    datos[0] = 4;
    datos[1] = 1;
    datos[2] = 7;
    datos[3] = 9;
    datos[4] = 6;

    while (i < 5) {
        if (datos[i] == objetivo) {
            posicion = i;
            encontrado = true;
        }

        if (!encontrado) {
            i += 1;
        } else {
            i = 5;
        }
    }

    found_index = posicion;
    ret posicion;
}

func void main(){
    buscar(7);
}
