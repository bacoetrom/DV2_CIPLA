
#Include "Protheus.ch"
#Include "FWMVCDef.ch"

//-------------------------------------------------------------------
// CI02A004 - Consulta de Log de Auditoria Genérico (tabela ZZ1)
//
// Rotina MVC (Model-View-Controller) para VISUALIZAÇÃO dos registros
// gravados pelo motor genérico de auditoria U_ZZ1GravaLog (ZZ1U001),
// usado hoje pelo Ponto de Entrada A010TOK (MATA010 - Cadastro de
// Produtos, campo B1_TIPO) e pela função CI02A001 (SA2, campo
// A2_MSBLQL), podendo ser reaproveitado por qualquer outra rotina.
//
// Por se tratar de uma tabela de auditoria/log, esta rotina expõe
// apenas a opção "Visualizar" no Browse — não permite Incluir,
// Alterar ou Excluir pela tela.
//-------------------------------------------------------------------

/*/{Protheus.doc} CI02A004
Função principal da rotina. Monta o Browse (lista de registros) da
tabela ZZ1 e ativa a tela.
/*/
User Function CI02A004()

	Local oBrowse

	oBrowse := FWMBrowse():New()
	oBrowse:SetAlias("ZZ1")
	oBrowse:SetDescription("Log de Auditoria (ZZ1)")
	oBrowse:Activate()

Return

/*/{Protheus.doc} ModelDef
Define o Model (regras de dados) do log de auditoria genérico ZZ1.
@type function
@author Pablo Regis
@since 27/08/2026
@return object, "Instância de MPFormModel do CI02A004"
/*/
Static Function ModelDef()

	Local oStruZZ1 := FWFormStruct(1, "ZZ1")
	Local oModel

	oModel := MPFormModel():New("CI02A004M")
	oModel:AddFields("ZZ1MASTER", /*cOwner*/, oStruZZ1)
	oModel:SetPrimaryKey({"ZZ1_FILIAL", "ZZ1_SEQ"})
	oModel:SetDescription("Log de Auditoria Genérico")

	oModel:GetModel("ZZ1MASTER"):SetDescription("Dados do Evento de Auditoria")

Return oModel


/*/{Protheus.doc} ViewDef
Define a View (layout de tela) usada ao abrir/visualizar um registro
do log. Aqui é um formulário simples, com todos os campos da tabela
ZZ1 dispostos em uma única área (Box) horizontal.
/*/
Static Function ViewDef()

	Local oModel   := FWLoadModel("CI02A004")
	Local oStruZZ1 := FWFormStruct(2, "ZZ1")
	Local oView

	oView := FWFormView():New()
	oView:SetModel(oModel)
	oView:AddField("VIEW_ZZ1", oStruZZ1, "ZZ1MASTER")
	oView:CreateHorizontalBox("TELA", 100)
	oView:SetOwnerView("VIEW_ZZ1", "TELA")

Return oView


/*/{Protheus.doc} MenuDef
Define as opções de menu disponíveis no Browse.

Propositalmente só existe a opção "Visualizar" (OPERATION 2), sem
Incluir (3), Alterar (4) ou Excluir (5) — já que os registros dessa
tabela devem ser gravados exclusivamente pelo motor genérico de
auditoria U_ZZ1GravaLog (ZZ1U001), e não editados manualmente pelo
usuário.
/*/
Static Function MenuDef()

	Local aRotina := {}

	ADD OPTION aRotina TITLE "Visualizar" ACTION "VIEWDEF.CI02A004" OPERATION 2 ACCESS 0

Return aRotina
