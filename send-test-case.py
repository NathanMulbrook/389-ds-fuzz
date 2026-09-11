#!/usr/bin/env python3

"""Send one raw LDAP packet, optionally extracted from a fuzzer input."""

import argparse
import socket
import sys
from pathlib import Path


def ber_length(length):
    if length < 0x80:
        return bytes([length])
    encoded = length.to_bytes((length.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(encoded)]) + encoded


def ber_value(tag, value):
    return bytes([tag]) + ber_length(len(value)) + value


def ber_integer(value):
    encoded = value.to_bytes(max(1, (value.bit_length() + 7) // 8), "big")
    if encoded[0] & 0x80:
        encoded = b"\0" + encoded
    return ber_value(0x02, encoded)


def bind_request(message_id, bind_dn, password):
    request = (
        ber_integer(3)
        + ber_value(0x04, bind_dn.encode())
        + ber_value(0x80, password.encode())
    )
    message = ber_integer(message_id) + ber_value(0x60, request)
    return ber_value(0x30, message)


def read_length(data, offset):
    first = data[offset]
    offset += 1
    if first < 0x80:
        return first, offset
    length_bytes = first & 0x7f
    if length_bytes == 0 or length_bytes > 8:
        raise ValueError("unsupported BER length")
    end = offset + length_bytes
    if end > len(data):
        raise ValueError("truncated BER length")
    return int.from_bytes(data[offset:end], "big"), end


def recv_exact(sock, length):
    result = bytearray()
    while len(result) < length:
        chunk = sock.recv(length - len(result))
        if not chunk:
            raise ConnectionError("connection closed")
        result.extend(chunk)
    return bytes(result)


def recv_ldap_message(sock):
    tag = recv_exact(sock, 1)
    first_length = recv_exact(sock, 1)
    header = tag + first_length
    if first_length[0] < 0x80:
        length = first_length[0]
    else:
        count = first_length[0] & 0x7f
        if count == 0 or count > 8:
            raise ValueError("unsupported BER length")
        encoded_length = recv_exact(sock, count)
        header += encoded_length
        length = int.from_bytes(encoded_length, "big")
    return header + recv_exact(sock, length)


def ldap_operation(message):
    try:
        if message[0] != 0x30:
            return None, None
        _, offset = read_length(message, 1)
        if message[offset] != 0x02:
            return None, None
        integer_length, offset = read_length(message, offset + 1)
        offset += integer_length
        operation_tag = message[offset]
        operation_length, offset = read_length(message, offset + 1)
        operation_end = offset + operation_length
        if operation_tag not in (0x61, 0x65, 0x67, 0x69, 0x6b, 0x6d, 0x6f, 0x78):
            return operation_tag, None
        if offset >= operation_end or message[offset] != 0x0a:
            return operation_tag, None
        result_length, offset = read_length(message, offset + 1)
        result = int.from_bytes(message[offset:offset + result_length], "big")
        return operation_tag, result
    except (IndexError, ValueError):
        return None, None


def fuzzer_packet(data, packet_number):
    if not data:
        raise ValueError("empty fuzzer input")

    offset = 1  # The first byte contains the fuzzer control flags.
    current_packet = 0
    while offset < len(data):
        if len(data) - offset < 2:
            raise ValueError("truncated packet length")
        packet_length = int.from_bytes(data[offset:offset + 2], "big")
        offset += 2
        end = offset + packet_length
        if packet_length == 0 or end > len(data):
            raise ValueError("invalid packet length")
        current_packet += 1
        if current_packet == packet_number:
            return data[offset:end]
        offset = end

    raise ValueError(f"fuzzer input contains only {current_packet} packets")


def connect(host, port, timeout):
    return socket.create_connection((host, port), timeout=timeout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="raw LDAP packet or fuzzer input")
    parser.add_argument("--packet", type=int, metavar="N",
                        help="extract packet N from a multipacket fuzzer input")
    parser.add_argument("--host", default="::1")
    parser.add_argument("--port", type=int, default=5601)
    parser.add_argument("--bind-dn", help="simple-bind DN; omit for anonymous access")
    parser.add_argument("--password", default="", help="simple-bind password")
    parser.add_argument("--timeout", type=float, default=2.0)
    args = parser.parse_args()

    data = args.input.read_bytes()
    if args.packet is not None:
        if args.packet < 1:
            parser.error("--packet must be at least 1")
        data = fuzzer_packet(data, args.packet)

    print(f"Sending {len(data)} bytes to [{args.host}]:{args.port}")
    with connect(args.host, args.port, args.timeout) as sock:
        sock.settimeout(args.timeout)
        if args.bind_dn:
            sock.sendall(bind_request(100, args.bind_dn, args.password))
            response = recv_ldap_message(sock)
            _, result = ldap_operation(response)
            print(f"Bind result: {result}; response: {response.hex()}")
            if result != 0:
                return 2
        else:
            print("Authentication: anonymous")

        sock.sendall(data)
        try:
            response_number = 0
            while True:
                response = recv_ldap_message(sock)
                response_number += 1
                operation, result = ldap_operation(response)
                operation_name = f"0x{operation:02x}" if operation is not None else "unknown"
                print(f"Response {response_number}: operation={operation_name}, "
                      f"result={result}; bytes={response.hex()}")
                if result is not None:
                    break
        except socket.timeout:
            print("No response before timeout")
        except ConnectionError:
            print("Connection closed without a response")

    try:
        with connect(args.host, args.port, args.timeout):
            print("Server status: reachable")
    except OSError:
        print("Server status: unreachable")
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
