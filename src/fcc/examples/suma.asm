; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 15    # entrada principal | -> main @ 72
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
suma:    # addr=24
    addi sp, sp, 8
    stw ra, +0(sp)
    mov r0, p0
    mov r1, p1
    add r0, r0, r1
    stw r0, +4(sp)
    ldw r0, +4(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -8
    ret
main:    # addr=72
    addi sp, sp, 24
    stw ra, +0(sp)
    li r0, 2
    stw r0, +12(sp)
    ldw r0, +12(sp)
    stw r0, +8(sp)
    li r0, 3
    stw r0, +16(sp)
    ldw r0, +16(sp)
    stw r0, +4(sp)
    ldw r0, +8(sp)
    mov p0, r0
    ldw r0, +4(sp)
    mov p1, r0
    call -27    # -> suma @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +20(sp)
    ldw r0, +20(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -24
    ret
