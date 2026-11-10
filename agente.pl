%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Agente logico do Pitfall (Trabalho 2)
%%
%% O agente decide usando so o que ele sabe:
%%   memory/3, certeza/2, visitado/2, percepcao/3 -> base de conhecimento
%%   posicao/3, energia/1, ouros/1                -> estado do proprio agente
%%   map_size/2                                   -> tamanho do labirinto (12 x 12, dado no enunciado)
%% Ele NUNCA consulta tile/3 (o mapa real) nem adjacentes/1 (que le o mapa real).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:-dynamic plano/2.
:-dynamic aceita_risco/1.
:-dynamic limite_chance/1.

%quantos ouros existem no labirinto (enunciado)
total_ouros(3).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Conhecimento: o que e seguro, perigoso ou incerto
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%observacoes que indicam perigo
perigo(brisa).    %poco
perigo(passos).   %inimigo
perigo(palmas).   %teletransporte

tem_perigo(M) :- member(Z, M), perigo(Z).

%o que o agente percebe na casa em que esta (brilho = ouro, reflexo = energia)
percebe(Z) :- posicao(X,Y,_), memory(X,Y,M), member(Z,M).

%casa OK (Aula 07.2): o agente tem certeza de que nao ha perigo nela
seguro(X,Y) :- certeza(X,Y), memory(X,Y,M), \+ tem_perigo(M).
seguro(1,1).   %origem: o agente sempre comeca ali

%casa OK em que o agente ainda nao pisou
casa_nova(X,Y) :- seguro(X,Y), \+ visitado(X,Y), \+ posicao(X,Y,_).

%casa incerta: a memoria diz o que PODE ter nela, mas nao ha certeza
incerta(X,Y,M) :- memory(X,Y,M), \+ certeza(X,Y), \+ visitado(X,Y).

%a casa pode ter Z (com ou sem certeza)
pode_ter(X,Y,Z) :- memory(X,Y,M), member(Z,M).

%ja pegou todos os ouros do labirinto
pegou_todos :- ouros(N), total_ouros(N).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inferencia - regra de diagnostico (Aula 07.1):
%% Arejado(s) => existe r, Adjacente(r,s) e Poco(r).
%% Se a casa V sentiu Z e so UMA vizinha de V ainda pode ter Z, entao Z esta nela.
%% Vale para brisa (poco), passos (inimigo) e palmas (teletransporte).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%vizinhas de (VX,VY) que podem ser a causa de Z
candidatas(VX,VY,Z,L) :- findall((X,Y), (passo(VX,VY,_,X,Y), pode_ter(X,Y,Z)), L).

perigo_confirmado(X,Y,Z) :- percepcao(VX,VY,LO), member(Z,LO), perigo(Z),
                            candidatas(VX,VY,Z,[(X,Y)]), \+ certeza(X,Y).

deduz_perigos :- findall((X,Y,Z), perigo_confirmado(X,Y,Z), L), confirma_lista(L).

confirma_lista([]).
confirma_lista([(X,Y,Z)|T]) :- confirma(X,Y,Z), confirma_lista(T).

