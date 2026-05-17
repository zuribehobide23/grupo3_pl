:- use_module('wheel_windows.pl',
        [
            spin_wheel/3
        ]
    ).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).

%% Dynamic state
:- dynamic(option/2).
:- dynamic(game_started/1).            % mode: manual | automatic
:- dynamic(players/3).                 % players(Blue,Red,Yellow)
:- dynamic(current_turn/1).            % blue | red | yellow
:- dynamic(panel_list/1).              % list of panels available
:- dynamic(panel_index/1).             % index of current panel in panel_list
:- dynamic(panel/4).                   % panel(Type, Phrase, Clue, Masked)
:- dynamic(panel_type/1).              % normal | jackpot | final
:- dynamic(provisional/3).             % provisional(blue,Red,Yellow)
:- dynamic(accumulated/3).             % accumulated(blue,Red,Yellow)
:- dynamic(accum_gajos/3).             % accumm_gajos(blue,List), etc stored as acc_gajos(Color,List)
:- dynamic(last_wedges/1).             % last_wedges([WedgeBlue,WedgeRed,WedgeYellow])
:- dynamic(last_wheel_type/1).         % standard | jackpot
:- dynamic(last_force/1).              % last force used
:- dynamic(revealed_letters/1).        % list of revealed letters for current panel
:- dynamic(final_attempts/2).          % final_attempts(Player,Remaining)
:- dynamic(history/1).                 % history(ListOfGames) each game: game(Players,Winner,FinalPrize,PanelsPlayed)

%% ---------------------------
%% Utilities: errors & checks
%% ---------------------------

error(no_game_started) :- throw(error(no_game_started)).
error(invalid_option) :- throw(error(invalid_option)).
error(invalid_call) :- throw(error(invalid_call)).
error(not_allowed) :- throw(error(not_allowed)).

must_game_started :-
    game_started(_), !.
must_game_started :- error(no_game_started).

is_consonant(C) :-
    atom_chars(C,[Ch]),
    char_type(Ch, alpha),
    \+ member(Ch, [a,e,i,o,u,'A','E','I','O','U']).

is_vowel(V) :-
    atom_chars(V,[Ch]),
    char_type(Ch, alpha),
    member(Ch, [a,e,i,o,u]).

color_index(blue,1).
color_index(red,2).
color_index(yellow,3).

%% ---------------------------
%% Loading panels from files
%% ---------------------------

load_panels :-
    % read both files and parse into list of panel(Clue,Phrase)
    PanelDir = 'Paneles',
    file_concat(PanelDir,'paneles_generales.txt',GFile),
    file_concat(PanelDir,'paneles_tematicos.txt',TFile),
    read_file_to_string(GFile, GS, []),
    read_file_to_string(TFile, TS, []),
    parse_panels(GS, GPanels),
    parse_panels(TS, TPanels),
    append(GPanels, TPanels, All),
    retractall(panel_list(_)),
    assertz(panel_list(All)).

file_concat(A,B,C) :- atomic_list_concat([A,B], '/', C).

parse_panels(Text, Panels) :-
    % Panels separated by blank lines; each panel has lines "PISTA: ..." and "FRASE: ..."
    split_string(Text, "\n\n", "\n\t ", Blocks),
    include(non_empty_string, Blocks, Blocks2),
    maplist(parse_block, Blocks2, Panels).

non_empty_string(S) :- string_codes(S, Cs), \+ all_whitespace(Cs).
all_whitespace([]).
all_whitespace([C|Cs]) :- char_type(C, space), all_whitespace(Cs).

parse_block(Block, panel(PhraseTrim, ClueTrim)) :-
    split_string(Block, "\n", "\t ", Lines),
    find_line_prefix(Lines, "PISTA:", Clue),
    find_line_prefix(Lines, "FRASE:", Phrase),
    string_trim(Clue, ClueTrim),
    string_trim(Phrase, PhraseTrim).

find_line_prefix([L|_], Prefix, Rest) :-
    sub_string(L, 0, _, _, Prefix),
    sub_string(L, _, _, 0, After),
    string_trim(After, Rest), !.
