func void multiplicacion_matrices(int[][] A, int[][] B, int[][] C,
    int filas, int columnas, int comun) {

    int total_operaciones = 0;

    for (int i = 0; i += 1; i < filas) {

        int temporal_externo = i * 100;

        for (int j = 0; j += 1; j < columnas) {

            int basura1 = i + j;

            int suma = 0;

            for (int k = 0; k += 1; k < comun) {

                int basura2 = k * 50;

                suma += A[i][k] * B[k][j];

                total_operaciones += 1;
            }

            C[i][j] = suma;

            int basura3 = suma * 999;
        }
    }

    int estadistica = total_operaciones;
    int desperdicio = estadistica * 2;

    ret;
}


func void main() {
    int filas = 2;
    int columnas = 2;
    int comun = 2;

    int A[2][2];
    A[0][0] = 1;
    A[0][1] = 2;
    A[1][0] = 3;
    A[1][1] = 4;

    int B[2][2];
    B[0][0] = 5;
    B[0][1] = 6;
    B[1][0] = 7;
    B[1][1] = 8;

    int C[2][2];

    multiplicacion_matrices(A, B, C, filas, columnas, comun);
}