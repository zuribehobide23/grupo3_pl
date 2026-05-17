:- use_module('wheel_windows.pl',
        [
            spin_wheel/3
        ]
    ).

:- encoding(utf8).

% =========================================================================
% CONFIGURACIONES Y ATRIBUTOS DINÁMICOS COMPARTIDOS
% =========================================================================
:- dynamic
    opcion/2,                   % Almacena: opcion(Apartado, Valor) 
    juego_iniciado/0,           % Indica si la partida formal ha comenzado
    jugador/2,                  % jugador(Color, Nombre)
    turno/1,                    % turno(Color)
    panel_actual/4,             % panel_actual(Tipo, Pista, FraseOriginal, LetrasDescubiertas)
    panel/2,                    % panel(Pista, Frase) cargados de fichero
    paneles_cargados/0,         % Flag para saber si se leyeron los txt
    premios_acumulados/2,       % premios_acumulados(Color, Cantidad)
    premios_provisionales/2,    % premios_provisionales(Color, Cantidad)
    gajos_acumulados/2,         % gajos_acumulados(Color, ListaGajos)
    ultimo_giro/1,              % Almacena el resultado del último spin_wheel
    historial_concursante/5,    % historial_concursante(Nombre, NumJuegos, NumFinales, PremioMax, PremioTotal)
    bote_actual/1,              % Bote acumulado en el panel de tipo bote
    panel_n/1,                  % Contador del número de panel actual en la partida
    intentos_final/1,           % Contador de intentos restantes en el Panel Final (máx 3)
    doble_letra_activa/0.       % Bandera que indica si el jugador disfruta del efecto Doble Letra

% =========================================================================
% A) CONFIGURACIÓN (PREDICADOS REQUERIDOS)
% =========================================================================

% Inicializa las opciones con valores por defecto de forma segura
init_opciones :-
    (retractall(opcion(_,_)), !; true),
    assertz(opcion(numero_paneles, 3)),
    assertz(opcion(modo_juego, manual)),
    assertz(opcion(fichero_historial, 'historial_concursantes.txt')).




configurar(Apartado, Valor) :-
    var(Apartado), !, 
    throw('Error. El apartado no puede ser una variable.').
configurar(numero_paneles, Valor) :-
    integer(Valor), Valor > 0, !,
    retractall(opcion(numero_paneles, _)),
    assertz(opcion(numero_paneles, Valor)).
configurar(modo_juego, Valor) :-
    member(Valor, [manual, automatico]), !,
    retractall(opcion(modo_juego, _)),
    assertz(opcion(modo_juego, Valor)).
configurar(fichero_historial, Valor) :-
    atom(Valor), !,
    retractall(opcion(fichero_historial, _)),
    assertz(opcion(fichero_historial, Valor)).
configurar(Apartado, Valor) :-
    write('Error. Valor '), write(Valor), write(' no valido para el apartado '), write(Apartado), writeln('.'),
    fail.

obtener_configuracion(Apartado, Valor) :-
    opcion(Apartado, Valor), !.
obtener_configuracion(Apartado, _) :-
    write('Error. El apartado '), write(Apartado), writeln(' no existe.'), fail.

% =========================================================================
% B) GESTIÓN DE JUGADORES Y TURNOS
% =========================================================================

registrar_concursante(Color, Nombre) :-
    juego_iniciado, !,
    throw('Error. No se pueden registrar concursantes con un juego ya iniciado.').
registrar_concursante(Color, Nombre) :-
    (\+ member(Color, [rojo, verde, azul])), !,
    throw('Error. El color del concursante debe ser rojo, verde o azul.').
registrar_concursante(Color, Nombre) :-
    (var(Nombre); \+ atom(Nombre)), !,
    throw('Error. El nombre del concursante debe ser un atomo valido.').
registrar_concursante(Color, Nombre) :-
    retractall(jugador(Color, _)),
    assertz(jugador(Color, Nombre)),
    write('Concursante '), write(Nombre), write(' registrado con el color '), write(Color), writeln('.').

