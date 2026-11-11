#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOPCONN.CH"

/*/{Protheus.doc} CI04R01
Relatório de Balanço de Estoque de Reagentes Controlados (MIT041).

Consolida, por Filial + Produto + Lote + Armazém, as informações regulatórias do
reagente (órgão fiscalizador, nº CAS, FDS, limite de estoque) com o balanço do
período: Saldo Inicial + Compras - Consumo - Perdas/Transferências = Saldo Final.

Base: MATR445 (estrutura TReport / query / CalcEst), MATR425 (filtro de validade
em SB8), MATR435 (CalcEstL por lote) e MATR330 (classificação por CF/CFOP).

Parâmetros (ParamBox - não depende de SX1; respostas salvas no perfil do usuário):
  MV_PAR01 Filial de                C  tam. filial   F3 SM0
  MV_PAR02 Filial até               C  tam. filial   F3 SM0 - o intervalo das duas
           perguntas é aplicado por BETWEEN nas consultas, respeitando o modo de
           compartilhamento de cada tabela (ver fFilCond)
  MV_PAR03 Período de               D
  MV_PAR04 Período até              D
  MV_PAR05 Grupo de Produto de      C  tam. BM_GRUPO F3 SBM
  MV_PAR06 Grupo de Produto até     C  tam. BM_GRUPO F3 SBM
  MV_PAR07 Produto/Reagente de      C  tam. B1_COD   F3 SB1
  MV_PAR08 Produto/Reagente até     C  tam. B1_COD   F3 SB1
  MV_PAR09 Validade de              D
  MV_PAR10 Validade até             D
  MV_PAR11 Órgãos Fiscalizadores    C  seleção múltipla via f_Opcoes: Polícia Civil
           (PC), Polícia Federal (PF), Exército (EX), ANVISA (AV) e NC - não controlado
           por nenhum deles. Padrão: os 4 órgãos marcados e NC desmarcado
  MV_PAR12 Listas ANVISA            C  seleção múltipla via f_Opcoes: as 12 listas da
           Portaria SVS/MS 344/98 (A1, A2, A3, B1, B2, C1 a C5, D1, D2). Padrão: todas
           marcadas. SÓ fica ativa para seleção quando a opção AV está marcada em
           MV_PAR11 (When U_CI04AVM): sem a ANVISA no grupo de órgãos a pergunta não
           tem efeito no recorte e por isso não é oferecida. Não tem opção NC - "não
           controlado" é o NC de MV_PAR11, que nega os órgãos e as listas de uma vez

TUDO EM OU: as opções marcadas nas duas perguntas formam uma única condição unida por
OR. Assim o relatório sai, numa mesma emissão, com PC + PF + EX + A1 + NC - os produtos
de cada órgão, os da lista A1 e os não controlados.

O conteúdo de cada pergunta é a concatenação dos códigos de 2 posições, com "**" nas
opções não marcadas (ex.: "PF**EX****" = Polícia Federal + Exército).

A ANVISA é o único órgão com detalhamento próprio (ver fValida):
  - AV marcada com todas, ou com nenhuma, das listas marcadas: vale a condição genérica
    da opção AV - campo da lista preenchido, ou seja, produto em qualquer lista da
    344/98 - e MV_PAR12 não entra na condição;
  - AV marcada com parte das listas marcadas: a opção AV sai do grupo de órgãos e as
    listas escolhidas tomam o seu lugar no OR, para que o recorte seja o pedido;
  - AV desmarcada: a ANVISA fica fora do recorte e MV_PAR12 é ignorada.

Flags de produto controlado na SB5 (configuração padrão TOTVS dos mapas):
  MV_PRODPF  -> campo da Polícia Federal  (ex.: B5_PRODPF)   - MATA950/MATR913
  MV_MTR949A -> campo do Exército         (ex.: B5_PRODEX)   - MATR949
  MV_MTR947A -> campo da Polícia Civil    (ex.: B5_PRODCON)  - MATR947
Opcionais (configuração PF): MV_DESCPR (nome comercial), MV_CODMAPA (cód. SIPROQUIM).

Lista da Portaria SVS/MS 344/98: campo PADRÃO SB1.B1_TPPROD (C 2), o mesmo que o
MATR924 (Livro de Registro Específico) usa para separar os livros - 'A1', 'A2', 'A3',
'B1', 'B2', 'C1' a 'C5', 'D1', 'D2'. É o único indicador de ANVISA usado pelo
relatório, tanto na opção AV dos órgãos quanto nas listas de MV_PAR12: a flag
B5_XANVISA continua fora do fonte.

As opções da pergunta MV_PAR12 vêm da tabela genérica SX5_LISTA da SX5 (a mesma do
B1_TPPROD): lista nova ou descrição alterada no cadastro aparece sem recompilar.
Só entram chaves com exatamente 2 posições, porque os códigos são concatenados em
largura fixa. Sem a tabela cadastrada, vale a relação fixa de fListFix.

Campos customizados (SB5): B5_XCAS e B5_XFDS.

Limite de estoque: BZ_EMAX (SBZ - Produto x Filial) e, na falta dele, B1_EMAX (SB1),
resolvidos por fLimEst. O limite deixou de ter campo customizado na SB5.

A coluna "Armazenamento / Storage" é o armazém do saldo (B8_LOCAL / B2_LOCAL), e não a
condição de guarda: o B5_XARMAZ deixou de ser consultado quando a coluna de armazém
recebeu esse rótulo.
Todos são opcionais: campo inexistente no dicionário é impresso como "   ". No filtro, a
opção cujo campo não existe é ignorada e registrada no diagnóstico - o resultado fica
mais restrito, nunca mais abrangente. Nos Órgãos Fiscalizadores, se NENHUMA opção
marcada tiver campo, a emissão é bloqueada: sem condição de órgão o relatório listaria
todo o estoque como se fosse controlado. Nas Listas ANVISA, o grupo apenas deixa de
entrar no OR.

Colunas e campos que saíram do layout continuam no fonte, comentados e marcados com
"[FORA DO LAYOUT]", para facilitar o retorno. São eles:
  PRODUTO (B1_COD)            substituído pelo Nome Comercial, que virou a âncora do total
  SUBLOTE (B8_NUMLOTE)        sem reposição
  LOTEFOR (B8_LOTEFOR)        sem reposição
  ARMAZEN (B5_XARMAZ)         o rótulo "Armazenamento" passou a designar o armazém
  NFDOC/NFSERIE/NFEMIS        consolidados na coluna de Notas Fiscais de Compra
  SLDSIS + CONFERE            checagem de divergência do saldo; nSis ainda é calculado
  Flag B5_XANVISA             a opção AV voltou ao grupo de órgãos, mas identificada
                              pelo campo da lista (B1_TPPROD); a flag segue fora
Cada ponto traz, no comentário, o que precisa ser reativado junto.

@type Function
@author Pablo Regis
@since  08/10/2026
@version 1.0
/*/

//-- Campos customizados (MIT041 - seção 7.2)
#DEFINE CPO_CAS      "B5_XNCAS"
#DEFINE CPO_FDS      "B5_XFDS"

//-- [FORA DO LAYOUT] Campos que saíram do relatório, mantidos para eventual retorno.
//-- Procure por "[FORA DO LAYOUT]" para achar todos os pontos envolvidos.
//-- B5_XANVISA: flag de produto controlado pela ANVISA. A opção AV está no grupo de
//--   órgãos (MV_PAR11), mas identificada pelo campo da lista (B1_TPPROD), que é o mesmo
//--   indicador de MV_PAR12 - ver fOrgaos para o que trocar se a flag voltar a valer.
// #DEFINE CPO_ANVISA   "B5_XANVISA"
//-- B5_XARMAZ: condição de guarda do reagente ("manter refrigerado", "ao abrigo de luz").
//--   Saiu quando o rótulo "Armazenamento" passou a designar o armazém (B8_LOCAL/B2_LOCAL).
// #DEFINE CPO_ARMAZ    "B5_XARMAZ"

//-- Lista da Portaria SVS/MS 344/98: campo PADRÃO da SB1 (C 2: "A1".."D2"), o mesmo que
//-- o MATR924 (Livro de Registro Específico) usa para classificar o produto por livro.
//-- O nome do campo pode ser trocado pelo parâmetro PAR_LISTA, como nos demais órgãos
#DEFINE CPO_LISTA    "B1_TPPROD"
#DEFINE TAB_LISTA    "SB1"
#DEFINE PAR_LISTA    "MV_XLISANV"
#DEFINE SX5_LISTA    "92"   //-- tabela genérica (SX5) com os códigos do B1_TPPROD

//-- Conteúdo impresso quando o campo não existe na SB5
#DEFINE CPO_VAZIO    "   "

//-- Regras de classificação (MIT041 - seção 6). PERDAS: pendência P1 com o cliente
#DEFINE CF_TRF_ENT   "1151/1152/1552/2151/2152/2552"
#DEFINE CF_TRF_SAI   "5151/5152/5156/5552/6151/6152/6156/6552"
#DEFINE D3_CF_TRANSF "RE4/DE4/RE7/DE7"
#DEFINE TM_PERDAS    "499/999"

//-- Grupos de seleção múltipla (f_Opcoes): órgãos em MV_PAR11, listas da 344/98 em MV_PAR12
#DEFINE ORG_TAM      2      //-- posições do código de cada opção
#DEFINE ORG_NC       "NC"   //-- "não controlado": última opção do grupo de órgãos, não é um órgão
#DEFINE ORG_AV       "AV"   //-- ANVISA: órgão cujo recorte pode ser detalhado pelas listas (MV_PAR12)
#DEFINE PAR_ORG      11
#DEFINE PAR_LIS      12
#DEFINE QTD_PARAM    12
#DEFINE MAX_DIAS     4095
#DEFINE NUM_PERG     "CI04R01"

//-- Posições do array de opções (mesma estrutura para órgãos e listas)
#DEFINE ORG_COD      1
#DEFINE ORG_DESC     2
#DEFINE ORG_CAMPO    3
#DEFINE ORG_PARAM    4
#DEFINE ORG_PREENCH  5   //-- .T.: controlado quando o campo está preenchido (qualquer conteúdo); .F.: flag = 'S'
#DEFINE ORG_CONTEU   6   //-- preenchido: controlado quando o campo tem este conteúdo (listas da 344/98)
#DEFINE ORG_ALIAS    7   //-- tabela do campo: "SB5" (flags dos órgãos) ou "SB1" (lista da 344/98)

/*/{Protheus.doc} CI04R01
Relatório de agentes controlados
@type function
@version 1.0 
@author Pablo Regis
@since 11/5/2026
/*/
User Function CI04R01()

Local oReport

Private mv_par01, mv_par02, mv_par03, mv_par04, mv_par05, mv_par06, mv_par07, mv_par08
Private mv_par09, mv_par10, mv_par11, mv_par12

If !fParams()
	Return
EndIf

oReport := ReportDef()
oReport:PrintDialog()

Return

/*/{Protheus.doc} fParams
Tela de parâmetros (ParamBox). Também acionada pelo botão "Parâmetros" do TReport.
@type Function
@author Pablo Regis
@since  21/10/2026
@return logical, .T. se confirmado
/*/
Static Function fParams()

Local aPergs  := {}
Local aRet    := {}
Local nTamFil := FWSizeFilial()
Local nTamGrp := TamSX3("BM_GRUPO")[1]
Local nTamPrd := TamSX3("B1_COD")[1]
Local lRet    := .F.
Local nI      := 0

aAdd(aPergs, {1, "Filial de"           , Space(nTamFil)          , "@!", "", "SM0", "", 50, .F.})
aAdd(aPergs, {1, "Filial até"          , Replicate("Z", nTamFil) , "@!", "", "SM0", "", 50, .T.})
aAdd(aPergs, {1, "Período de"          , FirstDate(dDataBase)    , ""  , "", ""   , "", 50, .T.})
aAdd(aPergs, {1, "Período até"         , LastDate(dDataBase)     , ""  , "", ""   , "", 50, .T.})
aAdd(aPergs, {1, "Grupo de Produto de" , Space(nTamGrp)          , "@!", "", "SBM", "", 50, .F.})
aAdd(aPergs, {1, "Grupo de Produto até", Replicate("Z", nTamGrp) , "@!", "", "SBM", "", 50, .T.})
aAdd(aPergs, {1, "Produto/Reagente de" , Space(nTamPrd)          , "@!", "", "SB1", "", 80, .F.})
aAdd(aPergs, {1, "Produto/Reagente até", Replicate("Z", nTamPrd) , "@!", "", "SB1", "", 80, .T.})
aAdd(aPergs, {1, "Validade de"         , StoD("19000101")        , ""  , "", ""   , "", 50, .T.})
aAdd(aPergs, {1, "Validade até"        , StoD("29991231")        , ""  , "", ""   , "", 50, .T.})
//-- Seleção múltipla pelo f_Opcoes: a validação de cada pergunta abre a tela de opções.
//-- O When de MV_PAR12 (CI04AVM) só libera as listas com a ANVISA marcada em MV_PAR11
aAdd(aPergs, {1, "Órgãos Fiscalizadores", fOrgDef(), "@!", "U_CI04ORG()", "", ""           , 100, .T.})
aAdd(aPergs, {1, "Listas ANVISA"        , fLisDef(), "@!", "U_CI04LIS()", "", "U_CI04AVM()", 100, .F.})

