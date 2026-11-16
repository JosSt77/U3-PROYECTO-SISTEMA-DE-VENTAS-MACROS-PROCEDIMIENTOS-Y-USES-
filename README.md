# Lenguajes de Interfaz - Unidad 3

## Datos Generales

* **Materia:** Lenguajes de Interfaz
* **Alumno:** Sotelo Izaguirre José Ángel
* **Horario:** 10-11
* **Docente:** Dr. José Luis Medina Jiménez
* **Proyecto:** Ventas e inventario en ensamblador (librería en línea) con macros, procedimientos y USES

## Descripción

Esta versión retoma el sistema de ventas e inventario de la Unidad 2 (MASM x86 de 32 bits con Irvine32) y mejora su legibilidad y reduce el código repetido. Conserva las funciones, las validaciones y la regla de negocio del proyecto original: con 5 o más ejemplares en una venta se descuenta el 10% del importe base.

## Cambios de la Unidad 3

* **Macros:** sustituyen secuencias cortas repetidas, por ejemplo `MostrarMensaje`, `SaltarSiFalla`, `SaltarSiFueraDeRango`, `EtiquetaImporte` y `EtiquetaNumero`. `AvisarSiFalla` y `ValidarNoCero` se declaran con `LOCAL` porque llevan una etiqueta interna y se usan en varios puntos.
* **Procedimientos nuevos:** `AcumularDigito`, `CalcularImporte`, `BuscarEnCatalogo`, `PedirNombre` y `PedirPrecio`. Cada procedimiento documenta qué recibe, qué devuelve y qué registros modifica o conserva.
* **USES:** 33 de los 34 procedimientos lo aplican en lugar de `push` y `pop` manuales, dejando fuera los registros que entregan resultados.
* **Líneas de código:** de 1120 a 899 (221 menos, cerca de 20%), contando con el mismo criterio en ambas versiones las líneas que no están vacías ni son solo comentario.

## Índice del Proyecto

1. [Proyecto de Visual Studio con código .asm](https://github.com/JosSt77/U3-PROYECTO-SISTEMA-DE-VENTAS-MACROS-PROCEDIMIENTOS-Y-USES-/blob/main/ProyectoEnsambladorU3/ProyectoEnsambladorU3/main.asm)
   * [1.1 Instrucciones de compilación](https://github.com/JosSt77/Proyecto-de-ventas-e-inventario-en-ensamblador/blob/main/ProyectoEnsambladorU3/ProyectoEnsambladorU3/Instrucciones%20de%20Compilaci%C3%B3n.md)
2. [Archivo de inventario con al menos tres productos de prueba](https://github.com/JosSt77/U3-PROYECTO-SISTEMA-DE-VENTAS-MACROS-PROCEDIMIENTOS-Y-USES-/blob/main/Inventario.txt)
3. [Reporte](https://github.com/JosSt77/U3-PROYECTO-SISTEMA-DE-VENTAS-MACROS-PROCEDIMIENTOS-Y-USES-/blob/main/ReporteProyectoEsambladorUnidad3.pdf)
4. [Tabla de pruebas](https://github.com/JosSt77/U3-PROYECTO-SISTEMA-DE-VENTAS-MACROS-PROCEDIMIENTOS-Y-USES-/blob/main/Tabla%20de%20Pruebas%20-%20Proyecto%20ensamblador%20Unidad%203.pdf)

## Versión anterior

* [Unidad 2](https://github.com/JosSt77/Proyecto-de-ventas-e-inventario-en-ensamblador)
