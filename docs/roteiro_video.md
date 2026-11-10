# Roteiro do vídeo (até 10 min)

O enunciado pede: explicação da estratégia, demonstração e discussão das limitações.
Todos os membros precisam aparecer e saber explicar qualquer parte.

| Tempo | Quem | O que mostrar / falar |
| --- | --- | --- |
| 0:00–1:00 | Membro 1 | O problema: Pitfall é o Mundo do Wumpus 12 x 12. O agente não vê o mapa; só sente brisa (poço), passos (inimigo), palmas (teletransporte), brilho (ouro) e reflexo (energia). Objetivo: pegar os 3 ouros e voltar para [1,1] vivo, gastando poucas ações. |
| 1:00–2:30 | Membro 1 | Base de conhecimento (README, tabela "Base de conhecimento"): `memory`, `certeza`, `visitado`, `percepcao`. Mostrar no console `consult('main.pl').`, andar duas vezes e `show_mem.` para ver `.`, `!` e `?`. |
| 2:30–4:00 | Membro 2 | Inferência: casa OK quando há certeza e nenhum perigo; regra de diagnóstico da Aula 07.1 ("se sentiu brisa e só uma vizinha pode ter poço, o poço está nela"). Mostrar `deduz_perigos` e o poço ficando colorido na interface. |
| 4:00–5:30 | Membro 2 | Escolha da ação: sistema de ação-valor da Aula 07.2. Ler as regras de `acao/1` em ordem: ótimas (pegar), fugir, boas (casa OK nova), arriscadas, voltar e sair, último recurso. |
| 5:30–6:30 | Membro 3 | Planejamento: busca em largura (Aula 03) só por casas seguras; por que BFS e não A* (o destino é "a casa nova mais próxima", que não é conhecido de antemão; todo passo custa 1, então a BFS acha o menor caminho). Ponto amarelo = plano; borda verde = casa OK não visitada. |
| 6:30–8:30 | Membro 3 | Demonstração: `python gmap.py mapa_medio.pl` rodando sozinho até "SAIU DA CAVERNA" (3/3 ouros). Tecla M mostra o mapa real só para conferência. Depois `python rodar_testes.py` e a tabela de resultados. |
| 8:30–10:00 | Todos | Avaliação de risco e limitações (README, seção "Limitações"): chance aproximada não é probabilidade exata; teletransporte pode cair num poço; inimigo dá dano a cada ação na casa dele; o agente não minimiza giros no plano inteiro. |

## Perguntas prováveis

- **O agente olha o mapa real?** Não. `agente.pl` não usa `tile/3` nem `adjacentes/1`, e há um teste
  (`test_agente_nao_consulta_o_mapa_real`) que verifica isso. O mapa real só é usado pelo motor do
  professor para gerar as percepções e aplicar dano, e pelo `rodar_testes.py` para anotar a causa da morte.
- **Por que guardar `percepcao/3`?** É o TELL do KB-Agent (Aula 07.1): o agente lembra o que sentiu em cada
  casa. Sem isso não dá para aplicar a regra de diagnóstico em casas visitadas antes.
- **Por que BFS e não A*?** O A* precisa de um destino fixo para a heurística. Explorando, o destino é
  "qualquer casa OK nova", então a BFS acha a mais próxima direto. Com custo 1 por passo, a BFS é ótima
  em número de passos (tabela da Aula 03).
- **Quando o agente arrisca?** Só quando não há mais casa OK nova e ainda falta ouro. Ele aceita casas que
  podem ter teletransporte, ou inimigo se a energia for maior que 80 (não matam na hora nem tiram pontos) e casas que podem ter poço
  só se a chance estimada for menor que 20%. Sem nada aceitável, volta para [1,1] e sai.
- **Como a chance é estimada?** É a maior entre: perigos que faltam achar / casas desconhecidas
  (a priori) e 1/K para cada vizinha que sentiu o perigo sem explicação (K = casas que podem ser a causa).
- **O que mudou no código do professor?** Ver a tabela "Mudanças no código-base" do README.