If ParamBox(aPergs, "Parâmetros - Reagentes Controlados", @aRet, , , .T., , , , NUM_PERG, .T., .T.)
	For nI := 1 To QTD_PARAM
		&("mv_par" + StrZero(nI, 2)) := aRet[nI]
	Next nI
	lRet := .T.
EndIf

FwFreeArray(aPergs)

Return lRet

/*/{Protheus.doc} CI04ORG
Validação da pergunta MV_PAR11 (Órgãos Fiscalizadores): abre a seleção múltipla com
o f_Opcoes.

O ParamBox macro-executa o conteúdo da validação, por isso esta rotina precisa ser
User Function (uma Static Function não é visível para o compilador de macros). O
ParamBox informa o nome da variável da pergunta ao TGet (cReadVar), de modo que
ReadVar() devolve "MV_PAR11" durante a validação.

@type Function
@author Pablo Regis
@since  05/11/2026
@return logical, .T. se ao menos uma opção ficou marcada
/*/
User Function CI04ORG()

Local aGrupo := fOrgaos()
//-- O NC nega todas as regras do grupo, ANVISA inclusive: é por ele que entram os
//-- produtos sem nenhum controle, lado a lado com os órgãos marcados (tudo em OU)
Local lRet   := fSelOpc(PAR_ORG, aGrupo, "Órgãos Fiscalizadores", .T., ;
                        "NÃO CONTROLADO (FORA DE TODOS OS ÓRGÃOS E LISTAS)")

FwFreeArray(aGrupo)

Return lRet

/*/{Protheus.doc} CI04LIS
Validação da pergunta MV_PAR12 (Listas ANVISA): abre a seleção múltipla com o
f_Opcoes. Vale aqui a mesma observação de CI04ORG sobre ser User Function.

Sem a ANVISA marcada em MV_PAR11 a pergunta não tem efeito no recorte, então a tela de
seleção não é aberta. O When da pergunta (CI04AVM) já impede o foco de chegar ao campo;
esta checagem cobre o caso de o campo ser alcançado antes de o When ser reavaliado.

O grupo das listas não tem opção NC e não é obrigatório: deixar tudo desmarcado vale
como "qualquer lista", o mesmo efeito de deixar todas marcadas.
@type Function
@author Pablo Regis
@since  05/11/2026
@return logical, .T. se o campo pode perder o foco
/*/
User Function CI04LIS()

Local aGrupo := {}
Local lRet   := .T.

If !U_CI04AVM()
	Help(NIL, NIL, NUM_PERG, NIL, "As Listas ANVISA só valem com a ANVISA marcada em Órgãos Fiscalizadores.", 1, 0, NIL, NIL, NIL, NIL, NIL, ;
	     {"Marque a opção AV - ANVISA na pergunta Órgãos Fiscalizadores."})
	Return .T.
EndIf

aGrupo := fListas()
lRet   := fSelOpc(PAR_LIS, aGrupo, "Listas ANVISA - Portaria 344/98", .F.)

FwFreeArray(aGrupo)

Return lRet

/*/{Protheus.doc} CI04AVM
.T. quando a ANVISA (opção AV) está marcada em MV_PAR11. É o When da pergunta MV_PAR12
- daí ser User Function, pelo mesmo motivo de CI04ORG - e também a guarda da validação
dessa pergunta.

Lê o conteúdo da pergunta direto, sem montar o grupo de órgãos: o When é avaliado a cada
tentativa de foco no campo, e remontar o grupo chamaria SuperGetMV e a validação dos
campos no dicionário a cada passagem.
@type Function
@author Pablo Regis
@since  11/11/2026
@return logical, .T. se a ANVISA está marcada em Órgãos Fiscalizadores
/*/
User Function CI04AVM()

Local cPar := ""

If Type("mv_par" + StrZero(PAR_ORG, 2)) == "C"
	cPar := &("mv_par" + StrZero(PAR_ORG, 2))
EndIf

Return fOrgPos(ORG_AV, cPar) > 0

/*/{Protheus.doc} fSelOpc
Abre o f_Opcoes para um grupo de opções e grava os códigos marcados na pergunta.
Usada pela validação das perguntas MV_PAR11 e MV_PAR12.
@type Function
@author Pablo Regis
@since  05/11/2026
@param nParam, numeric, número da pergunta (PAR_ORG ou PAR_LIS)
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param cTitulo, character, título da coluna de opções na tela do f_Opcoes
@param lObrig, logical, .T. exige ao menos uma opção marcada para sair do campo
@param cDescNC, character, descrição da opção NC na tela deste grupo (só nos órgãos)
@return logical, .T. se o campo pode perder o foco
/*/
Static Function fSelOpc(nParam, aGrupo, cTitulo, lObrig, cDescNC)

Local aOpcoes  := {}
Local cCodigos := ""
Local cVar     := AllTrim(ReadVar())
Local cSel     := ""
Local lRet     := .T.

//-- Fora do contexto do get (ReadVar vazio) a pergunta é endereçada pelo nome
If Empty(cVar)
	cVar := "MV_PAR" + StrZero(nParam, 2)
EndIf

aOpcoes := fOpcGrp(aGrupo, @cCodigos, cDescNC, fTemNC(nParam))

//-- Conteúdo atual: o f_Opcoes marca as opções já presentes na variável
If Type(cVar) == "C"
	cSel := fLimpaSel(&(cVar), cCodigos)
EndIf

If f_Opcoes(@cSel, cTitulo, aOpcoes, cCodigos, , , .F., ORG_TAM, Len(aOpcoes))
	&(cVar) := cSel
EndIf

//-- Grupo opcional: deixar tudo desmarcado é uma escolha válida (não filtra por ele)
If lObrig
	lRet := !Empty(fSelGrp(nParam, aGrupo))
	If !lRet
		Help(NIL, NIL, NUM_PERG, NIL, "Selecione ao menos uma opção em " + cTitulo + ".", 1, 0, NIL, NIL, NIL, NIL, NIL, ;
		     {"Marque uma das opções na tela de seleção."})
	EndIf
EndIf

FwFreeArray(aOpcoes)

Return lRet

/*/{Protheus.doc} fLimpaSel
Conteúdo da pergunta alinhado às opções atuais do grupo: cada código válido é mantido
na sua posição e as demais posições viram "**".

Sem isso, perfil gravado por uma versão anterior do relatório desalinharia a marcação
na tela do f_Opcoes - é o caso do NC que saiu do grupo das listas e do AV que entrou
no grupo dos órgãos.
@type Function
@author Pablo Regis
@since  11/11/2026
@param cSel, character, conteúdo atual da pergunta
@param cCodigos, character, concatenação dos códigos válidos (fOpcGrp)
@return character, conteúdo alinhado ao grupo
/*/
Static Function fLimpaSel(cSel, cCodigos)

Local cRet := ""
Local cCod := ""
Local nI   := 0

For nI := 1 To Len(cCodigos) Step ORG_TAM
	cCod := SubStr(cCodigos, nI, ORG_TAM)
	If fOrgPos(cCod, cSel) > 0
		cRet += cCod
	Else
		cRet += Replicate("*", ORG_TAM)
	EndIf
Next nI

Return cRet

/*/{Protheus.doc} ReportDef
Definição do layout (colunas bilíngues PT/EN).
/*/
Static Function ReportDef()

Local oReport
Local oSecao
Local oBreak
Local oBrkFil
Local cPictQtd := PesqPict("SB8", "B8_SALDO")
Local nTamQtd  := TamSX3("B8_SALDO")[1] + 4
Local cTitulo  := "Balanço de Estoque de Reagentes Controlados / Controlled Reagents Stock Balance"
Local cDescri  := "Consolida as informações regulatórias dos reagentes controlados com o balanço de " + ;
                  "estoque do período (saldo inicial, compras, consumo, perdas/transferências e saldo final)."

oReport := TReport():New(NUM_PERG, cTitulo, {|| fParams()}, {|oRep| ReportPrint(oRep)}, cDescri)
oReport:SetLandscape()
oReport:SetTotalInLine(.F.)

oSecao := TRSection():New(oReport, "Reagentes controlados / Controlled reagents", {"SB8", "SB1", "SB5"})
oSecao:SetTotalInLine(.F.)
oSecao:SetHeaderPage(.T.)

//-- Identificação
TRCell():New(oSecao, "LINHA"   , "", "Linha"                    + "/" + "Line"                       , "@E 999999", 6, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "FILIAL"  , "", "Filial"                   + "/" + "Branch"                     , "@!", FWSizeFilial())
TRCell():New(oSecao, "CONTROL" , "", "Controlado"               + "/" + "Controlled"                 , "@!", 12)

