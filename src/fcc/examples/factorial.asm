; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 28    # entrada principal | -> main @ 124
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
factorial:    # addr=24
    addi sp, sp, 12
    stw ra, +0(sp)
    li r0, 1
    stw r0, +8(sp)
    li r0, 1
    stw r0, +4(sp)
factorial_while_cond_1:    # addr=48
    ldw r0, +4(sp)
    mov r1, p0
    bgt r0, r1, 9    # -> factorial_while_end_2 @ 96
    ldw r0, +8(sp)
    ldw r1, +4(sp)
    mul r0, r0, r1
    stw r0, +8(sp)
    li r0, 1
    ldw r1, +4(sp)
    add r1, r1, r0
    stw r1, +4(sp)
    jmp -12    # -> factorial_while_cond_1 @ 48
factorial_while_end_2:    # addr=96
    ldw r1, +8(sp)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -12
    ret
main:    # addr=124
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 8
    mov p0, r0
    call -30    # -> factorial @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
    end
