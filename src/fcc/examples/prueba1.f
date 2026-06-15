int global_result;

func int llenar(int[] datos){
    datos[0] = 10;
    datos[1] = 20;
    datos[2] = 30;
    datos[3] = 40;
    ret 0;
}

func int sumar4(int[] datos){
    int total = 0;
    total = datos[0] + datos[1];
    total += datos[2];
    total += datos[3];
    ret total;
}

func int usar_chars(char[] texto){
    texto[0] = 'A';
    texto[1] = 'B';
    int total = texto[0] + texto[1];
    total += texto[2];
    total += texto[3];
    ret total;
}

func int usar_vault(vault[4] caja){
    int x = caja[0] + 2;
    caja[1] = x * 3;
    int y = caja[1] + x;
    ret y;
}

func int combinar_regs(int a, int b){
    int z = a + b;
    z = z - a;
    z = z * b;
    z = z / b;
    z = z % a;
    z = z & b;
    z = z | a;
    z = z ^ b;
    z = z << a;
    z = z >> b;
    ret z;
}

func int ops_inmediatas(int x){
    x = x + 1;
    x = x - 2;
    x = x * 3;
    x = x / 2;
    x = x % 5;
    x = x & 7;
    x = x | 8;
    x = x ^ 1;
    x = x << 1;
    x = x >> 1;
    ret x;
}

func int comparaciones(int a, int b){
    bool eq_ab = a == b;
    bool eq_5 = a == 5;
    bool distinto = b != 0;
    bool negado = !eq_5;
    int x = a;

    if (a == b) {
        x = x + 1;
    }
    if (a != b) {
        x = x + 2;
    }
    if (a < b) {
        x = x + 3;
    }
    if (a > b) {
        x = x + 4;
    }
    if (a <= b) {
        x = x + 5;
    }
    if (a >= b) {
        x = x + 6;
    }
    if (eq_ab) {
        x = x + 7;
    }
    if (distinto) {
        x = x + 8;
    }
    if (negado) {
        x = x + 9;
    }

    ret x;
}

@secure(0x21)
func int mezclar(int a, int b, int c){
    int x = (a ^ b) ^ c;
    ret x;
}

@secure(0x22)
func int segura_regs(int a, int b){
    int z = a + b;
    z = z - a;
    z = z * b;
    z = z / b;
    z = z % a;
    z = z & b;
    z = z | a;
    z = z ^ b;
    ret z;
}

@secure(0x23)
func int segura_inmediatas(int x){
    int base = 5;
    x = x + base;
    x = x + 1;
    x = x - 2;
    x = x * 3;
    x = x / 2;
    x = x % 5;
    x = x & 7;
    x = x | 8;
    x = x ^ 1;
    ret x;
}

@secure(0x24)
func int suma_segura3(int a, int b, int c){
    int z = (a + b) + c;
    ret z;
}

@secure(0x25)
func int desplaza_seguro(int a, int b, int c){
    int x = (a << b) + c;
    int y = (x >> b) + c;
    ret y;
}

@secure(0x26)
func int comparar_seguro(int a, int b){
    bool eqv = a == b;
    bool eqi = a == 7;
    int x = a + b;

    if (eqv) {
        x = x + 1;
    }
    if (eqi) {
        x = x + 2;
    }

    ret x;
}
