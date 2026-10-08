#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOPCONN.CH"

/*/{Protheus.doc} CI04R001
Relatório de Balanço de Estoque de Reagentes Controlados (MIT041).

Consolida, por Filial + Produto + Lote + Armazém, as informações regulatórias do
reagente (órgão fiscalizador, nº CAS, FDS, limite de estoque) com o balanço do
período: Saldo Inicial + Compras - Consumo - Perdas/Transferências = Saldo Final.

Base: MATR445 (estrutura TReport / query / CalcEst), MATR425 (filtro de validade
em SB8), MATR435 (CalcEstL por lote) e MATR330 (classificação por CF/CFOP).

Dicionário necessário
---------------------
Grupo de perguntas CI04R001 (SX1):
  01 Filial de ?                    C  tam. filial   F3 SM0
  02 Filial até ?                   C  tam. filial   F3 SM0
  03 Período de ?                   D  8
  04 Período até ?                  D  8
  05 Grupo de Produto de ?          C  tam. BM_GRUPO F3 SBM
  06 Grupo de Produto até ?         C  tam. BM_GRUPO F3 SBM
  07 Produto/Reagente de ?          C  tam. B1_COD   F3 SB1
  08 Produto/Reagente até ?         C  tam. B1_COD   F3 SB1
  09 Validade de ?                  D  8
  10 Validade até ?                 D  8
  11 Quais Órgãos Fiscalizadores ?  C  10            X1_VALID: U_CI04ROrg()

Flags de produto controlado na SB5 (configuração padrão TOTVS dos mapas):
  MV_PRODPF  -> campo da Polícia Federal  (ex.: B5_PRODPF)   - MATA950/MATR913
  MV_MTR949A -> campo do Exército         (ex.: B5_PRODEX)   - MATR949
  MV_MTR947A -> campo da Polícia Civil    (ex.: B5_PRODCON)  - MATR947
Opcionais (configuração PF): MV_DESCPR (nome comercial), MV_CODMAPA (cód. SIPROQUIM).

Campos customizados (SB5): B5_XCAS, B5_XFDS, B5_XANVISA, B5_XARMAZ, B5_XLIMEST.
Campos inexistentes no dicionário são tratados como vazios (o relatório não aborta).

@type  User Function
@author bacoetrom@gmail.com
@since  08/10/2026
@version 1.0
/*/

//-- Campos customizados (MIT041 - seção 7.2)
#DEFINE CPO_CAS      "B5_XCAS"
#DEFINE CPO_FDS      "B5_XFDS"
#DEFINE CPO_ANVISA   "B5_XANVISA"
#DEFINE CPO_ARMAZ    "B5_XARMAZ"
#DEFINE CPO_LIMEST   "B5_XLIMEST"

//-- Regras de classificação (MIT041 - seção 6). PERDAS: pendência P1 com o cliente
#DEFINE CF_TRF_ENT   "1151/1152/1552/2151/2152/2552"
#DEFINE CF_TRF_SAI   "5151/5152/5156/5552/6151/6152/6156/6552"
#DEFINE D3_CF_TRANSF "RE4/DE4/RE7/DE7"
#DEFINE TM_PERDAS    "499/999"

//-- Pergunta 11 - órgãos fiscalizadores (códigos de 2 posições)
#DEFINE ORG_CODIGOS  "PCPFEXAVNC"
#DEFINE MAX_DIAS     4095
#DEFINE NUM_PERG     "CI04R001"

//-- Posições do array de órgãos
#DEFINE ORG_COD      1
#DEFINE ORG_DESC     2
#DEFINE ORG_CAMPO    3
#DEFINE ORG_PARAM    4

/*/{Protheus.doc} CI04R001
Ponto de entrada do relatório.
/*/
User Function CI04R001()

Local oReport

Pergunte(NUM_PERG, .F.)

oReport := ReportDef()
oReport:PrintDialog()

Return

/*/{Protheus.doc} ReportDef
Definição do layout (colunas bilíngues PT/EN).
/*/
Static Function ReportDef()

Local oReport
Local oSecao
Local oBreak
Local cPictQtd := PesqPict("SB8", "B8_SALDO")
Local nTamQtd  := TamSX3("B8_SALDO")[1] + 4
Local cTitulo  := "Balanço de Estoque de Reagentes Controlados / Controlled Reagents Stock Balance"
Local cDescri  := "Consolida as informações regulatórias dos reagentes controlados com o balanço de " + ;
                  "estoque do período (saldo inicial, compras, consumo, perdas/transferências e saldo final)."

