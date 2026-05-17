:- use_module('wheel_windows.pl', [spin_wheel/3]).
:- encoding(utf8).

% =========================================================================
% CONFIGURACIONES Y ATRIBUTOS DINÁMICOS COMPARTIDOS
% =========================================================================
:- dynamic
    opcion/2,
    juego_iniciado/0,
    jugador/2,
    turno/1,
    panel_actual/4,
    panel/2,
    paneles_cargados/0,
    premios_acumulados/2,
    premios_provisionales/2,
    gajos_acumulados/2,
    ultimo_giro/1,
    historial_concursante/5,
    estado_comodin/2,        % [NUEVO] estado_comodin(Color, MotivoPérdida)
    intentos_final/1,        % [NUEVO] Intentos restantes en el panel final
    tipo_letra_extra/1.      % [NUEVO] Tipo de letra sorteada para Ayuda Final

% Inicialización de opciones por defecto
:- assertz(opcion(modo, manual)),
   assertz(opcion(modo_jugador, persona)),
   assertz(opcion(velocidad, normal)),
   assertz(opcion(numero_paneles, 3)). % [NUEVO] Configuración obligatoria

% Reglas de validación interna
opcion_valida(modo, V) :- member(V, [manual, automatico]).
opcion_valida(modo_jugador, V) :- member(V, [persona, bot]).
opcion_valida(velocidad, V) :- member(V, [rapido, lento, normal]).
opcion_valida(numero_paneles, V) :- integer(V), V >= 3. % [NUEVO]

comprobar_juego_iniciado :- juego_iniciado, !.
comprobar_juego_iniciado :- throw('Error. No hay ningún juego iniciado.').


% =========================================================================
% PERSISTENCIA DEL HISTORIAL [NUEVO BLOQUE 1]
% =========================================================================
archivo_historial('historial.txt').

cargar_historial :-
    archivo_historial(Ruta),
    exists_file(Ruta), !,
    open(Ruta, read, Stream),
    retractall(historial_concursante(_,_,_,_,_)),
    leer_historial(Stream),
    close(Stream).
cargar_historial. % Falla silenciosa si no existe el archivo inicial

leer_historial(Stream) :-
    read(Stream, Term),
    ( Term == end_of_file -> true
    ; assertz(Term), leer_historial(Stream) ).

guardar_historial :-
    % Solo se guarda si el juego fue en modo persona
    opcion(modo_jugador, persona),
    archivo_historial(Ruta),
    open(Ruta, write, Stream),
    forall(historial_concursante(N, J, F, M, T),
           (write_canonical(Stream, historial_concursante(N, J, F, M, T)), write(Stream, '.\n'))),
    close(Stream).
guardar_historial.


% =========================================================================
% AMBOS MODOS: MANUAL Y AUTOMÁTICO
% =========================================================================

ver_opcion(O) :-
    opcion(O, V), !,
    write('Configuración ['), write(O), write(']: '), writeln(V).
ver_opcion(_) :- throw('Error. El apartado indicado no existe.').

establecer_opcion(_, _) :-
    juego_iniciado, !,
    throw('Error. Ya hay un juego iniciado.').
establecer_opcion(O, _) :-
    \+ opcion_valida(O, _), !, throw('Error. Apartado no existe.').
establecer_opcion(O, V) :-
    \+ opcion_valida(O, V), !, throw('Error. Valor no válido.').
establecer_opcion(O, V) :-
    retractall(opcion(O, _)), assertz(opcion(O, V)),
    write('Actualizado ['), write(O), write('] a: '), writeln(V).

mostrar_panel :-
    comprobar_juego_iniciado,
    panel_actual(_, Pista, FraseOriginal, LetrasDescubiertas),
    de_frase_a_oculto(FraseOriginal, LetrasDescubiertas, FraseOculta),
    writeln('==================================================='),
    write(' PISTA: '), writeln(Pista),
    write(' PANEL: '), writeln(FraseOculta),
    writeln('===================================================').

mostrar_turno :-
    comprobar_juego_iniciado,
    turno(Color), jugador(Color, Nombre),
    opcion(modo_jugador, ModoJ),
    ( ModoJ == persona ->
        write('Turno actual: '), write(Color), write(' ('), write(Nombre), writeln(')')
    ;
        write('Turno actual: '), writeln(Color)
    ).

