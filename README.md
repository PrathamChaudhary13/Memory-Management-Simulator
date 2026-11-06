# Memory Management Simulator (x86 Assembly)

**Microprocessor Interfacing – Innovative Assignment**

A menu-driven simulator, written entirely in x86 assembly language, that shows how an operating system places processes into memory. It implements the three classic **fixed-partition allocation strategies** (First Fit, Best Fit, Worst Fit), lets you free processes, draws a memory map, reports fragmentation statistics, and **saves its state to a file** so memory contents survive between runs.

The project comes in two versions:

| File | Target | Assembler / IDE |
|------|--------|-----------------|
| `inno.asm` | 32-bit Windows | NASM via **SASM** |
| `innot.asm` | 16-bit DOS | **TASM** (run inside DOSBox) |

---

## Table of Contents

1. [Definition](#1-definition)
2. [Background concepts](#2-background-concepts)
3. [Features](#3-features)
4. [How it works](#4-how-it-works)
5. [Example session](#5-example-session)
6. [Installation and setup](#6-installation-and-setup)
7. [Running the project](#7-running-the-project)
8. [Real-life use cases](#8-real-life-use-cases)
9. [Limitations and future work](#9-limitations-and-future-work)
10. [Authors](#10-authors)

---

## 1. Definition

**Memory management** is the part of an operating system that decides which regions of RAM are given to which running processes, and takes them back when a process finishes.

This project is a **simulator** of that decision-making. It does not manage the real RAM of your computer. Instead it models a small pool of memory as a table of **8 fixed partitions** and lets you request and release space for processes, so you can watch how each placement strategy behaves.

The goal is to make the strategies visible and comparable at the lowest level of programming (registers, jumps, comparisons and raw system calls) rather than hiding them behind a high-level language.

---

## 2. Background concepts

**Fixed (static) partitioning.** Memory is divided into partitions of set sizes ahead of time. Each partition holds **at most one process**, and a process must fit entirely inside one partition.

**Placement strategies** decide *which* free partition a new process gets:

| Strategy | Rule | Strength | Weakness |
|----------|------|----------|----------|
| **First Fit** | Take the first free partition large enough. | Fastest, as it stops searching early. | Can waste space in early partitions. |
| **Best Fit** | Take the smallest free partition that is large enough. | Keeps large partitions free and minimizes waste per process. | Slower (must scan everything). |
| **Worst Fit** | Take the largest free partition. | Leaves leftover space that may still be useful. | Uses up big partitions quickly. |

**Internal fragmentation** is the unused space *inside* an allocated partition:

```
internal fragmentation = partition capacity − process size
```

For example, a 100-unit process placed in a 400-unit partition wastes 300 units. The *Memory Analytics* option reports this total.

---

## 3. Features

- Three allocation strategies: First Fit, Best Fit, Worst Fit
- Deallocate a process by its ID
- Memory map showing each partition's capacity and owner (`FREE` or `ALLOCATED`)
- Analytics: total, free and allocated memory, internal fragmentation, successful and failed allocations
- Input validation: process ID must be 1–99, size must be positive, duplicate IDs are rejected, and invalid menu choices are caught
- **Persistent state:** memory contents and counters are saved to `memstate.dat` after every change and reloaded on the next start
- Reset option to clear all memory and the saved file

---

## 4. How it works

### 4.1 Memory model

Eight partitions with fixed capacities (in memory units), totalling **1700**:

| Partition | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|-----------|---|---|---|---|---|---|---|---|
| Capacity  | 100 | 200 | 150 | 300 | 250 | 120 | 400 | 180 |

### 4.2 Data structures

All data lives in simple parallel arrays indexed by partition number:

| Table | Meaning |
|-------|---------|
| `blockTbl` | Capacity of each partition (constant) |
| `ownerTbl` | Process ID occupying each partition (`0` = free) |
| `reqTbl` | Size the process requested (used for fragmentation) |
| `successCnt`, `failCnt` | Counters for the analytics screen |

`ownerTbl`, `reqTbl` and the two counters are stored back-to-back as one **state block**, which is what gets written to disk.

### 4.3 Program flow

```
start ─► load saved state ─► show menu ─┐
                                        │
   ┌────────────────────────────────────┘
   ▼
 choice ──► 1/2/3  allocate (validate → search → place → save)
        ├─► 4      deallocate (find ID → free partition → save)
        ├─► 5      display memory map
        ├─► 6      display analytics
        ├─► 7      save and exit
        └─► 8      clear all memory and save
   (every option except Exit returns to the menu)
```

### 4.4 Allocation algorithm

1. Read the process ID and size, and validate them.
2. Scan `ownerTbl` to reject a process ID that is already in use.
3. Loop over the 8 partitions. Skip any that are occupied or too small.
4. Among the remaining candidates, choose by strategy:
   - **First Fit:** stop at the first candidate.
   - **Best Fit:** remember the candidate with the *smallest* capacity.
   - **Worst Fit:** remember the candidate with the *largest* capacity.
5. If a partition was chosen, record the owner and requested size, increment the success counter, save state and print the partition number. Otherwise increment the failure counter and report that no suitable partition exists.

When two partitions tie, the earlier one wins.

### 4.5 Deallocation

Search `ownerTbl` for the given process ID. If found, set that partition's owner and request size to `0` and save. Otherwise report "Process not found."

### 4.6 Persistence

After every state-changing action the 18 values of the state block are written to **`memstate.dat`** in the working directory. On startup the file is read back; if it is missing or the wrong size, memory starts empty.

- **`inno.asm`** calls the Windows API directly (`CreateFileA`, `ReadFile`, `WriteFile`, `CloseHandle`). It finds these functions at runtime by walking the process structures to locate `kernel32.dll` and searching its export table by name. The state file is **72 bytes** (18 × 4-byte values).
- **`innot.asm`** uses DOS `INT 21h` services (create, read, write and close file, plus string and character I/O). The state file is **36 bytes** (18 × 2-byte values).

> The two versions use different file formats. Do not copy a `memstate.dat` from one version to the other. Use *Reset saved memory* if switching.

---

## 5. Example session

Starting from empty memory, using the menu choices below:

| Step | Menu choice | Process ID | Size | Result |
|------|-------------|-----------|------|--------|
| 1 | 1 – First Fit | 1 | 120 | Partition 2 (first free partition ≥ 120 is the 200) |
| 2 | 2 – Best Fit | 2 | 120 | Partition 6 (the exact-fit 120) |
| 3 | 3 – Worst Fit | 3 | 100 | Partition 7 (the largest, 400) |

Selecting **6 – Memory Analytics** then shows:

```
Total memory: 1700
Free memory: 980
Allocated partition capacity: 720
Internal fragmentation: 380
Successful allocations: 3
Failed allocations: 0
```

Internal fragmentation is `(200−120) + (120−120) + (400−100) = 380`. Best Fit achieved zero waste on process 2, while Worst Fit wasted the most on process 3. Try the same requests with different strategies and compare.

---

## 6. Installation and setup

### 6.1 SASM (for `inno.asm`) – Windows

SASM (SimpleASM) is a free IDE that bundles the NASM assembler and a linker.

1. Go to the official SASM page: **https://dman95.github.io/SASM/** (releases are also on GitHub at `Dman95/SASM`).
2. Download the **Windows installer** (`.exe`).
3. Run the installer and follow the prompts. NASM and the toolchain are included, so nothing else is needed.
4. Launch SASM and open **Settings** (gear icon). Under *Build*, check that the mode is **x86** with the **NASM** assembler.

> `inno.asm` calls Windows APIs, so it must run on **Windows**. It will not work in SASM on Linux or macOS.

### 6.2 TASM (for `innot.asm`) – DOSBox

TASM (Turbo Assembler) is a 16-bit DOS tool from Borland. It is not distributed freely, so use the copy provided by your university lab or course. Because modern Windows cannot run DOS programs directly, you run it inside **DOSBox**.

1. Install DOSBox from **https://www.dosbox.com/** (download the Windows installer and run it).
2. Create a folder, for example `C:\TASM`, and place `TASM.EXE`, `TLINK.EXE` and any supporting files from your lab's TASM package inside it.
3. Copy `innot.asm` into the same folder.
4. Start DOSBox and mount the folder as a drive:
   ```
   mount c C:\TASM
   c:
   ```

---

## 7. Running the project

### 7.1 `inno.asm` (SASM)

1. Open SASM and choose **File → Open**, then select `inno.asm`.
2. Click **Build & Run** on the toolbar (or use the Build menu).
3. A console window opens with the menu. Type a number and press Enter.

### 7.2 `innot.asm` (TASM in DOSBox)

At the DOSBox prompt (after the mount steps above):

```
tasm innot.asm
tlink innot.obj
innot.exe
```

`tasm` assembles the source into `innot.obj`, `tlink` links it into `innot.exe`, and the last line runs it.

### Menu reference

```
1. First Fit
2. Best Fit
3. Worst Fit
4. Deallocate Process
5. Display Memory Map
6. Memory Analytics
7. Exit
8. Reset saved memory
```

---

## 8. Real-life use cases

The simulator is educational, but the ideas behind it show up in real systems:

- **Operating system design.** Early systems such as IBM OS/360 (MFT) used fixed partitions exactly like this model, and the same placement strategies still appear in memory allocators that manage free blocks.
- **Embedded systems and RTOS.** Microcontrollers often have no virtual memory. Firmware uses fixed-size memory pools, where predictable allocation and no surprise slowdowns matter more than flexibility.
- **Heap allocators (`malloc`).** Memory allocators use first-fit and best-fit searches over free lists. Understanding fragmentation explains why long-running programs can run out of usable memory even when total free space looks sufficient.
- **Cloud and virtual machine placement.** Deciding which server (a "partition") should host a new VM or container is a bin-packing problem solved with first-fit, best-fit and worst-fit style heuristics.
- **Storage and file systems.** Disk space allocation uses the same strategies to choose a free extent for a new file, with the same fragmentation trade-offs.
- **GPU and buffer management.** Graphics and network software allocate fixed-size buffers from pools to avoid unpredictable delays.
- **Teaching and benchmarking.** The simulator lets students and engineers compare strategies on the same workload, and see in assembly what a high-level allocator does for them.

---

## 9. Limitations and future work

- Partitions are **fixed**. There is no splitting of a partition and no merging of neighbours.
- Only **internal** fragmentation is modelled. External fragmentation arises with variable partitions.
- Memory units are abstract (no byte/KB/MB label).
- The two versions have separate, incompatible state files.
- `inno.asm` is Windows-only because of its direct API calls.

Possible extensions: variable-size (dynamic) partitions, compaction, a Next Fit strategy, per-strategy comparison reports, and a user-defined partition table.

---

## 10. Authors

- Pratham Chaudhary
- Tanish Solanki
