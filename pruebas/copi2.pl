:- use_module(library(random)).
:- use_module(library(lists)).

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
    juego_iniciado/0,           % Indica si la partida formal ha fcomenzado
    jugador/2,                  % jugador(Color, Nombre)
    turno/1,                    % turno(Color)
    panel_actual/4,             % panel_actual(Tipo, Pista, FraseOriginal, LetrasDescubiertas)
    panel/2,                    % panel(Pista, Frase) cargados de fichero
    paneles_cargados/0,         % Flag para saber si se leyeron los txt
    premios_acumulados/2,       % premios_acumulados(Color, Cantidad)
    premios_provisionales/2,    % premios_provisionales(Color, Cantidad)
    gajos_acumulados/2,         % gajos_acumulados(Color, ListaGajos)
    ultimo_giro/2,              % Almacena el resultado del último spin_wheel
    historial_concursante/5,    % historial_concursante(Nombre, NumJuegos, NumFinales, PremioMax, PremioTotal)
    estado_comodin/2,           % estado_comodin(Color, MotivoPérdida)
    intentos_final/1,           % Intentos restantes en el panel final
    tipo_letra_extra/1,         % Tipo de letra sorteada para Ayuda Final
    panel_estado/1,             % MODO AUT: nuevo, en_juego, ruleta_lanzada, letras_elegidas, resuelto
    gajo_actual/1,              % MODO AUT: Almacena el último gajo registrado
    letras_base_final/1,        % MODO AUT: Almacena las letras de la casa en la final
    bote_actual/1.              % Almacena el valor acumulado del bote común

% Inicialización limpia de opciones por defecto mediante directiva
:- retractall(opcion(_, _)),
   assertz(opcion(modo, manual)),
   assertz(opcion(modo_jugador, persona)),
   assertz(opcion(velocidad, normal)),
   assertz(opcion(numero_paneles, 3)).

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

cargar_historial :-
    archivo_historial(Ruta),
    exists_file(Ruta), !,
    open(Ruta, read, Stream),
    retractall(historial_concursante(_,_,_,_,_)),
    leer_historial(Stream),
    close(Stream).
cargar_historial.

leer_historial(Stream) :-
    read(Stream, Term),
    ( Term == end_of_file -> true
    ; assertz(Term), leer_historial(Stream) ).

guardar_historial :-
    opcion(modo_jugador, persona),
    archivo_historial(Ruta),
    open(Ruta, write, Stream),
    forall(historial_concursante(N, J, F, M, T),
           (write_canonical(Stream, historial_concursante(N, J, F, M, T)), write(Stream, '.\n'))),
    close(Stream).
guardar_historial.


%%%
%%%	Ambos modos: manual y automático
%%%

% ver_opcion/1
%	La llamada ver_opcion(+O) muestra el valor establecido en el apartado de configuración O.
%	Si el apartado de configuración O no existe, la llamada finaliza en error.
ver_opcion(O) :-
    opcion(O, V), !,
    write('Configuración ['), write(O), write(']: '), writeln(V).
ver_opcion(_) :-
    throw('Error. El apartado de configuración indicado no existe.').


% establecer_opcion/2
%	Si no hay ningún juego iniciado, la llamada establecer_opcion(+O,+V) establece el apartado de configuración O al valor V.
%	Si ya había un juego iniciado, el apartado de configuración O no existe o bien el valor V no se corresponde con el apartado de configuración O, entonces la llamada finaliza en error.
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
    write('Apartado de configuración '), write(O), write(' actualizado con éxito al valor: '), writeln(V).

% mostrar_panel/0
%	Si hay un juego iniciado, la llamada mostrar_panel muestra la frase y la pista del panel, ocultando las letras no descubiertas hasta el momento.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.
mostrar_panel :-
    comprobar_juego_iniciado,
    panel_actual(_, Pista, FraseOriginal, LetrasDescubiertas),
    de_frase_a_oculto(FraseOriginal, LetrasDescubiertas, FraseOculta),
    writeln('==================================================='),
    write(' PISTA: '), writeln(Pista),
    write(' PANEL: '), writeln(FraseOculta),
    writeln('===================================================').

% mostrar_turno/0
%	Si hay un juego iniciado, la llamada mostrar_turno muestra el color (y el nombre en el modo persona) del o la concursante que tiene el turno.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.
mostrar_turno :-
    comprobar_juego_iniciado,
    turno(Color),
    jugador(Color, Nombre),
    opcion(modo_jugador, ModoJ),
    ( ModoJ == persona ->
        write('Turno actual: Concursante de color '), write(Color), write(' ('), write(Nombre), writeln(')')
    ;
        write('Turno actual: Concursante de color '), writeln(Color)
    ).

% mostrar_premios_acumulados/0
%	Si hay un juego iniciado, mostrar_premios_acumulados muestra el premio acumulado de cada concursante en el juego actual.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.
mostrar_premios_acumulados :-
    comprobar_juego_iniciado,
    writeln('>>> PREMIOS ACUMULADOS EN LA PARTIDA <<<'),
    forall(jugador(Color, Nombre), (
        premios_acumulados(Color, Cantidad),
        write('  - Concursante '), write(Color), write(' ('), write(Nombre), write('): '), write(Cantidad), writeln(' €')    
    )).

% mostrar_premios_provisionales/0
%	Si hay un juego iniciado, mostrar_premios_provisionales muestra el premio provisional de cada concursante en el panel actual.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.
mostrar_premios_provisionales :-
    comprobar_juego_iniciado,
    writeln('>>> PREMIOS PROVISIONALES DEL PANEL ACTUAL <<<'),
    forall(jugador(Color, Nombre), (
        premios_provisionales(Color, Cantidad),
        write('  - Concursante '), write(Color), write(' ('), write(Nombre), write('): '), write(Cantidad), writeln(' €')    
    )).