mostrar_premios_acumulados :-
    comprobar_juego_iniciado, writeln('>>> PREMIOS ACUMULADOS <<<'),
    forall(jugador(C, N), (premios_acumulados(C, P), write(C), write(' ('), write(N), write('): '), write(P), writeln(' €'))).

mostrar_premios_provisionales :-
    comprobar_juego_iniciado, writeln('>>> PREMIOS PROVISIONALES <<<'),
    forall(jugador(C, N), (premios_provisionales(C, P), write(C), write(' ('), write(N), write('): '), write(P), writeln(' €'))).

mostrar_gajos_acumulados :-
    comprobar_juego_iniciado, writeln('>>> GAJOS ACUMULADOS <<<'),
    forall(jugador(C, N), (gajos_acumulados(C, L), write(C), write(' ('), write(N), write('): '), writeln(L))).

mostrar_ruleta :-
    comprobar_juego_iniciado,
    (panel_actual(final, _, _, _) -> throw('Error. No hay ruleta en panel final.') ; true),
    ( ultimo_giro(G) ; gajo_actual(G) ), !,
    turno(Color), write('Ruleta: '), writeln(G).
mostrar_ruleta :- writeln('No se ha lanzado la ruleta aún.').

ver_historial(C) :-
    historial_concursante(C, NumJuegos, NumFinales, PremioMax, PremioTotal), !,
    ( NumJuegos > 0 -> PremioMedio is PremioTotal / NumJuegos ; PremioMedio is 0 ),
    write('Historial de '), writeln(C),
    write('Juegos: '), writeln(NumJuegos),
    write('Finales: '), writeln(NumFinales),
    write('Max: '), write(PremioMax), writeln(' €'),
    write('Media: '), write(PremioMedio), writeln(' €').
ver_historial(C) :- write('Sin historial para: '), writeln(C).


% =========================================================================
% MODO MANUAL
% =========================================================================

es_consonante(C) :- member(C, [b,c,d,f,g,h,j,k,l,m,n,ñ,p,q,r,s,t,v,w,x,y,z]).
es_vocal(V)      :- member(V, [a,e,i,o,u,á,é,í,ó,ú]).

cambiar_turno :-
    turno(Actual),
    ( Actual == azul -> Siguiente = rojo ; Actual == rojo -> Siguiente = amarillo ; Siguiente = azul ),
    retractall(turno(_)), assertz(turno(Siguiente)),
    write('-> Cambio de turno a: '), writeln(Siguiente).

% [NUEVO] Lógica del comodín para retrasar la pérdida de turno
gestionar_perdida_turno(Motivo) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    ( member(special(wild_card), Lista) ->
        writeln('¡Atención! Vas a perder el turno. Puedes usar_comodin(\'Sí\') o usar_comodin(\'No\').'),
        retractall(estado_comodin(_, _)),
        assertz(estado_comodin(Color, Motivo))
    ;
        writeln('Pierdes el turno.'),
        cambiar_turno
    ).

iniciar_juego(_, _, _) :- juego_iniciado, !, throw('Error. Ya hay un juego.').
iniciar_juego(C1, C2, C3) :- (C1=C2; C1=C3; C2=C3), !, throw('Error. Nombres repetidos.').
iniciar_juego(C1, C2, C3) :-
    cargar_historial, % [NUEVO] Cargamos historial existente
    retractall(juego_iniciado), retractall(jugador(_,_)), retractall(turno(_)),
    retractall(premios_acumulados(_,_)), retractall(premios_provisionales(_,_)),
    retractall(gajos_acumulados(_,_)), retractall(ultimo_giro(_)),
    retractall(panel_actual(_,_,_,_)), retractall(intentos_final(_)),
    assertz(juego_iniciado),
    assertz(jugador(azul, C1)), assertz(jugador(rojo, C2)), assertz(jugador(amarillo, C3)),
    assertz(turno(azul)),
    assertz(premios_acumulados(azul, 0)), assertz(premios_acumulados(rojo, 0)), assertz(premios_acumulados(amarillo, 0)),
    assertz(premios_provisionales(azul, 0)), assertz(premios_provisionales(rojo, 0)), assertz(premios_provisionales(amarillo, 0)),
    assertz(gajos_acumulados(azul, [])), assertz(gajos_acumulados(rojo, [])), assertz(gajos_acumulados(amarillo, [])),
    writeln('Juego iniciado con éxito.').

