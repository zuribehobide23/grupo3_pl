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
    historial_concursante/5.    % historial_concursante(Nombre, NumJuegos, NumFinales, PremioMax, PremioTotal)

% Inicialización limpia de opciones por defecto usando directiva de inicialización
:- assertz(opcion(modo, manual)),
   assertz(opcion(modo_jugador, persona)),
   assertz(opcion(velocidad, normal)).

% Reglas de validación interna de los apartados de configuración
opcion_valida(modo, V) :- member(V, [manual, automatico]).
opcion_valida(modo_jugador, V) :- member(V, [persona, bot]).
opcion_valida(velocidad, V) :- member(V, [rapido, lento, normal]).

% Auxiliar de verificación de precondición global de partida en curso
comprobar_juego_iniciado :- 
    juego_iniciado, !.
comprobar_juego_iniciado :- 
    throw('Error. No hay ningún juego iniciado.').


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
    \+ opcion_valida(O, _), !,
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
    write('--- HISTORIAL GLOBAL DE '), 
    write(C), 
    writeln(' ---'),
    write('  - Número de juegos disputados: '), 
    writeln(NumJuegos),
    write('  - Accesos logrados al Panel Final: '), 
    writeln(NumFinales),
    write('  - Premio acumulado máximo histórico: '), 
    write(PremioMax), 
    writeln(' €'),
    write('  - Premio acumulado medio por partida: '), 
    write(PremioMedio), 
    writeln(' €').
ver_historial(C) :-
    write('No existen registros ni historial previo para el o la concursante '), 
    write(C), 
    writeln('.').

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

% iniciar_juego/3
iniciar_juego(_, _, _) :-
    juego_iniciado, !,
    throw('Error. Ya se ha iniciado un juego.').

iniciar_juego(C1, C2, C3) :-
    (C1 = C2; C1 = C3; C2 = C3), !,
    throw('Error. Los nombres de los concursantes deben ser diferentes entre sí.').

iniciar_juego(C1, C2, C3) :-
    % Limpieza de cualquier estado residual anterior, incluidos los de modo automático
    retractall(juego_iniciado),
    retractall(jugador(_, _)),
    retractall(turno(_)),
    retractall(premios_acumulados(_, _)),
    retractall(premios_provisionales(_, _)),
    retractall(gajos_acumulados(_, _)),
    retractall(ultimo_giro(_)),
    retractall(panel_actual(_, _, _, _)),
    retractall(panel_estado(_)),
    retractall(gajo_actual(_)),
    retractall(letras_base_final(_)),
    
    % Inicialización del nuevo estado del juego
    assertz(juego_iniciado),
    assertz(jugador(azul, C1)),
    assertz(jugador(rojo, C2)),
    assertz(jugador(amarillo, C3)),
    assertz(turno(azul)),
    
    assertz(premios_acumulados(azul, 0)),
    assertz(premios_acumulados(rojo, 0)),
    assertz(premios_acumulados(amarillo, 0)),
    assertz(premios_provisionales(azul, 0)),
    assertz(premios_provisionales(rojo, 0)),
    assertz(premios_provisionales(amarillo, 0)),
    
    assertz(gajos_acumulados(azul, [])),
    assertz(gajos_acumulados(rojo, [])),
    assertz(gajos_acumulados(amarillo, [])),
    write('Juego iniciado con éxito. Concursantes: Azul ('), 
    write(C1), 
    write('), Rojo ('), 
    write(C2), 
    write('), Amarillo ('), 
    write(C3), 
    writeln('). Turno inicial: Azul.').

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
        cambiar_turno
    ; GajoReal = special(bankrupt) ->
        writeln('¡Ouch! "Quiebra". Pierdes tu dinero provisional y tus gajos acumulados.'),
        retractall(premios_provisionales(Color, _)),
        assertz(premios_provisionales(Color, 0)),
        retractall(gajos_acumulados(Color, _)),
        assertz(gajos_acumulados(Color, [])),
        retractall(ultimo_giro(_)), % Limpiamos el tiro usado
        cambiar_turno
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