% mostrar_gajos_acumulados/0
%	Si hay un juego iniciado, mostrar_gajos_acumulados muestra los gajos acumulados por cada concursante en el juego actual.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.
mostrar_gajos_acumulados :-
    comprobar_juego_iniciado,
    writeln('>>> INVENTARIO DE GAJOS ACUMULADOS <<<'),
    forall(jugador(Color, Nombre), (
        gajos_acumulados(Color, ListaGajos),
        write('  - Concursante '), write(Color), write(' ('), write(Nombre), write('): '), writeln(ListaGajos)    
    )).

% mostrar_ruleta/0
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, mostrar_ruleta muestra el gajo en el que ha caído el o la concursante que tiene el turno.
%	Si no había un juego iniciado o bien el panel actual es de tipo Final, entonces la llamada finaliza en error.
mostrar_ruleta :-
    comprobar_juego_iniciado,
    panel_actual(final, _, _, _), !,
    throw('Error. El panel actual es de tipo Final (no se utiliza la ruleta aquí).').
mostrar_ruleta :-
    turno(Color),
    ultimo_giro(Color, Gajo), !,
    write('Resultado actual de la ruleta para el turno de '), write(Color), write(': '), writeln(G).
mostrar_ruleta :-
    writeln('Aún no se ha realizado ningún lanzamiento de ruleta en el turno actual.').

% ver_historial/1
%	ver_historial(+C) muestra el historial del o la concursante C: número de juegos y de veces que ha accedido al Panel final, premio acumulado máximo y premio acumulado medio.
ver_historial(C) :-
    historial_concursante(C, NumJuegos, NumFinales, PremioMax, PremioTotal), !,
    ( NumJuegos > 0 -> PremioMedio is PremioTotal / NumJuegos ; PremioMedio is 0 ),
    write('Historial de '), writeln(C),
    write('Juegos: '), writeln(NumJuegos),
    write('Finales: '), writeln(NumFinales),
    write('Max: '), write(PremioMax), writeln(' €'),
    write('Media: '), write(PremioMedio), writeln(' €').
ver_historial(C) :- write('Sin historial para: '), writeln(C).

% ver_ranking/0
%	ver_ranking muestra dos listas de concursantes: la primera lista muestra junto a cada nombre de concursante su número de juegos y el porcentaje de juegos en el que ha accedido al Panel final, y está ordenada de manera descendente según el porcentaje de juegos en los que ha accedido al Panel final; la segunda lista muestra junto a cada nombre de concursante su premio acumulado máximo y medio, y está ordenado de manera descendente según su premio acumulado medio.
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
    write('  Concursante: '), write(Nombre), write(' | Partidas: '), write(Juegos), write(' | Eficacia Final: '), write(Porcentaje), writeln('%'),  
    imprimir_ranking1(Resto).

imprimir_ranking2([]).
imprimir_ranking2([r2(Nombre, Maximo, Medio)|Resto]) :-
    write('  Concursante: '), write(Nombre), write(' | Máximo Histórico: '), write(Maximo), write(' € | Media: '), write(Medio), writeln(' €'),
    imprimir_ranking2(Resto). 


%%%
%%% Modo manual
%%%

es_consonante(C) :-
    member(C,
    [b,c,d,f,g,h,j,k,l,m,n,ñ,p,q,r,s,t,v,w,x,y,z,
     'B','C','D','F','G','H','J','K','L','M','N','Ñ',
     'P','Q','R','S','T','V','W','X','Y','Z']).

es_vocal(V) :-
    member(V,
    [a,e,i,o,u,
     'A','E','I','O','U',
     á,é,í,ó,ú,
     'Á','É','Í','Ó','Ú']).

cambiar_turno :-
    turno(Actual),
    ( Actual == azul -> Siguiente = rojo
    ; Actual == rojo -> Siguiente = amarillo
    ; Siguiente = azul
    ),
    retractall(turno(_)),
    assertz(turno(Siguiente)),
    write('-> Cambio de turno. Ahora le toca al concursante: '), write(Siguiente), writeln('.').

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

% iniciar_juego/3
%	Si no hay ningún juego iniciado, iniciar_juego(+C1,+C2,+C3) inicia un nuevo juego y establece el nombre de los y las concursantes azul, roja y amarilla a C1, C2 y C3 (diferentes entre sí) respectivamente.
%	Si ya había un juego iniciado o bien alguno de los nombres C1, C2 o C3 se repite, entonces la llamada finaliza en error.
iniciar_juego(_, _, _) :- juego_iniciado, !, throw('Error. Ya hay un juego.').
iniciar_juego(C1, C2, C3) :- (C1=C2; C1=C3; C2=C3), !, throw('Error. Nombres repetidos.').
iniciar_juego(C1, C2, C3) :-
    cargar_historial,
    retractall(juego_iniciado), retractall(jugador(_,_)), retractall(turno(_)),
    retractall(premios_acumulados(_,_)), retractall(premios_provisionales(_,_)),
    retractall(gajos_acumulados(_,_)), retractall(ultimo_giro(_,_)),
    retractall(panel_actual(_,_,_,_)), retractall(intentos_final(_)),
    retractall(bote_actual(_)), retractall(panel_estado(_)),
    retractall(gajo_actual(_)), retractall(letras_base_final(_)),
    retractall(tipo_letra_extra(_)), retractall(estado_comodin(_,_)),
    assertz(juego_iniciado),
    assertz(jugador(azul, C1)), assertz(jugador(rojo, C2)), assertz(jugador(amarillo, C3)),
    assertz(turno(azul)),
    assertz(premios_acumulados(azul, 0)), assertz(premios_acumulados(rojo, 0)), assertz(premios_acumulados(amarillo, 0)),
    assertz(premios_provisionales(azul, 0)), assertz(premios_provisionales(rojo, 0)), assertz(premios_provisionales(amarillo, 0)),
    assertz(gajos_acumulados(azul, [])), assertz(gajos_acumulados(rojo, [])), assertz(gajos_acumulados(amarillo, [])),
    assertz(bote_actual(0)),
    writeln('Juego iniciado con éxito.').

