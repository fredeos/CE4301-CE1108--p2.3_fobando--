#////////////////////////////////////////////////////////////////////////////////
# --- Directorios de unidades de control ---
dirCONTROL = ./src/control
dirCONTROLtb = ${dirCONTROL}/tests

# --- Directorios de memorias ---
dirINSTRMEM = ./src/instrmem
dirINSTRMEMtb = ${dirINSTRMEM}/tests

dirDATAMEM = ./src/datamem
dirDATAMEMtb = ${dirDATAMEM}/tests

dirVAULT = ./src/vault
dirVAULTtb = ${dirVAULT}/tests

# --- Directorios de bancos registros ---
dirREGFILE = ./src/regfile
dirREGFILEtb = ${dirREGFILE}/tests

dirSECMEM = ./src/secmem
dirSECMEMtb = ${dirSECMEM}/tests

# --- Directorios de ALUs y Hazard Unit ---
dirALU = ./src/alu
dirALUtb = ${dirALU}/tests

dirHAZARD = ./src/hazard
dirHAZARDtb = ${dirHAZARD}/tests

# --- Directorio del datapath y extension de inmediatos ---
dirDATAPATH = ./src/datapath
dirDATAPATHtb = ${dirDATAPATH}/tests

#////////////////////////////////////////////////////////////////////////////////
# --- Archivos de codigo fuente para ejecutar pruebas ---

control_unit = ${dirCONTROL}/control_unit.sv ${dirCONTROL}/branch_decoder.sv ${dirCONTROL}/main_decoder.sv ${dirCONTROL}/alu_decoder.sv # unidad de control
admin_unit = ${dirCONTROL}/admin_unit.sv ${dirCONTROL}/cycle_comparer.sv	# unidad de administrador (sessiones de hardware seguro)
cond_unit = ${dirCONTROL}/cond_unit.sv	# unidad de condicionales y saltos (cambios al PC)
ssu = ${dirCONTROL}/ssu.sv				# unidad de seleccion segura (instrucciones @)

cpu = ${dirDATAPATH}/*.sv ${dirCONTROL}/*.sv ${dirINSTRMEM}/*.sv ${dirDATAMEM}/*.sv ${dirVAULT}/*.sv ${dirREGFILE}/*.sv ${dirSECMEM}/*.sv ${dirALU}/*.sv ${dirHAZARD}/hazard_unit.sv # compilar todos los modulos del procesador

#////////////////////////////////////////////////////////////////////////////////
# --- Makefile ---
top:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ./src/top.sv ./src/tb_top.sv

ControlUnit:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${control_unit} ${dirCONTROLtb}/tb_control_unit.sv

CondUnit:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${cond_unit} ${dirCONTROLtb}/tb_cond_unit.sv

AdminUnit:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${admin_unit} ${dirCONTROLtb}/tb_admin_unit.sv

SSU:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${ssu} ${dirCONTROLtb}/tb_ssu.sv

SecureMemory:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirSECMEM}/secure_memory.sv ${dirSECMEMtb}/tb_secure_memory.sv

RegFile:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirREGFILE}/register_file.sv ${dirREGFILEtb}/tb_register_file.sv

Hazard:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirHAZARD}/hazard_unit.sv ${dirHAZARDtb}/tb_hazard_unit.sv

InstructionMemory:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirINSTRMEM}/instruction_memory.sv ${dirINSTRMEMtb}/instruction_memory_tb.sv

DataMemory:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirDATAMEM}/data_memory.sv ${dirDATAMEMtb}/data_memory_tb.sv

Vault:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirVAULT}/vault.sv ${dirVAULTtb}/vault_tb.sv

pALU:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirALU}/pALU.sv ${dirALUtb}/pALU_tb.sv

sALU:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirALU}/sALU.sv ${dirALUtb}/sALU_tb.sv

ImmExt:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${dirDATAPATH}/imm_ext32.sv ${dirDATAPATHtb}/tb_imm_ext.sv

Datapath:
	mkdir -p ./output
	iverilog -g2012 -o ./output/sim.out ${cpu} ${dirDATAPATHtb}/tb_datapath.sv

run:
	vvp ./output/sim.out
	gtkwave ./output/wave.vcd

run-config:
	vvp ./output/sim.out
	gtkwave ./output/wave.vcd ./output/$(TARGET).gtkw

pyload-mem:
	python src/load_file.py --input input/$(INPUT) --output src/$(OUTPUT) --address $(ADDRESS)

pyextract-data:
	python src/extract_data.py --memory output/$(INPUT) --address $(ADDRESS) --size $(SIZE) --output output/$(OUTPUT)

clean:
	rm ./output/**