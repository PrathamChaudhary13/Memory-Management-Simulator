%include "io.inc"

section .data
    titleMsg        db 10,'===== MEMORY MANAGEMENT SIMULATOR =====',10,0

    menuMsg         db 10,'1. First Fit',10
                    db '2. Best Fit',10
                    db '3. Worst Fit',10
                    db '4. Deallocate Process',10
                    db '5. Display Memory Map',10
                    db '6. Memory Analytics',10
                    db '7. Exit',10
                    db '8. Reset saved memory',10
                    db 'Enter choice: ',0

    pidMsg          db 10,'Enter process ID (1-99): ',0
    sizeMsg         db 'Enter process size: ',0
    freeMsg         db 10,'Enter process ID to deallocate: ',0

    allocMsg        db 10,'Allocation successful. Partition: ',0
    failMsg         db 10,'Allocation failed: no suitable partition.',10,0
    releaseMsg      db 10,'Process deallocated successfully.',10,0
    notFoundMsg     db 10,'Process not found.',10,0
    duplicateMsg    db 10,'Process ID already exists.',10,0
    invalidChoiceMsg db 10,'Invalid menu choice.',10,0
    invalidPidMsg   db 10,'Invalid process ID. Use 1-99.',10,0
    invalidSizeMsg  db 10,'Invalid size. Enter a positive number.',10,0
    resetMsg        db 10,'All memory cleared and saved.',10,0

    mapTitle        db 10,'--- MEMORY MAP ---',10,0
    partMsg         db 'Partition ',0
    capacityMsg     db ' | Capacity: ',0
    ownerMsg        db ' | Process ID: ',0
    freeText        db 'FREE',10,0
    usedText        db ' ALLOCATED',10,0

    statsTitle      db 10,'--- MEMORY ANALYTICS ---',10,0
    totalMsg        db 'Total memory: ',0
    freeTotalMsg    db 10,'Free memory: ',0
    usedTotalMsg    db 10,'Allocated partition capacity: ',0
    fragMsg         db 10,'Internal fragmentation: ',0
    successMsg      db 10,'Successful allocations: ',0
    failureMsg      db 10,'Failed allocations: ',0
    byeMsg          db 10,'Simulator closed.',10,0

    fileName        db 'memstate.dat',0

    nCreateFileA    db 'CreateFileA',0
    nReadFile       db 'ReadFile',0
    nWriteFile      db 'WriteFile',0
    nCloseHandle    db 'CloseHandle',0

    blockTbl        dd 100,200,150,300,250,120,400,180
    totalMemory     dd 1700

stateBlock:
    ownerTbl        dd 0,0,0,0,0,0,0,0
    reqTbl          dd 0,0,0,0,0,0,0,0
    successCnt      dd 0
    failCnt         dd 0

    menuChoice      dd 0
    procId          dd 0
    reqSize         dd 0
    algoSel         dd 0

    bestIndex       dd 0FFFFFFFFh
    bestSize        dd 0

    freeTotal       dd 0
    allocCap        dd 0
    fragTotal       dd 0
    idx             dd 0
    fileHandle      dd 0
    bytesDone       dd 0

    pCreateFileA    dd 0
    pReadFile       dd 0
    pWriteFile      dd 0
    pCloseHandle    dd 0

    gfName          dd 0
    gfExp           dd 0

section .text
global CMAIN

CMAIN:
    mov ebp, esp
    call ResolveApis
    call LoadState

MAIN_MENU:
    PRINT_STRING titleMsg
    PRINT_STRING menuMsg

    GET_DEC 4, eax
    mov [menuChoice], eax

    cmp eax, 1
    je FIRST_FIT
    cmp eax, 2
    je BEST_FIT
    cmp eax, 3
    je WORST_FIT
    cmp eax, 4
    je DO_DEALLOC
    cmp eax, 5
    je DISPLAY_MAP
    cmp eax, 6
    je DO_STATS
    cmp eax, 7
    je EXIT_PROGRAM
    cmp eax, 8
    je DO_RESET

    PRINT_STRING invalidChoiceMsg
    jmp MAIN_MENU

FIRST_FIT:
    mov dword [algoSel], 1
    jmp DO_ALLOC

BEST_FIT:
    mov dword [algoSel], 2
    jmp DO_ALLOC

WORST_FIT:
    mov dword [algoSel], 3

DO_ALLOC:
    PRINT_STRING pidMsg

    GET_DEC 4, eax
    mov [procId], eax

    cmp eax, 1
    jb INVALID_PID
    cmp eax, 99
    ja INVALID_PID

    PRINT_STRING sizeMsg

    GET_DEC 4, eax
    mov [reqSize], eax

    cmp eax, 0
    je INVALID_SIZE

    xor esi, esi

