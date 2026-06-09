; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 3    # entrada principal | -> main @ 24
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
main:    # addr=24
    addi sp, sp, 28
    stw ra, +0(sp)
    li r0, 10
    stw r0, +16(sp)
    ldw r0, +16(sp)
    stw r0, +8(sp)
    li r0, 2
    stw r0, +20(sp)
    ldw r0, +8(sp)
    ldw r1, +20(sp)
    mul r0, r0, r1
    stw r0, +24(sp)
    ldw r0, +24(sp)
    stw r0, +4(sp)
    ldw r0, +4(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -28
    ret
