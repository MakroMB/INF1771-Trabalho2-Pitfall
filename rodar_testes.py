"""Roda o agente sem interface e registra pontuação, ouro, sobrevivência e ações.

Uso:
    python rodar_testes.py                    # os 3 mapas fornecidos, 30 execuções cada
    python rodar_testes.py mapa_facil.pl      # só um mapa
    python rodar_testes.py --aleatorios 200   # também 200 mapas sorteados com os mesmos elementos
    python rodar_testes.py --risco palmas passos   # muda os perigos que o agente aceita arriscar
"""

import argparse
import csv
import os
import random
from pathlib import Path
from statistics import mean

from pyswip import Prolog

PASTA = Path(__file__).resolve().parent
MAPAS = ["mapa_facil.pl", "mapa_medio.pl", "mapa_dificil.pl"]
# Teletransporte e dano dos inimigos são sorteados: cada execução usa uma semente.
EXECUCOES = 30
# Evita laço infinito caso o agente fique preso.
LIMITE_ACOES = 1000
SAIDA = PASTA / "resultados"
PASTA_ALEATORIOS = SAIDA / "mapas_aleatorios"
# Elementos do enunciado: 2 d, 2 D, 8 poços, 3 ouros, 4 teletransportes e 3 itens de energia.
ELEMENTOS = "dd" + "DD" + "P" * 8 + "O" * 3 + "T" * 4 + "U" * 3


def valor(prolog, consulta):
    """Primeiro valor de X na consulta, ou None se ela falhar."""
    respostas = list(prolog.query(consulta))
    return respostas[0]["X"] if respostas else None


def jogar(prolog, mapa, semente):
    """Uma partida completa: o mesmo ciclo percepção-decisão-ação do gmap.py."""
    list(prolog.query(f"carrega_mapa('{mapa}')"))
    list(prolog.query(f"set_random(seed({semente}))"))
    list(prolog.query("atualiza_obs, verifica_player"))
    acoes = 0
    while acoes < LIMITE_ACOES:
        if valor(prolog, "posicao(_,_,X)") == "morto" or list(prolog.query("saiu")):
            break
        acao = valor(prolog, "executa_acao(X)")
        list(prolog.query(acao))
        list(prolog.query("atualiza_obs, verifica_player"))
        acoes += 1

    if valor(prolog, "posicao(_,_,X)") == "morto":
        # Só para o relatório: o que matou o agente (o agente nunca vê tile/3).
        causa = valor(prolog, "posicao(A,B,_), tile(A,B,X)")
        resultado = "morreu (poço)" if causa == "P" else "morreu (inimigo)"
    elif list(prolog.query("saiu")):
        resultado = "saiu"
    else:
        resultado = "limite de ações"
    return {
        "mapa": mapa,
        "semente": semente,
        "pontuacao": valor(prolog, "pontuacao(X)"),
        "ouros": valor(prolog, "ouros(X)"),
        "energia": valor(prolog, "energia(X)"),
        "acoes": acoes,
        "resultado": resultado,
    }


def gerar_mapa(caminho, semente):
    """Mapa 12 x 12 com os elementos do enunciado em casas sorteadas; [1,1] fica livre."""
    sorteio = random.Random(semente)
    casas = [(x, y) for x in range(1, 13) for y in range(1, 13) if (x, y) != (1, 1)]
    conteudo = dict(zip(sorteio.sample(casas, len(ELEMENTOS)), ELEMENTOS))
    linhas = [":-dynamic tile/3.", "map_size(12,12)."]
    for y in range(12, 0, -1):
        for x in range(1, 13):
            linhas.append(f"tile({x},{y},'{conteudo.get((x, y), '')}').")
    caminho.write_text("\n".join(linhas) + "\n", encoding="utf-8")


def linha_resumo(nome, partidas):
    pontos = [p["pontuacao"] for p in partidas]
    n = len(partidas)
    vivos = sum(not p["resultado"].startswith("morreu") for p in partidas)
    completos = sum(p["resultado"] == "saiu" and p["ouros"] == 3 for p in partidas)
    return (f"| {nome} | {n} | {mean(pontos):.1f} | {max(pontos)} | {min(pontos)} | "
            f"{mean(p['ouros'] for p in partidas):.2f} | {vivos}/{n} | {completos}/{n} | "
            f"{mean(p['acoes'] for p in partidas):.1f} |")


def resumo(partidas, aleatorias):
    """Uma linha por mapa fornecido e uma linha para todos os mapas aleatórios juntos."""
    linhas = ["| Mapa | Partidas | Pontuação média | Melhor | Pior | Ouro médio | Sobreviveu | Saiu com 3 ouros | Ações (média) |",
              "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for mapa in dict.fromkeys(p["mapa"] for p in partidas):
        linhas.append(linha_resumo(mapa, [p for p in partidas if p["mapa"] == mapa]))
    if aleatorias:
        linhas.append(linha_resumo(f"{len(aleatorias)} mapas aleatórios", aleatorias))
    return "\n".join(linhas)


def main():
    parser = argparse.ArgumentParser(description="Testes do agente lógico do Pitfall.")
    parser.add_argument("mapas", nargs="*", default=MAPAS, help="Arquivos de mapa (.pl).")
    parser.add_argument("--execucoes", type=int, default=EXECUCOES, help="Partidas por mapa fornecido.")
    parser.add_argument("--aleatorios", type=int, default=0, help="Quantos mapas aleatórios testar.")
    parser.add_argument("--risco", nargs="*", help="Perigos aceitos ao arriscar (brisa, passos, palmas).")
    parser.add_argument("--limite", type=float, help="Chance máxima aceita para os outros perigos.")
    args = parser.parse_args()

    os.chdir(PASTA)  # o Prolog procura os mapas na pasta atual
    prolog = Prolog()
    prolog.consult("main.pl")
    # Os dois parâmetros da política de risco podem ser trocados sem editar o agente.
    if args.risco is not None:
        list(prolog.query("retractall(aceita_risco(_))"))
        for perigo in args.risco:
            list(prolog.query(f"assert(aceita_risco({perigo}))"))
    if args.limite is not None:
        list(prolog.query(f"retractall(limite_chance(_)), assert(limite_chance({args.limite}))"))

    partidas = [jogar(prolog, mapa, semente) for mapa in args.mapas for semente in range(args.execucoes)]

    aleatorias = []
    if args.aleatorios:
        PASTA_ALEATORIOS.mkdir(parents=True, exist_ok=True)
        for i in range(args.aleatorios):
            caminho = PASTA_ALEATORIOS / f"aleatorio_{i:03}.pl"
            gerar_mapa(caminho, i)
            aleatorias.append(jogar(prolog, caminho.relative_to(PASTA).as_posix(), i))

    SAIDA.mkdir(exist_ok=True)
    with open(SAIDA / "partidas.csv", "w", newline="", encoding="utf-8") as arquivo:
        escritor = csv.DictWriter(arquivo, fieldnames=list(partidas[0]))
        escritor.writeheader()
        escritor.writerows(partidas + aleatorias)
    tabela = resumo(partidas, aleatorias)
    (SAIDA / "resumo.md").write_text(tabela + "\n", encoding="utf-8")
    print(tabela)
    print(f"\nDetalhes de cada partida: {SAIDA / 'partidas.csv'}")


if __name__ == "__main__":
    main()
