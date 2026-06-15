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
    addi sp, sp, 572
    stw ra, +0(sp)
    li r0, 16
    stw r0, +184(sp)
    ldw r0, +184(sp)
    stw r0, +140(sp)
    li r0, 2
    stw r0, +228(sp)
    ldw r0, +228(sp)
    stw r0, +136(sp)
    li r0, 20
    stw r0, +272(sp)
    li r0, 0
    stw r0, +352(sp)
    addi r0, sp, 72
    ldw r1, +352(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +272(sp)
    stw r1, +0(r0)
    li r0, 18
    stw r0, +400(sp)
    li r0, 1
    stw r0, +444(sp)
    addi r0, sp, 72
    ldw r1, +444(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +400(sp)
    stw r1, +0(r0)
    li r0, 22
    stw r0, +488(sp)
    li r0, 2
    stw r0, +532(sp)
    addi r0, sp, 72
    ldw r1, +532(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +488(sp)
    stw r1, +0(r0)
    li r0, 25
    stw r0, +568(sp)
    li r0, 3
    stw r0, +144(sp)
    addi r0, sp, 72
    ldw r1, +144(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +568(sp)
    stw r1, +0(r0)
    li r0, 27
    stw r0, +148(sp)
    li r0, 4
    stw r0, +152(sp)
    addi r0, sp, 72
    ldw r1, +152(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +148(sp)
    stw r1, +0(r0)
    li r0, 24
    stw r0, +156(sp)
    li r0, 5
    stw r0, +160(sp)
    addi r0, sp, 72
    ldw r1, +160(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +156(sp)
    stw r1, +0(r0)
    li r0, 30
    stw r0, +164(sp)
    li r0, 6
    stw r0, +168(sp)
    addi r0, sp, 72
    ldw r1, +168(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +164(sp)
    stw r1, +0(r0)
    li r0, 32
    stw r0, +172(sp)
    li r0, 7
    stw r0, +176(sp)
    addi r0, sp, 72
    ldw r1, +176(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +172(sp)
    stw r1, +0(r0)
    li r0, 29
    stw r0, +180(sp)
    li r0, 8
    stw r0, +188(sp)
    addi r0, sp, 72
    ldw r1, +188(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +180(sp)
    stw r1, +0(r0)
    li r0, 31
    stw r0, +192(sp)
    li r0, 9
    stw r0, +196(sp)
    addi r0, sp, 72
    ldw r1, +196(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +192(sp)
    stw r1, +0(r0)
    li r0, 35
    stw r0, +200(sp)
    li r0, 10
    stw r0, +204(sp)
    addi r0, sp, 72
    ldw r1, +204(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +200(sp)
    stw r1, +0(r0)
    li r0, 33
    stw r0, +208(sp)
    li r0, 11
    stw r0, +212(sp)
    addi r0, sp, 72
    ldw r1, +212(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +208(sp)
    stw r1, +0(r0)
    li r0, 37
    stw r0, +216(sp)
    li r0, 12
    stw r0, +220(sp)
    addi r0, sp, 72
    ldw r1, +220(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +216(sp)
    stw r1, +0(r0)
    li r0, 40
    stw r0, +224(sp)
    li r0, 13
    stw r0, +232(sp)
    addi r0, sp, 72
    ldw r1, +232(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +224(sp)
    stw r1, +0(r0)
    li r0, 38
    stw r0, +236(sp)
    li r0, 14
    stw r0, +240(sp)
    addi r0, sp, 72
    ldw r1, +240(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +236(sp)
    stw r1, +0(r0)
    li r0, 42
    stw r0, +244(sp)
    li r0, 15
    stw r0, +248(sp)
    addi r0, sp, 72
    ldw r1, +248(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +244(sp)
    stw r1, +0(r0)
    li r0, 0
    stw r0, +252(sp)
    addi r0, sp, 72
    ldw r1, +252(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    stw r1, +256(sp)
    li r0, 0
    stw r0, +260(sp)
    addi r0, sp, 8
    ldw r1, +260(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +256(sp)
    stw r1, +0(r0)
    li r0, 1
    stw r0, +264(sp)
    addi r0, sp, 72
    ldw r1, +264(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +0(r0)
    stw r1, +268(sp)
    li r0, 1
    stw r0, +276(sp)
    addi r0, sp, 8
    ldw r1, +276(sp)
    muli r1, r1, 4
    add r0, r0, r1
    ldw r1, +268(sp)
    stw r1, +0(r0)
main_while_cond_1:    # addr=832
    ldw r0, +136(sp)
    ldw r1, +140(sp)
    li r2, 0
    blt r0, r1, 1    # -> main_ir_cmp_true_1 @ 852
    jmp 1    # -> main_ir_cmp_end_2 @ 856
main_ir_cmp_true_1:    # addr=852
    li r2, 1
main_ir_cmp_end_2:    # addr=856
    stw r2, +280(sp)
    ldw r2, +280(sp)
    beqz r2, 94    # -> main_while_end_2 @ 1244
    addi r2, sp, 72
    ldw r0, +136(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +288(sp)
    li r2, 2
    stw r2, +296(sp)
    ldw r2, +136(sp)
    ldw r0, +296(sp)
    sub r2, r2, r0
    stw r2, +304(sp)
    addi r2, sp, 8
    ldw r0, +304(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +0(r2)
    stw r0, +312(sp)
    li r2, 2
    stw r2, +320(sp)
    ldw r2, +312(sp)
    ldw r0, +320(sp)
    div r2, r2, r0
    stw r2, +328(sp)
    ldw r2, +288(sp)
    ldw r0, +328(sp)
    add r2, r2, r0
    stw r2, +336(sp)
    addi r2, sp, 8
    ldw r0, +136(sp)
    muli r0, r0, 4
    add r2, r2, r0
    ldw r0, +336(sp)
    stw r0, +0(r2)
    li r2, 1
    stw r2, +344(sp)
    ldw r2, +136(sp)
    ldw r0, +344(sp)
    add r2, r2, r0
    stw r2, +356(sp)
    ldw r2, +356(sp)
    stw r2, +136(sp)
    ldw r2, +136(sp)
    ldw r0, +140(sp)
    li r1, 0
    blt r2, r0, 1    # -> main_ir_cmp_true_3 @ 1056
    jmp 1    # -> main_ir_cmp_end_4 @ 1060
main_ir_cmp_true_3:    # addr=1056
    li r1, 1
main_ir_cmp_end_4:    # addr=1060
    stw r1, +284(sp)
    ldw r1, +284(sp)
    beqz r1, 43    # -> main_while_end_2 @ 1244
    addi r1, sp, 72
    ldw r2, +136(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +292(sp)
    li r1, 2
    stw r1, +300(sp)
    ldw r1, +136(sp)
    ldw r2, +300(sp)
    sub r1, r1, r2
    stw r1, +308(sp)
    addi r1, sp, 8
    ldw r2, +308(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +316(sp)
    li r1, 2
    stw r1, +324(sp)
    ldw r1, +316(sp)
    ldw r2, +324(sp)
    div r1, r1, r2
    stw r1, +332(sp)
    ldw r1, +292(sp)
    ldw r2, +332(sp)
    add r1, r1, r2
    stw r1, +340(sp)
    addi r1, sp, 8
    ldw r2, +136(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +340(sp)
    stw r2, +0(r1)
    li r1, 1
    stw r1, +348(sp)
    ldw r1, +136(sp)
    ldw r2, +348(sp)
    add r1, r1, r2
    stw r1, +360(sp)
    ldw r1, +360(sp)
    stw r1, +136(sp)
    jmp -103    # -> main_while_cond_1 @ 832
main_while_end_2:    # addr=1244
    li r1, 0
    stw r1, +364(sp)
    addi r1, sp, 8
    ldw r2, +364(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +368(sp)
    li r1, 1
    stw r1, +372(sp)
    addi r1, sp, 8
    ldw r2, +372(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +376(sp)
    ldw r1, +368(sp)
    ldw r2, +376(sp)
    add r1, r1, r2
    stw r1, +380(sp)
    li r1, 2
    stw r1, +384(sp)
    addi r1, sp, 8
    ldw r2, +384(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +388(sp)
    ldw r1, +380(sp)
    ldw r2, +388(sp)
    add r1, r1, r2
    stw r1, +392(sp)
    li r1, 3
    stw r1, +396(sp)
    addi r1, sp, 8
    ldw r2, +396(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +404(sp)
    ldw r1, +392(sp)
    ldw r2, +404(sp)
    add r1, r1, r2
    stw r1, +408(sp)
    li r1, 4
    stw r1, +412(sp)
    addi r1, sp, 8
    ldw r2, +412(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +416(sp)
    ldw r1, +408(sp)
    ldw r2, +416(sp)
    add r1, r1, r2
    stw r1, +420(sp)
    li r1, 5
    stw r1, +424(sp)
    addi r1, sp, 8
    ldw r2, +424(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +428(sp)
    ldw r1, +420(sp)
    ldw r2, +428(sp)
    add r1, r1, r2
    stw r1, +432(sp)
    li r1, 6
    stw r1, +436(sp)
    addi r1, sp, 8
    ldw r2, +436(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +440(sp)
    ldw r1, +432(sp)
    ldw r2, +440(sp)
    add r1, r1, r2
    stw r1, +448(sp)
    li r1, 7
    stw r1, +452(sp)
    addi r1, sp, 8
    ldw r2, +452(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +456(sp)
    ldw r1, +448(sp)
    ldw r2, +456(sp)
    add r1, r1, r2
    stw r1, +460(sp)
    li r1, 8
    stw r1, +464(sp)
    addi r1, sp, 8
    ldw r2, +464(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +468(sp)
    ldw r1, +460(sp)
    ldw r2, +468(sp)
    add r1, r1, r2
    stw r1, +472(sp)
    li r1, 9
    stw r1, +476(sp)
    addi r1, sp, 8
    ldw r2, +476(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +480(sp)
    ldw r1, +472(sp)
    ldw r2, +480(sp)
    add r1, r1, r2
    stw r1, +484(sp)
    li r1, 10
    stw r1, +492(sp)
    addi r1, sp, 8
    ldw r2, +492(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +496(sp)
    ldw r1, +484(sp)
    ldw r2, +496(sp)
    add r1, r1, r2
    stw r1, +500(sp)
    li r1, 11
    stw r1, +504(sp)
    addi r1, sp, 8
    ldw r2, +504(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +508(sp)
    ldw r1, +500(sp)
    ldw r2, +508(sp)
    add r1, r1, r2
    stw r1, +512(sp)
    li r1, 12
    stw r1, +516(sp)
    addi r1, sp, 8
    ldw r2, +516(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +520(sp)
    ldw r1, +512(sp)
    ldw r2, +520(sp)
    add r1, r1, r2
    stw r1, +524(sp)
    li r1, 13
    stw r1, +528(sp)
    addi r1, sp, 8
    ldw r2, +528(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +536(sp)
    ldw r1, +524(sp)
    ldw r2, +536(sp)
    add r1, r1, r2
    stw r1, +540(sp)
    li r1, 14
    stw r1, +544(sp)
    addi r1, sp, 8
    ldw r2, +544(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +548(sp)
    ldw r1, +540(sp)
    ldw r2, +548(sp)
    add r1, r1, r2
    stw r1, +552(sp)
    li r1, 15
    stw r1, +556(sp)
    addi r1, sp, 8
    ldw r2, +556(sp)
    muli r2, r2, 4
    add r1, r1, r2
    ldw r2, +0(r1)
    stw r2, +560(sp)
    ldw r1, +552(sp)
    ldw r2, +560(sp)
    add r1, r1, r2
    stw r1, +564(sp)
    ldw r1, +564(sp)
    stw r1, +4(sp)
    ldw r1, +4(sp)
    la r2, 4
    stw r1, +0(r2)
    la r2, 4
    ldw r1, +0(r2)
    nop    # espera valor antes de mover retorno
    mov p0, r1
    ldw ra, +0(sp)
    addi sp, sp, -572
    ret
    end
