int respuesta;

func int main(){
    int n = 16;
    int k = 2;
    int x[16];
    int y[16];
    int acumulado;

    x[0] = 20;
    x[1] = 18;
    x[2] = 22;
    x[3] = 25;
    x[4] = 27;
    x[5] = 24;
    x[6] = 30;
    x[7] = 32;
    x[8] = 29;
    x[9] = 31;
    x[10] = 35;
    x[11] = 33;
    x[12] = 37;
    x[13] = 40;
    x[14] = 38;
    x[15] = 42;

    y[0] = x[0];
    y[1] = x[1];

    # y[n] - y[n-2]/2 = x[n]
    while (k < n) {
        y[k] = x[k] + (y[k - 2] / 2);
        k += 1;
    }

    acumulado = y[0] + y[1] + y[2] + y[3] + y[4] + y[5] + y[6] + y[7] + y[8] + y[9] + y[10] + y[11] + y[12] + y[13] + y[14] + y[15];
    respuesta = acumulado;
    ret respuesta;
}
