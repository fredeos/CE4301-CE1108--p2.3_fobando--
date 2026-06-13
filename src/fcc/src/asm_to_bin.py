"""Codificacion de ensamblador FCC/F32IS a instrucciones binarias."""

from __future__ import annotations

from dataclasses import dataclass
import struct
from typing import Optional, Iterable

from ast_nodes import BinaryOpNode, LiteralNode, ProgramNode, UnaryOpNode, VarDeclNode
from clases import SECURE_PRIMARY, SECURE_SECONDARY
from symbol_table import DATA_BASE, MEMORY_SIZE, SymbolTable, TypeInfo


HEADER_MAGIC = b"FCCB"
HEADER_VERSION = 1
HEADER_SIZE = 32


@dataclass
class BinaryHeader:
    """Encabezado simple para el archivo binario final."""

    entry_point: int
    code_size: int
    data_size: int
    code_base: int = 0
    data_base: int = 0
    memory_size: int = MEMORY_SIZE
    version: int = HEADER_VERSION

    def pack(self) -> bytes:
        """Empaqueta el encabezado en formato binario little-endian."""

        return struct.pack(
            "<4sHHIIIIII",
            HEADER_MAGIC,
            self.version,
            HEADER_SIZE,
            self.entry_point,
            self.code_size,
            self.data_size,
            self.code_base,
            self.data_base,
            self.memory_size,
        )


