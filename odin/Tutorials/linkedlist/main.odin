#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:strings"

PAUSE: bool
FIN: bool

listHead: ^node

node :: struct {
	data: int,
	next: ^node,
}

create_node :: proc(data: int) -> ^node {
	n := new(node)
	n^ = {
		data = data,
		next = nil,
	}
	return n
}

//head is a pointer to a pointer. This allows us to modify where head points to.
//for linked lists this is important as we need to be able to create new nodes,
//and then add them into the list, and re-address our head to the new node. 
insertAtFirst :: proc(head: ^^node, data: int) {
	//create a new node
	newNode := create_node(data)
	//assign the next node to head^ which is the dereferences head^^ (a node pointer)
	newNode.next = head^
	//reassign head to equal newNode
	head^ = newNode
}

//Inserst a node at the end of our singly linked list
insertAtEnd :: proc(head: ^^node, data: int) {
	//create new node
	newNode := create_node(data)
	//if head pointer is nil, head now equals newNode
	if head^ == nil {
		head^ = newNode
		return
	}
	tmp := head^
	//as long as tmp.next isn't nil
	//tmp = tmp.next
	for tmp.next != nil {
		tmp = tmp.next
	}
	tmp.next = newNode
}

//inserts node(data) at position pos
insertAtPosition :: proc(head: ^^node, data: int, pos: int) {
	newNode := create_node(data)
	if pos == 0 {
		insertAtFirst(head, data)
		return
	}

	tmp := head^
	for i := 0; tmp != nil && i < pos - 1; i += 1 {
		tmp = tmp.next
	}
	if tmp == nil {
		fmt.printf("Pos out of range!\n")
		free(newNode)
		return
	}
	newNode.next = tmp.next
	tmp.next = newNode
}

deleteFromFirst :: proc(head: ^^node) {
	if (head^ == nil) {
		fmt.printf("List is empty\n")
		return
	}
	tmp := head^
	head^ = tmp.next
	free(tmp)
}

print :: proc(head: ^node) {
	tmp := head
	for tmp != nil {
		fmt.printf("%i -> \n", tmp.data)
		tmp = tmp.next
	}
	fmt.printf("NULL\n")
}

deleteFromEnd :: proc(head: ^^node) {
	if head^ == nil {
		fmt.printf("List is empty\n")
		return
	}
	tmp := head^

	if (tmp.next == nil) {
		free(tmp)
		head^ = nil
		return
	}

	for tmp.next.next != nil {
		tmp = tmp.next
	}
	free(tmp.next)
	tmp.next = nil
}

deleteAtPosition :: proc(head: ^^node, pos: int) {
	if head^ == nil {
		fmt.printf("List is empty\n")
		return
	}

	tmp := head^
	if pos == 0 {
		deleteFromFirst(head)
		return
	}

	for i := 0; tmp != nil && i < pos - 1; i += 1 {
		tmp = tmp.next
	}

	if tmp == nil || tmp.next == nil {
		fmt.printf("pos out of range!\n")
		return
	}
	next := tmp.next.next
	free(tmp.next)
	tmp.next = next
}

init_program :: proc() {
	listHead = nil

	insertAtFirst(&listHead, 10)
	fmt.printf("linked list after inserting the node:10 at the beginning\n")
	print(listHead)

	fmt.printf("Linked list after inserting the node:20 at the end \n")
	insertAtEnd(&listHead, 20)
	print(listHead)

	fmt.printf("Linked list after inserting the node:5 at the end \n")
	insertAtEnd(&listHead, 5)
	print(listHead)

	fmt.printf("Linked list after inserting the node:30 at the end \n")
	insertAtEnd(&listHead, 30)
	print(listHead)

	fmt.printf("Linked list after inserting the node:15 at position 2 \n")
	insertAtPosition(&listHead, 15, 2)
	print(listHead)

	fmt.printf("Linked list after deleting first node \n")
	deleteFromFirst(&listHead)
	print(listHead)

	fmt.printf("Linked list after deleting last node \n")
	deleteFromEnd(&listHead)
	print(listHead)

	fmt.printf("Linked list after deleting at pos 1 \n")
	deleteAtPosition(&listHead, 2)
	print(listHead)
}

main :: proc() {

	//init program
	init_program()

}
