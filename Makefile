#////////////////////////////////////////////////////////////////////////////////
CPU_SRC = ./src/isa
GEN = ./gen
OUT = ./output
DIRS = ${GEN} ${OUT}

# --- Directorios de unidades de control ---
CONTROL = ${CPU_SRC}/control

ADMIN = ${CPU_SRC}/admin

CONDUNIT = ${CPU_SRC}/cond

SSU = ${CPU_SRC}/ssu

# --- Directorios de memorias ---
INSTRMEM = ${CPU_SRC}/instrmem

DATAMEM = ${CPU_SRC}/datamem

CACHE = ${CPU_SRC}/cache

PACKEDM = ${CPU_SRC}/packed_mem

VAULT = ${CPU_SRC}/vault

# --- Directorios de bancos registros ---
REGFILE = ${CPU_SRC}/regfile

SECMEM = ${CPU_SRC}/secmem

# --- Directorios de ALUs y Hazard Unit ---
ALU = ${CPU_SRC}/alu

HAZARD = ${CPU_SRC}/hazard

# --- Directorio del datapath y extension de inmediatos ---
IMMEXT = ${CPU_SRC}/imm_ext

#////////////////////////////////////////////////////////////////////////////////
# --- Archivos de codigo fuente para ejecutar pruebas ---
MODS = ${CONTROL}/*.sv ${ADMIN}/*.sv ${CONDUNIT}/*.sv ${SSU}/*.sv ${INSTRMEM}/*.sv ${DATAMEM}/*.sv ${VAULT}/*.sv ${REGFILE}/*.sv ${SECMEM}/*.sv ${ALU}/*.sv ${HAZARD}/*.sv ${IMMEXT}/*.sv

#////////////////////////////////////////////////////////////////////////////////
TARGET = pipeline
CONFIG = default

# --- Makefile ---

# + Modulos individuales
control_unit: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${CONTROL}/*.sv ${CONTROL}/tests/*.sv

admin_unit: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${ADMIN}/*.sv ${ADMIN}/tests/*.sv

cond_unit: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${CONDUNIT}/*.sv ${CONDUNIT}/tests/*.sv

ssu: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${SSU}/*.sv ${SSU}/tests/*.sv

instrmem: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${INSTRMEM}/*.sv ${INSTRMEM}/tests/*.sv

cache: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${CACHE}/*.sv ${CACHE}/tests/*.sv

datamem: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${DATAMEM}/*.sv ${DATAMEM}/tests/*.sv

packed_mem: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${PACKEDM}/*.sv ${CACHE}/*.sv ${DATAMEM}/*.sv ${PACKEDM}/tests/*.sv

vault: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${VAULT}/*.sv ${VAULT}/tests/*.sv

regfile: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${REGFILE}/*.sv ${REGFILE}/tests/*.sv

secmem: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${SECMEM}/*.sv ${SECMEM}/tests/*.sv

pALU: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${ALU}/pALU.sv ${ALU}/tests/pALU_tb.sv

sALU: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${ALU}/sALU.sv ${ALU}/tests/sALU_tb.sv

hazard_unit: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${HAZARD}/*.sv ${HAZARD}/tests/*.sv

imm_ext: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${IMMEXT}/*.sv ${IMMEXT}/tests/*.sv

# + Procesadores con pipeline
pipeline: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${CPU_SRC}/$@.sv ${MODS} ${CPU_SRC}/tests/$@_tb.sv

pipeline_wcache: dirs
	iverilog -g2012 -o ${GEN}/$@.out ${CPU_SRC}/$@.sv ${MODS} ${CPU_SRC}/tests/$@_tb.sv

# + Reglas varias
run:
	vvp ${GEN}/$(TARGET).out 
	gtkwave ${GEN}/$(TARGET).vcd ./config/$(CONFIG).gtkw

pyload-mem:
	python src/load_file.py --input input/$(INPUT) --output src/$(OUTPUT) --address $(ADDRESS)

pyextract-data:
	python src/extract_data.py --memory output/$(INPUT) --address $(ADDRESS) --size $(SIZE) --output output/$(OUTPUT)

dirs:
	mkdir -p ${DIRS}

clean:
	rm ./output/**
	rm ./gen/**

.PHONY: dirs clean