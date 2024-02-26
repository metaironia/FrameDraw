RamkaAAA	proc
		
		cld

		push bp
		mov bp, sp

		push cs
		pop ds		; ds = cs
	
		mov bl, FrameHeight
		mov bh, FrameWidth
		mov dh, FrameColor
		mov si, FrameStyleAddr
		mov di, FrameTextAddr		

		push di			; saving text addr in di
	
		mov di, 0b800h
		mov es, di		; es = seg addr vram
	
		xor di, di
		call ShadowFrameDraw

		xor di, di
		call FrameDraw

		pop si			; TextDraw requires text addr in si	
		push bx			; saving original width

		xor di, di      	; di = very beginning of vram

		call CenterDI

		mov bh, 4d 		; bh = 4 for output of register's name 

		call TextDraw

		pop bx			; popping original width
		
		xor di, di
		call CenterDI		
		
		add di, 160d    	; di = new line
		add di, 8d		; offset to print registers

		mov cx, 13d		; 13 registers

		add bp, 4d		; bp = pos to ax register in stack

RegisterOutput:	mov ax, [bp]

		call RegisterDraw

		inc bp
		inc bp

		loop RegisterOutput

		pop bp

		ret
		
		endp 

;--------------------------
; CmdArgsVarsSet
; Entry: -
; Return: - (set frame settings variables)  
;--------------------------

CmdArgsVarsSet	proc

		call CmdArgsScan
		
		mov FrameHeight, bl
		mov FrameWidth, bh
		
		mov FrameColor, dh

		mov FrameStyleAddr, si
		mov FrameTextAddr, di  
		
		ret

		endp


;--------------------------
; CenterDI
; Entry: di = vram pos
; Return: centered di
;--------------------------

CenterDI	proc

		push dx			 ; saving dx

		xor dh, dh
		call VerticalCentering
		call HorizontalCentering ; dl = horizontal offset

		add di, dx		 ; di is now centered
		
		pop dx			 ; popping dx

		ret

		endp

;-----------------------
; RegisterDraw
; Entry: di = current vram pos, ax = register to print, dh = color attr
; Assumes: es = 0b800h
;-----------------------

RegisterDraw	proc

		push ax ax ax ax	; saving ax

		and ax, 0f000h		; mask to first number
		shr ax, 12d 		; now that number is the last
			
		call PrintNumToAscii

		pop ax
		and ax, 0f00h		; mask to second number		
		shr ax, 8d		; now that number is the last
		
		call PrintNumToAscii

		pop ax
		and ax, 00f0h		; mask to third number		
		shr ax, 4d		; now that number is the last

		call PrintNumToAscii

		pop ax
		and ax, 000fh		; mask to number byte		

		call PrintNumToAscii

		pop ax			; popping ax

		add di, 160d		; di = new line
		sub di, 8d		; di = 4 lines left prev pos

		ret
		
		endp

;-----------------------------
; PrintNumToAscii
; Entry: ax = number from 0 to F, di = current pos to print, dh = color attr
; Assumes: es = 0b800h
; Destructs: ax
;-----------------------------

PrintNumToAscii	proc	
		
		mov si, offset RegisterString
		add si, ax			; si = addr to number

		lodsb				; al = ascii code of number	
	
		mov ah, dh			; ah = color attr		

		stosw

		ret

		endp

RegisterString	db '0123456789ABCDEF'


;-------------------------
; TextDraw
; Entry:    si = text address, bh = width, dh = color attr  
; Return:   -
; Destruct: si, dh
;-------------------------

TextDraw	proc

		push dx      ; saving text address in dl and color attr in dh

		xor dx, dx
		
		add di, dx   ; di += horizontal offset

		pop dx	     ; popping text address in dl and color attr in dh 

		add di, 2d    ; one line right of top-left frame corner

		mov ah, dh   ; ah = color attr


NextString:	add di, 160d  ; di += new line

		xor ch, ch
		mov cl, bh  
		sub cx, 2d    ; cx = width - 2

		push cx      ; saving width - 2 in stack 

TextInterlace:	cmp byte ptr [si], '$'
		je TextInterlaceEnd

		lodsb		; al = text char
		stosw		; [di] = ax
				; si++

		loop TextInterlace

		cmp byte ptr [si], '$'
		
		pop cx		; popping width - 2 in cx
		shl cx, 1	; cx *= 2 because of color attr
		sub di, cx      ; di = new string pos

		jne NextString		

TextInterlaceEnd:
		
		pop cx
		
		ret

		endp

