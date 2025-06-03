package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:net"
import "core:os"
import "core:strconv"
import "core:sync"
import "core:sys/unix"
import "core:thread"
import "core:time"


NAME :: "odin-server"
VERSION :: "0.1.0"

server_init :: proc() {
	context.logger = log.create_console_logger()
	if (len(os.args) != 2) {
		fmt.printf("Usage: %s <port>\n", os.args[0])
		os.exit(1)
	}

	port, port_parsed := strconv.parse_int(os.args[1], 10)
	if !port_parsed {
		fmt.printf("Invalid port number: %s\n", os.args[1])
		os.exit(1)
	}

	fmt.printf("Starting %s version %s on port %d...\n", NAME, VERSION, port)

	endpoint, endpoint_parsed := net.parse_endpoint("0.0.0.0")
	if !endpoint_parsed {
		fmt.printf("failed to parse endpoint\n")
		os.exit(1)
	}

	endpoint.port = int(port)
	listen_socket, listen_err := net.listen_tcp(endpoint)
	if listen_err != nil {
		fmt.printf("Failed to listen on %s: %s\n", endpoint, listen_err)
		os.exit(1)
	}

	fmt.printf("Listening on TCP: %s", net.endpoint_to_string(endpoint))

	for {
		cli, _, err_accept := net.accept_tcp(listen_socket)
		if err_accept != nil {
			fmt.printf("Failed to accept connection: %s\n", err_accept)
			continue
		}
		thread.create_and_start_with_poly_data(cli, handle_msg)
	}
	net.close(listen_socket)
	fmt.printf("Server stopped.\n")

	//_fds, pollfds_alloc_err := make([dynamic]posix.pollfd, 0, 1024)

	/*
	bind_err := net.bind(listen_socket, endpoint)
	if bind_err != nil {
		{
			fmt.printf("Failed to bind to %s: %s\n", endpoint, bind_err)
			os.exit(1)
		}
	}*/
}

handle_msg :: proc(sock: net.TCP_Socket) {
	buffer: [256]u8
	for {
		bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])
		if err_recv != nil {
			fmt.println("Failed to receive data")
		}
		received := buffer[:bytes_recv]
		if len(received) == 0 ||
		   is_ctrl_d(received) ||
		   is_empty(received) ||
		   is_telnet_ctrl_c(received) {
			fmt.println("Disconnecting client")
			break
		}
		fmt.printfln("Server received [ %d bytes ]: %s", len(received), received)
		bytes_sent, err_send := net.send_tcp(sock, received)
		if err_send != nil {
			fmt.println("Failed to send data")
		}
		sent := received[:bytes_sent]
		fmt.printfln("Server sent [ %d bytes ]: %s", len(sent), sent)
	}
	net.close(sock)
}

is_ctrl_d :: proc(bytes: []u8) -> bool {
	return len(bytes) == 1 && bytes[0] == 4
}

is_empty :: proc(bytes: []u8) -> bool {
	return(
		(len(bytes) == 2 && bytes[0] == '\r' && bytes[1] == '\n') ||
		(len(bytes) == 1 && bytes[0] == '\n') \
	)
}

is_telnet_ctrl_c :: proc(bytes: []u8) -> bool {
	return(
		(len(bytes) == 3 && bytes[0] == 255 && bytes[1] == 251 && bytes[2] == 6) ||
		(len(bytes) == 5 &&
				bytes[0] == 255 &&
				bytes[1] == 244 &&
				bytes[2] == 255 &&
				bytes[3] == 253 &&
				bytes[4] == 6) \
	)
}
