# Programa propuesto: calculo de la serie de Fibonacci.
# Genera F(0)..F(10) en memoria y guarda F(10) como resultado final.

int fibonacci_series[11];
int fibonacci_result;

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
    fibonacci_result = anterior;

    if (limite >= 1) {
        fibonacci_series[1] = actual;
        fibonacci_result = actual;
    }

    while (i <= limite) {
        siguiente = anterior + actual;
        fibonacci_series[i] = siguiente;

        anterior = actual;
        actual = siguiente;
        fibonacci_result = siguiente;
        i += 1;
    }

    ret fibonacci_result;
}

func int fibonacci(int n){
    int resultado = fibonacci_aux(n);
    ret resultado;
}

func void main(){
    fibonacci(10);
}