CHECK_DUPLICATE:
    cmp esi, 8
    jae START_SEARCH

    mov eax, [ownerTbl + esi*4]
    cmp eax, 0
    je DUPLICATE_NEXT

    cmp eax, [procId]
    je DUPLICATE_PID

DUPLICATE_NEXT:
    inc esi
    jmp CHECK_DUPLICATE

START_SEARCH:
    mov dword [bestIndex], 0FFFFFFFFh
    mov dword [bestSize], 0
    xor esi, esi

SEARCH_LOOP:
    cmp esi, 8
    jae SEARCH_DONE

    cmp dword [ownerTbl + esi*4], 0
    jne NEXT_PARTITION

    mov eax, [blockTbl + esi*4]
    cmp eax, [reqSize]
    jb NEXT_PARTITION

    cmp dword [algoSel], 1
    je SELECT_PARTITION

    cmp dword [algoSel], 2
    je CHECK_BEST

    jmp CHECK_WORST

CHECK_BEST:
    cmp dword [bestIndex], 0FFFFFFFFh
    je SAVE_CANDIDATE

    mov eax, [blockTbl + esi*4]
    cmp eax, [bestSize]
    jb SAVE_CANDIDATE
    jmp NEXT_PARTITION

CHECK_WORST:
    cmp dword [bestIndex], 0FFFFFFFFh
    je SAVE_CANDIDATE

    mov eax, [blockTbl + esi*4]
    cmp eax, [bestSize]
    ja SAVE_CANDIDATE
    jmp NEXT_PARTITION

SAVE_CANDIDATE:
    mov [bestIndex], esi
    mov eax, [blockTbl + esi*4]
    mov [bestSize], eax
    jmp NEXT_PARTITION

SELECT_PARTITION:
    mov [bestIndex], esi
    jmp SEARCH_DONE

NEXT_PARTITION:
    inc esi
    jmp SEARCH_LOOP

SEARCH_DONE:
    cmp dword [bestIndex], 0FFFFFFFFh
    je ALLOCATION_FAILED

    mov ebx, [bestIndex]
    mov eax, [procId]
    mov [ownerTbl + ebx*4], eax

    mov eax, [reqSize]
    mov [reqTbl + ebx*4], eax

    inc dword [successCnt]
    call SaveState

    PRINT_STRING allocMsg

    mov eax, [bestIndex]
    inc eax
    PRINT_DEC 4, eax
    NEWLINE

    jmp MAIN_MENU

ALLOCATION_FAILED:
    inc dword [failCnt]
    call SaveState
    PRINT_STRING failMsg
    jmp MAIN_MENU

INVALID_PID:
    PRINT_STRING invalidPidMsg
    jmp MAIN_MENU

INVALID_SIZE:
    PRINT_STRING invalidSizeMsg
    jmp MAIN_MENU

DUPLICATE_PID:
    PRINT_STRING duplicateMsg
    jmp MAIN_MENU

DO_DEALLOC:
    PRINT_STRING freeMsg

    GET_DEC 4, eax
    mov [procId], eax

    xor esi, esi

REL_LOOP:
    cmp esi, 8
    jae REL_NOT_FOUND

    mov eax, [ownerTbl + esi*4]
    cmp eax, [procId]
    je REL_FOUND

    inc esi
    jmp REL_LOOP

REL_FOUND:
    mov dword [ownerTbl + esi*4], 0
    mov dword [reqTbl + esi*4], 0
    call SaveState

    PRINT_STRING releaseMsg
    jmp MAIN_MENU

REL_NOT_FOUND:
    PRINT_STRING notFoundMsg
    jmp MAIN_MENU

DISPLAY_MAP:
    PRINT_STRING mapTitle

    mov dword [idx], 0

MAP_LOOP:
    cmp dword [idx], 8
    jae MAP_DONE

    PRINT_STRING partMsg

    mov eax, [idx]
    inc eax
    PRINT_DEC 4, eax

    PRINT_STRING capacityMsg

    mov esi, [idx]
    mov eax, [blockTbl + esi*4]
    PRINT_DEC 4, eax

    PRINT_STRING ownerMsg

    mov esi, [idx]
    mov eax, [ownerTbl + esi*4]
    cmp eax, 0
    je MAP_FREE

    PRINT_DEC 4, eax
    PRINT_STRING usedText
    jmp MAP_NEXT

MAP_FREE:
    PRINT_STRING freeText

MAP_NEXT:
    inc dword [idx]
    jmp MAP_LOOP

MAP_DONE:
    jmp MAIN_MENU

DO_STATS:
    mov dword [freeTotal], 0
    mov dword [allocCap], 0
    mov dword [fragTotal], 0

    xor esi, esi