@dataclass
class Instruction:
    """Representa una instruccion F32IS lista para codificarse."""

    op: str
    rd: Optional[int | str] = None
    rn: Optional[int | str] = None
    rm: Optional[int | str] = None
    sf: Optional[int | str] = None
    imm: Optional[int] = None
    op1: Optional[str] = None
    op2: Optional[str] = None
    is_secure: bool = False
    s_flag: bool = False
    use_sub: bool = False

    def _validate_isa_constraints(self):
        """Aplica restricciones estructurales del ISA antes de codificar."""

        secure_native_ops = {
            "login",
            "quit",
            "send",
            "recv",
            "ldvw",
            "ldvh",
            "ldvb",
            "stvw",
            "stvh",
            "stvb",
            "padd",
            "psub",
            "pmul",
            "pdiv",
            "pmod",
            "pand",
            "porr",
            "pxor",
            "pseq",
            "pmov",
            "paddadd",
            "pxorxor",
            "pslladd",
            "psrladd",
            "paddi",
            "psubi",
            "pmuli",
            "pdivi",
            "pmodi",
            "pandi",
            "porri",
            "pxori",
            "pseqi",
            "pmovi",
            "pla",
            "pli",
        }
        if self.is_secure and self.op in secure_native_ops:
            raise ValueError(f'la instruccion "{self.op}" no debe usar prefijo "@" porque ya pertenece al hardware seguro')

        secure_dest_ops = {
            "send",
            "ldvw",
            "ldvh",
            "ldvb",
            "padd",
            "psub",
            "pmul",
            "pdiv",
            "pmod",
            "pand",
            "porr",
            "pxor",
            "pseq",
            "pmov",
            "paddadd",
            "pxorxor",
            "pslladd",
            "psrladd",
            "paddi",
            "psubi",
            "pmuli",
            "pdivi",
            "pmodi",
            "pandi",
            "porri",
            "pxori",
            "pseqi",
            "pmovi",
            "pla",
            "pli",
        }
        if self.op in secure_dest_ops and self.rd == 0:
            raise ValueError(f'la instruccion "{self.op}" no puede escribir en "ax" porque es de solo lectura')

    def _lower_pseudo(self):
        """Convierte pseudo-instrucciones a su forma real de la ISA."""

        op_clean = self.op.lstrip("@")
        secure_prefix = self.op.startswith("@")

        if op_clean == "call":
            self.op = "jal"
            self.rd = "ra"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean == "jmp":
            self.op = "jal"
            self.rd = "zero"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean == "beqz":
            self.op = "beq"
            self.rm = "zero"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean == "ret":
            self.op = "mov"
            self.rd = "pc"
            self.rn = "ra"
            self.rm = None
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean == "nop":
            self.op = "add"
            self.rd = "zero"
            self.rn = "zero"
            self.rm = "zero"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean == "end":
            self.op = "end"
            self.rd = "zero"
            self.rn = "zero"
            self.rm = "zero"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean == "seqz":
            self.op = "seq"
            self.rm = "zero"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean in {"li", "la"}:
            self.op = "movi"
            self.rn = "zero"
            self.is_secure = self.is_secure or secure_prefix
            return

        if op_clean in {"pli", "pla"}:
            self.op = "pmovi"
            self.rn = "zero"
            self.is_secure = True
            return

    def _normalize_secure_metadata(self):
        """Deriva metadatos faltantes para instrucciones seguras."""

        op_clean = self.op.lstrip("@")
        if self.op1 is None:
            self.op1 = SECURE_PRIMARY.get(op_clean)
        if self.op2 is None:
            self.op2 = SECURE_SECONDARY.get(op_clean)

    def _resolve_regs(self):
        """Convierte alias de registros a indices fisicos."""

        self._normalize_secure_metadata()

        primarias = ["sll", "srl", "add", "sub", "mul", "div", "mod", "and", "orr", "xor", "seq", "mov"]
        secundarias = ["add", "xor"]
        combos_pr = [f"p{primary}{secondary}" for primary in primarias for secondary in secundarias]

        secure_ops = set(
            combos_pr
            + [
                "padd",
                "psub",
                "pmul",
                "pdiv",
                "pmod",
                "pand",
                "porr",
                "pxor",
                "pseq",
                "pmov",
                "paddi",
                "psubi",
                "pmuli",
                "pdivi",
                "pmodi",
                "pandi",
                "porri",
                "pxori",
                "pseqi",
                "pmovi",
                "send",
                "recv",
                "ldvw",
                "ldvh",
                "ldvb",
                "stvw",
                "stvh",
                "stvb",
                "pla",
                "pli",
            ]
        )

        op_clean = self.op.lstrip("@")
        is_secure_instr = op_clean in secure_ops

        if self.rd is not None and isinstance(self.rd, str):
            secure_field = is_secure_instr and op_clean != "recv"
            self.rd = F32IS_Encoder.get_reg_addr(self.rd, secure_field)

        if self.rn is not None and isinstance(self.rn, str):
            secure_field = is_secure_instr and op_clean != "send"
            self.rn = F32IS_Encoder.get_reg_addr(self.rn, secure_field)

        if self.rm is not None and isinstance(self.rm, str):
            self.rm = F32IS_Encoder.get_reg_addr(self.rm, is_secure_instr)

        if self.sf is not None and isinstance(self.sf, str):
            self.sf = F32IS_Encoder.get_reg_addr(self.sf, is_secure_instr)

    def encode(self) -> str:
        """Codifica la instruccion a una palabra binaria de 32 bits."""

        if self.op.startswith("@"):
            self.is_secure = True
            self.op = self.op[1:]

        self._lower_pseudo()

        self._resolve_regs()
        self._validate_isa_constraints()

        tipo_r = {"add", "sub", "mul", "div", "mod", "and", "orr", "xor", "sll", "srl", "mov", "seq", "ret", "nop", "seqz", "end"}
        tipo_i = {"addi", "subi", "muli", "divi", "modi", "andi", "orri", "xori", "slli", "srli", "movi", "seqi", "li", "la"}
        tipo_m = {"ldw", "ldh", "ldb", "stw", "sth", "stb"}
        tipo_b = {"beq", "bne", "bgt", "blt", "bge", "ble", "beqz"}
        tipo_j = {"jal", "jmp"}
        tipo_f = {"call"}
        tipo_pr = {"padd", "psub", "pmul", "pdiv", "pmod", "pand", "porr", "pxor", "pseq", "pmov", "paddadd", "pxorxor", "pslladd", "psrladd"}
        tipo_pi = {"paddi", "psubi", "pmuli", "pdivi", "pmodi", "pandi", "porri", "pxori", "pseqi", "pmovi", "pla", "pli"}
        tipo_v = {"ldvw", "ldvh", "ldvb", "stvw", "stvh", "stvb"}
        tipo_t = {"send", "recv"}
        tipo_s = {"login", "quit"}

        if self.op in tipo_r:
            return F32IS_Encoder.encode_r(self)
        if self.op in tipo_i:
            return F32IS_Encoder.encode_i(self)
        if self.op in tipo_m:
            return F32IS_Encoder.encode_m(self)
        if self.op in tipo_b:
            return F32IS_Encoder.encode_b(self)
        if self.op in tipo_j:
            return F32IS_Encoder.encode_j(self)
        if self.op in tipo_f:
            return F32IS_Encoder.encode_f(self)
        if self.op in tipo_pr:
            return F32IS_Encoder.encode_pr(self)
        if self.op in tipo_pi:
            return F32IS_Encoder.encode_pi(self)
        if self.op in tipo_v:
            return F32IS_Encoder.encode_v(self)
        if self.op in tipo_t:
            return F32IS_Encoder.encode_t(self)
        if self.op in tipo_s:
            return F32IS_Encoder.encode_s(self)
        raise ValueError(f"Instruccion no soportada para binarizacion: {self.op}")


