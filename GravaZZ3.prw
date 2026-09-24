#Include "Protheus.ch"

/*/{Protheus.doc} GravaZZ3
Funcao publica para gravacao dos dados de auditoria na tabela ZZ3.

@author  Desenvolvedor Protheus
@since   22/09/2026
@type    Function
/*/
User Function GravaZZ3(cJustificativa, cUsuario, cOrigem)
    Local cDocNum   := SD3->D3_DOC
    Local cProduto  := SD3->D3_COD
    Local nQuant    := SD3->D3_QUANT
    Local cArmOri   := SD3->D3_LOCAL
    Local cArmDes   := ""
    
    // Recupera o armazem destino posicionado na memoria da rotina MATA261
    If Type("cLocDest") == "C" .And. !Empty(cLocDest)
        cArmDes := cLocDest
    Else
        cArmDes := SD3->D3_LOCAL
    EndIf

    DbSelectArea("ZZ3")
    DbSetOrder(1) // ZZ3_FILIAL + ZZ3_DOC + ZZ3_PRODUT

    If RecLock("ZZ3", .T.)
        ZZ3->ZZ3_FILIAL  := xFilial("ZZ3")
        ZZ3->ZZ3_DOC     := cDocNum
        ZZ3->ZZ3_PRODUT  := cProduto
        ZZ3->ZZ3_QUANT   := nQuant
        ZZ3->ZZ3_ARMORI  := cArmOri
        ZZ3->ZZ3_ARMDES  := cArmDes
        ZZ3->ZZ3_JUSTIF  := AllTrim(cJustificativa)
        ZZ3->ZZ3_USUARIO := cUsuario
        ZZ3->ZZ3_DATA    := dDataBase
        ZZ3->ZZ3_HORA    := Time()
        ZZ3->ZZ3_ORIGEM  := cOrigem
        
        ZZ3->(MsUnlock())
    EndIf

Return

/*
===============================================================================
Resumo de Campos para Cadastro no SIGACFG (Configurador):
===============================================================================
Tabela: ZZ3 - Auditoria de Transferencias
Indice: 1 (ZZ3_FILIAL + ZZ3_DOC + ZZ3_PRODUT)

Campos:
- ZZ3_FILIAL (C, 2,  0) : Filial
- ZZ3_DOC    (C, 9,  0) : Documento
- ZZ3_PRODUT (C, 15, 0) : Produto
- ZZ3_QUANT  (N, 12, 2) : Quantidade
- ZZ3_ARMORI (C, 2,  0) : Armazem Origem
- ZZ3_ARMDES (C, 2,  0) : Armazem Destino
- ZZ3_JUSTIF (C, 255,0) : Justificativa
- ZZ3_USUARIO(C, 6,  0) : Codigo Usuario
- ZZ3_DATA   (D, 8,  0) : Data Confirmacao
- ZZ3_HORA   (C, 5,  0) : Hora Confirmacao
- ZZ3_ORIGEM (C, 1,  0) : Origem (1=Manual, 2=Automatica)
===============================================================================
*/
