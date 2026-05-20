import os
import sys
import argparse

def generate_zeros(size_kb, filename):
    # 1. Obtener la ruta del directorio donde está este script (data_utilities)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 2. Ruta hacia la carpeta 'memories' (un nivel arriba)
    target_dir = os.path.normpath(os.path.join(current_dir, "..", "memories"))
    
    # 3. Crear la carpeta 'memories' si no existe
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)
        print(f"Directorio creado: {target_dir}")

    # 4. Definir la ruta completa del archivo de salida
    output_path = os.path.join(target_dir, filename)

    # 5. Calcular palabras (32 bits / 4 bytes)
    num_words = (size_kb * 1024) // 4
    
    print(f"Generando archivo en: {output_path}")
    
    try:
        with open(output_path, 'w') as f:
            for _ in range(num_words):
                f.write("00000000\n")
        print(f"Éxito: {num_words} palabras de ceros escritas.")
        print(f"Tamaño final: {size_kb} KB.")
    except Exception as e:
        print(f"Error al escribir el archivo: {e}")

if __name__ == "__main__":
    # Usamos argparse para que sea más profesional y fácil de usar
    parser = argparse.ArgumentParser(description='Generador de archivos .hex de ceros para memorias Verilog.')
    parser.add_argument('kb', type=int, help='Tamaño de la memoria en KB')
    parser.add_argument('filename', type=str, nargs='?', default='data_init.hex', 
                        help='Nombre del archivo de salida (por defecto: data_init.hex)')

    args = parser.parse_args()
    generate_zeros(args.kb, args.filename)


"""
python gen_file.py 64 data_mem.hex
python gen_file.py 32 instr_mem.hex
python gen_file.py 16 vault_mem.hex
"""