;------------------------
; ShadowFrameDraw
; Entry: -
; Return: -
; Destructs: ax, cx, di
;------------------------

ShadowFrameDraw		proc

			call CenterDI

			add di, 2d	; di = one line right of right border 
			
			mov cl, bh
			xor ch, ch	; cx = frame width

			push cx		; saving frame width in stack

			shl cx, 1	; cx *= 2 because of color attr
			add di, cx	; di = right border pos

			mov cl, bl	; cx = border height

			mov al, 0	; no symbol to print
			mov ah, 10h	; blue background color attr 

VerticalShadowDraw:	add di, 158d	; di = new line same column

			call SingleCharDraw

			loop VerticalShadowDraw
	
			pop cx		; popping frame width from stack

			push cx		; saving frame width
			shl cx, 1	; cx *= 2 because of color attr

			sub di, cx	; get back to left frame border 

			pop cx		; cx = width for cycle			

HorizontalShadowDraw:	call SingleCharDraw

			loop HorizontalShadowDraw

			ret
			
			endp

;------------------------
; CmdArgsScan
; Entry: -
; Return: -
; Destruct: ax
;------------------------

CmdArgsScan	proc
		
		mov ax, offset CmdArgsStringEnd	
		mov cx, offset CmdArgsString
		sub cx, ax	 ; cx = length of cmd args 

		mov di, offset CmdArgsString ; di = offset to first arg

		call SizeScan    ; first scan for width
		mov bl, bh	 ; bl = width

		call SizeScan	 ; second scan for height
		xchg bh, bl	 ; bl = height, bh = width
	
		call ColorScan   ; color attr in dh
		
		call StyleScan   ; style addr in si

		call TextScan    ; text addr in di
		
		ret

		endp

;--------------------------
; TextScan
; Entry: di = curr pos
; Return: addr of text in di
; Destruct:
;--------------------------

TextScan	proc

		call SpacesSkip

		ret
		
		endp

;-------------------------
; SpacesSkip
; Entry: di before spaces
; Return: di after spaces
; Destructs: al
;-------------------------

SpacesSkip	proc
		
		mov al, 20h	; 20h = space ascii character		
		repe scasb
		
		dec di

		ret
		
		endp

;------------------------
; StyleScan
; Entry: di = current pos
; Return: offset to string in si
; Destructs: ax
;------------------------

StyleScan	proc

		call SpacesSkip	
	
		mov si, di
		mov al, 2ah  	  ; 2ah = * in ascii 
						
		scasb	      

		jne DefaultStyle  ; if not eq *, turns on user's style

		inc si
		add di, 9	  ; di = pos after user's symbols style
		
		jmp StyleScanEnd

DefaultStyle:	lodsb
		
		sub al, '0'       ; al = digit
		 
		mov ah, 9         ; in style 9 chars
		mul ah	          ; ax = offset to style
		
		mov si, ax 		    ;
		add si, offset StringsStyle ; set addr of style chars				
		
StyleScanEnd:	ret
		
		endp

;------------------------
; ColorScan
; Entry: di
; Return: color attribute in dh
; Destructs: al, hyi ego znaet (last was a joke)
;------------------------

ColorScan	proc

		xor dh, dh
		mov si, di
		
ColorHexScan:	mov al, 20h   		; 20h = space ascii code
		scasb	     	 	; cmp al, es:[di++]
		
		je ColorHexScanEnd

		lodsb			; al = [si++]

		cmp al, '9'		; al = either digit or letter
		ja ColorLetter
		
		sub al, '0'		; al = digit

		jmp ColorStore

ColorLetter:	sub al, 'a'- 10		; al = from a to f	

ColorStore:	shl dh, 4		
		
		add dh, al

		jmp ColorHexScan		

ColorHexScanEnd:
		ret
		
		endp

;------------------------
; SizeScan
; Entry: di
; Return: width (or height) of frame in bh, curr pos in di
; Destructs: ax, dh
;------------------------

SizeScan	proc

		call SpacesSkip

		mov dh, 10          ; mul coefficient
		xor bh, bh          ; total number = 0

		mov si, di
		
ArgScan:	mov al, 20h         ; al = space ascii code
 		
		scasb		    ; cmp al, es:[di++]
		je EndArgScan	
		
		lodsb
		
		sub al, '0'	    ; al = digit from 0 to 9 
		
		xchg bh, al	    ; al = prev total num, bh = scanned num
		mul dh		    ; al = bh * 10
		
		add al, bh	    ; al = present time total number
		xchg bh, al	    ; bh = total number

		jmp ArgScan
