# python fcc.py examples/dce_pruebas/prueba2.f --optimized-ir -O3
func int transformar(int v){
    int r = v * 3;

    int muerto_local = r + 20;
    muerto_local *= 2;

    ret r;
}

func int main(){
    int i = 0;
    int total = 0;

    int muerto_inicio = 50;
    muerto_inicio += 10;

    while (i < 4) {
        int temp = transformar(i);

        int muerto_loop = temp + 100;
        muerto_loop *= i;

        total = total + i;
        i += 1;
    }

    int muerto_final = total * 999;
    muerto_final += 1;

    ret total;
}