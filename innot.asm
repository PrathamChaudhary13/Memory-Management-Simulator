; ============================================================
;  MEMORY MANAGEMENT SIMULATOR  (TASM / 16-bit DOS version)
;  Assemble:  tasm inno_tasm.asm
;  Link:      tlink inno_tasm.obj
;  Run:       inno_tasm.exe
; ============================================================
        .model small
        .stack 100h
        jumps                       ; let conditional jumps reach far labels

STATE_SIZE equ 36                   ; 18 words saved to file

        .data
titleMsg    db 13,10,'===== MEMORY MANAGEMENT SIMULATOR =====',13,10,'$'

menuMsg     db 13,10,'1. First Fit',13,10
            db '2. Best Fit',13,10
            db '3. Worst Fit',13,10
            db '4. Deallocate Process',13,10
            db '5. Display Memory Map',13,10
            db '6. Memory Analytics',13,10
            db '7. Exit',13,10
            db '8. Reset saved memory',13,10
            db 'Enter choice: $'

pidMsg      db 13,10,'Enter process ID (1-99): $'
sizeMsg     db 'Enter process size: $'
freeMsg     db 13,10,'Enter process ID to deallocate: $'

allocMsg    db 13,10,'Allocation successful. Partition: $'
failMsg     db 13,10,'Allocation failed: no suitable partition.',13,10,'$'
releaseMsg  db 13,10,'Process deallocated successfully.',13,10,'$'
notFoundMsg db 13,10,'Process not found.',13,10,'$'
duplicateMsg db 13,10,'Process ID already exists.',13,10,'$'
invalidChoiceMsg db 13,10,'Invalid menu choice.',13,10,'$'
invalidPidMsg db 13,10,'Invalid process ID. Use 1-99.',13,10,'$'
invalidSizeMsg db 13,10,'Invalid size. Enter a positive number.',13,10,'$'
resetMsg    db 13,10,'All memory cleared and saved.',13,10,'$'

mapTitle    db 13,10,'--- MEMORY MAP ---',13,10,'$'
partMsg     db 'Partition $'
capacityMsg db ' | Capacity: $'
ownerMsg    db ' | Process ID: $'
freeText    db 'FREE',13,10,'$'
usedText    db ' ALLOCATED',13,10,'$'

statsTitle  db 13,10,'--- MEMORY ANALYTICS ---',13,10,'$'
totalMsg    db 'Total memory: $'
freeTotalMsg db 13,10,'Free memory: $'
usedTotalMsg db 13,10,'Allocated partition capacity: $'
fragMsg     db 13,10,'Internal fragmentation: $'
successMsg  db 13,10,'Successful allocations: $'
failureMsg  db 13,10,'Failed allocations: $'
byeMsg      db 13,10,'Simulator closed.',13,10,'$'

fileName    db 'memstate.dat',0

blockTbl    dw 100,200,150,300,250,120,400,180
totalMemory dw 1700

; ---- saved state block (36 bytes: owners, requests, counters) ----
stateBlock  label word
ownerTbl    dw 8 dup(0)
reqTbl      dw 8 dup(0)
successCnt  dw 0
failCnt     dw 0

; ---- working variables ----
menuChoice  dw 0
procId      dw 0
reqSize     dw 0
algoSel     dw 0
bestIndex   dw 0FFFFh               ; byte offset into tables, FFFFh = none
bestSize    dw 0
freeTotal   dw 0
allocCap    dw 0
fragTotal   dw 0
idx         dw 0                    ; byte offset (0,2,4,...,14)
fileHandle  dw 0

inBuf       db 7,0,7 dup(0)         ; DOS buffered-input buffer

; ============================================================
        .code
main:
        mov  ax, @data
        mov  ds, ax
        mov  es, ax
        call LoadState

