; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 44
    li r0, 0
    la r1, 0
    stw r0, +0(r1)
    li r0, 1
    la r1, 4
    stw r0, +0(r1)
    li r0, 5
    la r1, 16
    stw r0, +0(r1)
    call 114    # entrada principal | -> main @ 500
__halt__:    # addr=44
    jmp -1    # -> __halt__ @ 44
maximo_lista:    # addr=48
    addi sp, sp, 12
    stw ra, +0(sp)
    li r0, 0
    stw r0, +8(sp)
    la r1, 20
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    stw r0, +4(sp)
maximo_lista_while_cond_1:    # addr=88
    ldw r0, +8(sp)
    la r2, 16
    ldw r1, +0(r2)
    bge r0, r1, 19    # -> maximo_lista_while_end_2 @ 180
    la r1, 20
    ldw r2, +8(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    ldw r1, +4(sp)
    ble r0, r1, 7    # -> maximo_lista_if_else_4 @ 160
    la r1, 20
    ldw r2, +8(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    stw r0, +4(sp)
    jmp 0    # -> maximo_lista_if_end_3 @ 160
maximo_lista_if_else_4:    # addr=160
maximo_lista_if_end_3:    # addr=160
    li r0, 1
    ldw r1, +8(sp)
    add r1, r1, r0
    stw r1, +8(sp)
    jmp -23    # -> maximo_lista_while_cond_1 @ 88
maximo_lista_while_end_2:    # addr=180
    ldw r1, +4(sp)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -12
    ret
sumeMayores:    # addr=208
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 0
    la r1, 0
    stw r0, +0(r1)
    li r0, 1
    la r1, 4
    stw r0, +0(r1)
sumeMayores_while_cond_5:    # addr=240
    la r1, 0
    ldw r0, +0(r1)
    li r1, 100
    bge r0, r1, 45    # -> sumeMayores_while_end_6 @ 436
    call -53    # -> maximo_lista @ 48
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    la r1, 40
    stw r0, +0(r1)
    la r1, 40
    ldw r0, +0(r1)
    divi r0, r0, 2
    li r1, 5
    bne r0, r1, 7    # -> sumeMayores_if_else_8 @ 324
    li r0, 2
    la r2, 40
    ldw r1, +0(r2)
    mul r1, r1, r0
    la r2, 40
    stw r1, +0(r2)
    jmp 0    # -> sumeMayores_if_end_7 @ 324
sumeMayores_if_else_8:    # addr=324
sumeMayores_if_end_7:    # addr=324
    la r0, 40
    ldw r1, +0(r0)
    la r2, 0
    ldw r0, +0(r2)
    add r0, r0, r1
    la r2, 0
    stw r0, +0(r2)
    la r1, 40
    ldw r0, +0(r1)
    la r2, 4
    ldw r1, +0(r2)
    mul r1, r1, r0
    la r2, 4
    stw r1, +0(r2)
    la r0, 4
    ldw r1, +0(r0)
    li r0, 500
    ble r1, r0, 4    # -> sumeMayores_if_else_10 @ 412
    li r1, 10
    la r0, 4
    stw r1, +0(r0)
    jmp 5    # -> sumeMayores_if_end_9 @ 432
sumeMayores_if_else_10:    # addr=412
    la r0, 4
    ldw r1, +0(r0)
    subi r1, r1, 10
    la r0, 4
    stw r1, +0(r0)
sumeMayores_if_end_9:    # addr=432
    jmp -49    # -> sumeMayores_while_cond_5 @ 240
sumeMayores_while_end_6:    # addr=436
    la r0, 0
    ldw r1, +0(r0)
    la r0, 8
    stw r1, +0(r0)
    la r0, 4
    ldw r1, +0(r0)
    la r0, 12
    stw r1, +0(r0)
    la r0, 8
    ldw r1, +0(r0)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
main:    # addr=500
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 100
    la r1, 20
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 2
    la r1, 20
    li r2, 1
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 3
    la r1, 20
    li r2, 2
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 4
    la r1, 20
    li r2, 3
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 5
    la r1, 20
    li r2, 4
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    call -106    # -> sumeMayores @ 208
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
