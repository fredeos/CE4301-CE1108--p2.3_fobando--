import argparse
import math
import mimetypes
import os
import re


def resolve_output_path(filename):
    path = os.path.normpath(filename)
    if os.path.isabs(path) or path == "src" or path.startswith(f"src{os.sep}"):
        return path

    current_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(current_dir, path)


def parse_hex_words(raw_content):
    words = []
    text_content = raw_content.decode("utf-8")

    for line in text_content.splitlines():
        clean = line.split("//")[0]
        clean = re.sub(r"@\S*", "", clean).strip()
        if not clean:
            continue

        for hex_word in re.findall(r"[0-9a-fA-F]+", clean):
            words.append(int(hex_word, 16))

    return words


def parse_memory_dump_words(raw_content):
    words = []
    text_content = raw_content.decode("utf-8")

    for line in text_content.splitlines():
        clean = line.split("//")[0].strip()
        if not clean or clean.startswith("@"):
            continue

        token = clean.split()[0]
        if re.fullmatch(r"[xXzZ]+", token):
            words.append(0)
        elif re.fullmatch(r"[0-9a-fA-F]+", token):
            words.append(int(token, 16))

    return words


def is_memory_dump(raw_content):
    try:
        text_content = raw_content.decode("utf-8")
    except UnicodeDecodeError:
        return False

    return any(re.match(r"\s*//\s*0x[0-9a-fA-F]+", line) for line in text_content.splitlines())


def parse_binary_words(raw_content):
    words = []
    for index in range(0, len(raw_content), 4):
        chunk = raw_content[index:index + 4]
        if len(chunk) < 4:
            chunk = chunk + b"\x00" * (4 - len(chunk))

        word = (chunk[3] << 24) | (chunk[2] << 16) | (chunk[1] << 8) | chunk[0]
        words.append(word)

    return words


def main():
    parser = argparse.ArgumentParser(description="Carga archivos a memoria Verilog")
    parser.add_argument("--input", required=True, help="Archivo de entrada")
    parser.add_argument("--output", required=True, help="Archivo .hex de salida")
    parser.add_argument("--address", required=True, help="Direccion inicial hex")
    parser.add_argument(
        "--format",
        choices=["auto", "binary", "hex"],
        default="auto",
        help="Formato de carga. auto interpreta .hex/.mem como texto hexadecimal.",
    )
    parser.add_argument(
        "--tea-config",
        action="store_true",
        help="Escribe data_mem[0]=ADDRESS y data_mem[4]=ceil(size/8) antes del archivo.",
    )

    args = parser.parse_args()
    start_addr = int(args.address, 16)
    if start_addr % 4 != 0:
        raise SystemExit("Error: la direccion inicial debe estar alineada a 4 bytes.")
    word_addr = start_addr // 4

    if not os.path.exists(args.input):
        raise SystemExit(f"Error: {args.input} no existe.")

    with open(args.input, "rb") as handle:
        raw_content = handle.read()

    input_ext = os.path.splitext(args.input)[1].lower()
    detected_type = mimetypes.guess_type(args.input)[0] or "application/octet-stream"
    preserve_memory_dump = args.format == "auto" and is_memory_dump(raw_content)

    use_hex_mode = preserve_memory_dump or args.format == "hex" or (
        args.format == "auto" and input_ext in {".hex", ".mem"}
    )

    if use_hex_mode:
        mode = "VOLCADO COMPLETO DE MEMORIA" if preserve_memory_dump else "TEXTO HEXADECIMAL"
        words = parse_memory_dump_words(raw_content) if preserve_memory_dump else parse_hex_words(raw_content)
        loaded_size = len(words) * 4
    else:
        mode = "BINARIO PURO"
        words = parse_binary_words(raw_content)
        loaded_size = len(raw_content)

    if not words:
        raise SystemExit("Error: no se encontraron datos para cargar.")

    output_path = resolve_output_path(args.output)
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    tea_blocks = math.ceil(loaded_size / 8)
    tea_padded_size = tea_blocks * 8

    with open(output_path, "w", encoding="utf-8") as handle:
        if not preserve_memory_dump:
            if args.tea_config:
                if start_addr < 8:
                    raise SystemExit("Error: --tea-config requiere cargar el archivo desde 0x8 o superior.")
                handle.write("@00000000\n")
                handle.write(f"{start_addr & 0xFFFFFFFF:08x}\n")
                handle.write(f"{tea_blocks & 0xFFFFFFFF:08x}\n")
            handle.write(f"@{word_addr:08x}\n")
        for word in words:
            handle.write(f"{word & 0xFFFFFFFF:08x}\n")

    print("--- Cargando Archivo ---")
    print(f"Modo: {mode}")
    print(f"Origen: {args.input}")
    print(f"Tipo detectado: {detected_type}")
    print(f"Tamano fuente: {len(raw_content)} bytes")
    print(f"Tamano cargado: {loaded_size} bytes")
    print(f"SIZE para extraccion: {loaded_size}")
    print(f"Destino: {output_path}")
    print(f"Direccion inicial: {hex(start_addr)}")
    if preserve_memory_dump:
        print("Direccion aplicada: preservada desde el volcado de memoria")
        print("Nota: ADDRESS se ignora para no desplazar data_mem_exit.hex.")
        print(f"Rango del volcado: 0x0 -> {hex(loaded_size - 1)}")
    else:
        if args.tea_config:
            print("Configuracion TEA escrita:")
            print(f"  data_mem[0x0] = {hex(start_addr)}")
            print(f"  data_mem[0x4] = {tea_blocks}")
        print(f"Rango usado: {hex(start_addr)} -> {hex(start_addr + loaded_size - 1)}")
    print(f"Palabras de 32 bits escritas: {len(words)}")
    print(f"Bloques TEA de 64 bits: {tea_blocks}")
    if preserve_memory_dump:
        print(f"Rango TEA con padding: preservado en el volcado completo")
    else:
        print(f"Rango TEA con padding: {hex(start_addr)} -> {hex(start_addr + tea_padded_size - 1)}")
    print(f"Padding final para TEA: {tea_padded_size - loaded_size} bytes")
    print("Carga completada exitosamente.")


if __name__ == "__main__":
    main()


"""
python src/load_file.py --input input/prueba1.hex --output src/instrmem/instr_mem.hex --address 0x0
python src/load_file.py --input input/bedrock.png --output ./datamem/data_mem.hex --address 0x0
"""
