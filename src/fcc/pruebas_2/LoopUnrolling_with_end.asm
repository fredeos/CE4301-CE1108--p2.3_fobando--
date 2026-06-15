; Codigo ensamblador generado por FCC
; Backend: IR TAC
__init__:    # addr=0
    li sp, 8
    mov p0, zero    # resultado de programa por defecto
    call 261    # entrada principal | -> main @ 1056
    nop    # relleno antes de end
    nop    # relleno antes de end
    nop    # relleno antes de end
    end    # fin real del programa tras retornar de main
__end_fallback__:    # addr=28
    jmp -1    # respaldo si end se interpreta como nop | -> __end_fallback__ @ 28
procesar_bloques:    # addr=32
    addi sp, sp, 204
    stw ra, +0(sp)
    li r0, 0
    stw r0, +40(sp)
    ldw r0, +40(sp)
    nop    # espera load-use
    stw r0, +12(sp)
    li r0, 0
    stw r0, +92(sp)
    ldw r0, +92(sp)
    nop    # espera load-use
    stw r0, +8(sp)
    li r0, 0
    stw r0, +128(sp)
    ldw r0, +128(sp)
    nop    # espera load-use
    stw r0, +8(sp)
procesar_bloques_while_cond_1:    # addr=100
    li r0, 6
    stw r0, +132(sp)
    ldw r0, +8(sp)
    ldw r1, +132(sp)
    li r2, 0
    blt r0, r1, 1    # -> procesar_bloques_ir_cmp_true_1 @ 128
    jmp 1    # -> procesar_bloques_ir_cmp_end_2 @ 132
procesar_bloques_ir_cmp_true_1:    # addr=128
    li r2, 1
procesar_bloques_ir_cmp_end_2:    # addr=132
    stw r2, +144(sp)
    ldw r2, +144(sp)
    nop    # espera load-use
    beqz r2, 124    # -> procesar_bloques_while_end_2 @ 644
    mov r2, p0
    ldw r0, +8(sp)
    nop    # espera load-use
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    nop    # espera load-use
    stw r0, +156(sp)
    li r2, 2
    stw r2, +168(sp)
    ldw r2, +156(sp)
    ldw r0, +168(sp)
    nop    # espera load-use
    mul r2, r2, r0
    stw r2, +180(sp)
    addi r2, sp, 16
    ldw r0, +8(sp)
    nop    # espera load-use
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +180(sp)
    nop    # espera load-use
    stw r0, +0(r2)
    li r2, 1
    stw r2, +192(sp)
    ldw r2, +8(sp)
    ldw r0, +192(sp)
    nop    # espera load-use
    add r2, r2, r0
    stw r2, +44(sp)
    ldw r2, +44(sp)
    nop    # espera load-use
    stw r2, +8(sp)
    li r2, 6
    stw r2, +136(sp)
    ldw r2, +8(sp)
    ldw r0, +136(sp)
    li r1, 0
    blt r2, r0, 1    # -> procesar_bloques_ir_cmp_true_3 @ 308
    jmp 1    # -> procesar_bloques_ir_cmp_end_4 @ 312
procesar_bloques_ir_cmp_true_3:    # addr=308
    li r1, 1
procesar_bloques_ir_cmp_end_4:    # addr=312
    stw r1, +148(sp)
    ldw r1, +148(sp)
    nop    # espera load-use
    beqz r1, 79    # -> procesar_bloques_while_end_2 @ 644
    mov r1, p0
    ldw r2, +8(sp)
    nop    # espera load-use
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    nop    # espera load-use
    stw r2, +160(sp)
    li r1, 2
    stw r1, +172(sp)
    ldw r1, +160(sp)
    ldw r2, +172(sp)
    nop    # espera load-use
    mul r1, r1, r2
    stw r1, +184(sp)
    addi r1, sp, 16
    ldw r2, +8(sp)
    nop    # espera load-use
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +184(sp)
    nop    # espera load-use
    stw r2, +0(r1)
    li r1, 1
    stw r1, +196(sp)
    ldw r1, +8(sp)
    ldw r2, +196(sp)
    nop    # espera load-use
    add r1, r1, r2
    stw r1, +48(sp)
    ldw r1, +48(sp)
    nop    # espera load-use
    stw r1, +8(sp)
    li r1, 6
    stw r1, +140(sp)
    ldw r1, +8(sp)
    ldw r2, +140(sp)
    li r0, 0
    blt r1, r2, 1    # -> procesar_bloques_ir_cmp_true_5 @ 488
    jmp 1    # -> procesar_bloques_ir_cmp_end_6 @ 492
