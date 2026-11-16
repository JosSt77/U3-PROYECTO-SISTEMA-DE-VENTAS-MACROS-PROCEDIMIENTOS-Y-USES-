; Materia: Lenguajes de Interfaz
; Alumno: Sotelo Izaguirre José Ángel
; Horario: 10-11
; Docente: Dr. José Luis Medina Jiménez
; Práctica: Proyecto de ventas e inventario en ensamblador
; Descripción: Sistema de consola para administrar hasta 10 productos (libros). Para dar de alta un producto
; se solicita el id (formato ABC-123), el nombre, el precio en pesos mexicanos y la cantidad. El programa permite
; mostrar el inventario, buscar por id, recibir mercancía, vender, mostrar el resumen, guardar y cargar el
; catálogo en un archivo. Los precios se guardan en centavos enteros y se muestran con dos decimales y la
; etiqueta MXN. Como regla adicional se aplica un descuento por cantidad: si en una venta se compran 5 o más
; ejemplares del mismo producto se descuenta el 10% del importe base, descartando la fracción de centavo.
; CAMBIO IMPLEMENTADO: Se reorganizó el código con macros, procedimientos y USES. Se conservan las funciones,
; las validaciones y la regla de negocio del proyecto original.

INCLUDE Irvine32.inc

MostrarMensaje MACRO texto
;Recibe el nombre de una variable BYTE y la imprime en pantalla modificando EDX y los registros que use WriteString
;Sustituye el código mov edx, OFFSET / call WriteString
    mov edx, OFFSET texto ; EDX recibe la dirección de la cadena
    call WriteString ; Imprime la cadena
ENDM

LlamarConCadena MACRO rutina, cadena
;Recibe el nombre de un procedimiento y el nombre de una variable BYTE, y llama al procedimiento con la dirección de la variable en EDX
;Sustituye el código mov edx, OFFSET / call rutina
    mov edx, OFFSET cadena ; EDX recibe la dirección de la cadena
    call rutina ; Se llama a la rutina indicada
ENDM

PedirNumero MACRO mensaje, maximo
;Recibe el nombre de una variable BYTE y un valor máximo, modifica EBX, EDX y los registros que use PedirEntero
    mov edx, OFFSET mensaje ; EDX = mensaje que se muestra al pedir el dato
    mov ebx, maximo ; EBX = valor máximo permitido
    call PedirEntero ; EAX = 1 si es válido o 0 si no, ECX = número capturado
ENDM

SaltarSiFalla MACRO destino ;Recibe como parametro destino el cual es la etiqueta a la que se salta si el procedimiento anterior falló
    cmp eax, 1 ;Compara si el procedimiento anterior tuvo exito
    jne destino ; Si no, se salta a la etiqueta indicada
ENDM

AvisarSiFalla MACRO mensaje
    LOCAL valido ; Cada expansión genera un nombre distinto para la etiqueta
    cmp eax, 1 ; Se compara si el procedimiento anterior tuvo exito
    je valido
    MostrarMensaje mensaje ; Si no, se muestra el error
    mov eax, 0 ; Se indica que el dato no es válido
    valido:
ENDM

ValidarNoCero MACRO destino ;Recibe como parametro la etiqueta a la que se salta si ECX vale cero
    LOCAL noEsCero ; Cada expansión genera un nombre distinto para la etiqueta
    cmp ecx, 0 ; No se permite una cantidad de cero unidades
    jne noEsCero
    MostrarMensaje msgCantCero ; Se avisa que la cantidad debe ser mayor que cero
    jmp destino
    noEsCero:
ENDM

SaltarSiFueraDeRango MACRO minimo, maximo, destino
;Tiene como parametros el límite inferior, el límite superior y la etiqueta a la que se salta si el dato no es válido
    cmp al, minimo ; Si AL es menor que el límite inferior no es válido
    jb destino
    cmp al, maximo ; Si AL es mayor que el límite superior no es válido
    ja destino
ENDM

ApuntarCampo MACRO desplazamiento ;Recibe como parametro la posición del campo dentro del registro
    mov edx, OFFSET tabla ; EDX apunta al inicio de la tabla
    add edx, esi ; Se avanza hasta el registro
    add edx, desplazamiento ; Se avanza hasta el campo
ENDM

GuardarCampo MACRO posicion, desplazamiento ;Recibe la posición del registro y la posición del campo dentro del registro
    mov esi, posicion ; ESI representa la posición del registro
    add esi, desplazamiento ; ESI es la posición del campo dentro del registro
    call CopiarEntrada ; Se copia la cadena de entrada al campo
ENDM

GuardarDword MACRO posicion, desplazamiento ;recibe la posición del registro y la posición del campo dentro del registro
    mov esi, posicion ; ESI representa la posición del registro
    mov DWORD PTR tabla[esi+desplazamiento], ecx ; Se guarda el valor en el campo indicado
ENDM

EtiquetaImporte MACRO etiqueta, variable 
;recibe como parametros el nombre de la variable con el texto previo y el nombre de la variable con el importe en centavos
    MostrarMensaje etiqueta ; Se muestra el texto previo
    mov eax, variable ; EAX es el importe en centavos
    call MostrarMXN ; Se muestra con el formato $pesos.centavos MXN
    call Crlf ; Salto de línea
ENDM

EtiquetaNumero MACRO etiqueta, variable ;recibe el nombre de la variable con el texto previo y el nombre de la variable con el número
    MostrarMensaje etiqueta ; Se muestra el texto previo
    mov eax, variable ; EAX es el número
    call MostrarNumero ; Se muestra el número
    call Crlf ; Salto de línea
ENDM

LeerLineaOError MACRO destino ;recibe la etiqueta a la que se salta si no se pudo leer la línea del archivo
    call LeerLinea ; Copia la siguiente línea del archivo a entrada
    SaltarSiFalla destino ; Si la línea es muy larga o está mal terminada se rechaza el archivo
ENDM

.data
;Buffers usados en el programa
;Estructura de cada producto (44 bytes por registro): +0 id, +8 nombre (max 25 caracteres), +36 precio, +40 cantidad
tabla BYTE 880 DUP(0) ; Espacio para 20 registros (catalogo + temporal)
entrada BYTE 40 DUP(0) ; Buffer entrada de ReadString
numTexto BYTE 12 DUP(0) ; Buffer para conversiones decimales
bufArchivo BYTE 513 DUP(0) ; Buffer de lectura
bufSalida BYTE 600 DUP(0) ; Buffer de escritura

;Variables usadas en el programa
totalProd DWORD 0
tmpTotal DWORD 0
ingresos DWORD 0
cambios DWORD 0
posRegistro DWORD 0
posArchivo DWORD 0
posTmp DWORD 0
contados DWORD 0
importeBase DWORD 0
importeDesc DWORD 0
importeTotal DWORD 0
unidades DWORD 0
valorInv DWORD 0
nombreArchivo BYTE "Inventario.txt", 0
archivoHandle DWORD ?
bytesLeidos DWORD 0
bytesEsperados DWORD 0

