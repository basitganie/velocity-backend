; ================================================================
; Velocity stdlib — hashmap.asm   v2 (clean rewrite)
; Open-addressing, linear-probe hash map
;
; Slot layout (32 bytes):
;   [+0]  key_ptr  8 — strdup'd key or NULL
;   [+8]  tag      8 — 0=EMPTY,1=INT,2=FLOAT,3=STR,4=DELETED
;   [+16] val      8 — payload
;   [+24] _pad     8 — padding
;
; Header (opaque handle returned as adad):
;   [+0]  cap    8 — slot count (power of 2)
;   [+8]  count  8 — live entries
;   [+16] slots  8 — slot array pointer
;
; Stack alignment rule (SysV ABI):
;   rsp % 16 must be 0 before any `call`.
;   At function entry rsp % 16 == 8 (return address pushed).
;   After `push rbp; mov rbp,rsp`: rsp % 16 == 0.
;   Each additional push decrements rsp by 8.
;   `sub rsp, N` must be chosen so that (N + 8*extra_pushes) % 16 == 0.
;   We use ONLY callee-saved registers (rbx, r12-r15) as loop counters
;   so they survive across libc calls without push/pop in loops.
; ================================================================

%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64 1
%endif

%ifdef WIN64
  %define ARG1 rcx
  %define ARG2 rdx
  %define ARG3 r8
%else
  %define ARG1 rdi
  %define ARG2 rsi
  %define ARG3 rdx
%endif

%define SLOT_KEY   0
%define SLOT_TAG   8
%define SLOT_VAL   16
%define SLOT_SIZE  32

%define TAG_EMPTY   0
%define TAG_INT     1
%define TAG_FLOAT   2
%define TAG_STR     3
%define TAG_DELETED 4

%define HDR_CAP    0
%define HDR_COUNT  8
%define HDR_SLOTS  16
%define HDR_SIZE   24

default rel
extern malloc, calloc, free, strdup, strcmp

global hashmap__new
global hashmap__free
global hashmap__set_int
global hashmap__set_float
global hashmap__set_str
global hashmap__get_int
global hashmap__get_float
global hashmap__get_str
global hashmap__has
global hashmap__delete
global hashmap__count
global hashmap__clear
global hashmap__get_tag
global hashmap__bits_to_float

section .text

; ----------------------------------------------------------------
; hm_next_pow2(rdi) -> rax   smallest power-of-2 >= rdi, min 16
; ----------------------------------------------------------------
hm_next_pow2:
    cmp  rdi, 16
    jae  .big
    mov  rax, 16
    ret
.big:
    lea  rax, [rdi - 1]
    bsr  rcx, rax
    mov  rax, 2
    shl  rax, cl
    ret

; ----------------------------------------------------------------
; hm_hash(rdi=key, rsi=cap) -> rax   FNV-1a 64-bit, masked
; ----------------------------------------------------------------
hm_hash:
    mov  rax, 0xcbf29ce484222325
    mov  rcx, 0x100000001b3
.loop:
    movzx rdx, byte [rdi]
    test  dl, dl
    jz    .done
    xor   rax, rdx
    imul  rax, rcx
    inc   rdi
    jmp   .loop
.done:
    lea   rdx, [rsi - 1]
    and   rax, rdx
    ret

