# Programa propuesto: calculo de la serie de Fibonacci.
# Genera F(0)..F(10) en memoria y retorna F(10) como resultado final.

int fibonacci_series[11];

func int fibonacci_aux(int limite){
    int anterior = 0;
    int actual = 1;
    int siguiente = 0;
    int i = 2;

    if (limite < 0) {
        limite = 0;
    }

    if (limite > 10) {
        limite = 10;
    }

    fibonacci_series[0] = anterior;
    int resultado = anterior;

    if (limite >= 1) {
        fibonacci_series[1] = actual;
        resultado = actual;
    }

    while (i <= limite) {
        siguiente = anterior + actual;
        fibonacci_series[i] = siguiente;

        anterior = actual;
        actual = siguiente;
        resultado = siguiente;
        i += 1;
    }

    ret resultado;
}

func int fibonacci(int n){
    int resultado = fibonacci_aux(n);
    ret resultado;
}

func int main(){
    ret fibonacci(10);
}
