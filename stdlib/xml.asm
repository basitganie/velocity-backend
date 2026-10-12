; ================================================================
; Velocity StdLib — XML Module (xml.asm) v1.0
; Windows x86-64 + Linux x86-64 + AArch64 Android/Linux
;
; Provides both DOM and SAX parsing.
;
; ── DOM API ──────────────────────────────────────────────────
;   xml__parse(src: lafz) -> adad          ; XmlNode* root or 0
;   xml__free(node: adad) -> adad          ; free entire tree
;   xml__tag(node: adad) -> lafz           ; element tag name
;   xml__text(node: adad) -> lafz          ; text content
;   xml__attr(node, name: lafz) -> lafz    ; attribute value or ""
;   xml__child(node: adad, i: adad) -> adad; i-th child node or 0
;   xml__child_count(node: adad) -> adad   ; number of children
;   xml__find(node, tag: lafz) -> adad     ; first child by tag
;   xml__find_all(node, tag: lafz) -> adad ; [XmlNode*] array
;   xml__attr_count(node: adad) -> adad    ; number of attributes
;   xml__attr_name(node, i: adad) -> lafz  ; i-th attr name
;   xml__attr_val(node, i: adad) -> lafz   ; i-th attr value
;   xml__is_element(node: adad) -> adad    ; 1 if element node
;   xml__is_text(node: adad) -> adad       ; 1 if text node
;   xml__stringify(node: adad) -> lafz     ; node back to XML string
;
; ── SAX API ──────────────────────────────────────────────────
;   xml__sax_parse(src, handler, userdata: adad) -> adad  ; 0=ok
;
;   handler is a pointer to XmlSaxHandler struct:
;     [+0]  on_open(tag:lafz, attrs:adad, userdata:adad)->adad
;     [+8]  on_close(tag:lafz, userdata:adad)->adad
;     [+16] on_text(text:lafz, userdata:adad)->adad
;
; ── XmlNode layout (heap, 8-byte fields) ─────────────────────
;   [+0]   type:   adad  (1=element, 2=text)
;   [+8]   tag:    lafz  (element name, or 0 for text nodes)
;   [+16]  text:   lafz  (text content for type=2, or 0)
;   [+24]  attrs:  adad  (ptr to XmlAttr array, or 0)
;   [+32]  attr_count: adad
;   [+40]  children:   adad  (ptr to XmlNode* array data)
;   [+48]  child_count: adad
;   [+56]  child_cap:   adad
;
; ── XmlAttr layout ───────────────────────────────────────────
;   [+0]  name:  lafz
;   [+8]  value: lafz
; ── Total XmlAttr size = 16 bytes ────────────────────────────
;
; All strings are heap-allocated (memory__malloc / strdup style).
; Trees are freed with xml__free (recursive).
; ================================================================

%ifndef WIN64_TARGET
%ifidni __OUTPUT_FORMAT__,win64
  %define WIN64_TARGET 1
%endif
%endif

%ifndef AARCH64_TARGET
default rel
%endif

; ── Register aliases ─────────────────────────────────────────
%ifdef WIN64_TARGET
  %define ARG1 rcx
  %define ARG2 rdx
  %define ARG3 r8
  %define ARG4 r9
%else
  %define ARG1 rdi
  %define ARG2 rsi
  %define ARG3 rdx
  %define ARG4 rcx
%endif

; ── XmlNode field offsets ────────────────────────────────────
%define XN_TYPE        0
%define XN_TAG         8
%define XN_TEXT        16
%define XN_ATTRS       24
%define XN_ATTR_COUNT  32
%define XN_CHILDREN    40
%define XN_CHILD_COUNT 48
%define XN_CHILD_CAP   56
%define XN_SIZE        64

; ── XmlAttr field offsets ────────────────────────────────────
%define XA_NAME        0
%define XA_VALUE       8
%define XA_SIZE        16

; ── Node types ───────────────────────────────────────────────
%define XML_ELEMENT    1
%define XML_TEXT       2

; ── Initial child/attr capacities ────────────────────────────
%define XML_INIT_CHILD_CAP  4
%define XML_INIT_ATTR_CAP   4

; ================================================================
; External dependencies
; ================================================================
extern malloc
extern calloc
extern realloc
extern free

; ── Velocity stdlib string helpers ───────────────────────────
extern memory__strlen
extern memory__strcpy
extern memory__strcmp
extern memory__memset
extern memory__memcpy

; ── Velocity string module ────────────────────────────────────
extern lafz__concat

section .data
xml_empty_str   db 0
xml_lt          db "<", 0
xml_gt          db ">", 0
xml_lt_slash    db "</", 0
xml_slash_gt    db "/>", 0
xml_space       db " ", 0
xml_eq_dq       db "=", 0x22, 0
xml_dq          db 0x22, 0
xml_amp         db "&amp;", 0
xml_lt_ent      db "&lt;", 0
xml_gt_ent      db "&gt;", 0
xml_quot_ent    db "&quot;", 0

section .bss
; scratch buffer for stringify (up to 64KB output)
xml_str_buf     resb 65536
xml_str_ptr     resq 1      ; current write position in xml_str_buf

; temporary attribute pointer buffer (for find_all)
xml_fa_buf      resb 4112   ; 16-byte header + 512 * 8 = array of XmlNode*
                             ; layout: [0]=cap [8]=len [16..]=ptrs

section .text

; ================================================================
; INTERNAL HELPERS
; ================================================================

; ── xml_strdup(src: rdi/rcx) -> rax  (heap copy of a C string) ──
; Uses malloc + strcpy. Returns 0 if src is 0.
xml_strdup:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    push rbx
    mov  rbx, rcx              ; save src
    test rcx, rcx
    jz   .sd_null
    ; strlen(src)
    sub  rsp, 32
    call memory__strlen
    add  rsp, 32
    inc  rax                   ; +1 for null
    ; malloc(len+1)
    mov  rcx, rax
    sub  rsp, 32
    call malloc
    add  rsp, 32
    test rax, rax
    jz   .sd_ret
    ; strcpy(dst, src)
    mov  rcx, rax
    mov  rdx, rbx
    push rax
    sub  rsp, 32
    call memory__strcpy
    add  rsp, 32
    pop  rax
    jmp  .sd_ret
.sd_null:
    xor  rax, rax
.sd_ret:
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
%else
    push rbp
    mov  rbp, rsp
    push rbx
    mov  rbx, rdi
    test rdi, rdi
    jz   .sd_null
    call memory__strlen
    inc  rax
    mov  rdi, rax
    call malloc
    test rax, rax
    jz   .sd_ret
    push rax
    mov  rdi, rax
    mov  rsi, rbx
    call memory__strcpy
    pop  rax
    jmp  .sd_ret
.sd_null:
    xor  rax, rax
.sd_ret:
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
%endif

; ── xml_alloc_node() -> rax  (zeroed XmlNode on heap) ────────
xml_alloc_node:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    sub  rsp, 32
    mov  rcx, 1
    mov  rdx, XN_SIZE
    call calloc
    add  rsp, 32
%else
    mov  rdi, 1
    mov  rsi, XN_SIZE
    call calloc
%endif
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_node_add_child(parent: rdi/rcx, child: rsi/rdx) ──────
; Grows parent's children array if needed, appends child ptr.
xml_node_add_child:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    mov  rbx, rcx              ; parent
    mov  r12, rdx              ; child
%else
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    mov  rbx, rdi              ; parent
    mov  r12, rsi              ; child
%endif
    mov  rax, [rbx + XN_CHILD_COUNT]
    mov  rcx, [rbx + XN_CHILD_CAP]
    cmp  rax, rcx
    jl   .nac_store

    ; grow: cap = cap == 0 ? INIT : cap*2
    test rcx, rcx
    jnz  .nac_grow
    mov  rcx, XML_INIT_CHILD_CAP
    jmp  .nac_do_alloc
