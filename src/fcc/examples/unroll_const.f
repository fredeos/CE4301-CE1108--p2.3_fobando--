int resultado_constante;

func int main(){
    int k = 0;
    int a[8];
    int b[8];
    int c[8];

    a[0] = 2;
    a[1] = 4;
    a[2] = 6;
    a[3] = 8;
    a[4] = 10;
    a[5] = 12;
    a[6] = 14;
    a[7] = 16;

    b[0] = 1;
    b[1] = 3;
    b[2] = 5;
    b[3] = 7;
    b[4] = 9;
    b[5] = 11;
    b[6] = 13;
    b[7] = 15;

    # N constante sin dependencia entre iteraciones: c[k] = a[k] + b[k]
    while (k < 8) {
        c[k] = a[k] + b[k];
        k += 1;
    }

    resultado_constante = c[0] + c[1] + c[2] + c[3] + c[4] + c[5] + c[6] + c[7];
    ret resultado_constante;
}
