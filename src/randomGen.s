.section __DATA,__rodata
    out:
        .asciz "--"
    hex_lut:
        .ascii "0123456789abcdef"
    newline:
        .asciz "\n"

.data

.p2align 3

chacha_constants:
    .quad 0x617078653320646e
    .quad 0x79622d326b206574 


.p2align 2

intermediate_state:
    .space 4 //initialized ?
    .space 4 //padding
    .space 48 //state
    .space 64 //current block
    .space 8 //current pos

.text
.global _main
.global _generate

.align 2


_write_to_console_hex:
    stp     x29, x30, [sp, #-16]!      
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!

    mov     x19, x0                    
    mov     x20, x1                    
    lsl     x21, x20, #1                

    
    add     x22, x21, #15               
    mov     x23, #-16                  
    and     x22, x22, x23               
    mov     x24, sp                     
    sub     sp, sp, x22                 
    mov     x23, sp                    

    adrp    x22, hex_lut@PAGE
    add     x22, x22, hex_lut@PAGEOFF

    hex_loop:
    cbz     x20, write_to_console

    ldrb    w8, [x19], #1

    lsr     w9, w8, #4                 
    ldrb    w10, [x22, w9, uxtw]              
    strb    w10, [x23], #1              

    and     w9, w8, #0xF              
    ldrb    w10, [x22, w9, uxtw]              
    strb    w10, [x23], #1             

    subs    x20, x20, #1
    b       hex_loop

    write_to_console:
    mov     x0, #1                    
    mov     x1, sp                      
    mov     x2, x21                    
    mov     x16, #4                     
    svc     #0x80

    mov     sp, x24                     
    ldp     x23, x24, [sp], #16        
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16        
    ret
/*
in:
x0 - address on Stack to write

out:
x0 - syscall write return val
 */
_write_to_console_str:
    str x30, [sp, #-16]!
    str x0, [sp, #-16]!

    bl _len

    mov x2, x0
    mov x0, #1
    

    ldr x1, [sp], #16
    mov x16, #4
    svc #0x80

    ldr x30, [sp], #16

    ret

_len:
    mov x1, #0

    _len_loop:
        ldrb w2, [x0, x1]
        cbz w2, _len_end

        add x1, x1, #1
        
        b _len_loop

    _len_end:
        mov x0, x1
        ret


/*
in:
x0 - address on Stack
x1 - length in bytes

out:
x0 - syscall write return val
*/
_write_to_console_adr:
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x16, #4

    svc #0x80
    ret



_main:

    cmp     x0, #2
    bne    _error

    ldr     x7, [x1, #8]

    mov     x2, #0              
    mov     x3, #10             

    parse_loop:

    ldrb    w4, [x7], #1
    cmp     w4, #0             
    beq    parse_done         

    sub     w4, w4, #'0'        
    mul     x2, x2, x3         
    add     x2, x2, x4        
    b       parse_loop

    parse_done:

    mov x7, x2

    stp x29, x30, [sp, #-16]!
    mov x29, sp
    add sp, sp, #-16
    
    mov x0, sp
    mov x1, x7
    bl _generate

    adrp x0, out@PAGE
    add  x0, x0, out@PAGEOFF
    bl _write_to_console_str

    mov x0, sp
    mov x1, x7
    bl _write_to_console_hex

    adrp x0, out@PAGE
    add  x0, x0, out@PAGEOFF    
    bl _write_to_console_str

    adrp x0, newline@PAGE
    add  x0, x0, newline@PAGEOFF    
    bl _write_to_console_str

    add sp, sp, #16
    ldp x29, x30, [sp], #16

    mov x0, #0
    mov x16, #1
    svc #0x80

    ret

/*
in:
x0 - address to store random value
x1 - desired length

out:
x0 - return code (0 success, 1 fail)
*/
_generate:
    //begin prologue
    //fp + ret
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    //callee saved registers
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    stp q8, q9, [sp, #-32]!
    stp q10, q11, [sp, #-32]!

    //dest_location
    mov x25, x0

    //desired length aka bytes left
    mov x26, x1

    //get position for intermediate state
    adrp x27, intermediate_state@PAGE
    add x27, x27, intermediate_state@PAGEOFF 

    //end prologue

    //begin main program
    bl _init_intermediate_state


    mainloop:

        cbz x26, end_mainloop

        ldr x28, [x27, #120]
        cmp x28, #64
        bge _refresh_and_loop

        //available bytes
        mov x2, #64
        sub x2, x2, x28
        cmp x26, x2

        //bytes to copy
        csel x3, x26, x2, ls

        //source address
        add x4, x27, #56
        add x4, x4, x28

        //if no bytes to copy -> update state
        cbz x3, update_state

        copy_loop:
            ldrb w5, [x4], #1
            strb w5, [x25], #1
            subs x3, x3, #1
            bne copy_loop
        
        update_state:
            
            cmp x26, x2
            csel x3, x26, x2, ls

            add x28, x28, x3
            str x28, [x27, #120]

            sub x26, x26, x3
            b mainloop
        
        _refresh_and_loop:
            bl _refresh_intermediate_state
            b mainloop

    end_mainloop:
    //end main program


    //begin epilogue
    //callee saved registers
    ldp x19, x20, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x27, x28, [sp], #16
    ldp q8, q9, [sp], #32
    ldp q10, q11, [sp], #32
    
    //fp + ret
    ldp x29, x30, [sp], #16
    //end epilogue

    ret
    
/*
in:
x27 - address of intermediate state

out:
none

*/
_init_intermediate_state:
    
    stp x25, x30, [sp, #-16]!

    //frame offset
    mov x25, x27

    //key + nonce
    add x0, x25, #8
    mov x1, #44

    mov x16, #500
    svc #0x80

    cbnz x0, _error

    //init flag
    mov x0, #1
    str x0, [x27]

    //gen first block
    ldp x19, x20, [x27, #8]
    ldp x21, x22, [x27, #24]
    ldp x23, x24, [x27, 40]

    bl _chacha_block
    
    add x25, x27, #56
    stp q0, q1, [x25], #32
    stp q2, q3, [x25]
    
    //curr pos is initialized as 0
    str xzr, [x27, #120]

    ldp x25, x30, [sp], #16
    ret


/*
in:
x27 - address of intermediate state

out:
none

*/
_refresh_intermediate_state:
    //saved callee saved registers and return addess also fetch intermediate state pointer
    stp x25, x30, [sp, #-16]!
    mov x25, x27

    ldp x19, x20, [x27, #8]
    ldp x21, x22, [x27, #24]
    ldp x23, x24, [x27, #40]

    //inc counter
    mov x0, #1
    lsl x0, x0, #32
    add x24, x24, x0 

    str x24, [x27, #40]

    //generate next block
    bl _chacha_block
    
    //push to intermediate state
    add x25, x27, #56
    stp q0, q1, [x25], #32
    stp q2, q3, [x25]

    //reset curr pos
    str xzr, [x27, #120]

    //restore callee saved registers and return address
    ldp x25, x30, [sp], #16
    ret

/*
in:
upper x24 - counter 
x23.. lower x24 - nonce
x19...x22 - key

out:
v0.4s...v3.4s - key expanded block
*/
_chacha_block:

    stp x25, x30, [sp, #-16]!
    add sp, sp, #-64

    bl _init_chacha_state

    ld1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]
    ld1 {v8.4s, v9.4s, v10.4s, v11.4s}, [x0]

    mov x25, #0

    block_loop_begin:
        
        bl _quarter_round

        ext v1.16b, v1.16b, v1.16b, #4
        ext v2.16b, v2.16b, v2.16b, #8
        ext v3.16b, v3.16b, v3.16b, #12

        bl _quarter_round

        ext v1.16b, v1.16b, v1.16b, #12
        ext v2.16b, v2.16b, v2.16b, #8
        ext v3.16b, v3.16b, v3.16b, #4

        add x25, x25, #2

        cmp x25, #20
        bne block_loop_begin
    

    add v0.4s, v0.4s, v8.4s
    add v1.4s, v1.4s, v9.4s
    add v2.4s, v2.4s, v10.4s
    add v3.4s, v3.4s, v11.4s

    add sp, sp, #64
    ldp x25, x30, [sp], #16

    ret

/*
in:
x23...x24 - (upper) ctr and (lower) nonce
x19...x22 - key

out:
x0 - refrence to the state
*/
_init_chacha_state:

    adrp x2, chacha_constants@PAGE
    add x2, x2, chacha_constants@PAGEOFF
    ldp x0, x1, [x2]

    stp x0, x1, [sp]
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]

    mov x0, sp
    ret
/*
v0.4s - a
v1.4s - b
v2.4s - c
v3.4s - d
*/
_quarter_round:

    add v0.16b, v0.16b, v1.16b
    eor v3.16b, v3.16b, v0.16b
    ushr v4.4s, v3.4s, #16
    shl v3.4s, v3.4s, #16
    orr v3.16b, v3.16b, v4.16b

    add v2.16b, v2.16b, v3.16b
    eor v1.16b, v1.16b, v2.16b
    ushr v4.4s, v1.4s, #20
    shl v1.4s, v1.4s, #12
    orr v1.16b, v1.16b, v4.16b
    
    add v0.16b, v0.16b, v1.16b
    eor v3.16b, v3.16b, v0.16b
    ushr v4.4s, v3.4s, #24
    shl v3.4s, v3.4s, #8
    orr v3.16b, v3.16b, v4.16b

    add v2.16b, v2.16b, v3.16b
    eor v1.16b, v1.16b, v2.16b
    ushr v4.4s, v1.4s, #25
    shl v1.4s, v1.4s, #7
    orr v1.16b, v1.16b, v4.16b

    ret
    
_error:
    mov x0, #1
    mov x16, #1
    svc #0x80 
