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
    estado_comodin/2,        % [NUEVO] estado_comodin(Color, MotivoPérdida)
    intentos_final/1,        % [NUEVO] Intentos restantes en el panel final
    tipo_ayuda_final/1,      % [NUEVO] Tipo de letra sorteada para Ayuda Final
    finalista/1,
    historial_actualizado/0.

% Inicialización limpia de opciones por defecto usando directiva de inicialización
:- assertz(opcion(modo, manual)),
   assertz(opcion(modo_jugador, persona)),
   assertz(opcion(velocidad, normal)),
    assertz(opcion(numero_paneles, 3)). % [NUEVO] Configuración obligatoria

% Reglas de validación interna de los apartados de configuración
opcion_valida(modo, V) :- member(V, [manual, automatico]).
opcion_valida(modo_jugador, V) :- member(V, [persona, bot]).
opcion_valida(velocidad, V) :- member(V, [rapido, lento, normal]).
opcion_valida(numero_paneles, V) :- integer(V), V >= 3.

% Auxiliar de verificación de precondición global de partida en curso
comprobar_juego_iniciado :- 
    juego_iniciado, !.
comprobar_juego_iniciado :- 
    throw('Error. No hay ningún juego iniciado.').


% =========================================================================
% PERSISTENCIA DEL HISTORIAL
% =========================================================================

archivo_historial('historial.txt').

% -------------------------------------------------------------------------
% CARGA SEGURA
% -------------------------------------------------------------------------

cargar_historial :-

    archivo_historial(Ruta),

    exists_file(Ruta),

    !,

    retractall(
        historial_concursante(_,_,_,_,_)
    ),

    setup_call_cleanup(

        open(Ruta, read, Stream),

        leer_historial(Stream),

        close(Stream)
    ).

cargar_historial.


leer_historial(Stream) :-

    read(Stream, Term),

    (
        Term == end_of_file

    ->
        true

    ;

        (
            Term = historial_concursante(_,_,_,_,_)

        ->
            assertz(Term)

        ;
            true
        ),

        leer_historial(Stream)
    ).

% -------------------------------------------------------------------------
% GUARDADO SEGURO
% -------------------------------------------------------------------------

guardar_historial :-

    opcion(modo_jugador, persona),

    !,

    archivo_historial(Ruta),

    setup_call_cleanup(

        open(Ruta, write, Stream),

        forall(

            historial_concursante(
                Nombre,
                Juegos,
                Finales,
                PremioMax,
                PremioTotal
            ),

            (
                write_canonical(
                    Stream,
                    historial_concursante(
                        Nombre,
                        Juegos,
                        Finales,
                        PremioMax,
                        PremioTotal
                    )
                ),

                write(Stream, '.\n')
            )
        ),

        close(Stream)
    ).

guardar_historial.

actualizar_historial(Nombre, TipoResultado, PremioPartida) :-

    (
        historial_concursante(Nombre, J, F, Max, Total)
    ->
        true
    ;
        J = 0,
        F = 0,
        Max = 0,
        Total = 0
    ),

    NuevoJ is J + 1,

    (
        TipoResultado == final
    ->
        NuevoF is F + 1
    ;
        NuevoF is F
    ),

    NuevoTotal is Total + PremioPartida,

    NuevoMax is max(Max, PremioPartida),

    retractall(historial_concursante(Nombre, _, _, _, _)),

    assertz(
        historial_concursante(
            Nombre,
            NuevoJ,
            NuevoF,
            NuevoMax,
            NuevoTotal
        )
    ).

actualizar_historiales_partida :-

    forall(

        jugador(Color, Nombre),

        (

            premios_acumulados(
                Color,
                Premio
            ),

            (
                finalista(Color)
            ->
                LlegoFinal = si
            ;
                LlegoFinal = no
            ),

            actualizar_historial(
                Nombre,
                LlegoFinal,
                Premio
            )

        )
    ).

apartado_existente(modo).
apartado_existente(modo_jugador).
apartado_existente(velocidad).
apartado_existente(numero_paneles).

% =========================================================================
% AMBOS MODOS: MANUAL Y AUTOMÁTICO - IMPLEMENTACIÓN COMPLETADA Y CORREGIDA
% =========================================================================

% --- ver_opcion/1 ---
ver_opcion(O) :-
    opcion(O, V), !,
    write('Configuración ['), 
    write(O), 
    write(']: '), 
    writeln(V).
ver_opcion(_) :-
    throw('Error. El apartado de configuración indicado no existe.').


% --- establecer_opcion/2 ---
establecer_opcion(_, _) :-
    juego_iniciado, !,
    throw('Error. Ya hay un juego iniciado. No se permite alterar las opciones de configuración.').