% Cambia el turno respetando la disponibilidad de los jugadores en la partida
siguiente_turno :-
    retract(turno(ColorActual)), !,
    siguiente_color(ColorActual, SiguienteColor),
    buscar_siguiente_valido(SiguienteColor, ColorFinal),
    assertz(turno(ColorFinal)),
    jugador(ColorFinal, Nombre),
    write('Es el turno de: '), write(Nombre), write(' ('), write(ColorFinal), writeln(')').
siguiente_turno :-
    buscar_siguiente_valido(rojo, ColorFinal),
    assertz(turno(ColorFinal)),
    jugador(ColorFinal, Nombre),
    write('Turno inicial asignado a: '), write(Nombre), write(' ('), write(ColorFinal), writeln(')').

siguiente_color(rojo, verde).
siguiente_color(verde, azul).
siguiente_color(azul, rojo).

buscar_siguiente_valido(Color, Color) :- jugador(Color, _), !.
buscar_siguiente_valido(Color, ColorFinal) :-
    siguiente_color(Color, Siguiente),
    buscar_siguiente_valido(Siguiente, ColorFinal).

% =========================================================================
% C) BANCO DE PANELES (CARGA DE FICHEROS)
% =========================================================================

cargar_paneles :-
    retractall(panel(_, _)),
    (cargar_fichero_txt('Paneles/paneles_generales.txt') -> true ; true),
    (cargar_fichero_txt('Paneles/paneles_tematicos.txt') -> true ; true),
    retractall(paneles_cargados),
    assertz(paneles_cargados),
    writeln('Banco de paneles cargado con exito.').

cargar_fichero_txt(Ruta) :-
    exists_file(Ruta), !,
    open(Ruta, read, Stream, [encoding(utf8)]),
    read_line_to_string(Stream, Linea),
    leer_lineas_paneles(Stream, Linea),
    close(Stream).
cargar_fichero_txt(Ruta) :-
    write('Advertencia: El archivo '), write(Ruta), writeln(' no existe o no se puede leer.'), fail.

leer_lineas_paneles(_, end_of_file) :- !.
leer_lineas_paneles(Stream, Linea) :-
    sub_string(Linea, 0, 7, _, "PISTA: "), !,
    sub_string(Linea, 7, _, 0, PistaConEspacios),
    split_string(PistaConEspacios, "", " \t\r\n", [Pista]),
    read_line_to_string(Stream, LineaFrase),
    ( sub_string(LineaFrase, 0, 7, _, "FRASE: ") ->
        sub_string(LineaFrase, 7, _, 0, FraseConEspacios),
        split_string(FraseConEspacios, "", " \t\r\n", [Frase]),
        atom_string(PistaAtom, Pista),
        atom_string(FraseAtom, Frase),
        assertz(panel(PistaAtom, FraseAtom))
    ;   true
    ),
    read_line_to_string(Stream, LineaSiguiente),
    leer_lineas_paneles(Stream, LineaSiguiente).
leer_lineas_paneles(Stream, _) :-
    read_line_to_string(Stream, SiguienteLinea),
    leer_lineas_paneles(Stream, SiguienteLinea).

% Control central de flujo de selección de paneles de la partida
seleccionar_panel :-
    \+ paneles_cargados, !, throw('Error. No hay paneles cargados. Ejecuta cargar_paneles primero.').
seleccionar_panel :-
    panel_n(N), obtener_configuracion(numero_paneles, MaxNormales),
    N > MaxNormales, N =:= MaxNormales + 1, !,
    preparar_panel_bote.
seleccionar_panel :-
    panel_n(N), obtener_configuracion(numero_paneles, MaxNormales),
    N =:= MaxNormales + 2, !,
    preparar_panel_final.
seleccionar_panel :-
    findall(panel(P, F), panel(P, F), Lista),
    (Lista == [] -> throw('Error. Banco de paneles vacio.') ; true),
    random_member(panel(PistaElegida, FraseElegida), Lista),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(normal, PistaElegida, FraseElegida, [])),
    write('Panel Normal seleccionado. Pista: '), writeln(PistaElegida).