oReport := TReport():New(NUM_PERG, cTitulo, NUM_PERG, {|oRep| ReportPrint(oRep)}, cDescri)
oReport:SetLandscape()
oReport:SetTotalInLine(.F.)

oSecao := TRSection():New(oReport, "Reagentes controlados / Controlled reagents", {"SB8", "SB1", "SB5"})
oSecao:SetTotalInLine(.F.)
oSecao:SetHeaderPage(.T.)

//-- Identificação
TRCell():New(oSecao, "FILIAL"  , "", "Filial"          + CRLF + "Branch"         , "@!", FWSizeFilial())
TRCell():New(oSecao, "PRODUTO" , "", "Código"          + CRLF + "Code"           , "@!", TamSX3("B1_COD")[1])
TRCell():New(oSecao, "NOMECOM" , "", "Nome Comercial"  + CRLF + "Trade Name"     , "@!", 30)
TRCell():New(oSecao, "NOMEQUI" , "", "Nome Químico"    + CRLF + "Chemical Name"  , "@!", 30)
TRCell():New(oSecao, "CAS"     , "", "Nº CAS"          + CRLF + "CAS Number"     , "@!", 12)
TRCell():New(oSecao, "CODMAPA" , "", "Cód. SIPROQUIM"  + CRLF + "SIPROQUIM Code" , "@!", 11)
TRCell():New(oSecao, "FORMA"   , "", "Forma"           + CRLF + "Physical Form"  , "@!", 10)
TRCell():New(oSecao, "UM"      , "", "UM"              + CRLF + "UoM"            , "@!", TamSX3("B1_UM")[1])

//-- Regulatório
TRCell():New(oSecao, "ORGAO"   , "", "Órgão Fiscaliz." + CRLF + "Regulatory Agency", "@!", 20)
TRCell():New(oSecao, "LIMEST"  , "", "Limite Estoque"  + CRLF + "Stock Limit"    , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "FDS"     , "", "FDS"             + CRLF + "SDS"            , "@!", 20)
TRCell():New(oSecao, "ARMAZEN" , "", "Armazenamento"   + CRLF + "Storage"        , "@!", 20)

//-- Lote
TRCell():New(oSecao, "ARMAZEM" , "", "Armazém"         + CRLF + "Warehouse"      , "@!", TamSX3("B8_LOCAL")[1])
TRCell():New(oSecao, "LOTE"    , "", "Lote"            + CRLF + "Batch"          , "@!", TamSX3("B8_LOTECTL")[1])
TRCell():New(oSecao, "SUBLOTE" , "", "Sub-Lote"        + CRLF + "Sub-Batch"      , "@!", TamSX3("B8_NUMLOTE")[1])
TRCell():New(oSecao, "LOTEFOR" , "", "Lote Fabric."    + CRLF + "Mfr. Batch"     , "@!", TamSX3("B8_LOTEFOR")[1])
TRCell():New(oSecao, "FABRIC"  , "", "Fabricante"      + CRLF + "Manufacturer"   , "@!", 30)
TRCell():New(oSecao, "DTFABRIC", "", "Dt. Fabricação"  + CRLF + "Mfg. Date"      , "@D", 10)
TRCell():New(oSecao, "DTVALID" , "", "Dt. Validade"    + CRLF + "Expiry Date"    , "@D", 10)

//-- Nota fiscal de compra
TRCell():New(oSecao, "NFDOC"   , "", "NF Compra"       + CRLF + "Purchase Inv."  , "@!", TamSX3("B8_DOC")[1])
TRCell():New(oSecao, "NFSERIE" , "", "Série"           + CRLF + "Series"         , "@!", TamSX3("B8_SERIE")[1])
TRCell():New(oSecao, "NFEMIS"  , "", "Emissão NF"      + CRLF + "Inv. Date"      , "@D", 10)

//-- Balanço do período
TRCell():New(oSecao, "SLDINI"  , "", "Saldo Inicial"   + CRLF + "Opening Balance", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "COMPRAS" , "", "Compras"         + CRLF + "Purchases"      , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "CONSUMO" , "", "Consumo"         + CRLF + "Consumption"    , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "PERDAS"  , "", "Perdas/Transf."  + CRLF + "Losses/Transfers", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "SLDFIM"  , "", "Saldo Final"     + CRLF + "Closing Balance", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "SLDSIS"  , "", "Saldo Sistema"   + CRLF + "System Balance" , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "CONFERE" , "", "Conferência"     + CRLF + "Check"          , "@!", 10)