% lanzar_ruleta/0
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada lanzar_ruleta hace girar la ruleta.
%	Si no había un juego iniciado o el panel actual es de tipo final, entonces la llamada finaliza en error.
lanzar_ruleta :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
lanzar_ruleta :-
    panel_actual(final, _, _, _), !, throw('Error. No se puede lanzar la ruleta en el panel final.').
lanzar_ruleta :-
    panel_actual(Tipo, _, _, _),
    (Tipo = normal ; Tipo = bote), !,
    (Tipo = normal -> TipoRuleta = standard ; TipoRuleta = jackpot),
    spin_wheel(TipoRuleta, random, GajosSeleccionados),
    retractall(ultimo_giro(_, _)),
    assertz(ultimo_giro(Color, GajoReal)),
    write('¡La ruleta ha girado con éxito! Gajo resultante: '), writeln(GajosSeleccionados),
    ( GajosSeleccionados = [_, GajoReal, _] -> true ; GajoReal = GajosSeleccionados ),
    turno(Color),
    ( GajoReal = special(loose_a_turn) ->
        writeln('¡Mala suerte! Caes en "Pierdes el turno".'),
        retractall(ultimo_giro(_)),
        gestionar_perdida_turno(loose_a_turn)
    ; GajoReal = special(bankrupt) ->
        writeln('¡Ouch! "Quiebra". Pierdes tu dinero provisional y tus gajos acumulados.'),
        retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, 0)),
        retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, [])),
        retractall(ultimo_giro(_)),
        gestionar_perdida_turno(bankrupt)
    ; 
        true
    ).

% elegir_consonante/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada elegir_consonante(+C) permite al o la concursante que tiene el turno elegir la consonante C.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien C no es una consonante, entonces la llamada finaliza en error.
elegir_consonante(_) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
elegir_consonante(_) :-
    panel_actual(final, _, _, _), !, throw('Error. No se puede elegir consonante en el panel final de este modo.').
elegir_consonante(C) :-
    \+ es_consonante(C), !, throw('Error. El carácter introducido no es una consonante válida.').
elegir_consonante(C) :-
    \+ ultimo_giro(_), !, throw('Error. Primero debes hacer girar la ruleta mediante lanzar_ruleta.').
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
            ( ListaGajos = [_, GajoReal, _] -> true ; GajoReal = ListaGajos ),
            
            % Procesamiento del Gajo Misterio si corresponde
            ( GajoReal == mistery ->
                writeln('¡Gajo MISTERIO! Sorteando un gajo normal aleatorio...'),
                random_member(GajoEfectivo,
                    [cash(0), cash(25), cash(75), cash(100), cash(150),
                    special(loose_a_turn),
                    special(bankrupt),
                    special(wild_card),
                    special(grand_prize_1),
                    special(grand_prize_2),
                    special(take_it),
                    special(double_letter)])
                write('El misterio revela: '), writeln(GajoEfectivo)
            ; GajoEfectivo = GajoReal ),

            % Procesamiento de efectos sobre el Gajo Efectivo final
            ( GajoEfectivo = cash(Valor) ->
                Ganancia is Valor * NumApariciones,
                premios_provisionales(Color, SaldoAnt),
                NuevoSaldo is SaldoAnt + Ganancia,
                retractall(premios_provisionales(Color, _)),
                assertz(premios_provisionales(Color, NuevoSaldo)),
                write('¡Acierto! La letra "'), write(C_Low), write('" aparece '), write(NumApariciones), write(' veces. Ganas '), write(Ganancia), write(' €. Saldo provisional: '), write(NuevoSaldo), writeln(' €.'),    
                ( Tipo == bote ->
                    bote_actual(BoteAnt),
                    NuevoBote is BoteAnt + Ganancia,
                    retractall(bote_actual(_)), assertz(bote_actual(NuevoBote)),
                    write('¡El Bote común aumenta! Nuevo valor del Bote: '), write(NuevoBote), writeln(' €.')
                ; true )         
            ; GajoEfectivo = special(bankrupt) ->
                retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, 0)),
                retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, [])),
                writeln('¡Quiebra! Pierdes todo tu dinero provisional y tus gajos acumulados.'),
                gestionar_perdida_turno(bankrupt)
            ; GajoEfectivo = special(loose_a_turn) ->
                writeln('¡Pierdes el turno! Pasa al siguiente concursante.'),
                gestionar_perdida_turno(loose_a_turn)
            ;
                gajos_acumulados(Color, GajosAnt),
                ( member(GajoEfectivo, GajosAnt) ->
                    writeln('Ya tenías este gajo. No se acumula duplicado.')
                ;
                    retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, [GajoEfectivo|GajosAnt])),
                    write('Te adjudicas el gajo: '), writeln(GajoEfectivo)
                )
            ),
            
            % Registro de la letra si no hubo pérdida de turno inmediata
            ( (GajoEfectivo \= special(bankrupt), GajoEfectivo \= special(loose_a_turn)) ->
                retractall(panel_actual(_, _, _, _)),
                assertz(panel_actual(Tipo, Pista, FraseOriginal, [C_Low|LetrasDescubiertas]))
            ; true ),
            retractall(ultimo_giro(_))
        ;
            write('La consonante "'), write(C_Low), writeln('" no se encuentra en el panel. Pierdes el turno.'),            
            retractall(ultimo_giro(_)),
            gestionar_perdida_turno(fallo_letra)
        )
    ).