find_line_prefix([_|T], Prefix, Rest) :- find_line_prefix(T, Prefix, Rest).

string_trim(S, T) :- string_codes(S, Cs), trim_codes(Cs, Rs), string_codes(T, Rs).
trim_codes(Cs, Rs) :- drop_leading(Cs, A), drop_trailing(A, Rs).
drop_leading([C|Cs], R) :- char_type(C, space), !, drop_leading(Cs, R).
drop_leading(L, L).
drop_trailing(L, R) :- reverse(L, RL), drop_leading(RL, RR), reverse(RR, R).

%% ---------------------------
%% Options
%% ---------------------------

% ver_opcion(+O)
ver_opcion(O) :-
    option(O, V), !,
    format('~w = ~w~n', [O, V]).
ver_opcion(_) :- error(invalid_option).

% establecer_opcion(+O,+V)
establecer_opcion(O, V) :-
    \+ game_started(_), !,
    ( retractall(option(O,_)); true ),
    assertz(option(O,V)),
    format('Opción ~w establecida a ~w~n', [O,V]).
establecer_opcion(_,_) :- error(not_allowed).

%% ---------------------------
%% Mostrar estado
%% ---------------------------

mostrar_panel :-
    must_game_started,
    panel(_, Phrase, Clue, Masked),
    format('PISTA: ~w~n', [Clue]),
    format('PANEL: ~w~n', [Masked]).
mostrar_panel :- error(no_game_started).

mostrar_turno :-
    must_game_started,
    current_turn(Color),
    ( game_started(manual) ->
        players(B,R,Y),
        (Color = blue -> Name = B; Color = red -> Name = R; Color = yellow -> Name = Y),
        format('Turno: ~w (~w)~n', [Color, Name])
    ;
        format('Turno: ~w~n', [Color])
    ).
mostrar_turno :- error(no_game_started).

mostrar_premios_acumulados :-
    must_game_started,
    accumulated(B,R,Y),
    format('Acumulados: blue=~w, red=~w, yellow=~w~n', [B,R,Y]).
mostrar_premios_acumulados :- error(no_game_started).

mostrar_premios_provisionales :-
    must_game_started,
    provisional(B,R,Y),
    format('Provisionales: blue=~w, red=~w, yellow=~w~n', [B,R,Y]).
mostrar_premios_provisionales :- error(no_game_started).

mostrar_gajos_acumulados :-
    must_game_started,
    acc_gajos(blue,GB), acc_gajos(red,GR), acc_gajos(yellow,GY),
    format('Gajos acumulados: blue=~w~nred=~w~nyellow=~w~n', [GB,GR,GY]).
mostrar_gajos_acumulados :- error(no_game_started).

mostrar_ruleta :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    last_wedges(W),
    format('Gajos actuales: ~w~n', [W]).
mostrar_ruleta :- error(no_game_started).

%% ---------------------------
%% Historial y ranking (simplificado)
%% ---------------------------

ver_historial(C) :-
    % muestra número de juegos, veces en panel final, premio máximo y medio
    ( history(H) -> true ; H = [] ),
    include(game_has_player(C), H, Games),
    length(Games, NG),
    findall(Reached, (member(G,Games), G = game(_,Reached,_,_)), ReachedList),
    sum_list_bool(ReachedList, TimesFinal),
    findall(P, (member(game(Players,_,FinalPrize,_), H), player_in(Players,C), P = FinalPrize), Prizes),
    ( Prizes = [] -> Max = 0, Mean = 0 ; max_list(Prizes, Max), sum_list(Prizes, S), length(Prizes, L), Mean is S / L ),
    format('Historial ~w: juegos=~w, panel_final=~w, max=~w, medio=~2f~n', [C, NG, TimesFinal, Max, Mean]).

game_has_player(C, game(Players,Reached,_,_)) :- player_in(Players,C).
player_in([B,R,Y], C) :- (B = C ; R = C ; Y = C).

sum_list_bool(L, S) :- include(=(true), L, T), length(T, S).