; ----------------------------------------------------------------
; hm_find_slot(rdi=slots, rsi=cap, rdx=key) -> rax=slot_ptr, r11=found
;
; Saves/restores: rbx r12 r13 r14 r15
; r11 is EXPLICITLY set in every exit path (strcmp clobbers it).
;
; Alignment audit:
;   entry rsp%16=8
;   push rbp  → rsp%16=0
;   sub rsp,8 → rsp%16=8  (1 byte to fix)  Wait:
;   push rbp (−8), sub rsp 8 (−8), push rbx..r15 (5×−8 = −40)
;   total from entry: −8−8−40 = −56. 56%16=8. BAD.
;   Fix: sub rsp, 16 instead.
;   push rbp (−8), sub rsp 16 (−16), push 5 regs (−40) = −64. 64%16=0 ✓
; ----------------------------------------------------------------
hm_find_slot:
    push rbp
    mov  rbp, rsp
    sub  rsp, 24            ; 24+5*8=64, 64%16=0 ✓
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov  r12, rdi           ; slots base
    mov  r13, rsi           ; cap
    mov  r14, rdx           ; search key

    ; initial probe index
    mov  rdi, r14
    mov  rsi, r13
    call hm_hash
    mov  rbx, rax           ; rbx = probe index

    xor  r15, r15           ; r15 = first tombstone slot ptr (0=none)
    ; r11 will be set explicitly at every exit

    mov  rcx, r13           ; probe limit
.probe:
    test rcx, rcx
    jz   .map_full

    mov  rax, rbx
    imul rax, SLOT_SIZE
    add  rax, r12           ; rax = current slot ptr

    mov  r8,  [rax + SLOT_TAG]
    cmp  r8,  TAG_EMPTY
    je   .hit_empty
    cmp  r8,  TAG_DELETED
    je   .hit_tomb

    ; live slot: compare keys
    mov  ARG1, [rax + SLOT_KEY]
    mov  ARG2, r14
    call strcmp             ; clobbers rax, rcx, rdx, rsi, rdi, r8-r11
    test rax, rax
    jnz  .next_probe

    ; match found — recompute slot ptr (rax clobbered by strcmp)
    mov  rax, rbx
    imul rax, SLOT_SIZE
    add  rax, r12
    mov  r11, 1             ; found = true
    jmp  .exit

.hit_tomb:
    test r15, r15
    jnz  .next_probe
    mov  r15, rax           ; remember first tombstone
    jmp  .next_probe

.hit_empty:
    ; key not found — return tombstone if available, else this empty slot
    test r15, r15
    cmovnz rax, r15         ; if tombstone, use it; else keep rax=empty slot
    xor  r11, r11           ; found = false
    jmp  .exit

.next_probe:
    inc  rbx
    cmp  rbx, r13
    jne  .no_wrap
    xor  rbx, rbx
.no_wrap:
    dec  rcx
    jmp  .probe

.map_full:
    xor  rax, rax
    xor  r11, r11
.exit:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    add  rsp, 24
    pop  rbp
    ret

; ----------------------------------------------------------------
; hm_grow(ARG1=map)
;
; Registers: r12=map r13=old_cap r14=old_slots r15=new_cap rbx=new_slots
; Scratch in frame: [rbp-8]=old_index [rbp-16]=old_slot_ptr
;
; Alignment: push rbp, sub rsp N, push rbx r12 r13 r14 r15 (5 pushes)
;   Need (N + 5*8) % 16 = 0 → N % 16 = 8 → N = 8, 24, 40...
;   Use N=24: 24+40=64, 64%16=0 ✓
;   [rbp-8] and [rbp-16] are in the 24-byte allocation ✓
; ----------------------------------------------------------------
hm_grow:
    push rbp
    mov  rbp, rsp
    sub  rsp, 24            ; 24+5*8=64, 64%16=0 ✓
    push rbx
    push r12
    push r13
    push r14
    push r15

%ifdef WIN64
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    mov  r13, [r12 + HDR_CAP]
    mov  r14, [r12 + HDR_SLOTS]
    mov  r15, r13
    shl  r15, 1                   ; new_cap = old_cap * 2

    ; calloc(new_cap * SLOT_SIZE, 1) — zeros = TAG_EMPTY=0 ✓
    mov  ARG1, r15
    imul ARG1, SLOT_SIZE
    mov  ARG2, 1
    call calloc
    mov  rbx, rax                 ; rbx = new slots

    mov  qword [rbp-8], 0         ; old_index = 0
