:-	module(wheel,
		[
			spin_wheel/3
		]
	).

%:-	use_module(library(pce)).

:-	dynamic	wheel_window/1,			% Image window reference 
			wheel_position/1.		% Wheel position: 0..355 (step 5)


%%% Wheel wedges

wheel_wedge(_,0,special(grand_prize_1)).
wheel_wedge(_,1,special(grand_prize_2)).
wheel_wedge(_,2,cash(150)).
wheel_wedge(_,3,special(loose_a_turn)).
wheel_wedge(_,4,cash(75)).
wheel_wedge(_,5,cash(50)).
wheel_wedge(_,6,cash(150)).
wheel_wedge(_,7,cash(75)).
wheel_wedge(_,8,special(double_letter)).
wheel_wedge(_,9,special(bankrupt)).
wheel_wedge(_,10,special(prize)).
wheel_wedge(_,11,cash(75)).
wheel_wedge(_,12,cash(100)).
wheel_wedge(standard,13,special(mistery)).
wheel_wedge(jackpot,13,special(jackpot)).
wheel_wedge(_,14,cash(75)).
wheel_wedge(_,15,special(loose_a_turn)).
wheel_wedge(_,16,special(take_it)).
wheel_wedge(_,17,special(wild_card)).
wheel_wedge(_,18,cash(50)).
wheel_wedge(_,19,cash(0)).
wheel_wedge(_,20,cash(25)).
wheel_wedge(_,21,special(bankrupt)).
wheel_wedge(_,22,special(extra_clue)).
wheel_wedge(_,23,cash(100)).


%%% Wheel images

wheel_image_path('Images').

get_wheel_path('standard',FP):-
		!,
		wheel_image_path(P),
		atomic_list_concat([P,'Standard_wheel','wheel_'],'/',FP).
get_wheel_path('jackpot',FP):-
		!,
		wheel_image_path(P),
		atomic_list_concat([P,'Jackpot_wheel','wheel_'],'/',FP).
get_wheel_path(T,_):-
		throw(get_wheel_path_error('Incorrect wheel type'(T))).


%%% Wheel actions

%%% spin_wheel(+W,+F,-L) always succeeds, spins the wheel W using force level F and unifies the list L with the 3 selected wedges when the wheel stops
%	Possible wheels: standard, jackpot
%	Possible force levels: 1..10 or random

spin_wheel(W,random,L):-
		!,
		random_between(1,10,F),
		spin_wheel(W,F,L).
spin_wheel(W,F,L):-
		member(W,[standard,jackpot]),
		integer(F),
		F >= 1,
		F =< 10,
		!,
%		calculate_spin_wheel(W,F,D,P),
%		get_selected_wedges(W,P,L),
%		display_spin_wheel(W,D).
		calculate_spin_wheel(W,F,P),
		get_selected_wedges(W,P,L).
spin_wheel(W,_,_):-
		\+ member(W,[standard,jackpot]),
		throw(spin_wheel_error(non_existing_wheel(W))).
spin_wheel(_,F,_):-
		(
			F < 1;
			F > 10
		),
		throw(spin_wheel_error(incorrect_power_level(F))).
spin_wheel(W,F,_):-
		throw(spin_wheel_error(unknown(W,F))).

/*
%%% calculate_spin_wheel(+W,+F,-D,-P) always succeeds and spins the wheel W using force level F, unifying the list D with pairs of the form (S,R) for each wheel position, where S is the time delay and R are the rotation degrees, and P with the last position of the wheel  

initial_waiting_time(0.5).
final_waiting_time(1.0).
push_delay(0.25).
initial_spin_delay(0.15).
total_spin_time(5.0).

calculate_spin_wheel(W,F,D,NWP):-
		get_wheel_path(W,P),
		get_wheel_position(WP),
		% Initial position
		initial_waiting_time(IWT),
		get_bitmap(P,WP,IB),
		D = [(IWT,IB)|RD],
		% Pushing positions
		calculate_push_spin_wheel(P,WP,F,RD,TD,PWP),
		% Spinning positions
		calculate_running_spin_wheel(P,PWP,F,TD,NTD,NWP),
		% Last position
		final_waiting_time(FWT),
		get_bitmap(P,NWP,NB),
		NTD = [(FWT,NB)],
		% Save wheel final position
		set_wheel_position(NWP).

calculate_push_spin_wheel(P,WP,F,D,TD,NWP):-
		D = [(T,B1),(T,B2),(T,B3)|TD],
		push_delay(PD),
		T is PD-(F/80),
		WP1 is WP,
		get_bitmap(P,WP1,B1),
		WP2 is (WP+5) mod 360,
		get_bitmap(P,WP2,B2),
		WP3 is (WP+10) mod 360,
		get_bitmap(P,WP3,B3),
		NWP is WP3.

calculate_running_spin_wheel(P,WP,F,D,TD,NWP):-
		initial_spin_delay(SD),
		random_between(0,5,R),
		S is (F*0.008)+(R/100),
		total_spin_time(ST),
		calculate_running_spin_wheel_positions(P,WP,SD,S,ST,D,TD,NWP).

calculate_running_spin_wheel_positions(_,WP,_,_,ST,TD,TD,WP):-
		ST < 0,
		!.
calculate_running_spin_wheel_positions(P,WP,PSD,S,ST,D,TD,NWP):-
		CWP is (WP+5) mod 360,
		SD is PSD-S,
		get_bitmap(P,CWP,B),
		D = [(SD,B)|RD],
		CSD is PSD+(SD/30),
		CST is ST-SD,
		calculate_running_spin_wheel_positions(P,CWP,CSD,S,CST,RD,TD,NWP).

get_bitmap(P,R,B):-
		atom_number(A,R),
		atomic_list_concat([P,A,'ccw.jpeg'],F),
		new(I,image(F)),
		new(B,bitmap(I)).
*/

