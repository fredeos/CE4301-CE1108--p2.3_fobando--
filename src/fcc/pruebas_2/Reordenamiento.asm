; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 4
    mov p0, zero    # resultado de programa por defecto
    call 111    # entrada principal | -> main @ 456
__halt_no_end__:    # addr=12
    jmp -1    # fin sin instruccion end | -> __halt_no_end__ @ 12
analizar_sensor_reordenado:    # addr=16
    addi sp, sp, 104
    stw ra, +0(sp)
    li r0, 0
    stw r0, +36(sp)
    li r0, 0
    stw r0, +72(sp)
    ldw r0, +36(sp)
    nop    # espera load-use
    stw r0, +32(sp)
    ldw r0, +72(sp)
    nop    # espera load-use
    stw r0, +28(sp)
analizar_sensor_reordenado_while_cond_1:    # addr=64
    ldw r0, +32(sp)
    mov r1, p1
    li r2, 0
    blt r0, r1, 1    # -> analizar_sensor_reordenado_ir_cmp_true_1 @ 84
    jmp 1    # -> analizar_sensor_reordenado_ir_cmp_end_2 @ 88
analizar_sensor_reordenado_ir_cmp_true_1:    # addr=84
    li r2, 1
analizar_sensor_reordenado_ir_cmp_end_2:    # addr=88
    stw r2, +76(sp)
    ldw r2, +76(sp)
    nop    # espera load-use
    beqz r2, 82    # -> analizar_sensor_reordenado_while_end_2 @ 432
    mov r2, p0
    ldw r0, +32(sp)
    nop    # espera load-use
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    nop    # espera load-use
    stw r0, +80(sp)
    li r2, 100
    stw r2, +84(sp)
    li r2, 2
    stw r2, +92(sp)
    li r2, 10
    stw r2, +100(sp)
    li r2, 3
    stw r2, +44(sp)
    li r2, 50
    stw r2, +52(sp)
    ldw r2, +32(sp)
    ldw r0, +84(sp)
    nop    # espera load-use
    mul r2, r2, r0
    stw r2, +88(sp)
    ldw r2, +80(sp)
    nop    # espera load-use
    stw r2, +24(sp)
    ldw r2, +88(sp)
    nop    # espera load-use
    stw r2, +20(sp)
    ldw r2, +24(sp)
    ldw r0, +92(sp)
    nop    # espera load-use
    mul r2, r2, r0
    stw r2, +96(sp)
    ldw r2, +24(sp)
    ldw r0, +52(sp)
    li r1, 0
    bgt r2, r0, 1    # -> analizar_sensor_reordenado_ir_cmp_true_3 @ 260
    jmp 1    # -> analizar_sensor_reordenado_ir_cmp_end_4 @ 264
analizar_sensor_reordenado_ir_cmp_true_3:    # addr=260
    li r1, 1
analizar_sensor_reordenado_ir_cmp_end_4:    # addr=264
    stw r1, +56(sp)
    ldw r1, +96(sp)
    nop    # espera load-use
    stw r1, +16(sp)
    ldw r1, +16(sp)
    ldw r2, +100(sp)
    nop    # espera load-use
    add r1, r1, r2
    stw r1, +40(sp)
    ldw r1, +40(sp)
    nop    # espera load-use
    stw r1, +12(sp)
    ldw r1, +12(sp)
    ldw r2, +44(sp)
    nop    # espera load-use
    mul r1, r1, r2
    stw r1, +48(sp)
    ldw r1, +48(sp)
    nop    # espera load-use
    stw r1, +8(sp)
    ldw r1, +56(sp)
    nop    # espera load-use
    beqz r1, 8    # -> analizar_sensor_reordenado_if_next_4 @ 388
    ldw r1, +28(sp)
    ldw r2, +8(sp)
    nop    # espera load-use
    add r1, r1, r2
    stw r1, +60(sp)
    ldw r1, +60(sp)
    nop    # espera load-use
    stw r1, +28(sp)
analizar_sensor_reordenado_if_next_4:    # addr=388
analizar_sensor_reordenado_if_end_3:    # addr=388
    li r1, 1
    stw r1, +64(sp)
    ldw r1, +32(sp)
    ldw r2, +64(sp)
    nop    # espera load-use
    add r1, r1, r2
    stw r1, +68(sp)
    ldw r1, +68(sp)
    nop    # espera load-use
    stw r1, +32(sp)
    jmp -92    # -> analizar_sensor_reordenado_while_cond_1 @ 64
analizar_sensor_reordenado_while_end_2:    # addr=432
    ldw r1, +28(sp)
    ldw ra, +0(sp)
    mov p0, r1
    addi sp, sp, -104
    ret
    nop    # relleno no ejecutado tras ret
main:    # addr=456
    addi sp, sp, 80
    stw ra, +0(sp)
    li r0, 20
    stw r0, +32(sp)
    li r0, 0
    stw r0, +48(sp)
    addi r0, sp, 12
    ldw r1, +48(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +32(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 60
    stw r0, +52(sp)
    li r0, 1
    stw r0, +56(sp)
    addi r0, sp, 12
    ldw r1, +56(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +52(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 45
    stw r0, +60(sp)
    li r0, 2
    stw r0, +64(sp)
    addi r0, sp, 12
    ldw r1, +64(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +60(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 80
    stw r0, +68(sp)
    li r0, 3
    stw r0, +72(sp)
    addi r0, sp, 12
    ldw r1, +72(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +68(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 70
    stw r0, +76(sp)
    li r0, 4
    stw r0, +36(sp)
    addi r0, sp, 12
    ldw r1, +36(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +76(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 5
    stw r0, +40(sp)
    addi r0, sp, 12
    ldw r1, +40(sp)
    mov p0, r0
    mov p1, r1
    call -179    # -> analizar_sensor_reordenado @ 16
    nop    # espera retorno de call antes de leer p0
    mov r1, p0
    stw r1, +44(sp)
    ldw r1, +44(sp)
    nop    # espera load-use
    stw r1, +8(sp)
    ldw r1, +8(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r1
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
    ldw ra, +0(sp)
    addi sp, sp, -80
    ret