.rehash:
    mov  rax, [rbp-8]
    cmp  rax, r13
    jge  .rehash_done

    imul rax, SLOT_SIZE
    add  rax, r14

    mov  r8, [rax + SLOT_TAG]
    cmp  r8, TAG_EMPTY
    je   .rehash_skip
    cmp  r8, TAG_DELETED
    je   .rehash_skip

    mov  [rbp-16], rax            ; save old slot ptr
    mov  ARG1, rbx
    mov  ARG2, r15
    mov  ARG3, [rax + SLOT_KEY]
    call hm_find_slot             ; rax=new slot ptr
    mov  r9,  [rbp-16]            ; restore old slot ptr (r9=caller-saved, fine here)

    mov  rax, rax                 ; new slot ptr still in rax
    mov  rdx, [r9 + SLOT_KEY]
    mov  [rax + SLOT_KEY], rdx
    mov  rdx, [r9 + SLOT_TAG]
    mov  [rax + SLOT_TAG], rdx
    mov  rdx, [r9 + SLOT_VAL]
    mov  [rax + SLOT_VAL], rdx

.rehash_skip:
    inc  qword [rbp-8]
    jmp  .rehash
.rehash_done:

    mov  ARG1, r14
    call free

    mov  [r12 + HDR_CAP],   r15
    mov  [r12 + HDR_SLOTS], rbx

    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    add  rsp, 24
    pop  rbp
    ret

; ----------------------------------------------------------------
; hashmap__new(ARG1=initial_cap) -> adad
;
; Alignment: push rbp, sub N, push rbx r12 (2 pushes)
;   Need (N+2*8)%16=0 → N%16=0 → N=16
;   16+16=32, 32%16=0 ✓
; ----------------------------------------------------------------
hashmap__new:
    push rbp
    mov  rbp, rsp
    sub  rsp, 16            ; 16+2*8=32, 32%16=0 ✓
    push rbx
    push r12

%ifdef WIN64
    mov  ARG1, rcx
%endif
    call hm_next_pow2
    mov  r12, rax           ; r12 = real cap

    mov  ARG1, HDR_SIZE
    call malloc
    mov  rbx, rax           ; rbx = header ptr

    mov  ARG1, r12
    imul ARG1, SLOT_SIZE
    mov  ARG2, 1
    call calloc             ; TAG_EMPTY=0 → no init needed

    mov  [rbx + HDR_CAP],   r12
    mov  qword [rbx + HDR_COUNT], 0
    mov  [rbx + HDR_SLOTS], rax
    mov  rax, rbx

    pop  r12
    pop  rbx
    add  rsp, 16
    pop  rbp
    ret

; ----------------------------------------------------------------
; hashmap__free(ARG1=map)
;
; Uses r12=map r13=slots rbx=cap r14=index r15=scratch
; Alignment: push rbp, sub N, push rbx r12 r13 r14 r15 (5)
;   Need (N+40)%16=0 → N%16=8 → N=8: 8+40=48%16=0 ✓
; ----------------------------------------------------------------
hashmap__free:
    push rbp
    mov  rbp, rsp
    sub  rsp, 8             ; 8+5*8=48, 48%16=0 ✓
    push rbx
    push r12
    push r13
    push r14
    push r15

%ifdef WIN64
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    mov  rbx, [r12 + HDR_CAP]
    mov  r13, [r12 + HDR_SLOTS]

    xor  r14, r14               ; r14 = index (callee-saved → survives free())
.free_loop:
    cmp  r14, rbx
    jge  .free_done
    mov  rax, r14
    imul rax, SLOT_SIZE
    add  rax, r13
    mov  r15, [rax + SLOT_TAG]
    cmp  r15, TAG_EMPTY
    je   .free_skip
    cmp  r15, TAG_DELETED
    je   .free_skip
    mov  ARG1, [rax + SLOT_KEY]
    call free                   ; r14 preserved (callee-saved) ✓
.free_skip:
    inc  r14
    jmp  .free_loop
.free_done:

    mov  ARG1, r13
    call free
    mov  ARG1, r12
    call free

    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    add  rsp, 8
    pop  rbp
    ret