EndArgScan:
		ret

		endp

;-----------------------
; VerticalCentering
; Entry: di, bl = height
; Assumes: di is very beginning or vram
; Return: centered di
; Destructs: ax
;-----------------------

VerticalCentering	proc
			
			mov ah, 80	
			mov al, bl
			
			shr al, 1	; al /= 2

			mul ah          ; ax = 80 * (bl/2)

			add di, 880	; di = 80 * 11 (11 ~= 25 / 2) 
			sub di, ax      ; di = 880 - 80 * (bl / 2)
			
			shl di, 1       ; di *= 2 because of color attr 	
			ret
			
			endp

;--------------------------
; HorizontalCentering
; Entry: bh = width
; Return: dl = horizontal centering offset
; Destructs: al
;--------------------------

HorizontalCentering	proc
						
			mov al, bh ; al = width

			shr al, 1  ; al = width / 2
			
			xor dl, dl 
			add dl, 40 ; dl = 40
			sub dl, al ; dl = 40 - width / 2 
			
			shl dl, 1  ; dl *= 2 because of color attr					
			ret			

			endp

;-----------------------
; FrameDraw
; Entry: si = address of style, dl = horizontal offset, bh = width
; Return: -
; Destructs: 
;-----------------------

FrameDraw	proc
		
		call VerticalCentering
		call HorizontalCentering

		mov al, bh		;	
		xor ah, ah		; ax = width

		push ax
		call InterlaceScan      ; draws top string of frame
		pop ax

		add si, 3		; si = middle strings chars

		mov cl, bl
		xor ch, ch		; cx = height
		sub cx, 2		; cx = height - 2

MiddleStrDraw:	push cx			; for MiddleStrDraw
		push ax

		call InterlaceScan  	; draws middle strings

		pop ax
		pop cx 		

		loop MiddleStrDraw

		add si, 3		; si = bottom strings char	
		
		push ax
		call InterlaceScan      ; draws bottom string of frame
		pop ax

		ret

		endp	


;----------------------------------------+
; InterlaceScan                          
; Entry: bh = width, 
;        dh = color attr, si = 3-char string offset,
;	 dl = horizontal offset, cx from stack
; Assumes: es = 0b800h, di is a very beginning of string 
; Return: -
; Destructs: ax, cx
;----------------------------------------

InterlaceScan	proc

		push bp    		;
		mov bp, sp 		; bp-chain

		mov cx, [bp+4]	
 
		push di			; saving di in stack
		
		xor ah, ah 		;
		mov al, dl 		; ax = horizontal offset

		add di, ax 		; di = horizontal offset				
		
		mov ah, dh 		; ah = color attr

		mov al, [si]	        ; al = left char	
		call SingleCharDraw     ; draws left char

		xor ch, ch		;
		mov cl, bh		; cx = width

		sub cx, 2    	 	; cx = length of middle symbols string
		mov al, [si+1]          ; al = middle char

MiddleChDr:	call SingleCharDraw 	; draws middle char string
		loop MiddleChDr	

		mov al, [si+2]          ; al = right char
		call SingleCharDraw     ; draws right char
		
		pop di      		; di = very beginning of string
		add di, 160 		; di = new string pos
		
		pop bp

		ret

		endp

;--------------------------
; SingleCharDraw
; Entry: al = symbol, di = pos to print char
; Assumes: es = 0b800h, ah = color attr
; Return: -
; Destructs: al
;--------------------------

SingleCharDraw	proc

		cmp al, 0
		je ColorAttrDraw		

		stosw 	  		; draw symbol and color attr 
		jmp SingleCharDrawEnd
		
ColorAttrDraw:	add di, 1  		; di = pos to color attr  ; if al == 0	
		mov al, ah
		stosb
		xor al, al 		; al = 0

SingleCharDrawEnd:

		ret

		endp


StringsStyle	db '+-+| |+-+' ; first style
		db '…Õª∫ ∫»Õº' ; second style

FrameWidth	db 0
FrameHeight	db 0
FrameColor	db 0
FrameStyleAddr	dw 0
FrameTextAddr	dw 0

CmdArgsString	db ' 9 15 4e 1 '
		db 'ax'
		db 'bx'
		db 'cx'
		db 'dx'
		db 'si'
		db 'di'
		db 'ds'
		db 'es'
		db 'ss'
		db 'bp'
		db 'sp'
		db 'ip'
		db 'cs$'
CmdArgsStringEnd:	       ; for args length	