//-- Regulatório
TRCell():New(oSecao, "ORGAO"   , "", "Órgão Fiscalizador"       + "/" + "Surveillance Body"          , "@!", 30)
TRCell():New(oSecao, "LIMEST"  , "", "Limite de Estoque"        + "/" + "Stock Limit"                , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")

//-- Identificação do reagente
//-- [FORA DO LAYOUT] Código do produto (B1_COD). O produto passou a ser identificado pelo
//-- Nome Comercial, que também virou a âncora da quebra de total. Para voltar, reative
//-- aqui, o oItem["PRODUTO"] em fMontaItem, o nome em fImprime e o TRBreak abaixo.
TRCell():New(oSecao, "PRODUTO" , "", "Código"                   + "/" + "Code"                       , "@!", TamSX3("B1_COD")[1])
TRCell():New(oSecao, "CODMAPA" , "", "Código do Reagente"       + "/" + "Reagent Code"               , "@!", 18)
TRCell():New(oSecao, "NOMECOM" , "", "Nome Comercial (Rótulo)"  + "/" + "Commercial Name (Label)"    , "@!", 30)
TRCell():New(oSecao, "NOMEQUI" , "", "Nome Químico (Português)" + "/" + "Chemical Name (Portuguese)" , "@!", 30)
TRCell():New(oSecao, "CAS"     , "", "Número CAS"               + "/" + "CAS Number"                 , "@!", 12)
TRCell():New(oSecao, "FORMA"   , "", "Forma"                    + "/" + "Form"                       , "@!", 10)
TRCell():New(oSecao, "FABRIC"  , "", "Fabricante"               + "/" + "Manufacturer"               , "@!", 30)
TRCell():New(oSecao, "LOTE"    , "", "Lote"                     + "/" + "Batch"                      , "@!", TamSX3("B8_LOTECTL")[1])
//-- [FORA DO LAYOUT] Sub-lote e lote do fornecedor. Sem a coluna de sub-lote, produtos com
//-- rastro "S" geram uma linha por sub-lote que fica visualmente idêntica às demais.
// TRCell():New(oSecao, "SUBLOTE" , "", "Sub-Lote"                 + "/" + "Sub-Batch"                  , "@!", TamSX3("B8_NUMLOTE")[1])
// TRCell():New(oSecao, "LOTEFOR" , "", "Lote Fabric."             + "/" + "Mfr. Batch"                 , "@!", TamSX3("B8_LOTEFOR")[1])
TRCell():New(oSecao, "FDS"     , "", "FDS"                      + "/" + "SDS"                        , "@!", 20)
//-- "Armazenamento" é o armazém/depósito do saldo (B8_LOCAL / B2_LOCAL), não a
//-- condição de guarda: o rótulo mudou, a origem do dado continua sendo o depósito
TRCell():New(oSecao, "ARMAZEM" , "", "Armazenamento"            + "/" + "Storage"                    , "@!", 20)
//-- [FORA DO LAYOUT] Condição de guarda do reagente (B5_XARMAZ), que ocupava o rótulo
//-- "Armazenamento" antes de ele passar a designar o armazém. Se as duas informações
//-- precisarem conviver, reative com um rótulo próprio (ex.: "Condições de Armazenamento").
// TRCell():New(oSecao, "ARMAZEN" , "", "Condições de Armazenamento" + "/" + "Storage Conditions"     , "@!", 20)
TRCell():New(oSecao, "DTFABRIC", "", "Data de Fabricação"       + "/" + "Manufacture Date"           , "@D", 10)
TRCell():New(oSecao, "DTVALID" , "", "Data de Validade"         + "/" + "Expiry Date"                , "@D", 10)
TRCell():New(oSecao, "UM"      , "", "Unidade de Medida"        + "/" + "Unit of Measure"            , "@!", TamSX3("B1_UM")[1])

//-- Balanço do período
TRCell():New(oSecao, "SLDINI"  , "", "Estoque Inicial do Mês"   + "/" + "Initial Monthly Inventory"  , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "COMPRAS" , "", "Quantidade Comprada"      + "/" + "Quantity Purchased"         , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "NFCOMPRA", "", "Notas Fiscais de Compra (Número, Fornecedor e Data)" + "/" + ;
                                     "Purchase Invoices (Number, Vendor and Date)"                   , "@!", 50)
//-- [FORA DO LAYOUT] As três colunas separadas da NF, consolidadas na coluna acima
//-- (fNFCompra). O fornecedor não existia como coluna e só passou a sair na consolidada.
// TRCell():New(oSecao, "NFDOC"   , "", "NF Compra"                + "/" + "Purchase Inv."              , "@!", TamSX3("B8_DOC")[1])
// TRCell():New(oSecao, "NFSERIE" , "", "Série"                    + "/" + "Series"                     , "@!", TamSX3("B8_SERIE")[1])
// TRCell():New(oSecao, "NFEMIS"  , "", "Emissão NF"               + "/" + "Inv. Date"                  , "@D", 10)
TRCell():New(oSecao, "CONSUMO" , "", "Quantidade Utilizada no Mês" + "/" + "Quantity Used During the Month", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "PERDAS"  , "", "Perdas e Transferências"  + "/" + "Losses and Transfers"       , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "SLDFIM"  , "", "Estoque Final"            + "/" + "Final Inventory"            , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
//-- [FORA DO LAYOUT] Conferência do saldo: "Estoque Final" é o saldo CALCULADO
//-- (inicial + compras - consumo - perdas) e "Saldo Sistema" era o saldo real na data
//-- final; a coluna "Conferência" comparava os dois e acusava DIVERGENTE. O nSis continua
//-- sendo calculado em fMontaItem, então basta reativar estas duas colunas e os
//-- respectivos oItem[] para ter a checagem de volta.
// TRCell():New(oSecao, "SLDSIS"  , "", "Saldo Sistema"            + "/" + "System Balance"             , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
// TRCell():New(oSecao, "CONFERE" , "", "Conferência"              + "/" + "Check"                      , "@!", 10)

//-- Responsabilidade (preenchimento manual)
TRCell():New(oSecao, "RESP"    , "", "Responsável"              + "/" + "Responsible Person"         , "@!", 15)
TRCell():New(oSecao, "CONFER"  , "", "Conferente"               + "/" + "Checker"                    , "@!", 15)
TRCell():New(oSecao, "OBS"     , "", "Observações"              + "/" + "Notes"                      , "@!", 20)

//-- Totais por filial e por produto (unidades diferentes entre produtos: sem total geral).
//-- A filial é a quebra maior, acompanhando o ORDER BY FILIAL, PRODUTO das consultas: sem
//-- ela, um produto que fecha uma filial e abre a seguinte cairia num total único
oBrkFil := TRBreak():New(oSecao, oSecao:Cell("FILIAL"), "Total da filial / Branch total", .F.)
TRFunction():New(oSecao:Cell("SLDINI" ), , "SUM", oBrkFil, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("COMPRAS"), , "SUM", oBrkFil, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("CONSUMO"), , "SUM", oBrkFil, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("PERDAS" ), , "SUM", oBrkFil, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("SLDFIM" ), , "SUM", oBrkFil, , cPictQtd, , .F., .F.)

//-- O produto é identificado pelo código, que é exato, e não pelo nome comercial
// oBreak := TRBreak():New(oSecao, oSecao:Cell("NOMECOM"), "Total do produto / Product total", .F.)
oBreak := TRBreak():New(oSecao, oSecao:Cell("PRODUTO"), "Total do produto / Product total", .F.)
TRFunction():New(oSecao:Cell("SLDINI" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("COMPRAS"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("CONSUMO"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("PERDAS" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("SLDFIM" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)

Return oReport

/*/{Protheus.doc} ReportPrint
Valida os filtros, percorre as filiais do intervalo e imprime.
@type function
@version 1.0  
@author Pablo Regis
@since 11/5/2026
/*/
Static Function ReportPrint(oReport)

Local oSecao   := oReport:Section(1)
Local aSM0     := {}
Local aFiliais := {}
Local aOrgaos  := {}
Local aListas  := {}
Local oCfg     := Nil
Local cCondOrg := ""
Local cErro    := ""
Local cIgnora  := ""
Local cFilBak  := cFilAnt
Local oDiag    := JsonObject():New()
Local nI       := 0

oDiag["FILIAIS"  ] := ""
oDiag["LIDOS"    ] := 0
oDiag["DESCART"  ] := 0
oDiag["IMPRESSOS"] := 0
oDiag["EXEMPLO"  ] := ""
oDiag["ORGIGN"   ] := ""

aOrgaos := fOrgaos()
aListas := fListas()

If !fValida(aOrgaos, aListas, @cCondOrg, @cErro, @cIgnora)
	Help(NIL, NIL, NUM_PERG, NIL, cErro, 1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros do relatório."})
	oReport:CancelPrint()
	Return
EndIf

//-- Opções sem campo na SB5 ficam fora do filtro (apenas registrado no diagnóstico)
If Empty(cIgnora)
	oDiag["ORGIGN"] := "nenhum"
Else
	oDiag["ORGIGN"] := cIgnora
EndIf

//-- Registra sempre o que foi marcado e a condição gerada. Sem isso, divergência entre
//-- o que o usuário marcou e o que a query filtrou só aparece quando nada é impresso
FWLogMsg("INFO", , NUM_PERG, FunName(), "", "01", ;
         "MV_PAR11=[" + cValToChar(mv_par11) + "] MV_PAR12=[" + cValToChar(mv_par12) + "] " + ;
         "Campos: " + fCpoOrg(aOrgaos) + fCpoOrg(aListas) + ;
         "Fora do filtro: " + oDiag["ORGIGN"] + " | Condicao: " + cCondOrg, 0, 0, {})

aSM0 := FWLoadSM0()
For nI := 1 To Len(aSM0)
	If aSM0[nI][SM0_GRPEMP] == cEmpAnt .And. ;
	   aSM0[nI][SM0_CODFIL] >= mv_par01 .And. aSM0[nI][SM0_CODFIL] <= mv_par02
		aAdd(aFiliais, aSM0[nI][SM0_CODFIL])
	EndIf
Next nI

If Empty(aFiliais)
	Help(NIL, NIL, NUM_PERG, NIL, "Nenhuma filial encontrada no intervalo informado.", 1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros Filial de / Filial até."})
	oReport:CancelPrint()
	Return
EndIf

oCfg := fConfig()

oReport:SetTitle(oReport:Title() + " - " + DtoC(mv_par03) + " a " + DtoC(mv_par04))
//-- Duas consultas percorrem o mesmo intervalo de filiais (SB8 com rastro e SB2 sem rastro)
oReport:SetMeter(Len(aFiliais) * 2)
oSecao:Init()

//-- Filial de referência: usada apenas por registro de tabela compartilhada, que não
//-- traz filial própria. A filial de cada linha vem do registro, dentro de fMontaItem
cFilAnt := aFiliais[1]
fProcessa(oReport, oSecao, aOrgaos, aListas, cCondOrg, oCfg, oDiag)

oSecao:Finish()
cFilAnt := cFilBak

//-- Nada impresso: mostra onde os registros foram descartados
If oDiag["IMPRESSOS"] == 0 .And. !oReport:Cancel()
	Help(NIL, NIL, NUM_PERG, NIL, ;
	     "Nenhuma linha impressa." + CRLF + ;
	     "Filtro de filial aplicado: " + oDiag["FILIAIS"] + CRLF + ;
	     "Registros lidos nas consultas: " + cValToChar(oDiag["LIDOS"]) + CRLF + ;
	     "Descartados (sem saldo e sem movimento): " + cValToChar(oDiag["DESCART"]) + CRLF + ;
	     "Exemplo descartado: " + oDiag["EXEMPLO"] + CRLF + ;
	     "Grupos com opção fora do filtro (campo inexistente no dicionário): " + oDiag["ORGIGN"] + CRLF + ;
	     "Filtro de órgãos e listas: " + cCondOrg, ;
	     1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros e o cadastro dos produtos controlados."})
EndIf

FreeObj(oDiag)

FwFreeArray(aSM0)
FwFreeArray(aFiliais)

Return

/*/{Protheus.doc} fValida
Validação dos filtros obrigatórios (fluxo alternativo A1) e montagem da condição dos
dois grupos de seleção.

TUDO EM OU: cada grupo é resolvido por fCondGrp (opções do grupo unidas por OR) e as
duas condições também são unidas por OR. Assim PC, PF, EX, a lista A1 e os produtos não
controlados (NC) saem na mesma emissão.

A ANVISA é o único órgão com detalhamento próprio:
  - AV marcada com todas, ou com nenhuma, das listas marcadas: vale a condição genérica
    da opção AV (campo da lista preenchido = produto em qualquer lista da 344/98) e
    MV_PAR12 não entra na condição;
  - AV marcada com parte das listas marcadas: a opção AV sai do grupo de órgãos e as
    listas escolhidas tomam o seu lugar no OR, para que o recorte seja o pedido;
  - AV desmarcada: MV_PAR12 é ignorada.

Quando a retirada da AV esvazia a seleção de órgãos (só a ANVISA estava marcada), o
grupo de órgãos não entra na condição. Chamar fCondGrp com a seleção vazia devolveria
"1 = 1" e, dentro de um OR, isso traria todo o estoque.
@type Function
@author Pablo Regis
@since  21/10/2026
@param aOrgaos, array, grupo dos órgãos fiscalizadores (fOrgaos)
@param aListas, array, grupo das listas da ANVISA (fListas)
@param cCondOrg, character, retorna a condição SQL dos dois grupos (por referência)
@param cErro, character, retorna a mensagem de erro (por referência)
@param cIgnora, character, retorna os grupos com opção fora do filtro (por referência)
@return logical, .T. se os parâmetros são válidos
/*/
Static Function fValida(aOrgaos, aListas, cCondOrg, cErro, cIgnora)

Local aCond   := {}
Local cOrg    := fSelGrp(PAR_ORG, aOrgaos)
Local cLis    := fSelGrp(PAR_LIS, aListas)
Local cCndOrg := ""
Local cCndLis := ""
Local nLis    := Len(cLis) / ORG_TAM
Local lDetLis := .F.
Local lRet    := .T.

//-- As listas só detalham a ANVISA quando ela está marcada e a seleção é parcial:
//-- todas marcadas (ou nenhuma) equivale a "qualquer lista", que é a própria opção AV
lDetLis := fOrgPos(ORG_AV, cOrg) > 0 .And. nLis > 0 .And. nLis < Len(aListas)

Do Case
Case Empty(mv_par02)
	cErro := "Informe o parâmetro Filial até."
Case mv_par01 > mv_par02
	cErro := "Filial de maior que Filial até."
Case Empty(mv_par03) .Or. Empty(mv_par04)
	cErro := "Informe o Período de e o Período até."
Case mv_par03 > mv_par04
	cErro := "Período de maior que Período até."
Case (mv_par04 - mv_par03) > MAX_DIAS
	cErro := "O período não pode ultrapassar " + cValToChar(MAX_DIAS) + " dias."
Case Empty(mv_par06)
	cErro := "Informe o parâmetro Grupo de Produto até."
Case mv_par05 > mv_par06
	cErro := "Grupo de Produto de maior que Grupo de Produto até."
Case Empty(mv_par08)
	cErro := "Informe o parâmetro Produto/Reagente até."
Case mv_par07 > mv_par08
	cErro := "Produto/Reagente de maior que Produto/Reagente até."
Case Empty(mv_par09) .Or. Empty(mv_par10)
	cErro := "Informe a Validade de e a Validade até."
Case mv_par09 > mv_par10
	cErro := "Validade de maior que Validade até."
Case Empty(cOrg)
	cErro := "Selecione ao menos uma opção em Órgãos Fiscalizadores."
EndCase

lRet := Empty(cErro)

//-- ANVISA detalhada por lista: a opção AV dá lugar às listas marcadas
If lRet .And. lDetLis
	cOrg := fTiraOpc(cOrg, ORG_AV)
	lRet := fCondGrp(aListas, cLis, "Listas ANVISA", .F., .F., @cCndLis, @cErro, @cIgnora)
EndIf

If lRet .And. !Empty(cOrg)
	lRet := fCondGrp(aOrgaos, cOrg, "Órgãos Fiscalizadores", .T., .T., @cCndOrg, @cErro, @cIgnora)
EndIf

//-- Os dois grupos entram no mesmo OR; grupo sem condição aplicável não entra
If lRet
	If !Empty(cCndOrg)
		aAdd(aCond, cCndOrg)
	EndIf
	If !Empty(cCndLis)
		aAdd(aCond, cCndLis)
	EndIf
	If Empty(aCond)
		cErro := "Nenhuma opção marcada em Órgãos Fiscalizadores e Listas ANVISA tem campo " + ;
		         "correspondente no dicionário." + CRLF + ;
		         "Sem isso o relatório listaria todo o estoque no lugar do recorte pedido."
		lRet  := .F.
	Else
		cCondOrg := "(" + fJunta(aCond, " OR ") + ")"
	EndIf
EndIf

FwFreeArray(aCond)

Return lRet

/*/{Protheus.doc} fCpoOrg
Pares "código=campo" de um grupo, para o log de diagnóstico. Campo vazio significa
parâmetro não configurado ou campo inexistente no dicionário - ou seja, opção fora do filtro.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@return character, pares separados por espaço
/*/
Static Function fCpoOrg(aGrupo)

Local cRet := ""
Local nI   := 0

For nI := 1 To Len(aGrupo)
	cRet += aGrupo[nI][ORG_COD] + "="
	If Empty(aGrupo[nI][ORG_CAMPO])
		cRet += "<sem campo> "
	Else
		cRet += aGrupo[nI][ORG_ALIAS] + "." + AllTrim(aGrupo[nI][ORG_CAMPO]) + " "
	EndIf
Next nI

Return cRet

/*/{Protheus.doc} fCondGrp
Condição SQL de um grupo de opções: as opções marcadas são unidas por OR e a opção NC
(só o grupo de órgãos a tem) nega todas as regras do grupo, trazendo o produto que não
é controlado por nenhuma delas.

Grupo com nada marcado, ou com tudo marcado, não restringe: a condição vira "1 = 1".

Opção cujo campo não existe no dicionário sai da condição e o grupo é registrado em
cIgnora - o resultado fica mais restrito, nunca mais abrangente. Se nenhuma opção
marcada tiver campo, o critério é:
  - grupo obrigatório (lObrig = .T., os órgãos): aborta, porque "1 = 1" devolveria todo
    o estoque no lugar do recorte pedido;
  - grupo opcional (as listas, que entram em OR com os órgãos): devolve condição vazia e
    o grupo fica fora do OR. "1 = 1" aqui anularia o filtro inteiro.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param cSel, character, códigos marcados (fSelGrp)
@param cGrupo, character, nome do grupo para as mensagens
@param lObrig, logical, .T. aborta quando o recorte pedido não pode ser aplicado
@param lTemNC, logical, .T. se o grupo oferece a opção NC (ver fTemNC)
@param cCond, character, retorna a condição SQL do grupo (por referência)
@param cErro, character, retorna a mensagem de erro (por referência)
@param cIgnora, character, acumula os grupos com opção fora do filtro (por referência)
@return logical, .T. se a condição pôde ser montada
/*/
Static Function fCondGrp(aGrupo, cSel, cGrupo, lObrig, lTemNC, cCond, cErro, cIgnora)

Local aCond := {}
Local aNeg  := {}
Local cCod  := ""
Local nI    := 0
Local nPos  := 0
Local nSel  := Len(cSel) / ORG_TAM
Local nTot  := Len(aGrupo)
Local lIgn  := .F.
Local lRet  := .T.

//-- Total de opções da tela, para reconhecer a seleção completa
If lTemNC
	nTot += 1
EndIf

For nI := 1 To Len(cSel) Step ORG_TAM
	If !lRet
		Exit
	EndIf
	cCod := SubStr(cSel, nI, ORG_TAM)
	If cCod == ORG_NC
		//-- Fora do grupo: nenhuma das regras configuradas se aplica ao produto
		aNeg := {}
		For nPos := 1 To Len(aGrupo)
			If !Empty(aGrupo[nPos][ORG_CAMPO])
				aAdd(aNeg, fCondOrg(aGrupo[nPos], .F.))
			EndIf
		Next nPos
		If Empty(aNeg)
			lIgn := .T.
		Else
			aAdd(aCond, "(" + fJunta(aNeg, " AND ") + ")")
		EndIf
	Else
		nPos := aScan(aGrupo, {|x| x[ORG_COD] == cCod})
		If nPos == 0
			cErro := "Código inválido em " + cGrupo + ": " + cCod + "."
			lRet  := .F.
		ElseIf Empty(aGrupo[nPos][ORG_CAMPO])
			//-- Campo inexistente no dicionário (ou parâmetro vazio): a opção sai do filtro
			lIgn := .T.
		Else
			aAdd(aCond, fCondOrg(aGrupo[nPos], .T.))
		EndIf
	EndIf
Next nI

If lRet
	Do Case
	Case !Empty(aCond)
		cCond := "(" + fJunta(aCond, " OR ") + ")"
	Case Empty(cSel) .Or. nSel >= nTot
		//-- Nada marcado ou tudo marcado: não restringe nada
		cCond := "(1 = 1)"
	Case !lObrig
		//-- Nenhuma opção marcada tem campo: o grupo não contribui com o OR
		cCond := ""
	OtherWise
		cErro := "Nenhuma opção marcada em " + cGrupo + " tem campo correspondente no dicionário." + CRLF + ;
		         "Sem isso o relatório listaria todo o estoque no lugar do recorte pedido."
		lRet  := .F.
	EndCase
EndIf

If lIgn
	If Empty(cIgnora)
		cIgnora := cGrupo
	Else
		cIgnora += ", " + cGrupo
	EndIf
EndIf

FwFreeArray(aNeg)
FwFreeArray(aCond)

Return lRet

/*/{Protheus.doc} fProcessa
Processa o intervalo de filiais (MV_PAR01 a MV_PAR02) em duas consultas: produtos com
rastro de lote/sublote (SB8) e produtos sem rastro (SB2).

A filial de cada linha vem do próprio registro (B8_FILIAL / B2_FILIAL), e não de um laço
externo: é ela que alimenta o saldo, o limite e a busca dos cadastros em fMontaItem. O
recorte do intervalo fica com fFilCond, que respeita o compartilhamento de cada tabela.
@type Function
@author Pablo Regis
@since  10/11/2026
/*/
Static Function fProcessa(oReport, oSecao, aOrgaos, aListas, cCondOrg, oCfg, oDiag)

Local oMov     := fCarregaMov()
Local oCache   := JsonObject():New()
Local oItem    := Nil
Local cAlias   := GetNextAlias()
Local cQry     := ""
Local cChave   := ""
Local cChvAnt  := ""
Local cSubChv  := ""
Local cFilAtu  := ""
Local lSubLote := .F.

oDiag["FILIAIS"] += "[SB8: " + fFilCond("SB8", "B8_FILIAL") + "| SB2: " + fFilCond("SB2", "B2_FILIAL") + "] "

//-- 1) Produtos com rastro de lote/sublote: um registro por Filial + Produto + Armazém + Lote (+ Sub-Lote)
cQry := "SELECT SB8.B8_FILIAL FILIAL, SB8.B8_PRODUTO PRODUTO, SB8.B8_LOCAL ARMAZEM, "
cQry += "       SB8.B8_LOTECTL LOTE, SB8.B8_NUMLOTE SUBLOTE, "
cQry += "       SB8.B8_DTVALID DTVALID, SB8.B8_DFABRIC DTFABRIC, SB8.B8_LOTEFOR LOTEFOR, "
cQry += "       SB8.B8_DOC DOC, SB8.B8_SERIE SERIE, SB8.B8_CLIFOR CLIFOR, SB8.B8_LOJA LOJA, SB8.B8_ORIGLAN ORIGLAN, "
//-- B1_EMAX saiu do cursor quando o limite passou a ser resolvido por fLimEst (SBZ -> SB1).
//-- Para voltar a usar o valor da query, reative a coluna, o TcSetField abaixo e passe
//-- (cAlias)->EMAX ao fLimEst no lugar do Posicione na SB1.
// cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO, SB1.B1_EMAX EMAX "
cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO "
cQry += "  FROM " + RetSqlName("SB8") + " SB8 "
cQry += " INNER JOIN " + RetSqlName("SB1") + " SB1 ON " + fFilJoin("SB1", "SB1.B1_FILIAL", "SB8.B8_FILIAL")
cQry += "       AND SB1.B1_COD = SB8.B8_PRODUTO AND SB1.D_E_L_E_T_ = ' ' "
cQry += "  LEFT JOIN " + RetSqlName("SB5") + " SB5 ON " + fFilJoin("SB5", "SB5.B5_FILIAL", "SB8.B8_FILIAL")
cQry += "       AND SB5.B5_COD = SB8.B8_PRODUTO AND SB5.D_E_L_E_T_ = ' ' "
cQry += " WHERE " + fFilCond("SB8", "SB8.B8_FILIAL")
cQry += "   AND SB8.B8_PRODUTO BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cQry += "   AND SB8.B8_DTVALID BETWEEN '" + DtoS(mv_par09) + "' AND '" + DtoS(mv_par10) + "' "
cQry += "   AND SB1.B1_RASTRO IN ('L','S') "
cQry += "   AND " + cCondOrg + " "
cQry += "   AND SB8.D_E_L_E_T_ = ' ' "
cQry += " ORDER BY SB8.B8_FILIAL, SB8.B8_PRODUTO, SB8.B8_LOCAL, SB8.B8_LOTECTL, SB8.B8_NUMLOTE, SB8.B8_DATA "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "DTVALID" , "D", 8, 0)
TcSetField(cAlias, "DTFABRIC", "D", 8, 0)
//-- Reativar junto com a coluna B1_EMAX no SELECT acima
// TcSetField(cAlias, "EMAX"    , "N", TamSX3("B1_EMAX")[1], TamSX3("B1_EMAX")[2])

While !(cAlias)->(Eof()) .And. !oReport:Cancel()

	//-- Medidor por filial: a consulta vem ordenada por filial
	If (cAlias)->FILIAL <> cFilAtu
		cFilAtu := (cAlias)->FILIAL
		oReport:IncMeter()
	EndIf

	lSubLote := (cAlias)->RASTRO == "S"
	cSubChv  := ""
	If lSubLote
		cSubChv := (cAlias)->SUBLOTE
	EndIf
	cChave := fChave((cAlias)->FILIAL, (cAlias)->PRODUTO, (cAlias)->ARMAZEM, (cAlias)->LOTE, cSubChv)

	//-- Rastro por lote pode ter mais de um SB8 para o mesmo lote: usa o primeiro (entrada mais antiga)
	If cChave <> cChvAnt
		cChvAnt := cChave
		oDiag["LIDOS"] += 1
		oItem   := fMontaItem(cAlias, .T., lSubLote, oMov, cChave, aOrgaos, aListas, oCfg, oCache, oDiag)
		If ValType(oItem) $ "O/J"   //-- JsonObject retorna "J"
			//-- Sequencial contínuo da coluna "Linha": reaproveita o contador de impressos
			oDiag["IMPRESSOS"] += 1
			oItem["LINHA"] := oDiag["IMPRESSOS"]
			fImprime(oSecao, oItem)
			FreeObj(oItem)
		EndIf
	EndIf

	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

//-- 2) Produtos controlados sem rastro: um registro por Filial + Produto + Armazém (validade não se aplica)
cAlias  := GetNextAlias()
cFilAtu := ""
cQry := "SELECT SB2.B2_FILIAL FILIAL, SB2.B2_COD PRODUTO, SB2.B2_LOCAL ARMAZEM, "
//-- B1_EMAX fora do cursor: o limite vem do fLimEst (ver nota na consulta da SB8)
// cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO, SB1.B1_EMAX EMAX "
cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO "
cQry += "  FROM " + RetSqlName("SB2") + " SB2 "
cQry += " INNER JOIN " + RetSqlName("SB1") + " SB1 ON " + fFilJoin("SB1", "SB1.B1_FILIAL", "SB2.B2_FILIAL")
cQry += "       AND SB1.B1_COD = SB2.B2_COD AND SB1.D_E_L_E_T_ = ' ' "
cQry += "  LEFT JOIN " + RetSqlName("SB5") + " SB5 ON " + fFilJoin("SB5", "SB5.B5_FILIAL", "SB2.B2_FILIAL")
cQry += "       AND SB5.B5_COD = SB2.B2_COD AND SB5.D_E_L_E_T_ = ' ' "
cQry += " WHERE " + fFilCond("SB2", "SB2.B2_FILIAL")
cQry += "   AND SB2.B2_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cQry += "   AND SB1.B1_RASTRO NOT IN ('L','S') "
cQry += "   AND " + cCondOrg + " "
cQry += "   AND SB2.D_E_L_E_T_ = ' ' "
cQry += " ORDER BY SB2.B2_FILIAL, SB2.B2_COD, SB2.B2_LOCAL "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
//-- Reativar junto com a coluna B1_EMAX no SELECT acima
// TcSetField(cAlias, "EMAX", "N", TamSX3("B1_EMAX")[1], TamSX3("B1_EMAX")[2])

While !(cAlias)->(Eof()) .And. !oReport:Cancel()
	If (cAlias)->FILIAL <> cFilAtu
		cFilAtu := (cAlias)->FILIAL
		oReport:IncMeter()
	EndIf
	cChave := fChave((cAlias)->FILIAL, (cAlias)->PRODUTO, (cAlias)->ARMAZEM, "", "")
	oDiag["LIDOS"] += 1
	oItem  := fMontaItem(cAlias, .F., .F., oMov, cChave, aOrgaos, aListas, oCfg, oCache, oDiag)
	If ValType(oItem) $ "O/J"   //-- JsonObject retorna "J"
		oDiag["IMPRESSOS"] += 1
		oItem["LINHA"] := oDiag["IMPRESSOS"]
		fImprime(oSecao, oItem)
		FreeObj(oItem)
	EndIf
	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

FreeObj(oMov)
FreeObj(oCache)

Return

/*/{Protheus.doc} fFilCond
Condição SQL do intervalo de filiais (MV_PAR01 a MV_PAR02) para a tabela informada,
respeitando o modo de compartilhamento do dicionário (FWModeAccess, nível 3).

Tabela EXCLUSIVA por filial: o registro guarda a própria filial, então o recorte é
"campo BETWEEN filial_de AND filial_ate" - os parâmetros entram direto na consulta.

Tabela COMPARTILHADA: a filial não é gravada no registro (fica em branco), e o único
filtro válido é o próprio xFilial da tabela. Aplicar o BETWEEN nesse caso descartaria
todas as linhas, porque branco não está entre os códigos de filial.
@type Function
@author Pablo Regis
@since  10/11/2026
@param cAlias, character, alias da tabela (ex.: "SB8")
@param cCampo, character, coluna de filial, qualificada ou não (ex.: "SB8.B8_FILIAL")
@return character, condição SQL
/*/
Static Function fFilCond(cAlias, cCampo)

Local cRet := ""

If AllTrim(FWModeAccess(cAlias, 3)) == "C"
	cRet := cCampo + " = '" + xFilial(cAlias) + "' "
Else
	cRet := cCampo + " BETWEEN '" + PadR(mv_par01, FWSizeFilial()) + "' AND '" + ;
	        PadR(mv_par02, FWSizeFilial()) + "' "
EndIf

Return cRet

/*/{Protheus.doc} fFilJoin
Condição de filial de uma tabela de apoio dentro do JOIN, amarrada à filial do registro
que comanda a consulta.

Tabela EXCLUSIVA: amarra na coluna de filial da tabela principal, para que cada registro
busque o cadastro da SUA filial, e não o de uma filial fixa.
Tabela COMPARTILHADA: o cadastro vale para a empresa toda, então vale o xFilial.
@type Function
@author Pablo Regis
@since  10/11/2026
@param cAlias, character, alias da tabela de apoio (ex.: "SB1")
@param cCampo, character, coluna de filial da tabela de apoio (ex.: "SB1.B1_FILIAL")
@param cCpoOrig, character, coluna de filial da tabela principal (ex.: "SB8.B8_FILIAL")
@return character, condição SQL
/*/
Static Function fFilJoin(cAlias, cCampo, cCpoOrig)

Local cRet := ""

If AllTrim(FWModeAccess(cAlias, 3)) == "C"
	cRet := cCampo + " = '" + xFilial(cAlias) + "' "
Else
	cRet := cCampo + " = " + cCpoOrig + " "
EndIf

Return cRet

/*/{Protheus.doc} fJoinB1
JOIN da SB1 das consultas de movimento: filtro de grupo de produto e filial amarrada à
filial do movimento (fFilJoin).
@type Function
@author Pablo Regis
@since  10/11/2026
@param cCpoFil, character, coluna de filial do movimento (ex.: "SD1.D1_FILIAL")
@param cCpoCod, character, coluna de produto do movimento (ex.: "SD1.D1_COD")
@return character, trecho SQL do JOIN
/*/
Static Function fJoinB1(cCpoFil, cCpoCod)

Local cRet := ""

cRet := " INNER JOIN " + RetSqlName("SB1") + " SB1 ON " + fFilJoin("SB1", "SB1.B1_FILIAL", cCpoFil)
cRet += "       AND SB1.D_E_L_E_T_ = ' ' "
cRet += "       AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cRet += "       AND SB1.B1_COD = " + cCpoCod + " "

Return cRet

/*/{Protheus.doc} fCarregaMov
Movimentos do período no intervalo de filiais, agregados por Filial + Produto + Armazém +
Lote + Sub-Lote e classificados em Compras / Consumo / Perdas-Transferências (MIT041 -
seção 6). Retorna JsonObject: chave -> {nCompras, nConsumo, nPerdas}.

O recorte de filial de cada tabela de movimento sai de fFilCond (BETWEEN nos parâmetros
para tabela exclusiva), e a filial entra na chave para que o movimento de uma filial não
seja somado ao saldo de outra.
@type Function
@author Pablo Regis
@since  21/10/2026
@return object, JsonObject com os movimentos agregados
/*/
Static Function fCarregaMov()

Local oMov      := JsonObject():New()
Local cAlias    := GetNextAlias()
Local cQry      := ""
Local cIni      := DtoS(mv_par03)
Local cFim      := DtoS(mv_par04)
Local cCfTrE    := fSqlIn(CF_TRF_ENT)
Local cCfTrS    := fSqlIn(CF_TRF_SAI)
Local cCfD3Tr   := fSqlIn(D3_CF_TRANSF)
Local cTmPerda  := fSqlIn(TM_PERDAS)
Local cPerdaD3  := ""
Local cProdD3   := ""
Local cWhereD3  := ""
Local lWmsNew   := SuperGetMv("MV_WMSNEW", .F., .F.)
Local lD3Servi  := .F.

If !lWmsNew
	lD3Servi := GetMV("MV_D3SERVI", .F., "N") == "N"
EndIf

cPerdaD3 := "(D3_CF IN (" + cCfD3Tr + ") OR D3_TM IN (" + cTmPerda + "))"
cProdD3  := "(D3_CF LIKE 'PR%' OR D3_CF LIKE 'ER%')"

//-- Mesmo filtro de WMS do MATR445
If lD3Servi .And. IntDL()
	cWhereD3 := " AND ( (D3_SERVIC = '   ') OR (D3_SERVIC <> '   ' AND D3_TM <= '500') OR "
	cWhereD3 += " (D3_SERVIC <> '   ' AND D3_TM > '500' AND D3_LOCAL = '" + GetMvNNR("MV_CQ", "98") + "') ) "
EndIf

cQry := "SELECT FIL, COD, LOC, LOTE, SUBLOTE, SUM(COMPRAS) COMPRAS, SUM(CONSUMO) CONSUMO, SUM(PERDAS) PERDAS FROM ( "

//-- SD1: compras (+), devolução de venda (- consumo), transferência recebida (- perdas/transf.)
cQry += "SELECT D1_FILIAL FIL, D1_COD COD, D1_LOCAL LOC, D1_LOTECTL LOTE, D1_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D1_TIPO <> 'D' AND D1_CF NOT IN (" + cCfTrE + ") THEN D1_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN D1_TIPO = 'D' THEN -D1_QUANT ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN D1_TIPO <> 'D' AND D1_CF IN (" + cCfTrE + ") THEN -D1_QUANT ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD1") + " SD1 "
cQry += " INNER JOIN " + RetSqlName("SF4") + " SF4 ON " + fFilJoin("SF4", "SF4.F4_FILIAL", "SD1.D1_FILIAL")
cQry += "       AND SF4.F4_CODIGO = SD1.D1_TES AND SF4.F4_ESTOQUE = 'S' AND SF4.D_E_L_E_T_ = ' ' "
cQry += fJoinB1("SD1.D1_FILIAL", "SD1.D1_COD")
cQry += " WHERE " + fFilCond("SD1", "SD1.D1_FILIAL")
cQry += "   AND SD1.D1_DTDIGIT BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD1.D1_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD1.D1_ORIGLAN <> 'LF' AND SD1.D_E_L_E_T_ = ' ' "

cQry += "UNION ALL "

//-- SD2: vendas (+ consumo), devolução de compra (- compras), transferência enviada (+ perdas/transf.)
cQry += "SELECT D2_FILIAL FIL, D2_COD COD, D2_LOCAL LOC, D2_LOTECTL LOTE, D2_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D2_TIPO = 'D' THEN -D2_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN D2_TIPO <> 'D' AND D2_CF NOT IN (" + cCfTrS + ") THEN D2_QUANT ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN D2_TIPO <> 'D' AND D2_CF IN (" + cCfTrS + ") THEN D2_QUANT ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD2") + " SD2 "
cQry += " INNER JOIN " + RetSqlName("SF4") + " SF4 ON " + fFilJoin("SF4", "SF4.F4_FILIAL", "SD2.D2_FILIAL")
cQry += "       AND SF4.F4_CODIGO = SD2.D2_TES AND SF4.F4_ESTOQUE = 'S' AND SF4.D_E_L_E_T_ = ' ' "
cQry += fJoinB1("SD2.D2_FILIAL", "SD2.D2_COD")
cQry += " WHERE " + fFilCond("SD2", "SD2.D2_FILIAL")
cQry += "   AND SD2.D2_EMISSAO BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD2.D2_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD2.D2_ORIGLAN <> 'LF' AND SD2.D_E_L_E_T_ = ' ' "

cQry += "UNION ALL "

//-- SD3: produção (+ compras/entradas), transferências e TMs de perda (perdas/transf.), demais (consumo)
cQry += "SELECT D3_FILIAL FIL, D3_COD COD, D3_LOCAL LOC, D3_LOTECTL LOTE, D3_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D3_CF LIKE 'PR%' THEN D3_QUANT WHEN D3_CF LIKE 'ER%' THEN -D3_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN NOT " + cProdD3 + " AND NOT " + cPerdaD3
cQry += "       THEN (CASE WHEN D3_TM > '500' THEN D3_QUANT ELSE -D3_QUANT END) ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN NOT " + cProdD3 + " AND " + cPerdaD3
cQry += "       THEN (CASE WHEN D3_TM > '500' THEN D3_QUANT ELSE -D3_QUANT END) ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD3") + " SD3 "
cQry += fJoinB1("SD3.D3_FILIAL", "SD3.D3_COD")
cQry += " WHERE " + fFilCond("SD3", "SD3.D3_FILIAL")
cQry += "   AND SD3.D3_EMISSAO BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD3.D3_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD3.D3_ESTORNO <> 'S' AND SD3.D_E_L_E_T_ = ' ' "
cQry += cWhereD3

cQry += ") MOV GROUP BY FIL, COD, LOC, LOTE, SUBLOTE "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "COMPRAS", "N", 18, 4)
TcSetField(cAlias, "CONSUMO", "N", 18, 4)
TcSetField(cAlias, "PERDAS" , "N", 18, 4)

While !(cAlias)->(Eof())
	oMov[fChave((cAlias)->FIL, (cAlias)->COD, (cAlias)->LOC, (cAlias)->LOTE, (cAlias)->SUBLOTE)] := ;
		{(cAlias)->COMPRAS, (cAlias)->CONSUMO, (cAlias)->PERDAS}
	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

Return oMov

/*/{Protheus.doc} fMontaItem
Calcula o balanço do item e reúne as informações regulatórias. Retorna Nil quando não há
saldo nem movimento no período.

A filial sai do próprio registro (coluna FILIAL do cursor) e é atribuída a cFilAnt antes
de qualquer cálculo: CalcEst/CalcEstL não recebem filial por parâmetro, sempre trabalham
na filial corrente. As buscas de cadastro usam FWxFilial(tabela, filial), que já resolve
o compartilhamento. Registro de tabela compartilhada vem com a filial em branco; nesse
caso vale a filial de referência que ReportPrint deixou em cFilAnt.
@type Function
@author Pablo Regis
@since  21/10/2026
@return variant, JsonObject do item ou Nil quando não há saldo nem movimento
/*/
Static Function fMontaItem(cAlias, lLote, lSubLote, oMov, cChave, aOrgaos, aListas, oCfg, oCache, oDiag)

Local oItem    := Nil
Local cFil     := (cAlias)->FILIAL
Local cProd    := (cAlias)->PRODUTO
Local cLocal   := (cAlias)->ARMAZEM
Local cLote    := ""
Local cSubLote := Nil
Local aMov     := oMov[cChave]
Local nIni     := 0
Local nSis     := 0
Local nFim     := 0
Local cEstMat  := ""
Local cControl := ""

//-- Tabela compartilhada: o registro não tem filial própria, vale a de referência
If Empty(cFil)
	cFil := cFilAnt
EndIf

//-- CalcEst/CalcEstL e xFilial() trabalham sempre na filial corrente
cFilAnt := cFil

If ValType(aMov) <> "A"
	aMov := {0, 0, 0}
EndIf

If lLote
	cLote := (cAlias)->LOTE
	If lSubLote
		cSubLote := (cAlias)->SUBLOTE
	EndIf
	nIni  := CalcEstL(cProd, cLocal, mv_par03    , cLote, cSubLote)[1]
	nSis  := CalcEstL(cProd, cLocal, mv_par04 + 1, cLote, cSubLote)[1]
Else
	nIni  := CalcEst(cProd, cLocal, mv_par03)[1]
	nSis  := CalcEst(cProd, cLocal, mv_par04 + 1)[1]
EndIf

//-- Sem saldo e sem movimento no período: não imprime
If nIni == 0 .And. nSis == 0 .And. aMov[1] == 0 .And. aMov[2] == 0 .And. aMov[3] == 0
	oDiag["DESCART"] += 1
	If Empty(oDiag["EXEMPLO"])
		oDiag["EXEMPLO"] := cFil + " / " + AllTrim(cProd) + " / " + cLocal + " / " + AllTrim(cLote) + ;
		                    " (Sld. " + DtoC(mv_par03) + " = " + cValToChar(nIni) + ;
		                    ", Sld. " + DtoC(mv_par04 + 1) + " = " + cValToChar(nSis) + ")"
	EndIf
	Return Nil
EndIf

nFim := nIni + aMov[1] - aMov[2] - aMov[3]

SB5->(DbSetOrder(1))
SB5->(MsSeek(FWxFilial("SB5", cFil) + cProd))

//-- A lista da 344/98 fica na SB1 (B1_TPPROD), lida por fDescOrg junto com as flags da SB5
SB1->(DbSetOrder(1))
SB1->(MsSeek(FWxFilial("SB1", cFil) + cProd))

oItem := JsonObject():New()
oItem["FILIAL"  ] := cFil
oItem["PRODUTO" ] := cProd
//-- Nome Comercial complementa a identificação do produto no layout
oItem["NOMECOM" ] := fCpoSB5(oCfg["DESCPR"], "")
If Empty(oItem["NOMECOM"])
	oItem["NOMECOM"] := (cAlias)->DESCRI
EndIf
oItem["NOMEQUI" ] := fCpoSB5("B5_CEME", CPO_VAZIO)
oItem["CAS"     ] := fCpoSB5(CPO_CAS, CPO_VAZIO)
oItem["CODMAPA" ] := fCpoSB5(oCfg["CODMAPA"], CPO_VAZIO)
cEstMat := fCpoSB5("B5_ESTMAT", "")
If Empty(cEstMat)
	oItem["FORMA"   ] := CPO_VAZIO
Else
	oItem["FORMA"   ] := X3Combo("B5_ESTMAT", cEstMat)
EndIf
oItem["UM"      ] := (cAlias)->UM
//-- Uma varredura só: a descrição dos órgãos e o indicador da coluna "Controlado?"
oItem["ORGAO"   ] := fDescOrg(aOrgaos, aListas, @cControl)
oItem["CONTROL" ] := cControl
oItem["LIMEST"  ] := fLimEst(cFil, cProd, oCache)
oItem["FDS"     ] := fCpoSB5(CPO_FDS, CPO_VAZIO)
oItem["ARMAZEM" ] := cLocal
//-- [FORA DO LAYOUT] Condição de guarda (B5_XARMAZ), ver CPO_ARMAZ nos #DEFINE
// oItem["ARMAZEN" ] := fCpoSB5(CPO_ARMAZ, CPO_VAZIO)

If lLote
	oItem["LOTE"    ] := cLote
	oItem["FABRIC"  ] := fFabric(cProd, cLote, (cAlias)->ORIGLAN, (cAlias)->CLIFOR, (cAlias)->LOJA, oCache)
	oItem["DTFABRIC"] := (cAlias)->DTFABRIC
	oItem["DTVALID" ] := (cAlias)->DTVALID
	oItem["NFCOMPRA"] := fNFCompra(cAlias)
	//-- [FORA DO LAYOUT] Sub-lote, lote do fornecedor e NF em colunas separadas
	// oItem["SUBLOTE" ] := If(lSubLote, (cAlias)->SUBLOTE, "")
	// oItem["LOTEFOR" ] := (cAlias)->LOTEFOR
	// oItem["NFDOC"   ] := (cAlias)->DOC
	// oItem["NFSERIE" ] := (cAlias)->SERIE
	// oItem["NFEMIS"  ] := If(Empty((cAlias)->DOC), CtoD(""), ;
	//                      Posicione("SF1", 1, xFilial("SF1") + (cAlias)->DOC + (cAlias)->SERIE + (cAlias)->CLIFOR + (cAlias)->LOJA, "F1_EMISSAO"))
Else
	oItem["LOTE"    ] := ""
	oItem["FABRIC"  ] := ""
	oItem["DTFABRIC"] := CtoD("")
	oItem["DTVALID" ] := CtoD("")
	oItem["NFCOMPRA"] := ""
	//-- [FORA DO LAYOUT] Contrapartida das colunas acima para produto sem rastro
	// oItem["SUBLOTE" ] := ""
	// oItem["LOTEFOR" ] := ""
	// oItem["NFDOC"   ] := ""
	// oItem["NFSERIE" ] := ""
	// oItem["NFEMIS"  ] := CtoD("")
EndIf

oItem["SLDINI"  ] := nIni
oItem["COMPRAS" ] := aMov[1]
oItem["CONSUMO" ] := aMov[2]
oItem["PERDAS"  ] := aMov[3]
oItem["SLDFIM"  ] := nFim
oItem["RESP"    ] := ""
oItem["CONFER"  ] := ""
oItem["OBS"     ] := ""

//-- [FORA DO LAYOUT] Saldo do sistema e conferência. O nSis continua sendo calculado
//-- acima (serve para descartar item sem saldo e sem movimento), então para ter a
//-- checagem de volta basta reativar estas duas linhas e as colunas em ReportDef.
// oItem["SLDSIS"  ] := nSis
// oItem["CONFERE" ] := If(Abs(nFim - nSis) < 0.0001, "OK", "DIVERGENTE")

Return oItem

/*/{Protheus.doc} fImprime
Transfere os valores do item para as células e imprime a linha.
/*/
Static Function fImprime(oSecao, oItem)

//-- Mesma ordem das células em ReportDef.
//-- [FORA DO LAYOUT] Ao reativar uma coluna, acrescente o nome aqui na posição
//-- correspondente: "SUBLOTE", "LOTEFOR", "ARMAZEN", "NFDOC", "NFSERIE",
//-- "NFEMIS", "SLDSIS", "CONFERE".
Local aCelulas := {"LINHA", "FILIAL", "CONTROL", "ORGAO", "LIMEST", "PRODUTO", "CODMAPA", "NOMECOM", "NOMEQUI", ;
                   "CAS", "FORMA", "FABRIC", "LOTE", "FDS", "ARMAZEM", "DTFABRIC", "DTVALID", "UM", ;
                   "SLDINI", "COMPRAS", "NFCOMPRA", "CONSUMO", "PERDAS", "SLDFIM", "RESP", "CONFER", "OBS"}
Local nI       := 0

For nI := 1 To Len(aCelulas)
	oSecao:Cell(aCelulas[nI]):SetValue(oItem[aCelulas[nI]])
Next nI

oSecao:PrintLine()

Return

/*/{Protheus.doc} fNFCompra
Nota fiscal de entrada do lote num único texto: "numero/serie - fornecedor - emissao".
Cada parte só entra quando tem conteúdo, para não deixar separadores soltos.
@type  Static Function
@author bacoetrom@gmail.com
@since  06/11/2026
@param cAlias, character, alias da consulta posicionada no lote (SB8)
@return character, nota fiscal de compra formatada
/*/
Static Function fNFCompra(cAlias)

Local cDoc   := AllTrim((cAlias)->DOC)
Local cSerie := AllTrim((cAlias)->SERIE)
Local cForn  := ""
Local dEmis  := CtoD("")
Local cRet   := ""

If !Empty(cDoc)
	cRet := cDoc
	If !Empty(cSerie)
		cRet += "/" + cSerie
	EndIf

	If !Empty((cAlias)->CLIFOR)
		cForn := fNomeSA2((cAlias)->CLIFOR + (cAlias)->LOJA)
		If !Empty(cForn)
			cRet += " - " + cForn
		EndIf
	EndIf

	dEmis := Posicione("SF1", 1, xFilial("SF1") + (cAlias)->DOC + (cAlias)->SERIE + ;
	                   (cAlias)->CLIFOR + (cAlias)->LOJA, "F1_EMISSAO")
	If !Empty(dEmis)
		cRet += " - " + DtoC(dEmis)
	EndIf
EndIf

Return cRet

/*/{Protheus.doc} fLimEst
Limite de estoque do produto na filial informada: BZ_EMAX (SBZ - Produto x Filial) e, na
falta dele, B1_EMAX (SB1 - Cadastro de Produtos).

A SBZ guarda os parâmetros de estoque por filial, por isso tem precedência sobre a SB1,
que vale para toda a empresa. É a mesma precedência que o padrão aplica no PCPA107
("ISNULL(SBZ.BZ_EMAX, SB1.B1_EMAX)").

A filial é parâmetro, e não a filial corrente: a emissão percorre várias filiais numa
consulta só, então o limite tem de ser o da filial do registro. A chave de busca sai de
FWxFilial(tabela, filial), que resolve o compartilhamento de cada tabela.

"Não existir na SBZ" cobre dois casos: produto sem registro na tabela e registro com
BZ_EMAX zerado. Limite zero é tratado como limite não informado, por isso a função cai
para a SB1.

As duas tabelas são tratadas como opcionais (fCampoTab): sem a tabela no ambiente ou sem
o campo no dicionário, a etapa é apenas ignorada e a função devolve 0 em vez de derrubar
a emissão.
@type Function
@author Pablo Regis
@since  10/11/2026
@param cFil, character, filial do registro (B8_FILIAL / B2_FILIAL)
@param cProd, character, código do produto (B1_COD)
@param oCache, object, JsonObject de cache da emissão (opcional)
@return numeric, limite de estoque; 0 se nenhuma das duas tabelas informa o valor
/*/
Static Function fLimEst(cFil, cProd, oCache)

Local cChave  := ""
Local nLimite := 0
Local lCache  := ValType(oCache) $ "O/J"   //-- JsonObject retorna "J"

cProd  := PadR(cProd, TamSX3("B1_COD")[1])
cChave := "LIM|" + AllTrim(cFil) + "|" + AllTrim(cProd)

//-- O mesmo produto se repete a cada lote/armazém: um seek por filial + produto, não por
//-- linha. A filial entra na chave porque o limite da SBZ é por filial
If lCache .And. ValType(oCache[cChave]) == "N"
	Return oCache[cChave]
EndIf

//-- 1) Limite da filial (SBZ, índice 1 = BZ_FILIAL+BZ_COD)
If !Empty(fCampoTab("BZ_EMAX", "SBZ", .T.))
	nLimite := Posicione("SBZ", 1, FWxFilial("SBZ", cFil) + cProd, "BZ_EMAX")
EndIf

//-- 2) Limite geral do cadastro de produtos (SB1)
If nLimite <= 0 .And. !Empty(fCampoTab("B1_EMAX", "SB1", .T.))
	nLimite := Posicione("SB1", 1, FWxFilial("SB1", cFil) + cProd, "B1_EMAX")
EndIf

If ValType(nLimite) <> "N"
	nLimite := 0
EndIf

If lCache
	oCache[cChave] := nLimite
EndIf

Return nLimite

/*/{Protheus.doc} fFabric
Fabricante do lote via amarração Produto x Fornecedor (SA5) - MIT041, seção 5.
  CP: fornecedor do lote (B8_CLIFOR/B8_LOJA) | TR: fornecedor do lote de origem | PR: própria empresa.
  A5_FABR preenchido -> fabricante; vazio e A5_FABREV F/vazio -> o próprio fornecedor;
  R/P sem fabricante -> fornecedor sinalizado; mais de um fabricante -> primeiro, sinalizado.
/*/
Static Function fFabric(cProd, cLote, cOrigLan, cCliFor, cLoja, oCache)

Local aArea   := GetArea()
Local aAreaA5 := SA5->(GetArea())
Local aFab    := {}
Local cRet    := ""
Local cChave  := ""
Local cFabRev := ""
Local cSeek   := ""

If AllTrim(cOrigLan) == "PR"
	cRet := fNomeEmp()
Else
	If AllTrim(cOrigLan) == "TR" .Or. Empty(cCliFor)
		fLoteOrig(cProd, cLote, @cCliFor, @cLoja)
	EndIf

	If !Empty(cCliFor)
		//-- A filial entra na chave porque a SA5 pode ser exclusiva por filial
		cChave := cFilAnt + "|" + cProd + cCliFor + cLoja
		If ValType(oCache[cChave]) == "C"
			cRet := oCache[cChave]
		Else
			cSeek := xFilial("SA5") + cCliFor + cLoja + cProd
			SA5->(DbSetOrder(1))   //-- A5_FILIAL+A5_FORNECE+A5_LOJA+A5_PRODUTO+...
			If SA5->(MsSeek(cSeek))
				While !SA5->(Eof()) .And. SA5->(A5_FILIAL + A5_FORNECE + A5_LOJA + A5_PRODUTO) == cSeek
					If !Empty(SA5->A5_FABR) .And. aScan(aFab, SA5->A5_FABR + SA5->A5_FALOJA) == 0
						aAdd(aFab, SA5->A5_FABR + SA5->A5_FALOJA)
					EndIf
					If Empty(cFabRev)
						cFabRev := SA5->A5_FABREV
					EndIf
					SA5->(DbSkip())
				EndDo
			EndIf

			Do Case
			Case Len(aFab) == 1
				cRet := fNomeSA2(aFab[1])
			Case Len(aFab) > 1
				cRet := fNomeSA2(aFab[1]) + " (+" + cValToChar(Len(aFab) - 1) + " FABRIC. NA SA5)"
			Case !Empty(cFabRev) .And. cFabRev $ "RP"
				cRet := fNomeSA2(cCliFor + cLoja) + " (REVENDEDOR - FABRICANTE NAO INFORMADO)"
			OtherWise
				cRet := fNomeSA2(cCliFor + cLoja)
			EndCase

			oCache[cChave] := cRet
		EndIf
	EndIf
EndIf

RestArea(aAreaA5)
RestArea(aArea)

Return cRet

/*/{Protheus.doc} fLoteOrig
Lote recebido por transferência: busca o fornecedor no lote de origem (compra),
em qualquer filial.
/*/
Static Function fLoteOrig(cProd, cLote, cCliFor, cLoja)

Local cAlias := GetNextAlias()
Local cQry   := ""

cQry := "SELECT B8_CLIFOR, B8_LOJA FROM " + RetSqlName("SB8") + " "
cQry += " WHERE B8_PRODUTO = '" + cProd + "' AND B8_LOTECTL = '" + cLote + "' "
cQry += "   AND B8_ORIGLAN = 'CP' AND B8_CLIFOR <> ' ' AND D_E_L_E_T_ = ' ' "
cQry += " ORDER BY B8_DATA "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
If !(cAlias)->(Eof())
	cCliFor := (cAlias)->B8_CLIFOR
	cLoja   := (cAlias)->B8_LOJA
EndIf
(cAlias)->(DbCloseArea())

Return

/*/{Protheus.doc} fOrgaos
Grupo da pergunta MV_PAR11 - órgãos fiscalizadores: código, descrição, campo, parâmetro
de origem e regra de controle (flag = 'S' nos três primeiros, campo preenchido na ANVISA).

A ANVISA entra aqui como qualquer outro órgão, mas pelo campo da lista da Portaria
344/98 (fCampoLis, SB1.B1_TPPROD): produto com lista preenchida é produto controlado
pela ANVISA. A pergunta MV_PAR12 apenas detalha quais listas interessam e só é
oferecida quando esta opção está marcada (ver CI04AVM).
@type Function
@author Pablo Regis
@since  21/10/2026
@return array, grupo de opções dos órgãos fiscalizadores
/*/
Static Function fOrgaos()

Local aOrgaos := {}

aAdd(aOrgaos, {"PC"  , "POLÍCIA CIVIL"           , fCampoMV("MV_MTR947A"), "MV_MTR947A", .F., "", "SB5"})
aAdd(aOrgaos, {"PF"  , "POLÍCIA FEDERAL"         , fCampoMV("MV_PRODPF") , "MV_PRODPF" , .F., "", "SB5"})
aAdd(aOrgaos, {"EX"  , "EXÉRCITO"                , fCampoMV("MV_MTR949A"), "MV_MTR949A", .F., "", "SB5"})
aAdd(aOrgaos, {ORG_AV, "ANVISA", fCampoLis()           , PAR_LISTA   , .T., "", TAB_LISTA})
//-- [FORA DO LAYOUT] Flag B5_XANVISA (CPO_ANVISA nos #DEFINE) como campo da opção AV.
//-- Hoje a ANVISA é identificada pelo campo da lista (B1_TPPROD), o mesmo indicador de
//-- MV_PAR12 - um só critério para a opção AV e para as listas. Para voltar a usar a
//-- flag, troque o campo da opção acima por fCampoSB5(CPO_ANVISA, .T.), reative o
//-- #DEFINE e lembre que a lista deixa de detalhar a mesma informação.

Return aOrgaos

/*/{Protheus.doc} fListas
Grupo da pergunta MV_PAR12 - listas da Portaria SVS/MS 344/98, na mesma estrutura dos
órgãos. Todas apontam para o único campo da lista (fCampoLis, SB1.B1_TPPROD) e se
diferenciam pelo conteúdo esperado (ORG_CONTEU), que é o próprio código da lista.
@type Function
@author Pablo Regis
@since  05/11/2026
@return array, grupo de opções das listas da ANVISA
/*/
Static Function fListas()

Local aListas := {}
Local aAnv    := fListAnv()
Local cCpoLis := fCampoLis()
Local nI      := 0

For nI := 1 To Len(aAnv)
	aAdd(aListas, {aAnv[nI][1], aAnv[nI][2], cCpoLis, PAR_LISTA, .F., aAnv[nI][1], TAB_LISTA})
Next nI

FwFreeArray(aAnv)

Return aListas

/*/{Protheus.doc} fListAnv
Listas de substâncias sujeitas a controle especial da Portaria SVS/MS 344/98, lidas da
tabela genérica SX5_LISTA da SX5 - a mesma que alimenta o campo B1_TPPROD. Assim, lista
nova ou descrição alterada no cadastro do cliente aparece sem recompilar o fonte.

Se a tabela genérica não estiver cadastrada, cai na relação fixa (fListFix): sem opções
o f_Opcoes não teria o que exibir e a pergunta ficaria inutilizável.
@type Function
@author Pablo Regis
@since  05/11/2026
@return array, pares {código de 2 posições, descrição}
/*/
Static Function fListAnv()

Local aListas := {}
Local aSX5    := FWGetSX5(SX5_LISTA)
Local cChave  := ""
Local nI      := 0

If ValType(aSX5) <> "A"
	aSX5 := {}
EndIf

For nI := 1 To Len(aSX5)
	cChave := AllTrim(aSX5[nI][3])   //-- [3] X5_CHAVE, [4] X5_DESCRI
	//-- Os códigos entram numa string de largura fixa: chave de tamanho diferente
	//-- quebraria o alinhamento, e NC é reservado para a opção "não controlado"
	If Len(cChave) == ORG_TAM .And. cChave <> ORG_NC
		aAdd(aListas, {cChave, AllTrim(aSX5[nI][4])})
	EndIf
Next nI

FwFreeArray(aSX5)

If Empty(aListas)
	aListas := fListFix()
EndIf

Return aListas

/*/{Protheus.doc} fListFix
Relação fixa das listas da Portaria SVS/MS 344/98 (Anexo I), usada apenas quando a
tabela genérica SX5_LISTA não está cadastrada.
A3 e B1 compartilham a descrição "PSICOTRÓPICOS" por definição da própria Portaria;
o código exibido ao lado da descrição diferencia as duas opções.
@type Function
@author Pablo Regis
@since  05/11/2026
@return array, pares {código de 2 posições, descrição}
/*/
Static Function fListFix()

Local aListas := {}

aAdd(aListas, {"A1", "ANVISA - ENTORPECENTES"})
aAdd(aListas, {"A2", "ANVISA - ENTORPECENTES DE USO EM CONCENTRAÇÕES ESPECIAIS"})
aAdd(aListas, {"A3", "ANVISA - PSICOTRÓPICOS"})
aAdd(aListas, {"B1", "ANVISA - PSICOTRÓPICOS"})
aAdd(aListas, {"B2", "ANVISA - PSICOTRÓPICOS ANOREXÍGENOS"})
aAdd(aListas, {"C1", "ANVISA - OUTRAS SUBSTÂNCIAS SUJEITAS A CONTROLE ESPECIAL"})
aAdd(aListas, {"C2", "ANVISA - SUBSTÂNCIAS RETINÓICAS"})
aAdd(aListas, {"C3", "ANVISA - IMUNOSSUPRESSORES"})
aAdd(aListas, {"C4", "ANVISA - ANTIRRETROVIRAIS"})
aAdd(aListas, {"C5", "ANVISA - SUBSTÂNCIAS ANABOLIZANTES"})
aAdd(aListas, {"D1", "ANVISA - PRECURSORAS"})
aAdd(aListas, {"D2", "ANVISA - REAGENTES QUÍMICOS"})

Return aListas

/*/{Protheus.doc} fCampoLis
Nome do campo que guarda a lista da Portaria 344/98. Usa o parâmetro PAR_LISTA quando
configurado e, na ausência dele, o campo padrão CPO_LISTA (B1_TPPROD, na SB1).
Retorna vazio se o campo não existir (as listas saem do filtro).
@type Function
@author Pablo Regis
@since  05/11/2026
@return character, nome do campo ou vazio
/*/
Static Function fCampoLis()

Local cCampo := Upper(AllTrim(SuperGetMV(PAR_LISTA, .F., CPO_LISTA)))

cCampo := StrTran(cCampo, TAB_LISTA + "->", "")

Return fCampoTab(cCampo, TAB_LISTA, .T.)

/*/{Protheus.doc} fCondOrg
Condição SQL do órgão: produto controlado (lControla = .T.) ou não controlado (.F.) por ele.
@type Function
@author Pablo Regis
@since  21/10/2026
@param aOrg, array, item do array de órgãos (fOrgaos)
@param lControla, logical, .T. condição positiva; .F. condição negada
@return character, condição SQL
/*/
Static Function fCondOrg(aOrg, lControla)

//-- As duas queries do fProcessa usam SB5 e SB1 com esses mesmos apelidos
Local cCampo := "COALESCE(" + aOrg[ORG_ALIAS] + "." + aOrg[ORG_CAMPO] + ",' ')"
Local cRet   := ""

Do Case
Case !Empty(aOrg[ORG_CONTEU])
	//-- Lista da 344/98: o campo guarda o código da lista
	If lControla
		cRet := cCampo + " = '" + aOrg[ORG_CONTEU] + "'"
	Else
		cRet := cCampo + " <> '" + aOrg[ORG_CONTEU] + "'"
	EndIf
Case aOrg[ORG_PREENCH]
	If lControla
		cRet := cCampo + " <> ' '"
	Else
		cRet := cCampo + " = ' '"
	EndIf
OtherWise
	If lControla
		cRet := cCampo + " = 'S'"
	Else
		cRet := cCampo + " <> 'S'"
	EndIf
EndCase

Return cRet

/*/{Protheus.doc} fDescOrg
Órgãos e listas que controlam o produto posicionado (flag = 'S' na SB5, campo
preenchido ou conteúdo igual ao código da lista da 344/98 na SB1).

Quando alguma lista se aplica, o código AV é dispensado: a lista já identifica a ANVISA
e repetir os dois só consumiria a coluna (ex.: "PF / A1", e não "PF / AV / A1").

Devolve também, por referência, o indicador da coluna "Controlado?": SIM quando ao
menos um órgão/lista se aplica, NÃO quando nenhum se aplica e CPO_VAZIO quando não
existe nenhum dos campos no dicionário - nesse caso o produto não é "não controlado", é
um produto que o relatório não tem como classificar, e afirmar NÃO seria incorreto num
relatório regulatório.
@type Function
@author Pablo Regis
@since  21/10/2026
@param aOrgaos, array, grupo dos órgãos fiscalizadores (fOrgaos)
@param aListas, array, grupo das listas da ANVISA (fListas)
@param cControl, character, retorna SIM, NÃO ou CPO_VAZIO (por referência)
@return character, códigos aplicáveis separados por " / "
/*/
Static Function fDescOrg(aOrgaos, aListas, cControl)

Local aDesc  := {}
Local aLis   := {}
Local cRet   := ""
Local lCampo := .F.
Local nI     := 0
Local nPos   := 0

fMarcGrp(aOrgaos, @aDesc, @lCampo)
fMarcGrp(aListas, @aLis, @lCampo)

If !Empty(aLis)
	//-- A lista já diz que o produto é da ANVISA
	nPos := aScan(aDesc, {|x| x == ORG_AV})
	If nPos > 0
		aDel(aDesc, nPos)
		aSize(aDesc, Len(aDesc) - 1)
	EndIf
	For nI := 1 To Len(aLis)
		aAdd(aDesc, aLis[nI])
	Next nI
EndIf

Do Case
Case !lCampo
	//-- Sem campo de órgão nem de lista no dicionário: não há como classificar o produto
	cRet     := CPO_VAZIO
	cControl := CPO_VAZIO
Case Empty(aDesc)
	cRet     := "NAO CONTROLADO"
	cControl := "NÃO"
OtherWise
	cRet     := fJunta(aDesc, " / ")
	cControl := "SIM"
EndCase

FwFreeArray(aLis)
FwFreeArray(aDesc)

Return cRet

/*/{Protheus.doc} fMarcGrp
Acrescenta em aDesc os códigos do grupo que se aplicam ao produto posicionado na SB5
e sinaliza em lCampo se o grupo tem ao menos um campo existente.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param aDesc, array, acumula os códigos aplicáveis (por referência)
@param lCampo, logical, .T. se algum campo do grupo existe na SB5 (por referência)
@return nil
/*/
Static Function fMarcGrp(aGrupo, aDesc, lCampo)

Local cConteudo := ""
Local nI        := 0
Local lControla := .F.

For nI := 1 To Len(aGrupo)
	If !Empty(aGrupo[nI][ORG_CAMPO])
		lCampo    := .T.
		cConteudo := fCpoTab(aGrupo[nI][ORG_CAMPO], aGrupo[nI][ORG_ALIAS], "")
		Do Case
		Case !Empty(aGrupo[nI][ORG_CONTEU])
			lControla := cConteudo == aGrupo[nI][ORG_CONTEU]
		Case aGrupo[nI][ORG_PREENCH]
			lControla := !Empty(cConteudo)
		OtherWise
			lControla := cConteudo == "S"
		EndCase
		If lControla
			aAdd(aDesc, aGrupo[nI][ORG_COD])
		EndIf
	EndIf
Next nI

Return

/*/{Protheus.doc} fConfig
Campos opcionais da configuração PF (nome comercial e código SIPROQUIM).
/*/
Static Function fConfig()

Local oCfg := JsonObject():New()

oCfg["DESCPR" ] := fCampoMV("MV_DESCPR")
oCfg["CODMAPA"] := fCampoMV("MV_CODMAPA")

Return oCfg

/*/{Protheus.doc} fCampoMV
Nome do campo da SB5 informado no parâmetro; vazio se o parâmetro estiver vazio
ou o campo não existir.
/*/
Static Function fCampoMV(cParam)

Local cCampo := Upper(AllTrim(SuperGetMV(cParam, .F., "")))

cCampo := StrTran(cCampo, "SB5->", "")

Return fCampoSB5(cCampo, .T.)

/*/{Protheus.doc} fCampoSB5
Retorna o nome do campo se existir na SB5 (lValida) ou vazio.

A validação roda antes do oSecao:Init() (que é quem abre as tabelas da seção), por
isso a SB5 é aberta aqui com ChkFile() quando necessário: sem a tabela aberta o
FieldPos() daria 0 e todos os campos de órgão seriam tratados como inexistentes.
@type Function
@author Pablo Regis
@since  21/10/2026
@param cCampo, character, nome do campo
@param lValida, logical, .F. devolve vazio sem consultar a SB5
@return character, nome do campo ou vazio
/*/
Static Function fCampoSB5(cCampo, lValida)
Return fCampoTab(cCampo, "SB5", lValida)

/*/{Protheus.doc} fCampoTab
Retorna o nome do campo se existir na tabela informada (lValida) ou vazio. Os campos
dos órgãos ficam na SB5 e a lista da 344/98 na SB1, por isso a tabela é parâmetro.
@type Function
@author Pablo Regis
@since  05/11/2026
@param cCampo, character, nome do campo
@param cAlias, character, alias da tabela ("SB5" ou "SB1")
@param lValida, logical, .F. devolve vazio sem consultar a tabela
@return character, nome do campo ou vazio
/*/
Static Function fCampoTab(cCampo, cAlias, lValida)

Local aArea := GetArea()

Do Case
Case !lValida .Or. Empty(cCampo) .Or. Empty(cAlias)
	cCampo := ""
Case Select(cAlias) == 0 .And. !ChkFile(cAlias)
	//-- Tabela indisponível no ambiente: não há como validar o campo
	cCampo := ""
Case (cAlias)->(FieldPos(cCampo)) == 0
	cCampo := ""
EndCase

RestArea(aArea)

Return cCampo

/*/{Protheus.doc} fCpoSB5
Conteúdo de um campo da SB5 posicionada; xDefault se o campo não existir.
/*/
Static Function fCpoSB5(cCampo, xDefault)
Return fCpoTab(cCampo, "SB5", xDefault)

/*/{Protheus.doc} fCpoTab
Conteúdo de um campo da tabela posicionada; xDefault se o campo não existir ou a
tabela não estiver posicionada.
@type Function
@author Pablo Regis
@since  05/11/2026
@param cCampo, character, nome do campo
@param cAlias, character, alias da tabela ("SB5" ou "SB1")
@param xDefault, variant, conteúdo devolvido quando o campo não existe
@return variant, conteúdo do campo
/*/
Static Function fCpoTab(cCampo, cAlias, xDefault)

Local xRet := xDefault
Local nPos := 0

If !Empty(cCampo) .And. !Empty(cAlias) .And. Select(cAlias) > 0
	nPos := (cAlias)->(FieldPos(cCampo))
	If nPos > 0 .And. !(cAlias)->(Eof())
		xRet := (cAlias)->(FieldGet(nPos))
		If ValType(xRet) == "C"
			xRet := AllTrim(xRet)
		EndIf
	EndIf
EndIf

Return xRet

/*/{Protheus.doc} fNomeSA2
Nome do fornecedor/fabricante (código + loja).
/*/
Static Function fNomeSA2(cCodLoja)
Return AllTrim(Posicione("SA2", 1, xFilial("SA2") + cCodLoja, "A2_NOME"))

/*/{Protheus.doc} fNomeEmp
Razão social da filial corrente (lote de produção própria).
/*/
Static Function fNomeEmp()

Local aAreaSM0 := SM0->(GetArea())
Local cNome    := ""

If SM0->(DbSeek(cEmpAnt + cFilAnt))
	cNome := AllTrim(SM0->M0_NOMECOM)
EndIf
RestArea(aAreaSM0)

Return cNome

/*/{Protheus.doc} fChave
Chave do item: Filial | Produto | Armazém | Lote | Sub-Lote.

A filial entra na chave porque a emissão percorre várias filiais numa consulta só: sem
ela, o movimento de uma filial seria somado ao saldo de outra.
@type Function
@author Pablo Regis
@since  21/10/2026
@param cFil, character, filial do registro
@param cProd, character, código do produto
@param cLocal, character, armazém
@param cLote, character, lote
@param cSubLote, character, sub-lote
@return character, chave do item
/*/
Static Function fChave(cFil, cProd, cLocal, cLote, cSubLote)
Return AllTrim(cFil) + "|" + AllTrim(cProd) + "|" + AllTrim(cLocal) + "|" + ;
       AllTrim(cLote) + "|" + AllTrim(cSubLote)

/*/{Protheus.doc} fSqlIn
"A/B/C" -> "'A','B','C'" para cláusula IN.
/*/
Static Function fSqlIn(cLista)

Local aItens := StrTokArr(cLista, "/")
Local cRet   := ""
Local nI     := 0

For nI := 1 To Len(aItens)
	cRet += If(nI > 1, ",", "") + "'" + AllTrim(aItens[nI]) + "'"
Next nI

Return If(Empty(cRet), "'###'", cRet)

/*/{Protheus.doc} fJunta
Concatena os elementos do array com o separador.
/*/
Static Function fJunta(aItens, cSep)

Local cRet := ""
Local nI   := 0

For nI := 1 To Len(aItens)
	cRet += If(nI > 1, cSep, "") + aItens[nI]
Next nI

Return cRet

/*/{Protheus.doc} fSelGrp
Códigos marcados na pergunta de um grupo, concatenados e sem as posições não marcadas
(ex.: "PF**EX****" -> "PFEX"). Conteúdo inválido digitado na pergunta é descartado.
@type Function
@author Pablo Regis
@since  21/10/2026
@param nParam, numeric, número da pergunta (PAR_ORG ou PAR_LIS)
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@return character, códigos selecionados
/*/
Static Function fSelGrp(nParam, aGrupo)

Local aOpcoes  := {}
Local cCodigos := ""
Local cVar     := "mv_par" + StrZero(nParam, 2)
Local cPar     := ""
Local cCod     := ""
Local cRet     := ""
Local nI       := 0

If Type(cVar) == "C"
	cPar := &(cVar)
EndIf

aOpcoes := fOpcGrp(aGrupo, @cCodigos, , fTemNC(nParam))

For nI := 1 To Len(cPar) Step ORG_TAM
	cCod := SubStr(cPar, nI, ORG_TAM)
	If fOrgPos(cCod, cCodigos) > 0
		cRet += cCod
	EndIf
Next nI

FwFreeArray(aOpcoes)

Return cRet

/*/{Protheus.doc} fTemNC
.T. para os grupos que oferecem a opção NC ("não controlado").

Só os Órgãos Fiscalizadores a têm: lá o NC nega as regras de todos os órgãos - ANVISA
inclusive, já que a opção AV olha o campo da lista - e traz de uma vez o produto sem
nenhum controle. Nas Listas ANVISA ele seria redundante e, com os grupos em OU, abriria
uma segunda porta para todo o estoque não controlado.
@type Function
@author Pablo Regis
@since  11/11/2026
@param nParam, numeric, número da pergunta (PAR_ORG ou PAR_LIS)
@return logical, .T. se o grupo tem a opção NC
/*/
Static Function fTemNC(nParam)

Return nParam == PAR_ORG

/*/{Protheus.doc} fTiraOpc
Seleção sem um código, preservando a ordem dos demais. Usada por fValida para tirar a
opção AV do grupo de órgãos quando a ANVISA é detalhada pelas listas marcadas.
@type Function
@author Pablo Regis
@since  11/11/2026
@param cSel, character, códigos marcados (fSelGrp)
@param cCod, character, código a retirar
@return character, códigos restantes
/*/
Static Function fTiraOpc(cSel, cCod)

Local cRet := ""
Local cAtu := ""
Local nI   := 0

For nI := 1 To Len(cSel) Step ORG_TAM
	cAtu := SubStr(cSel, nI, ORG_TAM)
	If cAtu <> cCod
		cRet += cAtu
	EndIf
Next nI

Return cRet

/*/{Protheus.doc} fOpcGrp
Opções de um grupo para o f_Opcoes, no formato "XX - DESCRIÇÃO" exigido pela função
(código com ORG_TAM posições seguido de " - ").
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param cCodigos, character, retorna a concatenação dos códigos na ordem das opções (por referência)
@param cDescNC, character, descrição da opção NC; o padrão serve para quem só precisa dos códigos
@param lTemNC, logical, .T. acrescenta a opção NC ao final do grupo (ver fTemNC)
@return array, opções exibidas na tela do f_Opcoes
/*/
Static Function fOpcGrp(aGrupo, cCodigos, cDescNC, lTemNC)

Local aOpcoes := {}
Local nI      := 0

Default cDescNC := "NÃO CONTROLADO"
Default lTemNC  := .T.

cCodigos := ""

For nI := 1 To Len(aGrupo)
	aAdd(aOpcoes, aGrupo[nI][ORG_COD] + " - " + aGrupo[nI][ORG_DESC])
	cCodigos += aGrupo[nI][ORG_COD]
Next nI

//-- NC é sempre a última opção: não é um órgão nem uma lista, serve para trazer os
//-- produtos fora do grupo
If lTemNC
	aAdd(aOpcoes, ORG_NC + " - " + cDescNC)
	cCodigos += ORG_NC
EndIf

Return aOpcoes

/*/{Protheus.doc} fDefGrp
Conteúdo inicial da pergunta de um grupo: todas as opções do grupo marcadas e, nos
grupos que têm NC, a posição do NC marcada ou não conforme lMarcaNC.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param lTemNC, logical, .T. se o grupo tem a opção NC (ver fTemNC)
@param lMarcaNC, logical, .T. marca também a opção "não controlado"
@return character, conteúdo inicial da pergunta
/*/
Static Function fDefGrp(aGrupo, lTemNC, lMarcaNC)

Local cRet := ""
Local nI   := 0

For nI := 1 To Len(aGrupo)
	cRet += aGrupo[nI][ORG_COD]
Next nI

If lTemNC
	If lMarcaNC
		cRet += ORG_NC
	Else
		cRet += Replicate("*", ORG_TAM)
	EndIf
EndIf

Return cRet

/*/{Protheus.doc} fOrgDef
Conteúdo inicial da pergunta MV_PAR11: os 4 órgãos marcados (ANVISA inclusive) e NC
desmarcado, ou seja, só produtos controlados por algum órgão - o comportamento
histórico do relatório.
@type Function
@author Pablo Regis
@since  05/11/2026
@return character, conteúdo inicial da pergunta
/*/
Static Function fOrgDef()

Local aGrupo := fOrgaos()
Local cRet   := fDefGrp(aGrupo, .T., .F.)

FwFreeArray(aGrupo)

Return cRet

/*/{Protheus.doc} fLisDef
Conteúdo inicial da pergunta MV_PAR12: todas as listas marcadas, o que equivale a
"qualquer lista da 344/98" - mesmo recorte da opção AV sozinha. O grupo não tem opção
NC, porque "não controlado" é o NC dos Órgãos Fiscalizadores.
@type Function
@author Pablo Regis
@since  05/11/2026
@return character, conteúdo inicial da pergunta
/*/
Static Function fLisDef()

Local aGrupo := fListas()
Local cRet   := fDefGrp(aGrupo, .F., .F.)

FwFreeArray(aGrupo)

Return cRet

/*/{Protheus.doc} fOrgPos
Posição do código na lista de códigos válidos, comparando em blocos de ORG_TAM
posições. Retorna 0 para as posições não marcadas ("**") e para códigos inexistentes.
@type Function
@author Pablo Regis
@since  05/11/2026
@param cCod, character, código a localizar
@param cCodigos, character, concatenação dos códigos válidos (fOpcGrp)
@return numeric, posição do código (1..n) ou 0
/*/
Static Function fOrgPos(cCod, cCodigos)

Local nRet := 0
Local nI   := 0

For nI := 1 To Len(cCodigos) Step ORG_TAM
	If SubStr(cCodigos, nI, ORG_TAM) == cCod
		nRet := ((nI - 1) / ORG_TAM) + 1
		Exit
	EndIf
Next nI

Return nRet

