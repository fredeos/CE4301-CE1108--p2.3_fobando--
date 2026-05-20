int suma = 0;
int resultado;
int lista[10];

func bool es_primo(int n){
    int divisor = 2;

    if (n <= 1) {
        ret false;
    }

    while ((divisor * divisor) <= n) {
        if ((n % divisor) == 0) {
            ret false;
        }

        divisor += 1;
    }

    ret true;
}

func int sume(){
    int i = 0;
    int reserva1;
    int reserva2;
    int valor = 0;

    while (i < 10) {
        valor = lista[i];

        if (es_primo(valor)) {
            suma += valor;
        }

        i += 1;
    }

    resultado = suma;
    ret resultado;
}

func void main(){
    lista[0] = 1;
    lista[1] = 2;
    lista[2] = 3;
    lista[3] = 4;
    lista[4] = 5;
    lista[5] = 6;
    lista[6] = 7;
    lista[7] = 8;
    lista[8] = 9;
    lista[9] = 11;

    sume();
}