%%% calculate_spin_wheel(+W,+F,-P) always succeeds and spins the wheel W using force level F, unifying P with the last position of the wheel  

initial_waiting_time(0.5).
final_waiting_time(1.0).
push_delay(0.25).
initial_spin_delay(0.15).
total_spin_time(5.0).

%calculate_spin_wheel(W,F,D,NWP):-
calculate_spin_wheel(W,F,NWP):-
		get_wheel_path(W,P),
		get_wheel_position(WP),
		% Initial position
		initial_waiting_time(IWT),
%		get_bitmap(P,WP,IB),
		IB = null,
%		D = [(IWT,IB)|RD],
		_ = [(IWT,IB)|RD],
		% Pushing positions
		calculate_push_spin_wheel(P,WP,F,RD,TD,PWP),
		% Spinning positions
		calculate_running_spin_wheel(P,PWP,F,TD,NTD,NWP),
		% Last position
		final_waiting_time(FWT),
%		get_bitmap(P,NWP,NB),
		NB = null,
		NTD = [(FWT,NB)],
		% Save wheel final position
		set_wheel_position(NWP).

%calculate_push_spin_wheel(P,WP,F,D,TD,NWP):-
calculate_push_spin_wheel(_,WP,F,D,TD,NWP):-
		D = [(T,B1),(T,B2),(T,B3)|TD],
		push_delay(PD),
		T is PD-(F/80),
%		WP1 is WP,
%		get_bitmap(P,WP1,B1),
		B1 = null,
%		WP2 is (WP+5) mod 360,
%		get_bitmap(P,WP2,B2),
		B2 = null,
		WP3 is (WP+10) mod 360,
%		get_bitmap(P,WP3,B3),
		B3 = null,
		NWP is WP3.

calculate_running_spin_wheel(P,WP,F,D,TD,NWP):-
		initial_spin_delay(SD),
		random_between(0,5,R),
		S is (F*0.008)+(R/100),
		total_spin_time(ST),
		calculate_running_spin_wheel_positions(P,WP,SD,S,ST,D,TD,NWP).

calculate_running_spin_wheel_positions(_,WP,_,_,ST,TD,TD,WP):-
		ST < 0,
		!.
calculate_running_spin_wheel_positions(P,WP,PSD,S,ST,D,TD,NWP):-
		CWP is (WP+5) mod 360,
		SD is PSD-S,
%		get_bitmap(P,CWP,B),
		B = null,
		D = [(SD,B)|RD],
		CSD is PSD+(SD/30),
		CST is ST-SD,
		calculate_running_spin_wheel_positions(P,CWP,CSD,S,CST,RD,TD,NWP).


%%% get_wheel_position(-P) always succeeds, and returns and deletes the current wheel position (if any)

get_wheel_position(P):-
		wheel_position(P),
		!,
		retract((wheel_position(P))).
get_wheel_position(0).

%%% set_wheel_position(+P) always succeeds and sets current wheel position to P

set_wheel_position(P):-
		assertz((wheel_position(P))).


%%% get_selected_wedges(+W,+P,-L) always succeeds and unifies the list L with the 3 selected wedges in the position P of the wheel W

get_selected_wedges(W,P,[SE1,SE2,SE3]):-
		(((P mod 15) =:= 0) ->
			(
				F = 0
			);
			(((P mod 15) =:= 0) ->
				(
					F = 355
				);
				(
					F = 5
				)
			)
		),
		WP1 is ((P+315+F) mod 360)//15,
		WP2 is ((P+F) mod 360)//15,
		WP3 is ((P+45+F) mod 360)//15,
		wheel_wedge(W,WP1,SE1),
		wheel_wedge(W,WP2,SE2),
		wheel_wedge(W,WP3,SE3),
		!.
get_selected_wedges(W,P,_):-
		throw(get_selected_wedges_error(W,P)).


display_spin_wheel(W,D):-
		((W = standard) ->
			(
				WT = 'La Prologta de la Suerte'
			);
			(
				WT = 'La Prologta de la Suerte: Jugamos por el bote'
			)
		),
		new(Window,picture(WT)),
		send(Window,size,size(875,875)),
		send(Window,open),
		maplist(display_wheel(Window),D),
		send(Window,destroy).

display_wheel(Window,(T,Bitmap)):-
		send(Window,display,Bitmap),
%		play_beep,
		sleep(T).

play_beep:-
		shell('echo -en "\a\r\033[K').