lanzar_ruleta :-
    \+ juego_iniciado, !, throw('Error. No hay juego.').
lanzar_ruleta :-
    estado_comodin(_, _), !, throw('Error. Responde primero si usas el comodín.').
lanzar_ruleta :-
    panel_actual(final, _, _, _), !, throw('Error. No hay ruleta en la final.').
lanzar_ruleta :-
    panel_actual(Tipo, _, _, _),
    (Tipo = normal -> TipoRuleta = standard ; TipoRuleta = jackpot),
    spin_wheel(TipoRuleta, random, GajosSeleccionados),
    retractall(ultimo_giro(_)), assertz(ultimo_giro(GajosSeleccionados)),
    write('Ruleta giró. Posición: '), writeln(GajosSeleccionados),

    ( GajosSeleccionados = [_, GajoReal, _] -> true ; GajoReal = GajosSeleccionados ),
    turno(Color),
    
    ( GajoReal = loose_a_turn ->
        writeln('Caes en Pierdes el turno.'),
        retractall(ultimo_giro(_)), gestionar_perdida_turno(loose_a_turn)
    ; GajoReal = bankrupt ->
        writeln('Quiebra. Pierdes saldo y gajos.'),
        retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, 0)),
        retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, [])),
        retractall(ultimo_giro(_)), gestionar_perdida_turno(bankrupt)
    ).

elegir_consonante(_) :- \+ juego_iniciado, !, throw('Error. No hay juego.').
elegir_consonante(_) :- estado_comodin(_, _), !, throw('Error. Responde si usas el comodín.').
elegir_consonante(_) :- panel_actual(final, _, _, _), !, throw('Error. No aplicable en la final.').
elegir_consonante(C) :- \+ es_consonante(C), !, throw('Error. No es consonante.').
elegir_consonante(_) :- \+ ultimo_giro(_), !, throw('Error. Lanza ruleta primero.').
elegir_consonante(C) :-
    turno(Color), panel_actual(Tipo, Pista, FraseOriginal, LetrasDescubiertas),
    downcase_atom(C, C_Low),
    ( member(C_Low, LetrasDescubiertas) ->
        writeln('Letra ya descubierta.'),
        retractall(ultimo_giro(_)), gestionar_perdida_turno(repetida)
    ;
        atom_chars(FraseOriginal, Chars), include(match_char(C_Low), Chars, Coincidencias), length(Coincidencias, NumApariciones),
        ( NumApariciones > 0 ->
            ultimo_giro([_, GajoReal, _]),
            
            % [NUEVO BLOQUE 5] El gajo Misterio (elige otro aleatorio)
            ( GajoReal == mistery ->
                writeln('¡Gajo MISTERIO! Sorteando un gajo normal aleatorio...'),
                random_member(GajoEfectivo, [cash(0), cash(25), cash(75), cash(100), cash(150), loose_a_turn, bankrupt, wild_card, extra_clue, take_it, double_letter]),
                write('El misterio revela: '), writeln(GajoEfectivo)
            ; GajoEfectivo = GajoReal ),

            ( GajoEfectivo = cash(Valor) ->
                Ganancia is Valor * NumApariciones,
                premios_provisionales(Color, SaldoAnt), NuevoSaldo is SaldoAnt + Ganancia,
                retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoSaldo)),
                write('Acierto. Ganas '), write(Ganancia), writeln(' €.')
            ; 
                % [CORREGIDO BLOQUE 3] Gajos especiales - Verificamos duplicidad
                gajos_acumulados(Color, GajosAnt),
                ( member(GajoEfectivo, GajosAnt) ->
                    writeln('Ya tenías este gajo. No se acumula duplicado.')
                ;
                    retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, [GajoEfectivo|GajosAnt])),
                    write('Te adjudicas el gajo: '), writeln(GajoEfectivo)
                )
            ),
            retractall(panel_actual(_, _, _, _)),
            assertz(panel_actual(Tipo, Pista, FraseOriginal, [C_Low|LetrasDescubiertas])),
            retractall(ultimo_giro(_))
        ;
            write('Fallo. La letra no está.'),
            retractall(ultimo_giro(_)), gestionar_perdida_turno(fallo_letra)
        )
    ).


