:-	use_module('wheel_linux.pl',
		[
			spin_wheel/3
		]
	).


%%%
%%%	Ambos modos: manual y automático
%%%

% ver_opcion/1
%	La llamada ver_opcion(+O) muestra el valor establecido en el apartado de configuración O.
%	Si el apartado de configuración O no existe, la llamada finaliza en error.



% establecer_opcion/2
%	Si no hay ningún juego iniciado, la llamada establecer_opcion(+O,+V) establece el apartado de configuración O al valor V.
%	Si ya había un juego iniciado, el apartado de configuración O no existe o bien el valor V no se corresponde con el apartado de configuración O, entonces la llamada finaliza en error.



% mostrar_panel/0
%	Si hay un juego iniciado, la llamada mostrar_panel muestra la frase y la pista del panel, ocultando las letras no descubiertas hasta el momento.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.



% mostrar_turno/0
%	Si hay un juego iniciado, la llamada mostrar_turno muestra el color (y el nombre en el modo persona) del o la concursante que tiene el turno.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.



% mostrar_premios_acumulados/0
%	Si hay un juego iniciado, mostrar_premios_acumulados muestra el premio acumulado de cada concursante en el juego actual.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.



% mostrar_premios_provisionales/0
%	Si hay un juego iniciado, mostrar_premios_provisionales muestra el premio provisional de cada concursante en el panel actual.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.



% mostrar_gajos_acumulados/0
%	Si hay un juego iniciado, mostrar_gajos_acumulados muestra los gajos acumulados por cada concursante en el juego actual.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.



% mostrar_ruleta/0
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, mostrar_ruleta muestra el gajo en el que ha caído el o la concursante que tiene el turno.
%	Si no había un juego iniciado o bien el panel actual es de tipo Final, entonces la llamada finaliza en error.


% ver_historial/1
%	ver_historial(+C) muestra el historial del o la concursante C: número de juegos y de veces que ha accedido al Panel final, premio acumulado máximo y premio acumulado medio.



% ver_ranking/0
%	ver_ranking muestra dos listas de concursantes: la primera lista muestra junto a cada nombre de concursante su número de juegos y el porcentaje de juegos en el que ha accedido al Panel final, y está ordenada de manera descendente según el porcentaje de juegos en los que ha accedido al Panel final; la segunda lista muestra junto a cada nombre de concursante su premio acumulado máximo y medio, y está ordenado de manera descendente según su premio acumulado medio.




%%%
%%% Modo manual
%%%

% iniciar_juego/3
%	Si no hay ningún juego iniciado, iniciar_juego(+C1,+C2,+C3) inicia un nuevo juego y establece el nombre de los y las concursantes azul, roja y amarilla a C1, C2 y C3 (diferentes entre sí) respectivamente.
%	Si ya había un juego iniciado o bien alguno de los nombres C1, C2 o C3 se repite, entonces la llamada finaliza en error.



% lanzar_ruleta/0
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada lanzar_ruleta hace girar la ruleta.
%	Si no había un juego iniciado o el panel actual es de tipo final, entonces la llamada finaliza en error.



% elegir_consonante/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada elegir_consonante(+C) permite al o la concursante que tiene el turno elegir la consonante C.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien C no es una consonante, entonces la llamada finaliza en error.



% usar_gajo/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada usar_gajo(+G) permite al o la concursante que tiene el turno utilizar el gajo G, que puede ser el gajo especial  Me Lo Quedo o bien Doble Letra.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien el gajo elegido G no es ni Me Lo Quedo ni Doble Letra, entonces la llamada finaliza en error.



% usar_comodin/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada usar_comodin(+R) permite al o la concursante que tiene el turno decidir si utiliza el gajo especial Comodín o no.
%	En concreto, si R es Sí, entonces el gajo especial Comodín será utilizado.
%	Por el contrario, si R es No, entonces el gajo especial Comodín no se utilizará.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien R no es ni Sí ni No, entonces la llamada finaliza en error.



% comprar_vocal/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada comprar_vocal(+V) permite al o la concursante que tiene el turno comprar la vocal V.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien V no es una vocal, entonces la llamada finaliza en error.



% resolver_panel/1
%	Si hay un juego iniciado, la llamada resolver_panel(+F) permite resolver el panel leyendo la frase F al o la concursante que tiene el turno en el caso de paneles de tipo normal o con bote, o bien que ha accedido al Panel final.
%	Si no había un juego iniciado, entonces la llamada finaliza en error.



% elegir_letras/5
%	Si hay un juego iniciado y el panel actual es de tipo final, la llamada elegir_letras(+C₁,+C₂,+C₃,+C4,+V) permite al o la concursante que ha accedido al Panel final elegir las consonantes C₁, C₂, C₃ y C4, (todas diferentes entre sí) y la vocal V.
%	Si no había un juego iniciado, el panel actual no es de tipo final, C₁, C₂, C₃ o C4 no son consonantes o no son diferentes entre sí, o bien V no es una vocal, entonces la llamada finaliza en error.



% elegir_letra_extra/1
%	Si hay un juego iniciado, el panel actual es de tipo final, y el o la concursante que ha accedido al Panel final ha acumulado el gajo especial Ayuda Final, la llamada elegir_letra_extra(+L) permite al o la concursante elegir la letra L del tipo letra elegido aleatoriamente por el programa.
%	Si no había un juego iniciado, el panel actual no es de tipo final, el o la concursante no ha acumulado el gajo especial Ayuda Final o bien L no es ni una consonante ni una vocal, no es el tipo de letra elegido aleatoriamente por el programa o no es diferente a las letras elegidas anteriormente, entonces la llamada finaliza en error.




