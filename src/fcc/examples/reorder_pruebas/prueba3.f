func int f1(int x){
    int a = 7;
    int b = 8;
    int c = a + b;

    ret x + c;
}

func int f2(int y){
    int m = 2;
    int n = 4;
    int r = m * n;

    ret y - r;
}

func int main(){
    int a = 6;
    int b = 3;
    int c = a * b;

    int primero = f1(c);

    if (primero > 20) {
        int x = 1;
        int y = 9;
        int z = x + y;

        int segundo = f2(z);

        ret segundo;
    } else {
        int p = 4;
        int q = 5;
        int r = p + q;

        int tercero = f1(r);

        ret tercero;
    }
}