ver_ranking :-
    ( history(H) -> true ; H = [] ),
    % First list: name, games, %access to final (descending)
    collect_players_stats(H, Stats),
    sort(2, @>=, Stats, ByFinalPerc),
    format('Ranking por porcentaje de acceso al Panel final:~n'),
    maplist(print_stat1, ByFinalPerc),
    format('Ranking por premio acumulado medio:~n'),
    sort(4, @>=, Stats, ByMean),
    maplist(print_stat2, ByMean).

collect_players_stats(H, Stats) :-
    findall(Name, (member(game([B,R,Y],_,_,_), H), (Name=B;Name=R;Name=Y)), NamesDup),
    sort(NamesDup, Names),
    maplist(player_stats(H), Names, Stats).

player_stats(H, Name, stat(Name, Games, PercFinal, MeanAccum)) :-
    include(game_has_player(Name), H, GamesList),
    length(GamesList, Games),
    findall(Reached, (member(game(Players,Reached,_,_), GamesList), player_in(Players,Name), Reached = Reached), ReachedList),
    ( Games = 0 -> PercFinal = 0 ; include(=(true), ReachedList, L), length(L, RF), PercFinal is (RF / Games) * 100 ),
    findall(A, (member(game(_,_,A,PlayersCount), H), % final prize stored in game as third arg
                 % if Name in that game, include A
                 true), AllPrizes),
    ( AllPrizes = [] -> MeanAccum = 0 ; sum_list(AllPrizes, S), length(AllPrizes, L), MeanAccum is S / L ).

print_stat1(stat(Name, Games, PercFinal, _)) :-
    format('~w: juegos=~w, %%panel_final=~2f~n', [Name, Games, PercFinal]).
print_stat2(stat(Name, _, _, Mean)) :-
    format('~w: premio medio=~2f~n', [Name, Mean]).

%% ---------------------------
%% Iniciar juego (modo manual)
%% ---------------------------

iniciar_juego(C1, C2, C3) :-
    ( game_started(_) -> error(not_allowed) ; true ),
    ( C1 == C2 ; C1 == C3 ; C2 == C3 ) -> error(invalid_call) ; true,
    % load panels
    load_panels,
    assertz(game_started(manual)),
    assertz(players(C1, C2, C3)),
    assertz(current_turn(blue)),
    assertz(panel_index(0)),
    assertz(provisional(0,0,0)),
    assertz(accumulated(0,0,0)),
    assertz(acc_gajos(blue,[])),
    assertz(acc_gajos(red,[])),
    assertz(acc_gajos(yellow,[])),
    assertz(last_wedges([none,none,none])),
    assertz(last_wheel_type(standard)),
    assertz(last_force(5)),
    format('Juego iniciado: blue=~w, red=~w, yellow=~w~n', [C1,C2,C3]),
    % start first panel automatically
    next_panel_setup.

next_panel_setup :-
    panel_list(List),
    panel_index(I),
    length(List, Len),
    ( I >= Len -> % no more panels -> prepare final
        prepare_final_panel
    ;
        NI is I + 1,
        retractall(panel_index(_)),
        assertz(panel_index(NI)),
        nth1(NI, List, panel(Phrase, Clue)),
        % default panel type: normal; if penultimate -> jackpot; if last -> final
        ( NI < Len -> Type = normal ; ( NI =:= Len -> Type = final ; Type = normal ) ),
        mask_phrase(Phrase, Masked, []),
        retractall(panel(_,_,_,_)),
        assertz(panel(Type, Phrase, Clue, Masked)),
        retractall(panel_type(_)),
        assertz(panel_type(Type)),
        retractall(revealed_letters(_)),
        assertz(revealed_letters([])),
        % reset provisional for panel
        retractall(provisional(_,_,_)),
        assertz(provisional(0,0,0)),
        format('Panel ~w cargado (tipo ~w).~n', [NI, Type])
    ).

prepare_final_panel :-
    % set panel_type(final) and leave phrase masked; final will be handled by panel_final_inicial/1
    panel_list(List),
    panel_index(I),
    nth1(I, List, panel(Phrase, Clue)),
    mask_phrase(Phrase, Masked, []),
    retractall(panel(_,_,_,_)),
    assertz(panel(final, Phrase, Clue, Masked)),
    retractall(panel_type(_)),
    assertz(panel_type(final)),
    retractall(revealed_letters(_)),
    assertz(revealed_letters([])),
    format('Panel final preparado.~n').

