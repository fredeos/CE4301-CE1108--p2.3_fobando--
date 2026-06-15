; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 8
    mov p0, zero    # resultado de programa por defecto
    call 3    # entrada principal | -> main @ 24
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
main:    # addr=24
    addi sp, sp, 72
    stw ra, +0(sp)
    li r0, 4
    stw r0, +24(sp)
    ldw r0, +24(sp)
    stw r0, +60(sp)
    li r0, 1
    stw r0, +28(sp)
    ldw r0, +60(sp)
    ldw r1, +28(sp)
    add r0, r0, r1
    stw r0, +32(sp)
    ldw r0, +32(sp)
    stw r0, +16(sp)
    li r0, 20
    stw r0, +36(sp)
    ldw r0, +36(sp)
    stw r0, +64(sp)
    li r0, 2
    stw r0, +40(sp)
    ldw r0, +64(sp)
    ldw r1, +40(sp)
    add r0, r0, r1
    stw r0, +44(sp)
    ldw r0, +44(sp)
    stw r0, +20(sp)
    li r0, 7
    stw r0, +48(sp)
    ldw r0, +48(sp)
    stw r0, +68(sp)
    ldw r0, +16(sp)
    ldw r1, +20(sp)
    add r0, r0, r1
    stw r0, +52(sp)
    ldw r0, +52(sp)
    ldw r1, +68(sp)
    add r0, r0, r1
    stw r0, +56(sp)
    ldw r0, +56(sp)
    la r1, 4
    stw r0, +0(r1)
    la r1, 4
    ldw r0, +0(r1)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -72
    ret
    end