procesar_bloques_ir_cmp_true_5:    # addr=488
    li r0, 1
procesar_bloques_ir_cmp_end_6:    # addr=492
    stw r0, +152(sp)
    ldw r0, +152(sp)
    nop    # espera load-use
    beqz r0, 34    # -> procesar_bloques_while_end_2 @ 644
    mov r0, p0
    ldw r1, +8(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +164(sp)
    li r0, 2
    stw r0, +176(sp)
    ldw r0, +164(sp)
    ldw r1, +176(sp)
    nop    # espera load-use
    mul r0, r0, r1
    stw r0, +188(sp)
    addi r0, sp, 16
    ldw r1, +8(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +188(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 1
    stw r0, +200(sp)
    ldw r0, +8(sp)
    ldw r1, +200(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +52(sp)
    ldw r0, +52(sp)
    nop    # espera load-use
    stw r0, +8(sp)
    jmp -136    # -> procesar_bloques_while_cond_1 @ 100
procesar_bloques_while_end_2:    # addr=644
    li r0, 0
    stw r0, +56(sp)
    addi r0, sp, 16
    ldw r1, +56(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +60(sp)
    li r0, 1
    stw r0, +64(sp)
    addi r0, sp, 16
    ldw r1, +64(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +68(sp)
    ldw r0, +60(sp)
    ldw r1, +68(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +72(sp)
    li r0, 2
    stw r0, +76(sp)
    addi r0, sp, 16
    ldw r1, +76(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +80(sp)
    ldw r0, +72(sp)
    ldw r1, +80(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +84(sp)
    ldw r0, +84(sp)
    nop    # espera load-use
    stw r0, +12(sp)
    li r0, 3
    stw r0, +88(sp)
    addi r0, sp, 16
    ldw r1, +88(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +96(sp)
    ldw r0, +12(sp)
    ldw r1, +96(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +100(sp)
    ldw r0, +100(sp)
    nop    # espera load-use
    stw r0, +12(sp)
    li r0, 4
    stw r0, +104(sp)
    addi r0, sp, 16
    ldw r1, +104(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +108(sp)
    ldw r0, +12(sp)
    ldw r1, +108(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +112(sp)
    ldw r0, +112(sp)
    nop    # espera load-use
    stw r0, +12(sp)
    li r0, 5
    stw r0, +116(sp)
    addi r0, sp, 16
    ldw r1, +116(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    nop    # espera load-use
    stw r1, +120(sp)
    ldw r0, +12(sp)
    ldw r1, +120(sp)
    nop    # espera load-use
    add r0, r0, r1
    stw r0, +124(sp)
    ldw r0, +124(sp)
    nop    # espera load-use
    stw r0, +12(sp)
    ldw r0, +12(sp)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    ldw ra, +0(sp)
    addi sp, sp, -204
    ret
main:    # addr=1056
    addi sp, sp, 84
    stw ra, +0(sp)
    li r0, 10
    stw r0, +32(sp)
    li r0, 0
    stw r0, +52(sp)
    addi r0, sp, 8
    ldw r1, +52(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +32(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 20
    stw r0, +56(sp)
    li r0, 1
    stw r0, +60(sp)
    addi r0, sp, 8
    ldw r1, +60(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +56(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 30
    stw r0, +64(sp)
    li r0, 2
    stw r0, +68(sp)
    addi r0, sp, 8
    ldw r1, +68(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +64(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 5
    stw r0, +72(sp)
    li r0, 3
    stw r0, +76(sp)
    addi r0, sp, 8
    ldw r1, +76(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +72(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 15
    stw r0, +80(sp)
    li r0, 4
    stw r0, +36(sp)
    addi r0, sp, 8
    ldw r1, +36(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +80(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    li r0, 25
    stw r0, +40(sp)
    li r0, 5
    stw r0, +44(sp)
    addi r0, sp, 8
    ldw r1, +44(sp)
    nop    # espera load-use
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +40(sp)
    nop    # espera load-use
    stw r1, +0(r0)
    addi r0, sp, 8
    mov p0, r0
    call -333    # -> procesar_bloques @ 32
    nop    # espera retorno de call antes de leer p0
    mov r0, p0
    stw r0, +48(sp)
    ldw r0, +48(sp)
    la r1, 4
    stw r0, +0(r1)
    la r1, 4
    ldw r0, +0(r1)
    nop    # espera valor antes de mover retorno
    mov p0, r0
    la r0, 0    # celda de resultado del programa
    stw p0, +0(r0)    # guardar resultado final
    ldw ra, +0(sp)
    addi sp, sp, -84
    ret