;Mensajes para el menú
msgBienvenida BYTE "LIBRERIA EN LINEA",0
msgMenu BYTE 0dh, 0ah, "1. Cargar datos existentes", 0dh, 0ah,
             "2. Registrar producto", 0dh, 0ah,
             "3. Mostrar inventario", 0dh, 0ah,
             "4. Buscar por id", 0dh, 0ah,
             "5. Recibir mercancia", 0dh, 0ah,
             "6. Vender (10% de descuento desde 5 ejemplares)", 0dh, 0ah,
             "7. Resumen", 0dh, 0ah,
             "8. Guardar", 0dh, 0ah,
             "0. Salir", 0dh, 0ah, 0

msgOpcion BYTE "Opcion: ", 0
msgId BYTE "Ingrese el id: ", 0
msgNombre BYTE "Ingrese el nombre (max 25 caracteres): ", 0
msgPrecio BYTE "Ingrese el precio en MXN: ", 0
msgCantidad BYTE "Ingrese la cantidad (max 100): ", 0
msgCantRec BYTE "Ingrese las unidades recibidas: ", 0
msgCantVta BYTE "Ingrese la cantidad a vender: ", 0
msgPreguntaGuardar BYTE "Hay cambios sin guardar. Desea guardar s/n? ", 0

;Mensajes para mostrar resultados
msgSep BYTE ", ", 0
msgCantLbl BYTE ", Cantidad: ", 0
msgPeso BYTE "$", 0
msgPunto BYTE ".", 0
msgCero BYTE "0", 0
msgMXN BYTE " MXN", 0
msgBaseLbl BYTE "Importe base: ", 0
msgDescLbl BYTE "Descuento 10%: -", 0
msgTotalLbl BYTE "Total: ", 0
msgNuevaExist BYTE "Nueva existencia: ", 0
msgProductos BYTE "Productos registrados: ", 0
msgUnidades BYTE "Unidades disponibles: ", 0
msgValor BYTE "Valor del inventario: ", 0
msgIngresos BYTE "Ingresos de la sesion: ", 0
salto BYTE 0dh, 0ah, 0

;Mensajes para los distintos errores
msgOpcionMal BYTE "Opcion invalida", 0dh, 0ah, 0
msgVacio BYTE "El dato no puede estar vacio.", 0dh, 0ah, 0
msgIdMal BYTE "Id invalido, use 3 letras mayusculas, un guion y 3 digitos.", 0dh, 0ah, 0
msgNombreMal BYTE "Nombre invalido, use de 1 a 25 caracteres.", 0dh, 0ah, 0
msgPrecioMal BYTE "Precio invalido.", 0dh, 0ah, 0
msgNumMal BYTE "Numero invalido.", 0dh, 0ah, 0
msgCantCero BYTE "La cantidad debe ser mayor que cero.", 0dh, 0ah, 0
msgLleno BYTE "El catalogo esta lleno.", 0dh, 0ah, 0
msgDuplicado BYTE "Ya existe un producto con ese id.", 0dh, 0ah, 0
msgNoExiste BYTE "No existe un producto con ese id.", 0dh, 0ah, 0
msgSinProductos BYTE "No hay productos registrados.", 0dh, 0ah, 0
msgExcede BYTE "La existencia no puede pasar de 100 unidades.", 0dh, 0ah, 0
msgSinExist BYTE "No hay existencias suficientes.", 0dh, 0ah, 0
msgDesborda BYTE "Desbordamiento, la operacion se cancelo.", 0dh, 0ah, 0
msgOk BYTE "Operacion realizada exitosamente.", 0dh, 0ah, 0

;Mensajes para cuando se guarda un archivo
msgGuardado BYTE "Catalogo guardado correctamente.", 0dh, 0ah, 0
msgNoGuardado BYTE "No se pudo guardar el archivo.", 0dh, 0ah, 0
msgNoArchivo BYTE "No se encontro el archivo.", 0dh, 0ah, 0
msgArchivoMal BYTE "Archivo invalido, el catalogo no cambio.", 0dh, 0ah, 0
msgErrLectura BYTE "Error al leer el archivo.", 0dh, 0ah, 0

.code
main PROC

    MostrarMensaje msgBienvenida ; Se muestra el mensaje de bienvenida

    menu: ;Ciclo del menú principal
        MostrarMensaje msgMenu
        LlamarConCadena PedirCadena, msgOpcion ; Se captura la opción, EAX regresa la longitud
        cmp eax, 1 ; La opción debe ser un solo carácter
        jne opcionMala
        mov al, entrada[0]
        sub al, '0' ; Se convierte el carácter ASCII en su valor numérico
        cmp al, 1 ; Opción 1: cargar
        je opc1
        cmp al, 2 ; Opción 2: registrar
        je opc2
        cmp al, 3 ; Opción 3: mostrar el inventario
        je opc3
        cmp al, 4 ; Opción 4: buscar
        je opc4
        cmp al, 5 ; Opción 5: recibir mercancía
        je opc5
        cmp al, 6 ; Opción 6: vender
        je opc6
        cmp al, 7 ; Opción 7: resumen
        je opc7
        cmp al, 8 ; Opción 8: guardar
        je opc8
        cmp al, 0 ; Opción 0: salir
        je salir

    opcionMala: ;Función cuando la opción no es válida
        MostrarMensaje msgOpcionMal
        jmp menu

    opc1:
        call Cargar
        jmp menu
    opc2:
        call Registrar
        jmp menu
    opc3:
        call MostrarInventario
        jmp menu
    opc4:
        call Buscar
        jmp menu
    opc5:
        call Recibir
        jmp menu
    opc6:
        call Vender
        jmp menu
    opc7:
        call Resumen
        jmp menu
    opc8:
        call Guardar
        jmp menu

    salir: ;Antes de terminar se revisa si hay cambios sin guardar
        cmp cambios, 0
        je terminar
        LlamarConCadena PedirCadena, msgPreguntaGuardar
        mov al, entrada[0]
        cmp al, 's'
        je guardarSalir
        cmp al, 'S'
        je guardarSalir
        jmp terminar ; Cualquier otra respuesta termina sin guardar

    guardarSalir:
        call Guardar

    terminar:
        exit

main ENDP