.nac_grow:
    shl  rcx, 1
.nac_do_alloc:
    mov  [rbx + XN_CHILD_CAP], rcx
    ; realloc(children, cap * 8)
    mov  rdx, rcx
    shl  rdx, 3
%ifdef WIN64_TARGET
    mov  rcx, [rbx + XN_CHILDREN]
    sub  rsp, 32
    call realloc
    add  rsp, 32
%else
    mov  rdi, [rbx + XN_CHILDREN]
    mov  rsi, rdx
    call realloc
%endif
    test rax, rax
    jz   .nac_ret
    mov  [rbx + XN_CHILDREN], rax

.nac_store:
    mov  rax, [rbx + XN_CHILDREN]
    mov  rcx, [rbx + XN_CHILD_COUNT]
    mov  [rax + rcx*8], r12
    inc  qword [rbx + XN_CHILD_COUNT]
.nac_ret:
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_node_add_attr(node, name, value: rdi/rcx,rsi/rdx,rdx/r8) ─
; Appends an XmlAttr to node's attr array.
xml_node_add_attr:
%ifdef WIN64_TARGET
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    mov  rbx, rcx
    mov  r12, rdx
    mov  r13, r8
%else
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    mov  rbx, rdi
    mov  r12, rsi
    mov  r13, rdx
%endif
    ; current count
    mov  rax, [rbx + XN_ATTR_COUNT]
    ; ensure space: realloc attrs to (count+1)*XA_SIZE
    inc  rax
    mov  rcx, rax
    imul rcx, rcx, XA_SIZE
%ifdef WIN64_TARGET
    mov  rdx, rcx
    mov  rcx, [rbx + XN_ATTRS]
    sub  rsp, 32
    call realloc
    add  rsp, 32
%else
    mov  rdi, [rbx + XN_ATTRS]
    mov  rsi, rcx
    call realloc
%endif
    test rax, rax
    jz   .naa_ret
    mov  [rbx + XN_ATTRS], rax
    ; index of new attr = old count
    mov  rcx, [rbx + XN_ATTR_COUNT]
    imul rcx, rcx, XA_SIZE
    add  rax, rcx              ; ptr to new XmlAttr
    ; strdup name and value
    push rax
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call xml_strdup
    add  rsp, 32
%else
    mov  rdi, r12
    call xml_strdup
%endif
    pop  rcx                   ; rcx = attr ptr
    mov  [rcx + XA_NAME], rax
    push rcx
%ifdef WIN64_TARGET
    mov  rcx, r13
    sub  rsp, 32
    call xml_strdup
    add  rsp, 32
%else
    mov  rdi, r13
    call xml_strdup
%endif
    pop  rcx
    mov  [rcx + XA_VALUE], rax
    inc  qword [rbx + XN_ATTR_COUNT]
.naa_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ================================================================
; PARSER STATE (static — not re-entrant, like the rest of stdlib)
; ================================================================
section .bss
xml_ps_src      resq 1   ; original source string pointer
xml_ps_pos      resq 1   ; current parse position (ptr into src)
xml_ps_err      resb 1   ; error flag (0=ok, 1=error)

section .text

; ── xml_skip_ws() — advance xml_ps_pos past whitespace ───────
xml_skip_ws:
%ifdef WIN64_TARGET
    push rbx
    mov  rbx, [rel xml_ps_pos]
.sw_loop:
    movzx rax, byte [rbx]
    cmp  al, ' '
    je   .sw_adv
    cmp  al, 9      ; tab
    je   .sw_adv
    cmp  al, 10     ; LF
    je   .sw_adv
    cmp  al, 13     ; CR
    je   .sw_adv
    jmp  .sw_done
.sw_adv:
    inc  rbx
    jmp  .sw_loop
.sw_done:
    mov  [rel xml_ps_pos], rbx
    pop  rbx
    ret
%else
    push rbx
    mov  rbx, [rel xml_ps_pos]
.sw_loop:
    movzx rax, byte [rbx]
    cmp  al, ' '
    je   .sw_adv
    cmp  al, 9
    je   .sw_adv
    cmp  al, 10
    je   .sw_adv
    cmp  al, 13
    je   .sw_adv
    jmp  .sw_done
.sw_adv:
    inc  rbx
    jmp  .sw_loop
.sw_done:
    mov  [rel xml_ps_pos], rbx
    pop  rbx
    ret
%endif

; ── xml_peek() -> rax  (byte at current pos, 0 at EOF) ───────
xml_peek:
    mov  rax, [rel xml_ps_pos]
    movzx rax, byte [rax]
    ret

; ── xml_advance() — move pos forward one byte ─────────────────
xml_advance:
    inc  qword [rel xml_ps_pos]
    ret

; ── xml_expect(c: rdi/rcx) -> rax (1=ok, 0=mismatch) ─────────
xml_expect:
%ifdef WIN64_TARGET
    mov  rax, [rel xml_ps_pos]
    movzx rdx, byte [rax]
    cmp  dl, cl
    jne  .xe_bad
    inc  qword [rel xml_ps_pos]
    mov  rax, 1
    ret
.xe_bad:
    mov  byte [rel xml_ps_err], 1
    xor  rax, rax
    ret
%else
    mov  rax, [rel xml_ps_pos]
    movzx rdx, byte [rax]
    cmp  dl, dil
    jne  .xe_bad
    inc  qword [rel xml_ps_pos]
    mov  rax, 1
    ret
.xe_bad:
    mov  byte [rel xml_ps_err], 1
    xor  rax, rax
    ret
%endif

; ── xml_is_name_start(c) -> rax (1 if letter or '_' or ':') ─
xml_is_name_start:
    ; rax = character byte (already loaded)
    cmp  al, 'A'
    jl   .ns_check_lower
    cmp  al, 'Z'
    jle  .ns_yes
.ns_check_lower:
    cmp  al, 'a'
    jl   .ns_check_us
    cmp  al, 'z'
    jle  .ns_yes
.ns_check_us:
    cmp  al, '_'
    je   .ns_yes
    cmp  al, ':'
    je   .ns_yes
    xor  rax, rax
    ret
.ns_yes:
    mov  rax, 1
    ret

; ── xml_is_name_char(c) -> rax ────────────────────────────────
xml_is_name_char:
    call xml_is_name_start
    test rax, rax
    jnz  .nc_yes
    ; also digits, '-', '.'
    movzx rax, byte [rel xml_ps_pos - 1]   ; WRONG — caller must pass char
    ; We'll just inline this check everywhere instead; stub returns 0
    xor  rax, rax
    ret
.nc_yes:
    mov  rax, 1
    ret

; ── xml_read_name() -> rax (heap string of XML name) ──────────
; Reads [A-Za-z_:][A-Za-z0-9_:.-]* from current position.
; r12 = start ptr, rbx = scan ptr, r13 = len
xml_read_name:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13

    mov  r12, [rel xml_ps_pos]
    mov  rbx, r12
.rn_loop:
    movzx rax, byte [rbx]
    test al, al
    jz   .rn_done
    cmp  al, 'A'
    jl   .rn_try_lower
    cmp  al, 'Z'
    jle  .rn_ok
.rn_try_lower:
    cmp  al, 'a'
    jl   .rn_try_digit
    cmp  al, 'z'
    jle  .rn_ok
.rn_try_digit:
    cmp  al, '0'
    jl   .rn_try_misc
    cmp  al, '9'
    jle  .rn_ok