mask_phrase(Phrase, Masked, Revealed) :-
    % Phrase is a string; Masked is string with letters replaced by '_' except spaces and punctuation
    string_chars(Phrase, Chs),
    maplist(mask_char(Revealed), Chs, Mchs),
    string_chars(Masked, Mchs).

mask_char(Revealed, C, '_') :- char_type(C, alpha), \+ member(C, Revealed), !.
mask_char(_, C, C).

%% ---------------------------
%% Lanzar ruleta (manual)
%% ---------------------------

lanzar_ruleta :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    last_wheel_type(WT),
    last_force(F),
    spin_wheel(WT, F, Wedges),
    retractall(last_wedges(_)),
    assertz(last_wedges(Wedges)),
    retractall(last_force(_)),
    assertz(last_force(F)),
    format('Ruleta lanzada: ~w~n', [Wedges]).

%% ---------------------------
%% Elegir consonante (manual)
%% ---------------------------

elegir_consonante(C) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    ( atom(C) -> true ; error(invalid_call) ),
    ( is_consonant(C) -> true ; error(invalid_call) ),
    current_turn(Color),
    last_wedges(Wedges),
    color_index(Color,Idx),
    nth1(Idx, Wedges, Wedge),
    panel(_, Phrase, Clue, Masked),
    revealed_letters(RL),
    ( member(C, RL) -> % already revealed
        format('La consonante ~w ya estaba descubierta. Pierde turno.~n', [C]),
        next_turn
    ;
        % check occurrences
        string_chars(Phrase, Chs),
        include(=(C), Chs, OccList),
        length(OccList, Occ),
        ( Occ =:= 0 ->
            format('La consonante ~w no aparece. Pierde turno.~n', [C]),
            next_turn
        ;
            % appears: reveal all occurrences
            reveal_letter(C),
            % update provisional and possibly gajos
            handle_wedge_on_consonant(Color, Wedge, Occ),
            format('Consonante ~w aparece ~w veces. Premio provisional actualizado.~n', [C,Occ])
        )
    ).

reveal_letter(C) :-
    panel(Type, Phrase, Clue, Masked),
    string_chars(Phrase, Pchs),
    string_chars(Masked, Mchs),
    maplist(reveal_char(C), Pchs, Mchs, NewMchs),
    string_chars(NewMasked, NewMchs),
    retractall(panel(_,_,_,_)),
    assertz(panel(Type, Phrase, Clue, NewMasked)),
    revealed_letters(RL),
    retractall(revealed_letters(_)),
    assertz(revealed_letters([C|RL])).

reveal_char(C, P, M, P) :- P = C, !.
reveal_char(_, P, M, M).

handle_wedge_on_consonant(Color, cash(V), Occ) :-
    % increase provisional by V * Occ
    provisional(B,R,Y),
    ( Color = blue -> NB is B + V*Occ, NR = R, NY = Y ; Color = red -> NB = B, NR is R + V*Occ, NY = Y ; Color = yellow -> NB = B, NR = R, NY is Y + V*Occ ),
    retractall(provisional(_,_,_)),
    assertz(provisional(NB,NR,NY)).
handle_wedge_on_consonant(Color, prize, Occ) :-
    % accumulate prize gajo if not already
    acc_gajos(Color, L),
    ( member(prize, L) -> true ; retractall(acc_gajos(Color,_)), assertz(acc_gajos(Color, [prize|L])) ),
    handle_wedge_on_consonant(Color, cash(0), Occ).
handle_wedge_on_consonant(Color, grand_prize_1, Occ) :-
    acc_gajos(Color, L),
    ( member(grand_prize_1, L) -> true ; retractall(acc_gajos(Color,_)), assertz(acc_gajos(Color, [grand_prize_1|L])) ),
    handle_wedge_on_consonant(Color, cash(0), Occ).
