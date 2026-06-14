; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 51    # entrada principal | -> main @ 216
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
__halt__:    # addr=20
    jmp -1    # -> __halt__ @ 20
calcula:    # addr=24
    addi sp, sp, 72
    stw ra, +0(sp)
    li r0, 1
    stw r0, +24(sp)
    mov r0, p0
    ldw r1, +24(sp)
    add r0, r0, r1
    stw r0, +28(sp)
    ldw r0, +28(sp)
    stw r0, +60(sp)
    li r0, 2
    stw r0, +32(sp)
    ldw r0, +60(sp)
    ldw r1, +32(sp)
    mul r0, r0, r1
    stw r0, +36(sp)
    ldw r0, +36(sp)
    stw r0, +16(sp)
    li r0, 3
    stw r0, +40(sp)
    mov r0, p0
    ldw r1, +40(sp)
    sub r0, r0, r1
    stw r0, +44(sp)
    ldw r0, +44(sp)
    stw r0, +64(sp)
    ldw r0, +16(sp)
    ldw r1, +64(sp)
    add r0, r0, r1
    stw r0, +48(sp)
    ldw r0, +48(sp)
    stw r0, +20(sp)
    ldw r0, +20(sp)
    mov r1, p0
    sub r0, r0, r1
    stw r0, +52(sp)
    ldw r0, +52(sp)
    stw r0, +68(sp)
    ldw r0, +68(sp)
    ldw r1, +16(sp)
    add r0, r0, r1
    stw r0, +56(sp)
    ldw r0, +56(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -72
    ret
main:    # addr=216
    addi sp, sp, 20
    stw ra, +0(sp)
    li r0, 12
    stw r0, +12(sp)
    ldw r0, +12(sp)
    mov p0, r0
    call -55    # -> calcula @ 24
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +16(sp)
    ldw r0, +16(sp)
    stw r0, +8(sp)
    ldw r0, +8(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -20
    ret