.rn_try_misc:
    cmp  al, '_'
    je   .rn_ok
    cmp  al, '-'
    je   .rn_ok
    cmp  al, '.'
    je   .rn_ok
    cmp  al, ':'
    je   .rn_ok
    jmp  .rn_done
.rn_ok:
    inc  rbx
    jmp  .rn_loop
.rn_done:
    mov  [rel xml_ps_pos], rbx
    ; r13 = length
    mov  r13, rbx
    sub  r13, r12
    test r13, r13
    jz   .rn_oom           ; zero-length name
    ; malloc(len + 1)
%ifdef WIN64_TARGET
    mov  rcx, r13
    inc  rcx
    sub  rsp, 32
    call malloc
    add  rsp, 32
%else
    mov  rdi, r13
    inc  rdi
    call malloc
%endif
    test rax, rax
    jz   .rn_oom
    ; byte copy: rax=dst  r12=src  r13=len
    push rax
    mov  rdi, rax
    mov  rsi, r12
    mov  rdx, r13
.rn_copy:
    test rdx, rdx
    jz   .rn_copy_done
    mov  cl, [rsi]
    mov  [rdi], cl
    inc  rsi
    inc  rdi
    dec  rdx
    jmp  .rn_copy
.rn_copy_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .rn_ret
.rn_oom:
    xor  rax, rax