establecer_opcion(O, _) :-
    \+ apartado_existente(O), !,
    throw('Error. El apartado de configuración indicado no existe.').

establecer_opcion(O, V) :-
    \+ opcion_valida(O, V), !,
    throw('Error. El valor V no se corresponde o no es válido para el apartado de configuración.').

establecer_opcion(O, V) :-
    retractall(opcion(O, _)),
    assertz(opcion(O, V)),
    write('Apartado de configuración '), 
    write(O), 
    write(' actualizado con éxito al valor: '), 
    writeln(V).

% --- mostrar_panel/0 ---
mostrar_panel :-
    comprobar_juego_iniciado,
    panel_actual(_, Pista, FraseOriginal, LetrasDescubiertas),
    de_frase_a_oculto(FraseOriginal, LetrasDescubiertas, FraseOculta),
    writeln('==================================================='),
    write(' PISTA: '), 
    writeln(Pista),
    write(' PANEL: '), 
    writeln(FraseOculta),
    writeln('===================================================').


% --- mostrar_turno/0 ---
mostrar_turno :-
    comprobar_juego_iniciado,
    turno(Color),
    jugador(Color, Nombre),
    opcion(modo_jugador, ModoJ),
    ( ModoJ == persona ->
        write('Turno actual: Concursante de color '), 
        write(Color), 
        write(' ('), 
        write(Nombre), 
        writeln(')')
    ;
        write('Turno actual: Concursante de color '), 
        writeln(Color)
    ).


% --- mostrar_premios_acumulados/0 ---
mostrar_premios_acumulados :-
    comprobar_juego_iniciado,
    writeln('>>> PREMIOS ACUMULADOS EN LA PARTIDA <<<'),
    forall(jugador(Color, Nombre), (
        premios_acumulados(Color, Cantidad),
        write('  - Concursante '), 
        write(Color), 
        write(' ('), 
        write(Nombre), 
        write('): '), 
        write(Cantidad), 
        writeln(' €')    
        )).


% --- mostrar_premios_provisionales/0 ---
mostrar_premios_provisionales :-
    comprobar_juego_iniciado,
    writeln('>>> PREMIOS PROVISIONALES DEL PANEL ACTUAL <<<'),
    forall(jugador(Color, Nombre), (
        premios_provisionales(Color, Cantidad),
        write('  - Concursante '), 
        write(Color), 
        write(' ('), 
        write(Nombre), 
        write('): '), 
        write(Cantidad), 
        writeln(' €')    
    )).


% --- mostrar_gajos_acumulados/0 ---
mostrar_gajos_acumulados :-
    comprobar_juego_iniciado,
    writeln('>>> INVENTARIO DE GAJOS ACUMULADOS <<<'),
    forall(jugador(Color, Nombre), (
        gajos_acumulados(Color, ListaGajos),
        write('  - Concursante '), 
        write(Color), 
        write(' ('), 
        write(Nombre), 
        write('): '), 
        writeln(ListaGajos)    
    )).


% --- mostrar_ruleta/0 ---
mostrar_ruleta :-
    comprobar_juego_iniciado,
    panel_actual(final, _, _, _), !,
    throw('Error. El panel actual es de tipo Final (no se utiliza la ruleta aquí).').

mostrar_ruleta :-
    ( ultimo_giro(G) ; gajo_actual(G) ), !,
    turno(Color),
    write('Resultado actual de la ruleta para el turno de '), 
    write(Color), 
    write(': '), 
    writeln(G).
mostrar_ruleta :-
    writeln('Aún no se ha realizado ningún lanzamiento de ruleta en el turno actual.').


% --- ver_historial/1 ---
ver_historial(C) :-
    historial_concursante(C, NumJuegos, NumFinales, PremioMax, PremioTotal), !,
    ( NumJuegos > 0 -> PremioMedio is PremioTotal / NumJuegos ; PremioMedio is 0 ),
    write('Historial de '), writeln(C),
    write('Juegos: '), writeln(NumJuegos),
    write('Finales: '), writeln(NumFinales),
    write('Max: '), write(PremioMax), writeln(' €'),
    write('Media: '), write(PremioMedio), writeln(' €').
ver_historial(C) :- write('Sin historial para: '), writeln(C).