preparar_panel_bote :-
    findall(panel(P, F), panel(P, F), Lista),
    random_member(panel(PistaElegida, FraseElegida), Lista),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(bote, PistaElegida, FraseElegida, [])),
    retractall(bote_actual(_)),
    assertz(bote_actual(1000)),
    write('¡PANEL CON BOTE! Inicializado con 1000€. Pista: '), writeln(PistaElegida).

preparar_panel_final :-
    retractall(panel_actual(_, _, _, _)),
    obtener_ganador_acumulado(Ganador),
    retractall(turno(_)),
    assertz(turno(Ganador)),
    jugador(Ganador, Nombre),
    retractall(intentos_final(_)),
    assertz(intentos_final(3)),
    write('¡PANEL FINAL! Solo participa el concursante con mas ganancias: '), write(Nombre), write(' ('), write(Ganador), writeln(')'),
    writeln('Esperando inicializacion de frase final via panel_final_inicial/1...').

panel_final_inicial(Frase) :-
    juego_iniciado,
    panel_n(N), obtener_configuracion(numero_paneles, MaxNormales),
    N =:= MaxNormales + 2, !,
    atom(Frase),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(final, 'Tematica Final', Frase, [])),
    write('Frase del Panel Final configurada con exito. Largo: '), atom_length(Frase, Len), write(Len), writeln(' caracteres.').
panel_final_inicial(_) :-
    throw('Error. No se puede inicializar el panel final en este momento de la partida.').

obtener_ganador_acumulado(Ganador) :-
    findall(Premio-Col, premios_acumulados(Col, Premio), Lista),
    (Lista == [] -> buscar_siguiente_valido(rojo, Ganador) ; keysort(Lista, Ordenado), reverse(Ordenado, [_-Ganador|_])).

% =========================================================================
% D) DINÁMICA DEL JUEGO (MECÁNICAS CORE)
% =========================================================================

comenzar_juego :-
    juego_iniciado, !, throw('Error. Ya existe una partida en curso.').
comenzar_juego :-
    findall(C, jugador(C, _), L), length(L, Cant), Cant < 1, !,
    throw('Error. No hay suficientes concursantes registrados para iniciar el juego.').
comenzar_juego :-
    assertz(juego_iniciado),
    retractall(panel_n(_)), assertz(panel_n(1)),
    retractall(premios_acumulados(_, _)), retractall(premios_provisionales(_, _)), retractall(gajos_acumulados(_, _)),
    forall(jugador(Col, _), (
        assertz(premios_acumulados(Col, 0)),
        assertz(premios_provisionales(Col, 0)),
        assertz(gajos_acumulados(Col, []))
    )),
    retractall(turno(_)),
    siguiente_turno,
    seleccionar_panel.

lanzar_ruleta :-
    \+ juego_iniciado, !, throw('Error. No hay ninguna partida iniciada.').
lanzar_ruleta :-
    panel_actual(final, _, _, _), !,
    throw('Error. En el Panel Final no se lanza la ruleta de manera estandar.').
lanzar_ruleta :-
    turno(Color),
    panel_actual(Tipo, _, _, _),
    (Tipo == bote -> TipoRueda = jackpot ; TipoRueda = standard),
    spin_wheel(TipoRueda, _, Wedge),
    retractall(ultimo_giro(_)),
    assertz(ultimo_giro(Wedge)),
    procesar_gajo(Color, Wedge).

procesar_gajo(Color, cash(Cantidad)) :- !,
    write('La ruleta se detiene en una casilla de dinero: '), write(Cantidad), writeln('€.').
procesar_gajo(Color, special(bankrupt)) :- !,
    writeln('¡QUIEBRA! Pierdes todo tu dinero provisional y tus gajos acumulados de este panel.'),
    retractall(premios_provisionales(Color, _)),
    assertz(premios_provisionales(Color, 0)),
    retractall(gajos_acumulados(Color, _)),
    assertz(gajos_acumulados(Color, [])),
    siguiente_turno.
procesar_gajo(Color, special(loose_a_turn)) :- !,
    writeln('¡PIERDE EL TURNO! Mala suerte, pasa el turno al siguiente concursante.'),
    siguiente_turno.
procesar_gajo(Color, special(jackpot)) :- !,
    bote_actual(B),
    write('¡CASILLA DE BOTE! Si aciertas una consonante, podras optar a resolver sumando los '), write(B), writeln('€.').