class F32IS_Encoder:
    """Constantes y rutinas de codificacion para la ISA F32IS."""

    OPCODES = {
        "add": 0b00000,
        "sub": 0b00000,
        "mul": 0b00000,
        "div": 0b00000,
        "mod": 0b00000,
        "and": 0b00000,
        "orr": 0b00000,
        "xor": 0b00000,
        "sll": 0b00000,
        "srl": 0b00000,
        "mov": 0b00000,
        "seq": 0b00000,
        "seqz": 0b00000,
        "addi": 0b00001,
        "subi": 0b00001,
        "muli": 0b00001,
        "divi": 0b00001,
        "modi": 0b00001,
        "andi": 0b00001,
        "orri": 0b00001,
        "xori": 0b00001,
        "slli": 0b00001,
        "srli": 0b00001,
        "movi": 0b00001,
        "seqi": 0b00001,
        "li": 0b00001,
        "la": 0b00001,
        "ldw": 0b00100,
        "ldh": 0b00100,
        "ldb": 0b00100,
        "stw": 0b00101,
        "sth": 0b00101,
        "stb": 0b00101,
        "ldvw": 0b00110,
        "ldvh": 0b00110,
        "ldvb": 0b00110,
        "stvw": 0b00111,
        "stvh": 0b00111,
        "stvb": 0b00111,
        "beq": 0b01000,
        "bne": 0b01000,
        "bgt": 0b01000,
        "blt": 0b01000,
        "bge": 0b01000,
        "ble": 0b01000,
        "beqz": 0b01000,
        "jal": 0b01001,
        "jmp": 0b01001,
        "call": 0b01001,
        "send": 0b10000,
        "recv": 0b10000,
        "login": 0b10001,
        "quit": 0b10001,
        "nop": 0b00000,
        "end": 0b00000,
        "ret": 0b00000,
    }

    FUNC4_ALU = {
        "sll": 0b0000,
        "slli": 0b0000,
        "srl": 0b0001,
        "srli": 0b0001,
        "add": 0b0010,
        "addi": 0b0010,
        "movi": 0b0010,
        "li": 0b0010,
        "la": 0b0010,
        "mov": 0b0010,
        "ret": 0b0010,
        "nop": 0b0010,
        "end": 0b0010,
        "sub": 0b0011,
        "subi": 0b0011,
        "mul": 0b0100,
        "muli": 0b0100,
        "div": 0b0101,
        "divi": 0b0101,
        "mod": 0b0110,
        "modi": 0b0110,
        "and": 0b0111,
        "andi": 0b0111,
        "orr": 0b1000,
        "orri": 0b1000,
        "xor": 0b1001,
        "xori": 0b1001,
        "seq": 0b1010,
        "seqi": 0b1010,
        "seqz": 0b1010,
    }

    FUNC3_SECURE = {"add": 0b000, "xor": 0b001}

    GPR_MAP = {
        "zero": 0,
        "ra": 1,
        "sp": 2,
        "pc": 3,
        "lr": 4,
        "p0": 5,
        "p1": 6,
        "p2": 7,
        "p3": 8,
        "p4": 9,
        "p5": 10,
        "p6": 11,
        "p7": 12,
        "p8": 13,
        "r0": 14,
        "r1": 15,
        "r2": 16,
        "r3": 17,
        "r4": 18,
        "r5": 19,
        "r6": 20,
        "r7": 21,
        "r8": 22,
        "r9": 23,
        "r10": 24,
        "r11": 25,
        "r12": 26,
        "r13": 27,
        "r14": 28,
        "r15": 29,
        "delta": 30,
        "max": 31,
    }

    SECURE_MAP = {
        "ax": 0,
        "bx": 1,
        "cx": 2,
        "dx": 3,
        "ex": 4,
        "fx": 5,
        "gx": 6,
        "hx": 7,
    }

    @staticmethod
    def get_reg_addr(name: str, is_secure_field: bool = False) -> int:
        """Resuelve el indice fisico de un registro."""

        name = name.lower().strip()
        if is_secure_field:
            if name.startswith("r") and name[1:].isdigit():
                index = int(name[1:])
                if 0 <= index < 7:
                    return index + 1
            if name not in F32IS_Encoder.SECURE_MAP:
                raise ValueError(f"Registro seguro invalido: {name}")
            return F32IS_Encoder.SECURE_MAP[name]
        if name not in F32IS_Encoder.GPR_MAP:
            raise ValueError(f"Registro general invalido: {name}")
        return F32IS_Encoder.GPR_MAP[name]

    @staticmethod
    def encode_r(inst: Instruction) -> str:
        p = "1" if inst.is_secure else "0"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0), "05b")
        op_name = "seq" if inst.op == "seqz" else inst.op
        func4 = format(F32IS_Encoder.FUNC4_ALU.get(op_name, 0), "04b")
        rd = format(inst.rd or 0, "05b")
        rn = format(inst.rn or 0, "05b")
        rm = format(inst.rm or 0, "05b")
        func7 = "0001111" if inst.op == "end" else "0000000"
        return func7 + rm + rn + rd + func4 + opcode + p

    @staticmethod
    def encode_i(inst: Instruction) -> str:
        p = "1" if inst.is_secure else "0"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b00001), "05b")
        func4 = format(F32IS_Encoder.FUNC4_ALU.get(inst.op, 0b0010), "04b")
        rd = format(inst.rd or 0, "05b")
        rn = format(inst.rn or 0, "05b")
        imm12 = format((inst.imm or 0) & 0xFFF, "012b")
        return imm12 + rn + rd + func4 + opcode + p

    @staticmethod
    def encode_m(inst: Instruction) -> str:
        p = "1" if inst.is_secure else "0"
        opcode_val = 0b00100 if inst.op.startswith("ld") else 0b00101
        opcode = format(opcode_val, "05b")
        w = "1" if "w" in inst.op else "0"
        h = "1" if "h" in inst.op else "0"
        b = "1" if "b" in inst.op else "0"
        imm_value = inst.imm or 0
        s_active = getattr(inst, "s_flag", False) or imm_value < 0
        s = "1" if s_active else "0"
        rd = format(inst.rd or 0, "05b")
        rn = format(inst.rn or 0, "05b")
        imm12 = format(abs(imm_value) & 0xFFF, "012b")
        return imm12 + rn + rd + w + h + b + s + opcode + p

    @staticmethod
    def encode_b(inst: Instruction) -> str:
        p = "1" if inst.is_secure else "0"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b01000), "05b")
        conditions = {
            "beq": 0b0001,
            "bne": 0b0010,
            "bgt": 0b0011,
            "blt": 0b0100,
            "bge": 0b0101,
            "ble": 0b0110,
        }
        func4 = format(conditions.get(inst.op, 0), "04b")
        rn = format(inst.rn or 0, "05b")
        rm = format(inst.rm or 0, "05b")
        imm12 = (inst.imm or 0) & 0xFFF
        imm12_low = format(imm12 & 0x1F, "05b")
        imm12_high = format((imm12 >> 5) & 0x7F, "07b")
        # Formato B:
        # [31:25] imm12[11:5] | [24:20] rm | [19:15] rn |
        # [14:10] imm12[4:0] | [9:6] cond | [5:1] opcode | [0] P
        return imm12_high + rm + rn + imm12_low + func4 + opcode + p

    @staticmethod
    def encode_j(inst: Instruction) -> str:
        p = "1" if inst.is_secure else "0"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b01001), "05b")
        rd = format(inst.rd or 0, "05b")
        imm_val = (inst.imm or 0) & 0x1FFFFF
        imm_3_0 = format(imm_val & 0xF, "04b")
        imm_20_4 = format((imm_val >> 4) & 0x1FFFF, "017b")
        return imm_20_4 + rd + imm_3_0 + opcode + p

    @staticmethod
    def encode_f(inst: Instruction) -> str:
        p = "1" if inst.is_secure else "0"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b01001), "05b")
        rd = format(inst.rd if inst.rd is not None else 1, "05b")
        imm_val = (inst.imm or 0) & 0x1FFFFF
        imm_3_0 = format(imm_val & 0xF, "04b")
        imm_20_4 = format((imm_val >> 4) & 0x1FFFF, "017b")
        return imm_20_4 + rd + imm_3_0 + opcode + p

    @staticmethod
    def encode_pr(inst: Instruction) -> str:
        p = "1"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b00010), "05b")
        func4 = format(F32IS_Encoder.FUNC4_ALU.get(inst.op1 or "add", 0b0010), "04b")
        func3 = format(F32IS_Encoder.FUNC3_SECURE.get(inst.op2 or "add", 0b000), "03b")
        sd = format(inst.rd or 0, "03b")
        sn = format(inst.rn or 0, "03b")
        sm = format(inst.rm or 0, "03b")
        sf = format(inst.sf or 0, "03b")
        return "0000000" + func3 + sf + sm + sn + sd + func4 + opcode + p

    @staticmethod
    def encode_pi(inst: Instruction) -> str:
        p = "1"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b00011), "05b")
        func4 = format(F32IS_Encoder.FUNC4_ALU.get(inst.op1 or "add", 0b0010), "04b")
        sd = format(inst.rd or 0, "03b")
        sn = format(inst.rn or 0, "03b")
        imm16 = format((inst.imm or 0) & 0xFFFF, "016b")
        return imm16 + sn + sd + func4 + opcode + p

    @staticmethod
    def encode_t(inst: Instruction) -> str:
        p = "1"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b10000), "05b")
        if inst.op == "send":
            func4 = "0000"
            sd = format(inst.rd or 0, "03b")
            rn = format(inst.rn or 0, "05b")
            return ("0" * 12) + rn + "00" + sd + func4 + opcode + p
        func4 = "0001"
        rd = format(inst.rd or 0, "05b")
        sm = format(inst.rn or 0, "03b")
        return ("0" * 13) + sm + "0" + rd + func4 + opcode + p

    @staticmethod
    def encode_s(inst: Instruction) -> str:
        p = "0"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b10001), "05b")
        func4 = "0000" if inst.op == "login" else "0001"
        imm20 = format((inst.imm or 0) & 0xFFFFF, "020b")
        return imm20 + "00" + func4 + opcode + p

    @staticmethod
    def encode_v(inst: Instruction) -> str:
        p = "1"
        opcode = format(F32IS_Encoder.OPCODES.get(inst.op, 0b00110), "05b")
        imm_value = inst.imm or 0
        s_active = getattr(inst, "use_sub", False) or imm_value < 0
        s_bit = "1" if s_active else "0"
        b_bit = "1" if "b" in inst.op.lower() else "0"
        h_bit = "1" if "h" in inst.op.lower() else "0"
        w_bit = "1" if "w" in inst.op.lower() else "0"
        sd = format(inst.rd or 0, "03b")
        sn = format(inst.rn or 0, "03b")
        imm16 = format(abs(imm_value) & 0xFFFF, "016b")
        return imm16 + sn + sd + w_bit + h_bit + b_bit + s_bit + opcode + p