elegir_consonante(C) :-
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
            
            % Procesamiento económico según el tipo de gajo real
            ( GajoReal = cash(Valor) ->
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
                GajoReal = special(bankrupt) ->
                retractall(premios_provisionales(Color, _)),
                assertz(premios_provisionales(Color, 0)),
                retractall(gajos_acumulados(Color, _)),
                assertz(gajos_acumulados(Color, [])),
                writeln('¡Quiebra! Pierdes todo tu dinero provisional y tus gajos acumulados.'),
                cambiar_turno
            ; GajoReal = special(loose_a_turn) ->
                writeln('¡Pierdes el turno! Pasa al siguiente concursante.'),
                cambiar_turno
            ;
                % Gajos especiales de inventario (Ej: premio, me lo quedo...)
                gajos_acumulados(Color, GajosAnt),
                retractall(gajos_acumulados(Color, _)),
                assertz(gajos_acumulados(Color, [GajoReal|GajosAnt])),
                write('¡Letra correcta! Te adjudicas el gajo especial '), 
                write(GajoReal), 
                writeln(' y conservas el turno.')
            ),
            
            % Registrar la letra como descubierta si no hubo penalización de pérdida de turno/quiebra
            ( (GajoReal \= special(bankrupt), GajoReal \= special(loose_a_turn)) ->
                retractall(panel_actual(_, _, _, _)),
                assertz(panel_actual(Tipo, Pista, FraseOriginal, [C_Low|LetrasDescubiertas]))
            ; true ),
            retractall(ultimo_giro(_)) % Limpiamos el tiro usado
        ;
            write('La consonante "'), 
            write(C_Low), 
            writeln('" no se encuentra en el panel. Pierdes el turno.'),            
            retractall(ultimo_giro(_)),
            cambiar_turno
        )
    ).

match_char(C, Char) :- downcase_atom(Char, Lower), Lower == C.