MAIN_MENU:
        lea  dx, titleMsg
        call PrintStr
        lea  dx, menuMsg
        call PrintStr

        call ReadDec
        mov  menuChoice, ax

        cmp  ax, 1
        je   FIRST_FIT
        cmp  ax, 2
        je   BEST_FIT
        cmp  ax, 3
        je   WORST_FIT
        cmp  ax, 4
        je   DO_DEALLOC
        cmp  ax, 5
        je   DISPLAY_MAP
        cmp  ax, 6
        je   DO_STATS
        cmp  ax, 7
        je   EXIT_PROGRAM
        cmp  ax, 8
        je   DO_RESET

        lea  dx, invalidChoiceMsg
        call PrintStr
        jmp  MAIN_MENU

FIRST_FIT:
        mov  algoSel, 1
        jmp  DO_ALLOC
BEST_FIT:
        mov  algoSel, 2
        jmp  DO_ALLOC
WORST_FIT:
        mov  algoSel, 3

; ------------------------------------------------------------
DO_ALLOC:
        lea  dx, pidMsg
        call PrintStr
        call ReadDec
        mov  procId, ax
        cmp  ax, 1
        jb   INVALID_PID
        cmp  ax, 99
        ja   INVALID_PID

        lea  dx, sizeMsg
        call PrintStr
        call ReadDec
        mov  reqSize, ax
        cmp  ax, 0
        je   INVALID_SIZE

        xor  si, si
CHECK_DUPLICATE:
        cmp  si, 16
        jae  START_SEARCH
        mov  ax, ownerTbl[si]
        cmp  ax, 0
        je   DUPLICATE_NEXT
        cmp  ax, procId
        je   DUPLICATE_PID
DUPLICATE_NEXT:
        add  si, 2
        jmp  CHECK_DUPLICATE

START_SEARCH:
        mov  bestIndex, 0FFFFh
        mov  bestSize, 0
        xor  si, si

SEARCH_LOOP:
        cmp  si, 16
        jae  SEARCH_DONE

        cmp  ownerTbl[si], 0
        jne  NEXT_PARTITION

        mov  ax, blockTbl[si]
        cmp  ax, reqSize
        jb   NEXT_PARTITION

        cmp  algoSel, 1
        je   SELECT_PARTITION
        cmp  algoSel, 2
        je   CHECK_BEST
        jmp  CHECK_WORST

CHECK_BEST:
        cmp  bestIndex, 0FFFFh
        je   SAVE_CANDIDATE
        mov  ax, blockTbl[si]
        cmp  ax, bestSize
        jb   SAVE_CANDIDATE
        jmp  NEXT_PARTITION

CHECK_WORST:
        cmp  bestIndex, 0FFFFh
        je   SAVE_CANDIDATE
        mov  ax, blockTbl[si]
        cmp  ax, bestSize
        ja   SAVE_CANDIDATE
        jmp  NEXT_PARTITION

SAVE_CANDIDATE:
        mov  bestIndex, si
        mov  ax, blockTbl[si]
        mov  bestSize, ax
        jmp  NEXT_PARTITION

SELECT_PARTITION:
        mov  bestIndex, si
        jmp  SEARCH_DONE

NEXT_PARTITION:
        add  si, 2
        jmp  SEARCH_LOOP

SEARCH_DONE:
        cmp  bestIndex, 0FFFFh
        je   ALLOCATION_FAILED

        mov  bx, bestIndex
        mov  ax, procId
        mov  ownerTbl[bx], ax
        mov  ax, reqSize
        mov  reqTbl[bx], ax

        inc  successCnt
        call SaveState

        lea  dx, allocMsg
        call PrintStr
        mov  ax, bestIndex
        shr  ax, 1                  ; byte offset -> index
        inc  ax                     ; 1-based partition number
        call PrintDec
        call NewLine
        jmp  MAIN_MENU

ALLOCATION_FAILED:
        inc  failCnt
        call SaveState
        lea  dx, failMsg
        call PrintStr
        jmp  MAIN_MENU