procesar_gajo(Color, Gajo) :-
    write('Has caido en el gajo especial: '), write(Gajo), writeln('. Se añade a tu inventario provisional.'),
    gajos_acumulados(Color, Lista),
    retractall(gajos_acumulados(Color, _)),
    assertz(gajos_acumulados(Color, [Gajo|Lista])).

elegir_consonante(Letra) :-
    \+ juego_iniciado, !, throw('Error. El juego no esta iniciado.').
elegir_consonante(Letra) :-
    \+ ultimo_giro(_), \+ doble_letra_activa, !, 
    throw('Error. Debes lanzar la ruleta antes de elegir una consonante.').
elegir_consonante(Letra) :-
    member(Letra, [a,e,i,o,u,'A','E','I','O','U']), !,
    throw('Error. No puedes elegir una vocal llamando a elegir_consonante.').
elegir_consonante(Letra) :-
    turno(Color),
    panel_actual(Tipo, Pista, Frase, Descubiertas),
    member(Letra, Descubiertas), !,
    writeln('Esa letra ya ha sido descubierta previamente. Pierdes el turno.'),
    retractall(ultimo_giro(_)), retractall(doble_letra_activa),
    siguiente_turno.
elegir_consonante(Letra) :-
    turno(Color),
    panel_actual(Tipo, Pista, Frase, Descubiertas),
    contar_coincidencias(Letra, Frase, Coincidencias),
    ( Coincidencias > 0 ->
        write('¡Acierto! La letra '), write(Letra), write(' aparece '), write(Coincidencias), writeln(' veces.'),
        retractall(panel_actual(_, _, _, _)),
        assertz(panel_actual(Tipo, Pista, Frase, [Letra|Descubiertas])),
        aplicar_recompensa_consonante(Color, Tipo, Coincidencias),
        ( retract(doble_letra_activa) ->
            writeln('¡Efecto Doble Letra consumido! Elige otra consonante directa.')
        ;   retractall(ultimo_giro(_))
        )
    ;   writeln('La letra no se encuentra en el panel. Cambio de turno.'),
        retractall(ultimo_giro(_)), retractall(doble_letra_activa),
        siguiente_turno
    ).

aplicar_recompensa_consonante(Color, final, _) :- !.
aplicar_recompensa_consonante(Color, bote, Coincidencias) :-
    ultimo_giro(special(jackpot)), !,
    bote_actual(B), NuevoBote is B + (50 * Coincidencias),
    retractall(bote_actual(_)), assertz(bote_actual(NuevoBote)),
    write('El bote del panel asciende ahora a: '), write(NuevoBote), writeln('€.').
aplicar_recompensa_consonante(Color, _, Coincidencias) :-
    ultimo_giro(cash(Valor)), !,
    premios_provisionales(Color, Actual),
    Nuevo is Actual + (Valor * Coincidencias),
    retractall(premios_provisionales(Color, _)),
    assertz(premios_provisionales(Color, Nuevo)),
    write('Sumas '), write(Nuevo), writeln('€ a tu saldo provisional de este panel.').
aplicar_recompensa_consonante(Color, _, Coincidencias) :-
    premios_provisionales(Color, Actual),
    Nuevo is Actual + (50 * Coincidencias),
    retractall(premios_provisionales(Color, _)),
    assertz(premios_provisionales(Color, Nuevo)).

comprar_vocal(Letra) :-
    \+ juego_iniciado, !, throw('Error. El juego no esta iniciado.').
comprar_vocal(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. En el Panel Final no se pueden comprar vocales de manera convencional.').
comprar_vocal(Letra) :-
    \+ member(Letra, [a,e,i,o,u,'A','E','I','O','U']), !,
    throw('Error. La letra elegida debe ser obligatoriamente una vocal.').
comprar_vocal(Letra) :-
    turno(Color),
    premios_provisionales(Color, Saldo), Saldo < 50, !,
    throw('Error. No dispones de suficientes fondos provisionales (50€) para comprar una vocal.').
comprar_vocal(Letra) :-
    turno(Color),
    panel_actual(Tipo, Pista, Frase, Descubiertas),
    member(Letra, Descubiertas), !,
    writeln('Vocal ya descubierta. Pierdes los 50€ igualmente y el turno pasa al siguiente.'),
    premios_provisionales(Color, Actual), N is Actual - 50,
    retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, N)),
    retractall(ultimo_giro(_)), siguiente_turno.