convertirDecimal PROC USES eax ebx ecx edx esi ;Convierte un número en su cadena decimal terminada en 00h
    ;Entradas: EAX = número, ESI = dirección del buffer de al menos 11 bytes
    ;Salidas: la cadena queda escrita en el buffer
    ;Registros modificados: ninguno (USES conserva EAX, EBX, ECX, EDX y ESI)
        mov ecx, 0 ; Contador de dígitos

    extraerDigitos:
        mov edx, 0
        mov ebx, 10 ; Divisor para extraer el último dígito
        div ebx ; Cociente en EAX y residuo (dígito) en EDX
        push edx ; Se apila el dígito
        inc ecx
        cmp eax, 0
        jne extraerDigitos

    construirCadena:
        pop edx ; Los dígitos salen en orden LIFO
        add dl, '0' ; Se convierte el dígito en su carácter ASCII
        mov [esi], dl
        inc esi
        loop construirCadena

        mov dl, 0 ; Terminador nulo
        mov [esi], dl
        ret ; USES restaura los registros; los dígitos apilados ya salieron, la pila queda equilibrada
convertirDecimal ENDP

MostrarNumero PROC USES edx esi ;Convierte un número a cadena decimal y lo muestra en pantalla
    ;Entradas: EAX = número
    ;Registros modificados: ninguno (USES conserva EDX y ESI, EAX solo se lee)
    mov esi, OFFSET numTexto ; ESI apunta al buffer donde se escribirá la cadena
    call convertirDecimal ; Se convierte el número de EAX en texto dentro de numTexto
    MostrarMensaje numTexto ; WriteString imprime la cadena a la que apunta EDX
    ret
MostrarNumero ENDP

MostrarMXN PROC USES eax ebx edx ;Muestra un importe en centavos con el formato $pesos.centavos MXN
    ;Entradas: EAX = importe en centavos
    ;Registros modificados: ninguno (USES conserva EAX, EBX y EDX)
    mov edx, 0 ; Se limpia EDX porque div usa EDX:EAX como dividendo
    mov ebx, 100 ;Se asigna 100 para comenzar la división
    div ebx ; EAX queda con los pesos y EDX con los centavos
    push edx ; Se guardan los centavos mientras se imprimen los pesos

    MostrarMensaje msgPeso ; Símbolo $
    call MostrarNumero ; Se muestran los pesos que están en EAX
    MostrarMensaje msgPunto ; Punto decimal

    pop eax ; EAX recibe los centavos
    cmp eax, 10 ; Con dos dígitos no hace falta relleno
    jae dosDigitos
    MostrarMensaje msgCero ; Relleno: 5 se muestra como 05

    dosDigitos:
        call MostrarNumero ; Se muestran los centavos
        MostrarMensaje msgMXN ; Etiqueta de la moneda
        ret
MostrarMXN ENDP

PedirCadena PROC USES ecx edx ;Muestra un mensaje y captura una cadena con ReadString
    ;Entradas: EDX = mensaje que se muestra al pedir el dato
    ;Salidas: la cadena queda en entrada y EAX = longitud capturada
    ;Registros modificados: EAX (USES conserva ECX y EDX)
    call WriteString
    mov edx, OFFSET entrada ; Buffer donde se guardará la entrada
    mov ecx, SIZEOF entrada ; Límite máximo de lectura
    call ReadString ; EAX regresa la cantidad de caracteres leídos
    ret
PedirCadena ENDP

PedirDato PROC USES ecx edx ;Proceso para pedir datos
    ;Entradas: EDX = mensaje que se muestra al pedir el dato
    ;Salidas: EAX = 1 si capturó algo (queda en entrada), 0 si está vacía (muestra el error)
    ;Registros modificados: EAX (USES conserva ECX y EDX)

    call PedirCadena 
    cmp eax, 0
    jne datoCapturado
    MostrarMensaje msgVacio
    mov eax, 0
    ret

    datoCapturado:
        mov eax, 1
        ret
PedirDato ENDP

ValidarId PROC USES ecx esi ;Revisa que entrada tenga el formato ABC-123: 3 letras mayúsculas, un guion y 3 dígitos
    ;Entradas: entrada con la cadena capturada
    ;Salidas: EAX = 1 si el id es válido, 0 si no lo es
    ;Registros modificados: EAX (USES conserva ECX y ESI)
    mov esi, 0 ; ESI es el índice dentro de entrada
    mov ecx, 3 ; Se revisan las posiciones 0, 1 y 2
    corroborarLetras:
        mov al, entrada[esi] ;Se recorre el índice para confirmar que lo que se encuentra en las posiciones 0, 1 y 2
        SaltarSiFueraDeRango 'A', 'Z', idInvalido ;sean solo letras mayúsculas (de la A a la Z)
        inc esi
        loop corroborarLetras ;se repite el ciclo hasta que terminen las 3 posiciones

        mov al, entrada[3] ; Separador en la posición 4 (índice 3)
        cmp al, '-'
        jne idInvalido
        mov esi, 4 ; El índice se coloca después del guion
        mov ecx, 3 ; Se revisan las posiciones 5, 6 y 7 (índices 4, 5 y 6)

    cicloDigitos:
        mov al, entrada[esi]
        SaltarSiFueraDeRango '0', '9', idInvalido ;Se confirma que los últimos tres caracteres sean dígitos del 0 al 9
        inc esi ;se incrementa el índice para pasar al siguiente dígito
        loop cicloDigitos

        mov al, entrada[7] ; Debe ser el fin de la cadena, así el id mide exactamente 7 caracteres
        cmp al, 0
        jne idInvalido
        mov eax, 1 ; Id válido
        jmp finValidarId

    idInvalido: ;Se retorna en caso de ser inválido
        mov eax, 0

    finValidarId:
        ret
ValidarId ENDP

ValidarNombre PROC USES ecx esi ;Revisa que entrada tenga de 1 a 25 caracteres imprimibles
    ;Entradas: entrada con la cadena capturada
    ;Salidas: EAX = 1 si es válido, 0 si no lo es
    ;Registros modificados: EAX (USES conserva ECX y ESI)
    mov esi, 0
    mov ecx, 0 ; ECX cuenta la longitud del nombre

    cicloNombre:
        mov al, entrada[esi]
        cmp al, 0 ;Compara que se haya llegado al final de la cadena del nombre
        je finNombre
        SaltarSiFueraDeRango 32, 126, nombreInvalido ; Solo se aceptan caracteres imprimibles (32 a 126)
        inc ecx ;se incrementa el valor de la longitud del nombre
        inc esi ;se incrementa el índice que recorre
        jmp cicloNombre

    finNombre:
        cmp ecx, 1 ;Se confirma que el nombre tenga una longitud de 1 a 25 caracteres
        jb nombreInvalido
        cmp ecx, 25
        ja nombreInvalido
        mov eax, 1
        jmp salirValidarNombre

    nombreInvalido:
        mov eax, 0

    salirValidarNombre:
        ret

ValidarNombre ENDP