STATS_LOOP:
    cmp esi, 8
    jae STATS_DONE

    mov eax, [ownerTbl + esi*4]
    cmp eax, 0
    jne STATS_OCCUPIED

    mov eax, [blockTbl + esi*4]
    add [freeTotal], eax
    jmp STATS_NEXT

STATS_OCCUPIED:
    mov eax, [blockTbl + esi*4]
    add [allocCap], eax

    sub eax, [reqTbl + esi*4]
    add [fragTotal], eax

STATS_NEXT:
    inc esi
    jmp STATS_LOOP

STATS_DONE:
    PRINT_STRING statsTitle

    PRINT_STRING totalMsg
    mov eax, [totalMemory]
    PRINT_DEC 4, eax

    PRINT_STRING freeTotalMsg
    mov eax, [freeTotal]
    PRINT_DEC 4, eax

    PRINT_STRING usedTotalMsg
    mov eax, [allocCap]
    PRINT_DEC 4, eax

    PRINT_STRING fragMsg
    mov eax, [fragTotal]
    PRINT_DEC 4, eax

    PRINT_STRING successMsg
    mov eax, [successCnt]
    PRINT_DEC 4, eax

    PRINT_STRING failureMsg
    mov eax, [failCnt]
    PRINT_DEC 4, eax
    NEWLINE

    jmp MAIN_MENU

DO_RESET:
    call ClearState
    call SaveState
    PRINT_STRING resetMsg
    jmp MAIN_MENU

EXIT_PROGRAM:
    call SaveState
    PRINT_STRING byeMsg
    xor eax, eax
    ret

ResolveApis:
    pusha
    mov eax, [fs:30h]
    mov eax, [eax+0Ch]
    mov esi, [eax+14h]
    lodsd
    xchg eax, esi
    lodsd
    mov ebx, [eax+10h]

    mov esi, nCreateFileA
    call GetFunc
    mov [pCreateFileA], eax

    mov esi, nReadFile
    call GetFunc
    mov [pReadFile], eax

    mov esi, nWriteFile
    call GetFunc
    mov [pWriteFile], eax

    mov esi, nCloseHandle
    call GetFunc
    mov [pCloseHandle], eax
    popa
    ret

GetFunc:
    push ebx
    push ecx
    push edx
    push edi
    push ebp
    mov [gfName], esi
    mov eax, [ebx+3Ch]
    add eax, ebx
    mov eax, [eax+78h]
    add eax, ebx
    mov [gfExp], eax
    mov ecx, [eax+18h]
    mov edx, [eax+20h]
    add edx, ebx
    xor ebp, ebp
.next:
    cmp ebp, ecx
    jae .notfound
    mov edi, [edx+ebp*4]
    add edi, ebx
    mov esi, [gfName]
.cmp:
    mov al, [esi]
    cmp al, [edi]
    jne .diff
    test al, al
    jz .found
    inc esi
    inc edi
    jmp .cmp
.diff:
    inc ebp
    jmp .next
.found:
    mov eax, [gfExp]
    mov edx, [eax+24h]
    add edx, ebx
    movzx edx, word [edx+ebp*2]
    mov ecx, [eax+1Ch]
    add ecx, ebx
    mov eax, [ecx+edx*4]
    add eax, ebx
    jmp .out
.notfound:
    xor eax, eax
.out:
    pop ebp
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

ClearState:
    pusha
    mov edi, stateBlock
    mov ecx, 18
    xor eax, eax
    cld
    rep stosd
    popa
    ret

LoadState:
    pusha
    cmp dword [pCreateFileA], 0
    je .done
    cmp dword [pReadFile], 0
    je .done
    cmp dword [pCloseHandle], 0
    je .done

    push 0
    push 80h
    push 3
    push 0
    push 1
    push 80000000h
    push fileName
    call [pCreateFileA]
    cmp eax, -1
    je .done

    mov [fileHandle], eax
    mov dword [bytesDone], 0

    push 0
    push bytesDone
    push 72
    push stateBlock
    push dword [fileHandle]
    call [pReadFile]

    push dword [fileHandle]
    call [pCloseHandle]

    cmp dword [bytesDone], 72
    je .done
    call ClearState
.done:
    popa
    ret

SaveState:
    pusha
    cmp dword [pCreateFileA], 0
    je .done
    cmp dword [pWriteFile], 0
    je .done
    cmp dword [pCloseHandle], 0
    je .done

    push 0
    push 80h
    push 2
    push 0
    push 0
    push 40000000h
    push fileName
    call [pCreateFileA]
    cmp eax, -1
    je .done

    mov [fileHandle], eax

    push 0
    push bytesDone
    push 72
    push stateBlock
    push dword [fileHandle]
    call [pWriteFile]

    push dword [fileHandle]
    call [pCloseHandle]
.done:
    popa
    ret