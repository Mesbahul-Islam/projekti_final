import socket
import time


def main() -> None:
    hostname = socket.gethostname()
    while True:
        print(f"Hello RX2 from {hostname}!", flush=True)
        time.sleep(5)


if __name__ == "__main__":
    main()
