int global_result;
func int factorial(int a){
    int resultado = 1;
    int i = 1;

    while (i <= a) {
        resultado = resultado * i;
        i += 1;
    }
    global_result = resultado;
    ret resultado;
}

func void main(){
    factorial(8);
}