; ----------------------------------------------------------------
; set_* helpers via macro
; r12=map r13=key r14=val  — all callee-saved, survive all calls
;
; Alignment: push rbp, sub N, push rbx r12 r13 r14 r15 (5)
;   N=8: 8+40=48%16=0 ✓
; ----------------------------------------------------------------
%macro DEF_SET 2  ; %1=function_name  %2=tag_constant
%1:
    push rbp
    mov  rbp, rsp
    sub  rsp, 8             ; 8+5*8=48, 48%16=0 ✓
    push rbx
    push r12
    push r13
    push r14
    push r15

%ifdef WIN64
    mov  r12, rcx
    mov  r13, rdx
    mov  r14, r8
%else
    mov  r12, rdi
    mov  r13, rsi
    mov  r14, rdx
%endif

    ; grow if needed
    mov  rax, [r12 + HDR_CAP]
    lea  rbx, [rax + rax*2]
    shr  rbx, 2             ; cap*3/4
    cmp  [r12 + HDR_COUNT], rbx
    jl   %%no_grow
    mov  ARG1, r12
    call hm_grow            ; r12 r13 r14 preserved (callee-saved) ✓
%%no_grow:
    mov  ARG1, [r12 + HDR_SLOTS]
    mov  ARG2, [r12 + HDR_CAP]
    mov  ARG3, r13
    call hm_find_slot       ; rax=slot, r11=found; r12 r13 r14 preserved ✓
    mov  rbx, rax           ; rbx = slot ptr
    test rbx, rbx
    jz   %%done
    test r11, r11
    jnz  %%write            ; existing key → update only
    ; new key
    mov  ARG1, r13
    call strdup             ; rax=new key ptr; rbx r12 r13 r14 preserved ✓
    mov  [rbx + SLOT_KEY], rax
    inc  qword [r12 + HDR_COUNT]
%%write:
    mov  qword [rbx + SLOT_TAG], %2
    mov  [rbx + SLOT_VAL], r14
%%done:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    add  rsp, 8
    pop  rbp
    ret
%endmacro

DEF_SET hashmap__set_int,   TAG_INT
DEF_SET hashmap__set_float, TAG_FLOAT
DEF_SET hashmap__set_str,   TAG_STR

; ----------------------------------------------------------------
; get_* helpers via macro
; r12=map r13=key — callee-saved, survive hm_find_slot call
;
; Alignment: push rbp, sub N, push rbx r12 r13 (3)
;   N=8: 8+24=32%16=0 ✓
; ----------------------------------------------------------------
%macro DEF_GET_PROLOGUE 0
    push rbp
    mov  rbp, rsp
    sub  rsp, 8             ; 8+3*8=32, 32%16=0 ✓
    push rbx
    push r12
    push r13
%ifdef WIN64
    mov  r12, rcx
    mov  r13, rdx
%else
    mov  r12, rdi
    mov  r13, rsi
%endif
    mov  ARG1, [r12 + HDR_SLOTS]
    mov  ARG2, [r12 + HDR_CAP]
    mov  ARG3, r13
    call hm_find_slot
%endmacro

%macro DEF_GET_EPILOGUE 0
    pop  r13
    pop  r12
    pop  rbx
    add  rsp, 8
    pop  rbp
    ret
%endmacro

; ----------------------------------------------------------------
hashmap__get_int:
    DEF_GET_PROLOGUE
    test r11, r11
    jz   .miss
    cmp  qword [rax + SLOT_TAG], TAG_INT
    jne  .miss
    mov  rax, [rax + SLOT_VAL]
    jmp  .hit
.miss: xor rax, rax
.hit:  DEF_GET_EPILOGUE

; ----------------------------------------------------------------
; get_float: codegen.c registers return type as tf=TYPE_F64
; so after this call, codegen emits movsd [rbp-N], xmm0
; We must return in xmm0.
; ----------------------------------------------------------------
hashmap__get_float:
    DEF_GET_PROLOGUE
    test r11, r11
    jz   .miss
    cmp  qword [rax + SLOT_TAG], TAG_FLOAT
    jne  .miss
    movq xmm0, [rax + SLOT_VAL]
    jmp  .hit