%cada casa tem uma coisa so: se tem Z, a memoria dela passa a ser [Z] com certeza
confirma(X,Y,_) :- certeza(X,Y), !.
confirma(X,Y,Z) :- retract(memory(X,Y,_)), assert(memory(X,Y,[Z])), assert(certeza(X,Y)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Avaliacao de risco
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%quantos perigos de cada tipo existem no labirinto (enunciado)
quantidade(brisa, 8).    %pocos
quantidade(passos, 4).   %inimigos (2 d e 2 D)
quantidade(palmas, 4).   %teletransportes

%casas que o agente ja conhece (visitou ou tem certeza do que tem)
conhecida(X,Y) :- certeza(X,Y).
conhecida(X,Y) :- visitado(X,Y).

%chance "a priori" de uma casa desconhecida ter Z: perigos que faltam achar / casas desconhecidas
a_priori(Z,P) :- quantidade(Z,Total),
                 findall((X,Y), (certeza(X,Y), pode_ter(X,Y,Z)), Achados), sort(Achados, A), length(A, NA),
                 findall((X,Y), conhecida(X,Y), Conhecidas), sort(Conhecidas, C), length(C, NC),
                 map_size(MX,MY), Desconhecidas is MX * MY - NC,
                 Faltam is Total - NA,
                 ((Faltam > 0, Desconhecidas > 0, P is Faltam / Desconhecidas, !); P = 0).

%Z sentido em (VX,VY) ja tem explicacao: uma vizinha tem Z com certeza
explicada(VX,VY,Z) :- passo(VX,VY,_,X,Y), certeza(X,Y), pode_ter(X,Y,Z).

%chance aproximada de (X,Y) ter Z: 1 se ja tem certeza; senao a maior entre a chance
%a priori e, para cada vizinha que sentiu Z sem explicacao, 1/K (K = casas que podem ser a causa)
chance(X,Y,Z,1) :- certeza(X,Y), pode_ter(X,Y,Z), !.
chance(X,Y,Z,P) :- findall(C, (passo(X,Y,_,VX,VY), percepcao(VX,VY,LO), member(Z,LO),
                               \+ explicada(VX,VY,Z), candidatas(VX,VY,Z,L),
                               length(L,K), C is 1/K), Cs),
                   a_priori(Z,P0),
                   maior([P0|Cs], P).

maior([X], X) :- !.
maior([H|T], M) :- maior(T, MT), ((H > MT, M = H, !); M = MT).

soma([], 0).
soma([H|T], S) :- soma(T, S1), S is S1 + H.

%perigos que o agente aceita correr quando acabam as casas seguras e ainda falta ouro.
%teletransporte nao mata sozinho (so leva para outro lugar); inimigo tira energia mas
%nao tira pontos; poco mata na hora e custa -1000, entao so e aceito com chance baixa.
aceita_risco(palmas).
aceita_risco(passos).

%chance maxima aceita para um perigo que nao esta na lista acima
limite_chance(0.2).

%inimigo so com energia para aguentar o maior dano (80)
risco_aceito(_,_,passos) :- aceita_risco(passos), energia(E), E > 80, !.
risco_aceito(_,_,Z) :- Z \= passos, aceita_risco(Z), !.
risco_aceito(X,Y,Z) :- chance(X,Y,Z,P), limite_chance(L), P < L.

%casa arriscada aceitavel: todo perigo que pode ter nela e aceitavel
arriscavel(X,Y) :- incerta(X,Y,M), \+ (member(Z,M), \+ risco_aceito(X,Y,Z)).

%risco total da casa: chance de cada perigo vezes o peso dele
peso(brisa, 10).
peso(passos, 3).
peso(palmas, 1).

%sort tira repeticoes (ex.: [brisa,brisa] quando o vizinho tinha dois pocos ao lado)
risco(X,Y,R) :- memory(X,Y,M0), sort(M0, M),
                findall(P, (member(Z,M), perigo(Z), peso(Z,W), chance(X,Y,Z,C), P is W * C), Ps),
                soma(Ps, R).

%entre as casas da lista, as de menor risco
menor_risco(Casas, Melhores) :- findall(R-(X,Y), (member((X,Y),Casas), risco(X,Y,R)), Rs),
                                sort(Rs, [Min-_|_]),
                                findall((X,Y), member(Min-(X,Y), Rs), Melhores).

%casas seguras que o agente alcanca andando (busca em largura sem alvo)
alcanca([], Vistas, Vistas).
alcanca([(X,Y)|Fila], Vistas, Todas) :-
    findall((NX,NY), (passo(X,Y,_,NX,NY), \+ member((NX,NY), Vistas), seguro(NX,NY)), Novas),
    append(Fila, Novas, Fila2), append(Vistas, Novas, Vistas2),
    alcanca(Fila2, Vistas2, Todas).

%casas que podem ser arriscadas: incertas ou teletransporte conhecido (saida de emergencia)
pode_arriscar(X,Y) :- incerta(X,Y,_).
pode_arriscar(X,Y) :- certeza(X,Y), pode_ter(X,Y,palmas).

%fronteira: casas arriscaveis vizinhas da regiao que o agente alcanca por casas seguras
fronteira(L) :- posicao(X,Y,_), alcanca([(X,Y)], [(X,Y)], Alcance),
                findall((A,B), (pode_arriscar(A,B), passo(A,B,_,C,D), member((C,D), Alcance)), L0),
                sort(L0, L).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Planejamento: busca em largura so por casas seguras
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%passo(X,Y,Dir,NX,NY): andar uma casa na direcao Dir sem sair do mapa
passo(X,Y,norte,X,NY) :- map_size(_,MAX_Y), Y < MAX_Y, NY is Y + 1.
passo(X,Y,sul,X,NY)   :- Y > 1, NY is Y - 1.
passo(X,Y,leste,NX,Y) :- map_size(MAX_X,_), X < MAX_X, NX is X + 1.
passo(X,Y,oeste,NX,Y) :- X > 1, NX is X - 1.

%ordem de expansao: primeiro seguir reto (economiza giros), depois as outras direcoes
direcoes(D, [D|Outras]) :- findall(O, (member(O, [norte,leste,sul,oeste]), O \= D), Outras).

%pode entrar no alvo (mesmo incerto) ou em qualquer casa segura;
%no modo "inimigo" tambem atravessa a casa de um inimigo conhecido
pode_entrar(X,Y,Alvos,_) :- member((X,Y), Alvos), !.
pode_entrar(X,Y,_,_) :- seguro(X,Y), !.
pode_entrar(X,Y,_,inimigo) :- certeza(X,Y), pode_ter(X,Y,passos), !.

%bfs(+Fila, +Vistas, +Alvos, +Modo, -Caminho) - busca em largura (Aula 03)
%Fila: lista de caminhos; cada caminho fica ao contrario [(X,Y,Dir) da ultima casa, ..., casa do agente]
%Vistas: casas ja colocadas na fila (evita estados repetidos)
bfs([[(X,Y,D)|Resto]|_], _, Alvos, _, [(X,Y,D)|Resto]) :- member((X,Y), Alvos), !.
bfs([[(X,Y,D)|Resto]|Fila], Vistas, Alvos, Modo, Caminho) :-
    direcoes(D, Ordem),
    findall((NX,NY,ND), (member(ND, Ordem), passo(X,Y,ND,NX,NY),
                         \+ member((NX,NY), Vistas), pode_entrar(NX,NY,Alvos,Modo)), Novos),
    findall([N,(X,Y,D)|Resto], member(N, Novos), NovosCaminhos),
    findall((NX,NY), member((NX,NY,_), Novos), NovasVistas),
    append(Fila, NovosCaminhos, Fila2),
    append(Vistas, NovasVistas, Vistas2),
    bfs(Fila2, Vistas2, Alvos, Modo, Caminho).

%giro que aproxima a direcao atual da desejada
a_direita(norte, leste).
a_direita(leste, sul).
a_direita(sul, oeste).
a_direita(oeste, norte).

acao_para(Dir, Dir, andar) :- !.
acao_para(Dir, Desejada, virar_direita) :- a_direita(Dir, Desejada), !.
acao_para(_, _, virar_esquerda).

%planeja ate o alvo mais proximo e devolve so a primeira acao do caminho
mover_para(Alvos, Acao) :- mover_para(Alvos, seguro, Acao).

mover_para(Alvos, Modo, Acao) :-
    Alvos \= [],
    posicao(X,Y,Dir),
    bfs([[(X,Y,Dir)]], [(X,Y)], Alvos, Modo, Invertido),
    reverse(Invertido, [_, (_,_,Proxima)|_]),
    guarda_plano(Invertido),
    acao_para(Dir, Proxima, Acao).

%guarda o caminho planejado para a interface desenhar
guarda_plano([]).
guarda_plano([(X,Y,_)|T]) :- assert(plano(X,Y)), guarda_plano(T).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Escolha da acao - sistema de acao-valor (Aula 07.2)
%% Primeiro o agente atualiza o que deduz; depois vale a primeira regra que der certo.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

executa_acao(X) :- retractall(plano(_,_)), deduz_perigos, acao(X), !.

%Otimas: pegar o ouro; pegar energia so se nao estiver cheia (o maximo e 100)
acao(pegar) :- percebe(brilho).
acao(pegar) :- percebe(reflexo), energia(E), E < 100.

%Fugir: em casa de inimigo o dano se repete a cada acao (ate ao virar), entao sai logo:
%primeiro tenta seguir em frente, sem girar; senao vai para a vizinha segura mais proxima
acao(andar) :- percebe(passos), posicao(PX,PY,D), passo(PX,PY,D,FX,FY),
               (seguro(FX,FY) ; arriscavel(FX,FY)).
acao(X) :- percebe(passos), posicao(PX,PY,_),
           findall((A,B), (passo(PX,PY,_,A,B), seguro(A,B)), L), mover_para(L, X).

%Energia baixa: volta para um item de energia que ja viu e deixou para depois
acao(X) :- energia(E), E =< 50,
           findall((A,B), (certeza(A,B), pode_ter(A,B,reflexo)), L), mover_para(L, X).

%Boas: ir para a casa segura ainda nao visitada mais proxima
acao(X) :- \+ pegou_todos, findall((A,B), casa_nova(A,B), L), mover_para(L, X).

%Arriscadas: sem casa segura e faltando ouro, vai para a casa aceitavel de menor risco
acao(X) :- \+ pegou_todos, fronteira(F), findall((A,B), (member((A,B),F), arriscavel(A,B)), L),
           menor_risco(L, Melhores), mover_para(Melhores, X).

%Objetivo final: estar em [1,1] e sair da caverna
acao(sair) :- posicao(1,1,_).
acao(X) :- mover_para([(1,1)], X).
%sem caminho seguro: atravessa um inimigo conhecido se a energia aguenta o dano maximo (80)
acao(X) :- energia(E), E > 80, mover_para([(1,1)], inimigo, X).

%Ultimo recurso (sem caminho seguro para casa): a casa incerta ou o teletransporte de menor risco
acao(X) :- fronteira(F), menor_risco(F, Melhores), mover_para(Melhores, X).

%Se nada der certo, chuta (sugestao do professor)
acao(X) :- L = [virar_esquerda, virar_direita, andar], random_between(1,3,I), nth1(I, L, X).