AcumularDigito PROC USES eax edx ;Suma un dígito ASCII a un acumulado con la fórmula acumulado x 10 + dígito
    ;Entradas: ECX = acumulado actual, AL = carácter ASCII del dígito ('0' a '9')
    ;Salidas: ECX = acumulado x 10 + dígito
    ;Registros modificados: ECX (USES conserva EAX y EDX)
    imul ecx, ecx, 10 ; ECX = acumulado x 10 (no usa EDX:EAX)    
    sub al, '0' ; Se convierte el ASCII en su valor de 0 a 9
    movzx edx, al ; EDX = dígito sin basura en los bits altos
    add ecx, edx ; Se suma el dígito
    ret
AcumularDigito ENDP

ConvertirEntero PROC USES esi ;Convierte la cadena de entrada en número con la fórmula acumulado x 10 + dígito
    ;Entradas: entrada con la cadena capturada, EBX = valor máximo permitido
    ;Salidas: EAX = 1 si es válido o 0 si no lo es, ECX = número convertido
    ;Registros modificados: EAX, ECX (USES conserva ESI)
    mov esi, 0
    mov ecx, 0 ; ECX es el acumulador
    mov al, entrada[0] ;se compara con el primer dígito del buffer entrada
    cmp al, 0 ; Una cadena vacía se rechaza
    je enteroMalo

    cicloEntero: ;Si es número, entonces se procede a realizar el ciclo de conversión
        mov al, entrada[esi]
        cmp al, 0
        je enteroBueno
        SaltarSiFueraDeRango '0', '9', enteroMalo ;Se compara que la cadena esté entre los rangos de caracter de 0 a 9
        call AcumularDigito ; ECX = acumulado x 10 + dígito
        cmp ecx, ebx ; No debe pasar del máximo
        ja enteroMalo
        inc esi
        jmp cicloEntero

    enteroBueno:
        mov eax, 1 ;se marca como operación exitosa
        jmp finEntero

    enteroMalo:
        mov eax, 0

    finEntero:
        ret
ConvertirEntero ENDP

ConvertirPrecio PROC USES ebx edx esi edi
    ;Acepta pesos enteros o un punto con uno o dos decimales, rechaza símbolos y un tercer decimal
    ;Todos los dígitos se acumulan en un solo número y al final se ajusta según los decimales escritos
    ;Entradas: entrada con la cadena capturada
    ;Salidas: EAX = 1 si es válido o 0 si no lo es, ECX = centavos de 1 a 999999
    ;Registros modificados: EAX, ECX (USES conserva EBX, EDX, ESI y EDI)
    mov esi, 0 ; ESI es el índice dentro de entrada
    mov ecx, 0 ; ECX acumula todos los dígitos como un solo número
    mov ebx, 0 ; EBX cuenta los dígitos de los pesos
    mov edi, 0 ; EDI: 0 sin punto, 1 punto sin decimales, 2 un decimal, 3 dos decimales

    cicloPrecio:
        mov al, entrada[esi]
        cmp al, 0 ; Fin de la cadena
        je finCadenaPrecio
        cmp al, '.' ; Se encontró el punto decimal
        je puntoPrecio
        SaltarSiFueraDeRango '0', '9', precioMalo ; Cualquier otro carácter debe ser un dígito
        call AcumularDigito ; ECX = acumulado x 10 + dígito
        cmp ecx, 999999 ; Si ya pasa del máximo se rechaza (también evita desbordar)
        ja precioMalo
        cmp edi, 0 ; Si todavía no hay punto, el dígito es de los pesos
        jne decimalPrecio
        inc ebx ; Es un dígito de los pesos
        jmp siguientePrecio

    decimalPrecio:
        inc edi ; Es un dígito de los decimales
        cmp edi, 3 ; Un tercer decimal se rechaza
        ja precioMalo

    siguientePrecio:
        inc esi ; Se pasa al siguiente carácter
        jmp cicloPrecio

    puntoPrecio:
        cmp edi, 0 ; Solo se permite un punto
        jne precioMalo
        cmp ebx, 0 ; Debe haber al menos un dígito antes del punto
        je precioMalo
        mov edi, 1 ; Se marca que ya apareció el punto
        inc esi
        jmp cicloPrecio

    finCadenaPrecio:
        cmp ebx, 0 ; Debe haber al menos un dígito de pesos
        je precioMalo
        cmp edi, 1 ; Un punto sin decimales se rechaza
        je precioMalo
        mov eax, ecx ; EAX = todos los dígitos juntos
        cmp edi, 3 ; Con dos decimales el acumulado ya son centavos
        je precioListo
        mov edx, 100 ; Sin punto: pesos x 100
        cmp edi, 0
        je escalarPrecio
        mov edx, 10 ; Con un decimal: 7.5 son 75 x 10 = 750 centavos

    escalarPrecio:
        mul edx ; EAX = acumulado x factor (100 o 10)

    precioListo:
        mov ecx, eax ; ECX regresa los centavos
        cmp ecx, 1 ; El mínimo es 1 centavo
        jb precioMalo
        cmp ecx, 999999 ; El máximo es 9999.99 pesos
        ja precioMalo
        mov eax, 1 ; Precio válido
        jmp finPrecio

    precioMalo:
        mov eax, 0

    finPrecio:
        ret
ConvertirPrecio ENDP

PedirId PROC USES edx ;Pide un id y verifica que tenga el formato correcto
    ;Entradas: EDX = mensaje que se muestra al pedir el dato
    ;Salidas: EAX = 1 si el id es válido (queda en entrada), 0 si no lo es (muestra el error)
    ;Registros modificados: EAX (USES conserva EDX)
    call PedirDato ; Captura la cadena, EAX = 1 si no está vacía
    SaltarSiFalla finPedirId ; Si estaba vacía PedirDato ya mostró el error
    call ValidarId ; Se revisa el formato ABC-123
    AvisarSiFalla msgIdMal ; Si el formato no es válido se muestra el error y EAX queda en 0

    finPedirId:
        ret
PedirId ENDP

PedirNombre PROC USES edx ;Pide un nombre y verifica que tenga de 1 a 25 caracteres imprimibles
    ;Entradas: EDX = mensaje que se muestra al pedir el dato
    ;Salidas: EAX = 1 si el nombre es válido (queda en entrada), 0 si no lo es (muestra el error)
    ;Registros modificados: EAX (USES conserva EDX)
    call PedirDato ; Captura la cadena, EAX = 1 si no está vacía
    SaltarSiFalla finPedirNombre ; Si estaba vacía PedirDato ya mostró el error
    call ValidarNombre ; Se revisa que tenga de 1 a 25 caracteres imprimibles
    AvisarSiFalla msgNombreMal ; Si no es válido se muestra el error y EAX queda en 0

    finPedirNombre:
        ret
PedirNombre ENDP