match_char(C, Char) :- downcase_atom(Char, Lower), Lower == C.

% usar_gajo/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada usar_gajo(+G) permite al o la concursante que tiene el turno utilizar el gajo G, que puede ser el gajo especial  Me Lo Quedo o bien Doble Letra.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien el gajo elegido G no es ni Me Lo Quedo ni Doble Letra, entonces la llamada finaliza en error.
usar_gajo(G) :- \+ juego_iniciado, !, throw('Error. No hay un juego iniciado.').
usar_gajo(G) :- G \= take_it, G \= double_letter, !, throw('Error. Gajo debe ser take_it o double_letter.').
usar_gajo(G) :-
    turno(Color), gajos_acumulados(Color, Lista),
    ( member(G, Lista) ->
        select(G, Lista, NuevaLista),
        retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevaLista)),
        ( G == take_it ->
            ( Color == azul -> Victima = rojo ; Color == rojo -> Victima = amarillo ; Victima = azul ),
            format('Me Lo Quedo: Robas premios provisionales y gajos al jugador de color ~w.~n', [Victima]),
            premios_provisionales(Victima, Botin), retractall(premios_provisionales(Victima, _)), assertz(premios_provisionales(Victima, 0)),
            premios_provisionales(Color, MiSaldo), NuevoSaldo is MiSaldo + Botin,
            retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoSaldo)),
            gajos_acumulados(Victima, GajosRobados), retractall(gajos_acumulados(Victima, _)), assertz(gajos_acumulados(Victima, [])),
            gajos_acumulados(Color, MisGajos), append(MisGajos, GajosRobados, GajosFinales),
            retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, GajosFinales))
        ; G == double_letter ->
            writeln('Doble Letra: Tienes un turno extra gratis sin tirar ruleta.')
        )
    ; throw('Error. No tienes este gajo.') ).

% usar_comodin/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada usar_comodin(+R) permite al o la concursante que tiene el turno decidir si utiliza el gajo especial Comodín o no.
%	En concreto, si R es Sí, entonces el gajo especial Comodín será utilizado.
%	Por el contrario, si R es No, entonces el gajo especial Comodín no se utilizará.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien R no es ni Sí ni No, entonces la llamada finaliza en error.
usar_comodin(R) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
usar_comodin(_) :-
    panel_actual(final, _, _, _), !, throw('Error. No se puede usar el comodín en el panel final.').
usar_comodin(R) :-
    R \= si, R \= no, R \= 'Si', R \= 'Sí', R \= 'No', !,
    throw('Error. La respuesta R debe ser Sí o No.').
usar_comodin(R) :-
    turno(Color),
    gajos_acumulados(Color, Lista),
    ( (R == si ; R == 'Si' ; R == 'Sí') ->
        ( member(special(wild_card), Lista) ->
            select(special(wild_card), Lista, NuevaLista),
            retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, NuevaLista)),
            writeln('Comodín (Wild Card) usado con éxito. Se evita la penalización.')
        ;
            throw('Error. El o la concursante no dispone del gajo Comodín.')
        )
    ;
        write('El concursante '), write(Color), writeln(' decide reservar su Comodín.')
    ).

% comprar_vocal/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada comprar_vocal(+V) permite al o la concursante que tiene el turno comprar la vocal V.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien V no es una vocal, entonces la llamada finaliza en error.
comprar_vocal(V) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
comprar_vocal(_) :-
    panel_actual(final, _, _, _), !, throw('Error. No se pueden comprar vocales en el panel final.').
comprar_vocal(V) :-
    \+ es_vocal(V), !, throw('Error. El carácter introducido no es una vocal válida.').
comprar_vocal(V) :-
    turno(Color),
    premios_provisionales(Color, Saldo),
    ( Saldo < 50 ->
        throw('Error. Saldo insuficiente. Comprar una vocal cuesta 50€ provisionales.')
    ;
        NuevoSaldo is Saldo - 50,
        retractall(premios_provisionales(Color, _)), assertz(premios_provisionales(Color, NuevoSaldo)),
        downcase_atom(V, V_Low),
        panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes),
        ( member(V_Low, LetrasAntes) ->
            write('La vocal "'), write(V_Low), write('" ya estaba descubierta. Pierdes 50€ y el turno por repetir.'),            
            gestionar_perdida_turno(repetida)
        ;
            atom_chars(FraseOriginal, Chars),
            include(match_char(V_Low), Chars, Coincidencias),
            length(Coincidencias, NumApariciones),
            ( NumApariciones > 0 ->
                retractall(panel_actual(_, _, _, _)), assertz(panel_actual(Tipo, Pista, FraseOriginal, [V_Low|LetrasAntes])),
                write('El concursante '), write(Color), write(' compra la vocal "'), write(V_Low), write('" por 50€. ¡Acierto! Saldo restante: '), write(NuevoSaldo), writeln('€')
            ;
                write('La vocal "'), write(V_Low), writeln('" no se encuentra en el panel. Pierdes 50€ y el turno.'),
                cambiar_turno
            )
        )
    ).

