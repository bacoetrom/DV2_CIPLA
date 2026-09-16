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
    Local aAlteracoes  := {}
    Local cCampoAtu    := ""
    Local xValorAnt    := Nil
    Local xValorNovo   := Nil
    Local nX           := 0

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

                    aAlteracoes := {}
                    For nX := 1 To Len(aCampSens)
                        cCampoAtu  := aCampSens[nX]
                        xValorAnt  := SA2->(FieldGet(FieldPos(cCampoAtu)))
                        xValorNovo := oModel:GetModel("SA2MASTER"):GetValue(cCampoAtu)
                        If xValorNovo <> xValorAnt
                            aAdd(aAlteracoes, {cCampoAtu, xValorAnt, xValorNovo})
                        EndIf
                    Next nX

                    If Len(aAlteracoes) > 0
                        xRet := U_CICOMR01(aAlteracoes)
                        If xRet == .F.
                            FWAlertWarning("Usuario sem permissao de alterar dados sensiveis do fornecedor!")
                        EndIf
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
