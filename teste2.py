import requests
import psycopg2
import dotenv
from datetime import datetime

API_BASE_URL = "https://dadosabertos.camara.leg.br/api/v2"

# Carrega as variáveis do arquivo .env local
load_dotenv()


# cofig das credenciais do bd postegree

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT")
}

KEYWORDS = [
    "suinocultura", "suínos", "proteína animal", "rações animais", "sanidade", 
    "animais de produção", "genética suína", "granjas", "integração", 
    "agroindústria", "animais de interesse econômico", "avicultura", "aves", 
    "frango", "milho", "produtor rural", "trabalhador rural", "dejeto de animais", 
    "maus tratos", "rótulo", "gaiolas", "animais domésticos"
]

# função para buscar palavras chaves na ementa

def identificar_palavras_chave(ementa):
    if not ementa: return []
    ementa_lower = ementa.lower()
    return [kw for kw in KEYWORDS if kw.lower() in ementa_lower]

# cria a tabela no bd

def criar_tabela(cursor):
    """Cria a tabela no PostgreSQL se ela ainda não existir."""
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS staging_proposicoes_suinocultura (
            id_proposicao INT PRIMARY KEY,
            identificacao VARCHAR(50),
            ementa TEXT,
            autor VARCHAR(255),
            situacao_atual TEXT,
            orgao_atual VARCHAR(100),
            ultima_movimentacao TEXT,
            data_ultima_movimentacao TIMESTAMP,
            dias_sem_movimentacao NUMERIC,
            palavras_chave TEXT,
            link_direto TEXT,
            ano_referencia INT,
            data_extracao TIMESTAMP
        );
    """)

def buscar_todas_proposicoes_tema(cod_tema, ano):
    url = f"{API_BASE_URL}/proposicoes"
    params = {"codTema": cod_tema, "ano": ano, "itens": 100}
    todas_proposicoes = []
    
    while url:
        print(f"Buscando página para o ano {ano} | URL: {url}")
        response = requests.get(url, params=params if "?" not in url else None)
        response.raise_for_status()
        data = response.json()
        
        proposicoes = data.get("dados", [])
        todas_proposicoes.extend(proposicoes)
        
        links = data.get("links", [])
        url = next((link["href"] for link in links if link["rel"] == "next"), None)
        params = None 
        
    return todas_proposicoes

def executar_carga_postgres(anos):
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    # Garante que a tabela existe antes de inserir
    criar_tabela(cursor)
    conn.commit()

    total_inseridos = 0

    for ano in anos:
        print(f"\n--- Processando Ano Histórico no Postgres: {ano} ---")
        proposicoes = buscar_todas_proposicoes_tema(cod_tema=64, ano=ano)
        print(f"Total bruto encontrado no Tema 64 para {ano}: {len(proposicoes)}")

        for prop in proposicoes:
            ementa = prop.get("ementa", "")
            keywords = identificar_palavras_chave(ementa)
            
            if keywords:
                id_prop = prop["id"]
                detalhes = requests.get(f"{API_BASE_URL}/proposicoes/{id_prop}").json().get("dados", {})
                status = detalhes.get("statusProposicao", {})
                
                autor_str = "Autor não identificado"
                resp_autor = requests.get(f"{API_BASE_URL}/proposicoes/{id_prop}/autores")
                if resp_autor.status_code == 200 and resp_autor.json().get("dados"):
                    a = resp_autor.json()["dados"][0]
                    partido, uf = a.get("siglaPartido", ""), a.get("uf", "")
                    comp = f" ({partido}/{uf})" if partido and uf else ""
                    autor_str = f"{a.get('nome')}{comp}"
                
                data_hora = status.get("dataHora")
                dias_sem_mov = None
                if data_hora:
                    try:
                        dt_mov = datetime.strptime(data_hora[:10], "%Y-%m-%d")
                        dias_sem_mov = (datetime.now() - dt_mov).days
                    except ValueError:
                        pass

                # Comando SQL com UPSERT (Idempotência)
                sql_upsert = """
                    INSERT INTO staging_proposicoes_suinocultura (
                        id_proposicao, identificacao, ementa, autor, situacao_atual, 
                        orgao_atual, ultima_movimentacao, data_ultima_movimentacao, 
                        dias_sem_movimentacao, palavras_chave, link_direto, ano_referencia, data_extracao
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id_proposicao) DO UPDATE SET
                        identificacao = EXCLUDED.identificacao,
                        ementa = EXCLUDED.ementa,
                        autor = EXCLUDED.autor,
                        situacao_atual = EXCLUDED.situacao_atual,
                        orgao_atual = EXCLUDED.orgao_atual,
                        ultima_movimentacao = EXCLUDED.ultima_movimentacao,
                        data_ultima_movimentacao = EXCLUDED.data_ultima_movimentacao,
                        dias_sem_movimentacao = EXCLUDED.dias_sem_movimentacao,
                        palavras_chave = EXCLUDED.palavras_chave,
                        link_direto = EXCLUDED.link_direto,
                        data_extracao = EXCLUDED.data_extracao;
                """
                
                cursor.execute(sql_upsert, (
                    int(id_prop),
                    f"{prop['siglaTipo']} {prop['numero']}/{prop['ano']}",
                    str(ementa),
                    str(autor_str),
                    str(status.get("descricaoTramitacao", "")),
                    str(status.get("siglaOrgao", "")),
                    str(status.get("despacho", "")),
                    data_hora if data_hora else None,
                    float(dias_sem_mov) if dias_sem_mov is not None else None,
                    str(", ".join(keywords)),
                    f"https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao={id_prop}",
                    int(ano),
                    datetime.now()
                ))
                total_inseridos += 1

        # Salva o lote do ano no banco
        conn.commit()
        print(f"Ano {ano} processado e gravado no PostgreSQL com sucesso!")

    cursor.close()
    conn.close()
    print(f"\nCarga concluída! Total de registros salvos/atualizados: {total_inseridos}")

if __name__ == "__main__":
    anos_historico = [2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026]
    executar_carga_postgres(anos_historico)