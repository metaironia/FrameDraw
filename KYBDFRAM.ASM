.model tiny
.286
.code
org 100h

Start:		mov ax, 3509h		; DOS 09h int, 35h func
		int 21h			

		mov Original09hOff, bx	; bx = OG offset of 09h int vect
		mov bx, es		; es = OG seg address of 09h int vect
		mov Original09hSeg, bx

		push 0
		pop es			; es = 0 segment

		mov bx, 9h * 4		; 9h interrupt, each interrupt
					; contains 4 byte (seg addr
					; and offset)

		cli			; interrupt is disallowed
		
		mov es:[bx], offset Interrupt09h ; es:[bx] = by 09h interrupt
						 ; offset
		
		push cs
		pop ax
		mov es:[bx+2], ax	; es:[bx+2] = my 09h 
					; interrupt segment

		sti			; interrupt is allowed

		mov dx, offset Interrupt90hEnd    
	
		shr dx, 4		; dx /= 16 
		inc dx			; +1 to be sure full program 
					; will be resident

		mov ax, 3100h
		int 21h			; stay resident


Interrupt09h	proc

		push ax bx es

		in al, 60h		; al = scan code
		cmp al, 3bh		; 3bh = F1 scan code 

		je HotkeyPressed	; if F1 was pressed

		cmp al, 3bh + 80h	; if F1 was released 
		je HotkeyPressed

		jmp HotkeyNotPressed

HotkeyPressed:	push 0b800h		; vram
		pop es
		
		xor bx, bx
		mov es:[bx], al
		mov byte ptr es:[bx+1], 4eh
		
		in al, 61h

		or al, 80h		; 10000000b mask
		out 61h, al		; disable kybd 

		and al, not 80h		; 01111111b mask
		out 61h, al		; enable kybd

		mov al, 20h		; EOI
		out 20h, al

		pop es bx ax

		iret

HotkeyNotPressed:
		pop es bx ax

db		0EAh		; far jump

Original09hOff	dw 0
Original09hSeg	dw 0

		endp	

Interrupt90hEnd:

end 		Start	