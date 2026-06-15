func int ajustar(int n){
    int a = 2;
    int b = 3;
    int c = a + b;

    ret n + c;
}

func int main(){
    int x = 8;
    int y = 4;
    int z = x + y;

    if (z > 10) {
        int p = 1;
        int q = 2;
        int r = p + q;

        int v = ajustar(r);

        ret v;
    } else {
        int a = 5;
        int b = 6;
        int c = a * b;

        int w = ajustar(c);

        ret w;
    }
}