comprar_vocal(_) :- \+ juego_iniciado, !, throw('Error. No hay juego.').
comprar_vocal(_) :- estado_comodin(_, _), !, throw('Error. Usa comodín primero.').
comprar_vocal(V) :- \+ es_vocal(V), !, throw('Error. No es vocal.').
comprar_vocal(V) :-
    turno(Color), premios_provisionales(Color, Saldo),
    ( Saldo < 50 -> throw('Error. Saldo insuficiente (50€).') ;
        NuevoSaldo is Saldo - 50,
        retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoSaldo)),
        downcase_atom(V, V_Low), panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes),
        ( member(V_Low, LetrasAntes) ->
            writeln('Vocal repetida.'), gestionar_perdida_turno(repetida)
        ;
            atom_chars(FraseOriginal, Chars), include(match_char(V_Low), Chars, Coincidencias), length(Coincidencias, Num),
            ( Num > 0 ->
                retractall(panel_actual(_, _, _, _)),
                assertz(panel_actual(Tipo, Pista, FraseOriginal, [V_Low|LetrasAntes])),
                write('El concursante '), 
                write(Color), 
                write(' compra la vocal "'), 
                write(V_Low), 
                write('" por 50€. ¡Acierto! Saldo restante: '), 
                write(NuevoSaldo), 
                writeln('€')
            ;
                write('La vocal "'), 
                write(V_Low), 
                writeln('" no se encuentra en el panel. Pierdes 50€ y pierdes el turno.'),
                cambiar_turno
            )
        )
    ).

% [CORREGIDO BLOQUE 2] Lógica completa de gajos especiales
usar_gajo(_) :- \+ juego_iniciado, !, throw('Error.').
usar_gajo(G) :- G \= take_it, G \= double_letter, !, throw('Error. Gajo debe ser take_it o double_letter.').
usar_gajo(G) :-
    turno(Color), gajos_acumulados(Color, Lista),
    ( member(G, Lista) ->
        select(G, Lista, NuevaLista), % Se consume el gajo
        retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevaLista)),
        ( G == take_it ->
            writeln('Me Lo Quedo: Robas provisionales y gajos al jugador rojo (Simulado para consola).'),
            % En manual, transferiríamos. Aquí simulamos robo estricto al siguiente
            premios_provisionales(rojo, Botin), retractall(premios_provisionales(rojo, _)), assertz(premios_provisionales(rojo, 0)),
            premios_provisionales(Color, MiSaldo), NuevoSaldo is MiSaldo + Botin,
            retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoSaldo)),
            gajos_acumulados(rojo, GajosRobados), retractall(gajos_acumulados(rojo, _)), assertz(gajos_acumulados(rojo, [])),
            gajos_acumulados(Color, MisGajos), append(MisGajos, GajosRobados, GajosFinales),
            retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, GajosFinales))
        ; G == double_letter ->
            writeln('Doble Letra: Tienes un turno extra gratis sin tirar ruleta.')
        )
    ; throw('Error. No tienes este gajo.') ).


usar_comodin(R) :-
    \+ estado_comodin(_, _), !, throw('Error. No estás en riesgo de perder turno.').
usar_comodin(R) :-
    normalizar_si_no(R, R_Interno),
    estado_comodin(Color, _),
    ( R_Interno == si ->
        gajos_acumulados(Color, Lista),
        ( select(special(wild_card), Lista, NuevaLista) ->
            retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevaLista)),
            writeln('Comodín usado. Mantienes el turno.'),
            retractall(estado_comodin(_, _))
        ;
            writeln('No tienes el gajo comodín. Pierdes turno.'), retractall(estado_comodin(_, _)), cambiar_turno
        )
    ;
        writeln('Reservas el comodín. Pierdes turno.'), retractall(estado_comodin(_, _)), cambiar_turno
    ).