% usar_gajo/1
usar_gajo(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

usar_gajo(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. No se pueden usar gajos especiales en el panel final.').

usar_gajo(G) :-
    G \= me_lo_quedo, G \= doble_letra,
    G \= 'Me Lo Quedo', G \= 'Doble Letra', !,
    throw('Error. El gajo elegido debe ser "me_lo_quedo" o "doble_letra".').

usar_gajo(G) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    ( (member(G, Lista) ; (G = 'Me Lo Quedo', member(special(take_it), Lista)) ; (G = 'Doble Letra', member(special(double_letter), Lista))) ->
        write('El concursante '), 
        write(Color), 
        write(' activa con éxito el gajo especial: '), 
        writeln(G)
    ;
        throw('Error. El o la concursante no posee el gajo indicado en su inventario.')
    ).


% usar_comodin/1
usar_comodin(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

usar_comodin(_) :-
    panel_actual(final, _, _, _), !,
    throw('Error. No se puede usar el comodín en el panel final.').

usar_comodin(R) :-
    R \= si, R \= no, R \= 'Sí', R \= 'No', !,
    throw('Error. La respuesta R debe ser Sí o No.').

usar_comodin(R) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    ( (R = si ; R = 'Sí') ->
        ( member(special(wild_card), Lista) ->
            select(special(wild_card), Lista, NuevaLista),
            retractall(gajos_acumulados(Color, _)),
            assertz(gajos_acumulados(Color, NuevaLista)),
            writeln('Comodín (Wild Card) usado con éxito. Se evita la penalización.')
        ;
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
    panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes),
    downcase_atom(F, F_Low),
    downcase_atom(FraseOriginal, Frase_Low),
    (F_Low = Frase_Low ->
        write('¡Enhorabuena! El concursante '), 
        write(Color), 
        writeln(' ha RESUELTO el panel correctamente.'),        % Consolidación económica de premios de panel a acumulados globales de la partida
        premios_provisionales(Color, Prov),
        premios_acumulados(Color, AcumAnt),
        ( (Tipo == bote, ultimo_giro(Gajos), (Gajos = [_, jackpot, _] ; Gajos = jackpot)) ->
                bote_actual(DineroBote),
                writeln('¡INCREÍBLE! Se lleva el BOTE ACUMULADO de la ronda!'),
                ExtraBote = DineroBote
            ; ExtraBote = 0 ),        
        NuevoAcum is AcumAnt + Prov,
        retractall(premios_acumulados(Color, _)),
        assertz(premios_acumulados(Color, NuevoAcum)),
        
        % Reseteo de saldos provisionales de todos para el próximo panel
        retractall(premios_provisionales(_, _)),
        assertz(premios_provisionales(azul, 0)),
        assertz(premios_provisionales(rojo, 0)),
        assertz(premios_provisionales(amarillo, 0)),
        
        % Marcamos estado para requerir un nuevo iniciar_panel en modo automático o carga manual
        retractall(panel_estado(_)),
        assertz(panel_estado(resuelto))
    ;
        write('Frase incorrecta. El concursante '), 
        write(Color), 
        writeln(' falla al intentar resolver el panel.'),        
        cambiar_turno
    ).


% elegir_letras/5
elegir_letras(_, _, _, _, _) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

elegir_letras(_, _, _, _, _) :-
    \+ panel_actual(final, _, _, _), !,
    throw('Error. El panel actual no es de tipo final.').

elegir_letras(C1, C2, C3, C4, V) :-
    (\+ es_consonante(C1); \+ es_consonante(C2); \+ es_consonante(C3); \+ es_consonante(C4)), !,
    throw('Error. Las primeras 4 opciones deben ser consonantes validas.').

elegir_letras(C1, C2, C3, C4, V) :-
    \+ es_vocal(V), !,
    throw('Error. La quinta opción debe ser una vocal válida.').

elegir_letras(C1, C2, C3, C4, _) :-
    ( C1 = C2; C1 = C3; C1 = C4; C2 = C3; C2 = C4; C3 = C4 ), !,
    throw('Error. Las consonantes elegidas deben ser diferentes entre sí.').

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
elegir_letra_extra(_) :-
    \+ juego_iniciado, !,
    throw('Error. No hay ningún juego iniciado.').

elegir_letra_extra(_) :-
    \+ panel_actual(final, _, _, _), !,
    throw('Error. El panel actual no es de tipo final.').

elegir_letra_extra(L) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    \+ member(special(grand_prize_1), Lista), \+ member(special(grand_prize_2), Lista), !,
    throw('Error. El o la concursante no ha acumulado el gajo especial Ayuda Final (Grand Prize).').

elegir_letra_extra(L) :-
    \+ es_consonante(L), \+ es_vocal(L), !,
    throw('Error. L debe ser una letra válida (consonante o vocal).').

elegir_letra_extra(L) :-
    downcase_atom(L, L_Low),
    panel_actual(final, Pista, FraseOriginal, LetrasAntes),
    ( member(L_Low, LetrasAntes) ->
        throw('Error. La letra extra ya se encuentra en las elecciones anteriores.')
    ;
        retractall(panel_actual(_, _, _, _)),
        assertz(panel_actual(final, Pista, FraseOriginal, [L_Low|LetrasAntes])),
        write('Letra extra legítima elegida y revealed en el panel: '), 
        write(L_Low), 
        writeln('.')
    ).


%%%
%%% MODO AUTOMÁTICO - CORREGIDO Y VALIDADO LIBRE DE SINGLETON VARIABLES
%%%

:- dynamic
    panel_estado/1,          % nuevo, en_juego, ruleta_lanzada, letras_elegidas, resuelto
    gajo_actual/1,           % Almacena el último gajo registrado en modo automático
    letras_base_final/1.     % Almacena las 3 consonantes y 1 vocal aleatorias de la casa en el panel final


de_frase_a_oculto(Frase, Letras, Oculta) :-
    atom_chars(Frase, Chars),
    maplist(ocultar_char(Letras), Chars, OcultaChars),
    atom_chars(Oculta, OcultaChars).

ocultar_char(_, ' ', ' ') :- !.
ocultar_char(_, Char, Char) :-
    member(Char, [',', '.', ';', ':', '-', '¡', '!', '¿', '?']), !.
ocultar_char(Letras, Char, Char) :-
    downcase_atom(Char, Lower),
    member(Lower, Letras), !.
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
    ; R == 'Sí' ->
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
    R \== 'Sí', R \== 'No', !,
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
    R \== 'Sí', R \== 'No', !,
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
    R \== 'Sí', R \== 'No', !,
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
    ( R == 'Sí' ->
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