INVALID_PID:
        lea  dx, invalidPidMsg
        call PrintStr
        jmp  MAIN_MENU

INVALID_SIZE:
        lea  dx, invalidSizeMsg
        call PrintStr
        jmp  MAIN_MENU

DUPLICATE_PID:
        lea  dx, duplicateMsg
        call PrintStr
        jmp  MAIN_MENU

; ------------------------------------------------------------
DO_DEALLOC:
        lea  dx, freeMsg
        call PrintStr
        call ReadDec
        mov  procId, ax
        cmp  ax, 0                  ; 0 means "free slot", never a real process
        je   REL_NOT_FOUND

        xor  si, si
REL_LOOP:
        cmp  si, 16
        jae  REL_NOT_FOUND
        mov  ax, ownerTbl[si]
        cmp  ax, procId
        je   REL_FOUND
        add  si, 2
        jmp  REL_LOOP

REL_FOUND:
        mov  ownerTbl[si], 0
        mov  reqTbl[si], 0
        call SaveState
        lea  dx, releaseMsg
        call PrintStr
        jmp  MAIN_MENU

REL_NOT_FOUND:
        lea  dx, notFoundMsg
        call PrintStr
        jmp  MAIN_MENU

; ------------------------------------------------------------
DISPLAY_MAP:
        lea  dx, mapTitle
        call PrintStr
        mov  idx, 0

MAP_LOOP:
        cmp  idx, 16
        jae  MAP_DONE

        lea  dx, partMsg
        call PrintStr
        mov  ax, idx
        shr  ax, 1
        inc  ax
        call PrintDec

        lea  dx, capacityMsg
        call PrintStr
        mov  si, idx
        mov  ax, blockTbl[si]
        call PrintDec

        lea  dx, ownerMsg
        call PrintStr
        mov  si, idx
        mov  ax, ownerTbl[si]
        cmp  ax, 0
        je   MAP_FREE

        call PrintDec
        lea  dx, usedText
        call PrintStr
        jmp  MAP_NEXT

MAP_FREE:
        lea  dx, freeText
        call PrintStr

MAP_NEXT:
        add  idx, 2
        jmp  MAP_LOOP

MAP_DONE:
        jmp  MAIN_MENU

; ------------------------------------------------------------
DO_STATS:
        mov  freeTotal, 0
        mov  allocCap, 0
        mov  fragTotal, 0
        xor  si, si

STATS_LOOP:
        cmp  si, 16
        jae  STATS_DONE

        mov  ax, ownerTbl[si]
        cmp  ax, 0
        jne  STATS_OCCUPIED

        mov  ax, blockTbl[si]
        add  freeTotal, ax
        jmp  STATS_NEXT

STATS_OCCUPIED:
        mov  ax, blockTbl[si]
        add  allocCap, ax
        sub  ax, reqTbl[si]
        add  fragTotal, ax

STATS_NEXT:
        add  si, 2
        jmp  STATS_LOOP

STATS_DONE:
        lea  dx, statsTitle
        call PrintStr

        lea  dx, totalMsg
        call PrintStr
        mov  ax, totalMemory
        call PrintDec

        lea  dx, freeTotalMsg
        call PrintStr
        mov  ax, freeTotal
        call PrintDec

        lea  dx, usedTotalMsg
        call PrintStr
        mov  ax, allocCap
        call PrintDec

        lea  dx, fragMsg
        call PrintStr
        mov  ax, fragTotal
        call PrintDec

        lea  dx, successMsg
        call PrintStr
        mov  ax, successCnt
        call PrintDec

        lea  dx, failureMsg
        call PrintStr
        mov  ax, failCnt
        call PrintDec
        call NewLine
        jmp  MAIN_MENU

; ------------------------------------------------------------
DO_RESET:
        call ClearState
        call SaveState
        lea  dx, resetMsg
        call PrintStr
        jmp  MAIN_MENU

