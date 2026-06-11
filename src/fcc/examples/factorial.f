func int factorial(int a){
    int resultado = 1;
    int i = 1;
    int m = 15;
    m += 16;

    while (i <= a) {
        resultado = resultado * i;
        #m = 12; # aqui si se aplica dce
        # m += 12; aqui no se aplica
        i += 1;
    }
    ret resultado;
}


func int main(){
    ret factorial(8);
}
