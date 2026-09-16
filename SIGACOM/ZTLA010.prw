
#Include "Protheus.ch"
#Include "FWMVCDef.ch"

//-------------------------------------------------------------------
// ZTLA010 - Consulta de Log de Auditoria Generico (tabela ZTL)
//
// Rotina MVC (Model-View-Controller) para VISUALIZAÇÃO dos registros
// gravados pelo motor generico de auditoria U_ZTLGravaLog (ZTLU001),
// usado hoje pelo Ponto de Entrada A010TOK (MATA010 - Cadastro de
// Produtos, campo B1_TIPO) e pela função CICOMR01 (SA2, campo
// A2_MSBLQL), podendo ser reaproveitado por qualquer outra rotina.
//
// Por se tratar de uma tabela de auditoria/log, esta rotina expõe
// apenas a opção "Visualizar" no Browse — não permite Incluir,
// Alterar ou Excluir pela tela.
//-------------------------------------------------------------------

/*/{Protheus.doc} ZTLA010
Função principal da rotina. Monta o Browse (lista de registros) da
tabela ZTL e ativa a tela.
/*/
User Function ZTLA010()

	Local oBrowse

	oBrowse := FWMBrowse():New()
	oBrowse:SetAlias("ZTL")
	oBrowse:SetDescription("Log de Auditoria (ZTL)")
	oBrowse:Activate()

Return

/*/{Protheus.doc} ModelDef
Define o Model (regras de dados) do log de auditoria generico ZTL.
@type function
@author Pablo Regis
@since 27/08/2026
@return object, "Instancia de MPFormModel do ZTLA010"
/*/
Static Function ModelDef()

	Local oStruZTL := FWFormStruct(1, "ZTL")
	Local oModel

	oModel := MPFormModel():New("ZTLA010M")
	oModel:AddFields("ZTLMASTER", /*cOwner*/, oStruZTL)
	oModel:SetPrimaryKey({"ZTL_FILIAL", "ZTL_SEQ"})
	oModel:SetDescription("Log de Auditoria Genérico")

	oModel:GetModel("ZTLMASTER"):SetDescription("Dados do Evento de Auditoria")

Return oModel


/*/{Protheus.doc} ViewDef
Define a View (layout de tela) usada ao abrir/visualizar um registro
do log. Aqui é um formulário simples, com todos os campos da tabela
ZTL dispostos em uma única área (Box) horizontal.
/*/
Static Function ViewDef()

	Local oModel   := FWLoadModel("ZTLA010")
	Local oStruZTL := FWFormStruct(2, "ZTL")
	Local oView

	oView := FWFormView():New()
	oView:SetModel(oModel)
	oView:AddField("VIEW_ZTL", oStruZTL, "ZTLMASTER")
	oView:CreateHorizontalBox("TELA", 100)
	oView:SetOwnerView("VIEW_ZTL", "TELA")

Return oView


/*/{Protheus.doc} MenuDef
Define as opções de menu disponíveis no Browse.

Propositalmente só existe a opção "Visualizar" (OPERATION 2), sem
Incluir (3), Alterar (4) ou Excluir (5) — já que os registros dessa
tabela devem ser gravados exclusivamente pelo motor generico de
auditoria U_ZTLGravaLog (ZTLU001), e não editados manualmente pelo
usuário.
/*/
Static Function MenuDef()

	Local aRotina := {}

	ADD OPTION aRotina TITLE "Visualizar" ACTION "VIEWDEF.ZTLA010" OPERATION 2 ACCESS 0

Return aRotina
