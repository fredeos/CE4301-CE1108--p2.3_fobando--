func int transformar(int n){
    int base = 3;
    int extra = 2;
    int suma = base + extra;

    ret n * suma;
}

func int main(){
    int i = 0;
    int total = 0;
    int limite = 5;

    while (i < limite) {
        int a = 10;
        int b = 20;
        int c = a + b;

        int t = transformar(i);

        if (t > c) {
            int x = 1;
            int y = 2;
            int z = x + y;

            total = total + z;
        } else {
            int m = 4;
            int n = 5;
            int k = m * n;

            total = total + k;
        }

        i += 1;
    }

    ret total;
}