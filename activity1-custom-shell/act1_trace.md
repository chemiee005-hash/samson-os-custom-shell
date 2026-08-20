# Activity 1 — Syscall Trace Analysis

## How this was produced

Command:
strace -f -e trace=read,write,clone,fork,exit_group python3 shell_act1.py 2> trace_output.txt

Command typed into the shell: test

Relevant excerpt from the actual trace output (trace_output.txt):

write(1, "py-sh> ", 7)                  = 7
read(0, "test\n", 8192)                 = 5
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD
, child_tidptr=0x71047febd490) = 937
[pid   936] read(3, "936 (python3) R 934 934 637 3481"..., 1024) = 280
[pid   937] write(1, "[CHILD] PID: 937 | PPID: 936 | T"..., 44) = 44
[pid   937] exit_group(0 <unfinished ...>
[pid   936] write(1, "[PARENT] Spawned child with PID:"..., 54 <unfinished ...>
[pid   937] <... exit_group resumed>)   = ?
[pid   936] <... write resumed>)        = 54
[pid   937] +++ exited with 0 +++
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=937, si_uid=1000, si_status=0, si_utime=0, si_stime=0} ---

(Shell PID in this run was 936, child PID was 937.)

---

## 1. Syscall Identification

While the shell was waiting at the py-sh> prompt for the user to type something, the kernel had the process blocked inside a **read()** system call on file descriptor 0 (stdin):

    read(0, "test\n", 8192) = 5

The process stays asleep inside this read(0, ...) call until the terminal driver hands back a full line after Enter is pressed. This is true whether the Python code calls input() or sys.stdin.readline() directly — both are built on top of the same underlying read() syscall on stdin.

## 2. The Fork Return Value

os.fork() on Linux is implemented via the clone() syscall. In the trace, this single call returns two different values depending on which process is asking:

- *Parent process:* clone() returned *937*, which is the PID of the new child:
      clone(...) = 937
  This matches pid = os.fork() in the parent's branch, where pid became 937.

- *Child process:* the kernel returns *0*. This isn't printed literally in the trace as a return value (because the child's copy of execution simply continues past the same call site), but it's confirmed indirectly: the child (PID 937) is the one that printed the [CHILD] message, which only happens inside the elif pid == 0: branch of the code. Since PID 937 executed that branch, its os.fork() call must have returned 0.

So one syscall, two different return values — 937 in the parent, 0 in the child — is exactly what lets the same if/elif/else code behave differently in each process.

## 3. Privilege Boundary

A user-space program (Ring 3) cannot create a new process on its own because doing so requires modifying resources that only the kernel (Ring 0) is allowed to touch:

- *Kernel data structures.* Creating a process means building a new task/process-table entry, assigning a new PID, and setting up new page tables. These live in protected kernel memory that Ring 3 code has no access to — letting arbitrary programs edit them directly would let any process corrupt the scheduler or impersonate other processes.
- *Memory management hardware.* The kernel has to program the CPU's memory management unit (MMU) to give the new process (initially copy-on-write) page tables. Reprogramming the MMU is a privileged, Ring-0-only operation on x86-64.
- *System-wide isolation and accounting.* Process creation has to be arbitrated against limits (like ulimit -u) and tracked centrally so the OS can schedule, signal, and reap it correctly — none of which user code can be trusted to do honestly on its own.

Because normal instructions can't cross this boundary, the CPU provides a special, controlled entry point: a software trap (historically int 0x80, on modern x86-64 the faster syscall instruction). Executing this instruction is the only legal way for Ring 3 code to ask Ring 0 to act on its behalf. The CPU switches privilege levels, jumps to a single fixed kernel entry point (never anywhere else), the kernel validates and performs the request (here, clone`/fork`), and returns control back to Ring 3 — handing back the two different return values (937 and 0) to the two now-separate processes, exactly as shown in the trace above.