PedirPrecio PROC USES edx ;Pide un precio en pesos y lo convierte a centavos
    ;Entradas: EDX = mensaje que se muestra al pedir el dato
    ;Salidas: EAX = 1 si el precio es válido o 0 si no lo es (muestra el error), ECX = centavos
    ;Registros modificados: EAX, ECX (USES conserva EDX)
    call PedirDato ; Captura la cadena, EAX = 1 si no está vacía
    SaltarSiFalla finPedirPrecio ; Si estaba vacía PedirDato ya mostró el error
    call ConvertirPrecio ; Los centavos regresan en ECX
    AvisarSiFalla msgPrecioMal ; Si no es válido se muestra el error y EAX queda en 0

    finPedirPrecio:
        ret
PedirPrecio ENDP

PedirEntero PROC USES edx ;Pide un número entero y verifica que sea válido y no pase del máximo
    ;Entradas: EDX = mensaje que se muestra al pedir el dato, EBX = valor máximo permitido
    ;Salidas: EAX = 1 si es válido o 0 si no lo es, ECX = número capturado
    ;Registros modificados: EAX, ECX (USES conserva EDX; EBX solo se lee)
    call PedirDato ; Captura la cadena, EAX = 1 si no está vacía
    SaltarSiFalla finPedirEntero ; Si estaba vacía PedirDato ya mostró el error
    call ConvertirEntero ; Convierte la cadena en número, el resultado queda en ECX
    AvisarSiFalla msgNumMal ; Si no es válido se muestra el error y EAX queda en 0

    finPedirEntero:
        ret
PedirEntero ENDP

CopiarEntrada PROC USES eax esi edi ;Copia la cadena de entrada, con su 00h, dentro de la tabla
    ;Entradas: ESI = posición de la tabla donde se escribirá la cadena
    ;Registros modificados: ninguno (USES conserva EAX, ESI y EDI)
        mov edi, 0 ; EDI es el índice de la cadena de entrada

    cicloCopia:
        mov al, entrada[edi] ; Se toma un carácter de entrada
        mov tabla[esi], al ; Se escribe en la tabla
        inc esi
        inc edi
        cmp al, 0 ; El ciclo termina después de copiar el 00h final
        jne cicloCopia
        ret
CopiarEntrada ENDP

BuscarId PROC USES ebx ecx edi ;Recorre registros de la tabla con ESI buscando el id que está en entrada
    ;Entradas: ESI = posición del primer registro que se revisa, ECX = cuántos registros se revisan
    ;Salidas: EAX = 1 si lo encontró (ESI = posición de su registro) o 0 si no lo encontró
    ;Registros modificados: EAX, ESI (USES conserva EBX, ECX y EDI)
    cmp ecx, 0 ; Sin registros no se encuentra
    je noHallado

    siguienteRegistro:
        push esi ; Se guarda la posición donde empieza el registro
        mov edi, 0 ; EDI es el índice del id buscado

    compararCaracter:
        mov al, tabla[esi] ; Carácter del id guardado
        mov bl, entrada[edi] ; Carácter del id buscado
        cmp al, bl
        jne distinto
        cmp al, 0 ; Iguales hasta el final: los ids son iguales
        je hallado
        inc esi ;se incrementan los índices
        inc edi
        jmp compararCaracter

    distinto:
        pop esi ; Se recupera el inicio del registro
        add esi, 44 ; Siguiente registro
        loop siguienteRegistro

    noHallado:
        mov eax, 0
        jmp finBuscarId

    hallado:
        pop esi ; ESI regresa al inicio del registro encontrado
        mov eax, 1

    finBuscarId:
        ret
BuscarId ENDP

BuscarEnCatalogo PROC USES ecx ;Busca el id que está en entrada entre todos los productos del catálogo
    ;Entradas: entrada con el id buscado
    ;Salidas: EAX = 1 si lo encontró (ESI = posición de su registro) o 0 si no lo encontró
    ;Registros modificados: EAX, ESI (USES conserva ECX)
    mov esi, 0 ; La búsqueda inicia en el primer registro
    mov ecx, totalProd ; Se revisan tantos registros como productos haya
    call BuscarId ; ESI regresa con la posición del registro si lo encuentra
    ret
BuscarEnCatalogo ENDP

PedirProducto PROC USES edx ;Pide un id y busca el producto en el catálogo
    ;Salidas: EAX = 1 si el producto existe (ESI = posición de su registro), 0 si no
    ;Registros modificados: EAX, ESI (USES conserva EDX)
    LlamarConCadena PedirId, msgId ; Se pide y valida el formato del id
    SaltarSiFalla finPedirProducto
    call BuscarEnCatalogo ; ESI regresa con la posición del registro si lo encuentra
    AvisarSiFalla msgNoExiste ; Si no existe se muestra el error y EAX queda en 0

    finPedirProducto:
        ret

PedirProducto ENDP

MostrarProducto PROC USES eax edx ;Muestra un producto en una línea
    ;Entradas: ESI = posición del registro dentro de tabla
    ;Registros modificados: ninguno (USES conserva EAX y EDX)
    ApuntarCampo 0 ; El id está en el desplazamiento +0
    call WriteString
    MostrarMensaje msgSep ;se agregan comas
    ApuntarCampo 8 ; El nombre está en el desplazamiento +8
    call WriteString
    MostrarMensaje msgSep
    mov eax, DWORD PTR tabla[esi+36] ; Precio en el desplazamiento +36
    call MostrarMXN
    MostrarMensaje msgCantLbl
    mov eax, DWORD PTR tabla[esi+40] ; Cantidad en el desplazamiento +40
    call MostrarNumero
    call Crlf
    ret
MostrarProducto ENDP

Registrar PROC USES eax ebx ecx edx esi ;Da de alta un producto pidiendo id, nombre, precio y cantidad
    ;Los datos se escriben en el primer registro libre, pero el producto solo cuenta cuando
    ;todos son válidos y se incrementa totalProd. Si algún dato es inválido no cambia el catálogo
    ;Registros modificados: ninguno (USES conserva EAX, EBX, ECX, EDX y ESI)
    cmp totalProd, 10 ; Capacidad máxima
    jb hayLugar ;comparar si hay espacio
    MostrarMensaje msgLleno
    jmp finRegistrar

    hayLugar:
        LlamarConCadena PedirId, msgId ; Se pide y valida el id
        SaltarSiFalla finRegistrar
        call BuscarEnCatalogo ; ¿El id ya existe?
        cmp eax, 1
        jne idLibre
        MostrarMensaje msgDuplicado
        jmp finRegistrar

    idLibre:
        mov eax, totalProd
        mov ebx, 44 ; Tamaño de cada registro
        mul ebx ; EAX = posición del primer registro libre
        mov posRegistro, eax ; Se guarda la posición porque ESI se modifica más adelante
        mov esi, eax
        call CopiarEntrada ; Se guarda el id en el desplazamiento +0

        LlamarConCadena PedirNombre, msgNombre ; Se pide y valida el nombre, queda en entrada
        SaltarSiFalla finRegistrar
        GuardarCampo posRegistro, 8 ; El nombre va en el desplazamiento +8

        LlamarConCadena PedirPrecio, msgPrecio ; Se pide y valida el precio, los centavos regresan en ECX
        SaltarSiFalla finRegistrar
        GuardarDword posRegistro, 36 ; Precio en el desplazamiento +36

        PedirNumero msgCantidad, 100 ; La cantidad máxima es 100, la cantidad regresa en ECX
        SaltarSiFalla finRegistrar
        GuardarDword posRegistro, 40 ; Cantidad en el desplazamiento +40

        inc totalProd ; Todos los datos son válidos, se cuenta un producto más
        mov cambios, 1 ; Se marca que hay cambios sin guardar
        MostrarMensaje msgOk

    finRegistrar:
        ret
