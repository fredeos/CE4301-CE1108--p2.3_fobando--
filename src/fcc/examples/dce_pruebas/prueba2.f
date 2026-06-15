func int sumarUno(int a){
    int r = a + 1;

    int basura = r * 100;
    basura += 50;

    ret r;
}

func int duplicar(int b){
    int r = b * 2;

    int muerto = 7;
    muerto += r;

    ret r;
}

func int main(){
    int x = 3;
    int y = 4;

    int a = sumarUno(x);

    int muerto1 = a + y;
    muerto1 *= 10;

    int b = duplicar(y);

    int muerto2 = b + 100;
    muerto2 -= 1;

    ret x;
}