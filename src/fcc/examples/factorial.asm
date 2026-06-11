; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 55    # entrada principal | -> main @ 232
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
factorial:    # addr=24
    addi sp, sp, 52
    stw ra, +0(sp)
    li r0, 1
    stw r0, +16(sp)
    ldw r0, +16(sp)
    stw r0, +12(sp)
    li r0, 1
    stw r0, +20(sp)
    ldw r0, +20(sp)
    stw r0, +8(sp)
    li r0, 15
    stw r0, +24(sp)
    ldw r0, +24(sp)
    stw r0, +4(sp)
    li r0, 16
    stw r0, +28(sp)
    ldw r0, +4(sp)
    ldw r1, +28(sp)
    add r0, r0, r1
    stw r0, +32(sp)
    ldw r0, +32(sp)
    stw r0, +4(sp)
factorial_while_cond_1:    # addr=112
    ldw r0, +8(sp)
    mov r1, p0
    li r2, 0
    ble r0, r1, 1    # -> factorial_ir_cmp_true_1 @ 132
    jmp 1    # -> factorial_ir_cmp_end_2 @ 136
factorial_ir_cmp_true_1:    # addr=132
    li r2, 1
factorial_ir_cmp_end_2:    # addr=136
    stw r2, +36(sp)
    ldw r2, +36(sp)
    beqz r2, 15    # -> factorial_while_end_2 @ 208
    ldw r2, +12(sp)
    ldw r0, +8(sp)
    mul r2, r2, r0
    stw r2, +40(sp)
    ldw r2, +40(sp)
    stw r2, +12(sp)
    li r2, 1
    stw r2, +44(sp)
    ldw r2, +8(sp)
    ldw r0, +44(sp)
    add r2, r2, r0
    stw r2, +48(sp)
    ldw r2, +48(sp)
    stw r2, +8(sp)
    jmp -24    # -> factorial_while_cond_1 @ 112
factorial_while_end_2:    # addr=208
    ldw r2, +12(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r2
    ldw ra, +0(sp)
    addi sp, sp, -52
    ret
main:    # addr=232
    addi sp, sp, 12
    stw ra, +0(sp)
    li r0, 8
    stw r0, +4(sp)
    ldw r0, +4(sp)
    mov p0, r0
    call -59    # -> factorial @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +8(sp)
    ldw r0, +8(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -12
    ret
