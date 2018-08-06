	NAME	TimeBoot
	PAGE	60,132
	TITLE	*** TimeBoot.Asm ***
;;
; TimeBoot.Asm
;
; TSR program to allow a computer reboot given the specified
;  time of day.  Times may be changed once resident, and the
;  program may be suspended, resumed, or uninstalled at any time.
;;
;;
; Revision History
;
; Stephen Smith		December,11, 1989	Version 1.0
;	Initial coding
; Stephen Smith		December 21, 1989	Version 1.1
;	Fixed problem with jmp to reboot (immediate mode) when
;	timeboot was resident.  Added "Installed" message. Forced
;	mandatory valid time passed on initial installation.
;;
;;
;
CODESEG	SEGMENT	PUBLIC 'CODE'
	ASSUME	cs:CODESEG,ds:CODESEG,es:CODESEG
;;
;	make this a .COM file
;;
	ORG	100h
;;
;
$Start:	jmp	Initialize
;;
; defines
;;
jmps	EQU	<jmp short>
VERSION	EQU	"1.2"
ACTIVE	EQU	00000001b
RESIDENT	EQU	00000010b
ABORTINST	EQU	00000100b
IMMEDIATE	EQU	00001000b
BYPASSCAD	EQU	00010000b
BOOT	EQU	472h
DOS	EQU	21h
BIOSDATA	EQU	40h
TIMEDELIM	EQU	':'
TIMERHIGH	EQU	6Eh
TIMERLOW	EQU	6Ch
COLDBOOT	EQU	0h
WARMBOOT	EQU	1234h
SHIFTCHECK	EQU	0ch	;control-alt key
;;
; here to allow verification of resident load
name$	DB	0Ah,0Dh
	DB	"TimeBoot ",VERSION,"$"
intime	DB	0
;;
; Old Timer Vector Address Storage
$OldTimer	LABEL	DWORD	;old interrupt 8h vector
oldtimerisr	DW	2 DUP(?)
;;
; Old Keyboard Vector Address Storage
$OldKeyboard	LABEL	DWORD	;old interrupt 9h vector
oldkeyboardisr	DW	2 DUP(?)
;;
; call to computer initialization routine
$BootAddr	LABEL DWORD
bootcall	DW	0000h,0ffffh
;;
; reboot time clicks
hours	DW	0	;default to midnight
minsec	DW	0
;;
; flags
status	DB	0
typeboot	DW	COLDBOOT	;default to cold boot
;;
; ascii time saved for display
aschour	DW	"00"
	DB	TIMEDELIM
ascmin	DW	"00"
	DB	0Ah,0Dh,"$"
;
;;
; Timer	Timer INT 08h ISR.
;;
;
Timer	PROC	FAR
	sti
	pushf		;set for iret from $OldTimer()
	call	cs:$OldTimer
	push	ds
	push	cs	;set data seg
	pop	ds
	test	status,ACTIVE	;are we active?
	jz	$TimerExit1

	cmp	intime,0	;not by the time...
	je	$TimerExit1

	push	ax	;save registers we use
	push	es
;
; retrieve timer high word (works out to be hours +-)
;
	mov	ax,BIOSDATA
	mov	es,ax
	mov	ax,WORD PTR es:[TIMERHIGH]
	cmp	ax,hours	;hour upon us?
	jne	$TimerExit
;
; retrieve timer low word
;
	mov	ax,WORD PTR es:[TIMERLOW]
	cmp	ax,minsec	;is is time?
	jne	$TimerExit
;
; time to reboot, here we go ...
;
$RebootMe:	xor	ax,ax
	mov	es,ax

	ASSUME	es:NOTHING

	mov	ax,typeboot
	mov	WORD PTR es:[BOOT],ax

	xor	ax,ax
	push	ax
	popf		;clear flags
	mov	ds,ax
	mov	ss,ax
	jmp	cs:$BootAddr	;reboot me!!
$TimerExit:	pop	es
	pop	ax
$TimerExit1:	pop	ds
	iret
