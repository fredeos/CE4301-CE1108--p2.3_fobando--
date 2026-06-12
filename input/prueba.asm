__init__:    # addr=0
    li r1, 0
    li r2, 1
    stw r2, 0(r1)
    nop
    stw r2, 8(r1)
    nop
    ldw r3, 4(r1)     
    