comprar_vocal(Letra) :-
    turno(Color),
    premios_provisionales(Color, Actual), NuevoSaldo is Actual - 50,
    retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoSaldo)),
    panel_actual(Tipo, Pista, Frase, Descubiertas),
    contar_coincidencias(Letra, Frase, Coincidencias),
    ( Coincidencias > 0 ->
        write('¡Acierto! La vocal aparece '), write(Coincidencias), writeln(' veces.'),
        retractall(panel_actual(_, _, _, _)),
        assertz(panel_actual(Tipo, Pista, Frase, [Letra|Descubiertas])),
        retractall(ultimo_giro(_))
    ;   writeln('La vocal no esta en la frase. Pierdes el turno.'),
        retractall(ultimo_giro(_)),
        siguiente_turno
    ).

% =========================================================================
% E) REGLAS Y USO DE GAJOS ESPECIALES
% =========================================================================

usar_gajo(special(take_it)) :-
    turno(Color), gajos_acumulados(Color, L), member(special(take_it), L), !,
    writeln('Activando gajo ME LO QUEDO. ¿A que concursante deseas robar? (rojo/verde/azul): '),
    ( obtener_configuracion(modo_juego, manual) -> read(Victima) ; decidir_victima_automatica(Color, Victima) ),
    ejecutar_robo(Color, Victima),
    eliminar_un_gajo(special(take_it), L, NuevaLista),
    retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevaLista)).
usar_gajo(special(double_letter)) :-
    turno(Color), gajos_acumulados(Color, L), member(special(double_letter), L), !,
    writeln('¡Gajo DOBLE LETRA activado con exito! Podras pedir dos consonantes en este turno.'),
    assertz(doble_letra_activa),
    eliminar_un_gajo(special(double_letter), L, NuevaLista),
    retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevaLista)).
usar_gajo(Gajo) :-
    write('No posees el gajo '), write(Gajo), writeln(' o no es valido para activacion manual.'), fail.

ejecutar_robo(Color, Victima) :-
    Color == Victima, !, writeln('No puedes robarte a ti mismo. Se pierde el efecto del gajo.').
ejecutar_robo(Color, Victima) :-
    jugador(Victima, _), !,
    premios_provisionales(Victima, Cash), gajos_acumulados(Victima, GajosV),
    premios_provisionales(Color, CashPropio), gajos_acumulados(Color, GajosP),
    NuevoCash is CashPropio + Cash,
    append(GajosV, GajosP, NuevosGajos),
    retractall(premios_provisionales(Victima, _)), assertz(premios_provisionales(Victima, 0)),
    retractall(gajos_acumulados(Victima, _)), assertz(gajos_acumulados(Victima, [])),
    retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoCash)),
    retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevosGajos)),
    write('¡Robo ejecutado! Has absorbido '), write(Cash), write('€ y todos los gajos del jugador '), write(Victima), writeln('.').
ejecutar_robo(_, _) :- writeln('Concursante objetivo no valido. Operacion cancelada.').

decidir_victima_automatica(Color, Victima) :-
    siguiente_color(Color, Victima), jugador(Victima, _), !.
decidir_victima_automatica(Color, Victima) :-
    siguiente_color(Color, Aux), siguiente_color(Aux, Victima).

eliminar_un_gajo(_, [], []) :- !.
eliminar_un_gajo(G, [G|T], T) :- !.
eliminar_un_gajo(G, [H|T], [H|R]) :- eliminar_un_gajo(G, T, R).

% =========================================================================
% F) RESOLUCIÓN DE PANELES E HISTORIAL
% =========================================================================

resolver_panel(Propuesta) :-
    \+ juego_iniciado, !, throw('Error. No hay ninguna partida en curso.').