Timer	ENDP
;
;;
; KeyBoard	Keyboard INT 09h ISR.
;;
;
Keyboard	PROC	FAR
	sti
	pushf
	push	ds
	push	cs	;set data seg
	pop	ds
	test	status,ACTIVE	;are we active?
	jz	$KeyboardExit1	;no need to continue
	push	ax
	push	es
	push	di
	mov	ax,40h	;BIOS data
	mov	es,ax
	mov	di,17h	;keyboard flag
	mov	ah,es:[di]
	test	ah,SHIFTCHECK	;control-alt key?
	jz	$KeyboardExit
	in	al,60h	;keyboard port
	test	status,BYPASSCAD	;bypass keyboard reboot
	jnz	$KillCad
	cmp	al,14h	;'T' scancode
	jne	$KeyboardExit
	jmps	$RebootMe
$KillCAD:	cmp	al,53h	;delete key
	jne	$KeyboardExit
	and	ah,not 04h	;turn off ctrl
	mov	es:[di],ah
$KeyboardExit:  pop	di
	pop	es
	pop	ax
$KeyboardExit1:	pop	ds
	popf
	jmp	cs:$OldKeyboard
Keyboard	ENDP
;
;;
;
$EndTsr	LABEL	WORD
;
;;
;
author$	DB	"  (C) Copyright 1991 Stephen Smith, Irving, TX. "
	DB	"All Rights Reserved."
crlf$	DB	0Ah,0Dh,"$"
syntax$	DB	"TSR Reboot at a specified time."
	DB	0Ah,0Dh,0Ah,0Dh,"usage:"
	DB	09h,"-h",09h,"help",09h,09h,"<this screen>",0Ah,0Dh
	DB	09h,"-?",09h,"status",0Ah,0Dh
	DB	09h,"-t",09h,"hh:mm",09h,0Ah,0Dh
	DB	09h,"-c",09h,"cold boot",09h,"<default>",0Ah,0Dh
	DB	09h,"-w",09h,"warm boot",0Ah,0Dh
	DB	09h,"-s",09h,"suspend",0Ah,0Dh
	DB	09h,"-r",09h,"resume",0Ah,0Dh
	DB	09h,"-i",09h,"immediate",0Ah,0Dh
	DB	09h,"-d",09h,"disable keyboard reboot",0Ah,0Dh
	DB	09h,"-e",09h,"enable keyboard reboot",0Ah,0Dh
	DB	09h,"-u",09h,"uninstall",0Ah,0Dh
	DB	"$"
echoname$	DB	"TIMEBOOT $"
installed$	DB	"has been installed.$"
altreboot$	DB	"  Alternate Reboot Key is Ctrl-Alt-T.$"
resident$	DB	"is resident.$"
notinst$	DB	"is not resident!",0Ah,0Dh,"$"
uninstall$	DB	"has been successfully uninstalled.",0Ah,0Dh,"$"
unsafe$	DB	"Unsafe to uninstall, suspending!",0Ah,0Dh,07h,"$"
badtime$	DB	"Invalid time!",0Ah,0Dh,07h,"$"
warm$	DB	"Warm$"
cold$	DB	"Cold$"
reboottime$	DB	" reboot set for $"
suspend$	DB	"has been suspended.",0Ah,0Dh,"$"
invalidparm$	DB	"Invalid parameter!",0Ah,0Dh,0Ah,0Dh,07h,"$"
residentseg	DW	0
;
;;
; GetDigit	returns hex of ascii digit, CF set if not digit
;;
;
GetDigit	PROC	NEAR
	sub	al,30h	;convert to int
	jc	$GetDigitExit	;below 0
	cmp	al,9
	ja	$GetDigitExit	;not above 9
	clc		;celar error flag
$GetDigitExit:	ret
GetDigit	ENDP
;
;;
; DigitToAsc	converts AX ascii digit to hex, CF set if not digit
;;
;
DigitToAsc	PROC	NEAR
	push	ax
	xor	ah,ah
	call	GetDigit
	jnc	$WDA1
	pop	ax
	jmps	$WDAExit