% --- ver_ranking/0 ---
ver_ranking :-
    findall(r1(Nom, NJ, Porc), (
        historial_concursante(Nom, NJ, NF, _, _),
        ( NJ > 0 -> Porc is (NF / NJ) * 100 ; Porc is 0 )
    ), L1),
    predsort(ordenar_por_porcentaje, L1, L1_Ordenada),

    findall(r2(Nom, Max, Med), (
        historial_concursante(Nom, NJ, _, Max, Tot),
        ( NJ > 0 -> Med is Tot / NJ ; Med is 0 )
    ), L2),
    predsort(ordenar_por_premio_medio, L2, L2_Ordenada),

    writeln('==================================================================='),
    writeln(' RANKING 1: Eficacia de Acceso a Panel Final (Descendente por %)'),
    writeln('==================================================================='),
    imprimir_ranking1(L1_Ordenada),
    
    writeln('\n==================================================================='),
    writeln(' RANKING 2: Rendimiento Económico (Descendente por Premio Medio)'),
    writeln('==================================================================='),
    imprimir_ranking2(L2_Ordenada).


% Auxiliares de ordenación
ordenar_por_porcentaje(<, r1(_, _, P1), r1(_, _, P2)) :- P1 > P2, !.
ordenar_por_porcentaje(>, r1(_, _, P1), r1(_, _, P2)) :- P1 < P2, !.
ordenar_por_porcentaje(=, r1(N, _, _), r1(N, _, _)) :- !.
ordenar_por_porcentaje(<, _, _).

ordenar_por_premio_medio(<, r2(_, _, M1), r2(_, _, M2)) :- M1 > M2, !.
ordenar_por_premio_medio(>, r2(_, _, M1), r2(_, _, M2)) :- M1 < M2, !.
ordenar_por_premio_medio(=, r2(N, _, _), r2(N, _, _)) :- !.
ordenar_por_premio_medio(<, _, _).

imprimir_ranking1([]).
imprimir_ranking1([r1(Nombre, Juegos, Porcentaje)|Resto]) :-
    write('  Concursante: '), 
    write(Nombre), 
    write(' | Partidas: '), 
    write(Juegos), 
    write(' | Eficacia Final: '), 
    write(Porcentaje), 
    writeln('%'),  
    imprimir_ranking1(Resto).

imprimir_ranking2([]).
imprimir_ranking2([r2(Nombre, Maximo, Medio)|Resto]) :-
    write('  Concursante: '), 
    write(Nombre), 
    write(' | Máximo Histórico: '), 
    write(Maximo), 
    write(' € | Media: '), 
    write(Medio), 
    writeln(' €'),
    imprimir_ranking2(Resto). 



%%%
%%% MODO MANUAL - LOGICA COMPLETADA
%%%

es_consonante(C) :- member(C, [b,c,d,f,g,h,j,k,l,m,n,ñ,p,q,r,s,t,v,w,x,y,z]).
es_vocal(V)      :- member(V, [a,e,i,o,u,á,é,í,ó,ú]).

% cambiar_turno/0 - Cambia el turno de forma secuencial: azul -> rojo -> amarillo -> azul
cambiar_turno :-
    turno(Actual),
    ( Actual == azul -> Siguiente = rojo
    ; Actual == rojo -> Siguiente = amarillo
    ; Siguiente = azul
    ),
    retractall(turno(_)),
    assertz(turno(Siguiente)),
    write('-> Cambio de turno. Ahora le toca al concursante: '), 
    write(Siguiente), 
    writeln('.').

% [NUEVO] Lógica del comodín para retrasar la pérdida de turno
gestionar_perdida_turno(Motivo) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    ( member(special(wild_card), Lista) ->
        writeln('¡Atención! Vas a perder el turno. Puedes usar_comodin(\'Si\') o usar_comodin(\'No\').'),
        retractall(estado_comodin(_, _)),
        assertz(estado_comodin(Color, Motivo))
    ;
        writeln('Pierdes el turno.'),
        cambiar_turno
    ).

% iniciar_juego/3
iniciar_juego(_, _, _) :- juego_iniciado, !, throw('Error. Ya hay un juego.').
iniciar_juego(C1, C2, C3) :- (C1=C2; C1=C3; C2=C3), !, throw('Error. Nombres repetidos.').
iniciar_juego(C1, C2, C3) :-
    cargar_historial, % [NUEVO] Cargamos historial existente
    retractall(juego_iniciado), retractall(jugador(_,_)), retractall(turno(_)),
    retractall(premios_acumulados(_,_)), retractall(premios_provisionales(_,_)),
    retractall(gajos_acumulados(_,_)), retractall(ultimo_giro(_)),
    retractall(panel_actual(_,_,_,_)), retractall(intentos_final(_)),
    retractall(finalista(_)), retractall(historial_actualizado),
    assertz(juego_iniciado),
    assertz(jugador(azul, C1)), assertz(jugador(rojo, C2)), assertz(jugador(amarillo, C3)),
    assertz(turno(azul)),
    assertz(premios_acumulados(azul, 0)), assertz(premios_acumulados(rojo, 0)), assertz(premios_acumulados(amarillo, 0)),
    assertz(premios_provisionales(azul, 0)), assertz(premios_provisionales(rojo, 0)), assertz(premios_provisionales(amarillo, 0)),
    assertz(gajos_acumulados(azul, [])), assertz(gajos_acumulados(rojo, [])), assertz(gajos_acumulados(amarillo, [])),
    retractall(estado_comodin(_, _)),
    retractall(tipo_ayuda_final(_)),
    assertz(intentos_final(3)),
    writeln('Juego iniciado con éxito.').

