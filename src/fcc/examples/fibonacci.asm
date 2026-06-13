; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 48
    mov p0, zero    # resultado de programa por defecto
    call 88    # entrada principal | -> main @ 364
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
fibonacci_aux:    # addr=24
    addi sp, sp, 24
    stw ra, +0(sp)
    li r0, 0
    stw r0, +20(sp)
    li r0, 1
    stw r0, +16(sp)
    li r0, 0
    stw r0, +12(sp)
    li r0, 2
    stw r0, +8(sp)
    mov r0, p0
    li r1, 0
    bge r0, r1, 2    # -> fibonacci_aux_if_else_2 @ 84
    li r0, 0
    mov p0, r0
fibonacci_aux_if_else_2:    # addr=84
fibonacci_aux_if_end_1:    # addr=84
    mov r0, p0
    li r1, 10
    ble r0, r1, 2    # -> fibonacci_aux_if_else_4 @ 104
    li r0, 10
    mov p0, r0
fibonacci_aux_if_else_4:    # addr=104
fibonacci_aux_if_end_3:    # addr=104
    ldw r0, +20(sp)
    la r1, 4
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    ldw r0, +20(sp)
    stw r0, +4(sp)
    mov r0, p0
    li r1, 1
    blt r0, r1, 8    # -> fibonacci_aux_if_else_6 @ 180
    ldw r0, +16(sp)
    la r1, 4
    li r2, 1
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    ldw r0, +16(sp)
    stw r0, +4(sp)
fibonacci_aux_if_else_6:    # addr=180
fibonacci_aux_if_end_5:    # addr=180
fibonacci_aux_while_cond_7:    # addr=180
    ldw r0, +8(sp)
    mov r1, p0
    bgt r0, r1, 21    # -> fibonacci_aux_while_end_8 @ 276
    ldw r0, +20(sp)
    ldw r1, +16(sp)
    add r0, r0, r1
    stw r0, +12(sp)
    ldw r0, +12(sp)
    la r1, 4
    ldw r2, +8(sp)
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    ldw r0, +16(sp)
    stw r0, +20(sp)
    ldw r0, +12(sp)
    stw r0, +16(sp)
    ldw r0, +12(sp)
    stw r0, +4(sp)
    li r0, 1
    ldw r1, +8(sp)
    add r1, r1, r0
    stw r1, +8(sp)
    jmp -24    # -> fibonacci_aux_while_cond_7 @ 180
fibonacci_aux_while_end_8:    # addr=276
    ldw r1, +4(sp)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -24
    ret
fibonacci:    # addr=304
    addi sp, sp, 8
    stw ra, +0(sp)
    mov r0, p0
    mov p0, r0
    call -75    # -> fibonacci_aux @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +4(sp)
    ldw r0, +4(sp)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -8
    ret
main:    # addr=364
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 10
    mov p0, r0
    call -20    # -> fibonacci @ 304
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
    end