$WDA1:	mov	bh,10	;times 10 for next digit
	mul	bh
	pop	bx	;get back original
	push	ax	;save result
	mov	ax,bx
	xchg	ah,al
	xor	ah,ah
	call	GetDigit
	jnc	$WDA2
	pop	ax
	jmps	$WDAExit
$WDA2:	xor	bh,bh	;zero out divisor
	mov	bl,al
	pop	ax
	add	ax,bx
	clc
$WDAExit:	ret
DigitToAsc	ENDP
;
;;
; DispMsg	Displays message to screen via DOS call
;;
;
DispMsg	PROC	NEAR
	mov	ah,9
	int	DOS
	ret
DispMsg	ENDP
;
;;
; HelpEmOut	Displays Help screen
;;
;
HelpEmOut	PROC	NEAR
	mov	dx,OFFSET syntax$
	call	DispMsg
	or	status,ABORTINST	;set flag to exit
	ret
HelpEmOut	ENDP
;
;;
; ShowTime	Displays reboot type and time
;;
;
ShowTime	PROC	NEAR
	mov	ax,es:aschour
	mov	aschour,ax
	mov	ax,es:ascmin
	mov	ascmin,ax
$BootType:	cmp	es:typeboot,COLDBOOT
	jne	$BootWarm
	mov	dx,OFFSET cold$
	jmps	$DispBoot
$BootWarm:	mov	dx,OFFSET warm$
$DispBoot:	call	DispMsg
	mov	dx,OFFSET reboottime$
	call	DispMsg
	mov	dx,OFFSET es:aschour
	call	DispMsg
	ret
ShowTime	ENDP
;
;;
; StatusReport	Displays status of TimeBoot
;;
;
StatusReport	PROC	NEAR
	mov	dx,OFFSET echoname$
	call	DispMsg
	test	status,RESIDENT
	jz	$Stat1
	mov	dx,OFFSET resident$
	call	DispMsg
	test	es:status,ACTIVE
	jnz	$IsActive
	mov	dx,OFFSET crlf$
	call	DispMsg
	mov	dx,OFFSET echoname$
	call	DispMsg
	mov	dx,OFFSET suspend$
	call	DispMsg
	jmps	$StatExit
$IsActive:	test	es:status,BYPASSCAD	;bypass keyboard?
	jnz	$Stat0
	mov	dx,OFFSET altreboot$
	call	DispMsg
$Stat0:	mov	dx,OFFSET crlf$
	call	DispMsg
	cmp	es:intime,1
	jne	$StatExit
	call	ShowTime
	jmps	$StatExit
$Stat1:	mov	dx,OFFSET notinst$
	call	DispMsg
	call	HelpEmOut
$StatExit:	ret
StatusReport	ENDP
;
;;
; Initialize	Initialization Routine, sets parameters from command line
;;
;
Initialize	PROC	NEAR
	mov	dx,OFFSET name$
	call	DispMsg
	mov	dx,OFFSET author$
	call	DispMsg
	cld

	ASSUME	es:NOTHING

$IsInstalled:	not	WORD PTR [$Start]	;zero word to avoid false match
	xor	bx,bx	;initialize search segment
	mov	ax,cs	;record current segment in ax
$IsInstLoop:	inc	bx	;next search segment
	mov	es,bx
	cmp	ax,bx	;reached current segment ?
	je	$SetNewLoad	;new load
	mov	si,OFFSET $Start	;point si and di to ID offset
	mov	di,si
	mov	cx,16	;check 16 characters
	repe	cmpsb
	or	cx,cx
	jnz	$IsInstLoop
	or	status,RESIDENT	;set installed bit
	mov	residentseg,bx	;save installed segment
	jmps	$CheckArgv	;check command line
$SetNewLoad:	or	status,ACTIVE	;set status no matter what 
	mov	ax,ds
	mov	residentseg,ax
;
; get command line args
;
$CheckArgv:	push	ds
	pop	es
	ASSUME	es:CODESEG

	cld
	mov	si,80h	;set to read arcv
	lodsb
	mov	cl,al	;cx = argc
	xor	ch,ch	;zero out high

	mov	ax,residentseg
	mov	es,ax	;set es to resident segment
	ASSUME	es:nothing

	jmps	$GetArgv
