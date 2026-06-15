; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 20
    mov p0, zero    # resultado de programa por defecto
    call 177    # entrada principal | -> main @ 720
__halt_no_end__:    # addr=12
    jmp -1    # fin sin instruccion end | -> __halt_no_end__ @ 12
multiplicacion_matrices:    # addr=16
    addi sp, sp, 168
    stw ra, +0(sp)
    li r0, 2
    stw r0, +64(sp)
    ldw r0, +64(sp)
    nop    # espera load-use
    stw r0, +60(sp)
    li r0, 2
    stw r0, +96(sp)
    ldw r0, +96(sp)
    nop    # espera load-use
    stw r0, +56(sp)
    li r0, 2
    stw r0, +132(sp)
    ldw r0, +132(sp)
    nop    # espera load-use
    stw r0, +52(sp)
    li r0, 0
    stw r0, +152(sp)
    ldw r0, +152(sp)
    nop    # espera load-use
    stw r0, +48(sp)
    li r0, 0
    stw r0, +156(sp)
    ldw r0, +156(sp)
    nop    # espera load-use
    stw r0, +44(sp)
multiplicacion_matrices_for_cond_1:    # addr=124
    ldw r0, +44(sp)
    ldw r1, +60(sp)
    li r2, 0
    blt r0, r1, 1    # -> multiplicacion_matrices_ir_cmp_true_1 @ 144
    jmp 1    # -> multiplicacion_matrices_ir_cmp_end_2 @ 148
multiplicacion_matrices_ir_cmp_true_1:    # addr=144
    li r2, 1
multiplicacion_matrices_ir_cmp_end_2:    # addr=148
    stw r2, +160(sp)
    ldw r2, +160(sp)
    nop    # espera load-use
    beqz r2, 133    # -> multiplicacion_matrices_for_end_3 @ 696
    li r2, 0
    stw r2, +164(sp)
    ldw r2, +164(sp)
    nop    # espera load-use
    stw r2, +36(sp)
multiplicacion_matrices_for_cond_4:    # addr=184
    ldw r2, +36(sp)
    ldw r0, +56(sp)
    li r1, 0
    blt r2, r0, 1    # -> multiplicacion_matrices_ir_cmp_true_3 @ 204
    jmp 1    # -> multiplicacion_matrices_ir_cmp_end_4 @ 208
multiplicacion_matrices_ir_cmp_true_3:    # addr=204
    li r1, 1
multiplicacion_matrices_ir_cmp_end_4:    # addr=208
    stw r1, +68(sp)
    ldw r1, +68(sp)
    nop    # espera load-use
    beqz r1, 107    # -> multiplicacion_matrices_for_end_6 @ 652
    li r1, 0
    stw r1, +72(sp)
    ldw r1, +72(sp)
    nop    # espera load-use
    stw r1, +28(sp)
    li r1, 0
    stw r1, +76(sp)
    ldw r1, +76(sp)
    nop    # espera load-use
    stw r1, +24(sp)
multiplicacion_matrices_for_cond_7:    # addr=264
    ldw r1, +24(sp)
    ldw r2, +52(sp)
    li r0, 0
    blt r1, r2, 1    # -> multiplicacion_matrices_ir_cmp_true_5 @ 284
    jmp 1    # -> multiplicacion_matrices_ir_cmp_end_6 @ 288
multiplicacion_matrices_ir_cmp_true_5:    # addr=284
    li r0, 1