Registrar ENDP

MostrarInventario PROC USES ecx edx esi ;Muestra todos los productos registrados, uno por línea
    ;Registros modificados: ninguno (USES conserva ECX, EDX y ESI)
    cmp totalProd, 0 ;se comprueba que existan productos
    jne hayProductos
    MostrarMensaje msgSinProductos
    jmp finMostrar

    hayProductos:
        mov esi, 0 ; ESI es la posición del registro que se muestra
        mov ecx, totalProd ; ECX controla cuántos registros faltan

    cicloMostrar:
        call MostrarProducto ; Se imprime el registro al que apunta ESI
        add esi, 44 ; Siguiente registro
        loop cicloMostrar

    finMostrar:
        ret
MostrarInventario ENDP

Buscar PROC USES eax ecx edx esi ;Pide un id y muestra el producto encontrado
    ;Registros modificados: ninguno (USES conserva EAX, ECX, EDX y ESI)
    call PedirProducto ;se llama al metodo para pedir el id
    SaltarSiFalla finBuscar
    call MostrarProducto ; ESI apunta al producto encontrado

    finBuscar:
        ret
Buscar ENDP

Recibir PROC USES eax ebx ecx edx esi ;Suma unidades a un producto existente sin pasar de 100
    ;Registros modificados: ninguno (USES conserva EAX, EBX, ECX, EDX y ESI)
    call PedirProducto ;se llama al método para buscar el id
    SaltarSiFalla finRecibir ;se comprueba que se haya retornado algo válido
    PedirNumero msgCantRec, 1000000 ; Valor máximo que se acepta capturar, ECX regresa la cantidad
    SaltarSiFalla finRecibir
    ValidarNoCero finRecibir ; No se permite recibir cero unidades

    cantidadRecibida:
        mov eax, DWORD PTR tabla[esi+40] ; Existencia actual
        add eax, ecx ; No desborda porque son máximo 1000100
        cmp eax, 100 ; La existencia no puede pasar de 100
        jbe aplicarEntrada
        MostrarMensaje msgExcede
        jmp finRecibir

    aplicarEntrada:
        mov DWORD PTR tabla[esi+40], eax ; Se guarda la nueva existencia
        mov cambios, 1 ; Se marca que hay cambios sin guardar
        MostrarMensaje msgNuevaExist
        call MostrarNumero ; Se muestra la nueva existencia que está en EAX
        call Crlf

    finRecibir:
        ret
Recibir ENDP

CalcularImporte PROC USES ebx edx ;Calcula el importe base, el descuento por cantidad y el total de una venta
    ;Regla adicional: con 5 o más ejemplares se descuenta el 10% del importe base y se descarta
    ;la fracción de centavo
    ;Entradas: ECX = cantidad vendida, ESI = posición del registro del producto
    ;Salidas: EAX = 1 si se calculó bien o 0 si algún resultado no cabe en 32 bits,
    ;importeBase, importeDesc e importeTotal con los importes en centavos
    ;Registros modificados: EAX (USES conserva EBX y EDX; ECX y ESI solo se leen)
    mov eax, DWORD PTR tabla[esi+36] ; Precio en centavos
    mul ecx ; EDX:EAX = precio x cantidad
    cmp edx, 0 ; Si EDX no es 0 no cabe en 32 bits
    jne importeDesborda
    mov importeBase, eax
    mov importeDesc, 0
    cmp ecx, 5 ; Regla adicional: 5 o más ejemplares
    jb sinDescuento
    mov ebx, 10
    mul ebx ; EAX = importe base x 10
    cmp edx, 0
    jne importeDesborda
    mov edx, 0
    mov ebx, 100
    div ebx ; EAX = base x 10 / 100, el residuo se descarta
    mov importeDesc, eax

    sinDescuento:
        mov eax, importeBase
        sub eax, importeDesc ; Total = importe base - descuento
        mov importeTotal, eax
        mov eax, 1 ; Cálculo correcto
        jmp finCalcularImporte

    importeDesborda:
        mov eax, 0 ; El importe no cabe en 32 bits

    finCalcularImporte:
        ret
CalcularImporte ENDP

Vender PROC USES eax ebx ecx edx esi
    ;Primero se validan todos los datos y hasta el final se actualizan existencias e ingresos
    ;Regla adicional: con 5 o más ejemplares se descuenta el 10% del importe base y se descarta
    ;la fracción de centavo. Si la venta se rechaza no cambia ningún dato
    ;Registros modificados: ninguno (USES conserva EAX, EBX, ECX, EDX y ESI)
    call PedirProducto ;se llama al método
    SaltarSiFalla finVender ;se válida el estado de válido
    PedirNumero msgCantVta, 1000000 ; Valor máximo que se acepta capturar, ECX regresa la cantidad
    SaltarSiFalla finVender
    ValidarNoCero finVender ; No se permite vender cero unidades

    ventaCantidad:
        cmp ecx, DWORD PTR tabla[esi+40] ; Cantidad contra existencia
        jbe hayExistencia ;en caso que haya existencia salta a la operación
        MostrarMensaje msgSinExist
        jmp finVender

    hayExistencia:
        call CalcularImporte ; Se calculan importe base, descuento y total
        SaltarSiFalla ventaDesborda ; Si algún importe no cabe en 32 bits se cancela
        mov eax, ingresos
        add eax, importeTotal ; Se suma la venta a los ingresos de la sesión
        jc ventaDesborda ; Si hay acarreo no cabe en 32 bits y se cancela

        mov ingresos, eax ; Venta aceptada: ahora sí se actualizan los datos
        mov eax, DWORD PTR tabla[esi+40]
        sub eax, ecx ; Existencia = existencia - cantidad vendida
        mov DWORD PTR tabla[esi+40], eax
        mov cambios, 1 ; Se marca que hay cambios sin guardar

        EtiquetaImporte msgBaseLbl, importeBase ; Se muestra el importe base
        cmp ecx, 5
        jb mostrarTotal ; Con menos de 5 no hubo descuento
        EtiquetaImporte msgDescLbl, importeDesc ; Se muestra el descuento

    mostrarTotal:
        EtiquetaImporte msgTotalLbl, importeTotal ; Se muestra el total a pagar
        jmp finVender

    ventaDesborda:
        MostrarMensaje msgDesborda ; Ningún dato se modificó, la venta se cancela

    finVender:
        ret
