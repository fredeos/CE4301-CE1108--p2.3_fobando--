int resultado_variable_pequena;

func int main(){
    int n = 6;
    int x[8];
    int y[8];
    int acumulado = 0;

    x[0] = 5;
    x[1] = 7;
    x[2] = 9;
    x[3] = 11;
    x[4] = 13;
    x[5] = 15;
    x[6] = 17;
    x[7] = 19;

    y[0] = x[0];
    y[1] = x[1];
    acumulado = y[0] + y[1];

    # N variable pequena: y[k] = x[k] + y[k-1] - y[k-2]/2
    for (int k = 2; k += 1; k < n) {
        y[k] = x[k] + y[k - 1] - (y[k - 2] / 2);
        acumulado += y[k];
    }

    resultado_variable_pequena = acumulado;
    ret resultado_variable_pequena;
}