% lanzar_ruleta/0
lanzar_ruleta :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

lanzar_ruleta :-
    panel_actual(final, _, _, _), !,
    throw('Error. No se puede lanzar la ruleta en el panel final.').

lanzar_ruleta :-
    panel_actual(Tipo, _, _, _),
    (Tipo = normal ; Tipo = bote), !,
    (Tipo = normal -> TipoRuleta = standard ; TipoRuleta = jackpot),
    
    spin_wheel(TipoRuleta, random, GajosSeleccionados),
    
    retractall(ultimo_giro(_)),
    assertz(ultimo_giro(GajosSeleccionados)),
    write('¡La ruleta ha girado con éxito! Gajo resultante en posición de aguja: '), 
    writeln(GajosSeleccionados),

    % =========================================================================
    % NUEVA MEJORA: Comprobar penalizaciones inmediatas al caer la aguja
    % =========================================================================
    ( GajosSeleccionados = [_, GajoReal, _] -> true ; GajoReal = GajosSeleccionados ),
    turno(Color),
    ( GajoReal = special(loose_a_turn) ->
        writeln('¡Mala suerte! Caes en "Pierdes el turno". Pasa al siguiente concursante.'),
        retractall(ultimo_giro(_)), % Limpiamos el tiro usado
        gestionar_perdida_turno(loose_a_turn)
    ; GajoReal = special(bankrupt) ->
        writeln('¡Ouch! "Quiebra". Pierdes tu dinero provisional y tus gajos acumulados.'),
        retractall(premios_provisionales(Color, _)),
        assertz(premios_provisionales(Color, 0)),
        retractall(gajos_acumulados(Color, _)),
        assertz(gajos_acumulados(Color, [])),
        retractall(ultimo_giro(_)), % Limpiamos el tiro usado
        gestionar_perdida_turno(bankrupt)
    ; 
        true % Si es dinero o gajo normal, el turno no cambia y el juego sigue
    ).