% resolver_panel/1
%	Si hay un juego iniciado, la llamada resolver_panel(+F) permite resolver el panel leyendo la frase F al o la concursante que tiene el turno en el caso de paneles de tipo normal o con bote, o bien que ha accedido al Panel final.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.
resolver_panel(F) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
resolver_panel(F) :-
    turno(Color),
    panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes),
    downcase_atom(F, F_Low),
    downcase_atom(FraseOriginal, Frase_Low),
    (F_Low = Frase_Low ->
        write('¡Enhorabuena! El concursante '), write(Color), writeln(' ha RESUELTO el panel correctamente.'),
        premios_provisionales(Color, Prov),
        premios_acumulados(Color, AcumAnt),
        gajos_acumulados(Color, Gajos),
        
        ( member(prize, Gajos) -> Extra2 = 300, select(prize, Gajos, G1) ; Extra2 = 0, G1 = Gajos ),
        ( (member(grand_prize_1, G1), member(grand_prize_2, G1)) -> 
            Extra1 = 600, select(grand_prize_1, G1, G2), select(grand_prize_2, G2, G_Finales) 
        ; Extra1 = 0, G_Finales = G1 ),
        
        TotalGanado is Prov + Extra1 + Extra2,
        NuevoAcum is AcumAnt + TotalGanado,
        retractall(premios_acumulados(Color, _)), assertz(premios_acumulados(Color, NuevoAcum)),
        retractall(gajos_acumulados(Color, _)), assertz(gajos_acumulados(Color, G_Finales)),
        
        writeln('Ganas premios y se aplican extras de gajos si los tenías.'),
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

% elegir_letras/5
%	Si hay un juego iniciado y el panel actual es de tipo final, la llamada elegir_letras(+C₁,+C₂,+C₃,+C4,+V) permite al o la concursante que ha accedido al Panel final elegir las consonantes C₁, C₂, C₃ y C4, (todas diferentes entre sí) y la vocal V.
%	Si no había un juego iniciado, el panel actual no es de tipo final, C₁, C₂, C₃ o C4 no son consonantes o no son diferentes entre sí, o bien V no es una vocal, entonces la llamada finaliza en error.
elegir_letras(_, _, _, _, _) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
elegir_letras(_, _, _, _, _) :-
    \+ panel_actual(final, _, _, _), !, throw('Error. El panel actual no es de tipo final.').
elegir_letras(C1, C2, C3, C4, V) :-
    (\+ es_consonante(C1); \+ es_consonante(C2); \+ es_consonante(C3); \+ es_consonante(C4)), !,
    throw('Error. Las primeras 4 opciones deben ser consonantes validas.').
elegir_letras(C1, C2, C3, C4, V) :-
    \+ es_vocal(V), !, throw('Error. La quinta opción debe ser una vocal válida.').
elegir_letras(C1, C2, C3, C4, _) :-
    ( C1 = C2; C1 = C3; C1 = C4; C2 = C3; C2 = C4; C3 = C4 ), !,
    throw('Error. Las consonantes elegidas deben ser diferentes entre sí.').
elegir_letras(C1, C2, C3, C4, V) :-
    maplist(downcase_atom, [C1, C2, C3, C4, V], [LC1, LC2, LC3, LC4, LV]),
    panel_actual(final, Pista, FraseOriginal, LetrasBase),
    append([LC1, LC2, LC3, LC4, LV], LetrasBase, NuevasLetras),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(final, Pista, FraseOriginal, NuevasLetras)),
    write('Letras seleccionadas para el Panel Final incorporadas con éxito.').

% elegir_letra_extra/1
%	Si hay un juego iniciado, el panel actual es de tipo final, y el o la concursante que ha accedido al Panel final ha acumulado el gajo especial Ayuda Final, la llamada elegir_letra_extra(+L) permite al o la concursante elegir la letra L del tipo letra elegido aleatoriamente por el programa.
%	Si no había un juego iniciado, el panel actual no es de tipo final, el o la concursante no ha acumulado el gajo especial Ayuda Final o bien L no es ni una consonante ni una vocal, no es el tipo de letra elegido aleatoriamente por el programa o no es diferente a las letras elegidas anteriormente, entonces la llamada finaliza en error.
elegir_letra_extra(L) :-
    ( \+ juego_iniciado -> throw(error(no_juego, 'Error. No hay ningún juego iniciado.')) ; true ),
    ( \+ panel_actual(final, _, _, _) -> throw(error(fase_incorrecta, 'Error. El panel actual no es de tipo final.')) ; true ),
    turno(Color),
    gajos_acumulados(Color, ListaGajos),
    ( \+ member(special(grand_prize_1), ListaGajos), \+ member(special(grand_prize_2), ListaGajos) ->
        throw(error(sin_ayuda_final, 'Error. El o la concursante no posee el gajo de Ayuda Final.'))
    ; true ),
    ( tipo_letra_extra(T) -> true ; random_member(T, [consonante, vocal]), assertz(tipo_letra_extra(T)) ),
    format('El sistema te obliga a pedir una: ~w.~n', [T]),
    ( T == consonante ->
        ( es_consonante(L) -> true ; throw(error(tipo_incorrecto, 'Error: Debe ser una consonante.')) )
    ;
        ( es_vocal(L) -> true ; throw(error(tipo_incorrecto, 'Error: Debe ser una vocal.')) )
    ),
    downcase_atom(L, L_Low),
    panel_actual(final, Pista, FraseOriginal, LetrasAntes),
    ( memberchk(L_Low, LetrasAntes) ->
        retractall(tipo_letra_extra(_)),
        throw(error(letra_duplicada, 'Error. La letra extra ya se encuentra descubierta.'))
    ; true ),
    retractall(panel_actual(final, _, _, _)),
    assertz(panel_actual(final, Pista, FraseOriginal, [L_Low|LetrasAntes])),
    retractall(tipo_letra_extra(_)),
    format('Letra extra legítima elegida: ~w.~n', [L_Low]).