%%%
%%% Modo automático
%%%

% iniciar_panel/1
%	Si hay un juego iniciado, el panel actual es de tipo normal o con bote y el panel anterior acaba de ser resuelto o bien es el primer panel del juego, la llamada iniciar_panel(+F) indica en F el número de palabras y el número de letras de cada palabra en la frase del panel a resolver.
%	En concreto, F es una expresión atómica (es decir, expresión delimitada por comillas simples) donde cada letra de la frase se oculta mediante el carácter _.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien el panel anterior no acaba de ser resuelto ni es el primer panel del juego, entonces la llamada finaliza en error.



% gajo_ruleta/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada gajo_ruleta(+G) indica que el gajo en el que ha caído el o la concursante con el turno es G.
%	Si no había un juego iniciado, el panel actual es de tipo final o bien G no es un gajo válido de la ruleta actual, entonces la llamada finaliza en error.



% aparece_consonante/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada aparece_consonante(+R,+F) indica si la consonante elegida por el o la concursante actual aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En concreto, si R es Sí, entonces se indica que la consonante elegida si aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En ese caso, en F (de tipo expresión atómica; es decir, expresión delimitada por comilla simple) se indica el estado actual de la frase del panel tras descubrir la consonante elegida, ocultando mediante _ las letras de la frase del panel que aún no han sido descubiertas.
%	Si R es No, entonces se indica que la consonante elegida no aparece en la frase del panel o bien ya había sido descubierta anteriormente.
%	Si no había un juego iniciado, el panel actual es de tipo final, R no es ni Sí ni No, la frase F no se ajusta con la frase proporcionada al comienzo del panel (es decir, no contiene el mismo número de palabras con el mismo número de letras casa una) o bien no descubre la consonante elegida, entonces la llamada finaliza en error.



% aparece_vocal/1
%	Si hay un juego iniciado y el panel actual es de tipo normal o con bote, la llamada aparece_vocal(+R,+F) indica si la vocal comprada por el o la concursante actual aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En concreto, si R es Sí, entonces se indica que la vocal comprada si aparece en la frase del panel y no ha sido descubierta anteriormente.
%	En ese caso, en F (de tipo expresión atómica; es decir, expresión delimitada por comilla simple) se indica el estado actual de la frase del panel tras descubrir la vocal comprada, ocultando mediante _ las letras de la frase del panel que aún no han sido descubiertas.
%	Si R es No, entonces se indica que la vocal comprada no aparece en la frase del panel o bien ya había sido descubierta anteriormente.
%	Si no había un juego iniciado, el panel actual es de tipo final, R no es ni Sí ni No o bien la frase F no se ajusta con la frase proporcionada al comienzo del panel (es decir, no contiene el mismo número de palabras con el mismo número de letras casa una) o no descubre la vocal comprada, entonces la llamada finaliza en error.



% panel_correcto/1
%	Si hay un juego iniciado y ya se ha lanzado la ruleta en el caso de los paneles de tipo normal o con bote, o bien ya se han elegido las letras en el caso del Panel final, la llamada panel_correcto(+R) indica si la frase leída por el o la concursante que tiene el turno en el caso de paneles de tipo normal o con bote, o bien que ha accedido al Panel final es correcta o no.
%	En concreto, si R es Sí, entonces se indica que la frase es correcta.
%	Si R es No, entonces se indica que la frase no es correcta.
%	Si no había un juego iniciado, aún no se ha lanzado la ruleta en el caso de los paneles de tipo normal o con bote, aún no se han elegido las letras en el caso del Panel final o bien R no es ni Sí ni No, entonces la llamada finaliza en error.



% panel_final_inicial/1
%	Si hay un juego iniciado, el panel actual es de tipo final y el o la concursante que ha accedido al Panel final aún no ha elegido ninguna letra, la llamada panel_final_inicial(+F) indica en F el número de palabras y el número de letras de cada palabra en la frase del Panel final a resolver descubriendo las letras (3 consonantes y 1 vocal) que han sido elegidas aleatoriamente.
%	En concreto, F es una expresión atómica (es decir, expresión delimitada por comillas simples) donde cada letra de la frase se oculta mediante el carácter _ a excepción de las que han sido descubiertas.
%	Si no había un juego iniciado, el panel actual no de de tipo final o bien el o la concursante ya ha elegido alguna letra, entonces la llamada finaliza en error.



% panel_final_definitivo/1
%	Si hay un juego iniciado, el panel actual es de tipo final y el o la concursante que ha accedido al Panel final ya ha elegido sus letras (4 consonantes y 1 vocal, la llamada panel_final_definitivo(+F) indica en F el número de palabras y el número de letras de cada palabra en la frase del Panel final a resolver descubriendo todas las letras que han sido elegidas.
%	En concreto, F es una expresión atómica (es decir, expresión delimitada por comillas simples) donde cada letra de la frase se oculta mediante el carácter _ a excepción de las que han sido descubiertas.
%	Si no había un juego iniciado, el panel actual no de de tipo final, el o la concursante aún no ha elegido ninguna letra, la frase F no se ajusta con la frase proporcionada mediante la llamada a panel_final_inicial/1 (es decir, no contiene el mismo número de palabras con el mismo número de letras casa una) o bien no descubre las letras elegidas, entonces la llamada finaliza en error.




