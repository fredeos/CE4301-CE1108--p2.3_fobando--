; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 48
    call 93    # entrada principal | -> main @ 380
__halt__:    # addr=8
    jmp -1    # -> __halt__ @ 8
fibonacci_aux:    # addr=12
    addi sp, sp, 20
    stw ra, +0(sp)
    li r0, 0
    stw r0, +16(sp)
    li r0, 1
    stw r0, +12(sp)
    li r0, 0
    stw r0, +8(sp)
    li r0, 2
    stw r0, +4(sp)
    mov r0, p0
    li r1, 0
    bge r0, r1, 3    # -> fibonacci_aux_if_else_2 @ 76
    li r0, 0
    mov p0, r0
    jmp 0    # -> fibonacci_aux_if_end_1 @ 76
fibonacci_aux_if_else_2:    # addr=76
fibonacci_aux_if_end_1:    # addr=76
    mov r0, p0
    li r1, 10
    ble r0, r1, 3    # -> fibonacci_aux_if_else_4 @ 100
    li r0, 10
    mov p0, r0
    jmp 0    # -> fibonacci_aux_if_end_3 @ 100
fibonacci_aux_if_else_4:    # addr=100
fibonacci_aux_if_end_3:    # addr=100
    ldw r0, +16(sp)
    la r1, 0
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    ldw r0, +16(sp)
    la r1, 44
    stw r0, +0(r1)
    mov r0, p0
    li r1, 1
    blt r0, r1, 10    # -> fibonacci_aux_if_else_6 @ 188
    ldw r0, +12(sp)
    la r1, 0
    li r2, 1
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    ldw r0, +12(sp)
    la r1, 44
    stw r0, +0(r1)
    jmp 0    # -> fibonacci_aux_if_end_5 @ 188
fibonacci_aux_if_else_6:    # addr=188
fibonacci_aux_if_end_5:    # addr=188
fibonacci_aux_while_cond_7:    # addr=188
    ldw r0, +4(sp)
    mov r1, p0
    bgt r0, r1, 22    # -> fibonacci_aux_while_end_8 @ 288
    ldw r0, +16(sp)
    ldw r1, +12(sp)
    add r0, r0, r1
    stw r0, +8(sp)
    ldw r0, +8(sp)
    la r1, 0
    ldw r2, +4(sp)
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    ldw r0, +12(sp)
    stw r0, +16(sp)
    ldw r0, +8(sp)
    stw r0, +12(sp)
    ldw r0, +8(sp)
    la r1, 44
    stw r0, +0(r1)
    li r0, 1
    ldw r1, +4(sp)
    add r1, r1, r0
    stw r1, +4(sp)
    jmp -25    # -> fibonacci_aux_while_cond_7 @ 188
fibonacci_aux_while_end_8:    # addr=288
    la r0, 44
    ldw r1, +0(r0)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -20
    ret
fibonacci:    # addr=320
    addi sp, sp, 8
    stw ra, +0(sp)
    mov r0, p0
    mov p0, r0
    call -82    # -> fibonacci_aux @ 12
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
main:    # addr=380
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 10
    mov p0, r0
    call -20    # -> fibonacci @ 320
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
