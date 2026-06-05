; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 43    # entrada principal | -> main @ 184
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
suma:    # addr=24
    addi sp, sp, 36
    stw ra, +0(sp)
    li r0, 0
    stw r0, +12(sp)
    ldw r0, +12(sp)
    stw r0, +8(sp)
    li r0, 0
    stw r0, +16(sp)
    ldw r0, +16(sp)
    stw r0, +4(sp)
suma_while_cond_1:    # addr=64
    ldw r0, +4(sp)
    mov r1, p0
    li r2, 0
    ble r0, r1, 1    # -> suma_ir_cmp_true_1 @ 84
    jmp 1    # -> suma_ir_cmp_end_2 @ 88
suma_ir_cmp_true_1:    # addr=84
    li r2, 1
suma_ir_cmp_end_2:    # addr=88
    stw r2, +20(sp)
    ldw r2, +20(sp)
    beqz r2, 15    # -> suma_while_end_2 @ 160
    ldw r2, +8(sp)
    ldw r0, +4(sp)
    add r2, r2, r0
    stw r2, +24(sp)
    ldw r2, +24(sp)
    stw r2, +8(sp)
    li r2, 1
    stw r2, +28(sp)
    ldw r2, +4(sp)
    ldw r0, +28(sp)
    add r2, r2, r0
    stw r2, +32(sp)
    ldw r2, +32(sp)
    stw r2, +4(sp)
    jmp -24    # -> suma_while_cond_1 @ 64
suma_while_end_2:    # addr=160
    ldw r2, +8(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r2
    ldw ra, +0(sp)
    addi sp, sp, -36
    ret
main:    # addr=184
    addi sp, sp, 12
    stw ra, +0(sp)
    li r0, 10
    stw r0, +4(sp)
    ldw r0, +4(sp)
    mov p0, r0
    call -47    # -> suma @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +8(sp)
    ldw r0, +8(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -12
    ret
