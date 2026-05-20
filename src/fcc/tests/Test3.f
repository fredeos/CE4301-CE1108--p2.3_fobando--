traigase "Test2.f"

int suma = 0;
int multiplicacion = 1;
int resultado_suma;
int resultado_multiplicacion;
int lista_largo = 5;
int lista[5];
int valorMaximo;

func int sumeMayores(){
    suma = 0;
    multiplicacion = 1;

    while (suma < 100) {
        valorMaximo = maximo_lista();

        if ((valorMaximo / 2) == 5) {
            valorMaximo *= 2;
        }

        suma += valorMaximo;
        multiplicacion *= valorMaximo;

        if (multiplicacion > 500) {
            multiplicacion = 10;
        } else {
            multiplicacion = multiplicacion - 10;
        }
    }

    resultado_suma = suma;
    resultado_multiplicacion = multiplicacion;
    ret resultado_suma;
}

func void main(){
    lista[0] = 100;
    lista[1] = 2;
    lista[2] = 3;
    lista[3] = 4;
    lista[4] = 5;

    sumeMayores();
}