handle_wedge_on_consonant(Color, grand_prize_2, Occ) :-
    acc_gajos(Color, L),
    ( member(grand_prize_2, L) -> true ; retractall(acc_gajos(Color,_)), assertz(acc_gajos(Color, [grand_prize_2|L])) ),
    handle_wedge_on_consonant(Color, cash(0), Occ).
handle_wedge_on_consonant(_, special(double_letter), Occ) :-
    % double letter: allow choosing another consonant (no automatic action here)
    format('Gajo Doble Letra: puede elegir otra consonante.~n').
handle_wedge_on_consonant(_, special(wild_card), _) :-
    format('Gajo Comodín: puede evitar perder turno si lo desea.~n').
handle_wedge_on_consonant(Color, special(bankrupt), _) :-
    % lose provisional
    provisional(B,R,Y),
    ( Color = blue -> NB = 0, NR = R, NY = Y ; Color = red -> NB = B, NR = 0, NY = Y ; Color = yellow -> NB = B, NR = R, NY = 0 ),
    retractall(provisional(_,_,_)),
    assertz(provisional(NB,NR,NY)),
    format('Quiebra: premio provisional perdido.~n').
handle_wedge_on_consonant(_, mistery, Occ) :-
    % mistery: choose random wedge among remaining 23 (simulate by random pick)
    random_between(1,23,R),
    format('Misterio: se elige aleatoriamente otro gajo (simulado: ~w).~n', [R]).
handle_wedge_on_consonant(_, jackpot, Occ) :-
    % jackpot wedge: handled in jackpot panel
    format('Bote: si resuelve en esta jugada, puede ganar el bote adicional.~n').
handle_wedge_on_consonant(_, _, _) :- true.

next_turn :-
    current_turn(C),
    ( C = blue -> NC = red ; C = red -> NC = yellow ; NC = blue ),
    retractall(current_turn(_)),
    assertz(current_turn(NC)),
    format('Turno pasa a ~w~n', [NC]).

%% ---------------------------
%% Usar gajo (Me Lo Quedo / Doble Letra)
%% ---------------------------

usar_gajo(take_it) :-
    must_game_started,
    current_turn(Color),
    acc_gajos(Color, L),
    ( member(take_it, L) -> true ; error(invalid_call) ),
    % choose a victim: for simplicity choose next player
    ( Color = blue -> Victim = red ; Color = red -> Victim = yellow ; Victim = blue ),
    % transfer provisional and gajos
    provisional(B,R,Y),
    ( Color = blue -> PB = B ; Color = red -> PB = R ; PB = Y ),
    ( Victim = blue -> PV = B ; Victim = red -> PV = R ; PV = Y ),
    NewPV = PB,
    NewPB = 0,
    % update provisional
    ( Color = blue -> NB = PB, NR = R, NY = Y ; Color = red -> NB = B, NR = PB, NY = Y ; NB = B, NR = R, NY = PB ),
    retractall(provisional(_,_,_)),
    assertz(provisional(NB,NR,NY)),
    % transfer gajos
    acc_gajos(Victim, LV), acc_gajos(Color, LC),
    retractall(acc_gajos(Victim,_)), retractall(acc_gajos(Color,_)),
    append(LC, LV, NewVictimGajos),
    assertz(acc_gajos(Victim, NewVictimGajos)),
    assertz(acc_gajos(Color, [])),
    format('Usado Me Lo Quedo: ~w se queda con los gajos y provisional de ~w.~n', [Color, Victim]).

usar_gajo(double_letter) :-
    must_game_started,
    current_turn(Color),
    acc_gajos(Color, L),
    ( member(double_letter, L) -> true ; error(invalid_call) ),
    % allow another consonant selection: no immediate effect here
    format('Usado Doble Letra: puede elegir otra consonante ahora.~n').

usar_gajo(_) :- error(invalid_call).

%% ---------------------------
%% Usar comodín (decisión Sí/No)
%% ---------------------------

usar_comodin(SiNo) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    ( SiNo = 'Sí' ; SiNo = 'No' ), !,
    ( SiNo = 'Sí' -> format('Comodín será utilizado si procede.~n') ; format('No se usa comodín.~n') ).
usar_comodin(_) :- error(invalid_call).