class F32IS_Writer:
    """Funciones de salida para instrucciones y binarios finales."""

    @staticmethod
    def to_bytes(binary_str: str) -> bytes:
        """Convierte una palabra binaria textual a 4 bytes little-endian."""

        return struct.pack("<I", int(binary_str, 2))

    @staticmethod
    def save_bin(filename: str, instructions: Iterable[str]):
        """Guarda solo el flujo de instrucciones binarias."""

        with open(filename, "wb") as handle:
            for inst in instructions:
                handle.write(F32IS_Writer.to_bytes(inst))

    @staticmethod
    def save_hex(filename: str, instructions: Iterable[str]):
        """Guarda las instrucciones en hexadecimal para simulacion."""

        with open(filename, "w", encoding="utf-8") as handle:
            for inst in instructions:
                handle.write(f"{int(inst, 2):08X}\n")

    @staticmethod
    def save_object_bin(filename: str, instructions: Iterable[str], data_blob: bytes):
        """Guarda un objeto parcial con codigo y datos, sin encabezado final."""

        with open(filename, "wb") as handle:
            for inst in instructions:
                handle.write(F32IS_Writer.to_bytes(inst))
            handle.write(data_blob)

    @staticmethod
    def save_program_bin(filename: str, header: BinaryHeader, instructions: Iterable[str], data_blob: bytes):
        """Guarda un binario final con encabezado, codigo y datos."""

        with open(filename, "wb") as handle:
            handle.write(header.pack())
            for inst in instructions:
                handle.write(F32IS_Writer.to_bytes(inst))
            handle.write(data_blob)