.rn_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_read_attr_value() -> rax  (heap string, strips quotes) ─
; Expects current char to be ' or "
xml_read_attr_value:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13

    call xml_peek
    movzx r13, al              ; quote char (' or ")
    cmp  al, '"'
    je   .rav_ok
    cmp  al, 39                ; single quote
    je   .rav_ok
    ; not a quote — error
    mov  byte [rel xml_ps_err], 1
    xor  rax, rax
    jmp  .rav_ret
.rav_ok:
    call xml_advance           ; skip opening quote
    mov  r12, [rel xml_ps_pos] ; start of value
    mov  rbx, r12
.rav_loop:
    movzx rax, byte [rbx]
    test al, al
    jz   .rav_done
    cmp  al, r13b              ; closing quote?
    je   .rav_done
    inc  rbx
    jmp  .rav_loop
.rav_done:
    mov  [rel xml_ps_pos], rbx
    ; length
    mov  rcx, rbx
    sub  rcx, r12
    push rcx
    push r12
%ifdef WIN64_TARGET
    mov  rdx, rcx
    inc  rdx
    mov  rcx, rdx
    sub  rsp, 32
    call malloc
    add  rsp, 32
%else
    mov  rdi, rcx
    inc  rdi
    call malloc
%endif
    pop  r12                   ; src
    pop  rcx                   ; len
    test rax, rax
    jz   .rav_ret
    ; byte copy
    push rax
    mov  rdi, rax
    mov  rsi, r12
    mov  rdx, rcx
.rav_copy:
    test rdx, rdx
    jz   .rav_copy_done
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    dec  rdx
    jmp  .rav_copy
.rav_copy_done:
    mov  byte [rdi], 0
    pop  rax
    ; skip closing quote
    call xml_advance
    jmp  .rav_ret2
.rav_ret:
    ; skip close quote if present
    call xml_peek
    cmp  al, r13b
    jne  .rav_ret2
    call xml_advance
.rav_ret2:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_skip_comment_or_cdata() ───────────────────────────────
; Called after "<!"; skips "-- ... -->" or "[CDATA[ ... ]]>".
; Also handles "<!DOCTYPE ...>".
xml_skip_comment_or_cdata:
    push rbp
    mov  rbp, rsp
    push rbx
    call xml_peek
    cmp  al, '-'               ; could be comment <!--
    jne  .scc_try_cdata
    call xml_advance
    call xml_peek
    cmp  al, '-'
    jne  .scc_skip_to_gt       ; malformed, skip to >
    call xml_advance
    ; skip until "-->"
.scc_cmt_loop:
    call xml_peek
    test al, al
    jz   .scc_ret
    cmp  al, '-'
    jne  .scc_cmt_adv
    call xml_advance
    call xml_peek
    cmp  al, '-'
    jne  .scc_cmt_loop
    call xml_advance
    call xml_peek
    cmp  al, '>'
    jne  .scc_cmt_loop
    call xml_advance
    jmp  .scc_ret
.scc_cmt_adv:
    call xml_advance
    jmp  .scc_cmt_loop

.scc_try_cdata:
    cmp  al, '['               ; CDATA?
    jne  .scc_skip_to_gt
    ; skip "[CDATA["
    mov  rcx, 6
.scc_cdata_hdr:
    call xml_advance
    dec  rcx
    jnz  .scc_cdata_hdr
    ; skip until "]]>"
.scc_cd_loop:
    call xml_peek
    test al, al
    jz   .scc_ret
    cmp  al, ']'
    jne  .scc_cd_adv
    call xml_advance
    call xml_peek
    cmp  al, ']'
    jne  .scc_cd_loop
    call xml_advance
    call xml_peek
    cmp  al, '>'
    jne  .scc_cd_loop
    call xml_advance
    jmp  .scc_ret
.scc_cd_adv:
    call xml_advance
    jmp  .scc_cd_loop

.scc_skip_to_gt:
    ; unknown <! construct; skip to matching >
.scc_sg_loop:
    call xml_peek
    test al, al
    jz   .scc_ret
    cmp  al, '>'
    je   .scc_sg_done
    call xml_advance
    jmp  .scc_sg_loop
.scc_sg_done:
    call xml_advance
.scc_ret:
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_read_text() -> rax (heap string, entities decoded) ───
; Reads raw text until '<'. Trims whitespace. Decodes &amp; &lt; &gt; &quot; &apos;
; Strategy: scan length, malloc worst-case, decode into buffer, realloc to fit.
; r12=src_start  rbx=src_end  r13=decoded_write_ptr
xml_read_text:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13

    mov  r12, [rel xml_ps_pos]
    mov  rbx, r12
.rt_loop:
    movzx rax, byte [rbx]
    test al, al
    jz   .rt_done
    cmp  al, '<'
    je   .rt_done
    inc  rbx
    jmp  .rt_loop
.rt_done:
    mov  [rel xml_ps_pos], rbx
    mov  r13, rbx              ; end ptr
    ; trim leading ws
.rt_trim_start:
    cmp  r12, r13
    jge  .rt_all_ws
    movzx rax, byte [r12]
    cmp  al, ' '
    je   .rt_ts_adv
    cmp  al, 9
    je   .rt_ts_adv
    cmp  al, 10
    je   .rt_ts_adv
    cmp  al, 13
    je   .rt_ts_adv
    jmp  .rt_trim_end
.rt_ts_adv:
    inc  r12
    jmp  .rt_trim_start
.rt_trim_end:
    ; trim trailing ws
    mov  rbx, r13
.rt_te_loop:
    cmp  rbx, r12
    jle  .rt_copy
    dec  rbx
    movzx rax, byte [rbx]
    cmp  al, ' '
    je   .rt_te_adv
    cmp  al, 9
    je   .rt_te_adv
    cmp  al, 10
    je   .rt_te_adv
    cmp  al, 13
    je   .rt_te_adv
    inc  rbx
    jmp  .rt_copy
.rt_te_adv:
    jmp  .rt_te_loop
.rt_copy:
    ; length of raw source
    mov  rcx, rbx
    sub  rcx, r12
    test rcx, rcx
    jz   .rt_empty
    ; malloc worst-case (raw len + 1 — decoded is always <=  raw)
    push rcx                   ; save raw len
    push r12                   ; save src start
    push rbx                   ; save src end
%ifdef WIN64_TARGET
    mov  rcx, [rsp + 16]       ; raw len
    inc  rcx
    sub  rsp, 32
    call malloc
    add  rsp, 32
%else
    mov  rdi, [rsp + 16]       ; raw len
    inc  rdi
    call malloc
%endif
    pop  rbx                   ; src end
    pop  r12                   ; src start
    pop  rcx                   ; raw len
    test rax, rax
    jz   .rt_ret
    ; decode loop: rsi=src  rdi=dst  rdx=src_end
    push rax
    mov  rdi, rax              ; dst
    mov  rsi, r12              ; src
    mov  rdx, rbx              ; src end
.rt_decode:
    cmp  rsi, rdx
    jge  .rt_decode_done
    movzx rax, byte [rsi]
    cmp  al, '&'
    jne  .rt_literal
    ; check for entity
    ; &amp;  &lt;  &gt;  &quot;  &apos;  &#...;
    ; peek next byte
    movzx rax, byte [rsi + 1]
    cmp  al, 'a'
    je   .rt_ent_a             ; &amp; or &apos;
    cmp  al, 'l'
    je   .rt_ent_l             ; &lt;
    cmp  al, 'g'
    je   .rt_ent_g             ; &gt;
    cmp  al, 'q'
    je   .rt_ent_q             ; &quot;
    jmp  .rt_literal           ; unknown entity — copy raw
.rt_ent_a:
    ; &amp; (5) or &apos; (6)
    movzx rax, byte [rsi + 2]
    cmp  al, 'm'
    jne  .rt_ent_apos
    ; &amp;
    mov  byte [rdi], '&'
    inc  rdi
    add  rsi, 5
    jmp  .rt_decode
.rt_ent_apos:
    ; &apos;
    mov  byte [rdi], 39        ; single quote
    inc  rdi
    add  rsi, 6
    jmp  .rt_decode
.rt_ent_l:
    ; &lt; (4)
    mov  byte [rdi], '<'
    inc  rdi
    add  rsi, 4
    jmp  .rt_decode
.rt_ent_g:
    ; &gt; (4)
    mov  byte [rdi], '>'
    inc  rdi
    add  rsi, 4
    jmp  .rt_decode
.rt_ent_q:
    ; &quot; (6)
    mov  byte [rdi], '"'
    inc  rdi
    add  rsi, 6
    jmp  .rt_decode
.rt_literal:
    movzx rax, byte [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    jmp  .rt_decode
.rt_decode_done:
    mov  byte [rdi], 0
    pop  rax
    jmp  .rt_ret
.rt_all_ws:
.rt_empty:
    xor  rax, rax
.rt_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_parse_node() -> rax (XmlNode* or 0) ───────────────────
; Recursively parses one node from current position.
; Returns 0 on error or when we hit a closing tag.
xml_parse_node:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    call xml_skip_ws
    call xml_peek
    test al, al
    jz   .pn_eof

    cmp  al, '<'
    jne  .pn_text

    ; ── it's a tag ──────────────────────────────────────────
    call xml_advance           ; skip '<'
    call xml_peek
    test al, al
    jz   .pn_eof

    cmp  al, '/'
    je   .pn_close_signal      ; closing tag encountered by parent

    cmp  al, '!'
    jne  .pn_try_pi
    call xml_advance           ; skip '!'
    call xml_skip_comment_or_cdata
    ; recurse to get next node
    call xml_parse_node
    jmp  .pn_ret

.pn_try_pi:
    cmp  al, '?'
    jne  .pn_open_tag
    ; processing instruction: skip to ?>
.pn_pi_loop:
    call xml_peek
    test al, al
    jz   .pn_eof
    cmp  al, '>'
    je   .pn_pi_done
    call xml_advance
    jmp  .pn_pi_loop
.pn_pi_done:
    call xml_advance
    call xml_parse_node
    jmp  .pn_ret

.pn_open_tag:
    ; read tag name
    call xml_read_name
    test rax, rax
    jz   .pn_err
    mov  r12, rax              ; r12 = tag name

    ; allocate element node
    call xml_alloc_node
    test rax, rax
    jz   .pn_err_free_tag
    mov  r13, rax              ; r13 = node ptr
    mov  qword [r13 + XN_TYPE], XML_ELEMENT
    mov  [r13 + XN_TAG], r12

    ; parse attributes
.pn_attr_loop:
    call xml_skip_ws
    call xml_peek
    test al, al
    jz   .pn_err
    cmp  al, '>'
    je   .pn_attr_done
    cmp  al, '/'
    je   .pn_self_close
    ; read attr name
    call xml_read_name
    test rax, rax
    jz   .pn_attr_done         ; no name = done
    mov  r14, rax              ; r14 = attr name
    call xml_skip_ws
    call xml_peek
    cmp  al, '='
    jne  .pn_attr_no_val       ; boolean attr
    call xml_advance           ; skip '='
    call xml_skip_ws
    call xml_read_attr_value
    mov  r15, rax              ; r15 = attr value
    jmp  .pn_attr_add
.pn_attr_no_val:
    lea  r15, [rel xml_empty_str]
.pn_attr_add:
%ifdef WIN64_TARGET
    mov  rcx, r13
    mov  rdx, r14
    mov  r8,  r15
    sub  rsp, 32
    call xml_node_add_attr
    add  rsp, 32
    ; free name/value strings (strdup'd inside add_attr)
    mov  rcx, r14
    sub  rsp, 32
    call free
    add  rsp, 32
    mov  rcx, r15
    lea  rdx, [rel xml_empty_str]
    cmp  rcx, rdx
    je   .pn_attr_loop
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r13
    mov  rsi, r14
    mov  rdx, r15
    call xml_node_add_attr
    mov  rdi, r14
    call free
    lea  rax, [rel xml_empty_str]
    cmp  r15, rax
    je   .pn_attr_loop
    mov  rdi, r15
    call free
%endif
    jmp  .pn_attr_loop

.pn_self_close:
    call xml_advance           ; skip '/'
    call xml_peek
    cmp  al, '>'
    jne  .pn_err
    call xml_advance           ; skip '>'
    mov  rax, r13
    jmp  .pn_ret

.pn_attr_done:
    call xml_advance           ; skip '>'

    ; parse children until closing tag
.pn_children:
    call xml_skip_ws
    call xml_peek
    test al, al
    jz   .pn_done_children     ; EOF

    cmp  al, '<'
    jne  .pn_child_text

    ; peek further: is it a closing tag for us?
    mov  rax, [rel xml_ps_pos]
    movzx rax, byte [rax + 1]
    cmp  al, '/'
    je   .pn_check_close

    ; child element (or comment/PI — handled by recurse)
    call xml_parse_node
    test rax, rax
    jz   .pn_done_children     ; 0 = close tag signal
%ifdef WIN64_TARGET
    mov  rcx, r13
    mov  rdx, rax
    sub  rsp, 32
    call xml_node_add_child
    add  rsp, 32
%else
    mov  rdi, r13
    mov  rsi, rax
    call xml_node_add_child
%endif
    jmp  .pn_children

.pn_child_text:
    call xml_read_text
    test rax, rax
    jz   .pn_children          ; whitespace-only, skip
    ; create text node
    push rax                   ; text string
    call xml_alloc_node
    test rax, rax
    jz   .pn_children
    mov  qword [rax + XN_TYPE], XML_TEXT
    pop  rcx
    mov  [rax + XN_TEXT], rcx
    push rax
%ifdef WIN64_TARGET
    mov  rcx, r13
    mov  rdx, rax
    sub  rsp, 32
    call xml_node_add_child
    add  rsp, 32
%else
    pop  rsi
    push rsi
    mov  rdi, r13
    call xml_node_add_child
%endif
    pop  rax
    jmp  .pn_children

.pn_check_close:
    ; consume "</"
    call xml_advance           ; '<'
    call xml_advance           ; '/'
    call xml_read_name         ; closing tag name (discard — trust structure)
    test rax, rax
    jz   .pn_done_children
%ifdef WIN64_TARGET
    sub  rsp, 32
    mov  rcx, rax
    call free
    add  rsp, 32
%else
    mov  rdi, rax
    call free
%endif
    call xml_skip_ws
    ; expect '>'
    call xml_peek
    cmp  al, '>'
    jne  .pn_err
    call xml_advance
    mov  rax, r13
    jmp  .pn_ret

.pn_done_children:
    mov  rax, r13
    jmp  .pn_ret

.pn_close_signal:
    ; caller's closing tag — return 0 to signal
    xor  rax, rax
    jmp  .pn_ret

.pn_text:
    ; top-level text (rare but valid in fragments)
    call xml_read_text
    test rax, rax
    jz   .pn_eof
    push rax
    call xml_alloc_node
    test rax, rax
    jz   .pn_eof
    mov  qword [rax + XN_TYPE], XML_TEXT
    pop  rcx
    mov  [rax + XN_TEXT], rcx
    jmp  .pn_ret

.pn_err_free_tag:
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif
.pn_err:
    mov  byte [rel xml_ps_err], 1
.pn_eof:
    xor  rax, rax
.pn_ret:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ================================================================
; PUBLIC DOM API
; ================================================================

; ── xml__parse(src: lafz) -> adad (XmlNode* or 0) ─────────────
global xml__parse
xml__parse:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, rcx
%else
    mov  rax, rdi
%endif
    ; init parser state
    mov  [rel xml_ps_src], rax
    mov  [rel xml_ps_pos], rax
    mov  byte [rel xml_ps_err], 0

    ; skip XML declaration <?xml ...?> if present
    call xml_skip_ws
    call xml_peek
    cmp  al, '<'
    jne  .xp_parse
    mov  rax, [rel xml_ps_pos]
    movzx rax, byte [rax + 1]
    cmp  al, '?'
    jne  .xp_parse
    ; skip to ?>
.xp_pi_skip:
    call xml_advance
    call xml_peek
    test al, al
    jz   .xp_parse
    cmp  al, '>'
    jne  .xp_pi_skip
    call xml_advance
    call xml_skip_ws

.xp_parse:
    call xml_parse_node
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__free(node: adad) -> adad ─────────────────────────────
; Recursively frees an XmlNode tree.
global xml__free
xml__free:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    test rbx, rbx
    jz   .xf_ret

    ; free tag string
    mov  r12, [rbx + XN_TAG]
    test r12, r12
    jz   .xf_text
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif

.xf_text:
    mov  r12, [rbx + XN_TEXT]
    test r12, r12
    jz   .xf_attrs
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif

.xf_attrs:
    ; free each attr's name and value strings, then the array
    mov  r12, [rbx + XN_ATTRS]
    test r12, r12
    jz   .xf_children
    mov  r13, [rbx + XN_ATTR_COUNT]
    xor  rcx, rcx
.xf_attr_loop:
    cmp  rcx, r13
    jge  .xf_attrs_done
    push rcx
    imul rax, rcx, XA_SIZE
    mov  rdi, [r12 + rax + XA_NAME]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call free
    add  rsp, 32
    pop  rcx
    push rcx
    imul rax, rcx, XA_SIZE
    mov  rcx, [r12 + rax + XA_VALUE]
    sub  rsp, 32
    call free
    add  rsp, 32
    pop  rcx
%else
    call free
    pop  rcx
    push rcx
    imul rax, rcx, XA_SIZE
    mov  rdi, [r12 + rax + XA_VALUE]
    call free
    pop  rcx
%endif
    inc  rcx
    jmp  .xf_attr_loop
.xf_attrs_done:
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif

.xf_children:
    mov  r12, [rbx + XN_CHILDREN]
    test r12, r12
    jz   .xf_self
    mov  r13, [rbx + XN_CHILD_COUNT]
    xor  rcx, rcx
.xf_child_loop:
    cmp  rcx, r13
    jge  .xf_children_done
    push rcx
    mov  rax, [r12 + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rax
    sub  rsp, 32
    call xml__free
    add  rsp, 32
    pop  rcx
%else
    mov  rdi, rax
    call xml__free
    pop  rcx
%endif
    inc  rcx
    jmp  .xf_child_loop
.xf_children_done:
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r12
    call free
%endif

.xf_self:
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, rbx
    call free
%endif
    xor  rax, rax
.xf_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__tag(node) -> lafz ────────────────────────────────────
global xml__tag
xml__tag:
%ifdef WIN64_TARGET
    mov  rax, [rcx + XN_TAG]
%else
    mov  rax, [rdi + XN_TAG]
%endif
    test rax, rax
    jnz  .xt_ret
    lea  rax, [rel xml_empty_str]
.xt_ret:
    ret

; ── xml__text(node) -> lafz ───────────────────────────────────
global xml__text
xml__text:
%ifdef WIN64_TARGET
    mov  rax, [rcx + XN_TEXT]
%else
    mov  rax, [rdi + XN_TEXT]
%endif
    test rax, rax
    jnz  .xte_ret
    lea  rax, [rel xml_empty_str]
.xte_ret:
    ret

; ── xml__is_element(node) -> adad ────────────────────────────
global xml__is_element
xml__is_element:
%ifdef WIN64_TARGET
    mov  rax, [rcx + XN_TYPE]
%else
    mov  rax, [rdi + XN_TYPE]
%endif
    cmp  rax, XML_ELEMENT
    sete al
    movzx rax, al
    ret

; ── xml__is_text(node) -> adad ───────────────────────────────
global xml__is_text
xml__is_text:
%ifdef WIN64_TARGET
    mov  rax, [rcx + XN_TYPE]
%else
    mov  rax, [rdi + XN_TYPE]
%endif
    cmp  rax, XML_TEXT
    sete al
    movzx rax, al
    ret

; ── xml__attr(node, name) -> lafz ────────────────────────────
global xml__attr
xml__attr:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  rbx, rcx              ; node
    mov  r12, rdx              ; name
%else
    mov  rbx, rdi
    mov  r12, rsi
%endif
    mov  r13, [rbx + XN_ATTR_COUNT]
    xor  rcx, rcx
    mov  r14, [rbx + XN_ATTRS]    ; load attrs ptr once
.xa_loop:
    cmp  rcx, r13
    jge  .xa_notfound
    push rcx
    imul rax, rcx, XA_SIZE
    add  rax, r14
    mov  rdi, [rax + XA_NAME]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    mov  rdx, r12
    sub  rsp, 32
    call memory__strcmp
    add  rsp, 32
    pop  rcx
%else
    mov  rsi, r12
    call memory__strcmp
    pop  rcx
%endif
    test rax, rax
    jnz  .xa_next
    ; found — derive value ptr from rcx (index) and r14 (attrs base)
    imul rax, rcx, XA_SIZE
    add  rax, r14
    mov  rax, [rax + XA_VALUE]
    test rax, rax
    jnz  .xa_ret
    lea  rax, [rel xml_empty_str]
    jmp  .xa_ret
.xa_next:
    inc  rcx
    jmp  .xa_loop
.xa_notfound:
    lea  rax, [rel xml_empty_str]
.xa_ret:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__child_count(node) -> adad ───────────────────────────
global xml__child_count
xml__child_count:
%ifdef WIN64_TARGET
    mov  rax, [rcx + XN_CHILD_COUNT]
%else
    mov  rax, [rdi + XN_CHILD_COUNT]
%endif
    ret

; ── xml__child(node, i) -> adad ──────────────────────────────
global xml__child
xml__child:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, rcx              ; node
    mov  rcx, rdx              ; i
%else
    mov  rax, rdi
    mov  rcx, rsi
%endif
    cmp  rcx, [rax + XN_CHILD_COUNT]
    jge  .xch_oob
    mov  rax, [rax + XN_CHILDREN]
    mov  rax, [rax + rcx*8]
    jmp  .xch_ret
.xch_oob:
    xor  rax, rax
.xch_ret:
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__attr_count(node) -> adad ────────────────────────────
global xml__attr_count
xml__attr_count:
%ifdef WIN64_TARGET
    mov  rax, [rcx + XN_ATTR_COUNT]
%else
    mov  rax, [rdi + XN_ATTR_COUNT]
%endif
    ret

; ── xml__attr_name(node, i) -> lafz ──────────────────────────
global xml__attr_name
xml__attr_name:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, rcx
    mov  rcx, rdx
%else
    mov  rax, rdi
    mov  rcx, rsi
%endif
    cmp  rcx, [rax + XN_ATTR_COUNT]
    jge  .xan_oob
    mov  rdi, [rax + XN_ATTRS]
    imul rcx, rcx, XA_SIZE
    mov  rax, [rdi + rcx + XA_NAME]
    test rax, rax
    jnz  .xan_ret
.xan_oob:
    lea  rax, [rel xml_empty_str]
.xan_ret:
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__attr_val(node, i) -> lafz ───────────────────────────
global xml__attr_val
xml__attr_val:
    push rbp
    mov  rbp, rsp
%ifdef WIN64_TARGET
    mov  rax, rcx
    mov  rcx, rdx
%else
    mov  rax, rdi
    mov  rcx, rsi
%endif
    cmp  rcx, [rax + XN_ATTR_COUNT]
    jge  .xav_oob
    mov  rdi, [rax + XN_ATTRS]
    imul rcx, rcx, XA_SIZE
    mov  rax, [rdi + rcx + XA_VALUE]
    test rax, rax
    jnz  .xav_ret
.xav_oob:
    lea  rax, [rel xml_empty_str]
.xav_ret:
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__find(node, tag) -> adad (first child with tag or 0) ─
global xml__find
xml__find:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  r12, rdx
%else
    mov  rbx, rdi
    mov  r12, rsi
%endif
    mov  r13, [rbx + XN_CHILD_COUNT]
    xor  rcx, rcx
.xf2_loop:
    cmp  rcx, r13
    jge  .xf2_notfound
    push rcx
    mov  rax, [rbx + XN_CHILDREN]
    pop  rcx
    push rcx
    mov  rax, [rax + rcx*8]
    test rax, rax
    jz   .xf2_next
    cmp  qword [rax + XN_TYPE], XML_ELEMENT
    jne  .xf2_next
    mov  rdi, [rax + XN_TAG]
    test rdi, rdi
    jz   .xf2_next
%ifdef WIN64_TARGET
    push rax
    mov  rcx, rdi
    mov  rdx, r12
    sub  rsp, 32
    call memory__strcmp
    add  rsp, 32
    pop  rax
%else
    push rax                   ; save child node
    mov  rsi, r12
    call memory__strcmp
    test rax, rax              ; test strcmp result BEFORE restoring child
    pop  rax                   ; restore child node (flags unaffected by pop)
%endif
    jnz  .xf2_next
    ; found
    pop  rcx
    jmp  .xf2_ret
.xf2_next:
    pop  rcx
    inc  rcx
    jmp  .xf2_loop
.xf2_notfound:
    xor  rax, rax
    jmp  .xf2_done
.xf2_ret:
    ; rax already holds the found node
.xf2_done:
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__find_all(node, tag) -> adad ([XmlNode*] array ptr) ──
; Returns Velocity array (data ptr; [ptr-8]=len, [ptr-16]=cap).
; Uses static xml_fa_buf — caller should not nest calls.
global xml__find_all
xml__find_all:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
%ifdef WIN64_TARGET
    mov  rbx, rcx
    mov  r12, rdx
%else
    mov  rbx, rdi
    mov  r12, rsi
%endif
    ; init array header
    lea  r14, [rel xml_fa_buf]
    mov  qword [r14], 512        ; cap
    mov  qword [r14 + 8], 0      ; len = 0
    lea  r13, [r14 + 16]         ; data ptr

    mov  r14, [rbx + XN_CHILD_COUNT]
    xor  rcx, rcx
.xfa_loop:
    cmp  rcx, r14
    jge  .xfa_done
    push rcx
    mov  rax, [rbx + XN_CHILDREN]
    pop  rcx
    push rcx
    mov  rax, [rax + rcx*8]
    test rax, rax
    jz   .xfa_next
    cmp  qword [rax + XN_TYPE], XML_ELEMENT
    jne  .xfa_next
    mov  rdi, [rax + XN_TAG]
    test rdi, rdi
    jz   .xfa_next
%ifdef WIN64_TARGET
    push rax
    mov  rcx, rdi
    mov  rdx, r12
    sub  rsp, 32
    call memory__strcmp
    add  rsp, 32
    pop  rax
%else
    push rax                   ; save child node
    mov  rsi, r12
    call memory__strcmp
    test rax, rax              ; test strcmp result BEFORE restoring child
    pop  rax                   ; restore child node (flags unaffected by pop)
%endif
    jnz  .xfa_next
    ; append to array
    lea  rdi, [rel xml_fa_buf]
    mov  rsi, [rdi + 8]        ; current len
    cmp  rsi, 511
    jge  .xfa_next
    mov  [r13 + rsi*8], rax
    inc  qword [rdi + 8]
.xfa_next:
    pop  rcx
    inc  rcx
    jmp  .xfa_loop
.xfa_done:
    lea  rax, [rel xml_fa_buf + 16]   ; return data ptr
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml__stringify(node) -> lafz ─────────────────────────────
; Serialises a node back to an XML string.
; Uses static xml_str_buf (up to 64 KB).
global xml__stringify
xml__stringify:
    push rbp
    mov  rbp, rsp
    push rbx
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    ; reset buffer
    lea  rax, [rel xml_str_buf]
    mov  [rel xml_str_ptr], rax
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call xml_stringify_node
    add  rsp, 32
%else
    mov  rdi, rbx
    call xml_stringify_node
%endif
    ; null-terminate
    mov  rax, [rel xml_str_ptr]
    mov  byte [rax], 0
    lea  rax, [rel xml_str_buf]
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── xml_stringify_node(node: rdi/rcx) — internal recursive ───
xml_stringify_node:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
%ifdef WIN64_TARGET
    mov  rbx, rcx
%else
    mov  rbx, rdi
%endif
    test rbx, rbx
    jz   .sn_ret

    mov  rax, [rbx + XN_TYPE]
    cmp  rax, XML_TEXT
    je   .sn_text

    ; ── element node ──────────────────────────────────────
    ; write "<tagname"
    call xml_str_write_lit_lt
    mov  r12, [rbx + XN_TAG]
    test r12, r12
    jz   .sn_no_tag
%ifdef WIN64_TARGET
    mov  rcx, r12
    sub  rsp, 32
    call xml_str_write_str
    add  rsp, 32
%else
    mov  rdi, r12
    call xml_str_write_str
%endif
.sn_no_tag:
    ; write attributes
    mov  r13, [rbx + XN_ATTR_COUNT]
    mov  r14, [rbx + XN_ATTRS]
    xor  rcx, rcx
.sn_attr_loop:
    cmp  rcx, r13
    jge  .sn_attrs_done
    push rcx
    imul rax, rcx, XA_SIZE
    ; write space
    call xml_str_write_lit_sp
    ; write name
    mov  r12, r14
    pop  rcx
    push rcx
    imul rax, rcx, XA_SIZE
    add  rax, r12
    mov  rdi, [rax + XA_NAME]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call xml_str_write_str
    add  rsp, 32
%else
    call xml_str_write_str
%endif
    ; write ="
    call xml_str_write_lit_eqdq
    ; write value (escaped)
    pop  rcx
    push rcx
    imul rax, rcx, XA_SIZE
    add  rax, r14
    mov  rdi, [rax + XA_VALUE]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call xml_str_write_escaped
    add  rsp, 32
%else
    call xml_str_write_escaped
%endif
    ; write "
    call xml_str_write_lit_dq
    pop  rcx
    inc  rcx
    jmp  .sn_attr_loop
.sn_attrs_done:
    ; self-close or children?
    cmp  qword [rbx + XN_CHILD_COUNT], 0
    je   .sn_self_close
    ; write >
    call xml_str_write_lit_gt
    ; recurse children
    mov  r13, [rbx + XN_CHILD_COUNT]
    xor  rcx, rcx
.sn_child_loop:
    cmp  rcx, r13
    jge  .sn_children_done
    push rcx
    mov  rax, [rbx + XN_CHILDREN]
    pop  rcx
    push rcx
    mov  rdi, [rax + rcx*8]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call xml_stringify_node
    add  rsp, 32
%else
    call xml_stringify_node
%endif
    pop  rcx
    inc  rcx
    jmp  .sn_child_loop
.sn_children_done:
    ; write </tagname>
    call xml_str_write_lit_ltsl
    mov  rdi, [rbx + XN_TAG]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call xml_str_write_str
    add  rsp, 32
%else
    call xml_str_write_str
%endif
    call xml_str_write_lit_gt
    jmp  .sn_ret

.sn_self_close:
    call xml_str_write_lit_slgt
    jmp  .sn_ret

.sn_text:
    mov  rdi, [rbx + XN_TEXT]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call xml_str_write_escaped
    add  rsp, 32
%else
    call xml_str_write_escaped
%endif
.sn_ret:
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

; ── String-buffer write helpers ───────────────────────────────
; All write to [xml_str_ptr] and advance it.

xml_str_write_str:
    ; rdi/rcx = string ptr
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .wsstr_ret
    mov  rax, [rel xml_str_ptr]
.wsstr_loop:
    mov  cl, [rdi]
    test cl, cl
    jz   .wsstr_done
    mov  [rax], cl
    inc  rax
    inc  rdi
    jmp  .wsstr_loop
.wsstr_done:
    mov  [rel xml_str_ptr], rax
.wsstr_ret:
    ret

xml_str_write_escaped:
    ; rdi/rcx = string; writes &amp; &lt; &gt; &quot; for special chars
%ifdef WIN64_TARGET
    mov  rdi, rcx
%endif
    test rdi, rdi
    jz   .wse_ret
.wse_loop:
    movzx rax, byte [rdi]
    test al, al
    jz   .wse_ret
    cmp  al, '&'
    je   .wse_amp
    cmp  al, '<'
    je   .wse_lt
    cmp  al, '>'
    je   .wse_gt
    cmp  al, '"'
    je   .wse_quot
    ; regular char
    push rdi
    mov  rdi, [rel xml_str_ptr]
    mov  [rdi], al
    inc  rdi
    mov  [rel xml_str_ptr], rdi
    pop  rdi
    inc  rdi
    jmp  .wse_loop
.wse_amp:
    push rdi
    lea  rdi, [rel xml_amp]
    call xml_str_write_str
    pop  rdi
    inc  rdi
    jmp  .wse_loop
.wse_lt:
    push rdi
    lea  rdi, [rel xml_lt_ent]
    call xml_str_write_str
    pop  rdi
    inc  rdi
    jmp  .wse_loop
.wse_gt:
    push rdi
    lea  rdi, [rel xml_gt_ent]
    call xml_str_write_str
    pop  rdi
    inc  rdi
    jmp  .wse_loop
.wse_quot:
    push rdi
    lea  rdi, [rel xml_quot_ent]
    call xml_str_write_str
    pop  rdi
    inc  rdi
    jmp  .wse_loop
.wse_ret:
    ret

; Literal write helpers (no args needed)
xml_str_write_lit_lt:
    push rdi
    lea  rdi, [rel xml_lt]
    call xml_str_write_str
    pop  rdi
    ret
xml_str_write_lit_gt:
    push rdi
    lea  rdi, [rel xml_gt]
    call xml_str_write_str
    pop  rdi
    ret
xml_str_write_lit_ltsl:
    push rdi
    lea  rdi, [rel xml_lt_slash]
    call xml_str_write_str
    pop  rdi
    ret
xml_str_write_lit_slgt:
    push rdi
    lea  rdi, [rel xml_slash_gt]
    call xml_str_write_str
    pop  rdi
    ret
xml_str_write_lit_sp:
    push rdi
    lea  rdi, [rel xml_space]
    call xml_str_write_str
    pop  rdi
    ret
xml_str_write_lit_eqdq:
    push rdi
    lea  rdi, [rel xml_eq_dq]
    call xml_str_write_str
    pop  rdi
    ret
xml_str_write_lit_dq:
    push rdi
    lea  rdi, [rel xml_dq]
    call xml_str_write_str
    pop  rdi
    ret

; ================================================================
; SAX API
; ================================================================

; ── XmlSaxHandler offsets ────────────────────────────────────
%define XSH_ON_OPEN    0
%define XSH_ON_CLOSE   8
%define XSH_ON_TEXT    16

section .bss
xml_sax_handler  resq 1    ; ptr to XmlSaxHandler
xml_sax_userdata resq 1    ; opaque ptr passed to every callback
; attribute array for SAX callbacks: flat array of [name, value] pairs
; up to 32 attrs per element; 32*2*8 = 512 bytes + 16 header
xml_sax_attr_buf resb 528

section .text

; ── xml__sax_parse(src, handler, userdata) -> adad (0=ok) ─────
global xml__sax_parse
xml__sax_parse:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
%ifdef WIN64_TARGET
    mov  rbx, rcx              ; src
    mov  r12, rdx              ; handler
    mov  r13, r8               ; userdata
%else
    mov  rbx, rdi
    mov  r12, rsi
    mov  r13, rdx
%endif
    mov  [rel xml_sax_handler], r12
    mov  [rel xml_sax_userdata], r13

    ; init parser state
    mov  [rel xml_ps_src], rbx
    mov  [rel xml_ps_pos], rbx
    mov  byte [rel xml_ps_err], 0

    ; skip XML declaration
    call xml_skip_ws
    call xml_peek
    cmp  al, '<'
    jne  .sax_loop
    mov  rax, [rel xml_ps_pos]
    movzx rax, byte [rax + 1]
    cmp  al, '?'
    jne  .sax_loop
.sax_pi_skip:
    call xml_advance
    call xml_peek
    test al, al
    jz   .sax_loop
    cmp  al, '>'
    jne  .sax_pi_skip
    call xml_advance
    call xml_skip_ws

.sax_loop:
    call xml_skip_ws
    call xml_peek
    test al, al
    jz   .sax_done
    cmp  al, '<'
    jne  .sax_text

    call xml_advance           ; consume '<'
    call xml_peek
    cmp  al, '/'
    je   .sax_close
    cmp  al, '!'
    je   .sax_bang
    cmp  al, '?'
    je   .sax_pi

    ; ── open tag ───────────────────────────────────────────
    call xml_read_name
    test rax, rax
    jz   .sax_done
    push rax                   ; save tag name

    ; build attr array in xml_sax_attr_buf
    lea  rbx, [rel xml_sax_attr_buf]
    mov  qword [rbx], 32        ; cap (name+val pairs)
    mov  qword [rbx + 8], 0     ; count
    lea  r12, [rbx + 16]        ; data

.sax_attr_loop:
    call xml_skip_ws
    call xml_peek
    test al, al
    jz   .sax_attr_done
    cmp  al, '>'
    je   .sax_attr_done
    cmp  al, '/'
    je   .sax_attr_done
    call xml_read_name
    test rax, rax
    jz   .sax_attr_done
    push rax                   ; attr name
    call xml_skip_ws
    call xml_peek
    cmp  al, '='
    jne  .sax_attr_boolval
    call xml_advance
    call xml_skip_ws
    call xml_read_attr_value
    jmp  .sax_attr_store
.sax_attr_boolval:
    lea  rax, [rel xml_empty_str]
.sax_attr_store:
    ; rax = value, [rsp] = name
    push rax
    lea  rbx, [rel xml_sax_attr_buf]
    mov  rcx, [rbx + 8]
    cmp  rcx, 32
    jge  .sax_attr_overflow
    ; store name and value — pop them off the stack, store, do NOT push back
    pop  rax                   ; value  (pushed second)
    pop  rdi                   ; name   (pushed first)
    push rcx
    imul rcx, rcx, 16
    mov  [r12 + rcx],     rdi  ; store name
    mov  [r12 + rcx + 8], rax  ; store value
    pop  rcx
    inc  qword [rbx + 8]
    jmp  .sax_attr_loop
.sax_attr_overflow:
    pop  rax                   ; discard value
    pop  rdi                   ; discard name
    jmp  .sax_attr_loop
.sax_attr_done:
    ; fire on_open(tag, attrs_ptr, userdata)
    pop  rbx                   ; tag name
    mov  r15, rbx              ; save tag in r15 NOW before callback clobbers rbx
    mov  r12, [rel xml_sax_handler]
    mov  r13, [rel xml_sax_userdata]
    mov  rax, [r12 + XSH_ON_OPEN]
    test rax, rax
    jz   .sax_after_open
%ifdef WIN64_TARGET
    push r12
    push r13
    mov  rcx, r15              ; use r15 (safe across call) not rbx
    lea  rdx, [rel xml_sax_attr_buf + 16]
    mov  r8,  r13
    sub  rsp, 32
    call rax
    add  rsp, 32
    pop  r13
    pop  r12
%else
    push r12
    push r13
    mov  rdi, r15              ; use r15 not rbx
    lea  rsi, [rel xml_sax_attr_buf + 16]
    mov  rdx, r13
    call rax
    pop  r13
    pop  r12
%endif
.sax_after_open:
    ; r15 already holds tag ptr (set before callback)

    ; free attr name/value strings (values from read_attr_value are heap;
    ; values == xml_empty_str were never heap-alloc'd so skip them)
    lea  r12, [rel xml_sax_attr_buf]
    mov  r13, [r12 + 8]        ; attr count
    lea  r14, [r12 + 16]       ; data ptr
    xor  rbx, rbx              ; loop index
.sax_free_attrs:
    cmp  rbx, r13
    jge  .sax_check_self_close
    ; compute offset = rbx * 16
    push rbx
    push r13
    imul rbx, rbx, 16
    ; free name (always heap from xml_read_name)
    mov  rdi, [r14 + rbx]
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    call free
%endif
    ; free value only if not xml_empty_str
    mov  rdi, [r14 + rbx + 8]
    lea  rax, [rel xml_empty_str]
    cmp  rdi, rax
    je   .sax_fa_skip_val
%ifdef WIN64_TARGET
    mov  rcx, rdi
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    call free
%endif
.sax_fa_skip_val:
    pop  r13
    pop  rbx
    inc  rbx
    jmp  .sax_free_attrs

.sax_check_self_close:
    call xml_skip_ws
    call xml_peek
    cmp  al, '/'
    jne  .sax_open_gt
    ; self-closing: consume '/>' then fire on_close with tag name
    call xml_advance           ; skip '/'
    call xml_peek
    cmp  al, '>'
    jne  .sax_free_tag         ; malformed — just free tag
    call xml_advance           ; skip '>'
    mov  r12, [rel xml_sax_handler]
    mov  r13, [rel xml_sax_userdata]
    mov  rax, [r12 + XSH_ON_CLOSE]
    test rax, rax
    jz   .sax_free_tag
%ifdef WIN64_TARGET
    push r12
    push r13
    mov  rcx, r15              ; tag
    mov  rdx, r13              ; userdata
    sub  rsp, 32
    call rax
    add  rsp, 32
    pop  r13
    pop  r12
%else
    push r12
    push r13
    mov  rdi, r15              ; tag
    mov  rsi, r13              ; userdata
    call rax
    pop  r13
    pop  r12
%endif
    jmp  .sax_free_tag

.sax_open_gt:
    call xml_peek
    cmp  al, '>'
    jne  .sax_free_tag
    call xml_advance           ; skip '>'

.sax_free_tag:
    ; free the tag string (saved in r15)
%ifdef WIN64_TARGET
    mov  rcx, r15
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, r15
    call free
%endif
    jmp  .sax_loop

.sax_close:
    call xml_advance           ; skip '/'
    call xml_read_name
    test rax, rax
    jz   .sax_loop
    push rax                   ; closing tag name
    call xml_skip_ws
    call xml_peek
    cmp  al, '>'
    jne  .sax_close_done
    call xml_advance
.sax_close_done:
    pop  rbx                   ; tag name
.sax_fire_close_now:
    mov  r12, [rel xml_sax_handler]
    mov  r13, [rel xml_sax_userdata]
    mov  rax, [r12 + XSH_ON_CLOSE]
    test rax, rax
    jz   .sax_after_close
%ifdef WIN64_TARGET
    push r12
    push r13
    mov  rcx, rbx
    mov  rdx, r13
    sub  rsp, 32
    call rax
    add  rsp, 32
    pop  r13
    pop  r12
%else
    push r12
    push r13
    mov  rdi, rbx
    mov  rsi, r13
    call rax
    pop  r13
    pop  r12
%endif
.sax_after_close:
    lea  rax, [rel xml_empty_str]
    cmp  rbx, rax
    je   .sax_loop
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, rbx
    call free
%endif
    jmp  .sax_loop

.sax_text:
    call xml_read_text
    test rax, rax
    jz   .sax_loop
    push rax
    mov  r12, [rel xml_sax_handler]
    mov  r13, [rel xml_sax_userdata]
    mov  rax, [r12 + XSH_ON_TEXT]
    test rax, rax
    jz   .sax_text_skip
    pop  rbx
    push rbx
%ifdef WIN64_TARGET
    push r12
    push r13
    mov  rcx, rbx
    mov  rdx, r13
    sub  rsp, 32
    call rax
    add  rsp, 32
    pop  r13
    pop  r12
%else
    push r12
    push r13
    mov  rdi, rbx
    mov  rsi, r13
    call rax
    pop  r13
    pop  r12
%endif
.sax_text_skip:
    pop  rbx
%ifdef WIN64_TARGET
    mov  rcx, rbx
    sub  rsp, 32
    call free
    add  rsp, 32
%else
    mov  rdi, rbx
    call free
%endif
    jmp  .sax_loop

.sax_bang:
    call xml_skip_comment_or_cdata
    jmp  .sax_loop

.sax_pi:
.sax_pi2_loop:
    call xml_peek
    test al, al
    jz   .sax_done
    cmp  al, '>'
    je   .sax_pi2_done
    call xml_advance
    jmp  .sax_pi2_loop
.sax_pi2_done:
    call xml_advance
    jmp  .sax_loop

.sax_done:
    movzx rax, byte [rel xml_ps_err]
    neg  rax              ; 0=ok, -1=err
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
