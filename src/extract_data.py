import argparse
import math
import os

def get_input_path(filename):
    direct_path = os.path.normpath(filename)
    if os.path.exists(direct_path):
        return direct_path

    current_dir = os.path.dirname(os.path.abspath(__file__))
    # Ajustamos para buscar en la carpeta de salida o memorias según tu flujo
    return os.path.normpath(os.path.join(current_dir, "..", filename))

def main():
    parser = argparse.ArgumentParser(description='Extrae datos de memoria a binario')
    parser.add_argument('--memory', required=True, help='Archivo de volcado (.hex/.txt)')
    parser.add_argument('--address', required=True, help='Dirección inicial en hex')
    parser.add_argument('--size', type=int, required=True, help='Tamaño en bytes a extraer')
    parser.add_argument('--output', required=True, help='Nombre del archivo de salida')

    args = parser.parse_args()
    
    # Intenta buscar en output primero (donde Verilog guarda el modificado)
    mem_path = get_input_path(args.memory)
    start_addr = int(args.address, 16)
    if start_addr % 4 != 0:
        raise SystemExit("Error: la dirección inicial debe estar alineada a 4 bytes.")
    word_start = start_addr // 4
    num_words = (args.size + 3) // 4 
    tea_blocks = math.ceil(args.size / 8)
    padded_size = tea_blocks * 8

    if not os.path.exists(mem_path):
        print(f"Error: No se encuentra el archivo en {mem_path}")
        return

    extracted_bytes = bytearray()
    
    with open(mem_path, 'r') as f:
        # CORRECCIÓN AQUÍ: 
        # 1. Filtramos líneas vacías, las que empiezan con '@' y las que empiezan con '//'
        lines = []
        for l in f:
            clean_l = l.strip()
            # Saltamos comentarios puros o líneas de dirección
            if not clean_l or clean_l.startswith('@') or clean_l.startswith('//'):
                continue
            
            # 2. Si la línea tiene datos pero un comentario al final, lo cortamos
            data_part = clean_l.split('//')[0].strip()
            if data_part:
                lines.append(data_part)
        
        # Extraer el segmento solicitado
        target_words = lines[word_start : word_start + num_words]
        
        for hex_word in target_words:
            try:
                val = int(hex_word, 16)
                # Descomponer de 32-bit word a bytes (Little Endian)
                extracted_bytes.append(val & 0xFF)
                extracted_bytes.append((val >> 8) & 0xFF)
                extracted_bytes.append((val >> 16) & 0xFF)
                extracted_bytes.append((val >> 24) & 0xFF)
            except ValueError:
                print(f"Advertencia: Saltando valor no hexadecimal: {hex_word}")
                continue

    # Guardar el archivo final (PNG/BIN)
    with open(args.output, 'wb') as f:
        f.write(extracted_bytes[:args.size])
    
    print(f"--- Extracción Completada ---")
    print(f"Archivo procesado: {mem_path}")
    print(f"Dirección inicial: {hex(start_addr)}")
    print(f"Rango extraído: {hex(start_addr)} -> {hex(start_addr + args.size - 1)}")
    print(f"Bloques TEA esperados: {tea_blocks}")
    print(f"Rango TEA con padding: {hex(start_addr)} -> {hex(start_addr + padded_size - 1)}")
    print(f"Bytes extraídos: {len(extracted_bytes[:args.size])}")
    print(f"Archivo de salida: {args.output}")

if __name__ == "__main__":
    main()


r"""
cd src\data_utilities
python extract_data.py --memory ../output/bedrock_mod.hex --address 0x0 --size 247 --output ../test_files/bedrock_recuperada.png
cd ../
"""