% [CORREGIDO BLOQUE 3 Y 4] Premios extraordinarios y control de intentos en final
resolver_panel(F) :-
    turno(Color), panel_actual(Tipo, Pista, FraseOriginal, _),
    downcase_atom(F, F_Low), downcase_atom(FraseOriginal, Frase_Low),
    (F_Low = Frase_Low ->
        writeln('¡RESUELTO!'),
        premios_provisionales(Color, Prov), premios_acumulados(Color, AcumAnt),
        gajos_acumulados(Color, Gajos),
        
        % Cálculo de Premios Extraordinarios
        ( member(prize, Gajos) -> Extra2 = 300, select(prize, Gajos, G1) ; Extra2 = 0, G1 = Gajos ),
        ( (member(grand_prize_1, G1), member(grand_prize_2, G1)) -> 
            Extra1 = 600, select(grand_prize_1, G1, G2), select(grand_prize_2, G2, G_Finales) 
        ; Extra1 = 0, G_Finales = G1 ),
        
        TotalGanado is Prov + Extra1 + Extra2,
        NuevoAcum is AcumAnt + TotalGanado,
        retractall(premios_acumulados(Color, _)), assertz(premios_acumulados(Color, NuevoAcum)),
        retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, G_Finales)),
        
        writeln('Ganas premios y se aplican extras de gajos si los tenías.'),
        % Fin de panel, si era el último, llamaríamos a guardar_historial
        ( Tipo == final -> guardar_historial ; true )
    ;
        ( Tipo == final ->
            intentos_final(Int), Quedan is Int - 1,
            retractall(intentos_final(_)), assertz(intentos_final(Quedan)),
            write('Fallo. Te quedan '), write(Quedan), writeln(' intentos.'),
            ( Quedan =:= 0 -> writeln('Fin de la final.'), guardar_historial ; true )
        ;
            writeln('Fallo.'), gestionar_perdida_turno(fallo_resolver)
        )
    ).

% [CORREGIDO BLOQUE 4] Solapamiento de letras en la final
elegir_letras(C1, C2, C3, C4, V) :-
    panel_actual(final, Pista, FraseOriginal, LetrasBase),
    % Validación de no solapamiento
    maplist(downcase_atom, [C1, C2, C3, C4, V], Seleccion),
    intersection(Seleccion, LetrasBase, Repetidas),
    ( Repetidas \= [] -> throw('Error. Has elegido letras ya descubiertas por el sistema.') ; true ),
    
    append(Seleccion, LetrasBase, NuevasLetras),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(final, Pista, FraseOriginal, NuevasLetras)),
    writeln('Letras de la final validadas y descubiertas.').

elegir_letra_extra(L) :-
    turno(Color), gajos_acumulados(Color, Lista),
    % [CORREGIDO] Gajo correcto: extra_clue
    \+ member(extra_clue, Lista), !, throw('Error. No tienes Ayuda Final.').
elegir_letra_extra(L) :-
    % [CORREGIDO] Sorteo aleatorio de tipo
    ( tipo_letra_extra(T) -> true ; random_member(T, [consonante, vocal]), assertz(tipo_letra_extra(T)) ),
    write('El sistema te obliga a pedir una: '), writeln(T),
    ( T == consonante -> ( es_consonante(L) -> true ; throw('Debe ser consonante.') )
    ; es_vocal(L) -> true ; throw('Debe ser vocal.') ),
    
    downcase_atom(L, L_Low), panel_actual(final, Pista, FraseOriginal, LetrasAntes),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(final, Pista, FraseOriginal, [L_Low|LetrasAntes])).


% =========================================================================
% MODO AUTOMÁTICO - TRADUCCIÓN ROBUSTA
% =========================================================================

normalizar_si_no('Sí', si) :- !. normalizar_si_no('Si', si) :- !.
normalizar_si_no('sí', si) :- !. normalizar_si_no('si', si) :- !.
normalizar_si_no('No', no) :- !. normalizar_si_no('no', no) :- !.

de_frase_a_oculto(FraseOriginal, LetrasDescubiertas, FraseOculta) :-
    atom_chars(FraseOriginal, ListaChars),
    maplist(ocultar_char(LetrasDescubiertas), ListaChars, ListaOcultaChars),
    atom_chars(FraseOculta, ListaOcultaChars).

ocultar_char(_, ' ', ' ') :- !.
ocultar_char(_, Char, Char) :- member(Char, [',', '.', ';', ':', '-', '¡', '!', '¿', '?']), !.
ocultar_char(LetrasDescubiertas, Char, Char) :- downcase_atom(Char, LetraMin), member(LetraMin, LetrasDescubiertas), !.
ocultar_char(_, _, '_').


