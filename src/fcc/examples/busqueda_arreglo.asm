; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 4
    call 76    # entrada principal | -> main @ 312
__halt__:    # addr=8
    jmp -1    # -> __halt__ @ 8
buscar:    # addr=12
    addi sp, sp, 36
    stw ra, +0(sp)
    li r0, 0
    stw r0, +12(sp)
    li r0, 1
    sub r0, zero, r0
    stw r0, +8(sp)
    li r0, 0
    stw r0, +4(sp)
    li r0, 4
    addi r1, sp, 16
    li r2, 0
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 1
    addi r1, sp, 16
    li r2, 1
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 7
    addi r1, sp, 16
    li r2, 2
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 9
    addi r1, sp, 16
    li r2, 3
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
    li r0, 6
    addi r1, sp, 16
    li r2, 4
    muli r2, r2, 4
    add r1, r1, r2
    stw r0, +0(r1)
buscar_while_cond_1:    # addr=168
    ldw r0, +12(sp)
    li r1, 5
    bge r0, r1, 23    # -> buscar_while_end_2 @ 272
    addi r1, sp, 16
    ldw r2, +12(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r0, +0(r1)
    mov r1, p0
    bne r0, r1, 5    # -> buscar_if_else_4 @ 228
    ldw r0, +12(sp)
    stw r0, +8(sp)
    li r0, 1
    stw r0, +4(sp)
    jmp 0    # -> buscar_if_end_3 @ 228
buscar_if_else_4:    # addr=228
buscar_if_end_3:    # addr=228
    ldw r0, +4(sp)
    seqz r0, r0
    beqz r0, 5    # -> buscar_if_else_6 @ 260
    li r0, 1
    ldw r1, +12(sp)
    add r1, r1, r0
    stw r1, +12(sp)
    jmp 2    # -> buscar_if_end_5 @ 268
buscar_if_else_6:    # addr=260
    li r1, 5
    stw r1, +12(sp)
buscar_if_end_5:    # addr=268
    jmp -26    # -> buscar_while_cond_1 @ 168
buscar_while_end_2:    # addr=272
    ldw r1, +8(sp)
    la r0, 0
    stw r1, +0(r0)
    ldw r1, +8(sp)
    nop    # espera load-use antes de mover retorno
    nop    # espera load-use antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -36
    ret
main:    # addr=312
    addi sp, sp, 4
    stw ra, +0(sp)
    li r0, 7
    mov p0, r0
    call -80    # -> buscar @ 12
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