;
; check for good install, return with errorlevel if not
;
$TryInstall:	test	status,IMMEDIATE
	jz	$TryInst1
	mov	ax,residentseg	;make sure we get reboot type
	mov	ds,ax
	jmp	$RebootMe
$TryInst1:	test	status,RESIDENT
	jnz	$TermErr
	test	status,ABORTINST
	jnz	$TermErr
	test	status,BYPASSCAD
	jz	$CheckForTime
	jmp	$GoodInst	;install
$CheckForTime:	cmp	intime,1
	jne	$TermErr
	jmp	$GoodInst	;install
$TermErr:	call	StatusReport
$TermExit:	mov	ax,4C01h
	int	DOS
$GetArgv:	or	cl,cl	;any more?
	jnz	$TrimArgv
	jmps	$TryInstall
$TrimArgv:	lodsb
	dec	cl
	cmp	al,' '
	je	$GetArgv
	cmp	al,'-'	;parameter?
	je	$GetArgv1
	cmp	al,'/'	;parameter?
	je	$GetArgv1
	jmps	$GetArgv
$GetArgv1:	lodsb
	dec	cl
	cmp	al,'?'	;status?
	jne	$GetArgv2
	jmps	$TermErr
$GetArgv2:	and	al,01011111b	;capitalize *argv
	cmp	al,'H'	;help?
	jne	$GetArgv3
	call	HelpEmOut
	jmps	$TermExit
$GetArgv3:	cmp	al,'T'	;time?
	jne	$GetArgv4
	jmp	$SetTime
	jmps	$GetArgv
$GetArgv4:	cmp	al,'C'	;cold boot?
	jne	$GetArgv5
	mov	es:typeboot,COLDBOOT
	jmps	$GetArgv
$GetArgv5:	cmp	al,'W'	;warm boot?
	jne	$GetArgv6
	mov	es:typeboot,WARMBOOT
	jmps	$GetArgv
$GetArgv6:	cmp	al,'S'	;suspend
	jne	$GetArgv7
	and	es:status,not ACTIVE
	jmps	$GetArgv
$GetArgv7:	cmp	al,'R'	;resume
	jne	$GetArgv8
	or	es:status,ACTIVE
	jmps	$GetArgv
$GetArgv8:	cmp	al,'I'
	jne	$GetArgv9
	or	status,IMMEDIATE
	jmps	$GetArgv
$GetArgv9:	cmp	al,'D'	;disable keyboard reboot
	jne	$GetArgv10
	or	es:status,BYPASSCAD
	jmps	$GetArgv
$GetArgv10:	cmp	al,'E'	;enable keyboard reboot
	jne	$GetArgv11
	and	es:status,not BYPASSCAD
	jmp	$GetArgv
$GetArgv11:	cmp	al,'U'	;uninstall
	jne	$GetArgv12
	jmp	$UnInstall
$GetArgv12:	mov	dx,OFFSET invalidparm$
	call	DispMsg
	call	HelpEmOut
	jmp	$TermExit
;
; release environment block, and go tsr
;
$GoodInst:	test	status,IMMEDIATE
	jz	$GoodInst1
	jmp	$RebootMe
$GoodInst1:	mov	bx,WORD PTR ds:[2Ch]
	mov	es,bx	;segment environment
	mov	ah,49h	;free memory
	int	DOS

	mov	ax,3508h	;save old vector address
	int	DOS
	mov	oldtimerisr,bx
	mov	oldtimerisr[2],es
	push	cs
	pop	ds
	mov	dx,OFFSET Timer	;set to our routine
	mov	ax,2508h
	int	DOS

	mov	ax,3509h	;save old vector address
	int	DOS
	mov	oldkeyboardisr,bx
	mov	oldkeyboardisr[2],es
	push	cs
	pop	ds
	mov	dx,OFFSET Keyboard	;set to our routine
	mov	ax,2509h
	int	DOS

	mov	dx,OFFSET echoname$
	call	DispMsg
	mov	dx,OFFSET installed$
	call	DispMsg
	test	status,BYPASSCAD	;bypass keyboard?
	jnz	$GoodInst2
	mov	dx,OFFSET altreboot$
	call	DispMsg