//-- Responsabilidade (preenchimento manual)
TRCell():New(oSecao, "RESP"    , "", "Responsável"     + CRLF + "Responsible"    , "@!", 15)
TRCell():New(oSecao, "CONFER"  , "", "Conferente"      + CRLF + "Checked by"     , "@!", 15)
TRCell():New(oSecao, "OBS"     , "", "Observações"     + CRLF + "Remarks"        , "@!", 20)

//-- Totais por produto (unidades diferentes entre produtos: sem total geral)
oBreak := TRBreak():New(oSecao, oSecao:Cell("PRODUTO"), "Total do produto / Product total", .F.)
TRFunction():New(oSecao:Cell("SLDINI" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("COMPRAS"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("CONSUMO"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("PERDAS" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("SLDFIM" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)

Return oReport

/*/{Protheus.doc} ReportPrint
Valida os filtros, percorre as filiais do intervalo e imprime.
/*/
Static Function ReportPrint(oReport)

Local oSecao   := oReport:Section(1)
Local aSM0     := {}
Local aFiliais := {}
Local aOrgaos  := {}
Local oCfg     := Nil
Local cCondOrg := ""
Local cErro    := ""
Local cFilBak  := cFilAnt
Local nI       := 0

aOrgaos := fOrgaos()

If !fValida(aOrgaos, @cCondOrg, @cErro)
	Help(NIL, NIL, NUM_PERG, NIL, cErro, 1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros do relatório."})
	oReport:CancelPrint()
	Return
EndIf

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
oReport:SetMeter(Len(aFiliais))
oSecao:Init()

For nI := 1 To Len(aFiliais)
	If oReport:Cancel()
		Exit
	EndIf
	cFilAnt := aFiliais[nI]        //-- CalcEst/CalcEstL e xFilial() usam a filial corrente
	oReport:IncMeter()
	fProcFil(oReport, oSecao, aOrgaos, cCondOrg, oCfg)
Next nI

oSecao:Finish()
cFilAnt := cFilBak

FwFreeArray(aSM0)
FwFreeArray(aFiliais)

Return

/*/{Protheus.doc} fValida
Validação dos filtros obrigatórios (fluxo alternativo A1) e montagem da condição de órgãos.
/*/
Static Function fValida(aOrgaos, cCondOrg, cErro)

Local cOrg   := fLimpaOrg(mv_par11)
Local aCond  := {}
Local aNC    := {}
Local cCod   := ""
Local nI     := 0
Local nPos   := 0
Local lRet   := .T.

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
	cErro := "Selecione ao menos um órgão fiscalizador."
EndCase

lRet := Empty(cErro)

//-- Condição SQL dos órgãos marcados (unidos por OR)
For nI := 1 To Len(cOrg) Step 2
	If !lRet
		Exit
	EndIf
	cCod := SubStr(cOrg, nI, 2)
	If cCod == "NC"
		//-- Não controlado: nenhuma das flags configuradas = 'S'
		aEval(aOrgaos, {|x| If(!Empty(x[ORG_CAMPO]), aAdd(aNC, "COALESCE(SB5." + x[ORG_CAMPO] + ",' ') <> 'S'"), Nil)})
		aAdd(aCond, If(Empty(aNC), "1 = 1", "(" + fJunta(aNC, " AND ") + ")"))
	Else
		nPos := aScan(aOrgaos, {|x| x[ORG_COD] == cCod})
		If nPos == 0
			cErro := "Código de órgão inválido: " + cCod + "."
			lRet  := .F.
		ElseIf Empty(aOrgaos[nPos][ORG_CAMPO])
			cErro := "Órgão " + aOrgaos[nPos][ORG_DESC] + " não configurado" + ;
			         If(Empty(aOrgaos[nPos][ORG_PARAM]), " (campo " + CPO_ANVISA + " inexistente na SB5).", ;
			            " (parâmetro " + aOrgaos[nPos][ORG_PARAM] + " vazio ou campo inexistente na SB5).")
			lRet  := .F.
		Else
			aAdd(aCond, "SB5." + aOrgaos[nPos][ORG_CAMPO] + " = 'S'")
		EndIf
	EndIf
Next nI

If lRet
	cCondOrg := "(" + fJunta(aCond, " OR ") + ")"
EndIf

Return lRet

/*/{Protheus.doc} fProcFil
Processa a filial corrente: produtos com rastro (SB8) e sem rastro (SB2).
/*/
Static Function fProcFil(oReport, oSecao, aOrgaos, cCondOrg, oCfg)

Local oMov     := fCarregaMov()
Local oCache   := JsonObject():New()
Local oItem    := Nil
Local cAlias   := GetNextAlias()
Local cQry     := ""
Local cChave   := ""
Local cChvAnt  := ""
Local lSubLote := .F.

//-- 1) Produtos com rastro de lote/sublote: um registro por Produto + Armazém + Lote (+ Sub-Lote)
cQry := "SELECT SB8.B8_PRODUTO PRODUTO, SB8.B8_LOCAL ARMAZEM, SB8.B8_LOTECTL LOTE, SB8.B8_NUMLOTE SUBLOTE, "
cQry += "       SB8.B8_DTVALID DTVALID, SB8.B8_DFABRIC DTFABRIC, SB8.B8_LOTEFOR LOTEFOR, "
cQry += "       SB8.B8_DOC DOC, SB8.B8_SERIE SERIE, SB8.B8_CLIFOR CLIFOR, SB8.B8_LOJA LOJA, SB8.B8_ORIGLAN ORIGLAN, "
cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO, SB1.B1_EMAX EMAX "
cQry += "  FROM " + RetSqlName("SB8") + " SB8 "
cQry += " INNER JOIN " + RetSqlName("SB1") + " SB1 ON SB1.B1_FILIAL = '" + xFilial("SB1") + "' "
cQry += "       AND SB1.B1_COD = SB8.B8_PRODUTO AND SB1.D_E_L_E_T_ = ' ' "
cQry += "  LEFT JOIN " + RetSqlName("SB5") + " SB5 ON SB5.B5_FILIAL = '" + xFilial("SB5") + "' "
cQry += "       AND SB5.B5_COD = SB8.B8_PRODUTO AND SB5.D_E_L_E_T_ = ' ' "
cQry += " WHERE SB8.B8_FILIAL = '" + xFilial("SB8") + "' "
cQry += "   AND SB8.B8_PRODUTO BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cQry += "   AND SB8.B8_DTVALID BETWEEN '" + DtoS(mv_par09) + "' AND '" + DtoS(mv_par10) + "' "
cQry += "   AND SB1.B1_RASTRO IN ('L','S') "
cQry += "   AND " + cCondOrg + " "
cQry += "   AND SB8.D_E_L_E_T_ = ' ' "
cQry += " ORDER BY SB8.B8_PRODUTO, SB8.B8_LOCAL, SB8.B8_LOTECTL, SB8.B8_NUMLOTE, SB8.B8_DATA "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "DTVALID" , "D", 8, 0)
TcSetField(cAlias, "DTFABRIC", "D", 8, 0)
TcSetField(cAlias, "EMAX"    , "N", TamSX3("B1_EMAX")[1], TamSX3("B1_EMAX")[2])

While !(cAlias)->(Eof()) .And. !oReport:Cancel()

	lSubLote := (cAlias)->RASTRO == "S"
	cChave   := fChave((cAlias)->PRODUTO, (cAlias)->ARMAZEM, (cAlias)->LOTE, If(lSubLote, (cAlias)->SUBLOTE, ""))

	//-- Rastro por lote pode ter mais de um SB8 para o mesmo lote: usa o primeiro (entrada mais antiga)
	If cChave <> cChvAnt
		cChvAnt := cChave
		oItem   := fMontaItem(cAlias, .T., lSubLote, oMov, cChave, aOrgaos, oCfg, oCache)
		If ValType(oItem) == "O"
			fImprime(oSecao, oItem)
			FreeObj(oItem)
		EndIf
	EndIf

	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

//-- 2) Produtos controlados sem rastro: um registro por Produto + Armazém (validade não se aplica)
cAlias := GetNextAlias()
cQry := "SELECT SB2.B2_COD PRODUTO, SB2.B2_LOCAL ARMAZEM, "
cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO, SB1.B1_EMAX EMAX "
cQry += "  FROM " + RetSqlName("SB2") + " SB2 "
cQry += " INNER JOIN " + RetSqlName("SB1") + " SB1 ON SB1.B1_FILIAL = '" + xFilial("SB1") + "' "
cQry += "       AND SB1.B1_COD = SB2.B2_COD AND SB1.D_E_L_E_T_ = ' ' "
cQry += "  LEFT JOIN " + RetSqlName("SB5") + " SB5 ON SB5.B5_FILIAL = '" + xFilial("SB5") + "' "
cQry += "       AND SB5.B5_COD = SB2.B2_COD AND SB5.D_E_L_E_T_ = ' ' "
cQry += " WHERE SB2.B2_FILIAL = '" + xFilial("SB2") + "' "
cQry += "   AND SB2.B2_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cQry += "   AND SB1.B1_RASTRO NOT IN ('L','S') "
cQry += "   AND " + cCondOrg + " "
cQry += "   AND SB2.D_E_L_E_T_ = ' ' "
cQry += " ORDER BY SB2.B2_COD, SB2.B2_LOCAL "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "EMAX", "N", TamSX3("B1_EMAX")[1], TamSX3("B1_EMAX")[2])

While !(cAlias)->(Eof()) .And. !oReport:Cancel()
	cChave := fChave((cAlias)->PRODUTO, (cAlias)->ARMAZEM, "", "")
	oItem  := fMontaItem(cAlias, .F., .F., oMov, cChave, aOrgaos, oCfg, oCache)
	If ValType(oItem) == "O"
		fImprime(oSecao, oItem)
		FreeObj(oItem)
	EndIf
	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

FreeObj(oMov)
FreeObj(oCache)

Return

/*/{Protheus.doc} fCarregaMov
Movimentos do período da filial corrente, agregados por Produto + Armazém + Lote + Sub-Lote
e classificados em Compras / Consumo / Perdas-Transferências (MIT041 - seção 6).
Retorna JsonObject: chave -> {nCompras, nConsumo, nPerdas}.
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
Local cJoinB1   := ""
Local lWmsNew   := SuperGetMv("MV_WMSNEW", .F., .F.)
Local lD3Servi  := IIf(lWmsNew, .F., GetMV("MV_D3SERVI", .F., "N") == "N")

cPerdaD3 := "(D3_CF IN (" + cCfD3Tr + ") OR D3_TM IN (" + cTmPerda + "))"
cProdD3  := "(D3_CF LIKE 'PR%' OR D3_CF LIKE 'ER%')"

//-- Mesmo filtro de WMS do MATR445
If lD3Servi .And. IntDL()
	cWhereD3 := " AND ( (D3_SERVIC = '   ') OR (D3_SERVIC <> '   ' AND D3_TM <= '500') OR "
	cWhereD3 += " (D3_SERVIC <> '   ' AND D3_TM > '500' AND D3_LOCAL = '" + GetMvNNR("MV_CQ", "98") + "') ) "
EndIf

cJoinB1 := " INNER JOIN " + RetSqlName("SB1") + " SB1 ON SB1.B1_FILIAL = '" + xFilial("SB1") + "' AND SB1.D_E_L_E_T_ = ' ' "
cJoinB1 += " AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' AND SB1.B1_COD = "

cQry := "SELECT COD, LOC, LOTE, SUBLOTE, SUM(COMPRAS) COMPRAS, SUM(CONSUMO) CONSUMO, SUM(PERDAS) PERDAS FROM ( "

//-- SD1: compras (+), devolução de venda (- consumo), transferência recebida (- perdas/transf.)
cQry += "SELECT D1_COD COD, D1_LOCAL LOC, D1_LOTECTL LOTE, D1_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D1_TIPO <> 'D' AND D1_CF NOT IN (" + cCfTrE + ") THEN D1_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN D1_TIPO = 'D' THEN -D1_QUANT ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN D1_TIPO <> 'D' AND D1_CF IN (" + cCfTrE + ") THEN -D1_QUANT ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD1") + " SD1 "
cQry += " INNER JOIN " + RetSqlName("SF4") + " SF4 ON SF4.F4_FILIAL = '" + xFilial("SF4") + "' "
cQry += "       AND SF4.F4_CODIGO = SD1.D1_TES AND SF4.F4_ESTOQUE = 'S' AND SF4.D_E_L_E_T_ = ' ' "
cQry += cJoinB1 + "SD1.D1_COD "
cQry += " WHERE SD1.D1_FILIAL = '" + xFilial("SD1") + "' "
cQry += "   AND SD1.D1_DTDIGIT BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD1.D1_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD1.D1_ORIGLAN <> 'LF' AND SD1.D_E_L_E_T_ = ' ' "

cQry += "UNION ALL "

//-- SD2: vendas (+ consumo), devolução de compra (- compras), transferência enviada (+ perdas/transf.)
cQry += "SELECT D2_COD COD, D2_LOCAL LOC, D2_LOTECTL LOTE, D2_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D2_TIPO = 'D' THEN -D2_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN D2_TIPO <> 'D' AND D2_CF NOT IN (" + cCfTrS + ") THEN D2_QUANT ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN D2_TIPO <> 'D' AND D2_CF IN (" + cCfTrS + ") THEN D2_QUANT ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD2") + " SD2 "
cQry += " INNER JOIN " + RetSqlName("SF4") + " SF4 ON SF4.F4_FILIAL = '" + xFilial("SF4") + "' "
cQry += "       AND SF4.F4_CODIGO = SD2.D2_TES AND SF4.F4_ESTOQUE = 'S' AND SF4.D_E_L_E_T_ = ' ' "
cQry += cJoinB1 + "SD2.D2_COD "
cQry += " WHERE SD2.D2_FILIAL = '" + xFilial("SD2") + "' "
cQry += "   AND SD2.D2_EMISSAO BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD2.D2_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD2.D2_ORIGLAN <> 'LF' AND SD2.D_E_L_E_T_ = ' ' "

cQry += "UNION ALL "

//-- SD3: produção (+ compras/entradas), transferências e TMs de perda (perdas/transf.), demais (consumo)
cQry += "SELECT D3_COD COD, D3_LOCAL LOC, D3_LOTECTL LOTE, D3_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D3_CF LIKE 'PR%' THEN D3_QUANT WHEN D3_CF LIKE 'ER%' THEN -D3_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN NOT " + cProdD3 + " AND NOT " + cPerdaD3
cQry += "       THEN (CASE WHEN D3_TM > '500' THEN D3_QUANT ELSE -D3_QUANT END) ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN NOT " + cProdD3 + " AND " + cPerdaD3
cQry += "       THEN (CASE WHEN D3_TM > '500' THEN D3_QUANT ELSE -D3_QUANT END) ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD3") + " SD3 "
cQry += cJoinB1 + "SD3.D3_COD "
cQry += " WHERE SD3.D3_FILIAL = '" + xFilial("SD3") + "' "
cQry += "   AND SD3.D3_EMISSAO BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD3.D3_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD3.D3_ESTORNO <> 'S' AND SD3.D_E_L_E_T_ = ' ' "
cQry += cWhereD3

cQry += ") MOV GROUP BY COD, LOC, LOTE, SUBLOTE "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "COMPRAS", "N", 18, 4)
TcSetField(cAlias, "CONSUMO", "N", 18, 4)
TcSetField(cAlias, "PERDAS" , "N", 18, 4)

While !(cAlias)->(Eof())
	oMov[fChave((cAlias)->COD, (cAlias)->LOC, (cAlias)->LOTE, (cAlias)->SUBLOTE)] := ;
		{(cAlias)->COMPRAS, (cAlias)->CONSUMO, (cAlias)->PERDAS}
	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

Return oMov

/*/{Protheus.doc} fMontaItem
Calcula o balanço do item e reúne as informações regulatórias. Retorna Nil quando
não há saldo nem movimento no período.
/*/
Static Function fMontaItem(cAlias, lLote, lSubLote, oMov, cChave, aOrgaos, oCfg, oCache)

Local oItem    := Nil
Local cProd    := (cAlias)->PRODUTO
Local cLocal   := (cAlias)->ARMAZEM
Local cLote    := ""
Local cSubLote := Nil
Local aMov     := oMov[cChave]
Local nIni     := 0
Local nSis     := 0
Local nFim     := 0
Local cEstMat  := ""
Local xLimite  := Nil

If ValType(aMov) <> "A"
	aMov := {0, 0, 0}
EndIf

If lLote
	cLote    := (cAlias)->LOTE
	cSubLote := If(lSubLote, (cAlias)->SUBLOTE, Nil)
	nIni     := CalcEstL(cProd, cLocal, mv_par03    , cLote, cSubLote)[1]
	nSis     := CalcEstL(cProd, cLocal, mv_par04 + 1, cLote, cSubLote)[1]
Else
	nIni     := CalcEst(cProd, cLocal, mv_par03)[1]
	nSis     := CalcEst(cProd, cLocal, mv_par04 + 1)[1]
EndIf

//-- Sem saldo e sem movimento no período: não imprime
If nIni == 0 .And. nSis == 0 .And. aMov[1] == 0 .And. aMov[2] == 0 .And. aMov[3] == 0
	Return Nil
EndIf

nFim := nIni + aMov[1] - aMov[2] - aMov[3]

SB5->(DbSetOrder(1))
SB5->(MsSeek(xFilial("SB5") + cProd))

oItem := JsonObject():New()
oItem["FILIAL"  ] := cFilAnt
oItem["PRODUTO" ] := cProd
oItem["NOMECOM" ] := fCpoSB5(oCfg["DESCPR"], "")
If Empty(oItem["NOMECOM"])
	oItem["NOMECOM"] := (cAlias)->DESCRI
EndIf
oItem["NOMEQUI" ] := fCpoSB5("B5_CEME", "")
oItem["CAS"     ] := fCpoSB5(CPO_CAS, "")
oItem["CODMAPA" ] := fCpoSB5(oCfg["CODMAPA"], "")
cEstMat := fCpoSB5("B5_ESTMAT", "")
oItem["FORMA"   ] := If(Empty(cEstMat), "", X3Combo("B5_ESTMAT", cEstMat))
oItem["UM"      ] := (cAlias)->UM
oItem["ORGAO"   ] := fDescOrg(aOrgaos)
xLimite := fCpoSB5(CPO_LIMEST, Nil)
oItem["LIMEST"  ] := If(ValType(xLimite) == "N" .And. xLimite > 0, xLimite, (cAlias)->EMAX)
oItem["FDS"     ] := fCpoSB5(CPO_FDS, "")
oItem["ARMAZEN" ] := fCpoSB5(CPO_ARMAZ, "")
oItem["ARMAZEM" ] := cLocal

If lLote
	oItem["LOTE"    ] := cLote
	oItem["SUBLOTE" ] := If(lSubLote, (cAlias)->SUBLOTE, "")
	oItem["LOTEFOR" ] := (cAlias)->LOTEFOR
	oItem["FABRIC"  ] := fFabric(cProd, cLote, (cAlias)->ORIGLAN, (cAlias)->CLIFOR, (cAlias)->LOJA, oCache)
	oItem["DTFABRIC"] := (cAlias)->DTFABRIC
	oItem["DTVALID" ] := (cAlias)->DTVALID
	oItem["NFDOC"   ] := (cAlias)->DOC
	oItem["NFSERIE" ] := (cAlias)->SERIE
	oItem["NFEMIS"  ] := If(Empty((cAlias)->DOC), CtoD(""), ;
	                     Posicione("SF1", 1, xFilial("SF1") + (cAlias)->DOC + (cAlias)->SERIE + (cAlias)->CLIFOR + (cAlias)->LOJA, "F1_EMISSAO"))
Else
	oItem["LOTE"    ] := ""
	oItem["SUBLOTE" ] := ""
	oItem["LOTEFOR" ] := ""
	oItem["FABRIC"  ] := ""
	oItem["DTFABRIC"] := CtoD("")
	oItem["DTVALID" ] := CtoD("")
	oItem["NFDOC"   ] := ""
	oItem["NFSERIE" ] := ""
	oItem["NFEMIS"  ] := CtoD("")
EndIf

oItem["SLDINI"  ] := nIni
oItem["COMPRAS" ] := aMov[1]
oItem["CONSUMO" ] := aMov[2]
oItem["PERDAS"  ] := aMov[3]
oItem["SLDFIM"  ] := nFim
oItem["SLDSIS"  ] := nSis
oItem["CONFERE" ] := If(Abs(nFim - nSis) < 0.0001, "OK", "DIVERGENTE")
oItem["RESP"    ] := ""
oItem["CONFER"  ] := ""
oItem["OBS"     ] := ""

Return oItem

/*/{Protheus.doc} fImprime
Transfere os valores do item para as células e imprime a linha.
/*/
Static Function fImprime(oSecao, oItem)

Local aCelulas := {"FILIAL", "PRODUTO", "NOMECOM", "NOMEQUI", "CAS", "CODMAPA", "FORMA", "UM", ;
                   "ORGAO", "LIMEST", "FDS", "ARMAZEN", "ARMAZEM", "LOTE", "SUBLOTE", "LOTEFOR", ;
                   "FABRIC", "DTFABRIC", "DTVALID", "NFDOC", "NFSERIE", "NFEMIS", "SLDINI", ;
                   "COMPRAS", "CONSUMO", "PERDAS", "SLDFIM", "SLDSIS", "CONFERE", "RESP", "CONFER", "OBS"}
Local nI       := 0

For nI := 1 To Len(aCelulas)
	oSecao:Cell(aCelulas[nI]):SetValue(oItem[aCelulas[nI]])
Next nI

oSecao:PrintLine()

Return

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
		cChave := cProd + cCliFor + cLoja
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
Órgãos fiscalizadores: código, descrição, campo da flag na SB5 e parâmetro de origem.
/*/
Static Function fOrgaos()

Local aOrgaos := {}

aAdd(aOrgaos, {"PC", "POLÍCIA CIVIL"  , fCampoMV("MV_MTR947A")      , "MV_MTR947A"})
aAdd(aOrgaos, {"PF", "POLÍCIA FEDERAL", fCampoMV("MV_PRODPF")       , "MV_PRODPF" })
aAdd(aOrgaos, {"EX", "EXÉRCITO"       , fCampoMV("MV_MTR949A")      , "MV_MTR949A"})
aAdd(aOrgaos, {"AV", "ANVISA"         , fCampoSB5(CPO_ANVISA, .T.)  , ""          })   //-- sem flag padrão (P7)

Return aOrgaos

/*/{Protheus.doc} fDescOrg
Órgãos cuja flag está = 'S' para o produto posicionado na SB5.
/*/
Static Function fDescOrg(aOrgaos)

Local aDesc := {}
Local nI    := 0

For nI := 1 To Len(aOrgaos)
	If !Empty(aOrgaos[nI][ORG_CAMPO]) .And. fCpoSB5(aOrgaos[nI][ORG_CAMPO], "") == "S"
		aAdd(aDesc, aOrgaos[nI][ORG_COD])
	EndIf
Next nI

Return If(Empty(aDesc), "NAO CONTROLADO", fJunta(aDesc, " / "))

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
/*/
Static Function fCampoSB5(cCampo, lValida)

If !lValida .Or. Empty(cCampo) .Or. SB5->(FieldPos(cCampo)) == 0
	cCampo := ""
EndIf

Return cCampo

/*/{Protheus.doc} fCpoSB5
Conteúdo de um campo da SB5 posicionada; xDefault se o campo não existir.
/*/
Static Function fCpoSB5(cCampo, xDefault)

Local xRet := xDefault
Local nPos := 0

If !Empty(cCampo)
	nPos := SB5->(FieldPos(cCampo))
	If nPos > 0 .And. !SB5->(Eof())
		xRet := SB5->(FieldGet(nPos))
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
Chave do item: Produto | Armazém | Lote | Sub-Lote.
/*/
Static Function fChave(cProd, cLocal, cLote, cSubLote)
Return AllTrim(cProd) + "|" + AllTrim(cLocal) + "|" + AllTrim(cLote) + "|" + AllTrim(cSubLote)

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

/*/{Protheus.doc} fLimpaOrg
Normaliza o conteúdo da pergunta 11 (remove espaços e marcadores de não selecionado).
/*/
Static Function fLimpaOrg(cOrg)
Return StrTran(StrTran(AllTrim(cOrg), "*", ""), " ", "")

/*/{Protheus.doc} CI04ROrg
X1_VALID da pergunta 11: seleção múltipla dos órgãos fiscalizadores (tela "Escolha Padrões").
Grava em MV_PAR11 os códigos marcados concatenados (ex.: PFEX = Polícia Federal + Exército).
@type User Function
/*/
User Function CI04ROrg()

Local aBox    := {"00001 - POLÍCIA CIVIL", "00002 - POLÍCIA FEDERAL", "00003 - EXÉRCITO", ;
                  "00004 - ANVISA", "00005 - NÃO CONTROLADO"}
Local aCodRet := {}
Local cVar    := ReadVar()
Local cRet    := ""
Local nI      := 0

If !IsBlind()
	If f_Opcoes(@aCodRet, ;           // uVarRet
	            "Escolha Padrões", ;  // cTitulo
	            @aBox, ;              // aOpcoes
	            ORG_CODIGOS, ;        // cOpcoes
	            , ;                   // nLin1
	            , ;                   // nCol1
	            , ;                   // l1Elem
	            2, ;                  // nTam
	            Len(aBox), ;          // nElemRet
	            , ;                   // lMultSelect
	            , ;                   // lComboBox
	            , ;                   // cCampo
	            , ;                   // lNotOrdena
	            , ;                   // lNotPesq
	            .T.)                  // lForceRetArr
		For nI := 1 To Len(aCodRet)
			cRet += aCodRet[nI]
		Next nI
		&(cVar) := PadR(cRet, 10)
	EndIf
EndIf

FwFreeArray(aBox)
FwFreeArray(aCodRet)

Return .T.