% elegir_consonante/1
elegir_consonante(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

elegir_consonante(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. No se puede elegir consonante directamente en el panel final de este modo.').

elegir_consonante(C) :-
    \+ es_consonante(C), !,
    throw('Error. El carácter introducido no es una consonante válida.').

elegir_consonante(_) :-
    \+ ultimo_giro(_), !,
    throw('Error. Primero debes hacer girar la ruleta mediante lanzar_ruleta.').

elegir_consonante(C) :-
    turno(Color),
    panel_actual(Tipo, Pista, FraseOriginal, LetrasDescubiertas),
    downcase_atom(C, C_Low),
    ( member(C_Low, LetrasDescubiertas) ->
        throw('Error. Esa consonante ya ha sido descubierta previamente.')
    ;
        atom_chars(FraseOriginal, Chars),
        include(match_char(C_Low), Chars, Coincidencias),
        length(Coincidencias, NumApariciones),
        ( NumApariciones > 0 ->
            ultimo_giro(ListaGajos),

            % --- CORRECCIÓN CRÍTICA: Extraer el gajo del medio del trío [G1, GajoReal, G3] ---
            ( ListaGajos = [_, GajoReal, _] -> true ; GajoReal = ListaGajos ),
            
            % [NUEVO BLOQUE 5] El gajo Misterio (elige otro aleatorio)
            ( GajoReal = special(mistery) ->
                writeln('¡Gajo MISTERIO! Sorteando un gajo normal aleatorio...'),
                random_member(
                    GajoEfectivo,
                    [
                        cash(0),
                        cash(25),
                        cash(75),
                        cash(100),
                        cash(150),
                        special(loose_a_turn),
                        special(bankrupt),
                        special(wild_card),
                        special(extra_clue),
                        take_it,
                        double_letter
                    ]
                ),
                write('El misterio revela: '), writeln(GajoEfectivo)
            ; GajoEfectivo = GajoReal ),
            
            % Procesamiento económico según el tipo de gajo real
            ( GajoEfectivo = cash(Valor) ->
                Ganancia is Valor * NumApariciones,
                premios_provisionales(Color, SaldoAnt),
                NuevoSaldo is SaldoAnt + Ganancia,
                retractall(premios_provisionales(Color, _)),
                assertz(premios_provisionales(Color, NuevoSaldo)),
                write('¡Acierto! La letra "'), 
                write(C_Low), 
                write('" aparece '), 
                write(NumApariciones), 
                write(' veces. Ganas '), 
                write(Ganancia), 
                write(' €. Saldo provisional: '), 
                write(NuevoSaldo), 
                writeln(' €.'),    
                ( Tipo == bote ->
                    bote_actual(BoteAnt),
                    NuevoBote is BoteAnt + Ganancia,
                    retractall(bote_actual(_)),
                    assertz(bote_actual(NuevoBote)),
                    write('¡El Bote común aumenta! Nuevo valor del Bote: '), 
                    write(NuevoBote), 
                    writeln(' €.')
                ; true )         
            ; 
                GajoEfectivo = special(bankrupt) ->
                retractall(premios_provisionales(Color, _)),
                assertz(premios_provisionales(Color, 0)),
                retractall(gajos_acumulados(Color, _)),
                assertz(gajos_acumulados(Color, [])),
                writeln('¡Quiebra! Pierdes todo tu dinero provisional y tus gajos acumulados.'),
                gestionar_perdida_turno(bankrupt)
            ; GajoEfectivo = special(loose_a_turn) ->
                writeln('¡Pierdes el turno! Pasa al siguiente concursante.'),
                gestionar_perdida_turno(loose_a_turn)
            ;
                % Gajos especiales de inventario (Ej: premio, me lo quedo...)
                gajos_acumulados(Color, GajosAnt),
                ( member(GajoEfectivo, GajosAnt) ->
                    writeln('Ya tenías este gajo. No se acumula duplicado.')
                ;
                    retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, [GajoEfectivo|GajosAnt])),
                    write('Te adjudicas el gajo: '), writeln(GajoEfectivo)
                )
            ),
            
            % Registrar la letra como descubierta si no hubo penalización de pérdida de turno/quiebra
            ( (GajoEfectivo \= special(bankrupt), GajoEfectivo \= special(loose_a_turn)) ->
                retractall(panel_actual(_, _, _, _)),
                assertz(panel_actual(Tipo, Pista, FraseOriginal, [C_Low|LetrasDescubiertas]))
            ; true ),
            retractall(ultimo_giro(_)) % Limpiamos el tiro usado
        ;
            write('La consonante "'), 
            write(C_Low), 
            writeln('" no se encuentra en el panel. Pierdes el turno.'),            
            retractall(ultimo_giro(_)),
            gestionar_perdida_turno(fallo_letra)
        )
    ).

match_char(C, Char) :-
    downcase_atom(Char, Lower),
    normalizar_letra(Lower, NormalizadaChar),
    normalizar_letra(C, NormalizadaC),
    NormalizadaChar == NormalizadaC.

normalizar_letra('á', a).
normalizar_letra('é', e).
normalizar_letra('í', i).
normalizar_letra('ó', o).
normalizar_letra('ú', u).
normalizar_letra(Char, Char).

normalizar_texto(Texto, Normalizado) :-
    atom_chars(Texto, Chars),
    maplist(normalizar_char, Chars, Normalizadas),
    atom_chars(Normalizado, Normalizadas).

normalizar_char(Char, Normalizada) :-
    downcase_atom(Char, Lower),
    normalizar_letra(Lower, Normalizada).


% usar_gajo/1
% [CORREGIDO BLOQUE 2] Lógica completa de gajos especiales
usar_gajo(_) :-
    \+ juego_iniciado,
    !,
    throw('Error.').

usar_gajo(G) :-
    G \= take_it,
    G \= double_letter,
    !,
    throw('Error. Gajo debe ser take_it o double_letter.').