%% ---------------------------
%% Comprar vocal
%% ---------------------------

comprar_vocal(V) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    ( is_vowel(V) -> true ; error(invalid_call) ),
    current_turn(Color),
    provisional(B,R,Y),
    ( Color = blue -> P = B ; Color = red -> P = R ; P = Y ),
    ( P < 50 -> error(invalid_call) ; true ),
    % reduce provisional by 50
    ( Color = blue -> NB is B - 50, NR = R, NY = Y ; Color = red -> NB = B, NR is R - 50, NY = Y ; NB = B, NR = R, NY is Y - 50 ),
    retractall(provisional(_,_,_)),
    assertz(provisional(NB,NR,NY)),
    % reveal vowel if present
    panel(Type, Phrase, Clue, Masked),
    string_chars(Phrase, Pchs),
    include(=(V), Pchs, OccList),
    length(OccList, Occ),
    ( Occ =:= 0 ->
        format('Vocal ~w no aparece. Pierde turno.~n', [V]),
        next_turn
    ;
        reveal_letter(V),
        format('Vocal ~w aparece ~w veces. Premio provisional reducido 50€.~n', [V,Occ])
    ).

%% ---------------------------
%% Resolver panel
%% ---------------------------

resolver_panel(Guess) :-
    must_game_started,
    panel(_, Phrase, _, _),
    % normalize strings: remove extra spaces and compare case-insensitive
    normalize_space(atom(NG), Guess),
    normalize_space(atom(NP), Phrase),
    downcase_atom(NG, LG), downcase_atom(NP, LP),
    ( LG = LP ->
        % correct: add provisional to accumulated, handle extraordinary prizes
        current_turn(Color),
        provisional(B,R,Y),
        accumulated(AB,AR,AY),
        ( Color = blue -> NewAB is AB + B, NewAR = AR, NewAY = AY, FinalProv = B ; Color = red -> NewAB = AB, NewAR is AR + R, NewAY = AY, FinalProv = R ; NewAB = AB, NewAR = AR, NewAY is AY + Y, FinalProv = Y ),
        retractall(accumulated(_,_,_)),
        assertz(accumulated(NewAB,NewAR,NewAY)),
        % remove prize gajos if applicable and add extraordinary amounts
        acc_gajos(Color, Gs),
        ( member(prize, Gs) -> Extra1 = 300 ; Extra1 = 0 ),
        ( (member(grand_prize_1, Gs), member(grand_prize_2, Gs)) -> Extra2 = 600 ; Extra2 = 0 ),
        TotalExtra is Extra1 + Extra2,
        % update accumulated with extras
        ( Color = blue -> FinalAccum is NewAB + TotalExtra ; Color = red -> FinalAccum is NewAR + TotalExtra ; FinalAccum is NewAY + TotalExtra ),
        format('Panel resuelto correctamente por ~w. Premio provisional añadido: ~w. Extras: ~w~n', [Color, FinalProv, TotalExtra]),
        % clear provisional for all players
        retractall(provisional(_,_,_)), assertz(provisional(0,0,0)),
        % advance to next panel
        next_turn,
        next_panel_setup
    ;
        format('Respuesta incorrecta. Pierde turno.~n'),
        next_turn
    ).

%% ---------------------------
%% Panel final: elegir letras y resolver
%% ---------------------------

elegir_letras(C1,C2,C3,C4,V) :-
    must_game_started,
    panel_type(final),
    maplist(is_consonant, [C1,C2,C3,C4]),
    all_different([C1,C2,C3,C4]),
    is_vowel(V),
    % reveal chosen letters
    maplist(reveal_letter_if_present, [C1,C2,C3,C4,V]),
    % mark that player has chosen (we assume current_turn is the finalist)
    format('Letras elegidas: ~w,~w,~w,~w y vocal ~w~n', [C1,C2,C3,C4,V]).

reveal_letter_if_present(L) :-
    panel(_, Phrase, _, _),
    string_chars(Phrase, Chs),
    ( member(L, Chs) -> reveal_letter(L) ; true ).

