# Cada entrada tem um rótulo legível (exibido nos resultados) e um termo, que é
# um fragmento de regex POSIX usado com o operador ~* do Postgres (case-insensitive).
# O prefixo \m ancora o INÍCIO de uma palavra: evita que um radical curto capture
# falsos positivos por estar embutido no meio de outra palavra (ex.: sem a âncora,
# o radical de "aves" bateria em "grave" e "Navega"; o radical de "ração" bateria
# em "tração" e "castração" — ambos confirmados na prática antes desta correção).
#
# Termos com variação de gênero/número usam radical (ex.: "suín" cobre suíno,
# suína, suínos, suínas). Frases de duas palavras usam ".*" entre as âncoras
# para cobrir a concordância plural de ambas (ex.: "produtor rural" /
# "produtores rurais").
KEYWORDS = [
    ("suinocultura", r"\msuinocultura"),
    ("suínos", r"\msuín"),
    ("proteína animal", r"\mproteín.*\manima"),
    ("rações animais", r"\mraç.*\manima"),
    ("sanidade", r"\msanidade"),
    ("animais de produção", r"\manima.*\mprodu"),
    ("genética suína", r"\mgenétic.*\msuín"),
    ("granjas", r"\mgranj"),
    ("integração", r"\mintegraç"),
    ("agroindústria", r"\magroindústr"),
    ("animais de interesse econômico", r"\manima.*\minteresse.*\meconômic"),
    ("avicultura", r"\mavicultura"),
    ("aves", r"\mave"),
    ("frango", r"\mfrang"),
    ("milho", r"\mmilho"),
    ("produtor rural", r"\mprodutor.*\mrura"),
    ("trabalhador rural", r"\mtrabalhador.*\mrura"),
    ("dejeto de animais", r"\mdejeto.*\manima"),
    ("maus tratos", r"\mmaus tratos"),
    ("rótulo", r"\mrótul"),
    ("gaiolas", r"\mgaiol"),
    ("animais domésticos", r"\manima.*\mdoméstic"),
]