%%%
%%% Modo automático
%%%

% Auxiliar para contar consonantes y vocales en modo automático
contar_tipos([], 0, 0).
contar_tipos([H|T], CC, CV) :-
    es_consonante(H), !, contar_tipos(T, CC1, CV), CC is CC1 + 1.
contar_tipos([H|T], CC, CV) :-
    es_vocal(H), !, contar_tipos(T, CC, CV1), CV is CV1 + 1.
contar_tipos([_|T], CC, CV) :-
    contar_tipos(T, CC, CV).

de_frase_a_oculto(FraseOriginal, LetrasDescubiertas, FraseOculta) :-
    atom_chars(FraseOriginal, ListaChars),
    maplist(ocultar_char(LetrasDescubiertas), ListaChars, ListaOcultaChars),
    atom_chars(FraseOculta, ListaOcultaChars).

ocultar_char(_, ' ', ' ') :- !.
ocultar_char(_, Char, Char) :- member(Char, [',', '.', ';', ':', '-', '¡', '!', '¿', '?']), !.
ocultar_char(LetrasDescubiertas, Char, Char) :-
    downcase_atom(Char, LetraMin),
    member(LetraMin, LetrasDescubiertas), !.
ocultar_char(_, _, '_').

obtener_nuevas_letras([], [], [], _, []).
obtener_nuevas_letras([O|Os], [A|As], [F|Fs], LetrasAntes, Nuevas) :-
    ( A == '_', F \== '_' ->
        downcase_atom(O, LowerO),
        downcase_atom(F, LowerF),
        ( LowerF == LowerO ->
            obtener_nuevas_letras(Os, As, Fs, LetrasAntes, RestoNuevas),
            ( member(LowerO, RestoNuevas) -> Nuevas = RestoNuevas ; Nuevas = [LowerO|RestoNuevas] )
        ;
            throw('Error. El carácter revelado en F no coincide con la frase original del panel.')
        )
    ;
        ( A \== '_' -> 
            ( F == A -> true ; throw('Error. Se ha alterado un carácter ya descubierto o un espacio.') )
        ;
            ( F == '_' -> true ; throw('Error. Estructura inesperada en la frase oculta F.') )
        ),
        obtener_nuevas_letras(Os, As, Fs, LetrasAntes, Nuevas)
    ).

validar_cambio_frase(R, F, TipoEsperado) :-
    panel_actual(_, _, FraseOriginal, LetrasAntes),
    de_frase_a_oculto(FraseOriginal, LetrasAntes, F_Antes),
    ( R == 'No' ->
        ( F == F_Antes -> true ; throw('Error. Si R es No, la frase F debe ser idéntica al estado anterior.') )
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
            retractall(panel_actual(Tipo, Pista, FraseOriginal, LetrasAntes)),
            assertz(panel_actual(Tipo, Pista, FraseOriginal, [NuevaLetra|LetrasAntes]))
        ;
            throw('Error. La frase F debe descubrir exactamente una nueva letra del tipo esperado.')
        )
    ).

% iniciar_panel/1
%	Si hay un juego iniciado, el panel actual es de tipo normal o con bote y el panel anterior acaba de ser resuelto o bien es el primer panel del juego, la llamada iniciar_panel(+F) indica en F el número de palabras y el número de letras de cada palabra en la frase del panel a resolver.
%	En concreto, F es una expresión atómica (es decir, expresión delimitada por comillas simples) donde cada letra de la frase se oculta mediante el carácter _.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien el panel anterior no acaba de ser resuelto ni es el primer panel del juego, entonces la llamada finaliza en error.
iniciar_panel(_) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
iniciar_panel(_) :-
    panel_actual(final, _, _, _), !, throw('Error. El panel actual es de tipo final.').
iniciar_panel(F) :-
    panel_actual(Tipo, _, FraseOriginal, _),
    (Tipo = normal ; Tipo = bote),
    de_frase_a_oculto(FraseOriginal, [], F_Oculta),
    ( F = F_Oculta -> 
        retractall(panel_estado(_)), assertz(panel_estado(en_juego)),
        write('Modo Automático: Panel de tipo ('), write(Tipo), writeln(') iniciado.')    
    ; 
        throw('Error. La expresión F no coincide con el formato inicial oculto.')
    ).

% gajo_ruleta/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada gajo_ruleta(+G) indica que el gajo en el que ha caído el o la concursante con el turno es G.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien G no es un gajo válido de la ruleta actual, entonces la llamada finaliza en error.
gajo_ruleta(_) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
gajo_ruleta(_) :-
    panel_actual(final, _, _, _), !, throw('Error. El panel actual es de tipo final.').
gajo_ruleta(G) :-
    retractall(gajo_actual(_)), assertz(gajo_actual(G)),
    retractall(panel_estado(_)), assertz(panel_estado(ruleta_lanzada)),
    write('Modo Automático: Concursante cae en el gajo '), write(G), writeln('.').