usar_gajo(G) :-
    turno(Color),
    gajos_acumulados(Color, Lista),

    ( member(G, Lista) ->

        select(G, Lista, NuevaLista),
        retractall(gajos_acumulados(Color, _)),
        assertz(gajos_acumulados(Color, NuevaLista)),

        (
            G == take_it ->

                siguiente_jugador(Color, Victima),

                premios_provisionales(Victima, Botin),

                retractall(premios_provisionales(Victima, _)),
                assertz(premios_provisionales(Victima, 0)),

                premios_provisionales(Color, MiSaldo),
                NuevoSaldo is MiSaldo + Botin,

                retractall(premios_provisionales(Color, _)),
                assertz(premios_provisionales(Color, NuevoSaldo)),

                gajos_acumulados(Victima, GajosRobados),

                retractall(gajos_acumulados(Victima, _)),
                assertz(gajos_acumulados(Victima, [])),

                gajos_acumulados(Color, MisGajos),

                append(MisGajos, GajosRobados, GajosFinales),

                retractall(gajos_acumulados(Color, _)),
                assertz(gajos_acumulados(Color, GajosFinales)),

                writeln('¡Robo ejecutado correctamente!')

        ;
            G == double_letter ->

                writeln('Doble Letra activado.')
        )

    ;
        throw('Error. No tienes este gajo.')
    ).

siguiente_jugador(azul, rojo).
siguiente_jugador(rojo, amarillo).
siguiente_jugador(amarillo, azul).

eliminar_un_gajo(_, [], []) :- !.
eliminar_un_gajo(G, [G|T], T) :- !.
eliminar_un_gajo(G, [H|T], [H|R]) :- eliminar_un_gajo(G, T, R).

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


