"""Testes do agente lógico. Rodar da pasta do projeto: ``python -m unittest discover tests``."""

import os
import unittest
from pathlib import Path

from pyswip import Prolog

RAIZ = Path(__file__).resolve().parents[1]
os.chdir(RAIZ)
prolog = Prolog()
prolog.consult("main.pl")


def consulta(texto):
    return list(prolog.query(texto))


def acao():
    return consulta("executa_acao(X)")[0]["X"]


def cenario(*fatos, posicao="posicao(1,1,norte)"):
    """Recomeça o jogo e coloca na base só os fatos dados (o agente não vê o mapa real)."""
    consulta("reset_game")
    consulta("retract(posicao(_,_,_))")
    consulta(f"assert({posicao})")
    for fato in fatos:
        consulta(f"assert({fato})")


def cenario_com_risco(energia, perigo="passos"):
    # O perigo conhecido ao norte explica a percepção; a casa a leste continua incerta.
    cenario("memory(1,1,[])", "certeza(1,1)",
            f"memory(1,2,[{perigo}])", "certeza(1,2)",
            f"memory(2,1,[{perigo}])", f"percepcao(1,1,[{perigo}])")
    consulta(f"retract(energia(_)), assert(energia({energia}))")


class AgenteTests(unittest.TestCase):
    def test_agente_nao_consulta_o_mapa_real(self):
        codigo = "\n".join(linha.split("%")[0] for linha in (RAIZ / "agente.pl").read_text(encoding="utf-8").splitlines())
        for proibido in ("tile(", "adjacentes(", "observacoes(", "adjacente("):
            self.assertNotIn(proibido, codigo)

    def test_pega_ouro_quando_sente_brilho(self):
        cenario("memory(1,1,[brilho])", "certeza(1,1)")
        self.assertEqual(acao(), "pegar")

    def test_so_pega_energia_se_nao_estiver_cheia(self):
        cenario("memory(1,1,[reflexo])", "certeza(1,1)", "memory(1,2,[])", "certeza(1,2)")
        self.assertNotEqual(acao(), "pegar")
        consulta("retract(energia(_)), assert(energia(60))")
        self.assertEqual(acao(), "pegar")

    def test_nao_arrisca_inimigo_com_energia_ate_80(self):
        for energia in (1, 40, 80):
            with self.subTest(energia=energia):
                cenario_com_risco(energia)
                chance = consulta("chance(2,1,passos,P)")[0]["P"]
                self.assertLess(chance, 0.2)
                self.assertFalse(consulta("arriscavel(2,1)"))
                self.assertEqual(acao(), "sair")

    def test_arrisca_inimigo_com_energia_acima_de_80(self):
        for energia in (81, 100):
            with self.subTest(energia=energia):
                cenario_com_risco(energia)
                self.assertTrue(consulta("arriscavel(2,1)"))
                self.assertEqual(acao(), "virar_direita")
                consulta("virar_direita")
                self.assertEqual(acao(), "andar")

    def test_chance_baixa_de_inimigo_tambem_exige_energia(self):
        consulta("retractall(aceita_risco(passos))")
        try:
            for energia, esperada in ((40, "sair"), (80, "sair"), (81, "virar_direita")):
                with self.subTest(energia=energia):
                    cenario_com_risco(energia)
                    self.assertEqual(acao(), esperada)
        finally:
            consulta("assert(aceita_risco(passos))")

    def test_energia_baixa_nao_bloqueia_teletransporte(self):
        cenario_com_risco(40, "palmas")
        self.assertTrue(consulta("arriscavel(2,1)"))
        self.assertEqual(acao(), "virar_direita")

    def test_regra_de_diagnostico_confirma_poco(self):
        # Em [2,1] sentiu brisa; [1,1] e [2,2] são seguras, então o poço só pode estar em [3,1].
        cenario("visitado(1,1)", "percepcao(2,1,[brisa])",
                "memory(2,2,[])", "certeza(2,2)", "memory(3,1,[brisa])",
                posicao="posicao(2,1,leste)")
        consulta("deduz_perigos")
        self.assertTrue(consulta("certeza(3,1)"))
        self.assertTrue(consulta("memory(3,1,[brisa])"))

    def test_planejamento_desvia_de_casa_incerta(self):
        # Olhando para leste, [2,1] pode ter poço; a única casa nova é [2,2], então o
        # caminho seguro passa por [1,2] (norte) mesmo custando um giro.
        cenario("percepcao(1,1,[brisa])", "memory(2,1,[brisa])", "visitado(1,2)",
                "memory(1,2,[])", "certeza(1,2)", "memory(2,2,[])", "certeza(2,2)",
                posicao="posicao(1,1,leste)")
        self.assertEqual(acao(), "virar_esquerda")
        planejado = {(c["X"], c["Y"]) for c in consulta("plano(X,Y)")}
        self.assertNotIn((2, 1), planejado)

    def test_com_tres_ouros_volta_e_sai(self):
        cenario("ouros(3)", "memory(1,2,[])", "certeza(1,2)", "memory(2,1,[])", "certeza(2,1)")
        consulta("retract(ouros(0))")
        self.assertEqual(acao(), "sair")
        cenario("memory(1,2,[])", "certeza(1,2)", "visitado(1,1)", posicao="posicao(1,2,norte)")
        consulta("retract(ouros(0)), assert(ouros(3))")
        self.assertIn(acao(), ("virar_esquerda", "virar_direita"))  # vira para voltar
        self.assertIn((1, 1), {(c["X"], c["Y"]) for c in consulta("plano(X,Y)")})

    def test_partidas_completas_nos_mapas_fornecidos(self):
        for mapa in ("mapa_facil.pl", "mapa_medio.pl", "mapa_dificil.pl"):
            with self.subTest(mapa=mapa):
                consulta(f"carrega_mapa('{mapa}')")
                consulta("set_random(seed(0))")
                consulta("atualiza_obs, verifica_player")
                for _ in range(1000):
                    if consulta("posicao(_,_,morto)") or consulta("saiu"):
                        break
                    consulta(acao())
                    consulta("atualiza_obs, verifica_player")
                self.assertTrue(consulta("saiu"))
                self.assertEqual(consulta("ouros(X)")[0]["X"], 3)


if __name__ == "__main__":
    unittest.main()
