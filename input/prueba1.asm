; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 8
    mov p0, zero    # resultado de programa por defecto
    call 52    # entrada principal | -> main @ 220
    nop    # relleno antes de end
    nop    # relleno antes de end
    nop    # relleno antes de end
    end    # fin real del programa tras retornar de main
__end_fallback__:    # addr=28
    jmp -1    # respaldo si end se interpreta como nop | -> __end_fallback__ @ 28
sumatoria:    # addr=32
    addi sp, sp, 40
    stw ra, +0(sp)
    li r0, 0
    stw r0, +16(sp)
    ldw r0, +16(sp)
    nop    # espera load-use
    stw r0, +12(sp)
    li r0, 0
    stw r0, +20(sp)
    ldw r0, +20(sp)
    nop    # espera load-use
    stw r0, +8(sp)
sumatoria_for_cond_1:    # addr=80
    ldw r0, +8(sp)
    mov r1, p0
    li r2, 0
    blt r0, r1, 1    # -> sumatoria_ir_cmp_true_1 @ 100
    jmp 1    # -> sumatoria_ir_cmp_end_2 @ 104
sumatoria_ir_cmp_true_1:    # addr=100
    li r2, 1
sumatoria_ir_cmp_end_2:    # addr=104
    stw r2, +24(sp)
    ldw r2, +24(sp)
    nop    # espera load-use
    beqz r2, 19    # -> sumatoria_for_end_3 @ 196
    ldw r2, +12(sp)
    ldw r0, +8(sp)
    nop    # espera load-use
    add r2, r2, r0
    stw r2, +28(sp)
    ldw r2, +28(sp)
    nop    # espera load-use
    stw r2, +12(sp)
sumatoria_for_update_2:    # addr=152
    li r2, 1
    stw r2, +32(sp)
    ldw r2, +8(sp)
    ldw r0, +32(sp)
    nop    # espera load-use
    add r2, r2, r0
    stw r2, +36(sp)
    ldw r2, +36(sp)
    nop    # espera load-use
    stw r2, +8(sp)
    jmp -29    # -> sumatoria_for_cond_1 @ 80
sumatoria_for_end_3:    # addr=196
    ldw r2, +12(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r2
    ldw ra, +0(sp)
    addi sp, sp, -40
    ret
main:    # addr=220
    addi sp, sp, 24
    stw ra, +0(sp)
    li r0, 10
    stw r0, +12(sp)
    ldw r0, +12(sp)
    nop    # espera load-use
    stw r0, +8(sp)
    li r0, 10
    stw r0, +16(sp)
    ldw r0, +16(sp)
    nop    # espera load-use
    mov p0, r0
    call -60    # -> sumatoria @ 32
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +20(sp)
    ldw r0, +20(sp)
    la r1, 4
    stw r0, +0(r1)
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
    ldw ra, +0(sp)
    addi sp, sp, -24
    ret