elegir_letra_extra(L) :-
    must_game_started,
    panel_type(final),
    current_turn(Color),
    acc_gajos(Color, Gs),
    ( member(extra_clue, Gs) -> true ; error(invalid_call) ),
    ( is_consonant(L) ; is_vowel(L) ),
    reveal_letter_if_present(L),
    format('Letra extra elegida: ~w~n', [L]).

panel_final_inicial(F) :-
    must_game_started,
    panel_type(final),
    panel(final, Phrase, Clue, Masked),
    % choose 4 consonants and 1 vowel randomly from alphabet (but only reveal those present)
    random_consonants(4, Cs),
    random_vowel(V),
    maplist(reveal_letter_if_present, Cs),
    reveal_letter_if_present(V),
    panel(final, Phrase, Clue, NewMasked),
    F = NewMasked,
    format('Panel final inicial: ~w~n', [F]).

panel_final_definitivo(F) :-
    must_game_started,
    panel_type(final),
    panel(final, Phrase, Clue, Masked),
    % after player chooses letters, show definitive masked
    panel(final, Phrase, Clue, NewMasked),
    F = NewMasked,
    format('Panel final definitivo: ~w~n', [F]).

random_consonants(N, Cs) :-
    findall(C, (member(C, [b,c,d,f,g,h,j,k,l,m,n,p,q,r,s,t,v,w,x,y,z]), atom_string(C, _)), All),
    random_permutation(All, P),
    length(Cs, N),
    append(Cs, _, P).

random_vowel(V) :-
    random_member(V, [a,e,i,o,u]).

%% ---------------------------
%% Modo automático: iniciar_panel/1, gajo_ruleta/1, aparece_consonante/2, aparece_vocal/2, panel_correcto/1
%% ---------------------------

iniciar_panel(F) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    panel(_, Phrase, Clue, Masked),
    % F is an atomic expression where letters are '_' except spaces; we validate shape
    atom(F),
    string_chars(Phrase, Pchs),
    string_chars(F, Fchs),
    length(Pchs, L1), length(Fchs, L2),
    ( L1 =\= L2 -> error(invalid_call) ; true ),
    format('Panel iniciado (automático). Estado: ~w~n', [F]).

gajo_ruleta(G) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    % validate G is a valid wedge term
    valid_wedge(G),
    retractall(last_wedges(_)),
    % set wedge for current player only (simulate)
    current_turn(Color),
    color_index(Color,Idx),
    last_wedges(LW),
    nth1(Idx, LW, _, Rest),
    nth1(Idx, NewLW, G, LW), % replace
    retractall(last_wedges(_)),
    assertz(last_wedges(NewLW)),
    format('Gajo ruleta (automático) establecido: ~w~n', [G]).

valid_wedge(cash(V)) :- member(V, [0,25,50,75,100,150]).
valid_wedge(prize).
valid_wedge(grand_prize_1).
valid_wedge(grand_prize_2).
valid_wedge(loose_a_turn).
valid_wedge(bankrupt).
valid_wedge(wild_card).
valid_wedge(extra_clue).
valid_wedge(take_it).
valid_wedge(double_letter).
valid_wedge(mistery).
valid_wedge(jackpot).

aparece_consonante(R, F) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    ( R = 'Sí' ; R = 'No' ),
    ( atom(F) -> true ; error(invalid_call) ),
    format('aparece_consonante: ~w, estado: ~w~n', [R, F]).

aparece_vocal(R, F) :-
    must_game_started,
    panel_type(T),
    ( T = final -> error(invalid_call) ; true ),
    ( R = 'Sí' ; R = 'No' ),
    ( atom(F) -> true ; error(invalid_call) ),
    format('aparece_vocal: ~w, estado: ~w~n', [R, F]).

panel_correcto(R) :-
    must_game_started,
    ( R = 'Sí' ; R = 'No' ),
    format('panel_correcto: ~w~n', [R]).

%% ---------------------------
%% Helpers
%% ---------------------------

all_different(L) :- sort(L, S), length(L, N), length(S, N).

%% ---------------------------
%% Initialization defaults
%% ---------------------------

:- (   % try to load panels at module load time if possible
        catch(load_panels, _, fail)
    ; true ).