multiplicacion_matrices_ir_cmp_end_6:    # addr=288
    stw r0, +80(sp)
    ldw r0, +80(sp)
    nop    # espera load-use
    beqz r0, 62    # -> multiplicacion_matrices_for_end_9 @ 552
    mov r0, p0
    ldw r1, +44(sp)
    mov r2, p2
    mul r1, r1, r2
    add r0, r0, r1
    stw r0, +84(sp)
    ldw r0, +84(sp)
    ldw r1, +24(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +88(sp)
    mov r0, p1
    ldw r1, +24(sp)
    mov r2, p3
    mul r1, r1, r2
    add r0, r0, r1
    stw r0, +92(sp)
    ldw r0, +92(sp)
    ldw r1, +36(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +100(sp)
    ldw r0, +88(sp)
    ldw r1, +100(sp)
    nop    # espera load-use
    mul r0, r0, r1
    stw r0, +104(sp)
    ldw r0, +28(sp)
    ldw r1, +104(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +108(sp)
    ldw r0, +108(sp)
    nop    # espera load-use
    stw r0, +28(sp)
    li r0, 1
    stw r0, +112(sp)
    ldw r0, +48(sp)
    ldw r1, +112(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +116(sp)
    ldw r0, +116(sp)
    nop    # espera load-use
    stw r0, +48(sp)
multiplicacion_matrices_for_update_8:    # addr=508
    li r0, 1
    stw r0, +120(sp)
    ldw r0, +24(sp)
    ldw r1, +120(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +124(sp)
    ldw r0, +124(sp)
    nop    # espera load-use
    stw r0, +24(sp)
    jmp -72    # -> multiplicacion_matrices_for_cond_7 @ 264
multiplicacion_matrices_for_end_9:    # addr=552
    la r0, 4
    ldw r1, +44(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +128(sp)
    ldw r0, +128(sp)
    ldw r1, +36(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +28(sp)
    nop    # espera load-use
    stw r1, +0(r0)
multiplicacion_matrices_for_update_5:    # addr=608
    li r0, 1
    stw r0, +136(sp)
    ldw r0, +36(sp)
    ldw r1, +136(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +140(sp)
    ldw r0, +140(sp)
    nop    # espera load-use
    stw r0, +36(sp)
    jmp -117    # -> multiplicacion_matrices_for_cond_4 @ 184
multiplicacion_matrices_for_end_6:    # addr=652
multiplicacion_matrices_for_update_2:    # addr=652
    li r0, 1
    stw r0, +144(sp)
    ldw r0, +44(sp)
    ldw r1, +144(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +148(sp)
    ldw r0, +148(sp)
    nop    # espera load-use
    stw r0, +44(sp)
    jmp -143    # -> multiplicacion_matrices_for_cond_1 @ 124
multiplicacion_matrices_for_end_3:    # addr=696
    la r0, 4
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -168
    ret
main:    # addr=720
    addi sp, sp, 172
    stw ra, +0(sp)
    li r0, 1
    stw r0, +40(sp)
    li r0, 0
    stw r0, +84(sp)
    addi r0, sp, 24
    ldw r1, +84(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +128(sp)
    li r0, 0
    stw r0, +148(sp)
    ldw r0, +128(sp)
    ldw r1, +148(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +40(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 2
    stw r0, +152(sp)
    li r0, 0
    stw r0, +156(sp)
    addi r0, sp, 24
    ldw r1, +156(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +160(sp)
    li r0, 1
    stw r0, +164(sp)
    ldw r0, +160(sp)
    ldw r1, +164(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +152(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 3
    stw r0, +168(sp)
    li r0, 1
    stw r0, +44(sp)
    addi r0, sp, 24
    ldw r1, +44(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +48(sp)
    li r0, 0
    stw r0, +52(sp)
    ldw r0, +48(sp)
    ldw r1, +52(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +168(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 4
    stw r0, +56(sp)
    li r0, 1
    stw r0, +60(sp)
    addi r0, sp, 24
    ldw r1, +60(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +64(sp)
    li r0, 1
    stw r0, +68(sp)
    ldw r0, +64(sp)
    ldw r1, +68(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +56(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 5
    stw r0, +72(sp)
    li r0, 0
    stw r0, +76(sp)
    addi r0, sp, 8
    ldw r1, +76(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +80(sp)
    li r0, 0
    stw r0, +88(sp)
    ldw r0, +80(sp)
    ldw r1, +88(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +72(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 6
    stw r0, +92(sp)
    li r0, 0
    stw r0, +96(sp)
    addi r0, sp, 8
    ldw r1, +96(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +100(sp)
    li r0, 1
    stw r0, +104(sp)
    ldw r0, +100(sp)
    ldw r1, +104(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +92(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 7
    stw r0, +108(sp)
    li r0, 1
    stw r0, +112(sp)
    addi r0, sp, 8
    ldw r1, +112(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +116(sp)
    li r0, 0
    stw r0, +120(sp)
    ldw r0, +116(sp)
    ldw r1, +120(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +108(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 8
    stw r0, +124(sp)
    li r0, 1
    stw r0, +132(sp)
    addi r0, sp, 8
    ldw r1, +132(sp)
    nop    # espera load-use
    muli r1, r1, 8
    add r0, r0, r1
    stw r0, +136(sp)
    li r0, 1
    stw r0, +140(sp)
    ldw r0, +136(sp)
    ldw r1, +140(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +124(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    addi r0, sp, 24
    addi r1, sp, 8
    li r2, 8
    li r3, 8
    mov p0, r0
    mov p1, r1
    mov p2, r2
    mov p3, r3
    call -347    # -> multiplicacion_matrices @ 16
    li r3, 0
    stw r3, +144(sp)
    ldw r3, +144(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r3
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
    ldw ra, +0(sp)
    addi sp, sp, -172
    ret