.miss: xorpd xmm0, xmm0
.hit:  DEF_GET_EPILOGUE

; ----------------------------------------------------------------
hashmap__get_str:
    DEF_GET_PROLOGUE
    test r11, r11
    jz   .miss
    cmp  qword [rax + SLOT_TAG], TAG_STR
    jne  .miss
    mov  rax, [rax + SLOT_VAL]
    jmp  .hit
.miss: xor rax, rax
.hit:  DEF_GET_EPILOGUE

; ----------------------------------------------------------------
hashmap__has:
    DEF_GET_PROLOGUE
    mov  rax, r11
    DEF_GET_EPILOGUE

; ----------------------------------------------------------------
hashmap__get_tag:
    DEF_GET_PROLOGUE
    test r11, r11
    jz   .miss
    mov  rax, [rax + SLOT_TAG]
    jmp  .hit
.miss: mov rax, -1
.hit:  DEF_GET_EPILOGUE

; ----------------------------------------------------------------
hashmap__delete:
    DEF_GET_PROLOGUE
    test r11, r11
    jz   .miss
    ; free key — rax=slot ptr, save in rbx (callee-saved)
    mov  rbx, rax
    mov  ARG1, [rbx + SLOT_KEY]
    call free               ; rbx preserved ✓
    mov  qword [rbx + SLOT_KEY], 0
    mov  qword [rbx + SLOT_TAG], TAG_DELETED
    mov  qword [rbx + SLOT_VAL], 0
    dec  qword [r12 + HDR_COUNT]
    mov  rax, 1
    jmp  .hit
.miss: xor rax, rax
.hit:  DEF_GET_EPILOGUE

; ----------------------------------------------------------------
hashmap__count:
    mov  rax, [ARG1 + HDR_COUNT]
    ret

; ----------------------------------------------------------------
; hashmap__clear(ARG1=map)
; r12=map r13=slots rbx=cap r14=index — all callee-saved
;
; Alignment: push rbp, sub N, push rbx r12 r13 r14 r15 (5)
;   N=8: 8+40=48%16=0 ✓
; ----------------------------------------------------------------
hashmap__clear:
    push rbp
    mov  rbp, rsp
    sub  rsp, 8             ; 8+5*8=48, 48%16=0 ✓
    push rbx
    push r12
    push r13
    push r14
    push r15

%ifdef WIN64
    mov  r12, rcx
%else
    mov  r12, rdi
%endif
    mov  rbx, [r12 + HDR_CAP]
    mov  r13, [r12 + HDR_SLOTS]

    xor  r14, r14               ; index (callee-saved → survives free)
.clear_loop:
    cmp  r14, rbx
    jge  .clear_done
    mov  rax, r14
    imul rax, SLOT_SIZE
    add  rax, r13               ; rax = slot ptr
    mov  r15, [rax + SLOT_TAG]
    cmp  r15, TAG_EMPTY
    je   .clear_skip
    cmp  r15, TAG_DELETED
    je   .clear_zero
    ; free key — save slot ptr in r15
    mov  r15, rax
    mov  ARG1, [rax + SLOT_KEY]
    call free                   ; r14 r15 preserved ✓
    mov  rax, r15               ; restore slot ptr
.clear_zero:
    mov  qword [rax + SLOT_KEY], 0
    mov  qword [rax + SLOT_TAG], TAG_EMPTY
    mov  qword [rax + SLOT_VAL], 0
.clear_skip:
    inc  r14
    jmp  .clear_loop
.clear_done:
    mov  qword [r12 + HDR_COUNT], 0

    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    add  rsp, 8
    pop  rbp
    ret

; ----------------------------------------------------------------
hashmap__bits_to_float:
    movq xmm0, ARG1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