% usar_comodin/1
usar_comodin(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

usar_comodin(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. No se puede usar el comodín en el panel final.').

usar_comodin(R) :-
    R \= si, R \= no, R \= 'Si', R \= 'No', !,
    throw('Error. La respuesta R debe ser Si o No.').

usar_comodin(R) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    ( (R = si ; R = 'Si') ->
        ( member(special(wild_card), Lista) ->
            select(special(wild_card), Lista, NuevaLista),
            retractall(gajos_acumulados(Color, _)),
            assertz(gajos_acumulados(Color, NuevaLista)),
            retractall(estado_comodin(_, _)),
            writeln('Comodín usado correctamente.')        ;
            throw('Error. El o la concursante no dispone del gajo Comodín.')
        )
    ;
        write('El concursante '), 
        write(Color), 
        writeln(' decide reservar su Comodín.')
    ).


% comprar_vocal/1
comprar_vocal(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

comprar_vocal(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. No se pueden comprar vocales en el panel final.').

comprar_vocal(V) :-
    \+ es_vocal(V), !,
    throw('Error. El carácter introducido no es una vocal válida.').
comprar_vocal(V) :-
    turno(Color),
    premios_provisionales(Color, Saldo),
    ( Saldo < 50 ->
        throw('Error. Saldo insuficiente. Comprar una vocal cuesta 50€ provisionales.')
    ;
        NuevoSaldo is Saldo - 50,
        retractall(premios_provisionales(Color, _)),
        assertz(premios_provisionales(Color, NuevoSaldo)),
        downcase_atom(V, V_Low),
        panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes),
        ( member(V_Low, LetrasAntes) ->
            write('La vocal "'), 
            write(V_Low), 
            writeln('" ya estaba descubierta. Pierdes 50€ y el turno por repetir.'),            
            cambiar_turno
        ;
            % Comprobamos si la vocal existe realmente en la frase
            atom_chars(FraseOriginal, Chars),
            include(match_char(V_Low), Chars, Coincidencias),
            length(Coincidencias, NumApariciones),
            ( NumApariciones > 0 ->
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


% resolver_panel/1
resolver_panel(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

resolver_panel(F) :-
    turno(Color),
    jugador(Color, Nombre),
    panel_actual(Tipo, _, FraseOriginal, _),

    normalizar_texto(F, F_Normal),
    normalizar_texto(FraseOriginal, Frase_Normal),

    ( F_Normal = Frase_Normal ->

        write('¡Enhorabuena! El concursante '),
        write(Color),
        writeln(' ha RESUELTO el panel correctamente.'),

        premios_provisionales(Color, Prov),
        premios_acumulados(Color, AcumAnt),
        gajos_acumulados(Color, Gajos),

        % =========================================
        % PREMIOS EXTRA
        % =========================================

        ( member(special(prize), Gajos) ->
            Extra2 = 300,
            select(special(prize), Gajos, G1)
        ;
            Extra2 = 0,
            G1 = Gajos
        ),

        (
            member(special(grand_prize_1), G1),
            member(special(grand_prize_2), G1)
        ->
            Extra1 = 600,
            select(special(grand_prize_1), G1, G2),
            select(special(grand_prize_2), G2, G_Finales)
        ;
            Extra1 = 0,
            G_Finales = G1
        ),

        TotalGanado is Prov + Extra1 + Extra2,
        NuevoAcum is AcumAnt + TotalGanado,

        retractall(premios_acumulados(Color, _)),
        assertz(premios_acumulados(Color, NuevoAcum)),

        retractall(gajos_acumulados(Color, _)),
        assertz(gajos_acumulados(Color, G_Finales)),

        writeln('Ganas premios y se aplican extras de gajos si los tenías.'),

        % =========================================
        % ACTUALIZAR HISTORIAL
        % =========================================

        ( Tipo == final ->
            Resultado = final
        ;
            Resultado = normal
        ),

        actualizar_historial(
            Nombre,
            Resultado,
            NuevoAcum
        ),

        guardar_historial

    ;

        % =========================================
        % FALLO AL RESOLVER
        % =========================================

        ( Tipo == final ->

            intentos_final(Int),
            Quedan is Int - 1,

            retractall(intentos_final(_)),
            assertz(intentos_final(Quedan)),

            write('Fallo. Te quedan '),
            write(Quedan),
            writeln(' intentos.'),

            (
                Quedan =:= 0 ->
                    writeln('Fin de la final.'),
                    actualizar_historial(Nombre, fallo_final, 0),
                    guardar_historial
            ;
                true
            )

        ;

            writeln('Fallo.'),
            gestionar_perdida_turno(fallo_resolver)
        )
    ).


% elegir_letras/5
elegir_letras(_, _, _, _, _) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

elegir_letras(_, _, _, _, _) :-
    \+ panel_actual(final, _, _, _), !,
    throw('Error. El panel actual no es de tipo final.').

elegir_letras(C1, C2, C3, C4, _) :-
    (\+ es_consonante(C1); \+ es_consonante(C2); \+ es_consonante(C3); \+ es_consonante(C4)), !,
    throw('Error. Las primeras 4 opciones deben ser consonantes validas.').

elegir_letras(_, _, _, _, V) :-
    \+ es_vocal(V), !,
    throw('Error. La quinta opción debe ser una vocal válida.').

elegir_letras(C1, C2, C3, C4, _) :-
    ( C1 = C2; C1 = C3; C1 = C4; C2 = C3; C2 = C4; C3 = C4 ), !,
    throw('Error. Las consonantes elegidas deben ser diferentes entre Si.').

elegir_letras(C1, C2, C3, C4, V) :-
    maplist(downcase_atom, [C1, C2, C3, C4, V], [LC1, LC2, LC3, LC4, LV]),
    panel_actual(final, Pista, FraseOriginal, LetrasBase),
    append([LC1, LC2, LC3, LC4, LV], LetrasBase, NuevasLetras),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(final, Pista, FraseOriginal, NuevasLetras)),
    write('Letras seleccionadas para el Panel Final incorporadas con éxito: '), 
    write(C1), 
    write(', '), 
    write(C2), 
    write(', '), 
    write(C3), 
    write(', '), 
    write(C4), 
    write(' y la vocal '), 
    write(V), 
    writeln('.').

% elegir_letra_extra/1
% elegir_letra_extra/1 - Versión Combinada e Infalible
elegir_letra_extra(L) :-

    ( \+ juego_iniciado ->
        throw(error(no_juego,
            'Error. No hay ningún juego iniciado.'))
    ; true ),

    ( \+ panel_actual(final, _, _, _) ->
        throw(error(fase_incorrecta,
            'Error. El panel actual no es de tipo final.'))
    ; true ),

    turno(Color),
    gajos_acumulados(Color, ListaGajos),

    ( \+ member(special(extra_clue), ListaGajos) ->
        throw(error(sin_ayuda_final,
            'Error. El concursante no posee el gajo Ayuda Final.'))
    ; true ),

    % -------------------------------------------------------------
    % Sorteo persistente del tipo de ayuda
    % -------------------------------------------------------------
    (
        tipo_ayuda_final(Tipo)
    ->
        true
    ;
        random_member(Tipo, [consonante, vocal, pista]),
        assertz(tipo_ayuda_final(Tipo))
    ),

    format('La ayuda final sorteada es: ~w.~n', [Tipo]),

    (
        Tipo == pista ->

            revelar_pista_extra,

            retractall(tipo_ayuda_final(_)),
            eliminar_gajo_extra_clue(Color)

    ;

        validar_letra_extra(Tipo, L),

        aplicar_letra_extra(L),

        retractall(tipo_ayuda_final(_)),
        eliminar_gajo_extra_clue(Color)
    ).

validar_letra_extra(consonante, L) :-
    es_consonante(L), !.

validar_letra_extra(vocal, L) :-
    es_vocal(L), !.

validar_letra_extra(consonante, _) :-
    throw(error(tipo_incorrecto,
        'Error. Debe introducir una consonante.')).

validar_letra_extra(vocal, _) :-
    throw(error(tipo_incorrecto,
        'Error. Debe introducir una vocal.')).

aplicar_letra_extra(L) :-

    downcase_atom(L, Lower),

    panel_actual(final, Pista, Frase, LetrasAntes),

    ( member(Lower, LetrasAntes) ->
        throw(error(letra_repetida,
            'Error. La letra ya estaba elegida.'))
    ; true ),

    retractall(panel_actual(_,_,_,_)),
    assertz(panel_actual(
        final,
        Pista,
        Frase,
        [Lower|LetrasAntes]
    )),

    format('Letra extra revelada: ~w.~n', [Lower]).    

revelar_pista_extra :-

    panel_actual(final, Pista, _, _),

    write('PISTA EXTRA: '),
    writeln(Pista).

eliminar_gajo_extra_clue(Color) :-

gajos_acumulados(Color, Lista),

    select(
        special(extra_clue),
        Lista,
        NuevaLista
    ),

    retractall(gajos_acumulados(Color,_)),
    assertz(gajos_acumulados(Color,NuevaLista)).

%%%
%%% MODO AUTOMÁTICO - CORREGIDO Y VALIDADO LIBRE DE SINGLETON VARIABLES
%%%

:- dynamic
    panel_estado/1,          % nuevo, en_juego, ruleta_lanzada, letras_elegidas, resuelto
    gajo_actual/1,           % Almacena el último gajo registrado en modo automático
    letras_base_final/1.     % Almacena las 3 consonantes y 1 vocal aleatorias de la casa en el panel final


% Convierte la frase original en su versión oculta basándose en las letras descubiertas
de_frase_a_oculto(FraseOriginal, LetrasDescubiertas, FraseOculta) :-
    atom_chars(FraseOriginal, ListaChars),
    maplist(ocultar_char(LetrasDescubiertas), ListaChars, ListaOcultaChars),
    atom_chars(FraseOculta, ListaOcultaChars).

% Si es un espacio o un signo de puntuación, se queda como está
ocultar_char(_, ' ', ' ') :- !.
ocultar_char(_, Char, Char) :- member(Char, [',', '.', ';', ':', '-', '¡', '!', '¿', '?']), !.

% Si la letra (en minúscula) ya ha sido descubierta, se muestra en el tablero
ocultar_char(LetrasDescubiertas, Char, Char) :-
    downcase_atom(Char, LetraMin),
    member(LetraMin, LetrasDescubiertas), !.

% En cualquier otro caso, la letra se oculta con un guion bajo
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
    throw('Error. El parámetro R debe ser estrictamente Si o No.').

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
    throw('Error. El parámetro R debe ser estrictamente Si o No.').

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
    throw('Error. El parámetro R debe ser estrictamente Si o No.').

panel_correcto(_) :-
    panel_actual(Tipo, _, _, _),
    (Tipo = normal ; Tipo = bote),
    \+ panel_estado(ruleta_lanzada), !,
    throw('Error. Aún no se ha lanzado la ruleta en este panel antes de intentar resolver.').

panel_correcto(_) :-
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
        retractall(panel_actual(_,_,_,_)),
        assertz(panel_actual(final, _, FraseOriginal, TodasLasLetras)),
        retractall(panel_estado(_)),
        assertz(panel_estado(letras_elegidas)),
        writeln('Modo Automático: Letras del concursante validadas con éxito (4C, 1V). Panel definitivo listo.')
    ;
        throw('Error. La frase F no se ajusta con panel_final_inicial/1 o no descubre exactamente 4 consonantes y 1 vocal distintas.')
    ).

contar_tipos([], 0, 0).

contar_tipos([L|R], C, V) :-
    contar_tipos(R, C1, V1),

    (
        es_consonante(L)
    ->
        C is C1 + 1,
        V is V1
    ;
        es_vocal(L)
    ->
        V is V1 + 1,
        C is C1
    ;
        C is C1,
        V is V1
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

    findall(
        panel(Pista, Frase),
        panel(Pista, Frase),
        ListaPaneles
    ),

    (
        ListaPaneles == [] ->
        throw('Error. No hay paneles cargados.')

    ;
        true
    ),

    random_member(
        panel(PistaElegida, FraseElegida),
        ListaPaneles
    ),

    retract(
        panel(PistaElegida, FraseElegida)
    ),

    retractall(panel_actual(_, _, _, _)),

    assertz(
        panel_actual(
            normal,
            PistaElegida,
            FraseElegida,
            []
        )
    ),

    retractall(panel_estado(_)),
    assertz(panel_estado(en_juego)),

    write('Panel seleccionado: '),
    writeln(PistaElegida).