resolver_panel(Propuesta) :-
    turno(Color),
    panel_actual(Tipo, Pista, Frase, Descubiertas),
    ( Propuesta == Frase ->
        write('¡EXCELENTE! Has resuelto el panel correctamente: "'), write(Frase), writeln('"'),
        consolidar_premios(Color, Tipo),
        avanzar_flujo_paneles
    ;   writeln('Respuesta incorrecta.'),
        procesar_fallo_resolucion(Tipo)
    ).

procesar_fallo_resolucion(final) :- !,
    intentos_final(I), NuevoI is I - 1,
    retractall(intentos_final(_)), assertz(intentos_final(NuevoI)),
    write('Te quedan '), write(NuevoI), writeln(' intentos para resolver el Panel Final.'),
    ( NuevoI <= 0 ->
        writeln('¡Se agotaron los intentos en el Panel Final! Fin de la partida.'),
        finalizar_partida_formal
    ;   true
    ).
procesar_fallo_resolucion(_) :-
    retractall(ultimo_giro(_)),
    siguiente_turno.

consolidar_premios(Color, final) :- !,
    random_between(2, 8, Multiplicador),
    PremioFinal is Multiplicador * 1000,
    premios_acumulados(Color, Actual),
    Nuevo is Actual + PremioFinal,
    retractall(premios_acumulados(Color, _)), assertz(premios_acumulados(Color, Nuevo)),
    write('¡Victoria en el Panel Final! Te llevas un premio extraordinario de '), write(PremioFinal), writeln('€.').
consolidar_premios(Color, Tipo) :-
    premios_provisionales(Color, Prov),
    premios_acumulados(Color, Acum),
    gajos_acumulados(Color, Gajos),
    calcular_bonus_gajos(Gajos, Bonus, GajosLimpios),
    ( Tipo == bote -> bote_actual(BoteTotal) ; BoteTotal = 0 ),
    SumaTotal is Prov + Bonus + BoteTotal,
    NuevoAcum is Acum + SumaTotal,
    retractall(premios_acumulados(Color, _)), assertz(premios_acumulados(Color, NuevoAcum)),
    write('Ganancias consolidadas en este panel para el jugador: '), write(SumaTotal), write('€ (Prov: '), write(Prov), write(', Bonus Gajos: '), write(Bonus), write(', Bote: '), write(BoteTotal), writeln(').'),
    retractall(premios_provisionales(_, _)),
    retractall(gajos_acumulados(_, _)),
    retractall(bote_actual(_)),
    forall(jugador(Col, _), (assertz(premios_provisionales(Col, 0)), assertz(gajos_acumulados(Col, [])))).

calcular_bonus_gajos(L, Bonus, NuevaL) :-
    member(special(grand_prize_1), L), member(special(grand_prize_2), L), !,
    Bonus = 600,
    eliminar_un_gajo(special(grand_prize_1), L, L1),
    eliminar_un_gajo(special(grand_prize_2), L1, NuevaL).
calcular_bonus_gajos(L, Bonus, NuevaL) :-
    member(special(prize), L), !,
    Bonus = 300,
    eliminar_un_gajo(special(prize), L, NuevaL).
calcular_bonus_gajos(L, 0, L).

avanzar_flujo_paneles :-
    panel_n(N),
    NuevoN is N + 1,
    retractall(panel_n(_)), assertz(panel_n(NuevoN)),
    obtener_configuracion(numero_paneles, MaxNormales),
    ( NuevoN > MaxNormales + 2 ->
        writeln('¡Felicidades a todos! La partida reglamentaria ha concluido.'),
        finalizar_partida_formal
    ;   seleccionar_panel
    ).

finalizar_partida_formal :-
    guardar_historial,
    retractall(juego_iniciado),
    writeln('Partida finalizada. Historial actualizado de forma persistente.').

% =========================================================================
% G) PERSISTENCIA E HISTORIAL (ENTRADA/SALIDA - TEMA 5)
% =========================================================================

cargar_historial :-
    retractall(historial_concursante(_, _, _, _, _)),
    obtener_configuracion(fichero_historial, File),
    ( exists_file(File) ->
        open(File, read, Stream, [encoding(utf8)]),
        read_line_to_string(Stream, Linea),
        procesar_lineas_historial(Stream, Linea),
        close(Stream)
    ;   true
    ).