def encode_instruction_stream(instructions: Iterable[Instruction]) -> list[str]:
    """Codifica una lista de instrucciones parseadas."""

    return [instruction.encode() for instruction in instructions]


def _literal_value(node: LiteralNode):
    """Evalua un literal del AST a su valor de Python."""

    if node.literal_type == "int":
        return int(str(node.value), 10)
    if node.literal_type == "hex":
        return int(str(node.value), 0)
    if node.literal_type == "bool":
        return 1 if bool(node.value) else 0
    if node.literal_type == "char":
        text = str(node.value)
        if len(text) >= 2 and text[0] == "'" and text[-1] == "'":
            body = text[1:-1]
            if body.startswith("\\"):
                escape_map = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "\\": "\\", "'": "'", '"': '"'}
                body = escape_map.get(body[1:], body[1:])
            return ord(body)
        return ord(text[0])
    if node.literal_type == "float":
        return float(str(node.value))
    return None


def _evaluate_constant_expression(node):
    """Evalua expresiones constantes simples para inicializadores globales."""

    if node is None:
        return None
    if isinstance(node, LiteralNode):
        return _literal_value(node)
    if isinstance(node, UnaryOpNode):
        value = _evaluate_constant_expression(node.operand)
        if value is None:
            return None
        if node.operator == "-":
            return -value
        if node.operator == "!":
            return 0 if value else 1
        return None
    if isinstance(node, BinaryOpNode):
        left = _evaluate_constant_expression(node.left)
        right = _evaluate_constant_expression(node.right)
        if left is None or right is None:
            return None
        operations = {
            "+": lambda a, b: a + b,
            "-": lambda a, b: a - b,
            "*": lambda a, b: a * b,
            "/": lambda a, b: a // b if b != 0 else None,
            "%": lambda a, b: a % b if b != 0 else None,
            "&": lambda a, b: a & b,
            "|": lambda a, b: a | b,
            "^": lambda a, b: a ^ b,
            "<<": lambda a, b: a << b,
            ">>": lambda a, b: a >> b,
            "==": lambda a, b: 1 if a == b else 0,
            "!=": lambda a, b: 1 if a != b else 0,
            "<": lambda a, b: 1 if a < b else 0,
            "<=": lambda a, b: 1 if a <= b else 0,
            ">": lambda a, b: 1 if a > b else 0,
            ">=": lambda a, b: 1 if a >= b else 0,
        }
        operation = operations.get(node.operator)
        return operation(left, right) if operation is not None else None
    return None


