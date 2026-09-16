#include "protheus.ch"
#include "parmtype.ch"
#INCLUDE "FWMVCDEF.CH"

/*/{Protheus.doc} CUSTOMERVENDOR
description
@type function
@version
@author User
@since 9/3/2026
@return variant, return_description
/*/
User Function CUSTOMERVENDOR()
    Local aParam       := PARAMIXB
    Local xRet         := .T.
    Local oObj         := ""
    Local cIdPonto     := ""
    Local cIdModel     := ""
    Local lIsGrid      := .F.
    Local oModel       := FwModelActive()
    Local nOpc
    Local aCampSens    := {"A2_MSBLQL", "A2_XSTATU"}
    Local cCampoAtu    := ""
    Local xValorAnt    := Nil
    Local xValorNovo   := Nil
    Local nX           := 0
    Local oAssEle      as Object

    If aParam <> NIL
        oObj     := aParam[1]
        nOpc     := oObj:GetOperation()
        cIdPonto := aParam[2]
        cIdModel := aParam[3]
        lIsGrid  := (Len(aParam) > 3)

        If  Upper(Alltrim(cIdModel))  == "SA2MASTER"

            If cIdPonto == "MODELPOS"

            ElseIf cIdPonto == "FORMPOS"
                If oModel <> NIL    .And.  nOpc == MODEL_OPERATION_UPDATE

                    oAssEle := ZTLAssinaEletronica():New("CUSTOMERVENDOR", "SA2", SA2->A2_FILIAL + SA2->A2_COD + SA2->A2_LOJA)
                    oAssEle:SetParamChave("FS_CICOMR01")

                    For nX := 1 To Len(aCampSens)
                        cCampoAtu  := aCampSens[nX]
                        xValorAnt  := SA2->(FieldGet(FieldPos(cCampoAtu)))
                        xValorNovo := oModel:GetModel("SA2MASTER"):GetValue(cCampoAtu)
                        If xValorNovo <> xValorAnt
                            oAssEle:AddAlteracao(cCampoAtu, xValorAnt, xValorNovo)
                        EndIf
                    Next nX

                    xRet := oAssEle:Confirma()
                    If xRet == .F.
                        FWAlertWarning("Usuario sem permissao de alterar dados sensiveis do fornecedor!")
                    EndIf

                EndIf
            ElseIf cIdPonto == "FORMLINEPRE"

            ElseIf cIdPonto == "FORMLINEPOS"

            ElseIf cIdPonto == "MODELCOMMITTTS"

            ElseIf cIdPonto == "MODELCOMMITNTTS"

            ElseIf cIdPonto == "FORMCOMMITTTSPRE"

            ElseIf cIdPonto == "FORMCOMMITTTSPOS"

            ElseIf cIdPonto == "MODELCANCEL"

            ElseIf cIdPonto == "BUTTONBAR"

            EndIf
    EndIf
    EndiF

Return xRet