obtener_nuevas_letras([], [], [], _, []).
obtener_nuevas_letras([O|Os], [A|As], [F|Fs], LetrasAntes, Nuevas) :-
    ( A == '_', F \== '_' ->
        downcase_atom(O, LowerO),
        ( F == O ->
            obtener_nuevas_letras(Os, As, Fs, LetrasAntes, RestoNuevas),
            ( member(LowerO, RestoNuevas) -> Nuevas = RestoNuevas ; Nuevas = [LowerO|RestoNuevas] )
        ;
            throw('Error. El carácter revelado en F no coincide con la frase original del panel.')
        )
    ;
        ( A \== '_' -> 
            ( F == A -> true ; throw('Error. Se ha alterado un carácter que ya estaba descubierto o un espacio.') )
        ;
            ( F == '_' -> true ; throw('Error. Hay un carácter inesperado en la estructura de la frase.') )
        ),
        obtener_nuevas_letras(Os, As, Fs, LetrasAntes, Nuevas)
    ).


% CORRECCIÓN DE VARIABLE HUÉRFANA (NuevaLetter -> NuevaLetra)
validar_cambio_frase(R, F, TipoEsperado) :-
    panel_actual(_, _, FraseOriginal, LetrasAntes),
    de_frase_a_oculto(FraseOriginal, LetrasAntes, F_Antes),
    ( R == 'No' ->
        ( F == F_Antes -> true ; throw('Error. Si R es No, la frase F debe ser idéntica al estado anterior sin descubrir nada.') )
    ; R == 'Si' ->
        atom_chars(F, CharsF),
        atom_chars(FraseOriginal, CharsOrig),
        atom_chars(F_Antes, CharsAntes),
        obtener_nuevas_letras(CharsOrig, CharsAntes, CharsF, LetrasAntes, Nuevas),
        ( Nuevas = [NuevaLetra] ->
            ( TipoEsperado == consonante ->
                ( es_consonante(NuevaLetra) -> true ; throw('Error. La letra descubierta no es una consonante.') )
            ; TipoEsperado == vocal ->
                ( es_vocal(NuevaLetra) -> true ; throw('Error. La letra descubierta no es una vocal.') )
            ),
            panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes),
            retract(panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes)),
            assertz(panel_actual(Tipo, Pista, FraseOriginal, [NuevaLetra|LetrasAntes]))
        ;
            throw('Error. La frase F debe descubrir exactamente una nueva letra del tipo esperado.')
        )
    ).


