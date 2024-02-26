.model tiny
.286
.code
org 100h

F1_SCANCODE equ	3bh

Start:			call CmdArgsVarsSet

			call MyInterrupt09hSet
			call MyInterrupt08hSet

			mov dx, offset ResidentFrameEnd    
	
			shr dx, 4		; dx /= 16 
			inc dx			; +1 to be sure full program 
						; will be resident

			mov ax, 3100h
			int 21h			; stay resident

MyInterrupt09hSet	proc

			mov ax, 3509h		; DOS 09h int, 35h func
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
		
			mov es:[bx], offset Interrupt09h ; es:[bx] = 09h interrupt offset
		
			push cs
			pop ax
			mov es:[bx+2], ax	; es:[bx+2] = my 09h 
						; interrupt segment

			sti			; interrupt is allowed

			ret

			endp


MyInterrupt08hSet	proc

			mov ax, 3508h		; DOS 08h int, 35h func
			int 21h			

			mov Original08hOff, bx	; bx = OG offset of 08h int vect
			mov bx, es		; es = OG seg address of 08h int vect
			mov Original08hSeg, bx

			push 0
			pop es			; es = 0 segment

			mov bx, 8h * 4		; 8h interrupt, each interrupt
						; contains 4 byte (seg addr
						; and offset)

			cli			; interrupt is disallowed
		
			mov es:[bx], offset Interrupt08h ; es:[bx] = 08h interrupt offset
		
			push cs
			pop ax
			mov es:[bx+2], ax	; es:[bx+2] = my 08h 
						; interrupt segment

			sti			; interrupt is allowed

			ret
			
			endp

Interrupt09h		proc
		
			push ax

			in al, 60h		; al = scan code
			and al, not 80h		; al = pressed or released scan code F1

			cmp al, F1_SCANCODE	 

			je HotkeyPressed	; if F1 was pressed or released
	
			jmp HotkeyNotPressed
		
HotkeyPressed:		push ds			; saving ds

			push cs
			pop ds			; ds = cs
	
			mov IfHotkeyPressed, 01h ; not zero
	
			pop ds			; popping ds
	
			in al, 61h
	
			or al, 80h		; 10000000b mask
			out 61h, al		; disable kybd 
	
			and al, not 80h		; 01111111b mask
			out 61h, al		; enable kybd

			mov al, 20h		; EOI
			out 20h, al

			pop ax
	
			iret
	
			endp
	
HotkeyNotPressed:	pop ax

			db 0EAh			; far jump

Original09hOff		dw 0
Original09hSeg		dw 0


Interrupt08h		proc

			push ds			; saving ds

			push cs		
			pop ds			; ds = cs
	
			cmp IfHotkeyPressed, 0
	
			pop ds			; popping ds
	
			je HotkeyNotPressed08h 
	
			push sp bp ss es ds di si dx cx bx ax ; pushing all regs	

			call RamkaAAA
	
			pop ax bx cx dx si di ds es ss bp sp  ; popping all regs

HotkeyNotPressed08h:	db 0EAh			; far jump

Original08hOff  	dw 0
Original08hSeg		dw 0

			endp	

IfHotkeyPressed		db 0

include ramka.asm 

ResidentFrameEnd:

end 			Start	