def _pack_scalar_value(type_info: TypeInfo, value) -> bytes:
    """Empaqueta un valor escalar segun el tipo semantico."""

    if type_info.name == "char" and not type_info.is_array and not type_info.is_pointer:
        return struct.pack("<B", int(value) & 0xFF)
    if type_info.name == "float" and not type_info.is_array and not type_info.is_pointer:
        return struct.pack("<f", float(value))
    return struct.pack("<I", int(value) & 0xFFFFFFFF)


def build_global_data_blob(program: ProgramNode, symbol_table: SymbolTable) -> tuple[bytes, int]:
    """Construye el segmento de datos iniciales para variables globales."""

    global_symbols = [
        symbol
        for symbol in symbol_table.global_scope.symbols.values()
        if symbol.segment == "global" and symbol.address is not None and symbol.type_info is not None
    ]
    if not global_symbols:
        return b"", 0

    data_base = min(symbol.address for symbol in global_symbols if symbol.address is not None)
    data_end = max((symbol.address or data_base) + symbol.size for symbol in global_symbols)
    blob = bytearray(data_end - data_base)

    initializers = {}
    for declaration in program.declarations:
        if isinstance(declaration, VarDeclNode):
            for declarator in declaration.declarators:
                initializers[declarator.name] = declarator.initializer

    for symbol in global_symbols:
        offset = (symbol.address or data_base) - data_base
        type_info = symbol.type_info
        if type_info is None or type_info.is_array:
            continue
        initializer = initializers.get(symbol.name)
        if initializer is None:
            continue
        value = _evaluate_constant_expression(initializer)
        if value is None:
            continue
        packed = _pack_scalar_value(type_info, value)
        blob[offset : offset + len(packed)] = packed

    return bytes(blob), data_base


def build_program_header(encoded_instructions: Iterable[str], data_blob: bytes, entry_point: int, data_base: int) -> BinaryHeader:
    """Genera el encabezado del archivo binario final."""

    code_size = len(list(encoded_instructions)) * 4
    return BinaryHeader(
        entry_point=entry_point,
        code_size=code_size,
        data_size=len(data_blob),
        code_base=0,
        data_base=data_base,
    )