$GoodInst2:	mov	dx,OFFSET crlf$
	call	DispMsg
	mov	ax,residentseg	;set for call to show reboot time
	mov	es,ax
	cmp	es:intime,1
	jne	$GoodInst3
	call	ShowTime
$GoodInst3:	mov	dx,(OFFSET $EndTsr - OFFSET CODESEG) shr 4
	inc	dx	;save an extra paragraph
	mov	ax,3100h
	int	DOS	;TSR me
;
; uninstall program
;
$UnInstall:	test	status,RESIDENT	;are we here?
	jnz	$UnInst1
	mov	dx,OFFSET echoname$
	call	DispMsg
	mov	dx,OFFSET notinst$
	call	DispMsg
	mov	ax,4C02h	;exit with error level
	int	DOS
$UnInst1:	mov	ax,3508h	;see if timer still with us
	int	DOS
	mov	ax,es
	cmp	ax,residentseg
	jne	$BadUnInst
$UnInst1a:	mov	ax,3509h	;see if timer still with us
	int	DOS
	mov	ax,es
	cmp	ax,residentseg
	je	$Uninst2
$BadUnInst:	mov	es,residentseg
	and	es:status,not ACTIVE	;suspend it
	mov	dx,OFFSET unsafe$	;someone else has timer
	call	DispMsg
	mov	ax,4C03h
	int	DOS
;
; zero first word to prevent false reload check
;
$Uninst2:	not	WORD PTR es:[$Start]

	ASSUME ds:NOTHING

	lds	dx,es:[$OldTimer]
	mov	ax,2508h	;reset timer vector
	int	DOS

	lds	dx,es:[$OldKeyboard]
	mov	ax,2509h	;reset timer vector
	int	DOS

	push	cs
	pop	ds

	ASSUME ds:CODESEG

	mov	ah,49h	;free our memory
	int	DOS
	jc	$BadUnInst
	mov	dx,OFFSET echoname$
	call	DispMsg
	mov	dx,OFFSET uninstall$
	call	DispMsg
	mov	ax,4C04h	;exit with error level
	int	21h
$SetTime:	sub	cx,5
	lodsb		;get hours
	xchg	ah,al
	lodsb
	xchg	ah,al
	mov	aschour,ax
	call	DigitToAsc
	jc	$InvalidTime
	cmp	al,23	;valid hours?
	ja	$InvalidTime
	mov	hours,ax
	lodsb		;get minutes
	cmp	al,TIMEDELIM
	jc	$InvalidTime
	lodsb
	xchg	ah,al
	lodsb
	xchg	ah,al
	mov	ascmin,ax
	call	DigitToAsc
	jc	$InvalidTime
	cmp	al,59	;valid minutes?
	ja	$InvalidTime
	mov	bx,60	;convert to seconds
	mul	bx
	mov	minsec,ax
$ParseOutSecs:	lodsb		;get seconds
	cmp	al,' '
	je	$AddInSecs
	or	cl,cl
	jz	$AddInSecs
	dec	cl
	jmps	$ParseOutSecs
$InvalidTime:	mov	dx,OFFSET badtime$
	call	DispMsg
	or	status,ABORTINST	;set flag to exit
	jmp	$TermErr
;
; convert seconds into timer clicks
;
$AddInSecs:	mov	ax,minsec
	mov	bx,8E3Dh
	mul	bx	;result in dx:ax
	mov	bx,7D0h
	div	bx	;divide high
;
; everything ok, save to RESIDENT segment
;
	mov	es:minsec,ax
	mov	ax,cs:hours	;exchange new values
	mov	es:hours,ax
	mov	ax,cs:aschour
	mov	es:aschour,ax
	mov	ax,cs:ascmin
	mov	es:ascmin,ax
;
; restore argc
;
	mov	es:intime,1
	jmp	$GetArgv
Initialize	ENDP
;;
;
CODESEG	ENDS
	END	$Start