EXIT_PROGRAM:
        call SaveState
        lea  dx, byeMsg
        call PrintStr
        mov  ax, 4C00h
        int  21h

; ============================================================
;  Helper routines
; ============================================================

; PrintStr: DX = offset of '$'-terminated string
PrintStr proc
        push ax
        mov  ah, 09h
        int  21h
        pop  ax
        ret
PrintStr endp

; NewLine: prints CR LF
NewLine proc
        push ax
        push dx
        mov  ah, 02h
        mov  dl, 13
        int  21h
        mov  dl, 10
        int  21h
        pop  dx
        pop  ax
        ret
NewLine endp

; PrintDec: prints unsigned AX in decimal
PrintDec proc
        push ax
        push bx
        push cx
        push dx
        xor  cx, cx
        mov  bx, 10
pd_div:
        xor  dx, dx
        div  bx
        push dx
        inc  cx
        test ax, ax
        jnz  pd_div
pd_out:
        pop  dx
        add  dl, '0'
        mov  ah, 02h
        int  21h
        loop pd_out
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
PrintDec endp

; ReadDec: reads a line, returns unsigned value in AX.
;          Returns 0 for empty, non-numeric or overflowing input
;          (0 is rejected as invalid by every caller).
ReadDec proc
        push bx
        push cx
        push dx
        push si
        push di

        lea  dx, inBuf
        mov  ah, 0Ah
        int  21h
        mov  ah, 02h                ; DOS echoes CR only; add the LF
        mov  dl, 10
        int  21h

        xor  ax, ax
        lea  si, inBuf+2
        mov  cl, inBuf[1]
        xor  ch, ch
        jcxz rd_done
        mov  bx, 10

rd_loop:
        xor  dx, dx
        mov  dl, [si]
        sub  dl, '0'
        cmp  dl, 9
        ja   rd_bad
        mov  di, dx                 ; save digit (mul clobbers DX)
        mul  bx                     ; DX:AX = AX * 10
        jc   rd_bad                 ; overflow beyond 16 bits
        add  ax, di
        jc   rd_bad
        inc  si
        loop rd_loop
        jmp  rd_done

rd_bad:
        xor  ax, ax
rd_done:
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
ReadDec endp

; ClearState: zero the saved state block
ClearState proc
        push ax
        push cx
        push di
        lea  di, stateBlock
        mov  cx, STATE_SIZE/2
        xor  ax, ax
        cld
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret
ClearState endp

; CloseFile: closes the handle stored in fileHandle
CloseFile proc
        push ax
        push bx
        mov  bx, fileHandle
        mov  ah, 3Eh
        int  21h
        pop  bx
        pop  ax
        ret
CloseFile endp

; LoadState: read memstate.dat into stateBlock (clears state on failure)
LoadState proc
        push ax
        push bx
        push cx
        push dx

        mov  ax, 3D00h              ; open for reading
        lea  dx, fileName
        int  21h
        jc   ls_done                ; no file yet -> keep defaults

        mov  fileHandle, ax
        mov  bx, ax
        mov  ah, 3Fh                ; read
        mov  cx, STATE_SIZE
        lea  dx, stateBlock
        int  21h
        jc   ls_bad
        cmp  ax, STATE_SIZE
        jne  ls_bad

        call CloseFile
        jmp  ls_done

ls_bad:
        call CloseFile
        call ClearState
ls_done:
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
LoadState endp

; SaveState: write stateBlock to memstate.dat (create/truncate)
SaveState proc
        push ax
        push bx
        push cx
        push dx

        mov  ah, 3Ch                ; create / truncate
        xor  cx, cx
        lea  dx, fileName
        int  21h
        jc   ss_done

        mov  fileHandle, ax
        mov  bx, ax
        mov  ah, 40h                ; write
        mov  cx, STATE_SIZE
        lea  dx, stateBlock
        int  21h

        call CloseFile
ss_done:
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
SaveState endp

        end main