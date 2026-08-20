import argparse

from tqdm import tqdm

import api_client as api
from db import get_connection
from load_bronze import carregar_proposicao_bronze

TEMAS = [64, 48]  # Agricultura, Pecuária, Pesca e Extrativismo / Meio Ambiente e Desenvolvimento Sustentável


def coletar_ids_unicos(temas):
    ids_vistos = set()
    ids_ordenados = []
    for cod_tema in temas:
        print(f"Listando proposições do tema {cod_tema}...")
        proposicoes = api.listar_proposicoes_por_tema(cod_tema)
        print(f"  {len(proposicoes)} proposições encontradas no tema {cod_tema}")
        for prop in proposicoes:
            id_prop = prop["id"]
            if id_prop not in ids_vistos:
                ids_vistos.add(id_prop)
                ids_ordenados.append(id_prop)
    return ids_ordenados


def executar_carga_bronze(limit=None):
    ids = coletar_ids_unicos(TEMAS)
    print(f"Total de IDs únicos (temas {TEMAS}): {len(ids)}")

    if limit is not None:
        ids = ids[:limit]
        print(f"Modo de teste: limitando a {len(ids)} proposições")

    ok_count = 0
    erro_count = 0

    with get_connection() as conn:
        for id_prop in tqdm(ids, desc="Carga bronze", unit="proposição"):
            resultado = carregar_proposicao_bronze(conn, id_prop)
            for tabela, status in resultado.items():
                if status == "ok":
                    ok_count += 1
                else:
                    erro_count += 1
                    tqdm.write(f"  ! proposição {id_prop} / {tabela}: {status}")

    print(f"\nCarga concluída. Endpoints ok: {ok_count} | Endpoints com erro: {erro_count}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Carga histórica da camada bronze")
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Limita a quantidade de proposições processadas (uso para teste)",
    )
    args = parser.parse_args()
    executar_carga_bronze(limit=args.limit)