% aparece_consonante/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada aparece_consonante(+R,+F) indica si la consonante elegida por el o la concursante actual aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En concreto, si R es Sí, entonces se indica que la consonante elegida si aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En ese caso, en F (de tipo expresión atómica; es decir, expresión delimitada por comilla simple) se indica el estado actual de la frase del panel tras descubrir la consonante elegida, ocultando mediante _ las letras de la frase del panel que aún no han sido descubiertas.
%	Si R es No, entonces se indica que la consonante elegida no aparece en la frase del panel o bien ya había sido descubierta anteriormente.
%	Si no había un juego iniciado, el panel actual es de tipo final, R no es ni Sí ni No, la frase F no se ajusta con la frase proporcionada al comienzo del panel (es decir, no contiene el mismo número de palabras con el mismo número de letras casa una) o bien no descubre la consonante elegida, entonces la llamada finaliza en error.
aparece_consonante(_, _) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
aparece_consonante(_, _) :-
    panel_actual(final, _, _, _), !, throw('Error. El panel actual es de tipo final.').
aparece_consonante(R, _) :-
    R \== 'Si', R \== 'No', !, throw('Error. El parámetro R debe ser estrictamente Si o No.').
aparece_consonante(R, F) :-
    validar_cambio_frase(R, F, consonante),
    retractall(panel_estado(_)), assertz(panel_estado(en_juego)).

% aparece_vocal/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada aparece_vocal(+R,+F) indica si la vocal comprada por el o la concursante actual aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En concreto, si R es Sí, entonces se indica que la vocal comprada si aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En ese caso, en F (de tipo expresión atómica; es decir, expresión delimitada por comilla simple) se indica el estado actual de la frase del panel tras descubrir la vocal comprada, ocultando mediante _ las letras de la frase del panel que aún no han sido descubiertas.
%	Si R es No, entonces se indica que la vocal comprada no aparece en la frase del panel o bien ya había sido descubierta anteriormente.
%	Si no había un juego iniciado, el panel actual es de tipo final, R no es ni Sí ni No o bien la frase F no se ajusta con la frase proporcionada al comienzo del panel (es decir, no contiene el mismo número de palabras con el mismo número de letras casa una) o no descubre la vocal comprada, entonces la llamada finaliza en error.
aparece_vocal(_, _) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
aparece_vocal(_, _) :-
    panel_actual(final, _, _, _), !, throw('Error. El panel actual es de tipo final.').
aparece_vocal(R, _) :-
    R \== 'Si', R \== 'No', !, throw('Error. El parámetro R debe ser estrictamente Si o No.').
aparece_vocal(R, F) :-
    validar_cambio_frase(R, F, vocal),
    retractall(panel_estado(_)), assertz(panel_estado(en_juego)).

% panel_correcto/1
%	Si hay un juego iniciado y ya se ha lanzado la ruleta en el caso de los paneles de tipo normal o con bote, o bien ya se han elegido las letras en el caso del Panel final, la llamada panel_correcto(+R) indica si la frase leída por el o la concursante que tiene el turno en el caso de paneles de tipo normal o con bote, o bien que ha accedido al Panel final es correcta o no.
%	En concreto, si R es Sí, entonces se indica que la frase es correcta.
%	Si R es No, entonces se indica que la frase no es correcta.
%	Si no había un juego iniciado, aún no se ha lanzado la ruleta en el caso de los paneles de tipo normal o con bote, aún no se han elegido las letras en el caso del Panel final o bien R no es ni Sí ni No, entonces la llamada finaliza en error.
panel_correcto(_) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
panel_correcto(R) :-
    R \== 'Si', R \== 'No', !, throw('Error. El parámetro R debe ser estrictamente Si o No.').
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
        retractall(panel_estado(_)), assertz(panel_estado(resuelto)),
        writeln('Modo Automático: Resolución CORRECTA.')
    ;
        retractall(panel_estado(_)), assertz(panel_estado(en_juego)),
        writeln('Modo Automático: Resolución INCORRECTA.')
    ).

% panel_final_inicial/1
%	Si hay un juego iniciado, el panel actual es de tipo final y el o la concursante que ha accedido al Panel final aún no ha elegido ninguna letra, la llamada panel_final_inicial(+F) indica en F el número de palabras y el número de letras de cada palabra en la frase del Panel final a resolver descubriendo las letras (3 consonantes y 1 vocal) que han sido elegidas aleatoriamente.
%	En concreto, F es una expresión atómica (es decir, expresión delimitada por comillas simples) donde cada letra de la frase se oculta mediante el carácter _ a excepción de las que han sido descubiertas.
%	Si no había un juego iniciado, el panel actual no de de tipo final o bien el o la concursante ya ha elegido alguna letra, entonces la llamada finaliza en error.
panel_final_inicial(_) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
panel_final_inicial(_) :-
    \+ panel_actual(final, _, _, _), !, throw('Error. El panel actual no es de tipo final.').
panel_final_inicial(_) :-
    panel_estado(letras_elegidas), !, throw('Error. Las letras definitivas ya han sido seleccionadas.').
panel_final_inicial(F) :-
    panel_actual(final, _, FraseOriginal, _),
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
        retractall(panel_estado(_)), assertz(panel_estado(esperando_letras_jugador))
    ;
        throw('Error. La frase F no coincide con el panel oculto inicial de la casa.')
    ).

consonantes_lista([b,c,d,f,g,h,j,k,l,m,n,ñ,p,q,r,s,t,v,w,x,y,z]).
vocales_lista([a,e,i,o,u,á,é,í,ó,ú]).

