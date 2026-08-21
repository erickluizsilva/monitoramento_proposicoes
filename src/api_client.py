import time

import requests

from config import API_BASE_URL

REQUEST_TIMEOUT = 15
SLEEP_BETWEEN_CALLS = 0.5
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 2  # segundos: 2, 4, 8...


def _get(url, params=None):
    last_error = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = requests.get(url, params=params, timeout=REQUEST_TIMEOUT)
            if response.status_code == 200:
                return response.json()
            if response.status_code == 429 or response.status_code >= 500:
                last_error = f"HTTP {response.status_code}"
            else:
                response.raise_for_status()
        except requests.RequestException as exc:
            last_error = str(exc)

        if attempt < MAX_RETRIES:
            time.sleep(RETRY_BACKOFF_BASE * attempt)

    raise RuntimeError(f"Falha ao chamar {url} após {MAX_RETRIES} tentativas: {last_error}")


def listar_proposicoes_por_tema(cod_tema, itens=100):
    """Retorna todas as proposições de um tema, seguindo a paginação via links.

    Faz uma pausa entre páginas para não sobrecarregar a API.
    """
    url = f"{API_BASE_URL}/proposicoes"
    params = {"codTema": cod_tema, "itens": itens, "ordenarPor": "id", "ordem": "ASC"}

    proposicoes = []
    while url:
        data = _get(url, params=params)
        proposicoes.extend(data.get("dados", []))

        links = data.get("links", [])
        url = next((link["href"] for link in links if link["rel"] == "next"), None)
        params = None  # a partir da 2a página, a URL do link já traz os query params

        if url:
            time.sleep(SLEEP_BETWEEN_CALLS)

    return proposicoes


def buscar_detalhes(id_proposicao):
    data = _get(f"{API_BASE_URL}/proposicoes/{id_proposicao}")
    return data.get("dados")


def buscar_autores(id_proposicao):
    data = _get(f"{API_BASE_URL}/proposicoes/{id_proposicao}/autores")
    return data.get("dados")


def buscar_temas(id_proposicao):
    data = _get(f"{API_BASE_URL}/proposicoes/{id_proposicao}/temas")
    return data.get("dados")


def buscar_tramitacoes(id_proposicao):
    data = _get(f"{API_BASE_URL}/proposicoes/{id_proposicao}/tramitacoes")
    return data.get("dados")


def buscar_deputado(id_deputado):
    data = _get(f"{API_BASE_URL}/deputados/{id_deputado}")
    return data.get("dados")
