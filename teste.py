# %%

import pandas as pd
import requests
import json

# %%

url = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

response = requests.get(url)
data = response.json()

# %%

df = pd.DataFrame(data['dados'])

# %%

df.to_csv('teste.csv')

# %%

url = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'pagina': 1,
    'itens': 100
}

response = requests.get(url, params=params)
data = response.json()

df = pd.DataFrame(data['dados'])

len(df)

# %%

data['links'][1]['href']

# %%

url_pagina_2 = data['links'][1]['href']

response_2 = requests.get(url_pagina_2)

data_2 = response_2.json()

# %%

data_2['dados'][0]
# %%

params_1 = {
    'ano': 2025,
    'itens': 100,
    'pagina': 1,
    'ordenarPor': 'id',
    'ordem': 'ASC'
}

params_2 = {
    'ano': 2025,
    'itens': 100,
    'pagina': 2,
    'ordenarPor': 'id',
    'ordem': 'ASC'
}

params_ult = {
    'ano': 2025,
    'itens': 100,
    'pagina': 484,
    'ordenarPor': 'id',
    'ordem': 'ASC'
}

response_1 = requests.get(url, params=params_1)
data_1 = response_1.json()

response_2 = requests.get(url, params=params_2)
data_2 = response_2.json()

response_ult = requests.get(url, params=params_ult)
data_ult = response_ult.json()

# %%

params_filtro = {
    # 'dataApresentacaoInicio': '2016-12-01',
    # 'dataApresentacaoFim': '2016-12-31',
    'id': 2121642,
    'ano': 2016
    # 'numero': 2672
    # 'itens': 100,
    # 'ordenarPor': 'id',
    # 'ordem': 'ASC'
}
response_filtro = requests.get(url, params=params_filtro)
data_filtro = response_filtro.json()
data_filtro
# df_filtro = pd.DataFrame(data_filtro['dados'])

# data_filtro['links'][-1]


# %%

df_1 = pd.DataFrame(data_1['dados'])
df_2 = pd.DataFrame(data_2['dados'])
df_ult = pd.DataFrame(data_ult['dados'])

# %%

df_ult

# %%

sao_iguais = df_1['id'].isin(df_2['id'])
sao_iguais

# %%
df_2['id']

# %%
df_merge = df


# %%

data['links'][-1]

# %%

df['id'].nunique()
#%%

df_1 = pd.DataFrame(data_1['dados'])
df_1

# %%

url_temas = 'https://dadosabertos.camara.leg.br/api/v2/referencias/proposicoes/codTema'

response_temas = requests.get(url_temas)
data_temas = response_temas.json()

df_temas = pd.DataFrame(data_temas['dados'])
df_temas
# %%

# df_temas = df_temas.drop(columns=['sigla', 'descricao'])
# df_temas
df_temas.to_csv('lista_temas.csv', index=False, encoding='utf-8')
# %%

url = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'codTema': 64,
    'itens': 100,
    'rel': ''
}

response = requests.get(url, params=params)
data = response.json()

df = pd.DataFrame(data['dados'])
# %%

url_teste = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'codTema': 64,
    'itens': 100
}

response = requests.get(url_teste, params=params)
data = response.json()

data['links']

# df = pd.DataFrame(data['dados'])

# %%

url = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'codTema': 64,
    'pagina': 1,
    'itens': 100
}

response = requests.get(url, params=params)

data = response.json()

df = pd.DataFrame(data['dados'])
df


# %%

id_proposicao = df.iloc[0]['id']
id_proposicao

# %%

url_temas = f'https://dadosabertos.camara.leg.br/api/v2/proposicoes/{id_proposicao}/temas'

response_temas = requests.get(url_temas)

data_temas = response_temas.json()
data_temas

# %%

pd.DataFrame(data_temas['dados'])

# %%

url = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'codTema': 64,
    'itens': 100
    }

response = requests.get(url, params=params)
data = response.json()

# %%
lista_proposicoes = []
for item in data['dados']:
    lista_proposicoes.append(item['id'])

print(lista_proposicoes)
# df = pd.DataFrame(data['dados'])

# %%

urls = {
    'detalhes': 'https://dadosabertos.camara.leg.br/api/v2/proposicoes/{id}',
    'autores': 'https://dadosabertos.camara.leg.br/api/v2/proposicoes/{id}/autores',
    'temas': 'https://dadosabertos.camara.leg.br/api/v2/proposicoes/{id}/temas',
    'tramitacoes': 'https://dadosabertos.camara.leg.br/api/v2/proposicoes/{id}/tramitacoes'
}

id_teste = 497409

todos_os_dados = {}
todos_os_dfs = {}

for key, value in urls.items():
    url_formatada = value.format(id=id_teste)

    response = requests.get(url_formatada)

    if response.status_code == 200:
        json_data = response.json()
        dados_uteis = json_data.get('dados')
        todos_os_dados[key] = dados_uteis


        if isinstance(dados_uteis, dict):
            todos_os_dfs[key] = pd.DataFrame([dados_uteis])
        else:
            todos_os_dfs[key] = pd.DataFrame(dados_uteis)

        print(f'sucesso ao processar: {key}')

    else:
        print(f'Erro {response.status_code} ao acessar: {key}')

# %%

print(todos_os_dfs)
# %%

url_detalhes = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes/497409'

# %%
for url in urls:
    response = requests.get(url_detalhes)
    data_detalhes = response.json()

    df_detalhes = pd.DataFrame(data_detalhes['dados'])
    df_detalhes.to_csv('detalhes.csv', index=False)


# %%

url = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'codTema': 48,
    'itens': 100
    }

response = requests.get(url, params=params)
data = response.json()
data['links']

# %%

link_tema_48 = 'https://dadosabertos.camara.leg.br/api/v2/proposicoes'

params = {
    'codTema'
}