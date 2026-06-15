# Descifrado completo in-place usando TEA.
#
# Este archivo documenta la intencion de alto nivel del ASM generado por
# gen_tea_unrolled.py. El archivo cifrado debe estar cargado en la misma
# direccion base usada para cifrar.

int base_address;       # Direccion byte inicial donde se cargo el archivo cifrado.
int block_count;        # ceil(file_size / 8).
vault[4] key;           # key[0..3] desde la boveda segura.

@secure(0xA9C1F)
func void tea_decrypt_file(){
    int offset = base_address;

    for (int block = 0; block += 1; block < block_count) {
        int v0 = data_mem[offset + 0];
        int v1 = data_mem[offset + 4];
        int sum = delta << 5;    # delta * 32.

        for (int round = 0; round += 1; round < 32) {
            v1 -= ((v0 << 4) + key[2]) ^ (v0 + sum) ^ ((v0 >> 5) + key[3]);
            v0 -= ((v1 << 4) + key[0]) ^ (v1 + sum) ^ ((v1 >> 5) + key[1]);
            sum -= delta;
        }

        data_mem[offset + 0] = v0;
        data_mem[offset + 4] = v1;
        offset += 8;
    }
}

func void main(){
    tea_decrypt_file();
}
