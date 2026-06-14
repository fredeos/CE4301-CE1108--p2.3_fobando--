; prueba
__init__:
    li sp, 12 # inicializar stacl
    li r0, 10 # asignar un valor a una variable local
    mov p0, r0
    la p1, 0  # asignar dir. a un parametro 
    la p2, 4  # asignar dir. a un parametro
    call 3    # @foo
    addi r0, r0, -2
    stw r0,+ 8(zero)
    end
# foo(limit, *result, *counter)
foo:
    addi sp, sp, 12
    stw ra,+ 0(sp)
    stw r0,+ 4(sp)
    stw r1,+ 8(sp)
    li r0, 0

    _loop_:
        beq r0, p0, 6
        ldw r1,+ 0(p1)
        add r1, r1, r0
        stw r0,+ 0(p2)
        stw r1,+ 0(p1)
        addi r0, r0, 1
        jmp -7

    _loop_end:
    ldw r1,+ 8(sp)
    ldw r0,+ 4(sp)
    ldw ra,+ 0(sp)
    subi sp, sp, 12
    ret