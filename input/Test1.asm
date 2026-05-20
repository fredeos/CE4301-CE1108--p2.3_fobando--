; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 48
    li r0, 0
    la r1, 0
    stw r0, +0(r1)
    call 85    # entrada principal | -> main @ 360
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
es_primo:    # addr=24
    addi sp, sp, 8
    stw ra, +0(sp)
    li r0, 2
    stw r0, +4(sp)
    mov r0, p0
    li r1, 1
    bgt r0, r1, 6    # -> es_primo_if_else_2 @ 76
    li r0, 0
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -8
    ret
    jmp 0    # -> es_primo_if_end_1 @ 76
es_primo_if_else_2:    # addr=76
es_primo_if_end_1:    # addr=76
es_primo_while_cond_3:    # addr=76
    ldw r0, +4(sp)
    ldw r1, +4(sp)
    mul r0, r0, r1
    mov r1, p0
    bgt r0, r1, 16    # -> es_primo_while_end_4 @ 160
    mov r0, p0
    ldw r1, +4(sp)
    mod r0, r0, r1
    li r1, 0
    bne r0, r1, 6    # -> es_primo_if_else_6 @ 140
    li r0, 0
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -8
    ret
    jmp 0    # -> es_primo_if_end_5 @ 140
es_primo_if_else_6:    # addr=140
es_primo_if_end_5:    # addr=140
    li r0, 1
    ldw r1, +4(sp)
    add r1, r1, r0
    stw r1, +4(sp)
    jmp -21    # -> es_primo_while_cond_3 @ 76
es_primo_while_end_4:    # addr=160
    li r1, 1
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -8
    ret
sume:    # addr=180
    addi sp, sp, 20
    stw ra, +0(sp)
    li r0, 0
    stw r0, +16(sp)
    li r0, 0
    stw r0, +4(sp)
sume_while_cond_7:    # addr=204
    ldw r0, +16(sp)
    li r1, 10
    bge r0, r1, 24    # -> sume_while_end_8 @ 312
    la r1, 8
    ldw r2, +16(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    stw r0, +4(sp)
    ldw r0, +4(sp)
    mov p0, r0
    call -57    # -> es_primo @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    beqz r0, 7    # -> sume_if_else_10 @ 292
    ldw r0, +4(sp)
    la r2, 0
    ldw r1, +0(r2)
    add r1, r1, r0
    la r2, 0
    stw r1, +0(r2)
    jmp 0    # -> sume_if_end_9 @ 292
sume_if_else_10:    # addr=292
sume_if_end_9:    # addr=292
    li r1, 1
    ldw r0, +16(sp)
    add r0, r0, r1
    stw r0, +16(sp)
    jmp -27    # -> sume_while_cond_7 @ 204
sume_while_end_8:    # addr=312
    la r1, 0
    ldw r0, +0(r1)
    la r1, 4
    stw r0, +0(r1)
    la r1, 4
    ldw r0, +0(r1)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -20
    ret
main:    # addr=360
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 1
    la r1, 8
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 2
    la r1, 8
    li r2, 1
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 3
    la r1, 8
    li r2, 2
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 4
    la r1, 8
    li r2, 3
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 5
    la r1, 8
    li r2, 4
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 6
    la r1, 8
    li r2, 5
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 7
    la r1, 8
    li r2, 6
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 8
    la r1, 8
    li r2, 7
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 9
    la r1, 8
    li r2, 8
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 11
    la r1, 8
    li r2, 9
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    call -108    # -> sume @ 180
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