Vender ENDP

Resumen PROC USES eax ecx edx esi ;Muestra las unidades disponibles, el valor del inventario y los ingresos de la sesión
    ;Registros modificados: ninguno (USES conserva EAX, ECX, EDX y ESI)
    mov unidades, 0 ;se inicializan los valores
    mov valorInv, 0
    mov esi, 0
    mov ecx, totalProd
    cmp ecx, 0
    je imprimirResumen

    cicloResumen:
        mov eax, DWORD PTR tabla[esi+40] ; Existencia del producto
        add unidades, eax
        mov eax, DWORD PTR tabla[esi+36] ; Precio del producto
        mov edx, DWORD PTR tabla[esi+40]
        mul edx ; EDX:EAX = precio x existencia
        cmp edx, 0 ; Si EDX no es 0 no cabe en 32 bits
        jne resumenDesborda
        add valorInv, eax
        jc resumenDesborda
        add esi, 44
        loop cicloResumen

    imprimirResumen:
        EtiquetaNumero msgProductos, totalProd ; Se muestran los productos registrados
        EtiquetaNumero msgUnidades, unidades ; Se muestran las unidades disponibles
        EtiquetaImporte msgValor, valorInv ; Se muestra el valor del inventario
        EtiquetaImporte msgIngresos, ingresos ; Se muestran los ingresos de la sesión
        jmp finResumen

    resumenDesborda:
        MostrarMensaje msgDesborda

    finResumen:
        ret
Resumen ENDP

AgregarCadena PROC USES eax edx ;Agrega una cadena, sin su 00h, al buffer bufSalida
    ;Entradas: EDX = dirección de la cadena, EBX = posición actual dentro de bufSalida
    ;Salidas: EBX avanzado al final de lo agregado
    ;Registros modificados: EBX (se deja modificado a propósito para seguir escribiendo, por eso no va en USES)

    cicloAgregar:
    mov al, [edx] ; Se toma un carácter de la cadena
    cmp al, 0 ; El 00h no se copia
    je finAgregar
    mov bufSalida[ebx], al ; Se escribe en el buffer de salida
    inc ebx ; EBX avanza en el buffer
    inc edx ; EDX avanza en la cadena
    jmp cicloAgregar

    finAgregar:
    ret
AgregarCadena ENDP

AgregarLinea PROC USES edx ;Agrega una cadena y un salto de línea al buffer bufSalida
    ;Entradas: EDX = dirección de la cadena, EBX = posición actual dentro de bufSalida
    ;Salidas: EBX avanzado al final de lo agregado
    ;Registros modificados: EBX (USES conserva EDX, que regresa a la dirección original de la cadena)
    call AgregarCadena ; Se agrega la cadena
    LlamarConCadena AgregarCadena, salto ; Se agrega el 0Dh 0Ah
    ret
AgregarLinea ENDP

AgregarNumero PROC USES edx esi ;Convierte un número en cadena decimal y la agrega al buffer con un salto de línea
    ;Entradas: EAX = número, EBX = posición actual dentro de bufSalida
    ;Salidas: EBX avanzado al final de lo agregado
    ;Registros modificados: EBX (USES conserva EDX y ESI, EAX solo se lee)
    mov esi, OFFSET numTexto ; Buffer donde se escribe la cadena decimal
    call convertirDecimal ; Se convierte EAX en texto
    LlamarConCadena AgregarLinea, numTexto ; Se agrega el texto y un salto de línea al buffer de salida
    ret
AgregarNumero ENDP

Guardar PROC USES eax ebx ecx edx esi ;Guarda el catálogo en el archivo de texto Inventario.txt
    ;Cada dato va en su propia línea: primero el total de productos y después, por cada
    ;producto, el id, el nombre, el precio en centavos y la cantidad
    ;Registros modificados: ninguno (USES conserva EAX, EBX, ECX, EDX y ESI)
    mov ebx, 0 ; EBX es la posición dentro de bufSalida
    mov eax, totalProd ;se guarda la cantidad total de productos
    call AgregarNumero
    mov esi, 0
    mov ecx, totalProd
    cmp ecx, 0
    je escribirArchivo ; Sin productos solo se escribe el total

    cicloGuardar:
        ApuntarCampo 0 ; El id está en el desplazamiento +0
        call AgregarLinea
        ApuntarCampo 8 ; El nombre está en el desplazamiento +8
        call AgregarLinea
        mov eax, DWORD PTR tabla[esi+36] ; Precio en centavos
        call AgregarNumero
        mov eax, DWORD PTR tabla[esi+40] ; Cantidad
        call AgregarNumero
        add esi, 44 ;se va incrementando el índice
        dec ecx
        jne cicloGuardar

    escribirArchivo:
        mov bytesEsperados, ebx ; EBX es el total de bytes que se armaron en bufSalida
        LlamarConCadena CreateOutputFile, nombreArchivo ; Se devuelve el identificador a EAX
        cmp eax, INVALID_HANDLE_VALUE ;se confirma que no exista error
        je errorGuardar
        mov archivoHandle, eax ; Se guarda el identificador del archivo

        mov eax, archivoHandle
        mov edx, OFFSET bufSalida ; Datos que se escribirán
        mov ecx, bytesEsperados ; Cantidad de bytes a escribir
        call WriteToFile ; Devuelve los bytes escritos en EAX
        jc errorEscritura
        cmp eax, bytesEsperados ; Deben coincidir con los esperados
        jne errorEscritura

        mov eax, archivoHandle
        call CloseFile
        test eax, eax ; Si el resultado es cero el cierre falló
        jz errorGuardar
        mov cambios, 0 ; Ya no hay cambios pendientes
        MostrarMensaje msgGuardado
        jmp finGuardar

    errorEscritura: ;Función cuando falla la escritura
        mov eax, archivoHandle
        call CloseFile ; Se cierra el archivo para no bloquear la memoria

    errorGuardar: ;Función que muestra mensaje de error
        MostrarMensaje msgNoGuardado

    finGuardar:
        ret
Guardar ENDP