% panel_final_definitivo/1
%	Si hay un juego iniciado, el panel actual es de tipo final y el o la concursante que ha accedido al Panel final ya ha elegido sus letras (4 consonantes y 1 vocal, la llamada panel_final_definitivo(+F) indica en F el número de palabras y el número de letras de cada palabra en la frase del Panel final a resolver descubriendo todas las letras que han sido elegidas.
%	En concreto, F es una expresión atómica (es decir, expresión delimitada por comillas simples) donde cada letra de la frase se oculta mediante el carácter _ a excepción de las que han sido descubiertas.
%	Si no había un juego iniciado, el panel actual no de de tipo final, el o la concursante aún no ha elegido ninguna letra, la frase F no se ajusta con la frase proporcionada mediante la llamada a panel_final_inicial/1 (es decir, no contiene el mismo número de palabras con el mismo número de letras casa una) o bien no descubre las letras elegidas, entonces la llamada finaliza en error.
panel_final_definitivo(F) :-
    \+ juego_iniciado, !, throw('Error. No hay ningún juego iniciado.').
panel_final_definitivo(_) :-
    \+ panel_actual(final, _, _, _), !, throw('Error. El panel actual no es de tipo final.').
panel_final_definitivo(_) :-
    \+ panel_estado(esperando_letras_jugador), \+ panel_estado(letras_elegidas), !,
    throw('Error. Llamada inválida: ejecute primero panel_final_inicial/1.').
panel_final_definitivo(F) :-
    panel_actual(final, Pista, FraseOriginal, _),
    letras_base_final(Base),
    de_frase_a_oculto(FraseOriginal, Base, F_Inicial),
    atom_chars(F, CharsF),
    atom_chars(FraseOriginal, CharsOrig),
    atom_chars(F_Inicial, CharsInicial),
    obtener_nuevas_letras(CharsOrig, CharsInicial, CharsF, Base, NuevasJugador),
    contar_tipos(NuevasJugador, CountC, CountV),
    ( CountC =:= 4, CountV =:= 1 ->
        append(Base, NuevasJugador, TodasLasLetras),
        retractall(panel_actual(final, _, _, _)),
        assertz(panel_actual(final, Pista, FraseOriginal, TodasLasLetras)),
        retractall(panel_estado(_)), assertz(panel_estado(letras_elegidas)),
        writeln('Modo Automático: Letras validadas con éxito (4C, 1V).')
    ;
        throw('Error. F debe descubrir exactamente 4 consonantes y 1 vocal distintas.')
    ).


% =========================================================================
% CARGA Y TRATAMIENTO DE FICHEROS DE TEXTO (PANELES)
% =========================================================================

% Auxiliar robusto de limpieza de espacios y saltos de línea para soportar múltiples palabras
trim_string(String, Cleaned) :-
    string_chars(String, Chars),
    exclude(is_newline, Chars, NoNewlines),
    trim_leading(NoNewlines, LeadingCleaned),
    reverse(LeadingCleaned, Reversed),
    trim_leading(Reversed, TrailingCleaned),
    reverse(TrailingCleaned, FinalChars),
    string_chars(Cleaned, FinalChars).

is_newline('\r').
is_newline('\n').

trim_leading([' '|T], R) :- !, trim_leading(T, R).
trim_leading(['\t'|T], R) :- !, trim_leading(T, R).
trim_leading(L, L).

cargar_paneles :-
    retractall(panel(_,_)),
    FicheroGeneral = 'Paneles/paneles_generales.txt',
    FicheroTematico = 'Paneles/paneles_tematicos.txt',
    procesar_fichero_paneles(FicheroGeneral),
    procesar_fichero_paneles(FicheroTematico),
    retractall(paneles_cargados),
    assertz(paneles_cargados),
    writeln('¡Banco de paneles cargado con éxito en el sistema!').

procesar_fichero_paneles(Ruta) :-
    exists_file(Ruta), !,
    open(Ruta, read, Stream, [encoding(utf8)]),
    read_line_to_string(Stream, PrimeraLinea),
    leer_lineas_paneles(Stream, PrimeraLinea),
    close(Stream).
procesar_fichero_paneles(Ruta) :-
    write('Advertencia: No se ha encontrado el fichero en la ruta '), writeln(Ruta).

leer_lineas_paneles(_, end_of_file) :- !.
leer_lineas_paneles(Stream, Linea) :-
    sub_string(Linea, 0, 7, _, "PISTA: "), !,

    sub_string(Linea, 7, _, 0, PistaConEspacios),
    trim_string(PistaConEspacios, PistaClean),

    read_line_to_string(Stream, LineaFrase),

    ( sub_string(LineaFrase, 0, 8, _, "FRASE: ") ->

        sub_string(LineaFrase, 8, _, 0, FraseConEspacios),
        trim_string(FraseConEspacios, FraseClean),

        atom_string(PistaAtom, PistaClean),
        atom_string(FraseAtom, FraseClean),

        assertz(panel(PistaAtom, FraseAtom))

    ; true ),

    read_line_to_string(Stream, Siguiente),
    leer_lineas_paneles(Stream, Siguiente).

leer_lineas_paneles(Stream, _) :-
    read_line_to_string(Stream, Siguiente),
    leer_lineas_paneles(Stream, Siguiente).

seleccionar_panel :-
    findall(panel(Pista, Frase), panel(Pista, Frase), ListaPaneles),
    ( ListaPaneles == [] -> 
        throw('Error. No hay paneles cargados. Ejecuta cargar_paneles primero.')
    ; true ),
    random_member(panel(PistaElegida, FraseElegida), ListaPaneles),
    retractall(panel_actual(_, _, _, _)),
    assertz(panel_actual(normal, PistaElegida, FraseElegida, [])),
    retractall(panel_estado(_)), assertz(panel_estado(en_juego)),
    write('Panel seleccionado para la ronda: '), writeln(PistaElegida).