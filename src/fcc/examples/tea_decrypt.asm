; Codigo ensamblador generado por FCC
; ISA base: F32IS (isa.md)
__init__:    # addr=0
    li sp, 8
    call 114    # entrada principal | -> main @ 464
__halt__:    # addr=8
    jmp -1    # -> __halt__ @ 8
tea_decrypt_file:    # addr=12
    addi sp, sp, 28
    stw ra, +0(sp)
    login 0xA9C1F
    beqz lr, 105    # -> tea_decrypt_file_secure_exit_1 @ 448
    pmovi r1, 0
    @ldw r0, +0(r1)
    @stw r0, +24(sp)
    pmovi bx, 0
    @stw r0, +20(sp)
tea_decrypt_file_for_cond_2:    # addr=48
    @ldw r0, +20(sp)
    pmovi r2, 4
    @ldw r1, +0(r2)
    @bge r0, r1, 96    # -> tea_decrypt_file_for_end_4 @ 448
    @ldw r2, +24(sp)
    paddi dx, dx, 0
    pmovi cx, 0
    padd cx, cx, dx
    @ldw r0, +0(r1)
    @stw r0, +16(sp)
    @ldw r2, +24(sp)
    paddi dx, dx, 4
    pmovi cx, 0
    padd cx, cx, dx
    @ldw r0, +0(r1)
    @stw r0, +12(sp)
    send bx, delta
    @slli r0, r0, 5
    @stw r0, +8(sp)
    pmovi bx, 0
    @stw r0, +4(sp)
tea_decrypt_file_for_cond_5:    # addr=132
    @ldw r0, +4(sp)
    pmovi cx, 32
    @bge r0, r1, 55    # -> tea_decrypt_file_for_end_7 @ 364
    @ldw r0, +16(sp)
    pmovi cx, 4
    pmovi ex, 0
    pmovi fx, 2
    pmuli fx, fx, 4
    padd ex, ex, fx
    ldvw dx, +0(ex)
    pslladd bx, bx, cx, dx
    @ldw r1, +16(sp)
    @ldw r2, +8(sp)
    padd cx, cx, dx
    @ldw r2, +16(sp)
    pmovi ex, 5
    pmovi gx, 0
    pmovi hx, 3
    pmuli hx, hx, 4
    padd gx, gx, hx
    ldvw fx, +0(gx)
    psrladd dx, dx, ex, fx
    pxorxor bx, bx, cx, dx
    @ldw r1, +12(sp)
    psub cx, cx, bx
    @stw r1, +12(sp)
    @ldw r1, +12(sp)
    pmovi bx, 4
    pmovi ex, 0
    pmovi fx, 0
    pmuli fx, fx, 4
    padd ex, ex, fx
    ldvw dx, +0(ex)
    pslladd cx, cx, bx, dx
    @ldw r0, +12(sp)
    @ldw r2, +8(sp)
    padd bx, bx, dx
    @ldw r2, +12(sp)
    pmovi ex, 5
    pmovi gx, 0
    pmovi hx, 1
    pmuli hx, hx, 4
    padd gx, gx, hx
    ldvw fx, +0(gx)
    psrladd dx, dx, ex, fx
    pxorxor cx, cx, bx, dx
    @ldw r0, +16(sp)
    psub bx, bx, cx
    @stw r0, +16(sp)
    send bx, delta
    @ldw r1, +8(sp)
    psub cx, cx, bx
    @stw r1, +8(sp)
tea_decrypt_file_for_update_6:    # addr=344
    pmovi cx, 1
    @ldw r0, +4(sp)
    padd bx, bx, cx
    @stw r0, +4(sp)
    @jmp -58    # -> tea_decrypt_file_for_cond_5 @ 132
tea_decrypt_file_for_end_7:    # addr=364
    @ldw r0, +16(sp)
    @ldw r2, +24(sp)
    paddi dx, dx, 0
    pmovi cx, 0
    padd cx, cx, dx
    @stw r0, +0(r1)
    @ldw r0, +12(sp)
    @ldw r2, +24(sp)
    paddi dx, dx, 4
    pmovi cx, 0
    padd cx, cx, dx
    @stw r0, +0(r1)
    pmovi bx, 8
    @ldw r1, +24(sp)
    padd cx, cx, bx
    @stw r1, +24(sp)
tea_decrypt_file_for_update_3:    # addr=428
    pmovi cx, 1
    @ldw r0, +20(sp)
    padd bx, bx, cx
    @stw r0, +20(sp)
    @jmp -100    # -> tea_decrypt_file_for_cond_2 @ 48
tea_decrypt_file_for_end_4:    # addr=448
tea_decrypt_file_secure_exit_1:    # addr=448
    quit
    ldw ra, +0(sp)
    addi sp, sp, -28
    ret
main:    # addr=464
    addi sp, sp, 4
    stw ra, +0(sp)
    call -116    # -> tea_decrypt_file @ 12
    ldw ra, +0(sp)
    addi sp, sp, -4
    ret
