import os
import sys


def main():
    while True:
        try:
            sys.stdout.write("py-sh> ")
            sys.stdout.flush()
            line = sys.stdin.readline()

            if line == "":
                raise EOFError

            cmd = line.strip()

            if not cmd:
                continue

            args = cmd.split()

            pid = os.fork()

            if pid < 0:
                print("py-sh: fork failed", file=sys.stderr)

            elif pid == 0:
                child_pid = os.getpid()
                parent_pid = os.getppid()
                print(f"[CHILD] PID: {child_pid} | PPID: {parent_pid} | Target: {args[0]}")
                os._exit(0)

            else:
                shell_pid = os.getpid()
                print(f"[PARENT] Spawned child with PID: {pid} | Shell PID: {shell_pid}")
                os.waitpid(pid, 0)

        except (EOFError, KeyboardInterrupt):
            print("\nExiting shell...")
            break


if __name__ == "__main__":
    main()
