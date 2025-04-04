from comms import Comms
import asyncio


async def get_available_peers(comms: Comms):
    available_peers = []
    while True:
        with comms.available_peers_lock:
            for peer in comms.available_peers:
                if peer not in available_peers:
                    print(peer)
                    available_peers.append(peer)


def get_input(msg, comms):
    user_in = input(msg)
    print(user_in)
    comms.start_connection_info(user_in)


async def main():
    print(f"{'_'*10}SELECT INTERFACE{'_'*10}")

    available_interfaces = {i: v for i, v in enumerate(Comms.interfaces, start=1)}

    for num, interface in available_interfaces.items():
        print(f"{num} - {interface}")

    interface_num = int(input("interface: "))
    interface_name = available_interfaces[interface_num]

    comms = Comms("Daniel", interface_name)
    await comms.start()
    await asyncio.to_thread(get_input, "choose peer to connect to: ", comms)  # Keep running for demo


if __name__ == "__main__":
    asyncio.run(main())
