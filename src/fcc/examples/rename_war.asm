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
    addi sp, sp, 52
    stw ra, +0(sp)
    li r0, 10
    stw r0, +16(sp)
    ldw r0, +16(sp)
    stw r0, +36(sp)
    li r0, 5
    stw r0, +20(sp)
    ldw r0, +36(sp)
    ldw r1, +20(sp)
    add r0, r0, r1
    stw r0, +24(sp)
    ldw r0, +24(sp)
    stw r0, +44(sp)
    li r0, 3
    stw r0, +28(sp)
    ldw r0, +28(sp)
    stw r0, +40(sp)
    ldw r0, +44(sp)
    ldw r1, +40(sp)
    mul r0, r0, r1
    stw r0, +32(sp)
    ldw r0, +32(sp)
    stw r0, +48(sp)
    ldw r0, +48(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -52
    ret
    end