procesar_lineas_historial(_, end_of_file) :- !.
procesar_lineas_historial(Stream, Linea) :-
    split_string(Linea, ";", "", [NomS, NJuegosS, NFinalesS, PMaxS, PTotalS]), !,
    atom_string(Nom, NomS),
    number_string(NJuegos, NJuegosS),
    number_string(NFinales, NFinalesS),
    number_string(PMax, PMaxS),
    number_string(PTotal, PTotalS),
    assertz(historial_concursante(Nom, NJuegos, NFinales, PMax, PTotal)),
    read_line_to_string(Stream, Siguiente),
    procesar_lineas_historial(Stream, Siguiente).
procesar_lineas_historial(Stream, _) :-
    read_line_to_string(Stream, Siguiente),
    procesar_lineas_historial(Stream, Siguiente).

guardar_historial :-
    cargar_historial,
    forall(jugador(Color, Nombre), (
        premios_acumulados(Color, PremioPartida),
        panel_n(N), obtener_configuracion(numero_paneles, Max),
        (N >= Max + 2 -> FueFinal = 1 ; FueFinal = 0),
        actualizar_registro_memoria(Nombre, PremioPartida, FueFinal)
    )),
    obtener_configuracion(fichero_historial, File),
    open(File, write, Stream, [encoding(utf8)]),
    forall(historial_concursante(Nom, NJ, NF, PMax, PTot), (
        write(Stream, Nom), write(Stream, ';'),
        write(Stream, NJ), write(Stream, ';'),
        write(Stream, NF), write(Stream, ';'),
        write(Stream, PMax), write(Stream, ';'),
        write(Stream, PTot), nl(Stream)
    )),
    close(Stream).

actualizar_registro_memoria(Nombre, PremioPartida, FueFinal) :-
    retract(historial_concursante(Nombre, NJ, NF, PMax, PTot)), !,
    NuevoNJ is NJ + 1,
    NuevoNF is NF + FueFinal,
    (PremioPartida > PMax -> NuevoPMax = PremioPartida ; NuevoPMax = PMax),
    NuevoPTot is PTot + PremioPartida,
    assertz(historial_concursante(Nombre, NuevoNJ, NuevoNF, NuevoPMax, NuevoPTot)).
actualizar_registro_memoria(Nombre, PremioPartida, FueFinal) :-
    assertz(historial_concursante(Nombre, 1, FueFinal, PremioPartida, PremioPartida)).

% =========================================================================
% H) MODO AUTOMÁTICO (REQUISITOS DEL RETO)
% =========================================================================

aparece_consonante(Letra) :-
    panel_actual(_, _, Frase, Descubiertas),
    atom_chars(Frase, Chars),
    member(Letra, Chars),
    \% Filtrar consonantes válidas puras
    \+ member(Letra, [a,e,i,o,u,'A','E','I','O','U',' ']),
    \+ member(Letra, Descubiertas), !.

aparece_vocal(Letra) :-
    panel_actual(_, _, Frase, Descubiertas),
    atom_chars(Frase, Chars),
    member(Letra, Chars),
    member(Letra, [a,e,i,o,u,'A','E','I','O','U']),
    \+ member(Letra, Descubiertas), !.

resolver_auto(Frase) :-
    panel_actual(_, _, Frase, _).

% =========================================================================
% UTILS Y AUXILIARES (RECURSIVIDAD COMPATIBLE)
% =========================================================================

contar_coincidencias(_, '', 0) :- !.
contar_coincidencias(Letra, Frase, Total) :-
    atom_chars(Frase, ListaChars),
    contar_recursivo(Letra, ListaChars, Total).

contar_recursivo(_, [], 0) :- !.
contar_recursivo(L, [H|T], N) :-
    char_equal_insensitive(L, H), !,
    contar_recursivo(L, T, Sub),
    N is Sub + 1.
contar_recursivo(L, [_|T], N) :-
    contar_recursivo(L, T, N).

char_equal_insensitive(C1, C2) :-
    downcase_atom(C1, A),
    downcase_atom(C2, A).

:- init_opciones.