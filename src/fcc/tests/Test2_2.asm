; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 36
    li r0, 7
    la r1, 0
    stw r0, +0(r1)
    li r0, 0
    la r1, 32
    stw r0, +0(r1)
    call 41    # entrada principal | -> main @ 196
__halt__:    # addr=32
    jmp -1    # -> __halt__ @ 32
maximo_lista:    # addr=36
    addi sp, sp, 12
    stw ra, +0(sp)
    li r0, 0
    stw r0, +8(sp)
    la r1, 4
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    stw r0, +4(sp)
maximo_lista_while_cond_1:    # addr=76
    ldw r0, +8(sp)
    la r2, 0
    ldw r1, +0(r2)
    bge r0, r1, 19    # -> maximo_lista_while_end_2 @ 168
    la r1, 4
    ldw r2, +8(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    ldw r1, +4(sp)
    ble r0, r1, 7    # -> maximo_lista_if_else_4 @ 148
    la r1, 4
    ldw r2, +8(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    stw r0, +4(sp)
    jmp 0    # -> maximo_lista_if_end_3 @ 148
maximo_lista_if_else_4:    # addr=148
maximo_lista_if_end_3:    # addr=148
    li r0, 1
    ldw r1, +8(sp)
    add r1, r1, r0
    stw r1, +8(sp)
    jmp -23    # -> maximo_lista_while_cond_1 @ 76
maximo_lista_while_end_2:    # addr=168
    ldw r1, +4(sp)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -12
    ret
main:    # addr=196
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 3
    la r1, 4
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 4
    la r1, 4
    li r2, 1
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 5
    la r1, 4
    li r2, 2
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 24
    la r1, 4
    li r2, 3
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 5
    la r1, 4
    li r2, 4
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 65
    la r1, 4
    li r2, 5
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 46
    la r1, 4
    li r2, 6
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    call -85    # -> maximo_lista @ 36
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    la r1, 32
    stw r0, +0(r1)
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
