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
    addi sp, sp, 552
    stw ra, +0(sp)
    li r0, 0
    stw r0, +144(sp)
    ldw r0, +144(sp)
    stw r0, +100(sp)
    li r0, 2
    stw r0, +188(sp)
    li r0, 0
    stw r0, +400(sp)
    addi r0, sp, 68
    ldw r1, +400(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +188(sp)
    stw r1, +0(r0)
    li r0, 4
    stw r0, +472(sp)
    li r0, 1
    stw r0, +516(sp)
    addi r0, sp, 68
    ldw r1, +516(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +472(sp)
    stw r1, +0(r0)
    li r0, 6
    stw r0, +536(sp)
    li r0, 2
    stw r0, +540(sp)
    addi r0, sp, 68
    ldw r1, +540(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +536(sp)
    stw r1, +0(r0)
    li r0, 8
    stw r0, +544(sp)
    li r0, 3
    stw r0, +548(sp)
    addi r0, sp, 68
    ldw r1, +548(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +544(sp)
    stw r1, +0(r0)
    li r0, 10
    stw r0, +104(sp)
    li r0, 4
    stw r0, +108(sp)
    addi r0, sp, 68
    ldw r1, +108(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +104(sp)
    stw r1, +0(r0)
    li r0, 12
    stw r0, +112(sp)
    li r0, 5
    stw r0, +116(sp)
    addi r0, sp, 68
    ldw r1, +116(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +112(sp)
    stw r1, +0(r0)
    li r0, 14
    stw r0, +120(sp)
    li r0, 6
    stw r0, +124(sp)
    addi r0, sp, 68
    ldw r1, +124(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +120(sp)
    stw r1, +0(r0)
    li r0, 16
    stw r0, +128(sp)
    li r0, 7
    stw r0, +132(sp)
    addi r0, sp, 68
    ldw r1, +132(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +128(sp)
    stw r1, +0(r0)
    li r0, 1
    stw r0, +136(sp)
    li r0, 0
    stw r0, +140(sp)
    addi r0, sp, 36
    ldw r1, +140(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +136(sp)
    stw r1, +0(r0)
    li r0, 3
    stw r0, +148(sp)
    li r0, 1
    stw r0, +152(sp)
    addi r0, sp, 36
    ldw r1, +152(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +148(sp)
    stw r1, +0(r0)
    li r0, 5
    stw r0, +156(sp)
    li r0, 2
    stw r0, +160(sp)
    addi r0, sp, 36
    ldw r1, +160(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +156(sp)
    stw r1, +0(r0)
    li r0, 7
    stw r0, +164(sp)
    li r0, 3
    stw r0, +168(sp)
    addi r0, sp, 36
    ldw r1, +168(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +164(sp)
    stw r1, +0(r0)
    li r0, 9
    stw r0, +172(sp)
    li r0, 4
    stw r0, +176(sp)
    addi r0, sp, 36
    ldw r1, +176(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +172(sp)
    stw r1, +0(r0)
    li r0, 11
    stw r0, +180(sp)
    li r0, 5
    stw r0, +184(sp)
    addi r0, sp, 36
    ldw r1, +184(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +180(sp)
    stw r1, +0(r0)
    li r0, 13
    stw r0, +192(sp)
    li r0, 6
    stw r0, +196(sp)
    addi r0, sp, 36
    ldw r1, +196(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +192(sp)
    stw r1, +0(r0)
    li r0, 15
    stw r0, +200(sp)
    li r0, 7
    stw r0, +204(sp)
    addi r0, sp, 36
    ldw r1, +204(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +200(sp)
    stw r1, +0(r0)
main_while_cond_1:    # addr=688
    li r0, 8
    stw r0, +208(sp)
    ldw r0, +100(sp)
    ldw r1, +208(sp)
    li r2, 0
    blt r0, r1, 1    # -> main_ir_cmp_true_1 @ 716
    jmp 1    # -> main_ir_cmp_end_2 @ 720
main_ir_cmp_true_1:    # addr=716
    li r2, 1
main_ir_cmp_end_2:    # addr=720
    stw r2, +240(sp)
    ldw r2, +240(sp)
    beqz r2, 318    # -> main_while_end_2 @ 2004
    addi r2, sp, 68
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +272(sp)
    addi r2, sp, 36
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +304(sp)
    ldw r2, +272(sp)
    ldw r0, +304(sp)
    add r2, r2, r0
    stw r2, +336(sp)
    addi r2, sp, 4
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +336(sp)
    stw r0, +0(r2)
    li r2, 1
    stw r2, +368(sp)
    ldw r2, +100(sp)
    ldw r0, +368(sp)
    add r2, r2, r0
    stw r2, +404(sp)
    ldw r2, +404(sp)
    stw r2, +100(sp)
    li r2, 8
    stw r2, +212(sp)
    ldw r2, +100(sp)
    ldw r0, +212(sp)
    li r1, 0
    blt r2, r0, 1    # -> main_ir_cmp_true_3 @ 880
    jmp 1    # -> main_ir_cmp_end_4 @ 884
main_ir_cmp_true_3:    # addr=880
    li r1, 1
main_ir_cmp_end_4:    # addr=884
    stw r1, +244(sp)
    ldw r1, +244(sp)
    beqz r1, 277    # -> main_while_end_2 @ 2004
    addi r1, sp, 68
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +276(sp)
    addi r1, sp, 36
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +308(sp)
    ldw r1, +276(sp)
    ldw r2, +308(sp)
    add r1, r1, r2
    stw r1, +340(sp)
    addi r1, sp, 4
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +340(sp)
    stw r2, +0(r1)
    li r1, 1
    stw r1, +372(sp)
    ldw r1, +100(sp)
    ldw r2, +372(sp)
    add r1, r1, r2
    stw r1, +408(sp)
    ldw r1, +408(sp)
    stw r1, +100(sp)
    li r1, 8
    stw r1, +216(sp)
    ldw r1, +100(sp)
    ldw r2, +216(sp)
    li r0, 0
    blt r1, r2, 1    # -> main_ir_cmp_true_5 @ 1044
    jmp 1    # -> main_ir_cmp_end_6 @ 1048
main_ir_cmp_true_5:    # addr=1044
    li r0, 1
main_ir_cmp_end_6:    # addr=1048
    stw r0, +248(sp)
    ldw r0, +248(sp)
    beqz r0, 236    # -> main_while_end_2 @ 2004
    addi r0, sp, 68
    ldw r1, +100(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    stw r1, +280(sp)
    addi r0, sp, 36
    ldw r1, +100(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    stw r1, +312(sp)
    ldw r0, +280(sp)
    ldw r1, +312(sp)
    add r0, r0, r1
    stw r0, +344(sp)
    addi r0, sp, 4
    ldw r1, +100(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +344(sp)
    stw r1, +0(r0)
    li r0, 1
    stw r0, +376(sp)
    ldw r0, +100(sp)
    ldw r1, +376(sp)
    add r0, r0, r1
    stw r0, +412(sp)
    ldw r0, +412(sp)
    stw r0, +100(sp)
    li r0, 8
    stw r0, +220(sp)
    ldw r0, +100(sp)
    ldw r1, +220(sp)
    li r2, 0
    blt r0, r1, 1    # -> main_ir_cmp_true_7 @ 1208
    jmp 1    # -> main_ir_cmp_end_8 @ 1212
main_ir_cmp_true_7:    # addr=1208
    li r2, 1
main_ir_cmp_end_8:    # addr=1212
    stw r2, +252(sp)
    ldw r2, +252(sp)
    beqz r2, 195    # -> main_while_end_2 @ 2004
    addi r2, sp, 68
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +284(sp)
    addi r2, sp, 36
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +316(sp)
    ldw r2, +284(sp)
    ldw r0, +316(sp)
    add r2, r2, r0
    stw r2, +348(sp)
    addi r2, sp, 4
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +348(sp)
    stw r0, +0(r2)
    li r2, 1
    stw r2, +380(sp)
    ldw r2, +100(sp)
    ldw r0, +380(sp)
    add r2, r2, r0
    stw r2, +416(sp)
    ldw r2, +416(sp)
    stw r2, +100(sp)
    li r2, 8
    stw r2, +224(sp)
    ldw r2, +100(sp)
    ldw r0, +224(sp)
    li r1, 0
    blt r2, r0, 1    # -> main_ir_cmp_true_9 @ 1372
    jmp 1    # -> main_ir_cmp_end_10 @ 1376
main_ir_cmp_true_9:    # addr=1372
    li r1, 1
main_ir_cmp_end_10:    # addr=1376
    stw r1, +256(sp)
    ldw r1, +256(sp)
    beqz r1, 154    # -> main_while_end_2 @ 2004
    addi r1, sp, 68
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +288(sp)
    addi r1, sp, 36
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +320(sp)
    ldw r1, +288(sp)
    ldw r2, +320(sp)
    add r1, r1, r2
    stw r1, +352(sp)
    addi r1, sp, 4
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +352(sp)
    stw r2, +0(r1)
    li r1, 1
    stw r1, +384(sp)
    ldw r1, +100(sp)
    ldw r2, +384(sp)
    add r1, r1, r2
    stw r1, +420(sp)
    ldw r1, +420(sp)
    stw r1, +100(sp)
    li r1, 8
    stw r1, +228(sp)
    ldw r1, +100(sp)
    ldw r2, +228(sp)
    li r0, 0
    blt r1, r2, 1    # -> main_ir_cmp_true_11 @ 1536
    jmp 1    # -> main_ir_cmp_end_12 @ 1540
main_ir_cmp_true_11:    # addr=1536
    li r0, 1
main_ir_cmp_end_12:    # addr=1540
    stw r0, +260(sp)
    ldw r0, +260(sp)
    beqz r0, 113    # -> main_while_end_2 @ 2004
    addi r0, sp, 68
    ldw r1, +100(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    stw r1, +292(sp)
    addi r0, sp, 36
    ldw r1, +100(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    stw r1, +324(sp)
    ldw r0, +292(sp)
    ldw r1, +324(sp)
    add r0, r0, r1
    stw r0, +356(sp)
    addi r0, sp, 4
    ldw r1, +100(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +356(sp)
    stw r1, +0(r0)
    li r0, 1
    stw r0, +388(sp)
    ldw r0, +100(sp)
    ldw r1, +388(sp)
    add r0, r0, r1
    stw r0, +424(sp)
    ldw r0, +424(sp)
    stw r0, +100(sp)
    li r0, 8
    stw r0, +232(sp)
    ldw r0, +100(sp)
    ldw r1, +232(sp)
    li r2, 0
    blt r0, r1, 1    # -> main_ir_cmp_true_13 @ 1700
    jmp 1    # -> main_ir_cmp_end_14 @ 1704
main_ir_cmp_true_13:    # addr=1700
    li r2, 1
main_ir_cmp_end_14:    # addr=1704
    stw r2, +264(sp)
    ldw r2, +264(sp)
    beqz r2, 72    # -> main_while_end_2 @ 2004
    addi r2, sp, 68
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +296(sp)
    addi r2, sp, 36
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +328(sp)
    ldw r2, +296(sp)
    ldw r0, +328(sp)
    add r2, r2, r0
    stw r2, +360(sp)
    addi r2, sp, 4
    ldw r0, +100(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +360(sp)
    stw r0, +0(r2)
    li r2, 1
    stw r2, +392(sp)
    ldw r2, +100(sp)
    ldw r0, +392(sp)
    add r2, r2, r0
    stw r2, +428(sp)
    ldw r2, +428(sp)
    stw r2, +100(sp)
    li r2, 8
    stw r2, +236(sp)
    ldw r2, +100(sp)
    ldw r0, +236(sp)
    li r1, 0
    blt r2, r0, 1    # -> main_ir_cmp_true_15 @ 1864
    jmp 1    # -> main_ir_cmp_end_16 @ 1868
main_ir_cmp_true_15:    # addr=1864
    li r1, 1
main_ir_cmp_end_16:    # addr=1868
    stw r1, +268(sp)
    ldw r1, +268(sp)
    beqz r1, 31    # -> main_while_end_2 @ 2004
    addi r1, sp, 68
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +300(sp)
    addi r1, sp, 36
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +332(sp)
    ldw r1, +300(sp)
    ldw r2, +332(sp)
    add r1, r1, r2
    stw r1, +364(sp)
    addi r1, sp, 4
    ldw r2, +100(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +364(sp)
    stw r2, +0(r1)
    li r1, 1
    stw r1, +396(sp)
    ldw r1, +100(sp)
    ldw r2, +396(sp)
    add r1, r1, r2
    stw r1, +432(sp)
    ldw r1, +432(sp)
    stw r1, +100(sp)
    jmp -329    # -> main_while_cond_1 @ 688
main_while_end_2:    # addr=2004
    li r1, 0
    stw r1, +436(sp)
    addi r1, sp, 4
    ldw r2, +436(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +440(sp)
    li r1, 1
    stw r1, +444(sp)
    addi r1, sp, 4
    ldw r2, +444(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +448(sp)
    ldw r1, +440(sp)
    ldw r2, +448(sp)
    add r1, r1, r2
    stw r1, +452(sp)
    li r1, 2
    stw r1, +456(sp)
    addi r1, sp, 4
    ldw r2, +456(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +460(sp)
    ldw r1, +452(sp)
    ldw r2, +460(sp)
    add r1, r1, r2
    stw r1, +464(sp)
    li r1, 3
    stw r1, +468(sp)
    addi r1, sp, 4
    ldw r2, +468(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +476(sp)
    ldw r1, +464(sp)
    ldw r2, +476(sp)
    add r1, r1, r2
    stw r1, +480(sp)
    li r1, 4
    stw r1, +484(sp)
    addi r1, sp, 4
    ldw r2, +484(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +488(sp)
    ldw r1, +480(sp)
    ldw r2, +488(sp)
    add r1, r1, r2
    stw r1, +492(sp)
    li r1, 5
    stw r1, +496(sp)
    addi r1, sp, 4
    ldw r2, +496(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +500(sp)
    ldw r1, +492(sp)
    ldw r2, +500(sp)
    add r1, r1, r2
    stw r1, +504(sp)
    li r1, 6
    stw r1, +508(sp)
    addi r1, sp, 4
    ldw r2, +508(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +512(sp)
    ldw r1, +504(sp)
    ldw r2, +512(sp)
    add r1, r1, r2
    stw r1, +520(sp)
    li r1, 7
    stw r1, +524(sp)
    addi r1, sp, 4
    ldw r2, +524(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +528(sp)
    ldw r1, +520(sp)
    ldw r2, +528(sp)
    add r1, r1, r2
    stw r1, +532(sp)
    ldw r1, +532(sp)
    la r2, 4
    stw r1, +0(r2)
    la r2, 4
    ldw r1, +0(r2)
    nop    # espera valor antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -552
    ret