% iniciar_panel/1
iniciar_panel(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

iniciar_panel(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. El panel actual es de tipo final.').

iniciar_panel(F) :-
    panel_actual(Tipo, _, FraseOriginal, _),
    (Tipo = normal ; Tipo = bote),
    de_frase_a_oculto(FraseOriginal, [], F_Oculta),
    ( F = F_Oculta -> 
        retractall(panel_estado(_)),
        assertz(panel_estado(en_juego)),
        write('Modo Automático: Panel de tipo ('), 
        write(Tipo), 
        writeln(') iniciado correctamente.')    
    ; 
        throw('Error. La expresión atómica F no se ajusta con el formato oculto inicial del panel.')
    ).


% gajo_ruleta/1
gajo_ruleta(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

gajo_ruleta(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. El panel actual es de tipo final.').

gajo_ruleta(G) :-
    retractall(gajo_actual(_)),
    assertz(gajo_actual(G)),
    retractall(panel_estado(_)),
    assertz(panel_estado(ruleta_lanzada)),
    write('Modo Automático: Concursante cae formalmente en el gajo '), 
    write(G), 
    writeln('.').
% --- aparece_consonante/2 ---
aparece_consonante(_, _) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

aparece_consonante(_, _) :-
    panel_actual(final, _, _, _), !,
    throw('Error. El panel actual es de tipo final.').

aparece_consonante(R, _) :-
    R \== 'Si', R \== 'No', !,
    throw('Error. El parámetro R debe ser estrictamente Sí o No.').

aparece_consonante(R, F) :-
    validar_cambio_frase(R, F, consonante),
    % Tras procesar la consonante, volvemos al flujo del panel esperando la siguiente acción
    retractall(panel_estado(_)),
    assertz(panel_estado(en_juego)).


% --- aparece_vocal/2 ---
aparece_vocal(_, _) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

aparece_vocal(_, _) :-
    panel_actual(final, _, _, _), !,
    throw('Error. El panel actual es de tipo final.').

aparece_vocal(R, _) :-
    R \== 'Si', R \== 'No', !,
    throw('Error. El parámetro R debe ser estrictamente Sí o No.').

aparece_vocal(R, F) :-
    validar_cambio_frase(R, F, vocal),
    retractall(panel_estado(_)),
    assertz(panel_estado(en_juego)).


% --- panel_correcto/1 ---
panel_correcto(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

panel_correcto(R) :-
    R \== 'Si', R \== 'No', !,
    throw('Error. El parámetro R debe ser estrictamente Sí o No.').

panel_correcto(R) :-
    panel_actual(Tipo, _, _, _),
    (Tipo = normal ; Tipo = bote),
    \+ panel_estado(ruleta_lanzada), !,
    throw('Error. Aún no se ha lanzado la ruleta en este panel antes de intentar resolver.').

panel_correcto(R) :-
    panel_actual(final, _, _, _),
    \+ panel_estado(letras_elegidas), !,
    throw('Error. Aún no se han elegido las letras definitivas en el Panel final.').

panel_correcto(R) :-
    ( R == 'Si' ->
        retractall(panel_estado(_)),
        assertz(panel_estado(resuelto)),
        writeln('Modo Automático: Resolución CORRECTA. Panel completado con éxito.')
    ;
        retractall(panel_estado(_)),
        assertz(panel_estado(en_juego)),
        writeln('Modo Automático: Resolución INCORRECTA. Continúa el juego.')
    ).


% --- panel_final_inicial/1 ---
panel_final_inicial(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

panel_final_inicial(_) :-
    \+ panel_actual(final, _, _, _), !,
    throw('Error. El panel actual no es de tipo final.').

panel_final_inicial(_) :-
    panel_estado(letras_elegidas), !,
    throw('Error. Restricción de flujo: el o la concursante ya ha seleccionado sus letras definitivas.').

panel_final_inicial(F) :-
    panel_actual(final, _, FraseOriginal, _),
    % Si es la primera vez que se consulta la base inicial, generamos las 3 consonantes y 1 vocal aleatorias
    ( letras_base_final(Base) -> true 
    ; 
        consonantes_lista(Cs), vocales_lista(Vs),
        random_permutation(Cs, CsR), CsR = [C1, C2, C3|_],
        random_member(Vocal, Vs),
        append([C1, C2, C3], [Vocal], Base),
        assertz(letras_base_final(Base))
    ),
    de_frase_a_oculto(FraseOriginal, Base, F_Oculta),
    ( F = F_Oculta ->
        retractall(panel_estado(_)),
        assertz(panel_estado(esperando_letras_jugador))
    ;
        throw('Error. La frase F no coincide con el panel oculto inicial de la casa para la gran final.')
    ).

consonantes_lista([b,c,d,f,g,h,j,k,l,m,n,ñ,p,q,r,s,t,v,w,x,y,z]).
vocales_lista([a,e,i,o,u,á,é,í,ó,ú]).

% --- panel_final_definitivo/1 ---
panel_final_definitivo(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

panel_final_definitivo(_) :-
    \+ panel_actual(final, _, _, _), !,
    throw('Error. El panel actual no es de tipo final.').

panel_final_definitivo(_) :-
    \+ panel_estado(esperando_letras_jugador), \+ panel_estado(letras_elegidas), !,
    throw('Error. Llamada inválida: no se ha iniciado la fase previa del panel final (panel_final_inicial/1).').

panel_final_definitivo(F) :-
    panel_actual(final, _, FraseOriginal, _),
    letras_base_final(Base),
    de_frase_a_oculto(FraseOriginal, Base, F_Inicial),
    
    atom_chars(F, CharsF),
    atom_chars(FraseOriginal, CharsOrig),
    atom_chars(F_Inicial, CharsInicial),
    
    % Obtenemos el grupo de nuevas letras que el concursante ha destapado
    obtener_nuevas_letras(CharsOrig, CharsInicial, CharsF, Base, NuevasJugador),
    contar_tipos(NuevasJugador, CountC, CountV),
    
    ( CountC =:= 4, CountV =:= 1 ->
        % Si cumple la condición exacta de 4 consonantes y 1 vocal nuevas, actualizamos el estado global
        append(Base, NuevasJugador, TodasLasLetras),
        retract(panel_actual(final, Pista, FraseOriginal, _)),
        assertz(panel_actual(final, Pista, FraseOriginal, TodasLasLetras)),
        retractall(panel_estado(_)),
        assertz(panel_estado(letras_elegidas)),
        writeln('Modo Automático: Letras del concursante validadas con éxito (4C, 1V). Panel definitivo listo.')
    ;
        throw('Error. La frase F no se ajusta con panel_final_inicial/1 o no descubre exactamente 4 consonantes y 1 vocal distintas.')
    ).







% cargar_paneles/0
% Lee los dos ficheros de texto obligatorios de la carpeta Paneles y los almacena en la memoria dinámica.
cargar_paneles :-
    % Limpiamos paneles previos si los hubiera para evitar duplicados
    retractall(panel(_,_)),
    
    % Rutas relativas hacia la carpeta Paneles
    FicheroGeneral = 'Paneles/paneles_generales.txt',
    FicheroTematico = 'Paneles/paneles_tematicos.txt',
    
    % Procesamos ambos ficheros
    procesar_fichero_paneles(FicheroGeneral),
    procesar_fichero_paneles(FicheroTematico),
    
    % Marcamos en la memoria dinámica que los paneles han sido cargados con éxito
    retractall(paneles_cargados),
    assertz(paneles_cargados),
    writeln('¡Banco de paneles cargado con éxito en el sistema!').

% procesar_fichero_paneles(+Ruta)
% Abre de forma segura un stream de lectura para el archivo indicado.
procesar_fichero_paneles(Ruta) :-
    exists_file(Ruta), !,
    open(Ruta, read, Stream, [encoding(utf8)]),
    read_line_to_string(Stream, PrimeraLinea),
    leer_lineas_paneles(Stream, PrimeraLinea),
    close(Stream).
procesar_fichero_paneles(Ruta) :-
    write('Advertencia: No se ha encontrado el fichero en la ruta '),
    writeln(Ruta).
% leer_lineas_paneles(+Stream, +LineaActual)
% Recorre recursivamente el fichero buscando las etiquetas "PISTA:" y "FRASE:"
leer_lineas_paneles(_, end_of_file) :- !. % Fin de fichero

leer_lineas_paneles(Stream, Linea) :-
    % Si la línea empieza con "PISTA:", extraemos el contenido y leemos la siguiente (que debería ser FRASE)
    sub_string(Linea, 0, 6, _, "PISTA:"), !,
    sub_string(Linea, 7, _, 0, PistaConEspacios),
    split_string(PistaConEspacios, "", " \t\r\n", [Pista]), % Limpieza de saltos de línea de Windows (\r\n)
    
    read_line_to_string(Stream, SiguienteLinea),
    (sub_string(SiguienteLinea, 0, 6, _, "FRASE:") ->
        sub_string(SiguienteLinea, 7, _, 0, FraseConEspacios),
        split_string(FraseConEspacios, "", " \t\r\n", [Frase]),
        
        % Guardamos el panel en la base de conocimientos dinámica como átomos
        atom_string(PistaAtom, Pista),
        atom_string(FraseAtom, Frase),
        assertz(panel(PistaAtom, FraseAtom))
    ;
        true
    ),
    read_line_to_string(Stream, LineaSiguiente),
    leer_lineas_paneles(Stream, LineaSiguiente).

leer_lineas_paneles(Stream, _) :-
    % Si es una línea vacía o decorativa (como los "====" de los temáticos), la salta
    read_line_to_string(Stream, SiguienteLinea),
    leer_lineas_paneles(Stream, SiguienteLinea).

% Predicado para elegir un panel al azar de los que ya están cargados
seleccionar_panel :-
    % 1. Buscar un panel aleatorio de la base de datos
    findall(panel(Pista, Frase), panel(Pista, Frase), ListaPaneles),
    ( ListaPaneles == [] -> 
        throw('Error. No hay paneles cargados. Ejecuta cargar_paneles primero.')
    ; true ),
    random_member(panel(PistaElegida, FraseElegida), ListaPaneles),
    
    % 2. Registrarlo como el panel_actual de tipo 'normal' y con 0 letras descubiertas ([])
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(normal, PistaElegida, FraseElegida, [])),
    
    % 3. Cambiar el estado del panel si juegas en Modo Automático
    retractall(panel_estado(_)),
    assertz(panel_estado(en_juego)),
    
    write('Panel seleccionado para la ronda: '), writeln(PistaElegida).