__init__:    # addr=0
    li r0, 10
    __loop__:
        ldw r1, 0(zero)
        ldw r2, 4(zero)
        addi r1, r1, 1
        add r3, r2, r1
        stw r1, 0(zero)
        stw r3, 4(zero)
        blt r1, r0, -7
    
    end