LeerLinea PROC USES ebx esi ;Copia a entrada la línea de bufArchivo que empieza en posArchivo
    ;La línea termina con el salto de línea 0Dh 0Ah o con el fin del texto
    ;Entradas: posArchivo con la posición de lectura
    ;Salidas: EAX = 1 si se leyó bien o 0 si la línea es muy larga o está mal terminada,
    ;entrada con la línea y posArchivo avanzado a la siguiente línea
    ;Registros modificados: EAX (USES conserva EBX y ESI)
    mov esi, posArchivo ; ESI es el índice dentro de bufArchivo
    mov ebx, 0 ; EBX es el índice de entrada

    cicloLinea:
        mov al, bufArchivo[esi]
        cmp al, 0dh ; Retorno de carro
        je finLineaCR
        cmp al, 0 ; Fin del texto
        je finLineaTexto
        cmp ebx, 30 ; Límite de longitud de una línea
        jae lineaMala
        mov entrada[ebx], al ; Se copia el carácter a entrada
        inc ebx
        inc esi
        jmp cicloLinea

    finLineaCR:
        mov entrada[ebx], 0 ; Se cierra la cadena con 00h
        inc esi ; Salta el retorno de carro
        mov al, bufArchivo[esi]
        cmp al, 0ah ; Después debe venir el salto de línea
        jne lineaMala
        inc esi ; Salta el salto de línea
        mov posArchivo, esi ; La siguiente lectura empieza en la línea que sigue
        mov eax, 1
        jmp finLeerLinea

    finLineaTexto:
        mov entrada[ebx], 0 ; Última línea sin salto de línea al final
        mov posArchivo, esi
        mov eax, 1
        jmp finLeerLinea

    lineaMala:
        mov eax, 0 ; Línea demasiado larga o mal terminada

    finLeerLinea:
        ret
LeerLinea ENDP

ValidarArchivo PROC USES ebx ecx edx esi ;Revisa el texto leído en bufArchivo antes de reemplazar el catálogo
;Cada producto leído se valida y se guarda en la zona temporal de la tabla (desde la posición 440)
    ;Salidas: EAX = 1 si todo el archivo es válido, 0 si no lo es; tmpTotal = total de productos
;Registros modificados: EAX (USES conserva EBX, ECX, EDX y ESI)
    mov posArchivo, 0 ;se inicializan valores
    mov contados, 0
    mov posTmp, 440 ; El primer registro temporal está en la posición 440

    LeerLineaOError archivoInvalido ; La primera línea trae el total de productos
    mov ebx, 10 ; El máximo de productos es 10
    call ConvertirEntero
    SaltarSiFalla archivoInvalido
    mov tmpTotal, ecx ; Se guarda el total declarado en el archivo

    revisarProducto:
        mov eax, contados
        cmp eax, tmpTotal ; Se termina cuando ya se leyeron todos los productos
        jae finProductos

        LeerLineaOError archivoInvalido ; Línea del id
        call ValidarId
        SaltarSiFalla archivoInvalido
        mov esi, 440 ; La búsqueda empieza en la zona temporal
        mov ecx, contados ; Solo se revisan los productos ya leídos
        call BuscarId ; ¿El id está repetido entre los registros temporales anteriores?
        cmp eax, 1
        je archivoInvalido
        mov esi, posTmp
        call CopiarEntrada ; Se guarda el id en el desplazamiento +0

        LeerLineaOError archivoInvalido ; Línea del nombre
        call ValidarNombre
        SaltarSiFalla archivoInvalido
        GuardarCampo posTmp, 8 ; El nombre va en el desplazamiento +8

        LeerLineaOError archivoInvalido ; Línea del precio
        mov ebx, 999999 ; Precio máximo en centavos
        call ConvertirEntero
        SaltarSiFalla archivoInvalido
        cmp ecx, 1 ; Precio mínimo: 1 centavo
        jb archivoInvalido
        GuardarDword posTmp, 36 ; Precio en el desplazamiento +36

        LeerLineaOError archivoInvalido ; Línea de la cantidad
        mov ebx, 100 ; Cantidad máxima
        call ConvertirEntero
        SaltarSiFalla archivoInvalido
        GuardarDword posTmp, 40 ; Cantidad en el desplazamiento +40

        add posTmp, 44 ; Siguiente registro temporal
        inc contados ; Un producto más leído
        jmp revisarProducto

    finProductos:
        mov esi, posArchivo
        mov al, bufArchivo[esi]
        cmp al, 0 ; No deben sobrar datos después del último producto
        jne archivoInvalido
        mov eax, 1 ; Archivo válido
        jmp finValidarArchivo

    archivoInvalido:
        mov eax, 0

    finValidarArchivo:
        ret
ValidarArchivo ENDP

Cargar PROC USES eax ebx ecx edx esi ;Lee el archivo, valida los datos y solo si son válidos reemplaza el catálogo
    ;Registros modificados: ninguno (USES conserva EAX, EBX, ECX, EDX y ESI)
    LlamarConCadena OpenInputFile, nombreArchivo ; Se devuelve el identificador a EAX
    cmp eax, INVALID_HANDLE_VALUE ;se comprueba que no exista error
    jne archivoAbierto
    MostrarMensaje msgNoArchivo ; Archivo ausente
    jmp finCargar

    archivoAbierto:
        mov archivoHandle, eax ; Se guarda el identificador del archivo
        mov eax, archivoHandle
        mov edx, OFFSET bufArchivo ; Buffer donde se guardará el contenido
        mov ecx, SIZEOF bufArchivo-1 ; Capacidad de lectura sin contar el 00h final
        call ReadFromFile ; Devuelve los bytes leídos en EAX
        jc errorLectura ;salta si hay un error de lectura
        mov bytesLeidos, eax
        mov eax, archivoHandle
        call CloseFile
        mov ebx, bytesLeidos
        mov bufArchivo[ebx], 0 ; 00h después del último byte leído
        cmp bytesLeidos, SIZEOF bufArchivo-1
        jae archivoMalo ; Si llenó el buffer el archivo es demasiado grande
        call ValidarArchivo ; Se valida todo el archivo antes de tocar el catálogo
        cmp eax, 1
        je reemplazar

    archivoMalo: ;Función cuando el archivo no es válido
        MostrarMensaje msgArchivoMal ; El catálogo actual no se modifica
        jmp finCargar

    reemplazar:
        mov eax, tmpTotal
        mov totalProd, eax ; El total del archivo pasa a ser el total del catálogo
        mov esi, 0 ; ESI es el índice del byte que se copia
        mov ecx, 440 ; Se copian los 440 bytes del catálogo

    copiar:
        mov al, tabla[esi+440] ; Byte de la zona temporal
        mov tabla[esi], al ; Se escribe en el catálogo
        inc esi
        loop copiar

        mov cambios, 0 ; El catálogo coincide con el archivo
        MostrarMensaje msgOk
        jmp finCargar

    errorLectura: ;Función cuando falla la lectura
        mov eax, archivoHandle
        call CloseFile ; Se cierra el archivo para no bloquear la memoria
        MostrarMensaje msgErrLectura

    finCargar:
        ret

Cargar ENDP

END main
