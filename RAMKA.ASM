.model tiny
.code
.286
org 100h									

Start:		cld
		call CmdArgsScan
		
		push dx		; saving text addr

		mov di, 0b800h
		mov es, di
		
		xor di, di

		push di		
		call ShadowFrameDraw
		pop di

		call FrameDraw
		
		pop dx		; TextDraw requires text addr in dl
		xor di, di      ; di = very beginning of vram

		call TextDraw

		mov ax, 4c00h
		int 21h 

;-------------------------
; TextDraw
; Entry:    dl = text address, bh = width 
; Assumes:  di is very beginning of vram 
; Return:   -
; Destruct: si, dh
;-------------------------

TextDraw	proc

		push dx      ; saving text address in dl and color attr in dh

		xor dx, dx

		call VerticalCentering
		call HorizontalCentering
		
		add di, dx   ; di += horizontal offset

		pop dx	     ; popping text address in dl and color attr in dh 

		add di, 2    ; one line right of top-left frame corner

		mov ah, dh   ; saving color attr in ah

		xor dh, dh
		mov si, dx   ; si = text address

NextString:	add di, 160  ; di += new line

		xor ch, ch
		mov cl, bh  
		sub cx, 2    ; cx = width - 2

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
; Entry: di in stack
; Return: -
;------------------------

ShadowFrameDraw		proc
			
			push bp
			mov bp, sp      ; bp-chain
			
			mov di, [bp+4]
			
			push si         ; saving offset to StylesString
			push dx		; saving color attr of real frame in dh

			mov si, offset ShadowStyle
			mov dh, 10h	; dh = blue color attr

			add di, 82      ; one lines below and one line right
					; real frame 
			call FrameDraw
			
			pop dx
			pop si
			
			pop bp
		
			ret
			
			endp

;------------------------
; CmdArgsScan
; Entry: -
; Return: -
;------------------------

CmdArgsScan	proc
				
		mov cl, ds:[80h] ; cx = length of cmd args
		mov di, 81h	 ; di = offset to first arg

		call SizeScan    ; first scan for width
		mov bl, bh	 ; bl = width

		call SizeScan	 ; second scan for height
		xchg bh, bl	 ; bl = height, bh = width
	
		call ColorScan   ; color attr in dh
		
		call StyleScan   ; style addr in si

		call TextScan    ; text addr in dl
		
		ret

		endp

;--------------------------
; TextScan
; Entry: di = curr pos
; Return: addr of text in dl
; Destruct: al
;--------------------------

TextScan	proc

		call SpacesSkip

		push bx	       ; saving bx
		push si	       ; saving si

		mov si, 80h    ; si = address of cmd args length

		mov bx, [si]   
		xor bh, bh     ; bx = length of cmd args
					
		add bx, 81h    ; bx = addr of cmd args end, 
			       ; 81h = addr of cmd args beginning
		
		mov byte ptr [bx], '$'  ; text ends by $ 
		
		mov al, dh     ; saving dh in al

		mov dx, di  
		mov dh, al     ; dl = text addr,
			       ; possible because text addr < 8bit

		pop si	       ; popping si
		pop bx	       ; popping bx

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
		
		sub di, 1

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
		mov al, 2ah   ; 2ah = * in ascii 
						
		scasb	      

		jne DefaultStyle  ; if not eq *, turns on user's style

		inc si

		jmp StyleScanEnd

DefaultStyle:	lodsb
		
		sub al, '0'	    ; al = digit
		 
		mov ah, 9	    ; in style 9 chars
		mul ah		    ; ax = offset to style
		
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
		db 'ÉÍ»º ºÈÍ¼' ; second style

ShadowStyle  	db '         ' 

end 		Start

